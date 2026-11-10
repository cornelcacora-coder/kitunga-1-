import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/product_options/customize_sheet.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Boutique : stock par taille, quantité limitée par la taille choisie.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('taille épuisée, plus que 2 en M, quantité plafonnée',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final shirt = ProductRecord.getDocumentFromData({
      'name': 'Chemise wax',
      'sale_price': 8000,
      'quantity': 10,
      'prod_img': '',
      'options': [
        {
          'name': 'Taille', 'required': true, 'max': 1,
          'choices': [
            {'label': 'S', 'price': 0, 'stock': 0},
            {'label': 'M', 'price': 0, 'stock': 2},
            {'label': 'L', 'price': 0, 'stock': 8},
          ],
        },
      ],
    }, _Ref('Product/p1'));
    KitungaCustomization? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showKitungaCustomizeSheet(context, shirt),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Épuisé'), findsOneWidget); // S
    expect(find.text('Plus que 2 · Inclus'), findsOneWidget); // M
    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();
    final plus = find.byIcon(Icons.add_rounded);
    for (var i = 0; i < 4; i++) {
      await tester.tap(plus);
      await tester.pumpAndSettle();
    }
    expect(find.text('2'), findsOneWidget); // plafonné au stock de M
    await tester.tap(find.textContaining('Ajouter au panier'));
    await tester.pumpAndSettle();
    expect(result?.quantity, 2);
    expect(result?.summary, 'Taille : M');
  });
}
