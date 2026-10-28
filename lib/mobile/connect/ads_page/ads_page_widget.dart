import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'ads_page_model.dart';
export 'ads_page_model.dart';

/// The introducing page
class AdsPageWidget extends StatefulWidget {
  const AdsPageWidget({super.key});

  static String routeName = 'adsPage';
  static String routePath = '/adsPage';

  @override
  State<AdsPageWidget> createState() => _AdsPageWidgetState();
}

class _AdsPageWidgetState extends State<AdsPageWidget>
    with TickerProviderStateMixin {
  late AdsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdsPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(
        Duration(
          milliseconds: 4000,
        ),
      );
      if (!mounted) return;

      _goToIntro();
    });

    animationsMap.addAll({
      'imageOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 80.0.ms,
            duration: 2000.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'buttonOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 1120.0.ms,
            duration: 1520.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 2000.0.ms,
            duration: 1580.0.ms,
            begin: Offset(1.0, 1.0),
            end: Offset(1.0, 1.0),
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

  // Empêche d'ouvrir l'introduction deux fois (bouton « Passer » + minuteur).
  bool _leftAd = false;

  void _goToIntro() {
    if (_leftAd || !mounted) return;
    _leftAd = true;
    context.pushNamed(IntroWidget.routeName);
  }

  Widget _adLabel() => Container(
        padding: EdgeInsetsDirectional.fromSTEB(10.0, 4.0, 10.0, 4.0),
        decoration: BoxDecoration(
          color: Color(0x8A000000),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(
          'Publicité',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // Bouton « Passer » avec un anneau qui se remplit pendant la publicité.
  Widget _skipButton() => Material(
        color: Color(0x8A000000),
        shape: StadiumBorder(),
        child: InkWell(
          customBorder: StadiumBorder(),
          onTap: _goToIntro,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 12.0, 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Passer',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 10.0),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 4000),
                  builder: (context, value, _) => SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2.0,
                      color: Colors.white,
                      backgroundColor: Color(0x40FFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: MediaQuery.sizeOf(context).width < 500.0
            ? Colors.black
            : FlutterFlowTheme.of(context).primaryBackground,
        body: Builder(
          builder: (context) {
            if (MediaQuery.sizeOf(context).width < 500.0) {
              // Publicité plein écran, sous la barre d'état.
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/pub_model.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment(0.0, 0.0),
                  ).animateOnPageLoad(
                      animationsMap['imageOnPageLoadAnimation']!),
                  SafeArea(
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 0.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _adLabel(),
                          Spacer(),
                          _skipButton().animateOnPageLoad(
                              animationsMap['buttonOnPageLoadAnimation']!),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return SafeArea(
                top: true,
                child: Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Container(
                    width: 350.0,
                    height: 200.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
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
                              context.pushNamed(IntroWidget.routeName);
                            },
                            text: 'Démarrer',
                            options: FFButtonOptions(
                              width: double.infinity,
                              height: 40.0,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 0.0, 16.0, 0.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
