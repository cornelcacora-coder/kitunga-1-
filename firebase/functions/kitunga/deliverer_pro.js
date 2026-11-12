/**
 * Espace professionnel du livreur : documents et vérification, note des
 * clients, performances, demandes de retrait, retard, arrivée au commerce,
 * alerte de sécurité et contact d'urgence.
 *
 * Documents : DelivererDocuments/{uid}_{type}. Les photos sont rangées
 * dans documents/{uid}/ (Storage privé) ; seul l'admin reçoit leur adresse.
 * Retraits : Withdrawals (une demande en attente à la fois, plafonnée au
 * solde) ; l'admin la valide par un versement du grand livre.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {notifyUsers} = require("./notifications");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const inc = (n) => admin.firestore.FieldValue.increment(n);
const err = (code, message) => new AcquisitionError(code, message);
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};
const DAY = 86400000;

const DOC_TYPES = {
  identity: {label: "Pièce d'identité", required: true},
  license: {label: "Permis de conduire", required: true},
  registration: {label: "Carte grise du véhicule", required: true},
  insurance: {label: "Assurance du véhicule", required: false},
};

async function deliverer(db, uid) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || u.get("role") !== "Deliver") {
    throw err("permission-denied", "Réservé aux livreurs.");
  }
  return u;
}

async function staffList(db) {
  const out = [];
  for (const r of ["Admin", "Support"]) {
    out.push(...(await db.collection("User").where("role", "==", r).get())
        .docs);
  }
  return out;
}

/** Photo d'un document : seulement dans le dossier privé du livreur. */
function documentUrl(url, uid) {
  const v = text(url, 1500);
  try {
    const u = new URL(v);
    if (u.protocol === "https:" &&
        u.hostname === "firebasestorage.googleapis.com" &&
        decodeURIComponent(u.pathname).includes(`/o/documents/${uid}/`)) {
      return v;
    }
  } catch (e) {
    // adresse invalide
  }
  throw err("invalid-argument", "Photo du document invalide.");
}

function docStatus(d, now = new Date()) {
  const exp = toDate(d.expires_at);
  if (d.status === "approved" && exp && exp < now) return "expired";
  return d.status || "pending";
}

/** État de vérification du livreur à partir de ses documents. */
function verificationOf(docs, now = new Date()) {
  const byType = Object.fromEntries(docs.map((d) => [d.type, d]));
  const required = Object.entries(DOC_TYPES).filter(([, t]) => t.required)
      .map(([k]) => k);
  const states = required.map((k) => byType[k] ?
    docStatus(byType[k], now) : "missing");
  if (states.includes("expired")) return "expired";
  if (states.includes("rejected")) return "rejected";
  if (states.includes("missing")) return "missing";
  if (states.includes("pending")) return "pending";
  return "verified";
}

async function docsOf(db, uid) {
  const snap = await db.collection("DelivererDocuments")
      .where("uid", "==", uid).get();
  return snap.docs.map((d) => d.data());
}

/** Le livreur dépose (ou renouvelle) un document. */
async function submitDocument({db, messaging, uid, data}) {
  await deliverer(db, uid);
  const type = text(data.type, 20);
  if (!DOC_TYPES[type]) throw err("invalid-argument", "Document inconnu.");
  const photo = documentUrl(data.photoUrl, uid);
  const expires = data.expiresAt ? new Date(String(data.expiresAt)) : null;
  if (expires && (isNaN(expires) || expires < new Date())) {
    throw err("invalid-argument", "Date d'expiration dépassée ou invalide.");
  }
  await db.doc(`DelivererDocuments/${uid}_${type}`).set({uid, type,
    label: DOC_TYPES[type].label, photo_url: photo,
    number: text(data.number, 60), expires_at: expires,
    status: "pending", reject_reason: "", submitted_at: ts(),
    reviewed_by: null, reviewed_at: null});
  await notifyUsers({db, messaging,
    users: (await staffList(db)).filter((u) => u.get("role") === "Admin"),
    title: "Document à vérifier",
    body: `${DOC_TYPES[type].label} déposé par un livreur.`,
    kind: "admin", data: {uid}});
  return {ok: true};
}

/** Mes documents et mon état de vérification. */
async function myDocuments({db, uid, now = new Date()}) {
  const u = await deliverer(db, uid);
  const docs = await docsOf(db, uid);
  const byType = Object.fromEntries(docs.map((d) => [d.type, d]));
  return {
    verification: verificationOf(docs, now),
    suspended: u.get("account_status") === "suspended",
    documents: Object.entries(DOC_TYPES).map(([type, t]) => {
      const d = byType[type];
      return {type, label: t.label, required: t.required,
        status: d ? docStatus(d, now) : "missing",
        number: d ? d.number || "" : "",
        expiresAt: d ? iso(d.expires_at) : null,
        rejectReason: d ? d.reject_reason || "" : ""};
    }),
  };
}

/** Documents à vérifier (admin), avec les photos. */
async function adminDocuments({db, uid, data, now = new Date()}) {
  await requireAdmin(db, uid);
  let q = db.collection("DelivererDocuments");
  if (data.uid) q = q.where("uid", "==", String(data.uid).slice(0, 128));
  const snap = await q.get();
  const names = {};
  const list = [];
  for (const d of snap.docs) {
    const x = d.data();
    const st = docStatus(x, now);
    if (!data.uid && data.filter !== "all" && st !== "pending") continue;
    if (!(x.uid in names)) {
      const u = await db.doc(`User/${x.uid}`).get();
      names[x.uid] = u.exists ? u.get("display_name") || x.uid : x.uid;
    }
    list.push({id: d.id, uid: x.uid, name: names[x.uid], type: x.type,
      label: x.label, status: st, number: x.number || "",
      photoUrl: x.photo_url, expiresAt: iso(x.expires_at),
      rejectReason: x.reject_reason || "",
      submittedAt: iso(x.submitted_at)});
  }
  return {documents: list.sort((a, b) =>
    String(b.submittedAt).localeCompare(String(a.submittedAt)))};
}

/** L'admin valide ou refuse un document ; badge « vérifié » à jour. */
async function adminReviewDocument({db, messaging, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`DelivererDocuments/${text(data.id, 200) || "_"}`);
  const d = await ref.get();
  if (!d.exists) throw err("not-found", "Document introuvable.");
  const approve = data.approve === true;
  const reason = text(data.reason, 300);
  if (!approve && !reason) {
    throw err("invalid-argument", "Indiquez le motif du refus.");
  }
  await ref.update({status: approve ? "approved" : "rejected",
    reject_reason: approve ? "" : reason, reviewed_by: adminUid,
    reviewed_at: ts()});
  const owner = d.get("uid");
  const verification = verificationOf(await docsOf(db, owner));
  await db.doc(`User/${owner}`).update({verified: verification ===
    "verified", verification});
  await db.collection("audit_logs").add({actor_uid: adminUid,
    actor_role: "Admin", action: approve ? "document.approve" :
      "document.reject", target: ref.path, details: {reason},
    created_at: ts()});
  const u = await db.doc(`User/${owner}`).get();
  await notifyUsers({db, messaging, users: [u],
    title: approve ? `${d.get("label")} validé` : `${d.get("label")} refusé`,
    body: approve ? (verification === "verified" ?
      "Votre compte livreur est vérifié." : "Merci, document validé.") :
      `Motif : ${reason}. Déposez un nouveau document.`,
    kind: "documents"});
  return {verification};
}

/** Note du client après la livraison (une seule fois par commande). */
async function rateDelivery({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const stars = Math.round(Number(data.stars));
  if (!(stars >= 1 && stars <= 5)) {
    throw err("invalid-argument", "Note de 1 à 5 étoiles.");
  }
  const ref = db.doc(`Orders/${text(data.orderId, 128) || "_"}`);
  return db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    if (!o.exists || !o.get("user_ref") || o.get("user_ref").id !== uid) {
      throw err("not-found", "Commande introuvable.");
    }
    if (!["Livrer", "Reçu"].includes(o.get("status"))) {
      throw err("failed-precondition", "Notez après la livraison.");
    }
    if (o.get("rating")) return {ok: true, already: true};
    const d = (o.get("deliver_reference") && o.get("deliver_reference").id) ||
      o.get("deliverer_ref");
    if (!d) throw err("failed-precondition", "Aucun livreur à noter.");
    tx.update(ref, {rating: {stars, comment: text(data.comment, 300),
      at: ts()}});
    tx.update(db.doc(`User/${d}`), {rating_sum: inc(stars),
      rating_count: inc(1)});
    // Note du commerce (facultative), donnée en même temps.
    const shopStars = Math.round(Number(data.shopStars));
    if (shopStars >= 1 && shopStars <= 5 && o.get("seller_ref") &&
        !o.get("shop_rating")) {
      tx.update(ref, {shop_rating: {stars: shopStars,
        comment: text(data.shopComment, 300), at: ts()}});
      tx.update(o.get("seller_ref"), {shop_rating_sum: inc(shopStars),
        shop_rating_count: inc(1)});
    }
    return {ok: true};
  });
}

/** Performances du livreur (données réelles, règles expliquées). */
async function myPerformance({db, uid, now = new Date()}) {
  const u = await deliverer(db, uid);
  const [orders, ledger, missions] = await Promise.all([
    db.collection("Orders").where("deliverer_ref", "==", uid).get(),
    db.collection("Ledger").where("account_uid", "==", uid).get(),
    db.collection("Missions").where("deliverer_uid", "==", uid).get(),
  ]);
  let delivered = 0;
  let failed = 0;
  let cancelledByOthers = 0;
  let km = 0;
  const durations = [];
  for (const o of orders.docs) {
    const s = o.get("status");
    if (["Livrer", "Reçu"].includes(s)) {
      delivered++;
      km += Number(o.get("delivery_km")) || 0;
      const a = toDate(o.get("taken_at"));
      const b = toDate(o.get("delivered_at"));
      if (a && b && b > a) durations.push((b - a) / 60000);
    } else if (s === "Non Reçu" || o.get("delivery_status") === "failed") {
      failed++;
    } else if (["Annulée", "Refusée"].includes(s)) {
      // Annulation par le client, le commerce ou l'admin : pas imputée au
      // livreur.
      cancelledByOthers++;
    }
  }
  const m = {accepted: 0, declined: 0, expired: 0};
  for (const x of missions.docs) {
    if (x.get("status") in m) m[x.get("status")]++;
  }
  // Gains par semaine (8 dernières) et du mois (heure de Brazzaville).
  const weeks = Array.from({length: 8}, (_, i) => ({index: i, amount: 0}));
  let month = 0;
  const local = new Date(now.getTime() + 3600000);
  const monthKey = local.toISOString().slice(0, 7);
  for (const e of ledger.docs) {
    const amount = Number(e.get("amount")) || 0;
    if (e.get("type") === "payout") continue;
    const at = toDate(e.get("at"));
    if (!at) continue;
    const age = Math.floor((now - at) / (7 * DAY));
    if (age >= 0 && age < 8) weeks[7 - age].amount += amount;
    if (new Date(at.getTime() + 3600000).toISOString().slice(0, 7) ===
      monthKey) month += amount;
  }
  const finished = delivered + failed;
  const answered = m.accepted + m.declined + m.expired;
  const count = u.get("rating_count") || 0;
  return {
    delivered, failed, cancelledByOthers,
    successRate: finished ? Math.round(delivered * 100 / finished) : null,
    acceptanceRate: answered ? Math.round(m.accepted * 100 / answered) : null,
    averageMinutes: durations.length ? Math.round(durations.reduce((a, b) =>
      a + b, 0) / durations.length) : null,
    distanceKm: Math.round(km * 10) / 10,
    monthEarnings: month,
    weeklyEarnings: weeks.map((w) => w.amount),
    rating: count ? Math.round((u.get("rating_sum") || 0) * 10 / count) / 10 :
      null,
    ratingCount: count,
  };
}

async function balanceOf(db, uid) {
  const snap = await db.collection("Ledger").where("account_uid", "==", uid)
      .get();
  return snap.docs.reduce((s, e) => s + (Number(e.get("amount")) || 0), 0);
}

/** Demande de retrait (livreur ou commerce). */
async function requestWithdrawal({db, messaging, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || !["Deliver", "Seller"].includes(u.get("role"))) {
    throw err("permission-denied", "Réservé aux livreurs et commerces.");
  }
  const amount = Math.round(Number(data.amount) || 0);
  if (amount < 500) throw err("invalid-argument", "Minimum 500 F.");
  const method = ["MoMo", "Airtel"].includes(data.method) ? data.method :
    "MoMo";
  const phone = text(data.phone, 20) || u.get("phone_number") || "";
  const ref = db.doc(`Withdrawals/${uid}_pending`);
  const balance = await balanceOf(db, uid);
  if (amount > balance) {
    throw err("failed-precondition",
        `Montant supérieur à votre solde (${balance} F).`);
  }
  await db.runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (cur.exists) {
      throw err("already-exists",
          "Une demande de retrait est déjà en cours de traitement.");
    }
    tx.set(ref, {uid, role: u.get("role"),
      name: u.get("display_name") || "", amount, method, phone,
      status: "pending", created_at: ts()});
  });
  await notifyUsers({db, messaging,
    users: (await staffList(db)).filter((x) => x.get("role") === "Admin"),
    title: "Demande de retrait", body: `${u.get("display_name") || "Un "
      + "partenaire"} demande ${amount} F (${method}).`, kind: "finance"});
  return {ok: true};
}

/** Mes demandes de retrait (en cours et passées). */
async function myWithdrawals({db, uid}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const snap = await db.collection("Withdrawals").where("uid", "==", uid)
      .get();
  return {withdrawals: snap.docs.map((w) => ({id: w.id,
    amount: w.get("amount"), method: w.get("method"),
    status: w.get("status"), reason: w.get("reason") || "",
    createdAt: iso(w.get("created_at"))}))
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))};
}

/** Demandes de retrait (admin). */
async function adminWithdrawals({db, uid}) {
  await requireAdmin(db, uid);
  const snap = await db.collection("Withdrawals")
      .where("status", "==", "pending").get();
  return {withdrawals: snap.docs.map((w) => ({id: w.id, uid: w.get("uid"),
    name: w.get("name"), role: w.get("role"), amount: w.get("amount"),
    method: w.get("method"), phone: w.get("phone"),
    createdAt: iso(w.get("created_at"))}))};
}

/**
 * L'admin traite une demande : versement fait (écriture du grand livre,
 * une seule fois) ou refus motivé. La demande est archivée.
 */
async function adminDecideWithdrawal({db, messaging, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`Withdrawals/${text(data.id, 200) || "_"}`);
  const w = await ref.get();
  if (!w.exists || w.get("status") !== "pending") {
    throw err("not-found", "Demande introuvable ou déjà traitée.");
  }
  const archive = db.collection("Withdrawals").doc();
  if (data.approve === true) {
    const {adminRecordPayout} = require("./finance");
    await adminRecordPayout({db, messaging, uid: adminUid, data: {
      uid: w.get("uid"), amount: w.get("amount"), method: w.get("method"),
      reference: text(data.reference, 120), requestId: `w-${archive.id}`}});
  } else if (!text(data.reason, 300)) {
    throw err("invalid-argument", "Indiquez le motif du refus.");
  }
  await db.runTransaction(async (tx) => {
    tx.set(archive, {...w.data(), status: data.approve === true ? "paid" :
      "rejected", reason: text(data.reason, 300),
    decided_by: adminUid, decided_at: ts()});
    tx.delete(ref);
  });
  if (data.approve !== true) {
    const u = await db.doc(`User/${w.get("uid")}`).get();
    await notifyUsers({db, messaging, users: [u],
      title: "Demande de retrait refusée",
      body: `Motif : ${text(data.reason, 300)}`, kind: "finance"});
  }
  return {ok: true};
}

async function myCourse(db, uid, orderId) {
  await deliverer(db, uid);
  const o = await db.doc(`Orders/${text(orderId, 128) || "_"}`).get();
  const mine = o.exists && ((o.get("deliver_reference") &&
    o.get("deliver_reference").id === uid) || o.get("deliverer_ref") === uid);
  if (!mine) throw err("not-found", "Course introuvable.");
  if (o.get("status") !== "encours") {
    throw err("failed-precondition", "Cette course n'est plus en cours.");
  }
  return o;
}

/** Retard annoncé au client et au commerce. */
async function reportDelay({db, messaging, uid, data}) {
  const o = await myCourse(db, uid, data.orderId);
  const minutes = Math.round(Number(data.minutes));
  if (![10, 20, 30, 45, 60].includes(minutes)) {
    throw err("invalid-argument", "Durée de retard invalide.");
  }
  const reason = text(data.reason, 200);
  await o.ref.update({delay: {minutes, reason, at: ts()}});
  const users = (await Promise.all([o.get("user_ref"), o.get("seller_ref")]
      .filter(Boolean).map((r) => r.get()))).filter((x) => x.exists);
  await notifyUsers({db, messaging, users,
    title: "Livraison retardée",
    body: `Le livreur aura environ ${minutes} min de retard` +
      `${reason ? ` (${reason})` : ""}.`, kind: "order",
    data: {orderId: o.id}});
  return {ok: true};
}

/** Arrivée du livreur au commerce : le vendeur est prévenu. */
async function arrivedAtShop({db, messaging, uid, data}) {
  const o = await myCourse(db, uid, data.orderId);
  if (o.get("picked_up_at")) return {ok: true, already: true};
  if (!o.get("at_shop_at")) await o.ref.update({at_shop_at: ts()});
  const shop = o.get("seller_ref") ? await o.get("seller_ref").get() : null;
  if (shop && shop.exists) {
    await notifyUsers({db, messaging, users: [shop],
      title: "Le livreur est arrivé",
      body: `Remettez-lui la commande ${o.get("order_unique_reference") ||
        o.id}.`, kind: "order", data: {orderId: o.id}});
  }
  return {ok: true};
}

/** Contact d'urgence du livreur. */
async function setEmergencyContact({db, uid, data}) {
  const u = await deliverer(db, uid);
  const name = text(data.name, 60);
  const phone = text(data.phone, 20);
  if (!name || phone.replace(/\D/g, "").length < 8) {
    throw err("invalid-argument", "Nom et numéro du contact obligatoires.");
  }
  await u.ref.update({emergency_contact: {name, phone}});
  return {ok: true};
}

/**
 * Alerte de sécurité : enregistrée, puis tous les admins et agents du
 * support sont prévenus (avec la position si elle est fournie), et un
 * ticket urgent est ouvert. Le livreur n'est informé « envoyée » qu'après
 * cette réponse du serveur.
 */
async function safetyAlert({db, messaging, uid, data}) {
  const u = await deliverer(db, uid);
  const ok = (v, a) => typeof v === "number" && Number.isFinite(v) &&
    Math.abs(v) <= a;
  const position = ok(data.lat, 90) && ok(data.lng, 180) ?
    {lat: data.lat, lng: data.lng} : null;
  const kind = ["accident", "danger", "health", "other"].includes(data.kind) ?
    data.kind : "other";
  const labels = {accident: "Accident", danger: "Situation dangereuse",
    health: "Malaise / santé", other: "Urgence"};
  const ref = await db.collection("SafetyAlerts").add({uid,
    name: u.get("display_name") || "", phone: u.get("phone_number") || "",
    kind, note: text(data.note, 300), position,
    order_id: text(data.orderId, 128) || null,
    emergency_contact: u.get("emergency_contact") || null,
    status: "open", created_at: ts()});
  const where = position ?
    ` Position : https://maps.google.com/?q=${position.lat},${position.lng}` :
    "";
  await notifyUsers({db, messaging, users: await staffList(db),
    title: `ALERTE ${labels[kind].toUpperCase()} · ${u.get("display_name") ||
      "Livreur"}`,
    body: `${text(data.note, 200) || labels[kind]}. Tél. ` +
      `${u.get("phone_number") || "?"}.${where}`,
    kind: "safety", data: {alertId: ref.id}});
  await require("./support").createTicketFor({db, messaging, author: u,
    system: true, data: {category: "livraison", priority: "urgent",
      orderId: data.orderId || undefined,
      subject: `ALERTE : ${labels[kind]}`,
      message: `${labels[kind]} signalé par le livreur.` +
        `${data.note ? ` ${text(data.note, 300)}` : ""}${where}`}});
  await db.collection("audit_logs").add({actor_uid: uid,
    actor_role: "Deliver", action: "safety.alert", target: ref.path,
    details: {kind}, created_at: ts()});
  return {alertId: ref.id};
}

/** Mes propositions refusées ou expirées (onglet « Refusées »). */
async function myMissions({db, uid}) {
  await deliverer(db, uid);
  const snap = await db.collection("Missions")
      .where("deliverer_uid", "==", uid).get();
  const orders = {};
  for (const m of snap.docs) {
    const id = m.get("order_id");
    if (!(id in orders)) {
      const o = await db.doc(`Orders/${id}`).get();
      orders[id] = o.exists ? {reference: o.get("order_unique_reference") ||
        id, zone: o.get("delivery_zone") || "",
      fees: o.get("delivery_fees") || 0} : {reference: id};
    }
  }
  return {missions: snap.docs.map((m) => ({id: m.id,
    status: m.get("status"), orderId: m.get("order_id"),
    ...orders[m.get("order_id")], at: iso(m.get("created_at"))}))
      .sort((a, b) => String(b.at).localeCompare(String(a.at)))
      .slice(0, 100)};
}

module.exports = {DOC_TYPES, verificationOf, submitDocument, myDocuments,
  adminDocuments, adminReviewDocument, rateDelivery, myPerformance,
  requestWithdrawal, myWithdrawals, adminWithdrawals, adminDecideWithdrawal,
  reportDelay, arrivedAtShop, setEmergencyContact, safetyAlert, myMissions};
