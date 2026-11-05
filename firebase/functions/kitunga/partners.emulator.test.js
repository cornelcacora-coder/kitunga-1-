/**
 * Test de la création de partenaire sur l'émulateur Firestore, avec Firebase
 * Auth simulé. Lancement :
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/partners.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const {createPartner} = require("./partners");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();

const fakeAuth = (error) => {
  const calls = {created: [], deleted: []};
  return {
    calls,
    createUser: async (u) => {
      if (error) throw Object.assign(new Error(error), {code: error});
      calls.created.push(u);
      return {uid: "partner1"};
    },
    deleteUser: async (uid) => calls.deleted.push(uid),
  };
};

const form = {email: " shop@test.cg ", password: "secret1", role: "Seller",
  displayName: "Boutique", phoneNumber: "060000000", category: "Boutique",
  verified: true, bio: "Bio", horraire: "8h-18h",
  subscribeType: "Mensuel - 250F"};

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/client").set({role: "User"});
});

test("admin : crée le partenaire sans changer de session", async () => {
  const auth = fakeAuth();
  const r = await createPartner({db, auth, uid: "admin", data: form});
  assert.equal(r.uid, "partner1");
  assert.equal(auth.calls.created[0].email, "shop@test.cg");
  const doc = (await db.doc("User/partner1").get()).data();
  assert.equal(doc.role, "Seller");
  assert.equal(doc.category, "Boutique");
  assert.equal(doc.Horraire, "8h-18h");
  assert.equal(doc.password, undefined); // jamais stocké
});

test("seul un administrateur peut créer un partenaire", async () => {
  for (const uid of ["client", "inconnu", null]) {
    const auth = fakeAuth();
    await assert.rejects(createPartner({db, auth, uid, data: form}),
        /administrateurs|Connexion requise/);
    assert.equal(auth.calls.created.length, 0);
  }
});

test("le rôle Admin ne peut pas être attribué", async () => {
  for (const role of ["Admin", "User", undefined]) {
    const auth = fakeAuth();
    await assert.rejects(createPartner({db, auth, uid: "admin",
      data: {...form, role}}), /type de partenaire/);
    assert.equal(auth.calls.created.length, 0);
  }
});

test("formulaire invalide et email déjà utilisé", async () => {
  await assert.rejects(createPartner({db, auth: fakeAuth(), uid: "admin",
    data: {...form, password: "123"}}), /6 caractères/);
  await assert.rejects(createPartner({db, auth: fakeAuth(), uid: "admin",
    data: {...form, email: " "}}), /adresse email/);
  await assert.rejects(createPartner({db,
    auth: fakeAuth("auth/email-already-exists"), uid: "admin", data: form}),
  /déjà associée/);
});
