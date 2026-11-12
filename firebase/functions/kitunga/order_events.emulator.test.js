/**
 * Notifications au fil des commandes, disponibilité des livreurs, contacts.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/order_events.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const ev = require("./order_events");
const {myNotifications} = require("./notifications");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const pushes = [];
const messaging = {sendEachForMulticast: async (m) => {
  pushes.push(m);
  return {successCount: m.tokens.length,
    responses: m.tokens.map(() => ({success: true}))};
}};
const titles = async (uid) =>
  (await myNotifications({db, uid})).notifications.map((x) => x.title);
const order = db.doc("Orders/o1");

/** Applique un changement à la commande et déclenche l'événement. */
async function change(fields) {
  const before = await order.get();
  if (before.exists) await order.update(fields);
  else await order.set(fields);
  const after = await order.get();
  return ev.onOrderWrite({db, messaging, before, after});
}

test.beforeEach(async () => {
  pushes.length = 0;
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/client").set({role: "User", display_name: "Awa",
    phone_number: "+242060000001", fcm_tokens: ["tel-client"]});
  await db.doc("User/shop").set({role: "Seller", display_name: "Chez Mado",
    phone_number: "+242060000002"});
  await db.doc("User/l1").set({role: "Deliver", display_name: "Jo",
    phone_number: "+242060000003", delivery_available: true,
    delivery_zones: ["Bacongo"]});
  await db.doc("User/l2").set({role: "Deliver", display_name: "Sam",
    delivery_available: true});
  await db.doc("User/l3").set({role: "Deliver", display_name: "Off",
    delivery_available: false});
  await db.doc("User/l4").set({role: "Deliver", display_name: "Loin",
    delivery_available: true, delivery_zones: ["Mfilou"]});
});

test("parcours complet : commerce, livreurs du quartier, client", async () => {
  await change({status: "En attente", order_unique_reference: "K-1",
    user_ref: db.doc("User/client"), seller_ref: db.doc("User/shop"),
    delivery_zone: "Bacongo", delivery_fees: 1000});
  assert.deepStrictEqual(await titles("shop"), ["Nouvelle commande"]);

  await change({status: "En préparation"});
  assert.deepStrictEqual(await titles("client"), ["Commande acceptée"]);
  assert.strictEqual(pushes.at(-1).tokens[0], "tel-client");

  await change({status: "Pret"});
  // En service et couvrant Bacongo (ou sans quartier choisi).
  assert.deepStrictEqual(await titles("l1"), ["Nouvelle commande à livrer"]);
  assert.deepStrictEqual(await titles("l2"), ["Nouvelle commande à livrer"]);
  assert.deepStrictEqual(await titles("l3"), []);
  assert.deepStrictEqual(await titles("l4"), []);
  assert.ok((await order.get()).get("ready_at"));

  await change({status: "encours", deliverer_ref: "l1",
    deliver_reference: db.doc("User/l1")});
  assert.strictEqual((await titles("client"))[0],
      "Votre commande est en route");
  assert.ok((await titles("shop")).includes("Commande prise en charge"));

  await change({status: "Livrer"});
  assert.strictEqual((await titles("client"))[0], "Commande livrée");
  // Une modification sans changement de statut ne renvoie rien.
  assert.deepStrictEqual(await change({note: "x"}), {sent: 0});
});

test("refus, annulation, problème de livraison", async () => {
  await order.set({status: "En attente", user_ref: db.doc("User/client"),
    seller_ref: db.doc("User/shop")});
  await change({status: "Refusée", refund_needed: true});
  assert.deepStrictEqual(await titles("client"), ["Commande refusée"]);
  await change({status: "Annulée"});
  assert.deepStrictEqual(await titles("shop"), ["Commande annulée"]);
  await change({delivery_issue: {type: "absent", label: "Client absent"}});
  assert.deepStrictEqual(await titles("admin"), ["Problème de livraison"]);
  await change({note: "même problème"});
  assert.strictEqual((await titles("admin")).length, 1);
});

test("commande prête depuis 20 minutes : alerte admin une seule fois",
    async () => {
      const now = new Date();
      await db.doc("Orders/vieille").set({status: "Pret",
        ready_at: new Date(now.getTime() - 25 * 60000),
        delivery_zone: "Bacongo"});
      await db.doc("Orders/recente").set({status: "Pret",
        ready_at: new Date(now.getTime() - 5 * 60000)});
      assert.deepStrictEqual(await ev.staleReadyOrders({db, messaging, now}),
          {count: 1});
      assert.deepStrictEqual(await titles("admin"),
          ["Commandes sans livreur"]);
      assert.deepStrictEqual(await ev.staleReadyOrders({db, messaging, now}),
          {count: 0});
    });

test("livreur : en service et quartiers", async () => {
  await ev.setDelivererStatus({db, uid: "l3",
    data: {available: true, zones: ["Bacongo", "Bacongo", "Ouenzé"]}});
  const u = await db.doc("User/l3").get();
  assert.strictEqual(u.get("delivery_available"), true);
  assert.deepStrictEqual(u.get("delivery_zones"), ["Bacongo", "Ouenzé"]);
  await assert.rejects(ev.setDelivererStatus({db, uid: "l3",
    data: {zones: ["Paris"]}}), {code: "invalid-argument"});
  await assert.rejects(ev.setDelivererStatus({db, uid: "client",
    data: {available: true}}), {code: "permission-denied"});
});

test("contacts : chacun voit les autres acteurs de sa commande", async () => {
  await order.set({status: "encours", user_ref: db.doc("User/client"),
    seller_ref: db.doc("User/shop"), deliverer_ref: "l1",
    deliver_reference: db.doc("User/l1")});
  const roles = async (uid) => (await ev.orderContacts({db, uid,
    data: {orderId: "o1"}})).contacts.map((c) => c.role);
  assert.deepStrictEqual(await roles("client"), ["commerce", "livreur"]);
  assert.deepStrictEqual(await roles("l1"), ["client", "commerce"]);
  assert.deepStrictEqual(await roles("shop"), ["client", "livreur"]);
  await assert.rejects(ev.orderContacts({db, uid: "l2",
    data: {orderId: "o1"}}), {code: "not-found"});
});

test("commande récupérée : le client est prévenu", async () => {
  await order.set({status: "encours", user_ref: db.doc("User/client"),
    seller_ref: db.doc("User/shop"), deliverer_ref: "l1"});
  await change({picked_up_at: new Date()});
  assert.deepStrictEqual(await titles("client"), ["Votre livreur arrive"]);
});
