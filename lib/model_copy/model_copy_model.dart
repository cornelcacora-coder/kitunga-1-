import '/components/view_deliver_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'model_copy_widget.dart' show ModelCopyWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ModelCopyModel extends FlutterFlowModel<ModelCopyWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for viewDeliver component.
  late ViewDeliverModel viewDeliverModel;

  @override
  void initState(BuildContext context) {
    viewDeliverModel = createModel(context, () => ViewDeliverModel());
  }

  @override
  void dispose() {
    viewDeliverModel.dispose();
  }
}
