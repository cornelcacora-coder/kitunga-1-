import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/api_requests/api_calls.dart';
import '/components/payment_method_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'cart_last_model.dart';
export 'cart_last_model.dart';

/// Page d'inscription utilisateur
class CartLastWidget extends StatefulWidget {
  const CartLastWidget({
    super.key,
    this.deliveryAddress,
    this.sellerRef,
    this.cartRef,
    this.airtelNumber,
    this.mtnNumber,
    this.orderitem,
  });

  final String? deliveryAddress;
  final DocumentReference? sellerRef;
  final CartRecord? cartRef;
  final String? airtelNumber;
  final String? mtnNumber;
  final DocumentReference? orderitem;

  static String routeName = 'CartLast';
  static String routePath = '/cartLast';

  @override
  State<CartLastWidget> createState() => _CartLastWidgetState();
}

class _CartLastWidgetState extends State<CartLastWidget> {
  late CartLastModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  double getDeliveryFeeForZone(String? zone) {
    if (zone == null || zone.isEmpty) return 1000.0;
    if ([
      'Makélékélé', 'Centre sportif', 'Kinsoundi', 'Diata', 'Kingouari',
      'Moukoundzi-Ngouaka', 'Château d\'eau', 'Barrage', 'Bacongo',
      'Mpissa', 'Poto-Poto', 'Centre-ville', 'Moungali', 'O.C.H',
      'Plateau des 15 ans', 'Batignolles', 'Moukondo', 'Avenue de la Paix',
      'Marché Moungali', 'Académie'
    ].contains(zone)) {
      return 1000.0;
    } else if ([
      'Ouenzé', 'Mapassi', 'Mpila', 'La Tsiémé', 'Talangaï', 'Mikalou',
      'Ngamakosso', 'Ma-Mboualé', 'Kanga Mbandz', 'Mfilou', 'Sadelmi',
      'La Base', 'Mazala', 'Cité des 17', 'Soprogie'
    ].contains(zone)) {
      return 1500.0;
    } else if ([
      'Madibou', 'Mansimou', 'Mafouta', 'Massissia', 'Djiri', 'Ndjiri',
      'Massengo', 'Kombo', 'Kintélé', 'Makabandilou'
    ].contains(zone)) {
      return 2000.0;
    } else if ([
      'Mayanga', 'Moussosso', 'Mbouono', 'Kombé', 'Kibina', 'Nganga-Lingolo'
    ].contains(zone)) {
      return 2500.0;
    }
    return 1000.0;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CartLastModel());

    _model.locationTextController ??= TextEditingController();
    _model.locationFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).secondaryText,
              size: 30.0,
            ),
            onPressed: () async {
              if (widget!.sellerRef != null) {
                FFAppState().isSameOrder = true;
                safeSetState(() {});

                context.pushNamed(
                  ShopDetailPageWidget.routeName,
                  queryParameters: {
                    'userRef': serializeParam(
                      widget!.sellerRef,
                      ParamType.DocumentReference,
                    ),
                  }.withoutNulls,
                );
              } else {
                context.pushNamed(HomeWidget.routeName);
              }
            },
          ),
          title: Align(
            alignment: AlignmentDirectional(0.0, 0.0),
            child: Text(
              'Panier',
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
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Container(
            width: () {
              if (MediaQuery.sizeOf(context).width < kBreakpointSmall) {
                return 400.0;
              } else if (MediaQuery.sizeOf(context).width < kBreakpointMedium) {
                return 400.0;
              } else if (MediaQuery.sizeOf(context).width < kBreakpointLarge) {
                return 500.0;
              } else {
                return 500.0;
              }
            }(),
            height: MediaQuery.sizeOf(context).height * 0.85,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
            ),
            child: Stack(
              alignment: AlignmentDirectional(0.0, -1.0),
              children: [
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(14.0),
                        child: StreamBuilder<List<CartRecord>>(
                          stream: queryCartRecord(
                            queryBuilder: (cartRecord) => cartRecord
                                .where(
                                  'user_ref',
                                  isEqualTo: currentUserReference,
                                )
                                .where(
                                  'is_ordered',
                                  isEqualTo: false,
                                )
                                .where(
                                  'seller_ref',
                                  isEqualTo: widget!.sellerRef,
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
                            List<CartRecord> cartCartRecordList =
                                snapshot.data!;
                            final currentSubtotal =
                                functions.calculateSubtotal(cartCartRecordList.toList()) ?? 0.0;
                            final currentFee = getDeliveryFeeForZone(_model.zoneValue);
                            final expectedGrandTotal = currentSubtotal + currentFee;
                            if (FFAppState().totalCart != currentSubtotal ||
                                FFAppState().fixedShippingFee != currentFee ||
                                FFAppState().GrandTotalCart != expectedGrandTotal) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  safeSetState(() {
                                    FFAppState().totalCart = currentSubtotal;
                                    FFAppState().fixedShippingFee = currentFee;
                                    _model.deliveryFees = currentFee;
                                    FFAppState().GrandTotalCart = expectedGrandTotal;
                                  });
                                }
                              });
                            }
                            if (cartCartRecordList.isEmpty) {
                              return EmptyCardWidget(
                                title: 'Panier vide !',
                                description:
                                    'Vous n\'avez aucun produit dans votre pannier. Accedez à une boutique afin de choisir un produit dans le catalogue disponible.',
                                buttonText: 'Explorer',
                                photo:
                                    'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/vnqklpswxo1p/EmptyCart.png',
                                action: () async {
                                  context.pushNamed(HomeWidget.routeName);
                                },
                              );
                            }

                            return InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                if (widget!.sellerRef ==
                                    cartCartRecordList.lastOrNull?.sellerRef) {
                                  FFAppState().totalCart =
                                      functions.calculateSubtotal(
                                          cartCartRecordList.toList())!;
                                  final currentFee = getDeliveryFeeForZone(_model.zoneValue);
                                  FFAppState().fixedShippingFee = currentFee;
                                  _model.deliveryFees = currentFee;
                                  FFAppState().GrandTotalCart =
                                      (FFAppState().totalCart) + currentFee;
                                  safeSetState(() {});
                                } else {
                                  await showDialog(
                                    context: context,
                                    builder: (alertDialogContext) {
                                      return AlertDialog(
                                        title: Text('Commande non valide'),
                                        content: Text(
                                            'Vous ne pouvez créer un pannier que pour un vendeur à la fois'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                                alertDialogContext),
                                            child: Text('D\'accord'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  await widget!.cartRef!.reference.delete();
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: List.generate(
                                    cartCartRecordList.length, (cartIndex) {
                                  final cartCartRecord =
                                      cartCartRecordList[cartIndex];
                                  return StreamBuilder<ProductRecord>(
                                    stream: ProductRecord.getDocument(
                                        cartCartRecord.productRef!),
                                    builder: (context, snapshot) {
                                      // Customize what your widget looks like when it's loading.
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: SizedBox(
                                            width: 50.0,
                                            height: 50.0,
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final productProductRecord =
                                          snapshot.data!;

                                      return Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(24.0),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(6.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
                                                child: Container(
                                                  width: 60.0,
                                                  height: 60.0,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16.0),
                                                  ),
                                                  child: CachedNetworkImage(
                                                    fadeInDuration: Duration(
                                                        milliseconds: 0),
                                                    fadeOutDuration: Duration(
                                                        milliseconds: 0),
                                                    imageUrl: getCORSProxyUrl(
                                                      valueOrDefault<String>(
                                                        productProductRecord
                                                            .prodImg,
                                                        'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/ebk2xgecgley/ShopIcon_(1).png',
                                                      ),
                                                    ),
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        productProductRecord
                                                            .name,
                                                        'Aucun produit Dispo',
                                                      ),
                                                      maxLines: 1,
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleMedium
                                                              .override(
                                                                font: GoogleFonts
                                                                    .interTight(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                                fontSize: 14.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                              ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          valueOrDefault<
                                                              String>(
                                                            productProductRecord
                                                                .specifications,
                                                            'Aucune specification',
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .labelSmall
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 11.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelSmall
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelSmall
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                        Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          9999.0),
                                                              border:
                                                                  Border.all(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .divider,
                                                              ),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(3.0),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: [
                                                                  InkWell(
                                                                    splashColor:
                                                                        Colors
                                                                            .transparent,
                                                                    focusColor:
                                                                        Colors
                                                                            .transparent,
                                                                    hoverColor:
                                                                        Colors
                                                                            .transparent,
                                                                    highlightColor:
                                                                        Colors
                                                                            .transparent,
                                                                    onTap:
                                                                        () async {
                                                                      if (cartCartRecord
                                                                              .quantity >
                                                                          1) {
                                                                        await cartCartRecord
                                                                            .reference
                                                                            .update({
                                                                          ...mapToFirestore(
                                                                            {
                                                                              'quantity': FieldValue.increment(-(1)),
                                                                            },
                                                                          ),
                                                                        });
                                                                      } else {
                                                                        await cartCartRecord
                                                                            .reference
                                                                            .delete();
                                                                      }
                                                                    },
                                                                    child: Icon(
                                                                      Icons
                                                                          .remove,
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .primary,
                                                                      size:
                                                                          20.0,
                                                                    ),
                                                                  ),
                                                                  Padding(
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            10.0,
                                                                            0.0,
                                                                            10.0,
                                                                            0.0),
                                                                    child: Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        cartCartRecord
                                                                            .quantity
                                                                            .toString(),
                                                                        '0',
                                                                      ),
                                                                      maxLines:
                                                                          1,
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
                                                                                FlutterFlowTheme.of(context).primaryText,
                                                                            fontSize:
                                                                                14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).titleMedium.fontStyle,
                                                                          ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                  InkWell(
                                                                    splashColor:
                                                                        Colors
                                                                            .transparent,
                                                                    focusColor:
                                                                        Colors
                                                                            .transparent,
                                                                    hoverColor:
                                                                        Colors
                                                                            .transparent,
                                                                    highlightColor:
                                                                        Colors
                                                                            .transparent,
                                                                    onTap:
                                                                        () async {
                                                                      await cartCartRecord
                                                                          .reference
                                                                          .update({
                                                                        ...mapToFirestore(
                                                                          {
                                                                            'quantity':
                                                                                FieldValue.increment(1),
                                                                          },
                                                                        ),
                                                                      });
                                                                    },
                                                                    child: Icon(
                                                                      Icons.add,
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                      size:
                                                                          20.0,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          valueOrDefault<
                                                              String>(
                                                            productProductRecord
                                                                .salePrice
                                                                .toString(),
                                                            '0',
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .titleMedium
                                                              .override(
                                                                font: GoogleFonts
                                                                    .interTight(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 16.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                        Text(
                                                          'F',
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .titleMedium
                                                              .override(
                                                                font: GoogleFonts
                                                                    .interTight(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 16.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 16.0)),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).divide(SizedBox(height: 16.0)),
                              ),
                            );
                          },
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(),
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(14.0),
                                  border: Border.all(
                                    color: FlutterFlowTheme.of(context).accent2,
                                    width: 0.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            color: FlutterFlowTheme.of(context)
                                                .tertiary,
                                            size: 24.0,
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Addresse de Livraison',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .titleSmall
                                                      .override(
                                                        font: GoogleFonts
                                                            .interTight(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Text(
                                                  'Indiquer l\'addresse de livraison de vote commande',
                                                  maxLines: 2,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodySmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall
                                                                .fontStyle,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ].divide(SizedBox(height: 4.0)),
                                            ),
                                          ),
                                        ].divide(SizedBox(width: 16.0)),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  14.0, 7.0, 4.0, 7.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.public_rounded,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    size: 18.0,
                                                  ),
                                                  Text(
                                                    'Quartier',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primary,
                                                          fontSize: 12.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ].divide(SizedBox(width: 2.0)),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  FlutterFlowDropDown<String>(
                                                    controller: _model
                                                            .zoneValueController ??=
                                                        FormFieldController<
                                                            String>(null),
                                                    options: [
                                                      'Académie',
                                                      'Avenue de la Paix',
                                                      'Bacongo',
                                                      'Barrage',
                                                      'Batignolles',
                                                      'Centre sportif',
                                                      'Centre-ville',
                                                      'Château d\'eau',
                                                      'Cité des 17',
                                                      'Diata',
                                                      'Djiri',
                                                      'Kibina',
                                                      'Kingouari',
                                                      'Kinsoundi',
                                                      'Kintélé',
                                                      'Kombo',
                                                      'Kombé',
                                                      'La Base',
                                                      'La Tsiémé',
                                                      'Ma-Mboualé',
                                                      'Madibou',
                                                      'Mafouta',
                                                      'Makabandilou',
                                                      'Makélékélé',
                                                      'Mansimou',
                                                      'Mapassi',
                                                      'Marché Moungali',
                                                      'Massengo',
                                                      'Massissia',
                                                      'Mayanga',
                                                      'Mbouono',
                                                      'Mfilou',
                                                      'Mikalou',
                                                      'Moukondo',
                                                      'Moukoundzi-Ngouaka',
                                                      'Moungali',
                                                      'Moussosso',
                                                      'Mpila',
                                                      'Mpissa',
                                                      'Ngamakosso',
                                                      'Nganga-Lingolo',
                                                      'Ndjiri',
                                                      'O.C.H',
                                                      'Ouenzé',
                                                      'Plateau des 15 ans',
                                                      'Poto-Poto',
                                                      'Sadelmi',
                                                      'Soprogie',
                                                      'Talangaï'
                                                    ],
                                                    onChanged: (val) async {
                                                       final fee = getDeliveryFeeForZone(val);
                                                       safeSetState(() {
                                                         _model.zoneValue = val;
                                                         _model.zone = val;
                                                         _model.deliveryFees = fee;
                                                         FFAppState().fixedShippingFee = fee;
                                                         FFAppState().GrandTotalCart = (FFAppState().totalCart) + fee;
                                                       });
                                                     },
                                                     width: 220.0,
                                                    height: 30.0,
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 12.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                    hintText:
                                                        'Choisi ton quartier',
                                                    icon: Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondary,
                                                      size: 24.0,
                                                    ),
                                                    elevation: 0.0,
                                                    borderColor:
                                                        Colors.transparent,
                                                    borderWidth: 0.0,
                                                    borderRadius: 8.0,
                                                    margin:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(12.0, 0.0,
                                                                12.0, 0.0),
                                                    hidesUnderline: true,
                                                    isOverButton: false,
                                                    isSearchable: false,
                                                    isMultiSelect: false,
                                                  ),
                                                ],
                                              ),
                                            ].divide(SizedBox(width: 10.0)),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  14.0, 7.0, 0.0, 7.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Icon(
                                                    Icons.store_rounded,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    size: 18.0,
                                                  ),
                                                  Text(
                                                    'Rue',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primary,
                                                          fontSize: 12.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ].divide(SizedBox(width: 2.0)),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 0.0, 10.0, 0.0),
                                                  child: Container(
                                                    width: 200.0,
                                                    child: TextFormField(
                                                      controller: _model
                                                          .locationTextController,
                                                      focusNode: _model
                                                          .locationFocusNode,
                                                      autofocus: false,
                                                      enabled: true,
                                                      obscureText: false,
                                                      decoration:
                                                          InputDecoration(
                                                        isDense: true,
                                                        labelStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                        hintText:
                                                            '62 bis Av Corniche, Mikalou',
                                                        hintStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: Color(
                                                                0x00000000),
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: Color(
                                                                0x00000000),
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        errorBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .error,
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        focusedErrorBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              BorderSide(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .error,
                                                            width: 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                        ),
                                                        filled: true,
                                                        fillColor:
                                                            Colors.transparent,
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                fontSize: 12.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                      cursorColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      enableInteractiveSelection:
                                                          true,
                                                      validator: _model
                                                          .locationTextControllerValidator
                                                          .asValidator(context),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 5.0)),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          final q = _model.zone != null && _model.zone!.isNotEmpty
                                              ? 'Brazzaville, ${_model.zone}'
                                              : 'Brazzaville, République du Congo';
                                          await launchURL('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
                                        },
                                        child: Container(
                                        width: double.infinity,
                                        height: 320.0,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: FlutterFlowTheme.of(context)
                                                .tertiary,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image.network(
                                            getCORSProxyUrl(
                                              valueOrDefault<String>(
                                                () {
                                                  if (_model.zone ==
                                                      'Avenue de la Paix') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/96kbhp9scr8m/Av_Paix.jpg';
                                                  } else if (_model.zone ==
                                                      'Bacongo') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/npi5151n0k1p/Bacongo.jpg';
                                                  } else if (_model.zone ==
                                                      'Barrage') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/h8ds3hm1wyjh/Barrage.jpg';
                                                  } else if (_model.zone ==
                                                      'Batignolles') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/dwghivq9my60/batignole.jpg';
                                                  } else if (_model.zone ==
                                                      'Centre sportif') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/q07gn73ny7ed/makelekele.jpg';
                                                  } else if (_model.zone ==
                                                      'Centre-ville') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/kuoubno85ha9/ville-radisson.jpg';
                                                  } else if (_model.zone ==
                                                      'Château d\'eau') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/wdvzqwoztlzg/chateau_deau.jpg';
                                                  } else if (_model.zone ==
                                                      'Cité des 17') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/wtl9b9von4fm/cite_17.jpg';
                                                  } else if (_model.zone ==
                                                      'Diata') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/g6cqd4p6yce7/diata.jpg';
                                                  } else if (_model.zone ==
                                                      'Djiri') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/em9ct121bd0r/djiri.jpg';
                                                  } else if (_model.zone ==
                                                      'Kibina') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/8p1lcrtnmey0/madibou.jpg';
                                                  } else if (_model.zone ==
                                                      'Kingouari') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/nqkurjwggyfl/kigouari.jpg';
                                                  } else if (_model.zone ==
                                                      'Kinsoundi') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/cmair8547wl9/kisundi.jpg';
                                                  } else if (_model.zone ==
                                                      'Kintélé') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/ci5rgx41bbjp/kintele.jpg';
                                                  } else if (_model.zone ==
                                                      'Kombo') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/cr8izr9r7vnm/kombo.jpg';
                                                  } else if (_model.zone ==
                                                      'La Base') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/mhk3zbchor0e/la_base.jpg';
                                                  } else if (_model.zone ==
                                                      'La Tsiémé') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/qbjo4oa6z5fi/La_Tsieme.jpg';
                                                  } else if (_model.zone ==
                                                      'Ma-Mboualé') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/gbvtyd8pt6z4/mbouale.jpg';
                                                  } else if (_model.zone ==
                                                      'Madibou') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/8p1lcrtnmey0/madibou.jpg';
                                                  } else if (_model.zone ==
                                                      'Mafouta') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/x572tglyd8om/mafouta.jpg';
                                                  } else if (_model.zone ==
                                                      'Makabandilou') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/0c3ae54nh2df/Makabandilou.jpg';
                                                  } else if (_model.zone ==
                                                      'Makélékélé') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/q07gn73ny7ed/makelekele.jpg';
                                                  } else if (_model.zone ==
                                                      'Mansimou') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/o5r47c7h6xy4/mansimou.jpg';
                                                  } else if (_model.zone ==
                                                      'Mapassi') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/l746lg8ewjw0/mapassi.png';
                                                  } else if (_model.zone ==
                                                      'Marché Moungali') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/gitzv0f94pm7/mougali.png';
                                                  } else if (_model.zone ==
                                                      'Massengo') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/lecrnafgnwrr/massengo.jpg';
                                                  } else if (_model.zone ==
                                                      'Massissia') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/uky530izfm3g/massissa.jpg';
                                                  } else if (_model.zone ==
                                                      'Mayanga') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/oi4vxr6thou2/mayanga.jpg';
                                                  } else if (_model.zone ==
                                                      'Mbouono') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/f4co5rqs7agc/mbouono.jpg';
                                                  } else if (_model.zone ==
                                                      'Mfilou') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/l0j1ul7cu4j4/mfilou.jpg';
                                                  } else if (_model.zone ==
                                                      'Mikalou') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/013eufdnn24t/mikalou.jpg';
                                                  } else if (_model.zone ==
                                                      'Moukondo') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/gwpsm4z8wefj/moukondo.jpg';
                                                  } else if (_model.zone ==
                                                      'Moukoundzi-Ngouaka') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/96xe8p58wj0q/moukounzi_ngouaka.jpg';
                                                  } else if (_model.zone ==
                                                      'Moungali') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/gitzv0f94pm7/mougali.png';
                                                  } else if (_model.zone ==
                                                      'Moussosso') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/ry4tfurzfzdd/moussosso.jpg';
                                                  } else if (_model.zone ==
                                                      'Mpila') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/v54qgk9kgjt7/mpila.jpg';
                                                  } else if (_model.zone ==
                                                      'Mpissa') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/pjdad8guzdwh/Mpiss.jpg';
                                                  } else if (_model.zone ==
                                                      'Ngamakosso') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/cmpi44hqlj9o/ngamakosso.jpg';
                                                  } else if (_model.zone ==
                                                      'Nganga-Lingolo') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/gnhw8yomipv0/ngangalingolo.jpg';
                                                  } else if (_model.zone ==
                                                      'Ndjiri') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/em9ct121bd0r/djiri.jpg';
                                                  } else if (_model.zone ==
                                                      'O.C.H') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/856amc5on2z1/OCH.jpg';
                                                  } else if (_model.zone ==
                                                      'Talangaï') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/x8iv4713ugv9/talangai.jpg';
                                                  } else if (_model.zone ==
                                                      'Soprogie') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/u5civf1yxxes/SOPROGIE.jpg';
                                                  } else if (_model.zone ==
                                                      'Sadelmi') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/b3jmepvevn7f/sadelmie.jpg';
                                                  } else if (_model.zone ==
                                                      'Poto-Poto') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/embxmtiggnh9/poto_poto.png';
                                                  } else if (_model.zone ==
                                                      'Plateau des 15 ans') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/m9unb7oz8mkx/Plateau.jpg';
                                                  } else if (_model.zone ==
                                                      'Ouenzé') {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/ryley3vutnl9/ouenze.png';
                                                  } else {
                                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/azpygr5br5gj/aa1.jpg';
                                                  }
                                                }(),
                                                'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/azpygr5br5gj/aa1.jpg',
                                              ),
                                            ),
                                            width: 200.0,
                                            height: 200.0,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      ),
                                    ].divide(SizedBox(height: 10.0)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Paiement',
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.interTight(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
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
                                    context.pushNamed(
                                        AddPhoneNumberWidget.routeName);
                                  },
                                  child: Text(
                                    'Changer le numéro',
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.interTight(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                          lineHeight: 1.4,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: AuthUserStreamWidget(
                              builder: (context) => wrapWithModel(
                                model: _model.paymentMethodModel,
                                updateCallback: () => safeSetState(() {}),
                                child: PaymentMethodWidget(
                                  selected: true,
                                  icon: Icon(
                                    Icons.phone_android_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 24.0,
                                  ),
                                  airtelNumber: valueOrDefault<String>(
                                    widget!.airtelNumber != null &&
                                            widget!.airtelNumber != ''
                                        ? valueOrDefault<String>(
                                            widget!.airtelNumber,
                                            '05xxxxxxx',
                                          )
                                        : currentPhoneNumber,
                                    '05xxxxxx ',
                                  ),
                                  mtnNumber: valueOrDefault<String>(
                                    widget!.mtnNumber != null &&
                                            widget!.mtnNumber != ''
                                        ? widget!.mtnNumber
                                        : currentPhoneNumber,
                                    '06xxxxxx ',
                                  ),
                                  isMoMo: () async {
                                    _model.paymentMethodModel.isMoMoValue = true;
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional(0.0, 1.0),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  20.0, 0.0, 20.0, 0.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: FlutterFlowTheme.of(context).accent2,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12.0),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10.0,
                                        sigmaY: 10.0,
                                      ),
                                      child: Container(
                                        height: 230.0,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: Colors.transparent,
                                            width: 0.0,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(14.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Cout total',
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
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            valueOrDefault<
                                                                String>(
                                                              FFAppState()
                                                                  .totalCart
                                                                  .toStringAsFixed(0),
                                                              '0',
                                                            ),
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
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
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
                                                          Text(
                                                            'F',
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
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
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
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Frais de Livraison',
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
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            valueOrDefault<
                                                                String>(
                                                              FFAppState()
                                                                  .fixedShippingFee
                                                                  .toStringAsFixed(0),
                                                              '1000',
                                                            ),
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
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
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
                                                          Text(
                                                            'F',
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
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
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
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  Divider(
                                                    thickness: 1.0,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .divider,
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Montant total',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleLarge
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .interTight(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  fontSize:
                                                                      18.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleLarge
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            valueOrDefault<
                                                                String>(
                                                              FFAppState()
                                                                  .GrandTotalCart
                                                                  .toStringAsFixed(0),
                                                              '0',
                                                            ),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .titleLarge
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .interTight(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleLarge
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                          Text(
                                                            'F',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .titleLarge
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .interTight(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleLarge
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleLarge
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ].divide(SizedBox(height: 8.0)),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Expanded(
                                                    child: FFButtonWidget(
                                                      onPressed: () async {
                                                        if (_model.zoneValue == null || _model.zoneValue!.trim().isEmpty) {
                                                          await showDialog(
                                                            context: context,
                                                            builder: (dialogCtx) => AlertDialog(
                                                              title: Text('Quartier requis'),
                                                              content: Text('Veuillez sélectionner votre quartier dans la liste avant de valider votre commande.'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(dialogCtx),
                                                                  child: Text('Ok'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          return;
                                                        }

                                                        if (_model.paymentMethodModel.isMoMoValue != true) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Veuillez sélectionner Mobile Money pour procéder au paiement.',
                                                                style: TextStyle(
                                                                  color: FlutterFlowTheme.of(context).primaryText,
                                                                ),
                                                              ),
                                                              backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
                                                            ),
                                                          );
                                                          return;
                                                        }

                                                        String rawPhone = widget!.mtnNumber != null && widget!.mtnNumber!.trim().isNotEmpty
                                                            ? widget!.mtnNumber!.trim()
                                                            : currentPhoneNumber;
                                                        String cleanedPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
                                                        if (cleanedPhone.startsWith('06') && cleanedPhone.length == 9) {
                                                          cleanedPhone = '242$cleanedPhone';
                                                        } else if (cleanedPhone.startsWith('6') && cleanedPhone.length == 8) {
                                                          cleanedPhone = '2420$cleanedPhone';
                                                        }
                                                        if (cleanedPhone.isEmpty) {
                                                          await showDialog(
                                                            context: context,
                                                            builder: (dialogCtx) => AlertDialog(
                                                              title: Text('Numéro requis'),
                                                              content: Text('Veuillez renseigner votre numéro MTN Mobile Money avant de valider votre commande.'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(dialogCtx),
                                                                  child: Text('Ok'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        showDialog(
                                                          context: context,
                                                          barrierDismissible: false,
                                                          builder: (dialogCtx) => Center(
                                                            child: Container(
                                                              padding: EdgeInsets.all(24.0),
                                                              decoration: BoxDecoration(
                                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                borderRadius: BorderRadius.circular(16.0),
                                                              ),
                                                              child: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  CircularProgressIndicator(
                                                                    color: FlutterFlowTheme.of(context).primary,
                                                                  ),
                                                                  SizedBox(height: 16.0),
                                                                  Text(
                                                                    'Validez le paiement sur votre téléphone\n(saisissez votre code PIN MTN)...',
                                                                    textAlign: TextAlign.center,
                                                                    style: FlutterFlowTheme.of(context).bodyMedium,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );


                                                        final currentFee = getDeliveryFeeForZone(_model.zoneValue);
                                                        FFAppState().fixedShippingFee = currentFee;
                                                        FFAppState().GrandTotalCart =
                                                            (FFAppState().totalCart) + currentFee;
                                                        final momoAmount = valueOrDefault<double>(
                                                          FFAppState().GrandTotalCart,
                                                          0.0,
                                                        );
                                                        final momoOrderId = FFAppState().orderReferenceUnique.isNotEmpty
                                                            ? FFAppState().orderReferenceUnique
                                                            : 'ORD-${DateTime.now().millisecondsSinceEpoch}';

                                                        ApiCallResponse momoResponse;
                                                        try {
                                                          momoResponse = await MoMoCallCall.call(
                                                            phoneNumber: cleanedPhone,
                                                            amount: momoAmount,
                                                            orderId: momoOrderId,
                                                          );
                                                        } catch (_) {
                                                          Navigator.of(context, rootNavigator: true).pop();
                                                          await showDialog(
                                                            context: context,
                                                            builder: (alertDialogContext) => AlertDialog(
                                                              title: Text('Erreur de connexion'),
                                                              content: Text('Impossible d\'initialiser le paiement Mobile Money. Veuillez vérifier votre connexion internet et réessayer.'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(alertDialogContext),
                                                                  child: Text('Ok'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          return;
                                                        }

                                                        Navigator.of(context, rootNavigator: true).pop();

                                                        if (!momoResponse.succeeded || MoMoCallCall.status(momoResponse.jsonBody) != 'success') {
                                                          await _logPaiement(
                                                            status: MoMoCallCall.status(momoResponse.jsonBody) == 'pending'
                                                                ? 'En attente'
                                                                : 'Echec',
                                                            response: momoResponse,
                                                            amount: momoAmount,
                                                            orderId: momoOrderId,
                                                          );
                                                          await showDialog(
                                                            context: context,
                                                            builder: (alertDialogContext) => AlertDialog(
                                                              title: Text('Échec de la transaction'),
                                                              content: Text(
                                                                MoMoCallCall.message(momoResponse.jsonBody) ??
                                                                    'La demande de paiement MoMo a échoué. Veuillez vérifier votre solde ou réessayer.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(alertDialogContext),
                                                                  child: Text('Ok'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          return;
                                                        }

                                                        var ordersRecordReference =
                                                            OrdersRecord
                                                                .collection
                                                                .doc();
                                                        await ordersRecordReference
                                                            .set(
                                                                createOrdersRecordData(
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          userRef:
                                                              currentUserReference,
                                                          isActive: true,
                                                          totalAmount:
                                                              valueOrDefault<
                                                                  double>(
                                                            FFAppState()
                                                                .GrandTotalCart,
                                                            0.0,
                                                          ),
                                                          sellerRef:
                                                              widget!.sellerRef,
                                                          deliveryLocation: _model
                                                              .locationTextController
                                                              .text,
                                                          orderId: FFAppState()
                                                              .orderReferenceUnique,
                                                          deliveryZone:
                                                              _model.zoneValue,
                                                          deliveryFees: FFAppState()
                                                              .fixedShippingFee,
                                                          orderUniqueReference:
                                                              FFAppState()
                                                                  .orderReferenceUnique,
                                                          status: 'En attente',
                                                        ));
                                                        _model.orderReference =
                                                            OrdersRecord.getDocumentFromData(
                                                                createOrdersRecordData(
                                                                  createdAt:
                                                                      getCurrentTimestamp,
                                                                  userRef:
                                                                      currentUserReference,
                                                                  isActive:
                                                                      true,
                                                                  totalAmount:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    FFAppState()
                                                                        .GrandTotalCart,
                                                                    0.0,
                                                                  ),
                                                                  sellerRef: widget!
                                                                      .sellerRef,
                                                                  deliveryLocation:
                                                                      _model
                                                                          .locationTextController
                                                                          .text,
                                                                  orderId:
                                                                      FFAppState()
                                                                          .orderReferenceUnique,
                                                                  deliveryZone:
                                                                      _model
                                                                          .zoneValue,
                                                                  deliveryFees:
                                                                      FFAppState()
                                                                          .fixedShippingFee,
                                                                  orderUniqueReference:
                                                                      FFAppState()
                                                                          .orderReferenceUnique,
                                                                  status:
                                                                      'En attente',
                                                                ),
                                                                ordersRecordReference);
                                                        try {
                                                          await ordersRecordReference.update({
                                                            'payment_reference': MoMoCallCall.referenceId(momoResponse.jsonBody),
                                                            'payment_status': 'Réussi',
                                                          });
                                                        } catch (_) {
                                                          // Le paiement est déjà encaissé : ne jamais interrompre la suite.
                                                        }
                                                        await _logPaiement(
                                                          status: 'Réussi',
                                                          response: momoResponse,
                                                          amount: momoAmount,
                                                          orderId: momoOrderId,
                                                          orderRef: ordersRecordReference,
                                                        );
                                                        await Future.wait([
                                                          Future(() async {
                                                            _model.orderRefs =
                                                                _model
                                                                    .orderReference
                                                                    ?.reference;
                                                            safeSetState(() {});
                                                          }),
                                                          Future(() async {
                                                            FFAppState()
                                                                    .GrandTotalCart =
                                                                0.0;
                                                            FFAppState()
                                                                    .totalCart =
                                                                0.0;
                                                            FFAppState()
                                                                    .isSameOrder =
                                                                false;
                                                            FFAppState()
                                                                .orderReferenceUnique = '';
                                                            safeSetState(() {});
                                                            await widget!
                                                                .cartRef!
                                                                .reference
                                                                .delete();
                                                          }),
                                                        ]);
                                                        await showDialog(
                                                          context: context,
                                                          builder:
                                                              (alertDialogContext) {
                                                            return AlertDialog(
                                                              title: Text(
                                                                  'Paiement initié'),
                                                              content: Text(
                                                                  MoMoCallCall.message(momoResponse.jsonBody) ??
                                                                      'Votre commande a été enregistrée. Veuillez valider la transaction Mobile Money sur votre téléphone.'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          alertDialogContext),
                                                                  child: Text(
                                                                      'Ok'),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );

                                                        context.pushNamed(
                                                            HomeWidget
                                                                .routeName);

                                                        safeSetState(() {});
                                                      },
                                                      text:
                                                          'Confirmer l\'ordre',
                                                      options: FFButtonOptions(
                                                        width:
                                                            MediaQuery.sizeOf(
                                                                        context)
                                                                    .width *
                                                                0.5,
                                                        height: 44.0,
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        iconPadding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primary,
                                                        textStyle: TextStyle(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14.0,
                                                        ),
                                                        elevation: 0.0,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    9999.0),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ].divide(SizedBox(height: 24.0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Trace chaque tentative de paiement MoMo dans la collection `Paiement`
  /// (consultée par le tableau de bord NOC) pour pouvoir rapprocher les
  /// paiements avec MTN en cas de litige.
  Future _logPaiement({
    required String status,
    required ApiCallResponse response,
    required double amount,
    required String orderId,
    DocumentReference? orderRef,
  }) async {
    // Erreur de saisie (numéro, montant) : aucune demande envoyée à MTN.
    if (getJsonField(response.jsonBody, r'''$.step''') == 'validation') {
      return;
    }
    try {
      await PaiementRecord.collection.doc().set({
        'status': status,
        'reference_id': MoMoCallCall.referenceId(response.jsonBody),
        'message': MoMoCallCall.message(response.jsonBody),
        'amount': amount,
        'order_id': orderId,
        'order_ref': orderRef,
        'user_ref': currentUserReference,
        'operator': 'MTN',
        'created_at': getCurrentTimestamp,
      });
    } catch (_) {
      // La journalisation ne doit jamais bloquer le parcours d'achat.
    }
  }
}
