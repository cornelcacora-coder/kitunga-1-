import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/backend/kitunga_categories.dart';
import 'package:kitunga/mobile/components/product_card/product_card_widget.dart';
import 'package:kitunga/mobile/main_app/home/home_sections.dart';
import 'package:kitunga/mobile/main_app/shop_detail_page/shop_detail_page_widget.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Vitrines et « Voir tout » : cartes, recherche, filtres, tri.
void main() {
  UserRecord shop(String id, String cat, {bool suspended = false}) =>
      UserRecord.getDocumentFromData({
        'display_name': id, 'role': 'Seller', 'category': cat,
        if (suspended) 'account_status': 'suspended',
      }, _Ref('User/$id'));
  ProductRecord p(String n, String seller,
          {String section = '', int price = 1500, String tag = ''}) =>
      ProductRecord.getDocumentFromData({
        'name': n, 'section': section, 'sale_price': price, 'price': price,
        'quantity': 10, 'on_sale': true, 'prod_img': '', 'specifications': tag,
        'seller_ref': _Ref('User/$seller'),
        'created_at': DateTime(2026, 11, 1),
      }, _Ref('Product/$n'));

  List<String> cards(WidgetTester t) => [
        for (final c in t.widgetList<KitungaProductCard>(
            find.byType(KitungaProductCard)))
          c.product.name,
      ];

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    KitungaCategoryStore.fetchOverride = () async => throw 'hors ligne';
  });

  Future<void> open(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(400, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: page));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('restaurant : cartes par rubrique, rayon, recherche, tri',
      (t) async {
    final zc = shop('zc', 'Restaurant');
    shopDetailShopOverride = () => Stream.value(zc);
    shopDetailProductsOverride = () => Stream.value([
          p('Riz gras', 'zc', section: 'Plats africains', price: 1500),
          p('Liboké', 'zc', section: 'Plats africains', price: 2500),
          p('Côtes', 'zc', section: 'Grillades', price: 2000),
        ]);
    await open(t, ShopDetailPageWidget(userRef: _Ref('User/zc')));
    // Cartes (et plus des lignes), rangées sous chaque rubrique.
    expect(cards(t), ['Riz gras', 'Liboké', 'Côtes']);
    expect(find.text('Plats africains'), findsWidgets);
    // Rayon « Grillades » en accès rapide.
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Grillades'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Grillades'));
    await t.pump();
    expect(cards(t), ['Côtes']);
    expect(find.text('1 plat'), findsOneWidget);
    // Le rayon choisi apparaît en pastille ; « Tout effacer » le retire.
    expect(find.widgetWithText(InputChip, 'Grillades'), findsOneWidget);
    await t.tap(find.text('Tout effacer'));
    await t.pump();
    expect(cards(t).length, 3);
    // Recherche.
    await t.enterText(find.byType(TextField), 'lib');
    await t.pump();
    expect(cards(t), ['Liboké']);
    await t.enterText(find.byType(TextField), '');
    await t.pump();
    // Tri par prix décroissant.
    await t.tap(find.byTooltip('Trier'));
    await t.pumpAndSettle();
    await t.tap(find.text('Prix décroissant').last);
    await t.pumpAndSettle();
    expect(cards(t), ['Liboké', 'Côtes', 'Riz gras']);
    // Filtre de prix depuis la fenêtre des filtres.
    await t.tap(find.byTooltip('Filtres'));
    await t.pumpAndSettle();
    await t.tap(find.text('Jusqu\'à 2 000 F').last);
    await t.pumpAndSettle();
    // « Jusqu'à 2 000 F » : 2 000 F inclus ; le tri décroissant est gardé.
    await t.tap(find.textContaining('Voir 2 résultats'));
    await t.pumpAndSettle();
    expect(cards(t), ['Côtes', 'Riz gras']);
    expect(find.widgetWithText(InputChip, 'Jusqu\'à 2 000 F'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Tendances : catégorie, commerces suspendus masqués',
      (t) async {
    productListShopsOverride = () => Stream.value([
          shop('mode', 'Boutique'),
          shop('zc', 'Restaurant'),
          shop('ferme', 'Boutique', suspended: true),
        ]);
    productListProductsOverride = () => Stream.value([
          p('Chemise', 'mode', tag: 'Tendance', price: 8000),
          p('Poulet DG', 'zc', tag: 'Tendance', price: 3000),
          p('Robe', 'ferme', tag: 'Tendance'),
          p('Pantalon', 'mode'),
        ]);
    await open(t, const KitungaProductListPage(
        tag: 'Tendance', title: 'Tendances', subtitle: ''));
    expect(cards(t).toSet(), {'Chemise', 'Poulet DG'});
    expect(find.widgetWithText(InputChip, 'Tendances'), findsOneWidget);
    await t.tap(find.byTooltip('Filtres'));
    await t.pumpAndSettle();
    await t.tap(find.text('Restaurant').last);
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Voir 1 résultat'));
    await t.pumpAndSettle();
    expect(cards(t), ['Poulet DG']);
    expect(t.takeException(), isNull);
  });
}
