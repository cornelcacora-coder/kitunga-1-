/**
 * Création d'un partenaire (commerçant ou livreur) par un administrateur.
 * Le compte est créé par le serveur : l'administrateur reste connecté à son
 * propre compte. Le rôle Admin ne s'attribue jamais ici, seulement depuis la
 * console Firebase.
 *
 * db et auth sont injectés (tests avec l'émulateur).
 */
const {PaymentError} = require("./errors");

const ROLES = ["Seller", "Deliver"];

const text = (v) => (typeof v === "string" ? v.trim() : "");

async function createPartner({db, auth, uid, data}) {
  if (!uid) throw new PaymentError("unauthenticated", "Connexion requise.");
  const caller = await db.doc(`User/${uid}`).get();
  if (!caller.exists || caller.get("role") !== "Admin") {
    throw new PaymentError("permission-denied",
        "Cette action est réservée aux administrateurs.");
  }
  const email = text(data.email);
  const password = typeof data.password === "string" ? data.password : "";
  if (!email) {
    throw new PaymentError("invalid-argument",
        "Veuillez renseigner l'adresse email.");
  }
  if (password.length < 6) {
    throw new PaymentError("invalid-argument",
        "Le mot de passe doit comporter au moins 6 caractères.");
  }
  if (!ROLES.includes(data.role)) {
    throw new PaymentError("invalid-argument",
        "Choisissez le type de partenaire : vendeur ou livreur.");
  }

  let created;
  try {
    created = await auth.createUser({email, password,
      displayName: text(data.displayName) || undefined});
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new PaymentError("already-exists",
          "Cette adresse email est déjà associée à un compte existant.");
    }
    if (e.code === "auth/invalid-email") {
      throw new PaymentError("invalid-argument", "Adresse email invalide.");
    }
    if (e.code === "auth/invalid-password") {
      throw new PaymentError("invalid-argument", "Mot de passe invalide.");
    }
    throw e;
  }

  // Mêmes champs qu'avant la création côté serveur.
  try {
    await db.doc(`User/${created.uid}`).set({
      uid: created.uid,
      created_time: new Date(),
      role: data.role,
      email,
      display_name: text(data.displayName),
      phone_number: text(data.phoneNumber),
      category: text(data.category) || "Vendeur",
      verified: data.verified === true,
      bio: text(data.bio),
      Horraire: text(data.horraire),
      is_subscribed: true,
      subscribe_type: text(data.subscribeType),
    });
  } catch (e) {
    // Pas de compte de connexion sans profil.
    await auth.deleteUser(created.uid).catch(() => {});
    throw e;
  }
  return {uid: created.uid};
}

module.exports = {createPartner};
