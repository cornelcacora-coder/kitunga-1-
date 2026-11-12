import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/auth/firebase_auth/auth_util.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/backend/kitunga_notifications.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_deliverer_panel.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_live_tracking.dart';
import 'package:kitunga/mobile/deliverer/kitunga_deliverer_home.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

OrdersRecord order(String id, String status,
        {String deliverer = '', String zone = 'Bacongo', DateTime? at}) =>
    OrdersRecord.getDocumentFromData({
      'status': status,
      'delivery_zone': zone,
      'delivery_fees': 1000,
      'deliverer_ref': deliverer,
      'order_unique_reference': 'K-$id',
      'created_at': at ?? DateTime.now(),
    }, _Ref('Orders/$id'));

/// Accueil du livreur : chiffres, états, nouvelles courses.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  late StreamController<Map<String, dynamic>> state;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    trackingTestMode = true;
    notificationsBackendOverride =
        (n, d) async => {'notifications': [], 'unread': 0};
    delivererBackendOverride = (n, d) async {
      calls.add((n, d));
      return {'ok': true};
    };
    currentUserDocument = UserRecord.getDocumentFromData(
        {'display_name': 'OKOMBI Serge', 'role': 'Deliver', 'verified': true},
        _Ref('User/me'));
  });

  setUp(() {
    calls.clear();
    state = StreamController<Map<String, dynamic>>.broadcast();
    delivererStateOverride = state.stream;
    delivererMyOrdersOverride = Stream.value([
      order('a', 'Livrer', deliverer: 'me'),
      order('b', 'Reçu', deliverer: 'me'),
      order('c', 'Annulée', deliverer: 'me'),
      order('d', 'Livrer', deliverer: 'me',
          at: DateTime.now().subtract(const Duration(days: 3))),
    ]);
    delivererOpenOrdersOverride = Stream.value([
      order('x', 'Pret', zone: 'Bacongo'),
      order('y', 'Pret', zone: 'Mfilou'),
    ]);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: KitungaDelivererHome())));
    await tester.pump();
  }

  testWidgets('en service : chiffres du jour, courses de mes quartiers',
      (tester) async {
    await open(tester);
    state.add({
      'delivery_available': true,
      'delivery_state': 'on',
      'delivery_zones': ['Bacongo']
    });
    await tester.pumpAndSettle();
    expect(find.text('Bonjour, OKOMBI 👋'), findsOneWidget);
    expect(find.text('Livreur vérifié'), findsOneWidget);
    expect(find.text('En service'), findsOneWidget);
    // Aujourd'hui : 2 courses livrées, 2000 F de frais.
    expect(find.textContaining('2 000 F'), findsOneWidget);
    // Seule la course de Bacongo est proposée.
    expect(find.text('Accepter la course'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // livrées au total
    expect(find.text('Dernières courses'), findsOneWidget);
    expect(find.text('Besoin d\'aide ?'), findsOneWidget);
  });

  testWidgets('en pause : pas de nouvelle course ; reprise du service',
      (tester) async {
    await open(tester);
    state.add({'delivery_available': false, 'delivery_state': 'pause'});
    await tester.pumpAndSettle();
    expect(find.text('Vous êtes en pause'), findsOneWidget);
    expect(find.text('Accepter la course'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('deliverer-state-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('state-on')));
    await tester.pumpAndSettle();
    expect(calls.single.$2, {'state': 'on'});
  });

  testWidgets('hors service', (tester) async {
    await open(tester);
    state.add({'delivery_available': false});
    await tester.pumpAndSettle();
    expect(find.text('Vous êtes hors service'), findsOneWidget);
  });
}
