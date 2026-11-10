/**
 * Opérations d'administration : remboursements à traiter, abonnements
 * offerts ou prolongés, suspension des comptes. Réservé à l'admin ; chaque
 * action est journalisée (audit_logs).
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {audit} = require("./acquisition/store");
const {normalizePhone} = require("./momo");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};
const DAY = 24 * 60 * 60 * 1000;

function accountSummary(doc) {
  const u = doc.data() || {};
  return {
    uid: doc.id,
    displayName: u.display_name || "",
    email: u.email || "",
    phone: u.phone_number || "",
    role: u.role || "User",
    subscribeCloseAt: iso(u.subscribe_close_at),
    accountStatus: u.account_status || "active",
    accountStatusReason: u.account_status_reason || null,
  };
}

// ── Remboursements ───────────────────────────────────────────────────────

/** Commandes à rembourser (refund_needed) pas encore remboursées. */
async function listRefunds({db}) {
  const snap = await db.collection("Orders")
      .where("refund_needed", "==", true).limit(300).get();
  const pending = snap.docs.filter((d) => d.get("refund_status") !== "Envoyé");
  const users = await Promise.all(pending.map((d) => {
    const ref = d.get("user_ref");
    return ref && ref.get ? ref.get() : Promise.resolve(null);
  }));
  const list = pending.map((d, i) => {
    const o = d.data();
    const u = users[i] && users[i].exists ? users[i].data() : {};
    return {
      orderId: d.id,
      reference: o.order_unique_reference || o.order_id || d.id,
      // Retour accepté : articles seulement (sans la livraison).
      amount: o.refund_amount ?? o.total_amount ?? 0,
      reason: o.refund_reason || "",
      deliveryFees: o.delivery_fees || 0,
      status: o.status || "",
      refundStatus: o.refund_status || "À traiter",
      refundError: o.refund_error || null,
      paymentReference: o.payment_reference || null,
      createdAt: iso(o.created_at),
      updatedAt: iso(o.status_updated_at),
      client: {name: u.display_name || "", phone: u.phone_number || "",
        email: u.email || ""},
    };
  });
  list.sort((a, b) => (a.updatedAt || "").localeCompare(b.updatedAt || ""));
  return {refunds: list};
}

/** L'admin a remboursé lui-même (transfert MoMo) : référence obligatoire. */
async function markRefunded({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const orderId = text(data.orderId, 128);
  const reference = text(data.reference, 120);
  if (!orderId) throw new AcquisitionError("invalid-argument", "Commande manquante.");
  if (!reference) {
    throw new AcquisitionError("invalid-argument",
        "Indiquez la référence du transfert de remboursement.");
  }
  const ref = db.doc(`Orders/${orderId}`);
  await db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    if (!o.exists) throw new AcquisitionError("not-found", "Commande introuvable.");
    if (o.get("refund_needed") !== true) {
      throw new AcquisitionError("failed-precondition",
          "Aucun remboursement n'est demandé pour cette commande.");
    }
    const status = o.get("refund_status");
    if (status === "Envoyé") {
      throw new AcquisitionError("failed-precondition",
          "Cette commande est déjà remboursée.");
    }
    if (status === "En cours") {
      throw new AcquisitionError("failed-precondition",
          "Un remboursement automatique est en cours pour cette commande.");
    }
    tx.update(ref, {refund_status: "Envoyé", refund_reference: reference,
      refund_error: null, refunded_manually_by: adminUid, refunded_at: ts()});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "refund.manual", target: ref.path,
      details: {reference, amount: o.get("total_amount") || 0,
        previous: status || null}});
  });
  return {ok: true};
}

// ── Recherche de comptes ─────────────────────────────────────────────────

/** Par email exact, téléphone (formats congolais) ou début de nom. */
async function searchAccounts({db, data}) {
  const q = text(data.q, 80);
  if (q.length < 2) {
    throw new AcquisitionError("invalid-argument",
        "Saisissez au moins 2 caractères.");
  }
  const users = db.collection("User");
  const queries = [];
  if (q.includes("@")) {
    for (const e of new Set([q, q.toLowerCase()])) {
      queries.push(users.where("email", "==", e).limit(10));
    }
  } else if (/^[+\d\s.-]+$/.test(q)) {
    const n = normalizePhone(q);
    const variants = new Set([q.replace(/[^\d+]/g, "")]);
    if (n) {
      variants.add(n);
      variants.add(`+${n}`);
      variants.add(`0${n.slice(4)}`);
      variants.add(n.slice(3));
    }
    for (const v of variants) {
      queries.push(users.where("phone_number", "==", v).limit(10));
    }
  } else {
    const cap = q.charAt(0).toUpperCase() + q.slice(1);
    for (const p of new Set([q, cap])) {
      queries.push(users.where("display_name", ">=", p)
          .where("display_name", "<=", `${p}`).limit(10));
    }
  }
  const snaps = await Promise.all(queries.map((x) => x.get()));
  const seen = new Map();
  for (const s of snaps) for (const d of s.docs) seen.set(d.id, d);
  return {accounts: [...seen.values()].slice(0, 25).map(accountSummary)};
}

// ── Abonnements ──────────────────────────────────────────────────────────

/**
 * Offre ou prolonge l'abonnement d'un client (sans paiement : aucune
 * commission n'est générée).
 */
async function grantSubscription({db, uid, data, clock = () => new Date()}) {
  const adminUid = await requireAdmin(db, uid);
  const userUid = text(data.userUid, 128);
  const days = data.days;
  const reason = text(data.reason, 300);
  if (!Number.isSafeInteger(days) || days < 1 || days > 366) {
    throw new AcquisitionError("invalid-argument",
        "Durée invalide : entre 1 et 366 jours.");
  }
  if (!reason) {
    throw new AcquisitionError("invalid-argument", "Indiquez le motif.");
  }
  const ref = db.doc(`User/${userUid || "_"}`);
  return db.runTransaction(async (tx) => {
    const u = await tx.get(ref);
    if (!u.exists) throw new AcquisitionError("not-found", "Compte introuvable.");
    const role = u.get("role") || "User";
    if (role !== "User") {
      throw new AcquisitionError("failed-precondition",
          "Seuls les clients ont un abonnement.");
    }
    const now = clock();
    const current = toDate(u.get("subscribe_close_at"));
    const from = current && current > now ? current : now;
    const until = new Date(from.getTime() + days * DAY);
    tx.update(ref, {
      subscribe_close_at: until,
      is_subscribed: true,
      ...(u.get("subscribe_type") ? {} : {subscribe_type: "Offert par Kitunga"}),
      subscription_granted_by: adminUid,
      subscription_granted_at: ts(),
    });
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "subscription.grant", target: ref.path,
      details: {days, reason, until: until.toISOString(),
        previous: current ? current.toISOString() : null}});
    return {until: until.toISOString()};
  });
}

// ── Suspension des comptes ───────────────────────────────────────────────

const SUSPENDABLE = ["User", "Guest", "Seller", "Deliver"];

/**
 * Suspend (connexion bloquée, sessions fermées dans l'heure) ou réactive un
 * client, commerçant ou livreur. Jamais un admin ni soi-même ; les
 * commerciaux se gèrent dans le module commercial.
 */
async function setAccountStatus({db, auth, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const userUid = text(data.userUid, 128);
  const status = text(data.status, 20);
  const reason = text(data.reason, 300);
  if (!["active", "suspended"].includes(status)) {
    throw new AcquisitionError("invalid-argument", "Statut inconnu.");
  }
  if (status === "suspended" && !reason) {
    throw new AcquisitionError("invalid-argument",
        "Indiquez le motif de la suspension.");
  }
  if (userUid === adminUid) {
    throw new AcquisitionError("failed-precondition",
        "Vous ne pouvez pas suspendre votre propre compte.");
  }
  const ref = db.doc(`User/${userUid || "_"}`);
  const u = await ref.get();
  if (!u.exists) throw new AcquisitionError("not-found", "Compte introuvable.");
  const role = u.get("role") || "User";
  if (role === "Commercial") {
    throw new AcquisitionError("failed-precondition",
        "Les commerciaux se gèrent dans le module commercial.");
  }
  if (!SUSPENDABLE.includes(role)) {
    throw new AcquisitionError("failed-precondition",
        "Ce compte ne peut pas être suspendu ici.");
  }
  // D'abord la connexion, puis le profil : un échec laisse le compte tel quel.
  await auth.updateUser(userUid, {disabled: status === "suspended"});
  if (status === "suspended") await auth.revokeRefreshTokens(userUid);
  await db.runTransaction(async (tx) => {
    tx.update(ref, {account_status: status,
      account_status_reason: status === "suspended" ? reason : null,
      account_status_updated_at: ts()});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: `account.${status}`, target: ref.path, details: {role, reason}});
  });
  return {ok: true};
}

/** Lecture pour l'interface « Gestion » (admin). */
async function adminOpsQuery({db, uid, data}) {
  await requireAdmin(db, uid);
  switch (text(data.view, 20)) {
    case "refunds": return listRefunds({db});
    case "search": return searchAccounts({db, data});
    default: throw new AcquisitionError("invalid-argument", "Vue inconnue.");
  }
}

module.exports = {adminOpsQuery, markRefunded, grantSubscription,
  setAccountStatus, searchAccounts, listRefunds};
