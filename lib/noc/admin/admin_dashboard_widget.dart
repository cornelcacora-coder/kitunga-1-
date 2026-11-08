import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/flutter_flow/flutter_flow_util.dart' show GoRouterHelper;
import '/noc/ops_alerts.dart'
    show orderAlerts, paymentFailureRate, countLevel, rateLevel, OpsLevel;
import '/noc/ops_panels.dart' show ordersByZone;
import '/noc/sales/sales_common.dart' show fcfa;
import '/noc/ui/admin_charts.dart';
import 'admin_dashboard_data.dart';
import 'admin_delivery_map.dart';
import 'admin_order_detail.dart';
import 'admin_shell.dart';
import '/noc/ui/admin_table.dart';
import '/noc/ui/admin_export.dart';

/// Tableau de bord de l'administration (adresse /supervisionDashboard) :
/// indicateurs clés comparés à la période précédente, commandes par jour,
/// répartition des statuts, commandes récentes, alertes et zones.
class AdminDashboardWidget extends StatefulWidget {
  const AdminDashboardWidget({super.key, this.clock});

  // Mêmes nom et adresse que l'ancien tableau de bord (liens existants).
  static String routeName = 'SupervisionDashboard';
  static String routePath = '/supervisionDashboard';

  /// Heure de référence (tests) ; sinon l'heure actuelle.
  final DateTime Function()? clock;

  @override
  State<AdminDashboardWidget> createState() => _AdminDashboardWidgetState();
}

typedef _People = Map<String, ({String name, String photo, String phone})>;

class _AdminDashboardWidgetState extends State<AdminDashboardWidget> {
  final _src = AdminDashboardSource.instance;
  DateTime get _now => (widget.clock ?? DateTime.now)();

  int _days = 30;

  /// Commandes des 180 derniers jours : couvre la plus longue période (90 j)
  /// et sa période de comparaison.
  late final Stream<List<DashOrder>> _orders =
      _src.ordersSince(_now.subtract(const Duration(days: 180)));
  late final Stream<List<DashOrder>> _inProgress = _src.inProgress();
  late final Stream<List<String?>> _payments =
      _src.paymentStatusesSince(_now.subtract(const Duration(days: 7)));
  late final Future<({int clients, int sellers, int delivers})> _totals =
      _src.totals();
  late Future<List<DateTime>> _newUsers = _loadUsers();

  final _People _people = {};
  final Set<String> _asked = {};

  /// Derniers chiffres affichés (rapport d'activité exportable).
  DashPeriod? _stats;
  List<DashOrder> _inPeriod = const [];
  List<DashOrder> _latest = const [];
  int? _newClients;
  ({int clients, int sellers, int delivers})? _totalsValue;
  Timer? _tick;

  Future<List<DateTime>> _loadUsers() =>
      _src.newUsersSince(_now.subtract(Duration(days: _days * 2)));

  @override
  void initState() {
    super.initState();
    // Les retards avancent avec le temps : recalcul chaque minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _setDays(int d) {
    setState(() {
      _days = d;
      _newUsers = _loadUsers();
    });
  }

  /// Charge les noms (clients, commerces) des commandes affichées.
  void _ensureNames(Iterable<String?> paths) {
    final missing =
        paths.whereType<String>().where((p) => _asked.add(p)).toList();
    if (missing.isEmpty) return;
    _src.names(missing).then((m) {
      if (mounted) setState(() => _people.addAll(m));
    }).catchError((_) {});
  }

  static const _periods = {7: '7 derniers jours', 30: '30 derniers jours', 90: '90 derniers jours'};

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      current: 'dashboard',
      title: 'Tableau de bord',
      subtitle: 'Activité de Kitunga en temps réel',
      actions: [
        AdminExportButton(data: _report),
        AdminSelect<int>(
          value: _days,
          items: _periods,
          icon: Icons.calendar_today_rounded,
          onChanged: _setDays,
        ),
      ],
      body: StreamBuilder<List<DashOrder>>(
        stream: _orders,
        builder: (context, snap) {
          if (snap.hasError) {
            return const AdminEmpty(
              icon: Icons.cloud_off_rounded,
              title: 'Données indisponibles',
              message: 'Vérifiez la connexion puis rechargez la page.',
            );
          }
          if (!snap.hasData) return const AdminLoading(height: 320.0);
          return _content(snap.data!);
        },
      ),
    );
  }

  Widget _content(List<DashOrder> orders) {
    final now = _now;
    final stats = periodStats(orders, now, _days);
    final from = now.subtract(Duration(days: _days));
    final inPeriod = orders
        .where((o) => o.createdAt != null && !o.createdAt!.isBefore(from))
        .toList();
    final recent = [...orders]
      ..removeWhere((o) => o.createdAt == null)
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    final latest = recent.take(20).toList();
    _ensureNames(latest.expand((o) => [o.userPath, o.sellerPath]));
    _stats = stats;
    _inPeriod = inPeriod;
    _latest = latest;

    // Une seule écoute des commandes en cours (carte, alertes, zones).
    return StreamBuilder<List<DashOrder>>(
      stream: _inProgress,
      builder: (context, live) => AdminScroll(
        children: [
          _kpis(stats),
          const SizedBox(height: 20.0),
          AdminSplit(
            flex: (3, 2),
            breakpoint: 1000.0,
            height: 430.0,
            left: _ordersChart(orders, now),
            right: _statusCard(inPeriod),
          ),
          const SizedBox(height: 20.0),
          _mapCard(now, live.data),
          const SizedBox(height: 20.0),
          AdminSplit(
            flex: (3, 2),
            breakpoint: 1000.0,
            left: _recentOrders(latest),
            right: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _alertsCard(now, live.data),
                const SizedBox(height: 20.0),
                _zonesCard(live.data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte des livraisons en cours, par quartier.
  Widget _mapCard(DateTime now, List<DashOrder>? live) {
    final wide = MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCardHeader(
            title: 'Carte des livraisons',
            subtitle: 'Commandes en cours par quartier de Brazzaville',
            trailing: TextButton.icon(
              onPressed: () => context.go(AdminPaths.zones),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18.0),
              label: const Text('Détail par zone'),
            ),
          ),
          if (live == null)
            const AdminLoading(height: 300.0)
          else
            AdminDeliveryMap(
              orders: live,
              now: now,
              height: wide ? 440.0 : 340.0,
              people: _people,
            ),
        ],
      ),
    );
  }

  /// Rapport d'activité : indicateurs, statuts et commandes récentes.
  AdminExportData? _report() {
    final s = _stats;
    if (s == null) return null;
    String trend(num cur, num prev) {
      final t = trendPercent(cur, prev);
      if (t == null) return '';
      return '${t >= 0 ? '+' : ''}${t.toStringAsFixed(t.abs() < 10 ? 1 : 0)} %';
    }
    final t = _totalsValue;
    final rows = <List<Object?>>[
      ['Indicateur', 'Commandes passées', s.orders, trend(s.orders, s.previousOrders)],
      ['Indicateur', 'Ventes livrées (F)', s.revenue, trend(s.revenue, s.previousRevenue)],
      if (_newClients != null)
        ['Indicateur', 'Nouveaux clients', _newClients, ''],
      [
        'Indicateur',
        'Livraison moyenne (min)',
        s.deliveryMinutes,
        s.deliveryMinutes == null || s.previousDeliveryMinutes == null
            ? ''
            : trend(s.deliveryMinutes!, s.previousDeliveryMinutes!),
      ],
      if (t != null) ...[
        ['Comptes', 'Clients inscrits', t.clients, ''],
        ['Comptes', 'Commerces', t.sellers, ''],
        ['Comptes', 'Livreurs', t.delivers, ''],
      ],
      for (final g in statusBreakdown(_inPeriod))
        ['Statut des commandes', g.label, g.count, ''],
      for (final o in _latest)
        [
          'Commande récente',
          '${o.reference} · ${_name(o.userPath)} → ${_name(o.sellerPath)} · ${orderStatusShort(o.status)}',
          o.total,
          _ago(o.createdAt),
        ],
    ];
    return AdminExportData(
      title: 'Rapport d\'activité',
      subtitle: '${_periods[_days]} · comparaison avec la période précédente',
      fileName: 'rapport_activite',
      headers: ['Rubrique', 'Élément', 'Valeur', 'Évolution / date'],
      flex: [3, 7, 2, 2],
      rows: rows,
    );
  }

  // ── Indicateurs ────────────────────────────────────────────────────────

  Widget _kpis(DashPeriod s) {
    return FutureBuilder<List<DateTime>>(
      future: _newUsers,
      builder: (context, users) {
        final now = _now;
        final from = now.subtract(Duration(days: _days));
        final list = users.data ?? const <DateTime>[];
        final newClients = list.where((d) => !d.isBefore(from)).length;
        if (users.hasData) _newClients = newClients;
        final prevClients = list.where((d) => d.isBefore(from)).length;
        return FutureBuilder<({int clients, int sellers, int delivers})>(
          future: _totals,
          builder: (context, totals) {
            final t = totals.data;
            _totalsValue = t;
            return AdminGrid(
              minItemWidth: 250.0,
              children: [
                AdminStatCard(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Commandes',
                  value: _int(s.orders),
                  color: AdminColors.red,
                  trend: trendPercent(s.orders, s.previousOrders),
                  caption: 'vs ${_int(s.previousOrders)} la période précédente',
                  onTap: () => context.go(AdminPaths.orders),
                ),
                AdminStatCard(
                  icon: Icons.payments_rounded,
                  label: 'Ventes livrées',
                  value: _money(s.revenue),
                  color: AdminColors.green,
                  trend: trendPercent(s.revenue, s.previousRevenue),
                  caption: 'Commandes remises aux clients',
                ),
                AdminStatCard(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Nouveaux clients',
                  value: users.hasData ? _int(newClients) : '…',
                  color: AdminColors.blue,
                  trend: users.hasData
                      ? trendPercent(newClients, prevClients)
                      : null,
                  caption: t == null
                      ? null
                      : '${_int(t.clients)} clients · ${_int(t.sellers)} commerces · ${_int(t.delivers)} livreurs',
                  onTap: () => context.go(AdminPaths.clients),
                ),
                AdminStatCard(
                  icon: Icons.timer_rounded,
                  label: 'Livraison moyenne',
                  value: s.deliveryMinutes == null
                      ? '—'
                      : _duration(s.deliveryMinutes!),
                  color: AdminColors.violet,
                  trend: s.deliveryMinutes == null ||
                          s.previousDeliveryMinutes == null
                      ? null
                      : trendPercent(
                          s.deliveryMinutes!, s.previousDeliveryMinutes!),
                  trendInverse: true,
                  caption: s.deliveries == 0
                      ? 'Aucune livraison mesurée'
                      : 'Sur ${_int(s.deliveries)} livraison${s.deliveries > 1 ? 's' : ''}',
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Graphiques ─────────────────────────────────────────────────────────

  Widget _ordersChart(List<DashOrder> orders, DateTime now) {
    final days = dailyOrders(orders, now, _days);
    final total = days.fold(0, (s, d) => s + d.count);
    final best = days.fold(0, (m, d) => d.count > m ? d.count : m);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCardHeader(
            title: 'Commandes par jour',
            subtitle: _periods[_days],
            trailing: Wrap(
              spacing: 18.0,
              children: [
                _mini('Total', _int(total)),
                _mini('Record', _int(best)),
              ],
            ),
          ),
          AdminAreaChart(
            values: [for (final d in days) d.count.toDouble()],
            labels: [
              for (final d in days) DateFormat('d MMM', 'fr').format(d.day)
            ],
            tooltipLabels: [
              for (final d in days)
                DateFormat('EEEE d MMMM', 'fr').format(d.day)
            ],
            format: (v) => v.round().toString(),
            height: 300.0,
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: AdminText.label(size: 12.0)),
          Text(value, style: AdminText.h2()),
        ],
      );

  Widget _statusCard(List<DashOrder> inPeriod) {
    final groups = statusBreakdown(inPeriod);
    final header = AdminCardHeader(
        title: 'Statuts des commandes', subtitle: _periods[_days]);
    final donut = AdminDonut(
      centerLabel: 'commandes',
      size: 168.0,
      slices: [
        for (final g in groups)
          (label: g.label, value: g.count.toDouble(), color: g.color),
      ],
    );
    return AdminCard(
      // Hauteur imposée (grand écran) : l'anneau est centré dans la carte,
      // à la même hauteur que la courbe voisine.
      child: LayoutBuilder(
        builder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (c.hasBoundedHeight)
              Expanded(child: Center(child: donut))
            else
              donut,
          ],
        ),
      ),
    );
  }

  // ── Commandes récentes ─────────────────────────────────────────────────

  Widget _recentOrders(List<DashOrder> latest) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCardHeader(
            title: 'Commandes récentes',
            subtitle: 'Les 20 dernières commandes, 5 par page',
            trailing: TextButton.icon(
              onPressed: () => context.go(AdminPaths.orders),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18.0),
              label: const Text('Tout voir'),
            ),
          ),
          AdminTable<DashOrder>(
            rows: latest,
            empty: const AdminEmpty(
                icon: Icons.receipt_long_rounded,
                title: 'Aucune commande',
                message: 'Les commandes apparaîtront ici.'),
            breakpoint: 560.0,
            onTap: (o) => showAdminOrderDetail(context, o, known: _people),
            actionsWidth: 44.0,
            actions: (o) => [
              AdminActionDot(
                icon: Icons.visibility_rounded,
                tooltip: 'Voir la commande',
                onTap: () => showAdminOrderDetail(context, o, known: _people),
              ),
            ],
            columns: [
              AdminColumn(
                  label: 'Commande',
                  flex: 3,
                  cell: (o) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              o.reference.isEmpty
                                  ? 'Sans référence'
                                  : o.reference,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdminText.strong(size: 13.0)),
                          Text(_ago(o.createdAt),
                              style: AdminText.label(
                                  color: AdminColors.faint, size: 12.0)),
                        ],
                      )),
              AdminColumn(
                  label: 'Client',
                  flex: 4,
                  cell: (o) => Row(
                        children: [
                          AdminAvatar(
                              name: _name(o.userPath),
                              photo: _people[o.userPath]?.photo,
                              size: 30.0),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(_name(o.userPath),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminText.body(size: 13.0)),
                          ),
                        ],
                      )),
              AdminColumn(
                  label: 'Commerce',
                  flex: 3,
                  cell: (o) => Text(_name(o.sellerPath),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.body(size: 13.0))),
              AdminColumn(
                  label: 'Montant',
                  flex: 2,
                  cell: (o) =>
                      Text(fcfa(o.total), style: AdminText.strong(size: 13.0))),
              AdminColumn(
                  label: 'Statut',
                  flex: 3,
                  cell: (o) => AdminBadge(orderStatusShort(o.status),
                      tone: orderStatusTone(o.status))),
            ],
            compact: _compactRow,
          ),
        ],
      ),
    );
  }

  String _name(String? path) =>
      path == null ? '—' : (_people[path]?.name ?? '…');

  Widget _compactRow(DashOrder o) {
    return InkWell(
      onTap: () => showAdminOrderDetail(context, o, known: _people),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AdminColors.border)),
        ),
        child: Row(
          children: [
            AdminAvatar(
                name: _name(o.userPath),
                photo: _people[o.userPath]?.photo,
                size: 40.0),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name(o.userPath),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.strong(size: 13.5)),
                  Text('${_name(o.sellerPath)} · ${_ago(o.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(size: 12.0)),
                  const SizedBox(height: 6.0),
                  AdminBadge(orderStatusShort(o.status),
                      tone: orderStatusTone(o.status)),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Text(fcfa(o.total), style: AdminText.strong(size: 13.5)),
          ],
        ),
      ),
    );
  }

  // ── Alertes et zones ───────────────────────────────────────────────────

  AdminTone _tone(OpsLevel l) => (fg: l.color, bg: l.bg);

  Widget _alertRow(
      IconData icon, String label, String value, String unit, OpsLevel level) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          AdminIconBadge(icon,
              color: level.color, background: level.bg, size: 42.0, round: false),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.label(color: AdminColors.text)),
                Text.rich(TextSpan(children: [
                  TextSpan(text: value, style: AdminText.h2()),
                  TextSpan(
                      text: ' $unit', style: AdminText.label(size: 12.0)),
                ])),
              ],
            ),
          ),
          AdminBadge(level.label, tone: _tone(level)),
        ],
      ),
    );
  }

  Widget _alertsCard(DateTime now, List<DashOrder>? inProgress) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminCardHeader(
              title: 'Alertes', subtitle: 'Mises à jour chaque minute'),
          Builder(
            builder: (context) {
              final a = orderAlerts(
                  (inProgress ?? const <DashOrder>[])
                      .map((o) => (status: o.status, createdAt: o.createdAt)),
                  now);
              final ready = inProgress != null;
              return Column(
                children: [
                  _alertRow(Icons.timer_off_rounded, 'Commandes en retard (+2 h)',
                      ready ? '${a.late}' : '…', 'commandes', countLevel(a.late)),
                  _alertRow(
                      Icons.hourglass_bottom_rounded,
                      'Sans réponse du vendeur (+15 min)',
                      ready ? '${a.noResponse}' : '…',
                      'commandes',
                      countLevel(a.noResponse)),
                ],
              );
            },
          ),
          StreamBuilder<List<String?>>(
            stream: _payments,
            builder: (context, snap) {
              final rate = paymentFailureRate(snap.data ?? const []);
              return _alertRow(
                Icons.credit_card_off_rounded,
                'Échecs de paiement (7 jours)',
                !snap.hasData
                    ? '…'
                    : rate == null
                        ? '—'
                        : rate.toStringAsFixed(rate < 10 ? 1 : 0),
                rate == null ? 'aucun paiement' : '%',
                rateLevel(snap.hasData ? rate : null),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _zonesCard(List<DashOrder>? inProgress) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminCardHeader(
              title: 'Commandes en cours par zone',
              subtitle: 'Quartiers de livraison'),
          Builder(
            builder: (context) {
              if (inProgress == null) return const AdminLoading(height: 100.0);
              final zones = ordersByZone(inProgress
                  .map((o) => (zone: o.zone, status: o.status)));
              if (zones.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('Aucune commande en cours',
                      textAlign: TextAlign.center,
                      style: AdminText.label()),
                );
              }
              final max = zones.first.total;
              return Column(
                children: [
                  for (final z in zones.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(z.zone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AdminText.strong(size: 13.0)),
                              ),
                              Text(
                                  '${z.total}'
                                  '${z.delivering > 0 ? ' · ${z.delivering} en livraison' : ''}',
                                  style: AdminText.label(size: 12.5)),
                            ],
                          ),
                          const SizedBox(height: 6.0),
                          AdminBar(value: z.total / max),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Formats ────────────────────────────────────────────────────────────

  static String _int(num n) => NumberFormat.decimalPattern('fr').format(n);

  /// Montant abrégé pour les grandes valeurs (1,2 M F).
  static String _money(double v) {
    if (v >= 1000000) {
      return '${NumberFormat('#,##0.0', 'fr').format(v / 1000000)} M F';
    }
    return fcfa(v);
  }

  static String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
  }

  String _ago(DateTime? d) {
    if (d == null) return '—';
    final diff = _now.difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat('d MMM yyyy', 'fr').format(d);
  }
}
