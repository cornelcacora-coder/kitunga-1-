/**
 * Attribution des courses (dispatch).
 *
 * Quand une commande est prête, le serveur choisit le meilleur livreur et
 * lui propose la course en exclusivité pendant un temps limité (60 s par
 * défaut). Refus ou expiration : la course est proposée au suivant. Après
 * plusieurs essais, ou si personne ne convient, elle est ouverte à tous
 * les livreurs en service du quartier (le premier qui accepte la prend).
 *
 * Choix du livreur (le score le plus bas gagne) :
 * - disponible (en service), compte actif, couvre le quartier du client ;
 * - capacité : nombre de courses en cours inférieur à celle de son
 *   véhicule (moto, voiture) ;
 * - distance jusqu'au commerce depuis sa dernière position, si elle a moins
 *   de 10 minutes ; sinon « position inconnue » (pénalité de 5 km) ;
 * - +2 par course déjà en cours.
 * La raison du choix est enregistrée (dispatch_reason) pour l'admin.
 *
 * Une seule attribution possible : l'acceptation se fait en transaction
 * (commande encore prête, sans livreur, proposition toujours valide).
 *
 * Collections : Missions (une proposition = un livreur, une commande),
 * Settings/dispatch (réglages modifiables par l'admin).
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {notifyUsers} = require("./notifications");
const {ZONE_POINTS} = require("./delivery_pricing");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const del = () => admin.firestore.FieldValue.delete();
const err = (code, message) => new AcquisitionError(code, message);
const SETTINGS = "Settings/dispatch";
const POSITION_FRESH_MS = 10 * 60 * 1000;
const UNKNOWN_KM = 5;

const DEFAULTS = {
  auto: true, // false : ouverte à tous (premier qui accepte)
  require_verified: false, // true : livreurs aux documents validés
  offer_seconds: 60,
  max_attempts: 3,
  capacity: {moto: 2, voiture: 3},
};
// Pas de vélos chez Kitunga : un ancien choix « velo » compte comme moto.
const VEHICLES = ["moto", "voiture"];

async function loadSettings(db) {
  const s = await db.doc(SETTINGS).get();
  const v = s.exists ? s.data() : {};
  return {...DEFAULTS, ...v,
    capacity: {...DEFAULTS.capacity, ...(v.capacity || {})}};
}

function km(a, b) {
  if (!a || !b) return null;
  const rad = (d) => d * Math.PI / 180;
  const h = Math.sin(rad(b[0] - a[0]) / 2) ** 2 + Math.cos(rad(a[0])) *
    Math.cos(rad(b[0])) * Math.sin(rad(b[1] - a[1]) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

const delivererOf = (o) => {
  const r = o.get("deliver_reference");
  return (r && r.id) || o.get("deliverer_ref") || "";
};

/**
 * Livreurs possibles pour une commande, du meilleur au moins bon.
 * Renvoie [{user, score, km, active, reason}].
 */
async function rankDeliverers({db, order, exclude = [], settings,
  now = new Date()}) {
  const zone = order.get("delivery_zone") || "";
  const pickup = ZONE_POINTS[order.get("shop_zone") || ""] ||
    ZONE_POINTS[zone] || null;
  const [users, running] = await Promise.all([
    db.collection("User").where("role", "==", "Deliver")
        .where("delivery_available", "==", true).get(),
    db.collection("Orders").where("status", "==", "encours").get(),
  ]);
  const active = {};
  for (const o of running.docs) {
    const id = delivererOf(o);
    if (id) active[id] = (active[id] || 0) + 1;
  }
  const out = [];
  for (const u of users.docs) {
    if (exclude.includes(u.id)) continue;
    if (u.get("account_status") === "suspended") continue;
    // Option de l'admin : seulement les livreurs aux documents validés.
    if (settings.require_verified && u.get("verified") !== true) continue;
    const zones = u.get("delivery_zones") || [];
    if (zones.length && zone && !zones.includes(zone)) continue;
    const vehicle = VEHICLES.includes(u.get("vehicle")) ?
      u.get("vehicle") : "moto";
    const cap = Number(settings.capacity[vehicle]) || 1;
    const n = active[u.id] || 0;
    if (n >= cap) continue;
    const pos = u.get("last_position");
    const at = pos && toDate(pos.at);
    const fresh = at && now - at <= POSITION_FRESH_MS &&
      typeof pos.lat === "number" && typeof pos.lng === "number";
    const dist = fresh && pickup ? km([pos.lat, pos.lng], pickup) : null;
    const score = (dist == null ? UNKNOWN_KM : dist) + 2 * n;
    const mins = fresh ? Math.max(0, Math.round((now - at) / 60000)) : null;
    const reason = [
      dist == null ? "position inconnue" :
        `${dist.toFixed(1).replace(".", ",")} km du commerce ` +
        `(position il y a ${mins} min)`,
      `${n} course${n > 1 ? "s" : ""} en cours (${vehicle}, ` +
        `capacité ${cap})`,
      zones.length ? `couvre ${zone || "le quartier"}` : "couvre toute la ville",
    ].join(" · ");
    out.push({user: u, score, km: dist, active: n, reason});
  }
  return out.sort((a, b) => a.score - b.score);
}

/** Anciens destinataires (refus, expiration) d'une commande. */
async function triedFor(db, orderId) {
  const snap = await db.collection("Missions")
      .where("order_id", "==", orderId).get();
  return snap.docs.map((m) => m.get("deliverer_uid"));
}

/**
 * Propose la course au meilleur livreur suivant. Sans candidat ou après
 * le nombre d'essais maximal : course ouverte à tous (une seule fois).
 */
async function offerNext({db, messaging, orderId, now = new Date()}) {
  const settings = await loadSettings(db);
  const ref = db.doc(`Orders/${orderId}`);
  const order = await ref.get();
  if (!order.exists || order.get("status") !== "Pret" ||
      delivererOf(order)) return {offered: false, why: "not-ready"};
  const until = toDate(order.get("offer_expires_at"));
  if (order.get("offer_to") && until && until > now) {
    return {offered: false, why: "pending"};
  }
  const tried = await triedFor(db, orderId);
  const attempts = tried.length;
  const ranked = settings.auto && attempts < Number(settings.max_attempts) ?
    await rankDeliverers({db, order, exclude: tried, settings, now}) : [];
  if (ranked.length === 0) return openToAll({db, messaging, order});

  const best = ranked[0];
  const expires = new Date(now.getTime() +
    Number(settings.offer_seconds) * 1000);
  const mission = db.collection("Missions").doc();
  const ok = await db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    const live = toDate(o.get("offer_expires_at"));
    if (o.get("status") !== "Pret" || delivererOf(o) ||
        (o.get("offer_to") && live && live > now)) return false;
    tx.set(mission, {order_id: orderId, deliverer_uid: best.user.id,
      status: "offered", attempt: attempts + 1, expires_at: expires,
      score: Math.round(best.score * 10) / 10, reason: best.reason,
      created_at: ts()});
    tx.update(ref, {offer_to: best.user.id, offer_expires_at: expires,
      offer_mission: mission.id, dispatch_reason: best.reason,
      dispatch_attempts: attempts + 1, dispatch_mode: "auto"});
    return true;
  });
  if (!ok) return {offered: false, why: "race"};
  const fees = Math.round(Number(order.get("delivery_fees")) || 0);
  await notifyUsers({db, messaging, users: [best.user],
    title: "Course proposée : répondez vite",
    body: `${order.get("shop_zone") || "Commerce"} → ` +
      `${order.get("delivery_zone") || "Brazzaville"} · ${fees} F. ` +
      `${settings.offer_seconds} s pour accepter.`,
    kind: "mission", data: {orderId, missionId: mission.id}});
  return {offered: true, to: best.user.id, missionId: mission.id};
}

/** Course ouverte à tous les livreurs en service du quartier. */
async function openToAll({db, messaging, order}) {
  if (order.get("dispatch_mode") === "open") {
    return {offered: false, why: "open"};
  }
  await order.ref.update({dispatch_mode: "open", offer_to: del(),
    offer_expires_at: del(), offer_mission: del()});
  const zone = order.get("delivery_zone") || "";
  const users = (await db.collection("User").where("role", "==", "Deliver")
      .where("delivery_available", "==", true).get()).docs.filter((u) => {
    if (u.get("account_status") === "suspended") return false;
    const zones = u.get("delivery_zones") || [];
    return zones.length === 0 || !zone || zones.includes(zone);
  });
  if (users.length) {
    const fees = Math.round(Number(order.get("delivery_fees")) || 0);
    await notifyUsers({db, messaging, users,
      title: "Nouvelle commande à livrer",
      body: `${zone || "Brazzaville"} · frais de livraison ${fees} F. ` +
        "Le premier qui accepte la prend.",
      kind: "delivery", data: {orderId: order.id}});
  }
  return {offered: false, why: "open", notified: users.length};
}

/** Le livreur accepte ou refuse la course qui lui est proposée. */
async function respondMission({db, messaging, uid, data, now = new Date()}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const mref = db.doc(`Missions/${String(data.missionId || "_")
      .slice(0, 128)}`);
  const accept = data.accept === true;
  const result = await db.runTransaction(async (tx) => {
    const m = await tx.get(mref);
    if (!m.exists || m.get("deliverer_uid") !== uid) {
      throw err("not-found", "Proposition introuvable.");
    }
    if (m.get("status") !== "offered") {
      throw err("failed-precondition", "Cette proposition n'est plus valable.");
    }
    const oref = db.doc(`Orders/${m.get("order_id")}`);
    const o = await tx.get(oref);
    const expired = toDate(m.get("expires_at")) <= now;
    const stillMine = o.exists && o.get("offer_mission") === m.id;
    if (!accept) {
      tx.update(mref, {status: "declined", answered_at: ts(),
        reason_declined: String(data.reason || "").slice(0, 200)});
      if (stillMine) {
        tx.update(oref, {offer_to: del(), offer_expires_at: del(),
          offer_mission: del()});
      }
      return {orderId: m.get("order_id"), accepted: false};
    }
    // Trop tard ou plus disponible : la proposition est close (écrite
    // avant de répondre au livreur), puis la course passe au suivant.
    if (expired) {
      tx.update(mref, {status: "expired"});
      if (stillMine) {
        tx.update(oref, {offer_to: del(), offer_expires_at: del(),
          offer_mission: del()});
      }
      return {orderId: m.get("order_id"), accepted: false, refused: "late"};
    }
    if (!stillMine || o.get("status") !== "Pret" || delivererOf(o)) {
      tx.update(mref, {status: "cancelled"});
      return {orderId: m.get("order_id"), accepted: false, refused: "gone"};
    }
    tx.update(mref, {status: "accepted", answered_at: ts()});
    tx.update(oref, {status: "encours", deliverer_ref: uid,
      deliver_reference: db.doc(`User/${uid}`), taken_at: ts(),
      offer_to: del(), offer_expires_at: del(), offer_mission: del(),
      status_actor: {uid, role: "Deliver", at: Date.now()},
      status_reason: null});
    return {orderId: m.get("order_id"), accepted: true};
  });
  if (!result.accepted) {
    await offerNext({db, messaging, orderId: result.orderId, now});
  }
  if (result.refused === "late") {
    throw err("deadline-exceeded",
        "Le temps pour accepter est écoulé : la course est proposée à un " +
        "autre livreur.");
  }
  if (result.refused === "gone") {
    throw err("failed-precondition", "Cette course n'est plus disponible.");
  }
  return result;
}

/** Propositions expirées : marquées, et la course passe au suivant. */
async function expireOffers({db, messaging, now = new Date()}) {
  const snap = await db.collection("Missions")
      .where("status", "==", "offered").get();
  let expired = 0;
  for (const m of snap.docs) {
    if (toDate(m.get("expires_at")) > now) continue;
    await m.ref.update({status: "expired"});
    const oref = db.doc(`Orders/${m.get("order_id")}`);
    const o = await oref.get();
    if (o.exists && o.get("offer_mission") === m.id) {
      await oref.update({offer_to: del(), offer_expires_at: del(),
        offer_mission: del()});
    }
    await offerNext({db, messaging, orderId: m.get("order_id"), now});
    expired++;
  }
  return {expired};
}

/** Commande sortie de « Prête » (prise, annulée…) : propositions closes. */
async function closeMissions({db, orderId, status = "cancelled"}) {
  const snap = await db.collection("Missions")
      .where("order_id", "==", orderId).where("status", "==", "offered").get();
  const batch = db.batch();
  snap.docs.forEach((m) => batch.update(m.ref, {status}));
  if (snap.size) await batch.commit();
  return snap.size;
}

/** Position du livreur en service (au plus toutes les 2 minutes). */
async function delivererPing({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || u.get("role") !== "Deliver") {
    throw err("permission-denied", "Réservé aux livreurs.");
  }
  const ok = (v, a) => typeof v === "number" && Number.isFinite(v) &&
    Math.abs(v) <= a;
  if (!ok(data.lat, 90) || !ok(data.lng, 180)) {
    throw err("invalid-argument", "Position invalide.");
  }
  // Seulement en service : la position n'est pas suivie hors du travail.
  if (u.get("delivery_available") !== true) return {ok: false};
  await u.ref.update({last_position: {lat: data.lat, lng: data.lng,
    at: ts()}});
  return {ok: true};
}

/** Le livreur indique son véhicule. */
async function setVehicle({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || u.get("role") !== "Deliver") {
    throw err("permission-denied", "Réservé aux livreurs.");
  }
  if (!VEHICLES.includes(data.vehicle)) {
    throw err("invalid-argument", "Véhicule inconnu.");
  }
  await u.ref.update({vehicle: data.vehicle});
  return {ok: true};
}

/** L'admin lit ou règle l'attribution automatique. */
async function adminDispatchSettings({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  if (data.save) {
    const s = data.save;
    const n = (v, min, max) => {
      const x = Number(v);
      if (!Number.isFinite(x) || x < min || x > max) {
        throw err("invalid-argument", "Valeur invalide.");
      }
      return Math.round(x);
    };
    const next = {auto: s.auto !== false,
      require_verified: s.require_verified === true,
      offer_seconds: n(s.offer_seconds, 15, 600),
      max_attempts: n(s.max_attempts, 1, 10),
      capacity: {moto: n((s.capacity || {}).moto, 1, 10),
        voiture: n((s.capacity || {}).voiture, 1, 10)}};
    await db.doc(SETTINGS).set({...next, updated_by: adminUid,
      updated_at: ts()});
    await db.collection("audit_logs").add({actor_uid: adminUid,
      actor_role: "Admin", action: "dispatch.update", target: SETTINGS,
      details: next, created_at: ts()});
  }
  const s = await loadSettings(db);
  return {settings: {auto: s.auto, require_verified: s.require_verified,
    offer_seconds: s.offer_seconds,
    max_attempts: s.max_attempts, capacity: s.capacity}};
}

/** Propositions d'une commande (admin) : qui, quand, réponse, pourquoi. */
async function orderMissions({db, uid, data}) {
  await requireAdmin(db, uid);
  const snap = await db.collection("Missions")
      .where("order_id", "==", String(data.orderId || "_")).get();
  const names = {};
  for (const m of snap.docs) {
    const id = m.get("deliverer_uid");
    if (!(id in names)) {
      const u = await db.doc(`User/${id}`).get();
      names[id] = u.exists ? u.get("display_name") || id : id;
    }
  }
  return {missions: snap.docs.map((m) => ({id: m.id,
    deliverer: names[m.get("deliverer_uid")], status: m.get("status"),
    attempt: m.get("attempt"), reason: m.get("reason") || "",
    createdAt: (toDate(m.get("created_at")) || new Date(0)).toISOString()}))
      .sort((a, b) => a.attempt - b.attempt)};
}

module.exports = {DEFAULTS, VEHICLES, loadSettings, rankDeliverers,
  offerNext, openToAll, respondMission, expireOffers, closeMissions,
  delivererPing, setVehicle, adminDispatchSettings, orderMissions};
