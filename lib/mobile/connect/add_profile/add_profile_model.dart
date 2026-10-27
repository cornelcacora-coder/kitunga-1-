import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:ui';
import '/index.dart';
import 'add_profile_widget.dart' show AddProfileWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddProfileModel extends FlutterFlowModel<AddProfileWidget> {
  ///  State fields for stateful widgets in this page.

  bool isDataUploading_userProfile = false;
  FFUploadedFile uploadedLocalFile_userProfile =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_userProfile = '';

  bool isDataUploading_businessCover = false;
  FFUploadedFile uploadedLocalFile_businessCover =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_businessCover = '';

  bool isDataUploading_businessProfile = false;
  FFUploadedFile uploadedLocalFile_businessProfile =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_businessProfile = '';

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
