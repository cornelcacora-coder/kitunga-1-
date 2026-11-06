/**
 * Confirmation de l'attribution à l'inscription (FIRST TOUCH).
 *
 * Le client vient de créer son compte : le premier contact provisoire de son
 * appareil (ou, à défaut, le code saisi à l'inscription) devient une
 * attribution définitive : acquisition_attributions/{uid}, créée une seule
 * fois, jamais réattribuée.
 *
 * Garde-fous :
 * - Nouveau client seulement : compte Firebase Auth créé au plus 72 h avant le
 *   premier contact (ou avant la saisie du code). La date vient de Firebase
 *   Auth, que l'utilisateur ne peut pas modifier.
 * - Même personne : l'empreinte du téléphone est enregistrée une seule fois.
 *   Un nouveau compte avec un téléphone déjà connu est enregistré « rejeté »
 *   (aucune commission) ; le commercial d'origine garde son client.
 * - Auto-parrainage : téléphone du client identique à celui du commercial.
 */
const admin = require("firebase-admin");
const {COLLECTIONS, AcquisitionError, parseReferralCode, installationId,
  identityKey, toDate} = require("./model");
const {checkCode} = require("./links");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const NEW_CLIENT_WINDOW = 72 * 60 * 60 * 1000;

/** Prénom et initiale du nom : seule information montrée au commercial. */
function shortName(displayName) {
  const parts = String(displayName || "").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "Client";
  const first = parts[0].slice(0, 20);
  return parts[1] ? `${first} ${parts[1][0].toUpperCase()}.` : first;
}

async function claimAttribution({db, auth, uid, data, identitySecret,
  clock = () => new Date()}) {
  if (!uid) throw new AcquisitionError("unauthenticated", "Connexion requise.");
  const install = data.installationId ?
    installationId(data.installationId) : null;
  const manualCode = data.code ? parseReferralCode(data.code) : null;
  if (data.code && !manualCode) {
    throw new AcquisitionError("invalid-argument", "Code commercial invalide.");
  }
  if (!install && !manualCode) return {status: "none"};

  const account = await auth.getUser(uid);
  // Compte anonyme (visiteur) : pas encore un client.
  if (!account.email) return {status: "not_a_client"};
  const accountCreated = new Date(account.metadata.creationTime);
  const now = clock();

  const attributionRef = db.doc(`${COLLECTIONS.attributions}/${uid}`);
  const touchRef = install ? db.doc(`${COLLECTIONS.touches}/${install}`) : null;

  return db.runTransaction(async (tx) => {
    const [existing, user, touch] = await Promise.all([
      tx.get(attributionRef),
      tx.get(db.doc(`User/${uid}`)),
      touchRef ? tx.get(touchRef) : Promise.resolve(null),
    ]);
    if (existing.exists) return {status: "already_attributed"};
    const role = user.exists ? (user.get("role") || "User") : null;
    if (role !== "User") return {status: "not_a_client"};

    // 1. Premier contact de l'appareil, s'il n'a pas déjà servi.
    let origin = null;
    if (touch && touch.exists && touch.get("status") === "provisional") {
      origin = {source: touch.get("source"), code: touch.get("code"),
        agentUid: touch.get("agent_uid"),
        campaignId: touch.get("campaign_id"),
        assignmentId: touch.get("assignment_id"),
        touchId: touch.id, touchedAt: toDate(touch.get("touched_at_server"))};
    }
    // 2. Sinon, le code saisi à l'inscription (revérifié maintenant).
    if (!origin && manualCode) {
      const check = await checkCode(db, manualCode, now, tx);
      if (!check.ok) return {status: "code_refused", reason: check.reason};
      origin = {source: "manual", code: manualCode, agentUid: check.agentUid,
        campaignId: check.campaignId, assignmentId: check.assignmentId,
        touchId: null, touchedAt: now};
    }
    if (!origin) return {status: "none"};

    // Nouveau client : compte créé au plus 72 h avant le contact.
    if (accountCreated.getTime() < origin.touchedAt.getTime() - NEW_CLIENT_WINDOW) {
      return {status: "existing_client"};
    }

    // Même personne et auto-parrainage (empreinte du téléphone).
    const key = identityKey(user.get("phone_number"), identitySecret);
    const keyRef = key ? db.doc(`${COLLECTIONS.identityKeys}/${key}`) : null;
    const [keyDoc, agent] = await Promise.all([
      keyRef ? tx.get(keyRef) : Promise.resolve(null),
      tx.get(db.doc(`${COLLECTIONS.agents}/${origin.agentUid}`)),
    ]);
    let status = "confirmed";
    let reason = null;
    if (key && agent.exists && agent.get("identity_key") === key) {
      status = "rejected";
      reason = "self_referral";
    } else if (keyDoc && keyDoc.exists && keyDoc.get("user_uid") !== uid) {
      status = "rejected";
      reason = "duplicate_person";
    }

    tx.create(attributionRef, {
      agent_uid: origin.agentUid,
      campaign_id: origin.campaignId,
      assignment_id: origin.assignmentId,
      code: origin.code,
      source: origin.source,
      touch_id: origin.touchId,
      // Installation de l'inscription : son activation vérifiée ouvre droit
      // à la commission d'activation (phase 7).
      installation_id: install,
      touched_at: origin.touchedAt,
      identity_key: key,
      status,
      status_reason: reason,
      duplicate_of: reason === "duplicate_person" ? keyDoc.get("user_uid") : null,
      confirmed_at: ts(),
      client_summary: {
        name: shortName(user.get("display_name")),
        signed_up_at: accountCreated,
        subscribed: false,
      },
    });
    if (keyRef && !(keyDoc && keyDoc.exists)) {
      tx.create(keyRef, {user_uid: uid, agent_uid: origin.agentUid,
        created_at: ts()});
    }
    if (origin.touchId) {
      tx.update(touchRef, {status: "confirmed", user_uid: uid,
        status_updated_at: ts()});
    }
    tx.create(db.collection(COLLECTIONS.events).doc(), {type: "signup",
      code: origin.code, campaign_id: origin.campaignId,
      agent_uid: origin.agentUid, assignment_id: origin.assignmentId,
      attribution_status: status, source: origin.source, created_at: ts()});
    return status === "confirmed" ? {status} : {status, reason};
  });
}

module.exports = {claimAttribution, shortName, NEW_CLIENT_WINDOW};
