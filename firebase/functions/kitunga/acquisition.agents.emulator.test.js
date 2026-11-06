/**
 * Module commercial : gestion des commerciaux par l'admin (Auth simulé).
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.agents.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const {createSalesAgent, updateSalesAgent, setSalesAgentStatus} =
  require("./acquisition/agents");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const identitySecret = "cle-de-test-suffisamment-longue";

/** Firebase Auth simulé : emails uniques, uid successifs. */
function fakeAuth() {
  const users = new Map();
  let n = 0;
  return {
    users,
    deleted: [],
    createUser: async ({email}) => {
      for (const u of users.values()) {
        if (u.email === email) {
          throw Object.assign(new Error("exists"),
              {code: "auth/email-already-exists"});
        }
      }
      const uid = `agent${++n}`;
      users.set(uid, {email, disabled: false});
      return {uid};
    },
    deleteUser: async function(uid) {
      users.delete(uid);
      this.deleted.push(uid);
    },
    updateUser: async (uid, changes) => {
      Object.assign(users.get(uid), changes);
    },
  };
}

const form = (extra = {}) => ({email: " Agent@Test.cg ", password: "secret12",
  displayName: "Jean Commercial", phone: "06 123 45 67",
  payoutMethod: {type: "mobile_money", phone: "061234567"}, ...extra});
const create = (auth, data = form(), uid = "admin") =>
  createSalesAgent({db, auth, uid, data, identitySecret});
const logs = async () =>
  (await db.collection("audit_logs").get()).docs.map((d) => d.data().action);

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/client").set({role: "User"});
  await db.doc("User/sales").set({role: "Commercial"});
});

test("réservé à l'admin", async () => {
  for (const uid of [null, "client", "sales", "inconnu"]) {
    await assert.rejects(create(fakeAuth(), form(), uid),
        /administrateurs|Connexion requise/);
  }
  assert.equal((await db.collection("sales_agents").get()).size, 0);
});

test("création : compte, profil Commercial, fiche et journal", async () => {
  const auth = fakeAuth();
  const r = await create(auth);
  assert.deepEqual(r, {uid: "agent1", agentCode: "KTG001"});
  assert.equal(auth.users.get("agent1").email, "agent@test.cg");
  const user = (await db.doc("User/agent1").get()).data();
  assert.equal(user.role, "Commercial");
  assert.equal(user.subscribe_close_at, undefined);
  const agent = (await db.doc("sales_agents/agent1").get()).data();
  assert.equal(agent.agent_code, "KTG001");
  assert.equal(agent.status, "active");
  assert.equal(agent.phone, "242061234567");
  assert.equal(agent.created_by, "admin");
  assert.deepEqual(agent.payout_method,
      {type: "mobile_money", operator: "MTN", phone: "242061234567"});
  assert.ok(!agent.identity_key.includes("061234567"));
  assert.equal(agent.password, undefined);
  assert.ok((await db.doc(`sales_agent_keys/${agent.identity_key}`).get())
      .exists);
  assert.deepEqual(await logs(), ["agent.create"]);
  const r2 = await create(auth, form({email: "b@test.cg", phone: "065555555"}));
  assert.equal(r2.agentCode, "KTG002");
});

test("création : 5 en même temps, numéros tous différents", async () => {
  const auth = fakeAuth();
  const results = await Promise.all([1, 2, 3, 4, 5].map((i) =>
    create(auth, form({email: `a${i}@test.cg`, phone: `06500000${i}`}))));
  const codes = results.map((r) => r.agentCode).sort();
  assert.deepEqual(codes, ["KTG001", "KTG002", "KTG003", "KTG004", "KTG005"]);
});

test("création : même téléphone refusé, compte annulé si conflit", async () => {
  const auth = fakeAuth();
  await create(auth);
  await assert.rejects(create(auth, form({email: "b@test.cg",
    phone: "+242 061234567"})), /déjà celui d'un autre commercial/);
  assert.equal(auth.users.size, 1);
  // Course : deux créations simultanées avec le même numéro.
  const auth2 = fakeAuth();
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  const results = await Promise.allSettled([
    create(auth2, form({email: "x@test.cg", phone: "069999999"})),
    create(auth2, form({email: "y@test.cg", phone: "069999999"})),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(auth2.users.size, 1, "le compte perdant est supprimé");
  assert.equal((await db.collection("sales_agents").get()).size, 1);
});

test("création : saisies invalides refusées", async () => {
  const auth = fakeAuth();
  const bad = [
    [{email: ""}, /adresse email/],
    [{password: "court"}, /8 caractères/],
    [{displayName: " "}, /nom du commercial/],
    [{phone: "12"}, /téléphone invalide/],
    [{payoutMethod: {type: "paypal"}}, /Mobile Money ou banque/],
    [{payoutMethod: {type: "bank", bankName: "BGFI"}}, /bancaires/],
    [{payoutMethod: {type: "mobile_money", operator: "X", phone: "061111111"}},
      /Opérateur/],
  ];
  for (const [extra, msg] of bad) {
    await assert.rejects(create(auth, form(extra)), msg, JSON.stringify(extra));
  }
  assert.equal(auth.users.size, 0);
  await create(auth);
  await assert.rejects(create(auth, form({phone: "065555555"})),
      /déjà associée/);
});

test("modification : nom, téléphone et paiement, avec journal", async () => {
  const auth = fakeAuth();
  await create(auth);
  const oldKey = (await db.doc("sales_agents/agent1").get()).get("identity_key");
  await updateSalesAgent({db, uid: "admin", identitySecret, data: {
    agentUid: "agent1", displayName: "Jean K.", phone: "065555555",
    payoutMethod: {type: "bank", bankName: "BGFI", accountHolder: "Jean K.",
      accountNumber: "CG12 3456 7890"}}});
  const agent = (await db.doc("sales_agents/agent1").get()).data();
  assert.equal(agent.display_name, "Jean K.");
  assert.equal(agent.phone, "242065555555");
  assert.equal(agent.payout_method.type, "bank");
  assert.equal((await db.doc("User/agent1").get()).get("phone_number"),
      "242065555555");
  assert.ok(!(await db.doc(`sales_agent_keys/${oldKey}`).get()).exists);
  assert.ok((await db.doc(`sales_agent_keys/${agent.identity_key}`).get())
      .exists);
  await create(auth, form({email: "b@test.cg", phone: "067777777"}));
  await assert.rejects(updateSalesAgent({db, uid: "admin", identitySecret,
    data: {agentUid: "agent2", phone: "065555555"}}), /déjà celui/);
  await assert.rejects(updateSalesAgent({db, uid: "sales", identitySecret,
    data: {agentUid: "agent1", displayName: "Pirate"}}), /administrateurs/);
  assert.deepEqual((await logs()).sort(),
      ["agent.create", "agent.create", "agent.update"]);
});

test("statuts : suspension, réactivation, archivage définitif", async () => {
  const auth = fakeAuth();
  await create(auth);
  const set = (status, reason = "Contrôle") => setSalesAgentStatus({db, auth,
    uid: "admin", data: {agentUid: "agent1", status, reason}});
  await assert.rejects(setSalesAgentStatus({db, auth, uid: "admin",
    data: {agentUid: "agent1", status: "suspended"}}), /motif/);
  await set("suspended");
  assert.equal(auth.users.get("agent1").disabled, false);
  await set("active", "");
  await set("archived", "Fin de contrat");
  assert.equal((await db.doc("sales_agents/agent1").get()).get("status"),
      "archived");
  assert.equal(auth.users.get("agent1").disabled, true);
  await set("archived", "Relance"); // rejouable
  await assert.rejects(set("active", ""), /interdit/);
  await assert.rejects(updateSalesAgent({db, uid: "admin", identitySecret,
    data: {agentUid: "agent1", displayName: "X"}}), /archivé/);
  await assert.rejects(setSalesAgentStatus({db, auth, uid: "sales",
    data: {agentUid: "agent1", status: "active"}}), /administrateurs/);
  assert.deepEqual((await logs()).sort(), ["agent.active", "agent.archived",
    "agent.create", "agent.suspended"]);
});
