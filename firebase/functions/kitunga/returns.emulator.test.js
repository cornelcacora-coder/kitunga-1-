/**
 * Retours et échanges.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/returns.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const r = require("./returns");
const ops = require("./admin_ops");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const day = 86400000;
const photo = "https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fmarie%2Fuploads%2F1.jpg?alt=media";
const order = async (id = "o1") => (await db.doc(`Orders/${id}`).get()).data();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/marie").set({role: "User", display_name: "Marie"});
  await db.doc("User/mode").set({role: "Seller", category: "Boutique"});
  await db.doc("User/resto").set({role: "Seller", category: "Restaurant"});
  const base = {user_ref: db.doc("User/marie"), status: "Reçu",
    total_amount: 16000, delivery_fees: 1000, order_unique_reference: "KT-1",
    delivered_at: new Date(Date.now() - 2 * day)};
  await db.doc("Orders/o1").set({...base, seller_ref: db.doc("User/mode")});
  await db.doc("Orders/o2").set({...base, seller_ref: db.doc("User/resto")});
  await db.doc("Orders/o3").set({...base, seller_ref: db.doc("User/mode"),
    delivered_at: new Date(Date.now() - 9 * day)});
  await db.doc("Orders/o4").set({...base, seller_ref: db.doc("User/mode"),
    status: "encours"});
});

const ask = (orderId, extra = {}, uid = "marie") => r.requestReturn({db, uid,
  data: {orderId, reason: "size", wish: "refund", ...extra}});

test("demande : boutique, livrée, dans les 7 jours, une seule fois",
    async () => {
      await assert.rejects(ask("o1", {}, "mode"), /introuvable/);
      await assert.rejects(ask("o2"), /boutiques et magasins/);
      await assert.rejects(ask("o3"), /délai de retour/);
      await assert.rejects(ask("o4"), /une fois la commande livrée/);
      await assert.rejects(ask("o1", {reason: "?"}), /motif/);
      await assert.rejects(ask("o1", {reason: "other"}), /Expliquez/);
      await assert.rejects(ask("o1", {photos: [
        "https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fautre%2F1.jpg",
      ]}), /application Kitunga/);
      await ask("o1", {photos: [photo], note: "Trop petit"});
      const o = await order();
      assert.strictEqual(o.return_status, "requested");
      assert.strictEqual(o.return_wish, "refund");
      assert.deepStrictEqual(o.return_photos, [photo]);
      await assert.rejects(ask("o1"), /déjà été demandé/);
    });

test("refus motivé par le commerce", async () => {
  await ask("o1");
  await assert.rejects(r.decideReturn({db, uid: "resto",
    data: {orderId: "o1", decision: "accept"}}), /introuvable/);
  await assert.rejects(r.decideReturn({db, uid: "mode",
    data: {orderId: "o1", decision: "refuse"}}), /pourquoi/);
  await r.decideReturn({db, uid: "mode", data: {orderId: "o1",
    decision: "refuse", note: "Article porté"}});
  const o = await order();
  assert.strictEqual(o.return_status, "refused");
  assert.strictEqual(o.return_decision_note, "Article porté");
  assert.strictEqual(o.refund_needed, undefined);
  await assert.rejects(r.decideReturn({db, uid: "mode",
    data: {orderId: "o1", decision: "accept"}}), /Aucune demande/);
});

test("remboursement accepté : dans les remboursements de l'admin",
    async () => {
      await ask("o1");
      const res = await r.decideReturn({db, uid: "mode",
        data: {orderId: "o1", decision: "accept"}});
      assert.strictEqual(res.refund, true);
      const o = await order();
      assert.strictEqual(o.refund_needed, true);
      assert.strictEqual(o.refund_amount, 15000); // sans la livraison
      const list = (await ops.adminOpsQuery({db, uid: "admin",
        data: {view: "refunds"}})).refunds;
      assert.strictEqual(list[0].amount, 15000);
      assert.strictEqual(list[0].reason, "Retour accepté par le commerce");
    });

test("échange accepté : pas de remboursement", async () => {
  await ask("o1", {wish: "exchange"});
  await r.decideReturn({db, uid: "mode",
    data: {orderId: "o1", decision: "accept"}});
  const o = await order();
  assert.strictEqual(o.return_status, "accepted");
  assert.strictEqual(o.refund_needed, undefined);
});
