import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'template_copy_model.dart';
export 'template_copy_model.dart';

/// Page d'inscription utilisateur
class TemplateCopyWidget extends StatefulWidget {
  const TemplateCopyWidget({super.key});

  static String routeName = 'TemplateCopy';
  static String routePath = '/templateCopy';

  @override
  State<TemplateCopyWidget> createState() => _TemplateCopyWidgetState();
}

class _TemplateCopyWidgetState extends State<TemplateCopyWidget> {
  late TemplateCopyModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TemplateCopyModel());

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
      ),
    );
  }
}
