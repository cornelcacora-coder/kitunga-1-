import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/components/payment_method_widget.dart';
import 'package:kitunga/flutter_flow/flutter_flow_model.dart';

/// Panier : choix MTN MoMo / Airtel Money et numéro qui paiera.
void main() {
  var airtelOn = true;
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    airtelAvailableOverride = () async => airtelOn;
  });
  setUp(() => airtelOn = true);

  testWidgets('Airtel pas encore activé : grisé, « Bientôt disponible »',
      (tester) async {
    airtelOn = false;
    final model = PaymentMethodModel();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: wrapWithModel(
          model: model,
          updateCallback: () {},
          child: const PaymentMethodWidget(
              mtnNumber: '051234567', airtelNumber: '051234567'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bientôt disponible'), findsOneWidget);
    expect(model.operator, 'MTN');
    await tester.tap(find.byKey(const ValueKey('payment-Airtel')));
    await tester.pumpAndSettle();
    expect(model.operator, 'MTN');
  });

  test('numéros et opérateurs', () {
    expect(nationalPhone('+242 06 123 45 67'), '061234567');
    expect(nationalPhone('61234567'), '061234567');
    expect(operatorOfPhone('061234567'), 'MTN');
    expect(operatorOfPhone('242051234567'), 'Airtel');
    expect(operatorOfPhone('041234567'), 'Airtel');
    expect(operatorOfPhone(''), isNull);
  });

  testWidgets('choisir Airtel Money vide le numéro MTN', (tester) async {
    final model = PaymentMethodModel();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: wrapWithModel(
            model: model,
            updateCallback: () {},
            child: const PaymentMethodWidget(
                mtnNumber: '+242061234567', airtelNumber: '+242061234567'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(model.operator, 'MTN');
    expect(model.phoneController.text, '061234567');
    expect(find.text('Numéro MTN MoMo qui paiera'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('payment-Airtel')));
    await tester.pumpAndSettle();
    expect(model.operator, 'Airtel');
    expect(model.phoneController.text, '');
    expect(find.text('Numéro Airtel Money qui paiera'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('payment-phone')), '051234567');
    expect(model.phoneController.text, '051234567');
  });

  testWidgets('compte Airtel : Airtel Money proposé d\'abord', (tester) async {
    final model = PaymentMethodModel();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: wrapWithModel(
          model: model,
          updateCallback: () {},
          child: const PaymentMethodWidget(
              mtnNumber: '051234567', airtelNumber: '051234567'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(model.operator, 'Airtel');
    expect(model.phoneController.text, '051234567');
  });
}
