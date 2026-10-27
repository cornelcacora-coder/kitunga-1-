import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/ads_comp/ads_comp_widget.dart';
import '/mobile/components/alert_info/alert_info_widget.dart';
import '/mobile/components/user_card/user_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'shops_model.dart';
export 'shops_model.dart';

/// Page d'inscription utilisateur
class ShopsWidget extends StatefulWidget {
  const ShopsWidget({
    super.key,
    this.tag,
  });

  final String? tag;

  static String routeName = 'Shops';
  static String routePath = '/shops';

  @override
  State<ShopsWidget> createState() => _ShopsWidgetState();
}

class _ShopsWidgetState extends State<ShopsWidget> {
  late ShopsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ShopsModel());

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
          title: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  context.safePop();
                },
                child: Icon(
                  Icons.arrow_back,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(14.0, 1.0, 14.0, 10.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Align(
                      alignment: AlignmentDirectional(1.0, 0.0),
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 0.0, 0.0),
                        child: Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: Color(0x2200FFFD),
                            shape: BoxShape.circle,
                          ),
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: Icon(
                              Icons.store_rounded,
                              color: Color(0xFF00B5B8),
                              size: 24.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      valueOrDefault<String>(
                        widget!.tag,
                        'Boutique',
                      ),
                      style:
                          FlutterFlowTheme.of(context).headlineMedium.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                                fontSize: 20.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                              ),
                    ),
                  ].divide(SizedBox(width: 10.0)),
                ),
              ),
            ],
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (responsiveVisibility(
                          context: context,
                          phone: false,
                        ))
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            child: wrapWithModel(
                              model: _model.adsCompModel,
                              updateCallback: () => safeSetState(() {}),
                              child: AdsCompWidget(
                                title: () {
                                  if (widget!.tag == 'Boutique') {
                                    return 'Kitunga Shop';
                                  } else if (widget!.tag == 'Magasin') {
                                    return 'Kitunga Magasin ';
                                  } else if (widget!.tag == 'Pharmacie') {
                                    return 'Kitunga Pharmacy';
                                  } else {
                                    return 'Kitunga Store';
                                  }
                                }(),
                                subtitle: () {
                                  if (widget!.tag == 'Boutique') {
                                    return 'Accédez aux meileures boutqiues de la place.';
                                  } else if (widget!.tag == 'Magasin') {
                                    return 'Visitez vos magasins préférés maintenant ';
                                  } else if (widget!.tag == 'Pharmacie') {
                                    return 'Retrouver tous vos produits dans la pharmacie la plus proche de chez vous';
                                  } else {
                                    return 'Tout ce dont vous avez besoin au meme endroit et en un click. ';
                                  }
                                }(),
                                tag: widget!.tag,
                                btnText: 'Live',
                                cover: () {
                                  if (widget!.tag == 'Magasin') {
                                    return 'https://dimg.dreamflow.cloud/v1/image/modern minimalist boutique storefront interior high-end fashion';
                                  } else if (widget!.tag == 'Pharmacie') {
                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/x17wknlm8k4f/PharmaciModel_(1).png';
                                  } else if (widget!.tag == 'Boutique') {
                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/01y62vfcxq6g/AdsModel_(1).png';
                                  } else if (widget!.tag == 'Restaurant') {
                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/yaerg0wuc2fl/RestoModel_(1).png';
                                  } else if (widget!.tag == 'Fast Food') {
                                    return 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/yaerg0wuc2fl/RestoModel_(1).png';
                                  } else {
                                    return 'https://dimg.dreamflow.cloud/v1/image/modern minimalist boutique storefront interior high-end fashion';
                                  }
                                }(),
                                onclickBtn: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (alertDialogContext) {
                                      return AlertDialog(
                                        title: Text('À venir'),
                                        content: Text(
                                            'Les portes vont bientot s\'ouvrire, revenez plutard svp !'),
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
                                },
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              20.0, 0.0, 20.0, 0.0),
                          child: Material(
                            color: Colors.transparent,
                            elevation: 0.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Container(
                              width: double.infinity,
                              height: 80.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).accent3,
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(14.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          () {
                                            if (widget!.tag == 'Boutique') {
                                              return 'Kitunga Shop';
                                            } else if (widget!.tag ==
                                                'Magasin') {
                                              return 'Kitunga Magasin ';
                                            } else if (widget!.tag ==
                                                'Pharmacie') {
                                              return 'Kitunga Pharmacy';
                                            } else if (widget!.tag ==
                                                'Fast Food') {
                                              return 'Kitunga Food';
                                            } else {
                                              return 'Kitunga Store';
                                            }
                                          }(),
                                          style: FlutterFlowTheme.of(context)
                                              .titleMedium
                                              .override(
                                                font: GoogleFonts.interTight(
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
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 17.0,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                        Text(
                                          () {
                                            if (widget!.tag == 'Boutique') {
                                              return 'Accédez aux meileures boutqiues de la place.';
                                            } else if (widget!.tag ==
                                                'Magasin') {
                                              return 'Visitez vos magasins préférés maintenant ';
                                            } else if (widget!.tag ==
                                                'Pharmacie') {
                                              return 'Vos produits dans la pharmacie la plus proche ';
                                            } else {
                                              return 'Tout ce dont vous avez besoin en 1  seul endroit';
                                            }
                                          }(),
                                          maxLines: 2,
                                          style: FlutterFlowTheme.of(context)
                                              .labelLarge
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelLarge
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelLarge
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 14.0,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelLarge
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelLarge
                                                        .fontStyle,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ].divide(SizedBox(width: 14.0)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(20.0),
                          child: StreamBuilder<List<UserRecord>>(
                            stream: queryUserRecord(
                              queryBuilder: (userRecord) => userRecord
                                  .where(
                                    'role',
                                    isEqualTo: 'Seller',
                                  )
                                  .where(
                                    'category',
                                    isEqualTo: widget!.tag,
                                  )
                                  .orderBy('created_time'),
                              limit: 20,
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
                              List<UserRecord> wrapUserRecordList =
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
                                children: List.generate(
                                    wrapUserRecordList.length, (wrapIndex) {
                                  final wrapUserRecord =
                                      wrapUserRecordList[wrapIndex];
                                  return Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 10.0),
                                    child: wrapWithModel(
                                      model: _model.userCardModels.getModel(
                                        wrapUserRecord.reference.id,
                                        wrapIndex,
                                      ),
                                      updateCallback: () => safeSetState(() {}),
                                      child: UserCardWidget(
                                        key: Key(
                                          'Keyj18_${wrapUserRecord.reference.id}',
                                        ),
                                        name: wrapUserRecord.displayName,
                                        badge: valueOrDefault<String>(
                                          () {
                                            if (wrapUserRecord.role ==
                                                'Seller') {
                                              return 'VENDEUR';
                                            } else if (wrapUserRecord.role ==
                                                'Deliver') {
                                              return 'LIVREUR';
                                            } else if (wrapUserRecord.role ==
                                                'Admin') {
                                              return 'ADMIN';
                                            } else {
                                              return 'USER';
                                            }
                                          }(),
                                          'USER',
                                        ),
                                        badgeBg: valueOrDefault<Color>(
                                          () {
                                            if (wrapUserRecord.role == 'User') {
                                              return Color(0x22FFE500);
                                            } else if (wrapUserRecord.role ==
                                                'Deliver') {
                                              return FlutterFlowTheme.of(
                                                      context)
                                                  .accent3;
                                            } else if (wrapUserRecord.role ==
                                                'Admin') {
                                              return FlutterFlowTheme.of(
                                                      context)
                                                  .accent1;
                                            } else {
                                              return FlutterFlowTheme.of(
                                                      context)
                                                  .accent2;
                                            }
                                          }(),
                                          Color(0x22FFE500),
                                        ),
                                        createdAt: wrapUserRecord.createdTime,
                                        userImg: valueOrDefault<String>(
                                          wrapUserRecord.photoUrl,
                                          'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/h5ta1mt8rram/UserIcon.png',
                                        ),
                                        isVerified: wrapUserRecord.verified,
                                        isUserConnected: true,
                                        iconCard: Icon(
                                          Icons.arrow_forward_ios,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 16.0,
                                        ),
                                        actionToUser: () async {},
                                        viewUser: () async {
                                          if (valueOrDefault(
                                                  currentUserDocument?.role,
                                                  '') ==
                                              'Guest') {
                                            await showModalBottomSheet(
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              enableDrag: false,
                                              context: context,
                                              builder: (context) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        MediaQuery.viewInsetsOf(
                                                            context),
                                                    child: AlertInfoWidget(
                                                      icon: Icon(
                                                        Icons.crisis_alert,
                                                        color: Colors.white,
                                                      ),
                                                      title: 'Accès Refusé !',
                                                      iconBg:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondary,
                                                      subtitle:
                                                          'Veuillez vous abonnez afin d\'accéder à toutes les fonctionalités de Kitunga sans limitation.',
                                                      btnTxt: 'S\'abonner',
                                                      onValidate: () async {
                                                        Navigator.of(context).pop();
                                                        context.pushNamed(
                                                          SignWidget.routeName,
                                                          queryParameters: {
                                                            'accessibility':
                                                                serializeParam(
                                                              'User',
                                                              ParamType.String,
                                                            ),
                                                          }.withoutNulls,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                );
                                              },
                                            ).then(
                                                (value) => safeSetState(() {}));
                                          } else {
                                            context.pushNamed(
                                              ShopDetailPageWidget.routeName,
                                              queryParameters: {
                                                'userRef': serializeParam(
                                                  wrapUserRecord.reference,
                                                  ParamType.DocumentReference,
                                                ),
                                                'isSameSeller': serializeParam(
                                                  false,
                                                  ParamType.bool,
                                                ),
                                              }.withoutNulls,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ]
                          .divide(SizedBox(height: 16.0))
                          .addToStart(SizedBox(height: 0.0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}