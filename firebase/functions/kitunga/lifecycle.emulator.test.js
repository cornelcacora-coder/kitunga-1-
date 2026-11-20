/**
 * Cycle de vie : statuts calculés, historique, disponibilité, purge GPS.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/lifecycle.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const lc = require("./lifecycle");
const ev = require("./order_events");
const tr = require("./delivery_tracking");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const order = db.doc("Orders/o1");

/** Écrit puis rejoue le déclencheur, comme en production. */
async function write(fields) {
  const before = await order.get();
  // Sans champ : on rejoue seulement le déclencheur.
  if (!before.exists) await order.set(fields);
  else if (Object.keys(fields).length) await order.update(fields);
  let after = await order.get();
  await lc.onOrderLifecycle({before, after});
  // Seconde exécution (provoquée par sa propre mise à jour) : sans effet.
  const again = await order.get();
  assert.deepStrictEqual(await lc.onOrderLifecycle({before: after,
    after: again}), {changed: false});
  after = await order.get();
  return after;
}

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/client").set({role: "User"});
  await db.doc("User/shop").set({role: "Seller"});
  await db.doc("User/l1").set({role: "Deliver"});
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/support").set({role: "Support"});
  await db.doc("User/autre").set({role: "User"});
});

test("statuts calculés et historique d'un parcours complet", async () => {
  let o = await write({status: "En attente", payment_status: "Réussi",
    user_ref: db.doc("User/client"), seller_ref: db.doc("User/shop")});
  assert.strictEqual(o.get("delivery_status"), "not_ready");
  assert.strictEqual(o.get("finance_status"), "paid");
  await write({status: "En préparation"});
  o = await write({status: "Pret"});
  assert.strictEqual(o.get("delivery_status"), "searching");
  o = await write({status: "encours", deliverer_ref: "l1",
    deliver_reference: db.doc("User/l1"),
    status_actor: {uid: "l1", role: "Deliver", at: 1}});
  assert.strictEqual(o.get("delivery_status"), "to_pickup");
  await tr.deliveryStep({db, uid: "l1", data: {orderId: "o1",
    step: "picked_up"}});
  o = await write({});
  assert.strictEqual(o.get("delivery_status"), "to_customer");
  await tr.deliveryStep({db, uid: "l1", data: {orderId: "o1",
    step: "arrived"}});
  o = await write({});
  assert.strictEqual(o.get("delivery_status"), "arrived");
  o = await write({status: "Livrer"});
  assert.strictEqual(o.get("delivery_status"), "delivered");

  const h = (await lc.orderHistoryFor({db, uid: "admin",
    data: {orderId: "o1"}})).history.filter((e) => e.field === "status");
  assert.deepStrictEqual(h.map((e) => e.to),
      ["En attente", "En préparation", "Pret", "encours", "Livrer"]);
  assert.deepStrictEqual(h.map((e) => e.byRole),
      ["System", "Seller", "Seller", "Deliver", "Deliver"]);
  assert.strictEqual(h[3].byUid, "l1");
  // Auteur resté d'un changement précédent : pas réattribué.
  assert.strictEqual(h[4].byUid, null);
  // Accès : acteurs de la commande, admin, support ; pas les autres.
  assert.ok(await lc.orderHistoryFor({db, uid: "client",
    data: {orderId: "o1"}}));
  assert.ok(await lc.orderHistoryFor({db, uid: "support",
    data: {orderId: "o1"}}));
  await assert.rejects(lc.orderHistoryFor({db, uid: "autre",
    data: {orderId: "o1"}}), {code: "not-found"});
});

test("statut financier : remboursement", () => {
  assert.strictEqual(lc.financeStatusOf({payment_status: "Réussi",
    refund_needed: true}), "refund_pending");
  assert.strictEqual(lc.financeStatusOf({refund_needed: true,
    refund_status: "Envoyé"}), "refunded");
  assert.strictEqual(lc.financeStatusOf({refund_status: "Échec"}),
      "refund_manual");
  assert.strictEqual(lc.deliveryStatusOf({status: "Annulée"}), "cancelled");
  assert.strictEqual(lc.deliveryStatusOf({status: "Non Reçu"}), "disputed");
});

test("arrivé : seulement après la récupération", async () => {
  await order.set({status: "encours", deliverer_ref: "l1"});
  await assert.rejects(tr.deliveryStep({db, uid: "l1", data: {orderId: "o1",
    step: "arrived"}}), {code: "failed-precondition"});
});

test("disponibilité : en pause = plus de propositions, historisée",
    async () => {
      await ev.setDelivererStatus({db, uid: "l1", data: {state: "on"}});
      await ev.setDelivererStatus({db, uid: "l1", data: {state: "pause"}});
      const u = await db.doc("User/l1").get();
      assert.strictEqual(u.get("delivery_state"), "pause");
      assert.strictEqual(u.get("delivery_available"), false);
      const log = (await db.collection("DelivererAvailability").get()).docs
          .map((d) => d.get("state")).sort();
      assert.deepStrictEqual(log, ["on", "pause"]);
      await assert.rejects(ev.setDelivererStatus({db, uid: "l1",
        data: {state: "dodo"}}), {code: "invalid-argument"});
    });

test("purge des positions des courses terminées", async () => {
  const old = new Date(Date.now() - 30 * 3600 * 1000);
  await db.doc("Orders/fini").set({status: "Livrer"});
  await db.doc("Orders/route").set({status: "encours"});
  await db.doc("DeliveryTracking/fini").set({lat: 1, lng: 1, at: old});
  await db.doc("DeliveryTracking/route").set({lat: 1, lng: 1, at: old});
  assert.deepStrictEqual(await lc.purgeOldPositions({db}), {removed: 1});
  assert.ok((await db.doc("DeliveryTracking/route").get()).exists);
});
