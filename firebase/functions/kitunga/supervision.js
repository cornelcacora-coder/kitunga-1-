/**
 * Supervision de l'admin : vue d'ensemble des cinq acteurs, des commandes,
 * des livraisons, des incidents, du support et des finances ; état et
 * historique de disponibilité des livreurs.
 */
const {toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");

const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};
const POSITION_FRESH_MS = 10 * 60 * 1000;

async function adminSupervision({db, uid, now = new Date()}) {
  await requireAdmin(db, uid);
  const [users, orders, tickets, ledger] = await Promise.all([
    db.collection("User").get(),
    db.collection("Orders").get(),
    db.collection("Tickets").get(),
    db.collection("Ledger").get(),
  ]);
  const roles = {User: 0, Seller: 0, Deliver: 0, Support: 0, Admin: 0};
  const deliverers = [];
  for (const u of users.docs) {
    const r = u.get("role") || "User";
    if (r in roles) roles[r]++;
    if (r === "Deliver") deliverers.push(u);
  }
  // Journée à Brazzaville (UTC+1).
  const day = (d) => new Date(d.getTime() + 3600000).toISOString().slice(0, 10);
  const today = day(now);
  const o = {pending: 0, preparing: 0, ready: 0, delivering: 0,
    deliveredToday: 0, delivered: 0, disputed: 0, failed: 0,
    cancelledToday: 0, incidents: 0, unassignedReady: 0};
  const active = {};
  const doneToday = {};
  const incidents = [];
  for (const d of orders.docs) {
    const s = d.get("status") || "";
    const created = toDate(d.get("created_at"));
    const delivered = toDate(d.get("delivered_at"));
    const deliverer = (d.get("deliver_reference") &&
      d.get("deliver_reference").id) || d.get("deliverer_ref") || "";
    if (s === "En attente" || s === "") o.pending++;
    else if (s === "En préparation") o.preparing++;
    else if (s === "Pret") {
      o.ready++;
      if (!deliverer) o.unassignedReady++;
    } else if (s === "encours") {
      o.delivering++;
      if (deliverer) active[deliverer] = (active[deliverer] || 0) + 1;
    } else if (s === "Livrer" || s === "Reçu") {
      o.delivered++;
      if (delivered && day(delivered) === today) {
        o.deliveredToday++;
        if (deliverer) doneToday[deliverer] = (doneToday[deliverer] || 0) + 1;
      }
    } else if (s === "Non Reçu") o.disputed++;
    else if (["Refusée", "Annulée"].includes(s) && created &&
      day(created) === today) o.cancelledToday++;
    if (d.get("delivery_status") === "failed") o.failed++;
    const issue = d.get("delivery_issue");
    if (issue && s === "encours") {
      o.incidents++;
      incidents.push({orderId: d.id,
        reference: d.get("order_unique_reference") || d.id,
        label: issue.label || issue.type || "Problème",
        note: issue.note || "", zone: d.get("delivery_zone") || ""});
    }
  }
  const t = {open: 0, urgent: 0, escalated: 0, resolved: 0};
  for (const k of tickets.docs) {
    const st = k.get("status");
    if (st === "resolved") t.resolved++;
    else {
      t.open++;
      if (k.get("priority") === "urgent") t.urgent++;
      if (st === "escalated") t.escalated++;
    }
  }
  let owed = 0;
  let kitunga = 0;
  for (const e of ledger.docs) {
    const a = Number(e.get("amount")) || 0;
    if (e.get("account_uid") === "kitunga") kitunga += a;
    else owed += a;
  }
  const list = deliverers.map((u) => {
    const pos = u.get("last_position");
    const at = pos && toDate(pos.at);
    const state = u.get("delivery_state") ||
      (u.get("delivery_available") === true ? "on" : "off");
    return {uid: u.id, name: u.get("display_name") || u.id,
      phone: u.get("phone_number") || "", state,
      suspended: u.get("account_status") === "suspended",
      verified: u.get("verified") === true,
      vehicle: u.get("vehicle") || "moto",
      zones: u.get("delivery_zones") || [],
      active: active[u.id] || 0, deliveredToday: doneToday[u.id] || 0,
      positionAt: at ? at.toISOString() : null,
      positionFresh: !!at && now - at <= POSITION_FRESH_MS,
      stateSince: iso(u.get("delivery_available_at"))};
  }).sort((a, b) => ({on: 0, pause: 1, off: 2}[a.state] -
    {on: 0, pause: 1, off: 2}[b.state]) || b.active - a.active);
  const states = {on: 0, pause: 0, off: 0};
  for (const d of list) states[d.state] = (states[d.state] || 0) + 1;
  return {actors: roles, orders: o, deliverers: list, delivererStates: states,
    incidents: incidents.slice(0, 50), tickets: t,
    finance: {owed, kitunga}};
}

/** Historique de disponibilité d'un livreur (admin). */
async function adminDelivererHistory({db, uid, data}) {
  await requireAdmin(db, uid);
  const id = String(data.uid || "_").slice(0, 128);
  const [log, missions] = await Promise.all([
    db.collection("DelivererAvailability")
        .where("deliverer_uid", "==", id).get(),
    db.collection("Missions").where("deliverer_uid", "==", id).get(),
  ]);
  const m = {offered: 0, accepted: 0, declined: 0, expired: 0, cancelled: 0};
  for (const d of missions.docs) m[d.get("status")] = (m[d.get("status")] ||
    0) + 1;
  const answered = m.accepted + m.declined + m.expired;
  return {
    history: log.docs.map((d) => ({state: d.get("state"),
      from: d.get("from") || "", at: iso(d.get("at"))}))
        .sort((a, b) => String(b.at).localeCompare(String(a.at)))
        .slice(0, 100),
    missions: {...m, acceptanceRate: answered ?
      Math.round(m.accepted * 100 / answered) : null},
  };
}

module.exports = {adminSupervision, adminDelivererHistory};
