/**
 * Itinéraires réels par la route (frais de livraison, heure d'arrivée,
 * tracé sur la carte).
 *
 * Secret Firebase ROUTING_API_KEY (scripts/routing_cle.sh) :
 *   google:CLÉ  → Google Routes API : vraies routes ET circulation en
 *                 temps réel (heure d'arrivée).
 *   ors:CLÉ     → OpenRouteService : vraies routes (OpenStreetMap), sans
 *                 la circulation.
 *   absent      → pas de service : l'application utilise l'estimation
 *                 (vol d'oiseau × coefficient) et l'indique comme telle.
 *
 * Les trajets sans circulation sont gardés 30 jours (RouteCache) pour que
 * le devis du panier et le paiement donnent exactement le même prix, et
 * pour limiter le coût des appels.
 */
const axios = require("axios").default;

const CACHE_DAYS = 30;
const MAX_POINTS = 120;

function config() {
  const raw = String(process.env.ROUTING_API_KEY || "").replace(/\s+/g, "");
  if (!raw || raw === "absent") return null;
  const i = raw.indexOf(":");
  if (i < 0) return null;
  const provider = raw.slice(0, i);
  const key = raw.slice(i + 1);
  if (!key || !["google", "ors"].includes(provider)) return null;
  return {provider, key};
}

/** Polyligne encodée (précision 5, Google et OpenRouteService). */
function decodePolyline(str) {
  const out = [];
  let i = 0;
  let lat = 0;
  let lng = 0;
  while (i < str.length) {
    for (const axis of [0, 1]) {
      let shift = 0;
      let result = 0;
      let b;
      do {
        b = str.charCodeAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && i < str.length);
      const d = result & 1 ? ~(result >> 1) : result >> 1;
      if (axis === 0) lat += d;
      else lng += d;
    }
    out.push([lat / 1e5, lng / 1e5]);
  }
  return out;
}

/** Tracé allégé (Firestore et téléphone) : au plus MAX_POINTS points. */
function simplify(points) {
  if (points.length <= MAX_POINTS) return points;
  const step = Math.ceil(points.length / MAX_POINTS);
  const kept = points.filter((_, i) => i % step === 0);
  const last = points[points.length - 1];
  if (kept[kept.length - 1] !== last) kept.push(last);
  return kept;
}

const r4 = (v) => Math.round(v * 1e4) / 1e4;

async function callProvider(cfg, from, to, traffic, http) {
  if (cfg.provider === "google") {
    // Google Routes API (remplace l'ancienne Directions API pour les
    // nouveaux projets). Circulation : TRAFFIC_AWARE (heure d'arrivée).
    const latLng = (p) => ({location: {latLng: {latitude: p[0],
      longitude: p[1]}}});
    const res = await http.post(
        "https://routes.googleapis.com/directions/v2:computeRoutes", {
          origin: latLng(from), destination: latLng(to),
          travelMode: "DRIVE",
          routingPreference: traffic ? "TRAFFIC_AWARE" : "TRAFFIC_UNAWARE",
          languageCode: "fr", regionCode: "cg", units: "METRIC",
        }, {headers: {"Content-Type": "application/json",
          "X-Goog-Api-Key": cfg.key,
          "X-Goog-FieldMask":
            "routes.distanceMeters,routes.duration,routes.polyline"},
        timeout: 10000});
    const route = res.data && res.data.routes && res.data.routes[0];
    if (!route || !(route.distanceMeters >= 0)) return null;
    return {meters: route.distanceMeters,
      seconds: parseInt(String(route.duration || "0s"), 10) || 0,
      polyline: route.polyline && route.polyline.encodedPolyline ?
        decodePolyline(route.polyline.encodedPolyline) : [],
      traffic};
  }
  const res = await http.post(
      "https://api.openrouteservice.org/v2/directions/driving-car",
      {coordinates: [[from[1], from[0]], [to[1], to[0]]]},
      {headers: {"Authorization": cfg.key,
        "Content-Type": "application/json"}, timeout: 10000});
  const route = res.data && res.data.routes && res.data.routes[0];
  if (!route || !route.summary) return null;
  return {meters: route.summary.distance, seconds: route.summary.duration,
    polyline: typeof route.geometry === "string" ?
      decodePolyline(route.geometry) : [], traffic: false};
}

/**
 * Itinéraire réel entre deux points [lat, lng]. Renvoie
 * {km, minutes, polyline: [{lat, lng}], source, traffic} ou null (pas de
 * service configuré, ou service injoignable : à l'appelant de prévoir
 * l'estimation, signalée comme telle).
 * traffic : heure d'arrivée avec la circulation (Google), jamais gardée.
 */
async function route({db, from, to, traffic = false, http = axios,
  now = new Date()}) {
  const cfg = config();
  if (!cfg || !from || !to) return null;
  const id = `${cfg.provider}_${r4(from[0])}_${r4(from[1])}_` +
    `${r4(to[0])}_${r4(to[1])}`.replace(/\./g, "d");
  const ref = db ? db.doc(`RouteCache/${id.replace(/\./g, "d")}`) : null;
  if (ref && !traffic) {
    const c = await ref.get();
    const at = c.exists && c.get("at") && c.get("at").toDate ?
      c.get("at").toDate() : null;
    if (at && now - at < CACHE_DAYS * 86400000) {
      return {km: c.get("km"), minutes: c.get("minutes"),
        polyline: c.get("polyline") || [], source: cfg.provider,
        traffic: false};
    }
  }
  let r;
  try {
    r = await callProvider(cfg, from, to, traffic, http);
  } catch (e) {
    console.error("Itinéraire indisponible", e.message);
    return null;
  }
  if (!r || !(r.meters >= 0)) return null;
  const out = {km: Math.round(r.meters / 100) / 10,
    minutes: Math.max(1, Math.ceil(r.seconds / 60)),
    polyline: simplify(r.polyline).map(([lat, lng]) => ({lat, lng})),
    source: cfg.provider, traffic: r.traffic};
  if (ref && !traffic) {
    await ref.set({km: out.km, minutes: out.minutes,
      polyline: out.polyline, at: now});
  }
  return out;
}

module.exports = {config, decodePolyline, simplify, route};
