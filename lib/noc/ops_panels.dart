import '/backend/backend.dart';
import '/backend/order_status.dart';

/// Calculs de suivi des livraisons (testés), utilisés par l'administration.

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
