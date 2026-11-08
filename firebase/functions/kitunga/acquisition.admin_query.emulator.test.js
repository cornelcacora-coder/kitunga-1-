/**
 * Module commercial : lecture des données pour l'interface admin.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.admin_query.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const {salesAdminQuery, periodOf} = require("./acquisition/admin_query");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const D = (day, h = 12) => new Date(Date.UTC(2026, 10, day, h));
const q = (data, uid = "admin") =>
  salesAdminQuery({db, uid, data, clock: () => D(20)});

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/agentA").set({role: "Commercial"});
  await db.doc("sales_agents/agentA").set({agent_code: "KTG001",
    display_name: "Jean", status: "active", created_at: D(1),
    identity_key: "secret-hash", phone: "242061234567"});
  await db.doc("sales_agents/agentB").set({agent_code: "KTG002",
    display_name: "Paul", status: "suspended", created_at: D(2)});
  await db.doc("acquisition_campaigns/c1").set({name: "Brazza",
    status: "active", starts_at: D(1), ends_at: D(30), rule_id: "r1",
    created_at: D(1)});
  await db.doc("commission_rules/r1").set({label: "R", activation_amount: 50,
    first_subscription_amount: 100, eligible_plans: ["annual"],
    created_at: D(1)});
  await db.doc("campaign_agents/a1").set({campaign_id: "c1", agent_uid: "agentA",
    agent_code: "KTG001", status: "active", starts_at: D(1), ends_at: D(25),
    referral_code: "KTG001-X7P9"});
  const ev = (type, day, agent = "agentA") => db.collection("acquisition_events")
      .add({type, campaign_id: "c1", agent_uid: agent, created_at: D(day),
        ip_hash: "h"});
  for (const [t, d] of [["click", 15], ["click", 16], ["click", 17],
    ["click", 18], ["signup", 16], ["signup", 17], ["subscription", 18],
    ["activation", 16], ["click", 3]]) await ev(t, d);
  await ev("click", 19, "agentB");
  const cm = (id, extra) => db.doc(`commission_transactions/${id}`).set({
    type: "first_subscription", agent_uid: "agentA", campaign_id: "c1",
    client_uid: id, amount: 100, status: "pending", flags: [],
    created_at: D(18), ...extra});
  await cm("p1", {});
  await cm("ap", {status: "approved"});
  await cm("pd", {status: "paid", created_at: D(2)});
  await cm("rv", {type: "reversal", amount: -100, status: "approved"});
});

test("réservé à l'admin", async () => {
  for (const uid of ["agentA", null]) {
    await assert.rejects(q({view: "overview"}, uid),
        /administrateurs|Connexion requise/);
  }
  await assert.rejects(q({view: "inconnue"}), /Vue inconnue/);
});

test("vue d'ensemble : compteurs, conversion, commissions", async () => {
  const o = await q({view: "overview", period: "month"});
  assert.equal(o.activeCampaigns, 1);
  assert.equal(o.activeAgents, 1);
  assert.equal(o.clicks, 6); // le clic du 3 compte aussi (mois de novembre)
  assert.equal(o.signups, 2);
  assert.equal(o.subscriptions, 1);
  assert.equal(o.activations, 1);
  assert.equal(o.conversion.subscriptionPerSignup, 50);
  assert.equal(o.commissions.generated, 300); // p1 + ap + pd (2 novembre)
  assert.equal(o.commissions.paid, 100);
  assert.equal(o.commissions.due, 0); // ap 100 + contrepassation -100
  assert.equal(o.commissions.pending, 100);
});

test("filtres : période, commercial, campagne", async () => {
  const week = await q({view: "overview", period: "week"});
  // Semaine du lundi 16 novembre au 20.
  assert.equal(week.clicks, 4);
  const agentB = await q({view: "overview", agentUid: "agentB"});
  assert.equal(agentB.clicks, 1);
  assert.equal(agentB.commissions.paid, 0);
  const custom = await q({view: "overview", period: "custom",
    from: D(16, 0).toISOString(), to: D(17, 0).toISOString()});
  assert.equal(custom.clicks, 1); // clic du 16 à midi
  assert.equal(custom.signups, 1);
  await assert.rejects(q({view: "overview", period: "custom", from: "x"}),
      /Période invalide/);
});

test("période à l'heure de Brazzaville (UTC+1)", () => {
  const now = new Date("2026-11-18T23:30:00Z"); // 19 nov. 00 h 30 à Brazzaville
  assert.equal(periodOf({period: "today"}, now).start.toISOString(),
      "2026-11-18T23:00:00.000Z");
  assert.equal(periodOf({period: "month"}, now).start.toISOString(),
      "2026-10-31T23:00:00.000Z");
  assert.equal(periodOf({period: "week"}, now).start.toISOString(),
      "2026-11-15T23:00:00.000Z");
});

test("listes : commerciaux, campagnes, affectations, commissions", async () => {
  const {agents} = await q({view: "agents"});
  assert.equal(agents.length, 2);
  const a = agents.find((x) => x.uid === "agentA");
  assert.equal(a.currentAssignment.code, "KTG001-X7P9");
  assert.equal(a.identity_key, undefined);
  assert.ok(!JSON.stringify(agents).includes("secret-hash"));
  const c = await q({view: "campaigns"});
  assert.equal(c.campaigns[0].name, "Brazza");
  assert.equal(c.rules[0].firstSubscriptionAmount, 100);
  const detail = await q({view: "campaign", campaignId: "c1"});
  assert.equal(detail.assignments[0].link,
      "https://kitunga-xtvpe4.web.app/r/KTG001-X7P9");
  const all = await q({view: "commissions"});
  assert.equal(all.commissions.length, 4);
  const pending = await q({view: "commissions", status: "pending"});
  assert.deepEqual(pending.commissions.map((x) => x.id), ["p1"]);
  assert.ok(!JSON.stringify(all).includes("ip_hash"));
  const events = JSON.stringify(await q({view: "audit"}));
  assert.ok(!events.includes("ip_hash"));
});
