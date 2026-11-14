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

/// Itinéraire réel affiché ; estimation dite comme telle sans service.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    trackingTestMode = true;
  });

  test('itinéraire du serveur pour la bonne destination seulement', () {
    final t = {
      'route': {
        'target': 'shop', 'minutes': 35, 'km': 9.6, 'traffic': true,
        'polyline': [
          {'lat': -4.27, 'lng': 15.27},
          {'lat': -4.28, 'lng': 15.25},
        ],
      }
    };
    final r = routeOf(t, 'shop')!;
    expect(r.minutes, 35);
    expect(r.points.length, 2);
    expect(routeOf(t, 'client'), isNull);
    expect(routeOf(null, 'shop'), isNull);
  });

  Future<void> mission(WidgetTester tester, Map<String, dynamic> t) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<Map<String, dynamic>> backend(String n, Map<String, dynamic> d) async =>
        n == 'kitungaDeliveryTracking' ? t : {'ok': true};
    trackingBackendOverride = backend;
    delivererBackendOverride = backend;
    addTearDown(() {
      trackingBackendOverride = null;
      delivererBackendOverride = null;
    });
    final stream = StreamController<OrdersRecord>.broadcast();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
        home: DelivererMissionPage(
            orderRef: _Ref('Orders/o1'), stream: stream.stream)));
    stream.add(OrdersRecord.getDocumentFromData(
        {'status': 'encours', 'delivery_zone': 'Mfilou'}, _Ref('Orders/o1')));
    await tester.pumpAndSettle();
  }

  testWidgets('livreur : distance et minutes par la route, circulation',
      (tester) async {
    await mission(tester, {
      'status': 'encours', 'zone': 'Mfilou', 'shop': {'name': 'Mado'},
      'route': {'target': 'shop', 'minutes': 35, 'km': 9.6, 'traffic': true,
        'polyline': []},
    });
    expect(find.textContaining('9,6 km par la route · 35 min '
        '(circulation comprise)'), findsOneWidget);
  });

  testWidgets('sans service d\'itinéraire : « Estimation »', (tester) async {
    await mission(tester, {
      'status': 'encours', 'zone': 'Mfilou', 'shop': {'name': 'Mado'},
    });
    // Sans position GPS du livreur (tests) ni route : rien d'inventé.
    expect(find.textContaining('par la route'), findsNothing);
  });
}
