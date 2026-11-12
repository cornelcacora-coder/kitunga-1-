/**
 * Espace professionnel du vendeur.
 *
 * - Actions sur une commande, vérifiées par le serveur et historisées
 *   (auteur = commerce) : accepter (avec temps de préparation), refuser
 *   (motif obligatoire ; remboursement si payée), marquer prête, confirmer
 *   la remise au livreur.
 * - Ouvert / fermé maintenant (sans toucher aux horaires) : un commerce
 *   fermé momentanément ne prend plus de commande.
 * - Performances : ventes par jour et par semaine, panier moyen, temps de
 *   préparation, taux de refus, meilleurs produits, stocks bas.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const err = (code, message) => new AcquisitionError(code, message);
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const DAY = 86400000;
const LOW_STOCK = 5;

async function seller(db, uid) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || u.get("role") !== "Seller") {
    throw err("permission-denied", "Réservé aux commerces.");
  }
  return u;
}

/**
 * action : accept (prepMinutes facultatif), refuse (reason), ready,
 * handover (le livreur a bien récupéré la commande).
 */
async function sellerOrderAction({db, uid, data}) {
  await seller(db, uid);
  const action = text(data.action, 20);
  const ref = db.doc(`Orders/${text(data.orderId, 128) || "_"}`);
  return db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    if (!o.exists || !o.get("seller_ref") || o.get("seller_ref").id !== uid) {
      throw err("not-found", "Commande introuvable.");
    }
    const status = o.get("status") || "";
    const actor = {status_actor: {uid, role: "Seller", at: Date.now()},
      status_updated_at: ts()};
    if (action === "accept") {
      if (!["", "En attente"].includes(status)) {
        throw err("failed-precondition", "Cette commande est déjà traitée.");
      }
      const prep = Math.round(Number(data.prepMinutes) || 0);
      tx.update(ref, {status: "En préparation", accepted_at: ts(),
        ...(prep >= 5 && prep <= 240 ? {prep_minutes: prep} : {}),
        ...actor, status_reason: null});
      return {status: "En préparation"};
    }
    if (action === "refuse") {
      if (!["", "En attente", "En préparation"].includes(status)) {
        throw err("failed-precondition",
            "Une commande prête ou en livraison ne peut plus être refusée : " +
            "contactez le support.");
      }
      const reason = text(data.reason, 300);
      if (!reason) throw err("invalid-argument", "Indiquez le motif du refus.");
      tx.update(ref, {status: "Refusée", refusal_reason: reason,
        ...(o.get("payment_status") === "Réussi" ? {refund_needed: true} : {}),
        ...actor, status_reason: reason});
      return {status: "Refusée"};
    }
    if (action === "ready") {
      if (status !== "En préparation") {
        throw err("failed-precondition",
            "Acceptez d'abord la commande avant de la déclarer prête.");
      }
      tx.update(ref, {status: "Pret", ...actor, status_reason: null});
      return {status: "Pret"};
    }
    if (action === "handover") {
      if (status !== "encours") {
        throw err("failed-precondition",
            "Aucun livreur n'a encore pris cette commande.");
      }
      tx.update(ref, {handover_confirmed_at: ts(),
        ...(o.get("picked_up_at") ? {} : {picked_up_at: ts()})});
      return {status};
    }
    throw err("invalid-argument", "Action inconnue.");
  });
}

/** Ouvert / fermé maintenant (fermeture momentanée). */
async function sellerSetOpen({db, uid, data}) {
  const u = await seller(db, uid);
  const closed = data.open === false;
  await u.ref.update({shop_closed_now: closed,
    shop_closed_since: closed ? ts() : null});
  return {open: !closed};
}

/** Performances du commerce (données réelles). */
async function sellerPerformance({db, uid, now = new Date()}) {
  const u = await seller(db, uid);
  const [orders, products, ledger] = await Promise.all([
    db.collection("Orders").where("seller_ref", "==", u.ref).get(),
    db.collection("Product").where("seller_ref", "==", u.ref).get(),
    db.collection("Ledger").where("account_uid", "==", uid).get(),
  ]);
  // Jours à l'heure de Brazzaville (UTC+1).
  const day = (d) => new Date(d.getTime() + 3600000).toISOString()
      .slice(0, 10);
  const days = Array.from({length: 7}, (_, i) =>
    day(new Date(now.getTime() - (6 - i) * DAY)));
  const byDay = Object.fromEntries(days.map((d) => [d, 0]));
  let delivered = 0;
  let refused = 0;
  let total = 0;
  const preps = [];
  const doneIds = [];
  for (const o of orders.docs) {
    const s = o.get("status");
    const fees = Number(o.get("delivery_fees")) || 0;
    const items = Math.max(0, (Number(o.get("total_amount")) || 0) - fees);
    if (["Livrer", "Reçu"].includes(s)) {
      delivered++;
      total += items;
      doneIds.push(o.id);
      const at = toDate(o.get("delivered_at")) || toDate(o.get("created_at"));
      if (at && day(at) in byDay) byDay[day(at)] += items;
    } else if (s === "Refusée") {
      refused++;
    }
    const a = toDate(o.get("accepted_at"));
    const r = toDate(o.get("ready_at"));
    if (a && r && r > a) preps.push((r - a) / 60000);
  }
  // Meilleurs produits : articles des commandes livrées.
  const counts = {};
  for (let i = 0; i < doneIds.length; i += 10) {
    const chunk = doneIds.slice(i, i + 10);
    const refs = (await Promise.all(chunk.map((id) =>
      db.doc(`Orders/${id}`).get())))
        .map((o) => o.get("order_unique_reference")).filter(Boolean);
    if (refs.length === 0) continue;
    const items = await db.collection("OrderItems")
        .where("order_ref", "in", refs).get();
    for (const it of items.docs) {
      const name = it.get("item_name") || it.get("name") || "";
      if (!name) continue;
      counts[name] = (counts[name] || 0) + (Number(it.get("quantity")) || 1);
    }
  }
  const lowStock = products.docs.filter((p) => p.get("on_sale") !== false &&
    (Number(p.get("quantity")) || 0) <= LOW_STOCK)
      .map((p) => ({id: p.id, name: p.get("name") || "",
        quantity: Number(p.get("quantity")) || 0}))
      .sort((a, b) => a.quantity - b.quantity).slice(0, 20);
  const finished = delivered + refused;
  const month = new Date(now.getTime() + 3600000).toISOString().slice(0, 7);
  return {
    delivered, refused,
    refusalRate: finished ? Math.round(refused * 100 / finished) : null,
    revenue: total,
    averageBasket: delivered ? Math.round(total / delivered) : null,
    averagePrepMinutes: preps.length ? Math.round(preps.reduce((x, y) =>
      x + y, 0) / preps.length) : null,
    salesByDay: days.map((d) => ({day: d, amount: byDay[d]})),
    monthEarnings: ledger.docs.filter((e) => e.get("type") !== "payout" &&
      toDate(e.get("at")) && new Date(toDate(e.get("at")).getTime() +
        3600000).toISOString().slice(0, 7) === month)
        .reduce((x, e) => x + (Number(e.get("amount")) || 0), 0),
    topProducts: Object.entries(counts).sort((a, b) => b[1] - a[1])
        .slice(0, 5).map(([name, quantity]) => ({name, quantity})),
    lowStock,
  };
}

module.exports = {sellerOrderAction, sellerSetOpen, sellerPerformance,
  LOW_STOCK};
