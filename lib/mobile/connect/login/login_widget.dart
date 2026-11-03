import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import '/mobile/components/form_styles/form_styles.dart';
import '/mobile/components/kitunga_logo/kitunga_logo_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'login_model.dart';
export 'login_model.dart';

/// Page d'inscription utilisateur
class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'Login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    _model.emailTextController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();

    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  Future _signIn() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    safeSetState(() => _loading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();

      final user = await authManager.signInWithEmail(
        context,
        _model.emailTextController.text.trim(),
        _model.passwordTextController.text,
      );
      if (user == null) {
        return;
      }

      await currentUserReference!.update(createUserRecordData(
        isLoggedIn: true,
      ));

      context.goNamedAuth(HomeWidget.routeName, context.mounted);
    } finally {
      if (mounted) safeSetState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldStyle = GoogleFonts.inter(
      color: theme.primaryText,
      fontSize: 15.0,
      fontWeight: FontWeight.w500,
    );

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Arrière-plan signature Kitunga (vagues rouges, cercles & filigrane) ──
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KitungaAuthBackgroundPainter(isDark: isDark),
                ),
              ),
            ),

            // ── 2. Formulaire de connexion ──────────────────────────────────
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440.0),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Bouton retour rond
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22.0),
                              onTap: () => context.safePop(),
                              child: Container(
                                width: 42.0,
                                height: 42.0,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E242B) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2C3238) : const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  size: 20.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),

                          // Logo Kitunga
                          Center(
                            child: KitungaLogo(size: 110.0),
                          ),
                          const SizedBox(height: 18.0),

                          // Titre
                          Text(
                            'Connexion',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.interTight(
                              color: theme.primaryText,
                              fontSize: 28.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12.0),

                          // Séparateur signature ─── 🛍️ ───
                          const KitungaOrnamentDivider(),
                          const SizedBox(height: 12.0),

                          // Sous-titre
                          Text(
                            'Connectez-vous pour commander et suivre vos achats.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: theme.secondaryText,
                              fontSize: 14.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28.0),

                          // Adresse e-mail
                          const KitungaFieldLabel('Adresse e-mail'),
                          TextFormField(
                            controller: _model.emailTextController,
                            focusNode: _model.emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: fieldStyle,
                            decoration: kitungaInputDecoration(
                              context,
                              'Adresse e-mail',
                              Icons.mail_outline_rounded,
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) {
                                return 'Veuillez saisir votre adresse e-mail.';
                              }
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(value)) {
                                return 'Adresse e-mail invalide.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),

                          // Mot de passe
                          const KitungaFieldLabel('Mot de passe'),
                          TextFormField(
                            controller: _model.passwordTextController,
                            focusNode: _model.passwordFocusNode,
                            obscureText: !_model.passwordVisibility,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _signIn(),
                            style: fieldStyle,
                            decoration: kitungaInputDecoration(
                              context,
                              'Mot de passe',
                              Icons.lock_outline_rounded,
                              suffix: IconButton(
                                splashRadius: 20.0,
                                onPressed: () => safeSetState(() =>
                                    _model.passwordVisibility =
                                        !_model.passwordVisibility),
                                icon: Icon(
                                  _model.passwordVisibility
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  size: 20.0,
                                ),
                              ),
                            ),
                            validator: (v) => (v ?? '').isEmpty
                                ? 'Veuillez saisir votre mot de passe.'
                                : null,
                          ),
                          const SizedBox(height: 8.0),

                          // Mot de passe oublié ?
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: GestureDetector(
                              onTap: () => context.pushNamed(
                                  ForgotPasswordWidget.routeName),
                              child: Text(
                                'Mot de passe oublié ?',
                                style: GoogleFonts.interTight(
                                  color: const Color(0xFFE51A1A),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // Bouton de connexion
                          KitungaPrimaryButton(
                            text: 'Se connecter',
                            loading: _loading,
                            onPressed: _signIn,
                          ),
                          const SizedBox(height: 20.0),

                          // Pas encore de compte ? Créer un compte
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
                              const SizedBox(width: 4.0),
                              GestureDetector(
                                onTap: () => context.pushNamed(
                                  SignWidget.routeName,
                                  queryParameters: {
                                    'accessibility': serializeParam(
                                        'User', ParamType.String),
                                  }.withoutNulls,
                                ),
                                child: Text(
                                  'Créer un compte',
                                  style: GoogleFonts.interTight(
                                    color: const Color(0xFFE51A1A),
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
