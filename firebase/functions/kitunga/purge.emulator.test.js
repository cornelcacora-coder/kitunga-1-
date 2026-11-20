/**
 * Nettoyage des données de test.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/purge.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const {purgeTestData, storagePath} = require("./purge");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();

// Faux Storage : fichiers en mémoire.
function fakeBucket(names) {
  const files = new Set(names);
  const file = (name) => ({
    name,
    copy: async (dest) => {
      if (!files.has(name)) throw Object.assign(new Error("nf"), {code: 404});
      files.add(dest.name);
    },
    delete: async () => {
      if (!files.delete(name)) throw Object.assign(new Error("nf"), {code: 404});
    },
  });
  return {
    files,
    file,
    getFiles: async ({prefix}) =>
      [[...files].filter((f) => f.startsWith(prefix)).map(file)],
  };
}
const fakeAuth = () => ({deleted: [], async deleteUsers(uids) {
  this.deleted.push(...uids);
  return {successCount: uids.length};
}});
const url = (path) => "https://firebasestorage.googleapis.com/v0/b/x/o/" +
  encodeURIComponent(path) + "?alt=media";
const exists = async (p) => (await db.doc(p).get()).exists;

let bucket;
let auth;
test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  bucket = fakeBucket([
    "users/shop/uploads/logo.png",
    "users/shop/uploads/p1.png",
    "users/liv/uploads/preuve.jpg",
    "users/admin/uploads/p2.png",
    "users/marie/uploads/avatar.png",
  ]);
  auth = fakeAuth();
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/marie").set({role: "User", display_name: "Marie"});
  await db.doc("User/agent").set({role: "Commercial"});
  await db.doc("User/shop").set({role: "Seller", display_name: "Chez Paul"});
  await db.doc("User/liv").set({role: "Deliver", display_name: "Jean"});
  await db.doc("Product/p1").set({name: "A",
    prod_img: url("users/shop/uploads/p1.png"),
    seller_ref: db.doc("User/shop")});
  await db.doc("Product/p2").set({name: "B",
    prod_img: url("users/admin/uploads/p2.png"),
    seller_ref: db.doc("User/shop")});
  await db.doc("Cart/c1").set({user_ref: db.doc("User/marie"),
    product_ref: db.doc("Product/p1")});
  await db.doc("Orders/o1").set({status: "En attente",
    user_ref: db.doc("User/marie"), created_at: new Date()});
  await db.doc("OrderItems/i1").set({order_ref: "ORD-1"});
  await db.doc("Paiement/order").set({status: "Réussi", amount: 3500});
  await db.doc("Paiement/sub").set({status: "Réussi", kind: "subscription",
    user_ref: db.doc("User/marie")});
  await db.doc("Categories/c").set({name: "Boutique"});
  await db.doc("sales_agents/agent").set({status: "active"});
});

const ctx = (data, uid = "admin") => ({db, auth, bucket, uid, data,
  clock: () => new Date(Date.UTC(2026, 10, 8, 14, 30))});

test("réservé à l'admin", async () => {
  for (const uid of ["marie", "shop", "agent", null]) {
    await assert.rejects(purgeTestData(ctx({mode: "preview"}, uid)),
        /administrateurs|Connexion requise/);
    await assert.rejects(purgeTestData(ctx({mode: "purge",
      confirm: "SUPPRIMER"}, uid)), /administrateurs|Connexion requise/);
  }
  assert.ok(await exists("Product/p1"));
});

test("aperçu : rien n'est supprimé", async () => {
  const r = await purgeTestData(ctx({mode: "preview"}));
  assert.deepStrictEqual(r.counts, {sellers: 1, delivers: 1, products: 2,
    orders: 1, orderItems: 1, carts: 1, payments: 1,
    keptSubscriptionPayments: 1});
  assert.deepStrictEqual(r.sellers, ["Chez Paul"]);
  assert.ok(await exists("Product/p1"));
  assert.strictEqual(bucket.files.size, 5);
});

test("suppression : confirmation, sauvegarde, périmètre exact", async () => {
  await assert.rejects(purgeTestData(ctx({mode: "purge", confirm: "oui"})),
      /SUPPRIMER/);
  const r = await purgeTestData(ctx({mode: "purge", confirm: "SUPPRIMER"}));
  assert.strictEqual(r.runId, "20261108T143000");
  assert.strictEqual(r.files, 4);
  assert.strictEqual(r.accounts, 2);
  // Supprimé.
  for (const p of ["User/shop", "User/liv", "Product/p1", "Product/p2",
    "Cart/c1", "Orders/o1", "OrderItems/i1", "Paiement/order"]) {
    assert.strictEqual(await exists(p), false, p);
  }
  // Conservé.
  for (const p of ["User/admin", "User/marie", "User/agent", "Paiement/sub",
    "Categories/c", "sales_agents/agent"]) {
    assert.ok(await exists(p), p);
  }
  assert.deepStrictEqual(auth.deleted.sort(), ["liv", "shop"]);
  assert.ok(bucket.files.has("users/marie/uploads/avatar.png"));
  assert.ok(!bucket.files.has("users/admin/uploads/p2.png"));
  assert.ok(bucket.files.has(
      "purge_backups/20261108T143000/files/users/shop/uploads/logo.png"));
  // Sauvegarde des documents.
  const items = await db.collection("purge_backups/20261108T143000/items")
      .get();
  assert.strictEqual(items.size, 8);
  const p1 = await db.doc(
      "purge_backups/20261108T143000/items/Product__p1").get();
  assert.strictEqual(p1.get("data").seller_ref.path, "User/shop");
  const h = await purgeTestData(ctx({mode: "history"}));
  assert.strictEqual(h.runs[0].status, "terminé");
  // Relancer ne casse rien (il ne reste rien à supprimer).
  const again = await purgeTestData(ctx({mode: "purge", confirm: "SUPPRIMER"}));
  assert.strictEqual(again.counts.products, 0);
});

test("restauration : documents et fichiers remis", async () => {
  await purgeTestData(ctx({mode: "purge", confirm: "SUPPRIMER"}));
  const r = await purgeTestData(ctx({mode: "restore",
    runId: "20261108T143000"}));
  assert.deepStrictEqual(r, {documents: 8, files: 4});
  assert.ok(await exists("Product/p1"));
  assert.ok(await exists("User/shop"));
  assert.strictEqual((await db.doc("Orders/o1").get()).get("status"),
      "En attente");
  assert.ok(bucket.files.has("users/shop/uploads/logo.png"));
  await assert.rejects(purgeTestData(ctx({mode: "restore", runId: "x"})),
      /introuvable/);
});

test("adresse d'image vers chemin Storage", () => {
  assert.strictEqual(storagePath(url("users/a/uploads/b c.png")),
      "users/a/uploads/b c.png");
  assert.strictEqual(storagePath("asset:assets/x.png"), null);
  assert.strictEqual(storagePath(""), null);
});
