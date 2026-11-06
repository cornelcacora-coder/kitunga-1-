/**
 * Écritures sûres du module commercial. Toutes passent par le serveur (Admin
 * SDK) : les règles Firestore interdisent aux applications d'écrire dans ces
 * collections.
 */
const admin = require("firebase-admin");
const {COLLECTIONS, AcquisitionError, assertTransition} = require("./model");

const ALREADY_EXISTS = 6; // code gRPC renvoyé par create() si le document existe

/**
 * Crée le document seulement s'il n'existe pas. Renvoie true si ce appel l'a
 * créé, false s'il existait déjà : sûr face aux appels répétés ou simultanés.
 */
async function createOnce(ref, data) {
  try {
    await ref.create(data);
    return true;
  } catch (e) {
    if (e && e.code === ALREADY_EXISTS) return false;
    throw e;
  }
}

/** Entrée du journal d'audit, écrite dans la même transaction que l'action. */
function audit(tx, db, {actorUid, actorRole, action, target, details = {}}) {
  tx.create(db.collection(COLLECTIONS.audit).doc(), {
    actor_uid: actorUid || null,
    actor_role: actorRole || "system",
    action,
    target,
    details,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Change le statut d'un document en vérifiant la transition, dans une
 * transaction, avec l'entrée d'audit correspondante. Renvoie l'ancien statut.
 */
async function transition(db, ref, kind, to, {actorUid, actorRole, extra = {},
  details = {}} = {}) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new AcquisitionError("not-found", "Élément introuvable.");
    }
    const from = snap.get("status");
    assertTransition(kind, from, to);
    tx.update(ref, {
      ...extra,
      status: to,
      status_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    audit(tx, db, {actorUid, actorRole, action: `${kind}.${to}`,
      target: ref.path, details: {from, ...details}});
    return from;
  });
}

module.exports = {createOnce, audit, transition};
