import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class OrderItemsRecord extends FirestoreRecord {
  OrderItemsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "product_ref" field.
  DocumentReference? _productRef;
  DocumentReference? get productRef => _productRef;
  bool hasProductRef() => _productRef != null;

  // "item_name" field.
  String? _itemName;
  String get itemName => _itemName ?? '';
  bool hasItemName() => _itemName != null;

  // "price_at_purchase" field.
  double? _priceAtPurchase;
  double get priceAtPurchase => _priceAtPurchase ?? 0.0;
  bool hasPriceAtPurchase() => _priceAtPurchase != null;

  // "quantity" field.
  int? _quantity;
  int get quantity => _quantity ?? 0;
  bool hasQuantity() => _quantity != null;

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  bool hasImage() => _image != null;

  // "cart_ref" field.
  DocumentReference? _cartRef;
  DocumentReference? get cartRef => _cartRef;
  bool hasCartRef() => _cartRef != null;

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "order_ref" field.
  String? _orderRef;
  String get orderRef => _orderRef ?? '';
  bool hasOrderRef() => _orderRef != null;

  void _initializeFields() {
    _productRef = snapshotData['product_ref'] as DocumentReference?;
    _itemName = snapshotData['item_name'] as String?;
    _priceAtPurchase = castToType<double>(snapshotData['price_at_purchase']);
    _quantity = castToType<int>(snapshotData['quantity']);
    _image = snapshotData['image'] as String?;
    _cartRef = snapshotData['cart_ref'] as DocumentReference?;
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _orderRef = snapshotData['order_ref'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('OrderItems');

  static Stream<OrderItemsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => OrderItemsRecord.fromSnapshot(s));

  static Future<OrderItemsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => OrderItemsRecord.fromSnapshot(s));

  static OrderItemsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      OrderItemsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static OrderItemsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OrderItemsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'OrderItemsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OrderItemsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOrderItemsRecordData({
  DocumentReference? productRef,
  String? itemName,
  double? priceAtPurchase,
  int? quantity,
  String? image,
  DocumentReference? cartRef,
  DocumentReference? userRef,
  String? orderRef,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'product_ref': productRef,
      'item_name': itemName,
      'price_at_purchase': priceAtPurchase,
      'quantity': quantity,
      'image': image,
      'cart_ref': cartRef,
      'user_ref': userRef,
      'order_ref': orderRef,
    }.withoutNulls,
  );

  return firestoreData;
}

class OrderItemsRecordDocumentEquality implements Equality<OrderItemsRecord> {
  const OrderItemsRecordDocumentEquality();

  @override
  bool equals(OrderItemsRecord? e1, OrderItemsRecord? e2) {
    return e1?.productRef == e2?.productRef &&
        e1?.itemName == e2?.itemName &&
        e1?.priceAtPurchase == e2?.priceAtPurchase &&
        e1?.quantity == e2?.quantity &&
        e1?.image == e2?.image &&
        e1?.cartRef == e2?.cartRef &&
        e1?.userRef == e2?.userRef &&
        e1?.orderRef == e2?.orderRef;
  }

  @override
  int hash(OrderItemsRecord? e) => const ListEquality().hash([
        e?.productRef,
        e?.itemName,
        e?.priceAtPurchase,
        e?.quantity,
        e?.image,
        e?.cartRef,
        e?.userRef,
        e?.orderRef
      ]);

  @override
  bool isValidKey(Object? o) => o is OrderItemsRecord;
}
