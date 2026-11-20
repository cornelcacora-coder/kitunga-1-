/**
 * Supervision de l'admin : compteurs, livreurs, historique.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/supervision.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const sv = require("./supervision");
const ev = require("./order_events");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const now = new Date();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/c1").set({role: "User"});
  await db.doc("User/s1").set({role: "Seller"});
  await db.doc("User/l1").set({role: "Deliver", display_name: "Jo",
    delivery_available: true, delivery_state: "on",
    last_position: {lat: -4.2, lng: 15.2, at: now}});
  await db.doc("User/l2").set({role: "Deliver", delivery_state: "pause"});
  await db.doc("Orders/a").set({status: "En attente", created_at: now});
  await db.doc("Orders/b").set({status: "Pret", created_at: now});
  await db.doc("Orders/c").set({status: "encours", deliverer_ref: "l1",
    delivery_issue: {label: "Client absent"}, created_at: now});
  await db.doc("Orders/d").set({status: "Livrer", deliverer_ref: "l1",
    delivered_at: now, created_at: now});
  await db.doc("Orders/e").set({status: "Non Reçu", created_at: now});
  await db.doc("Tickets/t1").set({status: "open", priority: "urgent"});
  await db.doc("Ledger/x").set({account_uid: "l1", amount: 1000});
});

test("vue d'ensemble : acteurs, commandes, livreurs, incidents, tickets",
    async () => {
      const r = await sv.adminSupervision({db, uid: "admin", now});
      assert.deepStrictEqual([r.actors.User, r.actors.Seller,
        r.actors.Deliver], [1, 1, 2]);
      assert.strictEqual(r.orders.pending, 1);
      assert.strictEqual(r.orders.unassignedReady, 1);
      assert.strictEqual(r.orders.delivering, 1);
      assert.strictEqual(r.orders.deliveredToday, 1);
      assert.strictEqual(r.orders.disputed, 1);
      assert.strictEqual(r.orders.incidents, 1);
      assert.strictEqual(r.incidents[0].label, "Client absent");
      assert.deepStrictEqual(r.delivererStates, {on: 1, pause: 1, off: 0});
      const jo = r.deliverers.find((d) => d.uid === "l1");
      assert.strictEqual(jo.active, 1);
      assert.strictEqual(jo.deliveredToday, 1);
      assert.strictEqual(jo.positionFresh, true);
      assert.strictEqual(r.tickets.urgent, 1);
      assert.strictEqual(r.finance.owed, 1000);
      await assert.rejects(sv.adminSupervision({db, uid: "l1"}),
          {code: "permission-denied"});
    });

test("historique de disponibilité d'un livreur", async () => {
  await ev.setDelivererStatus({db, uid: "l2", data: {state: "on"}});
  await ev.setDelivererStatus({db, uid: "l2", data: {state: "off"}});
  await db.collection("Missions").add({deliverer_uid: "l2",
    status: "accepted"});
  await db.collection("Missions").add({deliverer_uid: "l2",
    status: "declined"});
  const h = await sv.adminDelivererHistory({db, uid: "admin",
    data: {uid: "l2"}});
  assert.strictEqual(h.history.length, 2);
  assert.strictEqual(h.missions.acceptanceRate, 50);
});
