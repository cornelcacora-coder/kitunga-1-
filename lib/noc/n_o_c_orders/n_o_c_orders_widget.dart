import '/backend/backend.dart';
import '/components/order_comp_n_o_c_widget.dart';
import '/components/view_deliver_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/noc/n_o_c_order_item_view/n_o_c_order_item_view_widget.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'n_o_c_orders_model.dart';
export 'n_o_c_orders_model.dart';

class NOCOrdersWidget extends StatefulWidget {
  const NOCOrdersWidget({super.key});

  @override
  State<NOCOrdersWidget> createState() => _NOCOrdersWidgetState();
}

class _NOCOrdersWidgetState extends State<NOCOrdersWidget> {
  late NOCOrdersModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NOCOrdersModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Material(
        color: Colors.transparent,
        elevation: 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.7,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            boxShadow: [
              BoxShadow(
                blurRadius: 4.0,
                color: Color(0x33000000),
                offset: Offset(
                  0.0,
                  2.0,
                ),
              )
            ],
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: FlutterFlowTheme.of(context).accent1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Container(
              decoration: BoxDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'COMMANDES EN COURS',
                        style: FlutterFlowTheme.of(context)
                            .titleMedium
                            .override(
                              font: GoogleFonts.interTight(
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.bold,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .fontStyle,
                              lineHeight: 1.4,
                            ),
                      ),
                      InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.close_sharp,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 24.0,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Livreur',
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.2,
                              ),
                        ),
                        Text(
                          'Livreur',
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.2,
                              ),
                        ),
                        Text(
                          'Zone',
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.2,
                              ),
                        ),
                        Text(
                          'Date de livraison',
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.2,
                              ),
                        ),
                        Text(
                          'Id de commande',
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.2,
                              ),
                        ),
                        Text(
                          'Statu de la livraison',
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 10.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.2,
                              ),
                        ),
                      ].divide(SizedBox(width: 16.0)),
                    ),
                  ),
                  Container(
                    width: 100.0,
                    height: MediaQuery.sizeOf(context).height * 0.52,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                    child: StreamBuilder<List<OrdersRecord>>(
                      stream: queryOrdersRecord(
                        queryBuilder: (ordersRecord) => ordersRecord.where(
                          'status',
                          isNotEqualTo: 'Reçu',
                        ),
                      ),
                      builder: (context, snapshot) {
                        // Customize what your widget looks like when it's loading.
                        if (!snapshot.hasData) {
                          return Center(
                            child: SizedBox(
                              width: 50.0,
                              height: 50.0,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  FlutterFlowTheme.of(context).primary,
                                ),
                              ),
                            ),
                          );
                        }
                        List<OrdersRecord> listedOrderOrdersRecordList =
                            snapshot.data!;

                        return Wrap(
                          spacing: 0.0,
                          runSpacing: 0.0,
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          direction: Axis.horizontal,
                          runAlignment: WrapAlignment.start,
                          verticalDirection: VerticalDirection.down,
                          clipBehavior: Clip.none,
                          children:
                              List.generate(listedOrderOrdersRecordList.length,
                                  (listedOrderIndex) {
                            final listedOrderOrdersRecord =
                                listedOrderOrdersRecordList[listedOrderIndex];
                            return wrapWithModel(
                              model: _model.orderCompNOCModels.getModel(
                                listedOrderOrdersRecord.reference.id,
                                listedOrderIndex,
                              ),
                              updateCallback: () => safeSetState(() {}),
                              child: OrderCompNOCWidget(
                                key: Key(
                                  'Keyawc_${listedOrderOrdersRecord.reference.id}',
                                ),
                                profile: listedOrderOrdersRecord.deliveryPhoto,
                                zone: valueOrDefault<String>(
                                  listedOrderOrdersRecord.deliveryZone,
                                  'Zone non précisée',
                                ),
                                orderId: listedOrderOrdersRecord.orderId,
                                status: valueOrDefault<String>(
                                  listedOrderOrdersRecord.status,
                                  'En attente',
                                ),
                                statusBg: valueOrDefault<Color>(
                                  () {
                                    if (listedOrderOrdersRecord.status ==
                                        'En attente') {
                                      return FlutterFlowTheme.of(context)
                                          .accent3;
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Pret') {
                                      return Color(0x4DEEED60);
                                    } else if (listedOrderOrdersRecord.status ==
                                        'encours') {
                                      return Color(0x4D3943D2);
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Livrer') {
                                      return FlutterFlowTheme.of(context)
                                          .accent2;
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Reçu') {
                                      return Color(0x4DAC39D2);
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Non Reçu') {
                                      return Color(0x4DCB39D2);
                                    } else {
                                      return FlutterFlowTheme.of(context)
                                          .accent2;
                                    }
                                  }(),
                                  FlutterFlowTheme.of(context).accent2,
                                ),
                                statuTextBg: valueOrDefault<Color>(
                                  () {
                                    if (listedOrderOrdersRecord.status ==
                                        'En attente') {
                                      return FlutterFlowTheme.of(context)
                                          .primary;
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Pret') {
                                      return FlutterFlowTheme.of(context)
                                          .warning;
                                    } else if (listedOrderOrdersRecord.status ==
                                        'encours') {
                                      return Color(0xFF180FE0);
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Livrer') {
                                      return FlutterFlowTheme.of(context)
                                          .tertiary;
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Reçu') {
                                      return Color(0xFFB908EC);
                                    } else if (listedOrderOrdersRecord.status ==
                                        'Non Reçu') {
                                      return Color(0xFFF10DC3);
                                    } else {
                                      return FlutterFlowTheme.of(context)
                                          .secondaryText;
                                    }
                                  }(),
                                  FlutterFlowTheme.of(context).success,
                                ),
                                createdAt: listedOrderOrdersRecord.createdAt,
                                isReady: Icon(
                                  Icons.add_alert_rounded,
                                  color: FlutterFlowTheme.of(context).warning,
                                ),
                                isDelivery: Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFFB908EC),
                                ),
                                inProgress: Icon(
                                  Icons.delivery_dining_rounded,
                                  color: Color(0xFF180FE0),
                                ),
                                isNotDelivery: Icon(
                                  Icons.crisis_alert,
                                  color: Color(0xFFF10DC3),
                                ),
                                isWaiting: Icon(
                                  Icons.timer_rounded,
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                                isCompleted: Icon(
                                  Icons.thumb_up_alt,
                                  color: FlutterFlowTheme.of(context).tertiary,
                                ),
                                viewDeliver: () async {
                                  if (listedOrderOrdersRecord.delivererRef !=
                                          null &&
                                      listedOrderOrdersRecord.delivererRef !=
                                          '') {
                                    await showModalBottomSheet(
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      enableDrag: false,
                                      context: context,
                                      builder: (context) {
                                        return Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: ViewDeliverWidget(
                                            deliverRef: listedOrderOrdersRecord
                                                .deliverReference,
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  } else {
                                    await showDialog(
                                      context: context,
                                      builder: (alertDialogContext) {
                                        return AlertDialog(
                                          title: Text(
                                              'Aucun Livreur Pour l\'instant !'),
                                          content: Text(
                                              'Le colis n\'a pas encore été pris en charge par un livreur ... En attente d\'un livreur.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  alertDialogContext),
                                              child: Text('Ok'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                },
                                viewOrder: () async {
                                  await showModalBottomSheet(
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    enableDrag: false,
                                    context: context,
                                    builder: (context) {
                                      return Padding(
                                        padding:
                                            MediaQuery.viewInsetsOf(context),
                                        child: NOCOrderItemViewWidget(
                                          zone: listedOrderOrdersRecord
                                              .deliveryZone,
                                          rue: listedOrderOrdersRecord
                                              .deliveryLocation,
                                          orderReferece: listedOrderOrdersRecord
                                              .orderUniqueReference,
                                        ),
                                      );
                                    },
                                  ).then((value) => safeSetState(() {}));
                                },
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ].divide(SizedBox(height: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
