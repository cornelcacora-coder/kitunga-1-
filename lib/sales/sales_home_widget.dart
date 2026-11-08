import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/noc/sales/sales_common.dart';
import 'referral_qr.dart';

/// Espace commercial (rôle Commercial) : remplace l'accueil client. Toutes
/// les données viennent du serveur (kitungaSalesAgentQuery), qui ne renvoie
/// que celles du commercial connecté.
class SalesHomeWidget extends StatefulWidget {
  const SalesHomeWidget({super.key});

  @override
  State<SalesHomeWidget> createState() => _SalesHomeWidgetState();
}

Future<Map<String, dynamic>> agentQuery(String view,
        [Map<String, dynamic> extra = const {}]) =>
    salesCall('kitungaSalesAgentQuery', {'view': view, ...extra});

class _SalesHomeWidgetState extends State<SalesHomeWidget> {
  String _period = 'month';
  late Future<Map<String, dynamic>> _home = _load();

  Future<Map<String, dynamic>> _load() => agentQuery('home', {'period': _period});

  void _reload() {
    setState(() {
      _home = _load();
    });
  }

  Future<void> _signOut() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    if (!mounted) return;
    GoRouter.of(context).clearRedirectLocation();
    context.goNamedAuth(IntroWidget.routeName, context.mounted);
  }

  Future<void> _requestPayout() async {
    final ok = await runSalesAction(context,
        () => salesCall('kitungaRequestPayout', {}),
        'Demande envoyée : l\'administrateur Kitunga va la traiter.');
    if (ok) _reload();
  }

  void _openList(String title, String view) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _AgentListPage(title: title, view: view)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSalesSurface,
      body: RefreshIndicator(
        color: kSalesRed,
        onRefresh: () async => _reload(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _home,
          builder: (context, snap) {
            final data = snap.data;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(data?['profile'] as Map?),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
                  child: snap.connectionState != ConnectionState.done
                      ? const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(
                              child: CircularProgressIndicator(color: kSalesRed)))
                      : snap.hasError
                          ? SalesEmpty(
                              icon: Icons.cloud_off_rounded,
                              title: 'Chargement impossible',
                              text: '${snap.error}',
                              action: TextButton(
                                  onPressed: _reload,
                                  child: const Text('Réessayer')))
                          : _content(data!),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> d) {
    final profile = Map<String, dynamic>.from(d['profile'] as Map);
    final assignments = listOf(d['assignments']);
    final stats = Map<String, dynamic>.from(d['stats'] as Map);
    final money = Map<String, dynamic>.from(d['commissions'] as Map);
    final canRequest = (money['approved'] as num? ?? 0) > 0 &&
        profile['payoutMethodSet'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile['status'] == 'suspended') ...[
          SalesCard(
            child: Row(children: [
              const Icon(Icons.pause_circle_outline_rounded, color: kSalesRed),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                    'Compte suspendu : vos liens ne rapportent plus de commission. '
                    'Contactez l\'administrateur Kitunga.',
                    style: salesBody(color: kSalesInk)),
              ),
            ]),
          ),
          const SizedBox(height: 14.0),
        ],
        if (assignments.isEmpty)
          const SalesCard(
            child: SalesEmpty(
              icon: Icons.campaign_outlined,
              title: 'Aucune campagne en cours',
              text: 'Votre QR code apparaîtra ici dès qu\'une campagne vous sera affectée.',
            ),
          ),
        for (final a in assignments) ...[
          _campaignCard(a),
          const SizedBox(height: 14.0),
        ],
        Wrap(
          spacing: 8.0,
          children: [
            for (final p in const [
              ('today', 'Aujourd\'hui'),
              ('week', 'Semaine'),
              ('month', 'Mois'),
            ])
              ChoiceChip(
                label: Text(p.$2),
                selected: _period == p.$1,
                selectedColor: kSalesRed.withValues(alpha: 0.15),
                onSelected: (_) {
                  _period = p.$1;
                  _reload();
                },
              ),
          ],
        ),
        const SizedBox(height: 10.0),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10.0,
          crossAxisSpacing: 10.0,
          childAspectRatio: 1.7,
          children: [
            _stat('Clics', stats['clicks'], Icons.ads_click_rounded),
            _stat('Installations vérifiées', stats['activations'],
                Icons.verified_rounded),
            _stat('Inscriptions', stats['signups'], Icons.person_add_alt_1_rounded),
            _stat('Abonnements payés', stats['subscriptions'],
                Icons.workspace_premium_rounded),
          ],
        ),
        const SizedBox(height: 16.0),
        SalesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mes commissions', style: salesTitle()),
              const SizedBox(height: 10.0),
              _moneyRow('En attente de validation', money['pending']),
              _moneyRow('Validées (à verser)', money['approved'], bold: true),
              _moneyRow('En cours de versement', money['reserved']),
              _moneyRow('Déjà payées', money['paid']),
              const SizedBox(height: 12.0),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: kSalesRed,
                    minimumSize: const Size.fromHeight(46.0)),
                onPressed: canRequest ? _requestPayout : null,
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Demander un versement'),
              ),
              if (profile['payoutMethodSet'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                      'Votre moyen de paiement n\'est pas encore enregistré : '
                      'contactez l\'administrateur Kitunga.',
                      style: salesBody(size: 12.0)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        for (final l in const [
          (Icons.people_alt_outlined, 'Mes clients', 'clients'),
          (Icons.receipt_long_outlined, 'Détail de mes commissions', 'commissions'),
          (Icons.account_balance_wallet_outlined, 'Mes versements', 'payouts'),
        ]) ...[
          SalesCard(
            onTap: () => _openList(l.$2, l.$3),
            child: Row(children: [
              Icon(l.$1, color: kSalesRed),
              const SizedBox(width: 12.0),
              Expanded(child: Text(l.$2, style: salesTitle(15.0))),
              const Icon(Icons.chevron_right_rounded, color: kSalesMuted),
            ]),
          ),
          const SizedBox(height: 8.0),
        ],
        const SizedBox(height: 16.0),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded, size: 20.0),
          label: const Text('Se déconnecter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kSalesRed,
            side: const BorderSide(color: kSalesRed),
            minimumSize: const Size.fromHeight(48.0),
          ),
        ),
      ],
    );
  }

  Widget _campaignCard(Map<String, dynamic> a) {
    final link = a['link'] as String;
    return SalesCard(
      child: Column(
        children: [
          Text('${a['campaignName']}', style: salesTitle(17.0)),
          Text('Du ${dateFr(a['startsAt'] as String?)} au ${dateFr(a['endsAt'] as String?)}',
              style: salesBody()),
          const SizedBox(height: 12.0),
          LayoutBuilder(
            builder: (context, box) => KitungaReferralQr(
                code: a['referralCode'] as String,
                size: box.maxWidth.clamp(160.0, 240.0) - 32.0),
          ),
          const SizedBox(height: 8.0),
          Text('Faites scanner ce QR code, ou partagez votre lien.',
              textAlign: TextAlign.center, style: salesBody()),
          const SizedBox(height: 8.0),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lien copié.')));
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copier mon lien'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, dynamic value, IconData icon) => Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: const Color(0xFFE9E9EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18.0, color: kSalesRed),
            const Spacer(),
            Text('${value ?? 0}',
                style: GoogleFonts.interTight(
                    fontSize: 22.0, fontWeight: FontWeight.w800, color: kSalesInk)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: salesBody(size: 12.0)),
          ],
        ),
      );

  Widget _moneyRow(String label, dynamic value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(children: [
          Expanded(child: Text(label, style: salesBody(color: kSalesInk))),
          Text(fcfa(value as num?),
              style: bold ? salesTitle(15.0) : salesBody(color: kSalesInk)),
        ]),
      );

  Widget _header(Map? profile) {
    final name = (profile?['displayName'] as String?) ?? '';
    final code = (profile?['agentCode'] as String?) ?? '';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kSalesRed, kSalesDeepRed],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.0)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 18.0, 24.0, 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/logo/kitunga_logo_white.png', height: 52.0),
              const SizedBox(height: 14.0),
              Text('ESPACE COMMERCIAL',
                  style: GoogleFonts.interTight(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
              const SizedBox(height: 4.0),
              Text(name.isEmpty ? 'Bienvenue' : name,
                  style: GoogleFonts.interTight(
                      color: Colors.white,
                      fontSize: 26.0,
                      fontWeight: FontWeight.w800)),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(code,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Listes de l'espace commercial : clients, commissions, versements.
class _AgentListPage extends StatefulWidget {
  const _AgentListPage({required this.title, required this.view});

  final String title;
  final String view;

  @override
  State<_AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<_AgentListPage> {
  late Future<Map<String, dynamic>> _future = agentQuery(widget.view);

  @override
  Widget build(BuildContext context) {
    void reload() {
      setState(() {
        _future = agentQuery(widget.view);
      });
    }

    return Scaffold(
      backgroundColor: kSalesSurface,
      appBar: AppBar(
          backgroundColor: kSalesRed,
          foregroundColor: Colors.white,
          title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SalesLoader(
            future: _future,
            onRetry: reload,
            builder: (data) {
              final items = listOf(data[widget.view]);
              if (items.isEmpty) {
                return const SalesEmpty(
                    icon: Icons.inbox_outlined, title: 'Rien pour l\'instant');
              }
              return Column(
                children: [
                  for (final i in items) ...[
                    SalesCard(child: _row(i)),
                    const SizedBox(height: 8.0),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> i) {
    switch (widget.view) {
      case 'clients':
        return Row(children: [
          Icon(i['subscribed'] == true
              ? Icons.workspace_premium_rounded
              : Icons.person_outline_rounded,
              color: i['subscribed'] == true ? kSalesRed : kSalesMuted),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i['name']}', style: salesTitle(15.0)),
                Text(
                    'Inscrit le ${dateFr(i['signedUpAt'] as String?)} · '
                    '${i['subscribed'] == true ? 'abonné' : 'pas encore abonné'}',
                    style: salesBody()),
                if (i['status'] != 'confirmed')
                  Text('Non retenu (même personne ou auto-parrainage)',
                      style: salesBody(color: kSalesRed)),
              ],
            ),
          ),
        ]);
      case 'commissions':
        return Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(commissionType[i['type']] ?? '${i['type']}',
                    style: salesTitle(15.0)),
                Text('Le ${dateFr(i['createdAt'] as String?)}', style: salesBody()),
                if (i['statusReason'] != null)
                  Text('${i['statusReason']}', style: salesBody()),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fcfa(i['amount'] as num?), style: salesTitle(15.0)),
              StatusChip(commissionStatus[i['status']]),
            ],
          ),
        ]);
      default:
        return Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fcfa(i['amount'] as num?), style: salesTitle(15.0)),
                Text('${i['itemsCount']} commission(s) · demandé le '
                    '${dateFr(i['requestedAt'] as String?)}',
                    style: salesBody()),
                if (i['externalReference'] != null)
                  Text('Payé le ${dateFr(i['paidAt'] as String?)} · réf. '
                      '${i['externalReference']}',
                      style: salesBody(color: kSalesInk)),
                if (i['statusReason'] != null)
                  Text('Motif : ${i['statusReason']}', style: salesBody()),
              ],
            ),
          ),
          StatusChip(payoutStatus[i['status']]),
        ]);
    }
  }
}
