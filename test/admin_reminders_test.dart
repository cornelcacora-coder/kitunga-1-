import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/admin/admin_clients_widget.dart';
import 'package:kitunga/noc/admin/admin_shell.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Admin : groupes d'abonnement des clients et rappels.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> client(String uid, String name, String state) => {
        'uid': uid, 'displayName': name, 'email': '$uid@test.cg',
        'phone': '06', 'subscription': state, 'accountStatus': 'active',
        'createdAt': '2026-11-01T10:00:00Z',
      };

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    salesBackendOverride = (f, d) async {
      calls.add((f, d));
      if (f == 'kitungaCatalogQuery') {
        return {
          'total': 3,
          'counts': {'active': 1, 'expiring': 0, 'expired': 1, 'never': 1},
          'clients': [
            client('a', 'Alice', 'active'),
            client('b', 'Bruno', 'expired'),
            client('c', 'Chloé', 'never'),
          ],
        };
      }
      return {'sent': 1, 'pushed': 1};
    };
    adminPendingOrders = () => Stream.value(0);
    adminDisplayName = () => 'Admin';
  });

  testWidgets('filtre « Expirés » puis rappel au groupe', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
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
      home: AdminClientsWidget(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Expirés · 1'), findsOneWidget);
    expect(find.text('Jamais abonnés · 1'), findsOneWidget);
    expect(find.text('Envoyer un rappel (3)'), findsOneWidget);
    await tester.tap(find.text('Expirés · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    await tester.tap(find.text('Envoyer un rappel (1)'));
    await tester.pumpAndSettle();
    // Message proposé pour les abonnements terminés.
    expect(find.text('Votre abonnement est terminé'), findsOneWidget);
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    final sent = calls.lastWhere((c) => c.$1 == 'kitungaAdminSendReminder').$2;
    expect(sent['uids'], ['b']);
    expect(sent['title'], 'Votre abonnement est terminé');
    expect(tester.takeException(), isNull);
  });
}
