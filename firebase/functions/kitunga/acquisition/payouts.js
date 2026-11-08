/**
 * Validation des commissions et versements aux commerciaux (module commercial).
 *
 * - Valider : seulement après le délai de sécurité (eligible_at). Une
 *   commission signalée (flags) exige que l'admin le reconnaisse avec une note.
 * - Rejeter ou annuler : motif obligatoire. Une commission payée n'est jamais
 *   modifiée : son annulation crée une contrepassation (montant négatif,
 *   validée) déduite du versement suivant.
 * - Versement : demandé (admin ou commercial lui-même), validé ou refusé par
 *   l'admin, puis marqué payé avec la référence du virement fait par l'admin
 *   (aucun virement automatique). Les commissions du versement sont
 *   « réservées » : elles ne peuvent pas être payées deux fois.
 * - Un seul versement en cours par commercial (fiche du commercial = verrou).
 */
const admin = require("firebase-admin");
const {COLLECTIONS, AcquisitionError, assertTransition, reversalId, toDate,
  CURRENCY} = require("./model");
const {audit} = require("./store");
const {requireAdmin} = require("./agents");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const MAX_ITEMS = 200; // commissions par versement (limite des transactions)
const OPEN_PAYOUT = ["requested", "approved"];

/** Valider, rejeter ou annuler une commission (admin). */
async function reviewCommission({db, uid, data, clock = () => new Date()}) {
  const adminUid = await requireAdmin(db, uid);
  const id = text(data.commissionId, 200);
  const decision = text(data.decision, 20);
  const reason = text(data.reason, 300);
  const ref = db.doc(`${COLLECTIONS.commissions}/${id}`);
  if (!["approve", "reject", "reverse"].includes(decision)) {
    throw new AcquisitionError("invalid-argument", "Décision inconnue.");
  }
  if (decision !== "approve" && !reason) {
    throw new AcquisitionError("invalid-argument", "Indiquez le motif.");
  }
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new AcquisitionError("not-found", "Commission introuvable.");
    }
    const c = snap.data();
    const log = (action, details = {}) => audit(tx, db, {actorUid: adminUid,
      actorRole: "Admin", action, target: ref.path,
      details: {from: c.status, reason, ...details}});

    if (decision === "approve") {
      assertTransition("commission", c.status, "approved");
      const eligible = toDate(c.eligible_at);
      if (eligible && clock() < eligible) {
        throw new AcquisitionError("failed-precondition",
            "Le délai de sécurité de cette commission n'est pas terminé.");
      }
      const flags = c.flags || [];
      if (flags.length && (data.acknowledgeFlags !== true || !reason)) {
        throw new AcquisitionError("failed-precondition",
            "Commission signalée : confirmez l'avoir vérifiée et ajoutez une note.");
      }
      tx.update(ref, {status: "approved", approved_by: adminUid,
        approved_at: ts(), review_note: reason || null,
        status_updated_at: ts()});
      log("commission.approved", {flags});
      return {status: "approved"};
    }
    if (decision === "reject") {
      assertTransition("commission", c.status, "rejected");
      tx.update(ref, {status: "rejected", status_reason: reason,
        rejected_by: adminUid, status_updated_at: ts()});
      log("commission.rejected");
      return {status: "rejected"};
    }
    // Annulation (remboursement, fraude découverte…).
    if (c.status === "paid") {
      if (c.type === "reversal") {
        throw new AcquisitionError("failed-precondition",
            "Une contrepassation ne s'annule pas.");
      }
      const revRef = db.doc(`${COLLECTIONS.commissions}/${reversalId(id)}`);
      if ((await tx.get(revRef)).exists) {
        throw new AcquisitionError("already-exists",
            "Cette commission a déjà été contrepassée.");
      }
      tx.create(revRef, {
        type: "reversal", agent_uid: c.agent_uid, client_uid: c.client_uid,
        campaign_id: c.campaign_id, assignment_id: c.assignment_id,
        rule_id: c.rule_id, amount: -c.amount, currency: c.currency || CURRENCY,
        source_ref: ref.path, status: "approved", status_reason: reason,
        flags: [], eligible_at: null, payout_id: null,
        approved_by: adminUid, approved_at: ts(), created_at: ts(),
      });
      tx.update(ref, {reversed_by: revRef.id, reversal_reason: reason});
      log("commission.reversal", {reversal: revRef.id, amount: -c.amount});
      return {status: "paid", reversal: revRef.id};
    }
    if (c.status === "reserved") {
      throw new AcquisitionError("failed-precondition",
          "Commission dans un versement en cours : refusez d'abord le versement.");
    }
    assertTransition("commission", c.status, "reversed");
    tx.update(ref, {status: "reversed", status_reason: reason,
      status_updated_at: ts()});
    log("commission.reversed");
    return {status: "reversed"};
  });
}

/**
 * Demande de versement des commissions validées d'un commercial. Appelant :
 * un admin (data.agentUid) ou le commercial lui-même.
 */
async function requestPayout({db, uid, data}) {
  if (!uid) throw new AcquisitionError("unauthenticated", "Connexion requise.");
  const caller = await db.doc(`User/${uid}`).get();
  const role = caller.exists ? caller.get("role") : null;
  let agentUid;
  if (role === "Admin") {
    agentUid = text(data.agentUid, 128);
  } else if (role === "Commercial") {
    agentUid = uid;
  } else {
    throw new AcquisitionError("permission-denied", "Action non autorisée.");
  }
  if (!agentUid) {
    throw new AcquisitionError("invalid-argument", "Commercial manquant.");
  }
  const agentRef = db.doc(`${COLLECTIONS.agents}/${agentUid}`);
  const payoutRef = db.collection(COLLECTIONS.payouts).doc();

  return db.runTransaction(async (tx) => {
    const [agent, open, approved] = await Promise.all([
      tx.get(agentRef),
      tx.get(db.collection(COLLECTIONS.payouts)
          .where("agent_uid", "==", agentUid)
          .where("status", "in", OPEN_PAYOUT).limit(1)),
      tx.get(db.collection(COLLECTIONS.commissions)
          .where("agent_uid", "==", agentUid)
          .where("status", "==", "approved").limit(MAX_ITEMS)),
    ]);
    if (!agent.exists) {
      throw new AcquisitionError("not-found", "Commercial introuvable.");
    }
    if (!open.empty) {
      throw new AcquisitionError("failed-precondition",
          "Un versement est déjà en cours pour ce commercial.");
    }
    const method = agent.get("payout_method");
    if (!method) {
      throw new AcquisitionError("failed-precondition",
          "Renseignez d'abord le moyen de paiement du commercial.");
    }
    const items = approved.docs;
    const total = items.reduce((s, d) => s + (d.get("amount") || 0), 0);
    if (items.length === 0 || total <= 0) {
      throw new AcquisitionError("failed-precondition",
          "Aucun montant validé à verser.");
    }
    tx.update(agentRef, {payout_version:
      admin.firestore.FieldValue.increment(1)}); // verrou
    tx.create(payoutRef, {agent_uid: agentUid, amount: total,
      currency: CURRENCY, method, status: "requested",
      items_count: items.length, requested_by: uid, requested_at: ts(),
      external_reference: null});
    for (const d of items) {
      tx.update(d.ref, {status: "reserved", payout_id: payoutRef.id,
        status_updated_at: ts()});
      tx.create(payoutRef.collection(COLLECTIONS.payoutItems).doc(d.id), {
        agent_uid: agentUid, commission_id: d.id, amount: d.get("amount")});
    }
    audit(tx, db, {actorUid: uid, actorRole: role, action: "payout.requested",
      target: payoutRef.path, details: {amount: total, items: items.length}});
    return {payoutId: payoutRef.id, amount: total, items: items.length};
  });
}

/** Valider, refuser ou marquer payé un versement (admin). */
async function decidePayout({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`${COLLECTIONS.payouts}/${text(data.payoutId, 128)}`);
  const decision = text(data.decision, 20);
  const reason = text(data.reason, 300);
  const reference = text(data.externalReference, 120);
  const to = {approve: "approved", reject: "rejected", paid: "paid"}[decision];
  if (!to) throw new AcquisitionError("invalid-argument", "Décision inconnue.");
  if (to === "rejected" && !reason) {
    throw new AcquisitionError("invalid-argument", "Indiquez le motif du refus.");
  }
  if (to === "paid" && !reference) {
    throw new AcquisitionError("invalid-argument",
        "Indiquez la référence du virement effectué.");
  }
  return db.runTransaction(async (tx) => {
    const payout = await tx.get(ref);
    if (!payout.exists) {
      throw new AcquisitionError("not-found", "Versement introuvable.");
    }
    const from = payout.get("status");
    assertTransition("payout", from, to);
    const items = to === "approved" ? null :
      await tx.get(ref.collection(COLLECTIONS.payoutItems));
    tx.update(ref, {status: to, status_reason: reason || null,
      decided_by: adminUid, status_updated_at: ts(),
      ...(to === "paid" ? {external_reference: reference, paid_at: ts()} : {})});
    if (items) {
      for (const item of items.docs) {
        const cRef = db.doc(`${COLLECTIONS.commissions}/${item.id}`);
        tx.update(cRef, to === "paid" ?
          {status: "paid", paid_at: ts(), status_updated_at: ts()} :
          {status: "approved", payout_id: null, status_updated_at: ts()});
      }
    }
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: `payout.${to}`, target: ref.path,
      details: {from, reason, reference: reference || null}});
    return {status: to};
  });
}

module.exports = {reviewCommission, requestPayout, decidePayout, MAX_ITEMS};
