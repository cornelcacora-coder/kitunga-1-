import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/index.dart' show IntroWidget;
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/components/kitunga_logo/kitunga_logo_widget.dart';
import '/noc/n_o_c_alert/n_o_c_alert_widget.dart';
import '/noc/n_o_c_delivery/n_o_c_delivery_widget.dart';
import '/noc/n_o_c_orders/n_o_c_orders_widget.dart';
import '/noc/noc_cta/noc_cta_widget.dart';
import '/noc/noc_missing_images/noc_missing_images_widget.dart';
import '/noc/sales/sales_common.dart';

/// Menu de l'administration, regroupé en sections dépliables. Une entrée
/// ouvre soit une page (route), soit un panneau (fenêtre du tableau de bord).
class AdminNavItem {
  const AdminNavItem(this.key, this.label, this.icon, {this.path, this.sheet});

  final String key;
  final String label;
  final IconData icon;
  final String? path;
  final Widget Function()? sheet;
}

class AdminNavGroup {
  const AdminNavGroup(this.label, this.icon, this.items);

  final String label;
  final IconData icon;
  final List<AdminNavItem> items;
}

/// Adresses des pages (aussi déclarées dans nav.dart et web_admin_only.dart).
class AdminPaths {
  static const dashboard = '/supervisionDashboard';
  static const categories = '/categories';
  static const products = '/produits';
  static const sellers = '/commercants';
  static const delivers = '/livreurs';
  static const clients = '/clients';
  static const ops = '/gestion';
  static const sales = '/commercial';
}

final List<AdminNavGroup> kAdminMenu = [
  AdminNavGroup('Opérations', Icons.local_shipping_outlined, [
    AdminNavItem('orders', 'Commandes', Icons.shopping_cart_outlined,
        sheet: () => const NOCOrdersWidget()),
    AdminNavItem('deliveries', 'Livraisons', Icons.history_rounded,
        sheet: () => const NOCDeliveryWidget()),
    AdminNavItem('zones', 'Livraisons par zone', Icons.place_outlined,
        sheet: () => const NocCtaWidget()),
    AdminNavItem('alerts', 'Alertes critiques', Icons.warning_amber_rounded,
        sheet: () => const NOCAlertWidget()),
  ]),
  AdminNavGroup('Catalogue', Icons.inventory_2_outlined, [
    const AdminNavItem('categories', 'Catégories', Icons.category_outlined,
        path: AdminPaths.categories),
    const AdminNavItem('products', 'Produits', Icons.shopping_bag_outlined,
        path: AdminPaths.products),
    AdminNavItem('missing', 'Fiches à compléter', Icons.hide_image_outlined,
        sheet: () => const NOCMissingImagesWidget()),
  ]),
  const AdminNavGroup('Partenaires', Icons.handshake_outlined, [
    AdminNavItem('sellers', 'Commerçants & boutiques', Icons.storefront_outlined,
        path: AdminPaths.sellers),
    AdminNavItem('delivers', 'Livreurs', Icons.delivery_dining_outlined,
        path: AdminPaths.delivers),
  ]),
  const AdminNavGroup('Clients', Icons.people_outline_rounded, [
    AdminNavItem('clients', 'Clients', Icons.person_outline_rounded,
        path: AdminPaths.clients),
  ]),
  const AdminNavGroup('Gestion', Icons.admin_panel_settings_outlined, [
    AdminNavItem('ops', 'Remboursements & comptes',
        Icons.account_balance_wallet_outlined,
        path: AdminPaths.ops),
    AdminNavItem('sales', 'Module commercial', Icons.campaign_outlined,
        path: AdminPaths.sales),
  ]),
];

/// Menu latéral : vue d'ensemble puis sections dépliables. La section de la
/// page ouverte est dépliée d'office et son entrée mise en avant.
class KitungaAdminSidebar extends StatelessWidget {
  const KitungaAdminSidebar({super.key, required this.current});

  /// Clé de l'entrée active ('dashboard' pour le tableau de bord).
  final String current;

  void _open(BuildContext context, AdminNavItem item) {
    // Dans un tiroir (petit écran), on le ferme d'abord.
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) Navigator.of(context).pop();
    if (item.sheet != null) {
      showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: false,
        context: context,
        builder: (context) => Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: item.sheet!(),
        ),
      );
    } else if (item.path != null && item.key != current) {
      context.go(item.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _NavTile(
          label: 'Vue d\'ensemble',
          icon: Icons.grid_view_rounded,
          selected: current == 'dashboard',
          onTap: () {
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold?.isDrawerOpen ?? false) Navigator.of(context).pop();
            if (current != 'dashboard') context.go(AdminPaths.dashboard);
          },
        ),
        const SizedBox(height: 4.0),
        for (final g in kAdminMenu)
          _NavGroup(
            group: g,
            current: current,
            onOpen: (item) => _open(context, item),
          ),
      ],
    );
  }
}

class _NavGroup extends StatefulWidget {
  const _NavGroup(
      {required this.group, required this.current, required this.onOpen});

  final AdminNavGroup group;
  final String current;
  final void Function(AdminNavItem) onOpen;

  @override
  State<_NavGroup> createState() => _NavGroupState();
}

class _NavGroupState extends State<_NavGroup> {
  late bool _open = widget.group.items.any((i) => i.key == widget.current);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final active = widget.group.items.any((i) => i.key == widget.current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Icon(widget.group.icon,
                    size: 20.0, color: active ? kSalesRed : theme.primaryText),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Text(widget.group.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: theme.primaryText,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700)),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more_rounded,
                      size: 20.0, color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 18.0, bottom: 6.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                          left: BorderSide(color: theme.alternate, width: 1.5)),
                    ),
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in widget.group.items)
                          _NavTile(
                            label: item.label,
                            icon: item.icon,
                            dense: true,
                            external: item.sheet != null,
                            selected: item.key == widget.current,
                            onTap: () => widget.onOpen(item),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.dense = false,
    this.external = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool dense;

  /// Ouvre un panneau par-dessus la page (et non une nouvelle page).
  final bool external;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = selected ? kSalesRed : theme.primaryText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Material(
        color: selected ? kSalesRed.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: dense ? 12.0 : 16.0, vertical: dense ? 10.0 : 14.0),
            child: Row(
              children: [
                Icon(icon, size: dense ? 18.0 : 20.0, color: color),
                SizedBox(width: dense ? 10.0 : 14.0),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: color,
                          fontSize: dense ? 13.5 : 14.0,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (external)
                  Icon(Icons.open_in_new_rounded,
                      size: 14.0, color: theme.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Déconnexion de l'administrateur (même logique que le tableau de bord).
Future<void> adminSignOut(BuildContext context) async {
  GoRouter.of(context).prepareAuthEvent();
  await authManager.signOut();
  GoRouter.of(context).clearRedirectLocation();
  if (context.mounted) {
    context.pushNamedAuth(IntroWidget.routeName, context.mounted);
  }
}

/// Cadre des pages d'administration : menu latéral sur ordinateur, tiroir
/// sur petit écran, en-tête avec titre et actions.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.current,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.body,
  });

  final String current;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;

  static const wideBreakpoint = 1000.0;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final sidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 20.0),
          child: Row(
            children: [
              const KitungaLogo(size: 40.0),
              const SizedBox(width: 12.0),
              Text('KITUNGA',
                  style: GoogleFonts.interTight(
                      color: theme.primary,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: KitungaAdminSidebar(current: current),
          ),
        ),
        const Divider(height: 1.0),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: _NavTile(
            label: 'Déconnexion',
            icon: Icons.logout_rounded,
            selected: false,
            onTap: () => adminSignOut(context),
          ),
        ),
      ],
    );

    final header = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28.0 : 16.0, 20.0, 16.0, 12.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: salesTitle(wide ? 24.0 : 20.0)),
              if (subtitle != null) ...[
                const SizedBox(height: 2.0),
                Text(subtitle!, style: salesBody()),
              ],
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: 8.0, runSpacing: 8.0, children: actions),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, Expanded(child: body)],
    );

    if (wide) {
      return Scaffold(
        backgroundColor: kSalesSurface,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 270.0,
              color: theme.primaryBackground,
              child: sidebar,
            ),
            const VerticalDivider(width: 1.0, color: Color(0xFFE9E9EE)),
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: kSalesSurface,
      appBar: AppBar(
        backgroundColor: kSalesRed,
        foregroundColor: Colors.white,
        elevation: 0.0,
        title: Row(
          children: [
            Image.asset('assets/logo/kitunga_logo_white.png', height: 28.0),
            const SizedBox(width: 10.0),
            Flexible(
              child: Text('Administration',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.interTight(
                      fontWeight: FontWeight.w800, fontSize: 18.0)),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: theme.primaryBackground,
        child: SafeArea(child: sidebar),
      ),
      body: content,
    );
  }
}

// ── Images ───────────────────────────────────────────────────────────────

/// Image d'une catégorie, d'un produit ou d'un partenaire : image incluse
/// dans l'application (« asset:… ») ou adresse en ligne.
class AdminImage extends StatelessWidget {
  const AdminImage(this.src,
      {super.key,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.icon = Icons.image_outlined});

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('asset:')) {
      return Image.asset(src.substring(6),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _empty());
    }
    if (src.startsWith('http')) {
      return KitungaImage(src,
          width: width, height: height, fallbackIcon: icon, placeholder: _empty());
    }
    return _empty();
  }

  Widget _empty() => Container(
        width: width,
        height: height,
        color: const Color(0xFFEDEDF1),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFFA5A8B0), size: 26.0),
      );
}

/// Remplace le choix d'image dans les tests (adresse renvoyée directement).
@visibleForTesting
Future<String?> Function()? adminImagePickerOverride;

/// Choisit une image dans la galerie et l'envoie dans le dossier de l'admin
/// (Firebase Storage). Renvoie son adresse, ou null si annulé ou en échec.
Future<String?> pickAdminImage(BuildContext context) async {
  if (adminImagePickerOverride != null) return adminImagePickerOverride!();
  final messenger = ScaffoldMessenger.of(context);
  final files = await selectMedia(
    mediaSource: MediaSource.photoGallery,
    maxWidth: 1600.0,
    imageQuality: 85,
  );
  if (files == null || files.isEmpty) return null;
  final file = files.first;
  if (!context.mounted || !validateFileFormat(file.storagePath, context)) {
    return null;
  }
  if (file.bytes.length > 10 * 1024 * 1024) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Image trop lourde (10 Mo au maximum).'),
        backgroundColor: kSalesDeepRed));
    return null;
  }
  messenger.showSnackBar(const SnackBar(
      content: Text('Envoi de l\'image…'), duration: Duration(seconds: 2)));
  try {
    final url = await uploadData(file.storagePath, file.bytes);
    if (url == null) throw 'échec';
    return url;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('L\'image n\'a pas pu être envoyée. Réessayez.'),
        backgroundColor: kSalesDeepRed));
    return null;
  }
}

/// Zone d'image d'un formulaire : aperçu et bouton « Changer l'image ».
class AdminImageField extends StatelessWidget {
  const AdminImageField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.height = 140.0,
    this.background,
    this.fit = BoxFit.cover,
    this.allowRemove = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final double height;
  final Color? background;
  final BoxFit fit;
  final bool allowRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: salesBody(color: kSalesInk, size: 13.0)),
        const SizedBox(height: 6.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            height: height,
            width: double.infinity,
            color: background ?? const Color(0xFFEDEDF1),
            padding: fit == BoxFit.contain ? const EdgeInsets.all(12.0) : null,
            child: AdminImage(value, height: height, fit: fit),
          ),
        ),
        const SizedBox(height: 6.0),
        Wrap(
          spacing: 8.0,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined, size: 18.0),
              label: Text(value.isEmpty ? 'Ajouter une image' : 'Changer l\'image'),
              style: OutlinedButton.styleFrom(foregroundColor: kSalesRed),
              onPressed: () async {
                final url = await pickAdminImage(context);
                if (url != null) onChanged(url);
              },
            ),
            if (allowRemove && value.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(''),
                child: const Text('Retirer'),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Éléments communs des listes ──────────────────────────────────────────

/// Barre de recherche des listes.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField(
      {super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320.0,
      child: TextField(
        onChanged: onChanged,
        decoration: salesInput('Rechercher', hint: hint).copyWith(
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

/// Menu d'actions d'une ligne : voir, modifier, supprimer, etc.
class AdminRowActions extends StatelessWidget {
  const AdminRowActions({super.key, required this.actions});

  final List<({String label, IconData icon, VoidCallback onTap, bool danger})>
      actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: kSalesMuted),
      onSelected: (i) => actions[i].onTap(),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actions[i].icon,
                    size: 18.0,
                    color: actions[i].danger ? kSalesRed : kSalesInk),
                const SizedBox(width: 10.0),
                Flexible(
                  child: Text(actions[i].label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: actions[i].danger ? kSalesRed : kSalesInk)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

typedef AdminAction = ({
  String label,
  IconData icon,
  VoidCallback onTap,
  bool danger
});

AdminAction viewAction(VoidCallback f) =>
    (label: 'Voir', icon: Icons.visibility_outlined, onTap: f, danger: false);
AdminAction editAction(VoidCallback f) =>
    (label: 'Modifier', icon: Icons.edit_outlined, onTap: f, danger: false);
AdminAction deleteAction(VoidCallback f, {String label = 'Supprimer'}) =>
    (label: label, icon: Icons.delete_outline_rounded, onTap: f, danger: true);

/// Bouton principal d'une page (« Ajouter … »).
Widget adminAddButton(String label, VoidCallback onPressed) =>
    FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: kSalesRed,
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
      ),
      icon: const Icon(Icons.add_rounded),
      label: Text(label),
      onPressed: onPressed,
    );

/// Fenêtre de formulaire (titre, contenu défilant, boutons).
class AdminFormDialog extends StatelessWidget {
  const AdminFormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saving = false,
    this.saveLabel = 'Enregistrer',
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 12.0, 8.0),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: salesTitle(19.0))),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in children) ...[
                      c,
                      const SizedBox(height: 14.0),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 20.0),
              // Passe à la ligne sur un écran étroit au lieu de déborder.
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kSalesRed),
                    onPressed: saving ? null : onSave,
                    child: saving
                        ? const SizedBox(
                            width: 18.0,
                            height: 18.0,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.0, color: Colors.white))
                        : Text(saveLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé : valeur » des fiches.
class AdminInfoRow extends StatelessWidget {
  const AdminInfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130.0,
              child: Text(label, style: salesBody(size: 13.0))),
          Expanded(
            child: Text(value.trim().isEmpty ? '—' : value,
                style: salesBody(color: kSalesInk, size: 13.5)),
          ),
        ],
      ),
    );
  }
}

/// Confirmation simple. true si confirmé.
Future<bool> adminConfirm(BuildContext context,
    {required String title,
    required String message,
    String confirm = 'Supprimer'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Statut d'un compte (champ account_status).
const accountStatusStyle = <String, StatusStyle>{
  'active': (label: 'Actif', color: Color(0xFF1E9E5A)),
  'suspended': (label: 'Suspendu', color: Color(0xFFE08A00)),
};

/// Nombre entier saisi (vide = null).
int? parseInt(String v) =>
    int.tryParse(v.replaceAll(RegExp(r'[\s  .]'), ''));

/// Page rafraîchie quand l'admin revient sur l'onglet.
typedef AdminReload = void Function();

/// Indique le nombre d'éléments affichés.
String countLabel(int n, String singular, String plural) =>
    '$n ${n > 1 ? plural : singular}';

/// Formulaire : ligne de deux champs sur grand écran, une colonne sinon.
class AdminFieldRow extends StatelessWidget {
  const AdminFieldRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 420.0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 14.0),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12.0),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }
}

/// Dernière mise à jour d'une donnée (pour les en-têtes de liste).
String nowLabel() => 'Mis à jour à ${DateFormat('HH:mm', 'fr').format(DateTime.now())}';
