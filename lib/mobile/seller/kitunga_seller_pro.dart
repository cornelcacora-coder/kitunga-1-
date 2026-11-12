import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'kitunga_seller_actions.dart' show sellerCall;

/// Pages professionnelles du vendeur : performances, avis, stock.

const _red = Color(0xFFE51A1A);
const _redDark = Color(0xFFB0101A);
const _green = Color(0xFF17A35B);
const _orange = Color(0xFFE08A00);

String _fcfa(num v) => '${NumberFormat.decimalPattern('fr').format(v)} F';

void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

PreferredSizeWidget _bar(BuildContext context, String title) {
  final theme = FlutterFlowTheme.of(context);
  return AppBar(
    backgroundColor: theme.secondaryBackground,
    foregroundColor: theme.primaryText,
    elevation: 0,
    title: Text(title,
        style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
  );
}

Widget _loader(AsyncSnapshot snap, VoidCallback retry) => snap.hasError
    ? Center(
        child: TextButton(
            onPressed: retry,
            child: const Text('Connexion impossible. Réessayer')))
    : const Center(child: CircularProgressIndicator(color: _red));

// ── Performances ─────────────────────────────────────────────────────────

class SellerPerformancePage extends StatefulWidget {
  const SellerPerformancePage({super.key});

  @override
  State<SellerPerformancePage> createState() => _SellerPerformanceState();
}

class _SellerPerformanceState extends State<SellerPerformancePage> {
  late Future<Map<String, dynamic>> _data =
      sellerCall('kitungaSellerPerformance', const {});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: _bar(context, 'Mes performances'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) {
            return _loader(snap, () => setState(() {
                  _data = sellerCall('kitungaSellerPerformance', const {});
                }));
          }
          final d = snap.data!;
          final days = (d['salesByDay'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final max = days.fold<num>(
              1, (m, e) => (e['amount'] as num) > m ? e['amount'] as num : m);
          final top = (d['topProducts'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          Widget kpi(String label, String value, IconData icon, Color c) =>
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.alternate),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                        radius: 18,
                        backgroundColor: c.withValues(alpha: 0.12),
                        child: Icon(icon, color: c, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(value,
                                style: GoogleFonts.interTight(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: theme.primaryText)),
                          ),
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: theme.secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  kpi('Ventes livrées', _fcfa(d['revenue'] as num? ?? 0),
                      Icons.payments_rounded, _red),
                  kpi('Revenus du mois', _fcfa(d['monthEarnings'] as num? ?? 0),
                      Icons.account_balance_wallet_rounded, _green),
                  kpi('Commandes livrées', '${d['delivered'] ?? 0}',
                      Icons.task_alt_rounded, _green),
                  kpi(
                      'Panier moyen',
                      d['averageBasket'] == null
                          ? '—'
                          : _fcfa(d['averageBasket'] as num),
                      Icons.shopping_basket_rounded,
                      const Color(0xFF2563EB)),
                  kpi(
                      'Préparation moyenne',
                      d['averagePrepMinutes'] == null
                          ? '—'
                          : '${d['averagePrepMinutes']} min',
                      Icons.timer_rounded,
                      _orange),
                  kpi(
                      'Taux de refus',
                      d['refusalRate'] == null ? '—' : '${d['refusalRate']} %',
                      Icons.block_rounded,
                      _red),
                ],
              ),
              const SizedBox(height: 20),
              Text('Ventes des 7 derniers jours',
                  style: GoogleFonts.interTight(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
              const SizedBox(height: 10),
              Container(
                height: 180,
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.alternate),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                  (days[i]['amount'] as num) == 0
                                      ? ''
                                      : NumberFormat.compact(locale: 'fr')
                                          .format(days[i]['amount']),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: theme.secondaryText)),
                              const SizedBox(height: 2),
                              Container(
                                height:
                                    110 * (days[i]['amount'] as num) / max + 2,
                                decoration: BoxDecoration(
                                  color: i == days.length - 1
                                      ? _red
                                      : _red.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  i == days.length - 1
                                      ? 'Auj.'
                                      : DateFormat('E', 'fr')
                                          .format(DateTime.parse(
                                              '${days[i]['day']}'))
                                          .substring(0, 3),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: theme.secondaryText)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Produits les plus vendus',
                  style: GoogleFonts.interTight(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
              const SizedBox(height: 8),
              if (top.isEmpty)
                Text('Ils apparaîtront après vos premières ventes livrées.',
                    style: GoogleFonts.inter(color: theme.secondaryText)),
              for (var i = 0; i < top.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _red.withValues(alpha: 0.1),
                    child: Text('${i + 1}',
                        style: GoogleFonts.inter(
                            color: _red, fontWeight: FontWeight.w800)),
                  ),
                  title: Text('${top[i]['name']}',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText)),
                  trailing: Text('${top[i]['quantity']} vendus',
                      style: GoogleFonts.inter(color: theme.secondaryText)),
                ),
              const SizedBox(height: 10),
              Text(
                  'Ventes livrées = montant des articles (sans les frais de '
                  'livraison). Revenus = montant net crédité après commission.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: theme.secondaryText)),
            ],
          );
        },
      ),
    );
  }
}

// ── Avis ─────────────────────────────────────────────────────────────────

class SellerReviewsPage extends StatefulWidget {
  const SellerReviewsPage({super.key});

  @override
  State<SellerReviewsPage> createState() => _SellerReviewsState();
}

class _SellerReviewsState extends State<SellerReviewsPage> {
  late Future<Map<String, dynamic>> _data =
      sellerCall('kitungaSellerReviews', const {});

  void _reload() => setState(() {
        _data = sellerCall('kitungaSellerReviews', const {});
      });

  Future<void> _report(Map<String, dynamic> r) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Signaler cet avis'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Pourquoi cet avis est-il abusif ?',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Signaler au support')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await sellerCall('kitungaSellerReportReview',
          {'orderId': r['orderId'], 'reason': c.text.trim()});
      if (mounted) _snack(context, 'Avis signalé : le support l\'examine.');
      _reload();
    } on ServerPaymentException catch (e) {
      if (mounted) _snack(context, e.message);
    } catch (_) {
      if (mounted) _snack(context, 'Connexion impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: _bar(context, 'Avis des clients'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return _loader(snap, _reload);
          final d = snap.data!;
          final list = (d['reviews'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_red, _redDark]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFC21A), size: 40),
                    const SizedBox(width: 12),
                    Text(
                        d['rating'] == null
                            ? 'Pas encore d\'avis'
                            : '${d['rating']} / 5 · ${d['count']} avis',
                        style: GoogleFonts.interTight(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                Text('Les avis apparaissent après les livraisons.',
                    style: GoogleFonts.inter(color: theme.secondaryText)),
              for (final r in list)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.alternate),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                                i <= (r['stars'] as num)
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: const Color(0xFFFFC21A),
                                size: 18),
                          const Spacer(),
                          Text('N° ${r['reference']}',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: theme.secondaryText)),
                        ],
                      ),
                      if ('${r['comment']}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${r['comment']}',
                              style:
                                  GoogleFonts.inter(color: theme.primaryText)),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: r['reported'] == true
                            ? Text('Signalé au support',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _orange))
                            : TextButton(
                                onPressed: () => _report(r),
                                child: const Text('Signaler')),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Stock ────────────────────────────────────────────────────────────────

/// Stocks bas, ajustement (entrée, sortie, inventaire), historique.
class SellerStockPage extends StatefulWidget {
  const SellerStockPage({super.key});

  @override
  State<SellerStockPage> createState() => _SellerStockState();
}

class _SellerStockState extends State<SellerStockPage> {
  late Future<List<Map<String, dynamic>>> _data = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await Future.wait([
      sellerCall('kitungaSellerPerformance', const {}),
      sellerCall('kitungaSellerStockMovements', const {}),
    ]);
    return r;
  }

  void _reload() => setState(() {
        _data = _load();
      });

  Future<void> _adjust(Map<String, dynamic> p) async {
    var kind = 'in';
    final qty = TextEditingController();
    final reason = TextEditingController();
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
              Text('${p['name']} · stock ${p['quantity']}',
                  style: GoogleFonts.interTight(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'in', label: Text('Entrée')),
                  ButtonSegment(value: 'out', label: Text('Sortie')),
                  ButtonSegment(value: 'count', label: Text('Inventaire')),
                ],
                selected: {kind},
                onSelectionChanged: (v) => set(() => kind = v.first),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('stock-qty'),
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: kind == 'count'
                        ? 'Quantité comptée'
                        : 'Quantité'),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                    labelText: 'Motif (facultatif)',
                    hintText: 'Livraison fournisseur, casse…'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const ValueKey('stock-save'),
                style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _red,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    try {
      final r = await sellerCall('kitungaSellerAdjustStock', {
        'productId': p['id'],
        'kind': kind,
        'quantity': int.tryParse(qty.text.trim()) ?? -1,
        'reason': reason.text.trim(),
      });
      if (mounted) _snack(context, 'Stock : ${r['before']} → ${r['after']}.');
      _reload();
    } on ServerPaymentException catch (e) {
      if (mounted) _snack(context, e.message);
    } catch (_) {
      if (mounted) _snack(context, 'Connexion impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    const kinds = {
      'in': ('Entrée', Icons.add_circle_outline_rounded, _green),
      'out': ('Sortie', Icons.remove_circle_outline_rounded, _orange),
      'count': ('Inventaire', Icons.fact_check_outlined, Color(0xFF2563EB)),
      'sale': ('Vente', Icons.shopping_bag_outlined, _red),
    };
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: _bar(context, 'Stock'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return _loader(snap, _reload);
          final low = (snap.data![0]['lowStock'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final moves = (snap.data![1]['movements'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Stocks bas et ruptures',
                  style: GoogleFonts.interTight(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
              const SizedBox(height: 8),
              if (low.isEmpty)
                Text('Aucun produit en stock bas. Bravo !',
                    style: GoogleFonts.inter(color: theme.secondaryText)),
              for (final p in low)
                Card(
                  elevation: 0,
                  color: theme.secondaryBackground,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.alternate)),
                  child: ListTile(
                    leading: Icon(
                        (p['quantity'] as num) <= 0
                            ? Icons.remove_shopping_cart_rounded
                            : Icons.inventory_2_outlined,
                        color: (p['quantity'] as num) <= 0 ? _red : _orange),
                    title: Text('${p['name']}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    subtitle: Text((p['quantity'] as num) <= 0
                        ? 'En rupture'
                        : 'Reste ${p['quantity']}'),
                    trailing: TextButton(
                      key: ValueKey('stock-${p['id']}'),
                      onPressed: () => _adjust(p),
                      child: const Text('Ajuster'),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text('Historique des mouvements',
                  style: GoogleFonts.interTight(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
              const SizedBox(height: 8),
              if (moves.isEmpty)
                Text('Aucun mouvement pour l\'instant.',
                    style: GoogleFonts.inter(color: theme.secondaryText)),
              for (final m in moves.take(50))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(kinds[m['kind']]?.$2 ?? Icons.swap_vert,
                      color: kinds[m['kind']]?.$3),
                  title: Text(
                      '${m['product']} · ${kinds[m['kind']]?.$1 ?? m['kind']} '
                      '${m['quantity']}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${m['before']} → ${m['after']}'
                      '${'${m['reason']}'.isEmpty ? '' : ' · ${m['reason']}'}'),
                  trailing: Text(
                      m['at'] == null
                          ? ''
                          : DateFormat('d/M HH:mm')
                              .format(DateTime.parse('${m['at']}').toLocal()),
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: theme.secondaryText)),
                ),
            ],
          );
        },
      ),
    );
  }
}
