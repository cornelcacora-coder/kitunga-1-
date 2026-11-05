import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import '/mobile/components/kitunga_logo/kitunga_logo_widget.dart';
import '/mobile/components/form_styles/form_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        const SnackBar(
          content: Text(
              'Impossible d\'accéder en mode visiteur. Vérifiez votre connexion internet.'),
        ),
      );
    } finally {
      if (mounted) safeSetState(() => _visitorLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Arrière-plan signature (vagues rouges, cercles & filigrane) ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: KitungaAuthBackgroundPainter(isDark: isDark),
              ),
            ),
          ),

          // ── 2. Contenu principal centré ──────────────────────────────────
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440.0),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Kitunga
                      Center(
                        child: KitungaLogo(size: 115.0),
                      ),
                      const SizedBox(height: 18.0),

                      // Titre "Bienvenue sur" / "Kitunga"
                      Text(
                        'Bienvenue sur',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 26.0,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        'Kitunga',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.interTight(
                          color: const Color(0xFFE51A1A),
                          fontSize: 38.0,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // Séparateur ─── 🛍️ ───
                      const KitungaOrnamentDivider(),
                      const SizedBox(height: 12.0),

                      // Sous-titre
                      Text(
                        'Boutiques, restaurants et pharmacies\nprès de chez vous.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: theme.secondaryText,
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 28.0),

                      // Carte 1 : "J'ai déjà un compte"
                      Material(
                        color: isDark ? const Color(0xFF1E242B) : Colors.white,
                        borderRadius: BorderRadius.circular(24.0),
                        elevation: 0.0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24.0),
                          onTap: () => context.pushNamed(LoginWidget.routeName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24.0),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C3238) : const Color(0xFFF1F4F8),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0C000000),
                                  blurRadius: 14.0,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48.0,
                                  height: 48.0,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF331D1D) : const Color(0xFFFFECEC),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: Color(0xFFE51A1A),
                                    size: 24.0,
                                  ),
                                ),
                                const SizedBox(width: 14.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'J\'ai déjà un compte',
                                        style: GoogleFonts.interTight(
                                          color: theme.primaryText,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3.0),
                                      Text(
                                        'Connectez-vous pour continuer',
                                        style: GoogleFonts.inter(
                                          color: theme.secondaryText,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 34.0,
                                  height: 34.0,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE51A1A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white,
                                    size: 22.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14.0),

                      // Carte 2 : "Découvrir en visiteur"
                      Material(
                        color: isDark ? const Color(0xFF1E242B) : Colors.white,
                        borderRadius: BorderRadius.circular(24.0),
                        elevation: 0.0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24.0),
                          onTap: _continueAsVisitor,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24.0),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C3238) : const Color(0xFFF1F4F8),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0C000000),
                                  blurRadius: 14.0,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48.0,
                                  height: 48.0,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF222830) : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.explore_outlined,
                                    color: theme.primaryText,
                                    size: 24.0,
                                  ),
                                ),
                                const SizedBox(width: 14.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Découvrir en visiteur',
                                        style: GoogleFonts.interTight(
                                          color: theme.primaryText,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3.0),
                                      Text(
                                        'Parcourez sans compte',
                                        style: GoogleFonts.inter(
                                          color: theme.secondaryText,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _visitorLoading
                                    ? const SizedBox(
                                        width: 22.0,
                                        height: 22.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFFE51A1A),
                                        ),
                                      )
                                    : Icon(
                                        Icons.chevron_right_rounded,
                                        color: theme.secondaryText,
                                        size: 24.0,
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26.0),

                      // Séparateur ─── 🛍️ ───
                      const KitungaOrnamentDivider(),
                      const SizedBox(height: 14.0),

                      // "Pas encore de compte ?"
                      Text(
                        'Pas encore de compte ?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: theme.secondaryText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10.0),

                      // Bouton capsule "Créer un compte >"
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26.0),
                          onTap: () {
                            context.pushNamed(
                              SignWidget.routeName,
                              queryParameters: {
                                'accessibility': serializeParam('User', ParamType.String),
                              }.withoutNulls,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 13.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26.0),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE51A1A),
                                  Color(0xFFB70000),
                                ],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x35E51A1A),
                                  blurRadius: 12.0,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Créer un compte',
                                  style: GoogleFonts.interTight(
                                    color: Colors.white,
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 19.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18.0),

                      // Conditions d'utilisation
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
        ],
      ),
    );
  }
}
