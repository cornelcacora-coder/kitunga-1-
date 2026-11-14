import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_exact_point.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_live_tracking.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_deliverer_panel.dart';
import 'package:kitunga/mobile/deliverer/kitunga_deliverer_pro.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

/// Position exacte : bouton, et destination du livreur.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    trackingTestMode = true;
  });

  test('Brazzaville seulement ; lecture des positions du serveur', () {
    expect(inBrazzaville(-4.27, 15.27), isTrue);
    expect(inBrazzaville(48.85, 2.35), isFalse);
    expect(exactPointOf({'lat': -4.28, 'lng': 15.25})!.latitude, -4.28);
    expect(exactPointOf(null), isNull);
  });

  testWidgets('localiser, refus hors de la ville, retirer', (tester) async {
    Map<String, double>? point;
    var where = (lat: -4.2930, lng: 15.2560, accuracy: 8.0);
    exactPointOverride = () async => where;
    addTearDown(() => exactPointOverride = null);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (c, set) => KitungaExactPointButton(
              point: point, onChanged: (p) => set(() => point = p)),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('exact-point-locate')));
    await tester.pumpAndSettle();
    expect(point, {'lat': -4.2930, 'lng': 15.2560});
    expect(find.text('Position exacte enregistrée'), findsOneWidget);
    expect(find.text('Précision ± 8 m.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exact-point-clear')));
    await tester.pumpAndSettle();
    expect(point, isNull);
    where = (lat: 5.3, lng: -4.0, accuracy: 5.0); // Abidjan
    await tester.tap(find.byKey(const ValueKey('exact-point-locate')));
    await tester.pumpAndSettle();
    expect(point, isNull);
    expect(find.text('Cette position est hors de Brazzaville.'),
        findsOneWidget);
  });

  testWidgets('livreur : itinéraire vers le commerce puis vers le client',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var picked = false;
    Future<Map<String, dynamic>> backend(String n, Map<String, dynamic> d) async =>
        n == 'kitungaDeliveryTracking'
            ? {
                'status': 'encours',
                'zone': 'Bacongo',
                'shop': {'name': 'Mado'},
                'shopPoint': {'lat': -4.2805, 'lng': 15.2560},
                'deliveryPoint': {'lat': -4.2930, 'lng': 15.2560},
                if (picked) 'pickedUpAt': '2026-11-14T10:00:00Z',
              }
            : {'ok': true};
    trackingBackendOverride = backend;
    delivererBackendOverride = backend;
    addTearDown(() {
      trackingBackendOverride = null;
      delivererBackendOverride = null;
    });
    final stream = StreamController<OrdersRecord>.broadcast();
    await tester.pumpWidget(MaterialApp(
        home: DelivererMissionPage(
            orderRef: _Ref('Orders/o1'), stream: stream.stream)));
    stream.add(OrdersRecord.getDocumentFromData(
        {'status': 'encours', 'delivery_zone': 'Bacongo'}, _Ref('Orders/o1')));
    await tester.pumpAndSettle();
    expect(find.text('Itinéraire vers le commerce'), findsOneWidget);
    picked = true;
    await tester.tap(find.byKey(const ValueKey('mission-picked-up')));
    await tester.pumpAndSettle();
    expect(find.text('Itinéraire vers le client'), findsOneWidget);
    await stream.close();
    // Distance porte à porte : ≈ 1,4 km → environ 7 min.
    final m = etaMinutes(exactPointOf({'lat': -4.2805, 'lng': 15.2560})!,
        exactPointOf({'lat': -4.2930, 'lng': 15.2560})!);
    expect(m, inInclusiveRange(5, 9));
    expect(proBackendOverride, isNull);
  });
}
