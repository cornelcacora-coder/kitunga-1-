/**
 * Frais de livraison selon la distance commerce → client, tarif admin.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/delivery_pricing.emulator.test.js"
 */
process.env.KITUNGA_MOMO_MOCK = "1";
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const dp = require("./delivery_pricing");
const wallet = require("./wallet");
const {startPayment, confirmPayment} = require("./payments");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/buyer").set({role: "User",
    subscribe_close_at: new Date(Date.now() + 86400000)});
  await db.doc("User/shop").set({role: "Seller", shop_zone: "Kintélé"});
  await db.doc("User/old").set({role: "Seller"});
});

test("calcul : même quartier, loin, plafond, sans quartier du commerce",
    () => {
      assert.strictEqual(dp.computeFee({shopZone: "Bacongo",
        clientZone: "Bacongo"}).fee, 1000);
      const far = dp.computeFee({shopZone: "Kintélé", clientZone: "Bacongo"});
      assert.strictEqual(far.fee, 4200);
      assert.strictEqual(far.mode, "distance");
      assert.strictEqual(dp.computeFee({shopZone: "Kintélé",
        clientZone: "Bacongo", settings: {maximum: 3000}}).fee, 3000);
      // Ancien tarif : commerce sans quartier, ou mode « zones ».
      assert.deepStrictEqual(dp.computeFee({shopZone: "",
        clientZone: "Kintélé"}), {fee: 2000, km: null, mode: "zones", exact: false});
      assert.strictEqual(dp.computeFee({shopZone: "Kintélé",
        clientZone: "Bacongo", settings: {mode: "zones"}}).fee, 1000);
    });

test("l'admin règle le tarif ; le devis le suit", async () => {
  const r = await dp.adminDeliveryPricing({db, uid: "admin", data: {}});
  assert.strictEqual(r.settings.per_km, 150);
  await dp.adminDeliveryPricing({db, uid: "admin", data: {save: {
    ...r.settings, base: 0, per_km: 100}}});
  const q = await dp.deliveryQuote({db, uid: "buyer",
    data: {sellerPath: "User/shop", zone: "Bacongo"}});
  assert.strictEqual(q.fee, 2500); // 24,3 km × 100 F, arrondi
  assert.strictEqual(q.shopZone, "Kintélé");
  await assert.rejects(dp.adminDeliveryPricing({db, uid: "buyer",
    data: {}}), {code: "permission-denied"});
  await assert.rejects(dp.adminDeliveryPricing({db, uid: "admin",
    data: {save: {...r.settings, road_factor: 9}}}),
  {code: "invalid-argument"});
});

test("paiement : frais selon la distance, gardés à la confirmation",
    async () => {
      await db.doc("Product/p1").set({name: "Pain", sale_price: 500,
        price: 500, quantity: 10, on_sale: true});
      await db.doc("Cart/c1").set({user_ref: db.doc("User/buyer"),
        seller_ref: db.doc("User/shop"), product_ref: db.doc("Product/p1"),
        quantity: 1, options: "", is_ordered: false});
      const s = await startPayment({db, momo: wallet, uid: "buyer",
        sellerPath: "User/shop", zone: "Bacongo", phone: "061234567"});
      assert.strictEqual(s.fee, 4200);
      assert.strictEqual(s.amount, 4700);
      // L'admin change le tarif avant la confirmation : rien ne bouge.
      await db.doc("Settings/delivery_pricing").set({per_km: 1});
      const r = await confirmPayment({db, momo: wallet, uid: "buyer",
        referenceId: s.referenceId});
      assert.strictEqual(r.status, "paid");
      const o = await db.doc(r.orderPath).get();
      assert.strictEqual(o.get("delivery_fees"), 4200);
      assert.strictEqual(o.get("shop_zone"), "Kintélé");
      assert.strictEqual(o.get("delivery_km"), 24.3);
    });
