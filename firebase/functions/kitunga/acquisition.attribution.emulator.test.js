/**
 * Module commercial : confirmation de l'attribution à l'inscription.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.attribution.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const c = require("./acquisition/campaigns");
const links = require("./acquisition/links");
const {claimAttribution, shortName} = require("./acquisition/attribution");
const {identityKey} = require("./acquisition/model");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const identitySecret = "cle-de-test-suffisamment-longue";
const D = (day, h = 12) => new Date(Date.UTC(2026, 10, day, h));
const INSTALL = (n) => `3f2b8c1e-9a4d-4e2f-8b6a-${String(n).padStart(12, "0")}`;

/** Firebase Auth simulé : date de création et email de chaque compte. */
const accounts = {};
const auth = {getUser: async (uid) => accounts[uid] ||
  {email: null, metadata: {creationTime: D(1).toUTCString()}}};
const account = (uid, created, email = `${uid}@test.cg`) => {
  accounts[uid] = {email, metadata: {creationTime: created.toUTCString()}};
};

let codeA; let codeB; let campaignId;

test.beforeEach(async () => {
  for (const col of await db.listCollections()) await db.recursiveDelete(col);
  for (const k of Object.keys(accounts)) delete accounts[k];
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("sales_agents/agentA").set({agent_code: "KTG001",
    status: "active", identity_key: identityKey("069000001", identitySecret)});
  await db.doc("sales_agents/agentB").set({agent_code: "KTG002",
    status: "active", identity_key: identityKey("069000002", identitySecret)});
  const ruleId = (await c.createCommissionRule({db, uid: "admin", data: {
    label: "R", activationAmount: 50, firstSubscriptionAmount: 100,
    eligiblePlans: ["annual"]}})).ruleId;
  campaignId = (await c.createCampaign({db, uid: "admin", data: {name: "C",
    startsAt: D(1).toISOString(), endsAt: D(30).toISOString(), ruleId}}))
      .campaignId;
  await c.setCampaignStatus({db, uid: "admin", clock: () => D(2),
    data: {campaignId, status: "active"}});
  const assign = async (agentUid) => (await c.assignAgent({db, uid: "admin",
    data: {campaignId, agentUid, startsAt: D(1).toISOString(),
      endsAt: D(20).toISOString()}})).referralCode;
  codeA = await assign("agentA");
  codeB = await assign("agentB");
});

const touch = (uid, n, code, day = 5) => links.recordTouch({db, uid,
  clock: () => D(day), data: {installationId: INSTALL(n), code,
    source: "install_referrer"}});
async function newClient(uid, {phone = "061111111", created = D(6),
  name = "Marie Mbemba"} = {}) {
  account(uid, created);
  await db.doc(`User/${uid}`).set({role: "User", phone_number: phone,
    display_name: name});
}
const claim = (uid, data, day = 6) => claimAttribution({db, auth, uid,
  identitySecret, clock: () => D(day), data});
const attributionOf = async (uid) =>
  (await db.doc(`acquisition_attributions/${uid}`).get()).data();

test("visiteur puis inscription : attribution confirmée au premier commercial",
    async () => {
      await db.doc("User/guest").set({role: "Guest"});
      await touch("guest", 1, codeA);
      await newClient("marie");
      assert.deepEqual(await claim("marie", {installationId: INSTALL(1)}),
          {status: "confirmed"});
      const a = await attributionOf("marie");
      assert.equal(a.agent_uid, "agentA");
      assert.equal(a.campaign_id, campaignId);
      assert.equal(a.status, "confirmed");
      assert.equal(a.source, "install_referrer");
      assert.equal(a.installation_id, INSTALL(1));
      assert.deepEqual(Object.keys(a.client_summary).sort(),
          ["name", "signed_up_at", "subscribed"]);
      assert.equal(a.client_summary.name, "Marie M.");
      assert.ok(!JSON.stringify(a).includes("061111111"), "pas de téléphone");
      const t = (await db.doc(`acquisition_touches/${INSTALL(1)}`).get()).data();
      assert.equal(t.status, "confirmed");
      assert.equal(t.user_uid, "marie");
      assert.ok((await db.doc(`attribution_identity_keys/${a.identity_key}`)
          .get()).exists);
      const ev = await db.collection("acquisition_events")
          .where("type", "==", "signup").get();
      assert.equal(ev.size, 1);
    });

test("FIRST TOUCH : le code saisi ensuite ne remplace pas le premier contact",
    async () => {
      await touch("guest", 1, codeA);
      await newClient("marie");
      await claim("marie", {installationId: INSTALL(1), code: codeB});
      assert.equal((await attributionOf("marie")).agent_uid, "agentA");
      assert.deepEqual(await claim("marie", {code: codeB}),
          {status: "already_attributed"});
      assert.equal((await attributionOf("marie")).agent_uid, "agentA");
    });

test("inscription : deux demandes simultanées, une seule attribution",
    async () => {
      await touch("guest", 1, codeA);
      await newClient("marie");
      const r = await Promise.all([claim("marie", {installationId: INSTALL(1)}),
        claim("marie", {code: codeB})]);
      assert.equal(r.filter((x) => x.status === "confirmed").length, 1);
      assert.equal((await db.collection("acquisition_attributions").get()).size,
          1);
    });

test("code saisi à l'inscription (iPhone, sans lien)", async () => {
  await newClient("paul");
  assert.deepEqual(await claim("paul", {code: codeB.toLowerCase()}),
      {status: "confirmed"});
  const a = await attributionOf("paul");
  assert.equal(a.agent_uid, "agentB");
  assert.equal(a.source, "manual");
  await newClient("lea");
  await db.doc(`referral_codes/${codeA}`).update({status: "disabled"});
  assert.deepEqual(await claim("lea", {code: codeA}),
      {status: "code_refused", reason: "code_disabled"});
  await assert.rejects(claim("lea", {code: "abc"}), /Code commercial invalide/);
  assert.deepEqual(await claim("lea", {}), {status: "none"});
});

test("client déjà inscrit avant le contact : pas d'attribution", async () => {
  await newClient("ancien", {created: D(1)});
  await touch("ancien", 1, codeA, 5); // 4 jours après son inscription
  assert.deepEqual(await claim("ancien", {installationId: INSTALL(1)}),
      {status: "existing_client"});
  await newClient("ancien2", {created: D(2)});
  assert.deepEqual(await claim("ancien2", {code: codeA}, 8),
      {status: "existing_client"});
  assert.equal((await db.collection("acquisition_attributions").get()).size, 0);
});

test("même personne, nouveau compte : enregistré rejeté, sans changer de commercial",
    async () => {
      await touch("g1", 1, codeA);
      await newClient("marie", {phone: "06 111 11 11"});
      await claim("marie", {installationId: INSTALL(1)});
      await touch("g2", 2, codeB);
      await newClient("marie2", {phone: "+242061111111"});
      assert.deepEqual(await claim("marie2", {installationId: INSTALL(2)}),
          {status: "rejected", reason: "duplicate_person"});
      const dup = await attributionOf("marie2");
      assert.equal(dup.status, "rejected");
      assert.equal(dup.duplicate_of, "marie");
      assert.equal((await attributionOf("marie")).agent_uid, "agentA");
    });

test("auto-parrainage : téléphone du commercial", async () => {
  await newClient("cousin", {phone: "069000001"});
  assert.deepEqual(await claim("cousin", {code: codeA}),
      {status: "rejected", reason: "self_referral"});
});

test("contact déjà utilisé par un autre compte : pas réutilisé", async () => {
  await touch("guest", 1, codeA);
  await newClient("marie");
  await claim("marie", {installationId: INSTALL(1)});
  await newClient("frere", {phone: "062222222"});
  assert.deepEqual(await claim("frere", {installationId: INSTALL(1)}),
      {status: "none"});
});

test("pas un client : visiteur anonyme, vendeur, commercial", async () => {
  await touch("guest", 1, codeA);
  accounts.guest = {email: null, metadata: {creationTime: D(5).toUTCString()}};
  assert.deepEqual(await claim("guest", {installationId: INSTALL(1)}),
      {status: "not_a_client"});
  for (const role of ["Seller", "Commercial"]) {
    account(role, D(6));
    await db.doc(`User/${role}`).set({role});
    assert.deepEqual(await claim(role, {code: codeA}), {status: "not_a_client"});
  }
  await assert.rejects(claimAttribution({db, auth, uid: null, data: {},
    identitySecret}), /Connexion requise/);
});

test("campagne terminée après le contact : attribution conservée", async () => {
  await touch("guest", 1, codeA);
  await c.setCampaignStatus({db, uid: "admin", clock: () => D(5),
    data: {campaignId, status: "completed", reason: "Fin"}});
  await newClient("marie");
  assert.deepEqual(await claim("marie", {installationId: INSTALL(1)}),
      {status: "confirmed"});
});

test("nom abrégé", () => {
  assert.equal(shortName("Marie Mbemba Ngoma"), "Marie M.");
  assert.equal(shortName("Paul"), "Paul");
  assert.equal(shortName("  "), "Client");
});
