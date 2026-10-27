import '/components/view_deliver_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'model_copy_model.dart';
export 'model_copy_model.dart';

/// Page d'inscription utilisateur
class ModelCopyWidget extends StatefulWidget {
  const ModelCopyWidget({super.key});

  static String routeName = 'ModelCopy';
  static String routePath = '/modelCopy';

  @override
  State<ModelCopyWidget> createState() => _ModelCopyWidgetState();
}

class _ModelCopyWidgetState extends State<ModelCopyWidget> {
  late ModelCopyModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ModelCopyModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SafeArea(
          top: true,
          child: Align(
            alignment: AlignmentDirectional(0.0, 0.0),
            child: wrapWithModel(
              model: _model.viewDeliverModel,
              updateCallback: () => safeSetState(() {}),
              child: ViewDeliverWidget(),
            ),
          ),
        ),
      ),
    );
  }
}
