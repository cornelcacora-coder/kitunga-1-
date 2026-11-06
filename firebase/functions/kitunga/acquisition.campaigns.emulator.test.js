/**
 * Module commercial : barèmes, campagnes, affectations et clôture.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.campaigns.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const c = require("./acquisition/campaigns");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();

const D = (day, h = 12) => new Date(Date.UTC(2026, 10, day, h));
const at = (date) => () => date; // horloge simulée
const A = "admin";

async function rule(extra = {}) {
  return (await c.createCommissionRule({db, uid: A, data: {label: "Lancement",
    activationAmount: 50, firstSubscriptionAmount: 100,
    eligiblePlans: ["quarterly", "annual"], ...extra}})).ruleId;
}
async function campaign(extra = {}) {
  return (await c.createCampaign({db, uid: A, data: {name: "Brazzaville",
    startsAt: D(1).toISOString(), endsAt: D(30).toISOString(),
    ruleId: await rule(), ...extra}})).campaignId;
}
const status = (id, s, clock, reason = "Test") =>
  c.setCampaignStatus({db, uid: A, data: {campaignId: id, status: s, reason},
    clock: at(clock)});
const assign = (campaignId, agentUid, from, to, extra = {}) =>
  c.assignAgent({db, uid: A, data: {campaignId, agentUid,
    startsAt: from.toISOString(), endsAt: to.toISOString(), ...extra}});
const get = async (path) => (await db.doc(path).get()).data();

test.beforeEach(async () => {
  for (const col of await db.listCollections()) await db.recursiveDelete(col);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/agentA").set({role: "Commercial"});
  await db.doc("sales_agents/agentA").set({agent_code: "KTG001", status: "active"});
  await db.doc("sales_agents/agentB").set({agent_code: "KTG002", status: "active"});
  await db.doc("sales_agents/agentS").set({agent_code: "KTG003",
    status: "suspended"});
});

test("barème : figé, réservé à l'admin, anti-fraude", async () => {
  const id = await rule();
  const r = await get(`commission_rules/${id}`);
  assert.equal(r.activation_amount, 50);
  assert.equal(r.currency, "XAF");
  // Activation + abonnement doit rester sous la formule la moins chère.
  await assert.rejects(rule({firstSubscriptionAmount: 450}), /sous le prix/);
  await assert.rejects(rule({eligiblePlans: ["monthly"],
    firstSubscriptionAmount: 200}), /la moins chère \(250 F\)/);
  await assert.rejects(rule({eligiblePlans: ["gratuit"]}), /formules/);
  await assert.rejects(rule({eligiblePlans: []}), /formules/);
  await assert.rejects(rule({activationAmount: 10.5}), /Montant invalide/);
  await assert.rejects(rule({activationAmount: -5}), /Montant invalide/);
  await assert.rejects(c.createCommissionRule({db, uid: "agentA", data: {}}),
      /administrateurs/);
  assert.equal(typeof c.updateCommissionRule, "undefined");
});

test("campagne : création validée, brouillon par défaut", async () => {
  const id = await campaign();
  const cp = await get(`acquisition_campaigns/${id}`);
  assert.equal(cp.status, "draft");
  assert.equal(cp.grace_days, 30);
  assert.equal(cp.hold_days, 7);
  for (const [extra, msg] of [
    [{name: ""}, /Nom/],
    [{endsAt: D(1).toISOString()}, /après la date de début/],
    [{startsAt: "pas une date"}, /Date de début invalide/],
    [{endsAt: new Date(Date.UTC(2029, 0, 1)).toISOString()}, /2 ans/],
    [{ruleId: "inconnu"}, /Barème/],
    [{graceDays: 400}, /Délai après la fin/],
  ]) {
    await assert.rejects(campaign(extra), msg, JSON.stringify(extra));
  }
});

test("statuts : activation dans les dates, clôture, archivage", async () => {
  const id = await campaign();
  await assert.rejects(status(id, "active", new Date(Date.UTC(2026, 9, 20))),
      /entre sa date de début et sa date de fin/);
  await assert.rejects(status(id, "scheduled", D(5)), /début est passée/);
  await status(id, "active", D(5));
  await assert.rejects(status(id, "draft", D(5)), /interdit/);
  await assert.rejects(c.setCampaignStatus({db, uid: A, clock: at(D(6)),
    data: {campaignId: id, status: "paused"}}), /motif/);
  await status(id, "paused", D(6));
  await status(id, "active", D(7));
  await status(id, "completed", D(8));
  await status(id, "completed", D(8)); // rejouable
  await assert.rejects(status(id, "active", D(9)), /interdit/);
  await status(id, "archived", D(9));
  await assert.rejects(status(id, "completed", D(9)), /interdit/);
  const actions = (await db.collection("audit_logs").get()).docs
      .map((d) => d.get("action"));
  for (const a of ["campaign.create", "campaign.active", "campaign.paused",
    "campaign.completed", "campaign.archived"]) {
    assert.ok(actions.includes(a), a);
  }
});

test("modification : barème figé une fois lancée", async () => {
  const id = await campaign();
  await c.updateCampaign({db, uid: A, data: {campaignId: id, name: "Pointe",
    ruleId: await rule({activationAmount: 20})}});
  await status(id, "active", D(5));
  await assert.rejects(c.updateCampaign({db, uid: A, data: {campaignId: id,
    ruleId: await rule()}}), /seuls les textes/);
  await assert.rejects(c.updateCampaign({db, uid: A, clock: at(D(5)),
    data: {campaignId: id, endsAt: D(4).toISOString()}}), /déjà passée/);
  await assign(id, "agentA", D(2), D(25));
  await assert.rejects(c.updateCampaign({db, uid: A, clock: at(D(5)),
    data: {campaignId: id, endsAt: D(20).toISOString()}}), /affectations/);
  await c.updateCampaign({db, uid: A, clock: at(D(5)),
    data: {campaignId: id, endsAt: D(29).toISOString()}});
  await status(id, "completed", D(6));
  await assert.rejects(c.updateCampaign({db, uid: A, data: {campaignId: id,
    name: "X"}}), /terminée/);
});

test("affectation : code unique, dates et commercial vérifiés", async () => {
  const id = await campaign();
  const r = await assign(id, "agentA", D(2), D(15));
  assert.match(r.referralCode, /^KTG001-[2-9A-HJKMNP-Z]{4}$/);
  const code = await get(`referral_codes/${r.referralCode}`);
  assert.equal(code.agent_uid, "agentA");
  assert.equal(code.assignment_id, r.assignmentId);
  assert.equal(code.status, "active");
  const a = await get(`campaign_agents/${r.assignmentId}`);
  assert.equal(a.referral_code, r.referralCode);
  await assert.rejects(assign(id, "agentS", D(2), D(5)), /pas actif/);
  await assert.rejects(assign(id, "inconnu", D(2), D(5)), /pas actif/);
  await assert.rejects(assign(id, "agentB", new Date(Date.UTC(2026, 9, 1)),
      D(5)), /dates de la campagne/);
  await assert.rejects(assign("inconnue", "agentB", D(2), D(5)), /introuvable/);
});

test("affectation : pas de chevauchement sans autorisation motivée", async () => {
  const id1 = await campaign();
  const id2 = await campaign({name: "Pointe-Noire"});
  await assign(id1, "agentA", D(2), D(15));
  await assert.rejects(assign(id2, "agentA", D(10), D(20)), /déjà une affectation/);
  await assert.rejects(assign(id2, "agentA", D(10), D(20),
      {allowOverlap: true}), /Indiquez pourquoi/);
  const ok = await assign(id2, "agentA", D(10), D(20),
      {allowOverlap: true, overlapReason: "Renfort marché Total"});
  const a = await get(`campaign_agents/${ok.assignmentId}`);
  assert.equal(a.allow_overlap, true);
  assert.ok(a.overlaps_with);
  await assign(id2, "agentA", D(20), D(25)); // juste après : accepté
});

test("affectation : deux demandes simultanées, une seule passe", async () => {
  const id1 = await campaign();
  const id2 = await campaign({name: "Pointe-Noire"});
  const results = await Promise.allSettled([
    assign(id1, "agentA", D(2), D(15)),
    assign(id2, "agentA", D(5), D(20)),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  const active = await db.collection("campaign_agents")
      .where("agent_uid", "==", "agentA").get();
  assert.equal(active.size, 1);
});

test("clôture : affectations fermées, codes désactivés, plus d'affectation",
    async () => {
      const id = await campaign();
      await status(id, "active", D(2));
      const a = await assign(id, "agentA", D(2), D(20));
      const b = await assign(id, "agentB", D(2), D(20));
      await status(id, "completed", D(10));
      for (const r of [a, b]) {
        assert.equal((await get(`campaign_agents/${r.assignmentId}`)).status,
            "ended");
        assert.equal((await get(`referral_codes/${r.referralCode}`)).status,
            "disabled");
      }
      assert.equal((await get(`acquisition_campaigns/${id}`))
          .assignments_closed, true);
      await assert.rejects(assign(id, "agentA", D(11), D(12)), /terminée/);
    });

test("fin d'affectation manuelle : motif obligatoire, code désactivé",
    async () => {
      const id = await campaign();
      const r = await assign(id, "agentA", D(2), D(20));
      await assert.rejects(c.endAssignment({db, uid: A,
        data: {assignmentId: r.assignmentId}}), /motif/);
      await c.endAssignment({db, uid: A, data: {assignmentId: r.assignmentId,
        status: "cancelled", reason: "Erreur de saisie"}});
      assert.equal((await get(`campaign_agents/${r.assignmentId}`)).status,
          "cancelled");
      assert.equal((await get(`referral_codes/${r.referralCode}`)).status,
          "disabled");
      await assert.rejects(c.endAssignment({db, uid: A, data: {
        assignmentId: r.assignmentId, reason: "x"}}), /interdit/);
    });

test("traitement planifié : démarre, clôture, rejouable", async () => {
  const id = await campaign({startsAt: D(10).toISOString(),
    endsAt: D(20).toISOString()});
  await status(id, "scheduled", D(5));
  const a = await assign(id, "agentA", D(10), D(20));
  const b = await assign(id, "agentB", D(10), D(12));

  let r = await c.runCampaignSchedule({db, clock: at(D(9))});
  assert.deepEqual(r, {activated: 0, completed: 0, assignmentsClosed: 0});
  r = await c.runCampaignSchedule({db, clock: at(D(10, 13))});
  assert.equal(r.activated, 1);
  assert.equal((await get(`acquisition_campaigns/${id}`)).status, "active");

  // Affectation arrivée à sa fin : fermée, campagne toujours active.
  r = await c.runCampaignSchedule({db, clock: at(D(13))});
  assert.equal(r.assignmentsClosed, 1);
  assert.equal((await get(`referral_codes/${b.referralCode}`)).status,
      "disabled");
  assert.equal((await get(`referral_codes/${a.referralCode}`)).status,
      "active");

  r = await c.runCampaignSchedule({db, clock: at(D(21))});
  assert.equal(r.completed, 1);
  assert.equal((await get(`acquisition_campaigns/${id}`)).status, "completed");
  assert.equal((await get(`referral_codes/${a.referralCode}`)).status,
      "disabled");
  r = await c.runCampaignSchedule({db, clock: at(D(22))});
  assert.deepEqual(r, {activated: 0, completed: 0, assignmentsClosed: 0});
  const system = (await db.collection("audit_logs")
      .where("actor_role", "==", "system").get()).size;
  assert.ok(system >= 3);
});

test("réservé à l'admin", async () => {
  const id = await campaign();
  for (const call of [
    () => c.createCampaign({db, uid: "agentA", data: {}}),
    () => c.updateCampaign({db, uid: "agentA", data: {campaignId: id}}),
    () => c.setCampaignStatus({db, uid: "agentA", data: {campaignId: id}}),
    () => c.assignAgent({db, uid: "agentA", data: {campaignId: id,
      agentUid: "agentA", startsAt: D(2).toISOString(),
      endsAt: D(3).toISOString()}}),
    () => c.endAssignment({db, uid: null, data: {}}),
  ]) {
    await assert.rejects(call(), /administrateurs|Connexion requise/);
  }
});
