/**
 * Suivi en direct : étape « récupérée », position du livreur, lecture.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/delivery_tracking.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const t = require("./delivery_tracking");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const data = {orderId: "o1"};

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/client").set({role: "User"});
  await db.doc("User/shop").set({role: "Seller", display_name: "Chez Mado"});
  await db.doc("User/l1").set({role: "Deliver", display_name: "Jo",
    photo_url: "https://x/jo.jpg"});
  await db.doc("User/l2").set({role: "Deliver"});
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("Orders/o1").set({status: "encours",
    user_ref: db.doc("User/client"), seller_ref: db.doc("User/shop"),
    deliverer_ref: "l1", deliver_reference: db.doc("User/l1"),
    delivery_zone: "Bacongo", delivery_location: "Rue 12",
    taken_at: new Date()});
});

test("le livreur récupère la commande puis partage sa position", async () => {
  await t.deliveryStep({db, uid: "l1", data: {...data, step: "picked_up"}});
  await t.deliveryPosition({db, uid: "l1",
    data: {...data, lat: -4.28, lng: 15.25, accuracy: 12}});
  const r = await t.deliveryTracking({db, uid: "client", data});
  assert.strictEqual(r.status, "encours");
  assert.ok(r.pickedUpAt);
  assert.deepStrictEqual([r.position.lat, r.position.lng], [-4.28, 15.25]);
  assert.strictEqual(r.deliverer.name, "Jo");
  assert.strictEqual(r.shop.name, "Chez Mado");
  assert.strictEqual(r.zone, "Bacongo");
  // Le commerce et l'admin voient aussi le suivi.
  assert.ok((await t.deliveryTracking({db, uid: "shop", data})).position);
  assert.ok((await t.deliveryTracking({db, uid: "admin", data})).position);
});

test("contrôles : autre livreur, course terminée, position fausse",
    async () => {
      await assert.rejects(t.deliveryPosition({db, uid: "l2",
        data: {...data, lat: -4, lng: 15}}), {code: "permission-denied"});
      await assert.rejects(t.deliveryPosition({db, uid: "l1",
        data: {...data, lat: "x", lng: 15}}), {code: "invalid-argument"});
      await assert.rejects(t.deliveryTracking({db, uid: "l2", data}),
          {code: "not-found"});
      await t.deliveryPosition({db, uid: "l1",
        data: {...data, lat: -4.2, lng: 15.2}});
      await db.doc("Orders/o1").update({status: "Livrer"});
      await assert.rejects(t.deliveryStep({db, uid: "l1",
        data: {...data, step: "picked_up"}}), {code: "failed-precondition"});
      // Livrée : la position n'est plus montrée.
      assert.strictEqual((await t.deliveryTracking({db, uid: "client", data}))
          .position, null);
    });
