import 'package:flutter/material.dart';

import 'sales_admin_widget.dart';
import 'sales_common.dart';
import '/noc/ui/admin_export.dart';

/// Noms des commerciaux et campagnes, pour afficher autre chose que des
/// identifiants.
Future<Map<String, dynamic>> _withNames(Future<Map<String, dynamic>> main) async {
  final r = await Future.wait([main, salesQuery('agents'), salesQuery('campaigns')]);
  return {
    ...r[0],
    'agentNames': {
      for (final a in listOf(r[1]['agents']))
        a['uid']: '${a['agentCode']} · ${a['displayName']}',
    },
    'agents': r[1]['agents'],
    'campaignNames': {
      for (final c in listOf(r[2]['campaigns'])) c['id']: c['name'],
    },
  };
}

// ── Commissions ──────────────────────────────────────────────────────────

class SalesCommissionsTab extends StatefulWidget {
  const SalesCommissionsTab({super.key});

  @override
  State<SalesCommissionsTab> createState() => _SalesCommissionsTabState();
}

class _SalesCommissionsTabState extends State<SalesCommissionsTab> {
  String? _status = 'pending';
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() => _withNames(
      salesQuery('commissions', {if (_status != null) 'status': _status}));

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _approve(Map<String, dynamic> c) async {
    final flags = List<String>.from(c['flags'] as List? ?? []);
    String note = '';
    if (flags.isNotEmpty) {
      final r = await askText(context, 'Commission signalée',
          label: 'Note de vérification (obligatoire)',
          hint: flags.map((f) => commissionFlag[f] ?? f).join(' · '));
      if (r == null) return;
      note = r;
    }
    if (!mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaReviewCommission', {
              'commissionId': c['id'],
              'decision': 'approve',
              if (flags.isNotEmpty) 'acknowledgeFlags': true,
              if (note.isNotEmpty) 'reason': note,
            }),
        'Commission validée.');
    if (ok) _reload();
  }

  Future<void> _decide(Map<String, dynamic> c, String decision) async {
    final reason = await askText(
        context,
        decision == 'reject' ? 'Rejeter la commission' : 'Annuler la commission',
        hint: c['status'] == 'paid'
            ? 'Déjà payée : une contrepassation sera déduite du prochain versement.'
            : null);
    if (reason == null || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaReviewCommission',
            {'commissionId': c['id'], 'decision': decision, 'reason': reason}),
        'Commission mise à jour.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('pending', 'En attente'),
      ('approved', 'Validées'),
      ('reserved', 'En versement'),
      ('paid', 'Payées'),
      ('rejected', 'Rejetées'),
      ('reversed', 'Annulées'),
      (null, 'Toutes'),
    ];
    return SalesPage(
      onRefresh: () async => _reload(),
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final f in filters)
              ChoiceChip(
                label: Text(f.$2),
                selected: _status == f.$1,
                selectedColor: kSalesRed.withValues(alpha: 0.15),
                onSelected: (_) {
                  _status = f.$1;
                  _reload();
                },
              ),
          ],
        ),
        const SizedBox(height: 16.0),
        SalesLoader(
          future: _future,
          onRetry: _reload,
          builder: (data) {
            final items = listOf(data['commissions']);
            final agents = Map<String, dynamic>.from(data['agentNames'] as Map);
            final campaigns =
                Map<String, dynamic>.from(data['campaignNames'] as Map);
            if (items.isEmpty) {
              return const SalesEmpty(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune commission ici');
            }
            final total =
                items.fold<num>(0, (s, c) => s + ((c['amount'] as num?) ?? 0));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${items.length} commission(s) · total ${fcfa(total)}',
                          style: salesBody()),
                    ),
                    AdminExportButton(
                      data: () => AdminExportData(
                        title: 'Commissions',
                        subtitle: '${items.length} commission(s) · total ${fcfa(total)}',
                        fileName: 'commissions',
                        headers: ['Date', 'Commercial', 'Campagne', 'Type',
                          'Formule', 'Montant', 'Statut', 'Éligible le', 'Motif'],
                        flex: [2, 3, 3, 2, 2, 2, 2, 2, 3],
                        moneyColumns: {5},
                        rows: [
                          for (final c in items)
                            [
                              dateFr(c['createdAt'] as String?),
                              agents[c['agentUid']] ?? c['agentUid'] ?? '',
                              campaigns[c['campaignId']] ?? '',
                              commissionType[c['type']] ?? '${c['type'] ?? ''}',
                              planLabel[c['plan']] ?? '',
                              c['amount'] as num?,
                              commissionStatus[c['status']]?.label ?? '${c['status'] ?? ''}',
                              dateFr(c['eligibleAt'] as String?),
                              c['statusReason'] ?? '',
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                for (final c in items) ...[
                  _commissionCard(c, agents, campaigns),
                  const SizedBox(height: 10.0),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _commissionCard(Map<String, dynamic> c, Map<String, dynamic> agents,
      Map<String, dynamic> campaigns) {
    final status = c['status'] as String?;
    final flags = List<String>.from(c['flags'] as List? ?? []);
    final eligible = DateTime.tryParse('${c['eligibleAt']}');
    final waiting =
        status == 'pending' && eligible != null && eligible.isAfter(DateTime.now());
    return SalesCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(fcfa(c['amount'] as num?), style: salesTitle(17.0)),
                    Text(commissionType[c['type']] ?? '${c['type']}',
                        style: salesBody(color: kSalesInk)),
                    StatusChip(commissionStatus[status]),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text('${agents[c['agentUid']] ?? c['agentUid']} · '
                    '${campaigns[c['campaignId']] ?? 'Campagne'}',
                    style: salesBody()),
                Text(
                    'Générée le ${dateFr(c['createdAt'] as String?)}'
                    '${c['plan'] != null ? ' · formule ${planLabel[c['plan']] ?? c['plan']}' : ''}',
                    style: salesBody()),
                if (waiting)
                  Text('Validable à partir du ${dateFr(c['eligibleAt'] as String?)}',
                      style: salesBody(color: const Color(0xFFE08A00))),
                if (c['statusReason'] != null)
                  Text('Motif : ${c['statusReason']}', style: salesBody()),
                if (c['reversedBy'] != null)
                  Text('Contrepassée (déduite du prochain versement)',
                      style: salesBody()),
                for (final f in flags)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16.0, color: Color(0xFFE08A00)),
                      const SizedBox(width: 4.0),
                      Flexible(
                          child: Text(commissionFlag[f] ?? f,
                              style: salesBody(color: const Color(0xFF9A5B00)))),
                    ]),
                  ),
              ],
            ),
          ),
          if (status == 'pending' || status == 'approved' ||
              (status == 'paid' && c['type'] != 'reversal' && c['reversedBy'] == null))
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (status == 'pending')
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kSalesRed),
                    onPressed: waiting ? null : () => _approve(c),
                    child: const Text('Valider'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (d) => _decide(c, d),
                  itemBuilder: (_) => [
                    if (status != 'paid')
                      const PopupMenuItem(value: 'reject', child: Text('Rejeter')),
                    const PopupMenuItem(value: 'reverse', child: Text('Annuler')),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Versements ───────────────────────────────────────────────────────────

class SalesPayoutsTab extends StatefulWidget {
  const SalesPayoutsTab({super.key});

  @override
  State<SalesPayoutsTab> createState() => _SalesPayoutsTabState();
}

class _SalesPayoutsTabState extends State<SalesPayoutsTab> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() => _withNames(salesQuery('payouts'));

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _prepare(List<Map<String, dynamic>> agents) async {
    final candidates = agents.where((a) => a['status'] != 'archived').toList();
    if (candidates.isEmpty) return;
    String agentUid = candidates.first['uid'] as String;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Préparer un versement'),
          content: SizedBox(
            width: 420.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    'Regroupe toutes les commissions validées du commercial '
                    '(contrepassations déduites). Elles sont mises de côté '
                    'jusqu\'au paiement ou au refus.',
                    style: salesBody()),
                const SizedBox(height: 12.0),
                DropdownButtonFormField<String>(
                  initialValue: agentUid,
                  isExpanded: true,
                  decoration: salesInput('Commercial'),
                  items: [
                    for (final a in candidates)
                      DropdownMenuItem(
                          value: a['uid'] as String,
                          child: Text('${a['agentCode']} · ${a['displayName']}')),
                  ],
                  onChanged: (v) => setLocal(() => agentUid = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kSalesRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Préparer'),
            ),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaRequestPayout', {'agentUid': agentUid}),
        'Versement préparé.');
    if (ok) _reload();
  }

  Future<void> _decide(Map<String, dynamic> p, String decision) async {
    final data = <String, dynamic>{'payoutId': p['id'], 'decision': decision};
    if (decision == 'reject') {
      final r = await askText(context, 'Refuser le versement',
          hint: 'Les commissions redeviennent disponibles.');
      if (r == null) return;
      data['reason'] = r;
    }
    if (decision == 'paid') {
      if (!mounted) return;
      final r = await askText(context, 'Versement effectué',
          label: 'Référence du virement',
          hint: 'Numéro de transaction Mobile Money ou référence bancaire, '
              'après avoir fait le virement vous-même.');
      if (r == null) return;
      data['externalReference'] = r;
    }
    if (!mounted) return;
    final ok = await runSalesAction(
        context, () => salesCall('kitungaDecidePayout', data),
        'Versement mis à jour.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SalesPage(
      onRefresh: () async => _reload(),
      children: [
        SalesLoader(
          future: _future,
          onRetry: _reload,
          builder: (data) {
            final payouts = listOf(data['payouts']);
            final agents = Map<String, dynamic>.from(data['agentNames'] as Map);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    'Aucun virement automatique : vous payez le commercial, '
                    'puis vous saisissez la référence.',
                    style: salesBody()),
                const SizedBox(height: 10.0),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: [
                  AdminExportButton(
                    data: () => AdminExportData(
                      title: 'Versements aux commerciaux',
                      subtitle: '${payouts.length} versement(s)',
                      fileName: 'versements',
                      headers: ['Demandé le', 'Commercial', 'Montant',
                        'Commissions', 'Moyen de paiement', 'Statut',
                        'Payé le', 'Référence du virement', 'Motif'],
                      flex: [2, 3, 2, 1, 3, 2, 2, 3, 3],
                      moneyColumns: {2},
                      rows: [
                        for (final p in payouts)
                          [
                            dateFr(p['requestedAt'] as String?),
                            agents[p['agentUid']] ?? p['agentUid'] ?? '',
                            p['amount'] as num?,
                            p['itemsCount'] as num?,
                            payoutMethodLabel(p['method'] as Map?),
                            payoutStatus[p['status']]?.label ?? '${p['status'] ?? ''}',
                            p['paidAt'] == null ? '' : dateFr(p['paidAt'] as String?),
                            p['externalReference'] ?? '',
                            p['statusReason'] ?? '',
                          ],
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kSalesRed),
                    onPressed: () => _prepare(listOf(data['agents'])),
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Préparer un versement'),
                  ),
                  ],
                ),
                const SizedBox(height: 16.0),
                if (payouts.isEmpty)
                  const SalesEmpty(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Aucun versement'),
                for (final p in payouts) ...[
                  SalesCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(fcfa(p['amount'] as num?),
                                      style: salesTitle(17.0)),
                                  StatusChip(payoutStatus[p['status']]),
                                ],
                              ),
                              const SizedBox(height: 4.0),
                              Text('${agents[p['agentUid']] ?? p['agentUid']}',
                                  style: salesBody(color: kSalesInk)),
                              Text(payoutMethodLabel(p['method'] as Map?),
                                  style: salesBody()),
                              Text(
                                  '${p['itemsCount']} commission(s) · demandé le '
                                  '${dateFr(p['requestedAt'] as String?)}',
                                  style: salesBody()),
                              if (p['externalReference'] != null)
                                Text(
                                    'Payé le ${dateFr(p['paidAt'] as String?)} · '
                                    'réf. ${p['externalReference']}',
                                    style: salesBody(color: kSalesInk)),
                              if (p['statusReason'] != null)
                                Text('Motif : ${p['statusReason']}',
                                    style: salesBody()),
                            ],
                          ),
                        ),
                        if (p['status'] == 'requested')
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: kSalesRed),
                            onPressed: () => _decide(p, 'approve'),
                            child: const Text('Valider'),
                          ),
                        if (p['status'] == 'approved')
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF136B3D)),
                            onPressed: () => _decide(p, 'paid'),
                            child: const Text('Marquer payé'),
                          ),
                        if (['requested', 'approved'].contains(p['status']))
                          IconButton(
                            tooltip: 'Refuser',
                            onPressed: () => _decide(p, 'reject'),
                            icon: Icon(Icons.block_rounded, color: kSalesMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10.0),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
