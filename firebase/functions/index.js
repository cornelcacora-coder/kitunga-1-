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

const MOMO_SECRETS = [
  "MOMO_COLLECTION_USER", "MOMO_COLLECTION_KEY", "MOMO_COLLECTION_SUBSCRIPTION",
  "MOMO_DISBURSEMENT_USER", "MOMO_DISBURSEMENT_KEY",
  "MOMO_DISBURSEMENT_SUBSCRIPTION",
];

function callable(handler) {
  return functions.region("us-west1")
      .runWith({secrets: MOMO_SECRETS, timeoutSeconds: 60})
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

/** Remboursement automatique d'une commande payée refusée ou annulée. */
exports.kitungaRefundOrder = functions.region("us-west1")
    .runWith({secrets: MOMO_SECRETS})
    .firestore.document("Orders/{orderId}")
    .onUpdate((change) => payments.refundOrder({
      db: admin.firestore(), momo,
      orderRef: change.after.ref, order: change.after.data(),
    }));
