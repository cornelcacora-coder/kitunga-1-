import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/mobile/components/messaging/kitunga_messages.dart';
import 'package:kitunga/noc/admin/admin_layout.dart';
import 'package:kitunga/noc/messages/staff_inbox.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Messages directs de l'équipe Kitunga.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    adminPendingOrders = () => Stream.value(0);
    adminDisplayName = () => 'Admin';
    messagesNoPolling = true;
    Future<Map<String, dynamic>> backend(
        String n, Map<String, dynamic> d) async {
      calls.add((n, d));
      switch (n) {
        case 'kitungaStaffInbox':
          return {
            'unread': 1,
            'conversations': [
              {'id': 'direct_l1', 'targetUid': 'l1', 'targetName': 'Jo',
                'targetRole': 'Deliver', 'lastMessage': 'D\'accord, à 9 h.',
                'lastAt': '2026-11-12T10:00:00Z', 'unread': 1},
            ]
          };
        case 'kitungaSupportUserLookup':
          return {
            'users': [
              {'uid': 's1', 'name': 'Chez Mado', 'role': 'Seller',
                'phone': '055554433'},
            ]
          };
        case 'kitungaStaffOpenDirect':
          return {'conversationId': 'direct_${d['uid']}',
            'title': 'Chez Mado · Commerce'};
        case 'kitungaConversationMessages':
          return {'open': true, 'messages': []};
      }
      return {'ok': true};
    }

    salesBackendOverride = backend;
    messagesBackendOverride = backend;
  });
  setUp(calls.clear);

  Future<void> open(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pumpAndSettle();
  }

  testWidgets('boîte de l\'équipe : non-lus, ouverture', (tester) async {
    await open(tester, const AdminMessagesWidget());
    expect(find.text('Jo · Livreur'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    await tester.tap(find.text('Jo · Livreur'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.$1 == 'kitungaConversationMessages' &&
        c.$2['conversationId'] == 'direct_l1'), isTrue);
  });

  testWidgets('nouveau message : recherche puis conversation',
      (tester) async {
    await open(tester, const AdminMessagesWidget());
    await tester.tap(find.text('Nouveau message'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'mado');
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chez Mado'));
    await tester.pumpAndSettle();
    expect(calls.any((c) =>
        c.$1 == 'kitungaStaffOpenDirect' && c.$2['uid'] == 's1'), isTrue);
    expect(find.text('Chez Mado · Commerce'), findsOneWidget);
  });

  testWidgets('bouton Écrire', (tester) async {
    await open(tester,
        const Scaffold(body: Center(child: StaffWriteButton(uid: 's1'))));
    await tester.tap(find.text('Écrire'));
    await tester.pumpAndSettle();
    expect(find.text('Chez Mado · Commerce'), findsOneWidget);
  });
}
