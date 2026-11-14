/**
 * Frais de livraison selon la distance entre le quartier du commerce et
 * celui du client. Le tarif est réglé par l'admin (Settings/delivery_pricing)
 * et le serveur fait seul le calcul.
 *
 *   frais = base + prix_par_km × distance × coefficient_route
 *   arrondi à « arrondi » F au-dessus, entre « minimum » et « maximum ».
 *
 * La distance est mesurée entre les centres des deux quartiers (vol
 * d'oiseau) ; le coefficient route (1,3 par défaut) tient compte des
 * détours des rues. Commerce sans quartier renseigné ou mode « zones » :
 * ancien tarif par quartier du client (pricing.js).
 */
const admin = require("firebase-admin");
const {AcquisitionError} = require("./acquisition/model");
const {requireAdmin} = require("./acquisition/agents");
const {deliveryFee: zoneFee, ZONES} = require("./pricing");

const err = (code, message) => new AcquisitionError(code, message);
const SETTINGS = "Settings/delivery_pricing";

/** Centre approximatif de chaque quartier (même liste que la carte admin). */
const ZONE_POINTS = {
  "Makélékélé": [-4.2905, 15.2345],
  "Centre sportif": [-4.2840, 15.2420],
  "Kinsoundi": [-4.3045, 15.2255],
  "Diata": [-4.2720, 15.2195],
  "Kingouari": [-4.2950, 15.2455],
  "Moukoundzi-Ngouaka": [-4.2880, 15.2205],
  "Château d'eau": [-4.2745, 15.2340],
  "Barrage": [-4.2975, 15.2215],
  "Bacongo": [-4.2805, 15.2560],
  "Mpissa": [-4.2660, 15.2495],
  "Poto-Poto": [-4.2560, 15.2720],
  "Centre-ville": [-4.2685, 15.2830],
  "Moungali": [-4.2485, 15.2620],
  "O.C.H": [-4.2425, 15.2560],
  "Plateau des 15 ans": [-4.2565, 15.2560],
  "Batignolles": [-4.2425, 15.2705],
  "Moukondo": [-4.2385, 15.2500],
  "Avenue de la Paix": [-4.2505, 15.2650],
  "Marché Moungali": [-4.2470, 15.2600],
  "Académie": [-4.2600, 15.2780],
  "Ouenzé": [-4.2300, 15.2650],
  "Mapassi": [-4.2285, 15.2550],
  "Mpila": [-4.2400, 15.2950],
  "La Tsiémé": [-4.2250, 15.2795],
  "Talangaï": [-4.2080, 15.2800],
  "Mikalou": [-4.2050, 15.2650],
  "Ngamakosso": [-4.1950, 15.2900],
  "Ma-Mboualé": [-4.2150, 15.2705],
  "Kanga Mbandz": [-4.2005, 15.2750],
  "Mfilou": [-4.2550, 15.2050],
  "Sadelmi": [-4.2350, 15.2400],
  "La Base": [-4.2450, 15.2450],
  "Mazala": [-4.2200, 15.2600],
  "Cité des 17": [-4.2300, 15.2350],
  "Soprogie": [-4.2380, 15.2895],
  "Madibou": [-4.3100, 15.2050],
  "Mansimou": [-4.3150, 15.2200],
  "Mafouta": [-4.2850, 15.1950],
  "Massissia": [-4.3300, 15.2000],
  "Djiri": [-4.1700, 15.2700],
  "Ndjiri": [-4.1700, 15.2700],
  "Massengo": [-4.1600, 15.2650],
  "Kombo": [-4.3060, 15.2150],
  "Kintélé": [-4.1250, 15.3200],
  "Makabandilou": [-4.1500, 15.2750],
  "Mayanga": [-4.3400, 15.1900],
  "Moussosso": [-4.3350, 15.2100],
  "Mbouono": [-4.3000, 15.1850],
  "Kombé": [-4.3500, 15.2000],
  "Kibina": [-4.3250, 15.1950],
  "Nganga-Lingolo": [-4.3700, 15.1700]
};

const DEFAULTS = {
  mode: "distance", // « distance » ou « zones » (ancien tarif)
  base: 500,
  per_km: 150,
  road_factor: 1.3,
  minimum: 1000,
  maximum: 5000,
  rounding: 100,
};

/** Distance à vol d'oiseau en km entre deux quartiers, ou null. */
function zoneDistanceKm(a, b) {
  const p = ZONE_POINTS[a];
  const q = ZONE_POINTS[b];
  if (!p || !q) return null;
  const rad = (d) => d * Math.PI / 180;
  const h = Math.sin(rad(q[0] - p[0]) / 2) ** 2 + Math.cos(rad(p[0])) *
    Math.cos(rad(q[0])) * Math.sin(rad(q[1] - p[1]) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

/** Réglages enregistrés, complétés par les valeurs par défaut. */
async function loadSettings(db) {
  const s = await db.doc(SETTINGS).get();
  return {...DEFAULTS, ...(s.exists ? s.data() : {})};
}

/**
 * Frais d'une livraison. Renvoie {fee, km, mode}.
 * km : distance retenue (route estimée), null en mode « zones ».
 */
/**
 * Point GPS valide dans l'agglomération de Brazzaville ({lat, lng}), ou
 * null. Sert pour la position exacte du client et du commerce.
 */
function pointOf(v) {
  if (!v || typeof v !== "object") return null;
  const lat = Number(v.lat);
  const lng = Number(v.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat < -4.6 || lat > -3.9 || lng < 14.9 || lng > 15.6) return null;
  return {lat: Math.round(lat * 1e6) / 1e6, lng: Math.round(lng * 1e6) / 1e6};
}

function haversineKm(a, b) {
  const rad = (d) => d * Math.PI / 180;
  const h = Math.sin(rad(b[0] - a[0]) / 2) ** 2 + Math.cos(rad(a[0])) *
    Math.cos(rad(b[0])) * Math.sin(rad(b[1] - a[1]) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

/**
 * Frais d'une livraison, de porte à porte quand les positions exactes sont
 * connues (shopPoint, clientPoint), sinon d'un centre de quartier à l'autre.
 * Renvoie {fee, km, mode, exact}.
 */
/** Points de départ et d'arrivée [lat, lng] (exacts, sinon quartiers). */
function endpoints({shopZone, clientZone, shopPoint, clientPoint}) {
  const from = pointOf(shopPoint);
  const to = pointOf(clientPoint);
  return {a: from ? [from.lat, from.lng] : ZONE_POINTS[shopZone] || null,
    b: to ? [to.lat, to.lng] : ZONE_POINTS[clientZone] || null,
    exact: !!(from && to)};
}

/**
 * roadKm : distance réelle par la route (service d'itinéraire). Sans elle,
 * estimation à vol d'oiseau × coefficient route (source « estimate »).
 */
function computeFee({shopZone, clientZone, shopPoint, clientPoint,
  settings = DEFAULTS, roadKm = null}) {
  const s = {...DEFAULTS, ...settings};
  const {a, b, exact} = endpoints({shopZone, clientZone, shopPoint,
    clientPoint});
  const straight = s.mode === "distance" && a && b ? haversineKm(a, b) : null;
  if (straight == null) {
    return {fee: zoneFee(clientZone), km: null, mode: "zones", exact: false,
      source: "zones"};
  }
  const road = Number.isFinite(roadKm) && roadKm >= 0;
  const km = road ? roadKm : straight * Number(s.road_factor);
  const step = Math.max(1, Number(s.rounding) || 1);
  let fee = Math.ceil((Number(s.base) + Number(s.per_km) * km) / step) * step;
  fee = Math.max(Number(s.minimum) || 0, fee);
  if (Number(s.maximum) > 0) fee = Math.min(Number(s.maximum), fee);
  return {fee, km: Math.round(km * 10) / 10, mode: "distance", exact,
    source: road ? "route" : "estimate"};
}

/** Frais pour un commerce (document User), le quartier et la position du
 * client. */
async function feeFor(db, seller, clientZone, settings, clientPoint,
    http) {
  const ok = seller && seller.exists;
  const args = {shopZone: ok ? seller.get("shop_zone") : null,
    shopPoint: ok ? seller.get("shop_point") : null, clientZone,
    clientPoint, settings: settings || await loadSettings(db)};
  // Distance réelle par la route quand un service est configuré.
  const {a, b} = endpoints(args);
  const r = args.settings.mode !== "zones" && a && b ?
    await require("./routing").route({db, from: a, to: b,
      ...(http ? {http} : {})}) : null;
  return computeFee({...args, roadKm: r ? r.km : null});
}

/** Devis affiché au client dans le panier, avant le paiement. */
async function deliveryQuote({db, uid, data}) {
  if (!uid) throw err("unauthenticated", "Connexion requise.");
  const zone = String(data.zone || "");
  const path = String(data.sellerPath || "");
  if (!/^User\/[A-Za-z0-9]{1,128}$/.test(path)) {
    throw err("invalid-argument", "Commerce invalide.");
  }
  const seller = await db.doc(path).get();
  const r = await feeFor(db, seller, zone, null, data.point);
  return {...r, shopZone: seller.exists ? seller.get("shop_zone") || "" : ""};
}

const num = (v, min, max) => {
  const n = Number(v);
  if (!Number.isFinite(n) || n < min || n > max) {
    throw err("invalid-argument", "Valeur de tarif invalide.");
  }
  return n;
};

/** L'admin lit (data.save absent) ou enregistre le tarif. */
async function adminDeliveryPricing({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  if (data.save) {
    const s = data.save;
    const next = {
      mode: s.mode === "zones" ? "zones" : "distance",
      base: num(s.base, 0, 100000),
      per_km: num(s.per_km, 0, 100000),
      road_factor: num(s.road_factor, 1, 3),
      minimum: num(s.minimum, 0, 100000),
      maximum: num(s.maximum, 0, 1000000),
      rounding: num(s.rounding, 1, 1000),
    };
    await db.doc(SETTINGS).set({...next, updated_by: adminUid,
      updated_at: admin.firestore.FieldValue.serverTimestamp()});
    await db.collection("audit_logs").add({actor_uid: adminUid,
      actor_role: "Admin", action: "delivery_pricing.update",
      target: SETTINGS, details: next,
      created_at: admin.firestore.FieldValue.serverTimestamp()});
  }
  const settings = await loadSettings(db);
  const out = {};
  for (const k of Object.keys(DEFAULTS)) out[k] = settings[k];
  return {settings: out, zones: ZONES};
}

module.exports = {pointOf, haversineKm, ZONE_POINTS, DEFAULTS, zoneDistanceKm, computeFee, feeFor,
  loadSettings, deliveryQuote, adminDeliveryPricing};
