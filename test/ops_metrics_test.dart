import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitunga/noc/ops_alerts.dart';
import 'package:kitunga/noc/ops_panels.dart';

/// Indicateurs du tableau de bord admin, calculés sur les vraies données.
void main() {
  final now = DateTime(2026, 11, 8, 12, 0);

  ({String status, DateTime? createdAt}) order(String status, Duration age) =>
      (status: status, createdAt: now.subtract(age));

  test('retards (+2 h) et commandes sans réponse (+15 min)', () {
    final r = orderAlerts([
      order('En attente', const Duration(minutes: 5)), // récente
      order('En attente', const Duration(minutes: 20)), // sans réponse
      order('', const Duration(minutes: 30)), // ancien statut vide
      order('En préparation', const Duration(hours: 3)), // en retard
      order('encours', const Duration(hours: 1)),
      (status: 'En attente', createdAt: null), // date inconnue : ignorée
    ], now);
    expect(r.late, 1);
    expect(r.noResponse, 2);
  });

  test('livraisons en cours regroupées par zone', () {
    final zones = ordersByZone([
      (zone: 'Poto-Poto', status: 'encours'),
      (zone: 'Poto-Poto ', status: 'Pret'),
      (zone: '', status: 'En attente'),
      (zone: 'Bacongo', status: 'En attente'),
      (zone: 'Poto-Poto', status: 'En préparation'),
    ]);
    expect(zones.first, (zone: 'Poto-Poto', total: 3, delivering: 1));
    expect(zones.map((z) => z.zone), contains('Zone non précisée'));
    expect(zones, hasLength(3));
  });

  test('taux d\'échec de paiement', () {
    expect(paymentFailureRate([]), isNull);
    expect(paymentFailureRate(['En attente']), isNull);
    expect(paymentFailureRate(['Echec', 'Réussi', 'Réussi', 'Réussi']), 25);
  });

  test('niveaux : Normal, Moyen, Élevé selon la valeur', () {
    expect(countLevel(0).label, 'Normal');
    expect(countLevel(2).label, 'Moyen');
    expect(countLevel(3).label, 'Élevé');
    expect(rateLevel(null).label, 'Aucune donnée');
    expect(rateLevel(5).label, 'Normal');
    expect(rateLevel(12).label, 'Moyen');
    expect(rateLevel(40).label, 'Élevé');
  });

  test('temps de livraison moyen sur les commandes mesurées', () {
    Timestamp t(int minutes) =>
        Timestamp.fromDate(now.add(Duration(minutes: minutes)));
    final r = averageDeliveryMinutes([
      {'created_at': t(0), 'delivered_at': t(40)},
      {'created_at': t(0), 'delivered_at': t(60)},
      {'created_at': t(0)}, // pas encore livrée : ignorée
      {'created_at': t(10), 'delivered_at': t(0)}, // incohérente : ignorée
    ]);
    expect(r.minutes, 50);
    expect(r.count, 2);
    expect(averageDeliveryMinutes([]).minutes, isNull);
  });
}
