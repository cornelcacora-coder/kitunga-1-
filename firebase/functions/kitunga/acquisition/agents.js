/**
 * Gestion des commerciaux par un administrateur : création du compte (le
 * serveur crée le compte de connexion, l'admin reste connecté), modification
 * et changement de statut. Chaque action est journalisée dans audit_logs.
 *
 * db et auth sont injectés (tests sur l'émulateur avec Auth simulé) ;
 * identitySecret est la clé ACQ_IDENTITY_KEY.
 */
const admin = require("firebase-admin");
const {normalizePhone} = require("../momo");
const {COLLECTIONS, AcquisitionError, agentCode, identityKey,
  assertTransition} = require("./model");
const {audit} = require("./store");

const now = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max = 80) =>
  (typeof v === "string" ? v.trim().slice(0, max) : "");

/** Vérifie que l'appelant est administrateur ; renvoie son uid. */
async function requireAdmin(db, uid) {
  if (!uid) throw new AcquisitionError("unauthenticated", "Connexion requise.");
  const caller = await db.doc(`User/${uid}`).get();
  if (!caller.exists || caller.get("role") !== "Admin") {
    throw new AcquisitionError("permission-denied",
        "Cette action est réservée aux administrateurs.");
  }
  return uid;
}

function phoneOf(raw) {
  const phone = normalizePhone(raw);
  if (!phone) {
    throw new AcquisitionError("invalid-argument",
        "Numéro de téléphone invalide.");
  }
  return phone;
}

/**
 * Moyen de paiement du commercial (pour ses versements). Rien n'est versé
 * automatiquement : l'admin effectue le virement et saisit sa référence.
 */
function payoutMethodOf(raw) {
  if (raw == null) return null;
  if (raw.type === "mobile_money") {
    const operator = text(raw.operator, 20) || "MTN";
    if (!["MTN", "Airtel"].includes(operator)) {
      throw new AcquisitionError("invalid-argument", "Opérateur inconnu.");
    }
    return {type: "mobile_money", operator, phone: phoneOf(raw.phone)};
  }
  if (raw.type === "bank") {
    const method = {
      type: "bank",
      bank_name: text(raw.bankName),
      account_holder: text(raw.accountHolder),
      account_number: text(raw.accountNumber, 40).replace(/\s+/g, " "),
    };
    if (!method.bank_name || !method.account_holder ||
      !/^[A-Za-z0-9 -]{5,40}$/.test(method.account_number)) {
      throw new AcquisitionError("invalid-argument",
          "Coordonnées bancaires incomplètes ou invalides.");
    }
    return method;
  }
  throw new AcquisitionError("invalid-argument",
      "Moyen de paiement : Mobile Money ou banque.");
}

function authError(e) {
  const known = {
    "auth/email-already-exists": ["already-exists",
      "Cette adresse email est déjà associée à un compte existant."],
    "auth/invalid-email": ["invalid-argument", "Adresse email invalide."],
    "auth/invalid-password": ["invalid-argument", "Mot de passe invalide."],
  };
  const k = known[e && e.code];
  return k ? new AcquisitionError(k[0], k[1]) : e;
}

/** Crée un commercial : compte de connexion, profil User et fiche commerciale. */
async function createSalesAgent({db, auth, uid, data, identitySecret}) {
  const adminUid = await requireAdmin(db, uid);
  const email = text(data.email, 120).toLowerCase();
  const password = typeof data.password === "string" ? data.password : "";
  const displayName = text(data.displayName);
  if (!email) {
    throw new AcquisitionError("invalid-argument",
        "Veuillez renseigner l'adresse email.");
  }
  if (password.length < 8) {
    throw new AcquisitionError("invalid-argument",
        "Le mot de passe doit comporter au moins 8 caractères.");
  }
  if (!displayName) {
    throw new AcquisitionError("invalid-argument",
        "Veuillez renseigner le nom du commercial.");
  }
  const phone = phoneOf(data.phone);
  const key = identityKey(phone, identitySecret);
  const payoutMethod = payoutMethodOf(data.payoutMethod);
  const keyRef = db.doc(`${COLLECTIONS.agentKeys}/${key}`);
  const phoneTaken = new AcquisitionError("already-exists",
      "Ce numéro de téléphone est déjà celui d'un autre commercial.");
  // Vérification avant de créer le compte (revérifiée dans la transaction).
  if ((await keyRef.get()).exists) throw phoneTaken;

  let created;
  try {
    created = await auth.createUser({email, password, displayName});
  } catch (e) {
    throw authError(e);
  }

  try {
    const code = await db.runTransaction(async (tx) => {
      const counterRef = db.doc(`${COLLECTIONS.counters}/agents`);
      const [counter, keyDoc] =
        await Promise.all([tx.get(counterRef), tx.get(keyRef)]);
      if (keyDoc.exists) throw phoneTaken;
      const sequence = (counter.exists ? counter.get("last") : 0) + 1;
      const agentCodeValue = agentCode(sequence);
      tx.set(counterRef, {last: sequence}, {merge: true});
      tx.create(keyRef, {agent_uid: created.uid, created_at: now()});
      tx.create(db.doc(`User/${created.uid}`), {
        uid: created.uid,
        created_time: now(),
        role: "Commercial",
        email,
        display_name: displayName,
        phone_number: phone,
      });
      tx.create(db.doc(`${COLLECTIONS.agents}/${created.uid}`), {
        agent_code: agentCodeValue,
        display_name: displayName,
        email,
        phone,
        identity_key: key,
        payout_method: payoutMethod,
        status: "active",
        created_by: adminUid,
        created_at: now(),
        updated_at: now(),
      });
      audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
        action: "agent.create",
        target: `${COLLECTIONS.agents}/${created.uid}`,
        details: {agent_code: agentCodeValue}});
      return agentCodeValue;
    });
    return {uid: created.uid, agentCode: code};
  } catch (e) {
    // Pas de compte de connexion sans fiche commerciale.
    await auth.deleteUser(created.uid).catch(() => {});
    throw e;
  }
}

/** Modifie le nom, le téléphone ou le moyen de paiement d'un commercial. */
async function updateSalesAgent({db, uid, data, identitySecret}) {
  const adminUid = await requireAdmin(db, uid);
  const agentUid = text(data.agentUid, 128);
  if (!agentUid) {
    throw new AcquisitionError("invalid-argument", "Commercial manquant.");
  }
  const changes = {};
  if (data.displayName !== undefined) {
    changes.display_name = text(data.displayName);
    if (!changes.display_name) {
      throw new AcquisitionError("invalid-argument", "Nom manquant.");
    }
  }
  if (data.payoutMethod !== undefined) {
    changes.payout_method = payoutMethodOf(data.payoutMethod);
  }
  let newPhone = null;
  if (data.phone !== undefined) newPhone = phoneOf(data.phone);
  if (Object.keys(changes).length === 0 && !newPhone) {
    throw new AcquisitionError("invalid-argument", "Aucune modification.");
  }

  await db.runTransaction(async (tx) => {
    const agentRef = db.doc(`${COLLECTIONS.agents}/${agentUid}`);
    const agent = await tx.get(agentRef);
    if (!agent.exists) {
      throw new AcquisitionError("not-found", "Commercial introuvable.");
    }
    if (agent.get("status") === "archived") {
      throw new AcquisitionError("failed-precondition",
          "Un commercial archivé ne peut plus être modifié.");
    }
    const userChanges = {};
    if (newPhone && newPhone !== agent.get("phone")) {
      const key = identityKey(newPhone, identitySecret);
      const keyRef = db.doc(`${COLLECTIONS.agentKeys}/${key}`);
      if ((await tx.get(keyRef)).exists) {
        throw new AcquisitionError("already-exists",
            "Ce numéro de téléphone est déjà celui d'un autre commercial.");
      }
      tx.create(keyRef, {agent_uid: agentUid, created_at: now()});
      tx.delete(db.doc(`${COLLECTIONS.agentKeys}/${agent.get("identity_key")}`));
      changes.phone = newPhone;
      changes.identity_key = key;
      userChanges.phone_number = newPhone;
    }
    if (changes.display_name) userChanges.display_name = changes.display_name;
    tx.update(agentRef, {...changes, updated_at: now()});
    if (Object.keys(userChanges).length) {
      tx.update(db.doc(`User/${agentUid}`), userChanges);
    }
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "agent.update", target: agentRef.path,
      details: {fields: Object.keys(changes)}});
  });
  return {ok: true};
}

/**
 * Suspend, réactive ou archive un commercial. Archivé : il ne peut plus se
 * connecter ; son historique (clients, commissions) est conservé.
 */
async function setSalesAgentStatus({db, auth, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const agentUid = text(data.agentUid, 128);
  const status = text(data.status, 20);
  const reason = text(data.reason, 300);
  if (!agentUid) {
    throw new AcquisitionError("invalid-argument", "Commercial manquant.");
  }
  if (status !== "active" && !reason) {
    throw new AcquisitionError("invalid-argument",
        "Indiquez le motif de la suspension ou de l'archivage.");
  }
  const agentRef = db.doc(`${COLLECTIONS.agents}/${agentUid}`);
  await db.runTransaction(async (tx) => {
    const agent = await tx.get(agentRef);
    if (!agent.exists) {
      throw new AcquisitionError("not-found", "Commercial introuvable.");
    }
    const from = agent.get("status");
    // Archivage rejoué (ex. désactivation du compte échouée) : on ne refait
    // que la désactivation, après la transaction.
    if (from === "archived" && status === "archived") return;
    assertTransition("agent", from, status);
    tx.update(agentRef, {status, status_reason: reason || null,
      status_updated_at: now(), updated_at: now()});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: `agent.${status}`, target: agentRef.path,
      details: {from, reason}});
  });
  if (status === "archived") await auth.updateUser(agentUid, {disabled: true});
  return {ok: true};
}

module.exports = {requireAdmin, createSalesAgent, updateSalesAgent,
  setSalesAgentStatus, payoutMethodOf};
