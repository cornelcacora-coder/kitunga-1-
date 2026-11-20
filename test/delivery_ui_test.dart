import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/backend/server_payment.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_delivery.dart';
import 'package:kitunga/noc/ui/admin_export.dart';

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

/// Remise par code et reçu, avec un serveur simulé.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  final receipt = {
    'number': 'KTG-2026-000001',
    'orderReference': 'ORD-1',
    'orderedAt': '2026-11-08T10:00:00Z',
    'deliveredAt': '2026-11-08T10:45:00Z',
    'codeVerified': true,
    'client': {'name': 'Marie'},
    'seller': {'name': 'Le Crisp\'nCroc'},
    'deliverer': 'Jean',
    'address': 'Poto-Poto · Rue 12',
    'lines': [
      {'name': 'Poulet braisé', 'options': 'Accompagnement : Frites',
        'quantity': 2, 'unitPrice': 2500, 'total': 5000},
    ],
    'subtotal': 5000,
    'deliveryFees': 1000,
    'total': 6000,
    'payment': {'method': 'MTN Mobile Money', 'reference': 'MTN-123'},
  };
  final order = OrdersRecord.getDocumentFromData(
      {'status': 'encours', 'user_ref': _Ref('User/marie')},
      _Ref('Orders/o1'));

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    deliveryBackendOverride = (name, data) async {
      calls.add((name, data));
      switch (name) {
        case 'kitungaDeliveryCode':
          return {'code': '4821', 'locked': false};
        case 'kitungaConfirmDelivery':
          if (data['code'] != '4821') {
            throw ServerPaymentException('Code faux. Il reste 4 essais.');
          }
          return {'ok': true};
        case 'kitungaOrderReceipt':
          return receipt;
        case 'kitungaReportDeliveryIssue':
          return {'ok': true};
        case 'kitungaTakeDelivery':
          if (data['orderId'] == 'pris') {
            throw ServerPaymentException(
                'Cette commande a déjà été prise par un autre livreur.');
          }
          return {'ok': true};
      }
      return {};
    };
    deliveryPhotoOverride = () async =>
        'https://firebasestorage.googleapis.com/v0/b/x/o/p.jpg';
  });
  setUp(calls.clear);

  Future<void> open(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 860);
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
      home: Scaffold(body: home),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('client : le code de remise s\'affiche', (tester) async {
    await open(tester, KitungaDeliveryCodeCard(order: order));
    for (final c in ['4', '8', '2', '1']) {
      expect(find.text(c), findsOneWidget);
    }
    expect(find.textContaining('Ne le communiquez jamais'), findsOneWidget);
    expect(KitungaDeliveryCodeCard.showsFor(order, _Ref('User/marie')), isTrue);
    expect(KitungaDeliveryCodeCard.showsFor(order, _Ref('User/autre')), isFalse);
  });

  testWidgets('livreur : code et photo obligatoires, code faux, réussite',
      (tester) async {
    bool? result;
    await open(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await kitungaCompleteDelivery(context, order),
            child: const Text('Terminer'),
          ),
        ));
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer la remise'));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez les 4 chiffres du client.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('Confirmer la remise'));
    await tester.pumpAndSettle();
    expect(find.text('Prenez une photo de la remise.'), findsOneWidget);
    await tester.tap(find.text('Photographier la remise'));
    await tester.pumpAndSettle();
    expect(find.text('Photo prise (reprendre)'), findsOneWidget);
    await tester.tap(find.text('Confirmer la remise'));
    await tester.pumpAndSettle();
    expect(find.text('Code faux. Il reste 4 essais.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '4821');
    await tester.tap(find.text('Confirmer la remise'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(calls.last.$1, 'kitungaConfirmDelivery');
    expect(calls.last.$2['code'], '4821');
    expect(calls.last.$2['photoUrl'], startsWith('https://'));
  });

  testWidgets('livreur : accepter, ou commande déjà prise', (tester) async {
    final taken = OrdersRecord.getDocumentFromData(
        {'status': 'Pret'}, _Ref('Orders/pris'));
    final results = <bool>[];
    await open(
        tester,
        Builder(
          builder: (context) => Column(children: [
            TextButton(
              onPressed: () async =>
                  results.add(await kitungaTakeDelivery(context, order)),
              child: const Text('Accepter'),
            ),
            TextButton(
              onPressed: () async =>
                  results.add(await kitungaTakeDelivery(context, taken)),
              child: const Text('Accepter 2'),
            ),
          ]),
        ));
    await tester.tap(find.text('Accepter'));
    await tester.pump();
    expect(find.text('Commande prise en charge. Bonne route !'),
        findsOneWidget);
    expect(calls.last.$2['orderId'], 'o1');
    await tester.tap(find.text('Accepter 2'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Cette commande a déjà été prise par un autre livreur.'),
        findsOneWidget);
    expect(results, [true, false]);
  });

  testWidgets('livreur : signaler un client injoignable', (tester) async {
    await open(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => kitungaCompleteDelivery(context, order),
            child: const Text('Terminer'),
          ),
        ));
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Problème'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(calls.last.$1, 'kitungaReportDeliveryIssue');
    expect(calls.last.$2['type'], 'absent');
  });

  testWidgets('reçu : numéro, articles, totaux, paiement', (tester) async {
    await open(tester, const KitungaReceiptPage(orderId: 'o1'));
    expect(find.text('N° KTG-2026-000001'), findsOneWidget);
    expect(find.text('Remise confirmée par code'), findsOneWidget);
    expect(find.text('2 × Poulet braisé'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('6 000 F'), findsOneWidget);
    expect(find.text('MTN-123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('reçu PDF : fichier valide', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await buildReceiptPdf(receipt);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
