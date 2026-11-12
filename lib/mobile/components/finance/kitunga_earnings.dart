import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';

/// « Mes gains » (livreur) / « Mes revenus » (commerce) : solde, gains du
/// jour et de la semaine, versements reçus, détail des écritures. Les
/// montants viennent du grand livre tenu par le serveur.

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    earningsBackendOverride;

Future<Map<String, dynamic>> kitungaMyEarnings() =>
    earningsBackendOverride != null
        ? earningsBackendOverride!('kitungaMyEarnings', const {})
        : kitungaCallFunction('kitungaMyEarnings', const {});

const _red = Color(0xFFE51A1A);
const _redDark = Color(0xFFB0101A);
const _green = Color(0xFF17A35B);

String fcfaOf(num v) => '${NumberFormat.decimalPattern('fr').format(v)} F';

Future<void> openKitungaEarnings(BuildContext context,
        {bool seller = false}) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => KitungaEarningsPage(seller: seller)));

class KitungaEarningsPage extends StatefulWidget {
  const KitungaEarningsPage({super.key, this.seller = false});

  final bool seller;

  @override
  State<KitungaEarningsPage> createState() => _KitungaEarningsPageState();
}

class _KitungaEarningsPageState extends State<KitungaEarningsPage> {
  late Future<Map<String, dynamic>> _data = kitungaMyEarnings();

  Future<void> _reload() async {
    final f = kitungaMyEarnings();
    setState(() {
      _data = f;
    });
    await f.catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = widget.seller ? 'Mes revenus' : 'Mes gains';
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text(title,
            style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: _red, size: 40),
                    const SizedBox(height: 10),
                    Text('Impossible de charger vos gains.',
                        style: GoogleFonts.inter(color: theme.primaryText)),
                    TextButton(
                        onPressed: _reload, child: const Text('Réessayer')),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _red));
          }
          final d = snap.data!;
          final entries = (d['entries'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final s = Map<String, dynamic>.from((d['settings'] as Map?) ?? {});
          final rule = widget.seller
              ? 'Commission Kitunga : '
                  '${((s['commission_rate'] as num? ?? 0) * 100).round()} % '
                  'du montant des articles.'
              : 'Vous recevez '
                  '${((s['deliverer_share'] as num? ?? 1) * 100).round()} % '
                  'des frais de livraison de chaque course livrée.';
          return RefreshIndicator(
            color: _red,
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_red, _redDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solde à recevoir',
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(fcfaOf(d['balance'] as num? ?? 0),
                          key: const ValueKey('earnings-balance'),
                          style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                          'Versé par Kitunga : '
                          '${fcfaOf(d['paidOut'] as num? ?? 0)}',
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: [
                    for (final (label, key) in const [
                      ('Aujourd\'hui', 'today'),
                      ('7 jours', 'week'),
                      ('Ce mois', 'month'),
                      ('Depuis le début', 'total'),
                    ])
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.alternate),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(label,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.secondaryText)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(fcfaOf(d[key] as num? ?? 0),
                                  style: GoogleFonts.interTight(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.primaryText)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(rule,
                      style: GoogleFonts.inter(
                          fontSize: 12.5, color: theme.secondaryText)),
                ),
                const SizedBox(height: 14),
                // Retrait : demande validée par Kitunga (versement).
                _WithdrawalBox(
                    balance: d['balance'] as num? ?? 0, onDone: _reload),
                const SizedBox(height: 18),
                Text('Détail',
                    style: GoogleFonts.interTight(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText)),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        widget.seller
                            ? 'Vos ventes apparaîtront ici dès qu\'une '
                                'commande payée sera livrée.'
                            : 'Vos gains apparaîtront ici dès votre '
                                'première course livrée.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: theme.secondaryText)),
                  ),
                for (final e in entries) _EntryTile(e: e),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.e});

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final amount = e['amount'] as num? ?? 0;
    final type = '${e['type']}';
    final icon = switch (type) {
      'payout' => Icons.account_balance_wallet_rounded,
      'reversal' => Icons.undo_rounded,
      'sale' => Icons.storefront_rounded,
      _ => Icons.delivery_dining_rounded,
    };
    final at = DateTime.tryParse('${e['at']}')?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.alternate),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (amount >= 0 ? _green : _red).withValues(alpha: 0.1),
          child: Icon(icon, color: amount >= 0 ? _green : _red),
        ),
        title: Text('${e['label']}',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: theme.primaryText)),
        subtitle: at == null
            ? null
            : Text(DateFormat('d MMM yyyy, HH:mm', 'fr').format(at),
                style: GoogleFonts.inter(
                    fontSize: 12, color: theme.secondaryText)),
        trailing: Text('${amount >= 0 ? '+' : '−'}${fcfaOf(amount.abs())}',
            style: GoogleFonts.interTight(
                fontWeight: FontWeight.w800,
                color: amount >= 0 ? _green : _red)),
      ),
    );
  }
}


Future<Map<String, dynamic>> _fin(String name, Map<String, dynamic> data) =>
    earningsBackendOverride != null
        ? earningsBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

const _withdrawalStatus = {
  'pending': ('En attente de versement', Color(0xFFE08A00)),
  'paid': ('Versé', _green),
  'rejected': ('Refusé', _red),
};

/// Demande de retrait et suivi des demandes.
class _WithdrawalBox extends StatefulWidget {
  const _WithdrawalBox({required this.balance, required this.onDone});

  final num balance;
  final Future<void> Function() onDone;

  @override
  State<_WithdrawalBox> createState() => _WithdrawalBoxState();
}

class _WithdrawalBoxState extends State<_WithdrawalBox> {
  late Future<Map<String, dynamic>> _list = _fin('kitungaMyWithdrawals', {});

  Future<void> _request() async {
    final amount =
        TextEditingController(text: '${widget.balance.round()}');
    final phone = TextEditingController();
    var method = 'MoMo';
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Demander un retrait',
                  style: GoogleFonts.interTight(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Solde disponible : ${fcfaOf(widget.balance)}. '
                  'Kitunga verse puis confirme dans l\'application.',
                  style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('withdraw-amount'),
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Montant (F)', helperText: 'Minimum 500 F'),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'MoMo', label: Text('MTN MoMo')),
                  ButtonSegment(value: 'Airtel', label: Text('Airtel Money')),
                ],
                selected: {method},
                onSelectionChanged: (v) => set(() => method = v.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Numéro qui reçoit',
                    helperText: 'Vide : le numéro de votre compte'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('withdraw-send'),
                style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Envoyer la demande'),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _fin('kitungaRequestWithdrawal', {
        'amount': int.tryParse(amount.text.trim()) ?? 0,
        'method': method,
        'phone': phone.text.trim(),
      });
      messenger.showSnackBar(const SnackBar(
          content: Text('Demande envoyée : Kitunga vous préviendra.')));
      setState(() {
        _list = _fin('kitungaMyWithdrawals', {});
      });
      await widget.onDone();
    } on ServerPaymentException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Connexion impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _list,
      builder: (context, snap) {
        final list = (snap.data?['withdrawals'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final pending = list.any((w) => w['status'] == 'pending');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              key: const ValueKey('withdraw-open'),
              style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: pending || widget.balance < 500 ? null : _request,
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: Text(pending
                  ? 'Retrait en cours de traitement'
                  : widget.balance < 500
                      ? 'Retrait possible dès 500 F'
                      : 'Demander un retrait'),
            ),
            for (final w in list.take(5))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded,
                        color: theme.secondaryText, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Retrait ${fcfaOf(w['amount'] as num? ?? 0)} · '
                          '${w['method']}'
                          '${'${w['reason'] ?? ''}'.isEmpty ? '' : ' · ${w['reason']}'}',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: theme.primaryText)),
                    ),
                    Text(
                        (_withdrawalStatus[w['status']] ??
                                ('${w['status']}', theme.secondaryText))
                            .$1,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (_withdrawalStatus[w['status']] ??
                                    ('', theme.secondaryText))
                                .$2)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
