import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PaiementRecord extends FirestoreRecord {
  PaiementRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  void _initializeFields() {
    _status = snapshotData['status'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('Paiement');

  static Stream<PaiementRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => PaiementRecord.fromSnapshot(s));

  static Future<PaiementRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => PaiementRecord.fromSnapshot(s));

  static PaiementRecord fromSnapshot(DocumentSnapshot snapshot) =>
      PaiementRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static PaiementRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      PaiementRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'PaiementRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is PaiementRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createPaiementRecordData({
  String? status,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'status': status,
    }.withoutNulls,
  );

  return firestoreData;
}

class PaiementRecordDocumentEquality implements Equality<PaiementRecord> {
  const PaiementRecordDocumentEquality();

  @override
  bool equals(PaiementRecord? e1, PaiementRecord? e2) {
    return e1?.status == e2?.status;
  }

  @override
  int hash(PaiementRecord? e) => const ListEquality().hash([e?.status]);

  @override
  bool isValidKey(Object? o) => o is PaiementRecord;
}
