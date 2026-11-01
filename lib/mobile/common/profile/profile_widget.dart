import '/auth/firebase_auth/auth_util.dart';
import '/backend/subscription.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/alert_info/alert_info_widget.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import '/mobile/components/form_styles/form_styles.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_model.dart';
export 'profile_model.dart';

/// Page d'inscription utilisateur
class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});

  static String routeName = 'Profile';
  static String routePath = '/profile';

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  late ProfileModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _roleLabel(String role) => switch (role) {
        'Seller' => 'Vendeur',
        'Deliver' => 'Livreur',
        'Admin' => 'Administrateur',
        'Guest' => 'Visiteur',
        _ => 'Client',
      };

  String _initial() {
    final n = currentUserDisplayName.trim();
    return n.isEmpty ? 'K' : n[0].toUpperCase();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Se déconnecter ?'),
        content: Text('Vous devrez saisir à nouveau vos identifiants.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Déconnexion',
                style: TextStyle(color: FlutterFlowTheme.of(context).error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    GoRouter.of(context).clearRedirectLocation();
    context.pushNamedAuth(OnboardingWidget.routeName, context.mounted);
  }

  Future<void> _help() async {
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Centre d\'aide'),
        content: Text(
            'Besoin d\'assistance avec une commande ou votre compte ?\n\nE-mail : contact@ntemoconsulting.com\nDu lundi au samedi, 8h - 18h.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Fermer')),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              launchURL(Uri(
                scheme: 'mailto',
                path: 'contact@ntemoconsulting.com',
                query: 'subject=${Uri.encodeComponent('Assistance Kitunga')}',
              ).toString());
            },
            child: Text('Écrire au support'),
          ),
        ],
      ),
    );
  }

  Widget _group(FlutterFlowTheme theme, String title, List<Widget> items) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: theme.secondaryText,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: theme.divider),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1.0, indent: 60.0, color: theme.divider),
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
      FlutterFlowTheme theme, IconData icon, String label, VoidCallback onTap,
      {Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.0),
      leading: Container(
        width: 34.0,
        height: 34.0,
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Icon(icon, color: theme.primary, size: 19.0),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: theme.primaryText,
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded, color: theme.secondaryText),
    );
  }

  Widget _header(FlutterFlowTheme theme, String role) {
    final photo = currentUserPhoto;
    final plan = valueOrDefault(currentUserDocument?.subscribeType, '');
    final verified = valueOrDefault(currentUserDocument?.verified, false);
    // Le fond rouge passe sous la barre d'état.
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 300.0 + top,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Fond rouge Kitunga au bord inférieur arrondi.
          ClipPath(
            clipper: _CurveClipper(),
            child: Container(
              height: 180.0 + top,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primary,
                    Color.lerp(theme.primary, Colors.black, 0.25)!,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8.0 + top,
            left: 20.0,
            right: 20.0,
            child: Row(
              children: [
                Text(
                  'Profil',
                  style: GoogleFonts.interTight(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Spacer(),
                if (role != 'Guest')
                  TextButton(
                    onPressed: () =>
                        context.pushNamed(EditProfileWidget.routeName),
                    child: Text(
                      'Modifier',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 76.0 + top,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 116.0,
                      height: 116.0,
                      padding: EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: photo.isEmpty
                            ? Container(
                                color: Color.lerp(
                                    theme.primary, Colors.black, 0.35),
                                alignment: Alignment.center,
                                child: Text(
                                  _initial(),
                                  style: GoogleFonts.interTight(
                                    color: Colors.white,
                                    fontSize: 46.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : KitungaImage(photo,
                                width: 108.0,
                                height: 108.0,
                                fallbackIcon: Icons.person_rounded),
                      ),
                    ),
                    if (verified)
                      Positioned(
                        right: 4.0,
                        bottom: 4.0,
                        child: Container(
                          padding: EdgeInsets.all(3.0),
                          decoration: BoxDecoration(
                            color: theme.secondaryBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.verified_rounded,
                              color: Color(0xFF1E9E5A), size: 26.0),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 10.0),
                Text(
                  role == 'Guest'
                      ? 'Visiteur'
                      : (currentUserDisplayName.isEmpty
                          ? 'Mon compte'
                          : currentUserDisplayName),
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 21.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (currentUserEmail.isNotEmpty)
                  Text(
                    currentUserEmail,
                    style: GoogleFonts.inter(
                        color: theme.secondaryText, fontSize: 14.0),
                  ),
                SizedBox(height: 6.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _badge(theme, _roleLabel(role)),
                    if (plan.isNotEmpty && role != 'Guest' && role != 'User') ...[
                      SizedBox(width: 6.0),
                      _badge(theme, plan),
                    ],
                    if (role == 'User') ...[
                      SizedBox(width: 6.0),
                      _badge(
                        theme,
                        kitungaSubscriptionActive()
                            ? 'Abonné jusqu\'au ${dateTimeFormat('d/M/y', currentUserDocument!.subscribeCloseAt)}'
                            : 'Sans abonnement',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(FlutterFlowTheme theme, String text) => Container(
        padding: EdgeInsetsDirectional.fromSTEB(10.0, 3.0, 10.0, 3.0),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: theme.primary,
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      body: AuthUserStreamWidget(
        builder: (context) {
          final role = valueOrDefault(currentUserDocument?.role, '');
          final guest = role == 'Guest' || role.isEmpty;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ListView(
            padding: EdgeInsets.only(bottom: 32.0),
            children: [
              _header(theme, role),
              if (guest)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 0.0),
                  child: Container(
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(18.0),
                      border: Border.all(color: theme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Créez votre compte Kitunga',
                          style: GoogleFonts.interTight(
                            color: theme.primaryText,
                            fontSize: 17.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          'Pour commander, suivre vos livraisons et retrouver l\'historique de vos achats.',
                          style: GoogleFonts.inter(
                              color: theme.secondaryText,
                              fontSize: 13.5,
                              height: 1.4),
                        ),
                        SizedBox(height: 12.0),
                        KitungaPrimaryButton(
                          text: 'Créer un compte',
                          onPressed: () => context.pushNamed(
                            SignWidget.routeName,
                            queryParameters: {
                              'accessibility':
                                  serializeParam('User', ParamType.String),
                            }.withoutNulls,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!guest)
                _group(theme, 'Mon compte', [
                  _item(theme, Icons.person_outline_rounded, 'Mon profil',
                      () => context.pushNamed(MyProfileWidget.routeName)),
                  _item(
                      theme,
                      Icons.receipt_long_outlined,
                      role == 'Seller' || role == 'Deliver'
                          ? 'Commandes'
                          : 'Mes commandes',
                      () => context.pushNamed(OrderWidget.routeName)),
                  _item(theme, Icons.lock_outline_rounded, 'Sécurité',
                      () => context.pushNamed(SecurityWidget.routeName)),
                ]),
              _group(theme, 'Préférences', [
                _item(theme, Icons.settings_outlined, 'Paramètres',
                    () => context.pushNamed(SettingsWidget.routeName)),
                _item(
                  theme,
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  'Mode sombre',
                  () => setDarkModeSetting(
                      context, dark ? ThemeMode.light : ThemeMode.dark),
                  trailing: Switch.adaptive(
                    value: dark,
                    activeThumbColor: theme.primary,
                    onChanged: (v) => setDarkModeSetting(
                        context, v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ),
              ]),
              _group(theme, 'Aide et informations légales', [
                _item(theme, Icons.support_agent_rounded, 'Centre d\'aide',
                    _help),
                _item(
                    theme,
                    Icons.description_outlined,
                    'Conditions d\'utilisation',
                    () => context.pushNamed(TermsConditionsWidget.routeName)),
                _item(
                    theme,
                    Icons.privacy_tip_outlined,
                    'Politique de confidentialité',
                    () => context.pushNamed(PrivacyPolicyWidget.routeName)),
              ]),
              Padding(
                padding: EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 0.0),
                child: TextButton.icon(
                  onPressed: _logout,
                  style: TextButton.styleFrom(
                    minimumSize: Size.fromHeight(52.0),
                    backgroundColor: theme.secondaryBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                      side: BorderSide(color: theme.divider),
                    ),
                  ),
                  icon: Icon(Icons.logout_rounded, color: theme.error),
                  label: Text(
                    'Déconnexion',
                    style: GoogleFonts.inter(
                      color: theme.error,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bord inférieur arrondi de l'en-tête du profil.
class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0.0, size.height - 40.0)
    ..quadraticBezierTo(
        size.width / 2, size.height + 30.0, size.width, size.height - 40.0)
    ..lineTo(size.width, 0.0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
