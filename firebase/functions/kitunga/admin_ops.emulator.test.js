/**
 * Gestion admin : remboursements, abonnements offerts, comptes suspendus.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/admin_ops.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const ops = require("./admin_ops");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const D = (day) => new Date(Date.UTC(2026, 10, day, 12));
const auth = {disabled: {}, revoked: [],
  updateUser: async (uid, c) => {
    auth.disabled[uid] = c.disabled;
  },
  revokeRefreshTokens: async (uid) => {
    auth.revoked.push(uid);
  }};
const logs = async () => (await db.collection("audit_logs").get()).docs
    .map((d) => d.get("action")).sort();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  auth.disabled = {}; auth.revoked = [];
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/admin2").set({role: "Admin"});
  await db.doc("User/marie").set({role: "User", display_name: "Marie Ngoma",
    email: "marie@test.cg", phone_number: "061234567"});
  await db.doc("User/shop").set({role: "Seller", display_name: "Boutique"});
  await db.doc("User/agent").set({role: "Commercial"});
  await db.doc("Orders/o1").set({user_ref: db.doc("User/marie"),
    total_amount: 3500, status: "Annulée", refund_needed: true,
    order_unique_reference: "ORD-1", status_updated_at: D(5)});
  await db.doc("Orders/o2").set({user_ref: db.doc("User/marie"),
    total_amount: 2000, status: "Refusée", refund_needed: true,
    refund_status: "Envoyé"});
  await db.doc("Orders/o3").set({user_ref: db.doc("User/marie"),
    total_amount: 1000, status: "Annulée", refund_needed: true,
    refund_status: "En cours"});
});

test("réservé à l'admin", async () => {
  for (const uid of ["marie", "agent", null]) {
    await assert.rejects(ops.adminOpsQuery({db, uid, data: {view: "refunds"}}),
        /administrateurs|Connexion requise/);
    await assert.rejects(ops.markRefunded({db, uid, data: {orderId: "o1",
      reference: "x"}}), /administrateurs|Connexion requise/);
    await assert.rejects(ops.grantSubscription({db, uid, data: {
      userUid: "marie", days: 30, reason: "x"}}), /administrateurs|Connexion requise/);
    await assert.rejects(ops.setAccountStatus({db, auth, uid, data: {
      userUid: "shop", status: "suspended", reason: "x"}}),
    /administrateurs|Connexion requise/);
  }
});

test("remboursements : liste des commandes non remboursées", async () => {
  const {refunds} = await ops.adminOpsQuery({db, uid: "admin",
    data: {view: "refunds"}});
  assert.deepEqual(refunds.map((r) => r.orderId).sort(), ["o1", "o3"]);
  const o1 = refunds.find((r) => r.orderId === "o1");
  assert.equal(o1.amount, 3500);
  assert.equal(o1.client.phone, "061234567");
  assert.equal(o1.refundStatus, "À traiter");
});

test("remboursement manuel : référence, une seule fois, journalisé", async () => {
  await assert.rejects(ops.markRefunded({db, uid: "admin",
    data: {orderId: "o1"}}), /référence du transfert/);
  await ops.markRefunded({db, uid: "admin",
    data: {orderId: "o1", reference: "MP261108.1530.R1"}});
  const o = (await db.doc("Orders/o1").get()).data();
  assert.equal(o.refund_status, "Envoyé");
  assert.equal(o.refund_reference, "MP261108.1530.R1");
  assert.equal(o.refunded_manually_by, "admin");
  await assert.rejects(ops.markRefunded({db, uid: "admin",
    data: {orderId: "o1", reference: "x"}}), /déjà remboursée/);
  await assert.rejects(ops.markRefunded({db, uid: "admin",
    data: {orderId: "o3", reference: "x"}}), /automatique est en cours/);
  await db.doc("Orders/o4").set({status: "Reçu"});
  await assert.rejects(ops.markRefunded({db, uid: "admin",
    data: {orderId: "o4", reference: "x"}}), /Aucun remboursement/);
  assert.deepEqual(await logs(), ["refund.manual"]);
});

test("abonnement offert puis prolongé à partir de la fin actuelle", async () => {
  const r1 = await ops.grantSubscription({db, uid: "admin", clock: () => D(1),
    data: {userUid: "marie", days: 30, reason: "Geste commercial"}});
  assert.equal(r1.until, "2026-12-01T12:00:00.000Z");
  const r2 = await ops.grantSubscription({db, uid: "admin", clock: () => D(2),
    data: {userUid: "marie", days: 30, reason: "Prolongation"}});
  assert.equal(r2.until, "2026-12-31T12:00:00.000Z");
  const u = (await db.doc("User/marie").get()).data();
  assert.equal(u.subscribe_type, "Offert par Kitunga");
  assert.equal(u.is_subscribed, true);
  for (const [data, msg] of [
    [{userUid: "marie", days: 0, reason: "x"}, /Durée invalide/],
    [{userUid: "marie", days: 30}, /motif/],
    [{userUid: "shop", days: 30, reason: "x"}, /Seuls les clients/],
    [{userUid: "inconnu", days: 30, reason: "x"}, /introuvable/],
  ]) {
    await assert.rejects(ops.grantSubscription({db, uid: "admin", data}), msg);
  }
  // Aucun paiement créé : aucune commission possible.
  assert.equal((await db.collection("Paiement").get()).size, 0);
});

test("recherche : email, téléphone (formats congolais), début de nom", async () => {
  const s = (q) => ops.adminOpsQuery({db, uid: "admin", data: {view: "search", q}})
      .then((r) => r.accounts.map((a) => a.uid));
  assert.deepEqual(await s("marie@test.cg"), ["marie"]);
  assert.deepEqual(await s("Marie@Test.cg"), ["marie"]);
  assert.deepEqual(await s("+242 06 123 45 67"), ["marie"]);
  assert.deepEqual(await s("marie"), ["marie"]);
  assert.deepEqual(await s("Bout"), ["shop"]);
  await assert.rejects(s("a"), /2 caractères/);
});

test("suspension : bloque la connexion, refuse admin, soi-même, commercial",
    async () => {
      await assert.rejects(ops.setAccountStatus({db, auth, uid: "admin",
        data: {userUid: "shop", status: "suspended"}}), /motif/);
      await ops.setAccountStatus({db, auth, uid: "admin",
        data: {userUid: "shop", status: "suspended", reason: "Fraude"}});
      assert.equal(auth.disabled.shop, true);
      assert.deepEqual(auth.revoked, ["shop"]);
      assert.equal((await db.doc("User/shop").get()).get("account_status"),
          "suspended");
      await ops.setAccountStatus({db, auth, uid: "admin",
        data: {userUid: "shop", status: "active"}});
      assert.equal(auth.disabled.shop, false);
      for (const [userUid, msg] of [["admin", /propre compte/],
        ["admin2", /ne peut pas être suspendu/], ["agent", /module commercial/],
        ["inconnu", /introuvable/]]) {
        await assert.rejects(ops.setAccountStatus({db, auth, uid: "admin",
          data: {userUid, status: "suspended", reason: "x"}}), msg);
      }
      assert.deepEqual(await logs(), ["account.active", "account.suspended"]);
    });
