import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/backend/order_status.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/shop_card_vertical_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/alert_info/alert_info_widget.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import '/mobile/components/info_badge/info_badge_widget.dart';
import '/mobile/components/my_products_card/my_products_card_widget.dart';
import '/mobile/components/my_seller_card/my_seller_card_widget.dart';
import '/mobile/components/user_card/user_card_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import '/backend/kitunga_categories.dart' show kitungaShopIsActive;
import '/mobile/deliverer/kitunga_deliverer_home.dart' show KitungaDelivererHome;
import '/mobile/seller/kitunga_seller_home.dart' show KitungaSellerHome;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/mobile/components/app_drawer/app_drawer_widget.dart';
import '/mobile/components/kitunga_logo/kitunga_logo_widget.dart';
import 'buyer_home_view.dart';
import 'home_model.dart';
import '/mobile/components/form_styles/form_styles.dart';
export 'home_model.dart';

/// Page d'inscription utilisateur
class HomeWidget extends StatefulWidget {
  const HomeWidget({
    super.key,
    this.deliveryProof,
  });

  final String? deliveryProof;

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin {
  late HomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  LatLng? currentUserLocationValue;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());

    getCurrentUserLocation(defaultLocation: LatLng(0.0, 0.0), cached: true)
        .then((loc) => safeSetState(() => currentUserLocationValue = loc));
    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserLocationValue == null) {
      return Container(
        color: FlutterFlowTheme.of(context).primaryBackground,
        child: Center(
          child: SizedBox(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                FlutterFlowTheme.of(context).primary,
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<UserRecord>>(
      stream: queryUserRecord(
        queryBuilder: (userRecord) => userRecord.where(
          'role',
          isEqualTo: 'Seller',
        ),
      ),
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ),
            ),
          );
        }
        // Commerces désactivés par l'admin : masqués.
        List<UserRecord> homeUserRecordList =
            snapshot.data!.where(kitungaShopIsActive).toList();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
            drawer: AppDrawerWidget(),
            // Vendeur et livreur : l'en-tête est dans leur accueil.
            appBar: null,
            body: KitungaScaffoldBackground(
              child: SafeArea(
              top: false,
              child: Stack(
                alignment: AlignmentDirectional(1.0, 1.0),
                children: [
                  Builder(
                    builder: (context) {
                      if (valueOrDefault(currentUserDocument?.role, '') ==
                          'User') {
                        return BuyerHomeView(
                          sellers: homeUserRecordList,
                          onOpenDrawer: () =>
                              scaffoldKey.currentState?.openDrawer(),
                        );
                      } else if (valueOrDefault(
                              currentUserDocument?.role, '') ==
                          'Seller') {
                        // Accueil du vendeur : centre de pilotage du commerce.
                        return const KitungaSellerHome();
                      } else if (valueOrDefault(
                              currentUserDocument?.role, '') ==
                          'Deliver') {
                        // Accueil du livreur : outil de travail de la journée.
                        return const KitungaDelivererHome();
                      } else if (valueOrDefault(
                              currentUserDocument?.role, '') ==
                          'Admin') {
                        return Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            KitungaLogo(size: 150.0),
                            Align(
                              alignment: AlignmentDirectional(0.0, 0.0),
                              child: Container(
                                width: 350.0,
                                height: 200.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).accent3,
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FFButtonWidget(
                                        onPressed: () async {
                                          context.pushNamed(
                                              AdminDashboardWidget.routeName);
                                        },
                                        text: 'Démarrer',
                                        options: FFButtonOptions(
                                          width: double.infinity,
                                          height: 40.0,
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          iconPadding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 0.0),
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          textStyle: FlutterFlowTheme.of(
                                                  context)
                                              .titleSmall
                                              .override(
                                                font: GoogleFonts.interTight(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleSmall
                                                          .fontStyle,
                                                ),
                                                color: Colors.white,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontStyle,
                                              ),
                                          elevation: 0.0,
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ].divide(SizedBox(height: 10.0)),
                        );
                      } else {
                        return BuyerHomeView(
                          sellers: homeUserRecordList,
                          onOpenDrawer: () =>
                              scaffoldKey.currentState?.openDrawer(),
                        );
                      }
                    },
                  ),
                  // Vendeur : « Ajouter un produit » est dans son accueil.

                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}