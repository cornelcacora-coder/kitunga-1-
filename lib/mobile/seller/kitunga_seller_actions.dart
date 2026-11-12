import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/backend/server_payment.dart';

/// Actions du vendeur sur une commande, vérifiées par le serveur
/// (kitungaSellerOrderAction) : accepter avec un temps de préparation,
/// refuser avec un motif, marquer prête, confirmer la remise au livreur.

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    sellerBackendOverride;

Future<Map<String, dynamic>> sellerCall(
        String name, Map<String, dynamic> data) =>
    sellerBackendOverride != null
        ? sellerBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

Future<bool> _run(BuildContext context, OrdersRecord order, String action,
    String done, [Map<String, dynamic> extra = const {}]) async {
  try {
    await sellerCall('kitungaSellerOrderAction',
        {'orderId': order.reference.id, 'action': action, ...extra});
    if (context.mounted) _snack(context, done);
    return true;
  } on ServerPaymentException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, 'Connexion impossible. Réessayez.');
  }
  return false;
}

/// Accepter : le vendeur choisit son temps de préparation.
Future<bool> sellerAccept(BuildContext context, OrdersRecord order,
    {int? defaultMinutes}) async {
  final minutes = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accepter la commande',
                style: GoogleFonts.interTight(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Temps de préparation : le client en est informé.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [10, 15, 20, 30, 45, 60])
                  ChoiceChip(
                    key: ValueKey('prep-$m'),
                    label: Text('$m min'),
                    selected: m == defaultMinutes,
                    onSelected: (_) => Navigator.pop(c, m),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (minutes == null || !context.mounted) return false;
  return _run(context, order, 'accept', 'Commande acceptée : le client est '
      'prévenu.', {'prepMinutes': minutes});
}

/// Refuser : motif obligatoire (le client le voit ; remboursement si payée).
Future<bool> sellerRefuse(BuildContext context, OrdersRecord order) async {
  final controller = TextEditingController();
  const reasons = [
    'Produit en rupture',
    'Commerce bientôt fermé',
    'Trop de commandes en cours',
  ];
  final reason = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Refuser la commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Le client verra ce motif et sera remboursé s\'il a '
                'payé.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in reasons)
                  ActionChip(
                    label: Text(r),
                    onPressed: () => set(() => controller.text = r),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('refuse-reason'),
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Motif', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('refuse-confirm'),
            style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFFE51A1A)),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(c, controller.text.trim());
            },
            child: const Text('Refuser'),
          ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return false;
  return _run(context, order, 'refuse', 'Commande refusée.',
      {'reason': reason});
}

Future<bool> sellerReady(BuildContext context, OrdersRecord order) =>
    _run(context, order, 'ready',
        'Commande prête : un livreur est recherché.');

Future<bool> sellerHandover(BuildContext context, OrdersRecord order) =>
    _run(context, order, 'handover',
        'Remise confirmée : le client est prévenu.');

/// Minutes de préparation restantes (null si inconnues).
int? prepMinutesLeft(OrdersRecord o, [DateTime? now]) {
  final prep = (o.snapshotData['prep_minutes'] as num?)?.toInt();
  final v = o.snapshotData['accepted_at'];
  DateTime? at;
  if (v is DateTime) {
    at = v;
  } else {
    try {
      at = (v as dynamic)?.toDate() as DateTime?;
    } catch (_) {}
  }
  if (prep == null || at == null) return null;
  return prep - (now ?? DateTime.now()).difference(at).inMinutes;
}
