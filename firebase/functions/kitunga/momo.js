/**
 * Client MTN Mobile Money (Congo) côté serveur.
 *
 * Les clés ne sont plus dans l'application : elles sont lues dans les
 * secrets Firebase (voir firebase/functions/README-KITUNGA.md) :
 *   MOMO_COLLECTION_USER, MOMO_COLLECTION_KEY, MOMO_COLLECTION_SUBSCRIPTION
 *   MOMO_DISBURSEMENT_USER, MOMO_DISBURSEMENT_KEY,
 *   MOMO_DISBURSEMENT_SUBSCRIPTION
 *
 * KITUNGA_MOMO_MOCK=1 simule MTN (tests locaux uniquement).
 */
const axios = require("axios").default;
const crypto = require("crypto");

const BASE_URL = process.env.MOMO_BASE_URL || "https://proxy.momoapi.mtn.com";
const TARGET_ENV = process.env.MOMO_TARGET_ENV || "mtncongo";
const CURRENCY = "XAF";
// Un seul jeu de clés MTN pour toutes les plateformes NTEMO : chaque
// transaction porte le nom de la plateforme (rapprochement comptable).
const PLATFORM = "Kitunga";

function credentials(product) {
  const p = product === "disbursement" ? "DISBURSEMENT" : "COLLECTION";
  const user = process.env[`MOMO_${p}_USER`];
  const key = process.env[`MOMO_${p}_KEY`];
  const sub = process.env[`MOMO_${p}_SUBSCRIPTION`];
  if (!user || !key || !sub) {
    throw new Error(`Secrets MTN « ${product} » manquants.`);
  }
  return {user, key, sub};
}

async function token(product) {
  const {user, key, sub} = credentials(product);
  const res = await axios.post(`${BASE_URL}/${product}/token/`, null, {
    headers: {
      "Authorization": "Basic " +
        Buffer.from(`${user}:${key}`).toString("base64"),
      "Ocp-Apim-Subscription-Key": sub,
    },
    timeout: 20000,
  });
  return {accessToken: res.data.access_token, sub};
}

/** Numéro au format international congolais (242…), ou null. */
function normalizePhone(raw) {
  let p = String(raw || "").replace(/[^0-9]/g, "");
  if (p.startsWith("00242")) p = p.slice(2);
  if (!p.startsWith("242")) {
    if (p.startsWith("0") && p.length === 9) p = "242" + p;
    else if (p.length === 8) p = "2420" + p;
    else if (p.length > 0) p = "242" + p;
  }
  return p.length >= 11 ? p : null;
}

const mock = () => process.env.KITUNGA_MOMO_MOCK === "1";

/** Demande de paiement au client (il valide avec son code PIN). */
async function requestToPay({amount, phone, externalId,
  note = `commande ${externalId}`}) {
  const referenceId = crypto.randomUUID();
  if (mock()) return referenceId;
  const {accessToken, sub} = await token("collection");
  await axios.post(`${BASE_URL}/collection/v1_0/requesttopay`, {
    amount: String(Math.round(amount)),
    currency: CURRENCY,
    externalId: `${PLATFORM}-${externalId}`,
    payer: {partyIdType: "MSISDN", partyId: phone},
    payerMessage: PLATFORM,
    payeeNote: `Paiement venant de ${PLATFORM} - ${note}`,
  }, {
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "X-Reference-Id": referenceId,
      "X-Target-Environment": TARGET_ENV,
      "Ocp-Apim-Subscription-Key": sub,
    },
    timeout: 20000,
  });
  return referenceId;
}

/** SUCCESSFUL, FAILED ou PENDING (+ motif éventuel). */
async function paymentStatus(referenceId) {
  if (mock()) return {status: process.env.KITUNGA_MOMO_MOCK_STATUS || "SUCCESSFUL"};
  const {accessToken, sub} = await token("collection");
  const res = await axios.get(
      `${BASE_URL}/collection/v1_0/requesttopay/${referenceId}`, {
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "X-Target-Environment": TARGET_ENV,
          "Ocp-Apim-Subscription-Key": sub,
        },
        timeout: 15000,
      });
  return {status: res.data.status, reason: res.data.reason};
}

/** Remboursement : virement vers le numéro du client (Disbursement). */
async function transfer({amount, phone, externalId}) {
  const referenceId = crypto.randomUUID();
  if (mock()) return referenceId;
  const {accessToken, sub} = await token("disbursement");
  await axios.post(`${BASE_URL}/disbursement/v1_0/transfer`, {
    amount: String(Math.round(amount)),
    currency: CURRENCY,
    externalId: `${PLATFORM}-REMB-${externalId}`,
    payee: {partyIdType: "MSISDN", partyId: phone},
    payerMessage: `Remboursement ${PLATFORM}`,
    payeeNote: `Remboursement ${PLATFORM} - commande ${externalId}`,
  }, {
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "X-Reference-Id": referenceId,
      "X-Target-Environment": TARGET_ENV,
      "Ocp-Apim-Subscription-Key": sub,
    },
    timeout: 20000,
  });
  return referenceId;
}

module.exports = {normalizePhone, requestToPay, paymentStatus, transfer};
