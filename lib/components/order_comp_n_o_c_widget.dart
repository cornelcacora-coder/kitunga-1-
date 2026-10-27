import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'order_comp_n_o_c_model.dart';
export 'order_comp_n_o_c_model.dart';

/// Displaying order view for each order inside the listviews (including non
/// delivering orders only)
class OrderCompNOCWidget extends StatefulWidget {
  const OrderCompNOCWidget({
    super.key,
    this.profile,
    this.createdAt,
    this.zone,
    this.orderId,
    this.status,
    Color? statusBg,
    this.iconSatut,
    this.statuTextBg,
    this.name,
    this.isReady,
    this.isDelivery,
    this.inProgress,
    this.isNotDelivery,
    this.isWaiting,
    this.isCompleted,
    this.viewDeliver,
    this.viewOrder,
  }) : this.statusBg = statusBg ?? const Color(0x6824E0DB);

  final String? profile;
  final DateTime? createdAt;
  final String? zone;
  final String? orderId;
  final String? status;
  final Color statusBg;
  final Widget? iconSatut;
  final Color? statuTextBg;
  final String? name;
  final Widget? isReady;
  final Widget? isDelivery;
  final Widget? inProgress;
  final Widget? isNotDelivery;
  final Widget? isWaiting;
  final Widget? isCompleted;
  final Future Function()? viewDeliver;
  final Future Function()? viewOrder;

  @override
  State<OrderCompNOCWidget> createState() => _OrderCompNOCWidgetState();
}

class _OrderCompNOCWidgetState extends State<OrderCompNOCWidget> {
  late OrderCompNOCModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OrderCompNOCModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await widget.viewOrder?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
              child: Container(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: AlignmentDirectional(1.0, 0.0),
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 0.0, 0.0),
                        child: Container(
                          width: 35.0,
                          height: 35.0,
                          decoration: BoxDecoration(
                            color: valueOrDefault<Color>(
                              widget!.statusBg,
                              FlutterFlowTheme.of(context).accent2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: () {
                              if (widget!.status == 'En attente') {
                                return widget!.isWaiting!;
                              } else if (widget!.status == 'Pret') {
                                return widget!.isReady!;
                              } else if (widget!.status == 'encours') {
                                return widget!.inProgress!;
                              } else if (widget!.status == 'Livrer') {
                                return widget!.isCompleted!;
                              } else if (widget!.status == 'Reçu') {
                                return widget!.isDelivery!;
                              } else if (widget!.status == 'Non Reçu') {
                                return widget!.isNotDelivery!;
                              } else {
                                return widget!.iconSatut!;
                              }
                            }(),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional(0.0, 0.0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await widget.viewDeliver?.call();
                        },
                        child: Icon(
                          Icons.delivery_dining_rounded,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 26.0,
                        ),
                      ),
                    ),
                    Text(
                      valueOrDefault<String>(
                        widget!.zone,
                        'Zone non précisée',
                      ),
                      textAlign: TextAlign.start,
                      maxLines: 2,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                            lineHeight: 1.5,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      valueOrDefault<String>(
                        dateTimeFormat("d/M/y", widget!.createdAt),
                        '-',
                      ),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                            lineHeight: 1.5,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      valueOrDefault<String>(
                        widget!.orderId,
                        'OrderId-#0001',
                      ),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                            lineHeight: 1.5,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      width: 130.0,
                      height: 32.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: valueOrDefault<Color>(
                            widget!.statusBg,
                            FlutterFlowTheme.of(context).accent2,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                          shape: BoxShape.rectangle,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 8.0, 16.0, 8.0),
                          child: Container(
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: 1,
                                  child: Text(
                                    valueOrDefault<String>(
                                      widget!.status,
                                      'Non Reçu',
                                    ),
                                    maxLines: 1,
                                    style: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                          ),
                                          color: valueOrDefault<Color>(
                                            widget!.statuTextBg,
                                            Color(0xFF2A47A2),
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontStyle,
                                          lineHeight: 1.2,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: valueOrDefault<Color>(
                                    widget!.statuTextBg,
                                    Color(0xFF2A47A2),
                                  ),
                                  size: 20.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ].divide(SizedBox(width: 16.0)),
                ),
              ),
            ),
            Container(
              height: 1.0,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).alternate,
                shape: BoxShape.rectangle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
