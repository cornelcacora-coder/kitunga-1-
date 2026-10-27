import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'add_phone_number_widget.dart' show AddPhoneNumberWidget;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddPhoneNumberModel extends FlutterFlowModel<AddPhoneNumberWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for MTN widget.
  FocusNode? mtnFocusNode;
  TextEditingController? mtnTextController;
  String? Function(BuildContext, String?)? mtnTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    mtnFocusNode?.dispose();
    mtnTextController?.dispose();
  }
}
