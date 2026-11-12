/**
 * Finances : grand livre (Ledger), soldes, gains, versements.
 *
 * Règles (Settings/finance, modifiables par l'admin) :
 * - commission_rate : part de Kitunga sur le montant des articles
 *   (0 par défaut : aucune commission n'existait avant ce module) ;
 * - deliverer_share : part des frais de livraison reversée au livreur
 *   (1 par défaut : 100 %).
 *
 * Quand une commande payée est livrée, le serveur écrit une seule fois
 * (identifiants fixes, en transaction) :
 *   {id}_seller   + articles − commission          (commerce)
 *   {id}_deliverer + frais × part livreur           (livreur)
 *   {id}_kitunga  + commission + reste des frais    (Kitunga)
 * Une commande remboursée après coup reçoit les écritures inverses
 * ({id}_*_rev). Les versements de l'admin sont des écritures négatives
 * (payout_{requestId} : un double clic n'en crée qu'un). Le solde d'un
 * compte est la somme de ses écritures.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {notifyUsers} = require("./notifications");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const err = (code, message) => new AcquisitionError(code, message);
const SETTINGS = "Settings/finance";
const DEFAULTS = {commission_rate: 0, deliverer_share: 1};
const DELIVERED = ["Livrer", "Reçu"];
const round = (n) => Math.round(Number(n) || 0);
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};

async function loadSettings(db) {
  const s = await db.doc(SETTINGS).get();
  return {...DEFAULTS, ...(s.exists ? s.data() : {})};
}

const delivererOf = (o) => {
  const r = o.deliver_reference;
  return (r && r.id) || o.deliverer_ref || null;
};

/** Montants d'une commande selon les règles. */
function split(o, settings) {
  const fees = round(o.delivery_fees);
  const items = Math.max(0, round(o.total_amount) - fees);
  const commission = round(items * Number(settings.commission_rate));
  const toDeliverer = round(fees * Number(settings.deliverer_share));
  return {items, fees, commission, seller: items - commission,
    deliverer: toDeliverer, kitunga: commission + (fees - toDeliverer)};
}

/**
 * Déclencheur : règlement à la livraison, annulation si remboursée.
 * Sans effet si déjà fait (écritures à identifiant fixe).
 */
async function onOrderFinance({db, after}) {
  if (!after || !after.exists) return {done: false};
  const o = after.data();
  const ref = after.ref;
  const refunded = o.refund_status === "Envoyé";
  if (!o.settled_at && DELIVERED.includes(o.status) &&
      o.payment_status === "Réussi" && !o.refund_needed) {
    const settings = await loadSettings(db);
    const s = split(o, settings);
    const sellerId = o.seller_ref && o.seller_ref.id;
    const deliverer = delivererOf(o);
    const reference = o.order_unique_reference || after.id;
    const done = await db.runTransaction(async (tx) => {
      const cur = await tx.get(ref);
      if (cur.get("settled_at")) return false;
      const base = {order_id: after.id, order_ref: reference, at: ts()};
      if (sellerId) {
        tx.set(db.doc(`Ledger/${after.id}_seller`), {...base,
          account_uid: sellerId, account_role: "Seller", type: "sale",
          amount: s.seller, label: `Vente ${reference}` +
            (s.commission ? ` (commission ${s.commission} F)` : "")});
      }
      if (deliverer && s.deliverer) {
        tx.set(db.doc(`Ledger/${after.id}_deliverer`), {...base,
          account_uid: deliverer, account_role: "Deliver", type: "delivery",
          amount: s.deliverer, label: `Livraison ${reference}`});
      }
      if (s.kitunga) {
        tx.set(db.doc(`Ledger/${after.id}_kitunga`), {...base,
          account_uid: "kitunga", account_role: "Kitunga",
          type: "commission", amount: s.kitunga,
          label: `Commission ${reference}`});
      }
      tx.update(ref, {settled_at: ts(), settlement: {...s,
        commission_rate: Number(settings.commission_rate),
        deliverer_share: Number(settings.deliverer_share)}});
      return true;
    });
    return {done, kind: "settled"};
  }
  if (o.settled_at && refunded && !o.settlement_reversed_at) {
    const done = await db.runTransaction(async (tx) => {
      const cur = await tx.get(ref);
      if (cur.get("settlement_reversed_at")) return false;
      const parts = ["seller", "deliverer", "kitunga"];
      const docs = await Promise.all(parts.map((p) =>
        tx.get(db.doc(`Ledger/${after.id}_${p}`))));
      docs.forEach((d, i) => {
        if (!d.exists) return;
        tx.set(db.doc(`Ledger/${after.id}_${parts[i]}_rev`), {
          ...d.data(), amount: -Number(d.get("amount")),
          type: "reversal", label: `Annulation : ${d.get("label")}`,
          at: ts()});
      });
      tx.update(ref, {settlement_reversed_at: ts()});
      return true;
    });
    return {done, kind: "reversed"};
  }
  return {done: false};
}

async function entriesOf(db, uid) {
  const snap = await db.collection("Ledger")
      .where("account_uid", "==", uid).get();
  return snap.docs.map((d) => ({id: d.id, type: d.get("type"),
    amount: Number(d.get("amount")) || 0, label: d.get("label") || "",
    orderId: d.get("order_id") || null, method: d.get("method") || "",
    at: iso(d.get("at"))}))
      .sort((a, b) => String(b.at).localeCompare(String(a.at)));
}

/** Gains et solde du vendeur ou du livreur connecté. */
async function myEarnings({db, uid, now = new Date()}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || !["Seller", "Deliver"].includes(u.get("role"))) {
    throw err("permission-denied", "Réservé aux commerces et livreurs.");
  }
  const list = await entriesOf(db, uid);
  // Journées à l'heure de Brazzaville (UTC+1).
  const local = (d) => new Date(d.getTime() + 3600 * 1000);
  const day = (d) => local(d).toISOString().slice(0, 10);
  const today = day(now);
  const weekAgo = now.getTime() - 7 * 86400000;
  const earned = list.filter((e) => e.type !== "payout");
  const sum = (arr) => arr.reduce((s, e) => s + e.amount, 0);
  return {
    balance: sum(list),
    today: sum(earned.filter((e) => e.at && day(new Date(e.at)) === today)),
    week: sum(earned.filter((e) => e.at &&
      new Date(e.at).getTime() >= weekAgo)),
    total: sum(earned),
    paidOut: -sum(list.filter((e) => e.type === "payout")),
    entries: list.slice(0, 100),
    settings: await loadSettings(db),
  };
}

/** L'admin lit ou règle commission et part du livreur. */
async function adminFinanceSettings({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  if (data.save) {
    const c = Number(data.save.commission_rate);
    const d = Number(data.save.deliverer_share);
    if (!Number.isFinite(c) || c < 0 || c > 0.5 ||
        !Number.isFinite(d) || d < 0 || d > 1) {
      throw err("invalid-argument",
          "Commission entre 0 et 50 %, part du livreur entre 0 et 100 %.");
    }
    await db.doc(SETTINGS).set({commission_rate: c, deliverer_share: d,
      updated_by: adminUid, updated_at: ts()});
    await db.collection("audit_logs").add({actor_uid: adminUid,
      actor_role: "Admin", action: "finance.settings", target: SETTINGS,
      details: {commission_rate: c, deliverer_share: d}, created_at: ts()});
  }
  const s = await loadSettings(db);
  return {settings: {commission_rate: s.commission_rate,
    deliverer_share: s.deliverer_share}};
}

/** Versement à un commerce ou un livreur (une seule fois par requestId). */
async function adminRecordPayout({db, messaging, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const target = await db.doc(`User/${String(data.uid || "_")
      .slice(0, 128)}`).get();
  if (!target.exists || !["Seller", "Deliver"].includes(target.get("role"))) {
    throw err("not-found", "Compte introuvable.");
  }
  const amount = round(data.amount);
  if (amount <= 0) throw err("invalid-argument", "Montant invalide.");
  const requestId = String(data.requestId || "").replace(/[^A-Za-z0-9-]/g, "")
      .slice(0, 64);
  if (requestId.length < 8) {
    throw err("invalid-argument", "Identifiant de versement manquant.");
  }
  const method = ["MoMo", "Airtel", "Espèces", "Virement"]
      .includes(data.method) ? data.method : "MoMo";
  const balance = (await entriesOf(db, target.id))
      .reduce((s, e) => s + e.amount, 0);
  if (amount > balance) {
    throw err("failed-precondition",
        `Montant supérieur au solde (${balance} F).`);
  }
  const ref = db.doc(`Ledger/payout_${requestId}`);
  const created = await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return false;
    tx.set(ref, {account_uid: target.id,
      account_role: target.get("role"), type: "payout", amount: -amount,
      method, reference: String(data.reference || "").slice(0, 120),
      label: `Versement ${method}`, by: adminUid, at: ts()});
    tx.set(db.collection("audit_logs").doc(), {actor_uid: adminUid,
      actor_role: "Admin", action: "finance.payout",
      target: target.ref.path, details: {amount, method,
        reference: String(data.reference || "").slice(0, 120)},
      created_at: ts()});
    return true;
  });
  if (created) {
    await notifyUsers({db, messaging, users: [target],
      title: "Versement Kitunga",
      body: `${amount} F vous ont été versés (${method}).`,
      kind: "finance"});
  }
  return {ok: true, duplicate: !created, balance: balance -
    (created ? amount : 0)};
}

/** Vue financière de l'admin : totaux et soldes par compte. */
async function adminFinanceOverview({db, uid}) {
  await requireAdmin(db, uid);
  const [ledger, pays, refunds] = await Promise.all([
    db.collection("Ledger").get(),
    db.collection("Paiement").where("status", "==", "Réussi").get(),
    db.collection("Orders").where("refund_status", "==", "Envoyé").get(),
  ]);
  const accounts = {};
  let commission = 0;
  let payouts = 0;
  for (const e of ledger.docs) {
    const id = e.get("account_uid");
    const amount = Number(e.get("amount")) || 0;
    if (id === "kitunga") {
      commission += amount;
      continue;
    }
    const a = accounts[id] || (accounts[id] = {uid: id,
      role: e.get("account_role"), balance: 0, earned: 0, paidOut: 0});
    a.balance += amount;
    if (e.get("type") === "payout") {
      a.paidOut -= amount;
      payouts -= amount;
    } else {
      a.earned += amount;
    }
  }
  const users = await Promise.all(Object.keys(accounts).map((id) =>
    db.doc(`User/${id}`).get()));
  for (const u of users) {
    if (!u.exists) continue;
    accounts[u.id].name = u.get("display_name") || u.id;
    accounts[u.id].phone = u.get("phone_number") || "";
  }
  const collectedOrders = pays.docs.filter((p) => p.get("kind") !==
    "subscription");
  const subs = pays.docs.filter((p) => p.get("kind") === "subscription");
  const sum = (docs, f) => docs.reduce((s, d) =>
    s + (Number(d.get(f)) || 0), 0);
  return {
    totals: {
      collectedOrders: sum(collectedOrders, "amount"),
      subscriptions: sum(subs, "amount"),
      commission,
      payouts,
      refunds: refunds.docs.reduce((s, o) => s +
        (Number(o.get("refund_amount") ?? o.get("total_amount")) || 0), 0),
      owed: Object.values(accounts).reduce((s, a) => s + a.balance, 0),
    },
    accounts: Object.values(accounts).sort((a, b) => b.balance - a.balance),
    settings: await loadSettings(db),
  };
}

/** Écritures d'un compte (admin). */
async function adminAccountLedger({db, uid, data}) {
  await requireAdmin(db, uid);
  return {entries: (await entriesOf(db, String(data.uid || "_")))
      .slice(0, 200)};
}

module.exports = {DEFAULTS, split, onOrderFinance, myEarnings,
  adminFinanceSettings, adminRecordPayout, adminFinanceOverview,
  adminAccountLedger};
