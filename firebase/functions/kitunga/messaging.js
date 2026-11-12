/**
 * Messagerie entre les acteurs d'une commande, et annonces de l'admin.
 *
 * Conversations/{id} : participants (uids), rôles, commande liée, dernier
 * message, non-lus par participant. Messages : Conversations/{id}/messages.
 * Tout passe par le serveur : il vérifie que l'auteur participe (ou est
 * admin / support), écrit le message, met à jour les non-lus et prévient
 * les autres participants (notification push).
 *
 * Conversations d'une commande : client ↔ commerce, client ↔ livreur,
 * commerce ↔ livreur. Ouvertes pendant la commande et 48 h après la fin,
 * puis consultables en lecture seule.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {notifyUsers} = require("./notifications");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const inc = (n) => admin.firestore.FieldValue.increment(n);
const err = (code, message) => new AcquisitionError(code, message);
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};
const OPEN_AFTER_END_MS = 48 * 3600 * 1000;
const FINISHED = ["Livrer", "Reçu", "Non Reçu", "Refusée", "Annulée"];
const STAFF = ["Admin", "Support"];
const ROLE_OF = {client: "User", commerce: "Seller", livreur: "Deliver"};

async function me(db, uid) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists) throw err("permission-denied", "Compte introuvable.");
  return u;
}

/** Acteurs d'une commande : {client, commerce, livreur} → uid. */
function actorsOf(o) {
  const d = o.get("deliver_reference");
  return {
    client: o.get("user_ref") && o.get("user_ref").id,
    commerce: o.get("seller_ref") && o.get("seller_ref").id,
    livreur: (d && d.id) || o.get("deliverer_ref") || null,
  };
}

/** Conversation encore ouverte à l'écriture ? */
function writable(o) {
  if (!FINISHED.includes(o.get("status"))) return true;
  const end = toDate(o.get("delivered_at")) || toDate(o.get("status_updated_at"))
    || toDate(o.get("created_at"));
  return !end || Date.now() - end.getTime() <= OPEN_AFTER_END_MS;
}

/**
 * Ouvre (ou retrouve) la conversation avec un autre acteur de la commande.
 * data : {orderId, with: 'client' | 'commerce' | 'livreur'}.
 */
async function openOrderChat({db, uid, data}) {
  await me(db, uid);
  const o = await db.doc(`Orders/${String(data.orderId || "_")
      .slice(0, 128)}`).get();
  if (!o.exists) throw err("not-found", "Commande introuvable.");
  const actors = actorsOf(o);
  const mine = Object.keys(actors).find((k) => actors[k] === uid);
  if (!mine) throw err("not-found", "Commande introuvable.");
  const other = String(data.with || "");
  if (!ROLE_OF[other] || other === mine) {
    throw err("invalid-argument", "Interlocuteur invalide.");
  }
  if (!actors[other]) {
    throw err("failed-precondition", other === "livreur" ?
      "Aucun livreur n'est encore attribué à cette commande." :
      "Interlocuteur indisponible.");
  }
  const pair = [mine, other].sort().join("-");
  const ref = db.doc(`Conversations/order_${o.id}_${pair}`);
  const ref2 = o.get("order_unique_reference") || o.id;
  await db.runTransaction(async (tx) => {
    const c = await tx.get(ref);
    if (c.exists) return;
    tx.set(ref, {kind: "order", order_id: o.id,
      title: `Commande ${ref2}`,
      participants: [actors[mine], actors[other]],
      roles: {[actors[mine]]: mine, [actors[other]]: other},
      unread: {[actors[mine]]: 0, [actors[other]]: 0},
      last_message: "", last_at: ts(), created_at: ts()});
  });
  return {conversationId: ref.id};
}

/** Droit de lire une conversation : participant, admin ou support. */
async function access(db, uid, conversationId) {
  const u = await me(db, uid);
  const c = await db.doc(`Conversations/${String(conversationId || "_")
      .slice(0, 160)}`).get();
  if (!c.exists) throw err("not-found", "Conversation introuvable.");
  const participant = (c.get("participants") || []).includes(uid);
  const staff = STAFF.includes(u.get("role"));
  if (!participant && !staff) {
    throw err("not-found", "Conversation introuvable.");
  }
  return {u, c, participant, staff};
}

/** Envoie un message. */
async function sendMessage({db, messaging, uid, data}) {
  const {u, c, participant, staff} = await access(db, uid,
      data.conversationId);
  const body = typeof data.text === "string" ? data.text.trim() : "";
  if (!body) throw err("invalid-argument", "Écrivez votre message.");
  if (body.length > 2000) throw err("invalid-argument", "Message trop long.");
  if (c.get("kind") === "order") {
    const o = await db.doc(`Orders/${c.get("order_id")}`).get();
    if (o.exists && !writable(o) && !staff) {
      throw err("failed-precondition",
          "Cette commande est terminée : la conversation est fermée.");
    }
  }
  if (c.get("kind") === "announcement" && !staff) {
    throw err("permission-denied", "Les annonces sont en lecture seule.");
  }
  const role = (c.get("roles") || {})[uid] ||
    (staff ? (u.get("role") === "Admin" ? "admin" : "support") : "");
  const others = (c.get("participants") || []).filter((p) => p !== uid);
  const batch = db.batch();
  batch.set(c.ref.collection("messages").doc(), {from_uid: uid,
    from_role: role, from_name: u.get("display_name") || "", text: body,
    at: ts()});
  const update = {last_message: body.slice(0, 140), last_at: ts()};
  for (const p of others) update[`unread.${p}`] = inc(1);
  if (participant) update[`unread.${uid}`] = 0;
  // Message direct : la réponse de l'utilisateur arrive à toute l'équipe.
  const direct = c.get("kind") === "direct";
  if (direct && !staff) update.unread_staff = inc(1);
  if (direct && staff) update.unread_staff = 0;
  batch.update(c.ref, update);
  await batch.commit();
  const users = (await Promise.all(others.map((p) => db.doc(`User/${p}`)
      .get()))).filter((x) => x.exists);
  if (direct && !staff) users.push(...await staffMembers(db));
  if (users.length) {
    await notifyUsers({db, messaging, users,
      title: direct && staff ? "Message de l'équipe Kitunga" :
        direct ? `Message de ${u.get("display_name") || "un utilisateur"}` :
        `${u.get("display_name") || "Nouveau message"} · ` +
        `${c.get("title") || "Kitunga"}`,
      body: body.slice(0, 140), kind: "message",
      data: {conversationId: c.id}});
  }
  return {ok: true};
}

/** Messages d'une conversation (marque comme lus pour le participant). */
async function conversationMessages({db, uid, data}) {
  const {c, participant} = await access(db, uid, data.conversationId);
  const snap = await c.ref.collection("messages").orderBy("at", "asc")
      .limitToLast(200).get();
  // Lecture : non-lus remis à zéro et heure de lecture (accusé « Lu »).
  const direct = c.get("kind") === "direct";
  if (participant) {
    await c.ref.update({[`unread.${uid}`]: 0, [`read_at.${uid}`]: ts()});
  } else if (direct) {
    await c.ref.update({unread_staff: 0, staff_read_at: ts()});
  }
  const readAt = c.get("read_at") || {};
  const others = (c.get("participants") || []).filter((p) => p !== uid);
  const seen = [...others.map((p) => toDate(readAt[p])),
    ...(direct && participant ? [toDate(c.get("staff_read_at"))] : [])]
      .filter(Boolean).sort((x, y) => y - x)[0] || null;
  let open = true;
  if (c.get("kind") === "order") {
    const o = await db.doc(`Orders/${c.get("order_id")}`).get();
    open = !o.exists || writable(o);
  } else if (c.get("kind") === "announcement") {
    open = false;
  }
  return {
    title: c.get("title") || "",
    open,
    otherReadAt: seen ? seen.toISOString() : null,
    messages: snap.docs.map((m) => ({id: m.id, mine: m.get("from_uid") === uid,
      fromRole: m.get("from_role") || "", fromName: m.get("from_name") || "",
      text: m.get("text") || "", at: iso(m.get("at"))})),
  };
}

/** Mes conversations, la plus récente d'abord, avec les non-lus. */
async function myConversations({db, uid}) {
  await me(db, uid);
  const snap = await db.collection("Conversations")
      .where("participants", "array-contains", uid).get();
  const list = snap.docs.map((c) => ({id: c.id, kind: c.get("kind"),
    title: c.get("title") || "", orderId: c.get("order_id") || null,
    withRole: c.get("kind") === "direct" ? "kitunga" :
      Object.entries(c.get("roles") || {})
          .filter(([k]) => k !== uid).map(([, v]) => v)[0] || "",
    lastMessage: c.get("last_message") || "", lastAt: iso(c.get("last_at")),
    unread: (c.get("unread") || {})[uid] || 0}))
      .sort((a, b) => String(b.lastAt).localeCompare(String(a.lastAt)));
  return {conversations: list.slice(0, 100),
    unread: list.reduce((s, c) => s + c.unread, 0)};
}

/** Admins et agents du support (boîte partagée de l'équipe). */
async function staffMembers(db) {
  const out = [];
  for (const r of STAFF) {
    out.push(...(await db.collection("User").where("role", "==", r).get())
        .docs);
  }
  return out;
}

async function requireStaff(db, uid) {
  const u = await me(db, uid);
  if (!STAFF.includes(u.get("role"))) {
    throw err("permission-denied", "Réservé à l'équipe Kitunga.");
  }
  return u;
}

const ROLE_KEY = {User: "client", Seller: "commerce", Deliver: "livreur"};

/**
 * L'équipe (admin ou support) ouvre la conversation directe avec un
 * client, un commerce ou un livreur. Une conversation par personne,
 * partagée par toute l'équipe ; la personne peut répondre.
 */
async function staffOpenDirect({db, uid, data}) {
  await requireStaff(db, uid);
  const t = await db.doc(`User/${String(data.uid || "_").slice(0, 128)}`)
      .get();
  if (!t.exists || !ROLE_KEY[t.get("role") || "User"]) {
    throw err("not-found", "Compte introuvable.");
  }
  const ref = db.doc(`Conversations/direct_${t.id}`);
  await db.runTransaction(async (tx) => {
    const c = await tx.get(ref);
    const fields = {target_uid: t.id,
      target_name: t.get("display_name") || t.get("email") || t.id,
      target_role: t.get("role") || "User"};
    if (c.exists) {
      tx.update(ref, fields);
      return;
    }
    tx.set(ref, {kind: "direct", title: "Équipe Kitunga",
      participants: [t.id],
      roles: {[t.id]: ROLE_KEY[t.get("role") || "User"]},
      unread: {[t.id]: 0}, unread_staff: 0, last_message: "",
      last_at: ts(), created_at: ts(), ...fields});
  });
  return {conversationId: ref.id,
    title: `${t.get("display_name") || t.id} · ` +
      `${{client: "Client", commerce: "Commerce", livreur: "Livreur"}[
          ROLE_KEY[t.get("role") || "User"]]}`};
}

/** Boîte de l'équipe : conversations directes, non-lus d'abord. */
async function staffInbox({db, uid}) {
  await requireStaff(db, uid);
  const snap = await db.collection("Conversations")
      .where("kind", "==", "direct").get();
  const list = snap.docs.map((c) => ({id: c.id,
    targetUid: c.get("target_uid"), targetName: c.get("target_name") || "",
    targetRole: c.get("target_role") || "",
    lastMessage: c.get("last_message") || "", lastAt: iso(c.get("last_at")),
    unread: c.get("unread_staff") || 0}))
      .filter((c) => c.lastMessage)
      .sort((a, b) => (b.unread > 0) - (a.unread > 0) ||
        String(b.lastAt).localeCompare(String(a.lastAt)));
  return {conversations: list.slice(0, 200),
    unread: list.reduce((s, c) => s + c.unread, 0)};
}

/** Conversations d'une commande (litige) : équipe Kitunga seulement. */
async function orderConversations({db, uid, data}) {
  await requireStaff(db, uid);
  const snap = await db.collection("Conversations")
      .where("order_id", "==", String(data.orderId || "_").slice(0, 128))
      .get();
  const label = {client: "Client", commerce: "Commerce", livreur: "Livreur"};
  return {conversations: snap.docs.map((c) => ({id: c.id,
    between: Object.values(c.get("roles") || {}).map((r) => label[r] || r)
        .sort().join(" ↔ "),
    lastMessage: c.get("last_message") || "",
    lastAt: iso(c.get("last_at"))}))
      .sort((a, b) => String(b.lastAt).localeCompare(String(a.lastAt)))};
}

const AUDIENCES = {
  sellers: ["Seller"], deliverers: ["Deliver"], clients: ["User"],
  partners: ["Seller", "Deliver"], all: ["User", "Seller", "Deliver"],
};

/**
 * Annonce de l'admin à un groupe : notification à chacun, et une
 * conversation « Annonces Kitunga » (lecture seule) par destinataire.
 */
async function adminAnnounce({db, messaging, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const roles = AUDIENCES[data.audience];
  if (!roles) throw err("invalid-argument", "Destinataires inconnus.");
  const title = String(data.title || "").trim().slice(0, 80);
  const body = String(data.body || "").trim().slice(0, 1000);
  if (!title || !body) {
    throw err("invalid-argument", "Titre et message obligatoires.");
  }
  const users = [];
  for (const r of roles) {
    const s = await db.collection("User").where("role", "==", r)
        .limit(5000).get();
    users.push(...s.docs.filter((u) => u.get("account_status") !==
      "suspended"));
  }
  for (const u of users) {
    const ref = db.doc(`Conversations/announce_${u.id}`);
    await ref.set({kind: "announcement", title: "Annonces Kitunga",
      participants: [u.id], roles: {[u.id]: "destinataire"},
      last_message: `${title} — ${body}`.slice(0, 140), last_at: ts(),
      unread: {[u.id]: inc(1)}}, {merge: true});
    await ref.collection("messages").add({from_uid: adminUid,
      from_role: "admin", from_name: "Kitunga",
      text: `${title}\n\n${body}`, at: ts()});
  }
  await notifyUsers({db, messaging, users, title, body, kind: "announcement"});
  await db.collection("audit_logs").add({actor_uid: adminUid,
    actor_role: "Admin", action: "announcement.send",
    target: `audience:${data.audience}`,
    details: {count: users.length, title}, created_at: ts()});
  return {sent: users.length};
}

module.exports = {openOrderChat, sendMessage, conversationMessages,
  myConversations, adminAnnounce, writable, AUDIENCES, staffOpenDirect,
  staffInbox, orderConversations};
