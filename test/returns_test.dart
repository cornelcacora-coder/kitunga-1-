import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/returns/kitunga_returns.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Retours et échanges : demande du client, décision du commerce.
void main() {
  const photo = 'https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fmarie%2Fp.jpg';
  final calls = <(String, Map<String, dynamic>)>[];
  OrdersRecord order(Map<String, dynamic> extra) =>
      OrdersRecord.getDocumentFromData({
        'status': 'Reçu',
        'user_ref': _Ref('User/marie'),
        'seller_ref': _Ref('User/mode'),
        'delivered_at': DateTime.now().subtract(const Duration(days: 2)),
        ...extra,
      }, _Ref('Orders/o1'));

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    returnsBackendOverride = (name, data) async {
      calls.add((name, data));
      return {'ok': true};
    };
    returnsPhotoOverride = () async => photo;
  });
  setUp(calls.clear);

  Future<void> open(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child))));
    await tester.pumpAndSettle();
  }

  test('retour possible : livrée, dans les 7 jours, pas déjà demandé', () {
    expect(kitungaReturnOpen(order({})), isTrue);
    expect(kitungaReturnOpen(order({'status': 'encours'})), isFalse);
    expect(kitungaReturnOpen(order({'return_status': 'requested'})), isFalse);
    expect(
        kitungaReturnOpen(order({
          'delivered_at': DateTime.now().subtract(const Duration(days: 9)),
        })),
        isFalse);
  });

  testWidgets('client : boutique, demande de remboursement avec photo',
      (tester) async {
    await open(tester,
        KitungaReturnSection(order: order({}), sellerCategory: 'Boutique'));
    await tester.tap(find.text('Retourner ou échanger un article'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez le motif du retour.'), findsOneWidget);
    await tester.tap(find.text('Taille ou pointure qui ne convient pas'));
    await tester.tap(find.text('Un remboursement'));
    await tester.tap(find.text('Photo de l\'article (facultatif)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Trop petit');
    await tester.ensureVisible(find.text('Envoyer la demande'));
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'kitungaRequestReturn');
    expect(calls.single.$2, {
      'orderId': 'o1', 'reason': 'size', 'wish': 'refund',
      'note': 'Trop petit', 'photos': [photo],
    });
  });

  testWidgets('restaurant : pas de retour proposé', (tester) async {
    await open(tester,
        KitungaReturnSection(order: order({}), sellerCategory: 'Restaurant'));
    expect(find.text('Retourner ou échanger un article'), findsNothing);
  });

  testWidgets('client : suivi d\'un retour refusé', (tester) async {
    await open(
        tester,
        KitungaReturnSection(
            order: order({'return_status': 'refused',
              'return_decision_note': 'Article porté'}),
            sellerCategory: 'Boutique'));
    expect(find.text('Retour refusé : Article porté'), findsOneWidget);
  });

  testWidgets('commerce : refuser avec motif, accepter', (tester) async {
    final o = order({'return_status': 'requested', 'return_reason': 'defect',
      'return_wish': 'refund', 'return_note': 'Couture ouverte',
      'return_photos': [photo]});
    expect(KitungaSellerReturnCard.showsFor(o), isTrue);
    await open(tester, KitungaSellerReturnCard(order: o));
    expect(find.text('Demande de retour · Remboursement'), findsOneWidget);
    expect(find.text('Motif : Article abîmé ou défectueux'), findsOneWidget);
    expect(find.text('Photo 1'), findsOneWidget);
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Article porté');
    await tester.tap(find.text('Refuser').last);
    await tester.pumpAndSettle();
    expect(calls.last.$1, 'kitungaDecideReturn');
    expect(calls.last.$2,
        {'orderId': 'o1', 'decision': 'refuse', 'note': 'Article porté'});
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(calls.last.$2, {'orderId': 'o1', 'decision': 'accept'});
    expect(tester.takeException(), isNull);
  });
}
