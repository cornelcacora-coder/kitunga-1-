import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/order_status.dart';
import 'package:kitunga/components/order_comp_n_o_c_widget.dart';

/// Ligne de commande de l'admin : le statut est lisible (texte blanc sur la
/// couleur du statut) pour chaque statut, sans débordement.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
  });

  for (final status in [
    OrderStatus.pending, OrderStatus.preparing, OrderStatus.ready,
    OrderStatus.delivering, OrderStatus.delivered, OrderStatus.received,
    OrderStatus.notReceived, OrderStatus.refused, OrderStatus.cancelled,
  ]) {
    testWidgets('statut « $status » lisible', (tester) async {
      tester.view.physicalSize = const Size(1280, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OrderCompNOCWidget(
            status: status,
            statusBg: OrderStatus.color(status),
            statuTextBg: OrderStatus.color(status),
            zone: 'Poto-Poto',
            orderId: 'ORD-1',
            createdAt: DateTime(2026, 11, 8, 10),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final label = find.text(OrderStatus.label(status));
      expect(label, findsOneWidget);
      expect(tester.widget<Text>(label).style?.color, Colors.white);
      expect(tester.takeException(), isNull);
    });
  }
}
