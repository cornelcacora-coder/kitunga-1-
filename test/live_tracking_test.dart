import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_deliverer_panel.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_live_tracking.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Suivi en direct (client) et course en cours (livreur).
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  var tracking = <String, dynamic>{};

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    trackingTestMode = true;
    Future<Map<String, dynamic>> backend(
        String name, Map<String, dynamic> data) async {
      calls.add((name, data));
      if (name == 'kitungaDeliveryTracking') return tracking;
      if (name == 'kitungaDeliveryStep') {
        tracking = {...tracking, 'pickedUpAt': '2026-11-12T10:20:00Z'};
      }
      if (name == 'kitungaOrderContacts') return {'contacts': []};
      return {'ok': true};
    }

    trackingBackendOverride = backend;
    delivererBackendOverride = backend;
  });
  setUp(() {
    calls.clear();
    tracking = {
      'status': 'encours',
      'zone': 'Bacongo',
      'shop': {'name': 'Chez Mado'},
      'deliverer': {'name': 'Jo', 'photo': ''},
      'position': {'lat': -4.28, 'lng': 15.25, 'at': DateTime.now().toIso8601String()},
    };
  });

  OrdersRecord order(String status) => OrdersRecord.getDocumentFromData({
        'status': status,
        'delivery_zone': 'Bacongo',
        'delivery_location': 'Rue 12, près du marché',
        'delivery_fees': 1000,
        'order_unique_reference': 'K-123',
        'created_at': DateTime(2026, 11, 12, 10, 5),
      }, _Ref('Orders/o1'));

  test('étapes selon l\'avancement', () {
    var s = trackingSteps({'status': 'Pret', 'zone': 'Bacongo'});
    expect(s.map((e) => e.done).toList(), [true, true, false, false, false]);
    expect(s[2].current, isTrue);
    s = trackingSteps({'status': 'encours', 'pickedUpAt': 'x'});
    expect(s.where((e) => e.done).length, 4);
    expect(s[4].current, isTrue);
    s = trackingSteps({'status': 'Livrer'});
    expect(s.every((e) => e.done), isTrue);
  });

  testWidgets('client : suivi en direct avec le livreur', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: KitungaLiveTrackingCard(order: order('encours'))))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Suivi de la livraison'), findsOneWidget);
    expect(find.text('En direct'), findsOneWidget);
    expect(find.text('Jo'), findsOneWidget);
    expect(find.text('Le livreur va au commerce'), findsOneWidget);
    expect(find.textContaining('mise à jour à l\'instant'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('livreur : récupérer puis remettre', (tester) async {
    final stream = StreamController<OrdersRecord>.broadcast();
    await tester.pumpWidget(MaterialApp(
        home: DelivererMissionPage(
            orderRef: _Ref('Orders/o1'), stream: stream.stream)));
    stream.add(order('encours'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 1 · Récupérer la commande'), findsOneWidget);
    expect(find.text('Chez Mado'), findsWidgets);
    expect(find.text('1000 F'), findsOneWidget);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mission-picked-up')));
    await tester.pumpAndSettle();
    expect(calls.any((c) =>
        c.$1 == 'kitungaDeliveryStep' && c.$2['step'] == 'picked_up'), isTrue);
    expect(find.text('Étape 2 · Livrer le client'), findsOneWidget);
    expect(find.byKey(const ValueKey('mission-deliver')), findsOneWidget);
    await stream.close();
  });

  testWidgets('liste du livreur : carte de course', (tester) async {
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: KitungaCourseCard(
                order: order('Pret'),
                mine: false,
                onAction: () async => accepted = true))));
    expect(find.text('Prête à récupérer'), findsOneWidget);
    expect(find.text('Bacongo'), findsOneWidget);
    await tester.tap(find.text('Accepter la course'));
    expect(accepted, isTrue);
  });
}
