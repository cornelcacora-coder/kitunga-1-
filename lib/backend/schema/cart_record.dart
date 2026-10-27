import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Le pannier de commande
class CartRecord extends FirestoreRecord {
  CartRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "product_ref" field.
  DocumentReference? _productRef;
  DocumentReference? get productRef => _productRef;
  bool hasProductRef() => _productRef != null;

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "quantity" field.
  int? _quantity;
  int get quantity => _quantity ?? 0;
  bool hasQuantity() => _quantity != null;

  // "price" field.
  double? _price;
  double get price => _price ?? 0.0;
  bool hasPrice() => _price != null;

  // "product_name" field.
  String? _productName;
  String get productName => _productName ?? '';
  bool hasProductName() => _productName != null;

  // "is_active" field.
  bool? _isActive;
  bool get isActive => _isActive ?? false;
  bool hasIsActive() => _isActive != null;

  // "is_ordered" field.
  bool? _isOrdered;
  bool get isOrdered => _isOrdered ?? false;
  bool hasIsOrdered() => _isOrdered != null;

  // "clearCartValue" field.
  String? _clearCartValue;
  String get clearCartValue => _clearCartValue ?? '';
  bool hasClearCartValue() => _clearCartValue != null;

  // "seller_ref" field.
  DocumentReference? _sellerRef;
  DocumentReference? get sellerRef => _sellerRef;
  bool hasSellerRef() => _sellerRef != null;

  // "photo" field.
  String? _photo;
  String get photo => _photo ?? '';
  bool hasPhoto() => _photo != null;

  void _initializeFields() {
    _productRef = snapshotData['product_ref'] as DocumentReference?;
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _quantity = castToType<int>(snapshotData['quantity']);
    _price = castToType<double>(snapshotData['price']);
    _productName = snapshotData['product_name'] as String?;
    _isActive = snapshotData['is_active'] as bool?;
    _isOrdered = snapshotData['is_ordered'] as bool?;
    _clearCartValue = snapshotData['clearCartValue'] as String?;
    _sellerRef = snapshotData['seller_ref'] as DocumentReference?;
    _photo = snapshotData['photo'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('Cart');

  static Stream<CartRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CartRecord.fromSnapshot(s));

  static Future<CartRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CartRecord.fromSnapshot(s));

  static CartRecord fromSnapshot(DocumentSnapshot snapshot) => CartRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CartRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CartRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CartRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CartRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCartRecordData({
  DocumentReference? productRef,
  DocumentReference? userRef,
  DateTime? createdAt,
  int? quantity,
  double? price,
  String? productName,
  bool? isActive,
  bool? isOrdered,
  String? clearCartValue,
  DocumentReference? sellerRef,
  String? photo,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'product_ref': productRef,
      'user_ref': userRef,
      'created_at': createdAt,
      'quantity': quantity,
      'price': price,
      'product_name': productName,
      'is_active': isActive,
      'is_ordered': isOrdered,
      'clearCartValue': clearCartValue,
      'seller_ref': sellerRef,
      'photo': photo,
    }.withoutNulls,
  );

  return firestoreData;
}

class CartRecordDocumentEquality implements Equality<CartRecord> {
  const CartRecordDocumentEquality();

  @override
  bool equals(CartRecord? e1, CartRecord? e2) {
    return e1?.productRef == e2?.productRef &&
        e1?.userRef == e2?.userRef &&
        e1?.createdAt == e2?.createdAt &&
        e1?.quantity == e2?.quantity &&
        e1?.price == e2?.price &&
        e1?.productName == e2?.productName &&
        e1?.isActive == e2?.isActive &&
        e1?.isOrdered == e2?.isOrdered &&
        e1?.clearCartValue == e2?.clearCartValue &&
        e1?.sellerRef == e2?.sellerRef &&
        e1?.photo == e2?.photo;
  }

  @override
  int hash(CartRecord? e) => const ListEquality().hash([
        e?.productRef,
        e?.userRef,
        e?.createdAt,
        e?.quantity,
        e?.price,
        e?.productName,
        e?.isActive,
        e?.isOrdered,
        e?.clearCartValue,
        e?.sellerRef,
        e?.photo
      ]);

  @override
  bool isValidKey(Object? o) => o is CartRecord;
}
