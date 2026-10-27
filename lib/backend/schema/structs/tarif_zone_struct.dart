// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class TarifZoneStruct extends FFFirebaseStruct {
  TarifZoneStruct({
    /// The name of user location or quater
    String? quaterName,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _quaterName = quaterName,
        super(firestoreUtilData);

  // "QuaterName" field.
  String? _quaterName;
  String get quaterName => _quaterName ?? '';
  set quaterName(String? val) => _quaterName = val;

  bool hasQuaterName() => _quaterName != null;

  static TarifZoneStruct fromMap(Map<String, dynamic> data) => TarifZoneStruct(
        quaterName: data['QuaterName'] as String?,
      );

  static TarifZoneStruct? maybeFromMap(dynamic data) => data is Map
      ? TarifZoneStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'QuaterName': _quaterName,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'QuaterName': serializeParam(
          _quaterName,
          ParamType.String,
        ),
      }.withoutNulls;

  static TarifZoneStruct fromSerializableMap(Map<String, dynamic> data) =>
      TarifZoneStruct(
        quaterName: deserializeParam(
          data['QuaterName'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'TarifZoneStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is TarifZoneStruct && quaterName == other.quaterName;
  }

  @override
  int get hashCode => const ListEquality().hash([quaterName]);
}

TarifZoneStruct createTarifZoneStruct({
  String? quaterName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    TarifZoneStruct(
      quaterName: quaterName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

TarifZoneStruct? updateTarifZoneStruct(
  TarifZoneStruct? tarifZone, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    tarifZone
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addTarifZoneStructData(
  Map<String, dynamic> firestoreData,
  TarifZoneStruct? tarifZone,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (tarifZone == null) {
    return;
  }
  if (tarifZone.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && tarifZone.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final tarifZoneData = getTarifZoneFirestoreData(tarifZone, forFieldValue);
  final nestedData = tarifZoneData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = tarifZone.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getTarifZoneFirestoreData(
  TarifZoneStruct? tarifZone, [
  bool forFieldValue = false,
]) {
  if (tarifZone == null) {
    return {};
  }
  final firestoreData = mapToFirestore(tarifZone.toMap());

  // Add any Firestore field values
  mapToFirestore(tarifZone.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getTarifZoneListFirestoreData(
  List<TarifZoneStruct>? tarifZones,
) =>
    tarifZones?.map((e) => getTarifZoneFirestoreData(e, true)).toList() ?? [];
