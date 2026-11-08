import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/admin/admin_dashboard_data.dart';
import 'package:kitunga/noc/admin/admin_monitoring_widgets.dart';
import 'package:kitunga/noc/admin/admin_orders_widget.dart';
import 'package:kitunga/noc/admin/admin_shell.dart';
import 'package:kitunga/noc/ui/admin_export.dart';
import 'package:archive/archive.dart';
import 'dart:convert';

/// Pages Commandes, Livraisons, Alertes et Zones avec des données simulées.
void main() {
  final now = DateTime(2026, 11, 8, 12);

  DashOrder o(String id, String status, DateTime created,
          {DateTime? delivered, String zone = 'Poto-Poto', String? driver}) =>
      (
        id: id,
        reference: 'ORD-$id',
        status: status,
        total: 1000.0 * int.parse(id),
        createdAt: created,
        deliveredAt: delivered,
        zone: zone,
        location: 'Rue $id',
        userPath: 'User/client$id',
        sellerPath: 'User/shop',
        delivererPath: driver,
      );

  final recent = [
    o('1', 'Livrer', now.subtract(const Duration(days: 1)),
        delivered: now.subtract(const Duration(days: 1, minutes: -45)),
        driver: 'User/jean'),
    o('2', 'Non Reçu', now.subtract(const Duration(days: 2))),
    o('3', 'Annulée', now.subtract(const Duration(days: 3)), zone: 'Bacongo'),
  ];
  final live = [
    // À confirmer depuis 40 min : sans réponse du vendeur.
    o('4', 'En attente', now.subtract(const Duration(minutes: 40))),
    // Prête depuis 3 h : en retard et en attente d'un livreur.
    o('5', 'Pret', now.subtract(const Duration(hours: 3)), zone: 'Bacongo'),
    o('6', 'encours', now.subtract(const Duration(minutes: 50)),
        driver: 'User/jean'),
    // Ancienne commande toujours en cours (hors période) : incluse.
    o('7', 'En préparation', now.subtract(const Duration(days: 60))),
  ];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    adminPendingOrders = () => Stream.value(1);
    adminDisplayName = () => 'Admin';
    AdminDashboardSource.override = AdminDashboardSource(
      ordersSince: (_) => Stream.value([...recent, ...live.take(3)]),
      inProgress: () => Stream.value(live),
      newUsersSince: (_) async => const [],
      totals: () async => (clients: 0, sellers: 0, delivers: 0),
      paymentStatusesSince: (_) => Stream.value(const []),
      names: (paths) async => {
        for (final p in paths)
          p: (
            name: p == 'User/shop'
                ? 'Chez Paul'
                : p == 'User/jean'
                    ? 'Jean Livreur'
                    : 'Client ${p.substring(11)}',
            photo: '',
            phone: '061234567'
          ),
      },
      orderItems: (_) async => const [],
      payments: (_) => Stream.value([
        {'status': 'Echec', 'amount': 3500, 'message': 'Solde insuffisant',
          'created_at': now.subtract(const Duration(days: 1)),
          'user_path': 'User/client9'},
        {'status': 'Réussi', 'amount': 2000,
          'created_at': now.subtract(const Duration(days: 2))},
      ]),
    );
  });

  Future<void> open(WidgetTester tester, Widget page, Size size) async {
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
      home: page,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    // Dernière occurrence : l'onglet (une carte peut porter le même libellé).
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  test('zones : regroupement et délai moyen', () {
    final rows = zoneRows(live, recent);
    final poto = rows.firstWhere((r) => r.zone == 'Poto-Poto');
    expect(poto.live, 3);
    expect(poto.delivering, 1);
    expect(poto.month, 2);
    expect(poto.delivered, 1);
    expect(poto.avgMinutes, 45);
    expect(rows.firstWhere((r) => r.zone == 'Bacongo').live, 1);
    expect(mergeOrders(recent, live).length, 7);
    expect(adminDuration(const Duration(minutes: 125)), '2 h 05');
  });

  for (final size in const [Size(1440, 1000), Size(400, 860)]) {
    final w = size.width.toInt();

    testWidgets('commandes : onglets, recherche, fiche ($w px)', (tester) async {
      await open(tester, AdminOrdersWidget(clock: () => now), size);
      // 3 de la période + 4 en cours (dont une ancienne), sans doublon.
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('7'), findsWidgets);
      // 5 par page : la plus ancienne (ORD-7) est en page 2.
      expect(find.text('1–5 sur 7'), findsOneWidget);
      expect(find.text('ORD-7'), findsNothing);
      await tester.dragUntilVisible(find.byTooltip('Page suivante'),
          find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Page suivante'));
      await tester.pumpAndSettle();
      expect(find.text('ORD-7'), findsOneWidget);
      await tapText(tester, 'Non reçues');
      expect(find.text('ORD-2'), findsOneWidget);
      expect(find.text('ORD-1'), findsNothing);
      await tapText(tester, 'Toutes');
      await tester.enterText(find.byType(TextField).last, 'bacongo');
      await tester.pumpAndSettle();
      expect(find.text('ORD-3'), findsOneWidget);
      expect(find.text('ORD-5'), findsOneWidget);
      expect(find.text('ORD-1'), findsNothing);
      await tapText(tester, 'ORD-5');
      expect(find.text('Commande ORD-5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('livraisons : indicateurs et livreurs ($w px)', (tester) async {
      await open(tester,
          AdminOrdersWidget(mode: AdminOrdersMode.deliveries, clock: () => now),
          size);
      expect(find.text('À prendre en charge'), findsWidgets);
      expect(find.text('1 en attente depuis +30 min'), findsOneWidget);
      expect(find.text('ORD-5'), findsOneWidget);
      await tapText(tester, 'En cours de livraison');
      expect(find.textContaining('Jean Livreur'), findsWidgets);
      await tapText(tester, 'Livrées');
      expect(find.text('ORD-1'), findsOneWidget);
      expect(find.textContaining('45 min'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('alertes et zones ($w px)', (tester) async {
      await open(tester, AdminAlertsWidget(clock: () => now), size);
      expect(find.text('Commandes en retard'), findsOneWidget);
      expect(find.text('Sans réponse du vendeur'), findsOneWidget);
      // ORD-5 en retard, ORD-4 sans réponse, ORD-2 non reçue.
      expect(find.text('ORD-5'), findsWidgets);
      expect(find.text('ORD-4'), findsOneWidget);
      expect(find.text('ORD-2'), findsOneWidget);
      await tester.ensureVisible(find.text('Paiements échoués'));
      expect(find.textContaining('Solde insuffisant'), findsOneWidget);
      expect(find.text('50 %'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await open(tester, AdminZonesWidget(clock: () => now), size);
      expect(find.text('Poto-Poto'), findsOneWidget);
      expect(find.text('Bacongo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('export Excel des commandes affichées (onglet et filtres)',
      (tester) async {
    final saved = <(String, List<int>)>[];
    adminExportSaveOverride = (bytes, name, mime) => saved.add((name, bytes));
    addTearDown(() => adminExportSaveOverride = null);
    await open(tester, AdminOrdersWidget(clock: () => now),
        const Size(1440, 1000));
    await tapText(tester, 'Non reçues');
    await tester.tap(find.text('Exporter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excel (.xlsx)'));
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(saved.length, 1);
    expect(saved.single.$1, startsWith('kitunga_commandes_'));
    final sheet = utf8.decode(ZipDecoder()
        .decodeBytes(saved.single.$2)
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .content as List<int>);
    // Seule la commande non reçue de l'onglet est exportée.
    expect(sheet, contains('ORD-2'));
    expect(sheet, isNot(contains('ORD-1<')));
    expect(sheet, contains('onglet « Non reçues »'));
  });
}
