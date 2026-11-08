import 'dart:async';

import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/components/alert_card_widget.dart';

/// Indicateurs d'alerte du tableau de bord, calculés à partir des vraies
/// données (et non plus de valeurs fixes) :
/// - retards : commandes encore en cours plus de 2 h après leur création ;
/// - sans réponse : commandes toujours « En attente » après 15 min ;
/// - échecs de paiement : part des paiements refusés sur 7 jours.
/// Le niveau (Normal, Moyen, Élevé) et la couleur suivent la valeur.
class KitungaOpsAlerts extends StatefulWidget {
  const KitungaOpsAlerts({super.key, this.spacing = 10.0});

  final double spacing;

  @override
  State<KitungaOpsAlerts> createState() => _KitungaOpsAlertsState();
}

/// Seuils, en dehors du widget pour pouvoir les tester.
class OpsThresholds {
  static const lateAfter = Duration(hours: 2);
  static const noResponseAfter = Duration(minutes: 15);
  static const paymentWindow = Duration(days: 7);
}

typedef OpsLevel = ({String label, Color color, Color bg});

const _normal = (label: 'Normal', color: Color(0xFF1E9E5A), bg: Color(0x331E9E5A));
const _medium = (label: 'Moyen', color: Color(0xFFE0A50F), bg: Color(0x52E0A50F));
const _high = (label: 'Élevé', color: Color(0xFFE00F17), bg: Color(0x44E00F17));
const _unknown = (label: 'Aucune donnée', color: Color(0xFF8A8F98), bg: Color(0x228A8F98));

/// Niveau d'un compteur : 0 = Normal, jusqu'à [medium] = Moyen, au-delà Élevé.
OpsLevel countLevel(int n, {int medium = 2}) =>
    n == 0 ? _normal : (n <= medium ? _medium : _high);

/// Niveau d'un taux d'échec en % (null = pas de paiement sur la période).
OpsLevel rateLevel(double? rate) => rate == null
    ? _unknown
    : rate < 10
        ? _normal
        : rate < 25
            ? _medium
            : _high;

/// Calculs purs (testés) à partir des commandes en cours et des paiements.
({int late, int noResponse}) orderAlerts(
    Iterable<({String status, DateTime? createdAt})> inProgress, DateTime now) {
  var late = 0;
  var noResponse = 0;
  for (final o in inProgress) {
    final created = o.createdAt;
    if (created == null) continue;
    final age = now.difference(created);
    if (age > OpsThresholds.lateAfter) late++;
    if (OrderStatus.inProgress.take(2).contains(o.status) &&
        age > OpsThresholds.noResponseAfter) {
      noResponse++;
    }
  }
  return (late: late, noResponse: noResponse);
}

double? paymentFailureRate(Iterable<String?> statuses) {
  var failed = 0;
  var ok = 0;
  for (final s in statuses) {
    if (s == 'Echec') failed++;
    if (s == 'Réussi') ok++;
  }
  final total = failed + ok;
  return total == 0 ? null : failed * 100 / total;
}

class _KitungaOpsAlertsState extends State<KitungaOpsAlerts> {
  late final Stream<List<OrdersRecord>> _orders = queryOrdersRecord(
    queryBuilder: (q) => q.where('status', whereIn: OrderStatus.inProgress),
  );
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _payments =
      FirebaseFirestore.instance
          .collection('Paiement')
          .where('created_at',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime.now().subtract(OpsThresholds.paymentWindow)))
          .snapshots();
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Les durées avancent même sans nouvelle donnée : recalcul chaque minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Widget _card(String label, String value, String unit, IconData icon,
      OpsLevel level) {
    return AlertCardWidget(
      color: level.color,
      icon: Icon(icon, color: level.color, size: 24.0),
      label: label,
      status: level.label,
      value: value,
      unit: unit,
      bg: level.bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<List<OrdersRecord>>(
          stream: _orders,
          builder: (context, snap) {
            final a = orderAlerts(
                (snap.data ?? const <OrdersRecord>[])
                    .map((o) => (status: o.status, createdAt: o.createdAt)),
                DateTime.now());
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _card('RETARDS (+2 H)', snap.hasData ? '${a.late}' : '…',
                    'commandes', Icons.timer_rounded, countLevel(a.late)),
                SizedBox(height: widget.spacing),
                _card('SANS RÉPONSE VENDEUR (+15 MIN)',
                    snap.hasData ? '${a.noResponse}' : '…', 'commandes',
                    Icons.speed_rounded, countLevel(a.noResponse)),
              ],
            );
          },
        ),
        SizedBox(height: widget.spacing),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _payments,
          builder: (context, snap) {
            final rate = paymentFailureRate(
                (snap.data?.docs ?? const []).map((d) => d.data()['status'] as String?));
            return _card(
                'ÉCHECS DE PAIEMENT (7 J)',
                !snap.hasData
                    ? '…'
                    : rate == null
                        ? '—'
                        : rate.toStringAsFixed(rate < 10 ? 1 : 0),
                rate == null ? 'aucun paiement' : '%',
                Icons.credit_card_off_rounded,
                rateLevel(snap.hasData ? rate : null));
          },
        ),
      ],
    );
  }
}
