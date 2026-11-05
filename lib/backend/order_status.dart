import 'package:flutter/material.dart';

/// Statuts de commande. Les six premières valeurs existaient déjà en base
/// et sont conservées telles quelles (compatibilité avec les commandes
/// existantes et le tableau de bord d'administration).
class OrderStatus {
  OrderStatus._();

  static const pending = 'En attente'; // reçue, à confirmer par le vendeur
  static const preparing = 'En préparation'; // acceptée par le vendeur
  static const ready = 'Pret'; // prête, en attente d'un livreur
  static const delivering = 'encours'; // prise en charge par un livreur
  static const delivered = 'Livrer'; // remise au client
  static const received = 'Reçu'; // réception confirmée par le client
  static const notReceived = 'Non Reçu'; // le client signale un problème
  static const refused = 'Refusée'; // refusée par le vendeur
  static const cancelled = 'Annulée'; // annulée par le client

  /// Étapes affichées dans le suivi, dans l'ordre.
  static const steps = [pending, preparing, ready, delivering, delivered];

  /// Commandes visibles par les livreurs (à prendre ou en cours).
  static const forDeliverers = [ready, delivering];

  /// Commandes encore en cours pour le suivi d'administration.
  static const inProgress = ['', pending, preparing, ready, delivering];

  /// Commandes terminées ou arrêtées (historique d'administration).
  static const finished = [delivered, received, notReceived, refused, cancelled];

  /// Commandes remises au client.
  static const successful = [delivered, received];

  /// Remboursement demandé et pas encore envoyé.
  static bool refundToProcess(Map<String, dynamic> order) =>
      order['refund_needed'] == true && order['refund_status'] != 'Envoyé';

  static bool isClosed(String s) =>
      s == received || s == notReceived || s == refused || s == cancelled;

  static bool isStopped(String s) => s == refused || s == cancelled;

  static String label(String s) => switch (s) {
        pending || '' => 'En attente de confirmation',
        preparing => 'En préparation',
        ready => 'Prête',
        delivering => 'En livraison',
        delivered => 'Livrée',
        received => 'Reçue',
        notReceived => 'Non reçue',
        refused => 'Refusée',
        cancelled => 'Annulée',
        _ => s,
      };

  /// Libellé court d'une étape du suivi.
  static String stepLabel(String s) => switch (s) {
        pending => 'Reçue',
        preparing => 'Préparation',
        ready => 'Prête',
        delivering => 'En route',
        delivered => 'Livrée',
        _ => label(s),
      };

  static Color color(String s) => switch (s) {
        pending || '' => const Color(0xFFD99A00),
        preparing => const Color(0xFF2F6FDE),
        ready => const Color(0xFF7A4CD9),
        delivering => const Color(0xFFE8710A),
        delivered || received => const Color(0xFF1E9E5A),
        notReceived || refused || cancelled => const Color(0xFFE30613),
        _ => const Color(0xFF6B6B6B),
      };

  /// Rang dans le suivi (-1 si la commande est arrêtée).
  static int stepIndex(String s) {
    if (isStopped(s)) return -1;
    if (s == received || s == notReceived) return steps.length - 1;
    final i = steps.indexOf(s.isEmpty ? pending : s);
    return i < 0 ? 0 : i;
  }
}
