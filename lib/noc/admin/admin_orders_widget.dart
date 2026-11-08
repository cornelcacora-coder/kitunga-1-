import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/backend/order_status.dart';
import '/noc/sales/sales_common.dart' show fcfa;
import '/noc/ui/admin_export.dart';
import '/noc/ui/admin_table.dart';
import 'admin_dashboard_data.dart';
import 'admin_order_detail.dart';
import 'admin_shell.dart';

/// Commandes (/commandes) et livraisons (/livraisons) : tableau filtrable
/// (statut, période, recherche, zone), trié et paginé, avec la fiche de
/// chaque commande. Les commandes encore en cours sont toujours incluses,
/// même si elles sont plus anciennes que la période choisie.
enum AdminOrdersMode { orders, deliveries }

class AdminOrdersWidget extends StatefulWidget {
  const AdminOrdersWidget(
      {super.key, this.mode = AdminOrdersMode.orders, this.clock, this.tab});

  static String routeName = 'AdminOrders';
  static String routePath = '/commandes';
  static String deliveriesRouteName = 'AdminDeliveries';
  static String deliveriesRoutePath = '/livraisons';

  final AdminOrdersMode mode;
  final DateTime Function()? clock;

  /// Onglet de départ (paramètre « statut »).
  final String? tab;

  @override
  State<AdminOrdersWidget> createState() => _AdminOrdersWidgetState();
}

typedef _Tab = ({String key, String label, bool Function(DashOrder) test});

bool _in(DashOrder o, List<String> s) => s.contains(o.status);

final List<_Tab> _orderTabs = [
  (key: 'all', label: 'Toutes', test: (_) => true),
  (
    key: 'confirm',
    label: 'À confirmer',
    test: (o) => _in(o, ['', OrderStatus.pending])
  ),
  (
    key: 'preparing',
    label: 'En préparation',
    test: (o) => _in(o, [OrderStatus.preparing, OrderStatus.ready])
  ),
  (
    key: 'delivering',
    label: 'En livraison',
    test: (o) => _in(o, [OrderStatus.delivering])
  ),
  (
    key: 'delivered',
    label: 'Livrées',
    test: (o) => _in(o, OrderStatus.successful)
  ),
  (
    key: 'stopped',
    label: 'Annulées / refusées',
    test: (o) => _in(o, [OrderStatus.cancelled, OrderStatus.refused])
  ),
  (
    key: 'problem',
    label: 'Non reçues',
    test: (o) => _in(o, [OrderStatus.notReceived])
  ),
];

final List<_Tab> _deliveryTabs = [
  (
    key: 'ready',
    label: 'À prendre en charge',
    test: (o) => _in(o, [OrderStatus.ready])
  ),
  (
    key: 'delivering',
    label: 'En cours de livraison',
    test: (o) => _in(o, [OrderStatus.delivering])
  ),
  (
    key: 'delivered',
    label: 'Livrées',
    test: (o) => _in(o, OrderStatus.successful)
  ),
  (
    key: 'problem',
    label: 'Non reçues',
    test: (o) => _in(o, [OrderStatus.notReceived])
  ),
];

typedef _People = Map<String, ({String name, String photo, String phone})>;

class _AdminOrdersWidgetState extends State<AdminOrdersWidget> {
  final _src = AdminDashboardSource.instance;
  DateTime get _now => (widget.clock ?? DateTime.now)();
  bool get _deliveries => widget.mode == AdminOrdersMode.deliveries;
  List<_Tab> get _tabs => _deliveries ? _deliveryTabs : _orderTabs;

  late String _tab = _tabs.any((t) => t.key == widget.tab)
      ? widget.tab!
      : _tabs.first.key;
  int _days = 30;
  String _q = '';
  String? _zone;

  late Stream<List<DashOrder>> _period = _load();
  late final Stream<List<DashOrder>> _inProgress = _src.inProgress();

  final _People _people = {};
  final Set<String> _asked = {};

  /// Lignes affichées (onglet, filtres) pour l'export.
  List<DashOrder>? _shown;
  String _shownTab = '';

  Stream<List<DashOrder>> _load() => _src.ordersSince(_days == 0
      ? DateTime(2020)
      : _now.subtract(Duration(days: _days)));

  void _ensureNames(Iterable<String?> paths) {
    final missing =
        paths.whereType<String>().where((p) => _asked.add(p)).toList();
    if (missing.isEmpty) return;
    _src.names(missing).then((m) {
      if (mounted) setState(() => _people.addAll(m));
    }).catchError((_) {});
  }

  String _name(String? path, {String none = '—'}) =>
      path == null ? none : (_people[path]?.name ?? '…');

  String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  bool _matches(DashOrder o) {
    if (_zone != null && o.zone.trim() != _zone) return false;
    final q = _norm(_q.trim());
    if (q.isEmpty) return true;
    return [
      o.reference,
      o.zone,
      o.location,
      _name(o.userPath),
      _name(o.sellerPath),
      _name(o.delivererPath),
    ].any((v) => _norm(v).contains(q));
  }

  static const _periods = {
    7: '7 derniers jours',
    30: '30 derniers jours',
    90: '90 derniers jours',
    365: '12 derniers mois',
    0: 'Tout l\'historique',
  };

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      current: _deliveries ? 'deliveries' : 'orders',
      title: _deliveries ? 'Livraisons' : 'Commandes',
      subtitle: _deliveries
          ? 'Suivi des livreurs, de la prise en charge à la remise'
          : 'Toutes les commandes passées sur Kitunga',
      actions: [
        AdminExportButton(data: _export),
        AdminSelect<int>(
          value: _days,
          items: _periods,
          icon: Icons.calendar_today_rounded,
          onChanged: (d) => setState(() {
            _days = d;
            _period = _load();
          }),
        ),
      ],
      body: StreamBuilder<List<DashOrder>>(
        stream: _period,
        builder: (context, period) => StreamBuilder<List<DashOrder>>(
          stream: _inProgress,
          builder: (context, live) {
            if (period.hasError) {
              return const AdminEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: 'Données indisponibles',
                  message: 'Vérifiez la connexion puis rechargez la page.');
            }
            if (!period.hasData) return const AdminLoading(height: 320.0);
            final all = mergeOrders(period.data!, live.data ?? const []);
            _ensureNames(all.expand(
                (o) => [o.userPath, o.sellerPath, o.delivererPath]));
            return _content(all);
          },
        ),
      ),
    );
  }

  Widget _content(List<DashOrder> all) {
    final base = all.where(_matches).toList();
    final tab = _tabs.firstWhere((t) => t.key == _tab);
    final rows = base.where(tab.test).toList();
    _shown = rows;
    _shownTab = tab.label;
    final zones = {
      for (final o in all)
        if (o.zone.trim().isNotEmpty) o.zone.trim(),
    }.toList()
      ..sort();
    final wide = MediaQuery.sizeOf(context).width >= 700.0;

    return AdminScroll(
      children: [
        if (_deliveries) ...[
          _deliverySummary(all),
          const SizedBox(height: 20.0),
        ],
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminTabs<String>(
                value: _tab,
                tabs: [
                  for (final t in _tabs)
                    (
                      value: t.key,
                      label: t.label,
                      count: base.where(t.test).length
                    ),
                ],
                onChanged: (v) => setState(() => _tab = v),
              ),
              const SizedBox(height: 16.0),
              Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AdminSearchBox(
                    width: wide
                        ? 340.0
                        : MediaQuery.sizeOf(context).width - 72.0,
                    hint: 'Référence, client, commerce, livreur…',
                    onChanged: (v) => setState(() => _q = v),
                  ),
                  AdminSelect<String?>(
                    value: _zone,
                    icon: Icons.place_outlined,
                    items: {null: 'Toutes les zones', for (final z in zones) z: z},
                    onChanged: (v) => setState(() => _zone = v),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              _deliveries ? _deliveryTable(rows) : _orderTable(rows),
            ],
          ),
        ),
      ],
    );
  }

  // ── Export ─────────────────────────────────────────────────────────────

  AdminExportData? _export() {
    final rows = _shown;
    if (rows == null) return null;
    final sorted = [...rows]..sort((a, b) =>
        (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    final filters = [
      _periods[_days]!,
      'onglet « $_shownTab »',
      if (_zone != null) 'zone $_zone',
      if (_q.trim().isNotEmpty) 'recherche « ${_q.trim()} »',
      '${rows.length} commande${rows.length > 1 ? 's' : ''}',
    ].join(' · ');
    String addr(DashOrder o) =>
        [o.zone, o.location].where((s) => s.trim().isNotEmpty).join(' · ');
    if (_deliveries) {
      return AdminExportData(
        title: 'Livraisons',
        subtitle: filters,
        fileName: 'livraisons',
        headers: ['Référence', 'Commandée le', 'Livreur', 'Commerce',
          'Adresse', 'Durée (min)', 'Livrée le', 'Statut'],
        flex: [3, 3, 3, 3, 4, 2, 3, 2],
        rows: [
          for (final o in sorted)
            [
              o.reference,
              _date(o.createdAt),
              _name(o.delivererPath, none: 'Non attribué'),
              _name(o.sellerPath),
              addr(o),
              _elapsed(o)?.inMinutes,
              o.deliveredAt == null ? '' : _date(o.deliveredAt),
              orderStatusShort(o.status),
            ],
        ],
      );
    }
    return AdminExportData(
      title: 'Commandes',
      subtitle: filters,
      fileName: 'commandes',
      headers: ['Référence', 'Date', 'Client', 'Téléphone client', 'Commerce',
        'Adresse', 'Montant', 'Statut'],
      flex: [3, 3, 3, 2, 3, 4, 2, 2],
      moneyColumns: {6},
      rows: [
        for (final o in sorted)
          [
            o.reference,
            _date(o.createdAt),
            _name(o.userPath),
            _people[o.userPath]?.phone ?? '',
            _name(o.sellerPath),
            addr(o),
            o.total,
            orderStatusShort(o.status),
          ],
      ],
    );
  }

  // ── Commandes ──────────────────────────────────────────────────────────

  Widget _ref(DashOrder o) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(o.reference.isEmpty ? 'Sans référence' : o.reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminText.strong(size: 13.0)),
          Text(_date(o.createdAt),
              style: AdminText.label(color: AdminColors.faint, size: 12.0)),
        ],
      );

  Widget _person(String? path, {String none = '—'}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (path != null) ...[
            AdminAvatar(
                name: _name(path),
                photo: _people[path]?.photo,
                size: 28.0),
            const SizedBox(width: 8.0),
          ],
          Flexible(
            child: Text(_name(path, none: none),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminText.body(
                    size: 13.0,
                    color: path == null ? AdminColors.faint : AdminColors.text)),
          ),
        ],
      );

  Widget _status(DashOrder o) =>
      AdminBadge(orderStatusShort(o.status), tone: orderStatusTone(o.status));

  List<Widget> _view(DashOrder o) => [
        AdminActionDot(
          icon: Icons.visibility_rounded,
          tooltip: 'Voir la commande',
          onTap: () => showAdminOrderDetail(context, o, known: _people),
        ),
      ];

  Widget _empty() => AdminEmpty(
        icon: _deliveries
            ? Icons.delivery_dining_rounded
            : Icons.receipt_long_rounded,
        title: 'Aucune commande',
        message: _q.isNotEmpty || _zone != null
            ? 'Aucune commande ne correspond à ces filtres.'
            : 'Rien dans cet onglet pour la période choisie.',
      );

  Widget _orderTable(List<DashOrder> rows) {
    return AdminTable<DashOrder>(
      rows: rows,
      initialSort: 0,
      empty: _empty(),
      onTap: (o) => showAdminOrderDetail(context, o, known: _people),
      actions: _view,
      actionsWidth: 50.0,
      columns: [
        AdminColumn(
            label: 'Commande',
            flex: 3,
            cell: _ref,
            sortKey: (o) => o.createdAt),
        AdminColumn(
            label: 'Client',
            flex: 3,
            cell: (o) => _person(o.userPath),
            sortKey: (o) => _name(o.userPath).toLowerCase()),
        AdminColumn(
            label: 'Commerce',
            flex: 3,
            cell: (o) => Text(_name(o.sellerPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminText.body(size: 13.0)),
            sortKey: (o) => _name(o.sellerPath).toLowerCase()),
        AdminColumn(
            label: 'Zone',
            flex: 2,
            cell: (o) => Text(o.zone.isEmpty ? '—' : o.zone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminText.body(size: 13.0)),
            sortKey: (o) => o.zone.toLowerCase()),
        AdminColumn(
            label: 'Montant',
            flex: 2,
            cell: (o) => Text(fcfa(o.total), style: AdminText.strong(size: 13.0)),
            sortKey: (o) => o.total),
        AdminColumn(label: 'Statut', flex: 3, cell: _status,
            sortKey: (o) => orderStatusShort(o.status)),
      ],
      compact: (o) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _ref(o)),
              Text(fcfa(o.total), style: AdminText.strong(size: 13.5)),
            ],
          ),
          const SizedBox(height: 6.0),
          Text('${_name(o.userPath)} → ${_name(o.sellerPath)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminText.label(size: 12.5)),
          const SizedBox(height: 6.0),
          _status(o),
        ],
      ),
    );
  }

  // ── Livraisons ─────────────────────────────────────────────────────────

  Widget _deliverySummary(List<DashOrder> all) {
    final now = _now;
    final ready = all.where((o) => o.status == OrderStatus.ready).toList();
    final going = all.where((o) => o.status == OrderStatus.delivering).length;
    final waitingLong = ready
        .where((o) =>
            o.createdAt != null &&
            now.difference(o.createdAt!) > const Duration(minutes: 30))
        .length;
    final today = DateTime(now.year, now.month, now.day);
    final deliveredToday = all
        .where((o) => o.deliveredAt != null && !o.deliveredAt!.isBefore(today))
        .length;
    final drivers = {
      for (final o in all)
        if (o.status == OrderStatus.delivering && o.delivererPath != null)
          o.delivererPath,
    }.length;
    return AdminGrid(
      minItemWidth: 230.0,
      children: [
        AdminStatCard(
            icon: Icons.inventory_rounded,
            label: 'À prendre en charge',
            value: '${ready.length}',
            color: AdminColors.violet,
            caption: waitingLong == 0
                ? 'Aucune attente longue'
                : '$waitingLong en attente depuis +30 min'),
        AdminStatCard(
            icon: Icons.delivery_dining_rounded,
            label: 'En cours de livraison',
            value: '$going',
            color: AdminColors.blue,
            caption: '$drivers livreur${drivers > 1 ? 's' : ''} en course'),
        AdminStatCard(
            icon: Icons.task_alt_rounded,
            label: 'Livrées aujourd\'hui',
            value: '$deliveredToday',
            color: AdminColors.green),
      ],
    );
  }

  /// Durée : depuis la commande jusqu'à la remise (ou jusqu'à maintenant).
  Duration? _elapsed(DashOrder o) {
    final c = o.createdAt;
    if (c == null) return null;
    return (o.deliveredAt ?? _now).difference(c);
  }

  Widget _deliveryTable(List<DashOrder> rows) {
    return AdminTable<DashOrder>(
      rows: rows,
      initialSort: 0,
      empty: _empty(),
      onTap: (o) => showAdminOrderDetail(context, o, known: _people),
      actions: _view,
      actionsWidth: 50.0,
      highlight: (o) =>
          o.status == OrderStatus.ready &&
          (_elapsed(o) ?? Duration.zero) > const Duration(minutes: 30),
      columns: [
        AdminColumn(
            label: 'Commande',
            flex: 3,
            cell: _ref,
            sortKey: (o) => o.createdAt),
        AdminColumn(
            label: 'Livreur',
            flex: 3,
            cell: (o) => _person(o.delivererPath, none: 'Non attribué'),
            sortKey: (o) => _name(o.delivererPath, none: '').toLowerCase()),
        AdminColumn(
            label: 'Commerce',
            flex: 3,
            cell: (o) => Text(_name(o.sellerPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminText.body(size: 13.0)),
            sortKey: (o) => _name(o.sellerPath).toLowerCase()),
        AdminColumn(
            label: 'Adresse',
            flex: 3,
            cell: (o) => Text(
                [o.zone, o.location].where((s) => s.trim().isNotEmpty).join(' · ')
                        .isEmpty
                    ? '—'
                    : [o.zone, o.location]
                        .where((s) => s.trim().isNotEmpty)
                        .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AdminText.body(size: 13.0)),
            sortKey: (o) => o.zone.toLowerCase()),
        AdminColumn(
            label: 'Durée',
            flex: 2,
            cell: (o) {
              final d = _elapsed(o);
              return Text(d == null ? '—' : adminDuration(d),
                  style: AdminText.strong(
                      size: 13.0,
                      color: o.deliveredAt == null &&
                              (d ?? Duration.zero) > const Duration(hours: 2)
                          ? AdminColors.red
                          : AdminColors.ink));
            },
            sortKey: (o) => _elapsed(o)?.inMinutes),
        AdminColumn(label: 'Statut', flex: 3, cell: _status),
      ],
      compact: (o) {
        final d = _elapsed(o);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _ref(o)),
                Text(d == null ? '—' : adminDuration(d),
                    style: AdminText.strong(size: 13.0)),
              ],
            ),
            const SizedBox(height: 6.0),
            Text(
                '${_name(o.delivererPath, none: 'Non attribué')} · ${o.zone.isEmpty ? 'Zone non précisée' : o.zone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminText.label(size: 12.5)),
            const SizedBox(height: 6.0),
            _status(o),
          ],
        );
      },
    );
  }

  static String _date(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy, HH:mm', 'fr').format(d);
}
