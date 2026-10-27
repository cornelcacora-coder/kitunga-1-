import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/noc/n_o_c_delivers/n_o_c_delivers_widget.dart';
import 'template_widget.dart' show TemplateWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TemplateModel extends FlutterFlowModel<TemplateWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for NOC_Delivers component.
  late NOCDeliversModel nOCDeliversModel;

  @override
  void initState(BuildContext context) {
    nOCDeliversModel = createModel(context, () => NOCDeliversModel());
  }

  @override
  void dispose() {
    nOCDeliversModel.dispose();
  }
}
