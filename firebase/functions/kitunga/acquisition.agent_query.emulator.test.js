/**
 * Module commercial : espace commercial (ses propres données seulement).
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.agent_query.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const {salesAgentQuery} = require("./acquisition/agent_query");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const D = (day) => new Date(Date.UTC(2026, 10, day, 12));
const q = (uid, data) => salesAgentQuery({db, uid, data, clock: () => D(20)});

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  for (const [uid, role] of [["agentA", "Commercial"], ["agentB", "Commercial"],
    ["admin", "Admin"], ["client", "User"]]) {
    await db.doc(`User/${uid}`).set({role});
  }
  await db.doc("sales_agents/agentA").set({agent_code: "KTG001",
    display_name: "Jean", status: "active", identity_key: "secret",
    payout_method: {type: "mobile_money", phone: "242061234567"}});
  await db.doc("sales_agents/agentB").set({agent_code: "KTG002",
    display_name: "Paul", status: "active"});
  await db.doc("acquisition_campaigns/c1").set({name: "Brazza"});
  await db.doc("campaign_agents/s1").set({agent_uid: "agentA", campaign_id: "c1",
    status: "active", starts_at: D(1), ends_at: D(30),
    referral_code: "KTG001-X7P9"});
  for (const [t, d, a] of [["click", 18, "agentA"], ["click", 19, "agentA"],
    ["signup", 19, "agentA"], ["click", 19, "agentB"]]) {
    await db.collection("acquisition_events").add({type: t, agent_uid: a,
      campaign_id: "c1", created_at: D(d), ip_hash: "h"});
  }
  await db.doc("acquisition_attributions/clientX").set({agent_uid: "agentA",
    status: "confirmed", source: "install_referrer", confirmed_at: D(19),
    identity_key: "empreinte-secrete", installation_id: "install-9f3c",
    client_summary: {name: "Marie M.", signed_up_at: D(19), subscribed: true}});
  await db.doc("acquisition_attributions/clientY").set({agent_uid: "agentB",
    status: "confirmed", client_summary: {name: "Autre"}});
  await db.doc("commission_transactions/first_subscription_clientX").set({
    agent_uid: "agentA", client_uid: "clientX", type: "first_subscription",
    amount: 100, status: "approved", created_at: D(19)});
  await db.doc("commission_transactions/activation_clientY").set({
    agent_uid: "agentB", client_uid: "clientY", type: "activation", amount: 50,
    status: "paid", created_at: D(19)});
  await db.doc("commission_payouts/p1").set({agent_uid: "agentB", amount: 50,
    status: "paid"});
});

test("réservé aux commerciaux", async () => {
  for (const uid of ["admin", "client", null, "inconnu"]) {
    await assert.rejects(q(uid, {view: "home"}),
        /réservé aux commerciaux|Connexion requise/);
  }
});

test("accueil : campagne, lien, chiffres et soldes du commercial seul", async () => {
  const h = await q("agentA", {view: "home"});
  assert.equal(h.profile.agentCode, "KTG001");
  assert.equal(h.profile.payoutMethodSet, true);
  assert.equal(h.assignments[0].campaignName, "Brazza");
  assert.equal(h.assignments[0].link,
      "https://kitunga-xtvpe4.web.app/r/KTG001-X7P9");
  assert.deepEqual(h.stats, {clicks: 2, activations: 0, signups: 1,
    subscriptions: 0});
  assert.equal(h.commissions.approved, 100);
  assert.equal(h.commissions.paid, 0);
  assert.ok(!JSON.stringify(h).includes("secret"));
});

test("clients : informations limitées, jamais ceux d'un autre", async () => {
  const {clients} = await q("agentA", {view: "clients"});
  assert.equal(clients.length, 1);
  assert.deepEqual(Object.keys(clients[0]).sort(),
      ["confirmedAt", "name", "signedUpAt", "source", "status", "subscribed"]);
  assert.equal(clients[0].name, "Marie M.");
  const json = JSON.stringify(clients);
  for (const secret of ["clientX", "empreinte-secrete", "install-9f3c"]) {
    assert.ok(!json.includes(secret), secret);
  }
});

test("commissions et versements : les siens seulement", async () => {
  const {commissions} = await q("agentA", {view: "commissions"});
  assert.equal(commissions.length, 1);
  assert.ok(!JSON.stringify(commissions).includes("clientX"));
  assert.equal((await q("agentA", {view: "payouts"})).payouts.length, 0);
  assert.equal((await q("agentB", {view: "payouts"})).payouts.length, 1);
  // Un paramètre pour un autre commercial est ignoré.
  const other = await q("agentA", {view: "commissions", agentUid: "agentB"});
  assert.equal(other.commissions.length, 1);
  assert.equal(other.commissions[0].type, "first_subscription");
});
