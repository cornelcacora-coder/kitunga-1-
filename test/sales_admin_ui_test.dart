import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/sales/sales_admin_widget.dart';
import 'package:kitunga/noc/admin/admin_layout.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Interface admin du module commercial avec un serveur simulé : chaque
/// onglet s'affiche sans débordement ni erreur, et les actions envoient les
/// bonnes données.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];

  Map<String, dynamic> fake(String function, Map<String, dynamic> data) {
    if (function != 'kitungaSalesAdminQuery') return {'ok': true};
    switch (data['view']) {
      case 'overview':
        return {
          'period': {'start': '2026-10-31T23:00:00Z', 'end': '2026-11-20T12:00:00Z'},
          'activeCampaigns': 2, 'activeAgents': 5, 'clicks': 1250,
          'activations': 310, 'signups': 180, 'subscriptions': 42,
          'conversion': {'signupPerClick': 14.4, 'subscriptionPerSignup': 23.3},
          'commissions': {'generated': 123450, 'paid': 80000, 'due': 25000,
            'pending': 18450, 'truncated': false},
        };
      case 'agents':
        return {
          'agents': [
            {'uid': 'a1', 'agentCode': 'KTG001', 'displayName': 'Jean-Baptiste Mabiala',
              'email': 'jean.mabiala@exemple.cg', 'phone': '242061234567',
              'status': 'active', 'payoutMethod': {'type': 'mobile_money',
                'operator': 'MTN', 'phone': '242061234567'},
              'currentAssignment': {'code': 'KTG001-X7P9',
                'endsAt': '2026-11-30T23:00:00Z'}},
            {'uid': 'a2', 'agentCode': 'KTG002', 'displayName': 'Paul',
              'email': 'p@exemple.cg', 'phone': '242065555555',
              'status': 'suspended', 'statusReason': 'Contrôle en cours',
              'payoutMethod': null, 'currentAssignment': null},
          ],
        };
      case 'campaigns':
        return {
          'campaigns': [
            {'id': 'c1', 'name': 'Lancement Brazzaville', 'status': 'active',
              'startsAt': '2026-10-31T23:00:00Z', 'endsAt': '2026-11-30T23:00:00Z',
              'ruleId': 'r1', 'graceDays': 30, 'holdDays': 7,
              'objective': '500 abonnés', 'description': 'Marchés et universités'},
            {'id': 'c2', 'name': 'Pointe-Noire', 'status': 'draft',
              'startsAt': '2026-12-01T00:00:00Z', 'endsAt': '2026-12-31T00:00:00Z',
              'ruleId': 'r1', 'graceDays': 30, 'holdDays': 7},
          ],
          'rules': [
            {'id': 'r1', 'label': 'Lancement', 'activationAmount': 50,
              'firstSubscriptionAmount': 100,
              'eligiblePlans': ['quarterly', 'annual']},
          ],
        };
      case 'campaign':
        return {
          'assignments': [
            {'id': 's1', 'agentUid': 'a1', 'agentCode': 'KTG001',
              'status': 'active', 'startsAt': '2026-10-31T23:00:00Z',
              'endsAt': '2026-11-30T23:00:00Z', 'referralCode': 'KTG001-X7P9',
              'link': 'https://kitunga-xtvpe4.web.app/r/KTG001-X7P9',
              'allowOverlap': false},
          ],
        };
      case 'commissions':
        return {
          'commissions': [
            {'id': 'first_subscription_u1', 'type': 'first_subscription',
              'agentUid': 'a1', 'campaignId': 'c1', 'amount': 100,
              'status': 'pending', 'flags': ['shared_payer'],
              'plan': 'annual', 'eligibleAt': '2026-01-01T00:00:00Z',
              'createdAt': '2026-11-18T10:00:00Z'},
            {'id': 'activation_u2', 'type': 'activation', 'agentUid': 'a1',
              'campaignId': 'c1', 'amount': 50, 'status': 'paid', 'flags': [],
              'createdAt': '2026-11-10T10:00:00Z'},
          ],
        };
      case 'payouts':
        return {
          'payouts': [
            {'id': 'p1', 'agentUid': 'a1', 'amount': 25000, 'status': 'approved',
              'method': {'type': 'mobile_money', 'operator': 'MTN',
                'phone': '242061234567'},
              'itemsCount': 12, 'requestedAt': '2026-11-19T09:00:00Z'},
          ],
        };
      case 'audit':
        return {
          'audit': [
            {'actorRole': 'Admin', 'action': 'commission.approved',
              'target': 'commission_transactions/x',
              'createdAt': '2026-11-19T09:00:00Z'},
            {'actorRole': 'system', 'action': 'campaign.completed',
              'target': 'acquisition_campaigns/c0',
              'createdAt': '2026-11-01T00:00:00Z'},
          ],
        };
    }
    return {};
  }

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    adminPendingOrders = () => Stream.value(0);
    adminDisplayName = () => 'Admin';
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
      home: SalesAdminWidget(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(1280, 900), Size(400, 860)]) {
    testWidgets('six onglets sans erreur (${size.width.toInt()} px)',
        (tester) async {
      await open(tester, size);
      expect(find.text('Clics'), findsOneWidget);
      expect(find.text('1250'), findsOneWidget);
      await tab(tester, 'Commerciaux');
      expect(find.text('Jean-Baptiste Mabiala'), findsOneWidget);
      expect(find.textContaining('Code KTG001-X7P9'), findsOneWidget);
      await tab(tester, 'Campagnes');
      expect(find.text('Lancement Brazzaville'), findsOneWidget);
      await tab(tester, 'Commissions');
      expect(find.text('Même numéro MTN pour plusieurs clients'), findsOneWidget);
      await tab(tester, 'Versements');
      expect(find.text('Marquer payé'), findsOneWidget);
      await tab(tester, 'Historique');
      expect(find.text('Commission validée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('détail de campagne : affectation et QR code', (tester) async {
    await open(tester, const Size(1280, 900));
    await tab(tester, 'Campagnes');
    await tester.tap(find.text('Lancement Brazzaville'));
    await tester.pumpAndSettle();
    expect(find.text('KTG001-X7P9'), findsOneWidget);
    expect(find.text('Clôturer'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.qr_code_2_rounded));
    await tester.pumpAndSettle();
    expect(find.text('https://kitunga-xtvpe4.web.app/r/KTG001-X7P9'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commission signalée : note obligatoire puis validation',
      (tester) async {
    await open(tester, const Size(1280, 900));
    await tab(tester, 'Commissions');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer')); // note vide : refusé
    await tester.pumpAndSettle();
    expect(find.text('Commission signalée'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Même famille, vérifié');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    final review = calls.where((c) => c.$1 == 'kitungaReviewCommission').single;
    expect(review.$2, {
      'commissionId': 'first_subscription_u1',
      'decision': 'approve',
      'acknowledgeFlags': true,
      'reason': 'Même famille, vérifié',
    });
  });

  testWidgets('versement : référence du virement exigée', (tester) async {
    await open(tester, const Size(1280, 900));
    await tab(tester, 'Versements');
    await tester.tap(find.text('Marquer payé'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'MP261120.0912.A1');
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    final paid = calls.where((c) => c.$1 == 'kitungaDecidePayout').single;
    expect(paid.$2, {'payoutId': 'p1', 'decision': 'paid',
      'externalReference': 'MP261120.0912.A1'});
  });

  testWidgets('nouveau commercial : champs vérifiés avant envoi', (tester) async {
    await open(tester, const Size(1280, 900));
    await tab(tester, 'Commerciaux');
    await tester.tap(find.text('Nouveau commercial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Champ obligatoire'), findsWidgets);
    expect(calls.where((c) => c.$1 == 'kitungaCreateSalesAgent'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
