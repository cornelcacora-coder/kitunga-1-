/**
 * Module commercial : activation attestée par App Check (Play Integrity).
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.activations.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const {recordActivation, ANDROID_APP_ID, MAX_ATTEMPTS} =
  require("./acquisition/activations");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const INSTALL = (n) => `3f2b8c1e-9a4d-4e2f-8b6a-${String(n).padStart(12, "0")}`;
const GOOD = {appId: ANDROID_APP_ID, alreadyConsumed: false};
const activate = (uid, n, app) =>
  recordActivation({db, uid, app, data: {installationId: INSTALL(n)}});
const activation = async (n) =>
  (await db.doc(`app_activations/${INSTALL(n)}`).get()).data();
const events = async () => (await db.collection("acquisition_events")
    .where("type", "==", "activation").get()).docs.map((d) => d.data());

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc(`acquisition_touches/${INSTALL(1)}`).set({code: "KTG001-X7P9",
    campaign_id: "c1", agent_uid: "agentA", assignment_id: "a1",
    status: "provisional"});
});

test("jeton valide de l'application Kitunga : activation vérifiée", async () => {
  assert.deepEqual(await activate("guest", 1, GOOD), {verified: true});
  const a = await activation(1);
  assert.equal(a.verified, true);
  assert.equal(a.app_id, ANDROID_APP_ID);
  assert.equal(a.first_uid, "guest");
  assert.ok(a.activated_at);
  const [ev] = await events();
  assert.equal(ev.agent_uid, "agentA");
  assert.equal(ev.installation_id, INSTALL(1));
});

test("sans jeton, autre application ou jeton rejoué : non vérifiée", async () => {
  for (const [n, app, reason] of [
    [1, undefined, "no_app_check"],
    [2, {appId: "1:44272206573:android:42dd1d7a84c430465b02e4"}, "other_app"],
    [3, {appId: ANDROID_APP_ID, alreadyConsumed: true}, "replayed_token"],
  ]) {
    assert.deepEqual(await activate("guest", n, app), {verified: false, reason});
    assert.equal((await activation(n)).verified, false);
  }
  assert.equal((await events()).length, 0);
});

test("revérification : non vérifiée puis vérifiée, une seule fois", async () => {
  await activate("guest", 1, undefined);
  assert.deepEqual(await activate("marie", 1, GOOD), {verified: true});
  assert.deepEqual(await activate("marie", 1, GOOD), {verified: true});
  assert.deepEqual(await activate("marie", 1, undefined), {verified: true});
  const a = await activation(1);
  assert.equal(a.verified, true);
  assert.equal(a.verified_uid, "marie");
  assert.equal(a.first_uid, "guest");
  assert.equal((await events()).length, 1);
});

test("appels simultanés : un seul événement d'activation", async () => {
  const r = await Promise.all([1, 2, 3, 4].map(() => activate("guest", 1, GOOD)));
  assert.ok(r.every((x) => x.verified));
  assert.equal((await events()).length, 1);
});

test("essais limités par installation", async () => {
  for (let i = 0; i < MAX_ATTEMPTS; i++) await activate("guest", 5, undefined);
  assert.deepEqual(await activate("guest", 5, GOOD),
      {verified: false, reason: "limit"});
  assert.equal((await activation(5)).verified, false);
});

test("saisies invalides refusées", async () => {
  await assert.rejects(recordActivation({db, uid: null, app: GOOD,
    data: {installationId: INSTALL(1)}}), /Connexion requise/);
  await assert.rejects(recordActivation({db, uid: "g", app: GOOD,
    data: {installationId: "356938035643809"}}), /Installation invalide/);
});
