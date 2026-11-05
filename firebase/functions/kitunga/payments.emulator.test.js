/**
 * Test du paiement contrôlé par le serveur, sur l'émulateur Firestore et
 * avec MTN simulé (KITUNGA_MOMO_MOCK=1). Lancement :
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/payments.emulator.test.js"
 */
process.env.KITUNGA_MOMO_MOCK = "1";
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const momo = require("./momo");
const {startPayment, confirmPayment, refundOrder} = require("./payments");
const {startSubscription, confirmSubscription} = require("./subscriptions");
const {reconcilePending} = require("./reconcile");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();

const burger = {
  name: "Burger", sale_price: 2500, price: 2500, quantity: 3, on_sale: true,
  options: [
    {name: "Taille", required: true, max: 1, choices: [
      {label: "Normal", price: 0}, {label: "Maxi", price: 1000}]},
    {name: "Suppléments", required: false, max: 2, choices: [
      {label: "Fromage", price: 300, stock: 5},
      {label: "Bacon", price: 500, stock: 1}]},
  ],
};

async function seed(cartOptions, quantity) {
  const all = await db.listCollections();
  for (const c of all) await db.recursiveDelete(c);
  await db.doc("User/buyer").set({role: "User",
    subscribe_close_at: new Date(Date.now() + 86400000)});
  await db.doc("User/seller").set({role: "Seller"});
  await db.doc("Product/p1").set(burger);
  await db.doc("Cart/c1").set({
    user_ref: db.doc("User/buyer"), seller_ref: db.doc("User/seller"),
    product_ref: db.doc("Product/p1"), quantity, options: cartOptions,
    price: 1, is_ordered: false, // prix « client » volontairement faux
  });
}

const start = () => startPayment({db, momo, uid: "buyer",
  sellerPath: "User/seller", zone: "Talangaï", deliveryLocation: "Rue 1",
  phone: "06 123 45 67"});

test("variante épuisée : paiement refusé avant MTN", async () => {
  await seed("Taille : Maxi · Suppléments : Bacon", 2);
  await assert.rejects(start, /Stock insuffisant/);
});

test("paiement réussi : commande, stock et panier", async () => {
  await seed("Taille : Maxi · Suppléments : Fromage", 2);
  const s = await start();
  assert.equal(s.amount, (2500 + 1000 + 300) * 2 + 1500);

  const r = await confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  assert.equal(r.status, "paid");

  const order = (await db.doc(r.orderPath).get()).data();
  assert.equal(order.total_amount, s.amount);
  assert.equal(order.status, "En attente");
  assert.equal(order.payment_status, "Réussi");

  const p = (await db.doc("Product/p1").get()).data();
  assert.equal(p.quantity, 1); // 3 - 2
  assert.equal(p.options[1].choices[0].stock, 3); // Fromage 5 - 2
  assert.equal(p.options[1].choices[1].stock, 1); // Bacon inchangé

  assert.equal((await db.doc("Cart/c1").get()).exists, false);
  const items = await db.collection("OrderItems")
      .where("order_ref", "==", order.order_unique_reference).get();
  assert.equal(items.size, 1);
  assert.equal(items.docs[0].get("options"),
      "Taille : Maxi · Suppléments : Fromage");

  // Deuxième confirmation : pas de commande en double.
  const again = await confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  assert.equal(again.orderPath, r.orderPath);
  assert.equal((await db.collection("Orders").get()).size, 1);
});

test("stock pris entre-temps : payé, marqué à rembourser", async () => {
  await seed("Taille : Normal", 2);
  const s = await start();
  await db.doc("Product/p1").update({quantity: 1});
  const r = await confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  assert.equal(r.status, "paid_refund");
  const pay = (await db.doc(`Paiement/${s.referenceId}`).get()).data();
  assert.equal(pay.refund_needed, true);
  assert.equal((await db.collection("Orders").get()).size, 0);
});

test("commande refusée : remboursée une seule fois", async () => {
  await seed("Taille : Normal", 1);
  const s = await start();
  const r = await confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  const orderRef = db.doc(r.orderPath);
  await orderRef.update({status: "Refusée", refund_needed: true});
  const order = (await orderRef.get()).data();
  const first = await refundOrder({db, momo, orderRef, order,
    previousStatus: "En attente"});
  assert.ok(first);
  const second = await refundOrder({db, momo, orderRef, order,
    previousStatus: "En attente"});
  assert.equal(second, null);
  assert.equal((await orderRef.get()).get("refund_status"), "Envoyé");
});

/** Commande payée par le serveur puis arrêtée, prête à être remboursée. */
async function paidAndStoppedOrder() {
  await seed("Taille : Normal", 1);
  const s = await start();
  const r = await confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  const orderRef = db.doc(r.orderPath);
  await orderRef.update({status: "Annulée", refund_needed: true});
  return {orderRef, order: (await orderRef.get()).data(),
    referenceId: s.referenceId};
}

async function assertNotRefunded(orderRef, reason) {
  const after = (await orderRef.get()).data();
  assert.equal(after.refund_status, "À traiter manuellement");
  assert.match(after.refund_error, reason);
}

// MTN simulé qui échoue si un virement est tenté.
const noTransfer = (status = {status: "SUCCESSFUL"}) => ({
  paymentStatus: async () => status,
  transfer: async () => assert.fail("virement interdit"),
});

test("remboursement : commande déjà livrée refusée", async () => {
  const {orderRef, order} = await paidAndStoppedOrder();
  const r = await refundOrder({db, momo: noTransfer(), orderRef, order,
    previousStatus: "Livrer"});
  assert.equal(r, null);
  await assertNotRefunded(orderRef, /déjà acceptée/);
});

test("remboursement : fausse commande sur un vrai paiement refusée", async () => {
  const {order} = await paidAndStoppedOrder();
  const fake = db.collection("Orders").doc();
  await fake.set({...order, total_amount: 1000000});
  const r = await refundOrder({db, momo: noTransfer(), orderRef: fake,
    order: (await fake.get()).data(), previousStatus: "En attente"});
  assert.equal(r, null);
  await assertNotRefunded(fake, /ne correspond pas/);
});

test("remboursement : fausse trace de paiement refusée", async () => {
  await seed("Taille : Normal", 1);
  const fake = db.collection("Orders").doc();
  await db.doc("Paiement/forged").set({status: "En attente", amount: 1000000,
    payer_phone: "242060000000", order_ref: fake});
  await fake.set({status: "Annulée", refund_needed: true,
    total_amount: 1000000, payment_reference: "forged"});
  const r = await refundOrder({db, momo: noTransfer(), orderRef: fake,
    order: (await fake.get()).data(), previousStatus: "En attente"});
  assert.equal(r, null);
  await assertNotRefunded(fake, /non réussi/);
});

test("remboursement : montant différent chez MTN refusé", async () => {
  const {orderRef, order} = await paidAndStoppedOrder();
  const r = await refundOrder({db,
    momo: noTransfer({status: "SUCCESSFUL", amount: "1"}), orderRef, order,
    previousStatus: "En attente"});
  assert.equal(r, null);
  await assertNotRefunded(orderRef, /Montant MTN/);
});

test("remboursement : paiement non confirmé par MTN refusé", async () => {
  const {orderRef, order} = await paidAndStoppedOrder();
  const r = await refundOrder({db, momo: noTransfer({status: "FAILED"}),
    orderRef, order, previousStatus: "En attente"});
  assert.equal(r, null);
  await assertNotRefunded(orderRef, /non confirmé/);
});

test("visiteur : ne peut pas commander", async () => {
  await seed("Taille : Normal", 1);
  await db.doc("User/buyer").update({role: "Guest"});
  await assert.rejects(start, /abonnement Kitunga actif/);
});

test("paiement refusé par MTN : échec enregistré", async () => {
  await seed("Taille : Normal", 1);
  const s = await start();
  process.env.KITUNGA_MOMO_MOCK_STATUS = "FAILED";
  const r = await confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  delete process.env.KITUNGA_MOMO_MOCK_STATUS;
  assert.equal(r.status, "failed");
  assert.equal((await db.doc(`Paiement/${s.referenceId}`).get())
      .get("status"), "Echec");
});

test("abonnement expiré : commande refusée", async () => {
  await seed("Taille : Normal", 1);
  await db.doc("User/buyer").update({subscribe_close_at: new Date(0)});
  await assert.rejects(start, /abonnement Kitunga actif/);
});

test("abonnement payé : actif, prolongé, sans double comptage", async () => {
  await seed("Taille : Normal", 1);
  await db.doc("User/buyer").update({subscribe_close_at: new Date(0)});
  const s = await startSubscription({db, momo, uid: "buyer",
    plan: "monthly", phone: "065551234"});
  assert.equal(s.amount, 250);
  const r = await confirmSubscription({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  assert.equal(r.status, "paid");
  const until = (await db.doc("User/buyer").get())
      .get("subscribe_close_at").toDate();
  const days = (until - Date.now()) / 86400000;
  assert.ok(days > 29.9 && days <= 30, `jours : ${days}`);
  // Confirmer deux fois ne prolonge pas deux fois.
  await confirmSubscription({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  assert.equal((await db.doc("User/buyer").get())
      .get("subscribe_close_at").toDate().getTime(), until.getTime());
  // Un renouvellement s'ajoute à la fin actuelle.
  const s2 = await startSubscription({db, momo, uid: "buyer",
    plan: "annual", phone: "065551234"});
  await confirmSubscription({db, momo, uid: "buyer",
    referenceId: s2.referenceId});
  const until2 = (await db.doc("User/buyer").get())
      .get("subscribe_close_at").toDate();
  assert.equal(until2 - until, 365 * 86400000);
  assert.equal((await db.doc("User/buyer").get()).get("subscribe_type"),
      "Annuel - 1000 F");
  // Le paiement d'abonnement ne peut pas servir à créer une commande.
  await assert.rejects(confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId}), /introuvable/);
  await start(); // abonné : la commande passe
});

test("reconcile : abonnement et commande en attente", async () => {
  await seed("Taille : Normal", 1);
  await startSubscription({db, momo, uid: "buyer", plan: "monthly",
    phone: "065551234"});
  await start();
  assert.equal(await reconcilePending({db, momo}), 2);
  assert.equal((await db.collection("Orders").get()).size, 1);
  const pending = await db.collection("Paiement")
      .where("status", "==", "En attente").get();
  assert.equal(pending.size, 0);
  assert.equal(await reconcilePending({db, momo}), 0);
});
