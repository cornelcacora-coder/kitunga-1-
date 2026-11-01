/**
 * Paiement d'une commande, contrôlé par le serveur :
 *  1. startPayment   : panier relu, prix et stock recalculés, demande MTN.
 *  2. confirmPayment : si MTN confirme, transaction (stock décrémenté,
 *     commande et articles créés, panier vidé).
 *  3. refundOrder    : remboursement d'une commande payée puis refusée ou
 *     annulée.
 *
 * db et momo sont injectés (tests avec l'émulateur et un MTN simulé).
 */
const {priceCart} = require("./pricing");

const STOPPED = ["Refusée", "Annulée"];

class PaymentError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function orderReference() {
  const n = Date.now().toString(36).toUpperCase();
  const r = Math.random().toString(36).slice(2, 5).toUpperCase();
  return `KT-${n}-${r}`;
}

async function loadCart(db, userRef, sellerRef) {
  const snap = await db.collection("Cart")
      .where("user_ref", "==", userRef)
      .where("seller_ref", "==", sellerRef)
      .where("is_ordered", "==", false)
      .get();
  return snap.docs;
}

/** Démarre un paiement. Renvoie {referenceId, amount, subtotal, fee}. */
async function startPayment({db, momo, uid, sellerPath, zone, deliveryLocation,
  phone}) {
  if (!uid) throw new PaymentError("unauthenticated", "Connexion requise.");
  if (!zone) throw new PaymentError("invalid-argument", "Quartier requis.");
  const payer = momo.normalizePhone(phone);
  if (!payer) {
    throw new PaymentError("invalid-argument", "Numéro MTN invalide.");
  }
  const userRef = db.doc(`User/${uid}`);
  const sellerRef = db.doc(sellerPath);
  const carts = await loadCart(db, userRef, sellerRef);
  if (carts.length === 0) {
    throw new PaymentError("failed-precondition", "Votre panier est vide.");
  }
  const lines = await Promise.all(carts.map(async (c) => {
    const data = c.data();
    const product = data.product_ref ? await data.product_ref.get() : null;
    return {
      cartId: c.id,
      quantity: data.quantity,
      options: data.options || "",
      product: product && product.exists ? product.data() : null,
    };
  }));
  const priced = priceCart(lines, zone);
  if (priced.errors.length > 0) {
    throw new PaymentError("failed-precondition", priced.errors.join("\n"));
  }
  const reference = orderReference();
  const referenceId = await momo.requestToPay({
    amount: priced.total, phone: payer, externalId: reference,
  });
  await db.doc(`Paiement/${referenceId}`).set({
    status: "En attente",
    reference_id: referenceId,
    order_unique_reference: reference,
    amount: priced.total,
    subtotal: priced.subtotal,
    delivery_fees: priced.fee,
    user_ref: userRef,
    seller_ref: sellerRef,
    cart_ids: carts.map((c) => c.id),
    delivery_zone: zone,
    delivery_location: deliveryLocation || "",
    payer_phone: payer,
    operator: "MTN",
    created_at: new Date(),
  });
  return {referenceId, amount: priced.total, subtotal: priced.subtotal,
    fee: priced.fee};
}

/**
 * Vérifie le paiement auprès de MTN et, s'il est réussi, crée la commande.
 * Renvoie {status: 'pending'|'failed'|'paid'|'paid_refund', orderPath?}.
 */
async function confirmPayment({db, momo, uid, referenceId}) {
  const payRef = db.doc(`Paiement/${referenceId}`);
  const pay = await payRef.get();
  if (!pay.exists || pay.get("user_ref").id !== uid) {
    throw new PaymentError("not-found", "Paiement introuvable.");
  }
  if (pay.get("status") === "Réussi") {
    return {status: "paid", orderPath: pay.get("order_ref").path};
  }
  if (pay.get("status") === "Echec") return {status: "failed"};

  const mtn = await momo.paymentStatus(referenceId);
  if (mtn.status === "FAILED") {
    await payRef.update({status: "Echec", message: mtn.reason || ""});
    return {status: "failed", reason: mtn.reason};
  }
  if (mtn.status !== "SUCCESSFUL") return {status: "pending"};

  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(payRef);
    if (fresh.get("status") === "Réussi") {
      return {status: "paid", orderPath: fresh.get("order_ref").path};
    }
    const cartRefs = fresh.get("cart_ids").map((id) => db.doc(`Cart/${id}`));
    const carts = await Promise.all(cartRefs.map((r) => tx.get(r)));
    const productRefs = carts.map((c) => c.exists ? c.get("product_ref") : null);
    const products = await Promise.all(
        productRefs.map((r) => r ? tx.get(r) : null));

    const lines = carts.map((c, i) => ({
      cartRef: cartRefs[i],
      productRef: productRefs[i],
      quantity: c.exists ? c.get("quantity") : 0,
      options: c.exists ? c.get("options") || "" : "",
      product: products[i] && products[i].exists ? products[i].data() : null,
    }));
    const priced = priceCart(lines, fresh.get("delivery_zone"));

    // Payé mais plus disponible (stock pris entre-temps) : à rembourser.
    if (priced.errors.length > 0 || priced.total !== fresh.get("amount")) {
      tx.update(payRef, {
        status: "Réussi - non livrable",
        refund_needed: true,
        message: priced.errors.join("\n") || "Montant modifié entre-temps.",
      });
      return {status: "paid_refund", reason: priced.errors.join("\n")};
    }

    // Stock : produit, puis variantes choisies.
    priced.lines.forEach((line) => {
      const update = {quantity: Number(line.product.quantity) - line.quantity};
      if (line.picks.length > 0 && Array.isArray(line.product.options)) {
        update.options = line.product.options.map((g) => ({
          ...g,
          choices: (g.choices || []).map((c) =>
            c.stock != null && line.picks.some((p) =>
              p.group === g.name && p.choice === c.label) ?
              {...c, stock: Number(c.stock) - line.quantity} : c),
        }));
      }
      tx.update(line.productRef, update);
    });

    const reference = fresh.get("order_unique_reference");
    const orderRef = db.collection("Orders").doc();
    tx.set(orderRef, {
      created_at: new Date(),
      user_ref: fresh.get("user_ref"),
      seller_ref: fresh.get("seller_ref"),
      is_active: true,
      status: "En attente",
      total_amount: priced.total,
      delivery_fees: priced.fee,
      delivery_zone: fresh.get("delivery_zone"),
      delivery_location: fresh.get("delivery_location"),
      order_id: reference,
      order_unique_reference: reference,
      payment_reference: referenceId,
      payment_status: "Réussi",
    });
    priced.lines.forEach((line) => {
      tx.set(db.collection("OrderItems").doc(), {
        order_ref: reference,
        user_ref: fresh.get("user_ref"),
        product_ref: line.productRef,
        item_name: line.product.name || "",
        image: line.product.prod_img || "",
        quantity: line.quantity,
        price_at_purchase: line.unitPrice,
        options: line.options,
      });
      tx.delete(line.cartRef);
    });
    tx.update(payRef, {status: "Réussi", order_ref: orderRef});
    return {status: "paid", orderPath: orderRef.path};
  });
}

/** Rembourse une commande payée puis refusée ou annulée (une seule fois). */
async function refundOrder({db, momo, orderRef, order}) {
  if (!order.refund_needed || order.refund_status) return null;
  if (!STOPPED.includes(order.status) || !order.payment_reference) return null;
  const pay = await db.doc(`Paiement/${order.payment_reference}`).get();
  const phone = pay.exists ? pay.get("payer_phone") : null;
  if (!phone) {
    await orderRef.update({refund_status: "À traiter manuellement"});
    return null;
  }
  // Verrou : évite un double remboursement si la fonction est relancée.
  const locked = await db.runTransaction(async (tx) => {
    const cur = await tx.get(orderRef);
    if (cur.get("refund_status")) return false;
    tx.update(orderRef, {refund_status: "En cours"});
    return true;
  });
  if (!locked) return null;
  try {
    const transferId = await momo.transfer({
      amount: order.total_amount, phone, externalId: order.order_unique_reference,
    });
    await orderRef.update({refund_status: "Envoyé", refund_reference: transferId});
    return transferId;
  } catch (e) {
    await orderRef.update({refund_status: "Échec", refund_error: String(e)});
    return null;
  }
}

module.exports = {startPayment, confirmPayment, refundOrder, PaymentError};
