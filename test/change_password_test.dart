import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitunga/mobile/common/security/change_password_page.dart';

/// Changement de mot de passe : rien n'est changé sans confirmation exacte,
/// et le succès n'est annoncé que s'il a vraiment eu lieu.
void main() {
  final calls = <(String, String)>[];
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    changePasswordOverride = (current, next) async {
      calls.add((current, next));
      return current == 'ancien1' ? null : 'wrong-password';
    };
  });

  testWidgets('confirmation, mot de passe actuel faux, réussite',
      (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    bool? done;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => done = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
          child: const Text('Ouvrir'),
        ),
      )),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    final save = find.text('Enregistrer le nouveau mot de passe');

    await tester.enterText(fields.at(0), 'ancien1');
    await tester.enterText(fields.at(1), 'nouveau1');
    await tester.enterText(fields.at(2), 'nouveau2');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Les deux mots de passe ne correspondent pas.'),
        findsOneWidget);
    expect(calls, isEmpty); // rien n'a été changé

    await tester.enterText(fields.at(0), 'faux');
    await tester.enterText(fields.at(2), 'nouveau1');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Mot de passe actuel incorrect.'), findsOneWidget);
    expect(done, isNull); // pas de faux succès

    await tester.enterText(fields.at(0), 'ancien1');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls.last, ('ancien1', 'nouveau1'));
    expect(done, isTrue);
    expect(find.textContaining('Mot de passe modifié'), findsOneWidget);
  });
}
