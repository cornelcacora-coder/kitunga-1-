import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'verify_register_link_model.dart';
export 'verify_register_link_model.dart';
import '/mobile/components/form_styles/form_styles.dart';

/// Page d'inscription utilisateur
class VerifyRegisterLinkWidget extends StatefulWidget {
  const VerifyRegisterLinkWidget({super.key});

  static String routeName = 'VerifyRegisterLink';
  static String routePath = '/verifyRegisterLink';

  @override
  State<VerifyRegisterLinkWidget> createState() =>
      _VerifyRegisterLinkWidgetState();
}

class _VerifyRegisterLinkWidgetState extends State<VerifyRegisterLinkWidget> {
  late VerifyRegisterLinkModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VerifyRegisterLinkModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(
            'Vérification d\'identité',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: KitungaAuthBackgroundPainter(isDark: isDark),
                ),
              ),
            ),
            SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              wrapWithModel(
                model: _model.emptyCardModel,
                updateCallback: () => safeSetState(() {}),
                child: EmptyCardWidget(
                  photo:
                      'assets/images/app/wallet_card.png',
                  title: 'Mail Envoyé',
                  description:
                      'Nnous vous avons envoyé un mail accédez à votre boite mail afin de vérifier votre compt',
                  buttonText: 'Renvoyez le lien',
                  action: () async {
                    await authManager.sendEmailVerification();
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Vous avez déjà un  compte ?',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.normal,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 15.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                          lineHeight: 1.45,
                        ),
                  ),
                  FFButtonWidget(
                    onPressed: () async {
                      context.pushNamed(LoginWidget.routeName);
                    },
                    text: 'Se connecter',
                    options: FFButtonOptions(
                      height: 44.0,
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: Colors.transparent,
                      textStyle: GoogleFonts.interTight(
                        color: FlutterFlowTheme.of(context).primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.0,
                      ),
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ].divide(SizedBox(width: 8.0)),
              ),
            ].divide(SizedBox(height: 10.0)),
          ),
        ),
          ],
        ),
      ),
    );
  }
}
