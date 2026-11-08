import 'package:flutter/material.dart';

import '/noc/sales/sales_admin_widget.dart' show SalesPage;
import '/noc/sales/sales_common.dart';
import '/noc/ui/admin_kit.dart';

/// Gestion › Données de test : aperçu, suppression avec sauvegarde,
/// historique et restauration (fonction kitungaPurgeTestData).
class PurgeTestDataTab extends StatefulWidget {
  const PurgeTestDataTab({super.key});

  @override
  State<PurgeTestDataTab> createState() => _PurgeTestDataTabState();
}

Future<Map<String, dynamic>> _purgeCall(Map<String, dynamic> data) =>
    salesCall('kitungaPurgeTestData', data);

const _kConfirm = 'SUPPRIMER';

class _PurgeTestDataTabState extends State<PurgeTestDataTab> {
  late Future<Map<String, dynamic>> _preview = _purgeCall({'mode': 'preview'});
  late Future<Map<String, dynamic>> _history = _purgeCall({'mode': 'history'});
  final _confirm = TextEditingController();
  bool _running = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _preview = _purgeCall({'mode': 'preview'});
      _history = _purgeCall({'mode': 'history'});
    });
  }

  Future<void> _purge() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    try {
      final r = await _purgeCall({'mode': 'purge', 'confirm': _kConfirm});
      if (!mounted) return;
      setState(() {
        _result = r;
        _running = false;
        _confirm.clear();
      });
      messenger.showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF136B3D),
          content: Text('Données de test supprimées (sauvegarde conservée).')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      messenger.showSnackBar(
          SnackBar(backgroundColor: AdminColors.redDeep, content: Text('$e')));
    }
  }

  Future<void> _restore(String runId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
            'Les commerces, livreurs, produits, commandes et images supprimés '
            'lors de ce nettoyage seront remis en place. Les comptes de '
            'connexion des commerçants et livreurs ne peuvent pas être '
            'recréés : ils devront être créés à nouveau.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await runSalesAction(
        context,
        () => _purgeCall({'mode': 'restore', 'runId': runId}),
        'Sauvegarde restaurée');
    if (done) _reload();
  }

  Widget _tile(String label, int n, IconData icon, {bool kept = false}) {
    return Container(
      width: 200.0,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: kept ? AdminColors.greenSoft : AdminColors.redSoft,
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 22.0, color: kept ? AdminColors.green : AdminColors.red),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$n', style: AdminText.h1()),
                Text(label,
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

  @override
  Widget build(BuildContext context) {
    return SalesPage(
      onRefresh: () async => _reload(),
      children: [
        Text(
            'Avant le lancement réel : supprime les commerces, livreurs, '
            'produits, paniers, commandes et paiements de commandes de test. '
            'Les clients, les administrateurs, le module commercial, les '
            'catégories et les paiements d\'abonnement sont conservés. Une '
            'copie de sécurité est faite avant toute suppression.',
            style: salesBody()),
        const SizedBox(height: 14.0),
        SalesLoader(
          future: _preview,
          onRetry: _reload,
          builder: (data) {
            final c = Map<String, dynamic>.from(data['counts'] as Map);
            int n(String k) => (c[k] as num? ?? 0).toInt();
            final total = n('sellers') +
                n('delivers') +
                n('products') +
                n('orders') +
                n('orderItems') +
                n('carts') +
                n('payments');
            final sellers = (data['sellers'] as List? ?? const []).cast<String>();
            final delivers =
                (data['delivers'] as List? ?? const []).cast<String>();
            return SalesCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Sera supprimé', style: salesTitle(15.0)),
                  const SizedBox(height: 10.0),
                  Wrap(spacing: 10.0, runSpacing: 10.0, children: [
                    _tile('commerçants', n('sellers'), Icons.storefront_rounded),
                    _tile('livreurs', n('delivers'), Icons.two_wheeler_rounded),
                    _tile('produits', n('products'), Icons.shopping_bag_rounded),
                    _tile('commandes', n('orders'), Icons.receipt_long_rounded),
                    _tile('articles de commande', n('orderItems'),
                        Icons.list_alt_rounded),
                    _tile('paniers', n('carts'), Icons.shopping_cart_rounded),
                    _tile('paiements de commandes', n('payments'),
                        Icons.payments_rounded),
                  ]),
                  const SizedBox(height: 14.0),
                  Text('Conservé', style: salesTitle(15.0)),
                  const SizedBox(height: 10.0),
                  Wrap(spacing: 10.0, runSpacing: 10.0, children: [
                    _tile('paiements d\'abonnement', n('keptSubscriptionPayments'),
                        Icons.workspace_premium_rounded,
                        kept: true),
                  ]),
                  const SizedBox(height: 6.0),
                  Text(
                      'Ainsi que tous les clients, administrateurs, commerciaux, '
                      'campagnes, commissions et catégories.',
                      style: salesBody(size: 12.5)),
                  if (sellers.isNotEmpty || delivers.isNotEmpty) ...[
                    const SizedBox(height: 14.0),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Voir les comptes qui seront supprimés',
                          style: salesBody(color: kSalesInk)),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(spacing: 6.0, runSpacing: 6.0, children: [
                            for (final s in sellers)
                              Chip(
                                  avatar: const Icon(Icons.storefront_rounded,
                                      size: 16.0),
                                  label: Text(s)),
                            for (final d in delivers)
                              Chip(
                                  avatar: const Icon(Icons.two_wheeler_rounded,
                                      size: 16.0),
                                  label: Text(d)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16.0),
                  if (total == 0)
                    const SalesEmpty(
                        icon: Icons.task_alt_rounded,
                        title: 'Aucune donnée de test à supprimer')
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: AdminColors.redSoft,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AdminColors.red),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                                'Les comptes de connexion des commerçants et '
                                'livreurs seront supprimés définitivement. Le '
                                'reste est copié et peut être restauré.',
                                style: salesBody(color: kSalesInk)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14.0),
                    Wrap(
                      spacing: 12.0,
                      runSpacing: 12.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 260.0,
                          child: TextField(
                            controller: _confirm,
                            enabled: !_running,
                            onChanged: (_) => setState(() {}),
                            decoration: salesInput(
                                'Tapez $_kConfirm pour confirmer'),
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AdminColors.red),
                          onPressed: _running ||
                                  _confirm.text.trim() != _kConfirm
                              ? null
                              : _purge,
                          icon: _running
                              ? const SizedBox(
                                  width: 16.0,
                                  height: 16.0,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.0, color: Colors.white))
                              : const Icon(Icons.delete_forever_rounded),
                          label: Text(_running
                              ? 'Suppression en cours…'
                              : 'Supprimer les données de test'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (_result != null) ...[
          const SizedBox(height: 14.0),
          SalesCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AdminColors.green),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                      'Nettoyage terminé · ${_result!['files']} fichier(s) et '
                      '${_result!['accounts']} compte(s) supprimés · sauvegarde '
                      '${_result!['runId']}',
                      style: salesBody(color: kSalesInk)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20.0),
        Text('Sauvegardes des nettoyages', style: salesTitle(15.0)),
        const SizedBox(height: 10.0),
        SalesLoader(
          future: _history,
          onRetry: _reload,
          builder: (data) {
            final runs = listOf(data['runs']);
            if (runs.isEmpty) {
              return Text('Aucun nettoyage effectué pour l\'instant.',
                  style: salesBody());
            }
            return Column(
              children: [
                for (final r in runs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SalesCard(
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sauvegarde ${r['runId']}',
                                    style: salesTitle(14.0)),
                                Text(
                                    '${r['status']}'
                                    '${r['restored'] == true ? ' · restaurée' : ''}'
                                    ' · ${(r['counts'] as Map?)?['products'] ?? 0} produits'
                                    ' · ${(r['counts'] as Map?)?['orders'] ?? 0} commandes'
                                    ' · ${(r['counts'] as Map?)?['sellers'] ?? 0} commerces',
                                    style: salesBody(size: 12.5)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _restore(r['runId'] as String),
                            icon: const Icon(Icons.restore_rounded, size: 18.0),
                            label: const Text('Restaurer'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
