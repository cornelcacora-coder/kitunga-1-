/**
 * Position exacte : frais de porte à porte, repli sur le quartier,
 * enregistrement dans la commande, point de collecte du livreur.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/exact_location.emulator.test.js"
 */
process.env.KITUNGA_MOMO_MOCK = "1";
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const dp = require("./delivery_pricing");
const sp = require("./seller_pro");
const wallet = require("./wallet");
const {startPayment, confirmPayment} = require("./payments");
const dispatch = require("./dispatch");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
// Deux points du même quartier (Bacongo), à environ 1,5 km.
const shopAt = {lat: -4.2805, lng: 15.2560};
const homeAt = {lat: -4.2930, lng: 15.2560};

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/shop").set({role: "Seller", shop_zone: "Bacongo"});
  await db.doc("User/buyer").set({role: "User",
    subscribe_close_at: new Date(Date.now() + 86400000)});
  await db.doc("Product/p1").set({name: "Pain", sale_price: 500,
    quantity: 5, on_sale: true, seller_ref: db.doc("User/shop")});
  await db.doc("Cart/c1").set({user_ref: db.doc("User/buyer"),
    seller_ref: db.doc("User/shop"), product_ref: db.doc("Product/p1"),
    quantity: 1, options: "", is_ordered: false});
});

test("points valides seulement à Brazzaville", () => {
  assert.deepStrictEqual(dp.pointOf(homeAt), homeAt);
  assert.strictEqual(dp.pointOf({lat: 48.85, lng: 2.35}), null); // Paris
  assert.strictEqual(dp.pointOf({lat: "x", lng: 15.2}), null);
  assert.strictEqual(dp.pointOf(null), null);
});

test("frais : porte à porte quand les deux positions sont connues", () => {
  const exact = dp.computeFee({shopZone: "Bacongo", clientZone: "Bacongo",
    shopPoint: shopAt, clientPoint: homeAt});
  assert.strictEqual(exact.exact, true);
  assert.ok(exact.km > 1.5 && exact.km < 2.5); // ≈ 1,4 km × 1,3
  // Même quartier sans positions : distance nulle entre centres.
  const zones = dp.computeFee({shopZone: "Bacongo", clientZone: "Bacongo"});
  assert.strictEqual(zones.km, 0);
  assert.strictEqual(zones.exact, false);
  // Kintélé → position exacte à Bacongo : distance réelle.
  const mixed = dp.computeFee({shopZone: "Kintélé", clientZone: "Bacongo",
    clientPoint: homeAt});
  assert.strictEqual(mixed.exact, false);
  assert.ok(mixed.km > 20);
});

test("le commerçant enregistre sa position ; refus hors de la ville",
    async () => {
      await assert.rejects(sp.sellerSetLocation({db, uid: "shop",
        data: {lat: 5.3, lng: -4.0}}), {code: "invalid-argument"});
      await sp.sellerSetLocation({db, uid: "shop", data: shopAt});
      assert.strictEqual((await db.doc("User/shop").get())
          .get("shop_point").lat, shopAt.lat);
      await assert.rejects(sp.sellerSetLocation({db, uid: "buyer",
        data: shopAt}), {code: "permission-denied"});
    });

test("paiement : positions gardées dans la commande ; collecte du livreur",
    async () => {
      await sp.sellerSetLocation({db, uid: "shop", data: shopAt});
      const q = await dp.deliveryQuote({db, uid: "buyer", data: {
        sellerPath: "User/shop", zone: "Bacongo", point: homeAt}});
      assert.strictEqual(q.exact, true);
      const s = await startPayment({db, momo: wallet, uid: "buyer",
        sellerPath: "User/shop", zone: "Bacongo", phone: "061234567",
        deliveryPoint: homeAt});
      assert.strictEqual(s.fee, q.fee);
      const r = await confirmPayment({db, momo: wallet, uid: "buyer",
        referenceId: s.referenceId});
      const o = await db.doc(r.orderPath).get();
      assert.deepStrictEqual(o.get("delivery_point"), homeAt);
      assert.strictEqual(o.get("shop_point").lat, shopAt.lat);
      // Le livreur le plus proche du commerce (position exacte) est choisi.
      await db.doc(r.orderPath).update({status: "Pret"});
      await db.doc("User/pres").set({role: "Deliver",
        delivery_available: true,
        last_position: {lat: -4.2806, lng: 15.2561, at: new Date()}});
      await db.doc("User/loin").set({role: "Deliver",
        delivery_available: true,
        last_position: {lat: -4.20, lng: 15.30, at: new Date()}});
      const ranked = await dispatch.rankDeliverers({db,
        order: await db.doc(r.orderPath).get(), settings: dispatch.DEFAULTS});
      assert.strictEqual(ranked[0].user.id, "pres");
      assert.match(ranked[0].reason, /0,0 km du commerce/);
    });
