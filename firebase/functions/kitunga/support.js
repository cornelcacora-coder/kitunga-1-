/**
 * Support client : tickets, espace des agents, escalade vers l'admin.
 *
 * Rôle « Support » (attribué par l'admin) : lit et traite les tickets, lit
 * les commandes et conversations liées (voir lifecycle / messaging), répond,
 * ajoute des notes internes, change statut et priorité, s'attribue un
 * ticket, escalade vers l'admin. Il ne peut PAS rembourser, suspendre un
 * compte, changer un tarif ni un paiement : ces actions restent à l'admin.
 *
 * Tickets/{id} et Tickets/{id}/messages (internal = note interne, jamais
 * montrée à l'auteur). Les incidents de livraison et les commandes
 * « non reçues » ouvrent un ticket automatiquement.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {notifyUsers} = require("./notifications");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const err = (code, message) => new AcquisitionError(code, message);
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};

const CATEGORIES = {
  commande: "Commande",
  livraison: "Livraison",
  paiement: "Paiement / remboursement",
  compte: "Compte / abonnement",
  produit: "Produit",
  autre: "Autre",
};
const STATUSES = ["open", "in_progress", "waiting_user", "escalated",
  "resolved"];
const PRIORITIES = ["normal", "high", "urgent"];
const STAFF = ["Admin", "Support"];

async function userOf(db, uid) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists) throw err("permission-denied", "Compte introuvable.");
  return u;
}

async function requireStaff(db, uid) {
  const u = await userOf(db, uid);
  if (!STAFF.includes(u.get("role"))) {
    throw err("permission-denied", "Réservé au support Kitunga.");
  }
  return u;
}

async function staffUsers(db, roles = STAFF) {
  const out = [];
  for (const r of roles) {
    out.push(...(await db.collection("User").where("role", "==", r).get())
        .docs);
  }
  return out;
}

async function nextNumber(db) {
  const ref = db.doc("receipt_counters/tickets");
  return db.runTransaction(async (tx) => {
    const c = await tx.get(ref);
    const n = (c.exists ? c.get("value") || 0 : 0) + 1;
    tx.set(ref, {value: n});
    return `T-${String(n).padStart(5, "0")}`;
  });
}

/** Crée un ticket (utilisateur, ou le système pour un incident). */
async function createTicketFor({db, messaging, author, data, system = false}) {
  const category = CATEGORIES[data.category] ? data.category : "autre";
  const subject = text(data.subject, 120) || CATEGORIES[category];
  const message = text(data.message, 3000);
  if (!message) throw err("invalid-argument", "Décrivez votre demande.");
  let orderId = null;
  let orderRef = "";
  if (data.orderId) {
    const o = await db.doc(`Orders/${text(data.orderId, 128)}`).get();
    if (!o.exists) throw err("not-found", "Commande introuvable.");
    const d = o.get("deliver_reference");
    const actors = [o.get("user_ref") && o.get("user_ref").id,
      o.get("seller_ref") && o.get("seller_ref").id,
      (d && d.id) || o.get("deliverer_ref")];
    if (!system && !actors.includes(author.id)) {
      throw err("not-found", "Commande introuvable.");
    }
    orderId = o.id;
    orderRef = o.get("order_unique_reference") || o.id;
  }
  const priority = PRIORITIES.includes(data.priority) ? data.priority :
    ["livraison", "paiement"].includes(category) && orderId ? "high" :
      "normal";
  const photos = (Array.isArray(data.photos) ? data.photos : [])
      .map((p) => text(p, 1000)).filter((p) => /^https:\/\//.test(p))
      .slice(0, 4);
  const number = await nextNumber(db);
  const ref = db.collection("Tickets").doc();
  const batch = db.batch();
  batch.set(ref, {number, author_uid: author.id,
    author_role: author.get("role") || "User",
    author_name: author.get("display_name") || "",
    author_phone: author.get("phone_number") || "",
    category, subject, status: "open", priority, order_id: orderId,
    order_ref: orderRef, assigned_to: null, assigned_name: "",
    source: system ? "system" : "app",
    last_message: message.slice(0, 140), unread_staff: true,
    unread_author: false, created_at: ts(), updated_at: ts()});
  batch.set(ref.collection("messages").doc(), {from_uid: author.id,
    from_role: system ? "system" : "author",
    from_name: author.get("display_name") || "", text: message, photos,
    internal: false, at: ts()});
  await batch.commit();
  await notifyUsers({db, messaging, users: await staffUsers(db, ["Support"]),
    title: `${priority === "urgent" ? "URGENT · " : ""}Ticket ${number}`,
    body: `${CATEGORIES[category]} · ${subject}`, kind: "support",
    data: {ticketId: ref.id}});
  return {ticketId: ref.id, number};
}

async function createTicket({db, messaging, uid, data}) {
  const u = await userOf(db, uid);
  if ((u.get("role") || "") === "Guest") {
    throw err("permission-denied", "Créez votre compte pour écrire au support.");
  }
  return createTicketFor({db, messaging, author: u, data});
}

const summary = (t) => ({id: t.id, number: t.get("number"),
  category: t.get("category"), categoryLabel: CATEGORIES[t.get("category")],
  subject: t.get("subject"), status: t.get("status"),
  priority: t.get("priority"), orderId: t.get("order_id"),
  orderRef: t.get("order_ref") || "", authorName: t.get("author_name") || "",
  authorRole: t.get("author_role") || "", authorUid: t.get("author_uid"),
  assignedTo: t.get("assigned_to") || null,
  assignedName: t.get("assigned_name") || "",
  lastMessage: t.get("last_message") || "",
  unread: t.get("unread_staff") === true,
  createdAt: iso(t.get("created_at")), updatedAt: iso(t.get("updated_at"))});

/** Mes demandes (auteur). */
async function myTickets({db, uid}) {
  await userOf(db, uid);
  const snap = await db.collection("Tickets")
      .where("author_uid", "==", uid).get();
  const list = snap.docs.map((t) => ({...summary(t),
    unread: t.get("unread_author") === true}))
      .sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
  return {tickets: list, categories: CATEGORIES};
}

async function ticketAccess(db, uid, ticketId) {
  const u = await userOf(db, uid);
  const t = await db.doc(`Tickets/${text(ticketId, 128) || "_"}`).get();
  if (!t.exists) throw err("not-found", "Demande introuvable.");
  const staff = STAFF.includes(u.get("role"));
  if (!staff && t.get("author_uid") !== uid) {
    throw err("not-found", "Demande introuvable.");
  }
  return {u, t, staff};
}

/** Fil d'un ticket : l'auteur ne voit jamais les notes internes. */
async function ticketThread({db, uid, data}) {
  const {t, staff} = await ticketAccess(db, uid, data.ticketId);
  const snap = await t.ref.collection("messages").orderBy("at", "asc").get();
  await t.ref.update(staff ? {unread_staff: false} : {unread_author: false});
  return {
    ticket: summary(t),
    messages: snap.docs.filter((m) => staff || m.get("internal") !== true)
        .map((m) => ({id: m.id, fromRole: m.get("from_role"),
          fromName: m.get("from_name") || "", text: m.get("text") || "",
          photos: m.get("photos") || [], internal: m.get("internal") === true,
          mine: m.get("from_uid") === uid, at: iso(m.get("at"))})),
  };
}

/** Réponse (auteur ou support) ou note interne (support). */
async function ticketReply({db, messaging, uid, data}) {
  const {u, t, staff} = await ticketAccess(db, uid, data.ticketId);
  const body = text(data.text, 3000);
  if (!body) throw err("invalid-argument", "Écrivez votre réponse.");
  const internal = data.internal === true;
  if (internal && !staff) {
    throw err("permission-denied", "Note interne réservée au support.");
  }
  const photos = (Array.isArray(data.photos) ? data.photos : [])
      .map((p) => text(p, 1000)).filter((p) => /^https:\/\//.test(p))
      .slice(0, 4);
  const batch = db.batch();
  batch.set(t.ref.collection("messages").doc(), {from_uid: uid,
    from_role: staff ? (u.get("role") === "Admin" ? "admin" : "support") :
      "author",
    from_name: staff ? "Support Kitunga" : u.get("display_name") || "",
    text: body, photos, internal, at: ts()});
  const update = {updated_at: ts()};
  if (!internal) {
    update.last_message = body.slice(0, 140);
    if (staff) {
      update.unread_author = true;
      if (["open", "in_progress"].includes(t.get("status"))) {
        update.status = "waiting_user";
      }
      if (!t.get("assigned_to")) {
        update.assigned_to = uid;
        update.assigned_name = u.get("display_name") || "";
      }
    } else {
      // L'auteur qui répond rouvre sa demande (même résolue).
      update.unread_staff = true;
      if (["waiting_user", "resolved"].includes(t.get("status"))) {
        update.status = "open";
      }
    }
  }
  batch.update(t.ref, update);
  await batch.commit();
  if (!internal) {
    const target = staff ?
      [await db.doc(`User/${t.get("author_uid")}`).get()] :
      t.get("assigned_to") ?
        [await db.doc(`User/${t.get("assigned_to")}`).get()] :
        await staffUsers(db, ["Support"]);
    await notifyUsers({db, messaging, users: target.filter((x) => x.exists),
      title: staff ? `Réponse du support · ${t.get("number")}` :
        `Nouveau message · ${t.get("number")}`,
      body: body.slice(0, 140), kind: "support",
      data: {ticketId: t.id}});
  }
  return {ok: true};
}

/** File des tickets (support et admin) avec compteurs. */
async function supportQueue({db, uid, data}) {
  await requireStaff(db, uid);
  const snap = await db.collection("Tickets").get();
  const all = snap.docs.map(summary);
  const counts = {open: 0, in_progress: 0, waiting_user: 0, escalated: 0,
    resolved: 0, urgent: 0, mine: 0};
  for (const t of all) {
    counts[t.status] = (counts[t.status] || 0) + 1;
    if (t.priority === "urgent" && t.status !== "resolved") counts.urgent++;
    if (t.assignedTo === uid && t.status !== "resolved") counts.mine++;
  }
  const f = text(data.filter, 20) || "active";
  const q = text(data.search, 80).toLowerCase();
  const list = all.filter((t) => {
    if (f === "active" && t.status === "resolved") return false;
    if (STATUSES.includes(f) && t.status !== f) return false;
    if (f === "urgent" && (t.priority !== "urgent" ||
      t.status === "resolved")) return false;
    if (f === "mine" && t.assignedTo !== uid) return false;
    if (!q) return true;
    return [t.number, t.subject, t.authorName, t.orderRef, t.lastMessage]
        .some((v) => String(v || "").toLowerCase().includes(q));
  }).sort((a, b) => {
    const p = {urgent: 0, high: 1, normal: 2};
    return (p[a.priority] - p[b.priority]) ||
      String(b.updatedAt).localeCompare(String(a.updatedAt));
  });
  return {tickets: list.slice(0, 300), counts, categories: CATEGORIES};
}

/** Statut, priorité, attribution, escalade (support et admin). */
async function ticketUpdate({db, messaging, uid, data}) {
  const me = await requireStaff(db, uid);
  const ref = db.doc(`Tickets/${text(data.ticketId, 128) || "_"}`);
  const t = await ref.get();
  if (!t.exists) throw err("not-found", "Demande introuvable.");
  const changes = {updated_at: ts()};
  const notes = [];
  if (data.status !== undefined) {
    if (!STATUSES.includes(data.status)) {
      throw err("invalid-argument", "Statut inconnu.");
    }
    changes.status = data.status;
    notes.push(`Statut : ${data.status}`);
  }
  if (data.priority !== undefined) {
    if (!PRIORITIES.includes(data.priority)) {
      throw err("invalid-argument", "Priorité inconnue.");
    }
    changes.priority = data.priority;
    notes.push(`Priorité : ${data.priority}`);
  }
  if (data.assign !== undefined) {
    const to = data.assign === "me" ? uid : text(data.assign, 128) || null;
    if (to) {
      const a = await db.doc(`User/${to}`).get();
      if (!a.exists || !STAFF.includes(a.get("role"))) {
        throw err("invalid-argument", "Agent inconnu.");
      }
      changes.assigned_to = to;
      changes.assigned_name = a.get("display_name") || "";
      if (t.get("status") === "open") changes.status = "in_progress";
      notes.push(`Attribué à ${changes.assigned_name || to}`);
    } else {
      changes.assigned_to = null;
      changes.assigned_name = "";
      notes.push("Attribution retirée");
    }
  }
  if (data.escalate === true) {
    changes.status = "escalated";
    changes.escalated_at = ts();
    changes.escalation_note = text(data.note, 500);
    notes.push(`Escaladé à l'admin${data.note ? ` : ${text(data.note, 500)}`
      : ""}`);
  }
  if (notes.length === 0) {
    throw err("invalid-argument", "Aucune modification.");
  }
  await ref.update(changes);
  await ref.collection("messages").add({from_uid: uid, from_role: "system",
    from_name: me.get("display_name") || "", text: notes.join(" · "),
    internal: true, at: ts()});
  await db.collection("audit_logs").add({actor_uid: uid,
    actor_role: me.get("role"), action: "ticket.update", target: ref.path,
    details: {notes}, created_at: ts()});
  if (data.escalate === true) {
    await notifyUsers({db, messaging, users: await staffUsers(db, ["Admin"]),
      title: `Escalade · ticket ${t.get("number")}`,
      body: `${t.get("subject")}${data.note ? ` — ${text(data.note, 200)}` :
        ""}`, kind: "support", data: {ticketId: t.id}});
  }
  if (changes.status === "resolved") {
    const a = await db.doc(`User/${t.get("author_uid")}`).get();
    if (a.exists) {
      await notifyUsers({db, messaging, users: [a],
        title: `Demande ${t.get("number")} résolue`,
        body: "Répondez si le problème persiste : la demande sera rouverte.",
        kind: "support", data: {ticketId: t.id}});
    }
  }
  return {ok: true};
}

/**
 * Recherche d'un utilisateur (support) : profil, ses tickets, ses
 * dernières commandes. Lecture seule.
 */
async function supportUserLookup({db, uid, data}) {
  await requireStaff(db, uid);
  const q = text(data.query, 80).toLowerCase();
  if (q.length < 2) throw err("invalid-argument", "Saisissez au moins 2 lettres.");
  const users = (await db.collection("User").limit(5000).get()).docs
      .filter((u) => [u.get("display_name"), u.get("email"),
        u.get("phone_number")].some((v) =>
        String(v || "").toLowerCase().includes(q))).slice(0, 10);
  const out = [];
  for (const u of users) {
    const role = u.get("role") || "User";
    const field = role === "Seller" ? "seller_ref" : role === "Deliver" ?
      null : "user_ref";
    const orders = field ? await db.collection("Orders")
        .where(field, "==", u.ref).get() :
      await db.collection("Orders").where("deliverer_ref", "==", u.id).get();
    const tickets = await db.collection("Tickets")
        .where("author_uid", "==", u.id).get();
    out.push({uid: u.id, name: u.get("display_name") || "",
      role, phone: u.get("phone_number") || "", email: u.get("email") || "",
      accountStatus: u.get("account_status") || "active",
      tickets: tickets.size,
      orders: orders.docs.map((o) => ({id: o.id,
        reference: o.get("order_unique_reference") || o.id,
        status: o.get("status") || "",
        total: o.get("total_amount") || 0,
        createdAt: iso(o.get("created_at"))}))
          .sort((a, b) => String(b.createdAt).localeCompare(
              String(a.createdAt))).slice(0, 8)});
  }
  return {users: out};
}

/** L'admin donne ou retire le rôle Support à un compte. */
async function adminSetSupport({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const email = text(data.email, 200).toLowerCase();
  let u = null;
  if (data.uid) u = await db.doc(`User/${text(data.uid, 128)}`).get();
  else if (email) {
    const s = await db.collection("User").where("email", "==", email)
        .limit(1).get();
    u = s.docs[0] || null;
  }
  if (!u || !u.exists) throw err("not-found", "Compte introuvable.");
  const role = u.get("role") || "User";
  if (["Admin", "Seller", "Deliver"].includes(role)) {
    throw err("failed-precondition",
        "Ce compte est déjà admin, vendeur ou livreur : utilisez un compte " +
        "dédié au support.");
  }
  const enable = data.enabled !== false;
  await u.ref.update({role: enable ? "Support" : "User"});
  await db.collection("audit_logs").add({actor_uid: adminUid,
    actor_role: "Admin", action: enable ? "support.grant" : "support.revoke",
    target: u.ref.path, details: {from: role}, created_at: ts()});
  return {uid: u.id, role: enable ? "Support" : "User"};
}

/** Agents (pour l'attribution) : support et admins. */
async function supportAgents({db, uid}) {
  await requireStaff(db, uid);
  return {agents: (await staffUsers(db)).map((u) => ({uid: u.id,
    name: u.get("display_name") || u.get("email") || u.id,
    role: u.get("role")}))};
}

module.exports = {CATEGORIES, STATUSES, PRIORITIES, createTicket,
  createTicketFor, myTickets, ticketThread, ticketReply, supportQueue,
  ticketUpdate, supportUserLookup, adminSetSupport, supportAgents};
