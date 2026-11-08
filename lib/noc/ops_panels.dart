import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/components/stat_comp_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';

/// Temps de livraison réel : moyenne, sur 30 jours, entre la commande
/// (created_at) et la livraison (delivered_at, enregistrée par l'application
/// du livreur quand il termine). Remplace l'ancienne valeur fixe de 90.
class KitungaDeliveryTimeStat extends StatefulWidget {
  const KitungaDeliveryTimeStat({super.key});

  @override
  State<KitungaDeliveryTimeStat> createState() =>
      _KitungaDeliveryTimeStatState();
}

/// Moyenne en minutes (null si aucune livraison mesurée).
({int? minutes, int count}) averageDeliveryMinutes(
    Iterable<Map<String, dynamic>> orders) {
  var total = 0;
  var count = 0;
  for (final o in orders) {
    final created = (o['created_at'] as Timestamp?)?.toDate();
    final delivered = (o['delivered_at'] as Timestamp?)?.toDate();
    if (created == null || delivered == null || delivered.isBefore(created)) {
      continue;
    }
    total += delivered.difference(created).inMinutes;
    count++;
  }
  return (minutes: count == 0 ? null : (total / count).round(), count: count);
}

class _KitungaDeliveryTimeStatState extends State<KitungaDeliveryTimeStat> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _delivered =
      FirebaseFirestore.instance
          .collection('Orders')
          .where('delivered_at',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 30))))
          .snapshots();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _delivered,
      builder: (context, snap) {
        final avg = averageDeliveryMinutes(
            (snap.data?.docs ?? const []).map((d) => d.data()));
        return StatCompWidget(
          bgIcon: Icon(Icons.timer_rounded, color: theme.primaryText),
          bg: theme.accent3,
          title: 'TEMPS DE LIVRAISON',
          subtitle: avg.minutes == null
              ? 'Mesuré dès les prochaines livraisons'
              : 'Minutes en moyenne (30 j, ${avg.count} livraisons)',
          quantity: avg.minutes ?? 0,
        );
      },
    );
  }
}

/// Livraisons en cours par zone : remplace l'ancienne image de carte, qui
/// n'affichait aucune donnée réelle (les commandes n'ont pas de coordonnées
/// GPS, seulement un quartier).
class KitungaZonesPanel extends StatefulWidget {
  const KitungaZonesPanel({super.key});

  @override
  State<KitungaZonesPanel> createState() => _KitungaZonesPanelState();
}

/// Regroupement par zone : (zone, total, déjà pris par un livreur).
List<({String zone, int total, int delivering})> ordersByZone(
    Iterable<({String zone, String status})> orders) {
  final byZone = <String, ({int total, int delivering})>{};
  for (final o in orders) {
    final zone = o.zone.trim().isEmpty ? 'Zone non précisée' : o.zone.trim();
    final current = byZone[zone] ?? (total: 0, delivering: 0);
    byZone[zone] = (
      total: current.total + 1,
      delivering:
          current.delivering + (o.status == OrderStatus.delivering ? 1 : 0),
    );
  }
  final list = [
    for (final e in byZone.entries)
      (zone: e.key, total: e.value.total, delivering: e.value.delivering),
  ];
  list.sort((a, b) => b.total.compareTo(a.total));
  return list;
}

class _KitungaZonesPanelState extends State<KitungaZonesPanel> {
  late final Stream<List<OrdersRecord>> _orders = queryOrdersRecord(
    queryBuilder: (q) => q.where('status', whereIn: OrderStatus.inProgress),
  );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      color: theme.secondaryBackground,
      child: StreamBuilder<List<OrdersRecord>>(
        stream: _orders,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          final zones = ordersByZone(snap.data!
              .map((o) => (zone: o.deliveryZone, status: o.status)));
          if (zones.isEmpty) {
            return Center(
              child: Text('Aucune commande en cours',
                  style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
            );
          }
          final max = zones.first.total;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: zones.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10.0),
            itemBuilder: (context, i) {
              final z = zones[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 18.0, color: theme.primary),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(z.zone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyMedium),
                      ),
                      Text(
                        '${z.total} commande${z.total > 1 ? 's' : ''}'
                        '${z.delivering > 0 ? ' · ${z.delivering} en livraison' : ''}',
                        style: theme.bodySmall.copyWith(color: theme.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: LinearProgressIndicator(
                      value: z.total / max,
                      minHeight: 6.0,
                      color: theme.primary,
                      backgroundColor: theme.alternate,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
