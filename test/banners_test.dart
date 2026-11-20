import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/kitunga_banners.dart';
import 'package:kitunga/noc/admin/admin_banners_widget.dart';
import 'package:kitunga/noc/admin/admin_shell.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Publicités et promotions : page admin et bannières de l'application.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  const img = 'https://firebasestorage.googleapis.com/v0/b/x/o/pub.png';
  final banners = [
    {'id': 'b1', 'kind': 'app', 'title1': 'Livraison', 'title2': 'rapide',
      'subtitle': 'Recevez vos commandes', 'button': 'Découvrir', 'badge': '',
      'image': 'asset:assets/images/youngAfrican.jpg', 'color': '#E51A1A',
      'accent': '#FFD200', 'target': {'type': 'shops', 'value': ''},
      'order': 0, 'active': true, 'status': 'live', 'clicks': 12,
      'sellerUid': '', 'sellerName': ''},
    {'id': 'b2', 'kind': 'seller', 'title1': 'Le Crisp\'nCroc',
      'title2': '-20 %', 'subtitle': 'Sur les couscous', 'button': 'Commander',
      'badge': 'PROMO', 'image': img, 'color': '#C2185B', 'accent': '#FFFFFF',
      'target': {'type': 'shop', 'value': 'crisp'}, 'order': 1,
      'active': false, 'status': 'off', 'clicks': 3, 'sellerUid': 'crisp',
      'sellerName': 'Le Crisp\'nCroc', 'startsAt': '2026-12-01T00:00:00Z',
      'endsAt': '2026-12-24T22:59:59Z'},
  ];

  (String, Map<String, dynamic>) last(String f) =>
      calls.lastWhere((c) => c.$1 == f);

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    salesBackendOverride = (function, data) async {
      calls.add((function, data));
      return switch (function) {
        'kitungaListBanners' => {'banners': banners},
        'kitungaCatalogQuery' => switch (data['view']) {
            'partners' => {'partners': [
                {'uid': 'crisp', 'displayName': 'Le Crisp\'nCroc',
                  'category': 'Restaurant'},
              ]},
            'categories' => {'categories': [
                {'id': 'c1', 'name': 'Restaurant'},
                {'id': 'c2', 'name': 'Boutique'},
              ]},
            _ => {'products': []},
          },
        _ => {'ok': true, 'id': 'new'},
      };
    };
    adminImagePickerOverride = () async => img;
    adminPendingOrders = () => Stream.value(0);
    adminDisplayName = () => 'Admin';
  });
  setUp(calls.clear);

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('fr'),
      supportedLocales: [Locale('fr')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AdminBannersWidget(),
    ));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(1440, 1000), Size(400, 860)]) {
    final w = size.width.toInt();
    testWidgets('admin : voir, filtrer, activer, réordonner ($w px)',
        (tester) async {
      await open(tester, size);
      expect(find.text('Publicités & promotions'), findsWidgets);
      expect(find.text('Promotion Kitunga'), findsOneWidget);
      expect(find.text('Publicité · Le Crisp\'nCroc'), findsOneWidget);
      expect(find.text('Désactivée'), findsWidgets);
      expect(find.text('12 clics'), findsOneWidget);
      expect(find.text('Du 1 déc. 2026 au 24 déc. 2026'), findsOneWidget);
      expect(find.text('Clic : Vitrine de Le Crisp\'nCroc'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Activer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Activer'));
      await tester.pumpAndSettle();
      expect(last('kitungaSetBannerActive').$2, {'id': 'b2', 'active': true});

      await tester.ensureVisible(find.byTooltip('Descendre').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Descendre').first);
      await tester.pumpAndSettle();
      expect(last('kitungaReorderBanners').$2, {'ids': ['b2', 'b1']});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('admin : nouvelle bannière avec aperçu et contrôles',
      (tester) async {
    await open(tester, const Size(1440, 1000));
    await tester.tap(find.text('Nouvelle bannière'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'Fête');
    await tester.enterText(fields.at(1), 'des mères');
    await tester.pumpAndSettle();
    // L'aperçu suit la saisie.
    expect(find.text('des mères'), findsWidgets);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Ajoutez une image.'), findsOneWidget);
    await tester.tap(find.text('Publicité d\'un commerce'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ajouter une image').first);
    await tester.tap(find.text('Ajouter une image').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez le commerce annonceur.'), findsOneWidget);
    await tester.ensureVisible(find.text('Commerce annonceur'));
    await tester.tap(find.text('Commerce annonceur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Le Crisp\'nCroc · Restaurant').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final saved = last('kitungaSaveBanner').$2;
    expect(saved['kind'], 'seller');
    expect(saved['sellerUid'], 'crisp');
    expect(saved['title2'], 'des mères');
    expect(saved['image'], img);
    expect(saved['target'], {'type': 'shop', 'value': 'crisp'});
    expect(saved['startsAt'], isNull);
    expect(tester.takeException(), isNull);
  });

  test('application : bannières du serveur, jamais les anciennes au démarrage',
      () async {
    final store = KitungaBannerStore.instance..resetForTest();
    // Au démarrage : aucune ancienne image, zone d'attente.
    expect(store.list, isEmpty);
    expect(store.waiting, isTrue);
    KitungaBannerStore.fetchOverride = () async => {'banners': [
          banners[1],
          {'id': 'x', 'title1': '', 'title2': '', 'image': img}, // inutilisable
        ]};
    addTearDown(() => KitungaBannerStore.fetchOverride = null);
    await store.reload();
    expect(store.waiting, isFalse);
    final b = store.list.single;
    expect(b.title2, '-20 %');
    expect(b.badge, 'PROMO');
    expect(b.color, const Color(0xFFC2185B));
    expect(b.targetType, 'shop');
    expect(b.targetValue, 'crisp');
    // Image incluse dans l'application.
    expect(kitungaBannerFromServer(banners[0])!.image,
        'assets/images/youngAfrican.jpg');
    // Tout désactivé : plus de carrousel.
    KitungaBannerStore.fetchOverride = () async => {'banners': []};
    await store.reload();
    expect(store.list, isEmpty);
    // Hors connexion : on garde ce qu'on a.
    KitungaBannerStore.fetchOverride = () async => throw 'hors ligne';
    await store.reload();
    expect(store.list, isEmpty);
    store.resetForTest();
  });

  test('application : dernières bannières gardées sur le téléphone',
      () async {
    SharedPreferences.setMockInitialValues({
      'kitunga_banners_cache': jsonEncode([banners[1]]),
    });
    final store = KitungaBannerStore.instance..resetForTest(readCache: true);
    expect(store.list, isEmpty); // lecture de la copie locale lancée
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.list.single.title2, '-20 %');
    expect(store.waiting, isFalse);
    store.resetForTest();
  });
}
