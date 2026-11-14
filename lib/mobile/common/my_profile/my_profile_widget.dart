import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/main_app/order_view/order_view_widget.dart'
    show kitungaPageBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show FontFeature;
import 'package:google_fonts/google_fonts.dart';
export 'my_profile_model.dart';

const _red = Color(0xFFE51A1A);

/// « Mon profil » : photo, nom, coordonnées, présentation, identifiant.
class MyProfileWidget extends StatefulWidget {
  const MyProfileWidget({super.key});

  static String routeName = 'MyProfile';
  static String routePath = '/myProfile';

  @override
  State<MyProfileWidget> createState() => _MyProfileWidgetState();
}

class _MyProfileWidgetState extends State<MyProfileWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
      appBar: kitungaPageBar(context, 'Mon profil'),
      body: AuthUserStreamWidget(
        builder: (context) {
          final name = currentUserDisplayName.trim();
          final bio = valueOrDefault(currentUserDocument?.bio, '').trim();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(child: KitungaAvatar(url: currentUserPhoto, name: name)),
              const SizedBox(height: 14),
              Text(name.isEmpty ? 'Mon compte' : name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.interTight(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
              if (currentUserEmail.isNotEmpty)
                Text(currentUserEmail,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: theme.secondaryText)),
              const SizedBox(height: 22),
              _Card(children: [
                _Row(
                    icon: Icons.mail_outline_rounded,
                    label: 'E-mail',
                    value: currentUserEmail),
                _Row(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: currentPhoneNumber),
                _Row(
                    icon: Icons.notes_rounded,
                    label: 'Présentation',
                    value: bio),
              ]),
              const SizedBox(height: 14),
              _Card(children: [
                _Row(
                  icon: Icons.badge_outlined,
                  label: 'Identifiant (pour le support)',
                  value: currentUserUid,
                  exact: true,
                  trailing: IconButton(
                    tooltip: 'Copier',
                    icon: Icon(Icons.copy_rounded,
                        size: 19, color: theme.secondaryText),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: currentUserUid));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Identifiant copié.')));
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.pushNamed(EditProfileWidget.routeName),
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: Text('Modifier mon profil',
                      style: GoogleFonts.inter(
                          fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Photo de profil ronde, ou initiales sur fond rouge.
class KitungaAvatar extends StatelessWidget {
  const KitungaAvatar(
      {super.key, required this.url, required this.name, this.size = 104});

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: _red,
      child: Text(initials.isEmpty ? 'K' : initials,
          style: GoogleFonts.interTight(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800)),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _red.withValues(alpha: 0.25), width: 3),
      ),
      child: ClipOval(
        child: url.trim().isEmpty
            ? fallback
            : KitungaImage(url,
                width: size, height: size, placeholder: fallback),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, color: theme.alternate),
          children[i],
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.icon,
      required this.label,
      required this.value,
      this.exact = false,
      this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  /// Texte à recopier tel quel (identifiant) : sans les substitutions
  /// typographiques de la police (« 8x1 » affiché « 8×1 »).
  final bool exact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, size: 21, color: _red),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: theme.secondaryText)),
              const SizedBox(height: 2),
              Text(empty ? 'Non renseigné' : value,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: empty ? FontWeight.w500 : FontWeight.w600,
                      fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                      fontFeatures:
                          exact ? const [FontFeature.disable('calt')] : null,
                      color: empty ? theme.secondaryText : theme.primaryText)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
