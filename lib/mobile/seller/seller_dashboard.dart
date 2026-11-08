import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/kitunga_cuisines.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/form_styles/form_styles.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import 'seller_product_form.dart';
import 'seller_shared.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Produits du vendeur connecté (brouillons compris).
Stream<List<ProductRecord>> _myProducts() => queryProductRecord(
      queryBuilder: (q) =>
          q.where('seller_ref', isEqualTo: currentUserReference),
    );

List<String> _sectionsOf(List<ProductRecord> products) => products
    .map((p) => p.section.trim())
    .where((s) => s.isNotEmpty)
    .toSet()
    .toList();

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// Ouvre le formulaire de création d'un produit.
Future<void> openNewProductForm(BuildContext context, UserRecord shop) async {
  final products = await _myProducts().first;
  if (!context.mounted) return;
  _push(
    context,
    SellerProductFormPage(shop: shop, existingSections: _sectionsOf(products)),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Tableau de bord
// ─────────────────────────────────────────────────────────────────────────

/// Accueil du vendeur : état du commerce, chiffres réels, actions rapides.
class SellerDashboardView extends StatefulWidget {
  const SellerDashboardView({super.key, required this.shop});

  final UserRecord shop;

  @override
  State<SellerDashboardView> createState() => _SellerDashboardViewState();
}

class _SellerDashboardViewState extends State<SellerDashboardView> {
  late final Stream<List<ProductRecord>> _products = _myProducts();
  late final Stream<List<OrdersRecord>> _orders = queryOrdersRecord(
    queryBuilder: (q) => q.where('seller_ref', isEqualTo: currentUserReference),
  );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final shop = widget.shop;
    return StreamBuilder<List<ProductRecord>>(
      stream: _products,
      builder: (context, productSnap) {
        final products = productSnap.data ?? [];
        final published = products.where(kitungaIsPublished).toList();
        final drafts = products.length - published.length;
        final outOfStock = published.where((p) => p.quantity <= 0).length;
        final lowStock =
            published.where((p) => p.quantity > 0 && p.quantity <= 5).toList();

        return ListView(
          padding: EdgeInsets.only(bottom: 32.0),
          children: [
            _shopHeader(theme, shop),
            if (!shop.verified)
              _notice(
                theme,
                Icons.hourglass_top_rounded,
                'Votre commerce n\'est pas encore certifié par l\'équipe Kitunga. Complétez votre profil (logo, couverture, horaires) pour accélérer la vérification.',
              ),
            _title(theme, 'Vue d\'ensemble'),
            StreamBuilder<List<OrdersRecord>>(
              stream: _orders,
              builder: (context, orderSnap) {
                final orders = orderSnap.data ?? [];
                final pending =
                    orders.where((o) => o.status == 'En attente').length;
                final delivered = orders
                    .where((o) => o.status == 'Livrer' || o.status == 'Reçu');
                final revenue = delivered.fold<double>(
                    0, (total, o) => total + o.totalAmount);
                return _statsGrid(theme, [
                  (
                    icon: Icons.storefront_outlined,
                    value: '${published.length}',
                    label: 'En vente',
                  ),
                  (
                    icon: Icons.edit_note_rounded,
                    value: '$drafts',
                    label: 'Brouillons',
                  ),
                  (
                    icon: Icons.remove_shopping_cart_outlined,
                    value: '$outOfStock',
                    label: 'En rupture',
                  ),
                  (
                    icon: Icons.receipt_long_outlined,
                    value: orderSnap.hasData ? '$pending' : '…',
                    label: 'Commandes en attente',
                  ),
                  (
                    icon: Icons.local_shipping_outlined,
                    value: orderSnap.hasData ? '${delivered.length}' : '…',
                    label: 'Commandes livrées',
                  ),
                  (
                    icon: Icons.payments_outlined,
                    value: orderSnap.hasData ? kitungaPrice(revenue) : '…',
                    label: 'Ventes livrées',
                  ),
                ]);
              },
            ),
            _title(theme, 'Gérer mon commerce'),
            _actions(theme, shop, products),
            if (lowStock.isNotEmpty) ...[
              _title(theme, 'Stock bas'),
              for (final p in lowStock)
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.0),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: KitungaImage(p.prodImg, width: 44.0, height: 44.0),
                  ),
                  title: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: theme.primaryText,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('Plus que ${p.quantity} en stock',
                      style: GoogleFonts.inter(
                          color: theme.primary, fontSize: 12.0)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: theme.secondaryText),
                  onTap: () => _push(
                    context,
                    SellerProductFormPage(
                      shop: shop,
                      product: p,
                      existingSections: _sectionsOf(products),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _shopHeader(FlutterFlowTheme theme, UserRecord shop) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 8.0, 20.0, 8.0),
      child: Row(
        children: [
          ClipOval(
            child: kitungaNetImage(context, shop.photoUrl,
                width: 56.0,
                height: 56.0,
                placeholder: kitungaShopPlaceholder(context, shop,
                    width: 56.0, height: 56.0)),
          ),
          SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Espace vendeur',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 13.0),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shop.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 22.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (shop.verified)
                      Padding(
                        padding: EdgeInsetsDirectional.only(start: 6.0),
                        child: Icon(Icons.verified_rounded,
                            color: theme.primary, size: 20.0),
                      ),
                  ],
                ),
                Text(
                  [shop.category, shop.horraire]
                      .where((e) => e.trim().isNotEmpty)
                      .join(' · '),
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 13.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(FlutterFlowTheme theme, IconData icon, String text) {
    return Container(
      margin: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0.0),
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Color(0xFFD99A00).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Color(0xFFB07D00), size: 20.0),
          SizedBox(width: 10.0),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    color: theme.primaryText, fontSize: 13.0, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _title(FlutterFlowTheme theme, String text) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 24.0, 20.0, 10.0),
        child: Text(
          text,
          style: GoogleFonts.interTight(
            color: theme.primaryText,
            fontSize: 18.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _statsGrid(FlutterFlowTheme theme,
      List<({IconData icon, String value, String label})> stats) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      mainAxisSpacing: 10.0,
      crossAxisSpacing: 10.0,
      childAspectRatio: 0.95,
      children: [
        for (final s in stats)
          Container(
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: theme.primaryBackground,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(s.icon, color: theme.primary, size: 22.0),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s.value,
                    style: GoogleFonts.interTight(
                      color: theme.primaryText,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  s.label,
                  maxLines: 2,
                  style: GoogleFonts.inter(
                    color: theme.secondaryText,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actions(
      FlutterFlowTheme theme, UserRecord shop, List<ProductRecord> products) {
    final item = sellerItemLabel(shop.category);
    final actions = [
      (
        icon: Icons.add_circle_outline_rounded,
        label: 'Ajouter un $item',
        onTap: () => _push(
            context,
            SellerProductFormPage(
                shop: shop, existingSections: _sectionsOf(products))),
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Mon catalogue',
        onTap: () => _push(context, SellerCatalogPage(shop: shop)),
      ),
      (
        icon: Icons.view_list_outlined,
        label: sellerSectionsTitle(shop.category),
        onTap: () => _push(context, SellerSectionsPage(shop: shop)),
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Mes commandes',
        onTap: () => context.pushNamed(OrderWidget.routeName),
      ),
      (
        icon: Icons.schedule_rounded,
        label: 'Horaires et profil',
        onTap: () => _push(context, SellerProfilePage(shop: shop)),
      ),
      (
        icon: Icons.visibility_outlined,
        label: 'Voir ma vitrine',
        onTap: () => openKitungaShop(context, shop),
      ),
    ];
    return Column(
      children: [
        for (final a in actions)
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20.0),
            leading: Container(
              width: 42.0,
              height: 42.0,
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(a.icon, color: theme.primary, size: 22.0),
            ),
            title: Text(a.label,
                style: GoogleFonts.inter(
                    color: theme.primaryText,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600)),
            trailing:
                Icon(Icons.chevron_right_rounded, color: theme.secondaryText),
            onTap: a.onTap,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Catalogue
// ─────────────────────────────────────────────────────────────────────────

/// Gestion du catalogue : recherche, filtres, disponibilité et stock.
class SellerCatalogPage extends StatefulWidget {
  const SellerCatalogPage({super.key, required this.shop});

  final UserRecord shop;

  @override
  State<SellerCatalogPage> createState() => _SellerCatalogPageState();
}

class _SellerCatalogPageState extends State<SellerCatalogPage> {
  late final Stream<List<ProductRecord>> _products = _myProducts();
  String _query = '';
  String _filter = 'all'; // all, published, drafts, out

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: _appBar(context, 'Mon catalogue'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.primary,
        foregroundColor: Colors.white,
        onPressed: () => openNewProductForm(context, widget.shop),
        icon: Icon(Icons.add_rounded),
        label: Text('Ajouter',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<ProductRecord>>(
        stream: _products,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          final all = snapshot.data!;
          final q = _query.trim().toLowerCase();
          final shown = all.where((p) {
            if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) {
              return false;
            }
            return switch (_filter) {
              'published' => kitungaIsPublished(p),
              'drafts' => !kitungaIsPublished(p),
              'out' => p.quantity <= 0,
              _ => true,
            };
          }).toList();

          return ListView(
            padding: EdgeInsets.only(bottom: 96.0),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 8.0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.inter(
                      color: theme.primaryText, fontSize: 15.0),
                  decoration: kitungaInputDecoration(
                      context, 'Rechercher dans mon catalogue', Icons.search),
                ),
              ),
              SizedBox(
                height: 48.0,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 4.0),
                  children: [
                    for (final f in [
                      (v: 'all', l: 'Tous (${all.length})'),
                      (
                        v: 'published',
                        l: 'En vente (${all.where(kitungaIsPublished).length})'
                      ),
                      (
                        v: 'drafts',
                        l: 'Brouillons (${all.where((p) => !kitungaIsPublished(p)).length})'
                      ),
                      (
                        v: 'out',
                        l: 'Rupture (${all.where((p) => p.quantity <= 0).length})'
                      ),
                    ])
                      Padding(
                        padding: EdgeInsetsDirectional.only(end: 8.0),
                        child: ChoiceChip(
                          label: Text(f.l),
                          selected: _filter == f.v,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = f.v),
                          labelStyle: GoogleFonts.inter(
                            color: _filter == f.v
                                ? Colors.white
                                : theme.primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.0,
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
              if (all.isEmpty)
                _emptyCatalog(theme)
              else if (shown.isEmpty)
                Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Aucun produit dans cette sélection.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: theme.secondaryText)),
                )
              else
                for (final p in shown) _row(theme, p, all),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyCatalog(FlutterFlowTheme theme) => Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48.0, color: theme.secondaryText),
            SizedBox(height: 12.0),
            Text(
              'Votre catalogue est vide. Ajoutez votre premier ${sellerItemLabel(widget.shop.category)} pour qu\'il apparaisse dans votre vitrine.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: theme.secondaryText),
            ),
          ],
        ),
      );

  Widget _row(
      FlutterFlowTheme theme, ProductRecord p, List<ProductRecord> all) {
    final published = kitungaIsPublished(p);
    return InkWell(
      onTap: () => _push(
        context,
        SellerProductFormPage(
            shop: widget.shop, product: p, existingSections: _sectionsOf(all)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.0, 10.0, 12.0, 10.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: KitungaImage(p.prodImg, width: 64.0, height: 64.0),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700)),
                  Text(
                    [
                      kitungaPrice(p.salePrice > 0 ? p.salePrice : p.price),
                      if (p.section.isNotEmpty) p.section,
                      if (!published) 'Brouillon',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: published ? theme.secondaryText : theme.primary,
                        fontSize: 12.5),
                  ),
                  SizedBox(height: 4.0),
                  // Stock modifiable directement.
                  Row(
                    children: [
                      _stockButton(
                          theme,
                          Icons.remove_rounded,
                          p.quantity > 0
                              ? () => _setStock(p, p.quantity - 1)
                              : null),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          p.quantity <= 0
                              ? (hasCuisines(widget.shop.category) ? 'Épuisé' : 'Rupture')
                              : (hasCuisines(widget.shop.category) ? 'Portions : ${p.quantity}' : 'Stock : ${p.quantity}'),
                          style: GoogleFonts.inter(
                            color: p.quantity <= 0
                                ? theme.error
                                : theme.primaryText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _stockButton(theme, Icons.add_rounded,
                          () => _setStock(p, p.quantity + 1)),
                    ],
                  ),
                ],
              ),
            ),
            // Disponibilité (publié / brouillon).
            Column(
              children: [
                Switch.adaptive(
                  value: published,
                  activeThumbColor: theme.primary,
                  onChanged: (v) => _setPublished(p, v),
                ),
                Text(published ? 'En vente' : 'Masqué',
                    style: GoogleFonts.inter(
                        color: theme.secondaryText, fontSize: 11.0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockButton(
          FlutterFlowTheme theme, IconData icon, VoidCallback? onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: Container(
          width: 28.0,
          height: 28.0,
          decoration: BoxDecoration(
            color: theme.primaryBackground,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon,
              size: 16.0,
              color: onTap == null ? theme.divider : theme.primaryText),
        ),
      );

  Future<void> _setStock(ProductRecord p, int quantity) =>
      p.reference.update(createProductRecordData(
          quantity: quantity, modifiedAt: getCurrentTimestamp));

  Future<void> _setPublished(ProductRecord p, bool publish) async {
    // Restaurants : un plat peut être publié sans photo.
    if (publish && p.prodImg.isEmpty && !hasCuisines(widget.shop.category)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Ajoutez une photo à ce produit avant de le publier.')));
      return;
    }
    await p.reference.update(createProductRecordData(
        onSale: publish, modifiedAt: getCurrentTimestamp));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Rubriques / rayons
// ─────────────────────────────────────────────────────────────────────────

/// Rubriques du menu (ou rayons) : renommer, retirer, compter les produits.
class SellerSectionsPage extends StatelessWidget {
  const SellerSectionsPage({super.key, required this.shop});

  final UserRecord shop;

  Future<void> _rename(
      BuildContext context, String old, List<ProductRecord> products) async {
    final controller = TextEditingController(text: old);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Renommer « $old »'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(c, controller.text.trim()),
              child: Text('Renommer')),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == old) return;
    for (final p in products.where((p) => p.section.trim() == old)) {
      await p.reference.update(createProductRecordData(section: name));
    }
  }

  Future<void> _remove(BuildContext context, String section,
      List<ProductRecord> products) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer « $section » ?'),
        content: Text(
            'Les produits de cette rubrique ne seront pas supprimés : ils seront simplement rangés dans « Autres ».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(c, true), child: Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    for (final p in products.where((p) => p.section.trim() == section)) {
      await p.reference.update(createProductRecordData(section: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = sellerSectionsTitle(shop.category);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: _appBar(context, title),
      body: StreamBuilder<List<ProductRecord>>(
        stream: _myProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          final products = snapshot.data!;
          final sections = _sectionsOf(products);
          return ListView(
            padding: EdgeInsets.only(bottom: 32.0),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 12.0),
                child: Text(
                  'Une ${sellerSectionLabel(shop.category).toLowerCase()} apparaît dès qu\'un produit y est rangé (champ « ${sellerSectionLabel(shop.category)} » du formulaire produit). Les clients voient votre vitrine organisée selon ces rubriques.',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 13.0, height: 1.45),
                ),
              ),
              if (sections.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Aucune rubrique pour le moment.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: theme.secondaryText),
                  ),
                ),
              for (final s in sections)
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.0),
                  title: Text(s,
                      style: GoogleFonts.inter(
                          color: theme.primaryText,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    () {
                      final n =
                          products.where((p) => p.section.trim() == s).length;
                      return '$n produit${n > 1 ? 's' : ''}';
                    }(),
                    style: GoogleFonts.inter(
                        color: theme.secondaryText, fontSize: 12.0),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Renommer',
                        onPressed: () => _rename(context, s, products),
                        icon: Icon(Icons.edit_outlined,
                            color: theme.secondaryText),
                      ),
                      IconButton(
                        tooltip: 'Retirer',
                        onPressed: () => _remove(context, s, products),
                        icon: Icon(Icons.delete_outline_rounded,
                            color: theme.error),
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

// ─────────────────────────────────────────────────────────────────────────
// Horaires et profil
// ─────────────────────────────────────────────────────────────────────────

/// Description et horaires du commerce.
class SellerProfilePage extends StatefulWidget {
  const SellerProfilePage({super.key, required this.shop});

  final UserRecord shop;

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  late final _bio = TextEditingController(text: widget.shop.bio);
  late final _hours = TextEditingController(text: widget.shop.horraire);
  bool _saving = false;

  /// Cuisines du restaurant (filtre « Cuisine » des clients, suggestions).
  late final Set<String> _cuisines = {
    for (final c in (widget.shop.snapshotData['cuisines'] as List? ?? const []))
      '$c',
  };

  @override
  void dispose() {
    _bio.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.shop.reference.update({
        ...createUserRecordData(
          bio: _bio.text.trim(),
          horraire: _hours.text.trim(),
        ),
        if (hasCuisines(widget.shop.category)) 'cuisines': _cuisines.toList(),
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
          SnackBar(content: Text('Profil du commerce mis à jour.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final status = kitungaOpeningStatus(_hours.text);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: _appBar(context,
          hasCuisines(widget.shop.category) ? 'Profil et cuisines' : 'Horaires et profil'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
        children: [
          KitungaFieldLabel('Description / spécialité'),
          TextField(
            controller: _bio,
            maxLines: 3,
            style: GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
            decoration: kitungaInputDecoration(
                context,
                'Ex : Cuisine congolaise, grillades et poissons braisés',
                Icons.notes_rounded),
          ),
          SizedBox(height: 16.0),
          KitungaFieldLabel('Horaires d\'ouverture'),
          TextField(
            controller: _hours,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
            decoration: kitungaInputDecoration(
                context, 'Ex : 8h - 22h', Icons.schedule_rounded),
          ),
          SizedBox(height: 8.0),
          Text(
            status == null
                ? 'Écrivez vos horaires sous la forme « 8h - 22h » pour que les clients voient si vous êtes ouvert.'
                : 'Aperçu pour les clients : ${status.label}',
            style: GoogleFonts.inter(
              color: status == null
                  ? theme.secondaryText
                  : (status.open ? Color(0xFF1E9E5A) : theme.secondaryText),
              fontSize: 12.5,
            ),
          ),
          if (hasCuisines(widget.shop.category)) ...[
            SizedBox(height: 20.0),
            KitungaFieldLabel('Vos cuisines (${_cuisines.length}/8)'),
            Text(
              'Les clients pourront trouver votre restaurant avec le filtre « Cuisine ».',
              style: GoogleFonts.inter(
                  color: theme.secondaryText, fontSize: 12.5),
            ),
            SizedBox(height: 10.0),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: [
                for (final c in kCuisines)
                  FilterChip(
                    label: Text(c),
                    selected: _cuisines.contains(c),
                    showCheckmark: false,
                    selectedColor: theme.primary,
                    labelStyle: GoogleFonts.inter(
                        color: _cuisines.contains(c)
                            ? Colors.white
                            : theme.primaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                    onSelected: (v) => setState(() {
                      if (v && _cuisines.length < 8) _cuisines.add(c);
                      if (!v) _cuisines.remove(c);
                    }),
                  ),
              ],
            ),
          ],
          SizedBox(height: 28.0),
          KitungaPrimaryButton(
              text: 'Enregistrer', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

PreferredSizeWidget _appBar(BuildContext context, String title) {
  final theme = FlutterFlowTheme.of(context);
  return AppBar(
    backgroundColor: theme.secondaryBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 0.0,
    iconTheme: IconThemeData(color: theme.primaryText),
    title: Text(
      title,
      style: GoogleFonts.interTight(
        color: theme.primaryText,
        fontSize: 19.0,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
