import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/backend/kitunga_categories.dart';
import 'package:kitunga/mobile/main_app/search/kitunga_filters.dart';
import 'package:kitunga/mobile/main_app/search/kitunga_search_page.dart';

/// Référence de document factice (chemin seulement).
// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  bool operator ==(Object other) => other is _Ref && other.path == path;
  @override
  int get hashCode => path.hashCode;
}

UserRecord shop(String id, String name, String category,
        {bool verified = false, String horaire = '', bool suspended = false}) =>
    UserRecord.getDocumentFromData({
      'display_name': name,
      'role': 'Seller',
      'category': category,
      'verified': verified,
      'Horraire': horaire,
      if (suspended) 'account_status': 'suspended',
      'created_time': DateTime(2026, 1, id.length),
    }, _Ref('User/$id'));

ProductRecord product(String id, String name, String shopId, int price,
        {int? qty,
        bool express = false,
        String tag = '',
        bool published = true,
        String section = '',
        int day = 1}) =>
    ProductRecord.getDocumentFromData({
      'name': name,
      'price': price.toDouble(),
      'sale_price': price,
      if (qty != null) 'quantity': qty,
      'instant_disponibilty': express,
      'specifications': tag,
      'on_sale': published,
      'section': section,
      'seller_ref': _Ref('User/$shopId'),
      'created_at': DateTime(2026, 11, day),
    }, _Ref('Product/$id'));

void main() {
  final shops = [
    shop('paul', 'Chez Paul', 'Restaurant', verified: true, horaire: '8h - 22h'),
    shop('pharma', 'Pharmacie du Centre', 'Pharmacie'),
    shop('ferme', 'Boutique fermée', 'Boutique', suspended: true),
  ];
  final byPath = {for (final s in shops) s.reference.path: s};
  final products = [
    product('p1', 'Poulet braisé', 'paul', 5000, express: true, tag: 'Tendance',
        section: 'Plats', day: 3),
    product('p2', 'Poulet DG', 'paul', 7000, qty: 0, day: 5),
    product('p3', 'Doliprane 500', 'pharma', 1500, qty: 10, tag: 'Nouveauté',
        day: 7),
    product('p4', 'Brouillon', 'paul', 100, published: false),
    product('p5', 'Robe', 'ferme', 9000),
  ];
  List<String> names(ProductFilter f) =>
      filterProducts(products, byPath, f).map((p) => p.name).toList();

  test('produits : seulement publiés et commerces actifs', () {
    expect(names(const ProductFilter()),
        ['Doliprane 500', 'Poulet DG', 'Poulet braisé']);
  });

  test('produits : recherche sans accents, tous les mots', () {
    expect(names(const ProductFilter(query: 'poulet')),
        containsAll(['Poulet braisé', 'Poulet DG']));
    expect(names(const ProductFilter(query: 'braise')), ['Poulet braisé']);
    expect(names(const ProductFilter(query: 'poulet dg')), ['Poulet DG']);
    expect(names(const ProductFilter(query: 'chez paul')).length, 2);
    expect(names(const ProductFilter(query: 'pizza')), isEmpty);
  });

  test('produits : catégorie, prix, stock, express, mise en avant', () {
    expect(names(const ProductFilter(category: 'Pharmacie')), ['Doliprane 500']);
    expect(names(const ProductFilter(minPrice: 2000, maxPrice: 6000)),
        ['Poulet braisé']);
    expect(names(const ProductFilter(inStock: true)),
        ['Doliprane 500', 'Poulet braisé']);
    expect(names(const ProductFilter(express: true)), ['Poulet braisé']);
    expect(names(const ProductFilter(tag: 'Nouveauté')), ['Doliprane 500']);
    expect(const ProductFilter(express: true, minPrice: 1).activeCount, 2);
  });

  test('produits : tris', () {
    expect(names(const ProductFilter(sort: ProductSort.priceAsc)),
        ['Doliprane 500', 'Poulet braisé', 'Poulet DG']);
    expect(names(const ProductFilter(sort: ProductSort.priceDesc)).first,
        'Poulet DG');
    expect(names(const ProductFilter(sort: ProductSort.name)).first,
        'Doliprane 500');
  });

  test('commerces : actifs, catégorie, certifié, ouvert maintenant', () {
    List<String> s(ShopFilter f, {DateTime? now}) =>
        filterShops(shops, f, now: now).map((x) => x.displayName).toList();
    expect(s(const ShopFilter()), containsAll(['Chez Paul', 'Pharmacie du Centre']));
    expect(s(const ShopFilter()).contains('Boutique fermée'), isFalse);
    expect(s(const ShopFilter(verified: true)), ['Chez Paul']);
    expect(s(const ShopFilter(category: 'Pharmacie')), ['Pharmacie du Centre']);
    expect(s(const ShopFilter(openNow: true), now: DateTime(2026, 11, 8, 12)),
        ['Chez Paul']);
    expect(s(const ShopFilter(openNow: true), now: DateTime(2026, 11, 8, 23)),
        isEmpty);
    expect(s(const ShopFilter(query: 'pharma')), ['Pharmacie du Centre']);
  });

  test('libellés de prix', () {
    expect(priceRangeLabel(2000, 5000), '2 000 – 5 000 F');
    expect(priceRangeLabel(null, 2000), 'Jusqu\'à 2 000 F');
    expect(priceRangeLabel(25000, null), 'Dès 25 000 F');
  });

  testWidgets('écran de recherche : filtres, pastilles, onglets', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    KitungaCategoryStore.fetchOverride = () async => throw 'hors ligne';
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: KitungaSearchPage(
        initialQuery: 'poulet',
        productsOverride: Stream.value(products),
        shopsOverride: Stream.value(shops),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Produits (2)'), findsOneWidget);
    expect(find.text('Commerces (0)'), findsOneWidget);

    await tester.tap(find.text('Filtres'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrer les produits'), findsOneWidget);
    await tester.ensureVisible(find.text('Disponibles uniquement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disponibles uniquement'));
    await tester.pumpAndSettle();
    expect(find.text('Voir 1 résultat'), findsOneWidget);
    await tester.tap(find.text('Voir 1 résultat'));
    await tester.pumpAndSettle();
    expect(find.text('Produits (1)'), findsOneWidget);
    expect(find.text('Disponibles'), findsOneWidget); // pastille active

    // Retirer la pastille rétablit la liste.
    final close = find
        .descendant(of: find.byType(InputChip), matching: find.byType(Icon))
        .last;
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Produits (2)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pharma');
    await tester.pumpAndSettle();
    expect(find.text('Commerces (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    KitungaCategoryStore.fetchOverride = null;
  });
}
