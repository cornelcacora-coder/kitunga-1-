import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/mobile/components/support/kitunga_support.dart';
import 'package:kitunga/noc/sales/sales_common.dart';
import 'package:kitunga/noc/support/support_workspace.dart';

/// Support : demandes dans l'application, espace de travail des agents.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  final ticket = {
    'id': 't1', 'number': 'T-00001', 'subject': 'Paiement en double',
    'status': 'open', 'priority': 'high', 'category': 'paiement',
    'categoryLabel': 'Paiement / remboursement', 'orderRef': 'K-1',
    'authorName': 'Awa', 'authorRole': 'User', 'lastMessage': 'J\'ai payé 2 fois',
    'unread': true, 'updatedAt': '2026-11-12T09:00:00Z',
    'createdAt': '2026-11-12T09:00:00Z',
  };

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    Future<Map<String, dynamic>> backend(
        String n, Map<String, dynamic> d) async {
      calls.add((n, d));
      switch (n) {
        case 'kitungaMyTickets':
          return {'tickets': [ticket]};
        case 'kitungaCreateTicket':
          return {'ticketId': 't1', 'number': 'T-00001'};
        case 'kitungaTicketThread':
          return {
            'ticket': ticket,
            'messages': [
              {'text': 'J\'ai payé 2 fois', 'mine': true, 'fromRole': 'author',
                'at': '2026-11-12T09:00:00Z'},
              {'text': 'Vérification MTN', 'internal': true,
                'fromRole': 'support', 'fromName': 'Agent',
                'at': '2026-11-12T09:05:00Z'},
            ]
          };
        case 'kitungaSupportQueue':
          return {
            'tickets': [ticket],
            'counts': {'open': 1, 'urgent': 0, 'escalated': 0, 'mine': 0,
              'resolved': 3}
          };
      }
      return {'ok': true};
    }

    supportBackendOverride = backend;
    salesBackendOverride = backend;
  });
  setUp(calls.clear);

  testWidgets('application : mes demandes et nouvelle demande',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KitungaSupportPage()));
    await tester.pumpAndSettle();
    expect(find.text('T-00001 · Paiement en double'), findsOneWidget);
    expect(find.text('Ouverte'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ticket-message')),
        'Le livreur n\'est pas venu.');
    await tester.tap(find.byKey(const ValueKey('ticket-send')));
    await tester.pumpAndSettle();
    final create = calls.firstWhere((c) => c.$1 == 'kitungaCreateTicket');
    expect(create.$2['message'], 'Le livreur n\'est pas venu.');
    expect(create.$2['category'], 'commande');
    // Le fil de la nouvelle demande s'ouvre.
    expect(find.text('Demande T-00001'), findsOneWidget);
  });

  testWidgets('espace support : file, détail, note interne',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const MaterialApp(home: SupportWorkspaceWidget()));
    await tester.pumpAndSettle();
    expect(find.text('Support Kitunga'), findsOneWidget);
    expect(find.text('T-00001'), findsOneWidget);
    await tester.tap(find.text('Paiement en double'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Note interne'), findsWidgets);
    expect(find.text('Vérification MTN'), findsOneWidget);
    await tester.tap(find.text('Résoudre'));
    await tester.pumpAndSettle();
    expect(calls.any((c) =>
        c.$1 == 'kitungaTicketUpdate' && c.$2['status'] == 'resolved'), isTrue);
  });
}
