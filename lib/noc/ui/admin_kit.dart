import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Charte graphique de l'administration Kitunga (indépendante de
/// FlutterFlow) : couleurs tirées du logo, typographie Inter, espacements,
/// arrondis et ombres. Toutes les pages admin s'appuient dessus.
class AdminColors {
  AdminColors._();

  /// Mode sombre actif (fixé par [AdminThemeScope] avant chaque construction).
  static bool dark = false;

  static Color _m(int light, int darkValue) => Color(dark ? darkValue : light);

  // Marque (identique dans les deux modes)
  static const red = Color(0xFFE51A1A);
  static const redDeep = Color(0xFFB31212);

  // Fonds et surfaces
  static Color get page => _m(0xFFF2F3F7, 0xFF0E1014);
  static Color get panel => _m(0xFFE9EBF1, 0xFF1B1E25);
  static Color get surface => _m(0xFFFFFFFF, 0xFF171A21);
  static Color get surfaceAlt => _m(0xFFF7F8FB, 0xFF1E2129);
  static Color get border => _m(0xFFE6E8EE, 0xFF2A2E38);

  // Textes
  static Color get ink => _m(0xFF16181D, 0xFFF3F4F7);
  static Color get text => _m(0xFF3B3F47, 0xFFCBCFD7);
  static Color get muted => _m(0xFF6F737C, 0xFF9AA0AB);
  static Color get faint => _m(0xFFA2A6AE, 0xFF6E7481);

  // Statuts et graphiques : couleurs vives, fonds teintés transparents
  // (lisibles sur fond clair comme sur fond sombre).
  static const green = Color(0xFF17A35B);
  static const greenSoft = Color(0x2617A35B);
  static const orange = Color(0xFFE38B00);
  static const orangeSoft = Color(0x29E38B00);
  static const blue = Color(0xFF2F6FDB);
  static const blueSoft = Color(0x262F6FDB);
  static const violet = Color(0xFF7458E0);
  static const violetSoft = Color(0x297458E0);
  static const teal = Color(0xFF14A3A3);
  static const grey = Color(0xFF8A8F98);
  static const greySoftConst = Color(0x248A8F98);
  static const redSoft = Color(0x1FE51A1A);
  static Color get greySoft => _m(0xFFF0F1F4, 0xFF242832);
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

  static TextStyle display({Color? color}) =>
      GoogleFonts.interTight(
          color: color ?? AdminColors.ink, fontSize: 28.0, fontWeight: FontWeight.w800, height: 1.1);

  static TextStyle h1({Color? color}) => GoogleFonts.interTight(
      color: color ?? AdminColors.ink, fontSize: 22.0, fontWeight: FontWeight.w800);

  static TextStyle h2({Color? color}) => GoogleFonts.interTight(
      color: color ?? AdminColors.ink, fontSize: 16.0, fontWeight: FontWeight.w700);

  static TextStyle body({Color? color, double size = 14.0}) =>
      GoogleFonts.inter(color: color ?? AdminColors.text, fontSize: size, height: 1.4);

  static TextStyle label({Color? color, double size = 13.0}) =>
      GoogleFonts.inter(
          color: color ?? AdminColors.muted, fontSize: size, fontWeight: FontWeight.w500, height: 1.3);

  static TextStyle strong({Color? color, double size = 14.0}) =>
      GoogleFonts.inter(
          color: color ?? AdminColors.ink, fontSize: size, fontWeight: FontWeight.w700, height: 1.3);

  static TextStyle caps({Color? color}) => GoogleFonts.inter(
      color: color ?? AdminColors.faint,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8);
}

/// Thème Material des pages admin (boutons, champs, menus, fenêtres).
ThemeData adminTheme(ThemeData base) {
  final brightness = AdminColors.dark ? Brightness.dark : Brightness.light;
  // Surfaces de la charte (pas de teinte Material 3 sur fenêtres et menus).
  final scheme = ColorScheme.fromSeed(
    seedColor: AdminColors.red,
    primary: AdminColors.red,
    surface: AdminColors.surface,
    brightness: brightness,
  ).copyWith(
    primary: AdminColors.red,
    onPrimary: Colors.white,
    surface: AdminColors.surface,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: AdminColors.surface,
    surfaceContainerLow: AdminColors.surface,
    surfaceContainer: AdminColors.surface,
    surfaceContainerHigh: AdminColors.surface,
    surfaceContainerHighest: AdminColors.surfaceAlt,
    onSurface: AdminColors.ink,
    onSurfaceVariant: AdminColors.muted,
    outline: AdminColors.border,
    outlineVariant: AdminColors.border,
  );
  OutlineInputBorder border(Color c, [double w = 1.0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.md),
        borderSide: BorderSide(color: c, width: w),
      );
  return base.copyWith(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: AdminColors.page,
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AdminColors.text, displayColor: AdminColors.ink),
    iconTheme: IconThemeData(color: AdminColors.muted),
    canvasColor: AdminColors.surface,
    cardColor: AdminColors.surface,
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AdminColors.surface)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: AdminColors.text,
      iconColor: AdminColors.muted,
    ),
    checkboxTheme: base.checkboxTheme,
    dividerColor: AdminColors.border,
    dividerTheme:
        DividerThemeData(color: AdminColors.border, thickness: 1.0),
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
        side: BorderSide(color: AdminColors.border),
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
      side: BorderSide(color: AdminColors.border),
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
          color: const Color(0xFF23262E),
          borderRadius: BorderRadius.circular(AdminRadius.sm)),
      textStyle: AdminText.label(color: Colors.white, size: 12.0),
    ),
  );
}

/// Mode sombre de l'administration (choix mémorisé sur cet appareil).
final adminDarkMode = ValueNotifier<bool>(false);
const _kDarkPref = 'kitunga_admin_dark';
bool _darkLoaded = false;

/// Lit le choix enregistré (une seule fois).
Future<void> loadAdminDarkMode() async {
  if (_darkLoaded) return;
  _darkLoaded = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    adminDarkMode.value = prefs.getBool(_kDarkPref) ?? false;
  } catch (_) {
    // Préférences indisponibles : mode clair.
  }
}

/// Bascule clair / sombre et mémorise le choix.
Future<void> toggleAdminDarkMode() async {
  adminDarkMode.value = !adminDarkMode.value;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkPref, adminDarkMode.value);
  } catch (_) {}
}

/// Applique le thème admin (clair ou sombre) à une page et aux fenêtres
/// qu'elle ouvre. Au changement de mode, toute la page est reconstruite.
class AdminThemeScope extends StatefulWidget {
  const AdminThemeScope({super.key, required this.child});

  final Widget child;

  @override
  State<AdminThemeScope> createState() => _AdminThemeScopeState();
}

class _AdminThemeScopeState extends State<AdminThemeScope> {
  @override
  void initState() {
    super.initState();
    loadAdminDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adminDarkMode,
      builder: (context, dark, _) {
        AdminColors.dark = dark;
        return Theme(
          data: adminTheme(Theme.of(context)),
          child: KeyedSubtree(key: ValueKey(dark), child: widget.child),
        );
      },
    );
  }
}

// ── Composants ───────────────────────────────────────────────────────────

/// Carte blanche arrondie à ombre douce.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminRadius.lg),
        boxShadow: kAdminShadow,
      ),
      child: Material(
        color: color ?? AdminColors.surface,
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
const kToneGrey = (fg: AdminColors.grey, bg: AdminColors.greySoftConst);

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
            Icon(Icons.keyboard_arrow_down_rounded,
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
