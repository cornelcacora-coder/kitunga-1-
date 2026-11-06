/**
 * Activation vérifiée d'une installation (module commercial).
 *
 * L'application appelle kitungaRecordActivation avec un jeton App Check à
 * usage unique, obtenu par Play Integrity (vraie application Kitunga, sur un
 * vrai appareil). La fonction est déployée avec consumeAppCheckToken : le
 * jeton est consommé, un rejeu est signalé (alreadyConsumed).
 *
 * L'activation est « vérifiée » seulement si le jeton est valide, provient de
 * l'application Android com.ntemoconsulting.kitunga et n'a jamais servi. Une
 * activation non vérifiée est enregistrée telle quelle et peut être
 * revérifiée plus tard (10 essais au plus par installation).
 *
 * La commission d'activation (phase 7) exige : attribution confirmée +
 * activation vérifiée de la même installation.
 */
const admin = require("firebase-admin");
const {COLLECTIONS, AcquisitionError, installationId} = require("./model");

const ts = () => admin.firestore.FieldValue.serverTimestamp();

/** Application Firebase Android com.ntemoconsulting.kitunga. */
const ANDROID_APP_ID = "1:44272206573:android:55bb2e574ee67cea5b02e4";
const MAX_ATTEMPTS = 10;

/** `app` = context.app de la fonction appelable (jeton App Check vérifié). */
function attestation(app) {
  if (!app) return {verified: false, reason: "no_app_check"};
  if (app.appId !== ANDROID_APP_ID) return {verified: false, reason: "other_app"};
  if (app.alreadyConsumed) return {verified: false, reason: "replayed_token"};
  return {verified: true, reason: null};
}

async function recordActivation({db, uid, app, data}) {
  if (!uid) throw new AcquisitionError("unauthenticated", "Connexion requise.");
  const install = installationId(data.installationId);
  const check = attestation(app);
  const ref = db.doc(`${COLLECTIONS.activations}/${install}`);
  const touchRef = db.doc(`${COLLECTIONS.touches}/${install}`);

  return db.runTransaction(async (tx) => {
    const [snap, touch] = await Promise.all([tx.get(ref), tx.get(touchRef)]);
    if (snap.exists && snap.get("verified") === true) return {verified: true};
    const attempts = (snap.exists ? snap.get("attempts") || 0 : 0) + 1;
    if (attempts > MAX_ATTEMPTS) return {verified: false, reason: "limit"};
    const record = {
      verified: check.verified,
      reason: check.reason,
      app_id: app ? app.appId || null : null,
      attempts,
      last_uid: uid,
      updated_at: ts(),
      ...(check.verified ? {activated_at: ts(), verified_uid: uid} : {}),
    };
    if (snap.exists) {
      tx.update(ref, record);
    } else {
      tx.create(ref, {...record, first_uid: uid, created_at: ts()});
    }
    if (check.verified) {
      tx.create(db.collection(COLLECTIONS.events).doc(), {type: "activation",
        installation_id: install,
        code: touch.exists ? touch.get("code") : null,
        campaign_id: touch.exists ? touch.get("campaign_id") : null,
        agent_uid: touch.exists ? touch.get("agent_uid") : null,
        assignment_id: touch.exists ? touch.get("assignment_id") : null,
        created_at: ts()});
    }
    return check.verified ? {verified: true} :
      {verified: false, reason: check.reason};
  });
}

module.exports = {ANDROID_APP_ID, attestation, recordActivation, MAX_ATTEMPTS};
