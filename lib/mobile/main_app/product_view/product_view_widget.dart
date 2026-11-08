import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/subscription.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import 'dart:ui';
import '/flutter_flow/random_data_util.dart' as random_data;
import '/index.dart';
import '/mobile/components/product_options/customize_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'product_view_model.dart';
import '/mobile/components/form_styles/form_styles.dart';
export 'product_view_model.dart';

/// Page d'inscription utilisateur
class ProductViewWidget extends StatefulWidget {
  const ProductViewWidget({
    super.key,
    this.productRef,
    this.sellerRef,
    bool? isSameSeller,
  }) : this.isSameSeller = isSameSeller ?? false;

  final DocumentReference? productRef;
  final DocumentReference? sellerRef;
  final bool isSameSeller;

  static String routeName = 'ProductView';
  static String routePath = '/productView';

  @override
  State<ProductViewWidget> createState() => _ProductViewWidgetState();
}

class _ProductViewWidgetState extends State<ProductViewWidget> {
  late ProductViewModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProductViewModel());

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
        backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
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
              context.pop();
            },
          ),
          title: Text(
            'Produit',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
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
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: KitungaScaffoldBackground(
          child: SafeArea(
          top: true,
          child: Align(
            alignment: AlignmentDirectional(0.0, 0.0),
            child: Padding(
              padding: EdgeInsets.all(valueOrDefault<double>(
                MediaQuery.sizeOf(context).width > 760.0 ? 0.0 : 0.0,
                0.0,
              )),
              child: StreamBuilder<ProductRecord>(
                stream: ProductRecord.getDocument(widget!.productRef!),
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

                  final middleBodyProductRecord = snapshot.data!;

                  return Container(
                    width: MediaQuery.sizeOf(context).width < kBreakpointSmall
                        ? 400.0
                        : 500.0,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            scrollDirection: Axis.vertical,
                            children: [
                              Padding(
                                padding: EdgeInsets.all(10.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: KitungaImage(
                                    middleBodyProductRecord.prodImg,
                                    width: double.infinity,
                                    height: 302.0,
                                    fallbackIcon: Icons.image_outlined,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(14.0),
                                child: Container(
                                  width: 100.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Container(
                                            width: 40.0,
                                            height: 40.0,
                                            decoration: BoxDecoration(
                                              color: Color(0x22FFE500),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            child: Icon(
                                              Icons.sell_outlined,
                                              color: Color(0xFFB8A600),
                                              size: 24.0,
                                            ),
                                          ),
                                          Text(
                                            valueOrDefault<String>(
                                              middleBodyProductRecord.name,
                                              'Non disponible',
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            style: FlutterFlowTheme.of(context)
                                                .titleLarge
                                                .override(
                                                  font: GoogleFonts.interTight(
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleLarge
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  fontSize: 18.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleLarge
                                                          .fontStyle,
                                                ),
                                          ),
                                        ].divide(SizedBox(width: 14.0)),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            10.0, 10.0, 0.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      0.0, 0.0, 14.0, 0.0),
                                              child: Icon(
                                                Icons.diamond_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 28.0,
                                              ),
                                            ),
                                            Text(
                                              valueOrDefault<String>(
                                                middleBodyProductRecord
                                                    .salePrice
                                                    .toString(),
                                                '0',
                                              ),
                                              maxLines: 1,
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font:
                                                        GoogleFonts.montserrat(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    fontSize: 24.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                            Text(
                                              'F',
                                              maxLines: 1,
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font:
                                                        GoogleFonts.montserrat(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    fontSize: 24.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                            Flexible(
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    1.0, 0.0),
                                                child: Container(
                                                  width: 40.0,
                                                  height: 40.0,
                                                  decoration: BoxDecoration(
                                                    color: Color(0x22FF00E9),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment:
                                                      AlignmentDirectional(
                                                          1.0, 0.0),
                                                  child: Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            0.0, 0.0),
                                                    child: Icon(
                                                      Icons
                                                          .delivery_dining_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      size: 24.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Align(
                                              alignment: AlignmentDirectional(
                                                  1.0, 0.0),
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        10.0, 0.0, 0.0, 0.0),
                                                child: Container(
                                                  width: 40.0,
                                                  height: 40.0,
                                                  decoration: BoxDecoration(
                                                    color: Color(0x2200FFFD),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment:
                                                      AlignmentDirectional(
                                                          1.0, 0.0),
                                                  child: Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            0.0, 0.0),
                                                    child: Icon(
                                                      Icons.fastfood_sharp,
                                                      color: Color(0xFF00B5B8),
                                                      size: 24.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 10.0)),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    20.0, 10.0, 20.0, 0.0),
                                child: Container(
                                  width: 100.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 14.0),
                                    child: Text(
                                      valueOrDefault<String>(
                                        middleBodyProductRecord.description,
                                        'Le produit sélectionné n\'est pas disponible, veuillez sélectionné un autre  produit',
                                      ),
                                      textAlign: TextAlign.justify,
                                      maxLines: 4,
                                      style: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleLarge
                                                    .fontStyle,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              if (responsiveVisibility(
                                context: context,
                                phone: false,
                                tablet: false,
                                tabletLandscape: false,
                                desktop: false,
                              ))
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      20.0, 24.0, 0.0, 16.0),
                                  child: Text(
                                    'Colour',
                                    maxLines: 1,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                              if (responsiveVisibility(
                                context: context,
                                tablet: false,
                                tabletLandscape: false,
                                desktop: false,
                              ))
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      20.0, 0.0, 0.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 48.0,
                                        height: 48.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                        ),
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional(0.0, 0.0),
                                          child: Icon(
                                            Icons.loyalty_outlined,
                                            color: FlutterFlowTheme.of(context)
                                                .secondary,
                                            size: 24.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                width: 100.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quantité disponible',
                                      style: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .override(
                                            font: GoogleFonts.interTight(
                                              fontWeight: FontWeight.w800,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w800,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Align(
                                          alignment:
                                              AlignmentDirectional(1.0, 0.0),
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 10.0, 0.0),
                                            child: Container(
                                              width: 40.0,
                                              height: 40.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: AlignmentDirectional(
                                                  1.0, 0.0),
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Icon(
                                                  Icons
                                                      .production_quantity_limits_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  size: 24.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          valueOrDefault<String>(
                                            middleBodyProductRecord.quantity
                                                .toString(),
                                            '0',
                                          ),
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.montserrat(
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 24.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                        Flexible(
                                          child: Align(
                                            alignment:
                                                AlignmentDirectional(1.0, 0.0),
                                            child: Container(
                                              width: 48.0,
                                              height: 48.0,
                                              decoration: BoxDecoration(
                                                color: Color(0xFF806681),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                child: Image.asset(
                                                  'assets/images/Vector_(11).png',
                                                  width: 16.0,
                                                  height: 12.0,
                                                  fit: BoxFit.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Préparation du produit',
                                      style: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .override(
                                            font: GoogleFonts.interTight(
                                              fontWeight: FontWeight.w800,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w800,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .divider,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16.0),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Icon(
                                                      Icons.speed_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .success,
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Expédition express',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
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
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Text(
                                                        'Instantannée',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Icon(
                                                    Icons.check_circle,
                                                    color:
                                                        valueOrDefault<Color>(
                                                      middleBodyProductRecord
                                                              .instantDisponibilty
                                                          ? FlutterFlowTheme.of(
                                                                  context)
                                                              .primary
                                                          : FlutterFlowTheme.of(
                                                                  context)
                                                              .hint,
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .hint,
                                                    ),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 16.0)),
                                            ),
                                          ].divide(SizedBox(height: 8.0)),
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(height: 16.0)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              20.0, 10.0, 20.0, 10.0),
                          child: Container(
                            width: double.infinity,
                            height: 60.0,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                            ),
                            child: Visibility(
                              visible: valueOrDefault(
                                      currentUserDocument?.role, '') !=
                                  'Seller',
                              child: AuthUserStreamWidget(
                                builder: (context) => FFButtonWidget(
                                  onPressed: () async {
                                    // Médicament sur ordonnance : non commandable en ligne pour
                                    // l'instant (règles de délivrance à valider).
                                    if (middleBodyProductRecord.requiresPrescription) {
                                      await showDialog(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: Text('Médicament sur ordonnance'),
                                          content: Text(
                                              'Ce médicament nécessite une ordonnance. Il ne peut pas être commandé en ligne pour le moment : rendez-vous directement à la pharmacie avec votre ordonnance.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogContext),
                                              child: Text('Compris'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    // Client abonné (ou commerçant, livreur…) : il peut commander.
                                    if (kitungaCanOrder()) {
                                      // Produit épuisé : pas d'ajout au panier.
                                      if (middleBodyProductRecord.quantity <= 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text('Ce produit est actuellement en rupture de stock.')));
                                        return;
                                      }
                                      // Options, suppléments, variantes : choix du client et prix final.
                                      var unitPrice = middleBodyProductRecord.salePrice > 0
                                          ? middleBodyProductRecord.salePrice
                                          : middleBodyProductRecord.price.round();
                                      var chosenQuantity = 1;
                                      var chosenOptions = '';
                                      if (middleBodyProductRecord.options.isNotEmpty) {
                                        final custom = await showKitungaCustomizeSheet(
                                            context, middleBodyProductRecord);
                                        if (custom == null) return;
                                        unitPrice = custom.unitPrice;
                                        chosenQuantity = custom.quantity;
                                        chosenOptions = custom.summary;
                                      }
                                      // ── Vérification doublon panier ────────────────────────────────
                                      // Si le même produit (même options) est déjà dans un panier
                                      // actif et non commandé, on incrémente la quantité.
                                      final existingCarts = await queryCartRecordOnce(
                                        queryBuilder: (q) => q
                                            .where('user_ref', isEqualTo: currentUserReference)
                                            .where('product_ref', isEqualTo: widget.productRef)
                                            .where('is_ordered', isEqualTo: false)
                                            .where('is_active', isEqualTo: true),
                                      );
                                      final duplicate = existingCarts.where((c) =>
                                          c.options == chosenOptions).firstOrNull;
                                      if (duplicate != null) {
                                        // Incrémenter la quantité existante.
                                        await duplicate.reference.update({
                                          'quantity': duplicate.quantity + chosenQuantity,
                                          // Prix unitaire : le sous-total du panier
                                          // le multiplie déjà par la quantité.
                                          'price': unitPrice.toDouble(),
                                        });
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: const Text(
                                              'Quantité mise à jour dans votre panier.'),
                                        ));
                                        context.pushNamed(
                                          CartLastWidget.routeName,
                                          queryParameters: {
                                            'sellerRef': serializeParam(
                                              middleBodyProductRecord.sellerRef,
                                              ParamType.DocumentReference,
                                            ),
                                          }.withoutNulls,
                                        );
                                        return;
                                      }
                                      // ── Nouveau article dans le panier ─────────────────────────────
                                      var cartRecordReference =
                                          CartRecord.collection.doc();
                                      await cartRecordReference
                                          .set(createCartRecordData(

                                        productRef: widget!.productRef,
                                        userRef: currentUserReference,
                                        quantity: chosenQuantity,
                                        createdAt: getCurrentTimestamp,
                                        price: unitPrice.toDouble(),
                                        options: chosenOptions,
                                        productName:
                                            middleBodyProductRecord.name,
                                        isActive: true,
                                        isOrdered: false,
                                        clearCartValue: 'Not Empty',
                                        sellerRef: widget!.sellerRef,
                                      ));
                                      _model.nouveauPanierRef =
                                          CartRecord.getDocumentFromData(
                                              createCartRecordData(
                                                productRef: widget!.productRef,
                                                userRef: currentUserReference,
                                                quantity: chosenQuantity,
                                                createdAt: getCurrentTimestamp,
                                                price: unitPrice.toDouble(),
                                                options: chosenOptions,
                                                productName:
                                                    middleBodyProductRecord
                                                        .name,
                                                isActive: true,
                                                isOrdered: false,
                                                clearCartValue: 'Not Empty',
                                                sellerRef: widget!.sellerRef,
                                              ),
                                              cartRecordReference);
                                      if (FFAppState().isSameOrder != true) {
                                        // Identifiant de commande unique et robuste :
                                        // timestamp ms + suffixe alphanumérique aléatoire.
                                        final ts = DateTime.now().millisecondsSinceEpoch;
                                        final suffix = random_data.randomString(6, 6, true, true, false);
                                        FFAppState().orderReferenceUnique =
                                            'ORD-$ts-$suffix';
                                        safeSetState(() {});
                                      }

                                      var orderItemsRecordReference =
                                          OrderItemsRecord.collection.doc();
                                      await orderItemsRecordReference
                                          .set(createOrderItemsRecordData(
                                        itemName: middleBodyProductRecord.name,
                                        priceAtPurchase: unitPrice.toDouble(),
                                        quantity: chosenQuantity,
                                        image: middleBodyProductRecord.prodImg,
                                        options: chosenOptions,
                                        cartRef:
                                            _model.nouveauPanierRef?.reference,
                                        userRef: currentUserReference,
                                        productRef:
                                            middleBodyProductRecord.reference,
                                        orderRef:
                                            FFAppState().orderReferenceUnique,
                                      ));
                                      _model.nouveauOrderitems =
                                          OrderItemsRecord.getDocumentFromData(
                                              createOrderItemsRecordData(
                                        itemName: middleBodyProductRecord.name,
                                        priceAtPurchase: unitPrice.toDouble(),
                                        quantity: chosenQuantity,
                                        image: middleBodyProductRecord.prodImg,
                                        options: chosenOptions,
                                        cartRef: _model.nouveauPanierRef
                                                    ?.reference,
                                                userRef: currentUserReference,
                                                productRef:
                                                    middleBodyProductRecord
                                                        .reference,
                                                orderRef: FFAppState()
                                                    .orderReferenceUnique,
                                              ),
                                              orderItemsRecordReference);
                                      FFAppState().valueToClear = 'Not Empty';
                                      FFAppState().addToCartitems(
                                          _model.nouveauPanierRef!.reference);
                                      safeSetState(() {});

                                      context.pushNamed(
                                        CartLastWidget.routeName,
                                        queryParameters: {
                                          'sellerRef': serializeParam(
                                            middleBodyProductRecord.sellerRef,
                                            ParamType.DocumentReference,
                                          ),
                                          'cartRef': serializeParam(
                                            _model.nouveauPanierRef,
                                            ParamType.Document,
                                          ),
                                          'orderitem': serializeParam(
                                            _model.nouveauOrderitems?.reference,
                                            ParamType.DocumentReference,
                                          ),
                                        }.withoutNulls,
                                        extra: <String, dynamic>{
                                          'cartRef': _model.nouveauPanierRef,
                                        },
                                      );
                                    } else if (currentUserReference != null &&
                                        valueOrDefault(
                                                currentUserDocument?.role, '') !=
                                            'Guest') {
                                      // Client connecté sans abonnement actif.
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
                                          ],
                                        ),
                                      );
                                    } else {
                                      await showModalBottomSheet(
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        enableDrag: false,
                                        context: context,
                                        builder: (context) {
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EmptyCardWidget(
                                                photo:
                                                    'assets/images/app/illustration_ou1qzr.png',
                                                title:
                                                    'Créez votre compte',
                                                description:
                                                    'Créez votre compte Kitunga pour commander et suivre vos livraisons.',
                                                buttonText: 'Créer un compte',
                                                action: () async {
                                                  Navigator.pop(context);
                                                  context.pushNamed(
                                                    SignWidget.routeName,
                                                    queryParameters: {
                                                      'accessibility':
                                                          serializeParam(
                                                              'User',
                                                              ParamType.String),
                                                    }.withoutNulls,
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    }

                                    safeSetState(() {});
                                  },
                                  text: 'Ajouter au panier',
                                  options: FFButtonOptions(
                                    width: double.infinity,
                                    height: 56.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: FlutterFlowTheme.of(context).primary,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          color: Colors.white,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                    elevation: 1.0,
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  showLoadingIndicator: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
