import 'package:flutter/material.dart';

import '/backend/order_status.dart';

/// Indicateurs d'alerte de l'administration, calculés à partir des vraies
/// données (utilisés par le tableau de bord et la page Alertes) :
/// - retards : commandes encore en cours plus de 2 h après leur création ;
/// - sans réponse : commandes toujours « En attente » après 15 min ;
/// - échecs de paiement : part des paiements refusés sur 7 jours.
/// Le niveau (Normal, Moyen, Élevé) et la couleur suivent la valeur.

/// Seuils (testés).
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
