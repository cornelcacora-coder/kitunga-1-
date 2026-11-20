import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/admin/admin_layout.dart';
import 'package:kitunga/noc/admin/admin_supervision_widget.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Supervision en direct : compteurs, livreurs, annonce.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    adminPendingOrders = () => Stream.value(0);
    adminDisplayName = () => 'Admin';
    salesBackendOverride = (n, d) async {
      calls.add((n, d));
      if (n == 'kitungaAdminSupervision') {
        return {
          'actors': {'User': 120, 'Seller': 14, 'Deliver': 6, 'Support': 1},
          'orders': {'pending': 3, 'ready': 2, 'unassignedReady': 1,
            'delivering': 4, 'deliveredToday': 9, 'incidents': 1},
          'delivererStates': {'on': 3, 'pause': 1, 'off': 2},
          'tickets': {'open': 5, 'urgent': 1, 'escalated': 0},
          'finance': {'owed': 54000, 'kitunga': 0},
          'incidents': [
            {'reference': 'K-9', 'zone': 'Bacongo', 'label': 'Client absent',
              'note': ''}
          ],
          'deliverers': [
            {'uid': 'l1', 'name': 'Jo', 'state': 'on', 'vehicle': 'moto',
              'active': 1, 'deliveredToday': 4, 'positionFresh': true,
              'positionAt': '2026-11-12T10:00:00Z', 'zones': ['Bacongo']},
          ],
        };
      }
      return {'sent': 6};
    };
  });

  testWidgets('compteurs, incident, livreur, annonce', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AdminSupervisionWidget()));
    await tester.pumpAndSettle();
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Livrées aujourd\'hui'), findsOneWidget);
    expect(find.textContaining('Client absent'), findsOneWidget);
    expect(find.text('Jo'), findsOneWidget);
    expect(find.textContaining('1 sans livreur'), findsOneWidget);
    await tester.tap(find.text('Annonce'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'Pluie');
    await tester.enterText(fields.at(1), 'Soyez prudents.');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    final a = calls.firstWhere((c) => c.$1 == 'kitungaAdminAnnounce');
    expect(a.$2, {'audience': 'deliverers', 'title': 'Pluie',
      'body': 'Soyez prudents.'});
  });
}
