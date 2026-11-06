/**
 * Campagnes, barèmes de commission et affectations des commerciaux.
 * Réservé à l'administrateur ; chaque action est journalisée (audit_logs).
 *
 * Règles :
 * - Un barème est figé : changer les tarifs = créer un nouveau barème. Les
 *   commissions déjà générées gardent leur montant.
 * - Anti-fraude : activation + premier abonnement < prix de la formule
 *   éligible la moins chère (sinon payer de faux abonnements rapporte).
 * - Un commercial n'a pas deux affectations actives qui se chevauchent, sauf
 *   autorisation explicite de l'admin avec un motif écrit.
 * - Une campagne terminée n'accepte plus d'acquisitions : ses affectations
 *   sont fermées et ses codes désactivés.
 *
 * `clock` est injectable pour les tests (dates de début et de fin).
 */
const admin = require("firebase-admin");
const {PLANS} = require("../subscriptions");
const {COLLECTIONS, AcquisitionError, assertAmount, assertTransition,
  newReferralCode, periodsOverlap, toDate, CURRENCY} = require("./model");
const {audit} = require("./store");
const {requireAdmin} = require("./agents");

const ts = () => admin.firestore.FieldValue.serverTimestamp();
const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const DAY = 24 * 60 * 60 * 1000;
const MAX_SPAN = 731 * DAY; // une campagne ou affectation : 2 ans maximum
const BATCH = 400; // écritures par lot (limite Firestore : 500)

function dateOf(value, label) {
  const d = toDate(value);
  if (!d) throw new AcquisitionError("invalid-argument", `${label} invalide.`);
  return d;
}

function period(startRaw, endRaw) {
  const start = dateOf(startRaw, "Date de début");
  const end = dateOf(endRaw, "Date de fin");
  if (end <= start) {
    throw new AcquisitionError("invalid-argument",
        "La date de fin doit être après la date de début.");
  }
  if (end - start > MAX_SPAN) {
    throw new AcquisitionError("invalid-argument",
        "Une période ne peut pas dépasser 2 ans.");
  }
  return {start, end};
}

function boundedInt(value, min, max, fallback, label) {
  if (value === undefined || value === null) return fallback;
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    throw new AcquisitionError("invalid-argument",
        `${label} : nombre entier entre ${min} et ${max}.`);
  }
  return value;
}

// ── Barèmes ──────────────────────────────────────────────────────────────

async function createCommissionRule({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const label = text(data.label, 80);
  if (!label) {
    throw new AcquisitionError("invalid-argument", "Nom du barème manquant.");
  }
  const activation = assertAmount(data.activationAmount);
  const firstSubscription = assertAmount(data.firstSubscriptionAmount);
  const plans = Array.isArray(data.eligiblePlans) ?
    [...new Set(data.eligiblePlans)] : [];
  if (plans.length === 0 || plans.some((p) => !PLANS[p])) {
    throw new AcquisitionError("invalid-argument",
        "Choisissez les formules qui ouvrent droit à la commission.");
  }
  const cheapest = Math.min(...plans.map((p) => PLANS[p].price));
  if (activation + firstSubscription >= cheapest) {
    throw new AcquisitionError("invalid-argument",
        `Activation + premier abonnement (${activation + firstSubscription} F) ` +
        `doit rester sous le prix de la formule la moins chère (${cheapest} F).`);
  }
  const ref = db.collection(COLLECTIONS.rules).doc();
  await db.runTransaction(async (tx) => {
    tx.create(ref, {
      label,
      activation_amount: activation,
      first_subscription_amount: firstSubscription,
      eligible_plans: plans,
      currency: CURRENCY,
      created_by: adminUid,
      created_at: ts(),
    });
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "rule.create", target: ref.path,
      details: {activation, firstSubscription, plans}});
  });
  return {ruleId: ref.id};
}

// ── Campagnes ────────────────────────────────────────────────────────────

async function createCampaign({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const name = text(data.name, 100);
  if (!name) {
    throw new AcquisitionError("invalid-argument", "Nom de campagne manquant.");
  }
  const {start, end} = period(data.startsAt, data.endsAt);
  const ruleId = text(data.ruleId, 128);
  if (!ruleId || !(await db.doc(`${COLLECTIONS.rules}/${ruleId}`).get()).exists) {
    throw new AcquisitionError("invalid-argument",
        "Barème de commission introuvable.");
  }
  const ref = db.collection(COLLECTIONS.campaigns).doc();
  await db.runTransaction(async (tx) => {
    tx.create(ref, {
      name,
      description: text(data.description, 1000),
      objective: text(data.objective, 300),
      starts_at: start,
      ends_at: end,
      rule_id: ruleId,
      grace_days: boundedInt(data.graceDays, 0, 90, 30, "Délai après la fin"),
      hold_days: boundedInt(data.holdDays, 0, 60, 7, "Délai de sécurité"),
      status: "draft",
      created_by: adminUid,
      created_at: ts(),
      updated_at: ts(),
    });
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "campaign.create", target: ref.path, details: {name}});
  });
  return {campaignId: ref.id};
}

/**
 * Brouillon ou programmée : tout est modifiable. Active ou en pause : textes
 * et date de fin seulement (le barème ne change plus). Terminée : rien.
 */
async function updateCampaign({db, uid, data, clock = () => new Date()}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`${COLLECTIONS.campaigns}/${text(data.campaignId, 128)}`);
  await db.runTransaction(async (tx) => {
    const campaign = await tx.get(ref);
    if (!campaign.exists) {
      throw new AcquisitionError("not-found", "Campagne introuvable.");
    }
    const status = campaign.get("status");
    const editable = ["draft", "scheduled"].includes(status);
    const running = ["active", "paused"].includes(status);
    if (!editable && !running) {
      throw new AcquisitionError("failed-precondition",
          "Une campagne terminée ne peut plus être modifiée.");
    }
    const changes = {};
    for (const [key, field, max] of [["name", "name", 100],
      ["description", "description", 1000], ["objective", "objective", 300]]) {
      if (data[key] !== undefined) changes[field] = text(data[key], max);
    }
    if (changes.name === "") {
      throw new AcquisitionError("invalid-argument", "Nom de campagne manquant.");
    }
    if (running && (data.startsAt !== undefined || data.ruleId !== undefined ||
      data.graceDays !== undefined || data.holdDays !== undefined)) {
      throw new AcquisitionError("failed-precondition",
          "Campagne lancée : seuls les textes et la date de fin changent.");
    }
    if (data.startsAt !== undefined || data.endsAt !== undefined) {
      const {start, end} = period(data.startsAt ?? campaign.get("starts_at"),
          data.endsAt ?? campaign.get("ends_at"));
      if (running && end <= clock()) {
        throw new AcquisitionError("invalid-argument",
            "La nouvelle date de fin est déjà passée : clôturez la campagne.");
      }
      // Les affectations doivent rester dans la période de la campagne.
      const assignments = await tx.get(db.collection(COLLECTIONS.assignments)
          .where("campaign_id", "==", ref.id).where("status", "==", "active"));
      for (const a of assignments.docs) {
        if (toDate(a.get("starts_at")) < start || toDate(a.get("ends_at")) > end) {
          throw new AcquisitionError("failed-precondition",
              "Des affectations sortent de ces dates : modifiez-les d'abord.");
        }
      }
      changes.starts_at = start;
      changes.ends_at = end;
    }
    if (data.ruleId !== undefined) {
      const ruleId = text(data.ruleId, 128);
      if (!ruleId || !(await tx.get(db.doc(`${COLLECTIONS.rules}/${ruleId}`)))
          .exists) {
        throw new AcquisitionError("invalid-argument",
            "Barème de commission introuvable.");
      }
      changes.rule_id = ruleId;
    }
    if (data.graceDays !== undefined) {
      changes.grace_days = boundedInt(data.graceDays, 0, 90, 30,
          "Délai après la fin");
    }
    if (data.holdDays !== undefined) {
      changes.hold_days = boundedInt(data.holdDays, 0, 60, 7,
          "Délai de sécurité");
    }
    if (Object.keys(changes).length === 0) {
      throw new AcquisitionError("invalid-argument", "Aucune modification.");
    }
    tx.update(ref, {...changes, updated_at: ts()});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "campaign.update", target: ref.path,
      details: {fields: Object.keys(changes)}});
  });
  return {ok: true};
}

/**
 * Ferme les affectations encore actives d'une campagne terminée et désactive
 * leurs codes, par lots. Rejouable : ne touche que ce qui reste ouvert.
 */
async function closeAssignments(db, campaignId, actor) {
  let closed = 0;
  for (;;) {
    const open = await db.collection(COLLECTIONS.assignments)
        .where("campaign_id", "==", campaignId)
        .where("status", "==", "active").limit(BATCH / 2).get();
    if (open.empty) {
      await db.doc(`${COLLECTIONS.campaigns}/${campaignId}`)
          .update({assignments_closed: true});
      return closed;
    }
    const batch = db.batch();
    for (const a of open.docs) {
      batch.update(a.ref, {status: "ended", status_reason: "campaign_closed",
        status_updated_at: ts()});
      const code = a.get("referral_code");
      if (code) {
        batch.update(db.doc(`${COLLECTIONS.codes}/${code}`),
            {status: "disabled", status_updated_at: ts()});
      }
    }
    batch.create(db.collection(COLLECTIONS.audit).doc(), {
      actor_uid: actor.uid || null, actor_role: actor.role,
      action: "assignment.close_batch", target: `${COLLECTIONS.campaigns}/${campaignId}`,
      details: {count: open.size}, created_at: ts(),
    });
    await batch.commit();
    closed += open.size;
  }
}

/** Activation, pause, clôture, archivage (et programmation). */
async function setCampaignStatus({db, uid, data, clock = () => new Date()}) {
  const adminUid = await requireAdmin(db, uid);
  const ref = db.doc(`${COLLECTIONS.campaigns}/${text(data.campaignId, 128)}`);
  const to = text(data.status, 20);
  const reason = text(data.reason, 300);
  await db.runTransaction(async (tx) => {
    const campaign = await tx.get(ref);
    if (!campaign.exists) {
      throw new AcquisitionError("not-found", "Campagne introuvable.");
    }
    const from = campaign.get("status");
    if (from === to && to === "completed") return; // clôture rejouée
    assertTransition("campaign", from, to);
    const now = clock();
    const start = toDate(campaign.get("starts_at"));
    const end = toDate(campaign.get("ends_at"));
    if (to === "scheduled" && start <= now) {
      throw new AcquisitionError("failed-precondition",
          "La date de début est passée : activez directement la campagne.");
    }
    if (to === "active" && (now < start || now >= end)) {
      throw new AcquisitionError("failed-precondition",
          "Une campagne ne s'active qu'entre sa date de début et sa date de fin.");
    }
    if (to === "archived") {
      const open = await tx.get(db.collection(COLLECTIONS.commissions)
          .where("campaign_id", "==", ref.id)
          .where("status", "in", ["pending", "approved", "reserved"]).limit(1));
      if (!open.empty) {
        throw new AcquisitionError("failed-precondition",
            "Des commissions de cette campagne ne sont pas encore réglées.");
      }
    }
    if (["paused", "completed"].includes(to) && !reason && now < end) {
      throw new AcquisitionError("invalid-argument",
          "Indiquez le motif de la pause ou de la clôture anticipée.");
    }
    const extra = to === "completed" ?
      {closed_at: ts(), closed_by: adminUid, assignments_closed: false} :
      to === "archived" ? {archived_at: ts()} : {};
    tx.update(ref, {status: to, status_reason: reason || null,
      status_updated_at: ts(), updated_at: ts(), ...extra});
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: `campaign.${to}`, target: ref.path, details: {from, reason}});
  });
  if (to === "completed") {
    await closeAssignments(db, ref.id, {uid: adminUid, role: "Admin"});
  }
  return {ok: true};
}

/**
 * Traitement planifié : active les campagnes programmées arrivées à leur
 * date de début, termine celles dont la date de fin est passée. Rejouable.
 */
async function runCampaignSchedule({db, clock = () => new Date()}) {
  const now = clock();
  const result = {activated: 0, completed: 0, assignmentsClosed: 0};
  const actor = {uid: null, role: "system"};

  const due = await db.collection(COLLECTIONS.campaigns)
      .where("status", "==", "scheduled").where("starts_at", "<=", now).get();
  for (const doc of due.docs) {
    const changed = await db.runTransaction(async (tx) => {
      const c = await tx.get(doc.ref);
      if (c.get("status") !== "scheduled") return false;
      const to = toDate(c.get("ends_at")) <= now ? "completed" : "active";
      tx.update(doc.ref, {status: to, status_updated_at: ts(), updated_at: ts(),
        ...(to === "completed" ? {closed_at: ts(), closed_by: "system",
          assignments_closed: false} : {})});
      audit(tx, db, {actorRole: "system", action: `campaign.${to}`,
        target: doc.ref.path, details: {from: "scheduled", automatic: true}});
      return to;
    });
    if (changed === "active") result.activated++;
    if (changed === "completed") result.completed++;
  }

  const ended = await db.collection(COLLECTIONS.campaigns)
      .where("status", "in", ["active", "paused"])
      .where("ends_at", "<=", now).get();
  for (const doc of ended.docs) {
    const changed = await db.runTransaction(async (tx) => {
      const c = await tx.get(doc.ref);
      if (!["active", "paused"].includes(c.get("status"))) return false;
      tx.update(doc.ref, {status: "completed", status_updated_at: ts(),
        updated_at: ts(), closed_at: ts(), closed_by: "system",
        assignments_closed: false});
      audit(tx, db, {actorRole: "system", action: "campaign.completed",
        target: doc.ref.path, details: {from: c.get("status"), automatic: true}});
      return true;
    });
    if (changed) result.completed++;
  }

  // Termine les fermetures en attente ou interrompues.
  const closedCampaigns = await db.collection(COLLECTIONS.campaigns)
      .where("status", "==", "completed")
      .where("assignments_closed", "==", false).get();
  for (const doc of closedCampaigns.docs) {
    result.assignmentsClosed += await closeAssignments(db, doc.id, actor);
  }
  // Affectations arrivées à leur date de fin dans une campagne en cours.
  const expired = await db.collection(COLLECTIONS.assignments)
      .where("status", "==", "active").where("ends_at", "<=", now).get();
  for (const doc of expired.docs) {
    await endAssignmentDoc(db, doc.ref, "ended", "assignment_expired", actor);
    result.assignmentsClosed++;
  }
  return result;
}

// ── Affectations ─────────────────────────────────────────────────────────

/**
 * Affecte un commercial à une campagne. La fiche du commercial sert de
 * verrou : deux affectations simultanées du même commercial sont traitées
 * l'une après l'autre, la seconde voit la première.
 */
async function assignAgent({db, uid, data, random}) {
  const adminUid = await requireAdmin(db, uid);
  const campaignRef = db.doc(
      `${COLLECTIONS.campaigns}/${text(data.campaignId, 128)}`);
  const agentUid = text(data.agentUid, 128);
  const agentRef = db.doc(`${COLLECTIONS.agents}/${agentUid}`);
  const {start, end} = period(data.startsAt, data.endsAt);
  const allowOverlap = data.allowOverlap === true;
  const overlapReason = text(data.overlapReason, 300);
  if (allowOverlap && !overlapReason) {
    throw new AcquisitionError("invalid-argument",
        "Indiquez pourquoi ce commercial peut avoir deux affectations en même temps.");
  }
  const assignmentRef = db.collection(COLLECTIONS.assignments).doc();

  const code = await db.runTransaction(async (tx) => {
    const [campaign, agent] =
      await Promise.all([tx.get(campaignRef), tx.get(agentRef)]);
    if (!campaign.exists) {
      throw new AcquisitionError("not-found", "Campagne introuvable.");
    }
    if (!["draft", "scheduled", "active", "paused"]
        .includes(campaign.get("status"))) {
      throw new AcquisitionError("failed-precondition",
          "Cette campagne est terminée : plus d'affectation possible.");
    }
    if (!agent.exists || agent.get("status") !== "active") {
      throw new AcquisitionError("failed-precondition",
          "Ce commercial n'est pas actif.");
    }
    if (start < toDate(campaign.get("starts_at")) ||
      end > toDate(campaign.get("ends_at"))) {
      throw new AcquisitionError("invalid-argument",
          "L'affectation doit rester dans les dates de la campagne.");
    }
    const current = await tx.get(db.collection(COLLECTIONS.assignments)
        .where("agent_uid", "==", agentUid).where("status", "==", "active"));
    const clash = current.docs.find((a) => periodsOverlap(start, end,
        a.get("starts_at"), a.get("ends_at")));
    if (clash && !allowOverlap) {
      throw new AcquisitionError("failed-precondition",
          "Ce commercial a déjà une affectation sur ces dates.");
    }
    // Code unique : nouveau tirage si le code existe déjà.
    let referralCode = null;
    for (let i = 0; i < 5 && !referralCode; i++) {
      const candidate = newReferralCode(agent.get("agent_code"), random);
      if (!(await tx.get(db.doc(`${COLLECTIONS.codes}/${candidate}`))).exists) {
        referralCode = candidate;
      }
    }
    if (!referralCode) {
      throw new AcquisitionError("aborted", "Code indisponible, réessayez.");
    }
    tx.update(agentRef, {assignments_version:
      admin.firestore.FieldValue.increment(1)}); // verrou
    tx.create(assignmentRef, {
      campaign_id: campaignRef.id,
      agent_uid: agentUid,
      agent_code: agent.get("agent_code"),
      starts_at: start,
      ends_at: end,
      status: "active",
      referral_code: referralCode,
      allow_overlap: allowOverlap,
      overlap_reason: allowOverlap ? overlapReason : null,
      overlaps_with: clash ? clash.id : null,
      created_by: adminUid,
      created_at: ts(),
    });
    tx.create(db.doc(`${COLLECTIONS.codes}/${referralCode}`), {
      assignment_id: assignmentRef.id,
      campaign_id: campaignRef.id,
      agent_uid: agentUid,
      valid_from: start,
      valid_until: end,
      status: "active",
      created_at: ts(),
    });
    audit(tx, db, {actorUid: adminUid, actorRole: "Admin",
      action: "assignment.create", target: assignmentRef.path,
      details: {agent_uid: agentUid, campaign_id: campaignRef.id,
        referral_code: referralCode, overlap: Boolean(clash), overlapReason}});
    return referralCode;
  });
  return {assignmentId: assignmentRef.id, referralCode: code};
}

async function endAssignmentDoc(db, ref, status, reason, actor) {
  return db.runTransaction(async (tx) => {
    const a = await tx.get(ref);
    if (!a.exists) {
      throw new AcquisitionError("not-found", "Affectation introuvable.");
    }
    assertTransition("assignment", a.get("status"), status);
    tx.update(ref, {status, status_reason: reason, status_updated_at: ts()});
    tx.update(db.doc(`${COLLECTIONS.codes}/${a.get("referral_code")}`),
        {status: "disabled", status_updated_at: ts()});
    audit(tx, db, {actorUid: actor.uid, actorRole: actor.role,
      action: `assignment.${status}`, target: ref.path, details: {reason}});
  });
}

/** Termine ou annule une affectation : son code est désactivé. */
async function endAssignment({db, uid, data}) {
  const adminUid = await requireAdmin(db, uid);
  const status = data.status === "cancelled" ? "cancelled" : "ended";
  const reason = text(data.reason, 300);
  if (!reason) {
    throw new AcquisitionError("invalid-argument", "Indiquez le motif.");
  }
  await endAssignmentDoc(db,
      db.doc(`${COLLECTIONS.assignments}/${text(data.assignmentId, 128)}`),
      status, reason, {uid: adminUid, role: "Admin"});
  return {ok: true};
}

module.exports = {createCommissionRule, createCampaign, updateCampaign,
  setCampaignStatus, runCampaignSchedule, assignAgent, endAssignment,
  closeAssignments};
