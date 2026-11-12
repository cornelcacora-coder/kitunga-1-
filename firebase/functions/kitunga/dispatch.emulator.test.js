/**
 * Attribution des courses : choix, proposition, refus, expiration,
 * ouverture à tous, aucune double attribution.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/dispatch.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const d = require("./dispatch");
const {takeDelivery} = require("./delivery");
const {myNotifications} = require("./notifications");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const messaging = {sendEachForMulticast: async (m) => ({
  successCount: m.tokens.length, responses: m.tokens.map(() => ({success: true}))})};
const now = new Date();
const titles = async (uid) =>
  (await myNotifications({db, uid})).notifications.map((n) => n.title);
const order = () => db.doc("Orders/o1").get();

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/admin").set({role: "Admin"});
  const deliverer = (id, extra) => db.doc(`User/${id}`).set({role: "Deliver",
    display_name: id, delivery_available: true, ...extra});
  // Commerce à Bacongo (-4.2805, 15.2560).
  await deliverer("pres", {last_position: {lat: -4.281, lng: 15.257, at: now}});
  await deliverer("loin", {last_position: {lat: -4.20, lng: 15.30, at: now}});
  await deliverer("inconnu", {});
  await deliverer("ailleurs", {delivery_zones: ["Mfilou"],
    last_position: {lat: -4.2805, lng: 15.2560, at: now}});
  await deliverer("pause", {delivery_available: false});
  await db.doc("Orders/o1").set({status: "Pret", shop_zone: "Bacongo",
    delivery_zone: "Bacongo", delivery_fees: 1000});
});

test("classement : le plus proche, quartier couvert, en service",
    async () => {
      const ranked = await d.rankDeliverers({db, order: await order(),
        settings: d.DEFAULTS, now});
      assert.deepStrictEqual(ranked.map((r) => r.user.id),
          ["pres", "inconnu", "loin"].sort((a, b) =>
            ranked.findIndex((r) => r.user.id === a) -
            ranked.findIndex((r) => r.user.id === b)));
      assert.strictEqual(ranked[0].user.id, "pres");
      assert.ok(!ranked.some((r) => ["ailleurs", "pause"]
          .includes(r.user.id)));
      assert.match(ranked[0].reason, /km du commerce/);
    });

test("capacité : un vélo avec une course en cours n'en reçoit pas d'autre",
    async () => {
      await db.doc("User/pres").update({vehicle: "velo"});
      await db.doc("Orders/autre").set({status: "encours",
        deliverer_ref: "pres"});
      const ranked = await d.rankDeliverers({db, order: await order(),
        settings: d.DEFAULTS, now});
      assert.ok(!ranked.some((r) => r.user.id === "pres"));
    });

test("proposition au meilleur, refus, puis au suivant", async () => {
  const r = await d.offerNext({db, messaging, orderId: "o1", now});
  assert.strictEqual(r.to, "pres");
  let o = await order();
  assert.strictEqual(o.get("offer_to"), "pres");
  assert.match(o.get("dispatch_reason"), /km du commerce/);
  assert.deepStrictEqual(await titles("pres"),
      ["Course proposée : répondez vite"]);
  // Pendant l'exclusivité, un autre livreur ne peut pas la prendre.
  await assert.rejects(takeDelivery({db, uid: "loin",
    data: {orderId: "o1"}}), /proposée à un autre livreur/);

  await d.respondMission({db, messaging, uid: "pres",
    data: {missionId: r.missionId, accept: false}, now});
  o = await order();
  assert.notStrictEqual(o.get("offer_to"), "pres");
  assert.ok(o.get("offer_to"));
  assert.strictEqual(o.get("dispatch_attempts"), 2);
});

test("acceptation : une seule attribution, même en double clic",
    async () => {
      const r = await d.offerNext({db, messaging, orderId: "o1", now});
      const both = await Promise.allSettled([
        d.respondMission({db, messaging, uid: "pres",
          data: {missionId: r.missionId, accept: true}, now}),
        d.respondMission({db, messaging, uid: "pres",
          data: {missionId: r.missionId, accept: true}, now}),
      ]);
      assert.strictEqual(both.filter((x) => x.status === "fulfilled").length,
          1);
      const o = await order();
      assert.strictEqual(o.get("status"), "encours");
      assert.strictEqual(o.get("deliverer_ref"), "pres");
      assert.strictEqual(o.get("offer_to"), undefined);
      // Une autre proposition pour la même commande est impossible.
      assert.deepStrictEqual(await d.offerNext({db, messaging, orderId: "o1",
        now}), {offered: false, why: "not-ready"});
    });

test("expiration : la course passe au suivant ; accepter trop tard échoue",
    async () => {
      // Trop tard : refus clair, proposition close, course au suivant.
      const r = await d.offerNext({db, messaging, orderId: "o1", now});
      const later = new Date(now.getTime() + 61000);
      await assert.rejects(d.respondMission({db, messaging, uid: "pres",
        data: {missionId: r.missionId, accept: true}, now: later}),
      {code: "deadline-exceeded"});
      assert.strictEqual((await db.doc(`Missions/${r.missionId}`).get())
          .get("status"), "expired");
      let o = await order();
      const second = o.get("offer_mission");
      assert.ok(second && o.get("offer_to") !== "pres");
      // Sans réponse : la tâche planifiée l'expire et passe au suivant.
      const res = await d.expireOffers({db, messaging,
        now: new Date(now.getTime() + 125000)});
      assert.strictEqual(res.expired, 1);
      o = await order();
      assert.notStrictEqual(o.get("offer_mission"), second);
      assert.strictEqual(o.get("dispatch_attempts"), 3);
    });

test("après 3 essais : ouverte à tous ceux du quartier", async () => {
  for (let i = 0; i < 3; i++) {
    const o = await order();
    const m = o.get("offer_mission") ||
      (await d.offerNext({db, messaging, orderId: "o1", now})).missionId;
    const mm = await db.doc(`Missions/${m}`).get();
    await d.respondMission({db, messaging, uid: mm.get("deliverer_uid"),
      data: {missionId: m, accept: false}, now});
  }
  const o = await order();
  assert.strictEqual(o.get("dispatch_mode"), "open");
  assert.ok((await titles("inconnu")).includes("Nouvelle commande à livrer"));
  // Ouverte : le premier qui accepte la prend.
  await takeDelivery({db, uid: "loin", data: {orderId: "o1"}});
  assert.strictEqual((await order()).get("deliverer_ref"), "loin");
});

test("position : seulement en service ; véhicule ; réglages admin",
    async () => {
      assert.deepStrictEqual(await d.delivererPing({db, uid: "pause",
        data: {lat: -4.2, lng: 15.2}}), {ok: false});
      assert.deepStrictEqual(await d.delivererPing({db, uid: "inconnu",
        data: {lat: -4.2, lng: 15.2}}), {ok: true});
      await d.setVehicle({db, uid: "inconnu", data: {vehicle: "voiture"}});
      await assert.rejects(d.setVehicle({db, uid: "inconnu",
        data: {vehicle: "avion"}}), {code: "invalid-argument"});
      const s = await d.adminDispatchSettings({db, uid: "admin", data: {
        save: {auto: true, offer_seconds: 90, max_attempts: 2,
          capacity: {moto: 2, velo: 1, voiture: 4}}}});
      assert.strictEqual(s.settings.offer_seconds, 90);
      await assert.rejects(d.adminDispatchSettings({db, uid: "pres",
        data: {}}), {code: "permission-denied"});
    });
