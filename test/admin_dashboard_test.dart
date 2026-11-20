import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/admin/admin_dashboard_data.dart';
import 'package:kitunga/noc/admin/admin_delivery_map.dart';
import 'package:kitunga/noc/admin/admin_dashboard_widget.dart';
import 'package:kitunga/noc/admin/admin_shell.dart';
import 'package:kitunga/noc/ui/admin_charts.dart';

/// Tableau de bord : calculs et affichage avec des données simulées.
void main() {
  final now = DateTime(2026, 11, 8, 12);

  DashOrder o(String id, String status, double total, DateTime created,
          {DateTime? delivered, String zone = 'Poto-Poto'}) =>
      (
        id: id,
        reference: 'ORD-$id',
        status: status,
        total: total,
        createdAt: created,
        deliveredAt: delivered,
        zone: zone,
        location: 'Rue 12',
        userPath: 'User/client$id',
        sellerPath: 'User/shop',
        delivererPath: null,
        codeVerified: false,
        photo: '',
        issue: '',
      );

  final orders = [
    o('1', 'Livrer', 5000, now.subtract(const Duration(days: 1)),
        delivered: now.subtract(const Duration(days: 1, minutes: -40))),
    o('2', 'Reçu', 3000, now.subtract(const Duration(days: 3)),
        delivered: now.subtract(const Duration(days: 3, minutes: -60))),
    o('3', 'En attente', 2000, now.subtract(const Duration(hours: 3))),
    o('4', 'Annulée', 1500, now.subtract(const Duration(days: 2))),
    o('5', 'encours', 4000, now.subtract(const Duration(minutes: 30)),
        zone: 'Bacongo'),
    // Période précédente (8 à 14 jours avant).
    o('6', 'Livrer', 2000, now.subtract(const Duration(days: 10)),
        delivered: now.subtract(const Duration(days: 10, minutes: -30))),
  ];

  group('calculs', () {
    test('période et comparaison', () {
      final s = periodStats(orders, now, 7);
      expect(s.orders, 5);
      expect(s.previousOrders, 1);
      expect(s.revenue, 8000);
      expect(s.previousRevenue, 2000);
      expect(s.deliveryMinutes, 50);
      expect(s.previousDeliveryMinutes, 30);
      expect(s.deliveries, 2);
      expect(trendPercent(8000, 2000), 300);
      expect(trendPercent(0, 0), 0);
      expect(trendPercent(3, 0), isNull);
    });

    test('commandes par jour (aujourd\'hui en dernier)', () {
      final d = dailyOrders(orders, now, 7);
      expect(d.length, 7);
      expect(d.last.day, DateTime(2026, 11, 8));
      expect(d.last.count, 2);
      expect(d[5].count, 1); // hier
      expect(d.fold(0, (s, e) => s + e.count), 5);
    });

    test('répartition des statuts', () {
      final b = statusBreakdown(orders);
      expect({for (final g in b) g.label: g.count}, {
        'À confirmer': 1,
        'En préparation': 0,
        'En livraison': 1,
        'Livrées': 3,
        'Annulées ou refusées': 1,
      });
    });

    test('graduation de l\'axe', () {
      expect(niceScale(0).max, 4);
      expect(niceScale(7), (max: 8.0, step: 2.0));
      expect(niceScale(130).max, 200);
    });
  });

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AdminDeliveryMap.showTiles = false; // pas de réseau dans les tests
    await initializeDateFormatting('fr');
    adminPendingOrders = () => Stream.value(3);
    adminDisplayName = () => 'Fortuné Okombi';
    AdminDashboardSource.override = AdminDashboardSource(
      ordersSince: (_) => Stream.value(orders),
      inProgress: () => Stream.value(orders
          .where((x) => ['En attente', 'encours'].contains(x.status))
          .toList()),
      newUsersSince: (_) async => [
        now.subtract(const Duration(days: 2)),
        now.subtract(const Duration(days: 40)),
      ],
      totals: () async => (clients: 120, sellers: 14, delivers: 6),
      paymentStatusesSince: (_) =>
          Stream.value(['Réussi', 'Réussi', 'Echec', 'Réussi']),
      names: (paths) async => {
        for (final p in paths)
          p: (name: p == 'User/shop' ? 'Chez Paul' : 'Client ${p.substring(11)}',
              photo: '', phone: '061234567'),
      },
      orderItems: (_) async => [
        {'item_name': 'Poulet DG', 'quantity': 2, 'price_at_purchase': 2500,
          'options': 'Grande'},
      ],
    );
  });

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AdminDashboardWidget(clock: () => now),
    ));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(1440, 1000), Size(1024, 800), Size(400, 860)]) {
    final w = size.width.toInt();
    testWidgets('affichage complet sans débordement ($w px)', (tester) async {
      await open(tester, size);
      expect(find.text('Tableau de bord'), findsWidgets);
      expect(find.text('Commandes'), findsWidgets);
      expect(find.text('Ventes livrées'), findsOneWidget);
      expect(find.text('Nouveaux clients'), findsOneWidget);
      expect(find.text('Livraison moyenne'), findsOneWidget);
      // Période de 30 jours par défaut : 6 commandes.
      expect(find.text('6'), findsWidgets);
      expect(find.text('3'), findsWidgets); // cloche
      await tester.scrollUntilVisible(find.text('Commandes récentes'), 300.0,
          scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('Chez Paul'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Alertes'), 300.0,
          scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('25 %'), findsOneWidget); // 1 échec sur 4
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('période, fiche de commande et menu réduit', (tester) async {
    await open(tester, const Size(1440, 1000));
    await tester.tap(find.text('30 derniers jours').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 derniers jours').last);
    await tester.pumpAndSettle();
    expect(find.text('5'), findsWidgets);

    // La carte capte le glisser : on amène la ligne à l'écran directement.
    await tester.ensureVisible(find.text('ORD-5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORD-5'));
    await tester.pumpAndSettle();
    expect(find.text('Commande ORD-5'), findsOneWidget);
    expect(find.text('Poulet DG'), findsOneWidget);
    expect(find.text('Pas encore attribué'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    await tester.tap(find.byTooltip('Réduire ou agrandir le menu'));
    await tester.pumpAndSettle();
    expect(find.text('Administration'), findsNothing);
    adminSidebarCollapsed.value = false;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
