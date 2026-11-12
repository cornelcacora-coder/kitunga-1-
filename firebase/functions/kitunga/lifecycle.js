/**
 * Cycle de vie d'une commande : trois statuts distincts et un historique.
 *
 * - `status` (inchangé, valeurs historiques utilisées par l'application) :
 *   statut de la commande.
 * - `delivery_status` (calculé par le serveur) : searching, offered,
 *   to_pickup, to_customer, arrived, delivered, disputed, failed, cancelled.
 * - `finance_status` (calculé par le serveur) : unpaid, paid,
 *   refund_pending, refunded, refund_manual, settled.
 *
 * Chaque changement de l'un de ces statuts est enregistré dans
 * Orders/{id}/history : avant, après, quand, et qui (rôle déduit si la
 * modification vient de l'application).
 *
 * Les positions GPS des courses terminées sont effacées après 24 h ; la
 * trace utile aux litiges reste sur la commande (prise, récupération,
 * arrivée, remise, photo).
 */
const admin = require("firebase-admin");
const {toDate} = require("./acquisition/model");

const ts = () => admin.firestore.FieldValue.serverTimestamp();

/** Qui fait passer la commande à ce statut, quand l'application l'écrit. */
const ACTOR_OF_STATUS = {
  "En préparation": "Seller",
  "Pret": "Seller",
  "Refusée": "Seller",
  "encours": "Deliver",
  "Livrer": "Deliver",
  "Reçu": "User",
  "Non Reçu": "User",
  "Annulée": "User",
};

/** Statut de livraison déduit de la commande. */
function deliveryStatusOf(o) {
  const s = o.status || "";
  if (s === "Refusée" || s === "Annulée") return "cancelled";
  if (s === "Livrer" || s === "Reçu") return "delivered";
  if (s === "Non Reçu") return "disputed";
  if (s === "encours") {
    if (o.delivery_issue && o.delivery_issue.type === "failed") return "failed";
    if (o.arrived_at) return "arrived";
    if (o.picked_up_at) return "to_customer";
    return "to_pickup";
  }
  if (s === "Pret") {
    const until = toDate(o.offer_expires_at);
    return o.offer_to && until && until > new Date() ? "offered" : "searching";
  }
  return "not_ready";
}

/** Statut financier déduit de la commande. */
function financeStatusOf(o) {
  if (o.refund_status === "Envoyé") return "refunded";
  if (o.refund_status === "À traiter manuellement" ||
    o.refund_status === "Échec") return "refund_manual";
  if (o.refund_needed) return "refund_pending";
  if (o.settled_at) return "settled";
  return o.payment_status === "Réussi" ? "paid" : "unpaid";
}

/**
 * Déclencheur sur chaque écriture d'une commande : met à jour les statuts
 * calculés et l'historique. Sans effet quand rien ne change (la mise à jour
 * qu'il fait lui-même ne relance donc pas de boucle).
 */
async function onOrderLifecycle({before, after}) {
  if (!after || !after.exists) return {changed: false};
  const o = after.data();
  const prev = before && before.exists ? before.data() : null;
  const next = {
    delivery_status: deliveryStatusOf(o),
    finance_status: financeStatusOf(o),
  };
  const entries = [];
  // Auteur écrit par le serveur avec ce changement ; sinon (écriture de
  // l'application, ou auteur resté d'un changement précédent) : rôle déduit.
  const fresh = (v) => JSON.stringify(v || null) !==
    JSON.stringify(prev && prev.status_actor || null);
  const actor = o.status_actor && fresh(o.status_actor) ? o.status_actor : null;
  const reason = actor ? o.status_reason || null : null;
  if (!prev || prev.status !== o.status) {
    entries.push({field: "status", from: prev ? prev.status || "" : null,
      to: o.status || "",
      by_uid: actor && actor.uid || null,
      by_role: actor && actor.role || ACTOR_OF_STATUS[o.status] ||
        (prev ? "?" : "System")});
  }
  for (const f of ["delivery_status", "finance_status"]) {
    if (o[f] !== next[f]) {
      entries.push({field: f, from: o[f] || null, to: next[f],
        by_uid: null, by_role: "System"});
    }
  }
  if (entries.length === 0) return {changed: false};
  const batch = after.ref.firestore.batch();
  for (const e of entries) {
    batch.set(after.ref.collection("history").doc(),
        {...e, at: ts(), reason: e.field === "status" ? reason : null});
  }
  const changes = {};
  if (o.delivery_status !== next.delivery_status) {
    changes.delivery_status = next.delivery_status;
  }
  if (o.finance_status !== next.finance_status) {
    changes.finance_status = next.finance_status;
  }
  if (Object.keys(changes).length) batch.update(after.ref, changes);
  await batch.commit();
  return {changed: true, entries: entries.length};
}

/** Historique d'une commande (admin, support, ou acteur de la commande). */
async function orderHistoryFor({db, uid, data}) {
  const {AcquisitionError} = require("./acquisition/model");
  const err = (c, m) => new AcquisitionError(c, m);
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const id = String(data.orderId || "").slice(0, 128);
  const o = id ? await db.doc(`Orders/${id}`).get() : null;
  if (!o || !o.exists) throw err("not-found", "Commande introuvable.");
  const ids = [o.get("user_ref") && o.get("user_ref").id,
    o.get("seller_ref") && o.get("seller_ref").id,
    (o.get("deliver_reference") && o.get("deliver_reference").id) ||
      o.get("deliverer_ref")];
  if (!ids.includes(uid)) {
    const me = await db.doc(`User/${uid}`).get();
    if (!me.exists || !["Admin", "Support"].includes(me.get("role"))) {
      throw err("not-found", "Commande introuvable.");
    }
  }
  return {history: await orderHistory({db, orderId: o.id}),
    deliveryStatus: o.get("delivery_status") || "",
    financeStatus: o.get("finance_status") || ""};
}

async function orderHistory({db, orderId}) {
  const snap = await db.collection(`Orders/${orderId}/history`).get();
  return snap.docs.map((d) => {
    const h = d.data();
    const at = toDate(h.at);
    return {field: h.field, from: h.from, to: h.to, byRole: h.by_role,
      byUid: h.by_uid, reason: h.reason || "",
      at: at ? at.toISOString() : null};
  }).sort((a, b) => String(a.at).localeCompare(String(b.at)));
}

/** Efface les positions des courses terminées depuis plus de 24 h. */
async function purgeOldPositions({db, now = new Date()}) {
  const limit = now.getTime() - 24 * 3600 * 1000;
  const snap = await db.collection("DeliveryTracking").get();
  let removed = 0;
  for (const t of snap.docs) {
    const at = toDate(t.get("at"));
    if (at && at.getTime() > limit) continue;
    const o = await db.doc(`Orders/${t.id}`).get();
    if (o.exists && o.get("status") === "encours") continue;
    await t.ref.delete();
    removed++;
  }
  return {removed};
}

module.exports = {deliveryStatusOf, financeStatusOf, onOrderLifecycle,
  orderHistory, orderHistoryFor, purgeOldPositions, ACTOR_OF_STATUS};
