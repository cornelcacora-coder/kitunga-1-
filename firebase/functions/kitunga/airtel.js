/**
 * Client Airtel Money (Congo) côté serveur — API « Open API » d'Airtel
 * Africa. Même interface que momo.js (requestToPay, paymentStatus,
 * transfer) pour que les paiements, abonnements et remboursements
 * fonctionnent de la même façon.
 *
 * Secrets Firebase (scripts/airtel_cles.sh) :
 *   AIRTEL_CLIENT_ID, AIRTEL_CLIENT_SECRET
 * Valeur « absent » : Airtel Money pas encore activé (message clair au
 * client, rien n'est envoyé à Airtel).
 *
 * Réglages (variables d'environnement, valeurs par défaut ci-dessous) :
 *   AIRTEL_BASE_URL       https://openapi.airtel.africa
 *   AIRTEL_PAYMENTS_PATH  /merchant/v1/payments/
 *
 * KITUNGA_MOMO_MOCK=1 simule aussi Airtel (tests locaux uniquement).
 */
const axios = require("axios").default;
const crypto = require("crypto");

const BASE_URL = process.env.AIRTEL_BASE_URL || "https://openapi.airtel.africa";
const PAYMENTS_PATH = process.env.AIRTEL_PAYMENTS_PATH ||
  "/merchant/v1/payments/";
const COUNTRY = "CG";
const CURRENCY = "XAF";
const PLATFORM = "Kitunga";
/** Préfixe des références Airtel (les références MTN sont des UUID). */
const PREFIX = "AM";

class AirtelUnavailable extends Error {}

const clean = (v) => String(v || "").replace(/\s+/g, "");

function credentials() {
  const id = clean(process.env.AIRTEL_CLIENT_ID);
  const secret = clean(process.env.AIRTEL_CLIENT_SECRET);
  if (!id || !secret || id === "absent" || secret === "absent") {
    throw new AirtelUnavailable("Secrets Airtel manquants.");
  }
  return {id, secret};
}

/** Airtel Money est-il configuré ? */
function enabled() {
  try {
    credentials();
    return true;
  } catch (e) {
    return mock();
  }
}

const mock = () => process.env.KITUNGA_MOMO_MOCK === "1";

async function headers() {
  const {id, secret} = credentials();
  const res = await axios.post(`${BASE_URL}/auth/oauth2/token`, {
    client_id: id, client_secret: secret, grant_type: "client_credentials",
  }, {headers: {"Content-Type": "application/json", "Accept": "*/*"},
    timeout: 20000});
  return {
    "Authorization": `Bearer ${res.data.access_token}`,
    "Content-Type": "application/json",
    "Accept": "*/*",
    "X-Country": COUNTRY,
    "X-Currency": CURRENCY,
  };
}

/** 242051234567 → 051234567 (Airtel attend le numéro sans indicatif). */
const msisdn = (phone) => String(phone).replace(/^242/, "");

/** Demande de paiement : le client valide avec son code PIN Airtel. */
async function requestToPay({amount, phone, externalId,
  note = `commande ${externalId}`}) {
  const referenceId = PREFIX + crypto.randomBytes(10).toString("hex")
      .toUpperCase();
  if (mock()) return referenceId;
  await axios.post(`${BASE_URL}${PAYMENTS_PATH}`, {
    reference: `${PLATFORM} - ${note}`.slice(0, 64),
    subscriber: {country: COUNTRY, currency: CURRENCY, msisdn: msisdn(phone)},
    transaction: {amount: Math.round(amount), country: COUNTRY,
      currency: CURRENCY, id: referenceId},
  }, {headers: await headers(), timeout: 20000});
  return referenceId;
}

// TS : réussi ; TF : échoué ; TE : expiré ; TIP / TA : en cours.
const STATUS = {TS: "SUCCESSFUL", TF: "FAILED", TE: "FAILED"};

/** SUCCESSFUL, FAILED ou PENDING (même forme que momo.paymentStatus). */
async function paymentStatus(referenceId) {
  if (mock()) {
    return {status: process.env.KITUNGA_MOMO_MOCK_STATUS || "SUCCESSFUL",
      airtelMoneyId: `MOCK-${referenceId}`};
  }
  const res = await axios.get(
      `${BASE_URL}/standard/v1/payments/${referenceId}`,
      {headers: await headers(), timeout: 15000});
  const t = (res.data && res.data.data && res.data.data.transaction) || {};
  return {status: STATUS[t.status] || "PENDING", reason: t.message,
    airtelMoneyId: t.airtel_money_id};
}

/**
 * Remboursement d'un paiement Airtel : l'API « refund » rend la somme au
 * numéro qui a payé (paymentReference = référence Kitunga du paiement).
 */
async function transfer({paymentReference}) {
  const pay = await paymentStatus(paymentReference);
  if (pay.status !== "SUCCESSFUL" || !pay.airtelMoneyId) {
    throw new Error("Paiement Airtel non confirmé : remboursement impossible.");
  }
  if (mock()) return `REMB-${paymentReference}`;
  const res = await axios.post(`${BASE_URL}/standard/v1/payments/refund`, {
    transaction: {airtel_money_id: pay.airtelMoneyId},
  }, {headers: await headers(), timeout: 20000});
  const t = (res.data && res.data.data && res.data.data.transaction) || {};
  if (t.status && STATUS[t.status] === "FAILED") {
    throw new Error(`Remboursement Airtel refusé (${t.status}).`);
  }
  return `REMB-${pay.airtelMoneyId}`;
}

const isAirtelReference = (ref) => String(ref || "").startsWith(PREFIX);

module.exports = {requestToPay, paymentStatus, transfer, enabled,
  isAirtelReference, AirtelUnavailable};
