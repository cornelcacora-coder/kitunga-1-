/**
 * Support : tickets, notes internes, file, escalade, droits, incidents.
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/support.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const admin = require("firebase-admin");
const s = require("./support");
const ev = require("./order_events");
const {myNotifications} = require("./notifications");

admin.initializeApp({projectId: "demo-kitunga"});
const db = admin.firestore();
const messaging = null;
const titles = async (uid) =>
  (await myNotifications({db, uid})).notifications.map((n) => n.title);

test.beforeEach(async () => {
  for (const c of await db.listCollections()) await db.recursiveDelete(c);
  await db.doc("User/client").set({role: "User", display_name: "Awa",
    email: "awa@test.cg"});
  await db.doc("User/autre").set({role: "User"});
  await db.doc("User/shop").set({role: "Seller"});
  await db.doc("User/l1").set({role: "Deliver", display_name: "Jo"});
  await db.doc("User/sup").set({role: "Support", display_name: "Agent"});
  await db.doc("User/admin").set({role: "Admin"});
  await db.doc("User/futur").set({role: "User", email: "agent@kitunga.cg"});
  await db.doc("Orders/o1").set({status: "encours",
    order_unique_reference: "K-1", user_ref: db.doc("User/client"),
    seller_ref: db.doc("User/shop"), deliverer_ref: "l1"});
});

test("parcours d'un ticket : création, réponse, note interne, résolution",
    async () => {
      const {ticketId, number} = await s.createTicket({db, messaging,
        uid: "client", data: {category: "paiement", orderId: "o1",
          message: "J'ai payé deux fois."}});
      assert.strictEqual(number, "T-00001");
      assert.ok((await titles("sup"))[0].includes("T-00001"));
      let q = await s.supportQueue({db, uid: "sup", data: {}});
      assert.strictEqual(q.counts.open, 1);
      assert.strictEqual(q.tickets[0].priority, "high");

      await s.ticketUpdate({db, messaging, uid: "sup",
        data: {ticketId, assign: "me"}});
      await s.ticketReply({db, messaging, uid: "sup",
        data: {ticketId, text: "Client fiable, vérifier MTN.",
          internal: true}});
      await s.ticketReply({db, messaging, uid: "sup",
        data: {ticketId, text: "Nous vérifions votre paiement."}});
      // L'auteur ne voit pas la note interne ni les changements internes.
      const mine = await s.ticketThread({db, uid: "client",
        data: {ticketId}});
      assert.deepStrictEqual(mine.messages.map((m) => m.text),
          ["J'ai payé deux fois.", "Nous vérifions votre paiement."]);
      assert.strictEqual(mine.ticket.status, "waiting_user");
      const staff = await s.ticketThread({db, uid: "sup", data: {ticketId}});
      assert.ok(staff.messages.some((m) => m.internal));

      await s.ticketUpdate({db, messaging, uid: "sup",
        data: {ticketId, status: "resolved"}});
      assert.ok((await titles("client")).includes(
          "Demande T-00001 résolue"));
      // L'auteur répond : la demande est rouverte.
      await s.ticketReply({db, messaging, uid: "client",
        data: {ticketId, text: "Toujours pas remboursé."}});
      q = await s.supportQueue({db, uid: "sup", data: {filter: "open"}});
      assert.strictEqual(q.tickets.length, 1);
    });

test("droits : un étranger ne lit pas ; le client ne fait pas de note interne",
    async () => {
      const {ticketId} = await s.createTicket({db, messaging, uid: "client",
        data: {message: "Question"}});
      await assert.rejects(s.ticketThread({db, uid: "autre",
        data: {ticketId}}), {code: "not-found"});
      await assert.rejects(s.ticketReply({db, messaging, uid: "client",
        data: {ticketId, text: "x", internal: true}}),
      {code: "permission-denied"});
      await assert.rejects(s.supportQueue({db, uid: "client", data: {}}),
          {code: "permission-denied"});
      await assert.rejects(s.createTicket({db, messaging, uid: "autre",
        data: {orderId: "o1", message: "x"}}), {code: "not-found"});
      // Le support ne peut pas donner de rôle.
      await assert.rejects(s.adminSetSupport({db, uid: "sup",
        data: {email: "agent@kitunga.cg"}}), {code: "permission-denied"});
    });

test("escalade vers l'admin", async () => {
  const {ticketId} = await s.createTicket({db, messaging, uid: "client",
    data: {message: "Litige"}});
  await s.ticketUpdate({db, messaging, uid: "sup",
    data: {ticketId, escalate: true, note: "Remboursement à décider"}});
  assert.ok((await titles("admin"))[0].startsWith("Escalade"));
  const q = await s.supportQueue({db, uid: "admin",
    data: {filter: "escalated"}});
  assert.strictEqual(q.tickets.length, 1);
  const audit = await db.collection("audit_logs").get();
  assert.ok(audit.size >= 1);
});

test("incident de livraison et commande non reçue : tickets automatiques",
    async () => {
      const before = await db.doc("Orders/o1").get();
      await db.doc("Orders/o1").update({delivery_issue: {type: "absent",
        label: "Client absent"}});
      await ev.onOrderWrite({db, messaging, before,
        after: await db.doc("Orders/o1").get()});
      let q = await s.supportQueue({db, uid: "sup", data: {}});
      assert.strictEqual(q.tickets[0].priority, "urgent");
      assert.match(q.tickets[0].subject, /Client absent/);

      const b2 = await db.doc("Orders/o1").get();
      await db.doc("Orders/o1").update({status: "Non Reçu"});
      await ev.onOrderWrite({db, messaging, before: b2,
        after: await db.doc("Orders/o1").get()});
      q = await s.supportQueue({db, uid: "sup", data: {}});
      assert.strictEqual(q.counts.open, 2);
    });

test("rôle Support : donné et retiré par l'admin ; recherche d'un client",
    async () => {
      await s.adminSetSupport({db, uid: "admin",
        data: {email: "agent@kitunga.cg"}});
      assert.strictEqual((await db.doc("User/futur").get()).get("role"),
          "Support");
      await assert.rejects(s.adminSetSupport({db, uid: "admin",
        data: {uid: "l1"}}), {code: "failed-precondition"});
      await s.adminSetSupport({db, uid: "admin",
        data: {uid: "futur", enabled: false}});
      assert.strictEqual((await db.doc("User/futur").get()).get("role"),
          "User");
      const r = await s.supportUserLookup({db, uid: "sup",
        data: {query: "awa"}});
      assert.strictEqual(r.users[0].orders[0].reference, "K-1");
    });
