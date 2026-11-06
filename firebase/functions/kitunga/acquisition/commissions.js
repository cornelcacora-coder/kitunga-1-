/**
 * Génération des commissions (module commercial).
 *
 * Premier abonnement : déclenché quand un paiement d'abonnement passe à
 * « Réussi ». Ce statut n'est écrit que par le serveur, après vérification du
 * paiement auprès de MTN (subscriptions.confirmSubscription) ; les règles
 * Firestore interdisent aux applications de créer un paiement d'abonnement.
 *
 * Activation : quand l'attribution est confirmée ET que l'activation de la
 * même installation est attestée (App Check), dans n'importe quel ordre.
 *
 * Garanties :
 * - Une commission par type et par client (identifiant fixe, création unique) :
 *   notifications répétées ou simultanées sans effet.
 * - Montant recopié du barème de la campagne au moment de la génération : un
 *   nouveau barème ne change jamais une commission existante.
 * - Toujours « pending » (ou « rejected ») à la création : la validation est
 *   une décision de l'admin, après le délai de sécurité (eligible_at).
 * - Aucune commission pour un paiement en attente, refusé, gratuit, hors
 *   formule éligible, hors délai, ou qui n'est pas le premier abonnement.
 */
const admin = require("firebase-admin");
const {COLLECTIONS, CURRENCY, commissionId, eventEligible, holdUntil,
  identityKey, toDate} = require("./model");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const PAYER_KEYS = "commission_payer_keys";

/** Campagne, barème, affectation et commercial d'une attribution. */
async function loadContext(tx, db, attribution) {
  const [campaign, assignment, agent] = await Promise.all([
    tx.get(db.doc(`${COLLECTIONS.campaigns}/${attribution.campaign_id}`)),
    tx.get(db.doc(`${COLLECTIONS.assignments}/${attribution.assignment_id}`)),
    tx.get(db.doc(`${COLLECTIONS.agents}/${attribution.agent_uid}`)),
  ]);
  if (!campaign.exists || !assignment.exists) return null;
  const rule = await tx.get(
      db.doc(`${COLLECTIONS.rules}/${campaign.get("rule_id")}`));
  if (!rule.exists) return null;
  return {campaign, assignment, agent, rule};
}

/** Signalements pour l'admin (la commission reste en attente). */
function baseFlags({agent, assignment}) {
  const flags = [];
  if (!agent.exists || agent.get("status") !== "active") {
    flags.push("agent_not_active");
  }
  if (assignment.get("status") === "cancelled") {
    flags.push("assignment_cancelled");
  }
  return flags;
}

function skipped(tx, db, attribution, clientUid, type, reason) {
  tx.create(db.collection(COLLECTIONS.events).doc(), {
    type: "commission_skipped", commission_type: type, reason,
    client_uid: clientUid, agent_uid: attribution.agent_uid,
    campaign_id: attribution.campaign_id, created_at: ts(),
  });
  return {created: false, reason};
}

function commissionDoc({type, clientUid, attribution, ctx, amount, sourceRef,
  status, reason, flags, now, extra = {}}) {
  return {
    type,
    agent_uid: attribution.agent_uid,
    client_uid: clientUid,
    campaign_id: attribution.campaign_id,
    assignment_id: attribution.assignment_id,
    rule_id: ctx.rule.id,
    amount,
    currency: CURRENCY,
    source_ref: sourceRef,
    status,
    status_reason: reason || null,
    flags,
    eligible_at: holdUntil(now, ctx.campaign.get("hold_days") ?? 7),
    payout_id: null,
    created_at: ts(),
    ...extra,
  };
}

function auditCreate(tx, db, ref, details) {
  tx.create(db.collection(COLLECTIONS.audit).doc(), {
    actor_uid: null, actor_role: "system", action: "commission.create",
    target: ref.path, details, created_at: ts(),
  });
}

/**
 * Paiement modifié : génère la commission « premier abonnement » si le
 * paiement vient de passer à « Réussi » et que tout est vérifié.
 */
async function processSubscriptionPayment({db, paymentId, before, after,
  identitySecret, clock = () => new Date()}) {
  if (!after || after.kind !== "subscription") return {created: false};
  if (after.status !== "Réussi" || (before && before.status === "Réussi")) {
    return {created: false};
  }
  if (!Number.isSafeInteger(after.amount) || after.amount <= 0) {
    return {created: false, reason: "free"};
  }
  const userRef = after.user_ref;
  if (!userRef || !userRef.id) return {created: false};
  const clientUid = userRef.id;
  const now = clock();
  const ref = db.doc(`${COLLECTIONS.commissions}/` +
    commissionId("first_subscription", clientUid));
  const attributionRef = db.doc(`${COLLECTIONS.attributions}/${clientUid}`);
  const payerKey = identityKey(after.payer_phone, identitySecret);
  const payerRef = payerKey ? db.doc(`${PAYER_KEYS}/${payerKey}`) : null;

  return db.runTransaction(async (tx) => {
    const [existing, attributionDoc, earlier, payerDoc] = await Promise.all([
      tx.get(ref),
      tx.get(attributionRef),
      tx.get(db.collection("Paiement").where("user_ref", "==", userRef)
          .where("kind", "==", "subscription")
          .where("status", "==", "Réussi")),
      payerRef ? tx.get(payerRef) : Promise.resolve(null),
    ]);
    if (existing.exists) return {created: false, reason: "already_exists"};
    if (!attributionDoc.exists ||
      attributionDoc.get("status") !== "confirmed") {
      return {created: false, reason: "no_attribution"};
    }
    const attribution = attributionDoc.data();
    const ctx = await loadContext(tx, db, attribution);
    if (!ctx) {
      return skipped(tx, db, attribution, clientUid, "first_subscription",
          "campaign_missing");
    }
    // Premier abonnement payé seulement (celui-ci compris).
    const others = earlier.docs.filter((d) => d.id !== paymentId);
    if (others.length > 0) {
      return skipped(tx, db, attribution, clientUid, "first_subscription",
          "not_first_subscription");
    }
    if (!(ctx.rule.get("eligible_plans") || []).includes(after.plan)) {
      return skipped(tx, db, attribution, clientUid, "first_subscription",
          "plan_not_eligible");
    }
    const amount = ctx.rule.get("first_subscription_amount");
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      return skipped(tx, db, attribution, clientUid, "first_subscription",
          "no_amount");
    }
    if (!eventEligible({touchAt: attribution.touched_at,
      assignmentStart: ctx.assignment.get("starts_at"),
      assignmentEnd: ctx.assignment.get("ends_at"), eventAt: now,
      graceDays: ctx.campaign.get("grace_days") ?? 30})) {
      return skipped(tx, db, attribution, clientUid, "first_subscription",
          "out_of_window");
    }

    const flags = baseFlags(ctx);
    let status = "pending";
    let reason = null;
    if (payerKey && ctx.agent.exists &&
      ctx.agent.get("identity_key") === payerKey) {
      status = "rejected";
      reason = "payer_is_agent";
    } else if (payerDoc && payerDoc.exists &&
      (payerDoc.get("clients") || []).some((u) => u !== clientUid)) {
      flags.push("shared_payer");
    }

    tx.create(ref, commissionDoc({type: "first_subscription", clientUid,
      attribution, ctx, amount, sourceRef: `Paiement/${paymentId}`, status,
      reason, flags, now, extra: {plan: after.plan, payer_key: payerKey}}));
    if (payerRef) {
      tx.set(payerRef, {clients:
        admin.firestore.FieldValue.arrayUnion(clientUid), updated_at: ts()},
      {merge: true});
    }
    tx.update(attributionRef, {"client_summary.subscribed": true});
    tx.create(db.collection(COLLECTIONS.events).doc(), {type: "subscription",
      client_uid: clientUid, agent_uid: attribution.agent_uid,
      campaign_id: attribution.campaign_id,
      assignment_id: attribution.assignment_id, plan: after.plan,
      amount: after.amount, created_at: ts()});
    auditCreate(tx, db, ref, {type: "first_subscription", amount, status,
      flags, payment: paymentId});
    return {created: true, status};
  });
}

/**
 * Commission d'activation d'un client : attribution confirmée + activation
 * vérifiée de l'installation d'inscription. Rejouable sans effet.
 */
async function tryActivationCommission({db, clientUid,
  clock = () => new Date()}) {
  const ref = db.doc(`${COLLECTIONS.commissions}/` +
    commissionId("activation", clientUid));
  const attributionRef = db.doc(`${COLLECTIONS.attributions}/${clientUid}`);
  const now = clock();
  return db.runTransaction(async (tx) => {
    const [existing, attributionDoc] =
      await Promise.all([tx.get(ref), tx.get(attributionRef)]);
    if (existing.exists) return {created: false, reason: "already_exists"};
    if (!attributionDoc.exists ||
      attributionDoc.get("status") !== "confirmed") {
      return {created: false, reason: "no_attribution"};
    }
    const attribution = attributionDoc.data();
    if (!attribution.installation_id) {
      return {created: false, reason: "no_installation"};
    }
    const activation = await tx.get(db.doc(
        `${COLLECTIONS.activations}/${attribution.installation_id}`));
    if (!activation.exists || activation.get("verified") !== true) {
      return {created: false, reason: "activation_not_verified"};
    }
    const ctx = await loadContext(tx, db, attribution);
    if (!ctx) return {created: false, reason: "campaign_missing"};
    const amount = ctx.rule.get("activation_amount");
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      return {created: false, reason: "no_amount"};
    }
    const touchAt = toDate(attribution.touched_at);
    const activatedAt = toDate(activation.get("activated_at")) || now;
    const eventAt = activatedAt > touchAt ? activatedAt : touchAt;
    if (!eventEligible({touchAt, eventAt,
      assignmentStart: ctx.assignment.get("starts_at"),
      assignmentEnd: ctx.assignment.get("ends_at"),
      graceDays: ctx.campaign.get("grace_days") ?? 30})) {
      return skipped(tx, db, attribution, clientUid, "activation",
          "out_of_window");
    }
    const flags = baseFlags(ctx);
    tx.create(ref, commissionDoc({type: "activation", clientUid, attribution,
      ctx, amount, status: "pending", flags, now,
      sourceRef: `${COLLECTIONS.activations}/${attribution.installation_id}`}));
    auditCreate(tx, db, ref, {type: "activation", amount, flags});
    return {created: true, status: "pending"};
  });
}

/** Activation devenue vérifiée : clients inscrits avec cette installation. */
async function activationCommissionsForInstallation({db, installation, clock}) {
  const attributions = await db.collection(COLLECTIONS.attributions)
      .where("installation_id", "==", installation).get();
  const results = [];
  for (const a of attributions.docs) {
    results.push(await tryActivationCommission({db, clientUid: a.id, clock}));
  }
  return results;
}

module.exports = {processSubscriptionPayment, tryActivationCommission,
  activationCommissionsForInstallation, PAYER_KEYS};
