import '/mobile/main_app/subscription/my_subscription_page.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart' show KitungaClosedNotice;
import '/flutter_flow/random_data_util.dart' as random_data;
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/server_payment.dart';
import '/backend/subscription.dart';
import '/components/payment_method_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/components/product_card/product_card_widget.dart' show kitungaPrice;
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'cart_last_model.dart';
import '/mobile/components/form_styles/form_styles.dart';
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

  /// Frais calculés par le serveur (distance commerce → client), par
  /// « commerce|quartier ». Le paiement utilise le même calcul.
  final Map<String, double> _quotes = {};
  final Set<String> _quoting = {};

  double getDeliveryFeeForZone(String? zone) {
    final seller = _sellerRef;
    if (seller != null && zone != null && zone.isNotEmpty) {
      final key = '${seller.path}|$zone';
      final quoted = _quotes[key];
      if (quoted != null) return quoted;
      if (_quoting.add(key)) {
        kitungaCallFunction('kitungaDeliveryQuote',
                {'sellerPath': seller.path, 'zone': zone})
            .then((r) {
          final fee = (r['fee'] as num?)?.toDouble();
          if (fee == null || !mounted) return;
          safeSetState(() {
            _quotes[key] = fee;
            if (_model.zoneValue == zone) {
              _model.deliveryFees = fee;
              FFAppState().fixedShippingFee = fee;
              FFAppState().GrandTotalCart = FFAppState().totalCart + fee;
            }
          });
        }).catchError((_) {
          _quoting.remove(key); // nouvel essai au prochain affichage
        });
      }
    }
    // En attendant la réponse du serveur : ancien tarif par quartier.
    return _zoneFee(zone);
  }

  double _zoneFee(String? zone) {
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

  /// Lignes affichées, et donc payées, sur cet écran.
  List<CartRecord> _cartLines = [];

  /// Commerce de la commande : celui demandé à l'ouverture de l'écran, sinon
  /// celui des lignes affichées (panier ouvert depuis le menu, l'accueil…).
  DocumentReference? get _sellerRef =>
      widget.sellerRef ?? _cartLines.firstOrNull?.sellerRef;

  /// Une commande ne concerne qu'un seul commerce. Sans commerce précisé, on
  /// garde celui du dernier article ajouté ; les autres articles restent dans
  /// le panier et ne sont pas facturés.
  List<CartRecord> _linesOfOneSeller(List<CartRecord> lines) {
    if (widget.sellerRef != null || lines.isEmpty) return lines;
    var latest = lines.first;
    for (final line in lines) {
      final at = line.createdAt;
      final best = latest.createdAt;
      if (at != null && (best == null || at.isAfter(best))) latest = line;
    }
    return lines.where((l) => l.sellerRef == latest.sellerRef).toList();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
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
        body: KitungaScaffoldBackground(
          child: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.transparent,
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
                                _linesOfOneSeller(snapshot.data!);
                            _cartLines = cartCartRecordList;
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
                                    'Votre panier est vide. Parcourez les commerces pour choisir vos produits.',
                                buttonText: 'Explorer',
                                photo:
                                    'assets/images/app/emptycart.png',
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
                                if (_sellerRef ==
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
                                        title: Text('Un seul commerce par panier'),
                                        content: Text(
                                            'Votre panier contient déjà les articles d\'un autre commerce. Finalisez ou videz ce panier avant de commander ailleurs.'),
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
                                  await widget.cartRef?.reference.delete();
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
                                                  child: KitungaImage(
                                                    productProductRecord.prodImg,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fallbackIcon: Icons.image_outlined,
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
                                                        'Produit',
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
                                                    // Options choisies par le client (taille, suppléments…).
                                                    if (cartCartRecord.options.isNotEmpty)
                                                      Text(
                                                        cartCartRecord.options,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.inter(
                                                          color: FlutterFlowTheme.of(context).secondaryText,
                                                          fontSize: 12.5,
                                                        ),
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
                                                            '',
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
                                                          // Prix unitaire de la ligne (suppléments compris).
                                                          cartCartRecord.price.round().toString(),
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
                                                  'Adresse de livraison',
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
                                                        'Choisissez votre quartier',
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
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12.0),
                                          child: KitungaImage(
                                            () {
                                              if (_model.zone == 'Avenue de la Paix') {
                                                return 'assets/images/zones/av_paix.jpg';
                                              } else if (_model.zone == 'Bacongo') {
                                                return 'assets/images/zones/bacongo.jpg';
                                              } else if (_model.zone == 'Barrage') {
                                                return 'assets/images/zones/barrage.jpg';
                                              } else if (_model.zone == 'Batignolles') {
                                                return 'assets/images/zones/batignole.jpg';
                                              } else if (_model.zone == 'Centre sportif') {
                                                return 'assets/images/zones/makelekele.jpg';
                                              } else if (_model.zone == 'Centre-ville') {
                                                return 'assets/images/zones/ville_radisson.jpg';
                                              } else if (_model.zone == "Château d'eau") {
                                                return 'assets/images/zones/chateau_deau.jpg';
                                              } else if (_model.zone == "Cité des 17") {
                                                return 'assets/images/zones/cite_17.jpg';
                                              } else if (_model.zone == 'Diata') {
                                                return 'assets/images/zones/diata.jpg';
                                              } else if (_model.zone == 'Djiri') {
                                                return 'assets/images/zones/djiri.jpg';
                                              } else if (_model.zone == 'Kibina') {
                                                return 'assets/images/zones/madibou.jpg';
                                              } else if (_model.zone == 'Kingouari') {
                                                return 'assets/images/zones/kigouari.jpg';
                                              } else if (_model.zone == 'Kinsoundi') {
                                                return 'assets/images/zones/kisundi.jpg';
                                              } else if (_model.zone == 'Kintélé') {
                                                return 'assets/images/zones/kintele.jpg';
                                              } else if (_model.zone == 'Kombo') {
                                                return 'assets/images/zones/kombo.jpg';
                                              } else if (_model.zone == 'La Base') {
                                                return 'assets/images/zones/la_base.jpg';
                                              } else if (_model.zone == 'La Tsiémé') {
                                                return 'assets/images/zones/la_tsieme.jpg';
                                              } else if (_model.zone == 'Ma-Mboualé') {
                                                return 'assets/images/zones/mbouale.jpg';
                                              } else if (_model.zone == 'Madibou') {
                                                return 'assets/images/zones/madibou.jpg';
                                              } else if (_model.zone == 'Mafouta') {
                                                return 'assets/images/zones/mafouta.jpg';
                                              } else if (_model.zone == 'Makabandilou') {
                                                return 'assets/images/zones/makabandilou.jpg';
                                              } else if (_model.zone == 'Makélékélé') {
                                                return 'assets/images/zones/makelekele.jpg';
                                              } else if (_model.zone == 'Mansimou') {
                                                return 'assets/images/zones/mansimou.jpg';
                                              } else if (_model.zone == 'Mapassi') {
                                                return 'assets/images/zones/mapassi.png';
                                              } else if (_model.zone == 'Marché Moungali') {
                                                return 'assets/images/zones/mougali.png';
                                              } else if (_model.zone == 'Massengo') {
                                                return 'assets/images/zones/massengo.jpg';
                                              } else if (_model.zone == 'Massissia') {
                                                return 'assets/images/zones/massissa.jpg';
                                              } else if (_model.zone == 'Mayanga') {
                                                return 'assets/images/zones/mayanga.jpg';
                                              } else if (_model.zone == 'Mbouono') {
                                                return 'assets/images/zones/mbouono.jpg';
                                              } else if (_model.zone == 'Mfilou') {
                                                return 'assets/images/zones/mfilou.jpg';
                                              } else if (_model.zone == 'Mikalou') {
                                                return 'assets/images/zones/mikalou.jpg';
                                              } else if (_model.zone == 'Moukondo') {
                                                return 'assets/images/zones/moukondo.jpg';
                                              } else if (_model.zone == 'Moukoundzi-Ngouaka') {
                                                return 'assets/images/zones/moukounzi_ngouaka.jpg';
                                              } else if (_model.zone == 'Moungali') {
                                                return 'assets/images/zones/mougali.png';
                                              } else if (_model.zone == 'Moussosso') {
                                                return 'assets/images/zones/moussosso.jpg';
                                              } else if (_model.zone == 'Mpila') {
                                                return 'assets/images/zones/mpila.jpg';
                                              } else if (_model.zone == 'Mpissa') {
                                                return 'assets/images/zones/mpiss.jpg';
                                              } else if (_model.zone == 'Ngamakosso') {
                                                return 'assets/images/zones/ngamakosso.jpg';
                                              } else if (_model.zone == 'Nganga-Lingolo') {
                                                return 'assets/images/zones/ngangalingolo.jpg';
                                              } else if (_model.zone == 'Ndjiri') {
                                                return 'assets/images/zones/djiri.jpg';
                                              } else if (_model.zone == 'O.C.H') {
                                                return 'assets/images/zones/och.jpg';
                                              } else if (_model.zone == 'Talangaï') {
                                                return 'assets/images/zones/talangai.jpg';
                                              } else if (_model.zone == 'Soprogie') {
                                                return 'assets/images/zones/soprogie.jpg';
                                              } else if (_model.zone == 'Sadelmi') {
                                                return 'assets/images/zones/sadelmie.jpg';
                                              } else if (_model.zone == 'Poto-Poto') {
                                                return 'assets/images/zones/poto_poto.png';
                                              } else if (_model.zone == 'Plateau des 15 ans') {
                                                return 'assets/images/zones/plateau.jpg';
                                              } else if (_model.zone == 'Ouenzé') {
                                                return 'assets/images/zones/ouenze.png';
                                              } else {
                                                return 'assets/images/zones/aa1.jpg';
                                              }
                                            }(),
                                            width: double.infinity,
                                            height: 150.0,
                                            fallbackIcon: Icons.location_city_rounded,
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
                                              // Commerce fermé : prévenu avant de payer.
                                              if (_sellerRef != null)
                                                KitungaClosedNotice(
                                                    sellerRef: _sellerRef!),
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Expanded(
                                                    child: FFButtonWidget(
                                                      onPressed: () async {
                                                        // Lignes et commerce figés avant le paiement :
                                                        // ce sont eux qui seront facturés puis retirés.
                                                        final paidLines = List<CartRecord>.of(_cartLines);
                                                        final orderSellerRef = _sellerRef;
                                                        if (paidLines.isEmpty || orderSellerRef == null) {
                                                          await showDialog(
                                                            context: context,
                                                            builder: (dialogCtx) => AlertDialog(
                                                              title: Text(paidLines.isEmpty ? 'Panier vide' : 'Commerce introuvable'),
                                                              content: Text(paidLines.isEmpty
                                                                  ? 'Ajoutez un produit à votre panier avant de valider votre commande.'
                                                                  : 'Retirez cet article du panier puis ajoutez-le de nouveau depuis la page du commerce.'),
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

                                                        if (!kitungaCanOrder()) {
                                                          await showDialog(
                                                            context: context,
                                                            builder: (c) => AlertDialog(
                                                              title: Text('Abonnement requis'),
                                                              content: Text(kitungaSubscriptionRequired),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(c),
                                                                  child: Text('Compris'),
                                                                ),
                                                                FilledButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(c);
                                                                    openMySubscription(context);
                                                                  },
                                                                  child: Text('S\'abonner'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        // Numéro saisi dans « Moyen de paiement » (MTN ou Airtel).
                                                        final operator = _model.paymentMethodModel.operator;
                                                        final typedPhone = _model.paymentMethodModel.phoneController.text.trim();
                                                        String rawPhone = typedPhone.isNotEmpty
                                                            ? typedPhone
                                                            : widget!.mtnNumber != null && widget!.mtnNumber!.trim().isNotEmpty
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
                                                              content: Text('Veuillez renseigner votre numéro ${kPaymentOperators[operator]!.label} avant de valider votre commande.'),
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
                                                        if (kServerPayment) {
                                                          await _payOnServer(cleanedPhone, operator);
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
                                                        FFAppState().totalCart =
                                                            functions.calculateSubtotal(paidLines) ?? 0.0;
                                                        FFAppState().GrandTotalCart =
                                                            (FFAppState().totalCart) + currentFee;
                                                        final momoAmount = valueOrDefault<double>(
                                                          FFAppState().GrandTotalCart,
                                                          0.0,
                                                        );
                                                        // Référence propre à cette commande : les articles payés y sont
                                                        // rattachés juste après le paiement (voir _linkOrderItems).
                                                        final momoOrderId =
                                                            'ORD-${DateTime.now().millisecondsSinceEpoch}-${random_data.randomString(6, 6, true, true, false)}';

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
                                                              orderSellerRef,
                                                          deliveryLocation: _model
                                                              .locationTextController
                                                              .text,
                                                          orderId: momoOrderId,
                                                          deliveryZone:
                                                              _model.zoneValue,
                                                          deliveryFees: FFAppState()
                                                              .fixedShippingFee,
                                                          orderUniqueReference: momoOrderId,
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
                                                                  sellerRef:
                                                                      orderSellerRef,
                                                                  deliveryLocation:
                                                                      _model
                                                                          .locationTextController
                                                                          .text,
                                                                  orderId: momoOrderId,
                                                                  deliveryZone:
                                                                      _model
                                                                          .zoneValue,
                                                                  deliveryFees:
                                                                      FFAppState()
                                                                          .fixedShippingFee,
                                                                  orderUniqueReference: momoOrderId,
                                                                  status:
                                                                      'En attente',
                                                                ),
                                                                ordersRecordReference);
                                                        await _linkOrderItems(paidLines, momoOrderId);
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
                                                            // Toutes les lignes payées quittent le panier.
                                                            // La commande est déjà enregistrée : un échec
                                                            // ici ne doit pas masquer la confirmation.
                                                            for (final line in paidLines) {
                                                              try {
                                                                await line.reference.delete();
                                                              } catch (_) {}
                                                            }
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
      ),
    );
  }

  /// Rattache à la commande les articles réellement payés, avec leur quantité
  /// et leur prix finaux. La commande est déjà enregistrée : un échec ici ne
  /// doit pas interrompre le parcours.
  Future<void> _linkOrderItems(
      List<CartRecord> lines, String reference) async {
    for (final line in lines) {
      try {
        final items = await queryOrderItemsRecordOnce(
          queryBuilder: (q) => q
              .where('user_ref', isEqualTo: currentUserReference)
              .where('cart_ref', isEqualTo: line.reference),
        );
        for (final item in items) {
          await item.reference.update({
            'order_ref': reference,
            'quantity': line.quantity,
            'price_at_purchase': line.price,
          });
        }
      } catch (_) {}
    }
  }

  /// Paiement contrôlé par le serveur : prix, stock et commande calculés
  /// par les Cloud Functions (voir lib/backend/server_payment.dart).
  Future<void> _payOnServer(String phone, [String operator = 'MTN']) async {
    final label = kPaymentOperators[operator]?.label ?? 'Mobile Money';
    final short = operator == 'Airtel' ? 'Airtel' : 'MTN';
    final theme = FlutterFlowTheme.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.primary),
              SizedBox(height: 16.0),
              Text(
                'Validez le paiement sur votre téléphone\n(saisissez votre code PIN $label)...',
                textAlign: TextAlign.center,
                style: theme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
    String title;
    String message;
    var paid = false;
    try {
      final r = await kitungaServerPay(
        sellerRef: _sellerRef!,
        zone: _model.zoneValue ?? '',
        deliveryLocation: _model.locationTextController.text,
        phone: phone,
        operator: operator,
      );
      switch (r.status) {
        case 'paid':
          paid = true;
          title = 'Commande confirmée';
          message =
              'Paiement de ${kitungaPrice(r.amount)} reçu. Le commerce prépare votre commande, suivez-la dans « Mes commandes ».';
        case 'paid_refund':
          title = 'Article plus disponible';
          message =
              'Votre paiement a été reçu, mais un article n\'est plus disponible${r.reason?.isNotEmpty == true ? ' :\n${r.reason}' : '.'}\nLe support Kitunga va vous rembourser (contact@ntemoconsulting.com).';
        case 'failed':
          title = 'Paiement refusé';
          message =
              '$short a refusé le paiement. Vérifiez votre solde puis réessayez.';
        default:
          title = 'Paiement en attente';
          message =
              'Nous n\'avons pas encore reçu la validation $short. Si vous avez validé, votre commande apparaîtra dans « Mes commandes » dans quelques minutes.';
      }
    } on ServerPaymentException catch (e) {
      title = 'Paiement impossible';
      message = e.message;
    }
    navigator.pop();
    if (!mounted) return;
    if (paid) {
      FFAppState().GrandTotalCart = 0.0;
      FFAppState().totalCart = 0.0;
      FFAppState().isSameOrder = false;
      FFAppState().orderReferenceUnique = '';
    }
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Ok')),
        ],
      ),
    );
    if (paid) router.pushNamed(HomeWidget.routeName);
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
