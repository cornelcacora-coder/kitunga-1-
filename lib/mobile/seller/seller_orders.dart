import '/mobile/components/returns/kitunga_returns.dart'
    show KitungaSellerReturnCard;
import '/mobile/components/prescription/kitunga_prescription.dart'
    show showPrescriptionPhotos;
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_status.dart';
import 'kitunga_seller_actions.dart';
import '/mobile/components/delivery/kitunga_delivery.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Commandes reçues par le vendeur : accepter, refuser, préparer.
class SellerOrdersView extends StatefulWidget {
  const SellerOrdersView({super.key});

  @override
  State<SellerOrdersView> createState() => _SellerOrdersViewState();
}

class _SellerOrdersViewState extends State<SellerOrdersView> {
  // Tri local : pas d'index composite nécessaire côté Firestore.
  late final Stream<List<OrdersRecord>> _orders = queryOrdersRecord(
    queryBuilder: (q) => q.where('seller_ref', isEqualTo: currentUserReference),
  );
  String _tab = 'new';

  static const _tabs = [
    (key: 'new', label: 'Nouvelles'),
    (key: 'preparing', label: 'En préparation'),
    (key: 'shipping', label: 'Prêtes / en livraison'),
    (key: 'done', label: 'Terminées'),
    (key: 'stopped', label: 'Refusées / annulées'),
  ];

  bool _inTab(String tab, String status) => switch (tab) {
        'new' => status == OrderStatus.pending || status.isEmpty,
        'preparing' => status == OrderStatus.preparing,
        'shipping' =>
          status == OrderStatus.ready || status == OrderStatus.delivering,
        'done' => status == OrderStatus.delivered ||
            status == OrderStatus.received ||
            status == OrderStatus.notReceived,
        _ => OrderStatus.isStopped(status),
      };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<List<OrdersRecord>>(
      stream: _orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Impossible de charger les commandes.',
                style: GoogleFonts.inter(color: theme.secondaryText)),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: theme.primary));
        }
        final all = [...snapshot.data!]..sort((a, b) =>
            (b.createdAt ?? DateTime(2000))
                .compareTo(a.createdAt ?? DateTime(2000)));
        final shown = all.where((o) => _inTab(_tab, o.status)).toList();

        return ListView(
          padding: EdgeInsets.only(bottom: 32.0),
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 8.0, 20.0, 4.0),
              child: Text(
                'Commandes reçues',
                style: GoogleFonts.interTight(
                  color: theme.primaryText,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 52.0,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 6.0),
                children: [
                  for (final t in _tabs)
                    Padding(
                      padding: EdgeInsetsDirectional.only(end: 8.0),
                      child: ChoiceChip(
                        label: Text(
                            '${t.label} (${all.where((o) => _inTab(t.key, o.status)).length})'),
                        selected: _tab == t.key,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _tab = t.key),
                        labelStyle: GoogleFonts.inter(
                          color:
                              _tab == t.key ? Colors.white : theme.primaryText,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: theme.primary,
                        backgroundColor: theme.primaryBackground,
                        side: BorderSide.none,
                        shape: StadiumBorder(),
                      ),
                    ),
                ],
              ),
            ),
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48.0, color: theme.secondaryText),
                    SizedBox(height: 10.0),
                    Text(
                      _tab == 'new'
                          ? 'Aucune nouvelle commande pour le moment.'
                          : 'Aucune commande dans cette catégorie.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: theme.secondaryText),
                    ),
                  ],
                ),
              )
            else
              for (final o in shown)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 6.0),
                  child: _SellerOrderCard(order: o),
                ),
          ],
        );
      },
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  const _SellerOrderCard({required this.order});

  final OrdersRecord order;

  String get _ref => order.orderUniqueReference.isNotEmpty
      ? order.orderUniqueReference
      : order.orderId;

  void _openDetail(BuildContext context) => context.pushNamed(
        OrderViewSellerDeliverWidget.routeName,
        queryParameters: {
          'orderRefer': serializeParam(_ref, ParamType.String),
          'deliveryZone': serializeParam(order.deliveryZone, ParamType.String),
          'statu': serializeParam(order.status, ParamType.String),
          'amount':
              serializeParam(order.totalAmount.toString(), ParamType.String),
        }.withoutNulls,
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final status = order.status.isEmpty ? OrderStatus.pending : order.status;
    final color = OrderStatus.color(status);

    return Container(
      padding: EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Commande $_ref',
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsetsDirectional.fromSTEB(10.0, 4.0, 10.0, 4.0),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  OrderStatus.label(status),
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.0),
          Text(
            [
              if (order.createdAt != null)
                dateTimeFormat('d/M à H:mm', order.createdAt),
              if (order.deliveryZone.isNotEmpty) order.deliveryZone,
              kitungaPrice(order.totalAmount),
            ].join(' · '),
            style:
                GoogleFonts.inter(color: theme.secondaryText, fontSize: 13.0),
          ),
          SizedBox(height: 10.0),
          // Articles commandés, avec les options choisies.
          StreamBuilder<List<OrderItemsRecord>>(
            stream: queryOrderItemsRecord(
              queryBuilder: (q) => q.where('order_ref', isEqualTo: _ref),
            ),
            builder: (context, snap) {
              final items = snap.data ?? [];
              if (items.isEmpty) return SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final it in items)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        [
                          '${it.quantity > 0 ? it.quantity : 1} × ${it.itemName.isNotEmpty ? it.itemName : 'Article'}',
                          if (it.options.isNotEmpty) it.options,
                        ].join(' · '),
                        style: GoogleFonts.inter(
                            color: theme.primaryText, fontSize: 13.5),
                      ),
                    ),
                ],
              );
            },
          ),
          if (status == OrderStatus.refused &&
              '${order.snapshotData['refusal_reason'] ?? ''}'.isNotEmpty)
            Text(
              'Motif : ${order.snapshotData['refusal_reason']}',
              style: GoogleFonts.inter(color: theme.error, fontSize: 13.0),
            ),
          // Retour ou échange demandé par le client.
          if (KitungaSellerReturnCard.showsFor(order))
            KitungaSellerReturnCard(order: order),
          // Commande sur ordonnance : la pharmacie revoit l'ordonnance.
          if ((order.snapshotData['prescription_photos'] as List?)
                  ?.isNotEmpty ==
              true)
            Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: OutlinedButton.icon(
                onPressed: () => showPrescriptionPhotos(context, [
                  for (final x
                      in order.snapshotData['prescription_photos'] as List)
                    '$x',
                ]),
                icon: Icon(Icons.medical_information_outlined, size: 18.0),
                label: Text('Commande sur ordonnance · voir l\'ordonnance'),
              ),
            ),
          SizedBox(height: 10.0),
          Row(
            children: [
              TextButton(
                onPressed: () => _openDetail(context),
                child: Text('Voir le détail',
                    style: GoogleFonts.inter(
                        color: theme.secondaryText,
                        fontWeight: FontWeight.w600)),
              ),
              Spacer(),
              // Commande livrée : reçu (même numéro que celui du client).
              if (KitungaReceiptButton.showsFor(order))
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          KitungaReceiptPage(orderId: order.reference.id))),
                  icon: Icon(Icons.receipt_long_rounded,
                      size: 18.0, color: theme.primary),
                  label: Text('Reçu',
                      style: GoogleFonts.inter(
                          color: theme.primary, fontWeight: FontWeight.w700)),
                ),
              if (status == OrderStatus.pending) ...[
                OutlinedButton(
                  // Refus vérifié par le serveur (motif, remboursement).
                  onPressed: () => sellerRefuse(context, order),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.error),
                    shape: StadiumBorder(),
                  ),
                  child: Text('Refuser',
                      style: GoogleFonts.inter(
                          color: theme.error, fontWeight: FontWeight.w700)),
                ),
                SizedBox(width: 8.0),
                FilledButton(
                  onPressed: () => sellerAccept(context, order),
                  style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: theme.primary, shape: StadiumBorder()),
                  child: Text('Accepter',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
              if (status == OrderStatus.preparing)
                FilledButton.icon(
                  onPressed: () => sellerReady(context, order),
                  style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: theme.primary, shape: StadiumBorder()),
                  icon: Icon(Icons.check_rounded),
                  label: Text('Marquer comme prête',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              if (status == OrderStatus.ready)
                Text('En attente d\'un livreur',
                    style: GoogleFonts.inter(
                        color: theme.secondaryText, fontSize: 12.5)),
              // Livreur venu chercher la commande : remise confirmée.
              if (status == OrderStatus.delivering &&
                  order.snapshotData['handover_confirmed_at'] == null)
                FilledButton.icon(
                  onPressed: () => sellerHandover(context, order),
                  style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF17A35B),
                      shape: StadiumBorder()),
                  icon: Icon(Icons.handshake_rounded),
                  label: Text('Remis au livreur',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
