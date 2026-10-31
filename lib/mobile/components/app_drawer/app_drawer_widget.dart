import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Menu latéral (hamburger) : profil, accès rapides et mode sombre/clair.
class AppDrawerWidget extends StatelessWidget {
  const AppDrawerWidget({super.key});

  String _roleLabel(String role) {
    switch (role) {
      case 'Seller':
        return 'Vendeur';
      case 'Deliver':
        return 'Livreur';
      case 'Admin':
        return 'Administrateur';
      case 'Guest':
        return 'Visiteur';
      default:
        return 'Client';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Drawer(
      backgroundColor: theme.secondaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24.0)),
      ),
      child: SafeArea(
        child: AuthUserStreamWidget(
          builder: (context) {
            final role = valueOrDefault(currentUserDocument?.role, '');
            final isGuest = role == 'Guest' || role.isEmpty;
            final name = currentUserDisplayName.isNotEmpty
                ? currentUserDisplayName
                : (isGuest ? 'Visiteur' : 'Mon compte');

            // Ferme le menu puis ouvre la page demandée.
            // Le routeur est récupéré avant de fermer le menu : après la
            // fermeture, le contexte du menu n'est plus utilisable.
            void open(String routeName,
                {Map<String, dynamic> queryParameters = const {}}) {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.pushNamed(routeName, queryParameters: queryParameters);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête : photo, nom et rôle.
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(20.0, 24.0, 20.0, 20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28.0,
                        backgroundColor: theme.primary.withValues(alpha: 0.12),
                        backgroundImage: currentUserPhoto.isNotEmpty
                            ? NetworkImage(currentUserPhoto)
                            : null,
                        child: currentUserPhoto.isEmpty
                            ? Icon(Icons.person_rounded,
                                color: theme.primary, size: 28.0)
                            : null,
                      ),
                      SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.interTight(
                                color: theme.primaryText,
                                fontSize: 17.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Container(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  8.0, 2.0, 8.0, 2.0),
                              decoration: BoxDecoration(
                                color: theme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Text(
                                _roleLabel(role),
                                style: GoogleFonts.inter(
                                  color: theme.primary,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1.0, color: theme.divider),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    children: [
                      _DrawerItem(
                        icon: Icons.home_outlined,
                        label: 'Accueil',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      if (!isGuest)
                        _DrawerItem(
                          icon: Icons.receipt_long_outlined,
                          label: 'Mes commandes',
                          onTap: () => open(OrderWidget.routeName),
                        ),
                      if (role == 'User')
                        _DrawerItem(
                          icon: Icons.shopping_cart_outlined,
                          label: 'Mon panier',
                          onTap: () => open(CartLastWidget.routeName),
                        ),
                      _DrawerItem(
                        icon: Icons.storefront_outlined,
                        label: 'Boutiques',
                        onTap: () => open(
                          ShopsWidget.routeName,
                          queryParameters: {
                            'tag': serializeParam('Boutique', ParamType.String),
                          }.withoutNulls,
                        ),
                      ),
                      if (!isGuest)
                        _DrawerItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Mon profil',
                          onTap: () => open(MyProfileWidget.routeName),
                        ),
                      _DrawerItem(
                        icon: Icons.settings_outlined,
                        label: 'Paramètres',
                        onTap: () => open(SettingsWidget.routeName),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1.0, color: theme.divider),
                if (isGuest)
                  _DrawerItem(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Créer un compte',
                    color: theme.primary,
                    onTap: () => open(
                      SignWidget.routeName,
                      queryParameters: {
                        'accessibility':
                            serializeParam('User', ParamType.String),
                      }.withoutNulls,
                    ),
                  ),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Déconnexion',
                  color: theme.error,
                  onTap: () async {
                    GoRouter.of(context).prepareAuthEvent();
                    await authManager.signOut();
                    GoRouter.of(context).clearRedirectLocation();
                    context.pushNamedAuth(
                        OnboardingWidget.routeName, context.mounted);
                  },
                ),
                SizedBox(height: 8.0),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final c = color ?? theme.primaryText;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
      leading: Icon(icon, color: c),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: c,
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
