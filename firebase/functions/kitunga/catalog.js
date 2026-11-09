/**
 * Catalogue géré par l'admin : catégories de commerces, produits, fiches des
 * commerçants et livreurs. Réservé à l'admin ; chaque action est journalisée
 * (audit_logs). Les images sont envoyées par l'interface dans le dossier de
 * l'admin (Firebase Storage) : ces fonctions ne reçoivent que leur adresse.
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
const CATEGORIES = "Categories";
/** Catégories où un produit peut être publié sans photo (menus). */
const PHOTO_OPTIONAL = ["Restaurant", "Fast Food"];
const BATCH = 400;

/** Catégories d'origine de l'application (images incluses dans l'appli). */
const DEFAULT_CATEGORIES = [
  {name: "Boutique", image: "asset:assets/images/categories/boutique.png",
    color: "#FFE4E1"},
  {name: "Restaurant", image: "asset:assets/images/categories/restaurant.png",
    color: "#FFEBD6"},
  {name: "Pharmacie", image: "asset:assets/images/categories/pharmacie.png",
    color: "#E2F5E9"},
  {name: "Magasin", image: "asset:assets/images/categories/magasin.png",
    color: "#E2EDFB"},
  {name: "Fast Food", image: "asset:assets/images/categories/fastfood.png",
    color: "#FFF3D1"},
];

function err(code, message) {
  return new AcquisitionError(code, message);
}

/** Adresse d'image acceptée : stockage Firebase/Google ou image de l'appli. */
function imageOf(raw, {required = false, keep = null} = {}) {
  const v = text(raw, 1000);
  // Image déjà en place (même d'une autre origine) : conservée telle quelle.
  if (v && keep && v === keep) return v;
  if (!v) {
    if (required) throw err("invalid-argument", "Ajoutez une image.");
    return "";
  }
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

function amountOf(v, label, {allowEmpty = false} = {}) {
  if ((v === undefined || v === null || v === "") && allowEmpty) return null;
  const n = typeof v === "string" ? Number(v) : v;
  if (!Number.isSafeInteger(n) || n < 0 || n > 10000000) {
    throw err("invalid-argument", `${label} : nombre entier de FCFA.`);
  }
  return n;
}

// ── Catégories ───────────────────────────────────────────────────────────

/** Crée les 5 catégories d'origine si la collection est vide. */
async function seedCategories({db, uid}) {
  const adminUid = await requireAdmin(db, uid);
  const existing = await db.collection(CATEGORIES).limit(1).get();
  if (!existing.empty) return {created: 0};
  const batch = db.batch();
  DEFAULT_CATEGORIES.forEach((c, i) => {
    batch.set(db.collection(CATEGORIES).doc(), {...c,
      name_lower: c.name.toLowerCase(), order: i, active: true,
      created_at: ts(), updated_at: ts()});
  });
  batch.create(db.collection("audit_logs").doc(), {actor_uid: adminUid,
    actor_role: "Admin", action: "category.seed", target: CATEGORIES,
    details: {count: DEFAULT_CATEGORIES.length}, created_at: ts()});
  await batch.commit();
  return {created: DEFAULT_CATEGORIES.length};
}

/** Met à jour la catégorie des commerces (renommage ou remplacement). */
async function moveSellers(db, from, to) {
  let moved = 0;
  for (;;) {
    const snap = await db.collection("User").where("role", "==", "Seller")
        .where("category", "==", from).limit(BATCH).get();
    if (snap.empty) return moved;
    const batch = db.batch();
    for (const d of snap.docs) batch.update(d.ref, {category: to});
    await batch.commit();
    moved += snap.size;
  }
}

/** Création (sans id) ou modification d'une catégorie. */
async function saveCategory({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const id = text(data.id, 128);
  const name = text(data.name, 40);
  if (!name) throw err("invalid-argument", "Nom de la catégorie manquant.");
  const color = text(data.color, 9) || "#F2F2F5";
  if (!/^#[0-9A-Fa-f]{6}$/.test(color)) {
    throw err("invalid-argument", "Couleur invalide (format #RRVVBB).");
  }
  const image = imageOf(data.image, {required: !id});
  const order = Number.isSafeInteger(data.order) ? data.order : 99;
  const active = data.active !== false;

  const ref = id ? db.doc(`${CATEGORIES}/${id}`) :
    db.collection(CATEGORIES).doc();
  const previous = await db.runTransaction(async (tx) => {
    const [current, same] = await Promise.all([
      id ? tx.get(ref) : Promise.resolve(null),
      tx.get(db.collection(CATEGORIES)
          .where("name_lower", "==", name.toLowerCase()).limit(2)),
    ]);
    if (id && !current.exists) throw err("not-found", "Catégorie introuvable.");
    if (same.docs.some((d) => d.id !== ref.id)) {
      throw err("already-exists", "Une catégorie porte déjà ce nom.");
    }
    const values = {name, name_lower: name.toLowerCase(), color, order,
      active, updated_at: ts(), ...(image ? {image} : {})};
    if (id) {
      tx.update(ref, values);
    } else {
      tx.create(ref, {...values, created_at: ts()});
    }
    const oldName = current ? current.get("name") : null;
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: id ? "category.update" : "category.create", target: ref.path,
      details: {name, previous: oldName}});
    return oldName;
  });
  // Renommage : les commerces suivent leur catégorie.
  const moved = previous && previous !== name ?
    await moveSellers(db, previous, name) : 0;
  return {id: ref.id, sellersMoved: moved};
}

/**
 * Suppression : refusée si des commerces l'utilisent, sauf à indiquer une
 * catégorie de remplacement (reassignTo) où ils sont déplacés.
 */
async function deleteCategory({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`${CATEGORIES}/${text(data.id, 128) || "_"}`);
  const cat = await ref.get();
  if (!cat.exists) throw err("not-found", "Catégorie introuvable.");
  const name = cat.get("name");
  const used = (await db.collection("User").where("role", "==", "Seller")
      .where("category", "==", name).count().get()).data().count;
  const reassignTo = text(data.reassignTo, 128);
  let target = null;
  if (used > 0) {
    if (!reassignTo) {
      throw err("failed-precondition",
          `${used} commerce(s) utilisent cette catégorie : choisissez une ` +
          "catégorie de remplacement.");
    }
    const t = await db.doc(`${CATEGORIES}/${reassignTo}`).get();
    if (!t.exists || t.id === ref.id) {
      throw err("invalid-argument", "Catégorie de remplacement invalide.");
    }
    target = t.get("name");
    await moveSellers(db, name, target);
  }
  await db.runTransaction(async (tx) => {
    tx.delete(ref);
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "category.delete", target: ref.path,
      details: {name, sellersMoved: used, to: target}});
  });
  return {sellersMoved: used};
}

async function listCategories(db, uid) {
  // Première ouverture : les 5 catégories de l'application sont reprises.
  await seedCategories({db, uid});
  const snap = await db.collection(CATEGORIES).orderBy("order").get();
  const counts = await Promise.all(snap.docs.map((d) =>
    db.collection("User").where("role", "==", "Seller")
        .where("category", "==", d.get("name")).count().get()));
  return snap.docs.map((d, i) => ({id: d.id, name: d.get("name"),
    image: d.get("image") || "", color: d.get("color") || "#F2F2F5",
    order: d.get("order") ?? 99, active: d.get("active") !== false,
    sellers: counts[i].data().count}));
}

// ── Produits ─────────────────────────────────────────────────────────────

async function sellerOf(db, sellerUid) {
  const seller = await db.doc(`User/${text(sellerUid, 128) || "_"}`).get();
  if (!seller.exists || seller.get("role") !== "Seller") {
    throw err("invalid-argument", "Commerce introuvable.");
  }
  return seller;
}

/** Mises en avant proposées par l'application vendeur (champ specifications). */
const PRODUCT_TAGS = ["", "Nouveauté", "Tendance"];

/**
 * Création (sans id) ou modification d'un produit, pour un commerce. Mêmes
 * champs et mêmes règles que le formulaire de l'application vendeur :
 * on_sale = publié (visible des clients, photo obligatoire), sale_price =
 * prix de vente, instant_disponibilty = livraison express.
 */
async function saveProduct({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const id = text(data.id, 128);
  const name = text(data.name, 120);
  if (!name) throw err("invalid-argument", "Nom du produit manquant.");
  const price = amountOf(data.price, "Prix");
  if (price === 0) throw err("invalid-argument", "Indiquez le prix.");
  const quantity = amountOf(data.quantity, "Stock");
  const tag = text(data.tag, 30);
  if (!PRODUCT_TAGS.includes(tag)) {
    throw err("invalid-argument", "Mise en avant inconnue.");
  }
  const published = data.published !== false;
  const values = {
    name,
    description: text(data.description, 2000),
    specifications: tag,
    price,
    sale_price: price,
    quantity,
    on_sale: published,
    section: text(data.section, 60),
    unit: text(data.unit, 30),
    requires_prescription: data.requiresPrescription === true,
    instant_disponibilty: data.express === true,
    modified_at: ts(),
  };
  let ref;
  let current = null;
  if (id) {
    ref = db.doc(`Product/${id}`);
    current = await ref.get();
    if (!current.exists) throw err("not-found", "Produit introuvable.");
    if (data.sellerUid && data.sellerUid !== current.get("seller_ref").id) {
      throw err("invalid-argument",
          "Un produit ne change pas de commerce : créez-le dans l'autre.");
    }
  }
  values.prod_img = data.prodImg === undefined && current ?
    current.get("prod_img") || "" :
    imageOf(data.prodImg, {keep: current ? current.get("prod_img") : null});
  const sellerDoc = current ?
    await current.get("seller_ref").get() :
    await sellerOf(db, data.sellerUid);
  // Restaurants : un plat peut être publié sans photo (vignette affichée).
  if (published && !values.prod_img &&
    !PHOTO_OPTIONAL.includes(sellerDoc.get("category"))) {
    throw err("invalid-argument",
        "Ajoutez une photo avant de publier ce produit.");
  }
  if (current) {
    await ref.update(values);
  } else {
    const seller = await sellerOf(db, data.sellerUid);
    ref = db.collection("Product").doc();
    await ref.set({...values, seller_ref: seller.ref, options: [],
      created_at: ts()});
  }
  await db.runTransaction(async (tx) => audit(tx, db, {actorUid: adminUid,
    actorRole: "Admin", action: id ? "product.update" : "product.create",
    target: ref.path, details: {name, price, published}}));
  return {id: ref.id};
}

/**
 * Suppression d'un produit : il disparaît aussi des paniers en cours. Les
 * commandes passées gardent leur copie (nom, prix, image).
 */
async function deleteProduct({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const reason = text(data.reason, 300);
  if (!reason) throw err("invalid-argument", "Indiquez le motif.");
  const ref = db.doc(`Product/${text(data.id, 128) || "_"}`);
  const p = await ref.get();
  if (!p.exists) throw err("not-found", "Produit introuvable.");
  const carts = await db.collection("Cart").where("product_ref", "==", ref)
      .limit(BATCH).get();
  const batch = db.batch();
  for (const c of carts.docs) {
    if (c.get("is_ordered") !== true) batch.delete(c.ref);
  }
  batch.delete(ref);
  batch.create(db.collection("audit_logs").doc(), {actor_uid: adminUid,
    actor_role: "Admin", action: "product.delete", target: ref.path,
    details: {name: p.get("name"), reason}, created_at: ts()});
  await batch.commit();
  return {cartsCleared: carts.docs.filter((c) => c.get("is_ordered") !== true)
      .length};
}

async function listProducts(db, data) {
  const sellerUid = text(data.sellerUid, 128);
  const q = text(data.q, 60).toLowerCase();
  let query = db.collection("Product");
  // Pas de tri côté base : les anciens produits sans created_at seraient omis.
  if (sellerUid) {
    query = query.where("seller_ref", "==", db.doc(`User/${sellerUid}`));
  }
  const snap = await query.limit(1000).get();
  const sellerIds = [...new Set(snap.docs.map((d) => {
    const r = d.get("seller_ref");
    return r && r.id;
  }).filter(Boolean))];
  const sellers = await Promise.all(sellerIds.map((s) =>
    db.doc(`User/${s}`).get()));
  const sellerMap = Object.fromEntries(sellers.map((s) => [s.id, s]));
  let list = snap.docs.map((d) => {
    const p = d.data();
    const s = sellerMap[p.seller_ref && p.seller_ref.id];
    // Prix de vente : comme l'application (sale_price s'il est renseigné).
    const sale = Math.round(Number(p.sale_price) || 0);
    return {id: d.id, name: p.name || "", description: p.description || "",
      tag: p.specifications || "",
      price: sale > 0 ? sale : Math.round(Number(p.price) || 0),
      // Publié : champ absent = publié (anciens produits), comme l'appli.
      published: p.on_sale !== false, section: p.section || "",
      unit: p.unit || "", quantity: p.quantity ?? null,
      prodImg: p.prod_img || "", express: p.instant_disponibilty === true,
      requiresPrescription: p.requires_prescription === true,
      createdAt: iso(p.created_at),
      seller: s && s.exists ? {uid: s.id, name: s.get("display_name") || "",
        category: s.get("category") || ""} : null};
  });
  if (q) {
    list = list.filter((p) => p.name.toLowerCase().includes(q) ||
      (p.seller && p.seller.name.toLowerCase().includes(q)) ||
      p.section.toLowerCase().includes(q));
  }
  if (data.missingImage === true) list = list.filter((p) => !p.prodImg);
  if (text(data.category, 40)) {
    list = list.filter((p) => p.seller && p.seller.category === data.category);
  }
  list.sort((a, b) => (b.createdAt || "").localeCompare(a.createdAt || "") ||
    a.name.localeCompare(b.name, "fr"));
  return list.slice(0, 300);
}

// ── Commerçants et livreurs ──────────────────────────────────────────────

async function listPartners(db, data) {
  const role = data.role === "Deliver" ? "Deliver" : "Seller";
  const q = text(data.q, 60).toLowerCase();
  const snap = await db.collection("User").where("role", "==", role)
      .limit(1000).get();
  let docs = snap.docs;
  if (q) {
    docs = docs.filter((d) => [d.get("display_name"), d.get("email"),
      d.get("phone_number")].some((v) => String(v || "").toLowerCase()
        .includes(q)));
  }
  if (role === "Seller" && text(data.category, 40)) {
    docs = docs.filter((d) => d.get("category") === data.category);
  }
  docs = docs.slice(0, 300);
  const counts = role === "Seller" ? await Promise.all(docs.map((d) =>
    db.collection("Product").where("seller_ref", "==", d.ref).count().get())) :
    [];
  const list = docs.map((d, i) => {
    const u = d.data();
    return {uid: d.id, role, displayName: u.display_name || "",
      email: u.email || "", phone: u.phone_number || "",
      category: u.category || "", bio: u.bio || "",
      horraire: u.Horraire || "", photoUrl: u.photo_url || "",
      businessCover: u.Business_cover || "", verified: u.verified === true,
      accountStatus: u.account_status || "active",
      accountStatusReason: u.account_status_reason || null,
      createdAt: iso(u.created_time),
      cuisines: Array.isArray(u.cuisines) ? u.cuisines : [],
      products: role === "Seller" ? counts[i].data().count : null};
  });
  list.sort((a, b) => a.displayName.localeCompare(b.displayName, "fr"));
  return list;
}

/** Modification de la fiche d'un commerçant, d'un livreur ou d'un client. */
async function savePartner({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`User/${text(data.uid, 128) || "_"}`);
  const u = await ref.get();
  const role = u.exists ? u.get("role") || "User" : null;
  if (!["Seller", "Deliver", "User"].includes(role)) {
    throw err("not-found", "Compte introuvable.");
  }
  // Fiche client : nom et téléphone seulement.
  if (role === "User" && ["category", "bio", "horraire", "businessCover",
    "verified"].some((k) => data[k] !== undefined)) {
    throw err("invalid-argument", "Champ non modifiable pour un client.");
  }
  const changes = {};
  if (data.displayName !== undefined) {
    changes.display_name = text(data.displayName, 80);
    if (!changes.display_name) throw err("invalid-argument", "Nom manquant.");
  }
  if (data.phone !== undefined) {
    const phone = text(data.phone, 20);
    if (phone && !normalizePhone(phone)) {
      throw err("invalid-argument", "Numéro de téléphone invalide.");
    }
    changes.phone_number = phone;
  }
  if (data.category !== undefined && role === "Seller") {
    const name = text(data.category, 40);
    const exists = await db.collection(CATEGORIES)
        .where("name", "==", name).limit(1).get();
    if (exists.empty) throw err("invalid-argument", "Catégorie inconnue.");
    changes.category = name;
  }
  if (data.bio !== undefined) changes.bio = text(data.bio, 500);
  if (data.horraire !== undefined) changes.Horraire = text(data.horraire, 120);
  if (data.photoUrl !== undefined) {
    changes.photo_url = imageOf(data.photoUrl, {keep: u.get("photo_url")});
  }
  if (data.businessCover !== undefined) {
    changes.Business_cover = imageOf(data.businessCover,
        {keep: u.get("Business_cover")});
  }
  if (data.verified !== undefined) changes.verified = data.verified === true;
  if (data.cuisines !== undefined && role === "Seller") {
    if (!Array.isArray(data.cuisines) || data.cuisines.length > 8) {
      throw err("invalid-argument", "Cuisines : 8 au maximum.");
    }
    changes.cuisines = [...new Set(data.cuisines
        .map((c) => text(c, 40)).filter(Boolean))];
  }
  if (Object.keys(changes).length === 0) {
    throw err("invalid-argument", "Aucune modification.");
  }
  await db.runTransaction(async (tx) => {
    tx.update(ref, changes);
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "partner.update", target: ref.path,
      details: {fields: Object.keys(changes)}});
  });
  return {ok: true};
}

async function listClients(db, data) {
  const q = text(data.q, 60).toLowerCase();
  const snap = await db.collection("User").where("role", "==", "User")
      .limit(2000).get();
  let docs = snap.docs;
  if (q) {
    docs = docs.filter((d) => [d.get("display_name"), d.get("email"),
      d.get("phone_number")].some((v) => String(v || "").toLowerCase()
        .includes(q)));
  }
  const list = docs.map((d) => {
    const u = d.data();
    return {uid: d.id, displayName: u.display_name || "", email: u.email || "",
      phone: u.phone_number || "", photoUrl: u.photo_url || "",
      createdAt: iso(u.created_time), subscribeCloseAt: iso(u.subscribe_close_at),
      accountStatus: u.account_status || "active"};
  });
  list.sort((a, b) => (b.createdAt || "").localeCompare(a.createdAt || ""));
  return {clients: list.slice(0, 300), total: docs.length};
}

/**
 * Catégories visibles, pour l'application (accueil, recherche). Tant que
 * l'admin n'a rien enregistré, ce sont les 5 d'origine.
 */
async function publicCategories({db}) {
  const snap = await db.collection(CATEGORIES).orderBy("order").get();
  const list = snap.empty ? DEFAULT_CATEGORIES.map((c, i) => ({...c,
    order: i, active: true})) : snap.docs.map((d) => d.data());
  return {categories: list.filter((c) => c.active !== false).map((c) => ({
    name: c.name, image: c.image || "", color: c.color || "#F2F2F5"}))};
}

/** Lectures de l'interface admin (catalogue, partenaires, clients). */
async function catalogQuery({db, uid, data}) {
  await requireAdmin(db, uid);
  switch (text(data.view, 20)) {
    case "categories": return {categories: await listCategories(db, uid)};
    case "products": return {products: await listProducts(db, data)};
    case "partners": return {partners: await listPartners(db, data)};
    case "clients": return listClients(db, data);
    default: throw err("invalid-argument", "Vue inconnue.");
  }
}

/**
 * Import d'un menu (admin) : crée les plats d'un commerce en une fois.
 * items : [{section, name, price, description?}] ; les plats déjà présents
 * (même nom) sont ignorés. sideOption : groupe d'options ajouté aux plats
 * (hors accompagnements et boissons), ex. « Accompagnement (+500 F) ».
 */
async function importMenu({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const seller = await sellerOf(db, data.sellerUid);
  const items = Array.isArray(data.items) ? data.items : [];
  if (items.length === 0 || items.length > 300) {
    throw err("invalid-argument", "Menu vide ou trop long (300 plats au plus).");
  }
  const clean = items.map((it, i) => {
    const name = text(it && it.name, 120);
    if (!name) throw err("invalid-argument", `Ligne ${i + 1} : nom manquant.`);
    const price = amountOf(it.price, `Ligne ${i + 1} (${name}) : prix`);
    if (price === 0) {
      throw err("invalid-argument", `Ligne ${i + 1} (${name}) : prix manquant.`);
    }
    return {name, price, section: text(it.section, 60),
      description: text(it.description, 2000)};
  });
  let option = null;
  if (data.sideOption) {
    const o = data.sideOption;
    const choices = (Array.isArray(o.choices) ? o.choices : [])
        .map((c) => ({label: text(c.label, 60),
          price: amountOf(c.price, "Option : prix")}))
        .filter((c) => c.label);
    if (choices.length === 0) {
      throw err("invalid-argument", "Option : aucun choix.");
    }
    option = {name: text(o.name, 60) || "Accompagnement", required: false,
      max: 0, choices};
  }
  // Portions disponibles par plat (le restaurant les ajuste ensuite) :
  // sans stock, un plat ne peut pas être commandé.
  const portions = data.portions === undefined ? 50 :
    amountOf(data.portions, "Portions");
  if (portions > 100000) {
    throw err("invalid-argument", "Portions : 100 000 au plus.");
  }
  const photoOptional = PHOTO_OPTIONAL.includes(seller.get("category"));
  // draft : prix à confirmer par le commerce avant publication.
  const publish = photoOptional && data.draft !== true;
  const existing = await db.collection("Product")
      .where("seller_ref", "==", seller.ref).get();
  const known = new Set(existing.docs
      .map((d) => String(d.get("name") || "").trim().toLowerCase()));
  const noOption = /accompagnement|boisson|sauce|dessert|emballage/i;
  const created = [];
  const skipped = [];
  let batch = db.batch();
  let n = 0;
  for (const it of clean) {
    const key = it.name.toLowerCase();
    if (known.has(key)) {
      skipped.push(it.name);
      continue;
    }
    known.add(key);
    const ref = db.collection("Product").doc();
    batch.set(ref, {
      name: it.name, description: it.description, specifications: "",
      price: it.price, sale_price: it.price, section: it.section, unit: "",
      quantity: portions,
      prod_img: "", requires_prescription: false,
      instant_disponibilty: false,
      // Sans photo, publié seulement pour les restaurants.
      on_sale: publish,
      options: option && !noOption.test(it.section) ? [option] : [],
      seller_ref: seller.ref, created_at: ts(), modified_at: ts(),
    });
    created.push(it.name);
    if (++n % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  await batch.commit();
  await db.collection("audit_logs").add({actor_uid: adminUid,
    actor_role: "Admin", action: "product.import", target: seller.ref.path,
    details: {created: created.length, skipped: skipped.length},
    created_at: ts()});
  return {created: created.length, skipped, published: publish};
}

module.exports = {catalogQuery, importMenu, publicCategories, seedCategories, saveCategory, deleteCategory,
  saveProduct, deleteProduct, savePartner, DEFAULT_CATEGORIES, imageOf};
