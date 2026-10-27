import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'forgot_password_link_model.dart';
export 'forgot_password_link_model.dart';

/// Page d'inscription utilisateur
class ForgotPasswordLinkWidget extends StatefulWidget {
  const ForgotPasswordLinkWidget({super.key});

  static String routeName = 'ForgotPassword_link';
  static String routePath = '/forgotPasswordLink';

  @override
  State<ForgotPasswordLinkWidget> createState() =>
      _ForgotPasswordLinkWidgetState();
}

class _ForgotPasswordLinkWidgetState extends State<ForgotPasswordLinkWidget> {
  late ForgotPasswordLinkModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ForgotPasswordLinkModel());

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
          title: Text(
            'Mot de passe oublier',
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
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              wrapWithModel(
                model: _model.emptyCardModel,
                updateCallback: () => safeSetState(() {}),
                child: EmptyCardWidget(
                  photo:
                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/huber-eats-consumer-app-38yn7u/assets/bh9lkvi2krgy/Screenshot_2024-03-10_at_15.29.09.png',
                  title: 'Mail Envoyé',
                  description:
                      'Nous vous avions envoyé un lien, consultez vos e-mails afin de suivre le lien de reconnexion. ',
                  buttonText: 'Se reconnecter',
                  action: () async {
                    context.pushNamed(LoginWidget.routeName);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
