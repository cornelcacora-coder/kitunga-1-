import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/flutter_flow/flutter_flow_theme.dart';
import 'package:kitunga/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';

/// Panier : commerce fermé signalé avant le paiement.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('statut d\'ouverture lu avec les horaires de la semaine', () {
    const h = 'Lun-Sam 8h00-18h00 · Dim fermé';
    // Dimanche 15 novembre 2026, midi.
    final s = kitungaOpeningStatus(h, DateTime(2026, 11, 15, 12))!;
    expect(s.open, isFalse);
    expect(s.label, 'Fermé · ouvre demain à 8h00');
  });

  testWidgets('bandeau « fermé » du panier', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => KitungaClosedBanner(
              name: 'Chez Paul',
              label: 'Fermé · ouvre demain à 8h00',
              theme: FlutterFlowTheme.of(context)),
        ),
      ),
    ));
    expect(
        find.textContaining('Chez Paul est fermé en ce moment (ouvre demain à '
            '8h00)'),
        findsOneWidget);
    expect(find.textContaining('Votre panier est gardé'), findsOneWidget);
  });
}
