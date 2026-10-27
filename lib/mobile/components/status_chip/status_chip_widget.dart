import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'status_chip_model.dart';
export 'status_chip_model.dart';

class StatusChipWidget extends StatefulWidget {
  const StatusChipWidget({
    super.key,
    this.bg,
    this.label,
    this.color,
  });

  final Color? bg;
  final String? label;
  final Color? color;

  @override
  State<StatusChipWidget> createState() => _StatusChipWidgetState();
}

class _StatusChipWidgetState extends State<StatusChipWidget> {
  late StatusChipModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StatusChipModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          widget!.bg,
          Color(0x00000000),
        ),
        borderRadius: BorderRadius.circular(9999.0),
      ),
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
        child: Text(
          valueOrDefault<String>(
            widget!.label,
            'HOT',
          ),
          style: FlutterFlowTheme.of(context).labelSmall.override(
                font: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                ),
                color: valueOrDefault<Color>(
                  widget!.color,
                  Color(0x00000000),
                ),
                letterSpacing: 0.0,
                fontWeight: FontWeight.bold,
                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
              ),
        ),
      ),
    );
  }
}
