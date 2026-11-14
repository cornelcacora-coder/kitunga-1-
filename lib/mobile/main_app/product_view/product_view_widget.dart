import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/cart_add/kitunga_add_to_cart.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'product_view_model.dart';
export 'product_view_model.dart';

const _red = Color(0xFFE51A1A);

/// Fiche d'un produit : grande photo, commerce, prix, disponibilité,
/// description, et barre d'ajout au panier (quantité + bouton) toujours
/// visible en bas.
class ProductViewWidget extends StatefulWidget {
  const ProductViewWidget({
    super.key,
    this.productRef,
    this.sellerRef,
    bool? isSameSeller,
  }) : this.isSameSeller = isSameSeller ?? false;

  final DocumentReference? productRef;
  final DocumentReference? sellerRef;
  final bool isSameSeller;

  static String routeName = 'ProductView';
  static String routePath = '/productView';

  @override
  State<ProductViewWidget> createState() => _ProductViewWidgetState();
}

class _ProductViewWidgetState extends State<ProductViewWidget> {
  int _quantity = 1;
  bool _busy = false;

  Future<void> _add(ProductRecord p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await kitungaAddToCart(context, p,
          quantity: _quantity, sellerRef: widget.sellerRef);
      if (r == null || !mounted) return;
      if (r.updated) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Quantité mise à jour dans votre panier.')));
      }
      // Comme avant : le panier s'ouvre après l'ajout.
      context.pushNamed(
        CartLastWidget.routeName,
        queryParameters: {
          'sellerRef': serializeParam(
              p.sellerRef ?? widget.sellerRef, ParamType.DocumentReference),
          if (!r.updated)
            'cartRef': serializeParam(r.cart, ParamType.Document),
          if (r.orderItem != null)
            'orderitem':
                serializeParam(r.orderItem, ParamType.DocumentReference),
        }.withoutNulls,
        extra: <String, dynamic>{if (!r.updated) 'cartRef': r.cart},
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101418) : Colors.white;
    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<ProductRecord>(
        stream: ProductRecord.getDocument(widget.productRef!),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _red));
          }
          final p = snap.data!;
          final top = MediaQuery.paddingOf(context).top;
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _Hero(product: p, top: top)),
                    SliverToBoxAdapter(child: _Details(product: p)),
                  ],
                ),
              ),
              AuthUserStreamWidget(
                builder: (context) =>
                    valueOrDefault(currentUserDocument?.role, '') == 'Seller'
                        ? const SizedBox.shrink()
                        : _AddBar(
                            product: p,
                            quantity: _quantity,
                            busy: _busy,
                            onQuantity: (q) => setState(() => _quantity = q),
                            onAdd: () => _add(p),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Grande photo, bouton retour par-dessus.
class _Hero extends StatelessWidget {
  const _Hero({required this.product, required this.top});

  final ProductRecord product;
  final double top;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final height = 300.0 + top;
    return Stack(
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Container(
            width: double.infinity,
            height: height,
            color: theme.primaryBackground,
            child: KitungaImage(
              product.prodImg,
              width: double.infinity,
              height: height,
              fallbackIcon: Icons.image_outlined,
              placeholder: kitungaNoPhoto(theme, product, height),
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: top + 10,
          child: _RoundButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Retour',
            onTap: () => context.safePop(),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: const Color(0x33000000),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: const Color(0xFF1A1A1A), size: 22),
            ),
          ),
        ),
      );
}

/// Commerce, nom, prix, disponibilité, description.
class _Details extends StatelessWidget {
  const _Details({required this.product});

  final ProductRecord product;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = product;
    final unit = p.salePrice > 0 ? p.salePrice : p.price.round();
    final outOfStock = p.quantity <= 0;
    final lowStock = p.quantity > 0 && p.quantity <= 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.sellerRef != null) _ShopLine(shopRef: p.sellerRef!),
          const SizedBox(height: 12),
          Text(p.name,
              style: GoogleFonts.interTight(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText)),
          const SizedBox(height: 8),
          Text(kitungaPrice(unit),
              style: GoogleFonts.interTight(
                  fontSize: 24, fontWeight: FontWeight.w800, color: _red)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (outOfStock)
              const _Chip(
                  icon: Icons.block_rounded,
                  label: 'Rupture de stock',
                  color: Color(0xFFE30613))
            else if (lowStock)
              _Chip(
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Plus que ${p.quantity} en stock',
                  color: const Color(0xFFE8710A))
            else
              const _Chip(
                  icon: Icons.check_circle_rounded,
                  label: 'Disponible',
                  color: Color(0xFF1E9E5A)),
            if (p.instantDisponibilty)
              const _Chip(
                  icon: Icons.bolt_rounded,
                  label: 'Livraison express',
                  color: _red),
            if (p.requiresPrescription)
              const _Chip(
                  icon: Icons.medical_information_rounded,
                  label: 'Sur ordonnance',
                  color: Color(0xFF2F6FDE)),
            if (p.specifications.trim().isNotEmpty)
              _Chip(
                  icon: Icons.sell_rounded,
                  label: p.specifications.trim(),
                  color: theme.secondaryText),
          ]),
          const SizedBox(height: 24),
          Text('Description',
              style: GoogleFonts.interTight(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText)),
          const SizedBox(height: 8),
          Text(
            p.description.trim().isNotEmpty
                ? p.description.trim()
                : 'Le commerce n\'a pas encore ajouté de description pour ce '
                    'produit.',
            style: GoogleFonts.inter(
                fontSize: 14.5,
                height: 1.5,
                fontStyle: p.description.trim().isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: theme.secondaryText),
          ),
          if (p.options.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.tune_rounded, size: 18, color: theme.secondaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Options et suppléments au choix lors de l\'ajout.',
                    style: GoogleFonts.inter(
                        fontSize: 13.5, color: theme.secondaryText)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// « Chez Mama Loboko » : logo et nom du commerce, ouvre sa page.
class _ShopLine extends StatelessWidget {
  const _ShopLine({required this.shopRef});

  final DocumentReference shopRef;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<UserRecord>(
      stream: UserRecord.getDocument(shopRef),
      builder: (context, snap) {
        final shop = snap.data;
        if (shop == null) return const SizedBox(height: 36);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openKitungaShop(context, shop),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              ClipOval(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: shop.photoUrl.isNotEmpty
                      ? KitungaImage(shop.photoUrl,
                          width: 34,
                          height: 34,
                          fallbackIcon: Icons.storefront_rounded,
                          placeholder: kitungaShopPlaceholder(context, shop,
                              width: 34, height: 34))
                      : kitungaShopPlaceholder(context, shop,
                          width: 34, height: 34),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(shop.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryText)),
              ),
              Text('Voir le commerce',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _red)),
              const Icon(Icons.chevron_right_rounded, color: _red, size: 20),
            ]),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ]),
      );
}

/// Barre du bas : quantité et « Ajouter · 4 000 F ».
class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.product,
    required this.quantity,
    required this.busy,
    required this.onQuantity,
    required this.onAdd,
  });

  final ProductRecord product;
  final int quantity;
  final bool busy;
  final ValueChanged<int> onQuantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = product;
    final outOfStock = p.quantity <= 0;
    final unit = p.salePrice > 0 ? p.salePrice : p.price.round();
    // Avec options : quantité et prix choisis dans la feuille d'options.
    final stepper = !outOfStock && p.options.isEmpty;
    final label = outOfStock
        ? 'Rupture de stock'
        : stepper
            ? 'Ajouter · ${kitungaPrice(unit * quantity)}'
            : 'Choisir et ajouter';
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            if (stepper) ...[
              Container(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.alternate),
                ),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Moins',
                    onPressed:
                        quantity > 1 ? () => onQuantity(quantity - 1) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Text('$quantity',
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryText)),
                  IconButton(
                    tooltip: 'Plus',
                    onPressed: quantity < p.quantity
                        ? () => onQuantity(quantity + 1)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: outOfStock || busy ? null : onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    disabledBackgroundColor: theme.alternate,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
