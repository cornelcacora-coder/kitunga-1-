/**
 * Module commercial Kitunga : modèle de données (voir README-ACQUISITION.md).
 *
 * Ce fichier ne lit ni n'écrit rien : il fixe les noms des collections, les
 * statuts, les transitions autorisées et les identifiants de documents. Les
 * garanties d'unicité reposent sur ces identifiants : un document au nom
 * déterministe ne peut être créé qu'une seule fois (voir store.js).
 */
const crypto = require("crypto");
const {normalizePhone} = require("../momo");

const COLLECTIONS = Object.freeze({
  agents: "sales_agents",
  agentKeys: "sales_agent_keys", // empreinte du téléphone → commercial
  campaigns: "acquisition_campaigns",
  assignments: "campaign_agents",
  codes: "referral_codes",
  touches: "acquisition_touches",
  attributions: "acquisition_attributions",
  identityKeys: "attribution_identity_keys",
  activations: "app_activations",
  rules: "commission_rules",
  commissions: "commission_transactions",
  payouts: "commission_payouts",
  payoutItems: "items", // sous-collection de commission_payouts
  events: "acquisition_events",
  audit: "audit_logs",
  counters: "acquisition_counters",
});

/** Statuts et transitions autorisées : {statut: [statuts suivants]}. */
const TRANSITIONS = Object.freeze({
  campaign: {
    draft: ["scheduled", "active", "archived"],
    scheduled: ["draft", "active", "paused", "completed"],
    active: ["paused", "completed"],
    paused: ["active", "completed"],
    completed: ["archived"],
    archived: [],
  },
  agent: {
    active: ["suspended", "archived"],
    suspended: ["active", "archived"],
    archived: [],
  },
  assignment: {
    active: ["ended", "cancelled"],
    ended: [],
    cancelled: [],
  },
  code: {
    active: ["disabled"],
    disabled: [],
  },
  touch: {
    provisional: ["confirmed", "superseded", "rejected"],
    confirmed: [],
    superseded: [],
    rejected: [],
  },
  attribution: {
    confirmed: ["rejected", "void"],
    rejected: [],
    void: [],
  },
  // Une commission versée n'est jamais modifiée : un remboursement crée une
  // écriture de contrepassation séparée (type « reversal »).
  commission: {
    pending: ["approved", "rejected", "reversed"],
    approved: ["reserved", "rejected", "reversed"],
    reserved: ["paid", "approved"],
    paid: [],
    rejected: [],
    reversed: [],
  },
  payout: {
    requested: ["approved", "rejected"],
    approved: ["paid", "rejected"],
    paid: [],
    rejected: [],
  },
});

const COMMISSION_TYPES = Object.freeze(
    ["activation", "first_subscription", "reversal"]);
const CURRENCY = "XAF";
const MAX_AMOUNT = 1000000; // FCFA, garde-fou contre une saisie erronée
const PAYOUT_METHODS = Object.freeze(["mobile_money", "bank"]);

/** Erreur de règle métier (transformée en HttpsError par les fonctions). */
class AcquisitionError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function canTransition(kind, from, to) {
  const map = TRANSITIONS[kind];
  if (!map) throw new Error(`Type de statut inconnu : ${kind}`);
  return Array.isArray(map[from]) && map[from].includes(to);
}

function assertTransition(kind, from, to) {
  if (!canTransition(kind, from, to)) {
    throw new AcquisitionError("failed-precondition",
        `Passage de « ${from} » à « ${to} » interdit (${kind}).`);
  }
}

/** Montant en FCFA entiers ; négatif seulement pour une contrepassation. */
function assertAmount(amount, {allowNegative = false} = {}) {
  const ok = Number.isSafeInteger(amount) &&
    Math.abs(amount) <= MAX_AMOUNT && (allowNegative || amount >= 0);
  if (!ok) {
    throw new AcquisitionError("invalid-argument",
        "Montant invalide : nombre entier de FCFA attendu.");
  }
  return amount;
}

// ── Identifiants de documents (unicité garantie par la base) ─────────────

/** Une seule commission d'un type donné par client. */
function commissionId(type, clientUid) {
  if (type !== "activation" && type !== "first_subscription") {
    throw new AcquisitionError("invalid-argument", "Type de commission inconnu.");
  }
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(String(clientUid || ""))) {
    throw new AcquisitionError("invalid-argument", "Client invalide.");
  }
  return `${type}_${clientUid}`;
}

/** Une seule contrepassation par commission. */
function reversalId(originalCommissionId) {
  return `reversal_${originalCommissionId}`;
}

// Identifiant d'installation : UUID tiré au hasard par l'application au
// premier lancement, jamais un identifiant matériel (IMEI, numéro de série).
const INSTALLATION_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

function installationId(raw) {
  const id = String(raw || "").toLowerCase();
  if (!INSTALLATION_ID.test(id)) {
    throw new AcquisitionError("invalid-argument", "Installation invalide.");
  }
  return id;
}

// ── Codes commerciaux et codes de parrainage ──────────────────────────────

// Sans 0/O, 1/I/L : lisibles sans confusion sur une affiche.
const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
const AGENT_CODE = /^KTG\d{3,6}$/;
const REFERRAL_CODE = /^KTG\d{3,6}-[2-9A-HJKMNP-Z]{4}$/;

/** KTG001, KTG002… à partir d'un compteur tenu par le serveur. */
function agentCode(sequence) {
  if (!Number.isSafeInteger(sequence) || sequence < 1 || sequence > 999999) {
    throw new AcquisitionError("invalid-argument", "Numéro de commercial invalide.");
  }
  return `KTG${String(sequence).padStart(3, "0")}`;
}

/** KTG001-X7P9 : code de l'affectation, tiré au hasard. */
function newReferralCode(agentCodeValue, random = crypto.randomInt) {
  if (!AGENT_CODE.test(agentCodeValue)) {
    throw new AcquisitionError("invalid-argument", "Code commercial invalide.");
  }
  let suffix = "";
  for (let i = 0; i < 4; i++) suffix += CODE_ALPHABET[random(CODE_ALPHABET.length)];
  return `${agentCodeValue}-${suffix}`;
}

/** Code saisi ou reçu : mis en forme, ou null s'il est invalide. */
function parseReferralCode(raw) {
  const code = String(raw || "").trim().toUpperCase();
  return REFERRAL_CODE.test(code) ? code : null;
}

// ── Identité d'une personne (premier contact, auto-parrainage) ───────────

/**
 * Empreinte d'un numéro de téléphone (HMAC-SHA256 avec une clé secrète) : la
 * même personne est reconnue sans que le numéro soit stocké en clair.
 */
function identityKey(phone, secret) {
  if (!secret || String(secret).length < 16) {
    throw new Error("Clé ACQ_IDENTITY_KEY absente ou trop courte.");
  }
  const normalized = normalizePhone(phone);
  if (!normalized) return null;
  return crypto.createHmac("sha256", String(secret))
      .update(normalized).digest("hex");
}

// ── Dates ────────────────────────────────────────────────────────────────

function toDate(v) {
  if (v == null) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === "function") return v.toDate();
  const d = new Date(v);
  return isNaN(d.getTime()) ? null : d;
}

/** Périodes [début, fin[ qui se chevauchent. */
function periodsOverlap(aStart, aEnd, bStart, bEnd) {
  return toDate(aStart) < toDate(bEnd) && toDate(bStart) < toDate(aEnd);
}

const DAY = 24 * 60 * 60 * 1000;

/**
 * Un événement (activation, premier abonnement) ouvre droit à commission si
 * le premier contact a eu lieu pendant l'affectation et si l'événement
 * survient au plus tard graceDays jours après la fin de l'affectation.
 */
function eventEligible({touchAt, assignmentStart, assignmentEnd, eventAt,
  graceDays}) {
  const touch = toDate(touchAt);
  const event = toDate(eventAt);
  const start = toDate(assignmentStart);
  const end = toDate(assignmentEnd);
  if (!touch || !event || !start || !end) return false;
  if (!Number.isSafeInteger(graceDays) || graceDays < 0) return false;
  return touch >= start && touch < end && event >= touch &&
    event.getTime() <= end.getTime() + graceDays * DAY;
}

/** Date à partir de laquelle une commission peut être validée. */
function holdUntil(createdAt, holdDays) {
  if (!Number.isSafeInteger(holdDays) || holdDays < 0) {
    throw new AcquisitionError("invalid-argument", "Délai de sécurité invalide.");
  }
  return new Date(toDate(createdAt).getTime() + holdDays * DAY);
}

module.exports = {
  COLLECTIONS, TRANSITIONS, COMMISSION_TYPES, CURRENCY, MAX_AMOUNT,
  PAYOUT_METHODS, CODE_ALPHABET, AcquisitionError, canTransition,
  assertTransition, assertAmount, commissionId, reversalId, installationId,
  agentCode, newReferralCode, parseReferralCode, identityKey, toDate,
  periodsOverlap, eventEligible, holdUntil,
};
