import '/backend/backend.dart';
import '/backend/kitunga_categories.dart' show kitungaShopIsActive;
import '/mobile/components/product_card/product_card_widget.dart'
    show kitungaIsPublished;
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart'
    show kitungaOpeningStatus;

/// Filtres et tris de la recherche client (produits et commerces).
/// Fonctions pures, testées.

enum ProductSort { relevance, newest, priceAsc, priceDesc, name }

enum ShopSort { relevance, name, newest }

const productSortLabels = {
  ProductSort.relevance: 'Pertinence',
  ProductSort.newest: 'Plus récents',
  ProductSort.priceAsc: 'Prix croissant',
  ProductSort.priceDesc: 'Prix décroissant',
  ProductSort.name: 'Nom (A → Z)',
};

const shopSortLabels = {
  ShopSort.relevance: 'Pertinence',
  ShopSort.name: 'Nom (A → Z)',
  ShopSort.newest: 'Plus récents',
};

class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.category,
    this.minPrice,
    this.maxPrice,
    this.inStock = false,
    this.express = false,
    this.cuisine,
    this.tag,
    this.sort = ProductSort.relevance,
  });

  final String query;
  final String? category;
  final int? minPrice;
  final int? maxPrice;
  final bool inStock;
  final bool express;

  /// Cuisine du restaurant (champ cuisines du commerce).
  final String? cuisine;

  /// « Nouveauté » ou « Tendance » (champ specifications).
  final String? tag;
  final ProductSort sort;

  /// Nombre de filtres actifs (hors texte et tri), pour le badge.
  int get activeCount => [
        category != null,
        minPrice != null || maxPrice != null,
        inStock,
        express,
        cuisine != null,
        tag != null,
      ].where((b) => b).length;

  ProductFilter copyWith({
    String? query,
    String? Function()? category,
    int? Function()? minPrice,
    int? Function()? maxPrice,
    bool? inStock,
    bool? express,
    String? Function()? cuisine,
    String? Function()? tag,
    ProductSort? sort,
  }) =>
      ProductFilter(
        query: query ?? this.query,
        category: category != null ? category() : this.category,
        minPrice: minPrice != null ? minPrice() : this.minPrice,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        inStock: inStock ?? this.inStock,
        express: express ?? this.express,
        cuisine: cuisine != null ? cuisine() : this.cuisine,
        tag: tag != null ? tag() : this.tag,
        sort: sort ?? this.sort,
      );

  /// Sans filtre (le texte et le tri sont conservés).
  ProductFilter cleared() => ProductFilter(query: query, sort: sort);
}

class ShopFilter {
  const ShopFilter({
    this.query = '',
    this.category,
    this.openNow = false,
    this.verified = false,
    this.cuisine,
    this.sort = ShopSort.relevance,
  });

  final String query;
  final String? category;
  final String? cuisine;
  final bool openNow;
  final bool verified;
  final ShopSort sort;

  int get activeCount =>
      [category != null, cuisine != null, openNow, verified]
          .where((b) => b)
          .length;

  ShopFilter copyWith({
    String? query,
    String? Function()? category,
    bool? openNow,
    bool? verified,
    String? Function()? cuisine,
    ShopSort? sort,
  }) =>
      ShopFilter(
        query: query ?? this.query,
        category: category != null ? category() : this.category,
        cuisine: cuisine != null ? cuisine() : this.cuisine,
        openNow: openNow ?? this.openNow,
        verified: verified ?? this.verified,
        sort: sort ?? this.sort,
      );

  ShopFilter cleared() => ShopFilter(query: query, sort: sort);
}

/// Cuisines d'un restaurant (champ cuisines).
List<String> shopCuisines(UserRecord s) => [
      for (final c in (s.snapshotData['cuisines'] as List? ?? const [])) '$c',
    ];

/// Texte comparable : minuscules, sans accents.
String searchNorm(String v) => v
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c')
    .trim();

/// Prix de vente affiché (comme la fiche produit).
num productPrice(ProductRecord p) => p.salePrice > 0 ? p.salePrice : p.price;

/// Score de pertinence : nom > rayon/étiquette > description.
int _score(String q, List<String> fields) {
  if (q.isEmpty) return 1;
  var s = 0;
  final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  for (final w in words) {
    if (searchNorm(fields[0]).startsWith(w)) {
      s += 6;
    } else if (searchNorm(fields[0]).contains(w)) {
      s += 4;
    } else if (fields.skip(1).take(2).any((f) => searchNorm(f).contains(w))) {
      s += 2;
    } else if (fields.skip(3).any((f) => searchNorm(f).contains(w))) {
      s += 1;
    } else {
      return 0; // tous les mots doivent correspondre
    }
  }
  return s;
}

/// Produits visibles (publiés, commerce actif) filtrés et triés.
List<ProductRecord> filterProducts(List<ProductRecord> products,
    Map<String, UserRecord> shopsByPath, ProductFilter f) {
  final q = searchNorm(f.query);
  final scored = <(ProductRecord, int)>[];
  for (final p in products) {
    if (!kitungaIsPublished(p)) continue;
    final shop = shopsByPath[p.sellerRef?.path];
    if (shop == null || !kitungaShopIsActive(shop)) continue;
    if (f.category != null && shop.category != f.category) continue;
    if (f.cuisine != null && !shopCuisines(shop).contains(f.cuisine)) continue;
    final price = productPrice(p);
    if (f.minPrice != null && price < f.minPrice!) continue;
    if (f.maxPrice != null && price > f.maxPrice!) continue;
    if (f.inStock && p.hasQuantity() && p.quantity <= 0) continue;
    if (f.express && !p.instantDisponibilty) continue;
    if (f.tag != null && p.specifications != f.tag) continue;
    final score = _score(q, [
      p.name,
      p.section,
      p.specifications,
      p.description,
      shop.displayName,
    ]);
    if (score == 0) continue;
    scored.add((p, score));
  }
  int byDate(ProductRecord a, ProductRecord b) =>
      (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
  scored.sort((a, b) => switch (f.sort) {
        ProductSort.relevance =>
          b.$2 != a.$2 ? b.$2 - a.$2 : byDate(a.$1, b.$1),
        ProductSort.newest => byDate(a.$1, b.$1),
        ProductSort.priceAsc => productPrice(a.$1).compareTo(productPrice(b.$1)),
        ProductSort.priceDesc =>
          productPrice(b.$1).compareTo(productPrice(a.$1)),
        ProductSort.name =>
          searchNorm(a.$1.name).compareTo(searchNorm(b.$1.name)),
      });
  return [for (final s in scored) s.$1];
}

/// Commerces actifs filtrés et triés.
List<UserRecord> filterShops(List<UserRecord> shops, ShopFilter f,
    {DateTime? now}) {
  final q = searchNorm(f.query);
  final scored = <(UserRecord, int)>[];
  for (final s in shops) {
    if (!kitungaShopIsActive(s)) continue;
    if (f.category != null && s.category != f.category) continue;
    if (f.cuisine != null && !shopCuisines(s).contains(f.cuisine)) continue;
    if (f.verified && !s.verified) continue;
    if (f.openNow &&
        kitungaOpeningStatus(s.horraire, now)?.open != true) {
      continue;
    }
    final score = _score(q, [s.displayName, s.category, '', s.bio]);
    if (score == 0) continue;
    scored.add((s, score));
  }
  int byDate(UserRecord a, UserRecord b) => (b.createdTime ?? DateTime(2000))
      .compareTo(a.createdTime ?? DateTime(2000));
  scored.sort((a, b) => switch (f.sort) {
        ShopSort.relevance =>
          b.$2 != a.$2 ? b.$2 - a.$2 : (b.$1.verified ? 1 : 0) - (a.$1.verified ? 1 : 0),
        ShopSort.name =>
          searchNorm(a.$1.displayName).compareTo(searchNorm(b.$1.displayName)),
        ShopSort.newest => byDate(a.$1, b.$1),
      });
  return [for (final s in scored) s.$1];
}
