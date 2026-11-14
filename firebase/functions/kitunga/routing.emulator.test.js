/**
 * Itinéraires réels : Google (circulation), OpenRouteService, cache,
 * repli signalé comme estimation, heure d'arrivée du livreur.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/routing.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const routing = require("./routing");
const dp = require("./delivery_pricing");
const tracking = require("./delivery_tracking");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
// « _p~iF~ps|U_ulLnnqC_mqNvxq`@ » : 3 points (exemple de la doc Google).
const POLY = "_p~iF~ps|U_ulLnnqC_mqNvxq`@";
let calls = 0;
const google = {get: async (url, opts) => {
  calls++;
  assert.match(url, /directions\/json/);
  return {data: {status: "OK", routes: [{overview_polyline: {points: POLY},
    legs: [{distance: {value: 9600}, duration: {value: 1500},
      duration_in_traffic: opts.params.departure_time ?
        {value: 2100} : undefined}]}]}};
}};
const ors = {post: async () => {
  calls++;
  return {data: {routes: [{summary: {distance: 9100, duration: 1320},
    geometry: POLY}]}};
}};
const down = {get: async () => {
  throw new Error("réseau");
}};

test.beforeEach(async () => {
  calls = 0;
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
});
test.afterEach(() => {
  delete process.env.ROUTING_API_KEY;
});

test("polyligne décodée", () => {
  assert.deepStrictEqual(routing.decodePolyline(POLY),
      [[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]]);
});

test("sans clé : estimation signalée comme telle", async () => {
  process.env.ROUTING_API_KEY = "absent";
  const seller = await (async () => {
    await db.doc("User/s").set({role: "Seller", shop_zone: "Bacongo"});
    return db.doc("User/s").get();
  })();
  const r = await dp.feeFor(db, seller, "Mfilou");
  assert.strictEqual(r.source, "estimate");
});

test("Google : vraie route pour les frais, gardée pour le paiement",
    async () => {
      process.env.ROUTING_API_KEY = "google:CLE";
      await db.doc("User/s").set({role: "Seller", shop_zone: "Bacongo"});
      const seller = await db.doc("User/s").get();
      const r = await dp.feeFor(db, seller, "Mfilou", null, null, google);
      assert.strictEqual(r.source, "route");
      assert.strictEqual(r.km, 9.6);
      assert.strictEqual(r.fee, 2000); // 500 + 150 × 9,6 → 1940 → 2000
      // Même trajet ensuite (paiement) : même prix, sans nouvel appel.
      const again = await dp.feeFor(db, seller, "Mfilou", null, null, down);
      assert.deepStrictEqual(again, r);
      assert.strictEqual(calls, 1);
    });

test("OpenRouteService : vraie route, sans circulation", async () => {
  process.env.ROUTING_API_KEY = "ors:CLE";
  const r = await routing.route({db, from: [-4.28, 15.25],
    to: [-4.24, 15.21], http: ors});
  assert.strictEqual(r.km, 9.1);
  assert.strictEqual(r.minutes, 22);
  assert.strictEqual(r.traffic, false);
  assert.strictEqual(r.polyline.length, 3);
});

test("service en panne : pas de faux chiffre, l'appelant estime",
    async () => {
      process.env.ROUTING_API_KEY = "google:CLE";
      assert.strictEqual(await routing.route({db, from: [-4.28, 15.25],
        to: [-4.24, 15.21], http: down}), null);
    });

test("livreur : heure d'arrivée réelle avec circulation, vers le commerce " +
  "puis le client", async () => {
  process.env.ROUTING_API_KEY = "google:CLE";
  await db.doc("User/l1").set({role: "Deliver"});
  await db.doc("User/c1").set({role: "User"});
  await db.doc("Orders/o1").set({status: "encours", deliverer_ref: "l1",
    user_ref: db.doc("User/c1"), shop_zone: "Bacongo",
    delivery_zone: "Mfilou",
    delivery_point: {lat: -4.2470, lng: 15.2100}});
  const now = new Date();
  await tracking.deliveryPosition({db, uid: "l1", http: google, now,
    data: {orderId: "o1", lat: -4.27, lng: 15.27}});
  let t = await tracking.deliveryTracking({db, uid: "c1",
    data: {orderId: "o1"}});
  assert.strictEqual(t.route.target, "shop");
  assert.strictEqual(t.route.minutes, 35); // 2100 s avec circulation
  assert.strictEqual(t.route.traffic, true);
  // Moins d'une minute après : pas de nouveau calcul.
  await tracking.deliveryPosition({db, uid: "l1", http: google,
    now: new Date(now.getTime() + 20000),
    data: {orderId: "o1", lat: -4.271, lng: 15.27}});
  assert.strictEqual(calls, 1);
  // Commande récupérée : la destination devient le client, recalcul.
  await db.doc("Orders/o1").update({picked_up_at: new Date()});
  await tracking.deliveryPosition({db, uid: "l1", http: google,
    now: new Date(now.getTime() + 30000),
    data: {orderId: "o1", lat: -4.272, lng: 15.27}});
  t = await tracking.deliveryTracking({db, uid: "c1", data: {orderId: "o1"}});
  assert.strictEqual(t.route.target, "client");
  assert.strictEqual(calls, 2);
});
