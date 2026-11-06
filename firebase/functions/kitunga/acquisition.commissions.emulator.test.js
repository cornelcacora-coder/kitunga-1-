/**
 * Module commercial : génération des commissions (premier abonnement,
 * activation) et blocage de l'archivage.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.commissions.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const c = require("./acquisition/campaigns");
const links = require("./acquisition/links");
const {claimAttribution} = require("./acquisition/attribution");
const {recordActivation, ANDROID_APP_ID} = require("./acquisition/activations");
const k = require("./acquisition/commissions");
const {identityKey} = require("./acquisition/model");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const identitySecret = "cle-de-test-suffisamment-longue";
const D = (day, h = 12) => new Date(Date.UTC(2026, 10, day, h));
const INSTALL = (n) => `3f2b8c1e-9a4d-4e2f-8b6a-${String(n).padStart(12, "0")}`;
const AGENT_PHONE = "069000001";
const auth = {getUser: async (uid) => ({email: `${uid}@test.cg`,
  metadata: {creationTime: D(6).toUTCString()}})};

let campaignId; let code;

test.beforeEach(async () => {
  for (const col of await db.listCollections()) await db.recursiveDelete(col);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("sales_agents/agentA").set({agent_code: "KTG001",
    status: "active", identity_key: identityKey(AGENT_PHONE, identitySecret)});
  const ruleId = (await c.createCommissionRule({db, uid: "admin", data: {
    label: "R", activationAmount: 50, firstSubscriptionAmount: 100,
    eligiblePlans: ["quarterly", "annual"]}})).ruleId;
  campaignId = (await c.createCampaign({db, uid: "admin", data: {name: "C",
    startsAt: D(1).toISOString(), endsAt: D(30).toISOString(), ruleId,
    graceDays: 10, holdDays: 7}})).campaignId;
  await c.setCampaignStatus({db, uid: "admin", clock: () => D(2),
    data: {campaignId, status: "active"}});
  code = (await c.assignAgent({db, uid: "admin", data: {campaignId,
    agentUid: "agentA", startsAt: D(1).toISOString(),
    endsAt: D(20).toISOString()}})).referralCode;
});

/** Client apporté : contact, inscription, attribution confirmée. */
async function client(uid, n, phone = `06${String(n).padStart(7, "1")}`) {
  await links.recordTouch({db, uid: `guest${n}`, clock: () => D(5),
    data: {installationId: INSTALL(n), code, source: "install_referrer"}});
  await db.doc(`User/${uid}`).set({role: "User", phone_number: phone,
    display_name: "Client Test"});
  const r = await claimAttribution({db, auth, uid, identitySecret,
    clock: () => D(6), data: {installationId: INSTALL(n)}});
  assert.equal(r.status, "confirmed");
}

/** Paiement d'abonnement qui passe à « Réussi » (comme confirmSubscription). */
let payN = 0;
async function pay(uid, {plan = "annual", amount = 1000, payer = "061234567",
  day = 8, status = "Réussi", before = "En attente", kind = "subscription"} = {}) {
  const id = `pay${++payN}`;
  const after = {kind, plan, amount, status, payer_phone: payer,
    user_ref: db.doc(`User/${uid}`)};
  await db.doc(`Paiement/${id}`).set(after);
  return k.processSubscriptionPayment({db, paymentId: id, before:
    {...after, status: before}, after, identitySecret, clock: () => D(day)});
}
const commission = async (id) =>
  (await db.doc(`commission_transactions/${id}`).get()).data();

test("premier abonnement payé : commission en attente, montant du barème",
    async () => {
      await client("marie", 1);
      assert.deepEqual(await pay("marie"), {created: true, status: "pending"});
      const cm = await commission("first_subscription_marie");
      assert.equal(cm.amount, 100);
      assert.equal(cm.currency, "XAF");
      assert.equal(cm.agent_uid, "agentA");
      assert.equal(cm.campaign_id, campaignId);
      assert.equal(cm.status, "pending");
      assert.deepEqual(cm.flags, []);
      assert.equal(cm.source_ref, "Paiement/pay1");
      assert.equal(cm.eligible_at.toDate().toISOString(),
          "2026-11-15T12:00:00.000Z");
      assert.ok(!JSON.stringify(cm).includes("061234567"));
      const a = (await db.doc("acquisition_attributions/marie").get()).data();
      assert.equal(a.client_summary.subscribed, true);
      const audit = await db.collection("audit_logs")
          .where("action", "==", "commission.create").get();
      assert.equal(audit.size, 1);
    });

test("notification reçue plusieurs fois, même en même temps : une commission",
    async () => {
      await client("marie", 1);
      const id = "payX";
      const after = {kind: "subscription", plan: "annual", amount: 1000,
        status: "Réussi", payer_phone: "061234567",
        user_ref: db.doc("User/marie")};
      await db.doc(`Paiement/${id}`).set(after);
      const run = () => k.processSubscriptionPayment({db, paymentId: id,
        before: {...after, status: "En attente"}, after, identitySecret,
        clock: () => D(8)});
      const r = await Promise.all([run(), run(), run()]);
      assert.equal(r.filter((x) => x.created).length, 1);
      assert.equal((await run()).created, false);
      assert.equal((await db.collection("commission_transactions").get()).size,
          1);
    });

test("pas de commission : en attente, refusé, gratuit, autre type", async () => {
  await client("marie", 1);
  for (const opts of [{status: "En attente"}, {status: "Echec"},
    {amount: 0}, {kind: "order"}, {before: "Réussi"}]) {
    assert.equal((await pay("marie", opts)).created, false,
        JSON.stringify(opts));
  }
  assert.equal((await db.collection("commission_transactions").get()).size, 0);
});

test("pas de commission : formule non éligible ou pas le premier abonnement",
    async () => {
      await client("marie", 1);
      assert.equal((await pay("marie", {plan: "monthly", amount: 250}))
          .reason, "plan_not_eligible");
      // Le mensuel était déjà un abonnement payé : l'annuel n'est pas le premier.
      assert.equal((await pay("marie")).reason, "not_first_subscription");
      assert.equal((await db.collection("commission_transactions").get()).size,
          0);
    });

test("pas de commission : client non attribué ou attribution rejetée",
    async () => {
      await db.doc("User/inconnu").set({role: "User"});
      assert.equal((await pay("inconnu")).reason, "no_attribution");
      await client("marie", 1);
      await db.doc("acquisition_attributions/marie").update({status: "rejected"});
      assert.equal((await pay("marie")).reason, "no_attribution");
    });

test("hors délai : abonnement après la fin de l'affectation + délai", async () => {
  await client("marie", 1);
  // Affectation jusqu'au 20, délai 10 jours : le 1er décembre est trop tard.
  assert.equal((await pay("marie", {day: 31})).reason, "out_of_window");
  assert.equal((await pay("paul", {day: 31})).reason, "no_attribution");
});

test("le commercial paie lui-même : commission rejetée", async () => {
  await client("marie", 1);
  assert.deepEqual(await pay("marie", {payer: AGENT_PHONE}),
      {created: true, status: "rejected"});
  const cm = await commission("first_subscription_marie");
  assert.equal(cm.status_reason, "payer_is_agent");
});

test("un même numéro paie pour deux clients : signalé à l'admin", async () => {
  await client("marie", 1);
  await client("paul", 2);
  await pay("marie", {payer: "065555555"});
  await pay("paul", {payer: "+242 065555555"});
  assert.deepEqual((await commission("first_subscription_marie")).flags, []);
  assert.deepEqual((await commission("first_subscription_paul")).flags,
      ["shared_payer"]);
});

test("commercial suspendu entre-temps : commission signalée", async () => {
  await client("marie", 1);
  await db.doc("sales_agents/agentA").update({status: "suspended"});
  await pay("marie");
  const cm = await commission("first_subscription_marie");
  assert.equal(cm.status, "pending");
  assert.deepEqual(cm.flags, ["agent_not_active"]);
});

test("activation : attribution + activation attestée, dans les deux ordres",
    async () => {
      const GOOD = {appId: ANDROID_APP_ID, alreadyConsumed: false};
      // Ordre 1 : activation attestée avant l'inscription.
      await recordActivation({db, uid: "guest1", app: GOOD,
        data: {installationId: INSTALL(1)}});
      await client("marie", 1);
      assert.deepEqual(await k.tryActivationCommission({db, clientUid: "marie",
        clock: () => D(6)}), {created: true, status: "pending"});
      assert.equal((await commission("activation_marie")).amount, 50);
      // Ordre 2 : inscription d'abord, activation attestée ensuite.
      await client("paul", 2);
      assert.equal((await k.tryActivationCommission({db, clientUid: "paul"}))
          .reason, "activation_not_verified");
      await recordActivation({db, uid: "paul", app: undefined,
        data: {installationId: INSTALL(2)}});
      assert.equal((await k.activationCommissionsForInstallation({db,
        installation: INSTALL(2)}))[0].reason, "activation_not_verified");
      await recordActivation({db, uid: "paul", app: GOOD,
        data: {installationId: INSTALL(2)}});
      const r = await k.activationCommissionsForInstallation({db,
        installation: INSTALL(2), clock: () => D(7)});
      assert.deepEqual(r, [{created: true, status: "pending"}]);
      // Rejoué : rien de plus.
      assert.equal((await k.tryActivationCommission({db, clientUid: "paul"}))
          .created, false);
      assert.equal((await db.collection("commission_transactions")
          .where("type", "==", "activation").get()).size, 2);
    });

test("archivage bloqué tant que des commissions ne sont pas réglées",
    async () => {
      await client("marie", 1);
      await pay("marie");
      await c.setCampaignStatus({db, uid: "admin", clock: () => D(9),
        data: {campaignId, status: "completed", reason: "Fin"}});
      await assert.rejects(c.setCampaignStatus({db, uid: "admin",
        clock: () => D(9), data: {campaignId, status: "archived"}}),
      /pas encore réglées/);
      await db.doc("commission_transactions/first_subscription_marie")
          .update({status: "paid"});
      await c.setCampaignStatus({db, uid: "admin", clock: () => D(9),
        data: {campaignId, status: "archived"}});
    });
