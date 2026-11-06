/**
 * Module commercial : règles Firestore. Un commercial ne lit que ses propres
 * données ; personne n'écrit depuis une application.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/acquisition.rules.emulator.test.js"
 */
const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {initializeTestEnvironment, assertSucceeds, assertFails} =
  require("@firebase/rules-unit-testing");
const {doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection,
  query, where} = require("firebase/firestore");

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();

const OWNED = ["campaign_agents", "referral_codes", "acquisition_attributions",
  "commission_transactions", "commission_payouts"];
const ADMIN_ONLY = ["sales_agent_keys", "acquisition_touches", "app_activations",
  "attribution_identity_keys", "acquisition_events", "audit_logs",
  "acquisition_counters", "acquisition_limits", "commission_payer_keys"];

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-kitunga",
    firestore: {rules: fs.readFileSync(
        path.join(__dirname, "../../firestore.rules"), "utf8")},
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, "User/admin"), {role: "Admin"});
    await setDoc(doc(d, "User/agentA"), {role: "Commercial"});
    await setDoc(doc(d, "User/agentB"), {role: "Commercial"});
    await setDoc(doc(d, "User/client"), {role: "User"});
    await setDoc(doc(d, "User/seller"), {role: "Seller"});
    await setDoc(doc(d, "sales_agents/agentA"), {agent_code: "KTG001"});
    await setDoc(doc(d, "sales_agents/agentB"), {agent_code: "KTG002"});
    await setDoc(doc(d, "acquisition_campaigns/c1"), {name: "Lancement"});
    await setDoc(doc(d, "commission_rules/r1"), {activation_amount: 100});
    for (const c of OWNED) {
      await setDoc(doc(d, `${c}/a1`), {agent_uid: "agentA"});
      await setDoc(doc(d, `${c}/b1`), {agent_uid: "agentB"});
    }
    await setDoc(doc(d, "commission_payouts/a1/items/i1"),
        {agent_uid: "agentA"});
    await setDoc(doc(d, "commission_payouts/b1/items/i1"),
        {agent_uid: "agentB"});
    for (const c of ADMIN_ONLY) await setDoc(doc(d, `${c}/x`), {agent_uid: "agentA"});
  });
});
test.after(() => env.cleanup());

test("commercial : lit ses propres données", async () => {
  const d = db("agentA");
  await assertSucceeds(getDoc(doc(d, "sales_agents/agentA")));
  await assertSucceeds(getDoc(doc(d, "acquisition_campaigns/c1")));
  await assertSucceeds(getDoc(doc(d, "commission_rules/r1")));
  for (const c of OWNED) {
    await assertSucceeds(getDoc(doc(d, `${c}/a1`)));
    await assertSucceeds(getDocs(query(collection(d, c),
        where("agent_uid", "==", "agentA"))));
  }
  await assertSucceeds(getDoc(doc(d, "commission_payouts/a1/items/i1")));
});

test("commercial : jamais les données d'un autre, même en changeant l'adresse",
    async () => {
      const d = db("agentA");
      await assertFails(getDoc(doc(d, "sales_agents/agentB")));
      await assertFails(getDocs(collection(d, "sales_agents")));
      for (const c of OWNED) {
        await assertFails(getDoc(doc(d, `${c}/b1`)));
        await assertFails(getDocs(collection(d, c)));
        await assertFails(getDocs(query(collection(d, c),
            where("agent_uid", "==", "agentB"))));
      }
      await assertFails(getDoc(doc(d, "commission_payouts/b1/items/i1")));
      for (const c of ADMIN_ONLY) {
        await assertFails(getDoc(doc(d, `${c}/x`)));
      }
    });

test("commercial : ne modifie rien (commissions, attributions…)", async () => {
  const d = db("agentA");
  await assertFails(updateDoc(doc(d, "commission_transactions/a1"),
      {amount: 999999, status: "approved"}));
  await assertFails(updateDoc(doc(d, "acquisition_attributions/a1"),
      {agent_uid: "agentA"}));
  await assertFails(setDoc(doc(d, "commission_transactions/new"),
      {agent_uid: "agentA", amount: 500}));
  await assertFails(setDoc(doc(d, "commission_payouts/new"),
      {agent_uid: "agentA", amount: 500}));
  await assertFails(deleteDoc(doc(d, "commission_transactions/a1")));
  await assertFails(updateDoc(doc(d, "User/agentA"), {role: "Admin"}));
  await assertFails(updateDoc(doc(d, "User/client"), {subscribe_close_at: null}));
});

test("commercial : pas d'accès aux comptes, commandes ni paiements", async () => {
  const d = db("agentA");
  await assertFails(getDoc(doc(d, "User/client")));
  await assertFails(getDocs(collection(d, "User")));
  await assertFails(getDocs(collection(d, "Orders")));
  await assertFails(getDocs(collection(d, "Paiement")));
});

test("client et vendeur : aucun accès au module", async () => {
  for (const uid of ["client", "seller"]) {
    const d = db(uid);
    for (const c of [...OWNED, ...ADMIN_ONLY, "sales_agents",
      "acquisition_campaigns", "commission_rules"]) {
      await assertFails(getDocs(collection(d, c)));
    }
    await assertFails(setDoc(doc(d, "acquisition_touches/t"), {code: "x"}));
  }
});

test("visiteur non connecté : aucun accès", async () => {
  const d = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(d, "referral_codes/a1")));
  await assertFails(getDoc(doc(d, "acquisition_campaigns/c1")));
});

test("admin : lit tout mais n'écrit rien directement", async () => {
  const d = db("admin");
  for (const c of [...OWNED, ...ADMIN_ONLY, "sales_agents"]) {
    await assertSucceeds(getDocs(collection(d, c)));
  }
  await assertFails(updateDoc(doc(d, "commission_transactions/a1"),
      {amount: 1}));
  await assertFails(setDoc(doc(d, "audit_logs/y"), {action: "fake"}));
  await assertFails(deleteDoc(doc(d, "audit_logs/x")));
});
