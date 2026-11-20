import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/common/security/change_email_page.dart';
import '/mobile/common/security/change_password_page.dart';
import '/mobile/components/delete_account/delete_account.dart';
import '/mobile/main_app/order_view/order_view_widget.dart'
    show kitungaPageBar;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
export 'security_model.dart';

const _red = Color(0xFFE51A1A);

/// « Compte et sécurité » : informations du profil, e-mail et mot de passe
/// de connexion, suppression du compte. Pour tous les comptes.
class SecurityWidget extends StatefulWidget {
  const SecurityWidget({super.key});

  static String routeName = 'Security';
  static String routePath = '/security';

  @override
  State<SecurityWidget> createState() => _SecurityWidgetState();
}

class _SecurityWidgetState extends State<SecurityWidget> {
  @override
  void initState() {
    super.initState();
    // Après un changement d'e-mail confirmé : profil remis à jour.
    kitungaSyncEmail();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final password = kitungaHasPasswordLogin();
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
      appBar: kitungaPageBar(context, 'Compte et sécurité'),
      body: AuthUserStreamWidget(
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _Title('Mes informations'),
            _Group(children: [
              _Item(
                icon: Icons.person_outline_rounded,
                title: 'Nom, photo et téléphones',
                subtitle: currentUserDisplayName.isEmpty
                    ? 'Compléter mon profil'
                    : currentUserDisplayName,
                onTap: () => context.pushNamed(EditProfileWidget.routeName),
              ),
            ]),
            const SizedBox(height: 18),
            const _Title('Connexion'),
            _Group(children: [
              _Item(
                icon: Icons.mail_outline_rounded,
                title: 'Adresse e-mail',
                subtitle: currentUserEmail.isEmpty ? '—' : currentUserEmail,
                onTap: password
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangeEmailPage()))
                    : null,
                note: password
                    ? null
                    : 'Compte relié à Google : l\'e-mail se gère dans votre '
                        'compte Google.',
              ),
              _Item(
                icon: Icons.lock_outline_rounded,
                title: 'Mot de passe',
                subtitle: password ? 'Changer mon mot de passe' : '—',
                onTap: password
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage()))
                    : null,
                note: password
                    ? null
                    : 'Compte relié à Google : pas de mot de passe Kitunga.',
              ),
            ]),
            const SizedBox(height: 18),
            const _Title('Zone sensible'),
            _Group(children: [
              _Item(
                icon: Icons.delete_forever_rounded,
                title: 'Supprimer mon compte',
                subtitle: 'Définitif : vos données personnelles sont effacées',
                danger: true,
                onTap: () => showDeleteAccountDialog(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.poppins(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                color: FlutterFlowTheme.of(context).secondaryText)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 56, color: theme.alternate),
          children[i],
        ],
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.note,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? note;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = danger ? _red : theme.primaryText;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: _red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: theme.secondaryText)),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(note!,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: theme.secondaryText)),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: theme.secondaryText),
        ]),
      ),
    );
  }
}
