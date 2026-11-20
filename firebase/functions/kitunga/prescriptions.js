/**
 * Ordonnances (pharmacies).
 *
 * 1. Le client envoie la photo de son ordonnance à une pharmacie
 *    (photos rangées dans prescriptions/{uid}/, non lisibles publiquement).
 * 2. La pharmacie la valide (valable 7 jours, pour une commande) ou la
 *    refuse avec un motif.
 * 3. Au paiement, un médicament sur ordonnance n'est accepté qu'avec une
 *    ordonnance validée, non expirée et pas encore utilisée ; elle est
 *    rattachée à la commande (payments.js).
 *
 * Collection Prescriptions : écrite et lue uniquement par le serveur.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");

const PRESCRIPTIONS = "Prescriptions";
const VALID_DAYS = 7;
const MAX_PENDING = 3;
const DAY = 24 * 60 * 60 * 1000;
const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const err = (code, message) => new AcquisitionError(code, message);
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};

/** Photo envoyée par ce client dans son dossier privé d'ordonnances. */
function photoOf(raw, uid) {
  const v = text(raw, 1500);
  let url;
  try {
    url = new URL(v);
  } catch (_) {
    throw err("invalid-argument", "Photo d'ordonnance invalide.");
  }
  const path = decodeURIComponent(url.pathname);
  if (url.protocol !== "https:" ||
    url.hostname !== "firebasestorage.googleapis.com" ||
    !path.includes(`/o/prescriptions/${uid}/`)) {
    throw err("invalid-argument",
        "La photo doit être envoyée depuis l'application Kitunga.");
  }
  return v;
}

async function pharmacyOf(db, sellerUid) {
  const s = await db.doc(`User/${text(sellerUid, 128) || "_"}`).get();
  if (!s.exists || s.get("role") !== "Seller" ||
    s.get("category") !== "Pharmacie") {
    throw err("not-found", "Pharmacie introuvable.");
  }
  if (s.get("account_status") === "suspended") {
    throw err("failed-precondition", "Cette pharmacie n'est plus disponible.");
  }
  return s;
}

/** État réel : une ordonnance validée dont la date est passée a expiré. */
function statusOf(p, now = new Date()) {
  const s = p.status || "pending";
  if (s === "approved") {
    const until = toDate(p.expires_at);
    if (until && until <= now) return "expired";
  }
  return s;
}

function view(d, now) {
  const p = d.data();
  return {id: d.id, sellerUid: p.seller_uid, sellerName: p.seller_name || "",
    photos: p.photos || [], note: p.note || "", status: statusOf(p, now),
    reviewNote: p.review_note || "", createdAt: iso(p.created_at),
    expiresAt: iso(p.expires_at), orderId: p.order_ref ? p.order_ref.id : null};
}

/** Le client envoie son ordonnance à une pharmacie. */
async function submitPrescription({db, uid, data, now = new Date()}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const user = await db.doc(`User/${uid}`).get();
  if (!user.exists) throw err("permission-denied", "Compte introuvable.");
  const pharmacy = await pharmacyOf(db, data.sellerUid);
  if (pharmacy.id === uid) {
    throw err("invalid-argument", "Une pharmacie ne s'envoie pas d'ordonnance.");
  }
  const photos = Array.isArray(data.photos) ?
    data.photos.slice(0, 4).map((p) => photoOf(p, uid)) : [];
  if (photos.length === 0) {
    throw err("invalid-argument", "Ajoutez la photo de votre ordonnance.");
  }
  const mine = await db.collection(PRESCRIPTIONS)
      .where("user_uid", "==", uid)
      .where("seller_uid", "==", pharmacy.id).get();
  const pending = mine.docs.filter((d) =>
    statusOf(d.data(), now) === "pending").length;
  if (pending >= MAX_PENDING) {
    throw err("failed-precondition",
        "Vous avez déjà des ordonnances en attente de vérification par " +
        "cette pharmacie.");
  }
  const ref = db.collection(PRESCRIPTIONS).doc();
  await ref.set({
    user_ref: user.ref, user_uid: uid,
    user_name: user.get("display_name") || "",
    user_phone: user.get("phone_number") || "",
    seller_ref: pharmacy.ref, seller_uid: pharmacy.id,
    seller_name: pharmacy.get("display_name") || "",
    photos, note: text(data.note, 500), status: "pending",
    created_at: ts(), updated_at: ts(),
  });
  return {id: ref.id, status: "pending"};
}

/** Ordonnances du client (toutes, ou pour une pharmacie). */
async function myPrescriptions({db, uid, data = {}, now = new Date()}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  let q = db.collection(PRESCRIPTIONS).where("user_uid", "==", uid);
  const sellerUid = text(data.sellerUid, 128);
  if (sellerUid) q = q.where("seller_uid", "==", sellerUid);
  const snap = await q.get();
  return {prescriptions: snap.docs.map((d) => view(d, now))
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
      .slice(0, 30)};
}

/** Ordonnances reçues par la pharmacie connectée (en attente d'abord). */
async function sellerPrescriptions({db, uid, now = new Date()}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  await pharmacyOf(db, uid);
  const snap = await db.collection(PRESCRIPTIONS)
      .where("seller_uid", "==", uid).get();
  const rank = (s) => (s === "pending" ? 0 : 1);
  return {prescriptions: snap.docs.map((d) => ({...view(d, now),
    clientName: d.get("user_name") || "",
    clientPhone: d.get("user_phone") || ""}))
      .sort((a, b) => rank(a.status) - rank(b.status) ||
        String(b.createdAt).localeCompare(String(a.createdAt)))
      .slice(0, 60)};
}

/** La pharmacie valide (7 jours, une commande) ou refuse avec un motif. */
async function reviewPrescription({db, uid, data, now = new Date()}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  await pharmacyOf(db, uid);
  const ref = db.doc(`${PRESCRIPTIONS}/${text(data.id, 128) || "_"}`);
  const approve = data.decision === "approve";
  const note = text(data.note, 300);
  if (!approve && !note) {
    throw err("invalid-argument",
        "Indiquez au client pourquoi l'ordonnance est refusée.");
  }
  return db.runTransaction(async (tx) => {
    const p = await tx.get(ref);
    if (!p.exists || p.get("seller_uid") !== uid) {
      throw err("not-found", "Ordonnance introuvable.");
    }
    if (p.get("status") !== "pending") {
      throw err("failed-precondition", "Cette ordonnance a déjà été traitée.");
    }
    tx.update(ref, approve ? {
      status: "approved", review_note: "", reviewed_at: ts(),
      expires_at: new Date(now.getTime() + VALID_DAYS * DAY), updated_at: ts(),
    } : {
      status: "rejected", review_note: note, reviewed_at: ts(),
      updated_at: ts(),
    });
    return {ok: true, status: approve ? "approved" : "rejected"};
  });
}

/**
 * Ordonnance utilisable pour commander chez cette pharmacie : validée, non
 * expirée, pas encore utilisée (la plus proche de l'expiration). null sinon.
 */
async function usablePrescription(db, userUid, sellerUid, now = new Date()) {
  const snap = await db.collection(PRESCRIPTIONS)
      .where("user_uid", "==", userUid)
      .where("seller_uid", "==", sellerUid)
      .where("status", "==", "approved").get();
  const ok = snap.docs.filter((d) => statusOf(d.data(), now) === "approved")
      .sort((a, b) => toDate(a.get("expires_at")) - toDate(b.get("expires_at")));
  return ok[0] || null;
}

module.exports = {submitPrescription, myPrescriptions, sellerPrescriptions,
  reviewPrescription, usablePrescription, statusOf, VALID_DAYS};
