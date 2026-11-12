import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/components/payment_method_widget.dart'
    show airtelAvailableOverride;
import 'package:kitunga/mobile/main_app/subscription/my_subscription_page.dart';

/// Module « Mon abonnement » : état, formules, paiement MoMo, historique.
void main() {
  final calls = <(String, Map<String, dynamic>)>[];
  var state = <String, dynamic>{};
  var mtn = 'paid';
  const plans = [
    {'key': 'quarterly', 'label': 'Trimestriel - 300 F', 'price': 300, 'days': 91},
    {'key': 'semester', 'label': 'Semestriel - 500 F', 'price': 500, 'days': 183},
    {'key': 'annual', 'label': 'Annuel - 1000 F', 'price': 1000, 'days': 365},
  ];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    subscriptionPollDelay = Duration.zero;
    subscriptionBackendOverride = (name, data) async {
      calls.add((name, data));
      return switch (name) {
        'kitungaMySubscription' => state,
        'kitungaStartSubscription' => {'referenceId': 'ref-12345678'},
        _ => {'status': mtn},
      };
    };
  });
  setUp(calls.clear);
  setUpAll(() => airtelAvailableOverride = () async => true);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('fr'),
      supportedLocales: [Locale('fr')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MySubscriptionPage(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('expiré : formule annuelle payée par MoMo', (tester) async {
    state = {'required': true, 'active': false,
      'until': '2026-11-01T10:00:00Z', 'daysLeft': 0, 'plans': plans,
      'history': [
        {'date': '2026-05-01T10:00:00Z', 'amount': 300,
          'plan': 'Semestriel - 300 F', 'status': 'Réussi'},
      ]};
    mtn = 'paid';
    await open(tester);
    expect(find.text('Pas d\'abonnement actif'), findsOneWidget);
    expect(find.textContaining('Terminé le 1 novembre 2026'), findsOneWidget);
    expect(find.text('Semestriel - 300 F · 300 F'), findsOneWidget);
    await tester.tap(find.text('Annuel · 12 mois'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '06 123 45 67');
    await tester.tap(find.text('Payer 1000 F avec MTN MoMo'));
    await tester.pumpAndSettle();
    expect(calls.firstWhere((c) => c.$1 == 'kitungaStartSubscription').$2,
        {'plan': 'annual', 'phone': '06 123 45 67', 'operator': 'MTN'});
    expect(find.textContaining('Paiement de 1000 F reçu'), findsOneWidget);
  });

  testWidgets('paiement de l\'abonnement avec Airtel Money', (tester) async {
    state = {'required': true, 'active': false, 'plans': plans,
      'history': []};
    mtn = 'paid';
    calls.clear();
    await open(tester);
    await tester.tap(find.text('Airtel Money'));
    await tester.pumpAndSettle();
    expect(find.text('Numéro Airtel Money'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '05 123 45 67');
    await tester.tap(find.text('Payer 300 F avec Airtel Money'));
    await tester.pumpAndSettle();
    expect(calls.firstWhere((c) => c.$1 == 'kitungaStartSubscription').$2,
        {'plan': 'quarterly', 'phone': '05 123 45 67', 'operator': 'Airtel'});
    expect(find.textContaining('Paiement de 300 F reçu'), findsOneWidget);
  });

  testWidgets('actif : jours restants ; paiement refusé par MTN',
      (tester) async {
    state = {'required': true, 'active': true,
      'until': '2027-05-10T10:00:00Z', 'daysLeft': 181, 'plans': plans,
      'history': []};
    mtn = 'failed';
    await open(tester);
    expect(find.text('Abonnement actif'), findsOneWidget);
    expect(find.textContaining('181 jours restants'), findsOneWidget);
    expect(find.text('Prolonger mon abonnement'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '06 123 45 67');
    await tester.tap(find.text('Payer 300 F avec MTN MoMo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MTN a refusé le paiement'), findsOneWidget);
  });

  testWidgets('vendeur : pas d\'abonnement', (tester) async {
    state = {'required': false, 'active': false, 'plans': plans,
      'history': []};
    await open(tester);
    expect(find.textContaining('commande sans abonnement'), findsOneWidget);
  });

  testWidgets('inscription : formule choisie, payer plus tard ou continuer',
      (tester) async {
    state = {'required': true, 'active': false, 'until': null, 'daysLeft': 0,
      'plans': plans, 'history': []};
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final results = <bool?>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await Navigator.of(context)
              .push<bool>(MaterialPageRoute(
                  builder: (_) => const MySubscriptionPage(
                      fromSignup: true,
                      initialPlan: 'annual',
                      phone: '068139237')))),
          child: const Text('Créer le compte'),
        ),
      ),
    ));
    await tester.tap(find.text('Créer le compte'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dernière étape'), findsOneWidget);
    expect(find.text('Payer 1000 F avec MTN MoMo'), findsOneWidget);
    expect(find.text('068139237'), findsOneWidget);
    await tester.tap(find.text('Payer plus tard'));
    await tester.pumpAndSettle();
    expect(results, [false]);
    // Deuxième essai : payé, puis « Continuer ».
    mtn = 'paid';
    await tester.tap(find.text('Créer le compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payer 1000 F avec MTN MoMo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
  });

  testWidgets('Airtel pas encore activé : grisé', (tester) async {
    airtelAvailableOverride = () async => false;
    addTearDown(() => airtelAvailableOverride = () async => true);
    state = {'required': true, 'active': false, 'plans': plans,
      'history': []};
    await open(tester);
    expect(find.textContaining('Bientôt disponible'), findsOneWidget);
    await tester.tap(find.textContaining('Airtel Money'));
    await tester.pumpAndSettle();
    expect(find.text('Payer 300 F avec MTN MoMo'), findsOneWidget);
  });
}
