/**
 * Module commercial : règles du modèle (sans base de données).
 *   node --test kitunga/acquisition.model.test.js
 */
const test = require("node:test");
const assert = require("node:assert");
const m = require("./acquisition/model");

test("statuts : seules les transitions prévues sont acceptées", () => {
  assert.ok(m.canTransition("campaign", "active", "completed"));
  assert.ok(!m.canTransition("campaign", "completed", "active"));
  assert.ok(!m.canTransition("campaign", "archived", "active"));
  assert.ok(m.canTransition("commission", "pending", "approved"));
  assert.ok(!m.canTransition("commission", "paid", "reversed"));
  assert.ok(!m.canTransition("commission", "paid", "pending"));
  assert.ok(!m.canTransition("commission", "rejected", "approved"));
  assert.ok(!m.canTransition("payout", "paid", "rejected"));
  assert.ok(!m.canTransition("touch", "confirmed", "provisional"));
  assert.throws(() => m.assertTransition("payout", "rejected", "paid"),
      /interdit/);
  assert.throws(() => m.canTransition("inconnu", "a", "b"));
  // Aucun statut final ne peut repartir.
  for (const [kind, map] of Object.entries(m.TRANSITIONS)) {
    for (const end of ["archived", "paid", "rejected", "reversed", "void",
      "ended", "cancelled", "disabled", "superseded"]) {
      if (map[end]) assert.deepEqual(map[end], [], `${kind}.${end}`);
    }
  }
  assert.deepEqual(m.TRANSITIONS.touch.confirmed, []);
  // Attribution confirmée : seulement annulée (fraude), jamais réattribuée.
  assert.deepEqual(m.TRANSITIONS.attribution.confirmed, ["rejected", "void"]);
});

test("montants : FCFA entiers, négatifs réservés aux contrepassations", () => {
  assert.equal(m.assertAmount(100), 100);
  assert.equal(m.assertAmount(-100, {allowNegative: true}), -100);
  for (const bad of [-1, 10.5, "100", NaN, null, m.MAX_AMOUNT + 1]) {
    assert.throws(() => m.assertAmount(bad), /Montant invalide/, String(bad));
  }
});

test("identifiants : une commission par type et par client", () => {
  assert.equal(m.commissionId("activation", "abc"), "activation_abc");
  assert.equal(m.commissionId("first_subscription", "abc"),
      "first_subscription_abc");
  assert.equal(m.reversalId("first_subscription_abc"),
      "reversal_first_subscription_abc");
  assert.throws(() => m.commissionId("reversal", "abc"));
  assert.throws(() => m.commissionId("activation", "a/b"));
  assert.throws(() => m.commissionId("activation", ""));
});

test("installation : UUID aléatoire seulement", () => {
  const id = "3f2b8c1e-9a4d-4e2f-8b6a-1c2d3e4f5a6b";
  assert.equal(m.installationId(id.toUpperCase()), id);
  for (const bad of ["356938035643809", "abc", "", null,
    "3f2b8c1e-9a4d-1e2f-8b6a-1c2d3e4f5a6b"]) {
    assert.throws(() => m.installationId(bad), /Installation invalide/);
  }
});

test("codes : format lisible et vérifié", () => {
  assert.equal(m.agentCode(1), "KTG001");
  assert.equal(m.agentCode(1234), "KTG1234");
  assert.throws(() => m.agentCode(0));
  const code = m.newReferralCode("KTG001");
  assert.match(code, /^KTG001-[2-9A-HJKMNP-Z]{4}$/);
  assert.equal(m.parseReferralCode(` ${code.toLowerCase()} `), code);
  for (const bad of ["KTG001-X0P9", "KTG001-XIP9", "KTG001", "ABC001-X7P9",
    "KTG001-X7P9-1", "", null]) {
    assert.equal(m.parseReferralCode(bad), null, String(bad));
  }
  assert.throws(() => m.newReferralCode("KTG1"));
  const seen = new Set();
  for (let i = 0; i < 200; i++) seen.add(m.newReferralCode("KTG001"));
  assert.ok(seen.size > 190, "tirage aléatoire");
});

test("identité : même numéro, même empreinte, numéro jamais en clair", () => {
  const key = "cle-de-test-suffisamment-longue";
  const a = m.identityKey("06 123 45 67", key);
  assert.equal(a, m.identityKey("+242 061234567", key));
  assert.notEqual(a, m.identityKey("061234568", key));
  assert.notEqual(a, m.identityKey("061234567", key + "x"));
  assert.ok(!a.includes("061234567"));
  assert.equal(m.identityKey("", key), null);
  assert.throws(() => m.identityKey("061234567", ""), /ACQ_IDENTITY_KEY/);
});

test("périodes : chevauchement [début, fin[", () => {
  const d = (s) => new Date(`2026-11-${s}T00:00:00Z`);
  assert.ok(m.periodsOverlap(d("01"), d("10"), d("09"), d("20")));
  assert.ok(!m.periodsOverlap(d("01"), d("10"), d("10"), d("20")));
  assert.ok(m.periodsOverlap(d("05"), d("06"), d("01"), d("30")));
});

test("éligibilité : contact pendant l'affectation, délai après la fin", () => {
  const d = (s) => new Date(`2026-11-${s}T12:00:00Z`);
  const base = {assignmentStart: d("01"), assignmentEnd: d("10"),
    graceDays: 30};
  assert.ok(m.eventEligible({...base, touchAt: d("05"), eventAt: d("06")}));
  assert.ok(m.eventEligible({...base, touchAt: d("05"),
    eventAt: new Date("2026-12-10T12:00:00Z")}));
  assert.ok(!m.eventEligible({...base, touchAt: d("05"),
    eventAt: new Date("2026-12-10T12:00:01Z")}));
  assert.ok(!m.eventEligible({...base, touchAt: d("11"), eventAt: d("12")}));
  assert.ok(!m.eventEligible({...base, touchAt: d("05"), eventAt: d("04")}));
  assert.ok(!m.eventEligible({...base, touchAt: d("05"), eventAt: d("06"),
    graceDays: -1}));
});

test("délai de sécurité : date de validation possible", () => {
  const start = new Date("2026-11-01T00:00:00Z");
  assert.equal(m.holdUntil(start, 7).toISOString(), "2026-11-08T00:00:00.000Z");
  assert.throws(() => m.holdUntil(start, 1.5));
});
