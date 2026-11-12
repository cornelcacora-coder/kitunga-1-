/**
 * Scénario complet avec les cinq acteurs (client, vendeur, livreur, admin,
 * support), déclencheurs rejoués comme en production après chaque
 * écriture d'une commande (notifications, cycle de vie, finances).
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/scenario.emulator.test.js"
 */
process.env.KITUNGA_MOMO_MOCK = "1";
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const wallet = require("./wallet");
const {startPayment, confirmPayment} = require("./payments");
const ev = require("./order_events");
const lc = require("./lifecycle");
const fin = require("./finance");
const dispatch = require("./dispatch");
const delivery = require("./delivery");
const tracking = require("./delivery_tracking");
const chat = require("./messaging");
const support = require("./support");
const sv = require("./supervision");
const {myNotifications} = require("./notifications");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const messaging = null;
const PHOTO = "https://firebasestorage.googleapis.com/v0/b/x/o/remise.jpg";
const titles = async (uid) =>
  (await myNotifications({db, uid})).notifications.map((n) => n.title);

let orderId;
let last = null;

/** Rejoue les déclencheurs de la commande depuis le dernier état vu. */
async function fire() {
  const ref = db.doc(`Orders/${orderId}`);
  for (let i = 0; i < 4; i++) {
    const after = await ref.get();
    await ev.onOrderWrite({db, messaging, before: last, after});
    await lc.onOrderLifecycle({before: last, after});
    await fin.onOrderFinance({db, after});
    last = after;
    const again = await ref.get();
    // Les déclencheurs écrivent parfois (ready_at, statuts calculés) :
    // on rejoue jusqu'à ce que plus rien ne change.
    if (JSON.stringify(again.data()) === JSON.stringify(after.data())) break;
  }
  return ref.get();
}

async function update(fields) {
  await db.doc(`Orders/${orderId}`).update(fields);
  return fire();
}

test("parcours complet : de la commande au règlement, avec incident",
    async () => {
      for (const c of await db.listCollections()) await db.recursiveDelete(c);
      await db.doc("User/client").set({role: "User", display_name: "Awa",
        phone_number: "+242061111111",
        subscribe_close_at: new Date(Date.now() + 30 * 86400000)});
      await db.doc("User/shop").set({role: "Seller",
        display_name: "Chez Mado", shop_zone: "Poto-Poto"});
      await db.doc("User/l1").set({role: "Deliver", display_name: "Jo",
        delivery_available: true, delivery_state: "on",
        last_position: {lat: -4.256, lng: 15.272, at: new Date()}});
      await db.doc("User/admin").set({role: "Admin"});
      await db.doc("User/sup").set({role: "Support", display_name: "Agent"});
      await db.doc("Product/p1").set({name: "Poulet braisé", sale_price: 3000,
        price: 3000, quantity: 5, on_sale: true});
      await db.doc("Cart/c1").set({user_ref: db.doc("User/client"),
        seller_ref: db.doc("User/shop"), product_ref: db.doc("Product/p1"),
        quantity: 2, options: "", is_ordered: false});

      // 1. Le client paie (MTN simulé) : frais selon la distance.
      const pay = await startPayment({db, momo: wallet, uid: "client",
        sellerPath: "User/shop", zone: "Bacongo", phone: "061111111"});
      assert.strictEqual(pay.subtotal, 6000);
      const done = await confirmPayment({db, momo: wallet, uid: "client",
        referenceId: pay.referenceId});
      orderId = done.orderPath.split("/")[1];
      let o = await fire();
      // 2. Le vendeur est prévenu.
      assert.ok((await titles("shop")).includes("Nouvelle commande"));
      assert.strictEqual(o.get("finance_status"), "paid");

      // 3. Le vendeur accepte puis prépare.
      o = await update({status: "En préparation"});
      assert.ok((await titles("client")).includes("Commande acceptée"));
      // 4–5. Commande prête : le système propose la course au livreur.
      o = await update({status: "Pret"});
      assert.strictEqual(o.get("offer_to"), "l1");
      assert.strictEqual(o.get("delivery_status"), "offered");
      assert.ok((await titles("l1")).includes(
          "Course proposée : répondez vite"));

      // 6–7. Le livreur accepte ; le vendeur et le client sont prévenus.
      await dispatch.respondMission({db, messaging, uid: "l1",
        data: {missionId: o.get("offer_mission"), accept: true}});
      o = await fire();
      assert.strictEqual(o.get("status"), "encours");
      assert.ok((await titles("shop")).includes("Commande prise en charge"));
      assert.strictEqual(o.get("delivery_status"), "to_pickup");

      // 8. Récupération ; 9. le client suit le livreur en direct.
      await tracking.deliveryStep({db, uid: "l1",
        data: {orderId, step: "picked_up"}});
      await tracking.deliveryPosition({db, uid: "l1",
        data: {orderId, lat: -4.27, lng: 15.26}});
      o = await fire();
      assert.strictEqual(o.get("delivery_status"), "to_customer");
      const track = await tracking.deliveryTracking({db, uid: "client",
        data: {orderId}});
      assert.ok(track.position && track.pickedUpAt);
      assert.ok((await titles("client")).includes("Votre livreur arrive"));

      // 10. Client et livreur échangent des messages.
      const {conversationId} = await chat.openOrderChat({db, uid: "client",
        data: {orderId, with: "livreur"}});
      await chat.sendMessage({db, messaging, uid: "client",
        data: {conversationId, text: "Portail bleu, 2e étage."}});
      assert.strictEqual((await chat.myConversations({db, uid: "l1"}))
          .unread, 1);

      // Incident : le client ne répond pas → admin et support prévenus.
      await delivery.reportDeliveryIssue({db, uid: "l1",
        data: {orderId, type: "absent", note: "Ne répond pas"}});
      o = await fire();
      assert.ok((await titles("admin")).includes("Problème de livraison"));
      const queue = await support.supportQueue({db, uid: "sup", data: {}});
      assert.strictEqual(queue.tickets[0].priority, "urgent");
      assert.strictEqual(queue.tickets[0].orderId, orderId);

      // Arrivée puis 11. remise avec le code du client et une photo.
      await tracking.deliveryStep({db, uid: "l1",
        data: {orderId, step: "arrived"}});
      o = await fire();
      assert.strictEqual(o.get("delivery_status"), "arrived");
      const {code} = await delivery.deliveryCode({db, uid: "client",
        data: {orderId}});
      await delivery.confirmDelivery({db, uid: "l1",
        data: {orderId, code, photoUrl: PHOTO}});
      // 12–13. Commande livrée, finances réglées une seule fois.
      o = await fire();
      assert.strictEqual(o.get("status"), "Livrer");
      assert.strictEqual(o.get("delivery_status"), "delivered");
      assert.strictEqual(o.get("finance_status"), "settled");
      const earn = await fin.myEarnings({db, uid: "l1"});
      assert.strictEqual(earn.balance, o.get("delivery_fees"));
      assert.strictEqual((await fin.myEarnings({db, uid: "shop"})).balance,
          6000);

      // 14. L'admin voit le résultat ; l'historique est complet.
      const view = await sv.adminSupervision({db, uid: "admin"});
      assert.strictEqual(view.orders.deliveredToday, 1);
      const history = (await lc.orderHistoryFor({db, uid: "admin",
        data: {orderId}})).history.filter((h) => h.field === "status")
          .map((h) => h.to);
      assert.deepStrictEqual(history,
          ["En attente", "En préparation", "Pret", "encours", "Livrer"]);

      // 15. Le support résout le ticket ; le client est prévenu.
      await support.ticketUpdate({db, messaging, uid: "sup",
        data: {ticketId: queue.tickets[0].id, status: "resolved"}});
      const resolved = await support.supportQueue({db, uid: "sup",
        data: {filter: "resolved"}});
      assert.strictEqual(resolved.tickets.length, 1);
    });
