import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/sales/referral_qr.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('lien public du code', () {
    expect(kitungaReferralLink('KTG001-X7P9'),
        'https://kitunga-xtvpe4.web.app/r/KTG001-X7P9');
  });

  testWidgets('affiche le QR du lien et le code en clair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: KitungaReferralQr(code: 'KTG001-X7P9'))),
    ));
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr, isNotNull);
    expect(find.text('KTG001-X7P9'), findsOneWidget);
    final validation = QrValidator.validate(
      data: kitungaReferralLink('KTG001-X7P9'),
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    expect(validation.status, QrValidationStatus.valid);
  });
}
