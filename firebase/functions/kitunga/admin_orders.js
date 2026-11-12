/**
 * Actions de l'administrateur sur les commandes : annuler (motif
 * obligatoire, remboursement demandé si la commande était payée), attribuer
 * ou changer le livreur, marquer livrée, et clôturer en lot les anciennes
 * commandes jamais confirmées. Mêmes champs que l'application (statuts
 * existants, status_updated_at, refund_needed, deliver_reference…), plus le
 * motif et l'auteur de l'action. Chaque action est journalisée (audit_logs).
 */
const admin = require("firebase-admin");
const {AcquisitionError} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {audit} = require("./acquisition/store");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const err = (code, message) => new AcquisitionError(code, message);

// Statuts stockés (lib/backend/order_status.dart).
const S = {
  pending: "En attente",
  preparing: "En préparation",
  ready: "Pret",
  delivering: "encours",
  delivered: "Livrer",
  received: "Reçu",
  notReceived: "Non Reçu",
  refused: "Refusée",
  cancelled: "Annulée",
};
const IN_PROGRESS = ["", S.pending, S.preparing, S.ready, S.delivering];
const NOT_CONFIRMED = ["", S.pending];

/** Une commande payée doit être remboursée si elle est annulée. */
const refundFields = (order) =>
  order.get("payment_status") === "Réussi" ? {refund_needed: true} : {};

/** Action sur une commande : cancel, assign, deliver. */
async function adminOrderAction({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const action = text(data.action, 20);
  const ref = db.doc(`Orders/${text(data.orderId, 128) || "_"}`);
  const reason = text(data.reason, 300);

  let deliverer = null;
  if (action === "assign") {
    deliverer = await db.doc(`User/${text(data.delivererUid, 128) || "_"}`)
        .get();
    if (!deliverer.exists || deliverer.get("role") !== "Deliver") {
      throw err("invalid-argument", "Livreur introuvable.");
    }
    if (deliverer.get("account_status") === "suspended") {
      throw err("failed-precondition", "Ce livreur est suspendu.");
    }
  } else if (action === "cancel") {
    if (!reason) throw err("invalid-argument", "Indiquez le motif.");
  } else if (action !== "deliver") {
    throw err("invalid-argument", "Action inconnue.");
  }

  return db.runTransaction(async (tx) => {
    const order = await tx.get(ref);
    if (!order.exists) throw err("not-found", "Commande introuvable.");
    const status = order.get("status") || "";
    let changes;
    if (action === "cancel") {
      if (!IN_PROGRESS.includes(status)) {
        throw err("failed-precondition",
            "Cette commande est déjà terminée : elle ne peut plus être annulée.");
      }
      changes = {status: S.cancelled, cancel_reason: reason,
        cancelled_by: "admin", ...refundFields(order)};
    } else if (action === "assign") {
      if (![S.ready, S.delivering].includes(status)) {
        throw err("failed-precondition",
            "Un livreur s'attribue à une commande prête ou en livraison.");
      }
      // Comme l'acceptation par le livreur dans l'application.
      changes = {status: S.delivering, deliverer_ref: deliverer.id,
        deliver_reference: deliverer.ref};
    } else {
      if (status !== S.delivering) {
        throw err("failed-precondition",
            "Seule une commande en livraison peut être marquée livrée.");
      }
      changes = {status: S.delivered, delivered_at: ts()};
    }
    tx.update(ref, {...changes, status_updated_at: ts(),
      admin_updated_by: adminUid,
      // Historique : l'admin est l'auteur du changement.
      status_actor: {uid: adminUid, role: "Admin", at: Date.now()},
      status_reason: reason || null});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: `order.${action}`, target: ref.path,
      details: {from: status, to: changes.status,
        ...(reason ? {reason} : {}),
        ...(deliverer ? {deliverer: deliverer.id} : {}),
        refund: changes.refund_needed === true}});
    return {status: changes.status, refundNeeded: changes.refund_needed === true};
  });
}

/**
 * Clôture en lot : annule les commandes jamais confirmées plus anciennes que
 * [days] jours (ex. commandes de test), avec un motif commun.
 */
async function closeStaleOrders({db, uid, data, clock = () => new Date()}) {
  const adminUid = await requireAdmin(db, uid);
  const days = data.days;
  const reason = text(data.reason, 300);
  if (!Number.isSafeInteger(days) || days < 1 || days > 365) {
    throw err("invalid-argument", "Ancienneté invalide : entre 1 et 365 jours.");
  }
  if (!reason) throw err("invalid-argument", "Indiquez le motif.");
  const before = new Date(clock().getTime() - days * 86400000);
  const snap = await db.collection("Orders")
      .where("status", "in", NOT_CONFIRMED).limit(1000).get();
  const stale = snap.docs.filter((d) => {
    const c = d.get("created_at");
    const at = c && typeof c.toDate === "function" ? c.toDate() : c;
    return at instanceof Date && at < before;
  });
  let refunds = 0;
  for (let i = 0; i < stale.length; i += 400) {
    const batch = db.batch();
    for (const d of stale.slice(i, i + 400)) {
      const refund = refundFields(d);
      if (refund.refund_needed) refunds++;
      batch.update(d.ref, {status: S.cancelled, cancel_reason: reason,
        cancelled_by: "admin", status_updated_at: ts(),
        admin_updated_by: adminUid, ...refund});
    }
    await batch.commit();
  }
  await db.runTransaction(async (tx) => audit(tx, db, {actorUid: adminUid,
    actorRole: "Admin", action: "order.close_stale", target: "Orders",
    details: {days, reason, count: stale.length, refunds}}));
  return {closed: stale.length, refunds};
}

module.exports = {adminOrderAction, closeStaleOrders};
