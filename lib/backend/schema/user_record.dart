import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// The user main data base for displaying data like name, birth and more...
class UserRecord extends FirestoreRecord {
  UserRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "uid" field.
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "bio" field.
  String? _bio;
  String get bio => _bio ?? '';
  bool hasBio() => _bio != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  bool hasRole() => _role != null;

  // "verified" field.
  bool? _verified;
  bool get verified => _verified ?? false;
  bool hasVerified() => _verified != null;

  // "category" field.
  String? _category;
  String get category => _category ?? '';
  bool hasCategory() => _category != null;

  // "Business_cover" field.
  String? _businessCover;
  String get businessCover => _businessCover ?? '';
  bool hasBusinessCover() => _businessCover != null;

  // "Horraire" field.
  String? _horraire;
  String get horraire => _horraire ?? '';
  bool hasHorraire() => _horraire != null;

  // "is_subscribed" field.
  bool? _isSubscribed;
  bool get isSubscribed => _isSubscribed ?? false;
  bool hasIsSubscribed() => _isSubscribed != null;

  // "subscribe_type" field.
  String? _subscribeType;
  String get subscribeType => _subscribeType ?? '';
  bool hasSubscribeType() => _subscribeType != null;

  // "subscribe_close_at" field.
  DateTime? _subscribeCloseAt;
  DateTime? get subscribeCloseAt => _subscribeCloseAt;
  bool hasSubscribeCloseAt() => _subscribeCloseAt != null;

  // "isLoggedIn" field.
  bool? _isLoggedIn;
  bool get isLoggedIn => _isLoggedIn ?? false;
  bool hasIsLoggedIn() => _isLoggedIn != null;

  // "password" field.
  String? _password;
  String get password => _password ?? '';
  bool hasPassword() => _password != null;

  // "twoFA" field.
  bool? _twoFA;
  bool get twoFA => _twoFA ?? false;
  bool hasTwoFA() => _twoFA != null;

  void _initializeFields() {
    _email = snapshotData['email'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _photoUrl = snapshotData['photo_url'] as String?;
    _uid = snapshotData['uid'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _bio = snapshotData['bio'] as String?;
    _role = snapshotData['role'] as String?;
    _verified = snapshotData['verified'] as bool?;
    _category = snapshotData['category'] as String?;
    _businessCover = snapshotData['Business_cover'] as String?;
    _horraire = snapshotData['Horraire'] as String?;
    _isSubscribed = snapshotData['is_subscribed'] as bool?;
    _subscribeType = snapshotData['subscribe_type'] as String?;
    _subscribeCloseAt = snapshotData['subscribe_close_at'] as DateTime?;
    _isLoggedIn = snapshotData['isLoggedIn'] as bool?;
    _password = snapshotData['password'] as String?;
    _twoFA = snapshotData['twoFA'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('User');

  static Stream<UserRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UserRecord.fromSnapshot(s));

  static Future<UserRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UserRecord.fromSnapshot(s));

  static UserRecord fromSnapshot(DocumentSnapshot snapshot) => UserRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UserRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UserRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UserRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UserRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUserRecordData({
  String? email,
  String? displayName,
  String? photoUrl,
  String? uid,
  DateTime? createdTime,
  String? phoneNumber,
  String? bio,
  String? role,
  bool? verified,
  String? category,
  String? businessCover,
  String? horraire,
  bool? isSubscribed,
  String? subscribeType,
  DateTime? subscribeCloseAt,
  bool? isLoggedIn,
  String? password,
  bool? twoFA,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'uid': uid,
      'created_time': createdTime,
      'phone_number': phoneNumber,
      'bio': bio,
      'role': role,
      'verified': verified,
      'category': category,
      'Business_cover': businessCover,
      'Horraire': horraire,
      'is_subscribed': isSubscribed,
      'subscribe_type': subscribeType,
      'subscribe_close_at': subscribeCloseAt,
      'isLoggedIn': isLoggedIn,
      'password': password,
      'twoFA': twoFA,
    }.withoutNulls,
  );

  return firestoreData;
}

class UserRecordDocumentEquality implements Equality<UserRecord> {
  const UserRecordDocumentEquality();

  @override
  bool equals(UserRecord? e1, UserRecord? e2) {
    return e1?.email == e2?.email &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.uid == e2?.uid &&
        e1?.createdTime == e2?.createdTime &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.bio == e2?.bio &&
        e1?.role == e2?.role &&
        e1?.verified == e2?.verified &&
        e1?.category == e2?.category &&
        e1?.businessCover == e2?.businessCover &&
        e1?.horraire == e2?.horraire &&
        e1?.isSubscribed == e2?.isSubscribed &&
        e1?.subscribeType == e2?.subscribeType &&
        e1?.subscribeCloseAt == e2?.subscribeCloseAt &&
        e1?.isLoggedIn == e2?.isLoggedIn &&
        e1?.password == e2?.password &&
        e1?.twoFA == e2?.twoFA;
  }

  @override
  int hash(UserRecord? e) => const ListEquality().hash([
        e?.email,
        e?.displayName,
        e?.photoUrl,
        e?.uid,
        e?.createdTime,
        e?.phoneNumber,
        e?.bio,
        e?.role,
        e?.verified,
        e?.category,
        e?.businessCover,
        e?.horraire,
        e?.isSubscribed,
        e?.subscribeType,
        e?.subscribeCloseAt,
        e?.isLoggedIn,
        e?.password,
        e?.twoFA
      ]);

  @override
  bool isValidKey(Object? o) => o is UserRecord;
}
