import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/add_delivery_proof/add_delivery_proof_widget.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'order_model.dart';
export 'order_model.dart';

/// Page d'inscription utilisateur
class OrderWidget extends StatefulWidget {
  const OrderWidget({super.key});

  static String routeName = 'Order';
  static String routePath = '/order';

  @override
  State<OrderWidget> createState() => _OrderWidgetState();
}

class _OrderWidgetState extends State<OrderWidget> {
  late OrderModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OrderModel());

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
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          title: Align(
            alignment: AlignmentDirectional(0.0, -1.0),
            child: Text(
              'Commandes',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.interTight(
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 22.0,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
            ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              Align(
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Builder(
                  builder: (context) {
                    if (valueOrDefault(currentUserDocument?.role, '') ==
                        'User') {
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                        ),
                        child: StreamBuilder<List<OrdersRecord>>(
                          stream: queryOrdersRecord(
                            queryBuilder: (ordersRecord) => ordersRecord.where(
                              'user_ref',
                              isEqualTo: currentUserReference,
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
                            List<OrdersRecord> orderListOrdersRecordList =
                                snapshot.data!;
                            if (orderListOrdersRecordList.isEmpty) {
                              return EmptyCardWidget(
                                photo:
                                    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/vnqklpswxo1p/EmptyCart.png',
                                title: 'Aucune commande pour le moment',
                                description:
                                    'Ajoutez des produits à votre panier et validez votre commande : vous pourrez la suivre ici.',
                                buttonText: 'Découvrir les boutiques',
                                action: () async {
                                  context.pushNamed(HomeWidget.routeName);
                                },
                              );
                            }

                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              scrollDirection: Axis.vertical,
                              itemCount: orderListOrdersRecordList.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 20.0),
                              itemBuilder: (context, orderListIndex) {
                                final orderListOrdersRecord =
                                    orderListOrdersRecordList[orderListIndex];
                                return Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      15.0, 0.0, 15.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                        OrderViewWidget.routeName,
                                        queryParameters: {
                                          'orderRef': serializeParam(
                                            orderListOrdersRecord
                                                .orderUniqueReference,
                                            ParamType.String,
                                          ),
                                          'order': serializeParam(
                                            orderListOrdersRecord.reference,
                                            ParamType.DocumentReference,
                                          ),
                                        }.withoutNulls,
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(10.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        orderListOrdersRecord
                                                            .orderId,
                                                        '#0001',
                                                      ),
                                                      maxLines: 2,
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleMedium
                                                              .override(
                                                                font: GoogleFonts
                                                                    .interTight(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                                fontSize: 17.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                              ),
                                                    ),
                                                  ].divide(
                                                      SizedBox(width: 20.0)),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        dateTimeFormat(
                                                            "d/M/y",
                                                            orderListOrdersRecord
                                                                .createdAt),
                                                        '21/3/2026',
                                                      ),
                                                      maxLines: 2,
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyLarge
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                              ),
                                                    ),
                                                    Container(
                                                      width: 3.0,
                                                      height: 3.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Text(
                                                          valueOrDefault<
                                                              String>(
                                                            orderListOrdersRecord
                                                                .totalAmount
                                                                .toString(),
                                                            '0',
                                                          ),
                                                          maxLines: 2,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyLarge
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                        Text(
                                                          'CFA',
                                                          maxLines: 2,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyLarge
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ].divide(
                                                      SizedBox(width: 4.0)),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Container(
                                                      width: 3.0,
                                                      height: 3.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Text(
                                                      valueOrDefault<String>(
                                                        orderListOrdersRecord
                                                                        .status ==
                                                                    null ||
                                                                orderListOrdersRecord
                                                                        .status ==
                                                                    ''
                                                            ? 'En attente'
                                                            : orderListOrdersRecord
                                                                .status,
                                                        'En attente',
                                                      ),
                                                      maxLines: 2,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyLarge
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                            ),
                                                            color:
                                                                valueOrDefault<
                                                                    Color>(
                                                              () {
                                                                if (orderListOrdersRecord
                                                                        .status ==
                                                                    'En attente') {
                                                                  return FlutterFlowTheme.of(
                                                                          context)
                                                                      .error;
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'Pret') {
                                                                  return FlutterFlowTheme.of(
                                                                          context)
                                                                      .warning;
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'encours') {
                                                                  return Color(
                                                                      0xFF180FE0);
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'Livrer') {
                                                                  return FlutterFlowTheme.of(
                                                                          context)
                                                                      .success;
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'Reçu') {
                                                                  return Color(
                                                                      0xFFB908EC);
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'Non Reçu') {
                                                                  return Color(
                                                                      0xFFF10DC3);
                                                                } else {
                                                                  return FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText;
                                                                }
                                                              }(),
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .secondaryText,
                                                            ),
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                          ),
                                                    ),
                                                  ].divide(
                                                      SizedBox(width: 4.0)),
                                                ),
                                              ].divide(SizedBox(height: 4.0)),
                                            ),
                                            Flexible(
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    1.0, 0.0),
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 0.0, 5.0, 0.0),
                                                  child: FlutterFlowIconButton(
                                                    borderRadius: 24.0,
                                                    buttonSize: 40.0,
                                                    fillColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .accent3,
                                                    icon: Icon(
                                                      Icons
                                                          .manage_search_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      size: 24.0,
                                                    ),
                                                    onPressed: () async {
                                                      context.pushNamed(
                                                        OrderTrackWidget
                                                            .routeName,
                                                        queryParameters: {
                                                          'orderRef':
                                                              serializeParam(
                                                            orderListOrdersRecord
                                                                .reference,
                                                            ParamType
                                                                .DocumentReference,
                                                          ),
                                                        }.withoutNulls,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    } else if (valueOrDefault(currentUserDocument?.role, '') ==
                        'Seller') {
                      return Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                        child: Container(
                          width: () {
                            if (MediaQuery.sizeOf(context).width <
                                kBreakpointSmall) {
                              return 400.0;
                            } else if (MediaQuery.sizeOf(context).width <
                                kBreakpointMedium) {
                              return 400.0;
                            } else if (MediaQuery.sizeOf(context).width <
                                kBreakpointLarge) {
                              return 500.0;
                            } else {
                              return 500.0;
                            }
                          }(),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                          child: StreamBuilder<List<OrdersRecord>>(
                            stream: queryOrdersRecord(
                              queryBuilder: (ordersRecord) =>
                                  ordersRecord.where(
                                'seller_ref',
                                isEqualTo: currentUserReference,
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
                              List<OrdersRecord> orderListOrdersRecordList =
                                  snapshot.data!;
                              if (orderListOrdersRecordList.isEmpty) {
                                return EmptyCardWidget(
                                  photo:
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/vnqklpswxo1p/EmptyCart.png',
                                  title: 'Aucune commande pour le moment',
                                  description:
                                      'Dès qu\'un client passera commande dans votre boutique, elle apparaîtra ici.',
                                  buttonText: 'Voir mes produits',
                                  action: () async {
                                    context.pushNamed(HomeWidget.routeName);
                                  },
                                );
                              }

                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                scrollDirection: Axis.vertical,
                                itemCount: orderListOrdersRecordList.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 20.0),
                                itemBuilder: (context, orderListIndex) {
                                  final orderListOrdersRecord =
                                      orderListOrdersRecordList[orderListIndex];
                                  return Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        15.0, 0.0, 15.0, 0.0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        context.pushNamed(
                                          OrderViewSellerDeliverWidget
                                              .routeName,
                                          queryParameters: {
                                            'orderRefer': serializeParam(
                                              orderListOrdersRecord
                                                  .orderUniqueReference,
                                              ParamType.String,
                                            ),
                                            'deliveryZone': serializeParam(
                                              orderListOrdersRecord
                                                  .deliveryZone,
                                              ParamType.String,
                                            ),
                                            'statu': serializeParam(
                                              orderListOrdersRecord.status,
                                              ParamType.String,
                                            ),
                                            'amount': serializeParam(
                                              orderListOrdersRecord.totalAmount
                                                  .toString(),
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(10.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        valueOrDefault<String>(
                                                          orderListOrdersRecord
                                                              .orderId,
                                                          '#0001',
                                                        ),
                                                        maxLines: 2,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .interTight(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  fontSize:
                                                                      17.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ].divide(
                                                        SizedBox(width: 20.0)),
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Text(
                                                        valueOrDefault<String>(
                                                          dateTimeFormat(
                                                              "d/M/y",
                                                              orderListOrdersRecord
                                                                  .createdAt),
                                                          '21/3/2026',
                                                        ),
                                                        maxLines: 2,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Container(
                                                        width: 3.0,
                                                        height: 3.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .textfiled,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            valueOrDefault<
                                                                String>(
                                                              orderListOrdersRecord
                                                                  .totalAmount
                                                                  .toString(),
                                                              '0',
                                                            ),
                                                            maxLines: 2,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                          Text(
                                                            'CFA',
                                                            maxLines: 2,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ].divide(
                                                        SizedBox(width: 4.0)),
                                                  ),
                                                  if (orderListOrdersRecord
                                                          .status ==
                                                      'En attente')
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Container(
                                                          width: 3.0,
                                                          height: 3.0,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                        Text(
                                                          valueOrDefault<
                                                              String>(
                                                            orderListOrdersRecord
                                                                            .status ==
                                                                        null ||
                                                                    orderListOrdersRecord
                                                                            .status ==
                                                                        ''
                                                                ? 'En attente'
                                                                : orderListOrdersRecord
                                                                    .status,
                                                            'En attente',
                                                          ),
                                                          maxLines: 2,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyLarge
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                                color:
                                                                    valueOrDefault<
                                                                        Color>(
                                                                  () {
                                                                    if (orderListOrdersRecord
                                                                            .status ==
                                                                        'En attente') {
                                                                      return FlutterFlowTheme.of(
                                                                              context)
                                                                          .error;
                                                                    } else if (orderListOrdersRecord
                                                                            .status ==
                                                                        'Pret') {
                                                                      return FlutterFlowTheme.of(
                                                                              context)
                                                                          .warning;
                                                                    } else if (orderListOrdersRecord
                                                                            .status ==
                                                                        'encours') {
                                                                      return Color(
                                                                          0xFF180FE0);
                                                                    } else if (orderListOrdersRecord
                                                                            .status ==
                                                                        'Livrer') {
                                                                      return FlutterFlowTheme.of(
                                                                              context)
                                                                          .success;
                                                                    } else {
                                                                      return Color(
                                                                          0xFF2B2BB0);
                                                                    }
                                                                  }(),
                                                                  Color(
                                                                      0xFF2B2BB0),
                                                                ),
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                      ].divide(
                                                          SizedBox(width: 4.0)),
                                                    ),
                                                ].divide(SizedBox(height: 4.0)),
                                              ),
                                              if (orderListOrdersRecord
                                                      .status ==
                                                  'En attente')
                                                FFButtonWidget(
                                                  onPressed: () async {
                                                    await orderListOrdersRecord
                                                        .reference
                                                        .update(
                                                            createOrdersRecordData(
                                                      status: 'Pret',
                                                    ));
                                                    await showDialog(
                                                      context: context,
                                                      builder:
                                                          (alertDialogContext) {
                                                        return AlertDialog(
                                                          title: Text(
                                                              'Commande Prete !'),
                                                          content: Text(
                                                              'Vous avez terminé la commande avec succès, patientez un livreur va venir chercher  la commande'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      alertDialogContext),
                                                              child: Text('Ok'),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                  text: 'Pret à livrer',
                                                  options: FFButtonOptions(
                                                    height: 30.0,
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(16.0, 0.0,
                                                                16.0, 0.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .accent3,
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primary,
                                                          fontSize: 10.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                ),
                                              if (orderListOrdersRecord
                                                      .status !=
                                                  'En attente')
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Container(
                                                      width: 3.0,
                                                      height: 3.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Text(
                                                      valueOrDefault<String>(
                                                        orderListOrdersRecord
                                                                        .status ==
                                                                    null ||
                                                                orderListOrdersRecord
                                                                        .status ==
                                                                    ''
                                                            ? 'En attente'
                                                            : orderListOrdersRecord
                                                                .status,
                                                        'En attente',
                                                      ),
                                                      maxLines: 2,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyLarge
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                            ),
                                                            color:
                                                                valueOrDefault<
                                                                    Color>(
                                                              () {
                                                                if (orderListOrdersRecord
                                                                        .status ==
                                                                    'En attente') {
                                                                  return FlutterFlowTheme.of(
                                                                          context)
                                                                      .error;
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'Pret') {
                                                                  return FlutterFlowTheme.of(
                                                                          context)
                                                                      .warning;
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'encours') {
                                                                  return Color(
                                                                      0xFF180FE0);
                                                                } else if (orderListOrdersRecord
                                                                        .status ==
                                                                    'Livrer') {
                                                                  return FlutterFlowTheme.of(
                                                                          context)
                                                                      .success;
                                                                } else {
                                                                  return Color(
                                                                      0xFF2B2BB0);
                                                                }
                                                              }(),
                                                              Color(0xFF2B2BB0),
                                                            ),
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                          ),
                                                    ),
                                                  ].divide(
                                                      SizedBox(width: 4.0)),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    } else if (valueOrDefault(currentUserDocument?.role, '') ==
                        'Deliver') {
                      return Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: EdgeInsets.all(valueOrDefault<double>(
                            MediaQuery.sizeOf(context).width > 760.0
                                ? 0.0
                                : 0.0,
                            0.0,
                          )),
                          child: Container(
                            width: MediaQuery.sizeOf(context).width <
                                    kBreakpointSmall
                                ? 400.0
                                : 500.0,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Divider(
                                    thickness: 2.0,
                                    indent: 20.0,
                                    endIndent: 20.0,
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.9,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                    child: StreamBuilder<List<OrdersRecord>>(
                                      stream: queryOrdersRecord(
                                        queryBuilder: (ordersRecord) =>
                                            ordersRecord
                                                .where(
                                                  'deliverer_ref',
                                                  isEqualTo:
                                                      currentUserReference?.id,
                                                )
                                                .orderBy('created_at',
                                                    descending: true),
                                      ),
                                      builder: (context, snapshot) {
                                        // Customize what your widget looks like when it's loading.
                                        if (!snapshot.hasData) {
                                          return Center(
                                            child: SizedBox(
                                              width: 50.0,
                                              height: 50.0,
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        List<OrdersRecord>
                                            listViewOrdersRecordList =
                                            snapshot.data!;
                                        if (listViewOrdersRecordList.isEmpty) {
                                          return EmptyCardWidget(
                                            photo:
                                                'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/vnqklpswxo1p/EmptyCart.png',
                                            title: 'Aucune Commande Accepté',
                                            description:
                                                'Accepter une commande afin de la voir apparaitre ici',
                                            buttonText: 'Voir les commandes',
                                            action: () async {
                                              context.pushNamed(
                                                  HomeWidget.routeName);
                                            },
                                          );
                                        }

                                        return ListView.builder(
                                          padding: EdgeInsets.zero,
                                          primary: false,
                                          scrollDirection: Axis.vertical,
                                          itemCount:
                                              listViewOrdersRecordList.length,
                                          itemBuilder:
                                              (context, listViewIndex) {
                                            final listViewOrdersRecord =
                                                listViewOrdersRecordList[
                                                    listViewIndex];
                                            return Padding(
                                              padding: EdgeInsets.all(20.0),
                                              child: InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () async {
                                                  context.pushNamed(
                                                    OrderViewSellerDeliverWidget
                                                        .routeName,
                                                    queryParameters: {
                                                      'orderRefer':
                                                          serializeParam(
                                                        listViewOrdersRecord
                                                            .orderUniqueReference,
                                                        ParamType.String,
                                                      ),
                                                      'deliveryZone':
                                                          serializeParam(
                                                        listViewOrdersRecord
                                                            .deliveryZone,
                                                        ParamType.String,
                                                      ),
                                                      'statu': serializeParam(
                                                        listViewOrdersRecord
                                                            .status,
                                                        ParamType.String,
                                                      ),
                                                      'amount': serializeParam(
                                                        valueOrDefault<String>(
                                                          listViewOrdersRecord
                                                              .deliveryFees
                                                              .toString(),
                                                          '0',
                                                        ),
                                                        ParamType.String,
                                                      ),
                                                    }.withoutNulls,
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14.0),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.all(10.0),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .start,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        listViewOrdersRecord
                                                                            .orderId,
                                                                        '#-0',
                                                                      ),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .labelMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).labelMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                                                                            ),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).secondaryText,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).labelMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).labelMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                    Icon(
                                                                      Icons
                                                                          .schedule_rounded,
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .warning,
                                                                      size:
                                                                          18.0,
                                                                    ),
                                                                    Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        dateTimeFormat(
                                                                            "d/M H:mm",
                                                                            listViewOrdersRecord.createdAt),
                                                                        '-',
                                                                      ),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                            ),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).secondaryText,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodySmall.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                          ),
                                                                    ),
                                                                  ].divide(SizedBox(
                                                                      width:
                                                                          8.0)),
                                                                ),
                                                                Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  children: [
                                                                    Text(
                                                                      '+',
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.interTight(
                                                                              fontWeight: FontWeight.bold,
                                                                              fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                            ),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).success,
                                                                            fontSize:
                                                                                14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                    Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        listViewOrdersRecord
                                                                            .deliveryFees
                                                                            .toString(),
                                                                        '1000',
                                                                      ),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.interTight(
                                                                              fontWeight: FontWeight.bold,
                                                                              fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                            ),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).success,
                                                                            fontSize:
                                                                                14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                    Text(
                                                                      'F',
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.interTight(
                                                                              fontWeight: FontWeight.bold,
                                                                              fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                            ),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).success,
                                                                            fontSize:
                                                                                14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                            Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .calendar_month,
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .success,
                                                                      size:
                                                                          18.0,
                                                                    ),
                                                                    Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        listViewOrdersRecord
                                                                            .status,
                                                                        'Pret',
                                                                      ),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.interTight(
                                                                              fontWeight: FontWeight.w800,
                                                                              fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                            ),
                                                                            color:
                                                                                valueOrDefault<Color>(
                                                                              () {
                                                                                if (listViewOrdersRecord.status == 'encours') {
                                                                                  return FlutterFlowTheme.of(context).secondary;
                                                                                } else if (listViewOrdersRecord.status == 'Livrer') {
                                                                                  return FlutterFlowTheme.of(context).success;
                                                                                } else if (listViewOrdersRecord.status == 'Reçu') {
                                                                                  return Color(0xFF7908E0);
                                                                                } else if (listViewOrdersRecord.status == 'Non Reçu') {
                                                                                  return FlutterFlowTheme.of(context).secondary;
                                                                                } else {
                                                                                  return FlutterFlowTheme.of(context).primaryText;
                                                                                }
                                                                              }(),
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                            ),
                                                                            fontSize:
                                                                                14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.w800,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                  ].divide(SizedBox(
                                                                      width:
                                                                          8.0)),
                                                                ),
                                                              ].divide(SizedBox(
                                                                  width: 20.0)),
                                                            ),
                                                          ].divide(SizedBox(
                                                              height: 5.0)),
                                                        ),
                                                        Divider(
                                                          thickness: 1.0,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .divider,
                                                        ),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Container(
                                                              width: 30.0,
                                                              height: 30.0,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryBackground,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .location_on,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondary,
                                                                size: 18.0,
                                                              ),
                                                            ),
                                                            Expanded(
                                                              flex: 1,
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .start,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    valueOrDefault<
                                                                        String>(
                                                                      listViewOrdersRecord
                                                                          .deliveryZone,
                                                                      'Zone non précisée',
                                                                    ),
                                                                    maxLines: 1,
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.inter(
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).secondary,
                                                                          fontSize:
                                                                              12.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                  Text(
                                                                    valueOrDefault<
                                                                        String>(
                                                                      listViewOrdersRecord
                                                                          .deliveryLocation,
                                                                      '62 bis Av Corniche',
                                                                    ),
                                                                    maxLines: 1,
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.inter(
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          fontSize:
                                                                              12.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ].divide(SizedBox(
                                                                    height:
                                                                        4.0)),
                                                              ),
                                                            ),
                                                            if (_model
                                                                    .inProgress ==
                                                                true)
                                                              FFButtonWidget(
                                                                onPressed:
                                                                    () async {
                                                                  if (listViewOrdersRecord
                                                                          .status ==
                                                                      'encours') {
                                                                    await listViewOrdersRecord
                                                                        .reference
                                                                        .update(
                                                                            createOrdersRecordData(
                                                                      status:
                                                                          'Livrer',
                                                                      delivererRef:
                                                                          currentUserReference
                                                                              ?.id,
                                                                    ));
                                                                  } else {
                                                                    if (listViewOrdersRecord
                                                                            .status ==
                                                                        'Reçu') {
                                                                      await showModalBottomSheet(
                                                                        isScrollControlled:
                                                                            true,
                                                                        backgroundColor:
                                                                            Colors.transparent,
                                                                        enableDrag:
                                                                            false,
                                                                        context:
                                                                            context,
                                                                        builder:
                                                                            (context) {
                                                                          return GestureDetector(
                                                                            onTap:
                                                                                () {
                                                                              FocusScope.of(context).unfocus();
                                                                              FocusManager.instance.primaryFocus?.unfocus();
                                                                            },
                                                                            child:
                                                                                Padding(
                                                                              padding: MediaQuery.viewInsetsOf(context),
                                                                              child: AddDeliveryProofWidget(
                                                                                orderRef: listViewOrdersRecord.reference,
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                      ).then((value) =>
                                                                          safeSetState(
                                                                              () {}));

                                                                      _model.inProgress =
                                                                          false;
                                                                      safeSetState(
                                                                          () {});
                                                                    } else {
                                                                      await showModalBottomSheet(
                                                                        isScrollControlled:
                                                                            true,
                                                                        backgroundColor:
                                                                            Colors.transparent,
                                                                        enableDrag:
                                                                            false,
                                                                        context:
                                                                            context,
                                                                        builder:
                                                                            (context) {
                                                                          return GestureDetector(
                                                                            onTap:
                                                                                () {
                                                                              FocusScope.of(context).unfocus();
                                                                              FocusManager.instance.primaryFocus?.unfocus();
                                                                            },
                                                                            child:
                                                                                Padding(
                                                                              padding: MediaQuery.viewInsetsOf(context),
                                                                              child: EmptyCardWidget(
                                                                                photo: 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/gv3nx4dk4pps/boxicons-pXmQQk8IxaQ-unsplash.png',
                                                                                title: 'Colis non reçu !',
                                                                                description: 'Veuillez demandé une confirmation de l\'utilisateur afin de confirmer votre livraison ',
                                                                                buttonText: 'Compris !',
                                                                                action: () async {
                                                                                  Navigator.pop(context);
                                                                                },
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                      ).then((value) =>
                                                                          safeSetState(
                                                                              () {}));
                                                                    }
                                                                  }
                                                                },
                                                                text: () {
                                                                  if (listViewOrdersRecord
                                                                          .status ==
                                                                      'encours') {
                                                                    return 'Terminer';
                                                                  } else if (listViewOrdersRecord
                                                                          .status ==
                                                                      'Livrer') {
                                                                    return 'Confirmer';
                                                                  } else if (listViewOrdersRecord
                                                                          .status ==
                                                                      'Non Reçu') {
                                                                    return 'Non Reçu';
                                                                  } else if (listViewOrdersRecord
                                                                          .status ==
                                                                      'Reçu') {
                                                                    return 'Reçu';
                                                                  } else {
                                                                    return 'Expirer';
                                                                  }
                                                                }(),
                                                                options:
                                                                    FFButtonOptions(
                                                                  height: 30.0,
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          16.0,
                                                                          0.0,
                                                                          16.0,
                                                                          0.0),
                                                                  iconPadding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    () {
                                                                      if (listViewOrdersRecord
                                                                              .status ==
                                                                          'encours') {
                                                                        return FlutterFlowTheme.of(context)
                                                                            .secondary;
                                                                      } else if (listViewOrdersRecord
                                                                              .status ==
                                                                          'Livrer') {
                                                                        return FlutterFlowTheme.of(context)
                                                                            .success;
                                                                      } else if (listViewOrdersRecord
                                                                              .status ==
                                                                          'Reçu') {
                                                                        return Color(
                                                                            0xFF7908E0);
                                                                      } else if (listViewOrdersRecord
                                                                              .status ==
                                                                          'Non Reçu') {
                                                                        return FlutterFlowTheme.of(context)
                                                                            .secondary;
                                                                      } else {
                                                                        return FlutterFlowTheme.of(context)
                                                                            .primaryText;
                                                                      }
                                                                    }(),
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  textStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .interTight(
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .fontStyle,
                                                                        ),
                                                                        color: Colors
                                                                            .white,
                                                                        fontSize:
                                                                            10.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontStyle,
                                                                      ),
                                                                  elevation:
                                                                      0.0,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              24.0),
                                                                ),
                                                              ),
                                                          ].divide(SizedBox(
                                                              width: 16.0)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    } else if (valueOrDefault(currentUserDocument?.role, '') ==
                        'Admin') {
                      return StreamBuilder<List<OrdersRecord>>(
                        stream: queryOrdersRecord(
                          queryBuilder: (ordersRecord) => ordersRecord.where(
                            'user_ref',
                            isEqualTo: currentUserReference,
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
                          List<OrdersRecord> adminOrderOrdersRecordList =
                              snapshot.data!;
                          if (adminOrderOrdersRecordList.isEmpty) {
                            return EmptyCardWidget(
                              photo:
                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/vnqklpswxo1p/EmptyCart.png',
                              title: 'Aucune commande pour le moment',
                              description:
                                  'Ajoutez des produits à votre panier et validez votre commande : vous pourrez la suivre ici.',
                              buttonText: 'Découvrir les boutiques',
                              action: () async {
                                context.pushNamed(HomeWidget.routeName);
                              },
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            scrollDirection: Axis.vertical,
                            itemCount: adminOrderOrdersRecordList.length,
                            separatorBuilder: (_, __) => SizedBox(height: 20.0),
                            itemBuilder: (context, adminOrderIndex) {
                              final adminOrderOrdersRecord =
                                  adminOrderOrdersRecordList[adminOrderIndex];
                              return Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    15.0, 0.0, 15.0, 0.0),
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    context.pushNamed(
                                      OrderTrackWidget.routeName,
                                      queryParameters: {
                                        'orderRef': serializeParam(
                                          adminOrderOrdersRecord.reference,
                                          ParamType.DocumentReference,
                                        ),
                                      }.withoutNulls,
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Column(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    valueOrDefault<String>(
                                                      adminOrderOrdersRecord
                                                          .orderId,
                                                      '#0001',
                                                    ),
                                                    maxLines: 2,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .titleMedium
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 17.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ].divide(SizedBox(width: 20.0)),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Text(
                                                    valueOrDefault<String>(
                                                      dateTimeFormat(
                                                          "d/M/y",
                                                          adminOrderOrdersRecord
                                                              .createdAt),
                                                      '21/3/2026',
                                                    ),
                                                    maxLines: 2,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyLarge
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                  Container(
                                                    width: 3.0,
                                                    height: 3.0,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .textfiled,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Text(
                                                        valueOrDefault<String>(
                                                          adminOrderOrdersRecord
                                                              .totalAmount
                                                              .toString(),
                                                          '0',
                                                        ),
                                                        maxLines: 2,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Text(
                                                        'CFA',
                                                        maxLines: 2,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyLarge
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                ].divide(SizedBox(width: 4.0)),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Container(
                                                    width: 3.0,
                                                    height: 3.0,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  Text(
                                                    valueOrDefault<String>(
                                                      adminOrderOrdersRecord
                                                                      .status ==
                                                                  null ||
                                                              adminOrderOrdersRecord
                                                                      .status ==
                                                                  ''
                                                          ? 'En attente'
                                                          : adminOrderOrdersRecord
                                                              .status,
                                                      'En attente',
                                                    ),
                                                    maxLines: 2,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyLarge
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLarge
                                                                    .fontStyle,
                                                          ),
                                                          color: valueOrDefault<
                                                              Color>(
                                                            () {
                                                              if (adminOrderOrdersRecord
                                                                      .status ==
                                                                  'En attente') {
                                                                return FlutterFlowTheme.of(
                                                                        context)
                                                                    .error;
                                                              } else if (adminOrderOrdersRecord
                                                                      .status ==
                                                                  'Pret') {
                                                                return FlutterFlowTheme.of(
                                                                        context)
                                                                    .warning;
                                                              } else if (adminOrderOrdersRecord
                                                                      .status ==
                                                                  'encours') {
                                                                return Color(
                                                                    0xFF180FE0);
                                                              } else if (adminOrderOrdersRecord
                                                                      .status ==
                                                                  'Livrer') {
                                                                return FlutterFlowTheme.of(
                                                                        context)
                                                                    .success;
                                                              } else {
                                                                return FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText;
                                                              }
                                                            }(),
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ].divide(SizedBox(width: 4.0)),
                                              ),
                                            ].divide(SizedBox(height: 4.0)),
                                          ),
                                          Align(
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            child: FlutterFlowIconButton(
                                              borderRadius: 24.0,
                                              buttonSize: 40.0,
                                              fillColor:
                                                  FlutterFlowTheme.of(context)
                                                      .accent2,
                                              icon: Icon(
                                                Icons.bar_chart_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              onPressed: () async {
                                                context.pushNamed(
                                                  OrderTrackWidget.routeName,
                                                  queryParameters: {
                                                    'orderRef': serializeParam(
                                                      adminOrderOrdersRecord
                                                          .reference,
                                                      ParamType
                                                          .DocumentReference,
                                                    ),
                                                  }.withoutNulls,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    } else {
                      return Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            wrapWithModel(
                              model: _model.emptyCardModel,
                              updateCallback: () => safeSetState(() {}),
                              child: EmptyCardWidget(
                                photo:
                                    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/v1j5zelwpg12/Gemini_Generated_Image_ou1qzrou1qzrou1q-removebg-preview.png',
                                title: 'Créez votre compte',
                                description:
                                    'Créez votre compte Kitunga pour accéder à l\'historique de vos commandes.',
                                buttonText: 'Créer un compte',
                                action: () async {
                                  context.pushNamed(
                                    SignWidget.routeName,
                                    queryParameters: {
                                      'accessibility': serializeParam(
                                        'User',
                                        ParamType.String,
                                      ),
                                    }.withoutNulls,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
