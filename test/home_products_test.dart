import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/product_card/product_card_widget.dart';
import 'package:kitunga/mobile/main_app/home/home_sections.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Produits sur l'accueil des clients.
void main() {
  ProductRecord product(String id, String name,
          {String tag = '', bool published = true, int ageDays = 1}) =>
      ProductRecord.getDocumentFromData({
        'name': name,
        'sale_price': 2000,
        'price': 2000,
        'quantity': 10,
        'on_sale': published,
        'specifications': tag,
        'prod_img': '',
        'created_at': DateTime.now().subtract(Duration(days: ageDays)),
        'seller_ref': _Ref('User/crisp'),
      }, _Ref('Product/$id'));

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Nombre de cartes produit de ce nom.
  int cards(WidgetTester tester, String name) => tester
      .widgetList<KitungaProductCard>(find.byType(KitungaProductCard))
      .where((c) => c.product.name == name)
      .length;

  Future<void> open(WidgetTester tester, List<ProductRecord> list) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: KitungaHomeProducts(productsOverride: Stream.value(list)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Tendances, Nouveautés, Nos produits ; brouillons masqués',
      (tester) async {
    await open(tester, [
      product('a', 'Poulet yassa', tag: 'Tendance', ageDays: 90),
      product('b', 'Mosseka', tag: 'Nouveauté', ageDays: 60),
      product('c', 'Saka-saka', ageDays: 2),
      product('d', 'Ancien plat', ageDays: 200),
      product('e', 'Brouillon', published: false),
    ]);
    expect(find.text('Tendances'), findsOneWidget);
    expect(find.text('Nouveautés'), findsOneWidget);
    expect(find.text('Nos produits'), findsOneWidget);
    expect(cards(tester, 'Brouillon'), 0);
    // Poulet yassa : Tendances + Nos produits.
    expect(cards(tester, 'Poulet yassa'), 2);
    // Mosseka (marqué) et Saka-saka (récent) dans les Nouveautés.
    expect(cards(tester, 'Mosseka'), 2);
    expect(cards(tester, 'Saka-saka'), 2);
    // Ancien plat non marqué : seulement dans Nos produits.
    expect(cards(tester, 'Ancien plat'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans produit marqué : pas de rangée Tendances', (tester) async {
    await open(tester, [product('c', 'Saka-saka', ageDays: 2)]);
    expect(find.text('Tendances'), findsNothing);
    expect(find.text('Nouveautés'), findsOneWidget);
  });

  testWidgets('aucun produit : rien affiché', (tester) async {
    await open(tester, []);
    expect(find.text('Nos produits'), findsNothing);
  });
}
