import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/backend/order_status.dart';
import '/noc/ops_alerts.dart'
    show OpsThresholds, paymentFailureRate, countLevel, rateLevel, OpsLevel;
import '/noc/sales/sales_common.dart' show fcfa;
import '/noc/ui/admin_charts.dart';
import '/noc/ui/admin_export.dart';
import '/noc/ui/admin_table.dart';
import 'admin_dashboard_data.dart';
import 'admin_order_detail.dart';
import 'admin_shell.dart';

typedef _People = Map<String, ({String name, String photo, String phone})>;

/// Noms des clients, commerces et livreurs, chargés à la demande.
mixin _Names<W extends StatefulWidget> on State<W> {
  final _People people = {};
  final Set<String> _asked = {};

  void ensureNames(AdminDashboardSource src, Iterable<String?> paths) {
    final missing =
        paths.whereType<String>().where((p) => _asked.add(p)).toList();
    if (missing.isEmpty) return;
    src.names(missing).then((m) {
      if (mounted) setState(() => people.addAll(m));
    }).catchError((_) {});
  }

  String nameOf(String? path, {String none = '—'}) =>
      path == null ? none : (people[path]?.name ?? '…');
}

String _date(DateTime? d) =>
    d == null ? '—' : DateFormat('d MMM yyyy, HH:mm', 'fr').format(d);

AdminTone _tone(OpsLevel l) => (fg: l.color, bg: l.bg);

// ── Alertes ──────────────────────────────────────────────────────────────

/// Alertes (/alertes) : commandes en retard, sans réponse du vendeur, non
/// reçues, et paiements échoués, avec le détail de chacune.
class AdminAlertsWidget extends StatefulWidget {
  const AdminAlertsWidget({super.key, this.clock});

  static String routeName = 'AdminAlerts';
  static String routePath = '/alertes';

  final DateTime Function()? clock;

  @override
  State<AdminAlertsWidget> createState() => _AdminAlertsWidgetState();
}

class _AdminAlertsWidgetState extends State<AdminAlertsWidget>
    with _Names<AdminAlertsWidget> {
  final _src = AdminDashboardSource.instance;
  DateTime get _now => (widget.clock ?? DateTime.now)();

  late final Stream<List<DashOrder>> _inProgress = _src.inProgress();
  late final Stream<List<DashOrder>> _recent =
      _src.ordersSince(_now.subtract(const Duration(days: 30)));
  late final Stream<List<Map<String, dynamic>>> _payments =
      _src.payments(_now.subtract(OpsThresholds.paymentWindow));
  Timer? _tick;

  /// Dernières listes affichées (pour l'export).
  ({
    List<DashOrder> late,
    List<DashOrder> silent,
    List<DashOrder> notReceived,
    List<Map<String, dynamic>> failed,
  })? _last;

  AdminExportData? _export() {
    final l = _last;
    if (l == null) return null;
    final now = _now;
    String since(DashOrder o) => o.createdAt == null
        ? ''
        : adminDuration(now.difference(o.createdAt!));
    List<Object?> order(String type, DashOrder o) => [
          type,
          o.reference,
          _date(o.createdAt),
          since(o),
          nameOf(o.userPath),
          nameOf(o.sellerPath),
          people[o.sellerPath]?.phone ?? '',
          orderStatusShort(o.status),
          o.total,
        ];
    final total = l.late.length +
        l.silent.length +
        l.notReceived.length +
        l.failed.length;
    return AdminExportData(
      title: 'Alertes',
      subtitle: '${l.late.length} en retard · ${l.silent.length} sans réponse'
          ' · ${l.notReceived.length} non reçues (30 j)'
          ' · ${l.failed.length} paiements échoués (7 j)',
      fileName: 'alertes',
      headers: ['Alerte', 'Référence', 'Date', 'Depuis', 'Client', 'Commerce',
        'Téléphone commerce', 'Statut / motif', 'Montant'],
      flex: [3, 3, 3, 2, 3, 3, 3, 3, 2],
      moneyColumns: {8},
      rows: total == 0
          ? const []
          : [
              for (final o in l.late) order('En retard (+2 h)', o),
              for (final o in l.silent) order('Sans réponse (+15 min)', o),
              for (final o in l.notReceived) order('Non reçue', o),
              for (final p in l.failed)
                [
                  'Paiement échoué',
                  (p['order_id'] as String?) ?? '',
                  _date(p['created_at'] as DateTime?),
                  '',
                  nameOf(p['user_path'] as String?),
                  '',
                  '',
                  ((p['message'] as String?) ?? '').trim().isEmpty
                      ? 'Non précisé'
                      : p['message'] as String,
                  p['amount'] is num ? p['amount'] as num : null,
                ],
            ],
    );
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      current: 'alerts',
      title: 'Alertes',
      subtitle: 'Ce qui demande une action, mis à jour chaque minute',
      actions: [AdminExportButton(data: _export)],
      body: StreamBuilder<List<DashOrder>>(
        stream: _inProgress,
        builder: (context, live) => StreamBuilder<List<DashOrder>>(
          stream: _recent,
          builder: (context, recent) =>
              StreamBuilder<List<Map<String, dynamic>>>(
            stream: _payments,
            builder: (context, pays) {
              if (!live.hasData || !recent.hasData) {
                return const AdminLoading(height: 320.0);
              }
              return _content(live.data!, recent.data!, pays.data ?? const []);
            },
          ),
        ),
      ),
    );
  }

  Widget _content(List<DashOrder> live, List<DashOrder> recent,
      List<Map<String, dynamic>> pays) {
    final now = _now;
    Duration age(DashOrder o) =>
        o.createdAt == null ? Duration.zero : now.difference(o.createdAt!);
    final late = live.where((o) => age(o) > OpsThresholds.lateAfter).toList();
    final silent = live
        .where((o) =>
            ['', OrderStatus.pending].contains(o.status) &&
            age(o) > OpsThresholds.noResponseAfter)
        .toList();
    final notReceived =
        recent.where((o) => o.status == OrderStatus.notReceived).toList();
    final failed = pays.where((p) => p['status'] == 'Echec').toList();
    final rate = paymentFailureRate(pays.map((p) => p['status'] as String?));
    _last = (late: late, silent: silent, notReceived: notReceived, failed: failed);
    ensureNames(_src, [
      for (final o in [...late, ...silent, ...notReceived]) ...[
        o.userPath,
        o.sellerPath,
        o.delivererPath,
      ],
      for (final p in failed) p['user_path'] as String?,
    ]);

    return AdminScroll(
      children: [
        AdminGrid(
          minItemWidth: 230.0,
          children: [
            _kpi(Icons.timer_off_rounded, 'En retard (+2 h)', '${late.length}',
                countLevel(late.length)),
            _kpi(Icons.hourglass_bottom_rounded, 'Sans réponse (+15 min)',
                '${silent.length}', countLevel(silent.length)),
            _kpi(Icons.report_rounded, 'Non reçues (30 j)',
                '${notReceived.length}', countLevel(notReceived.length, medium: 0)),
            _kpi(
                Icons.credit_card_off_rounded,
                'Échecs de paiement (7 j)',
                rate == null ? '—' : '${rate.toStringAsFixed(rate < 10 ? 1 : 0)} %',
                rateLevel(rate)),
          ],
        ),
        const SizedBox(height: 20.0),
        _orderSection(
            'Commandes en retard',
            'Toujours en cours plus de 2 h après la commande',
            late,
            Icons.timer_off_rounded),
        const SizedBox(height: 20.0),
        _orderSection(
            'Sans réponse du vendeur',
            'À confirmer depuis plus de 15 min : relancer le commerce',
            silent,
            Icons.hourglass_bottom_rounded),
        const SizedBox(height: 20.0),
        _orderSection(
            'Commandes non reçues',
            'Signalées par le client sur les 30 derniers jours',
            notReceived,
            Icons.report_rounded),
        const SizedBox(height: 20.0),
        _paymentsSection(failed),
      ],
    );
  }

  Widget _kpi(IconData icon, String label, String value, OpsLevel level) {
    return AdminCard(
      padding: const EdgeInsets.all(18.0),
      child: Row(
        children: [
          AdminIconBadge(icon,
              color: level.color, background: level.bg, size: 50.0),
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
                Text(value, style: AdminText.display()),
                const SizedBox(height: 4.0),
                AdminBadge(level.label, tone: _tone(level)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderSection(
      String title, String subtitle, List<DashOrder> rows, IconData icon) {
    final now = _now;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCardHeader(
            title: title,
            subtitle: subtitle,
            trailing: AdminBadge('${rows.length}',
                tone: rows.isEmpty ? kToneGreen : kToneRed),
          ),
          AdminTable<DashOrder>(
            rows: rows,
            initialSort: 1,
            initialAscending: false,
            empty: AdminEmpty(
                icon: Icons.check_circle_rounded,
                title: 'Rien à signaler',
                message: 'Aucune commande dans cette situation.'),
            onTap: (o) => showAdminOrderDetail(context, o, known: people),
            actions: (o) => [
              AdminActionDot(
                icon: Icons.visibility_rounded,
                tooltip: 'Voir la commande',
                onTap: () => showAdminOrderDetail(context, o, known: people),
              ),
            ],
            actionsWidth: 50.0,
            columns: [
              AdminColumn(
                  label: 'Commande',
                  flex: 3,
                  cell: (o) => Text(
                      o.reference.isEmpty ? 'Sans référence' : o.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.strong(size: 13.0)),
                  sortKey: (o) => o.reference),
              AdminColumn(
                  label: 'Depuis',
                  flex: 2,
                  cell: (o) => Text(
                      o.createdAt == null
                          ? '—'
                          : adminDuration(now.difference(o.createdAt!)),
                      style: AdminText.strong(
                          size: 13.0, color: AdminColors.red)),
                  sortKey: (o) => o.createdAt == null
                      ? null
                      : now.difference(o.createdAt!).inMinutes),
              AdminColumn(
                  label: 'Client',
                  flex: 3,
                  cell: (o) => _text(nameOf(o.userPath))),
              AdminColumn(
                  label: 'Commerce',
                  flex: 3,
                  cell: (o) => _text(nameOf(o.sellerPath))),
              AdminColumn(
                  label: 'Téléphone commerce',
                  flex: 2,
                  cell: (o) => _text(people[o.sellerPath]?.phone ?? '—')),
              AdminColumn(
                  label: 'Statut',
                  flex: 3,
                  cell: (o) => AdminBadge(orderStatusShort(o.status),
                      tone: orderStatusTone(o.status))),
            ],
            compact: (o) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.reference.isEmpty ? 'Sans référence' : o.reference,
                    style: AdminText.strong(size: 13.0)),
                Text(
                    '${nameOf(o.sellerPath)} · depuis ${o.createdAt == null ? '—' : adminDuration(now.difference(o.createdAt!))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.label(size: 12.5)),
                const SizedBox(height: 6.0),
                AdminBadge(orderStatusShort(o.status),
                    tone: orderStatusTone(o.status)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsSection(List<Map<String, dynamic>> failed) {
    DateTime? at(Map<String, dynamic> p) => p['created_at'] as DateTime?;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCardHeader(
            title: 'Paiements échoués',
            subtitle: '7 derniers jours (MTN Mobile Money)',
            trailing: AdminBadge('${failed.length}',
                tone: failed.isEmpty ? kToneGreen : kToneOrange),
          ),
          AdminTable<Map<String, dynamic>>(
            rows: failed,
            initialSort: 0,
            empty: const AdminEmpty(
                icon: Icons.check_circle_rounded,
                title: 'Aucun échec',
                message: 'Tous les paiements récents ont abouti.'),
            columns: [
              AdminColumn(
                  label: 'Date',
                  flex: 3,
                  cell: (p) => _text(_date(at(p))),
                  sortKey: (p) => at(p)),
              AdminColumn(
                  label: 'Client',
                  flex: 3,
                  cell: (p) => _text(nameOf(p['user_path'] as String?))),
              AdminColumn(
                  label: 'Montant',
                  flex: 2,
                  cell: (p) => Text(
                      p['amount'] is num ? fcfa(p['amount'] as num) : '—',
                      style: AdminText.strong(size: 13.0)),
                  sortKey: (p) => (p['amount'] as num?)?.toDouble()),
              AdminColumn(
                  label: 'Motif',
                  flex: 5,
                  cell: (p) => _text(
                      ((p['message'] as String?) ?? '').trim().isEmpty
                          ? 'Non précisé'
                          : p['message'] as String,
                      lines: 2)),
            ],
            compact: (p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(nameOf(p['user_path'] as String?),
                            style: AdminText.strong(size: 13.0))),
                    Text(p['amount'] is num ? fcfa(p['amount'] as num) : '—',
                        style: AdminText.strong(size: 13.0)),
                  ],
                ),
                Text(_date(at(p)), style: AdminText.label(size: 12.0)),
                if (((p['message'] as String?) ?? '').isNotEmpty)
                  Text(p['message'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(size: 12.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _text(String v, {int lines = 1}) => Text(v,
    maxLines: lines,
    overflow: TextOverflow.ellipsis,
    style: AdminText.body(size: 13.0));

// ── Zones ────────────────────────────────────────────────────────────────

/// Activité par zone de livraison (/zones) : commandes en cours, en
/// livraison, volume et délai moyen sur 30 jours.
class AdminZonesWidget extends StatefulWidget {
  const AdminZonesWidget({super.key, this.clock});

  static String routeName = 'AdminZones';
  static String routePath = '/zones';

  final DateTime Function()? clock;

  @override
  State<AdminZonesWidget> createState() => _AdminZonesWidgetState();
}

typedef ZoneRow = ({
  String zone,
  int live,
  int delivering,
  int month,
  int delivered,
  int? avgMinutes,
});

/// Regroupement par zone (pur, testé).
List<ZoneRow> zoneRows(List<DashOrder> live, List<DashOrder> month) {
  String key(DashOrder o) =>
      o.zone.trim().isEmpty ? 'Zone non précisée' : o.zone.trim();
  final zones = {...live.map(key), ...month.map(key)};
  final rows = <ZoneRow>[];
  for (final z in zones) {
    final l = live.where((o) => key(o) == z);
    final m = month.where((o) => key(o) == z).toList();
    final timed = m.where((o) =>
        o.createdAt != null &&
        o.deliveredAt != null &&
        !o.deliveredAt!.isBefore(o.createdAt!));
    final total =
        timed.fold(0, (s, o) => s + o.deliveredAt!.difference(o.createdAt!).inMinutes);
    rows.add((
      zone: z,
      live: l.length,
      delivering: l.where((o) => o.status == OrderStatus.delivering).length,
      month: m.length,
      delivered: m.where((o) => OrderStatus.successful.contains(o.status)).length,
      avgMinutes: timed.isEmpty ? null : (total / timed.length).round(),
    ));
  }
  rows.sort((a, b) => b.live != a.live ? b.live - a.live : b.month - a.month);
  return rows;
}

class _AdminZonesWidgetState extends State<AdminZonesWidget> {
  final _src = AdminDashboardSource.instance;
  DateTime get _now => (widget.clock ?? DateTime.now)();
  late final Stream<List<DashOrder>> _live = _src.inProgress();
  late final Stream<List<DashOrder>> _month =
      _src.ordersSince(_now.subtract(const Duration(days: 30)));
  List<ZoneRow>? _rows;

  AdminExportData? _export() {
    final rows = _rows;
    if (rows == null) return null;
    return AdminExportData(
      title: 'Livraisons par zone',
      subtitle: 'Commandes en cours et 30 derniers jours · ${rows.length} zones',
      fileName: 'zones',
      headers: ['Zone', 'En cours', 'En livraison', 'Commandes (30 j)',
        'Livrées (30 j)', 'Délai moyen (min)'],
      flex: [4, 2, 2, 2, 2, 2],
      rows: [
        for (final r in rows)
          [r.zone, r.live, r.delivering, r.month, r.delivered, r.avgMinutes],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      current: 'zones',
      title: 'Livraisons par zone',
      subtitle: 'Quartiers de livraison : en cours et 30 derniers jours',
      actions: [AdminExportButton(data: _export)],
      body: StreamBuilder<List<DashOrder>>(
        stream: _live,
        builder: (context, live) => StreamBuilder<List<DashOrder>>(
          stream: _month,
          builder: (context, month) {
            if (!live.hasData || !month.hasData) {
              return const AdminLoading(height: 320.0);
            }
            final rows = zoneRows(live.data!, month.data!);
            _rows = rows;
            final maxLive = rows.fold(0, (m, r) => r.live > m ? r.live : m);
            final maxMonth = rows.fold(0, (m, r) => r.month > m ? r.month : m);
            return AdminScroll(
              children: [
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminCardHeader(
                        title: '${rows.length} zone${rows.length > 1 ? 's' : ''}',
                        subtitle:
                            '${live.data!.length} commandes en cours · ${month.data!.length} sur 30 jours',
                      ),
                      AdminTable<ZoneRow>(
                        rows: rows,
                        empty: const AdminEmpty(
                            icon: Icons.place_rounded,
                            title: 'Aucune commande',
                            message: 'Aucune zone de livraison à afficher.'),
                        columns: [
                          AdminColumn(
                              label: 'Zone',
                              flex: 3,
                              cell: (r) => Row(
                                    children: [
                                      const Icon(Icons.place_rounded,
                                          size: 16.0, color: AdminColors.red),
                                      const SizedBox(width: 6.0),
                                      Flexible(
                                          child: Text(r.zone,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AdminText.strong(
                                                  size: 13.0))),
                                    ],
                                  ),
                              sortKey: (r) => r.zone.toLowerCase()),
                          AdminColumn(
                              label: 'En cours',
                              flex: 3,
                              cell: (r) => _barCell(
                                  r.live,
                                  maxLive,
                                  r.delivering > 0
                                      ? '${r.delivering} en livraison'
                                      : null,
                                  AdminColors.red),
                              sortKey: (r) => r.live),
                          AdminColumn(
                              label: '30 jours',
                              flex: 3,
                              cell: (r) => _barCell(r.month, maxMonth,
                                  '${r.delivered} livrées', AdminColors.blue),
                              sortKey: (r) => r.month),
                          AdminColumn(
                              label: 'Délai moyen',
                              flex: 2,
                              cell: (r) => Text(
                                  r.avgMinutes == null
                                      ? '—'
                                      : adminDuration(
                                          Duration(minutes: r.avgMinutes!)),
                                  style: AdminText.strong(size: 13.0)),
                              sortKey: (r) => r.avgMinutes),
                        ],
                        compact: (r) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.zone, style: AdminText.strong(size: 13.5)),
                            const SizedBox(height: 4.0),
                            Text(
                                '${r.live} en cours · ${r.month} sur 30 j · délai ${r.avgMinutes == null ? '—' : adminDuration(Duration(minutes: r.avgMinutes!))}',
                                style: AdminText.label(size: 12.5)),
                            const SizedBox(height: 6.0),
                            AdminBar(
                                value: maxLive == 0 ? 0 : r.live / maxLive),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _barCell(int value, int max, String? note, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('$value', style: AdminText.strong(size: 13.0)),
            if (note != null) ...[
              const SizedBox(width: 6.0),
              Flexible(
                  child: Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(size: 11.5))),
            ],
          ],
        ),
        const SizedBox(height: 5.0),
        AdminBar(value: max == 0 ? 0 : value / max, color: color),
      ],
    );
  }
}
