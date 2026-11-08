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
  static const banners = '/publicites';
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
  const AdminNavGroup('Marketing', Icons.campaign_rounded, [
    AdminNavItem('banners', 'Publicités & promotions', Icons.view_carousel_rounded,
        path: AdminPaths.banners),
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

/// Couleurs du menu latéral (panneau sombre premium).
class _Side {
  static const top = Color(0xFF1C1F27);
  static const bottom = Color(0xFF111318);
  static const text = Color(0xFFB4B9C4);
  static const dim = Color(0xFF7A808C);
  static const line = Color(0x1AFFFFFF);
  static const hover = Color(0x0FFFFFFF);
  static const chip = Color(0x14FFFFFF);
  static const redA = Color(0xFFF23A3A);
  static const redB = Color(0xFFC4141B);
}

/// Panneau du menu : fond dégradé sombre, coins arrondis.
BoxDecoration adminSidebarDecoration({bool floating = true}) => BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_Side.top, _Side.bottom],
      ),
      borderRadius: floating ? BorderRadius.circular(24.0) : null,
      boxShadow: floating
          ? const [
              BoxShadow(
                  color: Color(0x33111318),
                  blurRadius: 30.0,
                  offset: Offset(0, 12)),
            ]
          : null,
    );

class KitungaAdminSidebar extends StatefulWidget {
  const KitungaAdminSidebar(
      {super.key, required this.current, this.collapsed = false});

  final String current;
  final bool collapsed;

  @override
  State<KitungaAdminSidebar> createState() => _KitungaAdminSidebarState();
}

class _KitungaAdminSidebarState extends State<KitungaAdminSidebar> {
  /// Commandes à confirmer : compteur sur « Opérations » et « Commandes ».
  late final Stream<int> _pending = adminPendingOrders();

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    final current = widget.current;
    return StreamBuilder<int>(
      stream: _pending,
      builder: (context, snap) {
        final badges = <String, int>{'orders': snap.data ?? 0};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(collapsed),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 18.0 : 20.0),
              child: const Divider(height: 1.0, color: _Side.line),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    collapsed ? 14.0 : 14.0, 16.0, collapsed ? 14.0 : 14.0, 8.0),
                children: [
                  if (!collapsed) _caption('NAVIGATION'),
                  _NavTile(
                    item: kDashboardItem,
                    selected: current == 'dashboard',
                    collapsed: collapsed,
                    onTap: () =>
                        openAdminItem(context, kDashboardItem, current: current),
                  ),
                  const SizedBox(height: 10.0),
                  if (!collapsed) _caption('MODULES'),
                  for (final g in kAdminMenu)
                    _NavGroup(
                      group: g,
                      current: current,
                      collapsed: collapsed,
                      badges: badges,
                    ),
                ],
              ),
            ),
            _profile(context, collapsed),
          ],
        );
      },
    );
  }

  Widget _caption(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 6.0, 0, 8.0),
        child: Text(text,
            style: AdminText.caps(color: _Side.dim).copyWith(letterSpacing: 1.4)),
      );

  /// Vrai logo Kitunga posé directement sur le panneau, sans cadre : sa
  /// variante pour fond sombre (K et mot « KITUNGA » en blanc, chariot rouge).
  Widget _brand(bool collapsed) {
    Widget logo(double h) => Image.asset(
          'assets/logo/kitunga_logo_dark_bg.png',
          height: h,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Kitunga',
          errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded,
              color: Colors.white, size: h * 0.6),
        );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 24.0, 0, 20.0),
        child: Center(child: logo(46.0)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22.0, 24.0, 18.0, 20.0),
      child: Row(
        children: [
          logo(68.0),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Espace',
                    style: AdminText.label(color: _Side.dim, size: 12.0)),
                Text('Administration',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.h2(color: Colors.white)
                        .copyWith(fontSize: 16.5)),
                const SizedBox(height: 6.0),
                Container(
                  height: 3.0,
                  width: 34.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_Side.redA, _Side.redB]),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profile(BuildContext context, bool collapsed) {
    final name = adminDisplayName();
    final logout = Tooltip(
      message: 'Déconnexion',
      child: Material(
        color: _Side.chip,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: () => adminSignOut(context),
          child: const SizedBox(
            width: 38.0,
            height: 38.0,
            child: Icon(Icons.logout_rounded, size: 18.0, color: _Side.text),
          ),
        ),
      ),
    );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 22.0, top: 10.0),
        child: Column(
          children: [
            AdminAvatar(name: name, size: 40.0),
            const SizedBox(height: 10.0),
            logout,
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(14.0, 8.0, 14.0, 18.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: _Side.hover,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: _Side.line),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AdminAvatar(name: name, size: 40.0),
              Positioned(
                right: -1.0,
                bottom: -1.0,
                child: Container(
                  width: 12.0,
                  height: 12.0,
                  decoration: BoxDecoration(
                    color: AdminColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: _Side.bottom, width: 2.0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.strong(color: Colors.white, size: 13.5)),
                Text('Administrateur',
                    style: AdminText.label(color: _Side.dim, size: 12.0)),
              ],
            ),
          ),
          logout,
        ],
      ),
    );
  }
}

/// Pastille de compteur (commandes à confirmer).
Widget _countBadge(int n, {bool onRed = false}) => Container(
      constraints: const BoxConstraints(minWidth: 22.0),
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: onRed ? Colors.white : _Side.redA,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Text(n > 99 ? '99+' : '$n',
          textAlign: TextAlign.center,
          style: AdminText.strong(
              color: onRed ? _Side.redB : Colors.white, size: 11.0)),
    );

/// Icône dans une pastille (menu).
class _IconChip extends StatelessWidget {
  const _IconChip(this.icon, {required this.active, this.strong = false});

  final IconData icon;
  final bool active;

  /// Sur fond rouge (entrée active de premier niveau).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.0,
      height: 34.0,
      decoration: BoxDecoration(
        color: strong
            ? Colors.white.withValues(alpha: 0.18)
            : active
                ? _Side.redA.withValues(alpha: 0.18)
                : _Side.chip,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Icon(icon,
          size: 18.0,
          color: strong
              ? Colors.white
              : active
                  ? const Color(0xFFFF6B6B)
                  : _Side.text),
    );
  }
}

class _NavGroup extends StatefulWidget {
  const _NavGroup({
    required this.group,
    required this.current,
    required this.collapsed,
    required this.badges,
  });

  final AdminNavGroup group;
  final String current;
  final bool collapsed;
  final Map<String, int> badges;

  @override
  State<_NavGroup> createState() => _NavGroupState();
}

class _NavGroupState extends State<_NavGroup> {
  late bool _open = widget.group.items.any((i) => i.key == widget.current);
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final active = g.items.any((i) => i.key == widget.current);
    final count =
        g.items.fold(0, (s, i) => s + (widget.badges[i.key] ?? 0));

    // Menu réduit : l'icône du groupe ouvre ses entrées dans un menu.
    if (widget.collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: PopupMenuButton<AdminNavItem>(
          tooltip: g.label,
          position: PopupMenuPosition.over,
          offset: const Offset(70, 0),
          color: _Side.top,
          onSelected: (i) => openAdminItem(context, i, current: widget.current),
          itemBuilder: (_) => [
            PopupMenuItem<AdminNavItem>(
              enabled: false,
              child: Text(g.label.toUpperCase(),
                  style: AdminText.caps(color: _Side.dim)),
            ),
            for (final i in g.items)
              PopupMenuItem(
                value: i,
                child: Row(
                  children: [
                    Icon(i.icon,
                        size: 18.0,
                        color: i.key == widget.current
                            ? const Color(0xFFFF6B6B)
                            : _Side.text),
                    const SizedBox(width: 10.0),
                    Text(i.label,
                        style: AdminText.body(
                            color: i.key == widget.current
                                ? Colors.white
                                : _Side.text)),
                  ],
                ),
              ),
          ],
          child: SizedBox(
            height: 50.0,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _IconChip(g.icon, active: active),
                if (count > 0)
                  Positioned(top: 2.0, right: 6.0, child: _countBadge(count)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(vertical: 2.0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
              decoration: BoxDecoration(
                color: _hover || (_open && active)
                    ? _Side.hover
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: Row(
                children: [
                  _IconChip(g.icon, active: active),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(g.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.strong(
                            color: active ? Colors.white : _Side.text,
                            size: 14.0)),
                  ),
                  if (count > 0 && !_open) ...[
                    _countBadge(count),
                    const SizedBox(width: 6.0),
                  ],
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20.0, color: active ? Colors.white : _Side.dim),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 26.0, bottom: 6.0),
                  child: Container(
                    padding: const EdgeInsets.only(left: 12.0),
                    decoration: const BoxDecoration(
                      border:
                          Border(left: BorderSide(color: _Side.line, width: 1.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in g.items)
                          _SubTile(
                            item: item,
                            selected: item.key == widget.current,
                            count: widget.badges[item.key] ?? 0,
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

/// Entrée de premier niveau (tableau de bord).
class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final AdminNavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : 10.0, vertical: 7.0),
          decoration: BoxDecoration(
            gradient: sel
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_Side.redA, _Side.redB])
                : null,
            color: sel ? null : (_hover ? _Side.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(14.0),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: _Side.redA.withValues(alpha: 0.40),
                        blurRadius: 18.0,
                        offset: const Offset(0, 8)),
                  ]
                : null,
          ),
          child: widget.collapsed
              ? Center(
                  child: _IconChip(widget.item.icon, active: sel, strong: sel))
              : Row(
                  children: [
                    _IconChip(widget.item.icon, active: sel, strong: sel),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(widget.item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.strong(
                              color: sel ? Colors.white : _Side.text,
                              size: 14.0)),
                    ),
                  ],
                ),
        ),
      ),
    );
    return widget.collapsed
        ? Tooltip(message: widget.item.label, child: tile)
        : tile;
  }
}

/// Entrée d'un groupe (sous-menu).
class _SubTile extends StatefulWidget {
  const _SubTile({
    required this.item,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  State<_SubTile> createState() => _SubTileState();
}

class _SubTileState extends State<_SubTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
          decoration: BoxDecoration(
            color: sel
                ? Colors.white.withValues(alpha: 0.08)
                : (_hover ? _Side.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: sel ? 8.0 : 5.0,
                height: sel ? 8.0 : 5.0,
                decoration: BoxDecoration(
                  color: sel ? _Side.redA : _Side.dim,
                  shape: BoxShape.circle,
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: _Side.redA.withValues(alpha: 0.6),
                              blurRadius: 8.0),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.label(
                            color: sel
                                ? Colors.white
                                : (_hover ? Colors.white : _Side.text),
                            size: 13.5)
                        .copyWith(
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500)),
              ),
              if (widget.count > 0) _countBadge(widget.count),
            ],
          ),
        ),
      ),
    );
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
          _CircleButton(
            icon: AdminColors.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: AdminColors.dark ? 'Mode clair' : 'Mode sombre',
            onTap: toggleAdminDarkMode,
          ),
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
        shape: CircleBorder(side: BorderSide(color: AdminColors.border)),
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
            prefixIcon: Icon(Icons.search_rounded,
                size: 20.0, color: AdminColors.faint),
            filled: true,
            fillColor: AdminColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 13.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdminRadius.pill),
              borderSide: BorderSide(color: AdminColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdminRadius.pill),
              borderSide: BorderSide(color: AdminColors.border),
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
            Icon(Icons.space_dashboard_rounded,
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
                backgroundColor: _Side.bottom,
                child: Container(
                  decoration: adminSidebarDecoration(floating: false),
                  child: SafeArea(child: KitungaAdminSidebar(current: current)),
                ),
              ),
        body: SafeArea(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: adminSidebarCollapsed,
                      // Panneau flottant aux coins arrondis.
                      builder: (context, collapsed, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: collapsed ? 92.0 : 280.0,
                        margin: const EdgeInsets.fromLTRB(14.0, 14.0, 0, 14.0),
                        decoration: adminSidebarDecoration(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24.0),
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: collapsed ? 92.0 : 280.0,
                            maxWidth: collapsed ? 92.0 : 280.0,
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
            constraints: const BoxConstraints(maxWidth: 2200.0),
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
    this.height,
  });

  /// Hauteur commune des deux colonnes sur grand écran (cartes alignées).
  final double? height;

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
      final row = Row(
        crossAxisAlignment:
            height == null ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: flex.$1, child: left),
          SizedBox(width: spacing),
          Expanded(flex: flex.$2, child: right),
        ],
      );
      return height == null ? row : SizedBox(height: height, child: row);
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
