/** Erreur montrée telle quelle au client (code = code HttpsError). */
class PaymentError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

module.exports = {PaymentError};
