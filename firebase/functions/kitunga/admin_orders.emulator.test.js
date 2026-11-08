/**
 * Actions admin sur les commandes.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/admin_orders.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const orders = require("./admin_orders");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const NOW = new Date(Date.UTC(2026, 10, 8, 12));
const daysAgo = (n) => new Date(NOW.getTime() - n * 86400000);
const order = async (id) => (await db.doc(`Orders/${id}`).get()).data();
const logs = async () => (await db.collection("audit_logs").get()).docs
    .map((d) => d.get("action")).sort();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/marie").set({role: "User"});
  await db.doc("User/jean").set({role: "Deliver", display_name: "Jean"});
  await db.doc("User/off").set({role: "Deliver", account_status: "suspended"});
  await db.doc("Orders/paid").set({status: "En attente",
    payment_status: "Réussi", created_at: daysAgo(5)});
  await db.doc("Orders/free").set({status: "En préparation",
    created_at: daysAgo(1)});
  await db.doc("Orders/ready").set({status: "Pret", created_at: daysAgo(1)});
  await db.doc("Orders/going").set({status: "encours", created_at: daysAgo(1),
    deliver_reference: db.doc("User/jean"), deliverer_ref: "jean"});
  await db.doc("Orders/done").set({status: "Livrer", created_at: daysAgo(3)});
  await db.doc("Orders/old").set({status: "", created_at: daysAgo(10)});
  await db.doc("Orders/new").set({status: "En attente",
    created_at: daysAgo(0.5)});
});

test("réservé à l'admin", async () => {
  for (const uid of ["marie", "jean", null]) {
    await assert.rejects(orders.adminOrderAction({db, uid, data: {
      orderId: "paid", action: "cancel", reason: "x"}}),
    /administrateurs|Connexion requise/);
    await assert.rejects(orders.closeStaleOrders({db, uid, data: {days: 2,
      reason: "x"}}), /administrateurs|Connexion requise/);
  }
  assert.deepStrictEqual(await logs(), []);
});

test("annuler : motif obligatoire, remboursement si payée", async () => {
  await assert.rejects(orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "paid", action: "cancel"}}), /motif/);
  const r = await orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "paid", action: "cancel", reason: "Commerce fermé"}});
  assert.deepStrictEqual(r, {status: "Annulée", refundNeeded: true});
  const o = await order("paid");
  assert.strictEqual(o.status, "Annulée");
  assert.strictEqual(o.refund_needed, true);
  assert.strictEqual(o.cancel_reason, "Commerce fermé");
  assert.strictEqual(o.cancelled_by, "admin");
  assert.ok(o.status_updated_at);
  // Non payée : pas de remboursement.
  await orders.adminOrderAction({db, uid: "admin", data: {orderId: "free",
    action: "cancel", reason: "Test"}});
  assert.strictEqual((await order("free")).refund_needed, undefined);
  // Déjà terminée : refusé.
  await assert.rejects(orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "done", action: "cancel", reason: "x"}}), /déjà terminée/);
  assert.deepStrictEqual(await logs(), ["order.cancel", "order.cancel"]);
});

test("attribuer un livreur : comme son acceptation", async () => {
  await assert.rejects(orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "ready", action: "assign", delivererUid: "marie"}}),
  /Livreur introuvable/);
  await assert.rejects(orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "ready", action: "assign", delivererUid: "off"}}), /suspendu/);
  await assert.rejects(orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "free", action: "assign", delivererUid: "jean"}}),
  /prête ou en livraison/);
  await orders.adminOrderAction({db, uid: "admin", data: {orderId: "ready",
    action: "assign", delivererUid: "jean"}});
  const o = await order("ready");
  assert.strictEqual(o.status, "encours");
  assert.strictEqual(o.deliverer_ref, "jean");
  assert.strictEqual(o.deliver_reference.path, "User/jean");
});

test("marquer livrée : seulement en livraison", async () => {
  await assert.rejects(orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "ready", action: "deliver"}}), /en livraison/);
  await orders.adminOrderAction({db, uid: "admin", data: {orderId: "going",
    action: "deliver"}});
  const o = await order("going");
  assert.strictEqual(o.status, "Livrer");
  assert.ok(o.delivered_at);
  await assert.rejects(orders.adminOrderAction({db, uid: "admin", data: {
    orderId: "going", action: "nimporte"}}), /Action inconnue/);
});

test("clôture en lot des commandes jamais confirmées", async () => {
  await assert.rejects(orders.closeStaleOrders({db, uid: "admin",
    data: {days: 2}}), /motif/);
  await assert.rejects(orders.closeStaleOrders({db, uid: "admin",
    data: {days: 0, reason: "x"}}), /Ancienneté/);
  const r = await orders.closeStaleOrders({db, uid: "admin",
    data: {days: 2, reason: "Commandes de test"}, clock: () => NOW});
  // « paid » (5 j, en attente) et « old » (10 j, sans statut) ; pas « new ».
  assert.deepStrictEqual(r, {closed: 2, refunds: 1});
  assert.strictEqual((await order("paid")).status, "Annulée");
  assert.strictEqual((await order("old")).status, "Annulée");
  assert.strictEqual((await order("old")).cancel_reason, "Commandes de test");
  assert.strictEqual((await order("new")).status, "En attente");
  assert.strictEqual((await order("free")).status, "En préparation");
  assert.deepStrictEqual(await logs(), ["order.close_stale"]);
});
