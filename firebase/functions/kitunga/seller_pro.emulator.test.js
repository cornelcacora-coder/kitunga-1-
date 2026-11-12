/**
 * Espace vendeur : actions sur les commandes, ouvert / fermé, performances.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/seller_pro.emulator.test.js"
 */
process.env.KITUNGA_MOMO_MOCK = "1";
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const sp = require("./seller_pro");
const wallet = require("./wallet");
const {startPayment} = require("./payments");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const order = db.doc("Orders/o1");

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/shop").set({role: "Seller", display_name: "Mado"});
  await db.doc("User/other").set({role: "Seller"});
  await db.doc("User/client").set({role: "User",
    subscribe_close_at: new Date(Date.now() + 86400000)});
  await order.set({status: "En attente", payment_status: "Réussi",
    seller_ref: db.doc("User/shop"), user_ref: db.doc("User/client"),
    total_amount: 6000, delivery_fees: 1000, order_unique_reference: "K-1"});
});

test("accepter, prête, remise au livreur ; auteur enregistré", async () => {
  await assert.rejects(sp.sellerOrderAction({db, uid: "other",
    data: {orderId: "o1", action: "accept"}}), {code: "not-found"});
  await assert.rejects(sp.sellerOrderAction({db, uid: "shop",
    data: {orderId: "o1", action: "ready"}}), {code: "failed-precondition"});
  await sp.sellerOrderAction({db, uid: "shop",
    data: {orderId: "o1", action: "accept", prepMinutes: 20}});
  let o = await order.get();
  assert.strictEqual(o.get("status"), "En préparation");
  assert.strictEqual(o.get("prep_minutes"), 20);
  assert.strictEqual(o.get("status_actor").role, "Seller");
  await sp.sellerOrderAction({db, uid: "shop",
    data: {orderId: "o1", action: "ready"}});
  assert.strictEqual((await order.get()).get("status"), "Pret");
  await assert.rejects(sp.sellerOrderAction({db, uid: "shop",
    data: {orderId: "o1", action: "refuse", reason: "x"}}),
  {code: "failed-precondition"});
  await order.update({status: "encours", deliverer_ref: "l1"});
  await sp.sellerOrderAction({db, uid: "shop",
    data: {orderId: "o1", action: "handover"}});
  o = await order.get();
  assert.ok(o.get("handover_confirmed_at") && o.get("picked_up_at"));
});

test("refus : motif obligatoire, remboursement si payée", async () => {
  await assert.rejects(sp.sellerOrderAction({db, uid: "shop",
    data: {orderId: "o1", action: "refuse"}}), {code: "invalid-argument"});
  await sp.sellerOrderAction({db, uid: "shop",
    data: {orderId: "o1", action: "refuse", reason: "Rupture"}});
  const o = await order.get();
  assert.strictEqual(o.get("status"), "Refusée");
  assert.strictEqual(o.get("refund_needed"), true);
  assert.strictEqual(o.get("refusal_reason"), "Rupture");
});

test("fermé maintenant : plus de commande ; réouverture", async () => {
  await sp.sellerSetOpen({db, uid: "shop", data: {open: false}});
  await db.doc("Product/p1").set({name: "Pain", sale_price: 500,
    quantity: 5, on_sale: true, seller_ref: db.doc("User/shop")});
  await db.doc("Cart/c1").set({user_ref: db.doc("User/client"),
    seller_ref: db.doc("User/shop"), product_ref: db.doc("Product/p1"),
    quantity: 1, options: "", is_ordered: false});
  await assert.rejects(startPayment({db, momo: wallet, uid: "client",
    sellerPath: "User/shop", zone: "Bacongo", phone: "061234567"}),
  /fermé pour le moment/);
  await sp.sellerSetOpen({db, uid: "shop", data: {open: true}});
  assert.ok((await startPayment({db, momo: wallet, uid: "client",
    sellerPath: "User/shop", zone: "Bacongo", phone: "061234567"}))
      .referenceId);
});

test("performances : ventes, panier, préparation, meilleurs produits, stock",
    async () => {
      const now = new Date();
      await order.update({status: "Livrer", delivered_at: now,
        accepted_at: new Date(now - 30 * 60000),
        ready_at: new Date(now - 10 * 60000)});
      await db.doc("Orders/o2").set({status: "Refusée",
        seller_ref: db.doc("User/shop")});
      await db.collection("OrderItems").add({order_ref: "K-1",
        item_name: "Poulet", quantity: 3});
      await db.doc("Product/p1").set({name: "Pain", quantity: 2,
        on_sale: true, seller_ref: db.doc("User/shop")});
      await db.doc("Product/p2").set({name: "Riz", quantity: 50,
        on_sale: true, seller_ref: db.doc("User/shop")});
      const r = await sp.sellerPerformance({db, uid: "shop", now});
      assert.strictEqual(r.delivered, 1);
      assert.strictEqual(r.refusalRate, 50);
      assert.strictEqual(r.averageBasket, 5000);
      assert.strictEqual(r.averagePrepMinutes, 20);
      assert.strictEqual(r.salesByDay[6].amount, 5000);
      assert.deepStrictEqual(r.topProducts, [{name: "Poulet", quantity: 3}]);
      assert.deepStrictEqual(r.lowStock.map((p) => p.name), ["Pain"]);
      await assert.rejects(sp.sellerPerformance({db, uid: "client"}),
          {code: "permission-denied"});
    });
