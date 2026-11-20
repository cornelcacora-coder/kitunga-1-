import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/backend/server_payment.dart';
import 'package:kitunga/mobile/seller/seller_promotions.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Publicités créées par un vendeur depuis son application.
void main() {
  const img = 'https://firebasestorage.googleapis.com/v0/b/x/o/p.jpg';
  final calls = <(String, Map<String, dynamic>)>[];
  var banners = <Map<String, dynamic>>[];
  final shop = UserRecord.getDocumentFromData(
      {'display_name': 'Le Crisp\'nCroc', 'role': 'Seller',
        'category': 'Restaurant'}, _Ref('User/crisp'));
  final mosseka = ProductRecord.getDocumentFromData(
      {'name': 'Mosseka', 'on_sale': true, 'prod_img': img,
        'seller_ref': _Ref('User/crisp')}, _Ref('Product/p1'));

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    sellerPromoBackendOverride = (name, data) async {
      calls.add((name, data));
      if (name == 'kitungaSellerBanners') {
        return {'max': 3, 'banners': banners};
      }
      if (name == 'kitungaSaveSellerBanner' && data['title1'] == 'Refus') {
        throw ServerPaymentException('3 publicités au plus en même temps.');
      }
      return {'ok': true, 'id': 'new', 'status': 'pending'};
    };
  });
  setUp(() {
    calls.clear();
    // Un flux par test (il ne se lit qu'une fois).
    sellerPromoProductsOverride = Stream.value([mosseka]);
  });

  Future<void> show(WidgetTester tester, String text,
      {double delta = 200.0}) async {
    await tester.scrollUntilVisible(find.text(text), delta,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: page,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('liste : états, motif de refus, pause, suppression',
      (tester) async {
    banners = [
      {'id': 'b1', 'title1': 'Crisp', 'title2': '-20 %', 'image': img,
        'status': 'live', 'active': true, 'clicks': 7,
        'endsAt': '2026-12-24T22:59:00Z'},
      {'id': 'b2', 'title1': 'Mosseka', 'title2': 'PROMO', 'image': img,
        'status': 'rejected', 'reviewNote': 'Photo floue', 'clicks': 0},
    ];
    await open(tester, SellerPromotionsPage(shop: shop));
    expect(find.text('Diffusée'), findsOneWidget);
    expect(find.text('Refusée'), findsOneWidget);
    expect(find.textContaining('Motif : Photo floue'), findsOneWidget);
    expect(find.textContaining('7 clics'), findsOneWidget);
    // Pause seulement pour une publicité validée.
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(calls.map((c) => c.$1), contains('kitungaSetSellerBannerActive'));
    expect(calls.firstWhere((c) => c.$1 == 'kitungaSetSellerBannerActive').$2,
        {'id': 'b1', 'active': false});
    await tester.ensureVisible(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last); // confirmation
    await tester.pumpAndSettle();
    expect(calls.firstWhere((c) => c.$1 == 'kitungaDeleteSellerBanner').$2,
        {'id': 'b2'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('nouvelle publicité d\'un produit : aperçu puis envoi',
      (tester) async {
    banners = [];
    bool? sent;
    await open(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => sent = await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => SellerPromotionForm(shop: shop))),
            child: const Text('Ouvrir'),
          ),
        ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    // Titre pré-rempli avec le nom du commerce, visible dans l'aperçu.
    expect(find.text('Le Crisp\'nCroc'), findsWidgets);
    await tester.tap(find.text('Ma boutique (vitrine)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mosseka').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '-15 % ce midi');
    await show(tester, '-20 %');
    await tester.tap(find.text('-20 %'));
    await tester.pumpAndSettle();
    expect(find.text('-15 % ce midi'), findsWidgets); // aperçu
    await show(tester, 'Envoyer pour validation');
    await tester.tap(find.text('Envoyer pour validation'));
    await tester.pumpAndSettle();
    final data = calls.last.$2;
    expect(calls.last.$1, 'kitungaSaveSellerBanner');
    expect(data['target'], {'type': 'product', 'value': 'p1'});
    expect(data['title2'], '-15 % ce midi');
    expect(data['badge'], '-20 %');
    expect(data['color'], '#E51A1A');
    expect(sent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erreur du serveur affichée dans le formulaire', (tester) async {
    await open(tester, SellerPromotionForm(shop: shop));
    await tester.enterText(find.byType(TextField).first, 'Refus');
    await show(tester, 'Envoyer pour validation');
    await tester.tap(find.text('Envoyer pour validation'));
    await tester.pumpAndSettle();
    // Pas de photo ni de couverture : refusé avant l'envoi.
    expect(find.text('Ajoutez une photo.'), findsOneWidget);
    sellerPromoPhotoOverride = () async => img;
    addTearDown(() => sellerPromoPhotoOverride = null);
    await show(tester, 'Choisir une photo', delta: -200.0);
    await tester.tap(find.text('Choisir une photo'));
    await tester.pumpAndSettle();
    await show(tester, 'Envoyer pour validation');
    await tester.tap(find.text('Envoyer pour validation'));
    await tester.pumpAndSettle();
    expect(find.text('3 publicités au plus en même temps.'), findsOneWidget);
  });
}
