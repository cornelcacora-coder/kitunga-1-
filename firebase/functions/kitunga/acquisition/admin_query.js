/**
 * Lecture des données du module commercial pour l'interface admin.
 *
 * Passe par le serveur (Admin SDK) : l'interface fonctionne quelles que soient
 * les règles Firestore déployées, et seules des données utiles sont renvoyées
 * (pas de téléphone de client, pas d'empreinte, pas d'adresse IP).
 */
const {COLLECTIONS, AcquisitionError, toDate} = require("./model");
const {requireAdmin} = require("./agents");
const {referralLink} = require("./links");

const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");
const iso = (v) => {
  const d = toDate(v);
  return d ? d.toISOString() : null;
};
const DAY = 24 * 60 * 60 * 1000;
const MAX_SCAN = 5000;

/** Début de période : today, week, month, ou dates ISO personnalisées. */
function periodOf(filters, now) {
  // Brazzaville : UTC+1, sans heure d'été.
  const local = new Date(now.getTime() + 60 * 60 * 1000);
  const startOfDay = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(),
      local.getUTCDate()) - 60 * 60 * 1000;
  switch (filters.period) {
    case "today": return {start: new Date(startOfDay), end: now};
    case "week": {
      const dow = (local.getUTCDay() + 6) % 7; // lundi = 0
      return {start: new Date(startOfDay - dow * DAY), end: now};
    }
    case "custom": {
      const start = toDate(filters.from);
      const end = toDate(filters.to);
      if (!start || !end || end <= start) {
        throw new AcquisitionError("invalid-argument", "Période invalide.");
      }
      return {start, end};
    }
    default: // month
      return {start: new Date(Date.UTC(local.getUTCFullYear(),
          local.getUTCMonth(), 1) - 60 * 60 * 1000), end: now};
  }
}

function scoped(query, filters) {
  let q = query;
  if (filters.campaignId) q = q.where("campaign_id", "==", filters.campaignId);
  if (filters.agentUid) q = q.where("agent_uid", "==", filters.agentUid);
  return q;
}

async function countEvents(db, type, filters, period) {
  const q = scoped(db.collection(COLLECTIONS.events)
      .where("type", "==", type), filters)
      .where("created_at", ">=", period.start)
      .where("created_at", "<", period.end);
  return (await q.count().get()).data().count;
}

async function overview(db, filters, now) {
  const period = periodOf(filters, now);
  const [campaigns, agents, clicks, activations, signups, subscriptions,
    commissions] = await Promise.all([
    db.collection(COLLECTIONS.campaigns).where("status", "==", "active")
        .count().get(),
    db.collection(COLLECTIONS.agents).where("status", "==", "active")
        .count().get(),
    countEvents(db, "click", filters, period),
    countEvents(db, "activation", filters, period),
    countEvents(db, "signup", filters, period),
    countEvents(db, "subscription", filters, period),
    scoped(db.collection(COLLECTIONS.commissions), filters)
        .limit(MAX_SCAN).get(),
  ]);
  let generated = 0; let paid = 0; let due = 0; let pending = 0;
  for (const d of commissions.docs) {
    const c = d.data();
    const created = toDate(c.created_at);
    if (created && created >= period.start && created < period.end &&
      ["pending", "approved", "reserved", "paid"].includes(c.status) &&
      c.type !== "reversal") {
      generated += c.amount;
    }
    if (c.status === "paid") paid += c.amount;
    if (["approved", "reserved"].includes(c.status)) due += c.amount;
    if (c.status === "pending") pending += c.amount;
  }
  const rate = (a, b) => (b > 0 ? Math.round((a / b) * 1000) / 10 : null);
  return {
    period: {start: iso(period.start), end: iso(period.end)},
    activeCampaigns: campaigns.data().count,
    activeAgents: agents.data().count,
    clicks, activations, signups, subscriptions,
    conversion: {signupPerClick: rate(signups, clicks),
      subscriptionPerSignup: rate(subscriptions, signups)},
    commissions: {generated, paid, due, pending,
      truncated: commissions.size >= MAX_SCAN},
  };
}

async function agentsList(db) {
  const [agents, assignments] = await Promise.all([
    db.collection(COLLECTIONS.agents).orderBy("created_at", "desc")
        .limit(300).get(),
    db.collection(COLLECTIONS.assignments).where("status", "==", "active")
        .limit(1000).get(),
  ]);
  const current = {};
  for (const a of assignments.docs) {
    current[a.get("agent_uid")] = {assignmentId: a.id,
      campaignId: a.get("campaign_id"), code: a.get("referral_code"),
      endsAt: iso(a.get("ends_at"))};
  }
  return agents.docs.map((d) => {
    const a = d.data();
    return {uid: d.id, agentCode: a.agent_code, displayName: a.display_name,
      email: a.email, phone: a.phone, status: a.status,
      statusReason: a.status_reason || null,
      payoutMethod: a.payout_method || null, createdAt: iso(a.created_at),
      currentAssignment: current[d.id] || null};
  });
}

async function campaignsList(db) {
  const [campaigns, rules] = await Promise.all([
    db.collection(COLLECTIONS.campaigns).orderBy("created_at", "desc")
        .limit(200).get(),
    db.collection(COLLECTIONS.rules).orderBy("created_at", "desc")
        .limit(100).get(),
  ]);
  return {
    campaigns: campaigns.docs.map((d) => {
      const c = d.data();
      return {id: d.id, name: c.name, description: c.description,
        objective: c.objective, status: c.status,
        statusReason: c.status_reason || null, startsAt: iso(c.starts_at),
        endsAt: iso(c.ends_at), ruleId: c.rule_id, graceDays: c.grace_days,
        holdDays: c.hold_days, createdAt: iso(c.created_at)};
    }),
    rules: rules.docs.map((d) => {
      const r = d.data();
      return {id: d.id, label: r.label, activationAmount: r.activation_amount,
        firstSubscriptionAmount: r.first_subscription_amount,
        eligiblePlans: r.eligible_plans, createdAt: iso(r.created_at)};
    }),
  };
}

async function campaignDetail(db, campaignId) {
  if (!campaignId) {
    throw new AcquisitionError("invalid-argument", "Campagne manquante.");
  }
  const assignments = await db.collection(COLLECTIONS.assignments)
      .where("campaign_id", "==", campaignId).limit(500).get();
  const list = assignments.docs.map((d) => {
    const a = d.data();
    return {id: d.id, agentUid: a.agent_uid, agentCode: a.agent_code,
      status: a.status, startsAt: iso(a.starts_at), endsAt: iso(a.ends_at),
      referralCode: a.referral_code, link: referralLink(a.referral_code),
      allowOverlap: a.allow_overlap === true,
      overlapReason: a.overlap_reason || null};
  });
  list.sort((x, y) => (y.startsAt || "").localeCompare(x.startsAt || ""));
  return {assignments: list};
}

async function commissionsList(db, filters) {
  let q = scoped(db.collection(COLLECTIONS.commissions), filters);
  const status = text(filters.status, 20);
  if (status) q = q.where("status", "==", status);
  const snap = await (status || filters.campaignId || filters.agentUid ?
    q.limit(500) : q.orderBy("created_at", "desc").limit(200)).get();
  const list = snap.docs.map((d) => {
    const c = d.data();
    return {id: d.id, type: c.type, agentUid: c.agent_uid,
      clientUid: c.client_uid, campaignId: c.campaign_id, amount: c.amount,
      currency: c.currency, status: c.status,
      statusReason: c.status_reason || null, flags: c.flags || [],
      plan: c.plan || null, eligibleAt: iso(c.eligible_at),
      createdAt: iso(c.created_at), payoutId: c.payout_id || null,
      reversedBy: c.reversed_by || null};
  });
  list.sort((x, y) => (y.createdAt || "").localeCompare(x.createdAt || ""));
  return list.slice(0, 200);
}

async function payoutsList(db, filters) {
  const snap = await (filters.agentUid ?
    db.collection(COLLECTIONS.payouts).where("agent_uid", "==", filters.agentUid)
        .limit(200) :
    db.collection(COLLECTIONS.payouts).orderBy("requested_at", "desc")
        .limit(200)).get();
  const list = snap.docs.map((d) => {
    const p = d.data();
    return {id: d.id, agentUid: p.agent_uid, amount: p.amount,
      currency: p.currency, method: p.method, status: p.status,
      statusReason: p.status_reason || null, itemsCount: p.items_count,
      requestedAt: iso(p.requested_at), paidAt: iso(p.paid_at),
      externalReference: p.external_reference || null};
  });
  list.sort((x, y) => (y.requestedAt || "").localeCompare(x.requestedAt || ""));
  return list;
}

async function auditList(db) {
  const snap = await db.collection(COLLECTIONS.audit)
      .orderBy("created_at", "desc").limit(150).get();
  return snap.docs.map((d) => {
    const a = d.data();
    return {id: d.id, actorUid: a.actor_uid, actorRole: a.actor_role,
      action: a.action, target: a.target, createdAt: iso(a.created_at)};
  });
}

async function salesAdminQuery({db, uid, data, clock = () => new Date()}) {
  await requireAdmin(db, uid);
  const filters = {
    period: text(data.period, 10) || "month",
    from: data.from, to: data.to,
    campaignId: text(data.campaignId, 128) || null,
    agentUid: text(data.agentUid, 128) || null,
    status: data.status,
  };
  switch (text(data.view, 20)) {
    case "overview": return overview(db, filters, clock());
    case "agents": return {agents: await agentsList(db)};
    case "campaigns": return campaignsList(db);
    case "campaign": return campaignDetail(db, text(data.campaignId, 128));
    case "commissions": return {commissions: await commissionsList(db, filters)};
    case "payouts": return {payouts: await payoutsList(db, filters)};
    case "audit": return {audit: await auditList(db)};
    default:
      throw new AcquisitionError("invalid-argument", "Vue inconnue.");
  }
}

module.exports = {salesAdminQuery, periodOf, countEvents, iso};
