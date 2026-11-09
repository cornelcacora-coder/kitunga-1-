import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/mobile/components/prescription/kitunga_prescription.dart';

/// Ordonnances : envoi par le client, vérification par la pharmacie.
void main() {
  const photo = 'https://firebasestorage.googleapis.com/v0/b/x/o/prescriptions%2Fmarie%2F1.jpg';
  final calls = <(String, Map<String, dynamic>)>[];
  var mine = <Map<String, dynamic>>[];
  var received = <Map<String, dynamic>>[];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    prescriptionBackendOverride = (name, data) async {
      calls.add((name, data));
      return switch (name) {
        'kitungaMyPrescriptions' => {'prescriptions': mine},
        'kitungaSellerPrescriptions' => {'prescriptions': received},
        _ => {'ok': true, 'status': 'pending'},
      };
    };
    prescriptionPhotoOverride = () async => photo;
  });
  setUp(calls.clear);

  Future<void> open(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: home),
    ));
    await tester.pumpAndSettle();
  }

  Widget gate(List<bool> results) => Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await kitungaPrescriptionGate(
              context,
              sellerUid: 'pharma',
              sellerName: 'Pharma Plus')),
          child: const Text('Ajouter au panier'),
        ),
      );

  testWidgets('ordonnance validée : le médicament peut être ajouté',
      (tester) async {
    mine = [{'id': 'p1', 'status': 'approved'}];
    final results = <bool>[];
    await open(tester, gate(results));
    await tester.tap(find.text('Ajouter au panier'));
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(find.text('Médicament sur ordonnance'), findsNothing);
  });

  testWidgets('sans ordonnance : photo puis envoi à la pharmacie',
      (tester) async {
    mine = [];
    final results = <bool>[];
    await open(tester, gate(results));
    await tester.tap(find.text('Ajouter au panier'));
    await tester.pumpAndSettle();
    expect(find.text('Médicament sur ordonnance'), findsOneWidget);
    await tester.tap(find.text('Envoyer à la pharmacie'));
    await tester.pumpAndSettle();
    expect(find.text('Ajoutez la photo de votre ordonnance.'), findsOneWidget);
    await tester.tap(find.text('Photographier l\'ordonnance'));
    await tester.pumpAndSettle();
    expect(find.text('Photo 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Pour mon fils');
    await tester.tap(find.text('Envoyer à la pharmacie'));
    await tester.pumpAndSettle();
    final sent = calls.last;
    expect(sent.$1, 'kitungaSubmitPrescription');
    expect(sent.$2, {'sellerUid': 'pharma', 'photos': [photo],
      'note': 'Pour mon fils'});
    expect(find.textContaining('Ordonnance envoyée à Pharma Plus'),
        findsOneWidget);
    // Pas encore validée : le médicament n'est pas ajouté.
    expect(results, [false]);
  });

  testWidgets('en attente ou refusée : message adapté', (tester) async {
    mine = [{'id': 'p1', 'status': 'pending'}];
    await open(tester, gate([]));
    await tester.tap(find.text('Ajouter au panier'));
    await tester.pumpAndSettle();
    expect(find.textContaining('en cours de vérification par Pharma Plus'),
        findsOneWidget);
    expect(find.text('Envoyer à la pharmacie'), findsNothing);
  });

  testWidgets('pharmacie : valider, refuser avec motif', (tester) async {
    received = [
      {'id': 'p1', 'status': 'pending', 'clientName': 'Marie',
        'clientPhone': '061234567', 'photos': [photo], 'note': 'Urgent',
        'createdAt': '2026-11-09T10:00:00Z'},
      {'id': 'p2', 'status': 'used', 'clientName': 'Jean', 'photos': [photo],
        'createdAt': '2026-11-08T10:00:00Z'},
    ];
    await open(tester, const SellerPrescriptionsPage());
    expect(find.text('Marie'), findsOneWidget);
    expect(find.text('À vérifier'), findsOneWidget);
    expect(find.text('Commandée'), findsOneWidget);
    expect(find.text('« Urgent »'), findsOneWidget);
    expect(find.text('Appeler le client'), findsOneWidget);
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ordonnance illisible');
    await tester.tap(find.text('Refuser').last);
    await tester.pumpAndSettle();
    expect(calls.firstWhere((c) => c.$1 == 'kitungaReviewPrescription').$2,
        {'id': 'p1', 'decision': 'reject', 'note': 'Ordonnance illisible'});
    calls.clear();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(calls.firstWhere((c) => c.$1 == 'kitungaReviewPrescription').$2,
        {'id': 'p1', 'decision': 'approve'});
    expect(tester.takeException(), isNull);
  });
}
