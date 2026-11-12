const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const https = require("https");
const cors = require("cors")({ origin: true });
// Pas d'instance permanente (coût mensuel) : le proxy ne sert plus qu'en
// secours. Ne pas écrire « minInstances » : l'outil Firebase ne connaît pas
// les tarifs de us-west1 et refuserait le déploiement sans --force.
const corsProxyRuntimeOptions = { timeoutSeconds: 15 };
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
        // Image introuvable ou refusée : l'erreur est transmise telle quelle.
        res.status(resp.statusCode || 502);
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
// MTN MoMo ou Airtel Money, selon l'opérateur choisi par le client.
const momo = require("./kitunga/wallet");
const payments = require("./kitunga/payments");
const subscriptions = require("./kitunga/subscriptions");
const partners = require("./kitunga/partners");
const {reconcilePending} = require("./kitunga/reconcile");

// Encaissement (Collection) : paiements et abonnements. Remboursements
// (Disbursement) : seulement kitungaRefundOrder, qui exige un compte MTN
// Disbursement approvisionné.
const COLLECTION_SECRETS = [
  "MOMO_COLLECTION_USER", "MOMO_COLLECTION_KEY", "MOMO_COLLECTION_SUBSCRIPTION",
  // Airtel Money (valeur « absent » tant qu'Airtel n'est pas activé).
  "AIRTEL_CLIENT_ID", "AIRTEL_CLIENT_SECRET",
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

// ── Catalogue (admin) : catégories, produits, commerçants et livreurs ───────
const catalog = require("./kitunga/catalog");

exports.kitungaCatalogQuery = acquisitionCallable((data, uid) =>
  catalog.catalogQuery({db: admin.firestore(), uid, data}));
exports.kitungaSaveCategory = acquisitionCallable((data, uid) =>
  catalog.saveCategory({db: admin.firestore(), uid, data}));
exports.kitungaDeleteCategory = acquisitionCallable((data, uid) =>
  catalog.deleteCategory({db: admin.firestore(), uid, data}));
exports.kitungaSaveProduct = acquisitionCallable((data, uid) =>
  catalog.saveProduct({db: admin.firestore(), uid, data}));
exports.kitungaDeleteProduct = acquisitionCallable((data, uid) =>
  catalog.deleteProduct({db: admin.firestore(), uid, data}));
exports.kitungaSavePartner = acquisitionCallable((data, uid) =>
  catalog.savePartner({db: admin.firestore(), uid, data}));
/** Import d'un menu complet pour un commerce (admin). */
exports.kitungaImportMenu = acquisitionCallable((data, uid) =>
  catalog.importMenu({db: admin.firestore(), uid, data}));
// ── Commandes (admin) : annuler, attribuer un livreur, livrer, clôturer ────
const adminOrders = require("./kitunga/admin_orders");

exports.kitungaAdminOrderAction = acquisitionCallable((data, uid) =>
  adminOrders.adminOrderAction({db: admin.firestore(), uid, data}));
exports.kitungaCloseStaleOrders = acquisitionCallable((data, uid) =>
  adminOrders.closeStaleOrders({db: admin.firestore(), uid, data}));

// ── Nettoyage des données de test (admin) ──────────────────────────────────
const purgeData = require("./kitunga/purge");

/** Aperçu, suppression avec sauvegarde, restauration, historique. */
exports.kitungaPurgeTestData = functions.region("us-west1")
    .runWith({timeoutSeconds: 540, memory: "1GB"})
    .https.onCall(async (data, context) => {
      try {
        return await purgeData.purgeTestData({db: admin.firestore(),
          auth: admin.auth(), bucket: admin.storage().bucket(),
          uid: context.auth && context.auth.uid, data: data || {}});
      } catch (e) {
        if (e instanceof AcquisitionError) {
          throw new functions.https.HttpsError(e.code, e.message);
        }
        console.error(e);
        throw new functions.https.HttpsError("internal",
            "Le nettoyage n'a pas pu aboutir. Relancez-le : il reprend là où " +
            "il s'est arrêté.");
      }
    });

// ── Remise sécurisée et reçus ────────────────────────────────────────────
const delivery = require("./kitunga/delivery");

/** Le client obtient le code de remise de sa commande. */
exports.kitungaDeliveryCode = acquisitionCallable((data, uid) =>
  delivery.deliveryCode({db: admin.firestore(), uid, data}));
/** Le livreur confirme la remise (code du client + photo). */
exports.kitungaConfirmDelivery = acquisitionCallable((data, uid) =>
  delivery.confirmDelivery({db: admin.firestore(), uid, data}));
/** Le livreur signale un problème de livraison. */
exports.kitungaTakeDelivery = acquisitionCallable((data, uid) =>
  delivery.takeDelivery({db: admin.firestore(), uid, data}));

exports.kitungaReportDeliveryIssue = acquisitionCallable((data, uid) =>
  delivery.reportDeliveryIssue({db: admin.firestore(), uid, data}));
/** Reçu d'une commande livrée. */
exports.kitungaOrderReceipt = acquisitionCallable((data, uid) =>
  delivery.orderReceipt({db: admin.firestore(), uid, data}));

// ── Publicités et promotions (carrousel d'accueil) ──────────────────────
const banners = require("./kitunga/banners");

exports.kitungaListBanners = acquisitionCallable((data, uid) =>
  banners.listBanners({db: admin.firestore(), uid}));
exports.kitungaSaveBanner = acquisitionCallable((data, uid) =>
  banners.saveBanner({db: admin.firestore(), uid, data}));
exports.kitungaSetBannerActive = acquisitionCallable((data, uid) =>
  banners.setBannerActive({db: admin.firestore(), uid, data}));
exports.kitungaReorderBanners = acquisitionCallable((data, uid) =>
  banners.reorderBanners({db: admin.firestore(), uid, data}));
exports.kitungaDeleteBanner = acquisitionCallable((data, uid) =>
  banners.deleteBanner({db: admin.firestore(), uid, data}));
/** Bannières diffusées, lues par l'application (sans connexion). */
exports.kitungaPublicBanners = acquisitionCallable(() =>
  banners.publicBanners({db: admin.firestore()}));
exports.kitungaBannerClick = acquisitionCallable((data) =>
  banners.bannerClick({db: admin.firestore(), data}));
exports.kitungaReviewBanner = acquisitionCallable((data, uid) =>
  banners.reviewBanner({db: admin.firestore(), uid, data}));
// Publicités proposées par les vendeurs depuis l'application.
exports.kitungaSellerBanners = acquisitionCallable((data, uid) =>
  banners.sellerBanners({db: admin.firestore(), uid}));
exports.kitungaSaveSellerBanner = acquisitionCallable((data, uid) =>
  banners.saveSellerBanner({db: admin.firestore(), uid, data}));
exports.kitungaSetSellerBannerActive = acquisitionCallable((data, uid) =>
  banners.setSellerBannerActive({db: admin.firestore(), uid, data}));
exports.kitungaDeleteSellerBanner = acquisitionCallable((data, uid) =>
  banners.deleteSellerBanner({db: admin.firestore(), uid, data}));

// ── Ordonnances (pharmacies) ─────────────────────────────────────────────
const prescriptions = require("./kitunga/prescriptions");

exports.kitungaSubmitPrescription = acquisitionCallable((data, uid) =>
  prescriptions.submitPrescription({db: admin.firestore(), uid, data}));
exports.kitungaMyPrescriptions = acquisitionCallable((data, uid) =>
  prescriptions.myPrescriptions({db: admin.firestore(), uid, data}));
exports.kitungaSellerPrescriptions = acquisitionCallable((data, uid) =>
  prescriptions.sellerPrescriptions({db: admin.firestore(), uid}));
exports.kitungaReviewPrescription = acquisitionCallable((data, uid) =>
  prescriptions.reviewPrescription({db: admin.firestore(), uid, data}));

// ── Retours et échanges (boutiques, magasins) ────────────────────────────
const returns = require("./kitunga/returns");

exports.kitungaRequestReturn = acquisitionCallable((data, uid) =>
  returns.requestReturn({db: admin.firestore(), uid, data}));
exports.kitungaDecideReturn = acquisitionCallable((data, uid) =>
  returns.decideReturn({db: admin.firestore(), uid, data}));

// ── Notifications et rappels d'abonnement ────────────────────────────────
const notifications = require("./kitunga/notifications");
const orderEvents = require("./kitunga/order_events");

exports.kitungaSaveFcmToken = acquisitionCallable((data, uid) =>
  notifications.saveFcmToken({db: admin.firestore(), uid, data}));
exports.kitungaMyNotifications = acquisitionCallable((data, uid) =>
  notifications.myNotifications({db: admin.firestore(), uid}));
exports.kitungaMarkNotificationsRead = acquisitionCallable((data, uid) =>
  notifications.markNotificationsRead({db: admin.firestore(), uid}));
exports.kitungaAdminSendReminder = acquisitionCallable((data, uid) =>
  notifications.adminSendReminder({db: admin.firestore(),
    messaging: admin.messaging(), uid, data}));

/** Rappels d'abonnement, chaque matin à 9 h (Brazzaville). */
exports.kitungaSubscriptionReminders = functions.region("us-west1")
    .pubsub.schedule("0 9 * * *").timeZone("Africa/Brazzaville")
    .onRun(() => notifications.subscriptionReminders({
      db: admin.firestore(), messaging: admin.messaging()}));

/** Notifications au fil des commandes (commerce, livreurs, client, admin). */
exports.kitungaOrderEvents = functions.region("us-west1")
    .firestore.document("Orders/{orderId}")
    .onWrite((change) => orderEvents.onOrderWrite({
      db: admin.firestore(), messaging: admin.messaging(),
      before: change.before, after: change.after}));

/** Commandes prêtes depuis 20 min sans livreur : alerte admin. */
exports.kitungaStaleReadyOrders = functions.region("us-west1")
    .pubsub.schedule("every 10 minutes")
    .onRun(() => orderEvents.staleReadyOrders({
      db: admin.firestore(), messaging: admin.messaging()}));

/** Le livreur : en service / hors service, quartiers couverts. */
exports.kitungaSetDelivererStatus = acquisitionCallable((data, uid) =>
  orderEvents.setDelivererStatus({db: admin.firestore(), uid, data}));

/** Coordonnées des autres acteurs d'une commande (appel, WhatsApp). */
exports.kitungaOrderContacts = acquisitionCallable((data, uid) =>
  orderEvents.orderContacts({db: admin.firestore(), uid, data}));

// ── Cycle de vie des commandes : statuts calculés et historique ──────────
const lifecycle = require("./kitunga/lifecycle");
exports.kitungaOrderLifecycle = functions.region("us-west1")
    .firestore.document("Orders/{orderId}")
    .onWrite((change) => lifecycle.onOrderLifecycle({
      before: change.before, after: change.after}));
exports.kitungaOrderHistory = acquisitionCallable((data, uid) =>
  lifecycle.orderHistoryFor({db: admin.firestore(), uid, data}));
/** Positions GPS des courses terminées : effacées après 24 h. */
exports.kitungaPurgePositions = functions.region("us-west1")
    .pubsub.schedule("every 6 hours")
    .onRun(() => lifecycle.purgeOldPositions({db: admin.firestore()}));

// ── Attribution des courses (dispatch) ───────────────────────────────────
const dispatch = require("./kitunga/dispatch");
/** Le livreur accepte ou refuse la course proposée. */
exports.kitungaRespondMission = acquisitionCallable((data, uid) =>
  dispatch.respondMission({db: admin.firestore(),
    messaging: admin.messaging(), uid, data}));
/** Propositions expirées : la course passe au livreur suivant. */
exports.kitungaExpireOffers = functions.region("us-west1")
    .pubsub.schedule("every 1 minutes")
    .onRun(() => dispatch.expireOffers({db: admin.firestore(),
      messaging: admin.messaging()}));
exports.kitungaDelivererPing = acquisitionCallable((data, uid) =>
  dispatch.delivererPing({db: admin.firestore(), uid, data}));
exports.kitungaSetVehicle = acquisitionCallable((data, uid) =>
  dispatch.setVehicle({db: admin.firestore(), uid, data}));
exports.kitungaAdminDispatchSettings = acquisitionCallable((data, uid) =>
  dispatch.adminDispatchSettings({db: admin.firestore(), uid, data}));
exports.kitungaOrderMissions = acquisitionCallable((data, uid) =>
  dispatch.orderMissions({db: admin.firestore(), uid, data}));

// ── Messagerie et annonces ───────────────────────────────────────────────
const chat = require("./kitunga/messaging");
exports.kitungaOpenOrderChat = acquisitionCallable((data, uid) =>
  chat.openOrderChat({db: admin.firestore(), uid, data}));
exports.kitungaSendMessage = acquisitionCallable((data, uid) =>
  chat.sendMessage({db: admin.firestore(), messaging: admin.messaging(),
    uid, data}));
exports.kitungaConversationMessages = acquisitionCallable((data, uid) =>
  chat.conversationMessages({db: admin.firestore(), uid, data}));
exports.kitungaMyConversations = acquisitionCallable((data, uid) =>
  chat.myConversations({db: admin.firestore(), uid}));
exports.kitungaAdminAnnounce = acquisitionCallable((data, uid) =>
  chat.adminAnnounce({db: admin.firestore(), messaging: admin.messaging(),
    uid, data}));

// ── Suivi en direct de la livraison ──────────────────────────────────────
const tracking = require("./kitunga/delivery_tracking");
exports.kitungaDeliveryStep = acquisitionCallable((data, uid) =>
  tracking.deliveryStep({db: admin.firestore(), uid, data}));
exports.kitungaDeliveryPosition = acquisitionCallable((data, uid) =>
  tracking.deliveryPosition({db: admin.firestore(), uid, data}));
exports.kitungaDeliveryTracking = acquisitionCallable((data, uid) =>
  tracking.deliveryTracking({db: admin.firestore(), uid, data}));

/** Catégories visibles, lues par l'application mobile. */
exports.kitungaPublicCategories = acquisitionCallable(() =>
  catalog.publicCategories({db: admin.firestore()}));

/**
 * Opérateurs disponibles : Airtel Money s'active tout seul dès que ses clés
 * sont installées (scripts/airtel_cles.sh), sans nouvelle version de l'app.
 */
exports.kitungaPaymentOptions = callable(() => ({
  mtn: true, airtel: require("./kitunga/airtel").enabled()}));

// ── Tarif de livraison selon la distance ─────────────────────────────────
const deliveryPricing = require("./kitunga/delivery_pricing");
/** Frais de livraison affichés dans le panier, avant le paiement. */
exports.kitungaDeliveryQuote = acquisitionCallable((data, uid) =>
  deliveryPricing.deliveryQuote({db: admin.firestore(), uid, data}));
/** L'admin lit ou règle le tarif de livraison. */
exports.kitungaAdminDeliveryPricing = acquisitionCallable((data, uid) =>
  deliveryPricing.adminDeliveryPricing({db: admin.firestore(), uid, data}));

/** Démarre un paiement MoMo : montant recalculé par le serveur. */
exports.kitungaStartPayment = callable((data, uid) => payments.startPayment({
  db: admin.firestore(), momo, uid,
  sellerPath: String(data.sellerPath || ""),
  zone: data.zone, deliveryLocation: data.deliveryLocation, phone: data.phone,
  operator: data.operator,
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
    operator: data.operator,
  }));

/** Vérifie le paiement et prolonge l'abonnement. */
/** Module « Mon abonnement » : état, formules, historique. */
exports.kitungaMySubscription = acquisitionCallable((data, uid) =>
  subscriptions.mySubscription({db: admin.firestore(), uid}));

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
