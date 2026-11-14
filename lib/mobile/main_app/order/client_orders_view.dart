import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

const _red = Color(0xFFE51A1A);

/// Commandes du client : onglets « En cours » / « Terminées », les plus
/// récentes d'abord, carte lisible (commerce, date, montant, statut).
class ClientOrdersView extends StatefulWidget {
  const ClientOrdersView(
      {super.key, required this.orders, required this.onShop});

  final List<OrdersRecord> orders;

  /// « Découvrir les boutiques » (liste vide).
  final VoidCallback onShop;

  @override
  State<ClientOrdersView> createState() => _ClientOrdersViewState();
}

class _ClientOrdersViewState extends State<ClientOrdersView> {
  bool _finished = false;
  bool _chosen = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final all = [...widget.orders]..sort((a, b) =>
        (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
    final current =
        all.where((o) => OrderStatus.inProgress.contains(o.status)).toList();
    final past =
        all.where((o) => !OrderStatus.inProgress.contains(o.status)).toList();
    // Sans choix du client : « Terminées » s'il n'a rien en cours.
    final finished = _chosen ? _finished : current.isEmpty && past.isNotEmpty;
    final shown = finished ? past : current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mes commandes',
                  style: GoogleFonts.interTight(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText)),
              const SizedBox(height: 2),
              Text('Suivez vos commandes en temps réel.',
                  style: GoogleFonts.inter(
                      fontSize: 13.5, color: theme.secondaryText)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            _Tab(
                label: 'En cours',
                count: current.length,
                selected: !finished,
                onTap: () => setState(() {
                      _chosen = true;
                      _finished = false;
                    })),
            const SizedBox(width: 10),
            _Tab(
                label: 'Terminées',
                count: past.length,
                selected: finished,
                onTap: () => setState(() {
                      _chosen = true;
                      _finished = true;
                    })),
          ]),
        ),
        Expanded(
          child: shown.isEmpty
              ? _Empty(
                  finished: finished,
                  hasAny: all.isNotEmpty,
                  onShop: widget.onShop)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _OrderCard(order: shown[i]),
                ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(
      {required this.label,
      required this.count,
      required this.selected,
      required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _red : theme.secondaryBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? _red : theme.alternate),
        ),
        child: Text(count > 0 ? '$label ($count)' : label,
            style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : theme.primaryText)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.finished, required this.hasAny, required this.onShop});

  final bool finished;
  final bool hasAny;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = !hasAny
        ? 'Aucune commande pour le moment'
        : finished
            ? 'Aucune commande terminée'
            : 'Aucune commande en cours';
    final text = !hasAny
        ? 'Ajoutez des produits à votre panier et validez votre commande : '
            'vous pourrez la suivre ici.'
        : finished
            ? 'Vos commandes livrées ou annulées apparaîtront ici.'
            : 'Vos prochaines commandes apparaîtront ici, avec leur suivi.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      children: [
        if (!hasAny)
          Image.asset('assets/images/app/emptycart.png',
              height: 150, fit: BoxFit.contain)
        else
          Icon(
              finished
                  ? Icons.inventory_2_outlined
                  : Icons.delivery_dining_outlined,
              size: 64,
              color: theme.secondaryText.withValues(alpha: 0.5)),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: GoogleFonts.interTight(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: theme.primaryText)),
        const SizedBox(height: 8),
        Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14, height: 1.4, color: theme.secondaryText)),
        const SizedBox(height: 22),
        Center(
          child: FilledButton.icon(
            onPressed: onShop,
            style: FilledButton.styleFrom(
                backgroundColor: _red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26))),
            icon: const Icon(Icons.storefront_rounded, size: 20),
            label: Text('Découvrir les boutiques',
                style: GoogleFonts.inter(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Nom des commerces déjà lus (évite de relire à chaque reconstruction).
final Map<String, Future<String>> _shopNames = {};

Future<String> _shopName(DocumentReference? ref) {
  if (ref == null) return Future.value('');
  return _shopNames[ref.path] ??= UserRecord.getDocumentOnce(ref)
      .then((u) => u.displayName)
      .catchError((_) => '');
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrdersRecord order;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = OrderStatus.color(order.status);
    final live = OrderStatus.inProgress.contains(order.status);
    final count = order.itemsCount;
    final amount = order.totalAmount % 1 == 0
        ? order.totalAmount.toInt().toString()
        : order.totalAmount.toStringAsFixed(0);
    return Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.pushNamed(
          OrderViewWidget.routeName,
          queryParameters: {
            'orderRef':
                serializeParam(order.orderUniqueReference, ParamType.String),
            'order':
                serializeParam(order.reference, ParamType.DocumentReference),
          }.withoutNulls,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.alternate),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.storefront_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _shopName(order.sellerRef),
                        builder: (context, s) => Text(
                          (s.data ?? '').isNotEmpty ? s.data! : 'Commande',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryText),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (order.orderId.isNotEmpty) order.orderId,
                          if (order.createdAt != null)
                            dateTimeFormat('d MMM y · HH:mm', order.createdAt,
                                locale: 'fr'),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: theme.secondaryText),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.secondaryText),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(OrderStatus.label(order.status),
                        style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ]),
                ),
                const Spacer(),
                if (count > 0)
                  Text('$count article${count > 1 ? 's' : ''} · ',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: theme.secondaryText)),
                Text('$amount F',
                    style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText)),
              ]),
              if (live) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed(
                      OrderTrackWidget.routeName,
                      queryParameters: {
                        'orderRef': serializeParam(
                            order.reference, ParamType.DocumentReference),
                      }.withoutNulls,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _red),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.location_on_rounded, size: 18),
                    label: Text('Suivre la commande',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
