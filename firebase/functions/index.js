const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const https = require("https");
const cors = require("cors")({ origin: true });
const corsProxyRuntimeOptions = { minInstances: 1, timeoutSeconds: 15 };
const ALLOWED_PROXY_HOSTS = [
  "firebasestorage.googleapis.com",
  "storage.googleapis.com",
];

/**
 * Provides a CORS proxy and returns the response body of the requested url,
 * which should be encoded with encodeURIComponent if there are additional
 * parameters for the requested url.
 */
exports.corsProxy = functions
  .region("us-west1")
  .runWith(corsProxyRuntimeOptions)
  .https.onRequest((req, res) => handleRequest(req, res));

async function handleRequest(req, res) {
  cors(req, res, () => {
    console.log("Body:", req.body);
    let url = req.query.url || req.body.url;
    if (!url) {
      res.status(403).send("URL is empty.");
      return;
    }
    // N'autorise que les fichiers hébergés sur le stockage Firebase / Google
    // pour éviter que le proxy serve à télécharger n'importe quelle URL.
    let parsed;
    try {
      parsed = new URL(url);
    } catch (_) {
      res.status(400).send("Invalid URL.");
      return;
    }
    if (parsed.protocol !== "https:" || !ALLOWED_PROXY_HOSTS.includes(parsed.hostname)) {
      res.status(403).send("Host not allowed.");
      return;
    }
    https
      .get(url, (resp) => {
        res.setHeader(
          "content-type",
          resp.headers["content-type"] || "image/jpeg",
        );
        resp.pipe(res);
      })
      .on("error", () => res.status(502).send("Upstream error."));
  });
}
exports.onUserDeleted = functions
  .region("us-west1")
  .auth.user()
  .onDelete(async (user) => {
    let firestore = admin.firestore();
    let userRef = firestore.doc("User/" + user.uid);
  });

// ── Paiement contrôlé par le serveur (voir README-KITUNGA.md) ─────────────
const momo = require("./kitunga/momo");
const payments = require("./kitunga/payments");
const subscriptions = require("./kitunga/subscriptions");
const partners = require("./kitunga/partners");
const {reconcilePending} = require("./kitunga/reconcile");

// Encaissement (Collection) : paiements et abonnements. Remboursements
// (Disbursement) : seulement kitungaRefundOrder, qui exige un compte MTN
// Disbursement approvisionné.
const COLLECTION_SECRETS = [
  "MOMO_COLLECTION_USER", "MOMO_COLLECTION_KEY", "MOMO_COLLECTION_SUBSCRIPTION",
];
const MOMO_SECRETS = [
  ...COLLECTION_SECRETS,
  "MOMO_DISBURSEMENT_USER", "MOMO_DISBURSEMENT_KEY",
  "MOMO_DISBURSEMENT_SUBSCRIPTION",
];

function callable(handler) {
  return functions.region("us-west1")
      .runWith({secrets: COLLECTION_SECRETS, timeoutSeconds: 60})
      .https.onCall(async (data, context) => {
        try {
          return await handler(data || {}, context.auth && context.auth.uid);
        } catch (e) {
          if (e instanceof payments.PaymentError) {
            throw new functions.https.HttpsError(e.code, e.message);
          }
          console.error(e);
          throw new functions.https.HttpsError("internal",
              "Le paiement n'a pas pu être traité. Réessayez.");
        }
      });
}

/** Création d'un partenaire par un administrateur (sans secret MTN). */
exports.kitungaCreatePartner = functions.region("us-west1")
    .https.onCall(async (data, context) => {
      try {
        return await partners.createPartner({
          db: admin.firestore(), auth: admin.auth(),
          uid: context.auth && context.auth.uid, data: data || {},
        });
      } catch (e) {
        if (e instanceof payments.PaymentError) {
          throw new functions.https.HttpsError(e.code, e.message);
        }
        console.error(e);
        throw new functions.https.HttpsError("internal",
            "Le partenaire n'a pas pu être créé. Réessayez.");
      }
    });

// ── Module commercial (voir README-ACQUISITION.md) ────────────────────────
const {AcquisitionError} = require("./kitunga/acquisition/model");
const agents = require("./kitunga/acquisition/agents");

/** Fonction appelable du module commercial (erreurs métier lisibles). */
function acquisitionCallable(handler, secrets = []) {
  return functions.region("us-west1")
      .runWith({secrets, timeoutSeconds: 60})
      .https.onCall(async (data, context) => {
        try {
          return await handler(data || {}, context.auth && context.auth.uid);
        } catch (e) {
          if (e instanceof AcquisitionError || e instanceof payments.PaymentError) {
            throw new functions.https.HttpsError(e.code, e.message);
          }
          console.error(e);
          throw new functions.https.HttpsError("internal",
              "L'opération n'a pas pu aboutir. Réessayez.");
        }
      });
}

/** Création d'un commercial par un administrateur. */
exports.kitungaCreateSalesAgent = acquisitionCallable((data, uid) =>
  agents.createSalesAgent({db: admin.firestore(), auth: admin.auth(), uid,
    data, identitySecret: process.env.ACQ_IDENTITY_KEY}), ["ACQ_IDENTITY_KEY"]);

/** Modification d'un commercial (nom, téléphone, moyen de paiement). */
exports.kitungaUpdateSalesAgent = acquisitionCallable((data, uid) =>
  agents.updateSalesAgent({db: admin.firestore(), uid, data,
    identitySecret: process.env.ACQ_IDENTITY_KEY}), ["ACQ_IDENTITY_KEY"]);

/** Suspension, réactivation ou archivage d'un commercial. */
exports.kitungaSetSalesAgentStatus = acquisitionCallable((data, uid) =>
  agents.setSalesAgentStatus({db: admin.firestore(), auth: admin.auth(), uid,
    data}));

const campaigns = require("./kitunga/acquisition/campaigns");
const campaignCall = (name) => acquisitionCallable((data, uid) =>
  campaigns[name]({db: admin.firestore(), uid, data}));

/** Barème de commission figé (montants en FCFA). */
exports.kitungaCreateCommissionRule = campaignCall("createCommissionRule");
/** Campagnes : création, modification, changement de statut. */
exports.kitungaCreateCampaign = campaignCall("createCampaign");
exports.kitungaUpdateCampaign = campaignCall("updateCampaign");
exports.kitungaSetCampaignStatus = campaignCall("setCampaignStatus");
/** Affectation d'un commercial à une campagne (code unique généré). */
exports.kitungaAssignAgent = campaignCall("assignAgent");
exports.kitungaEndAssignment = campaignCall("endAssignment");

/** Active et clôture les campagnes à leurs dates ; ferme les affectations. */
exports.kitungaCampaignSchedule = functions.region("us-west1")
    .pubsub.schedule("every 15 minutes")
    .onRun(() => campaigns.runCampaignSchedule({db: admin.firestore()}));

const links = require("./kitunga/acquisition/links");

/** Lien commercial /r/{code} (Firebase Hosting) : clic puis Google Play. */
exports.kitungaReferralRedirect = functions.region("us-west1")
    .runWith({secrets: ["ACQ_IDENTITY_KEY"], timeoutSeconds: 15})
    .https.onRequest((req, res) => links.handleReferralClick(req, res,
        {db: admin.firestore(), secret: process.env.ACQ_IDENTITY_KEY}));

/** Premier contact d'un appareil, envoyé par l'application. */
exports.kitungaRecordTouch = acquisitionCallable((data, uid) =>
  links.recordTouch({db: admin.firestore(), uid, data}));

const attribution = require("./kitunga/acquisition/attribution");

/** Confirme l'attribution d'un nouveau client à l'inscription. */
exports.kitungaClaimAttribution = acquisitionCallable((data, uid) =>
  attribution.claimAttribution({db: admin.firestore(), auth: admin.auth(), uid,
    data, identitySecret: process.env.ACQ_IDENTITY_KEY}), ["ACQ_IDENTITY_KEY"]);

const activations = require("./kitunga/acquisition/activations");

/**
 * Activation d'une installation, attestée par App Check (Play Integrity).
 * Jeton consommé : un jeton rejoué n'est jamais accepté comme vérifié.
 */
exports.kitungaRecordActivation = functions.region("us-west1")
    .runWith({timeoutSeconds: 30, consumeAppCheckToken: true})
    .https.onCall(async (data, context) => {
      try {
        return await activations.recordActivation({db: admin.firestore(),
          uid: context.auth && context.auth.uid, app: context.app,
          data: data || {}});
      } catch (e) {
        if (e instanceof AcquisitionError) {
          throw new functions.https.HttpsError(e.code, e.message);
        }
        console.error(e);
        throw new functions.https.HttpsError("internal",
            "L'opération n'a pas pu aboutir. Réessayez.");
      }
    });

const commissions = require("./kitunga/acquisition/commissions");

/** Abonnement payé (vérifié chez MTN) : commission « premier abonnement ». */
exports.kitungaOnSubscriptionPaid = functions.region("us-west1")
    .runWith({secrets: ["ACQ_IDENTITY_KEY"]})
    .firestore.document("Paiement/{paymentId}")
    .onUpdate((change, context) => commissions.processSubscriptionPayment({
      db: admin.firestore(), paymentId: context.params.paymentId,
      before: change.before.data(), after: change.after.data(),
      identitySecret: process.env.ACQ_IDENTITY_KEY}));

/** Nouvelle attribution : commission d'activation si déjà attestée. */
exports.kitungaOnAttributionCreated = functions.region("us-west1")
    .firestore.document("acquisition_attributions/{clientUid}")
    .onCreate((snap, context) => commissions.tryActivationCommission({
      db: admin.firestore(), clientUid: context.params.clientUid}));

/** Activation devenue vérifiée : commission d'activation des clients liés. */
exports.kitungaOnActivationVerified = functions.region("us-west1")
    .firestore.document("app_activations/{installation}")
    .onWrite((change, context) => {
      const after = change.after.exists ? change.after.data() : null;
      const before = change.before.exists ? change.before.data() : null;
      if (!after || after.verified !== true ||
        (before && before.verified === true)) {
        return null;
      }
      return commissions.activationCommissionsForInstallation({
        db: admin.firestore(), installation: context.params.installation});
    });

const payouts = require("./kitunga/acquisition/payouts");

/** Valider, rejeter ou annuler une commission (admin). */
exports.kitungaReviewCommission = acquisitionCallable((data, uid) =>
  payouts.reviewCommission({db: admin.firestore(), uid, data}));
/** Demande de versement (admin ou commercial). */
exports.kitungaRequestPayout = acquisitionCallable((data, uid) =>
  payouts.requestPayout({db: admin.firestore(), uid, data}));
/** Valider, refuser ou marquer payé un versement (admin). */
exports.kitungaDecidePayout = acquisitionCallable((data, uid) =>
  payouts.decidePayout({db: admin.firestore(), uid, data}));

const adminQuery = require("./kitunga/acquisition/admin_query");

/** Lecture des données du module pour l'interface admin. */
exports.kitungaSalesAdminQuery = acquisitionCallable((data, uid) =>
  adminQuery.salesAdminQuery({db: admin.firestore(), uid, data}));

const agentQuery = require("./kitunga/acquisition/agent_query");

/** Espace commercial : ses propres données seulement. */
exports.kitungaSalesAgentQuery = acquisitionCallable((data, uid) =>
  agentQuery.salesAgentQuery({db: admin.firestore(), uid, data}));

// ── Gestion (admin) : remboursements, abonnements, comptes ─────────────────
const adminOps = require("./kitunga/admin_ops");

exports.kitungaAdminOpsQuery = acquisitionCallable((data, uid) =>
  adminOps.adminOpsQuery({db: admin.firestore(), uid, data}));
/** Remboursement fait à la main par l'admin (référence du transfert). */
exports.kitungaMarkRefunded = acquisitionCallable((data, uid) =>
  adminOps.markRefunded({db: admin.firestore(), uid, data}));
/** Abonnement client offert ou prolongé (sans paiement, sans commission). */
exports.kitungaGrantSubscription = acquisitionCallable((data, uid) =>
  adminOps.grantSubscription({db: admin.firestore(), uid, data}));
/** Suspension ou réactivation d'un client, commerçant ou livreur. */
exports.kitungaSetAccountStatus = acquisitionCallable((data, uid) =>
  adminOps.setAccountStatus({db: admin.firestore(), auth: admin.auth(), uid,
    data}));

/** Démarre un paiement MoMo : montant recalculé par le serveur. */
exports.kitungaStartPayment = callable((data, uid) => payments.startPayment({
  db: admin.firestore(), momo, uid,
  sellerPath: String(data.sellerPath || ""),
  zone: data.zone, deliveryLocation: data.deliveryLocation, phone: data.phone,
}));

/** Vérifie le paiement et crée la commande (stock décrémenté). */
exports.kitungaConfirmPayment = callable((data, uid) =>
  payments.confirmPayment({
    db: admin.firestore(), momo, uid, referenceId: String(data.referenceId || ""),
  }));

/** Abonnement client payé par MoMo depuis la page web Kitunga. */
exports.kitungaStartSubscription = callable((data, uid) =>
  subscriptions.startSubscription({
    db: admin.firestore(), momo, uid,
    plan: String(data.plan || ""), phone: data.phone,
  }));

/** Vérifie le paiement et prolonge l'abonnement. */
exports.kitungaConfirmSubscription = callable((data, uid) =>
  subscriptions.confirmSubscription({
    db: admin.firestore(), momo, uid, referenceId: String(data.referenceId || ""),
  }));

/** Termine les paiements validés chez MTN mais jamais confirmés. */
exports.kitungaReconcilePayments = functions.region("us-west1")
    .runWith({secrets: COLLECTION_SECRETS})
    .pubsub.schedule("every 5 minutes")
    .onRun(() => reconcilePending({db: admin.firestore(), momo}));

/** Remboursement automatique d'une commande payée refusée ou annulée. */
exports.kitungaRefundOrder = functions.region("us-west1")
    .runWith({secrets: MOMO_SECRETS})
    .firestore.document("Orders/{orderId}")
    .onUpdate((change) => payments.refundOrder({
      db: admin.firestore(), momo,
      orderRef: change.after.ref, order: change.after.data(),
      previousStatus: change.before.get("status") || "",
    }));
