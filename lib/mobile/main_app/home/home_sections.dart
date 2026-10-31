import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Types de commerce : image correspondante et fond pastel distinct.
const kitungaCategories = [
  (
    name: 'Boutique',
    image: 'assets/images/categories/boutique.png',
    pastel: Color(0xFFFFE4E1),
  ),
  (
    name: 'Restaurant',
    image: 'assets/images/categories/restaurant.png',
    pastel: Color(0xFFFFEBD6),
  ),
  (
    name: 'Pharmacie',
    image: 'assets/images/categories/pharmacie.png',
    pastel: Color(0xFFE2F5E9),
  ),
  (
    name: 'Magasin',
    image: 'assets/images/categories/magasin.png',
    pastel: Color(0xFFE2EDFB),
  ),
  (
    name: 'Fast Food',
    image: 'assets/images/categories/fastfood.png',
    pastel: Color(0xFFFFF3D1),
  ),
];

/// Fond pastel d'une catégorie (atténué en mode sombre).
Color kitungaCategoryBackground(BuildContext context, String name) {
  final theme = FlutterFlowTheme.of(context);
  if (Theme.of(context).brightness == Brightness.dark) {
    return kitungaCategoryColor(theme, name).withValues(alpha: 0.18);
  }
  return kitungaCategories
      .firstWhere((c) => c.name == name, orElse: () => kitungaCategories.first)
      .pastel;
}

/// Ouvre la liste des commerces d'une catégorie.
void openKitungaCategory(BuildContext context, String category) {
  context.pushNamed(
    ShopsWidget.routeName,
    queryParameters: {
      'tag': serializeParam(category, ParamType.String),
    }.withoutNulls,
  );
}

/// Ouvre une page « Voir plus ».
void openSeeMore(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

/// Titre de section : titre, sous-titre et bouton « Voir plus ».
class KitungaSectionHeader extends StatelessWidget {
  const KitungaSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onMore,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 28.0, 8.0, 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.0),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: theme.secondaryText,
                      fontSize: 13.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir plus',
                    style: GoogleFonts.inter(
                      color: theme.primary,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.primary, size: 20.0),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tuile de catégorie de l'accueil (image sur fond pastel + nom).
class KitungaCategoryTile extends StatelessWidget {
  const KitungaCategoryTile({
    super.key,
    required this.name,
    required this.image,
    this.size = 72.0,
  });

  final String name;
  final String image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18.0),
      onTap: () => openKitungaCategory(context, name),
      child: SizedBox(
        width: size,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              padding: EdgeInsets.all(size * 0.14),
              decoration: BoxDecoration(
                color: kitungaCategoryBackground(context, name),
                borderRadius: BorderRadius.circular(size * 0.28),
              ),
              child: Image.asset(image, fit: BoxFit.contain),
            ),
            SizedBox(height: 8.0),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: theme.primaryText,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mise en page commune des pages « Voir plus ».
class _SeeMoreScaffold extends StatelessWidget {
  const _SeeMoreScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
        ),
        titleSpacing: 0.0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 18.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: theme.secondaryText,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

/// Grille paginée des pages « Voir plus » : 2 éléments par ligne,
/// 4 par page, avec navigation entre les pages.
class KitungaPagedGrid<T> extends StatefulWidget {
  const KitungaPagedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemExtent,
    this.perPage = 4,
    this.header,
  });

  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final double itemExtent;
  final int perPage;
  final Widget? header;

  @override
  State<KitungaPagedGrid<T>> createState() => _KitungaPagedGridState<T>();
}

class _KitungaPagedGridState<T> extends State<KitungaPagedGrid<T>> {
  int _page = 0;

  @override
  void didUpdateWidget(covariant KitungaPagedGrid<T> old) {
    super.didUpdateWidget(old);
    // La liste a changé (filtre) : on revient à la première page.
    if (old.items.length != widget.items.length) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final pages = (widget.items.length / widget.perPage).ceil();
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
    final shown =
        widget.items.skip(page * widget.perPage).take(widget.perPage).toList();

    return ListView(
      padding: EdgeInsets.only(bottom: 24.0),
      children: [
        if (widget.header != null) widget.header!,
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0.0),
          itemCount: shown.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14.0,
            crossAxisSpacing: 14.0,
            mainAxisExtent: widget.itemExtent,
          ),
          itemBuilder: (context, i) => widget.itemBuilder(context, shown[i]),
        ),
        if (pages > 1)
          Padding(
            padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Page précédente',
                  onPressed:
                      page > 0 ? () => setState(() => _page = page - 1) : null,
                  icon: Icon(Icons.chevron_left_rounded),
                ),
                for (var p = 0; p < pages; p++)
                  if (pages <= 6 ||
                      (p - page).abs() <= 1 ||
                      p == 0 ||
                      p == pages - 1)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12.0),
                        onTap: () => setState(() => _page = p),
                        child: Container(
                          width: 36.0,
                          height: 36.0,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p == page
                                ? theme.primary
                                : theme.primaryBackground,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            '${p + 1}',
                            style: GoogleFonts.inter(
                              color:
                                  p == page ? Colors.white : theme.primaryText,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                IconButton(
                  tooltip: 'Page suivante',
                  onPressed: page < pages - 1
                      ? () => setState(() => _page = page + 1)
                      : null,
                  icon: Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// « Voir plus » d'une liste de commerces, avec filtre par catégorie.
class KitungaShopListPage extends StatefulWidget {
  const KitungaShopListPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.shops,
  });

  final String title;
  final String subtitle;
  final List<UserRecord> shops;

  @override
  State<KitungaShopListPage> createState() => _KitungaShopListPageState();
}

class _KitungaShopListPageState extends State<KitungaShopListPage> {
  String _category = '';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    // Seules les catégories réellement présentes sont proposées.
    final present = kitungaCategories
        .where((c) => widget.shops.any((s) => s.category == c.name))
        .map((c) => c.name)
        .toList();
    final shown = _category.isEmpty
        ? widget.shops
        : widget.shops.where((s) => s.category == _category).toList();

    return _SeeMoreScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      child: KitungaPagedGrid<UserRecord>(
        items: shown,
        itemExtent: 182.0,
        header: present.length > 1
            ? SizedBox(
                height: 56.0,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
                  children: [
                    for (final c in ['', ...present])
                      Padding(
                        padding: EdgeInsetsDirectional.only(end: 8.0),
                        child: ChoiceChip(
                          label: Text(c.isEmpty ? 'Tous' : c),
                          selected: _category == c,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = c),
                          labelStyle: GoogleFonts.inter(
                            color: _category == c
                                ? Colors.white
                                : theme.primaryText,
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
              )
            : null,
        itemBuilder: (context, shop) =>
            KitungaShopCard(shop: shop, width: null, coverHeight: 96.0),
      ),
    );
  }
}

/// « Voir plus » des nouveaux produits : grille complète.
class KitungaProductListPage extends StatelessWidget {
  const KitungaProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _SeeMoreScaffold(
      title: 'Nos produits',
      subtitle: 'Les derniers articles ajoutés par nos commerçants',
      child: StreamBuilder<List<ProductRecord>>(
        stream: queryProductRecord(
          queryBuilder: (q) => q.orderBy('created_at', descending: true),
          limit: 60,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          final products = snapshot.data!.where(kitungaIsPublished).toList();
          return KitungaPagedGrid<ProductRecord>(
            items: products,
            itemExtent: KitungaProductCard.gridExtent,
            itemBuilder: (context, product) => KitungaProductCard(
              product: product,
              onTap: () => openKitungaProduct(context, product),
            ),
          );
        },
      ),
    );
  }
}
