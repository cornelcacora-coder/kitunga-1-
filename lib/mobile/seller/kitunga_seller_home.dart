import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/kitunga_notifications.dart' show KitungaNotificationBell;
import '/backend/order_status.dart';
import '/backend/server_payment.dart' show ServerPaymentException;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart' show OrderWidget;
import '/mobile/components/finance/kitunga_earnings.dart'
    show openKitungaEarnings;
import '/mobile/components/kitunga_contact.dart' show kCompanyPhones;
import '/mobile/components/messaging/kitunga_messages.dart'
    show openOrderChat;
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart'
    show openKitungaShop;
import '/mobile/components/support/kitunga_support.dart'
    show openKitungaSupport;
import 'kitunga_seller_actions.dart';
import 'kitunga_seller_pro.dart';
import 'seller_dashboard.dart'
    show
        SellerCatalogPage,
        SellerProfilePage,
        SellerSectionsPage,
        openNewProductForm;
import 'seller_promotions.dart' show SellerPromotionsPage;
import '/mobile/components/prescription/kitunga_prescription.dart'
    show SellerPrescriptionsPage;
import 'seller_shared.dart' show sellerSectionsTitle;

/// Accueil du vendeur : centre de pilotage du commerce.
///
/// En-tête (état Ouvert / En pause / Fermé, mode sombre, notifications),
/// chiffres du jour, alertes, commandes à traiter (accepter / refuser),
/// en préparation (prête), livreur (remise), raccourcis, assistance.

/// Remplacent les données dans les tests.
@visibleForTesting
Stream<UserRecord>? sellerShopOverride;
@visibleForTesting
Stream<List<OrdersRecord>>? sellerOrdersOverride;
@visibleForTesting
Stream<List<ProductRecord>>? sellerProductsOverride;

const _red = Color(0xFFE51A1A);
const _redDark = Color(0xFFB0101A);
const _yellow = Color(0xFFFFC21A);
const _orange = Color(0xFFFF8A00);
const _green = Color(0xFF17A35B);
const _blue = Color(0xFF2563EB);

String _fcfa(num v) => '${NumberFormat.decimalPattern('fr').format(v)} F';

/// « à l'instant », « il y a 12 min », « il y a 2 h ».
String _ago(DateTime at) {
  final m = DateTime.now().difference(at).inMinutes;
  if (m < 1) return 'à l\'instant';
  if (m < 60) return 'il y a $m min';
  return 'il y a ${m ~/ 60} h';
}
bool _today(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;
num _items(OrdersRecord o) =>
    (o.totalAmount - o.deliveryFees).clamp(0, double.infinity);

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

class KitungaSellerHome extends StatefulWidget {
  const KitungaSellerHome({super.key});

  @override
  State<KitungaSellerHome> createState() => _KitungaSellerHomeState();
}

class _KitungaSellerHomeState extends State<KitungaSellerHome> {
  late final Stream<UserRecord> _shop = sellerShopOverride ??
      UserRecord.getDocument(currentUserReference!);
  late final Stream<List<OrdersRecord>> _orders = sellerOrdersOverride ??
      queryOrdersRecord(
          queryBuilder: (q) =>
              q.where('seller_ref', isEqualTo: currentUserReference));
  late final Stream<List<ProductRecord>> _products = sellerProductsOverride ??
      queryProductRecord(
          queryBuilder: (q) =>
              q.where('seller_ref', isEqualTo: currentUserReference));
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Comptes à rebours de préparation.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ColoredBox(
      color: theme.primaryBackground,
      child: StreamBuilder<UserRecord>(
        stream: _shop,
        builder: (context, shopSnap) {
          final shop = shopSnap.data;
          if (shop == null) {
            return const Center(
                child: CircularProgressIndicator(color: _red));
          }
          return StreamBuilder<List<OrdersRecord>>(
            stream: _orders,
            builder: (context, orderSnap) => StreamBuilder<List<ProductRecord>>(
              stream: _products,
              builder: (context, productSnap) => _Body(
                shop: shop,
                orders: orderSnap.data,
                products: productSnap.data,
                offline: orderSnap.hasError,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.shop,
    required this.orders,
    required this.products,
    required this.offline,
  });

  final UserRecord shop;
  final List<OrdersRecord>? orders;
  final List<ProductRecord>? products;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final all = [...?orders]..sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final pending = all
        .where((o) => o.status == OrderStatus.pending || o.status.isEmpty)
        .toList();
    final preparing =
        all.where((o) => o.status == OrderStatus.preparing).toList();
    final pickup = all
        .where((o) =>
            o.status == OrderStatus.ready ||
            (o.status == OrderStatus.delivering &&
                o.snapshotData['picked_up_at'] == null))
        .toList();
    final late = preparing
        .where((o) => (prepMinutesLeft(o, now) ?? 1) < 0)
        .length;
    final deliveredToday = all.where((o) =>
        OrderStatus.successful.contains(o.status) &&
        _today(o.createdAt, now));
    final salesToday =
        deliveredToday.fold<num>(0, (s, o) => s + _items(o));
    final published =
        (products ?? const <ProductRecord>[]).where((p) => p.onSale).toList();
    final out = published.where((p) => p.quantity <= 0).length;
    final low =
        published.where((p) => p.quantity > 0 && p.quantity <= 5).length;
    final loading = orders == null;

    return RefreshIndicator(
      color: _red,
      onRefresh: () async =>
          Future<void>.delayed(const Duration(milliseconds: 400)),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Header(
            shop: shop,
            salesToday: salesToday,
            toHandle: pending.length,
          ),
          if (offline)
            const _Banner(
                icon: Icons.wifi_off_rounded,
                color: _orange,
                text: 'Connexion perdue : les commandes s\'afficheront dès le '
                    'retour du réseau.'),
          if (shop.snapshotData['account_status'] == 'suspended')
            _Banner(
              icon: Icons.block_rounded,
              color: _red,
              text: 'Commerce suspendu : il n\'apparaît plus aux clients. '
                  'Contactez le support.',
              action: 'Support',
              onTap: () => openKitungaSupport(context),
            )
          else if (!shop.verified)
            _Banner(
              icon: Icons.hourglass_top_rounded,
              color: _orange,
              text: 'Commerce pas encore vérifié : complétez logo, couverture '
                  'et horaires pour accélérer la vérification.',
              action: 'Mon commerce',
              onTap: () => _push(context, SellerProfilePage(shop: shop)),
            ),
          // Alertes intelligentes.
          if (late > 0 || out > 0 || low > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (late > 0)
                    _Alert(
                        Icons.timer_off_rounded,
                        '$late en retard',
                        _red,
                        () => context.pushNamed(OrderWidget.routeName)),
                  if (out > 0)
                    _Alert(Icons.remove_shopping_cart_rounded,
                        '$out en rupture', _red,
                        () => _push(context, const SellerStockPage())),
                  if (low > 0)
                    _Alert(Icons.inventory_2_outlined, '$low stock bas',
                        _orange,
                        () => _push(context, const SellerStockPage())),
                ],
              ),
            ),
          _Title('À traiter maintenant',
              count: pending.isEmpty ? null : pending.length),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: _red)),
            )
          else if (pending.isEmpty)
            const _Empty(
                icon: Icons.inbox_rounded,
                title: 'Aucune nouvelle commande',
                text: 'Vous serez prévenu dès qu\'un client commande.')
          else
            for (final o in pending) _OrderCard(order: o, kind: 'pending'),
          if (preparing.isNotEmpty) ...[
            _Title('En préparation', count: preparing.length),
            for (final o in preparing) _OrderCard(order: o, kind: 'preparing'),
          ],
          if (pickup.isNotEmpty) ...[
            _Title('Livreur et collecte', count: pickup.length),
            for (final o in pickup) _OrderCard(order: o, kind: 'pickup'),
          ],
          const _Title('Gérer mon commerce'),
          _Shortcuts(shop: shop),
          const _Help(),
        ],
      ),
    );
  }
}

// ── En-tête ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header(
      {required this.shop, required this.salesToday, required this.toHandle});

  final UserRecord shop;
  final num salesToday;
  final int toHandle;

  Widget _round(BuildContext context,
      {required Key key,
      required String tooltip,
      required IconData icon,
      Color? iconColor,
      required VoidCallback onTap}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1E242B) : Colors.white,
      shape: const CircleBorder(),
      child: IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon,
            color: iconColor ?? (dark ? Colors.white : const Color(0xFF1E242B)),
            size: 21),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = (shop.snapshotData['shop_rating_count'] as num?) ?? 0;
    final rating = count > 0
        ? ((shop.snapshotData['shop_rating_sum'] as num? ?? 0) / count)
        : null;
    return Stack(
      children: [
        Container(
          height: top + 248,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [_red, _redDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _round(context,
                      key: const ValueKey('seller-menu'),
                      tooltip: 'Menu',
                      icon: Icons.menu_rounded,
                      onTap: () => Scaffold.maybeOf(context)?.openDrawer()),
                  const SizedBox(width: 10),
                  _ShopStatePill(shop: shop),
                  const Spacer(),
                  _round(context,
                      key: const ValueKey('seller-theme'),
                      tooltip: dark ? 'Mode clair' : 'Mode sombre',
                      iconColor: dark ? const Color(0xFFFFD200) : null,
                      icon: dark
                          ? Icons.light_mode_rounded
                          : Icons.nightlight_round,
                      onTap: () => setDarkModeSetting(
                          context, dark ? ThemeMode.light : ThemeMode.dark)),
                  const SizedBox(width: 10),
                  const KitungaNotificationBell(size: 44),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: shop.photoUrl.isNotEmpty
                          ? Image.network(shop.photoUrl,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              webHtmlElementStrategy:
                                  WebHtmlElementStrategy.fallback,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 54,
                                  height: 54,
                                  child: Icon(Icons.storefront_rounded,
                                      color: _red)))
                          : const SizedBox(
                              width: 54,
                              height: 54,
                              child:
                                  Icon(Icons.storefront_rounded, color: _red)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            shop.displayName.isEmpty
                                ? 'Mon commerce'
                                : shop.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.interTight(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                                shop.verified
                                    ? Icons.verified_rounded
                                    : Icons.hourglass_top_rounded,
                                size: 14,
                                color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                  [
                                    if (shop.category.isNotEmpty)
                                      shop.category,
                                    shop.verified ? 'Vérifié' : 'À vérifier',
                                    if (rating != null)
                                      '★ ${rating.toStringAsFixed(1)} ($count)',
                                  ].join('  ·  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      color: Colors.white
                                          .withValues(alpha: 0.92),
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Card(
                        title: 'Ventes du jour',
                        value: _fcfa(salesToday),
                        icon: Icons.payments_rounded,
                        colors: const [Color(0xFF2A2F3A), Color(0xFF151922)],
                        link: 'Mes revenus',
                        onTap: () => openKitungaEarnings(context, seller: true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Card(
                        title: 'À traiter',
                        value: '$toHandle',
                        icon: Icons.receipt_long_rounded,
                        colors: const [_yellow, _orange],
                        link: 'Commandes',
                        onTap: () => context.pushNamed(OrderWidget.routeName),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const kShopStates = {
  'open': ('Ouvert', Color(0xFF17A35B), Icons.storefront_rounded,
      'Les clients peuvent commander (selon vos horaires).'),
  'pause': ('En pause', Color(0xFFE08A00), Icons.coffee_rounded,
      'Pas de nouvelle commande pour le moment.'),
  'closed': ('Fermé', Color(0xFF8A94A6), Icons.door_front_door_outlined,
      'Fermé maintenant, même pendant vos horaires.'),
};

String shopStateOf(UserRecord shop) {
  final s = shop.snapshotData['shop_state'];
  if (s is String && kShopStates.containsKey(s)) return s;
  return shop.snapshotData['shop_closed_now'] == true ? 'closed' : 'open';
}

class _ShopStatePill extends StatelessWidget {
  const _ShopStatePill({required this.shop});

  final UserRecord shop;

  Future<void> _choose(BuildContext context, String current) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in kShopStates.entries)
              ListTile(
                key: ValueKey('shop-${e.key}'),
                leading: CircleAvatar(
                    backgroundColor: e.value.$2.withValues(alpha: 0.12),
                    child: Icon(e.value.$3, color: e.value.$2)),
                title: Text(e.value.$1,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                subtitle: Text(e.value.$4),
                trailing: current == e.key
                    ? const Icon(Icons.check_circle_rounded, color: _green)
                    : null,
                onTap: () => Navigator.pop(c, e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == current || !context.mounted) return;
    final m = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await sellerCall('kitungaSellerSetOpen', {'state': chosen});
      m.showSnackBar(SnackBar(
          content: Text('Commerce : ${kShopStates[chosen]!.$1}.')));
    } on ServerPaymentException catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      m.showSnackBar(
          const SnackBar(content: Text('Connexion impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = shopStateOf(shop);
    final s = kShopStates[state]!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        key: const ValueKey('shop-state-pill'),
        borderRadius: BorderRadius.circular(30),
        onTap: () => _choose(context, state),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: s.$2),
              const SizedBox(width: 6),
              Text(s.$1,
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E242B))),
              const Icon(Icons.expand_more_rounded,
                  size: 16, color: Color(0xFF1E242B)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
    required this.link,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(value,
                        style: GoogleFonts.interTight(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                  ),
                  const Spacer(),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text(link,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 18),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Commandes ────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.kind});

  final OrdersRecord order;

  /// pending, preparing ou pickup.
  final String kind;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final o = order;
    final left = prepMinutesLeft(o);
    final ref = o.orderUniqueReference.isNotEmpty
        ? o.orderUniqueReference
        : o.reference.id;
    final atShop = o.snapshotData['at_shop_at'] != null;
    final hasDeliverer = o.delivererRef.isNotEmpty;
    String sub;
    Color subColor = theme.secondaryText;
    if (kind == 'pending') {
      sub = o.createdAt == null
          ? 'Nouvelle commande'
          : 'Reçue ${_ago(o.createdAt!)}';
    } else if (kind == 'preparing') {
      if (left == null) {
        sub = 'En préparation';
      } else if (left >= 0) {
        sub = 'Prête dans environ $left min';
      } else {
        sub = 'En retard de ${-left} min';
        subColor = _red;
      }
    } else if (!hasDeliverer) {
      sub = 'Recherche d\'un livreur…';
    } else if (atShop) {
      sub = 'Le livreur est arrivé : remettez-lui la commande';
      subColor = _green;
    } else {
      sub = 'Livreur en route vers le commerce';
    }
    return Container(
      key: ValueKey('seller-order-${o.reference.id}'),
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: kind == 'pending'
                ? _red.withValues(alpha: 0.4)
                : theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('N° $ref',
                    style: GoogleFonts.interTight(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText)),
              ),
              Text(_fcfa(_items(o)),
                  style: GoogleFonts.interTight(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _green)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
              [
                sub,
                if (o.deliveryZone.isNotEmpty) 'vers ${o.deliveryZone}',
              ].join(' · '),
              style: GoogleFonts.inter(fontSize: 13, color: subColor)),
          const SizedBox(height: 12),
          if (kind == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('refuse-${o.reference.id}'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () => sellerRefuse(context, o),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: ValueKey('accept-${o.reference.id}'),
                    style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: _green,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () => sellerAccept(context, o, defaultMinutes:
                        (currentUserDocument?.snapshotData['prep_minutes']
                                as num?)
                            ?.toInt()),
                    child: Text('Accepter',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            )
          else if (kind == 'preparing')
            FilledButton.icon(
              key: ValueKey('ready-${o.reference.id}'),
              style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _red,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => sellerReady(context, o),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Commande prête'),
            )
          else
            Row(
              children: [
                if (hasDeliverer)
                  IconButton.outlined(
                    tooltip: 'Écrire au livreur',
                    onPressed: () =>
                        openOrderChat(context, o.reference.id, 'livreur'),
                    icon: const Icon(Icons.forum_rounded, color: _blue),
                  ),
                if (hasDeliverer) const SizedBox(width: 10),
                if (o.status == OrderStatus.delivering)
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey('handover-${o.reference.id}'),
                      style: FilledButton.styleFrom(foregroundColor: Colors.white,backgroundColor: _green),
                      onPressed: () => sellerHandover(context, o),
                      icon: const Icon(Icons.handshake_rounded),
                      label: const Text('Remise au livreur'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Raccourcis et éléments communs ───────────────────────────────────────

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.shop});

  final UserRecord shop;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final items = [
      (Icons.add_box_rounded, 'Ajouter', _red,
          () => openNewProductForm(context, shop)),
      (Icons.inventory_2_rounded, 'Catalogue', _blue,
          () => _push(context, SellerCatalogPage(shop: shop))),
      (Icons.warehouse_rounded, 'Stock', _orange,
          () => _push(context, const SellerStockPage())),
      (Icons.view_list_rounded, sellerSectionsTitle(shop.category),
          const Color(0xFF7C3AED),
          () => _push(context, SellerSectionsPage(shop: shop))),
      (Icons.insights_rounded, 'Performances', _green,
          () => _push(context, const SellerPerformancePage())),
      (Icons.star_rounded, 'Avis', const Color(0xFFE0A800),
          () => _push(context, const SellerReviewsPage())),
      (Icons.campaign_rounded, 'Promotions', _red,
          () => _push(context, SellerPromotionsPage(shop: shop))),
      (Icons.account_balance_wallet_rounded, 'Revenus', _green,
          () => openKitungaEarnings(context, seller: true)),
      (Icons.schedule_rounded, 'Horaires', _blue,
          () => _push(context, SellerProfilePage(shop: shop))),
      (Icons.visibility_rounded, 'Vitrine', const Color(0xFF14A3A3),
          () => openKitungaShop(context, shop)),
      if (shop.category == 'Pharmacie')
        (Icons.medical_information_rounded, 'Ordonnances', _red,
            () => _push(context, const SellerPrescriptionsPage())),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          for (final (icon, label, color, onTap) in items)
            Material(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: ValueKey('shortcut-$label'),
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryText)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, {this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
      child: Row(children: [
        Text(title,
            style: GoogleFonts.interTight(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.primaryText)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: _red, borderRadius: BorderRadius.circular(20)),
            child: Text('$count',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ]),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
        labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700, color: color, fontSize: 13),
        backgroundColor: color.withValues(alpha: 0.08),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        onPressed: onTap,
      );
}

class _Banner extends StatelessWidget {
  const _Banner(
      {required this.icon,
      required this.color,
      required this.text,
      this.action,
      this.onTap});

  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 13, color: theme.primaryText)),
        ),
        if (action != null)
          TextButton(onPressed: onTap, child: Text(action!)),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _red.withValues(alpha: 0.08),
          child: Icon(icon, color: _red),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: theme.primaryText)),
              const SizedBox(height: 2),
              Text(text,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: theme.secondaryText)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Help extends StatelessWidget {
  const _Help();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final n = kCompanyPhones.first;
    Widget action(IconData icon, String label, Color color, VoidCallback t) =>
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: t,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText)),
              ]),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.support_agent_rounded, color: _red, size: 26),
            const SizedBox(width: 10),
            Text('Besoin d\'aide ?',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, color: theme.primaryText)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            action(Icons.forum_rounded, 'Écrire', _blue,
                () => openKitungaSupport(context)),
            action(Icons.call_rounded, 'Appeler', _green,
                () => launchURL('tel:+242$n')),
            action(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366),
                () => launchURL('https://wa.me/242$n')),
          ]),
        ],
      ),
    );
  }
}

/// Onglet « Catalogue » du vendeur (charge la fiche de son commerce).
class KitungaSellerCatalogTab extends StatelessWidget {
  const KitungaSellerCatalogTab({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<UserRecord>(
        stream: sellerShopOverride ??
            UserRecord.getDocument(currentUserReference!),
        builder: (context, snap) => snap.data == null
            ? const Center(child: CircularProgressIndicator(color: _red))
            : SellerCatalogPage(shop: snap.data!),
      );
}


/// Rubrique « Mon commerce » du profil vendeur.
class SellerShopSection extends StatelessWidget {
  const SellerShopSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final shop = currentUserDocument;
    if (shop == null) return const SizedBox.shrink();
    final items = [
      (Icons.storefront_outlined, 'Horaires, quartier et profil',
          () => _push(context, SellerProfilePage(shop: shop))),
      (Icons.warehouse_outlined, 'Stock et mouvements',
          () => _push(context, const SellerStockPage())),
      (Icons.insights_rounded, 'Performances',
          () => _push(context, const SellerPerformancePage())),
      (Icons.star_outline_rounded, 'Avis des clients',
          () => _push(context, const SellerReviewsPage())),
      (Icons.account_balance_wallet_outlined, 'Revenus et retraits',
          () => openKitungaEarnings(context, seller: true)),
      (Icons.campaign_outlined, 'Promotions',
          () => _push(context, SellerPromotionsPage(shop: shop))),
      (Icons.visibility_outlined, 'Voir ma vitrine',
          () => openKitungaShop(context, shop)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Mon commerce',
                style: GoogleFonts.inter(
                    color: theme.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 60, color: theme.alternate),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(items[i].$1, color: _red, size: 21),
                  ),
                  title: Text(items[i].$2,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: theme.secondaryText),
                  onTap: items[i].$3,
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
