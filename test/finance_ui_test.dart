import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/mobile/components/finance/kitunga_earnings.dart';
import 'package:kitunga/noc/admin/admin_finance_widget.dart';
import 'package:kitunga/noc/admin/admin_layout.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Gains (livreur, commerce) et page Finances de l'admin.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    earningsBackendOverride = (n, d) async => {
          'balance': 400, 'today': 1000, 'week': 1000, 'total': 1000,
          'paidOut': 600,
          'settings': {'commission_rate': 0, 'deliverer_share': 1},
          'entries': [
            {'type': 'payout', 'amount': -600, 'label': 'Versement MoMo',
              'at': '2026-11-12T10:00:00Z'},
            {'type': 'delivery', 'amount': 1000, 'label': 'Livraison K-1',
              'at': '2026-11-12T09:00:00Z'},
          ],
        };
    adminPendingOrders = () => Stream.value(0);
    adminDisplayName = () => 'Admin';
    salesBackendOverride = (n, d) async {
      calls.add((n, d));
      if (n == 'kitungaAdminFinanceOverview') {
        return {
          'totals': {'collectedOrders': 6000, 'subscriptions': 300,
            'commission': 0, 'refunds': 0, 'payouts': 600, 'owed': 5400},
          'settings': {'commission_rate': 0, 'deliverer_share': 1},
          'accounts': [
            {'uid': 'shop', 'role': 'Seller', 'name': 'Chez Mado',
              'balance': 5000, 'earned': 5000, 'paidOut': 0},
            {'uid': 'l1', 'role': 'Deliver', 'name': 'Jo', 'balance': 400,
              'earned': 1000, 'paidOut': 600},
          ],
        };
      }
      return {'ok': true};
    };
  });

  testWidgets('Mes gains : solde, versements, règle', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: KitungaEarningsPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('earnings-balance')), findsOneWidget);
    expect(find.textContaining('400'), findsWidgets);
    expect(find.text('Livraison K-1'), findsOneWidget);
    expect(find.textContaining('100 % des frais de livraison'),
        findsOneWidget);
  });

  testWidgets('Finances : soldes et versement', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminFinanceWidget()));
    await tester.pumpAndSettle();
    expect(find.text('Chez Mado'), findsOneWidget);
    expect(find.text('Reste à verser'), findsOneWidget);
    await tester.tap(find.text('Verser').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer le versement'));
    await tester.pumpAndSettle();
    final pay = calls.firstWhere((c) => c.$1 == 'kitungaAdminRecordPayout');
    expect(pay.$2['uid'], 'shop');
    expect(pay.$2['amount'], 5000);
    expect((pay.$2['requestId'] as String).length, greaterThan(8));
  });
}
