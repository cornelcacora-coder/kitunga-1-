/**
 * Paiement Airtel Money à côté de MTN MoMo (opérateurs simulés,
 * KITUNGA_MOMO_MOCK=1).
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/wallet.emulator.test.js"
 */
process.env.KITUNGA_MOMO_MOCK = "1";
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const wallet = require("./wallet");
const {startPayment, confirmPayment, refundOrder} = require("./payments");
const {startSubscription, confirmSubscription} = require("./subscriptions");
const {reconcilePending} = require("./reconcile");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const momo = wallet;

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/buyer").set({role: "User",
    subscribe_close_at: new Date(Date.now() + 86400000)});
  await db.doc("User/seller").set({role: "Seller"});
  await db.doc("Product/p1").set({name: "Pain", sale_price: 500, price: 500,
    quantity: 10, on_sale: true});
  await db.doc("Cart/c1").set({user_ref: db.doc("User/buyer"),
    seller_ref: db.doc("User/seller"), product_ref: db.doc("Product/p1"),
    quantity: 2, options: "", is_ordered: false});
});

const start = (operator, phone) => startPayment({db, momo, uid: "buyer",
  sellerPath: "User/seller", zone: "Bacongo", deliveryLocation: "Rue 1",
  phone, operator});

test("opérateur et numéro : contrôles clairs", () => {
  assert.strictEqual(wallet.operatorOf("Airtel Money"), "Airtel");
  assert.strictEqual(wallet.operatorOf(undefined), "MTN");
  assert.strictEqual(wallet.checkPhone("05 123 45 67", "Airtel"),
      "242051234567");
  assert.strictEqual(wallet.checkPhone("+242 04 123 45 67", "Airtel"),
      "242041234567");
  assert.throws(() => wallet.checkPhone("061234567", "Airtel"),
      /numéro MTN MoMo/);
  assert.throws(() => wallet.checkPhone("051234567", "MTN"),
      /numéro Airtel Money/);
  assert.throws(() => wallet.checkPhone("12", "MTN"), /invalide/);
});

test("Airtel non configuré : le client est invité à payer avec MTN", () => {
  process.env.KITUNGA_MOMO_MOCK = "0";
  try {
    assert.throws(() => wallet.checkPhone("051234567", "Airtel"),
        /pas encore disponible/);
    assert.strictEqual(wallet.checkPhone("061234567", "MTN"),
        "242061234567");
  } finally {
    process.env.KITUNGA_MOMO_MOCK = "1";
  }
});

test("commande payée par Airtel Money, puis remboursée", async () => {
  const s = await start("Airtel", "05 123 45 67");
  assert.match(s.referenceId, /^AM[0-9A-F]{20}$/);
  const pay = await db.doc(`Paiement/${s.referenceId}`).get();
  assert.strictEqual(pay.get("operator"), "Airtel");
  assert.strictEqual(pay.get("payer_phone"), "242051234567");
  assert.strictEqual(pay.get("amount"), 2000);

  const r = await confirmPayment({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  assert.strictEqual(r.status, "paid");
  const orderRef = db.doc(r.orderPath);
  await orderRef.update({status: "Refusée", refund_needed: true});
  const refund = await refundOrder({db, momo, orderRef,
    order: (await orderRef.get()).data(), previousStatus: "En attente"});
  assert.strictEqual(refund, `REMB-${s.referenceId}`);
  assert.strictEqual((await orderRef.get()).get("refund_status"), "Envoyé");
});

test("MTN reste le choix par défaut", async () => {
  const s = await start(undefined, "06 123 45 67");
  assert.doesNotMatch(s.referenceId, /^AM/);
  assert.strictEqual((await db.doc(`Paiement/${s.referenceId}`).get())
      .get("operator"), "MTN");
});

test("abonnement Airtel, terminé aussi par le rattrapage", async () => {
  const s = await startSubscription({db, momo, uid: "buyer",
    plan: "quarterly", phone: "051234567", operator: "Airtel"});
  assert.match(s.referenceId, /^AM/);
  assert.strictEqual(await reconcilePending({db, momo}), 1);
  const again = await confirmSubscription({db, momo, uid: "buyer",
    referenceId: s.referenceId});
  assert.strictEqual(again.status, "paid");
});
