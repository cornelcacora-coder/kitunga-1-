import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/kitunga_notifications.dart';

/// Cloche, centre de notifications, lien vers l'abonnement.
void main() {
  final calls = <String>[];
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    notificationsBackendOverride = (name, data) async {
      calls.add(name);
      if (name == 'kitungaMyNotifications') {
        return {
          'unread': 2,
          'notifications': [
            {'id': 'n1', 'title': 'Votre abonnement se termine demain',
              'body': 'Renouvelez-le dès maintenant.', 'kind': 'subscription',
              'read': false, 'createdAt': '2026-11-10T08:00:00Z'},
            {'id': 'n2', 'title': 'Promo', 'body': 'Livraison offerte',
              'kind': 'admin', 'read': false,
              'createdAt': '2026-11-09T08:00:00Z'},
          ],
        };
      }
      return {'ok': true};
    };
  });

  testWidgets('cloche : 2 non lues, page, lues, lien abonnement',
      (tester) async {
    var renew = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
            child: KitungaNotificationBell(onSubscription: (_) => renew++)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byType(KitungaNotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('Votre abonnement se termine demain'), findsOneWidget);
    expect(find.text('Livraison offerte'), findsOneWidget);
    expect(calls, contains('kitungaMarkNotificationsRead'));
    await tester.tap(find.text('Renouveler mon abonnement'));
    expect(renew, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing); // tout est lu
  });
}
