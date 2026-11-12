/**
 * Test des règles Firestore sur l'émulateur : les parcours de l'application
 * doivent passer, les détournements d'argent doivent être refusés. Lancement
 * (dépendances de développement installées) :
 *   firebase emulators:exec --only firestore --project demo-kitunga \
 *     "node --test kitunga/rules.emulator.test.js"
 */
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const {initializeTestEnvironment, assertSucceeds, assertFails} =
  require("@firebase/rules-unit-testing");
const {doc, setDoc, updateDoc, serverTimestamp, getDoc, getDocs, collection,
  query, where, orderBy} = require("firebase/firestore");

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const later = new Date(Date.now() + 86400000);

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-kitunga",
    firestore: {rules: fs.readFileSync(
        path.join(__dirname, "../../firestore.rules"), "utf8")},
  });
});
test.after(() => env.cleanup());

/** Données de départ, écrites sans passer par les règles. */
async function seed(order = {}, users = {}) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, "User/buyer"), {role: "User", subscribe_close_at: later});
    await setDoc(doc(d, "User/seller"), {role: "Seller"});
    await setDoc(doc(d, "User/driver"), {role: "Deliver"});
    await setDoc(doc(d, "User/admin"), {role: "Admin"});
    await setDoc(doc(d, "User/other"), {role: "User"});
    for (const [id, data] of Object.entries(users)) {
      await setDoc(doc(d, `User/${id}`), data);
    }
    await setDoc(doc(d, "Orders/o1"), {
      user_ref: doc(d, "User/buyer"), seller_ref: doc(d, "User/seller"),
      total_amount: 3500, delivery_fees: 1000, status: "En attente",
      order_unique_reference: "ORD-1", ...order,
    });
  });
}

const newOrder = (d, extra = {}) => ({
  user_ref: doc(d, "User/buyer"), seller_ref: doc(d, "User/seller"),
  total_amount: 3500, delivery_fees: 1000, status: "En attente",
  order_unique_reference: "ORD-2", ...extra,
});
const orderOf = (uid) => doc(db(uid), "Orders/o1");

// ── Parcours de l'application : doivent continuer de fonctionner ──────────

test("inscription : profil sans rôle puis rôle choisi", async () => {
  await seed({}, {fresh: {email: "a@b.c"}, fresh2: {email: "a@b.c"}});
  await assertSucceeds(setDoc(doc(db("fresh"), "User/fresh"),
      {role: "User", email: "a@b.c"}));
  await assertSucceeds(updateDoc(doc(db("fresh2"), "User/fresh2"),
      {role: "Guest"}));
  await assertSucceeds(updateDoc(doc(db("fresh2"), "User/fresh2"),
      {role: "User"}));
});

test("profil : modification sans changer de rôle", async () => {
  await seed();
  await assertSucceeds(updateDoc(doc(db("buyer"), "User/buyer"),
      {display_name: "Nouveau", is_logged_in: true}));
});

test("achat : commande, référence de paiement et trace", async () => {
  await seed();
  const d = db("buyer");
  await assertSucceeds(setDoc(doc(d, "Orders/o2"), newOrder(d)));
  await assertSucceeds(updateDoc(doc(d, "Orders/o2"),
      {payment_reference: "ref-1", payment_status: "Réussi"}));
  await assertSucceeds(setDoc(doc(d, "Paiement/p1"), {
    status: "Réussi", reference_id: "ref-1", message: null, amount: 3500,
    order_id: "ORD-2", order_ref: doc(d, "Orders/o2"),
    user_ref: doc(d, "User/buyer"), operator: "MTN",
    created_at: serverTimestamp(),
  }));
});

test("client : annule en attente, avec remboursement demandé", async () => {
  await seed({payment_status: "Réussi", payment_reference: "ref-1"});
  await assertSucceeds(updateDoc(orderOf("buyer"), {status: "Annulée",
    status_updated_at: serverTimestamp(), refund_needed: true}));
});

test("vendeur : accepte, prépare, refuse avec motif", async () => {
  await seed();
  await assertSucceeds(updateDoc(orderOf("seller"),
      {status: "En préparation", status_updated_at: serverTimestamp()}));
  await assertSucceeds(updateDoc(orderOf("seller"), {status: "Pret"}));
  await seed({payment_status: "Réussi", payment_reference: "ref-1"});
  await assertSucceeds(updateDoc(orderOf("seller"), {status: "Refusée",
    refusal_reason: "Rupture", refund_needed: true}));
});

test("livreur : prend la commande ; la remise passe par le serveur",
    async () => {
      await seed({status: "Pret"}, {driver2: {role: "Deliver"}});
      const d = db("driver");
      // Prendre la commande au nom d'un autre livreur : refusé.
      await assertFails(updateDoc(orderOf("driver"), {status: "encours",
        deliver_reference: doc(d, "User/driver2"), deliverer_ref: "driver2"}));
      await assertSucceeds(updateDoc(orderOf("driver"), {status: "encours",
        deliver_reference: doc(d, "User/driver"), deliverer_ref: "driver"}));
      // Sans code de remise vérifié par le serveur : refusé.
      await assertFails(updateDoc(orderOf("driver"), {status: "Livrer",
        delivered_at: serverTimestamp()}));
      await assertFails(updateDoc(orderOf("driver"), {status: "Reçu"}));
      await assertFails(updateDoc(orderOf("driver"),
          {delivery_code_verified: true}));
      await assertFails(updateDoc(orderOf("driver"), {delivery_photo: "url"}));
      await assertFails(updateDoc(orderOf("driver"),
          {receipt_number: "KTG-2026-000001"}));
      // Déjà prise : un second livreur ne peut plus la prendre.
      await assertFails(updateDoc(doc(db("driver2"), "Orders/o1"), {
        deliver_reference: doc(d, "User/driver2"), deliverer_ref: "driver2"}));
      await assertFails(updateDoc(orderOf("driver"),
          {taken_at: serverTimestamp()}));
      // Le client non plus ne peut pas se déclarer livré avant la remise.
      await assertFails(updateDoc(orderOf("buyer"), {status: "Reçu"}));
    });

test("codes de remise et compteurs de reçus : fermés aux applications",
    async () => {
      await seed();
      await env.withSecurityRulesDisabled(async (ctx) => {
        const f = ctx.firestore();
        await setDoc(doc(f, "delivery_codes/o1"), {code: "4821"});
        await setDoc(doc(f, "receipt_counters/2026"), {next: 2});
      });
      for (const uid of ["buyer", "driver", "seller", "admin"]) {
        await assertFails(getDoc(doc(db(uid), "delivery_codes/o1")));
        await assertFails(setDoc(doc(db(uid), "delivery_codes/o1"),
            {code: "0000"}));
        await assertFails(getDoc(doc(db(uid), "receipt_counters/2026")));
      }
    });

test("client : confirme ou signale la réception", async () => {
  await seed({status: "Livrer"});
  await assertSucceeds(updateDoc(orderOf("buyer"), {status: "Reçu"}));
  await seed({status: "Livrer"});
  await assertSucceeds(updateDoc(orderOf("buyer"), {status: "Non Reçu"}));
});

test("admin : peut corriger un statut", async () => {
  await seed({status: "Livrer"});
  await assertSucceeds(updateDoc(orderOf("admin"), {status: "Annulée"}));
});

test("admin : ajoute logo et couverture d'un partenaire", async () => {
  await seed();
  await assertSucceeds(updateDoc(doc(db("admin"), "User/seller"),
      {photo_url: "url", Business_cover: "url"}));
});

// Mêmes requêtes que les écrans de l'application.
const orders = (uid) => collection(db(uid), "Orders");
const users = (uid) => collection(db(uid), "User");
const countOf = async (q) => (await assertSucceeds(getDocs(q))).size;

test("lecture : boutiques et profil, comme l'application", async () => {
  await seed();
  for (const uid of ["buyer", "seller", "driver", "other"]) {
    await assertSucceeds(getDoc(doc(db(uid), `User/${uid}`)));
    await assertSucceeds(getDoc(doc(db(uid), "User/seller")));
    assert.equal(await countOf(query(users(uid),
        where("role", "==", "Seller"))), 1);
    assert.equal(await countOf(query(users(uid), where("role", "==", "Seller"),
        where("category", "==", "Restaurant"))), 0);
  }
  await assertSucceeds(getDoc(doc(db("newcomer"), "User/newcomer")));
});

test("lecture : chacun ses commandes, comme l'application", async () => {
  await seed({deliverer_ref: "driver", deliver_reference: null,
    status: "Reçu", created_at: later});
  assert.equal(await countOf(query(orders("buyer"), where("user_ref", "==",
      doc(db("buyer"), "User/buyer")))), 1);
  assert.equal(await countOf(query(orders("seller"), where("seller_ref", "==",
      doc(db("seller"), "User/seller")))), 1);
  assert.equal(await countOf(query(orders("driver"),
      where("deliverer_ref", "==", "driver"),
      orderBy("created_at", "desc"))), 1);
  for (const uid of ["buyer", "seller", "driver", "admin"]) {
    await assertSucceeds(getDoc(orderOf(uid)));
  }
});

test("lecture : le livreur voit les commandes prêtes ou en cours", async () => {
  await seed({status: "Pret"});
  assert.equal(await countOf(query(orders("driver"),
      where("status", "in", ["Pret", "encours"]))), 1);
  await assertSucceeds(getDoc(orderOf("driver")));
});

test("lecture : l'administrateur voit tout", async () => {
  await seed();
  assert.equal(await countOf(users("admin")), 5);
  assert.equal(await countOf(query(users("admin"),
      where("role", "==", "User"))), 2);
  assert.equal(await countOf(query(users("admin"),
      where("role", "==", "Deliver"))), 1);
  assert.equal(await countOf(orders("admin")), 1);
  await assertSucceeds(getDocs(collection(db("admin"), "system_logs")));
});

// ── Détournements : doivent être refusés ──────────────────────────────────

test("lecture : profils des clients et livreurs fermés", async () => {
  await seed({}, {guest: {role: "Guest"}});
  for (const uid of ["other", "guest", "seller", "driver"]) {
    await assertFails(getDoc(doc(db(uid), "User/buyer")));
    await assertFails(getDocs(users(uid)));
    await assertFails(getDocs(query(users(uid), where("role", "==", "User"))));
  }
  await assertFails(getDoc(doc(db("other"), "User/driver")));
  await assertFails(getDocs(query(users("other"),
      where("role", "==", "Deliver"))));
});

test("lecture : commandes des autres fermées", async () => {
  await seed({status: "Pret"});
  for (const uid of ["other", "buyer", "seller"]) {
    await assertFails(getDocs(orders(uid)));
  }
  await assertFails(getDoc(orderOf("other")));
  await assertFails(getDocs(query(orders("other"),
      where("status", "in", ["Pret", "encours"]))));
  await assertFails(getDocs(orders("driver")));
  await assertFails(getDocs(query(orders("driver"),
      where("status", "!=", "Livrer"))));
  await assertFails(getDocs(query(orders("other"),
      where("user_ref", "==", doc(db("other"), "User/buyer")))));
  await seed({status: "Reçu"});
  await assertFails(getDoc(orderOf("driver")));
});

test("lecture : journaux réservés à l'administrateur", async () => {
  await seed();
  await assertFails(getDocs(collection(db("buyer"), "system_logs")));
});

test("rôle : personne ne se déclare vendeur ou livreur", async () => {
  await seed({}, {fresh: {email: "a@b.c"}, guest: {role: "Guest"}});
  for (const role of ["Seller", "Deliver", "Admin"]) {
    await assertFails(setDoc(doc(db("newcomer"), "User/newcomer"), {role}));
    await assertFails(updateDoc(doc(db("fresh"), "User/fresh"), {role}));
    await assertFails(updateDoc(doc(db("guest"), "User/guest"), {role}));
  }
});

test("rôle : un client ne peut plus devenir vendeur ni admin", async () => {
  await seed();
  await assertFails(updateDoc(doc(db("buyer"), "User/buyer"), {role: "Seller"}));
  await assertFails(updateDoc(doc(db("buyer"), "User/buyer"), {role: "Admin"}));
  await assertFails(updateDoc(doc(db("buyer"), "User/buyer"),
      {subscribe_close_at: new Date(later.getTime() + 86400000)}));
});

test("admin : ne modifie rien d'autre sur un profil", async () => {
  await seed();
  for (const data of [{role: "Admin"}, {subscribe_close_at: new Date()},
    {display_name: "Autre"}]) {
    await assertFails(updateDoc(doc(db("admin"), "User/seller"), data));
  }
  await assertFails(updateDoc(doc(db("other"), "User/seller"),
      {photo_url: "url"}));
});

test("abonnement : sans abonnement ou en visiteur, pas de commande", async () => {
  await seed({}, {guest: {role: "Guest"}});
  for (const uid of ["other", "guest"]) {
    const d = db(uid);
    await assertFails(setDoc(doc(d, "Orders/x"),
        newOrder(d, {user_ref: doc(d, `User/${uid}`)})));
  }
});

test("commercial ou rôle inconnu : ni panier ni commande", async () => {
  await seed({}, {sales: {role: "Commercial"}, odd: {role: "Inconnu"}});
  for (const uid of ["sales", "odd"]) {
    const d = db(uid);
    await assertFails(setDoc(doc(d, "Orders/x"),
        newOrder(d, {user_ref: doc(d, `User/${uid}`)})));
    await assertFails(setDoc(doc(d, "Cart/x"),
        {user_ref: doc(d, `User/${uid}`), quantity: 1}));
  }
  const s = db("seller");
  await assertSucceeds(setDoc(doc(s, "Cart/y"),
      {user_ref: doc(s, "User/seller"), quantity: 1}));
});

test("création : commande déjà marquée payée ou à rembourser", async () => {
  await seed();
  const d = db("buyer");
  for (const extra of [{refund_needed: true}, {refund_status: "Envoyé"},
    {payment_status: "Réussi"}, {payment_reference: "x"},
    {status: "Annulée"}]) {
    await assertFails(setDoc(doc(d, "Orders/x"), newOrder(d, extra)));
  }
});

test("statut : retour en attente puis annulation impossible", async () => {
  await seed({status: "Livrer", payment_reference: "ref-1"});
  await assertFails(updateDoc(orderOf("buyer"), {status: "En attente"}));
  await assertFails(updateDoc(orderOf("buyer"), {status: "Annulée"}));
  await assertFails(updateDoc(orderOf("buyer"),
      {status: "Annulée", refund_needed: true}));
});

test("statut : seuls le client annule et le vendeur refuse", async () => {
  await seed();
  await assertFails(updateDoc(orderOf("seller"), {status: "Annulée"}));
  await assertFails(updateDoc(orderOf("buyer"), {status: "Refusée"}));
  await assertFails(updateDoc(orderOf("driver"), {status: "Annulée"}));
  await assertFails(updateDoc(orderOf("other"), {status: "Annulée"}));
});

test("statut : commande arrêtée définitivement", async () => {
  await seed({status: "Annulée"});
  await assertFails(updateDoc(orderOf("seller"), {status: "En préparation"}));
  await assertFails(updateDoc(orderOf("buyer"), {status: "En attente"}));
});

test("remboursement : demande hors arrêt, suivi réservé au serveur", async () => {
  await seed({status: "Annulée", refund_status: "Échec"});
  await assertFails(updateDoc(orderOf("buyer"), {refund_needed: true}));
  await assertFails(updateDoc(orderOf("buyer"), {refund_status: "Envoyé"}));
  await assertFails(updateDoc(orderOf("admin"), {refund_reference: "x"}));
  await seed();
  await assertFails(updateDoc(orderOf("buyer"), {refund_needed: true}));
});

test("paiement : référence posée une seule fois, par le client", async () => {
  await seed({payment_reference: "ref-1", payment_status: "Réussi"});
  await assertFails(updateDoc(orderOf("buyer"), {payment_reference: "autre"}));
  await seed();
  await assertFails(updateDoc(orderOf("seller"), {payment_status: "Réussi"}));
});

test("montant et références de la commande figés", async () => {
  await seed();
  await assertFails(updateDoc(orderOf("buyer"), {total_amount: 1000000}));
  await assertFails(updateDoc(orderOf("buyer"),
      {order_unique_reference: "autre"}));
});

test("Paiement : champs réservés au serveur interdits", async () => {
  await seed();
  const d = db("buyer");
  const base = {status: "En attente", user_ref: doc(d, "User/buyer")};
  for (const extra of [{kind: "subscription", plan: "annual"},
    {cart_ids: ["c1"]}, {payer_phone: "242060000000"},
    {subscription_until: later}, {order_unique_reference: "x"}]) {
    await assertFails(setDoc(doc(d, "Paiement/real-mtn-ref"),
        {...base, ...extra}));
  }
  await assertFails(updateDoc(doc(d, "Paiement/real-mtn-ref"), {status: "Réussi"}));
});

test("catégories : lecture publique, écriture par le serveur seulement",
    async () => {
      await seed();
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "Categories/c1"), {name: "Boutique"});
      });
      const anon = env.unauthenticatedContext().firestore();
      await assertSucceeds(getDoc(doc(anon, "Categories/c1")));
      await assertSucceeds(getDocs(collection(db("buyer"), "Categories")));
      for (const uid of ["buyer", "seller", "admin"]) {
        await assertFails(setDoc(doc(db(uid), "Categories/c2"), {name: "X"}));
        await assertFails(updateDoc(doc(db(uid), "Categories/c1"),
            {name: "Y"}));
      }
    });

test("commerces désactivés : la liste publique reste lisible", async () => {
  await seed({}, {shop2: {role: "Seller", account_status: "suspended"}});
  await assertSucceeds(getDocs(query(collection(db("buyer"), "User"),
      where("role", "==", "Seller"),
      where("account_status", "==", "suspended"))));
});

// ── Écosystème : champs et collections tenus par le serveur seul ─────────

test("statuts calculés, règlement et proposition : écrits par le serveur seul",
    async () => {
      await seed({status: "Pret"});
      for (const [uid, field, value] of [
        ["seller", "delivery_status", "delivered"],
        ["seller", "finance_status", "settled"],
        ["buyer", "settled_at", serverTimestamp()],
        ["driver", "offer_to", "driver"],
        ["driver", "arrived_at", serverTimestamp()],
        ["seller", "status_actor", {uid: "admin", role: "Admin"}],
        ["seller", "shop_zone", "Bacongo"],
      ]) {
        await assertFails(updateDoc(orderOf(uid), {[field]: value}));
      }
    });

test("grand livre, tickets, conversations, missions : illisibles en direct",
    async () => {
      await seed();
      await env.withSecurityRulesDisabled(async (ctx) => {
        const d = ctx.firestore();
        await setDoc(doc(d, "Ledger/o1_seller"), {account_uid: "seller",
          amount: 2500});
        await setDoc(doc(d, "Tickets/t1"), {author_uid: "buyer"});
        await setDoc(doc(d, "Conversations/c1"), {participants: ["buyer"]});
        await setDoc(doc(d, "Missions/m1"), {deliverer_uid: "driver"});
        await setDoc(doc(d, "Settings/finance"), {commission_rate: 0});
      });
      await assertFails(getDoc(doc(db("seller"), "Ledger/o1_seller")));
      await assertFails(setDoc(doc(db("seller"), "Ledger/x"),
          {account_uid: "seller", amount: 999999}));
      await assertFails(getDoc(doc(db("other"), "Tickets/t1")));
      await assertFails(getDoc(doc(db("other"), "Conversations/c1")));
      await assertFails(setDoc(doc(db("driver"), "Missions/m2"),
          {deliverer_uid: "driver", status: "accepted"}));
      await assertFails(setDoc(doc(db("seller"), "Settings/finance"),
          {commission_rate: 0}));
    });
