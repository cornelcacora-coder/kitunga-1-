import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SystemLogsRecord extends FirestoreRecord {
  SystemLogsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "timestamp" field.
  DateTime? _timestamp;
  DateTime? get timestamp => _timestamp;
  bool hasTimestamp() => _timestamp != null;

  // "event_type" field.
  String? _eventType;
  String get eventType => _eventType ?? '';
  bool hasEventType() => _eventType != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "response_time" field.
  DateTime? _responseTime;
  DateTime? get responseTime => _responseTime;
  bool hasResponseTime() => _responseTime != null;

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "delivery_date" field.
  DateTime? _deliveryDate;
  DateTime? get deliveryDate => _deliveryDate;
  bool hasDeliveryDate() => _deliveryDate != null;

  void _initializeFields() {
    _timestamp = snapshotData['timestamp'] as DateTime?;
    _eventType = snapshotData['event_type'] as String?;
    _status = snapshotData['status'] as String?;
    _responseTime = snapshotData['response_time'] as DateTime?;
    _userId = snapshotData['user_id'] as String?;
    _deliveryDate = snapshotData['delivery_date'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('system_logs');

  static Stream<SystemLogsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => SystemLogsRecord.fromSnapshot(s));

  static Future<SystemLogsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => SystemLogsRecord.fromSnapshot(s));

  static SystemLogsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      SystemLogsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static SystemLogsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      SystemLogsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'SystemLogsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is SystemLogsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createSystemLogsRecordData({
  DateTime? timestamp,
  String? eventType,
  String? status,
  DateTime? responseTime,
  String? userId,
  DateTime? deliveryDate,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'timestamp': timestamp,
      'event_type': eventType,
      'status': status,
      'response_time': responseTime,
      'user_id': userId,
      'delivery_date': deliveryDate,
    }.withoutNulls,
  );

  return firestoreData;
}

class SystemLogsRecordDocumentEquality implements Equality<SystemLogsRecord> {
  const SystemLogsRecordDocumentEquality();

  @override
  bool equals(SystemLogsRecord? e1, SystemLogsRecord? e2) {
    return e1?.timestamp == e2?.timestamp &&
        e1?.eventType == e2?.eventType &&
        e1?.status == e2?.status &&
        e1?.responseTime == e2?.responseTime &&
        e1?.userId == e2?.userId &&
        e1?.deliveryDate == e2?.deliveryDate;
  }

  @override
  int hash(SystemLogsRecord? e) => const ListEquality().hash([
        e?.timestamp,
        e?.eventType,
        e?.status,
        e?.responseTime,
        e?.userId,
        e?.deliveryDate
      ]);

  @override
  bool isValidKey(Object? o) => o is SystemLogsRecord;
}
