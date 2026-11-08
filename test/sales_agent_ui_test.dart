import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/sales/sales_common.dart';
import 'package:kitunga/sales/sales_home_widget.dart';

/// Espace commercial avec un serveur simulé (format téléphone).
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  var payoutMethodSet = true;

  Map<String, dynamic> fake(String function, Map<String, dynamic> data) {
    if (function == 'kitungaRequestPayout') return {'payoutId': 'p1'};
    switch (data['view']) {
      case 'home':
        return {
          'profile': {'agentCode': 'KTG001', 'displayName': 'Jean-Baptiste Mabiala',
            'status': 'active', 'payoutMethodSet': payoutMethodSet},
          'assignments': [
            {'campaignName': 'Lancement Brazzaville',
              'startsAt': '2026-10-31T23:00:00Z', 'endsAt': '2026-11-30T23:00:00Z',
              'referralCode': 'KTG001-X7P9',
              'link': 'https://kitunga-xtvpe4.web.app/r/KTG001-X7P9'},
          ],
          'period': {'start': '2026-10-31T23:00:00Z', 'end': '2026-11-20T12:00:00Z'},
          'stats': {'clicks': 312, 'activations': 87, 'signups': 54,
            'subscriptions': 12},
          'commissions': {'pending': 450, 'approved': 1200, 'reserved': 0,
            'paid': 3000},
        };
      case 'clients':
        return {'clients': [
          {'name': 'Marie M.', 'signedUpAt': '2026-11-18T10:00:00Z',
            'subscribed': true, 'status': 'confirmed'},
          {'name': 'Paul', 'signedUpAt': '2026-11-19T10:00:00Z',
            'subscribed': false, 'status': 'rejected'},
        ]};
    }
    return {};
  }

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    salesBackendOverride = (function, data) async {
      calls.add((function, data));
      return fake(function, data);
    };
  });

  setUp(() {
    calls.clear();
    payoutMethodSet = true;
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 860);
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
      home: SalesHomeWidget(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('accueil : campagne, QR code, chiffres et soldes', (tester) async {
    await open(tester);
    expect(find.text('Jean-Baptiste Mabiala'), findsOneWidget);
    expect(find.text('Lancement Brazzaville'), findsOneWidget);
    expect(find.text('KTG001-X7P9'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    await tester.ensureVisible(find.text('Demander un versement'));
    await tester.pumpAndSettle();
    expect(find.text('1\u202f200 F'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demande de versement envoyée', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Demander un versement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demander un versement'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.$1 == 'kitungaRequestPayout'), hasLength(1));
  });

  testWidgets('sans moyen de paiement : demande impossible', (tester) async {
    payoutMethodSet = false;
    await open(tester);
    await tester.ensureVisible(find.text('Demander un versement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demander un versement'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.$1 == 'kitungaRequestPayout'), isEmpty);
    expect(find.textContaining('moyen de paiement'), findsOneWidget);
  });

  testWidgets('mes clients : informations limitées', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Mes clients'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes clients'));
    await tester.pumpAndSettle();
    expect(find.text('Marie M.'), findsOneWidget);
    expect(find.textContaining('Non retenu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
