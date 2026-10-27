import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/ads_comp/ads_comp_widget.dart';
import '/mobile/components/alert_info/alert_info_widget.dart';
import '/mobile/components/user_card/user_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'shops_widget.dart' show ShopsWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ShopsModel extends FlutterFlowModel<ShopsWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for AdsComp component.
  late AdsCompModel adsCompModel;
  // Models for UserCard dynamic component.
  late FlutterFlowDynamicModels<UserCardModel> userCardModels;

  @override
  void initState(BuildContext context) {
    adsCompModel = createModel(context, () => AdsCompModel());
    userCardModels = FlutterFlowDynamicModels(() => UserCardModel());
  }

  @override
  void dispose() {
    adsCompModel.dispose();
    userCardModels.dispose();
  }
}
