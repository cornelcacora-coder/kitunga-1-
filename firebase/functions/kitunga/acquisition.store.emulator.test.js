/**
 * Module commercial : écritures sûres face aux appels simultanés et répétés.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.store.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const {createOnce, transition} = require("./acquisition/store");
const {COLLECTIONS} = require("./acquisition/model");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
});

test("création unique : 20 appels simultanés, un seul document", async () => {
  const ref = db.doc(`${COLLECTIONS.commissions}/first_subscription_client1`);
  const results = await Promise.all(Array.from({length: 20}, (_, i) =>
    createOnce(ref, {amount: 100, attempt: i})));
  assert.equal(results.filter(Boolean).length, 1);
  const snap = await ref.get();
  assert.equal(snap.get("amount"), 100);
});

test("création unique en transaction : un seul gagnant", async () => {
  const ref = db.doc(`${COLLECTIONS.attributions}/client1`);
  const tryClaim = (agent) => db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return false;
    tx.create(ref, {agent_uid: agent});
    return true;
  }).catch(() => false);
  const results = await Promise.all(
      ["A", "B", "C", "D", "E"].map(tryClaim));
  assert.equal(results.filter(Boolean).length, 1);
  const winner = (await ref.get()).get("agent_uid");
  assert.equal(results[["A", "B", "C", "D", "E"].indexOf(winner)], true);
});

test("statut : transition vérifiée et journalisée", async () => {
  const ref = db.doc(`${COLLECTIONS.commissions}/activation_c1`);
  await ref.set({status: "pending", amount: 100});
  const from = await transition(db, ref, "commission", "approved",
      {actorUid: "admin", actorRole: "Admin"});
  assert.equal(from, "pending");
  assert.equal((await ref.get()).get("status"), "approved");
  const logs = await db.collection(COLLECTIONS.audit).get();
  assert.equal(logs.size, 1);
  const log = logs.docs[0].data();
  assert.equal(log.action, "commission.approved");
  assert.equal(log.target, ref.path);
  assert.equal(log.details.from, "pending");
  await assert.rejects(transition(db, ref, "commission", "pending"),
      /interdit/);
  await assert.rejects(transition(db, db.doc("commission_transactions/x"),
      "commission", "approved"), /introuvable/);
  assert.equal((await db.collection(COLLECTIONS.audit).get()).size, 1);
});

test("statut : deux validations simultanées, une seule réussit", async () => {
  const ref = db.doc(`${COLLECTIONS.payouts}/p1`);
  await ref.set({status: "approved", amount: 600});
  const results = await Promise.allSettled([
    transition(db, ref, "payout", "paid", {actorUid: "a1"}),
    transition(db, ref, "payout", "paid", {actorUid: "a2"}),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal((await db.collection(COLLECTIONS.audit).get()).size, 1);
});
