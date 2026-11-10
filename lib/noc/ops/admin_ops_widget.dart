import 'package:flutter/material.dart';

import '/noc/sales/sales_admin_widget.dart' show SalesPage;
import '/noc/sales/sales_common.dart';
import '/noc/ui/admin_export.dart';
import '/noc/admin/admin_layout.dart' show AdminShell, AdminTabbedBody;
import 'purge_tab.dart';

/// Gestion (adresse /gestion) : remboursements à traiter, abonnements offerts
/// ou prolongés, suspension des comptes. Tout passe par le serveur, qui
/// vérifie le rôle admin et journalise chaque action.
class AdminOpsWidget extends StatelessWidget {
  const AdminOpsWidget({super.key});

  static String routeName = 'AdminOps';
  static String routePath = '/gestion';

  @override
  Widget build(BuildContext context) {
    return const AdminShell(
      current: 'ops',
      title: 'Remboursements & comptes',
      subtitle: 'Remboursements à traiter, abonnements offerts, comptes suspendus',
      body: AdminTabbedBody(
        tabs: [
          (Icons.currency_exchange_rounded, 'Remboursements'),
          (Icons.workspace_premium_outlined, 'Abonnements'),
          (Icons.manage_accounts_outlined, 'Comptes'),
          (Icons.cleaning_services_outlined, 'Données de test'),
        ],
        children: [
          _RefundsTab(),
          _AccountsTab(mode: _AccountsMode.subscriptions),
          _AccountsTab(mode: _AccountsMode.accounts),
          PurgeTestDataTab(),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>> _opsQuery(Map<String, dynamic> data) =>
    salesCall('kitungaAdminOpsQuery', data);

// ── Remboursements ───────────────────────────────────────────────────────

class _RefundsTab extends StatefulWidget {
  const _RefundsTab();

  @override
  State<_RefundsTab> createState() => _RefundsTabState();
}

class _RefundsTabState extends State<_RefundsTab> {
  late Future<Map<String, dynamic>> _future = _opsQuery({'view': 'refunds'});

  void _reload() {
    setState(() {
      _future = _opsQuery({'view': 'refunds'});
    });
  }

  Future<void> _markRefunded(Map<String, dynamic> r) async {
    final reference = await askText(context, 'Remboursement effectué',
        label: 'Référence du transfert',
        hint: 'Après avoir renvoyé ${fcfa(r['amount'] as num?)} au client '
            '(Mobile Money), saisissez la référence de la transaction.');
    if (reference == null || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaMarkRefunded',
            {'orderId': r['orderId'], 'reference': reference}),
        'Remboursement enregistré.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SalesPage(
      onRefresh: () async => _reload(),
      children: [
        Text(
            'Commandes payées puis annulées ou refusées. Le remboursement '
            'automatique n\'est pas activé : renvoyez l\'argent au client, '
            'puis enregistrez la référence du transfert.',
            style: salesBody()),
        const SizedBox(height: 14.0),
        SalesLoader(
          future: _future,
          onRetry: _reload,
          builder: (data) {
            final refunds = listOf(data['refunds']);
            if (refunds.isEmpty) {
              return const SalesEmpty(
                  icon: Icons.task_alt_rounded,
                  title: 'Aucun remboursement à traiter');
            }
            final total = refunds.fold<num>(
                0, (s, r) => s + ((r['amount'] as num?) ?? 0));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${refunds.length} commande(s) · ${fcfa(total)} à rembourser',
                          style: salesTitle(15.0)),
                    ),
                    AdminExportButton(
                      data: () => AdminExportData(
                        title: 'Remboursements à traiter',
                        subtitle: '${refunds.length} commande(s) · ${fcfa(total)} à rembourser',
                        fileName: 'remboursements',
                        headers: ['Commande', 'Montant', 'Statut commande',
                          'Remboursement', 'Client', 'Téléphone', 'Email',
                          'Référence MTN', 'Mise à jour'],
                        flex: [3, 2, 2, 3, 3, 2, 3, 3, 2],
                        moneyColumns: {1},
                        rows: [
                          for (final r in refunds)
                            [
                              r['reference'] ?? '',
                              r['amount'] as num?,
                              r['status'] ?? '',
                              r['refundStatus'] ?? '',
                              (r['client'] as Map?)?['name'] ?? '',
                              (r['client'] as Map?)?['phone'] ?? '',
                              (r['client'] as Map?)?['email'] ?? '',
                              r['paymentReference'] ?? '',
                              dateFr(r['updatedAt'] as String?),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                for (final r in refunds) ...[
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
                                  Text(fcfa(r['amount'] as num?),
                                      style: salesTitle(17.0)),
                                  Text('${r['reference']}',
                                      style: salesBody(color: kSalesInk)),
                                  StatusChip((
                                    label: '${r['refundStatus']}',
                                    color: r['refundStatus'] == 'Échec'
                                        ? kSalesRed
                                        : const Color(0xFFE08A00),
                                  )),
                                ],
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                  '${(r['client'] as Map)['name']} · '
                                  '${(r['client'] as Map)['phone']}',
                                  style: salesBody(color: kSalesInk)),
                              Text(
                                  'Commande ${(r['status'] as String).toLowerCase()} '
                                  'le ${dateFr(r['updatedAt'] as String?)}',
                                  style: salesBody()),
                              // Retour accepté : articles seulement.
                              if ('${r['reason'] ?? ''}'.isNotEmpty)
                                Text('${r['reason']} · montant des articles, '
                                    'sans la livraison',
                                    style: salesBody(color: kSalesInk)),
                              if (r['paymentReference'] != null)
                                Text('Paiement MTN : ${r['paymentReference']}',
                                    style: salesBody()),
                              if (r['refundError'] != null)
                                Text('${r['refundError']}',
                                    style: salesBody(color: kSalesRed)),
                            ],
                          ),
                        ),
                        if (r['refundStatus'] != 'En cours')
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF136B3D)),
                            onPressed: () => _markRefunded(r),
                            child: const Text('Marquer remboursé'),
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

// ── Abonnements et comptes ───────────────────────────────────────────────

enum _AccountsMode { subscriptions, accounts }

const _roleLabel = {
  'User': 'Client',
  'Guest': 'Visiteur',
  'Seller': 'Commerçant',
  'Deliver': 'Livreur',
  'Admin': 'Administrateur',
  'Commercial': 'Commercial',
};

class _AccountsTab extends StatefulWidget {
  const _AccountsTab({required this.mode});

  final _AccountsMode mode;

  @override
  State<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<_AccountsTab> {
  final _search = TextEditingController();
  Future<Map<String, dynamic>>? _future;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _run() {
    final q = _search.text.trim();
    if (q.length < 2) return;
    setState(() {
      _future = _opsQuery({'view': 'search', 'q': q});
    });
  }

  Future<void> _grant(Map<String, dynamic> a) async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Abonnement de ${a['displayName']}'),
        children: [
          for (final d in const [(7, '7 jours'), (30, '1 mois'), (90, '3 mois'),
            (365, '1 an')])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d.$1),
              child: Text('Offrir ou prolonger de ${d.$2}'),
            ),
        ],
      ),
    );
    if (days == null || !mounted) return;
    final reason = await askText(context, 'Motif',
        hint: 'Geste commercial, paiement reçu hors application, erreur…');
    if (reason == null || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaGrantSubscription',
            {'userUid': a['uid'], 'days': days, 'reason': reason}),
        'Abonnement prolongé.');
    if (ok) _run();
  }

  Future<void> _setStatus(Map<String, dynamic> a, String status) async {
    String reason = '';
    if (status == 'suspended') {
      final r = await askText(context, 'Suspendre ${a['displayName']}',
          hint: 'La connexion sera bloquée ; les sessions ouvertes se '
              'ferment dans l\'heure.');
      if (r == null) return;
      reason = r;
    }
    if (!mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSetAccountStatus',
            {'userUid': a['uid'], 'status': status, 'reason': reason}),
        status == 'suspended' ? 'Compte suspendu.' : 'Compte réactivé.');
    if (ok) _run();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = widget.mode == _AccountsMode.subscriptions;
    return SalesPage(
      children: [
        Text(
            subscriptions
                ? 'Offrir ou prolonger l\'abonnement d\'un client (sans paiement, '
                    'donc sans commission). Chaque action est journalisée.'
                : 'Suspendre ou réactiver un client, un commerçant ou un livreur. '
                    'Les commerciaux se gèrent dans le module commercial.',
            style: salesBody()),
        const SizedBox(height: 14.0),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(),
                decoration: salesInput('Rechercher un compte',
                    hint: 'E-mail, téléphone ou début du nom'),
              ),
            ),
            const SizedBox(width: 10.0),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: kSalesRed,
                  minimumSize: const Size(0, 52.0)),
              onPressed: _run,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Chercher'),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        if (_future == null)
          const SalesEmpty(
              icon: Icons.person_search_rounded,
              title: 'Recherchez un compte pour commencer')
        else
          SalesLoader(
            future: _future!,
            onRetry: _run,
            builder: (data) {
              final accounts = listOf(data['accounts']);
              if (accounts.isEmpty) {
                return const SalesEmpty(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun compte trouvé',
                    text: 'Essayez l\'e-mail exact ou le numéro de téléphone.');
              }
              return Column(
                children: [
                  for (final a in accounts) ...[
                    _accountCard(a, subscriptions),
                    const SizedBox(height: 10.0),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _accountCard(Map<String, dynamic> a, bool subscriptions) {
    final role = a['role'] as String? ?? 'User';
    final suspended = a['accountStatus'] == 'suspended';
    final until = DateTime.tryParse('${a['subscribeCloseAt']}');
    final subscribed = until != null && until.isAfter(DateTime.now());
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
                    Text(
                        (a['displayName'] as String?)?.isNotEmpty == true
                            ? a['displayName'] as String
                            : 'Sans nom',
                        style: salesTitle()),
                    StatusChip((
                      label: _roleLabel[role] ?? role,
                      color: kSalesMuted,
                    )),
                    if (suspended)
                      const StatusChip((label: 'Suspendu', color: kSalesRed)),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text('${a['email']}'
                    '${(a['phone'] as String?)?.isNotEmpty == true ? ' · ${a['phone']}' : ''}',
                    style: salesBody()),
                if (role == 'User')
                  Text(
                      subscribed
                          ? 'Abonné jusqu\'au ${dateFr(a['subscribeCloseAt'] as String?)}'
                          : until == null
                              ? 'Jamais abonné'
                              : 'Abonnement terminé le ${dateFr(a['subscribeCloseAt'] as String?)}',
                      style: salesBody(color: subscribed ? kSalesInk : kSalesMuted)),
                if (suspended && a['accountStatusReason'] != null)
                  Text('Motif : ${a['accountStatusReason']}', style: salesBody()),
              ],
            ),
          ),
          if (subscriptions && role == 'User')
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kSalesRed),
              onPressed: () => _grant(a),
              child: const Text('Prolonger'),
            ),
          if (!subscriptions &&
              ['User', 'Guest', 'Seller', 'Deliver'].contains(role))
            suspended
                ? FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF136B3D)),
                    onPressed: () => _setStatus(a, 'active'),
                    child: const Text('Réactiver'),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: kSalesRed),
                    onPressed: () => _setStatus(a, 'suspended'),
                    child: const Text('Suspendre'),
                  ),
        ],
      ),
    );
  }
}
