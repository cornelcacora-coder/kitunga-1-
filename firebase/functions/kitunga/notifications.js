/**
 * Notifications des utilisateurs.
 *
 * - Centre de notifications (collection Notifications, écrite et lue par le
 *   serveur seul) : visible dans l'application, même sans notification push.
 * - Notification push (Firebase Cloud Messaging) sur les téléphones dont
 *   l'application a enregistré son jeton (User.fcm_tokens).
 * - Rappels d'abonnement automatiques : 7 jours avant la fin, la veille, et
 *   le jour de l'expiration (une seule fois chacun).
 * - Rappels envoyés par l'admin à un client ou à un groupe.
 *
 * `messaging` est injecté (admin.messaging() en production, simulé en test).
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");

const NOTIFICATIONS = "Notifications";
const DAY = 24 * 60 * 60 * 1000;
const MAX_TOKENS = 5;
const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const err = (code, message) => new AcquisitionError(code, message);
const fmtDay = (d) => d.toLocaleDateString("fr-FR",
    {day: "numeric", month: "long", year: "numeric", timeZone: "Africa/Brazzaville"});

/**
 * Envoie une notification à des utilisateurs (documents User) : centre de
 * notifications + push. Les jetons refusés par FCM sont retirés.
 */
async function notifyUsers({db, messaging, users, title, body, kind,
  data = {}}) {
  let pushed = 0;
  for (const u of users) {
    await db.collection(NOTIFICATIONS).add({user_uid: u.id, title, body,
      kind, data, read: false, created_at: ts()});
    const tokens = (u.get("fcm_tokens") || []).filter((t) =>
      typeof t === "string" && t);
    if (!messaging || tokens.length === 0) continue;
    try {
      const res = await messaging.sendEachForMulticast({tokens,
        notification: {title, body},
        data: {kind, ...Object.fromEntries(Object.entries(data)
            .map(([k, v]) => [k, String(v)]))},
        android: {priority: "high"}});
      pushed += res.successCount || 0;
      const dead = (res.responses || []).map((r, i) => (!r.success &&
        r.error && /registration-token-not-registered|invalid-argument/
            .test(r.error.code || "")) ? tokens[i] : null).filter(Boolean);
      if (dead.length) {
        await u.ref.update({fcm_tokens:
          admin.firestore.FieldValue.arrayRemove(...dead)});
      }
    } catch (e) {
      console.error(`Push ${u.id}`, e);
    }
  }
  return {sent: users.length, pushed};
}

/** L'application enregistre le jeton push du téléphone. */
async function saveFcmToken({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const token = text(data.token, 4096);
  if (!token) throw err("invalid-argument", "Jeton manquant.");
  const ref = db.doc(`User/${uid}`);
  await db.runTransaction(async (tx) => {
    const u = await tx.get(ref);
    if (!u.exists) throw err("not-found", "Compte introuvable.");
    const list = (u.get("fcm_tokens") || []).filter((t) => t !== token);
    tx.update(ref, {fcm_tokens: [...list, token].slice(-MAX_TOKENS)});
  });
  return {ok: true};
}

async function myNotifications({db, uid}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const snap = await db.collection(NOTIFICATIONS)
      .where("user_uid", "==", uid).get();
  const list = snap.docs.map((d) => {
    const n = d.data();
    const at = toDate(n.created_at);
    return {id: d.id, title: n.title || "", body: n.body || "",
      kind: n.kind || "", read: n.read === true,
      createdAt: at ? at.toISOString() : null};
  }).sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
      .slice(0, 50);
  return {notifications: list, unread: list.filter((n) => !n.read).length};
}

async function markNotificationsRead({db, uid}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const snap = await db.collection(NOTIFICATIONS)
      .where("user_uid", "==", uid).where("read", "==", false).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.update(d.ref, {read: true}));
  await batch.commit();
  return {ok: true, count: snap.size};
}

// ── Abonnement : état d'un client ───────────────────────────────────────

/** active, expiring (7 jours ou moins), expired, never. */
function subscriptionState(u, now = new Date()) {
  const until = toDate(u.get ? u.get("subscribe_close_at") :
    u.subscribe_close_at);
  if (!until) return "never";
  if (until <= now) return "expired";
  return until - now <= 7 * DAY ? "expiring" : "active";
}

const REMINDERS = {
  "7d": (d) => ({title: "Votre abonnement se termine bientôt",
    body: `Votre abonnement Kitunga se termine le ${d}. Renouvelez-le dans ` +
      "Profil › Mon abonnement pour continuer à commander."}),
  "1d": (d) => ({title: "Votre abonnement se termine demain",
    body: `Votre abonnement Kitunga se termine le ${d}. Renouvelez-le dès ` +
      "maintenant dans Profil › Mon abonnement."}),
  "expired": () => ({title: "Votre abonnement est terminé",
    body: "Vous ne pouvez plus commander. Renouvelez votre abonnement " +
      "(300 F pour 6 mois ou 1000 F pour un an) dans Profil › Mon abonnement."}),
};

/**
 * Rappels automatiques (chaque matin) : 7 jours avant la fin, la veille,
 * le jour de l'expiration. Chaque rappel n'est envoyé qu'une fois pour une
 * même date de fin (User.subscription_reminders).
 */
async function subscriptionReminders({db, messaging, now = new Date()}) {
  const snap = await db.collection("User")
      .where("subscribe_close_at", ">=", new Date(now.getTime() - DAY))
      .where("subscribe_close_at", "<=", new Date(now.getTime() + 8 * DAY))
      .get();
  let count = 0;
  for (const u of snap.docs) {
    if ((u.get("role") || "User") !== "User") continue;
    if (u.get("account_status") === "suspended") continue;
    const until = toDate(u.get("subscribe_close_at"));
    const left = (until - now) / DAY;
    const stage = until <= now ? "expired" :
      left <= 1 ? "1d" : left <= 7 && left > 6 ? "7d" : null;
    if (!stage) continue;
    const key = until.toISOString();
    const sent = u.get("subscription_reminders") || {};
    if (sent[stage] === key) continue;
    const msg = REMINDERS[stage](fmtDay(until));
    await notifyUsers({db, messaging, users: [u], ...msg,
      kind: "subscription", data: {stage}});
    await u.ref.update({[`subscription_reminders.${stage}`]: key});
    count++;
  }
  return {count};
}

/** Clients d'un groupe (abonnés, expire bientôt, expirés, jamais abonnés). */
async function clientsOf(db, segment, now) {
  const snap = await db.collection("User").where("role", "==", "User")
      .limit(5000).get();
  return snap.docs.filter((u) => u.get("account_status") !== "suspended" &&
    (segment === "all" || subscriptionState(u, now) === segment));
}

const DEFAULT_MESSAGES = {
  active: {title: "Merci d'être abonné à Kitunga",
    body: "Profitez de vos commandes livrées partout à Brazzaville."},
  expiring: {title: "Votre abonnement se termine bientôt",
    body: "Renouvelez-le dans Profil › Mon abonnement pour continuer à " +
      "commander."},
  expired: REMINDERS.expired(),
  never: {title: "Abonnez-vous à Kitunga",
    body: "Pour commander : 300 F pour 6 mois ou 1000 F pour un an, dans " +
      "Profil › Mon abonnement."},
  all: {title: "Kitunga", body: ""},
};

/**
 * L'admin envoie un rappel : à des clients choisis (uids) ou à un groupe
 * (segment). Message par défaut selon le groupe, modifiable.
 */
async function adminSendReminder({db, messaging, uid, data, now = new Date()}) {
  const adminUid = await requireAdmin(db, uid);
  const segment = ["active", "expiring", "expired", "never", "all"]
      .includes(data.segment) ? data.segment : null;
  let users;
  if (Array.isArray(data.uids) && data.uids.length > 0) {
    const ids = [...new Set(data.uids.map((i) => text(i, 128)))].slice(0, 500);
    users = (await Promise.all(ids.map((i) => db.doc(`User/${i}`).get())))
        .filter((u) => u.exists && (u.get("role") || "User") === "User");
  } else if (segment) {
    users = await clientsOf(db, segment, now);
  } else {
    throw err("invalid-argument", "Choisissez les clients à prévenir.");
  }
  const base = DEFAULT_MESSAGES[segment || "expiring"];
  const title = text(data.title, 80) || base.title;
  const body = text(data.body, 400) || base.body;
  if (!body) throw err("invalid-argument", "Écrivez le message.");
  const res = await notifyUsers({db, messaging, users, title, body,
    kind: "admin"});
  await db.collection("audit_logs").add({actor_uid: adminUid,
    actor_role: "Admin", action: "notification.send",
    target: segment ? `segment:${segment}` : "User",
    details: {count: users.length, title}, created_at: ts()});
  return res;
}

module.exports = {notifyUsers, saveFcmToken, myNotifications,
  markNotificationsRead, subscriptionReminders, adminSendReminder,
  subscriptionState};
