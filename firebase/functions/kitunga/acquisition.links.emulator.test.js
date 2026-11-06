/**
 * Module commercial : lien /r/{code}, clics et premier contact.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.links.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const c = require("./acquisition/campaigns");
const links = require("./acquisition/links");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const secret = "cle-de-test-suffisamment-longue";
const D = (day, h = 12) => new Date(Date.UTC(2026, 10, day, h));
const clock = () => D(5);
const ANDROID = "Mozilla/5.0 (Linux; Android 14; SM-A146P) Chrome/120 Mobile";
const IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Safari";
const INSTALL = (n) => `3f2b8c1e-9a4d-4e2f-8b6a-${String(n).padStart(12, "0")}`;

let codeA; let codeB; let campaignId;

async function setup() {
  for (const col of await db.listCollections()) await db.recursiveDelete(col);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/agentA").set({role: "Commercial"});
  await db.doc("User/client").set({role: "User"});
  await db.doc("User/guest").set({role: "Guest"});
  await db.doc("sales_agents/agentA").set({agent_code: "KTG001", status: "active"});
  await db.doc("sales_agents/agentB").set({agent_code: "KTG002", status: "active"});
  const ruleId = (await c.createCommissionRule({db, uid: "admin", data: {
    label: "R", activationAmount: 50, firstSubscriptionAmount: 100,
    eligiblePlans: ["annual"]}})).ruleId;
  campaignId = (await c.createCampaign({db, uid: "admin", data: {name: "C",
    startsAt: D(1).toISOString(), endsAt: D(30).toISOString(), ruleId}}))
      .campaignId;
  await c.setCampaignStatus({db, uid: "admin", clock,
    data: {campaignId, status: "active"}});
  const assign = async (agentUid) => (await c.assignAgent({db, uid: "admin",
    data: {campaignId, agentUid, startsAt: D(1).toISOString(),
      endsAt: D(20).toISOString()}})).referralCode;
  codeA = await assign("agentA");
  codeB = await assign("agentB");
}

/** Requête et réponse HTTP simulées (comme Express). */
async function click(path, {ua = ANDROID, ip = "41.202.10.20", method = "GET",
  database = db} = {}) {
  const res = {
    statusCode: 200, headers: {}, body: null, location: null,
    set(k, v) {
      this.headers[k] = v; return this;
    },
    status(code) {
      this.statusCode = code; return this;
    },
    type() {
      return this;
    },
    send(body) {
      this.body = body;
    },
    redirect(code, url) {
      this.statusCode = code; this.location = url;
    },
  };
  const headers = {"user-agent": ua, "x-forwarded-for": `${ip}, 10.0.0.1`};
  const req = {path, method, ip, get: (h) => headers[h.toLowerCase()]};
  await links.handleReferralClick(req, res, {db: database, secret, clock});
  return res;
}

const events = async (type = "click") =>
  (await db.collection("acquisition_events").where("type", "==", type).get())
      .docs.map((d) => ({id: d.id, ...d.data()}));
const touch = (uid, n, code, extra = {}) => links.recordTouch({db, uid, clock,
  data: {installationId: INSTALL(n), code, source: "install_referrer",
    ...extra}});

test.beforeEach(setup);

test("lien : clic enregistré puis Google Play avec le code", async () => {
  const res = await click(`/r/${codeA.toLowerCase()}`);
  assert.equal(res.statusCode, 302);
  assert.equal(res.headers["Cache-Control"], "private, no-store");
  const url = new URL(res.location);
  assert.equal(url.searchParams.get("id"), "com.ntemoconsulting.kitunga");
  const ref = new URLSearchParams(url.searchParams.get("referrer"));
  assert.equal(ref.get("kitunga_code"), codeA);
  const [ev] = await events();
  assert.equal(ref.get("kitunga_click"), ev.id);
  assert.equal(ev.agent_uid, "agentA");
  assert.equal(ev.campaign_id, campaignId);
  assert.equal(ev.platform, "android");
  assert.ok(!JSON.stringify(ev).includes("41.202"), "IP jamais en clair");
});

test("lien : aperçus WhatsApp/Facebook et HEAD ne comptent pas", async () => {
  for (const ua of ["WhatsApp/2.23.20 A", "facebookexternalhit/1.1",
    "TelegramBot (like TwitterBot)"]) {
    const res = await click(`/r/${codeA}`, {ua});
    assert.equal(res.statusCode, 200);
  }
  await click(`/r/${codeA}`, {method: "HEAD"});
  assert.equal((await events()).length, 0);
});

test("lien : iPhone et ordinateur reçoivent une page avec le code", async () => {
  const res = await click(`/r/${codeA}`, {ua: IPHONE});
  assert.equal(res.statusCode, 200);
  assert.ok(res.body.includes(codeA));
  assert.ok(res.body.includes("play.google.com"));
  assert.equal((await events())[0].platform, "ios");
});

test("lien : code faux, désactivé ou campagne arrêtée, sans attribution",
    async () => {
      await db.doc("sales_agents/agentB").update({status: "suspended"});
      for (const path of ["/r/n'importe", "/r/KTG009-ABCD", `/r/${codeB}`,
        "/r/"]) {
        const res = await click(path);
        assert.equal(res.statusCode, 302, path);
        assert.ok(!res.location.includes("referrer"), path);
        const page = await click(path, {ua: IPHONE});
        assert.ok(!page.body.includes("KTG"), path);
      }
      await c.setCampaignStatus({db, uid: "admin", clock, data: {campaignId,
        status: "paused", reason: "Test"}});
      const res = await click(`/r/${codeA}`);
      assert.ok(!res.location.includes("referrer"));
      assert.equal((await events()).length, 0);
    });

test("lien : 30 clics par adresse et par jour, puis plus comptés", async () => {
  for (let i = 0; i < links.MAX_CLICKS_PER_IP_PER_DAY + 3; i++) {
    const res = await click(`/r/${codeA}`);
    assert.equal(res.statusCode, 302);
  }
  await click(`/r/${codeA}`, {ip: "41.202.10.99"});
  assert.equal((await events()).length, links.MAX_CLICKS_PER_IP_PER_DAY + 1);
});

test("lien : panne de la base, l'utilisateur va quand même sur Play",
    async () => {
      const broken = {doc: () => {
        throw new Error("indisponible");
      }, collection: () => {
        throw new Error("indisponible");
      }};
      const res = await click(`/r/${codeA}`, {database: broken});
      assert.equal(res.statusCode, 302);
      assert.ok(res.location.startsWith("https://play.google.com/"));
      assert.ok(!res.location.includes("referrer"));
    });

test("contact : premier contact provisoire, clic vérifié", async () => {
  await click(`/r/${codeA}`);
  const [ev] = await events();
  assert.deepEqual(await touch("guest", 1, codeA, {clickId: ev.id,
    referrerClickAt: Math.floor(D(5).getTime() / 1000)}), {accepted: true});
  const t = (await db.doc(`acquisition_touches/${INSTALL(1)}`).get()).data();
  assert.equal(t.status, "provisional");
  assert.equal(t.agent_uid, "agentA");
  assert.equal(t.click_verified, true);
  assert.equal(t.created_by_uid, "guest");
  await touch("client", 2, codeA, {clickId: "faux1234567890"});
  assert.equal((await db.doc(`acquisition_touches/${INSTALL(2)}`).get())
      .get("click_verified"), false);
  assert.equal((await events("touch")).length, 2);
});

test("contact : le premier commercial garde l'appareil (FIRST TOUCH)",
    async () => {
      await touch("guest", 1, codeA);
      const r = await touch("guest", 1, codeB);
      assert.deepEqual(r, {accepted: false, reason: "already_touched",
        sameCode: false});
      assert.equal((await db.doc(`acquisition_touches/${INSTALL(1)}`).get())
          .get("agent_uid"), "agentA");
    });

test("contact : deux commerciaux en même temps, un seul gagne", async () => {
  const results = await Promise.all([touch("guest", 7, codeA),
    touch("client", 7, codeB)]);
  assert.equal(results.filter((r) => r.accepted).length, 1);
  assert.equal((await events("touch")).length, 1);
});

test("contact : refus (commercial, code arrêté, client déjà attribué, abus)",
    async () => {
      assert.equal((await touch("agentA", 1, codeA)).reason, "not_a_client");
      await db.doc("acquisition_attributions/client").set({agent_uid: "agentB"});
      assert.equal((await touch("client", 2, codeA)).reason,
          "already_attributed");
      for (let n = 10; n < 13; n++) {
        assert.ok((await touch("guest", n, codeA)).accepted);
      }
      assert.equal((await touch("guest", 13, codeA)).reason, "limit");
      await db.doc(`referral_codes/${codeB}`).update({status: "disabled"});
      assert.equal((await touch("newbie", 20, codeB)).reason, "code_disabled");
      assert.equal((await db.collection("acquisition_touches").get()).size, 3);
    });

test("contact : saisies invalides refusées", async () => {
  await assert.rejects(links.recordTouch({db, uid: null, data: {}}),
      /Connexion requise/);
  await assert.rejects(touch("guest", 1, "pas-un-code"), /Code invalide/);
  await assert.rejects(links.recordTouch({db, uid: "guest", data: {
    installationId: "356938035643809", code: codeA,
    source: "install_referrer"}}), /Installation invalide/);
  await assert.rejects(touch("guest", 1, codeA, {source: "radio"}),
      /Origine inconnue/);
});
