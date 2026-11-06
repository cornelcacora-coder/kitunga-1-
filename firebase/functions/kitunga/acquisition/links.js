/**
 * Liens commerciaux et premier contact.
 *
 * 1. /r/{code} (fonction HTTP derrière Firebase Hosting) : enregistre le clic
 *    puis renvoie vers Google Play avec le code dans le paramètre
 *    « referrer ». Un clic n'est jamais une installation.
 * 2. kitungaRecordTouch : au premier lancement, l'application lit ce code
 *    (Google Play Install Referrer) et l'envoie avec son identifiant
 *    d'installation. Le serveur enregistre un premier contact « provisoire »
 *    par appareil ; il sera confirmé à l'inscription (phase 6).
 *
 * Rien n'est jamais pris tel quel : le code, la campagne et le commercial
 * sont revérifiés, et le premier contact d'un appareil ne change plus.
 */
const crypto = require("crypto");
const admin = require("firebase-admin");
const {COLLECTIONS, AcquisitionError, parseReferralCode, installationId,
  toDate} = require("./model");

const ts = () => admin.firestore.FieldValue.serverTimestamp();

const PLAY_PACKAGE = "com.ntemoconsulting.kitunga";
const PLAY_URL = `https://play.google.com/store/apps/details?id=${PLAY_PACKAGE}`;
const MAX_CLICKS_PER_IP_PER_DAY = 30;
const MAX_TOUCHES_PER_ACCOUNT = 3;
const SOURCES = ["install_referrer", "link", "manual"];
// Aperçus de liens (WhatsApp, Facebook…) et robots : jamais comptés.
const BOT = /bot|crawl|spider|slurp|facebookexternalhit|facebookcatalog|whatsapp|telegram|twitter|slack|discord|skype|linkedin|preview|headless|curl|wget|python|okhttp/i;

/** Lien public d'une affectation. */
function referralLink(code, base = "https://kitunga-xtvpe4.web.app") {
  return `${base.replace(/\/+$/, "")}/r/${code}`;
}

/** Lien Google Play portant le code (lu par l'application à l'installation). */
function playStoreUrl(code, clickId) {
  if (!code) return PLAY_URL;
  const referrer = new URLSearchParams({utm_source: "kitunga",
    utm_medium: "commercial", kitunga_code: code,
    ...(clickId ? {kitunga_click: clickId} : {})}).toString();
  return `${PLAY_URL}&referrer=${encodeURIComponent(referrer)}`;
}

/**
 * Le code permet-il une acquisition maintenant ? Renvoie les données utiles
 * ou {ok: false, reason}. Lecture simple ou dans une transaction (tx).
 */
async function checkCode(db, code, now, tx = null) {
  const read = (ref) => (tx ? tx.get(ref) : ref.get());
  const codeDoc = await read(db.doc(`${COLLECTIONS.codes}/${code}`));
  if (!codeDoc.exists) return {ok: false, reason: "unknown_code"};
  const c = codeDoc.data();
  const [campaign, agent] = await Promise.all([
    read(db.doc(`${COLLECTIONS.campaigns}/${c.campaign_id}`)),
    read(db.doc(`${COLLECTIONS.agents}/${c.agent_uid}`)),
  ]);
  if (c.status !== "active") return {ok: false, reason: "code_disabled"};
  if (now < toDate(c.valid_from) || now >= toDate(c.valid_until)) {
    return {ok: false, reason: "code_expired"};
  }
  if (!campaign.exists || campaign.get("status") !== "active") {
    return {ok: false, reason: "campaign_inactive"};
  }
  if (!agent.exists || agent.get("status") !== "active") {
    return {ok: false, reason: "agent_inactive"};
  }
  return {ok: true, code, campaignId: c.campaign_id, agentUid: c.agent_uid,
    assignmentId: c.assignment_id};
}

function dayKey(now) {
  return now.toISOString().slice(0, 10).replace(/-/g, "");
}

/** Empreinte de l'adresse IP, différente chaque jour (pas de suivi durable). */
function ipHash(ip, secret, now) {
  return crypto.createHmac("sha256", String(secret))
      .update(`ip:${dayKey(now)}:${ip || "?"}`).digest("hex").slice(0, 32);
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (ch) => ({"&": "&amp;", "<": "&lt;",
    ">": "&gt;", "\"": "&quot;", "'": "&#39;"})[ch]);
}

/** Page pour iPhone et ordinateur : le code à saisir et le lien Play. */
function landingPage(code) {
  const codeBlock = code ? `<p>Votre code commercial :</p>
    <p class="code">${escapeHtml(code)}</p>
    <p class="hint">Saisissez-le lors de votre inscription dans l'application.</p>` : "";
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>Kitunga</title>
<style>body{margin:0;font-family:system-ui,sans-serif;background:#e51a1a;color:#17181c;
display:flex;min-height:100vh;align-items:center;justify-content:center}
main{background:#fff;border-radius:20px;padding:32px 24px;max-width:360px;margin:16px;text-align:center}
h1{margin:0 0 8px;font-size:24px}.code{font-size:26px;font-weight:800;letter-spacing:2px;color:#e51a1a}
.hint{color:#6b6f76;font-size:14px}a{display:block;margin-top:20px;background:#e51a1a;color:#fff;
padding:14px;border-radius:12px;text-decoration:none;font-weight:700}</style></head>
<body><main><h1>Kitunga</h1><p>Boutiques, restaurants et pharmacies près de chez vous.</p>
${codeBlock}<a href="${PLAY_URL}">Télécharger sur Google Play</a></main></body></html>`;
}

/**
 * Traite /r/{code}. Le parcours de l'utilisateur ne doit jamais casser : en
 * cas d'erreur, on renvoie quand même vers Google Play (sans code).
 */
async function handleReferralClick(req, res, {db, secret,
  clock = () => new Date()}) {
  res.set("Cache-Control", "private, no-store");
  res.set("Referrer-Policy", "no-referrer");
  const ua = String(req.get("user-agent") || "");
  const android = /android/i.test(ua);
  const code = parseReferralCode(String(req.path || "").split("/").pop());
  let target = {code: null, clickId: null};
  try {
    const now = clock();
    const check = code ? await checkCode(db, code, now) : {ok: false};
    if (check.ok) {
      target.code = code;
      // Seul un vrai affichage compte (pas HEAD, pas les aperçus de liens).
      if (req.method === "GET" && !BOT.test(ua)) {
        const ip = String(req.get("x-forwarded-for") || req.ip || "")
            .split(",")[0].trim();
        const hash = ipHash(ip, secret, now);
        const eventRef = db.collection(COLLECTIONS.events).doc();
        const limitRef = db.doc(`acquisition_limits/click_${hash}_${dayKey(now)}`);
        const recorded = await db.runTransaction(async (tx) => {
          const limit = await tx.get(limitRef);
          const count = limit.exists ? limit.get("count") : 0;
          if (count >= MAX_CLICKS_PER_IP_PER_DAY) return false;
          tx.set(limitRef, {count: count + 1, day: dayKey(now)}, {merge: true});
          tx.create(eventRef, {type: "click", code, campaign_id: check.campaignId,
            agent_uid: check.agentUid, assignment_id: check.assignmentId,
            platform: android ? "android" : /iphone|ipad/i.test(ua) ? "ios" :
              "other", ip_hash: hash, created_at: ts()});
          return true;
        });
        if (recorded) target.clickId = eventRef.id;
      }
    }
  } catch (e) {
    console.error("Lien commercial :", e);
    target = {code: null, clickId: null};
  }
  if (android) {
    res.redirect(302, playStoreUrl(target.code, target.clickId));
  } else {
    res.status(200).type("html").send(landingPage(target.code));
  }
}

/**
 * Premier contact d'un appareil (appel de l'application, utilisateur connecté
 * en visiteur ou avec un compte). Renvoie {accepted, reason?}.
 */
async function recordTouch({db, uid, data, clock = () => new Date()}) {
  if (!uid) throw new AcquisitionError("unauthenticated", "Connexion requise.");
  const install = installationId(data.installationId);
  const code = parseReferralCode(data.code);
  if (!code) throw new AcquisitionError("invalid-argument", "Code invalide.");
  const source = SOURCES.includes(data.source) ? data.source : null;
  if (!source) throw new AcquisitionError("invalid-argument", "Origine inconnue.");
  const clickId = typeof data.clickId === "string" &&
    /^[A-Za-z0-9]{10,40}$/.test(data.clickId) ? data.clickId : null;
  const now = clock();

  const touchRef = db.doc(`${COLLECTIONS.touches}/${install}`);
  const limitRef = db.doc(`acquisition_limits/touch_${uid}`);
  const result = await db.runTransaction(async (tx) => {
    const [touch, attribution, caller, limit] = await Promise.all([
      tx.get(touchRef),
      tx.get(db.doc(`${COLLECTIONS.attributions}/${uid}`)),
      tx.get(db.doc(`User/${uid}`)),
      tx.get(limitRef),
    ]);
    if (attribution.exists) return {accepted: false, reason: "already_attributed"};
    if (touch.exists) {
      return {accepted: false, reason: "already_touched",
        sameCode: touch.get("code") === code};
    }
    const role = caller.exists ? caller.get("role") : null;
    if (["Commercial", "Admin", "Seller", "Deliver"].includes(role)) {
      return {accepted: false, reason: "not_a_client"};
    }
    if ((limit.exists ? limit.get("count") : 0) >= MAX_TOUCHES_PER_ACCOUNT) {
      return {accepted: false, reason: "limit"};
    }
    const check = await checkCode(db, code, now, tx);
    if (!check.ok) return {accepted: false, reason: check.reason};
    if (check.agentUid === uid) return {accepted: false, reason: "self_referral"};
    let clickVerified = false;
    if (clickId) {
      const click = await tx.get(db.doc(`${COLLECTIONS.events}/${clickId}`));
      clickVerified = click.exists && click.get("type") === "click" &&
        click.get("code") === code;
    }
    const clickAt = Number.isSafeInteger(data.referrerClickAt) &&
      data.referrerClickAt > 0 ? new Date(data.referrerClickAt * 1000) : null;
    tx.set(limitRef, {count: (limit.exists ? limit.get("count") : 0) + 1},
        {merge: true});
    tx.create(touchRef, {
      code,
      campaign_id: check.campaignId,
      agent_uid: check.agentUid,
      assignment_id: check.assignmentId,
      source,
      click_id: clickId,
      click_verified: clickVerified,
      referrer_click_at: clickAt,
      status: "provisional",
      created_by_uid: uid,
      touched_at: ts(),
      touched_at_server: now,
    });
    tx.create(db.collection(COLLECTIONS.events).doc(), {type: "touch", code,
      campaign_id: check.campaignId, agent_uid: check.agentUid,
      assignment_id: check.assignmentId, source, click_verified: clickVerified,
      created_at: ts()});
    return {accepted: true};
  });
  return result;
}

module.exports = {PLAY_PACKAGE, referralLink, playStoreUrl, checkCode,
  handleReferralClick, recordTouch, landingPage, BOT,
  MAX_CLICKS_PER_IP_PER_DAY, MAX_TOUCHES_PER_ACCOUNT};
