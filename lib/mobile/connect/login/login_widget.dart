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
    final fieldStyle =
        GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.secondaryBackground,
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              // Formulaire centré verticalement (défile si le clavier est ouvert).
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 450.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: 56.0),
                              Center(child: KitungaLogo(size: 140.0)),
                              SizedBox(height: 40.0),
                              TextFormField(
                                controller: _model.emailTextController,
                                focusNode: _model.emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: [AutofillHints.email],
                                style: fieldStyle,
                                decoration: kitungaInputDecoration(
                                    context,
                                    'Adresse e-mail',
                                    Icons.mail_outline_rounded),
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
                              SizedBox(height: 16.0),
                              TextFormField(
                                controller: _model.passwordTextController,
                                focusNode: _model.passwordFocusNode,
                                obscureText: !_model.passwordVisibility,
                                textInputAction: TextInputAction.done,
                                autofillHints: [AutofillHints.password],
                                onFieldSubmitted: (_) => _signIn(),
                                style: fieldStyle,
                                decoration: kitungaInputDecoration(
                                  context,
                                  'Mot de passe',
                                  Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    onPressed: () => safeSetState(() =>
                                        _model.passwordVisibility =
                                            !_model.passwordVisibility),
                                    icon: Icon(
                                      _model.passwordVisibility
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: theme.secondaryText,
                                      size: 22.0,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v ?? '').isEmpty
                                    ? 'Veuillez saisir votre mot de passe.'
                                    : null,
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: () => context.pushNamed(
                                      ForgotPasswordWidget.routeName),
                                  child: Text(
                                    'Mot de passe oublié ?',
                                    style: GoogleFonts.inter(
                                      color: theme.primary,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.0),
                              KitungaPrimaryButton(
                                text: 'Se connecter',
                                loading: _loading,
                                onPressed: _signIn,
                              ),
                              SizedBox(height: 16.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Pas encore de compte ?',
                                    style: GoogleFonts.inter(
                                        color: theme.secondaryText,
                                        fontSize: 14.0),
                                  ),
                                  TextButton(
                                    onPressed: () => context.pushNamed(
                                      SignWidget.routeName,
                                      queryParameters: {
                                        'accessibility': serializeParam(
                                            'User', ParamType.String),
                                      }.withoutNulls,
                                    ),
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
                              SizedBox(height: 24.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8.0,
                left: 16.0,
                child: IconButton(
                  onPressed: () => context.safePop(),
                  style: IconButton.styleFrom(
                      backgroundColor: theme.primaryBackground),
                  icon:
                      Icon(Icons.arrow_back_rounded, color: theme.primaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
