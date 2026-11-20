import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/mobile/common/security/change_email_page.dart';

/// Changement d'e-mail : adresse vérifiée, mot de passe exigé, et un lien
/// de confirmation annoncé seulement s'il a vraiment été envoyé.
void main() {
  final calls = <(String, String)>[];
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    changeEmailOverride = (password, email) async {
      calls.add((password, email));
      return password == 'secret1' ? null : 'wrong-password';
    };
  });

  testWidgets('adresse invalide, mot de passe faux, lien envoyé',
      (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ChangeEmailPage()));
    final send = find.text('Envoyer le lien de confirmation');

    await tester.enterText(find.byKey(const ValueKey('new-email')), 'pas-un-mail');
    await tester.enterText(find.byKey(const ValueKey('email-password')), 'x');
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.enterText(
        find.byKey(const ValueKey('new-email')), 'nouveau@kitunga.site');
    await tester.enterText(find.byKey(const ValueKey('email-password')), 'faux');
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Mot de passe incorrect.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('email-password')), 'secret1');
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(calls.last, ('secret1', 'nouveau@kitunga.site'));
    expect(find.text('Vérifiez votre nouvelle adresse'), findsOneWidget);
  });
}
