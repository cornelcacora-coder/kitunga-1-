import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'status_pill_model.dart';
export 'status_pill_model.dart';

class StatusPillWidget extends StatefulWidget {
  const StatusPillWidget({
    super.key,
    this.bg,
    this.icon,
    this.color,
    this.label,
  });

  final Color? bg;
  final String? icon;
  final Color? color;
  final String? label;

  @override
  State<StatusPillWidget> createState() => _StatusPillWidgetState();
}

class _StatusPillWidgetState extends State<StatusPillWidget> {
  late StatusPillModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StatusPillModel());

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
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_rounded,
              color: valueOrDefault<Color>(
                widget!.color,
                Color(0x00000000),
              ),
              size: 14.0,
            ),
            Text(
              valueOrDefault<String>(
                widget!.label,
                'ON THE WAY',
              ),
              style: FlutterFlowTheme.of(context).labelSmall.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelSmall.fontStyle,
                    ),
                    color: valueOrDefault<Color>(
                      widget!.color,
                      Color(0x00000000),
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.bold,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelSmall.fontStyle,
                  ),
            ),
          ].divide(SizedBox(width: 4.0)),
        ),
      ),
    );
  }
}
