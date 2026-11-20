/**
 * Ordonnances : envoi, vérification par la pharmacie, paiement.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/prescriptions.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const rx = require("./prescriptions");
const {startPayment, confirmPayment} = require("./payments");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const photo = (uid) => "https://firebasestorage.googleapis.com/v0/b/x/o/" +
  `prescriptions%2F${uid}%2F1.jpg?alt=media&token=t`;
const momo = {
  normalizePhone: (p) => String(p).replace(/\D/g, ""),
  requestToPay: async () => `ref-${Math.random().toString(36).slice(2, 10)}`,
  paymentStatus: async () => ({status: "SUCCESSFUL"}),
};
const day = 86400000;

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/marie").set({role: "User", display_name: "Marie",
    phone_number: "061234567",
    subscribe_close_at: new Date(Date.now() + 30 * day)});
  await db.doc("User/autre").set({role: "User"});
  await db.doc("User/pharma").set({role: "Seller", category: "Pharmacie",
    display_name: "Pharma Plus"});
  await db.doc("User/resto").set({role: "Seller", category: "Restaurant"});
  await db.doc("Product/amox").set({name: "Amoxicilline", sale_price: 3000,
    quantity: 5, on_sale: true, requires_prescription: true,
    seller_ref: db.doc("User/pharma")});
  await db.doc("Cart/c1").set({user_ref: db.doc("User/marie"),
    seller_ref: db.doc("User/pharma"), product_ref: db.doc("Product/amox"),
    quantity: 1, options: "", is_ordered: false});
});

const pay = () => startPayment({db, momo, uid: "marie",
  sellerPath: "User/pharma", zone: "Poto-Poto", phone: "061234567"});

test("envoi : photo privée du client, pharmacie seulement", async () => {
  const send = (data, uid = "marie") =>
    rx.submitPrescription({db, uid, data});
  await assert.rejects(send({sellerUid: "pharma", photos: []}), /photo/);
  // Photo d'un autre dossier (publique) ou d'un autre client : refusée.
  await assert.rejects(send({sellerUid: "pharma", photos: [
    "https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fmarie%2Fa.jpg"]}),
  /application Kitunga/);
  await assert.rejects(send({sellerUid: "pharma", photos: [photo("autre")]}),
      /application Kitunga/);
  await assert.rejects(send({sellerUid: "resto", photos: [photo("marie")]}),
      /Pharmacie introuvable/);
  const r = await send({sellerUid: "pharma", photos: [photo("marie")],
    note: "Pour mon fils"});
  assert.strictEqual(r.status, "pending");
  const mine = (await rx.myPrescriptions({db, uid: "marie",
    data: {sellerUid: "pharma"}})).prescriptions;
  assert.strictEqual(mine[0].note, "Pour mon fils");
  // La pharmacie voit le nom et le téléphone du client.
  const seen = (await rx.sellerPrescriptions({db, uid: "pharma"}))
      .prescriptions[0];
  assert.strictEqual(seen.clientName, "Marie");
  assert.strictEqual(seen.clientPhone, "061234567");
  await assert.rejects(rx.sellerPrescriptions({db, uid: "resto"}),
      /Pharmacie introuvable/);
  // Trois en attente au plus.
  await send({sellerUid: "pharma", photos: [photo("marie")]});
  await send({sellerUid: "pharma", photos: [photo("marie")]});
  await assert.rejects(send({sellerUid: "pharma", photos: [photo("marie")]}),
      /déjà des ordonnances en attente/);
});

test("sans ordonnance validée : paiement refusé ; refus motivé", async () => {
  await assert.rejects(pay(), /nécessite une ordonnance validée/);
  const {id} = await rx.submitPrescription({db, uid: "marie",
    data: {sellerUid: "pharma", photos: [photo("marie")]}});
  await assert.rejects(pay(), /nécessite une ordonnance validée/);
  await assert.rejects(rx.reviewPrescription({db, uid: "pharma",
    data: {id, decision: "reject"}}), /pourquoi/);
  await assert.rejects(rx.reviewPrescription({db, uid: "resto",
    data: {id, decision: "approve"}}), /Pharmacie introuvable/);
  await rx.reviewPrescription({db, uid: "pharma", data: {id,
    decision: "reject", note: "Ordonnance illisible"}});
  const p = (await rx.myPrescriptions({db, uid: "marie"})).prescriptions[0];
  assert.strictEqual(p.status, "rejected");
  assert.strictEqual(p.reviewNote, "Ordonnance illisible");
  await assert.rejects(pay(), /nécessite une ordonnance validée/);
});

test("validée : une commande, ordonnance rattachée puis utilisée",
    async () => {
      const {id} = await rx.submitPrescription({db, uid: "marie",
        data: {sellerUid: "pharma", photos: [photo("marie")]}});
      await rx.reviewPrescription({db, uid: "pharma",
        data: {id, decision: "approve"}});
      await assert.rejects(rx.reviewPrescription({db, uid: "pharma",
        data: {id, decision: "approve"}}), /déjà été traitée/);
      const s = await pay();
      const r = await confirmPayment({db, momo, uid: "marie",
        referenceId: s.referenceId});
      assert.strictEqual(r.status, "paid");
      const order = (await db.doc(r.orderPath).get()).data();
      assert.strictEqual(order.prescription_ref.id, id);
      assert.deepStrictEqual(order.prescription_photos, [photo("marie")]);
      const used = (await rx.myPrescriptions({db, uid: "marie"}))
          .prescriptions[0];
      assert.strictEqual(used.status, "used");
      assert.strictEqual(used.orderId, order ? r.orderPath.split("/")[1] : "");
      // Nouvelle commande : il faut une nouvelle ordonnance.
      await db.doc("Cart/c2").set({user_ref: db.doc("User/marie"),
        seller_ref: db.doc("User/pharma"),
        product_ref: db.doc("Product/amox"), quantity: 1, options: "",
        is_ordered: false});
      await assert.rejects(pay(), /nécessite une ordonnance validée/);
    });

test("validée mais expirée après 7 jours", async () => {
  const {id} = await rx.submitPrescription({db, uid: "marie",
    data: {sellerUid: "pharma", photos: [photo("marie")]}});
  await rx.reviewPrescription({db, uid: "pharma", data: {id,
    decision: "approve"}, now: new Date(Date.now() - 8 * day)});
  const p = (await rx.myPrescriptions({db, uid: "marie"})).prescriptions[0];
  assert.strictEqual(p.status, "expired");
  await assert.rejects(pay(), /nécessite une ordonnance validée/);
});
