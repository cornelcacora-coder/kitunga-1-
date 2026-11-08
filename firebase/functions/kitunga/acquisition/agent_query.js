/**
 * Espace commercial : lecture de SES données seulement (rôle Commercial).
 *
 * Passe par le serveur : rien ne dépend des règles Firestore, et seules des
 * informations limitées sur les clients sont renvoyées (prénom et initiale,
 * date d'inscription, abonné ou non) : ni téléphone, ni email, ni commande,
 * ni identifiant de compte.
 */
const {COLLECTIONS, AcquisitionError, toDate} = require("./model");
const {referralLink} = require("./links");
const {periodOf, countEvents, iso} = require("./admin_query");

const text = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");

async function requireAgent(db, uid) {
  if (!uid) throw new AcquisitionError("unauthenticated", "Connexion requise.");
  const [user, agent] = await Promise.all([
    db.doc(`User/${uid}`).get(),
    db.doc(`${COLLECTIONS.agents}/${uid}`).get(),
  ]);
  if (!user.exists || user.get("role") !== "Commercial" || !agent.exists) {
    throw new AcquisitionError("permission-denied",
        "Espace réservé aux commerciaux Kitunga.");
  }
  return agent;
}

async function home(db, uid, agent, period, now) {
  const filters = {agentUid: uid};
  const [assignments, clicks, activations, signups, subscriptions,
    commissions] = await Promise.all([
    db.collection(COLLECTIONS.assignments).where("agent_uid", "==", uid)
        .where("status", "==", "active").limit(10).get(),
    countEvents(db, "click", filters, period),
    countEvents(db, "activation", filters, period),
    countEvents(db, "signup", filters, period),
    countEvents(db, "subscription", filters, period),
    db.collection(COLLECTIONS.commissions).where("agent_uid", "==", uid)
        .limit(2000).get(),
  ]);
  const campaignIds = [...new Set(assignments.docs.map((a) => a.get("campaign_id")))];
  const campaigns = await Promise.all(campaignIds.map((id) =>
    db.doc(`${COLLECTIONS.campaigns}/${id}`).get()));
  const names = Object.fromEntries(campaigns.filter((c) => c.exists)
      .map((c) => [c.id, c.get("name")]));
  const totals = {pending: 0, approved: 0, reserved: 0, paid: 0};
  for (const d of commissions.docs) {
    const s = d.get("status");
    if (s in totals) totals[s] += d.get("amount") || 0;
  }
  return {
    profile: {agentCode: agent.get("agent_code"),
      displayName: agent.get("display_name"), status: agent.get("status"),
      payoutMethodSet: Boolean(agent.get("payout_method"))},
    assignments: assignments.docs.map((d) => {
      const a = d.data();
      return {campaignName: names[a.campaign_id] || "Campagne",
        startsAt: iso(a.starts_at), endsAt: iso(a.ends_at),
        referralCode: a.referral_code, link: referralLink(a.referral_code),
        expired: toDate(a.ends_at) <= now};
    }),
    period: {start: iso(period.start), end: iso(period.end)},
    stats: {clicks, activations, signups, subscriptions},
    commissions: totals,
  };
}

async function salesAgentQuery({db, uid, data, clock = () => new Date()}) {
  const agent = await requireAgent(db, uid);
  const now = clock();
  switch (text(data.view, 20)) {
    case "home":
      return home(db, uid, agent,
          periodOf({period: text(data.period, 10) || "month"}, now), now);
    case "clients": {
      const snap = await db.collection(COLLECTIONS.attributions)
          .where("agent_uid", "==", uid).limit(300).get();
      const clients = snap.docs.map((d) => {
        const a = d.data();
        const s = a.client_summary || {};
        return {name: s.name || "Client", signedUpAt: iso(s.signed_up_at),
          subscribed: s.subscribed === true, status: a.status,
          source: a.source, confirmedAt: iso(a.confirmed_at)};
      });
      clients.sort((x, y) =>
        (y.confirmedAt || "").localeCompare(x.confirmedAt || ""));
      return {clients};
    }
    case "commissions": {
      const snap = await db.collection(COLLECTIONS.commissions)
          .where("agent_uid", "==", uid).limit(300).get();
      const list = snap.docs.map((d) => {
        const c = d.data();
        return {type: c.type, amount: c.amount, status: c.status,
          plan: c.plan || null, createdAt: iso(c.created_at),
          eligibleAt: iso(c.eligible_at), statusReason: c.status_reason || null};
      });
      list.sort((x, y) => (y.createdAt || "").localeCompare(x.createdAt || ""));
      return {commissions: list};
    }
    case "payouts": {
      const snap = await db.collection(COLLECTIONS.payouts)
          .where("agent_uid", "==", uid).limit(100).get();
      const list = snap.docs.map((d) => {
        const p = d.data();
        return {amount: p.amount, status: p.status, itemsCount: p.items_count,
          requestedAt: iso(p.requested_at), paidAt: iso(p.paid_at),
          externalReference: p.external_reference || null,
          statusReason: p.status_reason || null};
      });
      list.sort((x, y) =>
        (y.requestedAt || "").localeCompare(x.requestedAt || ""));
      return {payouts: list};
    }
    default:
      throw new AcquisitionError("invalid-argument", "Vue inconnue.");
  }
}

module.exports = {salesAgentQuery};
