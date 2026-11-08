import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'sales_agents_tab.dart';
import 'sales_campaigns_tab.dart';
import 'sales_common.dart';
import 'sales_money_tabs.dart';

/// Module commercial : interface d'administration (adresse /commercial).
class SalesAdminWidget extends StatelessWidget {
  const SalesAdminWidget({super.key});

  static String routeName = 'AdminSales';
  static String routePath = '/commercial';

  static const _tabs = [
    (Icons.insights_rounded, 'Vue d\'ensemble'),
    (Icons.badge_outlined, 'Commerciaux'),
    (Icons.campaign_outlined, 'Campagnes'),
    (Icons.payments_outlined, 'Commissions'),
    (Icons.account_balance_wallet_outlined, 'Versements'),
    (Icons.history_rounded, 'Historique'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: kSalesSurface,
        appBar: AppBar(
          backgroundColor: kSalesRed,
          foregroundColor: Colors.white,
          elevation: 0.0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Tableau de bord',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/supervisionDashboard'),
          ),
          title: Row(
            children: [
              Image.asset('assets/logo/kitunga_logo_white.png', height: 30.0),
              const SizedBox(width: 12.0),
              Flexible(
                child: Text('Module commercial',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.interTight(
                        fontWeight: FontWeight.w800, fontSize: 19.0)),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3.0,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            tabs: [
              for (final t in _tabs) Tab(icon: Icon(t.$1, size: 20.0), text: t.$2),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            SalesAgentsTab(),
            SalesCampaignsTab(),
            SalesCommissionsTab(),
            SalesPayoutsTab(),
            _AuditTab(),
          ],
        ),
      ),
    );
  }
}

/// Largeur de lecture confortable sur ordinateur.
class SalesPage extends StatelessWidget {
  const SalesPage({super.key, required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 40.0),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(color: kSalesRed, onRefresh: onRefresh!, child: list);
  }
}

// ── Vue d'ensemble ───────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  String _period = 'month';
  DateTimeRange? _custom;
  String? _campaignId;
  String? _agentUid;
  late Future<Map<String, dynamic>> _stats = _load();
  late final Future<Map<String, dynamic>> _choices = Future.wait([
    salesQuery('campaigns'),
    salesQuery('agents'),
  ]).then((r) => {'campaigns': r[0]['campaigns'], 'agents': r[1]['agents']});

  Future<Map<String, dynamic>> _load() => salesQuery('overview', {
        'period': _period,
        if (_period == 'custom' && _custom != null) ...{
          'from': brazzavilleDayStart(_custom!.start),
          'to': brazzavilleDayEnd(_custom!.end),
        },
        if (_campaignId != null) 'campaignId': _campaignId,
        if (_agentUid != null) 'agentUid': _agentUid,
      });

  void _reload() => setState(() {
        _stats = _load();
      });

  Future<void> _choosePeriod(String p) async {
    if (p == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2025),
        lastDate: DateTime.now(),
        locale: const Locale('fr'),
      );
      if (range == null) return;
      _custom = range;
    }
    _period = p;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SalesPage(
      onRefresh: () async => _reload(),
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final p in const [
              ('today', 'Aujourd\'hui'),
              ('week', 'Cette semaine'),
              ('month', 'Ce mois'),
              ('custom', 'Période…'),
            ])
              ChoiceChip(
                label: Text(p.$1 == 'custom' && _custom != null &&
                        _period == 'custom'
                    ? '${DateFormat('d MMM', 'fr').format(_custom!.start)} – '
                        '${DateFormat('d MMM', 'fr').format(_custom!.end)}'
                    : p.$2),
                selected: _period == p.$1,
                selectedColor: kSalesRed.withValues(alpha: 0.15),
                onSelected: (_) => _choosePeriod(p.$1),
              ),
            FutureBuilder<Map<String, dynamic>>(
              future: _choices,
              builder: (context, snap) {
                final campaigns = listOf(snap.data?['campaigns']);
                final agents = listOf(snap.data?['agents']);
                return Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    _filter<String?>('Toutes les campagnes', _campaignId, [
                      for (final c in campaigns) (c['id'] as String, c['name'] as String),
                    ], (v) {
                      _campaignId = v;
                      _reload();
                    }),
                    _filter<String?>('Tous les commerciaux', _agentUid, [
                      for (final a in agents)
                        (a['uid'] as String, '${a['agentCode']} · ${a['displayName']}'),
                    ], (v) {
                      _agentUid = v;
                      _reload();
                    }),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20.0),
        SalesLoader(
          future: _stats,
          onRetry: _reload,
          builder: (s) {
            final c = Map<String, dynamic>.from(s['commissions'] as Map);
            final conv = Map<String, dynamic>.from(s['conversion'] as Map);
            String pct(dynamic v) => v == null ? '—' : '$v %';
            final tiles = [
              _Kpi('Campagnes actives', '${s['activeCampaigns']}', Icons.campaign_rounded),
              _Kpi('Commerciaux actifs', '${s['activeAgents']}', Icons.badge_rounded),
              _Kpi('Clics', '${s['clicks']}', Icons.ads_click_rounded),
              _Kpi('Activations vérifiées', '${s['activations']}', Icons.verified_rounded),
              _Kpi('Inscriptions', '${s['signups']}', Icons.person_add_alt_1_rounded),
              _Kpi('Abonnements payés', '${s['subscriptions']}', Icons.workspace_premium_rounded),
              _Kpi('Conversion clic → inscription', pct(conv['signupPerClick']),
                  Icons.trending_up_rounded),
              _Kpi('Conversion inscription → abonnement',
                  pct(conv['subscriptionPerSignup']), Icons.trending_up_rounded),
              _Kpi('Commissions générées', fcfa(c['generated']), Icons.receipt_long_rounded),
              _Kpi('Commissions payées (total)', fcfa(c['paid']), Icons.paid_rounded),
              _Kpi('Reste à payer', fcfa(c['due']),
                  Icons.account_balance_wallet_rounded, highlight: true),
              _Kpi('En attente de validation', fcfa(c['pending']),
                  Icons.hourglass_top_rounded),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Du ${dateFr(s['period']['start'] as String?, withTime: true)} '
                  'au ${dateFr(s['period']['end'] as String?, withTime: true)}',
                  style: salesBody(),
                ),
                const SizedBox(height: 12.0),
                LayoutBuilder(builder: (context, box) {
                  final columns = box.maxWidth > 900
                      ? 4
                      : box.maxWidth > 560
                          ? 3
                          : 2;
                  final w = (box.maxWidth - (columns - 1) * 12.0) / columns;
                  return Wrap(
                    spacing: 12.0,
                    runSpacing: 12.0,
                    children: [for (final t in tiles) SizedBox(width: w, child: t)],
                  );
                }),
                if (c['truncated'] == true) ...[
                  const SizedBox(height: 12.0),
                  Text('Totaux calculés sur les 5 000 premières commissions.',
                      style: salesBody()),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _filter<T>(String all, T value, List<(String, String)> options,
      ValueChanged<String?> onChanged) {
    return Container(
      width: 280.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFE0E0E6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value as String?,
          isExpanded: true,
          style: salesBody(color: kSalesInk),
          items: [
            DropdownMenuItem<String?>(
                value: null, child: Text(all, overflow: TextOverflow.ellipsis)),
            for (final o in options)
              DropdownMenuItem<String?>(
                  value: o.$1,
                  child: Text(o.$2, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, {this.highlight = false});

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132.0,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(colors: [kSalesRed, kSalesDeepRed])
            : null,
        color: highlight ? null : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: highlight ? null : Border.all(color: const Color(0xFFE9E9EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: highlight ? Colors.white : kSalesRed),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.interTight(
                    fontSize: 24.0,
                    fontWeight: FontWeight.w800,
                    color: highlight ? Colors.white : kSalesInk)),
          ),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: salesBody(
                  size: 12.0, color: highlight ? Colors.white70 : kSalesMuted)),
        ],
      ),
    );
  }
}

// ── Historique ───────────────────────────────────────────────────────────

const _auditLabels = <String, String>{
  'agent.create': 'Commercial créé',
  'agent.update': 'Commercial modifié',
  'agent.active': 'Commercial réactivé',
  'agent.suspended': 'Commercial suspendu',
  'agent.archived': 'Commercial archivé',
  'rule.create': 'Barème créé',
  'campaign.create': 'Campagne créée',
  'campaign.update': 'Campagne modifiée',
  'assignment.create': 'Commercial affecté',
  'assignment.ended': 'Affectation terminée',
  'assignment.cancelled': 'Affectation annulée',
  'assignment.close_batch': 'Affectations fermées (clôture)',
  'commission.create': 'Commission générée',
  'commission.approved': 'Commission validée',
  'commission.rejected': 'Commission rejetée',
  'commission.reversed': 'Commission annulée',
  'commission.reversal': 'Contrepassation créée',
  'payout.requested': 'Versement demandé',
  'payout.approved': 'Versement validé',
  'payout.rejected': 'Versement refusé',
  'payout.paid': 'Versement payé',
};

class _AuditTab extends StatefulWidget {
  const _AuditTab();

  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  late Future<Map<String, dynamic>> _future = salesQuery('audit');

  @override
  Widget build(BuildContext context) {
    void reload() => setState(() {
        _future = salesQuery('audit');
      });
    return SalesPage(
      onRefresh: () async => reload(),
      children: [
        Text('150 dernières actions', style: salesBody()),
        const SizedBox(height: 12.0),
        SalesLoader(
          future: _future,
          onRetry: reload,
          builder: (data) {
            final items = listOf(data['audit']);
            if (items.isEmpty) {
              return const SalesEmpty(
                  icon: Icons.history_rounded, title: 'Aucune action pour l\'instant');
            }
            return SalesCard(
              child: Column(
                children: [
                  for (final a in items)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          a['actorRole'] == 'system'
                              ? Icons.smart_toy_outlined
                              : Icons.person_outline_rounded,
                          color: kSalesMuted),
                      title: Text(
                          _auditLabels[a['action']] ?? '${a['action']}',
                          style: salesBody(color: kSalesInk, size: 14.0)),
                      subtitle: Text(
                          '${a['actorRole'] == 'system' ? 'Automatique' : a['actorRole']}'
                          ' · ${a['target']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: salesBody(size: 12.0)),
                      trailing: Text(dateFr(a['createdAt'] as String?, withTime: true),
                          style: salesBody(size: 12.0)),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
