import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/backend/order_status.dart';
import '/noc/ui/admin_kit.dart';

/// Données du tableau de bord : lecture Firestore (remplaçable dans les tests)
/// et calculs purs (périodes, évolutions, courbe, répartition des statuts).

typedef DashOrder = ({
  String id,
  String reference,
  String status,
  double total,
  DateTime? createdAt,
  DateTime? deliveredAt,
  String zone,
  String location,
  String? userPath,
  String? sellerPath,
  String? delivererPath,
  // Remise : code vérifié, photo, problème signalé par le livreur.
  bool codeVerified,
  String photo,
  String issue,
});

DateTime? _date(dynamic v) => v is Timestamp
    ? v.toDate()
    : v is DateTime
        ? v
        : null;

DashOrder dashOrderFrom(String id, Map<String, dynamic> d) => (
      id: id,
      reference: (d['order_unique_reference'] as String?) ?? '',
      status: (d['status'] as String?) ?? '',
      total: (d['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: _date(d['created_at']),
      deliveredAt: _date(d['delivered_at']),
      zone: (d['delivery_zone'] as String?) ?? '',
      location: (d['delivery_location'] as String?) ?? '',
      userPath: (d['user_ref'] as DocumentReference?)?.path,
      sellerPath: (d['seller_ref'] as DocumentReference?)?.path,
      delivererPath: (d['deliver_reference'] as DocumentReference?)?.path,
      codeVerified: d['delivery_code_verified'] == true,
      photo: (d['delivery_photo'] as String?) ?? '',
      issue: ((d['delivery_issue'] as Map?)?['label'] as String?) ?? '',
    );

/// Source des données ; [AdminDashboardSource.instance] lit Firestore.
class AdminDashboardSource {
  AdminDashboardSource({
    required this.ordersSince,
    required this.inProgress,
    required this.newUsersSince,
    required this.totals,
    required this.paymentStatusesSince,
    required this.names,
    required this.orderItems,
    Stream<List<Map<String, dynamic>>> Function(DateTime since)? payments,
  }) : payments = payments ?? ((_) => Stream.value(const []));

  /// Paiements depuis une date (statut, montant, message, client).
  final Stream<List<Map<String, dynamic>>> Function(DateTime since) payments;

  /// Commandes créées depuis une date (direct).
  final Stream<List<DashOrder>> Function(DateTime since) ordersSince;

  /// Commandes encore en cours, quelle que soit leur date (direct).
  final Stream<List<DashOrder>> Function() inProgress;

  /// Dates d'inscription des clients inscrits depuis une date.
  final Future<List<DateTime>> Function(DateTime since) newUsersSince;

  /// Nombres totaux : clients, commerçants, livreurs.
  final Future<({int clients, int sellers, int delivers})> Function() totals;

  /// Statuts des paiements depuis une date (taux d'échec).
  final Stream<List<String?>> Function(DateTime since) paymentStatusesSince;

  /// Noms affichés (et photo) de documents User, par chemin.
  final Future<Map<String, ({String name, String photo, String phone})>>
      Function(Iterable<String> paths) names;

  /// Articles d'une commande (collection OrderItems).
  final Future<List<Map<String, dynamic>>> Function(String reference)
      orderItems;

  static AdminDashboardSource? _override;

  /// Remplace la source dans les tests.
  @visibleForTesting
  static set override(AdminDashboardSource? s) => _override = s;

  static AdminDashboardSource get instance => _override ?? _firestore();

  static AdminDashboardSource _firestore() {
    final db = FirebaseFirestore.instance;
    Stream<List<DashOrder>> orders(Query<Map<String, dynamic>> q) =>
        q.snapshots().map((s) =>
            [for (final d in s.docs) dashOrderFrom(d.id, d.data())]);
    Future<int> count(String role) async =>
        (await db.collection('User').where('role', isEqualTo: role).count().get())
            .count ??
        0;
    return AdminDashboardSource(
      ordersSince: (since) => orders(db.collection('Orders').where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(since))),
      inProgress: () => orders(db
          .collection('Orders')
          .where('status', whereIn: OrderStatus.inProgress)),
      // Filtre sur le rôle fait ici : évite un index composite.
      newUsersSince: (since) async {
        final s = await db
            .collection('User')
            .where('created_time',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since))
            .get();
        return [
          for (final d in s.docs)
            if ((d.data()['role'] ?? 'User') == 'User' &&
                _date(d.data()['created_time']) != null)
              _date(d.data()['created_time'])!,
        ];
      },
      totals: () async {
        final r = await Future.wait(
            [count('User'), count('Seller'), count('Deliver')]);
        return (clients: r[0], sellers: r[1], delivers: r[2]);
      },
      paymentStatusesSince: (since) => db
          .collection('Paiement')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .snapshots()
          .map((s) => [for (final d in s.docs) d.data()['status'] as String?]),
      names: (paths) async {
        final list = await Future.wait(
            paths.toSet().map((p) => db.doc(p).get()));
        return {
          for (final d in list)
            if (d.exists)
              d.reference.path: (
                name: ((d.data()?['display_name'] as String?)?.trim()
                            .isNotEmpty ==
                        true)
                    ? (d.data()!['display_name'] as String).trim()
                    : (d.data()?['email'] as String?) ?? 'Sans nom',
                photo: (d.data()?['photo_url'] as String?) ?? '',
                phone: (d.data()?['phone_number'] as String?) ?? '',
              ),
        };
      },
      payments: (since) => db
          .collection('Paiement')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .snapshots()
          .map((s) => [
                for (final d in s.docs)
                  {
                    ...d.data(),
                    'id': d.id,
                    'created_at': _date(d.data()['created_at']),
                    'user_path':
                        (d.data()['user_ref'] as DocumentReference?)?.path,
                  },
              ]),
      orderItems: (reference) async {
        if (reference.isEmpty) return const [];
        final s = await db
            .collection('OrderItems')
            .where('order_ref', isEqualTo: reference)
            .get();
        return [for (final d in s.docs) d.data()];
      },
    );
  }
}

// ── Calculs ──────────────────────────────────────────────────────────────

/// Évolution en % entre deux valeurs (null si pas de référence).
double? trendPercent(num current, num previous) {
  if (previous == 0) return current == 0 ? 0.0 : null;
  return (current - previous) * 100 / previous;
}

typedef DashPeriod = ({
  int orders,
  int previousOrders,
  double revenue,
  double previousRevenue,
  int? deliveryMinutes,
  int? previousDeliveryMinutes,
  int deliveries,
});

bool _inWindow(DateTime? d, DateTime from, DateTime to) =>
    d != null && !d.isBefore(from) && d.isBefore(to);

int? _avgMinutes(Iterable<DashOrder> orders) {
  var total = 0;
  var n = 0;
  for (final o in orders) {
    final c = o.createdAt;
    final d = o.deliveredAt;
    if (c == null || d == null || d.isBefore(c)) continue;
    total += d.difference(c).inMinutes;
    n++;
  }
  return n == 0 ? null : (total / n).round();
}

/// Chiffres de la période [days] jours avant [now], comparés à la précédente.
DashPeriod periodStats(List<DashOrder> orders, DateTime now, int days) {
  final from = now.subtract(Duration(days: days));
  final prevFrom = from.subtract(Duration(days: days));
  final cur = orders.where((o) => _inWindow(o.createdAt, from, now)).toList();
  final prev =
      orders.where((o) => _inWindow(o.createdAt, prevFrom, from)).toList();
  double revenue(List<DashOrder> l) => l
      .where((o) => OrderStatus.successful.contains(o.status))
      .fold(0.0, (s, o) => s + o.total);
  final delivered = orders.where((o) => _inWindow(o.deliveredAt, from, now));
  final prevDelivered =
      orders.where((o) => _inWindow(o.deliveredAt, prevFrom, from));
  return (
    orders: cur.length,
    previousOrders: prev.length,
    revenue: revenue(cur),
    previousRevenue: revenue(prev),
    deliveryMinutes: _avgMinutes(delivered),
    previousDeliveryMinutes: _avgMinutes(prevDelivered),
    deliveries: delivered.where((o) => o.createdAt != null).length,
  );
}

/// Nombre de commandes par jour sur les [days] derniers jours (le dernier
/// élément = aujourd'hui).
List<({DateTime day, int count})> dailyOrders(
    List<DashOrder> orders, DateTime now, int days) {
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: days - 1));
  final counts = List<int>.filled(days, 0);
  for (final o in orders) {
    final c = o.createdAt;
    if (c == null) continue;
    final d = DateTime(c.year, c.month, c.day);
    // Différence en jours calendaires (sans effet des changements d'heure).
    final i = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    if (i >= 0 && i < days) counts[i]++;
  }
  return [
    for (var i = 0; i < days; i++)
      (day: DateTime(start.year, start.month, start.day + i), count: counts[i]),
  ];
}

/// Groupes de statuts affichés dans l'anneau.
typedef StatusGroup = ({String label, Color color, List<String> statuses});

final List<StatusGroup> kStatusGroups = [
  (
    label: 'À confirmer',
    color: AdminColors.orange,
    statuses: ['', OrderStatus.pending],
  ),
  (
    label: 'En préparation',
    color: AdminColors.violet,
    statuses: [OrderStatus.preparing, OrderStatus.ready],
  ),
  (
    label: 'En livraison',
    color: AdminColors.blue,
    statuses: [OrderStatus.delivering],
  ),
  (
    label: 'Livrées',
    color: AdminColors.green,
    statuses: OrderStatus.successful,
  ),
  (
    label: 'Annulées ou refusées',
    color: AdminColors.red,
    statuses: [
      OrderStatus.cancelled,
      OrderStatus.refused,
      OrderStatus.notReceived,
    ],
  ),
];

/// Répartition par groupe de statut des commandes de la période.
List<({String label, Color color, int count})> statusBreakdown(
    Iterable<DashOrder> orders) {
  final counts = List<int>.filled(kStatusGroups.length, 0);
  for (final o in orders) {
    final i = kStatusGroups.indexWhere((g) => g.statuses.contains(o.status));
    if (i >= 0) counts[i]++;
  }
  return [
    for (var i = 0; i < kStatusGroups.length; i++)
      (
        label: kStatusGroups[i].label,
        color: kStatusGroups[i].color,
        count: counts[i],
      ),
  ];
}

/// Couleur d'une pastille de statut de commande.
AdminTone orderStatusTone(String status) => switch (status) {
      '' || OrderStatus.pending => kToneOrange,
      OrderStatus.preparing || OrderStatus.ready => kToneViolet,
      OrderStatus.delivering => kToneBlue,
      OrderStatus.delivered || OrderStatus.received => kToneGreen,
      OrderStatus.refused ||
      OrderStatus.cancelled ||
      OrderStatus.notReceived =>
        kToneRed,
      _ => kToneGrey,
    };

/// Libellé court d'un statut de commande (pastilles).
String orderStatusShort(String status) => switch (status) {
      '' || OrderStatus.pending => 'À confirmer',
      _ => OrderStatus.label(status),
    };

/// Commandes de la période et commandes encore en cours (sans doublon).
List<DashOrder> mergeOrders(List<DashOrder> a, List<DashOrder> b) {
  final byId = <String, DashOrder>{for (final o in a) o.id: o};
  for (final o in b) {
    byId[o.id] = o;
  }
  return byId.values.toList();
}

/// Durée lisible (« 45 min », « 2 h 05 », « 3 j »).
String adminDuration(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '${m < 0 ? 0 : m} min';
  if (m < 60 * 24) {
    final r = m % 60;
    return r == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${r.toString().padLeft(2, '0')}';
  }
  return '${d.inDays} j';
}
