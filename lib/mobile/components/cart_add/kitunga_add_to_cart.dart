import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/subscription.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/random_data_util.dart' as random_data;
import '/index.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import '/mobile/components/prescription/kitunga_prescription.dart';
import '/mobile/components/product_options/customize_sheet.dart';
import '/mobile/main_app/subscription/my_subscription_page.dart';

/// Résultat d'un ajout au panier.
class KitungaCartAdd {
  const KitungaCartAdd(
      {required this.cart, this.orderItem, this.updated = false});

  /// Ligne du panier (nouvelle ou mise à jour).
  final CartRecord cart;
  final DocumentReference? orderItem;

  /// Le même produit (mêmes options) y était déjà : quantité augmentée.
  final bool updated;
}

/// Ajoute un produit au panier, avec les mêmes règles partout (page produit,
/// bouton + des cartes) :
/// - compte requis, abonnement actif pour un client ;
/// - ordonnance validée pour un médicament qui l'exige ;
/// - stock disponible ;
/// - options, suppléments, variantes : choix du client ;
/// - un seul commerce par panier (le client choisit de remplacer) ;
/// - même produit, mêmes options : quantité augmentée.
/// Renvoie null si rien n'a été ajouté (le client a été prévenu).
Future<KitungaCartAdd?> kitungaAddToCart(
  BuildContext context,
  ProductRecord product, {
  int quantity = 1,
  DocumentReference? sellerRef,
}) async {
  final seller = product.sellerRef ?? sellerRef;
  final role = valueOrDefault(currentUserDocument?.role, '');

  if (currentUserReference == null || role == 'Guest' || role.isEmpty) {
    await _askAccount(context);
    return null;
  }
  if (role == 'Seller') {
    _say(context, 'Les commerçants ne peuvent pas commander depuis leur compte.');
    return null;
  }
  if (!kitungaCanOrder()) {
    await _askSubscription(context);
    return null;
  }
  if (product.quantity <= 0) {
    _say(context, 'Ce produit est actuellement en rupture de stock.');
    return null;
  }
  if (product.requiresPrescription) {
    if (seller == null) return null;
    final pharmacy = await UserRecord.getDocumentOnce(seller);
    if (!context.mounted) return null;
    final ok = await kitungaPrescriptionGate(context,
        sellerUid: seller.id,
        sellerName: pharmacy.displayName.isEmpty
            ? 'la pharmacie'
            : pharmacy.displayName);
    if (!ok || !context.mounted) return null;
  }

  // Prix, quantité et options choisis.
  var unitPrice =
      product.salePrice > 0 ? product.salePrice : product.price.round();
  var chosenQuantity = quantity.clamp(1, product.quantity);
  var chosenOptions = '';
  if (product.options.isNotEmpty) {
    final custom = await showKitungaCustomizeSheet(context, product);
    if (custom == null || !context.mounted) return null;
    unitPrice = custom.unitPrice;
    chosenQuantity = custom.quantity;
    chosenOptions = custom.summary;
  }

  final lines = await queryCartRecordOnce(
    queryBuilder: (q) => q
        .where('user_ref', isEqualTo: currentUserReference)
        .where('is_ordered', isEqualTo: false)
        .where('is_active', isEqualTo: true),
  );
  if (!context.mounted) return null;

  // Un seul commerce par panier.
  final others = lines
      .where((c) => c.sellerRef != null && seller != null &&
          c.sellerRef != seller)
      .toList();
  if (others.isNotEmpty) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Un seul commerce par commande'),
        content: const Text(
            'Votre panier contient déjà les articles d\'un autre commerce. '
            'Voulez-vous le vider et ajouter ce produit ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Garder mon panier')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Vider et ajouter')),
        ],
      ),
    );
    if (replace != true || !context.mounted) return null;
    for (final line in others) {
      await line.reference.delete();
      FFAppState().removeFromCartitems(line.reference);
    }
    FFAppState().isSameOrder = false;
  }

  // Même produit, mêmes options : quantité augmentée.
  final duplicate = lines
      .where((c) =>
          c.productRef == product.reference && c.options == chosenOptions)
      .firstOrNull;
  if (duplicate != null) {
    final total = (duplicate.quantity + chosenQuantity)
        .clamp(1, product.quantity > 0 ? product.quantity : 1);
    await duplicate.reference.update({
      'quantity': total,
      // Prix unitaire : le sous-total le multiplie par la quantité.
      'price': unitPrice.toDouble(),
    });
    return KitungaCartAdd(cart: duplicate, updated: true);
  }

  // Nouvelle ligne du panier.
  final data = createCartRecordData(
    productRef: product.reference,
    userRef: currentUserReference,
    quantity: chosenQuantity,
    createdAt: getCurrentTimestamp,
    price: unitPrice.toDouble(),
    options: chosenOptions,
    productName: product.name,
    isActive: true,
    isOrdered: false,
    clearCartValue: 'Not Empty',
    sellerRef: seller,
  );
  final cartRef = CartRecord.collection.doc();
  await cartRef.set(data);
  final cart = CartRecord.getDocumentFromData(data, cartRef);

  if (FFAppState().isSameOrder != true) {
    // Identifiant de commande unique : horodatage + suffixe aléatoire.
    final ts = DateTime.now().millisecondsSinceEpoch;
    final suffix = random_data.randomString(6, 6, true, true, false);
    FFAppState().orderReferenceUnique = 'ORD-$ts-$suffix';
  }
  final itemRef = OrderItemsRecord.collection.doc();
  await itemRef.set(createOrderItemsRecordData(
    itemName: product.name,
    priceAtPurchase: unitPrice.toDouble(),
    quantity: chosenQuantity,
    image: product.prodImg,
    options: chosenOptions,
    cartRef: cartRef,
    userRef: currentUserReference,
    productRef: product.reference,
    orderRef: FFAppState().orderReferenceUnique,
  ));
  FFAppState().valueToClear = 'Not Empty';
  FFAppState().addToCartitems(cartRef);
  return KitungaCartAdd(cart: cart, orderItem: itemRef);
}

/// Bouton + d'une carte produit : ajout direct, puis « Voir le panier ».
Future<void> kitungaQuickAdd(BuildContext context, ProductRecord product) async {
  final r = await kitungaAddToCart(context, product);
  if (r == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(r.updated
          ? '${product.name} : quantité augmentée.'
          : '${product.name} ajouté au panier.'),
      action: SnackBarAction(
        label: 'Voir',
        onPressed: () => context.pushNamed(
          CartLastWidget.routeName,
          queryParameters: {
            'sellerRef': serializeParam(
                product.sellerRef, ParamType.DocumentReference),
          }.withoutNulls,
        ),
      ),
    ));
}

void _say(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<void> _askSubscription(BuildContext context) => showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Abonnement requis'),
        content: const Text(kitungaSubscriptionRequired),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Compris')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              openMySubscription(context);
            },
            child: const Text('S\'abonner'),
          ),
        ],
      ),
    );

Future<void> _askAccount(BuildContext context) => showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (sheet) => EmptyCardWidget(
        photo: 'assets/images/app/illustration_ou1qzr.png',
        title: 'Créez votre compte',
        description:
            'Créez votre compte Kitunga pour commander et suivre vos livraisons.',
        buttonText: 'Créer un compte',
        action: () async {
          Navigator.pop(sheet);
          context.pushNamed(
            SignWidget.routeName,
            queryParameters: {
              'accessibility': serializeParam('User', ParamType.String),
            }.withoutNulls,
          );
        },
      ),
    );
