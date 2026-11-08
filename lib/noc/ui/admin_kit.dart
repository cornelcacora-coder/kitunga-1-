import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Charte graphique de l'administration Kitunga (indépendante de
/// FlutterFlow) : couleurs tirées du logo, typographie Inter, espacements,
/// arrondis et ombres. Toutes les pages admin s'appuient dessus.
class AdminColors {
  AdminColors._();

  // Marque
  static const red = Color(0xFFE51A1A);
  static const redDeep = Color(0xFFB31212);
  static const redSoft = Color(0xFFFDECEC);

  // Fonds et surfaces
  static const page = Color(0xFFF2F3F7);
  static const panel = Color(0xFFE9EBF1);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF7F8FB);
  static const border = Color(0xFFE6E8EE);

  // Textes
  static const ink = Color(0xFF16181D);
  static const text = Color(0xFF3B3F47);
  static const muted = Color(0xFF6F737C);
  static const faint = Color(0xFFA2A6AE);

  // Statuts et graphiques
  static const green = Color(0xFF17A35B);
  static const greenSoft = Color(0xFFE5F6EC);
  static const orange = Color(0xFFE38B00);
  static const orangeSoft = Color(0xFFFFF2DE);
  static const blue = Color(0xFF2F6FDB);
  static const blueSoft = Color(0xFFE6EFFC);
  static const violet = Color(0xFF7458E0);
  static const violetSoft = Color(0xFFEFEBFC);
  static const teal = Color(0xFF14A3A3);
  static const grey = Color(0xFF8A8F98);
  static const greySoft = Color(0xFFF0F1F4);
}

class AdminRadius {
  AdminRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const pill = 999.0;
}

/// Ombre douce des cartes.
const kAdminShadow = [
  BoxShadow(color: Color(0x0A1B2340), blurRadius: 18.0, offset: Offset(0, 3)),
];

/// Ombre colorée de l'élément actif (menu, bouton principal).
List<BoxShadow> adminGlow(Color c) => [
      BoxShadow(
          color: c.withValues(alpha: 0.22),
          blurRadius: 14.0,
          offset: const Offset(0, 4)),
    ];

class AdminText {
  AdminText._();

  static TextStyle display({Color color = AdminColors.ink}) =>
      GoogleFonts.interTight(
          color: color, fontSize: 28.0, fontWeight: FontWeight.w800, height: 1.1);

  static TextStyle h1({Color color = AdminColors.ink}) => GoogleFonts.interTight(
      color: color, fontSize: 22.0, fontWeight: FontWeight.w800);

  static TextStyle h2({Color color = AdminColors.ink}) => GoogleFonts.interTight(
      color: color, fontSize: 16.0, fontWeight: FontWeight.w700);

  static TextStyle body({Color color = AdminColors.text, double size = 14.0}) =>
      GoogleFonts.inter(color: color, fontSize: size, height: 1.4);

  static TextStyle label({Color color = AdminColors.muted, double size = 13.0}) =>
      GoogleFonts.inter(
          color: color, fontSize: size, fontWeight: FontWeight.w500, height: 1.3);

  static TextStyle strong({Color color = AdminColors.ink, double size = 14.0}) =>
      GoogleFonts.inter(
          color: color, fontSize: size, fontWeight: FontWeight.w700, height: 1.3);

  static TextStyle caps({Color color = AdminColors.faint}) => GoogleFonts.inter(
      color: color,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8);
}

/// Thème Material des pages admin (boutons, champs, menus, fenêtres).
ThemeData adminTheme(ThemeData base) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AdminColors.red,
    primary: AdminColors.red,
    surface: AdminColors.surface,
    brightness: Brightness.light,
  );
  OutlineInputBorder border(Color c, [double w = 1.0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.md),
        borderSide: BorderSide(color: c, width: w),
      );
  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AdminColors.page,
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AdminColors.text, displayColor: AdminColors.ink),
    dividerColor: AdminColors.border,
    dividerTheme:
        const DividerThemeData(color: AdminColors.border, thickness: 1.0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.surfaceAlt,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
      labelStyle: AdminText.label(),
      hintStyle: AdminText.label(color: AdminColors.faint),
      border: border(AdminColors.border),
      enabledBorder: border(AdminColors.border),
      focusedBorder: border(AdminColors.red, 1.5),
      errorBorder: border(AdminColors.red),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.red,
        foregroundColor: Colors.white,
        textStyle: AdminText.strong(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadius.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.ink,
        side: const BorderSide(color: AdminColors.border),
        textStyle: AdminText.strong(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.red,
        textStyle: AdminText.strong(),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadius.sm)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.xl)),
      titleTextStyle: AdminText.h1(),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6.0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.md)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.md)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AdminColors.surface,
      side: const BorderSide(color: AdminColors.border),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.pill)),
      labelStyle: AdminText.label(color: AdminColors.text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : AdminColors.faint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AdminColors.red : AdminColors.panel),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AdminColors.red),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
          color: AdminColors.ink,
          borderRadius: BorderRadius.circular(AdminRadius.sm)),
      textStyle: AdminText.label(color: Colors.white, size: 12.0),
    ),
  );
}

/// Applique le thème admin à une page.
class AdminThemeScope extends StatelessWidget {
  const AdminThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: adminTheme(Theme.of(context)), child: child);
}

// ── Composants ───────────────────────────────────────────────────────────

/// Carte blanche arrondie à ombre douce.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.onTap,
    this.color = AdminColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminRadius.lg),
        boxShadow: kAdminShadow,
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AdminRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: AdminColors.surfaceAlt,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// En-tête d'une carte : titre, sous-titre, action à droite.
class AdminCardHeader extends StatelessWidget {
  const AdminCardHeader(
      {super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminText.h2()),
                if (subtitle != null) ...[
                  const SizedBox(height: 2.0),
                  Text(subtitle!, style: AdminText.label(size: 12.5)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pastille d'icône sur fond teinté (cartes chiffrées, en-têtes).
class AdminIconBadge extends StatelessWidget {
  const AdminIconBadge(this.icon,
      {super.key,
      this.color = AdminColors.red,
      this.background,
      this.size = 46.0,
      this.round = true});

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(round ? size / 2 : AdminRadius.md),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

/// Évolution en % avec flèche (vert si hausse, rouge si baisse).
class AdminTrend extends StatelessWidget {
  const AdminTrend(this.percent, {super.key, this.inverse = false});

  /// null : pas de comparaison possible.
  final double? percent;

  /// Une hausse est mauvaise (ex. temps de livraison).
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final p = percent;
    if (p == null) return const SizedBox.shrink();
    final up = p >= 0;
    final good = inverse ? !up : up;
    final color = p == 0
        ? AdminColors.grey
        : good
            ? AdminColors.green
            : AdminColors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
            p == 0
                ? Icons.remove_rounded
                : up
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
            size: 14.0,
            color: color),
        const SizedBox(width: 2.0),
        Text('${p.abs().toStringAsFixed(p.abs() < 10 ? 1 : 0)} %',
            style: AdminText.strong(color: color, size: 12.5)),
      ],
    );
  }
}

/// Carte chiffrée : icône, libellé, valeur, évolution.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AdminColors.red,
    this.trend,
    this.trendInverse = false,
    this.caption,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double? trend;
  final bool trendInverse;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18.0),
      child: Row(
        children: [
          AdminIconBadge(icon, color: color, size: 52.0),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.label()),
                const SizedBox(height: 4.0),
                Wrap(
                  spacing: 8.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(value, style: AdminText.display()),
                    AdminTrend(trend, inverse: trendInverse),
                  ],
                ),
                if (caption != null) ...[
                  const SizedBox(height: 4.0),
                  Text(caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(
                          color: AdminColors.faint, size: 12.0)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef AdminTone = ({Color fg, Color bg});

const kToneGreen = (fg: AdminColors.green, bg: AdminColors.greenSoft);
const kToneOrange = (fg: AdminColors.orange, bg: AdminColors.orangeSoft);
const kToneBlue = (fg: AdminColors.blue, bg: AdminColors.blueSoft);
const kToneViolet = (fg: AdminColors.violet, bg: AdminColors.violetSoft);
const kToneRed = (fg: AdminColors.red, bg: AdminColors.redSoft);
const kToneGrey = (fg: AdminColors.grey, bg: AdminColors.greySoft);

/// Pastille de statut (texte + point de couleur).
class AdminBadge extends StatelessWidget {
  const AdminBadge(this.label, {super.key, this.tone = kToneGrey});

  final String label;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.0,
            height: 6.0,
            decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6.0),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminText.strong(color: tone.fg, size: 12.0)),
          ),
        ],
      ),
    );
  }
}

/// Petit bouton d'action rond (voir, modifier, supprimer) des tableaux.
class AdminActionDot extends StatelessWidget {
  const AdminActionDot({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tone = kToneBlue,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tone.bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34.0,
            height: 34.0,
            child: Icon(icon, size: 17.0, color: tone.fg),
          ),
        ),
      ),
    );
  }
}

/// Liste déroulante compacte en pastille (période, filtres).
class AdminSelect<T> extends StatelessWidget {
  const AdminSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final e in items.entries)
          PopupMenuItem(
            value: e.key,
            child: Text(e.value,
                style: AdminText.body(
                    color: e.key == value ? AdminColors.red : AdminColors.ink)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminRadius.md),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17.0, color: AdminColors.muted),
              const SizedBox(width: 8.0),
            ],
            Flexible(
              child: Text(items[value] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.label(color: AdminColors.text)),
            ),
            const SizedBox(width: 6.0),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18.0, color: AdminColors.muted),
          ],
        ),
      ),
    );
  }
}

/// États de chargement, vide et erreur.
class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key, this.height = 160.0});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(
            child: SizedBox(
                width: 26.0,
                height: 26.0,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AdminColors.red))),
      );
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminIconBadge(icon,
              color: AdminColors.faint,
              background: AdminColors.greySoft,
              size: 60.0),
          const SizedBox(height: 14.0),
          Text(title, style: AdminText.h2(), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4.0),
            Text(message!,
                style: AdminText.label(), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 10.0), action!],
        ],
      ),
    );
  }
}

/// Initiales d'un nom, pour les avatars sans photo.
String adminInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts[1].characters.first : '';
  return (first + second).toUpperCase();
}

/// Avatar rond : photo si disponible, sinon initiales sur fond teinté.
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.name, this.photo, this.size = 38.0});

  final String name;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          color: AdminColors.redSoft, shape: BoxShape.circle),
      child: Text(adminInitials(name),
          style: AdminText.strong(color: AdminColors.red, size: size * 0.36)),
    );
    final p = photo ?? '';
    if (!p.startsWith('http')) return initials;
    return ClipOval(
      child: Image.network(p,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initials),
    );
  }
}
