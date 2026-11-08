import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/ops/admin_ops_widget.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Page « Gestion » avec un serveur simulé.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];

  Map<String, dynamic> fake(String function, Map<String, dynamic> data) {
    if (function != 'kitungaAdminOpsQuery') return {'ok': true};
    if (data['view'] == 'refunds') {
      return {'refunds': [
        {'orderId': 'o1', 'reference': 'ORD-1730-AB12', 'amount': 3500,
          'status': 'Annulée', 'refundStatus': 'À traiter manuellement',
          'refundError': 'Paiement non confirmé par MTN',
          'paymentReference': 'ref-mtn', 'updatedAt': '2026-11-07T10:00:00Z',
          'client': {'name': 'Marie Ngoma', 'phone': '061234567',
            'email': 'marie@test.cg'}},
      ]};
    }
    return {'accounts': [
      {'uid': 'marie', 'displayName': 'Marie Ngoma', 'email': 'marie@test.cg',
        'phone': '061234567', 'role': 'User', 'accountStatus': 'active',
        'subscribeCloseAt': '2026-10-01T00:00:00Z'},
      {'uid': 'shop', 'displayName': 'Boutique du marché', 'email': 'b@test.cg',
        'phone': '', 'role': 'Seller', 'accountStatus': 'suspended',
        'accountStatusReason': 'Fraude'},
    ]};
  }

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    salesBackendOverride = (function, data) async {
      calls.add((function, data));
      return fake(function, data);
    };
  });
  setUp(calls.clear);

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
      home: AdminOpsWidget(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'marie');
    await tester.tap(find.text('Chercher'));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(1280, 900), Size(400, 860)]) {
    testWidgets('trois onglets sans erreur (${size.width.toInt()} px)',
        (tester) async {
      await open(tester, size);
      expect(find.text('Marie Ngoma · 061234567'), findsOneWidget);
      await tester.tap(find.text('Abonnements'));
      await tester.pumpAndSettle();
      await search(tester);
      expect(find.textContaining('Abonnement terminé'), findsOneWidget);
      await tester.tap(find.text('Comptes'));
      await tester.pumpAndSettle();
      await search(tester);
      expect(find.text('Suspendu'), findsOneWidget);
      expect(find.text('Réactiver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('remboursement : référence envoyée au serveur', (tester) async {
    await open(tester, const Size(1280, 900));
    await tester.tap(find.text('Marquer remboursé'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'MP261108.1530.R1');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    final c = calls.where((c) => c.$1 == 'kitungaMarkRefunded').single;
    expect(c.$2, {'orderId': 'o1', 'reference': 'MP261108.1530.R1'});
  });

  testWidgets('abonnement : 1 mois offert avec motif', (tester) async {
    await open(tester, const Size(1280, 900));
    await tester.tap(find.text('Abonnements'));
    await tester.pumpAndSettle();
    await search(tester);
    await tester.tap(find.text('Prolonger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offrir ou prolonger de 1 mois'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Geste commercial');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    final c = calls.where((c) => c.$1 == 'kitungaGrantSubscription').single;
    expect(c.$2, {'userUid': 'marie', 'days': 30, 'reason': 'Geste commercial'});
  });

  testWidgets('suspension : motif obligatoire', (tester) async {
    await open(tester, const Size(1280, 900));
    await tester.tap(find.text('Comptes'));
    await tester.pumpAndSettle();
    await search(tester);
    await tester.tap(find.text('Suspendre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('Champ obligatoire'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Commandes fictives');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    final c = calls.where((c) => c.$1 == 'kitungaSetAccountStatus').single;
    expect(c.$2, {'userUid': 'marie', 'status': 'suspended',
      'reason': 'Commandes fictives'});
  });
}
