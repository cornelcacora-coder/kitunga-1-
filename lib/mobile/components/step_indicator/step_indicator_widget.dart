import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'step_indicator_model.dart';
export 'step_indicator_model.dart';

class StepIndicatorWidget extends StatefulWidget {
  const StepIndicatorWidget({
    super.key,
    this.bg,
    this.border,
    this.num,
    this.text_color,
    this.label,
    this.label_color,
  });

  final Color? bg;
  final String? border;
  final double? num;
  final Color? text_color;
  final String? label;
  final Color? label_color;

  @override
  State<StepIndicatorWidget> createState() => _StepIndicatorWidgetState();
}

class _StepIndicatorWidgetState extends State<StepIndicatorWidget> {
  late StepIndicatorModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StepIndicatorModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32.0,
          height: 32.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary,
            borderRadius: BorderRadius.circular(9999.0),
            border: Border.all(
              width: 2.0,
            ),
          ),
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Text(
            valueOrDefault<String>(
              widget!.num?.toString(),
              '1',
            ),
            style: TextStyle(
              color: valueOrDefault<Color>(
                widget!.text_color,
                Color(0x00000000),
              ),
              fontWeight: FontWeight.w800,
              fontSize: 14.0,
            ),
          ),
        ),
        Text(
          valueOrDefault<String>(
            widget!.label,
            'Panier',
          ),
          style: TextStyle(
            color: valueOrDefault<Color>(
              widget!.label_color,
              Color(0x00000000),
            ),
            fontWeight: FontWeight.w600,
            fontSize: 14.0,
          ),
        ),
      ].divide(SizedBox(width: 8.0)),
    );
  }
}
