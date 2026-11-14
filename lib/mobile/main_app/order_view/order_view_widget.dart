import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/components/order_progress/order_progress_widget.dart';
import '/mobile/components/product_card/product_card_widget.dart'
    show kitungaPrice;
import '/mobile/components/kitunga_contact.dart' show kCompanyPhones;
import '/mobile/components/support/kitunga_support.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
export 'order_view_model.dart';

const _red = Color(0xFFE51A1A);

/// Détail d'une commande (client) : progression, récapitulatif, adresse,
/// articles et montants, preuve de livraison, aide.
class OrderViewWidget extends StatefulWidget {
  const OrderViewWidget({
    super.key,
    this.orderRef,
    this.order,
  });

  /// Référence unique (order_unique_reference) : relie les articles.
  final String? orderRef;
  final DocumentReference? order;

  static String routeName = 'Order_View';
  static String routePath = '/orderView';

  @override
  State<OrderViewWidget> createState() => _OrderViewWidgetState();
}

class _OrderViewWidgetState extends State<OrderViewWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
      appBar: kitungaPageBar(context, 'Ma commande'),
      body: StreamBuilder<OrdersRecord>(
        stream: OrdersRecord.getDocument(widget.order!),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _red));
          }
          final o = snap.data!;
          final reference = (widget.orderRef ?? '').isNotEmpty
              ? widget.orderRef!
              : o.orderUniqueReference;
          final live = OrderStatus.inProgress.contains(o.status) &&
              o.status != OrderStatus.pending;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              KitungaOrderProgress(
                order: o,
                canCancel: o.userRef == currentUserReference,
              ),
              if (live) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => context.pushNamed(
                      OrderTrackWidget.routeName,
                      queryParameters: {
                        'orderRef': serializeParam(
                            o.reference, ParamType.DocumentReference),
                      }.withoutNulls,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.location_on_rounded, size: 20),
                    label: Text('Suivre la livraison',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _Section(
                title: 'Récapitulatif',
                child: Column(children: [
                  _InfoRow(
                      label: 'Commande',
                      value: o.orderId.isNotEmpty ? o.orderId : reference),
                  if (o.createdAt != null)
                    _InfoRow(
                        label: 'Passée le',
                        value: dateTimeFormat('d MMMM y à HH:mm', o.createdAt,
                            locale: 'fr')),
                  if (o.sellerRef != null) _ShopRow(shopRef: o.sellerRef!),
                  _InfoRow(
                    label: 'Statut',
                    trailing: _StatusChip(status: o.status),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Livraison',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          color: _red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              o.deliveryZone.isNotEmpty
                                  ? o.deliveryZone
                                  : 'Quartier non précisé',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryText)),
                          if (o.deliveryLocation.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(o.deliveryLocation.trim(),
                                  style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: theme.secondaryText)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Articles',
                child: _Items(reference: reference, order: o),
              ),
              if (o.deliveryPhoto.isNotEmpty || o.userSignature.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Section(
                  title: 'Preuve de livraison',
                  child: Row(children: [
                    if (o.deliveryPhoto.isNotEmpty)
                      Expanded(
                          child: _Proof(
                              label: 'Photo du colis', url: o.deliveryPhoto)),
                    if (o.deliveryPhoto.isNotEmpty &&
                        o.userSignature.isNotEmpty)
                      const SizedBox(width: 12),
                    if (o.userSignature.isNotEmpty)
                      Expanded(
                          child: _Proof(
                              label: 'Signature', url: o.userSignature)),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              _HelpTile(order: o, reference: reference),
            ],
          );
        },
      ),
    );
  }
}

/// Barre de titre des pages : retour rond et titre en gras.
PreferredSizeWidget kitungaPageBar(BuildContext context, String title) {
  final theme = FlutterFlowTheme.of(context);
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    automaticallyImplyLeading: false,
    titleSpacing: 4,
    leading: Navigator.of(context).canPop()
        ? IconButton(
            tooltip: 'Retour',
            onPressed: () => context.safePop(),
            icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
          )
        : null,
    title: Text(title,
        style: GoogleFonts.interTight(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: theme.primaryText)),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.interTight(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 14, color: theme.secondaryText)),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: trailing ??
                Text(value ?? '',
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryText)),
          ),
        ),
      ]),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.shopRef});

  final DocumentReference shopRef;

  @override
  Widget build(BuildContext context) => FutureBuilder<UserRecord>(
        future: UserRecord.getDocumentOnce(shopRef),
        builder: (context, s) => _InfoRow(
            label: 'Commerce',
            value: s.data?.displayName.isNotEmpty == true
                ? s.data!.displayName
                : '…'),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = OrderStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(OrderStatus.label(status),
          style: GoogleFonts.inter(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Articles de la commande, puis sous-total, livraison et total payé.
class _Items extends StatelessWidget {
  const _Items({required this.reference, required this.order});

  final String reference;
  final OrdersRecord order;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<List<OrderItemsRecord>>(
      stream: queryOrderItemsRecord(
        queryBuilder: (q) => q.where('order_ref', isEqualTo: reference),
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(color: _red)),
          );
        }
        final items = snap.data!;
        final subtotal = items.fold<double>(
            0, (s, i) => s + i.priceAtPurchase * (i.quantity <= 0 ? 1 : i.quantity));
        final fees = order.deliveryFees;
        final total = order.totalAmount > 0 ? order.totalAmount : subtotal + fees;
        return Column(
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Le détail des articles n\'est pas disponible.',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: theme.secondaryText)),
              ),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 54,
                      height: 54,
                      color: theme.primaryBackground,
                      child: KitungaImage(i.image,
                          width: 54,
                          height: 54,
                          fallbackIcon: Icons.fastfood_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText)),
                        if (i.options.isNotEmpty)
                          Text(i.options,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: theme.secondaryText)),
                        Text(
                            '${i.quantity <= 0 ? 1 : i.quantity} × '
                            '${kitungaPrice(i.priceAtPurchase)}',
                            style: GoogleFonts.inter(
                                fontSize: 12.5, color: theme.secondaryText)),
                      ],
                    ),
                  ),
                  Text(
                      kitungaPrice(i.priceAtPurchase *
                          (i.quantity <= 0 ? 1 : i.quantity)),
                      style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText)),
                ]),
              ),
            Divider(color: theme.alternate, height: 20),
            if (items.isNotEmpty) _Amount(label: 'Sous-total', value: subtotal),
            _Amount(label: 'Livraison', value: fees),
            const SizedBox(height: 4),
            _Amount(label: 'Total payé', value: total, strong: true),
          ],
        );
      },
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount(
      {required this.label, required this.value, this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final style = GoogleFonts.inter(
        fontSize: strong ? 17 : 14,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
        color: strong ? theme.primaryText : theme.secondaryText);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: style),
        const Spacer(),
        Text(kitungaPrice(value),
            style: style.copyWith(
                color: theme.primaryText,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700)),
      ]),
    );
  }
}

class _Proof extends StatelessWidget {
  const _Proof({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 130,
            width: double.infinity,
            color: theme.primaryBackground,
            child: KitungaImage(url,
                width: double.infinity,
                height: 130,
                fallbackIcon: Icons.image_outlined),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 12.5, color: theme.secondaryText)),
      ],
    );
  }
}

/// « Un problème avec cette commande ? » : demande au support liée à la
/// commande (suivie dans « Mes demandes au support »).
class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.order, required this.reference});

  final OrdersRecord order;
  final String reference;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openNewTicket(context,
            orderId: order.reference.id, orderRef: reference),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.alternate),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2F6FDE).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: Color(0xFF2F6FDE)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Un problème avec cette commande ?',
                      style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryText)),
                  Text('Écrivez au support Kitunga, réponse dans l\'app.',
                      style: GoogleFonts.inter(
                          fontSize: 12.5, color: theme.secondaryText)),
                ],
              ),
            ),
            // Comme avant : contact direct de l'équipe Kitunga sur WhatsApp.
            IconButton(
              tooltip: 'WhatsApp Kitunga',
              onPressed: () => launchURL('https://wa.me/242${kCompanyPhones.first}'
                  '?text=${Uri.encodeComponent('Bonjour Kitunga, au sujet de la commande ${reference} : ')}'),
              icon: const Icon(Icons.chat_rounded, color: Color(0xFF1E9E5A)),
            ),
          ]),
        ),
      ),
    );
  }
}
