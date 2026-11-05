/**
 * Paiements restés « En attente » (client parti avant la confirmation) :
 * on revérifie auprès de MTN et on termine l'abonnement ou la commande.
 */
const {confirmPayment} = require("./payments");
const {confirmSubscription} = require("./subscriptions");

const MAX_AGE = 24 * 60 * 60 * 1000;

async function reconcilePending({db, momo, now = new Date()}) {
  const snap = await db.collection("Paiement")
      .where("status", "==", "En attente").get();
  let done = 0;
  for (const doc of snap.docs) {
    const created = doc.get("created_at");
    const at = created && created.toDate ? created.toDate() : null;
    const userRef = doc.get("user_ref");
    if (!at || now - at > MAX_AGE || !userRef) continue;
    const args = {db, momo, uid: userRef.id, referenceId: doc.id};
    try {
      const r = doc.get("kind") === "subscription" ?
        await confirmSubscription(args) :
        doc.get("cart_ids") ? await confirmPayment(args) : null;
      if (r && r.status !== "pending") done++;
    } catch (e) {
      console.error(`Paiement ${doc.id}`, e);
    }
  }
  return done;
}

module.exports = {reconcilePending};
