/**
 * Catalogue admin : catégories, produits, fiches partenaires.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/catalog.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const cat = require("./catalog");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const IMG = "https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fadmin%2Fa.png?alt=media";
const logs = async () => (await db.collection("audit_logs").get()).docs
    .map((d) => d.get("action")).sort();
const categories = async () => (await cat.catalogQuery({db, uid: "admin",
  data: {view: "categories"}})).categories;
const byName = async (n) => (await categories()).find((c) => c.name === n);

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/marie").set({role: "User", display_name: "Marie",
    email: "marie@test.cg", created_time: new Date("2026-11-01")});
  await db.doc("User/shop").set({role: "Seller", display_name: "Chez Paul",
    category: "Restaurant", email: "paul@test.cg"});
  await db.doc("User/shop2").set({role: "Seller", display_name: "Pharma Plus",
    category: "Pharmacie"});
  await db.doc("User/liv").set({role: "Deliver", display_name: "Jean",
    category: "Vendeur"});
  await db.doc("Product/p1").set({name: "Poulet DG", price: 5000,
    sale_price: 5000, seller_ref: db.doc("User/shop"), section: "Plats",
    options: [{name: "Taille"}], created_at: new Date("2026-11-02")});
  await db.doc("Product/p2").set({name: "Doliprane", price: 1500,
    seller_ref: db.doc("User/shop2")});
});

test("réservé à l'admin", async () => {
  for (const uid of ["marie", "shop", null]) {
    await assert.rejects(cat.catalogQuery({db, uid,
      data: {view: "categories"}}), /administrateurs|Connexion requise/);
    await assert.rejects(cat.saveCategory({db, uid, data: {name: "X",
      image: IMG}}), /administrateurs|Connexion requise/);
    await assert.rejects(cat.deleteProduct({db, uid, data: {id: "p1",
      reason: "x"}}), /administrateurs|Connexion requise/);
    await assert.rejects(cat.savePartner({db, uid, data: {uid: "shop",
      bio: "x"}}), /administrateurs|Connexion requise/);
  }
  assert.deepStrictEqual(await logs(), []);
});

test("catégories : reprise des 5 d'origine, avec le nombre de commerces",
    async () => {
      const list = await categories();
      assert.deepStrictEqual(list.map((c) => c.name),
          ["Boutique", "Restaurant", "Pharmacie", "Magasin", "Fast Food"]);
      assert.strictEqual(list[1].sellers, 1);
      assert.strictEqual(list[0].sellers, 0);
      assert.ok(list[0].image.startsWith("asset:assets/images/categories/"));
      // Une seule reprise, même ouverte deux fois.
      assert.strictEqual((await categories()).length, 5);
      assert.deepStrictEqual(await logs(), ["category.seed"]);
    });

test("catégories : ajout, nom unique, image obligatoire, couleur", async () => {
  await categories();
  await assert.rejects(cat.saveCategory({db, uid: "admin",
    data: {name: "Boulangerie"}}), /image/);
  await assert.rejects(cat.saveCategory({db, uid: "admin",
    data: {name: "Boulangerie", image: "https://evil.com/a.png"}}),
  /interface Kitunga/);
  await assert.rejects(cat.saveCategory({db, uid: "admin",
    data: {name: "restaurant", image: IMG}}), /déjà ce nom/);
  await assert.rejects(cat.saveCategory({db, uid: "admin",
    data: {name: "Boulangerie", image: IMG, color: "rouge"}}), /Couleur/);
  const {id} = await cat.saveCategory({db, uid: "admin",
    data: {name: "Boulangerie", image: IMG, color: "#FFEEDD", order: 5}});
  const b = await byName("Boulangerie");
  assert.strictEqual(b.id, id);
  assert.strictEqual(b.image, IMG);
  assert.strictEqual(b.active, true);
});

test("catégories : renommer déplace les commerces, changer l'image seule",
    async () => {
      const r = await byName("Restaurant");
      const res = await cat.saveCategory({db, uid: "admin", data: {id: r.id,
        name: "Restaurants", color: r.color, order: r.order}});
      assert.strictEqual(res.sellersMoved, 1);
      assert.strictEqual((await db.doc("User/shop").get()).get("category"),
          "Restaurants");
      // Image conservée quand on n'en envoie pas.
      assert.strictEqual((await byName("Restaurants")).image, r.image);
      await cat.saveCategory({db, uid: "admin", data: {id: r.id,
        name: "Restaurants", image: IMG, color: r.color, order: r.order}});
      assert.strictEqual((await byName("Restaurants")).image, IMG);
      assert.strictEqual((await byName("Restaurants")).sellers, 1);
      await assert.rejects(cat.saveCategory({db, uid: "admin",
        data: {id: "absent", name: "Z"}}), /introuvable/);
    });

test("catégories : suppression protégée par un remplacement", async () => {
  const r = await byName("Restaurant");
  const f = await byName("Fast Food");
  await assert.rejects(cat.deleteCategory({db, uid: "admin",
    data: {id: r.id}}), /remplacement/);
  await assert.rejects(cat.deleteCategory({db, uid: "admin",
    data: {id: r.id, reassignTo: r.id}}), /invalide/);
  const res = await cat.deleteCategory({db, uid: "admin",
    data: {id: r.id, reassignTo: f.id}});
  assert.strictEqual(res.sellersMoved, 1);
  assert.strictEqual((await db.doc("User/shop").get()).get("category"),
      "Fast Food");
  // Catégorie vide : suppression directe.
  await cat.deleteCategory({db, uid: "admin",
    data: {id: (await byName("Magasin")).id}});
  assert.deepStrictEqual((await categories()).map((c) => c.name),
      ["Boutique", "Pharmacie", "Fast Food"]);
  assert.ok((await logs()).filter((a) => a === "category.delete").length, 2);
});

test("produits : liste avec commerce et catégorie, filtres", async () => {
  const {products} = await cat.catalogQuery({db, uid: "admin",
    data: {view: "products"}});
  assert.deepStrictEqual(products.map((p) => p.name),
      ["Poulet DG", "Doliprane"]);
  assert.deepStrictEqual(products[0].seller,
      {uid: "shop", name: "Chez Paul", category: "Restaurant"});
  assert.strictEqual(products[0].price, 5000);
  assert.strictEqual(products[0].published, true);
  // Prix de vente pris dans sale_price, comme l'application.
  await db.doc("Product/p2").update({sale_price: 1200, on_sale: false});
  const p2 = (await cat.catalogQuery({db, uid: "admin",
    data: {view: "products", sellerUid: "shop2"}})).products[0];
  assert.strictEqual(p2.price, 1200);
  assert.strictEqual(p2.published, false);
  const q = async (data) => (await cat.catalogQuery({db, uid: "admin",
    data: {view: "products", ...data}})).products.map((p) => p.id);
  assert.deepStrictEqual(await q({q: "paul"}), ["p1"]);
  assert.deepStrictEqual(await q({sellerUid: "shop2"}), ["p2"]);
  assert.deepStrictEqual(await q({category: "Pharmacie"}), ["p2"]);
  assert.deepStrictEqual(await q({missingImage: true}).then((l) => l.sort()),
      ["p1", "p2"]);
});

test("produits : ajout, modification (options gardées), contrôles", async () => {
  const base = {name: "Riz", price: 1000, quantity: 10, sellerUid: "shop",
    prodImg: IMG};
  await assert.rejects(cat.saveProduct({db, uid: "admin", data: {...base,
    sellerUid: "liv"}}), /Commerce introuvable/);
  await assert.rejects(cat.saveProduct({db, uid: "admin", data: {...base,
    price: -1}}), /Prix/);
  await assert.rejects(cat.saveProduct({db, uid: "admin", data: {...base,
    quantity: undefined}}), /Stock/);
  await assert.rejects(cat.saveProduct({db, uid: "admin", data: {...base,
    tag: "Promo"}}), /Mise en avant/);
  await assert.rejects(cat.saveProduct({db, uid: "admin", data: {...base,
    prodImg: ""}}), /photo avant de publier/);
  // Brouillon sans photo : accepté (non publié).
  await cat.saveProduct({db, uid: "admin", data: {...base, prodImg: "",
    published: false}});
  const {id} = await cat.saveProduct({db, uid: "admin", data: {...base,
    unit: "kg", tag: "Nouveauté", express: true}});
  const p = (await db.doc(`Product/${id}`).get()).data();
  assert.strictEqual(p.seller_ref.path, "User/shop");
  assert.strictEqual(p.price, 1000);
  assert.strictEqual(p.sale_price, 1000);
  assert.strictEqual(p.on_sale, true);
  assert.strictEqual(p.instant_disponibilty, true);
  assert.strictEqual(p.specifications, "Nouveauté");
  assert.strictEqual(p.quantity, 10);
  assert.deepStrictEqual(p.options, []);

  await db.doc("Product/p1").update({prod_img: "https://autre.cdn/p1.jpg"});
  await assert.rejects(cat.saveProduct({db, uid: "admin", data: {id: "p1",
    name: "x", price: 1, quantity: 1, prodImg: "https://autre.cdn/p2.jpg"}}),
  /interface Kitunga/);
  await cat.saveProduct({db, uid: "admin", data: {id: "p1",
    name: "Poulet DG maison", price: 5500, quantity: 3,
    prodImg: "https://autre.cdn/p1.jpg"}});
  const p1 = (await db.doc("Product/p1").get()).data();
  assert.strictEqual(p1.name, "Poulet DG maison");
  assert.strictEqual(p1.sale_price, 5500);
  assert.strictEqual(p1.on_sale, true);
  assert.deepStrictEqual(p1.options, [{name: "Taille"}]);
  assert.strictEqual(p1.prod_img, "https://autre.cdn/p1.jpg");
  assert.strictEqual(p1.seller_ref.path, "User/shop");
  // Sans image envoyée : celle en place est gardée.
  await cat.saveProduct({db, uid: "admin", data: {id: "p1",
    name: "Poulet DG", price: 5500, quantity: 3, published: false}});
  assert.strictEqual((await db.doc("Product/p1").get()).get("prod_img"),
      "https://autre.cdn/p1.jpg");
  assert.strictEqual((await db.doc("Product/p1").get()).get("on_sale"), false);
  await assert.rejects(cat.saveProduct({db, uid: "admin", data: {id: "p1",
    name: "x", price: 1, quantity: 1, sellerUid: "shop2"}}),
  /ne change pas de commerce/);
});

test("produits : suppression avec motif, paniers en cours nettoyés",
    async () => {
      await db.doc("Cart/c1").set({product_ref: db.doc("Product/p1"),
        is_ordered: false});
      await db.doc("Cart/c2").set({product_ref: db.doc("Product/p1"),
        is_ordered: true});
      await assert.rejects(cat.deleteProduct({db, uid: "admin",
        data: {id: "p1"}}), /motif/);
      const res = await cat.deleteProduct({db, uid: "admin",
        data: {id: "p1", reason: "Doublon"}});
      assert.strictEqual(res.cartsCleared, 1);
      assert.strictEqual((await db.doc("Product/p1").get()).exists, false);
      assert.strictEqual((await db.doc("Cart/c1").get()).exists, false);
      assert.strictEqual((await db.doc("Cart/c2").get()).exists, true);
      assert.deepStrictEqual(await logs(), ["product.delete"]);
    });

test("partenaires : listes, recherche, nombre de produits", async () => {
  const q = async (data) => (await cat.catalogQuery({db, uid: "admin",
    data: {view: "partners", ...data}})).partners;
  const sellers = await q({role: "Seller"});
  assert.deepStrictEqual(sellers.map((s) => s.uid), ["shop", "shop2"]);
  assert.strictEqual(sellers[0].products, 1);
  assert.strictEqual(sellers[0].accountStatus, "active");
  assert.deepStrictEqual((await q({role: "Deliver"})).map((s) => s.uid),
      ["liv"]);
  assert.deepStrictEqual((await q({role: "Seller", q: "pharma"}))
      .map((s) => s.uid), ["shop2"]);
  assert.deepStrictEqual((await q({role: "Seller", category: "Restaurant"}))
      .map((s) => s.uid), ["shop"]);
  const {clients, total} = await cat.catalogQuery({db, uid: "admin",
    data: {view: "clients", q: "marie"}});
  assert.strictEqual(total, 1);
  assert.strictEqual(clients[0].uid, "marie");
});

test("partenaires : modification de la fiche", async () => {
  await categories();
  await assert.rejects(cat.savePartner({db, uid: "admin",
    data: {uid: "admin", bio: "x"}}), /introuvable/);
  await assert.rejects(cat.savePartner({db, uid: "admin",
    data: {uid: "marie", bio: "x"}}), /non modifiable/);
  await cat.savePartner({db, uid: "admin", data: {uid: "marie",
    displayName: "Marie N.", phone: "061234567"}});
  assert.strictEqual((await db.doc("User/marie").get()).get("display_name"),
      "Marie N.");
  await assert.rejects(cat.savePartner({db, uid: "admin",
    data: {uid: "shop", category: "Inconnue"}}), /Catégorie inconnue/);
  await assert.rejects(cat.savePartner({db, uid: "admin",
    data: {uid: "shop", phone: "12"}}), /téléphone/);
  await assert.rejects(cat.savePartner({db, uid: "admin",
    data: {uid: "shop"}}), /Aucune modification/);
  await cat.savePartner({db, uid: "admin", data: {uid: "shop",
    displayName: "Chez Paul & Fils", category: "Fast Food",
    phone: "061234567", horraire: "8h-22h", photoUrl: IMG,
    businessCover: IMG, verified: true}});
  const u = (await db.doc("User/shop").get()).data();
  assert.strictEqual(u.display_name, "Chez Paul & Fils");
  assert.strictEqual(u.category, "Fast Food");
  assert.strictEqual(u.Horraire, "8h-22h");
  assert.strictEqual(u.photo_url, IMG);
  assert.strictEqual(u.Business_cover, IMG);
  assert.strictEqual(u.verified, true);
  assert.strictEqual(u.role, "Seller");
  assert.ok((await logs()).includes("partner.update"));
});

test("catégories pour l'application : d'origine, puis visibles seulement",
    async () => {
      const names = async () => (await cat.publicCategories({db})).categories
          .map((c) => c.name);
      assert.deepStrictEqual(await names(),
          ["Boutique", "Restaurant", "Pharmacie", "Magasin", "Fast Food"]);
      const m = await byName("Magasin");
      await cat.saveCategory({db, uid: "admin", data: {id: m.id,
        name: "Magasin", color: m.color, order: m.order, active: false}});
      await cat.saveCategory({db, uid: "admin", data: {name: "Boulangerie",
        image: IMG, order: 5}});
      assert.deepStrictEqual(await names(), ["Boutique", "Restaurant",
        "Pharmacie", "Fast Food", "Boulangerie"]);
      const b = (await cat.publicCategories({db})).categories[4];
      assert.deepStrictEqual(b, {name: "Boulangerie", image: IMG,
        color: "#F2F2F5"});
    });
