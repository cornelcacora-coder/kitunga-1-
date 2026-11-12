/**
 * Calcul des montants côté serveur : le montant envoyé par l'application
 * n'est jamais utilisé tel quel.
 *
 * Doit rester identique à getDeliveryFeeForZone (cart_last_widget.dart) et
 * au modèle d'options (lib/backend/kitunga_options.dart).
 */

const ZONE_FEES = [
  [1000, ["Makélékélé", "Centre sportif", "Kinsoundi", "Diata", "Kingouari",
    "Moukoundzi-Ngouaka", "Château d'eau", "Barrage", "Bacongo", "Mpissa",
    "Poto-Poto", "Centre-ville", "Moungali", "O.C.H", "Plateau des 15 ans",
    "Batignolles", "Moukondo", "Avenue de la Paix", "Marché Moungali",
    "Académie"]],
  [1500, ["Ouenzé", "Mapassi", "Mpila", "La Tsiémé", "Talangaï", "Mikalou",
    "Ngamakosso", "Ma-Mboualé", "Kanga Mbandz", "Mfilou", "Sadelmi",
    "La Base", "Mazala", "Cité des 17", "Soprogie"]],
  [2000, ["Madibou", "Mansimou", "Mafouta", "Massissia", "Djiri", "Ndjiri",
    "Massengo", "Kombo", "Kintélé", "Makabandilou"]],
  [2500, ["Mayanga", "Moussosso", "Mbouono", "Kombé", "Kibina",
    "Nganga-Lingolo"]],
];

function deliveryFee(zone) {
  if (!zone) return 1000;
  for (const [fee, zones] of ZONE_FEES) {
    if (zones.includes(zone)) return fee;
  }
  return 1000;
}

function basePrice(product) {
  const sale = Math.round(Number(product.sale_price) || 0);
  return sale > 0 ? sale : Math.round(Number(product.price) || 0);
}

/**
 * Relit le résumé des options enregistré dans le panier
 * (« Taille : Maxi · Suppléments : Fromage, Œuf ») et le confronte aux
 * options réelles du produit. Renvoie le supplément et les choix retenus,
 * ou une erreur si un choix n'existe pas / un groupe obligatoire manque.
 */
function resolveOptions(summary, groups) {
  groups = Array.isArray(groups) ? groups : [];
  const chosen = new Map(); // nom du groupe -> [libellés]
  for (const part of String(summary || "").split(" · ")) {
    if (!part.trim()) continue;
    const idx = part.indexOf(" : ");
    if (idx < 0) return {error: `Option illisible : « ${part} »`};
    const name = part.slice(0, idx).trim();
    const labels = part.slice(idx + 3).split(", ").map((l) => l.trim());
    chosen.set(name, labels);
  }
  let extra = 0;
  const picks = []; // {group, choice} pour les stocks de variantes
  for (const g of groups) {
    const labels = chosen.get(g.name) || [];
    chosen.delete(g.name);
    if (g.required && labels.length === 0) {
      return {error: `Choix obligatoire manquant : ${g.name}`};
    }
    const max = Number(g.max ?? 1);
    if (max > 0 && labels.length > max) {
      return {error: `Trop de choix pour ${g.name}`};
    }
    for (const label of labels) {
      const c = (g.choices || []).find((x) => x.label === label);
      if (!c) return {error: `Choix inconnu : ${g.name} / ${label}`};
      extra += Math.round(Number(c.price) || 0);
      picks.push({group: g.name, choice: label});
    }
  }
  if (chosen.size > 0) {
    return {error: `Option inconnue : ${[...chosen.keys()].join(", ")}`};
  }
  return {extra, picks};
}

/**
 * Lignes du panier + produits -> montants et contrôles de stock.
 * lines : [{quantity, options, product: {données du produit}}]
 */
/**
 * prescriptionOk : une ordonnance validée par la pharmacie couvre les
 * médicaments sur ordonnance du panier (voir prescriptions.js).
 */
function priceCart(lines, zone, {prescriptionOk = false} = {}) {
  const errors = [];
  let needsPrescription = false;
  let subtotal = 0;
  const priced = [];
  for (const line of lines) {
    const p = line.product;
    const qty = Math.max(1, Math.round(Number(line.quantity) || 1));
    if (!p) {
      errors.push("Un produit du panier n'existe plus.");
      continue;
    }
    if (p.on_sale === false) errors.push(`« ${p.name} » n'est plus en vente.`);
    if (p.requires_prescription === true) {
      needsPrescription = true;
      if (!prescriptionOk) {
        errors.push(`« ${p.name} » nécessite une ordonnance validée par la ` +
          "pharmacie : envoyez-la depuis la fiche du médicament.");
      }
    }
    if ((Number(p.quantity) || 0) < qty) {
      errors.push(`Stock insuffisant pour « ${p.name} ».`);
    }
    const opt = resolveOptions(line.options, p.options);
    if (opt.error) {
      errors.push(`${p.name} : ${opt.error}`);
      continue;
    }
    for (const pick of opt.picks) {
      const g = (p.options || []).find((x) => x.name === pick.group);
      const c = g && (g.choices || []).find((x) => x.label === pick.choice);
      if (c && c.stock != null && Number(c.stock) < qty) {
        errors.push(`Stock insuffisant : ${p.name} (${pick.choice}).`);
      }
    }
    const unit = basePrice(p) + opt.extra;
    subtotal += unit * qty;
    priced.push({...line, quantity: qty, unitPrice: unit, picks: opt.picks});
  }
  const fee = deliveryFee(zone);
  return {errors, lines: priced, subtotal, fee, total: subtotal + fee,
    needsPrescription};
}

const ZONES = ZONE_FEES.flatMap(([, zones]) => zones);

module.exports = {deliveryFee, resolveOptions, priceCart, basePrice, ZONES};
