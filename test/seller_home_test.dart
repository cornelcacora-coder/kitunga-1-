import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/auth/firebase_auth/auth_util.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/backend/kitunga_notifications.dart';
import 'package:kitunga/mobile/components/shop_card_kitunga/kitunga_shop_card.dart'
    show kitungaShopStatus;
import 'package:kitunga/mobile/seller/kitunga_seller_actions.dart';
import 'package:kitunga/mobile/seller/kitunga_seller_home.dart';
import 'package:kitunga/mobile/seller/kitunga_seller_pro.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

OrdersRecord order(String id, String status, {Map<String, dynamic>? extra}) =>
    OrdersRecord.getDocumentFromData({
      'status': status,
      'total_amount': 6000,
      'delivery_fees': 1000,
      'delivery_zone': 'Bacongo',
      'order_unique_reference': 'K-$id',
      'created_at': DateTime.now(),
      ...?extra,
    }, _Ref('Orders/$id'));

/// Accueil vendeur, actions sur les commandes, pages pro.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  final shop = UserRecord.getDocumentFromData({
    'display_name': 'Chez Mado',
    'category': 'Restaurant',
    'role': 'Seller',
    'verified': true,
    'shop_rating_sum': 9,
    'shop_rating_count': 2,
  }, _Ref('User/shop'));

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    notificationsBackendOverride =
        (n, d) async => {'notifications': [], 'unread': 0};
    currentUserDocument = shop;
    sellerBackendOverride = (n, d) async {
      calls.add((n, d));
      switch (n) {
        case 'kitungaSellerPerformance':
          return {
            'delivered': 4, 'refusalRate': 20, 'revenue': 20000,
            'averageBasket': 5000, 'averagePrepMinutes': 18,
            'monthEarnings': 20000,
            'salesByDay': [
              for (var i = 6; i >= 0; i--)
                {'day': DateTime.now()
                    .subtract(Duration(days: i))
                    .toIso8601String()
                    .substring(0, 10), 'amount': i == 0 ? 5000 : 1000}
            ],
            'topProducts': [{'name': 'Poulet braisé', 'quantity': 7}],
            'lowStock': [{'id': 'p1', 'name': 'Pain', 'quantity': 2}],
          };
        case 'kitungaSellerStockMovements':
          return {'movements': []};
        case 'kitungaSellerReviews':
          return {'rating': 4.5, 'count': 2, 'reviews': [
            {'orderId': 'o1', 'reference': 'K-1', 'stars': 2,
              'comment': 'Froid', 'reported': false},
          ]};
        case 'kitungaSellerAdjustStock':
          return {'before': 2, 'after': 12};
      }
      return {'ok': true};
    };
  });
  setUp(() {
    calls.clear();
    // Flux recréés à chaque test (un flux ne s'écoute qu'une fois).
    sellerShopOverride = Stream.value(shop);
    sellerProductsOverride = Stream.value([
      ProductRecord.getDocumentFromData(
          {'name': 'Pain', 'quantity': 0, 'on_sale': true}, _Ref('Product/p1')),
      ProductRecord.getDocumentFromData(
          {'name': 'Riz', 'quantity': 3, 'on_sale': true}, _Ref('Product/p2')),
    ]);
  });

  Future<void> big(WidgetTester t) async {
    t.view.physicalSize = const Size(900, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('accueil : chiffres, alertes, accepter, refuser',
      (tester) async {
    await big(tester);
    sellerOrdersOverride = Stream.value([
      order('a', 'En attente'),
      order('b', 'En préparation', extra: {
        'prep_minutes': 10,
        'accepted_at': DateTime.now().subtract(const Duration(minutes: 25)),
      }),
      order('c', 'encours', extra: {'deliverer_ref': 'l1', 'at_shop_at': 1}),
      order('d', 'Livrer'),
    ]);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: KitungaSellerHome())));
    await tester.pumpAndSettle();
    expect(find.text('Chez Mado'), findsOneWidget);
    expect(find.text('Ouvert'), findsOneWidget);
    expect(find.textContaining('5 000 F'), findsWidgets);
    expect(find.text('1 en retard'), findsOneWidget);
    expect(find.text('1 en rupture'), findsOneWidget);
    expect(find.text('1 stock bas'), findsOneWidget);
    expect(find.textContaining('Le livreur est arrivé'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('accept-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prep-20')));
    await tester.pumpAndSettle();
    expect(calls.last.$2,
        {'orderId': 'a', 'action': 'accept', 'prepMinutes': 20});

    await tester.tap(find.byKey(const ValueKey('refuse-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produit en rupture'));
    await tester.tap(find.byKey(const ValueKey('refuse-confirm')));
    await tester.pumpAndSettle();
    expect(calls.last.$2,
        {'orderId': 'a', 'action': 'refuse', 'reason': 'Produit en rupture'});

    await tester.tap(find.byKey(const ValueKey('ready-b')));
    await tester.pumpAndSettle();
    expect(calls.last.$2['action'], 'ready');
    await tester.tap(find.byKey(const ValueKey('handover-c')));
    await tester.pumpAndSettle();
    expect(calls.last.$2['action'], 'handover');
  });

  testWidgets('état du commerce : pause', (tester) async {
    await big(tester);
    sellerOrdersOverride = Stream.value(const []);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: KitungaSellerHome())));
    await tester.pumpAndSettle();
    expect(find.text('Aucune nouvelle commande'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shop-state-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-pause')));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'kitungaSellerSetOpen');
    expect(calls.single.$2, {'state': 'pause'});
  });

  testWidgets('performances, avis, stock', (tester) async {
    await big(tester);
    await tester.pumpWidget(const MaterialApp(home: SellerPerformancePage()));
    await tester.pumpAndSettle();
    expect(find.text('Poulet braisé'), findsOneWidget);
    expect(find.text('18 min'), findsOneWidget);
    expect(find.text('20 %'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SellerReviewsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Froid'), findsOneWidget);
    expect(find.text('Signaler'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SellerStockPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stock-p1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('stock-qty')), '10');
    await tester.tap(find.byKey(const ValueKey('stock-save')));
    await tester.pumpAndSettle();
    final a = calls.firstWhere((c) => c.$1 == 'kitungaSellerAdjustStock');
    expect(a.$2['kind'], 'in');
    expect(a.$2['quantity'], 10);
  });

  test('client : commerce en pause ou fermé pour le moment', () {
    UserRecord shopWith(Map<String, dynamic> d) =>
        UserRecord.getDocumentFromData(
            {'Horraire': 'Tous les jours 00h00-23h59', ...d},
            _Ref('User/s'));
    expect(kitungaShopStatus(shopWith({'shop_state': 'pause'}))!.label,
        'En pause');
    expect(kitungaShopStatus(shopWith({'shop_closed_now': true}))!.open,
        isFalse);
    // Sans décision du vendeur : d'après les horaires (pas de boucle).
    expect(kitungaShopStatus(shopWith({})), isNotNull);
  });
}
