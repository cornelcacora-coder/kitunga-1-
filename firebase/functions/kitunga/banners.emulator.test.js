/**
 * Publicités et promotions du carrousel d'accueil.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/banners.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const b = require("./banners");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const IMG = "https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fadmin%2Fpub.png?alt=media";
const list = async () => (await b.listBanners({db, uid: "admin"})).banners;
const pub = async (now) => (await b.publicBanners({db, now})).banners;
const day = 86400000;

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/marie").set({role: "User"});
  await db.doc("User/crisp").set({role: "Seller",
    display_name: "Le Crisp'nCroc", category: "Restaurant"});
  await db.doc("Product/p1").set({name: "Mosseka", seller_ref:
    db.doc("User/crisp")});
});

test("bannières d'origine : diffusées, puis reprises à l'ouverture admin",
    async () => {
      // Collection vide : l'application garde ses 3 bannières.
      assert.deepStrictEqual((await pub()).map((x) => x.title2),
          ["endroit", "rapide", "frais"]);
      await assert.rejects(b.listBanners({db, uid: "marie"}),
          /administrateurs/);
      const l = await list();
      assert.strictEqual(l.length, 3);
      assert.strictEqual(l[1].title1, "Livraison");
      assert.strictEqual(l[1].status, "live");
      assert.ok(l[0].image.startsWith("asset:assets/"));
      // Deuxième ouverture : pas de doublon.
      assert.strictEqual((await list()).length, 3);
    });

test("publicité d'un commerce : création, contrôles, diffusion, clics",
    async () => {
      await list();
      const base = {kind: "seller", sellerUid: "crisp", title1: "Le Crisp'nCroc",
        title2: "-20 %", subtitle: "Sur tous les couscous", image: IMG,
        badge: "PROMO", target: {type: "shop"}};
      await assert.rejects(b.saveBanner({db, uid: "admin", data: {...base,
        sellerUid: "marie"}}), /commerce annonceur/);
      await assert.rejects(b.saveBanner({db, uid: "admin", data: {...base,
        image: "https://exemple.com/a.png"}}), /interface Kitunga/);
      await assert.rejects(b.saveBanner({db, uid: "admin", data: {...base,
        color: "rouge"}}), /couleur invalide/);
      await assert.rejects(b.saveBanner({db, uid: "admin", data: {...base,
        target: {type: "product", value: "nope"}}}), /Produit introuvable/);
      const {id} = await b.saveBanner({db, uid: "admin", data: base});
      const saved = (await list()).find((x) => x.id === id);
      assert.strictEqual(saved.order, 3); // ajoutée à la fin
      assert.deepStrictEqual(saved.target, {type: "shop", value: "crisp"});
      assert.strictEqual(saved.sellerName, "Le Crisp'nCroc");
      assert.strictEqual(saved.color, "#E51A1A");
      assert.ok((await pub()).some((x) => x.id === id && x.badge === "PROMO"));

      await b.bannerClick({db, data: {id}});
      await b.bannerClick({db, data: {id}});
      await b.bannerClick({db, data: {id: "inconnue"}});
      assert.strictEqual((await list()).find((x) => x.id === id).clicks, 2);

      // Commerce suspendu : sa publicité n'est plus diffusée.
      await db.doc("User/crisp").update({account_status: "suspended"});
      assert.ok(!(await pub()).some((x) => x.id === id));
      const logs = (await db.collection("audit_logs").get()).docs
          .map((d) => d.get("action"));
      assert.ok(logs.includes("banner.create"));
    });

test("période de diffusion, désactivation, ordre, suppression", async () => {
  const l = await list();
  const now = new Date();
  const {id} = await b.saveBanner({db, uid: "admin", data: {kind: "app",
    title1: "Fête", title2: "des mères", image: IMG,
    startsAt: new Date(now.getTime() + day).toISOString(),
    endsAt: new Date(now.getTime() + 3 * day).toISOString(),
    target: {type: "category", value: "Boutique"}}});
  await assert.rejects(b.saveBanner({db, uid: "admin", data: {title1: "X",
    image: IMG, startsAt: "2026-12-10", endsAt: "2026-12-01"}}),
  /après le début/);
  assert.strictEqual((await list()).find((x) => x.id === id).status,
      "scheduled");
  assert.ok(!(await pub(now)).some((x) => x.id === id));
  assert.ok((await pub(new Date(now.getTime() + 2 * day)))
      .some((x) => x.id === id));
  assert.ok(!(await pub(new Date(now.getTime() + 4 * day)))
      .some((x) => x.id === id));

  await b.setBannerActive({db, uid: "admin", data: {id: l[0].id,
    active: false}});
  assert.strictEqual((await pub()).length, 2);
  assert.strictEqual((await list())[0].status, "off");

  const ids = (await list()).map((x) => x.id).reverse();
  await b.reorderBanners({db, uid: "admin", data: {ids}});
  assert.deepStrictEqual((await list()).map((x) => x.id), ids);
  await assert.rejects(b.reorderBanners({db, uid: "admin",
    data: {ids: [ids[0], ids[0]]}}), /Ordre invalide/);

  await b.deleteBanner({db, uid: "admin", data: {id}});
  assert.strictEqual((await list()).length, 3);
  await assert.rejects(b.deleteBanner({db, uid: "admin", data: {id}}),
      /introuvable/);
});
