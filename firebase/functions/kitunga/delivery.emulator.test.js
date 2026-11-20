/**
 * Remise sécurisée et reçus.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/delivery.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const d = require("./delivery");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const PHOTO = "https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fjean%2Fp.jpg?alt=media";
const order = async () => (await db.doc("Orders/o1").get()).data();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/marie").set({role: "User", display_name: "Marie",
    phone_number: "061234567"});
  await db.doc("User/autre").set({role: "User"});
  await db.doc("User/shop").set({role: "Seller", display_name: "Chez Paul",
    category: "Restaurant"});
  await db.doc("User/jean").set({role: "Deliver", display_name: "Jean"});
  await db.doc("User/paul").set({role: "Deliver", display_name: "Paul"});
  await db.doc("Orders/o1").set({status: "encours",
    user_ref: db.doc("User/marie"), seller_ref: db.doc("User/shop"),
    deliver_reference: db.doc("User/jean"), deliverer_ref: "jean",
    order_unique_reference: "ORD-1", total_amount: 6000, delivery_fees: 1000,
    delivery_zone: "Poto-Poto", delivery_location: "Rue 12",
    created_at: new Date(Date.UTC(2026, 10, 8, 10))});
  await db.doc("OrderItems/i1").set({order_ref: "ORD-1",
    item_name: "Poulet DG", quantity: 2, price_at_purchase: 2500,
    options: "Grande"});
  await db.doc("Paiement/pay").set({order_ref: db.doc("Orders/o1"),
    status: "Réussi", reference_id: "MTN-123"});
});

test("code : réservé au client, stable, absent du document commande",
    async () => {
      for (const uid of ["autre", "jean", "shop"]) {
        await assert.rejects(d.deliveryCode({db, uid, data: {orderId: "o1"}}),
            /Seul le client/);
      }
      await assert.rejects(d.deliveryCode({db, uid: null,
        data: {orderId: "o1"}}), /Connexion requise/);
      const a = await d.deliveryCode({db, uid: "marie", data: {orderId: "o1"}});
      assert.match(a.code, /^\d{4}$/);
      const b = await d.deliveryCode({db, uid: "marie", data: {orderId: "o1"}});
      assert.strictEqual(b.code, a.code);
      // Le code n'est pas dans la commande (lisible par d'autres comptes),
      // mais dans delivery_codes, fermée aux applications.
      const o = await order();
      assert.ok(!Object.keys(o).some((k) => k.includes("code")));
      assert.strictEqual((await db.doc("delivery_codes/o1").get())
          .get("code"), a.code);
    });

test("remise : bon livreur, bon code, photo obligatoire", async () => {
  const {code} = await d.deliveryCode({db, uid: "marie",
    data: {orderId: "o1"}});
  await assert.rejects(d.confirmDelivery({db, uid: "marie",
    data: {orderId: "o1", code, photoUrl: PHOTO}}), /Réservé aux livreurs/);
  await assert.rejects(d.confirmDelivery({db, uid: "paul",
    data: {orderId: "o1", code, photoUrl: PHOTO}}), /pas la vôtre/);
  await assert.rejects(d.confirmDelivery({db, uid: "jean",
    data: {orderId: "o1", code}}), /photo/);
  await assert.rejects(d.confirmDelivery({db, uid: "jean",
    data: {orderId: "o1", code: "12", photoUrl: PHOTO}}), /4 chiffres/);
  await d.confirmDelivery({db, uid: "jean",
    data: {orderId: "o1", code, photoUrl: PHOTO}});
  const o = await order();
  assert.strictEqual(o.status, "Livrer");
  assert.strictEqual(o.delivery_code_verified, true);
  assert.strictEqual(o.delivery_photo, PHOTO);
  assert.ok(o.delivered_at);
  // Plus de code une fois livrée.
  const after = await d.deliveryCode({db, uid: "marie",
    data: {orderId: "o1"}});
  assert.deepStrictEqual(after, {code: null, done: true});
});

test("remise : sans code client, puis codes faux et blocage", async () => {
  await assert.rejects(d.confirmDelivery({db, uid: "jean",
    data: {orderId: "o1", code: "1234", photoUrl: PHOTO}}),
  /n'a pas encore de code/);
  const {code} = await d.deliveryCode({db, uid: "marie",
    data: {orderId: "o1"}});
  const wrong = code === "1234" ? "4321" : "1234";
  for (let i = 1; i <= 4; i++) {
    await assert.rejects(d.confirmDelivery({db, uid: "jean",
      data: {orderId: "o1", code: wrong, photoUrl: PHOTO}}),
    new RegExp(`Il reste ${5 - i} essai`));
  }
  await assert.rejects(d.confirmDelivery({db, uid: "jean",
    data: {orderId: "o1", code: wrong, photoUrl: PHOTO}}), /bloquée/);
  // Même le bon code est refusé une fois bloqué.
  await assert.rejects(d.confirmDelivery({db, uid: "jean",
    data: {orderId: "o1", code, photoUrl: PHOTO}}), /bloquée/);
  const o = await order();
  assert.strictEqual(o.status, "encours");
  assert.strictEqual(o.delivery_issue.type, "code_locked");
});

test("problème de livraison signalé par le livreur", async () => {
  await assert.rejects(d.reportDeliveryIssue({db, uid: "jean",
    data: {orderId: "o1", type: "xx"}}), /inconnu/);
  await assert.rejects(d.reportDeliveryIssue({db, uid: "jean",
    data: {orderId: "o1", type: "other"}}), /Décrivez/);
  await assert.rejects(d.reportDeliveryIssue({db, uid: "paul",
    data: {orderId: "o1", type: "absent"}}), /pas la vôtre/);
  await d.reportDeliveryIssue({db, uid: "jean",
    data: {orderId: "o1", type: "absent", note: "Ne répond pas"}});
  const o = await order();
  assert.strictEqual(o.status, "encours");
  assert.strictEqual(o.delivery_issue.label, "Client injoignable");
});

test("reçu : après livraison, numéro unique, contenu complet", async () => {
  await assert.rejects(d.orderReceipt({db, uid: "marie",
    data: {orderId: "o1"}}), /une fois la commande livrée/);
  const {code} = await d.deliveryCode({db, uid: "marie",
    data: {orderId: "o1"}});
  await d.confirmDelivery({db, uid: "jean",
    data: {orderId: "o1", code, photoUrl: PHOTO}});
  await assert.rejects(d.orderReceipt({db, uid: "autre",
    data: {orderId: "o1"}}), /non accessible/);
  const r = await d.orderReceipt({db, uid: "marie", data: {orderId: "o1"}});
  assert.match(r.number, /^KTG-2026-000001$/);
  assert.strictEqual(r.orderReference, "ORD-1");
  assert.strictEqual(r.client.name, "Marie");
  assert.strictEqual(r.seller.name, "Chez Paul");
  assert.strictEqual(r.deliverer, "Jean");
  assert.deepStrictEqual(r.lines, [{name: "Poulet DG", options: "Grande",
    quantity: 2, unitPrice: 2500, total: 5000}]);
  assert.strictEqual(r.subtotal, 5000);
  assert.strictEqual(r.deliveryFees, 1000);
  assert.strictEqual(r.total, 6000);
  assert.deepStrictEqual(r.payment, {method: "MTN Mobile Money",
    reference: "MTN-123", phone: ""});
  assert.strictEqual(r.codeVerified, true);
  // Même numéro pour le commerce, l'admin et le livreur.
  for (const uid of ["shop", "admin", "jean"]) {
    const x = await d.orderReceipt({db, uid, data: {orderId: "o1"}});
    assert.strictEqual(x.number, r.number);
  }
  // Commande suivante : numéro suivant.
  await db.doc("Orders/o2").set({status: "Livrer",
    user_ref: db.doc("User/marie"), total_amount: 1000,
    created_at: new Date(Date.UTC(2026, 10, 9))});
  const r2 = await d.orderReceipt({db, uid: "admin", data: {orderId: "o2"}});
  assert.strictEqual(r2.number, "KTG-2026-000002");
  assert.strictEqual(r2.payment, null);
});

test("prise en charge : un seul livreur, même s'ils acceptent ensemble",
    async () => {
      await db.doc("Orders/o2").set({status: "Pret",
        user_ref: db.doc("User/marie"), seller_ref: db.doc("User/shop")});
      const take = (uid) => d.takeDelivery({db, uid, data: {orderId: "o2"}});
      await assert.rejects(take("marie"), /Réservé aux livreurs/);
      // Jean et Paul acceptent au même instant.
      const res = await Promise.allSettled([take("jean"), take("paul")]);
      assert.strictEqual(res.filter((r) => r.status === "fulfilled").length, 1);
      assert.match(res.find((r) => r.status === "rejected").reason.message,
          /déjà été prise/);
      const o = (await db.doc("Orders/o2").get()).data();
      assert.strictEqual(o.status, "encours");
      const winner = o.deliverer_ref;
      assert.ok(["jean", "paul"].includes(winner));
      assert.strictEqual(o.deliver_reference.id, winner);
      assert.ok(o.taken_at);
      // Le gagnant peut rappuyer sans erreur.
      assert.deepStrictEqual(await take(winner), {ok: true, already: true});
      // Commande pas encore prête : refusée.
      await db.doc("Orders/o3").set({status: "En attente",
        user_ref: db.doc("User/marie")});
      await assert.rejects(d.takeDelivery({db, uid: "jean",
        data: {orderId: "o3"}}), /plus disponible/);
      // Livreur suspendu.
      await db.doc("User/paul").update({account_status: "suspended"});
      await assert.rejects(d.takeDelivery({db, uid: "paul",
        data: {orderId: "o3"}}), /suspendu/);
    });
