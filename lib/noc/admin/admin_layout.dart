import 'dart:async';

import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart' show IntroWidget;
import '/noc/ui/admin_kit.dart';

/// Cadre de l'administration : menu latéral à sections dépliables (réductible
/// en icônes), barre du haut (recherche de page, notifications, compte) et
/// en-tête de page. Sur petit écran, le menu passe en tiroir.

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
  static const orders = '/commandes';
  static const deliveries = '/livraisons';
  static const zones = '/zones';
  static const alerts = '/alertes';
  static const missingImages = '/produits?sansImage=1';
}

const kDashboardItem = AdminNavItem(
    'dashboard', 'Tableau de bord', Icons.space_dashboard_rounded,
    path: AdminPaths.dashboard);

const List<AdminNavGroup> kAdminMenu = [
  const AdminNavGroup('Opérations', Icons.local_shipping_rounded, [
    AdminNavItem('orders', 'Commandes', Icons.receipt_long_rounded,
        path: AdminPaths.orders),
    AdminNavItem('deliveries', 'Livraisons', Icons.delivery_dining_rounded,
        path: AdminPaths.deliveries),
    AdminNavItem('zones', 'Livraisons par zone', Icons.place_rounded,
        path: AdminPaths.zones),
    AdminNavItem('alerts', 'Alertes', Icons.warning_amber_rounded,
        path: AdminPaths.alerts),
  ]),
  const AdminNavGroup('Catalogue', Icons.inventory_2_rounded, [
    AdminNavItem('categories', 'Catégories', Icons.category_rounded,
        path: AdminPaths.categories),
    AdminNavItem('products', 'Produits', Icons.shopping_bag_rounded,
        path: AdminPaths.products),
    AdminNavItem('missing', 'Produits sans photo', Icons.hide_image_rounded,
        path: AdminPaths.missingImages),
  ]),
  const AdminNavGroup('Partenaires', Icons.handshake_rounded, [
    AdminNavItem('sellers', 'Commerçants & boutiques', Icons.storefront_rounded,
        path: AdminPaths.sellers),
    AdminNavItem('delivers', 'Livreurs', Icons.two_wheeler_rounded,
        path: AdminPaths.delivers),
  ]),
  const AdminNavGroup('Clients', Icons.people_alt_rounded, [
    AdminNavItem('clients', 'Clients', Icons.person_rounded,
        path: AdminPaths.clients),
  ]),
  const AdminNavGroup('Gestion', Icons.admin_panel_settings_rounded, [
    AdminNavItem('ops', 'Remboursements & comptes',
        Icons.account_balance_wallet_rounded,
        path: AdminPaths.ops),
    AdminNavItem('sales', 'Module commercial', Icons.campaign_rounded,
        path: AdminPaths.sales),
  ]),
];

/// Toutes les entrées, pour la recherche de page.
List<AdminNavItem> get kAdminNavItems =>
    [kDashboardItem, for (final g in kAdminMenu) ...g.items];

/// Ouvre une entrée du menu : une page (adresse) ou un panneau.
void openAdminItem(BuildContext context, AdminNavItem item,
    {required String current}) {
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

/// Déconnexion de l'administrateur.
Future<void> adminSignOut(BuildContext context) async {
  GoRouter.of(context).prepareAuthEvent();
  await authManager.signOut();
  GoRouter.of(context).clearRedirectLocation();
  if (context.mounted) {
    context.pushNamedAuth(IntroWidget.routeName, context.mounted);
  }
}

/// Menu réduit en icônes (mémorisé pendant la session).
final adminSidebarCollapsed = ValueNotifier<bool>(false);

/// Nombre de commandes à confirmer (cloche) ; remplaçable dans les tests.
Stream<int> Function() adminPendingOrders = () => queryOrdersRecord(
      queryBuilder: (q) =>
          q.where('status', whereIn: OrderStatus.inProgress.take(2).toList()),
    ).map((l) => l.length);

/// Nom affiché de l'admin connecté ; remplaçable dans les tests.
String Function() adminDisplayName = () {
  try {
    final n = currentUserDisplayName.trim();
    if (n.isNotEmpty) return n;
    final e = currentUserEmail.trim();
    return e.isNotEmpty ? e.split('@').first : 'Administrateur';
  } catch (_) {
    return 'Administrateur';
  }
};

// ── Menu latéral ─────────────────────────────────────────────────────────

class KitungaAdminSidebar extends StatelessWidget {
  const KitungaAdminSidebar(
      {super.key, required this.current, this.collapsed = false});

  final String current;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo
          Padding(
            padding: EdgeInsets.fromLTRB(
                collapsed ? 0 : 24.0, 26.0, collapsed ? 0 : 20.0, 22.0),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 42.0,
                  height: 42.0,
                  padding: const EdgeInsets.all(7.0),
                  decoration: BoxDecoration(
                    color: AdminColors.red,
                    borderRadius: BorderRadius.circular(AdminRadius.md),
                    boxShadow: adminGlow(AdminColors.red),
                  ),
                  child: Image.asset('assets/logo/kitunga_logo_white.png',
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white)),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kitunga', style: AdminText.h1(color: AdminColors.ink)),
                      Text('Administration',
                          style: AdminText.label(size: 12.0)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 14.0 : 16.0),
              children: [
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10.0, 4.0, 0, 10.0),
                    child: Text('MENU', style: AdminText.caps()),
                  ),
                _NavTile(
                  item: kDashboardItem,
                  selected: current == 'dashboard',
                  collapsed: collapsed,
                  onTap: () =>
                      openAdminItem(context, kDashboardItem, current: current),
                ),
                const SizedBox(height: 6.0),
                for (final g in kAdminMenu)
                  _NavGroup(group: g, current: current, collapsed: collapsed),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                collapsed ? 14.0 : 16.0, 8.0, collapsed ? 14.0 : 16.0, 20.0),
            child: _NavTile(
              item: const AdminNavItem(
                  'logout', 'Déconnexion', Icons.logout_rounded),
              selected: false,
              collapsed: collapsed,
              onTap: () => adminSignOut(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavGroup extends StatefulWidget {
  const _NavGroup(
      {required this.group, required this.current, required this.collapsed});

  final AdminNavGroup group;
  final String current;
  final bool collapsed;

  @override
  State<_NavGroup> createState() => _NavGroupState();
}

class _NavGroupState extends State<_NavGroup> {
  late bool _open = widget.group.items.any((i) => i.key == widget.current);

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final active = g.items.any((i) => i.key == widget.current);

    // Menu réduit : l'icône du groupe ouvre ses entrées dans un menu.
    if (widget.collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: PopupMenuButton<AdminNavItem>(
          tooltip: g.label,
          position: PopupMenuPosition.over,
          offset: const Offset(64, 0),
          onSelected: (i) => openAdminItem(context, i, current: widget.current),
          itemBuilder: (_) => [
            PopupMenuItem<AdminNavItem>(
              enabled: false,
              child: Text(g.label.toUpperCase(), style: AdminText.caps()),
            ),
            for (final i in g.items)
              PopupMenuItem(
                value: i,
                child: Row(
                  children: [
                    Icon(i.icon,
                        size: 18.0,
                        color: i.key == widget.current
                            ? AdminColors.red
                            : AdminColors.muted),
                    const SizedBox(width: 10.0),
                    Text(i.label, style: AdminText.body()),
                  ],
                ),
              ),
          ],
          child: Container(
            height: 48.0,
            decoration: BoxDecoration(
              color: active ? AdminColors.redSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AdminRadius.md),
            ),
            child: Icon(g.icon,
                size: 22.0, color: active ? AdminColors.red : AdminColors.muted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AdminRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AdminRadius.md),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
                child: Row(
                  children: [
                    Icon(g.icon,
                        size: 21.0,
                        color: active ? AdminColors.red : AdminColors.muted),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Text(g.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.strong(
                              color: active ? AdminColors.ink : AdminColors.text)),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20.0, color: AdminColors.faint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 24.0, bottom: 6.0),
                  child: Container(
                    padding: const EdgeInsets.only(left: 10.0),
                    decoration: const BoxDecoration(
                      border: Border(
                          left: BorderSide(color: AdminColors.border, width: 2.0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in g.items)
                          _NavTile(
                            item: item,
                            dense: true,
                            selected: item.key == widget.current,
                            onTap: () => openAdminItem(context, item,
                                current: widget.current),
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
    required this.item,
    required this.selected,
    required this.onTap,
    this.dense = false,
    this.collapsed = false,
  });

  final AdminNavItem item;
  final bool selected;
  final bool dense;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Entrée active : pastille rouge pleine avec une ombre colorée.
    final strong = selected && !dense;
    final fg = strong
        ? Colors.white
        : selected
            ? AdminColors.red
            : AdminColors.text;
    final tile = Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      decoration: BoxDecoration(
        color: strong
            ? AdminColors.red
            : selected
                ? AdminColors.redSoft
                : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminRadius.md),
        boxShadow: strong ? adminGlow(AdminColors.red) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AdminRadius.md),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : (dense ? 12.0 : 14.0),
                vertical: dense ? 10.0 : 13.0),
            child: collapsed
                ? Icon(item.icon, size: 22.0, color: strong ? Colors.white : AdminColors.muted)
                : Row(
                    children: [
                      Icon(item.icon,
                          size: dense ? 18.0 : 21.0,
                          color: strong || selected ? fg : AdminColors.muted),
                      SizedBox(width: dense ? 10.0 : 14.0),
                      Expanded(
                        child: Text(item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: dense
                                ? AdminText.label(color: fg, size: 13.5)
                                    .copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500)
                                : AdminText.strong(color: fg)),
                      ),
                      if (item.sheet != null)
                        Icon(Icons.open_in_new_rounded,
                            size: 13.0,
                            color: AdminColors.faint.withValues(alpha: 0.8)),
                    ],
                  ),
          ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: item.label, child: tile) : tile;
  }
}

// ── Barre du haut ────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide, required this.current});

  final bool wide;
  final String current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28.0 : 12.0, 16.0, wide ? 28.0 : 12.0, 8.0),
      child: Row(
        children: [
          _CircleButton(
            icon: wide ? Icons.menu_open_rounded : Icons.menu_rounded,
            tooltip: wide ? 'Réduire ou agrandir le menu' : 'Menu',
            onTap: () => wide
                ? adminSidebarCollapsed.value = !adminSidebarCollapsed.value
                : Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 14.0),
          if (wide)
            Flexible(child: _PageSearch(current: current))
          else
            const Spacer(),
          if (wide) const Spacer(),
          const SizedBox(width: 12.0),
          _Notifications(current: current),
          const SizedBox(width: 12.0),
          _AccountMenu(wide: wide),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AdminColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AdminColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 44.0,
              height: 44.0,
              child: Icon(icon, size: 21.0, color: AdminColors.text)),
        ),
      ),
    );
  }
}

/// Recherche d'une page de l'administration (« Aller à… »).
class _PageSearch extends StatelessWidget {
  const _PageSearch({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420.0),
      child: Autocomplete<AdminNavItem>(
        displayStringForOption: (i) => i.label,
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          if (q.isEmpty) return const [];
          return kAdminNavItems.where((i) => i.label.toLowerCase().contains(q));
        },
        onSelected: (i) {
          FocusScope.of(context).unfocus();
          openAdminItem(context, i, current: current);
        },
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          onSubmitted: (_) => onSubmit(),
          style: AdminText.body(),
          decoration: InputDecoration(
            hintText: 'Rechercher une page…',
            prefixIcon: const Icon(Icons.search_rounded,
                size: 20.0, color: AdminColors.faint),
            filled: true,
            fillColor: AdminColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 13.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdminRadius.pill),
              borderSide: const BorderSide(color: AdminColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdminRadius.pill),
              borderSide: const BorderSide(color: AdminColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdminRadius.pill),
              borderSide: const BorderSide(color: AdminColors.red, width: 1.5),
            ),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6.0,
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(AdminRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420.0, maxHeight: 300.0),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                shrinkWrap: true,
                children: [
                  for (final i in options)
                    ListTile(
                      dense: true,
                      leading: Icon(i.icon, size: 20.0, color: AdminColors.muted),
                      title: Text(i.label, style: AdminText.body()),
                      onTap: () => onSelected(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notifications extends StatefulWidget {
  const _Notifications({required this.current});

  final String current;

  @override
  State<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<_Notifications> {
  late final Stream<int> _count = adminPendingOrders();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _count,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleButton(
              icon: Icons.notifications_none_rounded,
              tooltip: n == 0
                  ? 'Aucune commande en attente'
                  : '$n commande${n > 1 ? 's' : ''} à confirmer',
              onTap: () => context.go('${AdminPaths.orders}?statut=confirm'),
            ),
            if (n > 0)
              Positioned(
                right: -2.0,
                top: -2.0,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 20.0, minHeight: 20.0),
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AdminColors.red,
                    borderRadius: BorderRadius.circular(AdminRadius.pill),
                    border: Border.all(color: AdminColors.page, width: 2.0),
                  ),
                  child: Text(n > 99 ? '99+' : '$n',
                      style: AdminText.strong(color: Colors.white, size: 10.5)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final name = adminDisplayName();
    return PopupMenuButton<String>(
      tooltip: 'Mon compte',
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'logout') adminSignOut(context);
        if (v == 'home') context.go(AdminPaths.dashboard);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AdminText.strong()),
              Text('Administrateur', style: AdminText.label(size: 12.0)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'home',
          child: Row(children: [
            const Icon(Icons.space_dashboard_rounded,
                size: 18.0, color: AdminColors.muted),
            const SizedBox(width: 10.0),
            Text('Tableau de bord', style: AdminText.body()),
          ]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            const Icon(Icons.logout_rounded, size: 18.0, color: AdminColors.red),
            const SizedBox(width: 10.0),
            Text('Déconnexion', style: AdminText.body(color: AdminColors.red)),
          ]),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wide) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Bonjour, ${name.split(' ').first}',
                    style: AdminText.strong()),
                Text('Administrateur', style: AdminText.label(size: 12.0)),
              ],
            ),
            const SizedBox(width: 10.0),
          ],
          AdminAvatar(name: name, size: 42.0),
        ],
      ),
    );
  }
}

// ── Page ─────────────────────────────────────────────────────────────────

/// Cadre d'une page d'administration.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.current,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    required this.body,
  });

  final String current;
  final String title;
  final String? subtitle;

  /// Icône de l'en-tête (sinon celle de l'entrée du menu).
  final IconData? icon;
  final List<Widget> actions;

  /// Contenu ; il gère lui-même son défilement.
  final Widget body;

  static const wideBreakpoint = 1000.0;

  IconData get _icon =>
      icon ??
      kAdminNavItems
          .firstWhere((i) => i.key == current, orElse: () => kDashboardItem)
          .icon;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28.0 : 16.0, 14.0, wide ? 28.0 : 16.0, 18.0),
      child: Wrap(
        spacing: 14.0,
        runSpacing: 14.0,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: AdminColors.red,
                  borderRadius: BorderRadius.circular(AdminRadius.md),
                  boxShadow: adminGlow(AdminColors.red),
                ),
                child: Icon(_icon, color: Colors.white, size: 23.0),
              ),
              const SizedBox(width: 14.0),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: wide ? 560.0 : MediaQuery.sizeOf(context).width - 92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AdminText.h1(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.label()),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
        ],
      ),
    );

    final content = Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(wide: wide, current: current),
          header,
          Expanded(child: body),
        ],
      ),
    );

    return AdminThemeScope(
      child: Scaffold(
        backgroundColor: AdminColors.page,
        drawer: wide
            ? null
            : Drawer(
                width: 290.0,
                backgroundColor: AdminColors.surface,
                child: SafeArea(child: KitungaAdminSidebar(current: current)),
              ),
        body: SafeArea(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: adminSidebarCollapsed,
                      builder: (context, collapsed, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: collapsed ? 84.0 : 272.0,
                        decoration: const BoxDecoration(
                          color: AdminColors.surface,
                          border: Border(
                              right: BorderSide(color: AdminColors.border)),
                        ),
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: collapsed ? 84.0 : 272.0,
                            maxWidth: collapsed ? 84.0 : 272.0,
                            child: KitungaAdminSidebar(
                                current: current, collapsed: collapsed),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
      ),
    );
  }
}

/// Contenu défilant d'une page, avec une largeur de lecture confortable.
class AdminScroll extends StatelessWidget {
  const AdminScroll({super.key, required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(wide ? 28.0 : 16.0, 0, wide ? 28.0 : 16.0, 40.0),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Grille de cartes qui passe en une colonne sur petit écran.
class AdminGrid extends StatelessWidget {
  const AdminGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240.0,
    this.spacing = 20.0,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / (minItemWidth + spacing))
          .floor()
          .clamp(1, children.length);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Deux colonnes (proportions [flex]) sur grand écran, empilées sinon.
class AdminSplit extends StatelessWidget {
  const AdminSplit({
    super.key,
    required this.left,
    required this.right,
    this.flex = const (3, 2),
    this.breakpoint = 900.0,
    this.spacing = 20.0,
  });

  final Widget left;
  final Widget right;
  final (int, int) flex;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, SizedBox(height: spacing), right],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: flex.$1, child: left),
          SizedBox(width: spacing),
          Expanded(flex: flex.$2, child: right),
        ],
      );
    });
  }
}

/// Page à onglets dans le cadre admin (Gestion, Module commercial) : barre
/// d'onglets blanche sous l'en-tête, contenu de chaque onglet en dessous.
class AdminTabbedBody extends StatelessWidget {
  const AdminTabbedBody({super.key, required this.tabs, required this.children});

  final List<(IconData, String)> tabs;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint;
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 28.0 : 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(AdminRadius.lg),
                boxShadow: kAdminShadow,
              ),
              padding: const EdgeInsets.all(6.0),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AdminColors.red,
                  borderRadius: BorderRadius.circular(AdminRadius.md),
                  boxShadow: adminGlow(AdminColors.red),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AdminColors.text,
                labelStyle: AdminText.strong(size: 13.5),
                unselectedLabelStyle: AdminText.label(size: 13.5)
                    .copyWith(fontWeight: FontWeight.w600),
                splashBorderRadius: BorderRadius.circular(AdminRadius.md),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                tabs: [
                  for (final t in tabs)
                    Tab(
                      height: 44.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.$1, size: 18.0),
                          const SizedBox(width: 8.0),
                          Text(t.$2),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4.0),
          Expanded(child: TabBarView(children: children)),
        ],
      ),
    );
  }
}
