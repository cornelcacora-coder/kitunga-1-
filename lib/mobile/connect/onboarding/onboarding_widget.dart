import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/item/item_widget.dart';
import 'dart:ui';
import '/index.dart';
import '/mobile/components/kitunga_logo/kitunga_logo_widget.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'onboarding_model.dart';
export 'onboarding_model.dart';

class OnboardingWidget extends StatefulWidget {
  const OnboardingWidget({super.key});

  static String routeName = 'Onboarding';
  static String routePath = '/onboarding';

  @override
  State<OnboardingWidget> createState() => _OnboardingWidgetState();
}

class _OnboardingWidgetState extends State<OnboardingWidget> {
  late OnboardingModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OnboardingModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (MediaQuery.sizeOf(context).width > 1046.0) {
        context.pushNamed(IntroWidget.routeName);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  // Évite les doubles appuis pendant la connexion en mode visiteur.
  bool _visitorLoading = false;

  Future _continueAsVisitor() async {
    if (_visitorLoading) return;
    safeSetState(() => _visitorLoading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInAnonymously(context);
      if (user == null) {
        return;
      }

      if (currentUserReference != null) {
        await currentUserReference!.update(createUserRecordData(
          role: 'Guest',
        ));
      }

      context.pushNamedAuth(HomeWidget.routeName, context.mounted);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Impossible d\'accéder en mode visiteur. Vérifiez votre connexion internet.'),
        ),
      );
    } finally {
      if (mounted) safeSetState(() => _visitorLoading = false);
    }
  }

  Widget _choiceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Future Function() onTap,
    bool loading = false,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(18.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.0),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: theme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Icon(icon, color: color, size: 24.0),
              ),
              SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.interTight(
                        color: theme.primaryText,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.0),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: theme.secondaryText,
                        fontSize: 13.0,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.0),
              loading
                  ? SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.0, color: color),
                    )
                  : Icon(Icons.chevron_right_rounded,
                      color: theme.secondaryText, size: 24.0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        top: true,
        child: Align(
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 450.0,
            ),
            child: SingleChildScrollView(
              primary: false,
              padding: EdgeInsetsDirectional.fromSTEB(24.0, 32.0, 24.0, 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: KitungaLogo(size: 120.0),
                  ),
                  SizedBox(height: 28.0),
                  Text(
                    'Bienvenue sur Kitunga',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.interTight(
                      color: theme.primaryText,
                      fontSize: 28.0,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text(
                    'Boutiques, restaurants et pharmacies près de chez vous, livrés rapidement.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: theme.secondaryText,
                      fontSize: 15.0,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 40.0),
                  Text(
                    'Comment souhaitez-vous continuer ?',
                    style: GoogleFonts.inter(
                      color: theme.secondaryText,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.0),
                  _choiceCard(
                    icon: Icons.person_rounded,
                    color: theme.primary,
                    title: 'J\'ai déjà un compte',
                    subtitle: 'Connectez-vous pour commander et suivre vos achats',
                    onTap: () async {
                      context.pushNamed(LoginWidget.routeName);
                    },
                  ),
                  SizedBox(height: 12.0),
                  _choiceCard(
                    icon: Icons.explore_outlined,
                    color: theme.tertiary,
                    title: 'Découvrir en visiteur',
                    subtitle: 'Parcourez les boutiques sans créer de compte',
                    loading: _visitorLoading,
                    onTap: _continueAsVisitor,
                  ),
                  SizedBox(height: 28.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pas encore de compte ?',
                        style: GoogleFonts.inter(
                          color: theme.secondaryText,
                          fontSize: 14.0,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
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
                        child: Text(
                          'Créer un compte',
                          style: GoogleFonts.interTight(
                            color: theme.primary,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.0),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'En continuant, vous acceptez nos ',
                        style: GoogleFonts.inter(
                          color: theme.hint,
                          fontSize: 12.0,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            context.pushNamed(TermsConditionsWidget.routeName),
                        child: Text(
                          'conditions d\'utilisation',
                          style: GoogleFonts.inter(
                            color: theme.secondaryText,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        '.',
                        style: GoogleFonts.inter(
                          color: theme.hint,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
