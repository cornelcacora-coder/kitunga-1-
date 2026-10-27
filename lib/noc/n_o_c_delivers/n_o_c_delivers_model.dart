import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/noc/user_row_n_o_c/user_row_n_o_c_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'n_o_c_delivers_widget.dart' show NOCDeliversWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NOCDeliversModel extends FlutterFlowModel<NOCDeliversWidget> {
  ///  Local state fields for this component.

  bool userConnected = false;

  ///  State fields for stateful widgets in this component.

  // Models for UserRowNOC dynamic component.
  late FlutterFlowDynamicModels<UserRowNOCModel> userRowNOCModels;

  @override
  void initState(BuildContext context) {
    userRowNOCModels = FlutterFlowDynamicModels(() => UserRowNOCModel());
  }

  @override
  void dispose() {
    userRowNOCModels.dispose();
  }
}
