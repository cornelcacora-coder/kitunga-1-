/**
 * Retours et échanges (boutiques et magasins).
 *
 * Le client demande un retour dans les 7 jours suivant la livraison
 * (motif, souhait : échange ou remboursement, photos facultatives) ; le
 * commerce l'accepte ou le refuse avec un motif. Remboursement accepté :
 * la commande passe dans les remboursements de l'admin (montant des
 * articles, sans la livraison).
 *
 * Tout est rangé sur la commande (champs return_*), écrit par le serveur
 * seul (règles Firestore : orderServerFieldsUnchanged).
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");

const RETURN_DAYS = 7;
const DAY = 24 * 60 * 60 * 1000;
const CATEGORIES = ["Boutique", "Magasin"];
const DELIVERED = ["Livrer", "Reçu"];
const REASONS = {
  size: "Taille ou pointure qui ne convient pas",
  defect: "Article abîmé ou défectueux",
  not_as_described: "Différent de la description",
  wrong_item: "Mauvais article reçu",
  other: "Autre raison",
};
const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const err = (code, message) => new AcquisitionError(code, message);

function photoOf(raw, uid) {
  const v = text(raw, 1500);
  let url;
  try {
    url = new URL(v);
  } catch (_) {
    throw err("invalid-argument", "Photo invalide.");
  }
  const path = decodeURIComponent(url.pathname);
  if (url.protocol !== "https:" ||
    url.hostname !== "firebasestorage.googleapis.com" ||
    !path.includes(`/o/users/${uid}/`)) {
    throw err("invalid-argument",
        "La photo doit être envoyée depuis l'application Kitunga.");
  }
  return v;
}

/** Date de livraison (sinon dernière mise à jour du statut). */
const deliveredAt = (o) =>
  toDate(o.get("delivered_at")) || toDate(o.get("status_updated_at"));

/** Le client demande un retour ou un échange. */
async function requestReturn({db, uid, data, now = new Date()}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const ref = db.doc(`Orders/${text(data.orderId, 128) || "_"}`);
  const reason = text(data.reason, 30);
  const wish = data.wish === "refund" ? "refund" : "exchange";
  if (!REASONS[reason]) {
    throw err("invalid-argument", "Choisissez le motif du retour.");
  }
  const note = text(data.note, 500);
  if (reason === "other" && !note) {
    throw err("invalid-argument", "Expliquez la raison du retour.");
  }
  const photos = Array.isArray(data.photos) ?
    data.photos.slice(0, 4).map((p) => photoOf(p, uid)) : [];
  return db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    if (!o.exists || !o.get("user_ref") || o.get("user_ref").id !== uid) {
      throw err("not-found", "Commande introuvable.");
    }
    const seller = await tx.get(o.get("seller_ref"));
    if (!CATEGORIES.includes(seller.get("category"))) {
      throw err("failed-precondition",
          "Les retours ne concernent que les boutiques et magasins.");
    }
    if (!DELIVERED.includes(o.get("status"))) {
      throw err("failed-precondition",
          "Un retour se demande une fois la commande livrée.");
    }
    if (o.get("return_status")) {
      throw err("already-exists",
          "Un retour a déjà été demandé pour cette commande.");
    }
    const at = deliveredAt(o);
    if (at && now - at > RETURN_DAYS * DAY) {
      throw err("failed-precondition",
          `Le délai de retour (${RETURN_DAYS} jours après la livraison) ` +
          "est dépassé.");
    }
    tx.update(ref, {return_status: "requested", return_reason: reason,
      return_wish: wish, return_note: note, return_photos: photos,
      return_requested_at: ts()});
    return {ok: true, status: "requested"};
  });
}

/** Le commerce accepte (échange ou remboursement) ou refuse le retour. */
async function decideReturn({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const ref = db.doc(`Orders/${text(data.orderId, 128) || "_"}`);
  const accept = data.decision === "accept";
  const note = text(data.note, 300);
  if (!accept && !note) {
    throw err("invalid-argument",
        "Indiquez au client pourquoi le retour est refusé.");
  }
  return db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    if (!o.exists || !o.get("seller_ref") || o.get("seller_ref").id !== uid) {
      throw err("not-found", "Commande introuvable.");
    }
    if (o.get("return_status") !== "requested") {
      throw err("failed-precondition", "Aucune demande de retour en attente.");
    }
    const refund = accept && o.get("return_wish") === "refund";
    const amount = Math.max(0, Math.round(Number(o.get("total_amount") || 0) -
      Number(o.get("delivery_fees") || 0)));
    tx.update(ref, {
      return_status: accept ? "accepted" : "refused",
      return_decision_note: note, return_decided_at: ts(),
      // Remboursement : traité par l'admin (Gestion > Remboursements).
      ...(refund ? {refund_needed: true,
        refund_status: "À traiter manuellement", refund_amount: amount,
        refund_reason: "Retour accepté par le commerce"} : {}),
    });
    return {ok: true, status: accept ? "accepted" : "refused", refund};
  });
}

module.exports = {requestReturn, decideReturn, REASONS, RETURN_DAYS};
