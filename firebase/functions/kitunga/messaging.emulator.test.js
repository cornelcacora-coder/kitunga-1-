/**
 * Messagerie : conversations d'une commande, droits, non-lus, annonces.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/messaging.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const m = require("./messaging");
const {myNotifications} = require("./notifications");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const messaging = null;

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/client").set({role: "User", display_name: "Awa"});
  await db.doc("User/shop").set({role: "Seller", display_name: "Chez Mado"});
  await db.doc("User/l1").set({role: "Deliver", display_name: "Jo"});
  await db.doc("User/autre").set({role: "User"});
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/sup").set({role: "Support"});
  await db.doc("Orders/o1").set({status: "encours", order_unique_reference:
    "K-1", user_ref: db.doc("User/client"), seller_ref: db.doc("User/shop"),
  deliverer_ref: "l1", deliver_reference: db.doc("User/l1")});
});

test("client ↔ livreur : envoi, non-lus, notification, lecture", async () => {
  const {conversationId: id} = await m.openOrderChat({db, uid: "client",
    data: {orderId: "o1", with: "livreur"}});
  // Même conversation depuis l'autre côté.
  assert.strictEqual((await m.openOrderChat({db, uid: "l1",
    data: {orderId: "o1", with: "client"}})).conversationId, id);
  await m.sendMessage({db, messaging, uid: "client",
    data: {conversationId: id, text: "Je suis au portail bleu."}});
  let list = await m.myConversations({db, uid: "l1"});
  assert.strictEqual(list.unread, 1);
  assert.strictEqual(list.conversations[0].withRole, "client");
  assert.match((await myNotifications({db, uid: "l1"})).notifications[0]
      .title, /Awa/);
  const thread = await m.conversationMessages({db, uid: "l1",
    data: {conversationId: id}});
  assert.strictEqual(thread.messages[0].text, "Je suis au portail bleu.");
  assert.strictEqual(thread.messages[0].mine, false);
  list = await m.myConversations({db, uid: "l1"});
  assert.strictEqual(list.unread, 0);
});

test("droits : un étranger ne lit ni n'écrit ; le support lit", async () => {
  const {conversationId: id} = await m.openOrderChat({db, uid: "shop",
    data: {orderId: "o1", with: "client"}});
  await assert.rejects(m.conversationMessages({db, uid: "autre",
    data: {conversationId: id}}), {code: "not-found"});
  await assert.rejects(m.sendMessage({db, messaging, uid: "autre",
    data: {conversationId: id, text: "x"}}), {code: "not-found"});
  await assert.rejects(m.openOrderChat({db, uid: "autre",
    data: {orderId: "o1", with: "client"}}), {code: "not-found"});
  assert.ok(await m.conversationMessages({db, uid: "sup",
    data: {conversationId: id}}));
  await assert.rejects(m.sendMessage({db, messaging, uid: "client",
    data: {conversationId: id, text: "  "}}), {code: "invalid-argument"});
});

test("commande terminée depuis plus de 48 h : conversation fermée",
    async () => {
      const {conversationId: id} = await m.openOrderChat({db, uid: "client",
        data: {orderId: "o1", with: "commerce"}});
      await db.doc("Orders/o1").update({status: "Reçu",
        delivered_at: new Date(Date.now() - 50 * 3600 * 1000)});
      await assert.rejects(m.sendMessage({db, messaging, uid: "client",
        data: {conversationId: id, text: "Merci"}}),
      {code: "failed-precondition"});
      assert.strictEqual((await m.conversationMessages({db, uid: "client",
        data: {conversationId: id}})).open, false);
    });

test("annonce de l'admin aux livreurs", async () => {
  assert.deepStrictEqual(await m.adminAnnounce({db, messaging, uid: "admin",
    data: {audience: "deliverers", title: "Pluie", body: "Soyez prudents."}}),
  {sent: 1});
  const list = await m.myConversations({db, uid: "l1"});
  assert.strictEqual(list.conversations[0].kind, "announcement");
  assert.strictEqual(list.unread, 1);
  await assert.rejects(m.sendMessage({db, messaging, uid: "l1",
    data: {conversationId: list.conversations[0].id, text: "ok"}}),
  {code: "permission-denied"});
  await assert.rejects(m.adminAnnounce({db, messaging, uid: "l1",
    data: {audience: "all", title: "x", body: "y"}}),
  {code: "permission-denied"});
});
