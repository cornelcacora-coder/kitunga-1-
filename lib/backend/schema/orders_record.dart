import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Commande
class OrdersRecord extends FirestoreRecord {
  OrdersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "order_id" field.
  String? _orderId;
  String get orderId => _orderId ?? '';
  bool hasOrderId() => _orderId != null;

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "total_amount" field.
  double? _totalAmount;
  double get totalAmount => _totalAmount ?? 0.0;
  bool hasTotalAmount() => _totalAmount != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "items_count" field.
  int? _itemsCount;
  int get itemsCount => _itemsCount ?? 0;
  bool hasItemsCount() => _itemsCount != null;

  // "is_active" field.
  bool? _isActive;
  bool get isActive => _isActive ?? false;
  bool hasIsActive() => _isActive != null;

  // "deliverer_ref" field.
  String? _delivererRef;
  String get delivererRef => _delivererRef ?? '';
  bool hasDelivererRef() => _delivererRef != null;

  // "delivery_photo" field.
  String? _deliveryPhoto;
  String get deliveryPhoto => _deliveryPhoto ?? '';
  bool hasDeliveryPhoto() => _deliveryPhoto != null;

  // "otp_code" field.
  int? _otpCode;
  int get otpCode => _otpCode ?? 0;
  bool hasOtpCode() => _otpCode != null;

  // "seller_ref" field.
  DocumentReference? _sellerRef;
  DocumentReference? get sellerRef => _sellerRef;
  bool hasSellerRef() => _sellerRef != null;

  // "delivery_location" field.
  String? _deliveryLocation;
  String get deliveryLocation => _deliveryLocation ?? '';
  bool hasDeliveryLocation() => _deliveryLocation != null;

  // "user_signature" field.
  String? _userSignature;
  String get userSignature => _userSignature ?? '';
  bool hasUserSignature() => _userSignature != null;

  // "responded_at" field.
  DateTime? _respondedAt;
  DateTime? get respondedAt => _respondedAt;
  bool hasRespondedAt() => _respondedAt != null;

  // "deliver_reference" field.
  DocumentReference? _deliverReference;
  DocumentReference? get deliverReference => _deliverReference;
  bool hasDeliverReference() => _deliverReference != null;

  // "delivery_zone" field.
  String? _deliveryZone;
  String get deliveryZone => _deliveryZone ?? '';
  bool hasDeliveryZone() => _deliveryZone != null;

  // "delivery_fees" field.
  double? _deliveryFees;
  double get deliveryFees => _deliveryFees ?? 0.0;
  bool hasDeliveryFees() => _deliveryFees != null;

  // "order_unique_reference" field.
  String? _orderUniqueReference;
  String get orderUniqueReference => _orderUniqueReference ?? '';
  bool hasOrderUniqueReference() => _orderUniqueReference != null;

  void _initializeFields() {
    _orderId = snapshotData['order_id'] as String?;
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _totalAmount = castToType<double>(snapshotData['total_amount']);
    _status = snapshotData['status'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _itemsCount = castToType<int>(snapshotData['items_count']);
    _isActive = snapshotData['is_active'] as bool?;
    _delivererRef = snapshotData['deliverer_ref'] as String?;
    _deliveryPhoto = snapshotData['delivery_photo'] as String?;
    _otpCode = castToType<int>(snapshotData['otp_code']);
    _sellerRef = snapshotData['seller_ref'] as DocumentReference?;
    _deliveryLocation = snapshotData['delivery_location'] as String?;
    _userSignature = snapshotData['user_signature'] as String?;
    _respondedAt = snapshotData['responded_at'] as DateTime?;
    _deliverReference = snapshotData['deliver_reference'] as DocumentReference?;
    _deliveryZone = snapshotData['delivery_zone'] as String?;
    _deliveryFees = castToType<double>(snapshotData['delivery_fees']);
    _orderUniqueReference = snapshotData['order_unique_reference'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('Orders');

  static Stream<OrdersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => OrdersRecord.fromSnapshot(s));

  static Future<OrdersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => OrdersRecord.fromSnapshot(s));

  static OrdersRecord fromSnapshot(DocumentSnapshot snapshot) => OrdersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static OrdersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OrdersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'OrdersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OrdersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOrdersRecordData({
  String? orderId,
  DocumentReference? userRef,
  double? totalAmount,
  String? status,
  DateTime? createdAt,
  int? itemsCount,
  bool? isActive,
  String? delivererRef,
  String? deliveryPhoto,
  int? otpCode,
  DocumentReference? sellerRef,
  String? deliveryLocation,
  String? userSignature,
  DateTime? respondedAt,
  DocumentReference? deliverReference,
  String? deliveryZone,
  double? deliveryFees,
  String? orderUniqueReference,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'order_id': orderId,
      'user_ref': userRef,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt,
      'items_count': itemsCount,
      'is_active': isActive,
      'deliverer_ref': delivererRef,
      'delivery_photo': deliveryPhoto,
      'otp_code': otpCode,
      'seller_ref': sellerRef,
      'delivery_location': deliveryLocation,
      'user_signature': userSignature,
      'responded_at': respondedAt,
      'deliver_reference': deliverReference,
      'delivery_zone': deliveryZone,
      'delivery_fees': deliveryFees,
      'order_unique_reference': orderUniqueReference,
    }.withoutNulls,
  );

  return firestoreData;
}

class OrdersRecordDocumentEquality implements Equality<OrdersRecord> {
  const OrdersRecordDocumentEquality();

  @override
  bool equals(OrdersRecord? e1, OrdersRecord? e2) {
    return e1?.orderId == e2?.orderId &&
        e1?.userRef == e2?.userRef &&
        e1?.totalAmount == e2?.totalAmount &&
        e1?.status == e2?.status &&
        e1?.createdAt == e2?.createdAt &&
        e1?.itemsCount == e2?.itemsCount &&
        e1?.isActive == e2?.isActive &&
        e1?.delivererRef == e2?.delivererRef &&
        e1?.deliveryPhoto == e2?.deliveryPhoto &&
        e1?.otpCode == e2?.otpCode &&
        e1?.sellerRef == e2?.sellerRef &&
        e1?.deliveryLocation == e2?.deliveryLocation &&
        e1?.userSignature == e2?.userSignature &&
        e1?.respondedAt == e2?.respondedAt &&
        e1?.deliverReference == e2?.deliverReference &&
        e1?.deliveryZone == e2?.deliveryZone &&
        e1?.deliveryFees == e2?.deliveryFees &&
        e1?.orderUniqueReference == e2?.orderUniqueReference;
  }

  @override
  int hash(OrdersRecord? e) => const ListEquality().hash([
        e?.orderId,
        e?.userRef,
        e?.totalAmount,
        e?.status,
        e?.createdAt,
        e?.itemsCount,
        e?.isActive,
        e?.delivererRef,
        e?.deliveryPhoto,
        e?.otpCode,
        e?.sellerRef,
        e?.deliveryLocation,
        e?.userSignature,
        e?.respondedAt,
        e?.deliverReference,
        e?.deliveryZone,
        e?.deliveryFees,
        e?.orderUniqueReference
      ]);

  @override
  bool isValidKey(Object? o) => o is OrdersRecord;
}
