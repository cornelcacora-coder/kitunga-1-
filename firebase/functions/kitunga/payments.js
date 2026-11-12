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
const {subscriptionActive} = require("./subscriptions");
const {PaymentError} = require("./errors");
const {checkPhone, operatorOf} = require("./wallet");
const {feeFor} = require("./delivery_pricing");
const {openingStatus} = require("./hours");
const {usablePrescription, statusOf: prescriptionStatus} =
  require("./prescriptions");

const STOPPED = ["Refusée", "Annulée"];


function chunks(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
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
  phone, operator: rawOperator, now = new Date()}) {
  if (!uid) throw new PaymentError("unauthenticated", "Connexion requise.");
  if (!zone) throw new PaymentError("invalid-argument", "Quartier requis.");
  const operator = operatorOf(rawOperator);
  const payer = checkPhone(phone, operator);
  const userRef = db.doc(`User/${uid}`);
  const user = await userRef.get();
  if (!subscriptionActive(user)) {
    throw new PaymentError("failed-precondition",
        "Un abonnement Kitunga actif est nécessaire pour commander.");
  }
  const sellerRef = db.doc(sellerPath);
  // Commerce désactivé par l'admin : plus de commande possible.
  const seller = await sellerRef.get();
  if (seller.exists && seller.get("account_status") === "suspended") {
    throw new PaymentError("failed-precondition",
        "Ce commerce n'est plus disponible sur Kitunga.");
  }
  // Fermé momentanément par le commerçant (« Fermé maintenant »).
  if (seller.exists && seller.get("shop_closed_now") === true) {
    throw new PaymentError("failed-precondition",
        `${seller.get("display_name") || "Ce commerce"} est fermé pour le ` +
        "moment. Réessayez plus tard.");
  }
  // En dehors de ses horaires, le commerce ne prend pas de commande
  // (horaires non renseignés ou illisibles : rien n'est bloqué).
  const hours = seller.exists ?
    openingStatus(seller.get("Horraire"), now) : null;
  if (hours && !hours.open) {
    const name = seller.get("display_name") || "Ce commerce";
    throw new PaymentError("failed-precondition",
        `${name} est fermé en ce moment (${hours.label.replace("Fermé · ", "")}). ` +
        "Vous pourrez commander dès son ouverture.");
  }
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
  // Médicaments sur ordonnance : ordonnance validée par cette pharmacie.
  const needs = lines.some((l) => l.product &&
    l.product.requires_prescription === true);
  const prescription = needs ?
    await usablePrescription(db, uid, sellerRef.id, now) : null;
  // Frais selon la distance commerce → client (tarif réglé par l'admin).
  const delivery = await feeFor(db, seller, zone);
  const priced = priceCart(lines, zone, {prescriptionOk: !!prescription,
    fee: delivery.fee});
  if (priced.errors.length > 0) {
    throw new PaymentError("failed-precondition", priced.errors.join("\n"));
  }
  const reference = orderReference();
  const referenceId = await momo.requestToPay({
    amount: priced.total, phone: payer, externalId: reference, operator,
  });
  await db.doc(`Paiement/${referenceId}`).set({
    status: "En attente",
    reference_id: referenceId,
    order_unique_reference: reference,
    amount: priced.total,
    subtotal: priced.subtotal,
    delivery_fees: priced.fee,
    delivery_km: delivery.km,
    shop_zone: seller.exists ? seller.get("shop_zone") || "" : "",
    ...(prescription ? {prescription_id: prescription.id} : {}),
    user_ref: userRef,
    seller_ref: sellerRef,
    cart_ids: carts.map((c) => c.id),
    delivery_zone: zone,
    delivery_location: deliveryLocation || "",
    payer_phone: payer,
    operator,
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
  if (!uid) throw new PaymentError("unauthenticated", "Connexion requise.");
  if (!/^[A-Za-z0-9-]{8,64}$/.test(String(referenceId || ""))) {
    throw new PaymentError("not-found", "Paiement introuvable.");
  }
  const payRef = db.doc(`Paiement/${referenceId}`);
  const pay = await payRef.get();
  if (!pay.exists || pay.get("user_ref").id !== uid ||
      pay.get("kind") === "subscription") {
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
    // Articles provisoires créés par l'application à l'ajout au panier :
    // remplacés par ceux de la commande.
    const drafts = cartRefs.length === 0 ? [] : (await Promise.all(
        chunks(cartRefs, 30).map((part) => tx.get(db.collection("OrderItems")
            .where("cart_ref", "in", part))))).flatMap((q) => q.docs);

    const lines = carts.map((c, i) => ({
      cartRef: cartRefs[i],
      productRef: productRefs[i],
      quantity: c.exists ? c.get("quantity") : 0,
      options: c.exists ? c.get("options") || "" : "",
      product: products[i] && products[i].exists ? products[i].data() : null,
    }));
    // Ordonnance retenue au démarrage : encore validée et inutilisée ?
    const prescriptionId = fresh.get("prescription_id");
    const prescriptionRef = prescriptionId ?
      db.doc(`Prescriptions/${prescriptionId}`) : null;
    const prescription = prescriptionRef ? await tx.get(prescriptionRef) : null;
    const prescriptionOk = !!prescription && prescription.exists &&
      prescriptionStatus(prescription.data()) === "approved";
    // Frais vus et payés par le client (même si l'admin change le tarif).
    const priced = priceCart(lines, fresh.get("delivery_zone"),
        {prescriptionOk, fee: fresh.get("delivery_fees")});

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
      // Historique du stock : vente payée.
      tx.set(db.collection("StockMovements").doc(), {
        product_id: line.productRef.id,
        seller_uid: fresh.get("seller_ref").id,
        product_name: line.product.name || "", kind: "sale",
        quantity: line.quantity,
        before: Number(line.product.quantity) || 0,
        after: (Number(line.product.quantity) || 0) - line.quantity,
        reason: `Commande ${fresh.get("order_unique_reference")}`,
        by: "system", at: new Date()});
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
      // Quartier du commerce et distance : le livreur sait où récupérer.
      shop_zone: fresh.get("shop_zone") || "",
      delivery_km: fresh.get("delivery_km") ?? null,
      order_id: reference,
      order_unique_reference: reference,
      payment_reference: referenceId,
      payment_status: "Réussi",
      // Médicaments sur ordonnance : la pharmacie retrouve l'ordonnance.
      ...(priced.needsPrescription && prescriptionOk ? {
        prescription_ref: prescriptionRef,
        prescription_photos: prescription.get("photos") || [],
      } : {}),
    });
    if (priced.needsPrescription && prescriptionOk) {
      // Une ordonnance validée sert pour une seule commande.
      tx.update(prescriptionRef, {status: "used", order_ref: orderRef,
        used_at: new Date()});
    }
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
    drafts.filter((d) => !d.get("order_ref") &&
        d.get("user_ref") && d.get("user_ref").id === uid)
        .forEach((d) => tx.delete(d.ref));
    tx.update(payRef, {status: "Réussi", order_ref: orderRef});
    return {status: "paid", orderPath: orderRef.path};
  });
}

/**
 * Motif de refus d'un remboursement automatique, ou null s'il est légitime.
 * Tous les champs de la commande pouvant venir de l'application, seuls le
 * paiement écrit par le serveur et la réponse de MTN font foi.
 */
async function refundBlocker({momo, orderRef, order, previousStatus, pay}) {
  if (previousStatus !== "" && previousStatus !== "En attente") {
    return "Commande déjà acceptée au moment de l'arrêt.";
  }
  if (!pay.exists || pay.get("kind") === "subscription" ||
      pay.get("status") !== "Réussi" || !pay.get("payer_phone")) {
    return "Paiement serveur introuvable ou non réussi.";
  }
  const paidOrder = pay.get("order_ref");
  if (!paidOrder || paidOrder.path !== orderRef.path) {
    return "Ce paiement ne correspond pas à cette commande.";
  }
  if (Number(order.total_amount) !== Number(pay.get("amount"))) {
    return "Montant de la commande différent du montant payé.";
  }
  let mtn;
  try {
    mtn = await momo.paymentStatus(order.payment_reference);
  } catch (e) {
    return "Vérification MTN impossible.";
  }
  if (mtn.status !== "SUCCESSFUL") return "Paiement non confirmé par MTN.";
  if (mtn.amount != null && Number(mtn.amount) !== Number(pay.get("amount"))) {
    return "Montant MTN différent du montant enregistré.";
  }
  return null;
}

/**
 * Rembourse une commande payée puis refusée ou annulée (une seule fois).
 * previousStatus : statut de la commande avant la modification.
 */
async function refundOrder({db, momo, orderRef, order, previousStatus}) {
  if (!order.refund_needed || order.refund_status) return null;
  if (!STOPPED.includes(order.status) || !order.payment_reference) return null;
  const pay = await db.doc(`Paiement/${order.payment_reference}`).get();
  const blocker = await refundBlocker({momo, orderRef, order, previousStatus,
    pay});
  if (blocker) {
    await orderRef.update({refund_status: "À traiter manuellement",
      refund_error: blocker});
    return null;
  }
  const phone = pay.get("payer_phone");
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
      amount: pay.get("amount"), phone,
      externalId: pay.get("order_unique_reference"),
      paymentReference: order.payment_reference,
    });
    await orderRef.update({refund_status: "Envoyé", refund_reference: transferId});
    return transferId;
  } catch (e) {
    await orderRef.update({refund_status: "Échec", refund_error: String(e)});
    return null;
  }
}

module.exports = {startPayment, confirmPayment, refundOrder, PaymentError};
