/**
 * Nettoyage des données de test avant le lancement réel (admin seulement).
 *
 * Supprimé : commerçants (role Seller) et livreurs (role Deliver) avec leur
 * compte de connexion et leurs fichiers, tous les produits (et leurs photos),
 * paniers, commandes, articles de commande et paiements de COMMANDES.
 * Conservé : clients, administrateurs, commerciaux, module commercial,
 * catégories, journaux, et les paiements d'ABONNEMENT (kind « subscription »,
 * utilisés par les abonnements et les commissions).
 *
 * Avant toute suppression, chaque document est copié dans
 * purge_backups/{runId}/items et chaque fichier dans
 * purge_backups/{runId}/files/… (Storage) : « restore » les remet en place
 * (sauf les comptes de connexion, qui ne peuvent pas être recréés avec leur
 * mot de passe).
 */
const admin = require("firebase-admin");
const {AcquisitionError} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const err = (code, message) => new AcquisitionError(code, message);
const CONFIRM = "SUPPRIMER";
const BATCH = 200; // copie + suppression = 400 écritures par lot

/** Chemin Storage d'une adresse de téléchargement Firebase (ou null). */
function storagePath(url) {
  if (typeof url !== "string" || !url.startsWith("https://")) return null;
  try {
    const u = new URL(url);
    if (u.hostname === "firebasestorage.googleapis.com") {
      const m = u.pathname.match(/\/o\/(.+)$/);
      return m ? decodeURIComponent(m[1]) : null;
    }
    if (u.hostname === "storage.googleapis.com") {
      // /bucket/chemin
      return decodeURIComponent(u.pathname.split("/").slice(2).join("/")) ||
        null;
    }
  } catch (_) {
    return null;
  }
  return null;
}

/** Ce qui sera supprimé (lecture seule). */
async function collect(db) {
  const [users, products, orders, items, carts, payments] = await Promise.all([
    db.collection("User").where("role", "in", ["Seller", "Deliver"]).get(),
    db.collection("Product").get(),
    db.collection("Orders").get(),
    db.collection("OrderItems").get(),
    db.collection("Cart").get(),
    db.collection("Paiement").get(),
  ]);
  const sellers = users.docs.filter((d) => d.get("role") === "Seller");
  const delivers = users.docs.filter((d) => d.get("role") === "Deliver");
  // Paiements d'abonnement conservés (abonnements et commissions).
  const orderPayments = payments.docs
      .filter((d) => d.get("kind") !== "subscription");
  return {
    sellers, delivers,
    products: products.docs,
    orders: orders.docs,
    orderItems: items.docs,
    carts: carts.docs,
    payments: orderPayments,
    keptSubscriptionPayments: payments.size - orderPayments.length,
  };
}

const counts = (c) => ({
  sellers: c.sellers.length,
  delivers: c.delivers.length,
  products: c.products.length,
  orders: c.orders.length,
  orderItems: c.orderItems.length,
  carts: c.carts.length,
  payments: c.payments.length,
  keptSubscriptionPayments: c.keptSubscriptionPayments,
});

/** Fichiers à supprimer : dossiers des partenaires + photos de produits. */
async function filesToDelete(db, bucket, c) {
  const owners = new Set([...c.sellers, ...c.delivers].map((d) => d.id));
  const paths = new Set();
  for (const uid of owners) {
    const [files] = await bucket.getFiles({prefix: `users/${uid}/`});
    for (const f of files) paths.add(f.name);
  }
  // Photos de produits rangées ailleurs (ex. envoyées par l'admin), jamais
  // dans le dossier d'un client.
  const clientFolder = async (uid) => {
    const u = await db.doc(`User/${uid}`).get();
    return u.exists && (u.get("role") || "User") === "User";
  };
  for (const p of c.products) {
    const path = storagePath(p.get("prod_img"));
    if (!path || !path.startsWith("users/")) continue;
    const owner = path.split("/")[1];
    if (owners.has(owner) || !(await clientFolder(owner))) paths.add(path);
  }
  return [...paths];
}

async function preview({db, uid}) {
  await requireAdmin(db, uid);
  const c = await collect(db);
  const name = (d) => d.get("display_name") || d.get("email") || d.id;
  return {
    counts: counts(c),
    sellers: c.sellers.slice(0, 50).map(name),
    delivers: c.delivers.slice(0, 50).map(name),
  };
}

/** Copie puis supprime une liste de documents, par lots. */
async function backupAndDelete(db, runId, docs) {
  for (let i = 0; i < docs.length; i += BATCH) {
    const batch = db.batch();
    for (const d of docs.slice(i, i + BATCH)) {
      const col = d.ref.parent.id;
      batch.set(db.doc(`purge_backups/${runId}/items/${col}__${d.id}`),
          {collection: col, id: d.id, data: d.data()});
      batch.delete(d.ref);
    }
    await batch.commit();
  }
}

async function purge({db, auth, bucket, uid, data, clock = () => new Date()}) {
  const adminUid = await requireAdmin(db, uid);
  if (data.confirm !== CONFIRM) {
    throw err("failed-precondition",
        `Tapez ${CONFIRM} pour confirmer la suppression.`);
  }
  const c = await collect(db);
  const runId = clock().toISOString().replace(/[-:]/g, "").slice(0, 15);
  const runRef = db.doc(`purge_backups/${runId}`);
  await runRef.set({created_at: ts(), by: adminUid, status: "en cours",
    counts: counts(c)});

  // 1. Fichiers : copie de sécurité puis suppression.
  const paths = await filesToDelete(db, bucket, c);
  let files = 0;
  for (const p of paths) {
    const f = bucket.file(p);
    try {
      await f.copy(bucket.file(`purge_backups/${runId}/files/${p}`));
      await f.delete();
      files++;
    } catch (e) {
      if (e && e.code !== 404) throw e;
    }
  }

  // 2. Documents : copie puis suppression (commandes avant les comptes).
  for (const docs of [c.carts, c.orderItems, c.payments, c.orders,
    c.products, c.sellers, c.delivers]) {
    await backupAndDelete(db, runId, docs);
  }

  // 3. Comptes de connexion des commerçants et livreurs.
  const uids = [...c.sellers, ...c.delivers].map((d) => d.id);
  let accounts = 0;
  for (let i = 0; i < uids.length; i += 1000) {
    const r = await auth.deleteUsers(uids.slice(i, i + 1000));
    accounts += r.successCount;
  }

  const result = {runId, counts: counts(c), files, accounts};
  await runRef.update({status: "terminé", files, accounts,
    finished_at: ts()});
  await db.collection("audit_logs").add({actor_uid: adminUid,
    actor_role: "Admin", action: "data.purge", target: runRef.path,
    details: {...counts(c), files, accounts}, created_at: ts()});
  return result;
}

/** Remet les documents et fichiers d'un nettoyage (comptes non recréés). */
async function restore({db, bucket, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const runId = typeof data.runId === "string" ? data.runId.trim() : "";
  const runRef = db.doc(`purge_backups/${runId || "_"}`);
  const run = await runRef.get();
  if (!run.exists) throw err("not-found", "Sauvegarde introuvable.");
  const items = await runRef.collection("items").get();
  for (let i = 0; i < items.docs.length; i += 400) {
    const batch = db.batch();
    for (const d of items.docs.slice(i, i + 400)) {
      batch.set(db.doc(`${d.get("collection")}/${d.get("id")}`), d.get("data"));
    }
    await batch.commit();
  }
  const prefix = `purge_backups/${runId}/files/`;
  const [files] = await bucket.getFiles({prefix});
  for (const f of files) {
    await f.copy(bucket.file(f.name.slice(prefix.length)));
  }
  await runRef.update({restored_at: ts(), restored_by: adminUid});
  await db.collection("audit_logs").add({actor_uid: adminUid,
    actor_role: "Admin", action: "data.restore", target: runRef.path,
    details: {documents: items.size, files: files.length}, created_at: ts()});
  return {documents: items.size, files: files.length};
}

/** Liste des nettoyages effectués (sauvegardes disponibles). */
async function history({db, uid}) {
  await requireAdmin(db, uid);
  const snap = await db.collection("purge_backups").get();
  return {runs: snap.docs.map((d) => ({
    runId: d.id, status: d.get("status") || "",
    counts: d.get("counts") || {}, files: d.get("files") ?? null,
    accounts: d.get("accounts") ?? null,
    restored: d.get("restored_at") != null,
  })).sort((a, b) => b.runId.localeCompare(a.runId))};
}

async function purgeTestData(ctx) {
  switch (ctx.data.mode) {
    case "preview": return preview(ctx);
    case "purge": return purge(ctx);
    case "restore": return restore(ctx);
    case "history": return history(ctx);
    default: throw err("invalid-argument", "Mode inconnu.");
  }
}

module.exports = {purgeTestData, storagePath, CONFIRM};
