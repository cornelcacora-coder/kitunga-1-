/**
 * Abonnement client, payé par MTN MoMo depuis la page web Kitunga
 * (web/abonnement.html), jamais dans l'application Android (règle Google
 * Play sur les services numériques). L'abonnement est obligatoire pour
 * commander : User.subscribe_close_at doit être dans le futur.
 */
const {PaymentError} = require("./errors");

const DAY = 24 * 60 * 60 * 1000;

// Libellés identiques aux anciennes valeurs de User.subscribe_type.
const PLANS = {
  monthly: {label: "Mensuel - 250F", price: 250, days: 30},
  quarterly: {label: "Trimestriel - 500 F", price: 500, days: 90},
  annual: {label: "Annuel - 1000 F", price: 1000, days: 365},
};

function toDate(v) {
  if (!v) return null;
  return typeof v.toDate === "function" ? v.toDate() : new Date(v);
}

/** Rôles qui commandent sans abonnement (comptes créés par l'admin). */
const ROLES_WITHOUT_SUBSCRIPTION = ["Seller", "Deliver", "Admin"];

/**
 * Droit de commander : les rôles listés ci-dessus, ou un client (rôle User)
 * abonné. Tout autre rôle (Guest, Commercial, rôle inconnu) est refusé.
 */
function subscriptionActive(user, now = new Date()) {
  if (!user || !user.exists) return false;
  const role = user.get("role") || "User";
  if (ROLES_WITHOUT_SUBSCRIPTION.includes(role)) return true;
  if (role !== "User") return false;
  const until = toDate(user.get("subscribe_close_at"));
  return until != null && until > now;
}

/** Demande MTN pour la formule choisie. Renvoie {referenceId, amount}. */
async function startSubscription({db, momo, uid, plan, phone}) {
  if (!uid) throw new PaymentError("unauthenticated", "Connexion requise.");
  const p = PLANS[plan];
  if (!p) throw new PaymentError("invalid-argument", "Formule inconnue.");
  const payer = momo.normalizePhone(phone);
  if (!payer) {
    throw new PaymentError("invalid-argument", "Numéro MTN invalide.");
  }
  const user = await db.doc(`User/${uid}`).get();
  if (!user.exists) {
    throw new PaymentError("failed-precondition",
        "Créez d'abord votre compte dans l'application Kitunga.");
  }
  const reference = `ABO-${Date.now().toString(36).toUpperCase()}`;
  const referenceId = await momo.requestToPay({
    amount: p.price, phone: payer, externalId: reference,
    note: `abonnement ${p.label}`,
  });
  await db.doc(`Paiement/${referenceId}`).set({
    kind: "subscription",
    plan,
    status: "En attente",
    reference_id: referenceId,
    order_id: reference,
    amount: p.price,
    user_ref: user.ref,
    payer_phone: payer,
    operator: "MTN",
    created_at: new Date(),
  });
  return {referenceId, amount: p.price, label: p.label};
}

/**
 * Vérifie le paiement auprès de MTN ; s'il est réussi, prolonge
 * l'abonnement (à partir de la fin actuelle s'il est encore actif).
 * Renvoie {status: 'pending'|'failed'|'paid', until?}.
 */
async function confirmSubscription({db, momo, uid, referenceId}) {
  const payRef = db.doc(`Paiement/${referenceId}`);
  const pay = await payRef.get();
  if (!pay.exists || pay.get("kind") !== "subscription" ||
      pay.get("user_ref").id !== uid) {
    throw new PaymentError("not-found", "Paiement introuvable.");
  }
  if (pay.get("status") === "Réussi") {
    return {status: "paid", until: toDate(pay.get("subscription_until"))
        .toISOString()};
  }
  if (pay.get("status") === "Echec") return {status: "failed"};

  const mtn = await momo.paymentStatus(referenceId);
  if (mtn.status === "FAILED") {
    await payRef.update({status: "Echec", message: mtn.reason || ""});
    return {status: "failed", reason: mtn.reason};
  }
  if (mtn.status !== "SUCCESSFUL") return {status: "pending"};

  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(payRef);
    if (fresh.get("status") === "Réussi") {
      return {status: "paid", until: toDate(fresh.get("subscription_until"))
          .toISOString()};
    }
    const userRef = fresh.get("user_ref");
    const user = await tx.get(userRef);
    const p = PLANS[fresh.get("plan")];
    const now = new Date();
    const current = toDate(user.get("subscribe_close_at"));
    const from = current && current > now ? current : now;
    const until = new Date(from.getTime() + p.days * DAY);
    tx.update(userRef, {
      is_subscribed: true,
      subscribe_type: p.label,
      subscribe_close_at: until,
    });
    tx.update(payRef, {status: "Réussi", subscription_until: until});
    return {status: "paid", until: until.toISOString()};
  });
}

module.exports = {PLANS, ROLES_WITHOUT_SUBSCRIPTION, subscriptionActive, startSubscription,
  confirmSubscription};
