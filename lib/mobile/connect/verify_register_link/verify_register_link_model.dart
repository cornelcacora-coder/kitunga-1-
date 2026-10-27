import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'verify_register_link_widget.dart' show VerifyRegisterLinkWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class VerifyRegisterLinkModel
    extends FlutterFlowModel<VerifyRegisterLinkWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for EmptyCard component.
  late EmptyCardModel emptyCardModel;

  @override
  void initState(BuildContext context) {
    emptyCardModel = createModel(context, () => EmptyCardModel());
  }

  @override
  void dispose() {
    emptyCardModel.dispose();
  }
}
