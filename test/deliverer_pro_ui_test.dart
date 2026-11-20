import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_delivery.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_live_tracking.dart';
import 'package:kitunga/mobile/components/finance/kitunga_earnings.dart';
import 'package:kitunga/mobile/deliverer/kitunga_deliverer_pro.dart';
import 'package:kitunga/noc/admin/admin_documents_dialog.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

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

/// Espace professionnel du livreur et ses liens avec client et admin.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  Future<Map<String, dynamic>> backend(
      String n, Map<String, dynamic> d) async {
    calls.add((n, d));
    switch (n) {
      case 'kitungaMyDocuments':
        return {
          'verification': 'missing',
          'documents': [
            {'type': 'identity', 'label': 'Pièce d\'identité',
              'required': true, 'status': 'missing', 'number': '',
              'rejectReason': ''},
            {'type': 'license', 'label': 'Permis de conduire',
              'required': true, 'status': 'rejected', 'number': 'P1',
              'rejectReason': 'Photo floue'},
          ]
        };
      case 'kitungaMyPerformance':
        return {'delivered': 12, 'successRate': 92, 'acceptanceRate': 80,
          'averageMinutes': 28, 'distanceKm': 41.5, 'monthEarnings': 15000,
          'weeklyEarnings': [0, 0, 2000, 3000, 0, 1000, 4000, 5000],
          'rating': 4.7, 'ratingCount': 9, 'cancelledByOthers': 2};
      case 'kitungaMyEarnings':
        return {'balance': 3000, 'today': 1000, 'week': 3000,
          'month': 3000, 'total': 3000, 'paidOut': 0,
          'settings': {'deliverer_share': 1}, 'entries': []};
      case 'kitungaMyWithdrawals':
        return {'withdrawals': []};
      case 'kitungaAdminDocuments':
        return {
          'documents': [
            {'id': 'l1_identity', 'name': 'Jo', 'label': 'Pièce d\'identité',
              'status': 'pending', 'number': 'CNI-1', 'photoUrl': 'x',
              'rejectReason': ''},
          ]
        };
      case 'kitungaDeliveryTracking':
        return {'status': 'encours', 'zone': 'Bacongo',
          'shop': {'name': 'Mado'}};
    }
    return {'ok': true, 'alertId': 'a1'};
  }

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    trackingTestMode = true;
    proBackendOverride = backend;
    proPhotoOverride = () async => 'https://firebasestorage.googleapis.com/'
        'v0/b/x/o/documents%2Fme%2Fa.jpg';
    earningsBackendOverride = backend;
    deliveryBackendOverride = backend;
    trackingBackendOverride = backend;
    salesBackendOverride = backend;
  });
  setUp(calls.clear);

  Future<void> big(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('documents : état, refus motivé, dépôt', (tester) async {
    await big(tester);
    await tester.pumpWidget(
        const MaterialApp(home: DelivererDocumentsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Documents à compléter'), findsOneWidget);
    expect(find.textContaining('motif : Photo floue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doc-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doc-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doc-send')));
    await tester.pumpAndSettle();
    final c = calls.firstWhere((c) => c.$1 == 'kitungaSubmitDocument');
    expect(c.$2['type'], 'identity');
    expect('${c.$2['photoUrl']}', contains('documents%2F'));
  });

  testWidgets('performances : note, taux, graphique', (tester) async {
    await big(tester);
    await tester.pumpWidget(
        const MaterialApp(home: DelivererPerformancePage()));
    await tester.pumpAndSettle();
    expect(find.text('4.7 / 5'), findsOneWidget);
    expect(find.text('92 %'), findsOneWidget);
    expect(find.text('28 min'), findsOneWidget);
    expect(find.textContaining('ne vous sont pas imputées'), findsOneWidget);
  });

  testWidgets('alerte : envoyée seulement après confirmation', (tester) async {
    await big(tester);
    await tester.pumpWidget(const MaterialApp(home: DelivererSafetyPage()));
    await tester.tap(find.byKey(const ValueKey('sos-accident')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.$1 == 'kitungaSafetyAlert'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('sos-confirm')));
    await tester.pumpAndSettle();
    expect(calls.single.$2['kind'], 'accident');
    expect(find.textContaining('Alerte envoyée'), findsOneWidget);
  });

  testWidgets('gains : demande de retrait', (tester) async {
    await big(tester);
    await tester.pumpWidget(const MaterialApp(home: KitungaEarningsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Ce mois'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('withdraw-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('withdraw-amount')), '2000');
    await tester.tap(find.byKey(const ValueKey('withdraw-send')));
    await tester.pumpAndSettle();
    final w = calls.firstWhere((c) => c.$1 == 'kitungaRequestWithdrawal');
    expect(w.$2['amount'], 2000);
    expect(w.$2['method'], 'MoMo');
  });

  testWidgets('client : note du livreur', (tester) async {
    final order = OrdersRecord.getDocumentFromData({
      'status': 'Livrer',
      'user_ref': _Ref('User/client'),
      'deliverer_ref': 'l1',
    }, _Ref('Orders/o1'));
    expect(KitungaRateDeliverer.showsFor(order, _Ref('User/client')), isTrue);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: KitungaRateDeliverer(order: order))));
    await tester.tap(find.byKey(const ValueKey('star-4')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rate-send')));
    await tester.pumpAndSettle();
    expect(calls.single.$2, {'orderId': 'o1', 'stars': 4, 'comment': ''});
    expect(find.text('Merci pour votre avis !'), findsOneWidget);
  });

  testWidgets('course : arrivé au commerce, retard', (tester) async {
    await big(tester);
    final stream = StreamController<OrdersRecord>.broadcast();
    await tester.pumpWidget(MaterialApp(
        home: DelivererMissionPage(
            orderRef: _Ref('Orders/o1'), stream: stream.stream)));
    stream.add(OrdersRecord.getDocumentFromData(
        {'status': 'encours', 'delivery_zone': 'Bacongo'},
        _Ref('Orders/o1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mission-at-shop')));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.$1 == 'kitungaArrivedAtShop'), isTrue);
    await tester.tap(find.byKey(const ValueKey('mission-delay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delay-20')));
    await tester.pumpAndSettle();
    expect(calls.firstWhere((c) => c.$1 == 'kitungaReportDelay').$2,
        {'orderId': 'o1', 'minutes': 20});
    expect(find.byKey(const ValueKey('mission-sos')), findsOneWidget);
    await stream.close();
  });

  testWidgets('admin : vérification d\'un document', (tester) async {
    await big(tester);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => showAdminDocuments(c),
                    child: const Text('ouvrir'))))));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pièce d\'identité · Jo'), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.$1 == 'kitungaAdminReviewDocument' &&
        c.$2['approve'] == true), isTrue);
  });
}
