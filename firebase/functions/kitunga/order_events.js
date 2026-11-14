/**
 * Notifications au fil d'une commande (déclencheur sur Orders) et
 * disponibilité des livreurs.
 *
 * - Nouvelle commande : le commerce.
 * - Acceptée (En préparation) : le client.
 * - Prête : les livreurs en service qui couvrent le quartier (tous les
 *   livreurs en service s'ils n'ont choisi aucun quartier).
 * - En livraison : le client et le commerce.
 * - Récupérée au commerce : le client (le livreur arrive).
 * - Livrée : le client (confirmer la réception).
 * - Refusée / annulée : le client ou le commerce.
 * - Problème signalé par le livreur : les administrateurs.
 * - Prête depuis 20 minutes sans livreur : les administrateurs (une fois).
 * - En attente depuis 10 minutes (le commerce n'a pas répondu) : rappel au
 *   commerce et alerte aux administrateurs (une fois) ; après 30 minutes,
 *   annulation automatique, remboursement demandé, client prévenu.
 *
 * Les livreurs indiquent s'ils sont en service et leurs quartiers
 * (User.delivery_available, User.delivery_zones).
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {notifyUsers} = require("./notifications");
const {ZONES} = require("./pricing");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const err = (code, message) => new AcquisitionError(code, message);
const STALE_MINUTES = 20;
// Le commerce doit accepter ou refuser une nouvelle commande.
const PENDING_ALERT_MINUTES = 10;
const PENDING_CANCEL_MINUTES = 30;
// Plus ancienne : laissée à l'admin (clôture en lot des vieilles commandes),
// pour ne pas annuler d'un coup l'historique déjà en base.
const PENDING_MAX_HOURS = 24;

async function userOf(db, ref) {
  if (!ref) return null;
  const u = await (typeof ref === "string" ? db.doc(`User/${ref}`) : ref).get();
  return u.exists ? u : null;
}

async function admins(db) {
  return (await db.collection("User").where("role", "==", "Admin").get()).docs;
}

const ref = (o) => o.get("order_unique_reference") || o.id;

/**
 * Réagit à la création (before = null) ou à la modification d'une commande.
 */
async function onOrderWrite({db, messaging, before, after}) {
  if (!after || !after.exists) return {sent: 0};
  const send = async (users, title, body, kind) => {
    const list = users.filter(Boolean);
    if (list.length === 0) return 0;
    await notifyUsers({db, messaging, users: list, title, body, kind,
      data: {orderId: after.id}});
    return list.length;
  };
  const was = before && before.exists ? before.get("status") || "" : null;
  const now = after.get("status") || "";
  const client = () => userOf(db, after.get("user_ref"));
  const seller = () => userOf(db, after.get("seller_ref"));
  let sent = 0;

  if (was === null) {
    sent += await send([await seller()], "Nouvelle commande",
        `Commande ${ref(after)} à confirmer.`, "order");
    return {sent};
  }

  if (was !== now) {
    // Plus « Prête » : les propositions encore ouvertes sont closes.
    if (was === "Pret") {
      await require("./dispatch").closeMissions({db, orderId: after.id,
        status: now === "encours" &&
          after.get("deliverer_ref") === before.get("offer_to") ?
          "accepted" : "cancelled"});
    }
    const shop = await seller();
    const shopName = shop ? shop.get("display_name") || "Le commerce" :
      "Le commerce";
    switch (now) {
      case "En préparation":
        sent += await send([await client()], "Commande acceptée",
            `${shopName} prépare votre commande ${ref(after)}.`, "order");
        break;
      case "Pret": {
        // Attribution : proposée au meilleur livreur (60 s), puis au
        // suivant ; à défaut, ouverte à tous ceux du quartier.
        await after.ref.update({ready_at: ts()});
        const r = await require("./dispatch").offerNext({db, messaging,
          orderId: after.id});
        sent += r.offered ? 1 : r.notified || 0;
        break;
      }
      case "encours": {
        const d = await userOf(db, after.get("deliverer_ref") ||
          after.get("deliver_reference"));
        const name = d ? d.get("display_name") || "un livreur" : "un livreur";
        sent += await send([await client()], "Votre commande est en route",
            `${name} vous livre la commande ${ref(after)}. Préparez votre ` +
            "code de remise.", "order");
        sent += await send([shop], "Commande prise en charge",
            `${name} a pris la commande ${ref(after)}.`, "order");
        break;
      }
      case "Livrer":
        sent += await send([await client()], "Commande livrée",
            `Commande ${ref(after)} remise. Confirmez la réception dans ` +
            "« Mes commandes ».", "order");
        break;
      case "Refusée":
        sent += await send([await client()], "Commande refusée",
            `${shopName} n'a pas pu accepter la commande ${ref(after)}.` +
            (after.get("refund_needed") ? " Vous serez remboursé." : ""),
            "order");
        break;
      case "Annulée":
        sent += await send([shop], "Commande annulée",
            `La commande ${ref(after)} a été annulée.`, "order");
        break;
      default:
        break;
    }
  }

  // Le livreur a récupéré la commande : le client sait qu'il arrive.
  if (after.get("picked_up_at") && !before.get("picked_up_at")) {
    sent += await send([await client()], "Votre livreur arrive",
        `Commande ${ref(after)} récupérée. Suivez le livreur en direct dans ` +
        "« Mes commandes ».", "order");
  }

  // Le livreur est arrivé chez le client.
  if (after.get("arrived_at") && !before.get("arrived_at")) {
    sent += await send([await client()], "Votre livreur est arrivé",
        `Votre livreur vous attend avec la commande ${ref(after)}. Préparez ` +
        "votre code de remise.", "order");
  }

  // Problème signalé par le livreur : les administrateurs, et un ticket
  // urgent pour le support.
  const issue = after.get("delivery_issue");
  const prevIssue = before.get("delivery_issue");
  if (issue && JSON.stringify(issue) !== JSON.stringify(prevIssue || null)) {
    const label = issue.label || issue.type || "problème";
    sent += await send(await admins(db), "Problème de livraison",
        `Commande ${ref(after)} : ${label}` +
        `${issue.note ? ` — ${issue.note}` : ""}.`, "admin");
    const reporter = await userOf(db, after.get("deliverer_ref") ||
      after.get("deliver_reference"));
    if (reporter) {
      await require("./support").createTicketFor({db, messaging,
        author: reporter, system: true, data: {category: "livraison",
          priority: "urgent", orderId: after.id,
          subject: `Incident de livraison : ${label}`,
          message: `Signalé par le livreur : ${label}` +
            `${issue.note ? ` — ${issue.note}` : ""}.`}});
    }
  }

  // Le client déclare ne pas avoir reçu sa commande : ticket au support.
  if (was !== now && now === "Non Reçu") {
    const buyer = await client();
    if (buyer) {
      await require("./support").createTicketFor({db, messaging,
        author: buyer, system: true, data: {category: "livraison",
          priority: "high", orderId: after.id,
          subject: `Commande ${ref(after)} non reçue`,
          message: "Le client indique ne pas avoir reçu sa commande."}});
    }
  }
  return {sent};
}

/** Commandes prêtes depuis 20 minutes sans livreur : alerte admin (1 fois). */
async function staleReadyOrders({db, messaging, now = new Date()}) {
  const snap = await db.collection("Orders").where("status", "==", "Pret")
      .get();
  const limit = now.getTime() - STALE_MINUTES * 60 * 1000;
  const stale = snap.docs.filter((o) => {
    const at = toDate(o.get("ready_at"));
    return at && at.getTime() <= limit && !o.get("stale_alert_at");
  });
  if (stale.length === 0) return {count: 0};
  const list = stale.map((o) => `${ref(o)} (${o.get("delivery_zone") || "?"})`)
      .join(", ");
  await notifyUsers({db, messaging, users: await admins(db),
    title: "Commandes sans livreur",
    body: `${stale.length} commande(s) prête(s) depuis plus de ` +
      `${STALE_MINUTES} min : ${list}. Attribuez un livreur.`,
    kind: "admin"});
  const batch = db.batch();
  stale.forEach((o) => batch.update(o.ref, {stale_alert_at: ts()}));
  await batch.commit();
  return {count: stale.length};
}

/**
 * Nouvelles commandes sans réponse du commerce :
 * - 10 min : rappel au commerce, alerte aux administrateurs (une fois) ;
 * - 30 min : annulée automatiquement (motif enregistré), remboursement
 *   demandé si elle était payée, client et administrateurs prévenus (le
 *   commerce l'est par le déclencheur des commandes).
 */
async function pendingOrders({db, messaging, now = new Date()}) {
  const snap = await db.collection("Orders")
      .where("status", "==", "En attente").get();
  const age = (o) => {
    const at = toDate(o.get("created_at"));
    return at ? (now.getTime() - at.getTime()) / 60000 : null;
  };
  const recent = snap.docs.filter((o) => {
    const m = age(o);
    return m !== null && m < PENDING_MAX_HOURS * 60;
  });
  const toCancel = recent.filter((o) => age(o) >= PENDING_CANCEL_MINUTES);
  const toRemind = recent.filter((o) => age(o) >= PENDING_ALERT_MINUTES &&
    age(o) < PENDING_CANCEL_MINUTES && !o.get("pending_alert_at"));

  let cancelled = 0;
  const reason = "Le commerce n'a pas répondu dans les " +
    `${PENDING_CANCEL_MINUTES} minutes.`;
  for (const o of toCancel) {
    // Transaction : le commerce a pu accepter entre-temps.
    const done = await db.runTransaction(async (tx) => {
      const cur = await tx.get(o.ref);
      if (!cur.exists || cur.get("status") !== "En attente") return null;
      const paid = cur.get("payment_status") === "Réussi";
      tx.update(o.ref, {status: "Annulée", cancel_reason: reason,
        cancelled_by: "system", status_updated_at: ts(),
        ...(paid ? {refund_needed: true} : {})});
      return {paid};
    });
    if (!done) continue;
    cancelled++;
    const shop = await userOf(db, o.get("seller_ref"));
    const shopName = shop ? shop.get("display_name") || "Le commerce" :
      "Le commerce";
    const buyer = await userOf(db, o.get("user_ref"));
    if (buyer) {
      await notifyUsers({db, messaging, users: [buyer],
        title: "Commande annulée",
        body: `${shopName} n'a pas répondu à votre commande ${ref(o)} : ` +
          "elle est annulée." + (done.paid ? " Vous serez remboursé." : "") +
          " Vous pouvez commander dans un autre commerce.",
        kind: "order", data: {orderId: o.id}});
    }
  }
  if (cancelled > 0) {
    const list = toCancel.map((o) => ref(o)).join(", ");
    await notifyUsers({db, messaging, users: await admins(db),
      title: "Commandes annulées sans réponse",
      body: `${cancelled} commande(s) annulée(s) : le commerce n'a pas ` +
        `répondu en ${PENDING_CANCEL_MINUTES} min (${list}). Vérifiez les ` +
        "remboursements.", kind: "admin"});
  }

  if (toRemind.length > 0) {
    for (const o of toRemind) {
      const shop = await userOf(db, o.get("seller_ref"));
      if (shop) {
        await notifyUsers({db, messaging, users: [shop],
          title: "Commande en attente",
          body: `La commande ${ref(o)} attend votre réponse depuis ` +
            `${PENDING_ALERT_MINUTES} min. Acceptez-la ou refusez-la : ` +
            `sans réponse, elle sera annulée après ${PENDING_CANCEL_MINUTES}` +
            " min.", kind: "order", data: {orderId: o.id}});
      }
    }
    const list = toRemind.map((o) => ref(o)).join(", ");
    await notifyUsers({db, messaging, users: await admins(db),
      title: "Commandes sans réponse du commerce",
      body: `${toRemind.length} commande(s) en attente depuis plus de ` +
        `${PENDING_ALERT_MINUTES} min : ${list}. Contactez le commerce.`,
      kind: "admin"});
    const batch = db.batch();
    toRemind.forEach((o) => batch.update(o.ref, {pending_alert_at: ts()}));
    await batch.commit();
  }
  return {reminded: toRemind.length, cancelled};
}

/** Disponibilités du livreur : en service, en pause, hors service. */
const STATES = ["on", "pause", "off"];

/**
 * Le livreur indique sa disponibilité et ses quartiers. En pause ou hors
 * service, il ne reçoit plus de nouvelles courses mais termine celles
 * qu'il a déjà acceptées. Chaque changement est historisé
 * (DelivererAvailability) pour l'administration.
 */
async function setDelivererStatus({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || u.get("role") !== "Deliver") {
    throw err("permission-denied", "Réservé aux livreurs.");
  }
  const changes = {};
  // Ancienne application : available true / false.
  const state = STATES.includes(data.state) ? data.state :
    data.available === undefined ? null : data.available === true ? "on" :
    "off";
  if (data.state !== undefined && !STATES.includes(data.state)) {
    throw err("invalid-argument", "Disponibilité inconnue.");
  }
  if (state) {
    changes.delivery_state = state;
    changes.delivery_available = state === "on";
    changes.delivery_available_at = ts();
    await db.collection("DelivererAvailability").add({deliverer_uid: uid,
      state, from: u.get("delivery_state") ||
        (u.get("delivery_available") === true ? "on" : "off"), at: ts()});
  }
  if (data.zones !== undefined) {
    if (!Array.isArray(data.zones)) {
      throw err("invalid-argument", "Quartiers invalides.");
    }
    const zones = [...new Set(data.zones.map((z) => String(z)))];
    if (zones.some((z) => !ZONES.includes(z))) {
      throw err("invalid-argument", "Quartier inconnu.");
    }
    changes.delivery_zones = zones;
  }
  await u.ref.update(changes);
  return {ok: true};
}

/**
 * Coordonnées utiles autour d'une commande, selon qui demande : le client
 * voit le commerce et le livreur, le livreur voit le client et le commerce,
 * le commerce voit le client et le livreur.
 */
async function orderContacts({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const o = await db.doc(`Orders/${String(data.orderId || "_").slice(0, 128)}`)
      .get();
  if (!o.exists) throw err("not-found", "Commande introuvable.");
  const me = await db.doc(`User/${uid}`).get();
  const buyerId = o.get("user_ref") && o.get("user_ref").id;
  const sellerId = o.get("seller_ref") && o.get("seller_ref").id;
  const delivRef = o.get("deliver_reference");
  const delivId = (delivRef && delivRef.id) || o.get("deliverer_ref") || "";
  const isAdmin = me.exists && me.get("role") === "Admin";
  if (!isAdmin && ![buyerId, sellerId, delivId].includes(uid)) {
    throw err("not-found", "Commande introuvable.");
  }
  const card = async (id, role) => {
    if (!id || id === uid) return null;
    const u = await db.doc(`User/${id}`).get();
    if (!u.exists) return null;
    return {role, name: u.get("display_name") || "",
      phone: u.get("phone_number") || ""};
  };
  const people = await Promise.all([card(buyerId, "client"),
    card(sellerId, "commerce"), card(delivId, "livreur")]);
  return {contacts: people.filter((p) => p && p.phone)};
}

module.exports = {onOrderWrite, staleReadyOrders, pendingOrders,
  setDelivererStatus, orderContacts, STALE_MINUTES, PENDING_ALERT_MINUTES,
  PENDING_CANCEL_MINUTES};
