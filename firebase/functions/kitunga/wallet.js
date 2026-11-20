/**
 * Aiguillage des paiements mobiles : MTN MoMo ou Airtel Money.
 *
 * Même interface que momo.js, avec l'opérateur en plus :
 * - requestToPay({..., operator}) envoie la demande à l'opérateur choisi ;
 * - paymentStatus(ref) et transfer({paymentReference, ...}) retrouvent
 *   l'opérateur grâce à la référence (« AM… » pour Airtel).
 *
 * Numéros au Congo : MTN 06, Airtel 05 et 04.
 */
const mtn = require("./momo");
const airtel = require("./airtel");
const {PaymentError} = require("./errors");

const OPERATORS = {
  MTN: {label: "MTN MoMo", prefixes: ["06"]},
  Airtel: {label: "Airtel Money", prefixes: ["05", "04"]},
};

/** « airtel », « Airtel Money »… → « Airtel » ; sinon MTN. */
function operatorOf(raw) {
  return /airtel/i.test(String(raw || "")) ? "Airtel" : "MTN";
}

const WalletError = (message) =>
  new PaymentError("invalid-argument", message);

/**
 * Numéro au format 242…, contrôlé pour l'opérateur choisi.
 * Lève une PaymentError avec un message clair si le numéro ne convient pas.
 */
function checkPhone(phone, operator) {
  const op = OPERATORS[operator];
  const p = mtn.normalizePhone(phone);
  if (!p) throw WalletError(`Numéro ${op.label} invalide.`);
  const national = p.slice(3, 5);
  const other = Object.entries(OPERATORS).find(([k, o]) => k !== operator &&
    o.prefixes.includes(national));
  if (other) {
    throw WalletError(`Ce numéro est un numéro ${other[1].label}. ` +
      `Choisissez ${other[1].label} ou entrez un numéro ${op.label}.`);
  }
  if (operator === "Airtel" && !airtel.enabled()) {
    throw WalletError("Le paiement Airtel Money n'est pas encore " +
      "disponible. Payez avec MTN MoMo pour le moment.");
  }
  return p;
}

const pick = (ref) => airtel.isAirtelReference(ref) ? airtel : mtn;

module.exports = {
  OPERATORS,
  operatorOf,
  checkPhone,
  normalizePhone: mtn.normalizePhone,
  requestToPay: (args) =>
    (operatorOf(args.operator) === "Airtel" ? airtel : mtn).requestToPay(args),
  paymentStatus: (ref) => pick(ref).paymentStatus(ref),
  transfer: (args) => pick(args.paymentReference).transfer(args),
};
