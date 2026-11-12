/**
 * Finances : règlement à la livraison, annulation, versements, soldes.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/finance.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const f = require("./finance");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const order = db.doc("Orders/o1");
const settle = async () => f.onOrderFinance({db, after: await order.get()});
const ledger = async () => Object.fromEntries((await db.collection("Ledger")
    .get()).docs.map((d) => [d.id, d.get("amount")]));

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/shop").set({role: "Seller", display_name: "Chez Mado"});
  await db.doc("User/l1").set({role: "Deliver", display_name: "Jo"});
  await db.doc("User/client").set({role: "User"});
  await order.set({status: "encours", payment_status: "Réussi",
    total_amount: 6000, delivery_fees: 1000, order_unique_reference: "K-1",
    seller_ref: db.doc("User/shop"), deliverer_ref: "l1"});
});

test("règles actuelles : pas de commission, 100 % des frais au livreur",
    async () => {
      assert.deepStrictEqual(await settle(), {done: false});
      await order.update({status: "Livrer"});
      assert.strictEqual((await settle()).done, true);
      assert.deepStrictEqual(await ledger(),
          {o1_seller: 5000, o1_deliverer: 1000});
      // Rejoué (réception confirmée, nouveau déclenchement) : rien de plus.
      await order.update({status: "Reçu"});
      assert.strictEqual((await settle()).done, false);
      assert.strictEqual(Object.keys(await ledger()).length, 2);
      assert.strictEqual((await order.get()).get("settlement").seller, 5000);
    });

test("commission et part du livreur réglées par l'admin", async () => {
  await f.adminFinanceSettings({db, uid: "admin", data: {save: {
    commission_rate: 0.1, deliverer_share: 0.8}}});
  await order.update({status: "Livrer"});
  await settle();
  assert.deepStrictEqual(await ledger(), {o1_seller: 4500,
    o1_deliverer: 800, o1_kitunga: 700});
  await assert.rejects(f.adminFinanceSettings({db, uid: "admin",
    data: {save: {commission_rate: 0.9, deliverer_share: 1}}}),
  {code: "invalid-argument"});
  await assert.rejects(f.adminFinanceSettings({db, uid: "l1", data: {}}),
      {code: "permission-denied"});
});

test("remboursée après livraison : écritures inverses", async () => {
  await order.update({status: "Livrer"});
  await settle();
  await order.update({refund_status: "Envoyé"});
  assert.strictEqual((await settle()).kind, "reversed");
  const l = await ledger();
  assert.strictEqual(l.o1_seller + l.o1_seller_rev, 0);
  assert.strictEqual(l.o1_deliverer + l.o1_deliverer_rev, 0);
  assert.strictEqual((await settle()).done, false);
});

test("commande non payée ou à rembourser : aucun règlement", async () => {
  await order.update({status: "Livrer", payment_status: "En attente"});
  assert.strictEqual((await settle()).done, false);
  await order.update({payment_status: "Réussi", refund_needed: true});
  assert.strictEqual((await settle()).done, false);
});

test("gains, versement unique (double clic), solde, vue admin",
    async () => {
      await order.update({status: "Livrer"});
      await settle();
      let e = await f.myEarnings({db, uid: "l1"});
      assert.strictEqual(e.balance, 1000);
      assert.strictEqual(e.today, 1000);
      const pay = {uid: "l1", amount: 600, method: "MoMo",
        requestId: "req-12345678", reference: "MTN-1"};
      const both = await Promise.all([
        f.adminRecordPayout({db, messaging: null, uid: "admin", data: pay}),
        f.adminRecordPayout({db, messaging: null, uid: "admin", data: pay}),
      ]);
      assert.strictEqual(both.filter((r) => r.duplicate).length, 1);
      e = await f.myEarnings({db, uid: "l1"});
      assert.strictEqual(e.balance, 400);
      assert.strictEqual(e.paidOut, 600);
      await assert.rejects(f.adminRecordPayout({db, messaging: null,
        uid: "admin", data: {...pay, requestId: "req-87654321",
          amount: 5000}}), {code: "failed-precondition"});
      await assert.rejects(f.myEarnings({db, uid: "client"}),
          {code: "permission-denied"});
      const o = await f.adminFinanceOverview({db, uid: "admin"});
      assert.strictEqual(o.totals.payouts, 600);
      assert.strictEqual(o.totals.owed, 5400);
      assert.strictEqual(o.accounts[0].name, "Chez Mado");
    });
