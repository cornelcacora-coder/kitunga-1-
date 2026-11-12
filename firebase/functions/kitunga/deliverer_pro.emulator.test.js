/**
 * Espace professionnel du livreur : documents, note, performances,
 * retraits, retard, arrivée au commerce, alerte, propositions refusées.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/deliverer_pro.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const p = require("./deliverer_pro");
const {myNotifications} = require("./notifications");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const messaging = null;
const photo = (uid, f = "a.jpg") => "https://firebasestorage.googleapis.com" +
  `/v0/b/x/o/documents%2F${uid}%2F${f}?alt=media&token=t`;
const titles = async (uid) =>
  (await myNotifications({db, uid})).notifications.map((n) => n.title);
const later = new Date(Date.now() + 365 * 86400000).toISOString();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/sup").set({role: "Support"});
  await db.doc("User/l1").set({role: "Deliver", display_name: "Jo",
    phone_number: "060000000"});
  await db.doc("User/client").set({role: "User"});
  await db.doc("User/autre").set({role: "User"});
  await db.doc("User/shop").set({role: "Seller", display_name: "Mado"});
});

test("documents : dépôt, refus motivé, validation, badge vérifié, expiration",
    async () => {
      let d = await p.myDocuments({db, uid: "l1"});
      assert.strictEqual(d.verification, "missing");
      await assert.rejects(p.submitDocument({db, messaging, uid: "l1",
        data: {type: "identity", photoUrl: photo("autre")}}),
      {code: "invalid-argument"});
      for (const type of ["identity", "license", "registration"]) {
        await p.submitDocument({db, messaging, uid: "l1",
          data: {type, photoUrl: photo("l1", `${type}.jpg`), number: "X1",
            expiresAt: later}});
      }
      assert.ok((await titles("admin")).includes("Document à vérifier"));
      d = await p.myDocuments({db, uid: "l1"});
      assert.strictEqual(d.verification, "pending");
      const q = await p.adminDocuments({db, uid: "admin", data: {}});
      assert.strictEqual(q.documents.length, 3);
      await assert.rejects(p.adminReviewDocument({db, messaging,
        uid: "admin", data: {id: "l1_license", approve: false}}),
      {code: "invalid-argument"});
      await p.adminReviewDocument({db, messaging, uid: "admin",
        data: {id: "l1_license", approve: false, reason: "Photo floue"}});
      assert.strictEqual((await p.myDocuments({db, uid: "l1"})).verification,
          "rejected");
      await p.submitDocument({db, messaging, uid: "l1", data: {
        type: "license", photoUrl: photo("l1", "l2.jpg"), expiresAt: later}});
      for (const id of ["l1_identity", "l1_license", "l1_registration"]) {
        await p.adminReviewDocument({db, messaging, uid: "admin",
          data: {id, approve: true}});
      }
      assert.strictEqual((await db.doc("User/l1").get()).get("verified"),
          true);
      // Un document validé mais expiré : vérification à refaire.
      await db.doc("DelivererDocuments/l1_identity").update({
        expires_at: new Date(Date.now() - 86400000)});
      assert.strictEqual((await p.myDocuments({db, uid: "l1"})).verification,
          "expired");
      await assert.rejects(p.adminDocuments({db, uid: "l1", data: {}}),
          {code: "permission-denied"});
    });

test("note du client : une fois, après livraison, moyenne", async () => {
  await db.doc("Orders/o1").set({status: "encours", deliverer_ref: "l1",
    user_ref: db.doc("User/client")});
  await assert.rejects(p.rateDelivery({db, uid: "client",
    data: {orderId: "o1", stars: 5}}), {code: "failed-precondition"});
  await db.doc("Orders/o1").update({status: "Livrer"});
  await assert.rejects(p.rateDelivery({db, uid: "autre",
    data: {orderId: "o1", stars: 5}}), {code: "not-found"});
  await p.rateDelivery({db, uid: "client", data: {orderId: "o1", stars: 4}});
  assert.deepStrictEqual(await p.rateDelivery({db, uid: "client",
    data: {orderId: "o1", stars: 1}}), {ok: true, already: true});
  const perf = await p.myPerformance({db, uid: "l1"});
  assert.strictEqual(perf.rating, 4);
  assert.strictEqual(perf.ratingCount, 1);
});

test("performances : réussite, annulations non imputées, durée, gains",
    async () => {
      const now = new Date();
      await db.doc("Orders/a").set({status: "Livrer", deliverer_ref: "l1",
        delivery_km: 3.5, taken_at: new Date(now - 30 * 60000),
        delivered_at: now});
      await db.doc("Orders/b").set({status: "Non Reçu", deliverer_ref: "l1"});
      await db.doc("Orders/c").set({status: "Annulée", deliverer_ref: "l1"});
      await db.doc("Ledger/a_deliverer").set({account_uid: "l1",
        type: "delivery", amount: 1000, at: now});
      await db.doc("Missions/m1").set({deliverer_uid: "l1",
        status: "accepted", order_id: "a"});
      await db.doc("Missions/m2").set({deliverer_uid: "l1",
        status: "declined", order_id: "b"});
      const r = await p.myPerformance({db, uid: "l1", now});
      assert.strictEqual(r.delivered, 1);
      assert.strictEqual(r.successRate, 50);
      assert.strictEqual(r.cancelledByOthers, 1);
      assert.strictEqual(r.averageMinutes, 30);
      assert.strictEqual(r.distanceKm, 3.5);
      assert.strictEqual(r.monthEarnings, 1000);
      assert.strictEqual(r.weeklyEarnings[7], 1000);
      assert.strictEqual(r.acceptanceRate, 50);
      const ms = await p.myMissions({db, uid: "l1"});
      assert.ok(ms.missions.some((m) => m.status === "declined"));
    });

test("retrait : plafonné, une demande à la fois, validé par l'admin",
    async () => {
      await db.doc("Ledger/x").set({account_uid: "l1", type: "delivery",
        amount: 3000, at: new Date()});
      await assert.rejects(p.requestWithdrawal({db, messaging, uid: "l1",
        data: {amount: 5000}}), {code: "failed-precondition"});
      await p.requestWithdrawal({db, messaging, uid: "l1",
        data: {amount: 2000, method: "MoMo"}});
      await assert.rejects(p.requestWithdrawal({db, messaging, uid: "l1",
        data: {amount: 500}}), {code: "already-exists"});
      const w = (await p.adminWithdrawals({db, uid: "admin"})).withdrawals;
      assert.strictEqual(w[0].amount, 2000);
      await p.adminDecideWithdrawal({db, messaging, uid: "admin",
        data: {id: w[0].id, approve: true, reference: "MTN-9"}});
      const bal = (await db.collection("Ledger").where("account_uid", "==",
          "l1").get()).docs.reduce((s, e) => s + e.get("amount"), 0);
      assert.strictEqual(bal, 1000);
      const mine = await p.myWithdrawals({db, uid: "l1"});
      assert.strictEqual(mine.withdrawals[0].status, "paid");
      // Nouvelle demande possible, puis refus motivé.
      await p.requestWithdrawal({db, messaging, uid: "l1",
        data: {amount: 1000}});
      await p.adminDecideWithdrawal({db, messaging, uid: "admin",
        data: {id: "l1_pending", approve: false, reason: "Numéro invalide"}});
      assert.ok((await titles("l1")).includes("Demande de retrait refusée"));
    });

test("retard, arrivée au commerce, alerte de sécurité", async () => {
  await db.doc("Orders/o1").set({status: "encours", deliverer_ref: "l1",
    user_ref: db.doc("User/client"), seller_ref: db.doc("User/shop")});
  await p.arrivedAtShop({db, messaging, uid: "l1", data: {orderId: "o1"}});
  assert.ok((await titles("shop")).includes("Le livreur est arrivé"));
  await assert.rejects(p.reportDelay({db, messaging, uid: "l1",
    data: {orderId: "o1", minutes: 7}}), {code: "invalid-argument"});
  await p.reportDelay({db, messaging, uid: "l1",
    data: {orderId: "o1", minutes: 20, reason: "embouteillage"}});
  assert.ok((await titles("client")).includes("Livraison retardée"));
  await p.setEmergencyContact({db, uid: "l1",
    data: {name: "Maman", phone: "065555555"}});
  const r = await p.safetyAlert({db, messaging, uid: "l1",
    data: {kind: "accident", lat: -4.27, lng: 15.25, orderId: "o1",
      note: "Chute à moto"}});
  assert.ok(r.alertId);
  assert.ok((await titles("admin"))[0].startsWith("ALERTE ACCIDENT"));
  assert.ok((await titles("sup")).some((t) => t.startsWith("ALERTE")));
  const alert = await db.doc(`SafetyAlerts/${r.alertId}`).get();
  assert.strictEqual(alert.get("emergency_contact").name, "Maman");
  await assert.rejects(p.safetyAlert({db, messaging, uid: "client",
    data: {kind: "danger"}}), {code: "permission-denied"});
});
