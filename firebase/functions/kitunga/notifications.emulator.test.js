/**
 * Notifications et rappels d'abonnement.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/notifications.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const n = require("./notifications");
const cat = require("./catalog");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const day = 86400000;
// Heure réelle : le comptage des groupes (admin) se fait à l'heure actuelle.
const now = new Date();
const pushes = [];
const messaging = {
  sendEachForMulticast: async (m) => {
    pushes.push(m);
    return {successCount: m.tokens.filter((t) => t !== "mort").length,
      responses: m.tokens.map((t) => t === "mort" ?
        {success: false, error: {code: "messaging/registration-token-not-registered"}} :
        {success: true})};
  },
};
const notes = async (uid) =>
  (await n.myNotifications({db, uid})).notifications;

test.beforeEach(async () => {
  pushes.length = 0;
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  const user = (id, closeIn, extra = {}) => db.doc(`User/${id}`).set({
    role: "User", display_name: id, created_time: now,
    ...(closeIn === null ? {} :
      {subscribe_close_at: new Date(now.getTime() + closeIn)}),
    ...extra});
  await user("j7", 6.5 * day, {fcm_tokens: ["tel-a", "mort"]});
  await user("j1", 0.5 * day);
  await user("fini", -0.2 * day);
  await user("actif", 90 * day);
  await user("jamais", null);
  await db.doc("User/vendeur").set({role: "Seller",
    subscribe_close_at: new Date(now.getTime() + 0.5 * day)});
});

test("rappels automatiques : J-7, veille, expiration, une seule fois",
    async () => {
      assert.deepStrictEqual(await n.subscriptionReminders({db, messaging, now}),
          {count: 3});
      assert.match((await notes("j7"))[0].title, /se termine bientôt/);
      assert.match((await notes("j1"))[0].title, /se termine demain/);
      assert.match((await notes("fini"))[0].title, /est terminé/);
      assert.strictEqual((await notes("actif")).length, 0);
      assert.strictEqual((await notes("vendeur")).length, 0);
      // Push sur le téléphone ; jeton mort retiré.
      assert.deepStrictEqual(pushes[0].tokens, ["tel-a", "mort"]);
      assert.deepStrictEqual((await db.doc("User/j7").get())
          .get("fcm_tokens"), ["tel-a"]);
      // Relancé le même jour : rien de plus.
      assert.deepStrictEqual(await n.subscriptionReminders({db, messaging, now}),
          {count: 0});
      // Le client lit ses notifications.
      assert.strictEqual((await n.myNotifications({db, uid: "j7"})).unread, 1);
      await n.markNotificationsRead({db, uid: "j7"});
      assert.strictEqual((await n.myNotifications({db, uid: "j7"})).unread, 0);
    });

test("admin : groupes d'abonnement et envoi d'un rappel", async () => {
  const r = await cat.catalogQuery({db, uid: "admin",
    data: {view: "clients"}});
  assert.deepStrictEqual(r.counts,
      {active: 1, expiring: 2, expired: 1, never: 1});
  const expired = await cat.catalogQuery({db, uid: "admin",
    data: {view: "clients", subscription: "expired"}});
  assert.deepStrictEqual(expired.clients.map((c) => c.uid), ["fini"]);
  await assert.rejects(n.adminSendReminder({db, messaging, uid: "j7",
    data: {segment: "never"}}), /administrateurs/);
  await assert.rejects(n.adminSendReminder({db, messaging, uid: "admin",
    data: {}}), /Choisissez/);
  const sent = await n.adminSendReminder({db, messaging, uid: "admin",
    data: {segment: "never"}, now});
  assert.strictEqual(sent.sent, 1);
  assert.match((await notes("jamais"))[0].body, /300 F pour 3 mois/);
  await n.adminSendReminder({db, messaging, uid: "admin",
    data: {uids: ["actif", "vendeur"], title: "Promo", body: "Livraison offerte"}});
  assert.strictEqual((await notes("actif"))[0].title, "Promo");
  assert.strictEqual((await notes("vendeur")).length, 0); // clients seulement
});

test("jeton du téléphone : enregistré, sans doublon", async () => {
  await n.saveFcmToken({db, uid: "actif", data: {token: "x"}});
  await n.saveFcmToken({db, uid: "actif", data: {token: "x"}});
  await n.saveFcmToken({db, uid: "actif", data: {token: "y"}});
  assert.deepStrictEqual((await db.doc("User/actif").get())
      .get("fcm_tokens"), ["x", "y"]);
});
