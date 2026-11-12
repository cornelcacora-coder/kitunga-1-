/**
 * Remise sécurisée des commandes et reçus.
 *
 * - deliveryCode : le client obtient le code à 4 chiffres de sa commande
 *   (créé à la première demande). Le code est rangé dans delivery_codes,
 *   collection fermée à toutes les applications : seul le serveur le lit.
 * - confirmDelivery : le livreur assigné saisit le code donné par le client
 *   et joint une photo de la remise ; la commande passe « Livrer » (comme
 *   avant) avec delivery_code_verified. 5 codes faux : remise bloquée,
 *   l'admin est alerté (delivery_issue).
 * - reportDeliveryIssue : client injoignable, refus, adresse introuvable…
 * - orderReceipt : reçu d'une commande livrée (numéro unique KTG-AAAA-NNNNNN
 *   attribué une seule fois), pour le client, le commerce, le livreur ou
 *   l'admin.
 */
const admin = require("firebase-admin");
const crypto = require("crypto");
const {AcquisitionError, toDate} = require("./acquisition/model");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const err = (code, message) => new AcquisitionError(code, message);
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const MAX_ATTEMPTS = 5;
const DELIVERED = ["Livrer", "Reçu", "Non Reçu"];
const ISSUES = {
  absent: "Client injoignable",
  refused: "Commande refusée par le client",
  address: "Adresse introuvable",
  damaged: "Colis abîmé",
  other: "Autre problème",
};

async function caller(db, uid) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  return {uid, role: u.exists ? u.get("role") || "User" : null, user: u};
}

async function orderOf(db, orderId) {
  const ref = db.doc(`Orders/${text(orderId, 128) || "_"}`);
  const o = await ref.get();
  if (!o.exists) throw err("not-found", "Commande introuvable.");
  return o;
}

const isBuyer = (o, uid) => o.get("user_ref") && o.get("user_ref").id === uid;
const isSeller = (o, uid) =>
  o.get("seller_ref") && o.get("seller_ref").id === uid;
const isDeliverer = (o, uid) =>
  (o.get("deliver_reference") && o.get("deliver_reference").id === uid) ||
  o.get("deliverer_ref") === uid;

/** Code à 4 chiffres, sans 0000 ni chiffres tous identiques. */
function newCode() {
  for (;;) {
    const c = String(crypto.randomInt(0, 10000)).padStart(4, "0");
    if (!/^(\d)\1{3}$/.test(c)) return c;
  }
}

/** Le client obtient (et crée au besoin) le code de remise. */
async function deliveryCode({db, uid, data}) {
  const me = await caller(db, uid);
  const o = await orderOf(db, data.orderId);
  if (!isBuyer(o, me.uid)) {
    throw err("permission-denied", "Seul le client voit ce code.");
  }
  if (DELIVERED.includes(o.get("status")) ||
    ["Annulée", "Refusée"].includes(o.get("status"))) {
    return {code: null, done: true};
  }
  const ref = db.doc(`delivery_codes/${o.id}`);
  return db.runTransaction(async (tx) => {
    const c = await tx.get(ref);
    if (c.exists) return {code: c.get("code"), locked: c.get("locked") === true};
    const code = newCode();
    tx.create(ref, {code, attempts: 0, locked: false, created_at: ts()});
    return {code, locked: false};
  });
}

/** Adresse d'une photo envoyée par l'application (Firebase Storage). */
function photoOf(url) {
  const v = text(url, 1000);
  try {
    const u = new URL(v);
    if (u.protocol === "https:" &&
      ["firebasestorage.googleapis.com", "storage.googleapis.com"]
          .includes(u.hostname)) {
      return v;
    }
  } catch (_) {/* invalide */}
  throw err("invalid-argument", "Prenez une photo de la remise.");
}

/** Le livreur confirme la remise avec le code du client et une photo. */
async function confirmDelivery({db, uid, data}) {
  const me = await caller(db, uid);
  if (me.role !== "Deliver") {
    throw err("permission-denied", "Réservé aux livreurs.");
  }
  const code = text(data.code, 8);
  if (!/^\d{4}$/.test(code)) {
    throw err("invalid-argument", "Le code de remise a 4 chiffres.");
  }
  const photo = photoOf(data.photoUrl);
  const orderRef = db.doc(`Orders/${text(data.orderId, 128) || "_"}`);
  const codeRef = db.doc(`delivery_codes/${orderRef.id}`);
  return db.runTransaction(async (tx) => {
    const [o, c] = await Promise.all([tx.get(orderRef), tx.get(codeRef)]);
    if (!o.exists) throw err("not-found", "Commande introuvable.");
    if (!isDeliverer(o, me.uid)) {
      throw err("permission-denied", "Cette commande n'est pas la vôtre.");
    }
    if (o.get("status") !== "encours") {
      throw err("failed-precondition", "Cette commande n'est pas en livraison.");
    }
    if (!c.exists) {
      throw err("failed-precondition",
          "Le client n'a pas encore de code : demandez-lui d'ouvrir le suivi " +
          "de sa commande dans l'application Kitunga.");
    }
    if (c.get("locked") === true) {
      throw err("failed-precondition",
          "Trop de codes faux : remise bloquée. Contactez le support Kitunga.");
    }
    if (c.get("code") !== code) {
      const attempts = (c.get("attempts") || 0) + 1;
      const locked = attempts >= MAX_ATTEMPTS;
      tx.update(codeRef, {attempts, locked});
      if (locked) {
        tx.update(orderRef, {delivery_issue: {type: "code_locked",
          label: "Trop de codes de remise faux", by: me.uid, at: ts()}});
      }
      // Erreur métier renvoyée après l'écriture (la transaction est validée).
      return {ok: false, attemptsLeft: MAX_ATTEMPTS - attempts, locked};
    }
    tx.update(codeRef, {used_at: ts(), used_by: me.uid});
    tx.update(orderRef, {status: "Livrer", delivered_at: ts(),
      status_actor: {uid: me.uid, role: "Deliver", at: Date.now()},
      status_reason: null,
      status_updated_at: ts(), delivery_photo: photo,
      delivery_code_verified: true, deliverer_ref: me.uid,
      delivery_issue: admin.firestore.FieldValue.delete()});
    return {ok: true};
  }).then((r) => {
    if (r.ok) return r;
    throw err("invalid-argument", r.locked ?
      "Code faux. Trop d'essais : remise bloquée, l'administrateur est prévenu." :
      `Code faux. Il reste ${r.attemptsLeft} essai${r.attemptsLeft > 1 ?
        "s" : ""}.`);
  });
}

/** Le livreur signale un problème (la commande reste en livraison). */
async function reportDeliveryIssue({db, uid, data}) {
  const me = await caller(db, uid);
  const type = text(data.type, 20);
  if (!ISSUES[type]) throw err("invalid-argument", "Problème inconnu.");
  const note = text(data.note, 300);
  if (type === "other" && !note) {
    throw err("invalid-argument", "Décrivez le problème.");
  }
  const o = await orderOf(db, data.orderId);
  if (!isDeliverer(o, me.uid)) {
    throw err("permission-denied", "Cette commande n'est pas la vôtre.");
  }
  if (o.get("status") !== "encours") {
    throw err("failed-precondition", "Cette commande n'est pas en livraison.");
  }
  await o.ref.update({delivery_issue: {type, label: ISSUES[type], note,
    by: me.uid, at: ts()}});
  await db.collection("audit_logs").add({actor_uid: me.uid,
    actor_role: "Deliver", action: "order.delivery_issue",
    target: o.ref.path, details: {type, note}, created_at: ts()});
  return {ok: true};
}

/** Numéro de reçu attribué une seule fois (KTG-AAAA-NNNNNN). */
async function receiptNumber(db, orderRef, at) {
  return db.runTransaction(async (tx) => {
    const o = await tx.get(orderRef);
    if (o.get("receipt_number")) return o.get("receipt_number");
    const year = (at || new Date()).getUTCFullYear();
    const counterRef = db.doc(`receipt_counters/${year}`);
    const counter = await tx.get(counterRef);
    const next = (counter.exists ? counter.get("next") : 1) || 1;
    const number = `KTG-${year}-${String(next).padStart(6, "0")}`;
    tx.set(counterRef, {next: next + 1}, {merge: true});
    tx.update(orderRef, {receipt_number: number, receipt_at: ts()});
    return number;
  });
}

/** Reçu d'une commande livrée. */
async function orderReceipt({db, uid, data}) {
  const me = await caller(db, uid);
  const o = await orderOf(db, data.orderId);
  const allowed = me.role === "Admin" || isBuyer(o, me.uid) ||
    isSeller(o, me.uid) || isDeliverer(o, me.uid);
  if (!allowed) throw err("permission-denied", "Reçu non accessible.");
  if (!DELIVERED.includes(o.get("status"))) {
    throw err("failed-precondition",
        "Le reçu est disponible une fois la commande livrée.");
  }
  const deliveredAt = toDate(o.get("delivered_at")) ||
    toDate(o.get("status_updated_at")) || toDate(o.get("created_at"));
  const number = await receiptNumber(db, o.ref, deliveredAt);
  const ref = o.get("order_unique_reference") || o.get("order_id") || "";
  const [items, client, seller, deliverer, payments] = await Promise.all([
    ref ? db.collection("OrderItems").where("order_ref", "==", ref).get() :
      Promise.resolve({docs: []}),
    o.get("user_ref") ? o.get("user_ref").get() : null,
    o.get("seller_ref") ? o.get("seller_ref").get() : null,
    o.get("deliver_reference") ? o.get("deliver_reference").get() : null,
    db.collection("Paiement").where("order_ref", "==", o.ref).get(),
  ]);
  const name = (d) => d && d.exists ?
    (d.get("display_name") || d.get("email") || "") : "";
  const lines = items.docs.map((d) => {
    const qty = Number(d.get("quantity")) || 1;
    const price = Math.round(Number(d.get("price_at_purchase")) || 0);
    return {name: d.get("item_name") || "Article", options: d.get("options") ||
      "", quantity: qty, unitPrice: price, total: price * qty};
  });
  const subtotal = lines.reduce((s, l) => s + l.total, 0);
  const fees = Math.round(Number(o.get("delivery_fees")) || 0);
  const paid = payments.docs.find((p) => ["Réussi", "Réussi - non livrable"]
      .includes(p.get("status")));
  const iso = (v) => {
    const d = toDate(v);
    return d ? d.toISOString() : null;
  };
  return {
    number,
    orderReference: ref,
    orderedAt: iso(o.get("created_at")),
    deliveredAt: deliveredAt ? deliveredAt.toISOString() : null,
    status: o.get("status"),
    codeVerified: o.get("delivery_code_verified") === true,
    client: {name: name(client),
      phone: client && client.exists ? client.get("phone_number") || "" : ""},
    seller: {name: name(seller),
      category: seller && seller.exists ? seller.get("category") || "" : "",
      phone: seller && seller.exists ? seller.get("phone_number") || "" : ""},
    deliverer: name(deliverer),
    address: [o.get("delivery_zone"), o.get("delivery_location")]
        .filter((s) => s && String(s).trim()).join(" · "),
    lines,
    subtotal,
    deliveryFees: fees,
    total: Math.round(Number(o.get("total_amount")) || subtotal + fees),
    payment: paid ? {method: "MTN Mobile Money",
      reference: paid.get("reference_id") || paid.id,
      phone: paid.get("payer_phone") || ""} : null,
  };
}

/**
 * Un livreur prend une commande prête. Transaction : si deux livreurs
 * acceptent en même temps, un seul l'obtient, l'autre est prévenu.
 */
async function takeDelivery({db, uid, data}) {
  const me = await caller(db, uid);
  if (me.role !== "Deliver") {
    throw err("permission-denied", "Réservé aux livreurs.");
  }
  if (me.user.get("account_status") === "suspended") {
    throw err("permission-denied", "Votre compte livreur est suspendu.");
  }
  const ref = db.doc(`Orders/${text(data.orderId, 128) || "_"}`);
  return db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    if (!o.exists) throw err("not-found", "Commande introuvable.");
    if (isDeliverer(o, uid)) return {ok: true, already: true};
    const taken = o.get("deliver_reference") ||
      String(o.get("deliverer_ref") || "") !== "";
    if (taken) {
      throw err("already-exists",
          "Cette commande a déjà été prise par un autre livreur.");
    }
    if (o.get("status") !== "Pret") {
      throw err("failed-precondition", "Cette commande n'est plus disponible.");
    }
    // Course proposée en exclusivité à un autre livreur (quelques secondes).
    const until = toDate(o.get("offer_expires_at"));
    if (o.get("offer_to") && o.get("offer_to") !== uid && until &&
        until > new Date()) {
      throw err("failed-precondition",
          "Cette course est proposée à un autre livreur. Réessayez dans " +
          "un instant.");
    }
    tx.update(ref, {
      offer_to: admin.firestore.FieldValue.delete(),
      offer_expires_at: admin.firestore.FieldValue.delete(),
      offer_mission: admin.firestore.FieldValue.delete(),
      status: "encours",
      deliverer_ref: uid,
      deliver_reference: db.doc(`User/${uid}`),
      taken_at: ts(),
      status_actor: {uid, role: "Deliver", at: Date.now()},
      status_reason: null,
    });
    return {ok: true};
  });
}

module.exports = {deliveryCode, confirmDelivery, reportDeliveryIssue,
  orderReceipt, takeDelivery, ISSUES, MAX_ATTEMPTS};
