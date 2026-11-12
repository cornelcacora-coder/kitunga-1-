import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/backend/backend.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_deliverer_panel.dart';
import 'package:kitunga/mobile/components/delivery/kitunga_live_tracking.dart';
import 'package:kitunga/mobile/components/messaging/kitunga_messages.dart';
import 'package:kitunga/mobile/deliverer/kitunga_deliverer_home.dart';
import 'package:kitunga/mobile/deliverer/kitunga_deliverer_pages.dart';

// ignore: subtype_of_sealed_class
class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
}

OrdersRecord order(String id, String status, {Map<String, dynamic>? extra}) =>
    OrdersRecord.getDocumentFromData({
      'status': status,
      'delivery_zone': 'Bacongo',
      'delivery_fees': 1000,
      'order_unique_reference': 'K-$id',
      'created_at': DateTime.now(),
      ...?extra,
    }, _Ref('Orders/$id'));

/// Messagerie et onglets du livreur.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  var messages = <Map<String, dynamic>>[];

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    trackingTestMode = true;
    messagesNoPolling = true;
    messagesBackendOverride = (name, data) async {
      calls.add((name, data));
      switch (name) {
        case 'kitungaMyConversations':
          return {
            'unread': 2,
            'conversations': [
              {'id': 'c1', 'kind': 'order', 'title': 'Commande K-1',
                'withRole': 'client', 'lastMessage': 'Je suis au portail',
                'lastAt': DateTime.now().toIso8601String(), 'unread': 2},
              {'id': 'a1', 'kind': 'announcement', 'title': 'Annonces',
                'lastMessage': 'Pluie', 'unread': 0},
            ]
          };
        case 'kitungaConversationMessages':
          return {'open': true, 'messages': messages};
        case 'kitungaSendMessage':
          messages = [
            ...messages,
            {'mine': true, 'text': data['text'], 'fromRole': 'livreur',
              'at': DateTime.now().toIso8601String()},
          ];
          return {'ok': true};
        case 'kitungaOpenOrderChat':
          return {'conversationId': 'c1'};
      }
      return {};
    };
  });
  setUp(() {
    calls.clear();
    messages = [
      {'mine': false, 'text': 'Je suis au portail', 'fromRole': 'client',
        'fromName': 'Awa', 'at': DateTime.now().toIso8601String()},
    ];
  });

  testWidgets('liste, conversation, envoi', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: KitungaConversationsPage())));
    await tester.pumpAndSettle();
    expect(find.text('Client · Commande K-1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Annonces Kitunga'), findsOneWidget);
    await tester.tap(find.text('Client · Commande K-1'));
    await tester.pumpAndSettle();
    expect(find.text('Je suis au portail'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('chat-input')), 'J\'arrive dans 2 min');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(calls.any((c) =>
        c.$1 == 'kitungaSendMessage' &&
        c.$2['text'] == 'J\'arrive dans 2 min'), isTrue);
    expect(find.text('J\'arrive dans 2 min'), findsOneWidget);
  });

  testWidgets('conversation fermée : lecture seule', (tester) async {
    final prev = messagesBackendOverride!;
    messagesBackendOverride = (n, d) async =>
        n == 'kitungaConversationMessages'
            ? <String, dynamic>{'open': false, 'messages': messages}
            : await prev(n, d);
    addTearDown(() => messagesBackendOverride = prev);
    await tester.pumpWidget(const MaterialApp(
        home: KitungaChatPage(conversationId: 'c1', title: 'Client')));
    await tester.pumpAndSettle();
    expect(find.text('Conversation fermée : lecture seule.'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-input')), findsNothing);
  });

  testWidgets('Mes courses : en cours, terminées, incidents', (tester) async {
    delivererMyOrdersOverride = Stream.value([
      order('a', 'encours'),
      order('b', 'Livrer'),
      order('c', 'Non Reçu'),
    ]);
    delivererOpenOrdersOverride = Stream.value(const []);
    addTearDown(() {
      delivererMyOrdersOverride = null;
      delivererOpenOrdersOverride = null;
    });
    await tester.pumpWidget(const MaterialApp(home: KitungaDelivererCourses()));
    await tester.pumpAndSettle();
    expect(find.text('En cours'), findsWidgets);
    await tester.tap(find.text('Terminées'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 livrées'), findsOneWidget);
    await tester.tap(find.text('Proposées'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune proposition'), findsOneWidget);
  });

  testWidgets('Carte : courses prêtes de mes quartiers', (tester) async {
    delivererMyOrdersOverride = Stream.value([order('a', 'encours')]);
    delivererOpenOrdersOverride = Stream.value([order('x', 'Pret')]);
    delivererStateOverride = Stream.value(
        {'delivery_available': true, 'delivery_state': 'on'});
    addTearDown(() {
      delivererMyOrdersOverride = null;
      delivererOpenOrdersOverride = null;
      delivererStateOverride = null;
    });
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: KitungaDelivererMap())));
    await tester.pumpAndSettle();
    expect(find.text('1 course(s) prête(s) · 1 en cours'), findsOneWidget);
  });
}
