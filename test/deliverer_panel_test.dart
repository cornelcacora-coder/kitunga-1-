import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_deliverer_panel.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Livreur : en service, quartiers ; contacts d'une commande.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    delivererBackendOverride = (name, data) async {
      calls.add((name, data));
      if (name == 'kitungaOrderContacts') {
        return {
          'contacts': [
            {'role': 'client', 'name': 'Awa', 'phone': '+242 06 123 45 67'},
            {'role': 'commerce', 'name': 'Chez Mado', 'phone': '055554433'},
          ]
        };
      }
      return {'ok': true};
    };
  });
  setUp(calls.clear);

  test('quartiers couverts et numéros', () {
    expect(delivererCovers([], 'Bacongo'), isTrue);
    expect(delivererCovers(['Bacongo'], 'Bacongo'), isTrue);
    expect(delivererCovers(['Mfilou'], 'Bacongo'), isFalse);
    expect(phoneDigits('+242 06 123 45 67'), '242061234567');
    expect(phoneDigits('061234567'), '242061234567');
    expect(kDeliveryZones, contains('Poto-Poto'));
  });

  testWidgets('le livreur passe en service et choisit ses quartiers',
      (tester) async {
    final state = StreamController<Map<String, dynamic>>.broadcast();
    delivererStateOverride = state.stream;
    addTearDown(() => delivererStateOverride = null);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DelivererStateBuilder(
            builder: (_, s) => KitungaDelivererPanel(state: s)),
      ),
    ));
    state.add({'delivery_available': false});
    await tester.pumpAndSettle();
    expect(find.text('Hors service'), findsOneWidget);
    expect(find.text('Mes quartiers : toute la ville'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('deliverer-available')));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'kitungaSetDelivererStatus');
    expect(calls.single.$2, {'available': true});
    state.add({'delivery_available': true, 'delivery_zones': []});
    await tester.pumpAndSettle();
    expect(find.text('En service'), findsOneWidget);

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Bacongo'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer (1)'));
    await tester.pumpAndSettle();
    expect(calls.last.$2, {
      'zones': ['Bacongo']
    });
    state.add({
      'delivery_available': true,
      'delivery_zones': ['Bacongo']
    });
    await tester.pumpAndSettle();
    expect(find.text('Mes quartiers : Bacongo'), findsOneWidget);
    await state.close();
  });

  testWidgets('contacts : appeler ou écrire sur WhatsApp', (tester) async {
    final order = OrdersRecord.getDocumentFromData(
        {'status': 'encours'}, _Ref('Orders/o1'));
    expect(KitungaOrderContacts.showsFor(order), isTrue);
    expect(
        KitungaOrderContacts.showsFor(OrdersRecord.getDocumentFromData(
            {'status': 'Reçu'}, _Ref('Orders/o2'))),
        isFalse);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: KitungaOrderContacts(order: order))));
    await tester.pumpAndSettle();
    expect(calls.single.$2, {'orderId': 'o1'});
    expect(find.textContaining('Awa', findRichText: true), findsOneWidget);
    expect(find.textContaining('Chez Mado', findRichText: true), findsOneWidget);
    expect(find.byTooltip('Appeler'), findsNWidgets(2));
    expect(find.byTooltip('WhatsApp'), findsNWidgets(2));
  });
}
