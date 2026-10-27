import '/backend/backend.dart';
import '/components/alert_card_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'n_o_c_alert_widget.dart' show NOCAlertWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NOCAlertModel extends FlutterFlowModel<NOCAlertWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for AlertCard.
  late AlertCardModel alertCardModel1;
  // Model for AlertCard.
  late AlertCardModel alertCardModel2;
  // Model for AlertCard.
  late AlertCardModel alertCardModel3;

  @override
  void initState(BuildContext context) {
    alertCardModel1 = createModel(context, () => AlertCardModel());
    alertCardModel2 = createModel(context, () => AlertCardModel());
    alertCardModel3 = createModel(context, () => AlertCardModel());
  }

  @override
  void dispose() {
    alertCardModel1.dispose();
    alertCardModel2.dispose();
    alertCardModel3.dispose();
  }
}
