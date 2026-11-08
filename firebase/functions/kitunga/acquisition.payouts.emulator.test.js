/**
 * Module commercial : validation des commissions et versements.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.payouts.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const p = require("./acquisition/payouts");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const D = (day) => new Date(Date.UTC(2026, 10, day, 12));
const A = "admin";

async function commission(id, extra = {}) {
  await db.doc(`commission_transactions/${id}`).set({type: "first_subscription",
    agent_uid: "agentA", client_uid: id, campaign_id: "c1", assignment_id: "a1",
    rule_id: "r1", amount: 100, currency: "XAF", status: "pending", flags: [],
    eligible_at: D(10), payout_id: null, ...extra});
}
const get = async (path) => (await db.doc(path).get()).data();
const review = (id, decision, extra = {}, day = 11) => p.reviewCommission({db,
  uid: A, clock: () => D(day), data: {commissionId: id, decision, ...extra}});
const actions = async () => (await db.collection("audit_logs").get()).docs
    .map((d) => d.get("action")).sort();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/agentA").set({role: "Commercial"});
  await db.doc("User/agentB").set({role: "Commercial"});
  await db.doc("User/client").set({role: "User"});
  await db.doc("sales_agents/agentA").set({agent_code: "KTG001", status: "active",
    payout_method: {type: "mobile_money", operator: "MTN", phone: "242061234567"}});
  await db.doc("sales_agents/agentB").set({agent_code: "KTG002", status: "active",
    payout_method: null});
});

test("validation : après le délai de sécurité seulement", async () => {
  await commission("c1");
  await assert.rejects(review("c1", "approve", {}, 9), /délai de sécurité/);
  assert.deepEqual(await review("c1", "approve"), {status: "approved"});
  const c = await get("commission_transactions/c1");
  assert.equal(c.approved_by, "admin");
  await assert.rejects(review("c1", "approve"), /interdit/);
  assert.deepEqual(await actions(), ["commission.approved"]);
});

test("commission signalée : vérification et note obligatoires", async () => {
  await commission("c1", {flags: ["shared_payer"]});
  await assert.rejects(review("c1", "approve"), /signalée/);
  await assert.rejects(review("c1", "approve", {acknowledgeFlags: true}),
      /signalée/);
  await review("c1", "approve", {acknowledgeFlags: true,
    reason: "Même famille, vérifié par téléphone"});
  assert.equal((await get("commission_transactions/c1")).review_note,
      "Même famille, vérifié par téléphone");
});

test("rejet et annulation : motif obligatoire, états vérifiés", async () => {
  await commission("c1");
  await commission("c2");
  await assert.rejects(review("c1", "reject"), /motif/);
  await review("c1", "reject", {reason: "Client fictif"});
  await assert.rejects(review("c1", "approve"), /interdit/);
  await review("c2", "reverse", {reason: "Abonnement remboursé"});
  assert.equal((await get("commission_transactions/c2")).status, "reversed");
  await assert.rejects(review("c2", "decide"), /Décision inconnue/);
});

test("réservé à l'admin", async () => {
  await commission("c1");
  for (const uid of ["agentA", "client", null]) {
    await assert.rejects(p.reviewCommission({db, uid, data: {commissionId: "c1",
      decision: "approve"}}), /administrateurs|Connexion requise/);
    await assert.rejects(p.decidePayout({db, uid, data: {payoutId: "x",
      decision: "paid"}}), /administrateurs|Connexion requise/);
  }
});

test("versement complet : demandé, validé, payé avec référence", async () => {
  for (const id of ["c1", "c2", "c3"]) await commission(id);
  await review("c1", "approve");
  await review("c2", "approve");
  // c3 reste en attente : pas dans le versement.
  const r = await p.requestPayout({db, uid: "agentA", data: {}});
  assert.equal(r.amount, 200);
  assert.equal(r.items, 2);
  for (const id of ["c1", "c2"]) {
    const c = await get(`commission_transactions/${id}`);
    assert.equal(c.status, "reserved");
    assert.equal(c.payout_id, r.payoutId);
  }
  assert.equal((await get("commission_transactions/c3")).status, "pending");
  await assert.rejects(p.requestPayout({db, uid: A,
    data: {agentUid: "agentA"}}), /déjà en cours/);
  await p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
    decision: "approve"}});
  await assert.rejects(p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
    decision: "paid"}}), /référence du virement/);
  await p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
    decision: "paid", externalReference: "MP261108.1234.A56789"}});
  const pay = await get(`commission_payouts/${r.payoutId}`);
  assert.equal(pay.status, "paid");
  assert.equal(pay.external_reference, "MP261108.1234.A56789");
  for (const id of ["c1", "c2"]) {
    assert.equal((await get(`commission_transactions/${id}`)).status, "paid");
  }
  await assert.rejects(p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
    decision: "reject", reason: "x"}}), /interdit/);
});

test("versement refusé : commissions de nouveau disponibles", async () => {
  await commission("c1");
  await review("c1", "approve");
  const r = await p.requestPayout({db, uid: A, data: {agentUid: "agentA"}});
  await assert.rejects(review("c1", "reverse", {reason: "x"}), /versement en cours/);
  await assert.rejects(p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
    decision: "reject"}}), /motif/);
  await p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
    decision: "reject", reason: "Numéro MoMo erroné"}});
  const c = await get("commission_transactions/c1");
  assert.equal(c.status, "approved");
  assert.equal(c.payout_id, null);
  const r2 = await p.requestPayout({db, uid: "agentA", data: {}});
  assert.equal(r2.amount, 100);
});

test("commission payée puis remboursée : contrepassation déduite ensuite",
    async () => {
      await commission("c1");
      await review("c1", "approve");
      const r = await p.requestPayout({db, uid: "agentA", data: {}});
      await p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
        decision: "approve"}});
      await p.decidePayout({db, uid: A, data: {payoutId: r.payoutId,
        decision: "paid", externalReference: "REF1"}});
      const rev = await review("c1", "reverse", {reason: "Abonnement remboursé"});
      assert.equal(rev.reversal, "reversal_c1");
      const c1 = await get("commission_transactions/c1");
      assert.equal(c1.status, "paid");
      assert.equal(c1.amount, 100, "montant d'origine jamais modifié");
      const neg = await get("commission_transactions/reversal_c1");
      assert.equal(neg.amount, -100);
      assert.equal(neg.status, "approved");
      await assert.rejects(review("c1", "reverse", {reason: "x"}),
          /déjà été contrepassée/);
      // Prochain versement : 300 - 100 = 200.
      await commission("c2", {amount: 300});
      await review("c2", "approve");
      const r2 = await p.requestPayout({db, uid: "agentA", data: {}});
      assert.equal(r2.amount, 200);
      assert.equal(r2.items, 2);
    });

test("demandes refusées : rien à verser, sans moyen de paiement, autre rôle",
    async () => {
      await assert.rejects(p.requestPayout({db, uid: "agentA", data: {}}),
          /Aucun montant/);
      await commission("b1", {agent_uid: "agentB"});
      await review("b1", "approve");
      await assert.rejects(p.requestPayout({db, uid: "agentB", data: {}}),
          /moyen de paiement/);
      await assert.rejects(p.requestPayout({db, uid: "client", data: {}}),
          /non autorisée/);
      // Un commercial ne demande jamais pour un autre.
      await commission("a1");
      await review("a1", "approve");
      const r = await p.requestPayout({db, uid: "agentB",
        data: {agentUid: "agentA"}}).catch((e) => e.message);
      assert.match(String(r), /moyen de paiement/);
      assert.equal((await get("commission_transactions/a1")).status, "approved");
    });

test("deux demandes simultanées : un seul versement", async () => {
  await commission("c1");
  await review("c1", "approve");
  const r = await Promise.allSettled([
    p.requestPayout({db, uid: "agentA", data: {}}),
    p.requestPayout({db, uid: A, data: {agentUid: "agentA"}}),
  ]);
  assert.equal(r.filter((x) => x.status === "fulfilled").length, 1);
  assert.equal((await db.collection("commission_payouts").get()).size, 1);
});
