import '/noc/messages/staff_inbox.dart' show StaffWriteButton;
import 'dart:math';

import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart';
import 'admin_layout.dart';

/// Finances (adresse /finances) : encaissements, commission, versements,
/// soldes dus aux commerces et livreurs, règles (commission, part du
/// livreur). Les montants viennent du grand livre tenu par le serveur.
class AdminFinanceWidget extends StatefulWidget {
  const AdminFinanceWidget({super.key});

  static String routeName = 'AdminFinance';
  static String routePath = AdminPaths.finance;

  @override
  State<AdminFinanceWidget> createState() => _AdminFinanceWidgetState();
}

class _AdminFinanceWidgetState extends State<AdminFinanceWidget> {
  late Future<Map<String, dynamic>> _data = _load();
  final _commission = TextEditingController();
  final _share = TextEditingController();
  String _role = 'all';

  Future<Map<String, dynamic>> _load() async {
    final r = await salesCall('kitungaAdminFinanceOverview', const {});
    final s = Map<String, dynamic>.from(r['settings'] as Map);
    _commission.text =
        '${((s['commission_rate'] as num) * 100).toStringAsFixed(1).replaceAll('.0', '')}';
    _share.text =
        '${((s['deliverer_share'] as num) * 100).toStringAsFixed(1).replaceAll('.0', '')}';
    return r;
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  @override
  void dispose() {
    _commission.dispose();
    _share.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    final c = double.tryParse(_commission.text.replaceAll(',', '.'));
    final d = double.tryParse(_share.text.replaceAll(',', '.'));
    if (c == null || d == null) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaAdminFinanceSettings', {
              'save': {'commission_rate': c / 100, 'deliverer_share': d / 100}
            }),
        'Règles enregistrées : elles s\'appliquent aux prochaines '
        'livraisons.');
    if (ok) _reload();
  }

  Future<void> _payout(Map<String, dynamic> a) async {
    final amount = TextEditingController(text: '${a['balance']}');
    final reference = TextEditingController();
    var method = 'MoMo';
    final requestId =
        'p${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(99999)}';
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Verser à ${a['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Solde dû : ${fcfa(a['balance'] as num)}',
                  style: salesBody()),
              const SizedBox(height: 12),
              TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: salesInput('Montant (F)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: salesInput('Moyen'),
                items: const [
                  DropdownMenuItem(value: 'MoMo', child: Text('MTN MoMo')),
                  DropdownMenuItem(value: 'Airtel', child: Text('Airtel Money')),
                  DropdownMenuItem(value: 'Espèces', child: Text('Espèces')),
                  DropdownMenuItem(value: 'Virement', child: Text('Virement')),
                ],
                onChanged: (v) => set(() => method = v ?? method),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: reference,
                  decoration: salesInput('Référence de la transaction',
                      helper: 'N° MoMo, reçu… (contrôle comptable)')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Enregistrer le versement')),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaAdminRecordPayout', {
              'uid': a['uid'],
              'amount': int.tryParse(amount.text.trim()) ?? 0,
              'method': method,
              'reference': reference.text.trim(),
              'requestId': requestId,
            }),
        'Versement enregistré : ${a['name']} est prévenu.');
    if (ok) _reload();
  }

  Future<void> _ledger(Map<String, dynamic> a) async {
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Écritures · ${a['name']}'),
        content: SizedBox(
          width: 520,
          child: FutureBuilder<Map<String, dynamic>>(
            future: salesCall('kitungaAdminAccountLedger', {'uid': a['uid']}),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()));
              }
              final list = listOf(snap.data!['entries']);
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final e in list)
                    ListTile(
                      dense: true,
                      title: Text('${e['label']}', style: salesBody()),
                      subtitle: Text(
                          dateFr(e['at'] as String?, withTime: true),
                          style: salesBody(size: 12)),
                      trailing: Text(fcfa(e['amount'] as num),
                          style: salesTitle(14)),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        final d = snap.data;
        final t = Map<String, dynamic>.from((d?['totals'] as Map?) ?? {});
        final accounts = listOf(d?['accounts'])
            .where((a) => _role == 'all' || a['role'] == _role)
            .toList();
        Widget kpi(String label, num v, {String? help}) => SizedBox(
              width: 210,
              child: SalesCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: salesBody(size: 12.5)),
                    const SizedBox(height: 4),
                    Text(fcfa(v), style: salesTitle(20)),
                    if (help != null) Text(help, style: salesBody(size: 11.5)),
                  ],
                ),
              ),
            );
        return AdminShell(
          current: 'finance',
          title: 'Finances',
          subtitle: 'Encaissements, commission, soldes et versements',
          actions: [
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
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            kpi('Commandes encaissées',
                                t['collectedOrders'] as num? ?? 0),
                            kpi('Abonnements', t['subscriptions'] as num? ?? 0),
                            kpi('Part Kitunga', t['commission'] as num? ?? 0,
                                help: 'commission + reste des frais'),
                            kpi('Remboursements', t['refunds'] as num? ?? 0),
                            kpi('Déjà versé', t['payouts'] as num? ?? 0),
                            kpi('Reste à verser', t['owed'] as num? ?? 0,
                                help: 'commerces et livreurs'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Demandes de retrait des livreurs et commerces.
                        _Withdrawals(onChanged: _reload),
                        const SizedBox(height: 16),
                        SalesCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Règles de partage', style: salesTitle()),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 230,
                                    child: TextField(
                                      controller: _commission,
                                      decoration: salesInput(
                                          'Commission Kitunga (%)',
                                          helper: 'sur le montant des articles'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 230,
                                    child: TextField(
                                      controller: _share,
                                      decoration: salesInput(
                                          'Part du livreur (%)',
                                          helper: 'des frais de livraison'),
                                    ),
                                  ),
                                  FilledButton(
                                      onPressed: _saveRules,
                                      child: const Text('Enregistrer')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Soldes', style: salesTitle()),
                            const SizedBox(width: 12),
                            for (final (k, l) in const [
                              ('all', 'Tous'),
                              ('Seller', 'Commerces'),
                              ('Deliver', 'Livreurs'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(l),
                                  selected: _role == k,
                                  onSelected: (_) =>
                                      setState(() => _role = k),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (accounts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                'Aucun solde : les écritures apparaissent à la '
                                'première commande payée livrée.',
                                style: salesBody()),
                          ),
                        for (final a in accounts)
                          SalesCard(
                            child: Row(
                              children: [
                                Icon(
                                    a['role'] == 'Seller'
                                        ? Icons.storefront_rounded
                                        : Icons.delivery_dining_rounded,
                                    color: kSalesInk),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${a['name'] ?? a['uid']}',
                                          style: salesTitle(14)),
                                      Text(
                                          'Gagné ${fcfa(a['earned'] as num)} · '
                                          'versé ${fcfa(a['paidOut'] as num)}'
                                          '${'${a['phone'] ?? ''}'.isEmpty ? '' : ' · ${a['phone']}'}',
                                          style: salesBody(size: 12.5)),
                                    ],
                                  ),
                                ),
                                Text(fcfa(a['balance'] as num),
                                    style: salesTitle(16)),
                                const SizedBox(width: 10),
                                StaffWriteButton(uid: '${a['uid']}', dense: true),
                                TextButton(
                                    onPressed: () => _ledger(a),
                                    child: const Text('Écritures')),
                                FilledButton(
                                  onPressed: (a['balance'] as num) > 0
                                      ? () => _payout(a)
                                      : null,
                                  child: const Text('Verser'),
                                ),
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


class _Withdrawals extends StatefulWidget {
  const _Withdrawals({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_Withdrawals> createState() => _WithdrawalsState();
}

class _WithdrawalsState extends State<_Withdrawals> {
  late Future<Map<String, dynamic>> _data =
      salesCall('kitungaAdminWithdrawals', const {});

  Future<void> _decide(Map<String, dynamic> w, bool approve) async {
    final answer = await askText(
        context,
        approve
            ? 'Verser ${fcfa(w['amount'] as num)} à ${w['name']}'
            : 'Refuser la demande de ${w['name']}',
        label: approve
            ? 'Référence de la transaction (${w['method']} ${w['phone']})'
            : 'Motif du refus (le demandeur le verra)',
        required: !approve ? true : false);
    if (answer == null && !approve) return;
    if (!mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaAdminDecideWithdrawal', {
              'id': w['id'],
              'approve': approve,
              if (approve) 'reference': answer ?? '',
              if (!approve) 'reason': answer ?? '',
            }),
        approve ? 'Versement enregistré.' : 'Demande refusée.');
    if (ok) {
      setState(() {
        _data = salesCall('kitungaAdminWithdrawals', const {});
      });
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        final list = listOf(snap.data?['withdrawals']);
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SalesCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Demandes de retrait (${list.length})',
                    style: salesTitle()),
                const SizedBox(height: 8),
                for (final w in list)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${w['name']} · ${w['role'] == 'Seller' ? 'Commerce' : 'Livreur'} · '
                            '${fcfa(w['amount'] as num)} par ${w['method']} '
                            '(${w['phone']}) · ${dateFr(w['createdAt'] as String?, withTime: true)}',
                            style: salesBody()),
                      ),
                      TextButton(
                          onPressed: () => _decide(w, false),
                          child: const Text('Refuser')),
                      FilledButton(
                          onPressed: () => _decide(w, true),
                          child: const Text('Versé')),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
