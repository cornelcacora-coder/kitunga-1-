// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DeliveryDataStruct extends FFFirebaseStruct {
  DeliveryDataStruct({
    /// The user zone (location)
    String? zoneName,

    /// The user delivery fees for purshasing
    double? deliveryFees,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _zoneName = zoneName,
        _deliveryFees = deliveryFees,
        super(firestoreUtilData);

  // "zoneName" field.
  String? _zoneName;
  String get zoneName => _zoneName ?? '';
  set zoneName(String? val) => _zoneName = val;

  bool hasZoneName() => _zoneName != null;

  // "deliveryFees" field.
  double? _deliveryFees;
  double get deliveryFees => _deliveryFees ?? 0.0;
  set deliveryFees(double? val) => _deliveryFees = val;

  void incrementDeliveryFees(double amount) =>
      deliveryFees = deliveryFees + amount;

  bool hasDeliveryFees() => _deliveryFees != null;

  static DeliveryDataStruct fromMap(Map<String, dynamic> data) =>
      DeliveryDataStruct(
        zoneName: data['zoneName'] as String?,
        deliveryFees: castToType<double>(data['deliveryFees']),
      );

  static DeliveryDataStruct? maybeFromMap(dynamic data) => data is Map
      ? DeliveryDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'zoneName': _zoneName,
        'deliveryFees': _deliveryFees,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'zoneName': serializeParam(
          _zoneName,
          ParamType.String,
        ),
        'deliveryFees': serializeParam(
          _deliveryFees,
          ParamType.double,
        ),
      }.withoutNulls;

  static DeliveryDataStruct fromSerializableMap(Map<String, dynamic> data) =>
      DeliveryDataStruct(
        zoneName: deserializeParam(
          data['zoneName'],
          ParamType.String,
          false,
        ),
        deliveryFees: deserializeParam(
          data['deliveryFees'],
          ParamType.double,
          false,
        ),
      );

  @override
  String toString() => 'DeliveryDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is DeliveryDataStruct &&
        zoneName == other.zoneName &&
        deliveryFees == other.deliveryFees;
  }

  @override
  int get hashCode => const ListEquality().hash([zoneName, deliveryFees]);
}

DeliveryDataStruct createDeliveryDataStruct({
  String? zoneName,
  double? deliveryFees,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    DeliveryDataStruct(
      zoneName: zoneName,
      deliveryFees: deliveryFees,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

DeliveryDataStruct? updateDeliveryDataStruct(
  DeliveryDataStruct? deliveryData, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    deliveryData
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addDeliveryDataStructData(
  Map<String, dynamic> firestoreData,
  DeliveryDataStruct? deliveryData,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (deliveryData == null) {
    return;
  }
  if (deliveryData.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && deliveryData.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final deliveryDataData =
      getDeliveryDataFirestoreData(deliveryData, forFieldValue);
  final nestedData =
      deliveryDataData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = deliveryData.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getDeliveryDataFirestoreData(
  DeliveryDataStruct? deliveryData, [
  bool forFieldValue = false,
]) {
  if (deliveryData == null) {
    return {};
  }
  final firestoreData = mapToFirestore(deliveryData.toMap());

  // Add any Firestore field values
  mapToFirestore(deliveryData.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getDeliveryDataListFirestoreData(
  List<DeliveryDataStruct>? deliveryDatas,
) =>
    deliveryDatas?.map((e) => getDeliveryDataFirestoreData(e, true)).toList() ??
    [];
