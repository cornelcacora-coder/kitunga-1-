/**
 * Publicités et promotions du carrousel d'accueil de l'application.
 *
 * Deux sortes de bannières, gérées par l'admin :
 *  - « app » : promotion de Kitunga (livraison, nouveautés, catégories…) ;
 *  - « seller » : publicité d'un commerce partenaire (sa vitrine, un produit).
 *
 * Chaque bannière : textes, image, couleurs, bouton, destination du clic,
 * période de diffusion, ordre, active ou non. L'application lit les
 * bannières diffusées (publicBanners) et compte les clics (bannerClick).
 * Collection vide : les 3 bannières d'origine de l'application sont reprises
 * à la première ouverture de la page admin.
 */
const admin = require("firebase-admin");
const {AcquisitionError, toDate} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {audit} = require("./acquisition/store");

const BANNERS = "Banners";
const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const err = (code, message) => new AcquisitionError(code, message);
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};
const KINDS = ["app", "seller"];
const TARGETS = ["shops", "category", "shop", "product", "url", "none"];

/** Bannières d'origine (images incluses dans l'application). */
const DEFAULT_BANNERS = [
  {title1: "Tout au même", title2: "endroit",
    subtitle: "Boutiques, restaurants\net pharmacies",
    image: "asset:assets/images/Girl_Bag2.jpg"},
  {title1: "Livraison", title2: "rapide",
    subtitle: "Recevez vos commandes\nà domicile",
    image: "asset:assets/images/youngAfrican.jpg"},
  {title1: "Produits", title2: "frais",
    subtitle: "Alimentation, marché\net épicerie",
    image: "asset:assets/images/Gemini_Generated_Image_xb96ubxb96ubxb96.png"},
].map((b) => ({...b, kind: "app", button: "Découvrir", badge: "",
  color: "#E51A1A", accent: "#FFD200", target: {type: "shops", value: ""}}));

function imageOf(raw) {
  const v = text(raw, 1000);
  if (!v) throw err("invalid-argument", "Ajoutez une image.");
  if (v.startsWith("asset:assets/")) return v;
  let url;
  try {
    url = new URL(v);
  } catch (_) {
    throw err("invalid-argument", "Adresse d'image invalide.");
  }
  if (url.protocol !== "https:" ||
    !["firebasestorage.googleapis.com", "storage.googleapis.com"]
        .includes(url.hostname)) {
    throw err("invalid-argument",
        "L'image doit être envoyée depuis l'interface Kitunga.");
  }
  return v;
}

function colorOf(raw, fallback, label) {
  const c = text(raw, 9) || fallback;
  if (!/^#[0-9A-Fa-f]{6}$/.test(c)) {
    throw err("invalid-argument", `${label} : couleur invalide (#RRVVBB).`);
  }
  return c.toUpperCase();
}

function dateOf(raw, label) {
  if (raw === undefined || raw === null || raw === "") return null;
  const d = new Date(raw);
  if (isNaN(d.getTime())) throw err("invalid-argument", `${label} invalide.`);
  return d;
}

/** Destination du clic, vérifiée (commerce ou produit existants). */
async function targetOf(db, raw, sellerUid) {
  const t = raw && typeof raw === "object" ? raw : {};
  const type = TARGETS.includes(t.type) ? t.type : "shops";
  const value = text(t.value, 1000);
  switch (type) {
    case "category":
      if (!value) throw err("invalid-argument", "Choisissez la catégorie.");
      return {type, value};
    case "shop": {
      const uid = value || sellerUid;
      const u = uid ? await db.doc(`User/${uid}`).get() : null;
      if (!u || !u.exists || u.get("role") !== "Seller") {
        throw err("invalid-argument", "Choisissez le commerce.");
      }
      return {type, value: uid};
    }
    case "product": {
      const p = value ? await db.doc(`Product/${value}`).get() : null;
      if (!p || !p.exists) {
        throw err("invalid-argument", "Produit introuvable.");
      }
      return {type, value};
    }
    case "url": {
      let url;
      try {
        url = new URL(value);
      } catch (_) {
        throw err("invalid-argument", "Lien invalide.");
      }
      if (!["https:", "http:"].includes(url.protocol)) {
        throw err("invalid-argument", "Lien invalide.");
      }
      return {type, value};
    }
    default:
      return {type, value: ""};
  }
}

/** État de diffusion d'une bannière à l'instant `now`. */
function statusOf(b, now = new Date()) {
  // Publicité proposée par un vendeur : validée par l'admin avant diffusion.
  if (b.review === "pending") return "pending";
  if (b.review === "rejected") return "rejected";
  if (b.active === false) return "off";
  const start = toDate(b.starts_at);
  const end = toDate(b.ends_at);
  if (start && start > now) return "scheduled";
  if (end && end < now) return "expired";
  return "live";
}

async function seedBanners({db, uid}) {
  const adminUid = await requireAdmin(db, uid);
  const existing = await db.collection(BANNERS).limit(1).get();
  if (!existing.empty) return {created: 0};
  const batch = db.batch();
  DEFAULT_BANNERS.forEach((b, i) => {
    batch.set(db.collection(BANNERS).doc(), {...b, seller_uid: "",
      order: i, active: true, starts_at: null, ends_at: null, clicks: 0,
      created_at: ts(), updated_at: ts()});
  });
  batch.create(db.collection("audit_logs").doc(), {actor_uid: adminUid,
    actor_role: "Admin", action: "banner.seed", target: BANNERS,
    details: {count: DEFAULT_BANNERS.length}, created_at: ts()});
  await batch.commit();
  return {created: DEFAULT_BANNERS.length};
}

/** Liste complète pour l'admin (avec état et clics). */
async function listBanners({db, uid}) {
  await seedBanners({db, uid});
  const snap = await db.collection(BANNERS).orderBy("order").get();
  const sellerIds = [...new Set(snap.docs.map((d) => d.get("seller_uid"))
      .filter(Boolean))];
  const sellers = new Map(await Promise.all(sellerIds.map(async (id) => {
    const u = await db.doc(`User/${id}`).get();
    return [id, u.exists ? u.get("display_name") || "" : ""];
  })));
  const now = new Date();
  return {banners: snap.docs.map((d) => {
    const b = d.data();
    return {id: d.id, kind: b.kind || "app", sellerUid: b.seller_uid || "",
      sellerName: sellers.get(b.seller_uid) || "",
      title1: b.title1 || "", title2: b.title2 || "",
      subtitle: b.subtitle || "", button: b.button || "", badge: b.badge || "",
      image: b.image || "", color: b.color || "#E51A1A",
      accent: b.accent || "#FFD200",
      target: b.target || {type: "shops", value: ""},
      order: b.order ?? 99, active: b.active !== false,
      startsAt: iso(b.starts_at), endsAt: iso(b.ends_at),
      clicks: b.clicks || 0, status: statusOf(b, now),
      review: b.review || "approved", reviewNote: b.review_note || "",
      bySeller: b.submitted_by === "seller",
      updatedAt: iso(b.updated_at)};
  })};
}

/** Création (sans id) ou modification d'une bannière. */
async function saveBanner({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const id = text(data.id, 128);
  const kind = KINDS.includes(data.kind) ? data.kind : "app";
  const title1 = text(data.title1, 30);
  const title2 = text(data.title2, 24);
  if (!title1 && !title2) {
    throw err("invalid-argument", "Indiquez le titre de la bannière.");
  }
  let sellerUid = "";
  if (kind === "seller") {
    sellerUid = text(data.sellerUid, 128);
    const s = sellerUid ? await db.doc(`User/${sellerUid}`).get() : null;
    if (!s || !s.exists || s.get("role") !== "Seller") {
      throw err("invalid-argument", "Choisissez le commerce annonceur.");
    }
  }
  const startsAt = dateOf(data.startsAt, "Date de début");
  const endsAt = dateOf(data.endsAt, "Date de fin");
  if (startsAt && endsAt && endsAt <= startsAt) {
    throw err("invalid-argument", "La fin doit être après le début.");
  }
  const values = {
    kind, seller_uid: sellerUid, title1, title2,
    subtitle: text(data.subtitle, 90),
    button: text(data.button, 20) || "Découvrir",
    badge: text(data.badge, 14),
    image: imageOf(data.image),
    color: colorOf(data.color, "#E51A1A", "Couleur du fond"),
    accent: colorOf(data.accent, "#FFD200", "Couleur du titre"),
    target: await targetOf(db, data.target, sellerUid),
    active: data.active !== false,
    starts_at: startsAt, ends_at: endsAt,
    // Enregistrée par l'admin : validée d'office.
    review: "approved", review_note: "",
    updated_at: ts(),
  };
  const ref = id ? db.doc(`${BANNERS}/${id}`) : db.collection(BANNERS).doc();
  await db.runTransaction(async (tx) => {
    if (id) {
      const cur = await tx.get(ref);
      if (!cur.exists) throw err("not-found", "Bannière introuvable.");
      tx.update(ref, {...values,
        ...(Number.isSafeInteger(data.order) ? {order: data.order} : {})});
    } else {
      const last = await tx.get(db.collection(BANNERS)
          .orderBy("order", "desc").limit(1));
      const order = last.empty ? 0 : (last.docs[0].get("order") ?? 0) + 1;
      tx.create(ref, {...values, order, clicks: 0, created_at: ts()});
    }
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: id ? "banner.update" : "banner.create", target: ref.path,
      details: {kind, title: `${title1} ${title2}`.trim(), sellerUid}});
  });
  return {id: ref.id};
}

/** Active / désactive sans tout renvoyer. */
async function setBannerActive({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`${BANNERS}/${text(data.id, 128) || "_"}`);
  await db.runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (!cur.exists) throw err("not-found", "Bannière introuvable.");
    tx.update(ref, {active: data.active === true, updated_at: ts()});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: data.active === true ? "banner.enable" : "banner.disable",
      target: ref.path, details: {}});
  });
  return {ok: true};
}

/** Nouvel ordre d'affichage : liste complète des identifiants. */
async function reorderBanners({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ids = Array.isArray(data.ids) ? data.ids.map((i) => text(i, 128)) : [];
  if (ids.length === 0 || ids.length > 100 || new Set(ids).size !== ids.length) {
    throw err("invalid-argument", "Ordre invalide.");
  }
  const refs = ids.map((i) => db.doc(`${BANNERS}/${i || "_"}`));
  await db.runTransaction(async (tx) => {
    const docs = await Promise.all(refs.map((r) => tx.get(r)));
    if (docs.some((d) => !d.exists)) {
      throw err("not-found", "Bannière introuvable.");
    }
    refs.forEach((r, i) => tx.update(r, {order: i, updated_at: ts()}));
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "banner.reorder", target: BANNERS, details: {ids}});
  });
  return {ok: true};
}

async function deleteBanner({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`${BANNERS}/${text(data.id, 128) || "_"}`);
  await db.runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (!cur.exists) throw err("not-found", "Bannière introuvable.");
    tx.delete(ref);
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "banner.delete", target: ref.path,
      details: {title: `${cur.get("title1")} ${cur.get("title2")}`.trim()}});
  });
  return {ok: true};
}

/** Bannières diffusées maintenant (application ; sans connexion). */
async function publicBanners({db, now = new Date()}) {
  const snap = await db.collection(BANNERS).orderBy("order").get();
  const list = snap.empty ?
    DEFAULT_BANNERS.map((b, i) => ({...b, id: `default-${i}`, active: true})) :
    snap.docs.map((d) => ({...d.data(), id: d.id}));
  // Commerce suspendu : sa publicité n'est plus diffusée.
  const sellerIds = [...new Set(list.map((b) => b.seller_uid)
      .filter(Boolean))];
  const suspended = new Set((await Promise.all(sellerIds.map((i) =>
    db.doc(`User/${i}`).get()))).filter((u) => !u.exists ||
      u.get("account_status") === "suspended").map((u) => u.id));
  return {banners: list
      .filter((b) => statusOf(b, now) === "live" &&
        !(b.seller_uid && suspended.has(b.seller_uid)))
      .slice(0, 10)
      .map((b) => ({id: b.id, kind: b.kind || "app", title1: b.title1 || "",
        title2: b.title2 || "", subtitle: b.subtitle || "",
        button: b.button || "Découvrir", badge: b.badge || "",
        image: b.image || "", color: b.color || "#E51A1A",
        accent: b.accent || "#FFD200",
        target: b.target || {type: "shops", value: ""}}))};
}

/** Un clic sur une bannière (statistique simple, sans donnée personnelle). */
async function bannerClick({db, data}) {
  const id = text(data.id, 128);
  if (!id || id.startsWith("default-")) return {ok: true};
  const ref = db.doc(`${BANNERS}/${id}`);
  try {
    await ref.update({clicks: admin.firestore.FieldValue.increment(1)});
  } catch (_) {
    // Bannière supprimée entre-temps : clic ignoré.
  }
  return {ok: true};
}

/** Validation (ou refus motivé) d'une publicité proposée par un vendeur. */
async function reviewBanner({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`${BANNERS}/${text(data.id, 128) || "_"}`);
  const approve = data.decision === "approve";
  const note = text(data.note, 300);
  if (!approve && !note) {
    throw err("invalid-argument",
        "Indiquez au vendeur pourquoi la publicité est refusée.");
  }
  await db.runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (!cur.exists) throw err("not-found", "Bannière introuvable.");
    tx.update(ref, {review: approve ? "approved" : "rejected",
      review_note: approve ? "" : note, reviewed_by: adminUid,
      reviewed_at: ts(), updated_at: ts()});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: approve ? "banner.approve" : "banner.reject", target: ref.path,
      details: {sellerUid: cur.get("seller_uid") || "", note}});
  });
  return {ok: true};
}

// ── Publicités proposées par les vendeurs (application) ────────────────

/** Publicités non terminées qu'un vendeur peut avoir en même temps. */
const MAX_SELLER_BANNERS = 3;

async function sellerOf(db, uid) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const u = await db.doc(`User/${uid}`).get();
  if (!u.exists || u.get("role") !== "Seller") {
    throw err("permission-denied", "Réservé aux commerces partenaires.");
  }
  if (u.get("account_status") === "suspended") {
    throw err("permission-denied", "Votre commerce est suspendu.");
  }
  return u;
}

async function ownBanner(db, uid, id) {
  const ref = db.doc(`${BANNERS}/${text(id, 128) || "_"}`);
  const b = await ref.get();
  if (!b.exists || b.get("seller_uid") !== uid ||
    b.get("submitted_by") !== "seller") {
    throw err("not-found", "Publicité introuvable.");
  }
  return b;
}

function sellerView(d, now) {
  const b = d.data();
  return {id: d.id, title1: b.title1 || "", title2: b.title2 || "",
    subtitle: b.subtitle || "", button: b.button || "", badge: b.badge || "",
    image: b.image || "", color: b.color || "#E51A1A",
    accent: b.accent || "#FFD200",
    target: b.target || {type: "shop", value: ""},
    active: b.active !== false, startsAt: iso(b.starts_at),
    endsAt: iso(b.ends_at), clicks: b.clicks || 0,
    status: statusOf(b, now), reviewNote: b.review_note || "",
    updatedAt: iso(b.updated_at)};
}

/** Publicités du vendeur connecté. */
async function sellerBanners({db, uid}) {
  await sellerOf(db, uid);
  const snap = await db.collection(BANNERS)
      .where("seller_uid", "==", uid).get();
  const now = new Date();
  return {max: MAX_SELLER_BANNERS, banners: snap.docs
      .filter((d) => d.get("submitted_by") === "seller")
      .map((d) => sellerView(d, now))
      .sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)))};
}

/**
 * Création ou modification par le vendeur : sa vitrine ou un de ses
 * produits. Toute modification repasse en validation par l'admin.
 */
async function saveSellerBanner({db, uid, data}) {
  const seller = await sellerOf(db, uid);
  const id = text(data.id, 128);
  const title1 = text(data.title1, 30);
  const title2 = text(data.title2, 24);
  if (!title1 && !title2) {
    throw err("invalid-argument", "Indiquez le titre de la publicité.");
  }
  const t = data.target && typeof data.target === "object" ? data.target : {};
  let target = {type: "shop", value: uid};
  let productImage = "";
  if (t.type === "product") {
    const p = await db.doc(`Product/${text(t.value, 128) || "_"}`).get();
    const owner = p.exists && p.get("seller_ref");
    if (!owner || owner.id !== uid) {
      throw err("invalid-argument", "Choisissez un de vos produits.");
    }
    target = {type: "product", value: p.id};
    productImage = p.get("prod_img") || "";
  }
  // Sans photo choisie : celle du produit, sinon la couverture du commerce.
  const image = imageOf(text(data.image, 1000) || productImage ||
    seller.get("Business_cover") || seller.get("photo_url") || "");
  const startsAt = dateOf(data.startsAt, "Date de début");
  const endsAt = dateOf(data.endsAt, "Date de fin");
  if (startsAt && endsAt && endsAt <= startsAt) {
    throw err("invalid-argument", "La fin doit être après le début.");
  }
  const values = {
    kind: "seller", seller_uid: uid, submitted_by: "seller",
    title1, title2, subtitle: text(data.subtitle, 90),
    button: text(data.button, 20) || "Voir",
    badge: text(data.badge, 14), image,
    color: colorOf(data.color, "#E51A1A", "Couleur du fond"),
    accent: colorOf(data.accent, "#FFD200", "Couleur du titre"),
    target, starts_at: startsAt, ends_at: endsAt,
    review: "pending", review_note: "", updated_at: ts(),
  };
  const now = new Date();
  const ref = id ? (await ownBanner(db, uid, id)).ref :
    db.collection(BANNERS).doc();
  await db.runTransaction(async (tx) => {
    if (!id) {
      const mine = await tx.get(db.collection(BANNERS)
          .where("seller_uid", "==", uid));
      const running = mine.docs.filter((d) =>
        d.get("submitted_by") === "seller" &&
        !["expired", "rejected"].includes(statusOf(d.data(), now))).length;
      if (running >= MAX_SELLER_BANNERS) {
        throw err("failed-precondition",
            `${MAX_SELLER_BANNERS} publicités au plus en même temps : ` +
            "supprimez-en une ou attendez la fin d'une diffusion.");
      }
      const last = await tx.get(db.collection(BANNERS)
          .orderBy("order", "desc").limit(1));
      const order = last.empty ? 0 : (last.docs[0].get("order") ?? 0) + 1;
      tx.create(ref, {...values, active: true, order, clicks: 0,
        created_at: ts()});
    } else {
      tx.update(ref, values);
    }
    audit(tx, db, {actorUid: uid, actorRole: "Seller",
      action: id ? "banner.seller_update" : "banner.seller_create",
      target: ref.path, details: {title: `${title1} ${title2}`.trim()}});
  });
  return {id: ref.id, status: "pending"};
}

/** Pause / reprise par le vendeur (sans nouvelle validation). */
async function setSellerBannerActive({db, uid, data}) {
  await sellerOf(db, uid);
  const b = await ownBanner(db, uid, data.id);
  await b.ref.update({active: data.active === true, updated_at: ts()});
  return {ok: true};
}

async function deleteSellerBanner({db, uid, data}) {
  await sellerOf(db, uid);
  const b = await ownBanner(db, uid, data.id);
  await db.runTransaction(async (tx) => {
    tx.delete(b.ref);
    audit(tx, db, {actorUid: uid, actorRole: "Seller",
      action: "banner.seller_delete", target: b.ref.path, details: {}});
  });
  return {ok: true};
}

module.exports = {listBanners, saveBanner, setBannerActive, reorderBanners,
  deleteBanner, publicBanners, bannerClick, seedBanners, statusOf,
  reviewBanner, sellerBanners, saveSellerBanner, setSellerBannerActive,
  deleteSellerBanner, MAX_SELLER_BANNERS, DEFAULT_BANNERS};
