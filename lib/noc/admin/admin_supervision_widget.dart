import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart';
import '/noc/ui/admin_kit.dart';
import 'admin_layout.dart';

/// Supervision en direct (adresse /supervision) : les cinq acteurs, les
/// commandes par étape, les livraisons, les incidents, le support, les
/// finances, et chaque livreur (disponibilité, véhicule, position, courses).
/// Annonces aux vendeurs, livreurs ou clients.
class AdminSupervisionWidget extends StatefulWidget {
  const AdminSupervisionWidget({super.key});

  static String routeName = 'AdminSupervision';
  static String routePath = AdminPaths.supervision;

  @override
  State<AdminSupervisionWidget> createState() => _AdminSupervisionState();
}

const _stateLabels = {
  'on': ('En service', AdminColors.green),
  'pause': ('En pause', AdminColors.orange),
  'off': ('Hors service', AdminColors.grey),
};

const _vehicles = {'moto': 'Moto', 'velo': 'Vélo', 'voiture': 'Voiture'};

class _AdminSupervisionState extends State<AdminSupervisionWidget> {
  late Future<Map<String, dynamic>> _data =
      salesCall('kitungaAdminSupervision', const {});

  void _reload() {
    setState(() {
      _data = salesCall('kitungaAdminSupervision', const {});
    });
  }

  Future<void> _announce() async {
    var audience = 'deliverers';
    final title = TextEditingController();
    final body = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Envoyer une annonce'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: salesInput('Destinataires'),
                  items: const [
                    DropdownMenuItem(
                        value: 'deliverers', child: Text('Tous les livreurs')),
                    DropdownMenuItem(
                        value: 'sellers', child: Text('Tous les commerces')),
                    DropdownMenuItem(
                        value: 'partners',
                        child: Text('Commerces et livreurs')),
                    DropdownMenuItem(
                        value: 'clients', child: Text('Tous les clients')),
                    DropdownMenuItem(value: 'all', child: Text('Tout le monde')),
                  ],
                  onChanged: (v) => set(() => audience = v ?? audience),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: title,
                    maxLength: 80,
                    decoration: salesInput('Titre')),
                TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: salesInput('Message')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Envoyer')),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    await runSalesAction(
        context,
        () => salesCall('kitungaAdminAnnounce', {
              'audience': audience,
              'title': title.text.trim(),
              'body': body.text.trim(),
            }),
        'Annonce envoyée (notification et messagerie).');
  }

  Future<void> _history(Map<String, dynamic> d) => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Disponibilité · ${d['name']}'),
          content: SizedBox(
            width: 460,
            child: FutureBuilder<Map<String, dynamic>>(
              future: salesCall(
                  'kitungaAdminDelivererHistory', {'uid': d['uid']}),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()));
                }
                final m =
                    Map<String, dynamic>.from(snap.data!['missions'] as Map);
                final h = listOf(snap.data!['history']);
                return ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                        'Propositions : ${m['accepted'] ?? 0} acceptées, '
                        '${m['declined'] ?? 0} refusées, '
                        '${m['expired'] ?? 0} sans réponse'
                        '${m['acceptanceRate'] == null ? '' : ' · taux d\'acceptation ${m['acceptanceRate']} %'}',
                        style: salesBody()),
                    const SizedBox(height: 10),
                    if (h.isEmpty)
                      Text('Aucun changement enregistré.', style: salesBody()),
                    for (final e in h)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.circle,
                            size: 10,
                            color: _stateLabels[e['state']]?.$2 ??
                                AdminColors.grey),
                        title: Text(
                            _stateLabels[e['state']]?.$1 ?? '${e['state']}',
                            style: salesBody()),
                        trailing: Text(
                            dateFr(e['at'] as String?, withTime: true),
                            style: salesBody(size: 12)),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Fermer')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        final d = snap.data;
        Map<String, dynamic> part(String k) =>
            Map<String, dynamic>.from((d?[k] as Map?) ?? {});
        final actors = part('actors');
        final o = part('orders');
        final t = part('tickets');
        final f = part('finance');
        final st = part('delivererStates');
        final deliverers = listOf(d?['deliverers']);
        final incidents = listOf(d?['incidents']);
        Widget tile(String label, Object value, Color color,
                {String? help}) =>
            SizedBox(
              width: 170,
              child: SalesCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$value',
                        style: salesTitle(24).copyWith(color: color)),
                    Text(label, style: salesBody(size: 12.5)),
                    if (help != null)
                      Text(help, style: salesBody(size: 11)),
                  ],
                ),
              ),
            );
        Widget section(String title, List<Widget> tiles) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: salesTitle()),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: tiles),
                ],
              ),
            );
        return AdminShell(
          current: 'supervision',
          title: 'Supervision en direct',
          subtitle: 'Acteurs, commandes, livraisons, incidents, support',
          actions: [
            FilledButton.icon(
                onPressed: _announce,
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Annonce')),
            OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18.0),
                label: const Text('Actualiser')),
          ],
          body: snap.hasError
              ? Center(
                  child: Text('Lecture impossible. Réessayez.',
                      style: salesBody()))
              : d == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        section('Acteurs', [
                          tile('Clients', actors['User'] ?? 0, AdminColors.blue),
                          tile('Commerces', actors['Seller'] ?? 0,
                              AdminColors.violet),
                          tile('Livreurs', actors['Deliver'] ?? 0,
                              AdminColors.teal),
                          tile('Agents support', actors['Support'] ?? 0,
                              AdminColors.grey),
                        ]),
                        section('Commandes et livraisons', [
                          tile('À confirmer', o['pending'] ?? 0,
                              AdminColors.orange),
                          tile('En préparation', o['preparing'] ?? 0,
                              AdminColors.blue),
                          tile('Prêtes', o['ready'] ?? 0, AdminColors.violet,
                              help: '${o['unassignedReady'] ?? 0} sans livreur'),
                          tile('En livraison', o['delivering'] ?? 0,
                              AdminColors.red),
                          tile('Livrées aujourd\'hui', o['deliveredToday'] ?? 0,
                              AdminColors.green),
                          tile('Échouées', o['failed'] ?? 0, AdminColors.red),
                          tile('Litiges (non reçues)', o['disputed'] ?? 0,
                              AdminColors.orange),
                          tile('Annulées aujourd\'hui', o['cancelledToday'] ?? 0,
                              AdminColors.grey),
                        ]),
                        section('Livreurs, incidents, support, finances', [
                          tile('Livreurs en service', st['on'] ?? 0,
                              AdminColors.green),
                          tile('En pause', st['pause'] ?? 0,
                              AdminColors.orange),
                          tile('Hors service', st['off'] ?? 0,
                              AdminColors.grey),
                          tile('Incidents en cours', o['incidents'] ?? 0,
                              AdminColors.red),
                          tile('Tickets ouverts', t['open'] ?? 0,
                              AdminColors.blue,
                              help: '${t['urgent'] ?? 0} urgents · '
                                  '${t['escalated'] ?? 0} escaladés'),
                          tile('Reste à verser', fcfa(f['owed'] as num? ?? 0),
                              AdminColors.violet),
                          tile('Part Kitunga', fcfa(f['kitunga'] as num? ?? 0),
                              AdminColors.green),
                        ]),
                        if (incidents.isNotEmpty) ...[
                          Text('Incidents de livraison en cours',
                              style: salesTitle()),
                          const SizedBox(height: 8),
                          for (final i in incidents)
                            SalesCard(
                              child: Row(
                                children: [
                                  const Icon(Icons.report_rounded,
                                      color: AdminColors.red),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                        '${i['reference']} · ${i['zone']} · '
                                        '${i['label']}'
                                        '${'${i['note']}'.isEmpty ? '' : ' — ${i['note']}'}',
                                        style: salesBody()),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                        Text('Livreurs', style: salesTitle()),
                        const SizedBox(height: 8),
                        for (final dl in deliverers)
                          SalesCard(
                            child: Row(
                              children: [
                                Icon(Icons.circle,
                                    size: 12,
                                    color: _stateLabels[dl['state']]?.$2 ??
                                        AdminColors.grey),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${dl['name']}'
                                          '${dl['suspended'] == true ? ' · SUSPENDU' : ''}',
                                          style: salesTitle(14)),
                                      Text(
                                          [
                                            _stateLabels[dl['state']]?.$1 ?? '',
                                            _vehicles[dl['vehicle']] ?? '',
                                            '${dl['active']} en cours',
                                            '${dl['deliveredToday']} livrée(s) '
                                                'aujourd\'hui',
                                            dl['positionAt'] == null
                                                ? 'position inconnue'
                                                : dl['positionFresh'] == true
                                                    ? 'position récente'
                                                    : 'dernière position '
                                                        '${dateFr(dl['positionAt'] as String?, withTime: true)}',
                                            (dl['zones'] as List? ?? const [])
                                                    .isEmpty
                                                ? 'toute la ville'
                                                : (dl['zones'] as List)
                                                    .join(', '),
                                          ].join(' · '),
                                          style: salesBody(size: 12.5)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                    onPressed: () => _history(dl),
                                    child: const Text('Historique')),
                              ],
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}
