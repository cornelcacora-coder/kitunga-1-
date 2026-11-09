/** Horaires d'ouverture (même format que l'application). */
const test = require("node:test");
const assert = require("node:assert");
const {parseWeek, openingStatus} = require("./hours");

// Heure de Brazzaville → instant UTC. 9 novembre 2026 = lundi.
const at = (day, h, m = 0) => new Date(Date.UTC(2026, 10, 8 + day, h - 1, m));
const H = "Lun-Ven 8h00-20h00 · Sam 9h00-14h00 · Dim fermé";

test("relecture du format de l'application", () => {
  const w = parseWeek(H);
  assert.deepStrictEqual(w[4], {open: true, from: 480, to: 1200});
  assert.strictEqual(w[6].open, false);
  assert.deepStrictEqual(parseWeek("Tous les jours dès 10h30")[2],
      {open: true, from: 630, to: null});
  assert.strictEqual(parseWeek("8h - 18h")[6].from, 480);
  assert.strictEqual(parseWeek("Lun, Mar 8h00-12h00")[2].open, false);
  assert.strictEqual(parseWeek("le matin"), null);
  assert.strictEqual(parseWeek(""), null);
});

test("ouvert ou fermé, heure de Brazzaville", () => {
  assert.strictEqual(openingStatus(H, at(1, 10)).open, true);
  assert.strictEqual(openingStatus(H, at(1, 20, 30)).label,
      "Fermé · ouvre demain à 8h00");
  assert.strictEqual(openingStatus(H, at(6, 7)).label, "Fermé · ouvre à 9h00");
  assert.strictEqual(openingStatus(H, at(7, 12)).label,
      "Fermé · ouvre demain à 8h00");
  assert.strictEqual(openingStatus(H, at(6, 15)).label,
      "Fermé · ouvre lundi à 8h00");
  const night = "Lun-Sam 18h00-2h00 · Dim fermé";
  assert.strictEqual(openingStatus(night, at(2, 1)).open, true);
  assert.strictEqual(openingStatus(night, at(2, 3)).open, false);
  assert.strictEqual(openingStatus("horaires libres", at(1, 3)), null);
});
