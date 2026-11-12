import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/mobile/components/kitunga_zone_field.dart';
import 'package:kitunga/noc/admin/admin_delivery_pricing_widget.dart';

/// Tarif de livraison : simulation identique au serveur, champ quartier.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  const s = {
    'base': 500,
    'per_km': 150,
    'road_factor': 1.3,
    'minimum': 1000,
    'maximum': 5000,
    'rounding': 100,
  };

  test('mêmes résultats que le serveur', () {
    expect(simulateDeliveryFee(s, 'Bacongo', 'Bacongo')!.fee, 1000);
    expect(simulateDeliveryFee(s, 'Bacongo', 'Makélékélé')!.fee, 1100);
    final far = simulateDeliveryFee(s, 'Kintélé', 'Bacongo')!;
    expect(far.fee, 4200);
    expect(far.km, 24.3);
    expect(simulateDeliveryFee({...s, 'maximum': 3000}, 'Kintélé', 'Bacongo')!
        .fee, 3000);
    expect(simulateDeliveryFee(s, 'Paris', 'Bacongo'), isNull);
  });

  testWidgets('quartier du commerce : liste des quartiers', (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: KitungaShopZoneField(
                value: null, onChanged: (v) => chosen = v))));
    await tester.tap(find.byKey(const ValueKey('shop-zone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bacongo').last);
    await tester.pumpAndSettle();
    expect(chosen, 'Bacongo');
  });
}
