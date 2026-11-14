/**
 * Suivi en direct d'une livraison.
 *
 * - Le livreur signale qu'il a récupéré la commande au commerce
 *   (Orders.picked_up_at ; le statut reste « encours »).
 * - Pendant la course, l'application du livreur envoie sa position GPS
 *   (collection DeliveryTracking, écrite et lue par le serveur seul, pour
 *   ne pas réveiller les déclencheurs de la commande toutes les secondes).
 * - Le client, le commerce et l'admin lisent le suivi : étapes, livreur,
 *   dernière position connue.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const err = (code, message) => new AcquisitionError(code, message);
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};

async function loadOrder(db, data) {
  const id = String(data.orderId || "").slice(0, 128);
  if (!id) throw err("invalid-argument", "Commande manquante.");
  const o = await db.doc(`Orders/${id}`).get();
  if (!o.exists) throw err("not-found", "Commande introuvable.");
  return o;
}

const delivererOf = (o) => {
  const r = o.get("deliver_reference");
  return (r && r.id) || o.get("deliverer_ref") || "";
};

async function requireMyDelivery(db, uid, data) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const o = await loadOrder(db, data);
  if (delivererOf(o) !== uid) {
    throw err("permission-denied", "Cette course ne vous est pas attribuée.");
  }
  if (o.get("status") !== "encours") {
    throw err("failed-precondition", "Cette course n'est plus en cours.");
  }
  return o;
}

/** Étapes du livreur : commande récupérée, arrivé chez le client. */
async function deliveryStep({db, uid, data}) {
  const o = await requireMyDelivery(db, uid, data);
  if (data.step === "picked_up") {
    if (!o.get("picked_up_at")) await o.ref.update({picked_up_at: ts()});
    return {ok: true};
  }
  if (data.step === "arrived") {
    if (!o.get("picked_up_at")) {
      throw err("failed-precondition",
          "Confirmez d'abord la récupération de la commande.");
    }
    if (!o.get("arrived_at")) await o.ref.update({arrived_at: ts()});
    return {ok: true};
  }
  throw err("invalid-argument", "Étape inconnue.");
}

const inRange = (v, min, max) => typeof v === "number" &&
  Number.isFinite(v) && v >= min && v <= max;

/** Position GPS du livreur pendant la course. */
async function deliveryPosition({db, uid, data}) {
  const o = await requireMyDelivery(db, uid, data);
  const {lat, lng} = data;
  if (!inRange(lat, -90, 90) || !inRange(lng, -180, 180)) {
    throw err("invalid-argument", "Position invalide.");
  }
  const acc = inRange(data.accuracy, 0, 100000) ? data.accuracy : null;
  await db.doc(`DeliveryTracking/${o.id}`).set({lat, lng, accuracy: acc,
    deliverer_uid: uid, at: ts()});
  return {ok: true};
}

/** Suivi lu par le client, le commerce, le livreur ou un admin. */
async function deliveryTracking({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const o = await loadOrder(db, data);
  const buyer = o.get("user_ref") && o.get("user_ref").id;
  const seller = o.get("seller_ref") && o.get("seller_ref").id;
  const deliverer = delivererOf(o);
  if (![buyer, seller, deliverer].includes(uid)) {
    const me = await db.doc(`User/${uid}`).get();
    if (!me.exists || me.get("role") !== "Admin") {
      throw err("not-found", "Commande introuvable.");
    }
  }
  const [d, shop, track] = await Promise.all([
    deliverer ? db.doc(`User/${deliverer}`).get() : null,
    seller ? db.doc(`User/${seller}`).get() : null,
    db.doc(`DeliveryTracking/${o.id}`).get(),
  ]);
  const live = o.get("status") === "encours" && track.exists;
  return {
    status: o.get("status") || "",
    zone: o.get("delivery_zone") || "",
    shopZone: o.get("shop_zone") || "",
    shopPoint: o.get("shop_point") || null,
    deliveryPoint: o.get("delivery_point") || null,
    km: o.get("delivery_km") ?? null,
    address: o.get("delivery_location") || "",
    acceptedAt: iso(o.get("accepted_at") || o.get("status_updated_at")),
    readyAt: iso(o.get("ready_at")),
    takenAt: iso(o.get("taken_at")),
    pickedUpAt: iso(o.get("picked_up_at")),
    arrivedAt: iso(o.get("arrived_at")),
    atShopAt: iso(o.get("at_shop_at")),
    delay: o.get("delay") ? {minutes: o.get("delay").minutes,
      reason: o.get("delay").reason || ""} : null,
    deliveryStatus: o.get("delivery_status") || "",
    deliveredAt: iso(o.get("delivered_at")),
    shop: shop && shop.exists ? {name: shop.get("display_name") || ""} : null,
    deliverer: d && d.exists ? {name: d.get("display_name") || "",
      photo: d.get("photo_url") || ""} : null,
    position: live ? {lat: track.get("lat"), lng: track.get("lng"),
      at: iso(track.get("at"))} : null,
  };
}

module.exports = {deliveryStep, deliveryPosition, deliveryTracking};
