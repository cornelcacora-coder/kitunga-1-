import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/ops/purge_tab.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Gestion › Données de test, avec un serveur simulé.
void main() {
  final calls = <Map<String, dynamic>>[];
  var purged = false;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    salesBackendOverride = (f, d) async {
      calls.add(d);
      switch (d['mode']) {
        case 'preview':
          return {
            'counts': purged
                ? {'sellers': 0, 'delivers': 0, 'products': 0, 'orders': 0,
                    'orderItems': 0, 'carts': 0, 'payments': 0,
                    'keptSubscriptionPayments': 3}
                : {'sellers': 8, 'delivers': 4, 'products': 120, 'orders': 37,
                    'orderItems': 80, 'carts': 12, 'payments': 40,
                    'keptSubscriptionPayments': 3},
            'sellers': purged ? [] : ['Chez Paul', 'LBK Resto'],
            'delivers': purged ? [] : ['Jean'],
          };
        case 'purge':
          purged = true;
          return {'runId': '20261108T143000', 'files': 54, 'accounts': 12,
            'counts': {}};
        case 'history':
          return {'runs': purged
              ? [
                  {'runId': '20261108T143000', 'status': 'terminé',
                    'counts': {'products': 120, 'orders': 37, 'sellers': 8},
                    'restored': false},
                ]
              : []};
        case 'restore':
          return {'documents': 300, 'files': 54};
      }
      return {};
    };
  });

  testWidgets('aperçu, confirmation tapée, suppression puis restauration',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
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
      home: Scaffold(body: PurgeTestDataTab()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('120'), findsOneWidget);
    expect(find.text('paiements d\'abonnement'), findsOneWidget);
    expect(find.text('Aucun nettoyage effectué pour l\'instant.'),
        findsOneWidget);

    // Bouton bloqué tant que SUPPRIMER n'est pas tapé.
    final button = find.widgetWithText(
        FilledButton, 'Supprimer les données de test');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'supprimer');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'SUPPRIMER');
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c['mode'] == 'purge').single,
        {'mode': 'purge', 'confirm': 'SUPPRIMER'});
    expect(find.textContaining('sauvegarde 20261108T143000'), findsOneWidget);
    expect(find.text('Aucune donnée de test à supprimer'), findsOneWidget);

    await tester.tap(find.text('Restaurer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurer').last);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c['mode'] == 'restore').single,
        {'mode': 'restore', 'runId': '20261108T143000'});
    expect(tester.takeException(), isNull);
  });
}
