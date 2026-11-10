import '/backend/backend.dart';
import '/backend/kitunga_categories.dart';
export '/backend/kitunga_categories.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Types de commerce : image et fond pastel. Gérés par l'admin ; les 5
/// d'origine tant que la liste n'est pas chargée (voir kitunga_categories.dart).
List<KitungaCategory> get kitungaCategories =>
    KitungaCategoryStore.instance.list;

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
              padding: kitungaCategoryPadding(
                  image, EdgeInsets.all(size * 0.14)),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: kitungaCategoryBackground(context, name),
                borderRadius: BorderRadius.circular(size * 0.28),
              ),
              child: KitungaCategoryImage(image),
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
  const KitungaProductListPage({
    super.key,
    this.tag,
    this.title = 'Nos produits',
    this.subtitle = 'Les derniers articles ajoutés par nos commerçants',
  });

  /// Filtre « Nouveauté » ou « Tendance » (champ specifications) ; null : tous.
  final String? tag;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _SeeMoreScaffold(
      title: title,
      subtitle: subtitle,
      child: StreamBuilder<Set<String>>(
        stream: kitungaSuspendedShopPaths(),
        // En cas d'erreur de lecture, rien n'est masqué en plus.
        builder: (context, suspended) => StreamBuilder<List<ProductRecord>>(
        stream: queryProductRecord(
          queryBuilder: (q) => q.orderBy('created_at', descending: true),
          limit: tag == null ? 60 : 200,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          final hidden = suspended.data ?? const <String>{};
          final products = snapshot.data!
              .where(kitungaIsPublished)
              .where((p) => !hidden.contains(p.sellerRef?.path))
              .where((p) => tag == null || p.specifications == tag)
              .toList();
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
      ),
    );
  }
}


/// Produits sur l'accueil des clients : Tendances, Nouveautés et Nos produits
/// (publiés, commerces actifs), en rangées horizontales avec « Voir tout ».
class KitungaHomeProducts extends StatefulWidget {
  const KitungaHomeProducts({super.key, this.productsOverride});

  /// Tests : remplace la lecture des produits.
  final Stream<List<ProductRecord>>? productsOverride;

  @override
  State<KitungaHomeProducts> createState() => _KitungaHomeProductsState();
}

/// Tests : produits de l'accueil (sans Firebase).
@visibleForTesting
Stream<List<ProductRecord>>? Function()? kitungaHomeProductsOverride;

class _KitungaHomeProductsState extends State<KitungaHomeProducts> {
  late final Stream<List<ProductRecord>>? _override =
      widget.productsOverride ?? kitungaHomeProductsOverride?.call();
  late final Stream<List<ProductRecord>> _products = _override ??
      queryProductRecord(
        queryBuilder: (q) => q.orderBy('created_at', descending: true),
        limit: 150,
      );
  late final Stream<Set<String>> _hidden = _override != null
      ? Stream.value(const <String>{})
      : kitungaSuspendedShopPaths();

  /// Récent : ajouté depuis moins de 30 jours.
  static bool _recent(ProductRecord p) =>
      p.createdAt != null &&
      DateTime.now().difference(p.createdAt!) < const Duration(days: 30);

  Widget _row(BuildContext context, String title, List<ProductRecord> list,
      VoidCallback onSeeAll) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18.0),
          child: KitungaSectionHeader(title: title, onMore: onSeeAll),
        ),
        SizedBox(
          height: KitungaProductCard.gridExtent,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12.0),
            itemBuilder: (context, i) => SizedBox(
              width: 168.0,
              child: KitungaProductCard(
                product: list[i],
                onTap: () => openKitungaProduct(context, list[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _hidden,
      builder: (context, hiddenSnap) => StreamBuilder<List<ProductRecord>>(
        stream: _products,
        builder: (context, snap) {
          final hidden = hiddenSnap.data ?? const <String>{};
          final all = (snap.data ?? const <ProductRecord>[])
              .where(kitungaIsPublished)
              .where((p) => !hidden.contains(p.sellerRef?.path))
              .toList();
          if (all.isEmpty) return const SizedBox.shrink();
          final trending =
              all.where((p) => p.specifications == 'Tendance').take(12).toList();
          // Marqués « Nouveauté » d'abord, puis les plus récents.
          final fresh = [
            ...all.where((p) => p.specifications == 'Nouveauté'),
            ...all.where((p) => p.specifications != 'Nouveauté' && _recent(p)),
          ].take(12).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (trending.isNotEmpty)
                _row(context, 'Tendances', trending,
                    () => openSeeMore(context, const KitungaProductListPage(
                        tag: 'Tendance',
                        title: 'Tendances',
                        subtitle: 'Les produits les plus demandés'))),
              if (fresh.isNotEmpty)
                _row(context, 'Nouveautés', fresh,
                    () => openSeeMore(context, const KitungaProductListPage(
                        tag: 'Nouveauté',
                        title: 'Nouveautés',
                        subtitle: 'Les derniers arrivages de nos commerçants'))),
              _row(context, 'Nos produits', all.take(12).toList(),
                  () => openSeeMore(context, const KitungaProductListPage())),
            ],
          );
        },
      ),
    );
  }
}
