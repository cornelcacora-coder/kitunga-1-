import '/backend/server_payment.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/index.dart';
import '/mobile/components/kitunga_logo/kitunga_logo_widget.dart';
import '/mobile/components/form_styles/form_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'sign_model.dart';
import '/backend/acquisition.dart';
export 'sign_model.dart';

/// Page d'inscription utilisateur
class SignWidget extends StatefulWidget {
  const SignWidget({
    super.key,
    required this.accessibility,
  });

  /// User category profile
  final String? accessibility;

  static String routeName = 'Sign';
  static String routePath = '/sign';

  @override
  State<SignWidget> createState() => _SignWidgetState();
}

class _SignWidgetState extends State<SignWidget> {
  late SignModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Code commercial : prérempli et verrouillé s'il a été reçu à l'installation.
  final _referralCodeController = TextEditingController();
  bool _referralCodeLocked = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SignModel());
    KitungaAcquisition.savedCode().then((code) {
      if (code == null || !mounted) return;
      safeSetState(() {
        _referralCodeController.text = code;
        _referralCodeLocked = true;
      });
    });

    _model.businessNameTextController ??= TextEditingController();
    _model.businessNameFocusNode ??= FocusNode();

    _model.emailBusinessTextController ??= TextEditingController();
    _model.emailBusinessFocusNode ??= FocusNode();

    _model.phoneBusinessTextController ??= TextEditingController();
    _model.phoneBusinessFocusNode ??= FocusNode();

    _model.bioTextController ??= TextEditingController();
    _model.bioFocusNode ??= FocusNode();

    _model.horraireTextController ??= TextEditingController();
    _model.horraireFocusNode ??= FocusNode();

    _model.pwdBusinessTextController ??= TextEditingController();
    _model.pwdBusinessFocusNode ??= FocusNode();

    _model.confPwdBusinessTextController ??= TextEditingController();
    _model.confPwdBusinessFocusNode ??= FocusNode();

    _model.displayNameTextController ??= TextEditingController();
    _model.displayNameFocusNode ??= FocusNode();

    _model.emailUserTextController ??= TextEditingController();
    _model.emailUserFocusNode ??= FocusNode();

    _model.phoneUserTextController ??= TextEditingController();
    _model.phoneUserFocusNode ??= FocusNode();

    _model.passwordUserTextController ??= TextEditingController();
    _model.passwordUserFocusNode ??= FocusNode();

    _model.confirmPasswordUserTextController ??= TextEditingController();
    _model.confirmPasswordUserFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    _model.dispose();

    super.dispose();
  }

  final _userFormKey = GlobalKey<FormState>();
  bool _signingUp = false;

  static const _plans = [
    'Mensuel - 250F',
    'Trimestriel - 500 F',
    'Annuel - 1000 F',
  ];

  Future _signUpUser() async {
    if (_signingUp) return;
    if (!(_userFormKey.currentState?.validate() ?? false)) return;
    safeSetState(() => _signingUp = true);
    try {
      GoRouter.of(context).prepareAuthEvent();

      final user = await authManager.createAccountWithEmail(
        context,
        _model.emailUserTextController.text.trim(),
        _model.passwordUserTextController.text,
      );
      if (user == null) {
        return;
      }

      await UserRecord.collection.doc(user.uid).set(createUserRecordData(
            createdTime: getCurrentTimestamp,
            role: 'User',
            email: _model.emailUserTextController.text.trim(),
            displayName: _model.displayNameTextController.text.trim(),
            phoneNumber: _model.phoneUserTextController.text.trim(),
            category: 'User',
            verified: _model.certifiedValue,
            bio:
                'Je suis content d\'utiliser Kitunga comme App pour mes achats au quotidien',
            horraire: _model.horraireTextController.text,
            // Abonnement activé par le serveur après paiement MoMo.
            isSubscribed: false,
            subscribeType: _model.subscribTypeUserValue,
          ));

      // Module commercial : attribution au commercial (sans attendre).
      final referralCode = _referralCodeController.text.trim();
      if (referralCode.isNotEmpty && !_referralCodeLocked) {
        await KitungaAcquisition.rememberManualCode(referralCode);
      }
      KitungaAcquisition.syncNow();

      await showDialog(
        context: context,
        builder: (alertDialogContext) {
          return AlertDialog(
            title: Text('Bienvenue sur Kitunga !'),
            content: Text('Votre compte a été créé avec succès.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(alertDialogContext),
                child: Text('Continuer'),
              ),
            ],
          );
        },
      );

      context.pushNamedAuth(
        AddProfileWidget.routeName,
        context.mounted,
        queryParameters: {
          'role': serializeParam(
            valueOrDefault(currentUserDocument?.role, ''),
            ParamType.String,
          ),
        }.withoutNulls,
      );
    } finally {
      if (mounted) safeSetState(() => _signingUp = false);
    }
  }

  Widget _passwordToggle(bool visible, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onTap,
      splashRadius: 20.0,
      icon: Icon(
        visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        size: 20.0,
      ),
    );
  }

  /// Formulaire « Créer un compte » des clients.
  Widget _buildUserSignUp(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldStyle = GoogleFonts.inter(
      color: theme.primaryText,
      fontSize: 15.0,
      fontWeight: FontWeight.w500,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _userFormKey,
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
                  'Créer un compte',
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
                  'Rejoignez Kitunga et commandez auprès des commerces près de chez vous.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: theme.secondaryText,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 26.0),

                // Nom complet
                const KitungaFieldLabel('Nom complet'),
                TextFormField(
                  controller: _model.displayNameTextController,
                  focusNode: _model.displayNameFocusNode,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  style: fieldStyle,
                  decoration: kitungaInputDecoration(
                    context,
                    'Ex : Jean Mabiala',
                    Icons.person_outline_rounded,
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Veuillez saisir votre nom.'
                      : null,
                ),
                const SizedBox(height: 16.0),

                // Adresse e-mail
                const KitungaFieldLabel('Adresse e-mail'),
                TextFormField(
                  controller: _model.emailUserTextController,
                  focusNode: _model.emailUserFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  style: fieldStyle,
                  decoration: kitungaInputDecoration(
                    context,
                    'exemple@email.com',
                    Icons.mail_outline_rounded,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) {
                      return 'Veuillez saisir votre adresse e-mail.';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                      return 'Adresse e-mail invalide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // Téléphone
                const KitungaFieldLabel('Téléphone'),
                TextFormField(
                  controller: _model.phoneUserTextController,
                  focusNode: _model.phoneUserFocusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  style: fieldStyle,
                  decoration: kitungaInputDecoration(
                    context,
                    '06 XXX XX XX',
                    Icons.phone_outlined,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Code commercial (module commercial), facultatif
                const KitungaFieldLabel('Code commercial (facultatif)'),
                TextFormField(
                  controller: _referralCodeController,
                  readOnly: _referralCodeLocked,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  style: fieldStyle,
                  decoration: kitungaInputDecoration(
                    context,
                    'Ex. KTG001-X7P9',
                    Icons.badge_outlined,
                  ).copyWith(
                    helperText: _referralCodeLocked
                        ? 'Code reçu à l\'installation de l\'application.'
                        : 'Donné par le commercial qui vous a présenté Kitunga.',
                  ),
                  validator: (value) {
                    final code = (value ?? '').trim();
                    if (code.isEmpty ||
                        KitungaAcquisition.isValidCode(code)) {
                      return null;
                    }
                    return 'Code invalide (exemple : KTG001-X7P9).';
                  },
                ),
                const SizedBox(height: 16.0),

                // Formule d'abonnement
                const KitungaFieldLabel('Formule d\'abonnement'),
                DropdownButtonFormField<String>(
                  initialValue: _model.subscribTypeUserValue,
                  items: _plans
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p, style: fieldStyle),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      safeSetState(() => _model.subscribTypeUserValue = v),
                  dropdownColor: isDark ? const Color(0xFF1E242B) : Colors.white,
                  borderRadius: BorderRadius.circular(22.0),
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  decoration: kitungaInputDecoration(
                    context,
                    'Choisissez votre formule',
                    Icons.workspace_premium_outlined,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Mot de passe
                const KitungaFieldLabel('Mot de passe'),
                TextFormField(
                  controller: _model.passwordUserTextController,
                  focusNode: _model.passwordUserFocusNode,
                  obscureText: !_model.passwordUserVisibility,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  style: fieldStyle,
                  decoration: kitungaInputDecoration(
                    context,
                    '6 caractères minimum',
                    Icons.lock_outline_rounded,
                    suffix: _passwordToggle(
                      _model.passwordUserVisibility,
                      () => safeSetState(() => _model.passwordUserVisibility =
                          !_model.passwordUserVisibility),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < 6
                      ? 'Le mot de passe doit comporter au moins 6 caractères.'
                      : null,
                ),
                const SizedBox(height: 16.0),

                // Confirmer le mot de passe
                const KitungaFieldLabel('Confirmer le mot de passe'),
                TextFormField(
                  controller: _model.confirmPasswordUserTextController,
                  focusNode: _model.confirmPasswordUserFocusNode,
                  obscureText: !_model.confirmPasswordUserVisibility,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signUpUser(),
                  style: fieldStyle,
                  decoration: kitungaInputDecoration(
                    context,
                    'Saisissez-le à nouveau',
                    Icons.lock_outline_rounded,
                    suffix: _passwordToggle(
                      _model.confirmPasswordUserVisibility,
                      () => safeSetState(() =>
                          _model.confirmPasswordUserVisibility =
                              !_model.confirmPasswordUserVisibility),
                    ),
                  ),
                  validator: (v) => v != _model.passwordUserTextController.text
                      ? 'Les mots de passe ne correspondent pas.'
                      : null,
                ),
                const SizedBox(height: 26.0),

                // Bouton principal d'inscription
                KitungaPrimaryButton(
                  text: 'Créer mon compte',
                  loading: _signingUp,
                  onPressed: _signUpUser,
                ),
                const SizedBox(height: 18.0),

                // Déjà un compte ? Se connecter
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Vous avez déjà un compte ?',
                      style: GoogleFonts.inter(
                        color: theme.secondaryText,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    GestureDetector(
                      onTap: () => context.pushNamed(LoginWidget.routeName),
                      child: Text(
                        'Se connecter',
                        style: GoogleFonts.interTight(
                          color: const Color(0xFFE51A1A),
                          fontSize: 14.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),

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
                const SizedBox(height: 20.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Vue utilisateur standard avec arrière-plan signature Kitunga
    if (widget.accessibility != 'Admin') {
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
              // ── Arrière-plan signature Kitunga (vagues rouges, cercles & filigrane) ──
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: KitungaAuthBackgroundPainter(isDark: isDark),
                  ),
                ),
              ),

              // ── Formulaire d'inscription ──
              SafeArea(
                child: _buildUserSignUp(context),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SafeArea(
          top: true,
          child: Builder(
            builder: (context) {
              if (widget!.accessibility == 'Admin') {
                return Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.asset(
                          'assets/images/Gemini_Generated_Image_w63nlqw63nlqw63n.png',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Material(
                            color: Colors.transparent,
                            elevation: 0.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: Container(
                              width: () {
                                if (MediaQuery.sizeOf(context).width <
                                    kBreakpointSmall) {
                                  return 388.0;
                                } else if (MediaQuery.sizeOf(context).width <
                                    kBreakpointMedium) {
                                  return 500.0;
                                } else if (MediaQuery.sizeOf(context).width <
                                    kBreakpointLarge) {
                                  return 500.0;
                                } else {
                                  return 388.0;
                                }
                              }(),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Nouveau  Partenaire',
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .headlineLarge
                                              .override(
                                                font: GoogleFonts.interTight(
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .headlineLarge
                                                          .fontStyle,
                                                ),
                                                fontSize: 20.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineLarge
                                                        .fontStyle,
                                                lineHeight: 1.5,
                                              ),
                                        ),
                                        Icon(
                                          Icons.admin_panel_settings_outlined,
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          size: 34.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Form(
                                      key: _model.formKey2,
                                      autovalidateMode:
                                          AutovalidateMode.disabled,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if ((widget!.accessibility !=
                                                    'Deliver') ||
                                                (widget!.accessibility !=
                                                    'Admin'))
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        20.0, 0.0, 20.0, 0.0),
                                                child:
                                                    FlutterFlowDropDown<String>(
                                                  controller: _model
                                                          .subscribTypBusinessValueController ??=
                                                      FormFieldController<
                                                          String>(null),
                                                  options: [
                                                    'Mensuel - 250F',
                                                    'Trimestriel - 500 F',
                                                    'Annuel - 1000 F'
                                                  ],
                                                  onChanged: (val) =>
                                                      safeSetState(() => _model
                                                              .subscribTypBusinessValue =
                                                          val),
                                                  width: double.infinity,
                                                  height: 50.0,
                                                  textStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                  hintText:
                                                      'Type d\'abonnement',
                                                  icon: Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                    size: 24.0,
                                                  ),
                                                  fillColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                  elevation: 2.0,
                                                  borderColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .black20,
                                                  borderWidth: 1.0,
                                                  borderRadius: 12.0,
                                                  margin: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          12.0, 0.0, 12.0, 0.0),
                                                  hidesUnderline: true,
                                                  isOverButton: false,
                                                  isSearchable: false,
                                                  isMultiSelect: false,
                                                ),
                                              ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child:
                                                  FlutterFlowDropDown<String>(
                                                controller: _model
                                                        .userTypeValueController ??=
                                                    FormFieldController<String>(
                                                        null),
                                                options: [
                                                  'Vendeur',
                                                  'Livreur',
                                                ],
                                                onChanged: (val) =>
                                                    safeSetState(() => _model
                                                        .userTypeValue = val),
                                                width: double.infinity,
                                                height: 50.0,
                                                textStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                hintText: 'Type d\'utilisateur',
                                                icon: Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  size: 24.0,
                                                ),
                                                fillColor:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                elevation: 2.0,
                                                borderColor:
                                                    FlutterFlowTheme.of(context)
                                                        .black20,
                                                borderWidth: 1.0,
                                                borderRadius: 12.0,
                                                margin: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 12.0, 0.0),
                                                hidesUnderline: true,
                                                isOverButton: false,
                                                isSearchable: false,
                                                isMultiSelect: false,
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child: TextFormField(
                                                controller: _model
                                                    .businessNameTextController,
                                                focusNode: _model
                                                    .businessNameFocusNode,
                                                autofocus: false,
                                                textInputAction:
                                                    TextInputAction.next,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: false,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  hintText:
                                                      'Nom d\'utilisateur',
                                                  hintStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  errorStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                        lineHeight: 1.2,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .black20,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(16.0, 13.0,
                                                              0.0, 13.0),
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      fontSize: 17.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                cursorColor:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                validator: _model
                                                    .businessNameTextControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child: TextFormField(
                                                controller: _model
                                                    .emailBusinessTextController,
                                                focusNode: _model
                                                    .emailBusinessFocusNode,
                                                autofocus: false,
                                                textInputAction:
                                                    TextInputAction.next,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: false,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  hintText: 'Adresse e-mail',
                                                  hintStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                  errorStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                        lineHeight: 1.2,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .black20,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(16.0, 13.0,
                                                              0.0, 13.0),
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      fontSize: 13.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                cursorColor:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                validator: _model
                                                    .emailBusinessTextControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child: TextFormField(
                                                controller: _model
                                                    .phoneBusinessTextController,
                                                focusNode: _model
                                                    .phoneBusinessFocusNode,
                                                autofocus: false,
                                                textInputAction:
                                                    TextInputAction.next,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: false,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  hintText: 'Téléphone',
                                                  hintStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  errorStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                        lineHeight: 1.2,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .black20,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(16.0, 13.0,
                                                              0.0, 13.0),
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      fontSize: 13.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                keyboardType:
                                                    TextInputType.phone,
                                                cursorColor:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                validator: _model
                                                    .phoneBusinessTextControllerValidator
                                                    .asValidator(context),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .allow(RegExp('[0-9]'))
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child:
                                                  FlutterFlowDropDown<String>(
                                                controller: _model
                                                        .categoryValueController ??=
                                                    FormFieldController<String>(
                                                        null),
                                                options: [
                                                  'Magasin',
                                                  'Restaurant',
                                                  'Pharmacie',
                                                  'Boutique'
                                                ],
                                                onChanged: (val) =>
                                                    safeSetState(() => _model
                                                        .categoryValue = val),
                                                width: double.infinity,
                                                height: 50.0,
                                                textStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                hintText: 'Catégorie Business',
                                                icon: Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  size: 24.0,
                                                ),
                                                fillColor:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                elevation: 2.0,
                                                borderColor:
                                                    FlutterFlowTheme.of(context)
                                                        .black20,
                                                borderWidth: 1.0,
                                                borderRadius: 12.0,
                                                margin: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 12.0, 0.0),
                                                hidesUnderline: true,
                                                isOverButton: false,
                                                isSearchable: false,
                                                isMultiSelect: false,
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child: TextFormField(
                                                controller:
                                                    _model.bioTextController,
                                                focusNode: _model.bioFocusNode,
                                                autofocus: false,
                                                textCapitalization:
                                                    TextCapitalization
                                                        .sentences,
                                                textInputAction:
                                                    TextInputAction.next,
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  isDense: false,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  hintText: 'Bio',
                                                  hintStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  errorStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                        lineHeight: 1.2,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .black20,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(16.0, 13.0,
                                                              0.0, 13.0),
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      fontSize: 13.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                maxLines: 3,
                                                maxLength: 100,
                                                cursorColor:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                validator: _model
                                                    .bioTextControllerValidator
                                                    .asValidator(context),
                                                inputFormatters: [
                                                  if (!isAndroid && !isiOS)
                                                    TextInputFormatter
                                                        .withFunction((oldValue,
                                                            newValue) {
                                                      return TextEditingValue(
                                                        selection:
                                                            newValue.selection,
                                                        text: newValue.text
                                                            .toCapitalization(
                                                                TextCapitalization
                                                                    .sentences),
                                                      );
                                                    }),
                                                ],
                                              ),
                                            ),
                                            if ((widget!.accessibility ==
                                                    'Seller') ||
                                                (widget!.accessibility ==
                                                    'Deliver'))
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        20.0, 6.0, 20.0, 0.0),
                                                child: TextFormField(
                                                  controller: _model
                                                      .horraireTextController,
                                                  focusNode:
                                                      _model.horraireFocusNode,
                                                  autofocus: false,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: false,
                                                    labelStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .labelMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                    hintText:
                                                        'Horaire (ex: 8h - 18h)',
                                                    hintStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .labelMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .textfiled,
                                                          fontSize: 17.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                    errorStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .error,
                                                          fontSize: 17.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                          lineHeight: 1.2,
                                                        ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .black20,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primary,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    contentPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(
                                                                16.0,
                                                                13.0,
                                                                0.0,
                                                                13.0),
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                  cursorColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  validator: _model
                                                      .horraireTextControllerValidator
                                                      .asValidator(context),
                                                ),
                                              ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child: TextFormField(
                                                controller: _model
                                                    .pwdBusinessTextController,
                                                focusNode:
                                                    _model.pwdBusinessFocusNode,
                                                autofocus: false,
                                                textInputAction:
                                                    TextInputAction.done,
                                                obscureText: !_model
                                                    .pwdBusinessVisibility,
                                                decoration: InputDecoration(
                                                  isDense: false,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  hintText: 'Mot de passe',
                                                  hintStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  errorStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                        lineHeight: 1.2,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .black20,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(16.0, 13.0,
                                                              0.0, 13.0),
                                                  suffixIcon: InkWell(
                                                    onTap: () async {
                                                      safeSetState(() => _model
                                                              .pwdBusinessVisibility =
                                                          !_model
                                                              .pwdBusinessVisibility);
                                                    },
                                                    focusNode: FocusNode(
                                                        skipTraversal: true),
                                                    child: Icon(
                                                      _model.pwdBusinessVisibility
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      color: Color(0xFF696969),
                                                      size: 22.0,
                                                    ),
                                                  ),
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      fontSize: 13.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                cursorColor:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                validator: _model
                                                    .pwdBusinessTextControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child: TextFormField(
                                                controller: _model
                                                    .confPwdBusinessTextController,
                                                focusNode: _model
                                                    .confPwdBusinessFocusNode,
                                                autofocus: false,
                                                textInputAction:
                                                    TextInputAction.done,
                                                obscureText: !_model
                                                    .confPwdBusinessVisibility,
                                                decoration: InputDecoration(
                                                  isDense: false,
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  hintText:
                                                      'Confirmez le mot de passe',
                                                  hintStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .textfiled,
                                                        fontSize: 13.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  errorStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        fontSize: 17.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                        lineHeight: 1.2,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .black20,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(16.0, 13.0,
                                                              0.0, 13.0),
                                                  suffixIcon: InkWell(
                                                    onTap: () async {
                                                      safeSetState(() => _model
                                                              .confPwdBusinessVisibility =
                                                          !_model
                                                              .confPwdBusinessVisibility);
                                                    },
                                                    focusNode: FocusNode(
                                                        skipTraversal: true),
                                                    child: Icon(
                                                      _model.confPwdBusinessVisibility
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      color: Color(0xFF696969),
                                                      size: 22.0,
                                                    ),
                                                  ),
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      fontSize: 13.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                cursorColor:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                validator: _model
                                                    .confPwdBusinessTextControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 26.0, 20.0, 0.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Compte certifié',
                                                    maxLines: 1,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .headlineLarge
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .headlineLarge
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .headlineLarge
                                                                  .fontStyle,
                                                          lineHeight: 1.5,
                                                        ),
                                                  ),
                                                  Theme(
                                                    data: ThemeData(
                                                      checkboxTheme:
                                                          CheckboxThemeData(
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        materialTapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      4.0),
                                                        ),
                                                      ),
                                                      unselectedWidgetColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                    ),
                                                    child: Checkbox(
                                                      value: _model
                                                              .certifiedValue ??=
                                                          true,
                                                      onChanged:
                                                          (newValue) async {
                                                        safeSetState(() => _model
                                                                .certifiedValue =
                                                            newValue!);
                                                      },
                                                      side: (FlutterFlowTheme.of(
                                                                      context)
                                                                  .alternate !=
                                                              null)
                                                          ? BorderSide(
                                                              width: 2,
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .alternate!,
                                                            )
                                                          : null,
                                                      activeColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      checkColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .info,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 1.0),
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        20.0, 28.0, 20.0, 24.0),
                                                child: FFButtonWidget(
                                                  onPressed: () async {
                                                    if (_model.emailBusinessTextController.text.trim().isEmpty) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Veuillez renseigner votre adresse email.')),
                                                      );
                                                      return;
                                                    }
                                                    if (_model.pwdBusinessTextController.text.isEmpty) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Veuillez saisir un mot de passe.')),
                                                      );
                                                      return;
                                                    }
                                                    if (_model.pwdBusinessTextController.text.length < 6) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Le mot de passe doit comporter au moins 6 caractères.')),
                                                      );
                                                      return;
                                                    }
                                                    if (_model
                                                            .pwdBusinessTextController
                                                            .text !=
                                                        _model
                                                            .confPwdBusinessTextController
                                                            .text) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Les mots de passe ne correspondent pas.',
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }

                                                    final partnerRole = switch (_model.userTypeValue) {
                                                      'Vendeur' => 'Seller',
                                                      'Livreur' => 'Deliver',
                                                      _ => null,
                                                    };
                                                    if (partnerRole == null) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Choisissez le type de partenaire : vendeur ou livreur.')),
                                                      );
                                                      return;
                                                    }

                                                    // Compte créé par le serveur : l'administrateur
                                                    // reste connecté à son propre compte.
                                                    final String partnerId;
                                                    try {
                                                      final created = await kitungaCallFunction(
                                                        'kitungaCreatePartner',
                                                        {
                                                          'email': _model.emailBusinessTextController.text,
                                                          'password': _model.pwdBusinessTextController.text,
                                                          'role': partnerRole,
                                                          'displayName': _model.businessNameTextController.text,
                                                          'phoneNumber': _model.phoneBusinessTextController.text,
                                                          'category': _model.categoryValue,
                                                          'verified': _model.certifiedValue,
                                                          'bio': _model.bioTextController.text.trim().isNotEmpty
                                                              ? _model.bioTextController.text
                                                              : 'Je suis content d\'utiliser Kitunga comme App pour mes achats au quotidien',
                                                          'horraire': _model.horraireTextController.text,
                                                          'subscribeType': _model.subscribTypBusinessValue,
                                                        },
                                                      );
                                                      partnerId = created['uid'] as String;
                                                    } on ServerPaymentException catch (e) {
                                                      if (!context.mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text(e.message)),
                                                      );
                                                      return;
                                                    }
                                                    if (!context.mounted) return;

                                                    context.pushNamed(
                                                      AddProfileWidget.routeName,
                                                      queryParameters: {
                                                        'role': serializeParam(
                                                          widget!.accessibility,
                                                          ParamType.String,
                                                        ),
                                                        'partnerRef': serializeParam(
                                                          UserRecord.collection.doc(partnerId),
                                                          ParamType.DocumentReference,
                                                        ),
                                                      }.withoutNulls,
                                                    );
                                                  },
                                                  text: 'Ajouter',
                                                  options: FFButtonOptions(
                                                    width: double.infinity,
                                                    height: 56.0,
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .titleMedium
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          fontSize: 16.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderSide: BorderSide(
                                                      color: Colors.transparent,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24.0),
                                                  ),
                                                  showLoadingIndicator: false,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
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
              } else {
                return _buildUserSignUp(context);
              }
            },
          ),
        ),
      ),
    );
  }
}
