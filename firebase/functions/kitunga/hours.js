/**
 * Horaires d'ouverture d'un commerce (champ User.Horraire), même format que
 * l'application (lib/backend/kitunga_hours.dart) :
 *   « Lun-Ven 8h00-20h00 · Sam 9h00-14h00 · Dim fermé »
 *   « Tous les jours dès 10h30 »   « 8h - 18h » (ancien format)
 * Heure de Brazzaville (UTC+1, sans heure d'été).
 */
const DAYS = ["lun", "mar", "mer", "jeu", "ven", "sam", "dim"];
const DAY_LONG = ["lundi", "mardi", "mercredi", "jeudi", "vendredi",
  "samedi", "dimanche"];
const CLOSED = {open: false, from: 480, to: 1080};

function minutes(h, m) {
  const hh = Number(h);
  const mm = Number(m || 0);
  if (!Number.isInteger(hh) || !Number.isInteger(mm) || hh > 24 || mm > 59) {
    return null;
  }
  return hh * 60 + mm;
}

const RANGE = new RegExp("^(?:(fermée?)|dès\\s*(\\d{1,2})\\s*[hH:]\\s*(\\d{2})?|" +
  "(\\d{1,2})\\s*[hH:]\\s*(\\d{2})?\\s*(?:-|–|à)\\s*(\\d{1,2})\\s*[hH:]\\s*" +
  "(\\d{2})?)$", "i");

function parseRange(s) {
  const m = RANGE.exec(String(s).trim());
  if (!m) return null;
  if (m[1]) return CLOSED;
  if (m[2]) {
    const f = minutes(m[2], m[3]);
    return f === null ? null : {open: true, from: f, to: null};
  }
  const f = minutes(m[4], m[5]);
  const t = minutes(m[6], m[7]);
  if (f === null || t === null || f === t) return null;
  return {open: true, from: f, to: t};
}

/** 7 jours (lundi d'abord) ou null si le texte n'est pas compris. */
function parseWeek(text) {
  const s = String(text || "").trim();
  if (!s) return null;
  const all = /^tous les jours\s+(.*)$/i.exec(s);
  if (all) {
    const d = parseRange(all[1]);
    return d ? Array(7).fill(d) : null;
  }
  const whole = parseRange(s);
  if (whole) return Array(7).fill(whole);
  const week = Array(7).fill(null);
  for (const part of s.split("·")) {
    const m = /^\s*([a-zé]{3})(?:\s*([-,])\s*([a-zé]{3}))?\s+(.*)$/i
        .exec(part);
    if (!m) return null;
    const a = DAYS.indexOf(m[1].toLowerCase());
    const b = m[3] ? DAYS.indexOf(m[3].toLowerCase()) : a;
    const d = parseRange(m[4]);
    if (a < 0 || b < a || !d) return null;
    if (m[2] === ",") {
      week[a] = d;
      week[b] = d;
    } else {
      for (let i = a; i <= b; i++) week[i] = d;
    }
  }
  return week.map((d) => d || CLOSED);
}

const label = (m) => `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}`;

function openAt(d, minute) {
  if (!d.open) return false;
  if (d.to === null) return minute >= d.from;
  return d.from < d.to ? minute >= d.from && minute < d.to : minute >= d.from;
}

/**
 * Statut à l'instant `now` : {open, label} ; null si les horaires ne sont pas
 * exploitables (on ne bloque alors rien).
 */
function openingStatus(text, now = new Date()) {
  const week = parseWeek(text);
  if (!week) return null;
  const local = new Date(now.getTime() + 60 * 60 * 1000); // UTC+1
  const today = (local.getUTCDay() + 6) % 7; // 0 = lundi
  const minute = local.getUTCHours() * 60 + local.getUTCMinutes();
  const d = week[today];
  const y = week[(today + 6) % 7];
  if (y.open && y.to !== null && y.to < y.from && minute < y.to) {
    return {open: true, label: `Ouvert · ferme à ${label(y.to)}`};
  }
  if (openAt(d, minute)) return {open: true, label: "Ouvert"};
  if (d.open && minute < d.from) {
    return {open: false, label: `Fermé · ouvre à ${label(d.from)}`};
  }
  for (let k = 1; k <= 7; k++) {
    const n = week[(today + k) % 7];
    if (n.open) {
      const when = k === 1 ? "demain" : DAY_LONG[(today + k) % 7];
      return {open: false, label: `Fermé · ouvre ${when} à ${label(n.from)}`};
    }
  }
  return {open: false, label: "Fermé"};
}

module.exports = {parseWeek, openingStatus};
