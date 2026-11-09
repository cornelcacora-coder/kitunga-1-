import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/backend/kitunga_cuisines.dart';
import 'package:kitunga/noc/admin/admin_launch_partners.dart';
import 'package:kitunga/noc/admin/admin_menu_import.dart';
import 'package:kitunga/noc/sales/sales_common.dart';

/// Import de menu (Le Crisp'nCroc) et référentiel des cuisines.
void main() {
  final menu = File('test/menu_crispncroc.txt').readAsStringSync();

  test('menu du Crisp\'nCroc : 30 plats, 4 rubriques, rien d\'ignoré', () {
    final r = parseMenuText(menu);
    expect(r.unread, isEmpty);
    expect(r.lines.length, 30);
    final sections = {for (final l in r.lines) l.section};
    expect(sections, {
      'Plats africains',
      'Grillades',
      'Plats d\'ailleurs',
      'Accompagnements',
    });
    expect(r.lines.first,
        (section: 'Plats africains', name: 'Poisson salé aux aubergines',
          price: 2500));
    // « 1/2 » fait partie du nom, le prix est le dernier nombre.
    expect(r.lines.firstWhere((l) => l.name.startsWith('Poulet doux')),
        (section: 'Grillades', name: 'Poulet doux 1/2', price: 2000));
    expect(r.lines.where((l) => l.section == 'Accompagnements').length, 7);
  });

  test('menu de Zone de Confort : 33 plats, prix de l\'affiche', () {
    final zone = kLaunchPartners.firstWhere((p) => p.name == 'Zone de Confort');
    expect(zone.menuDraft, isFalse);
    final r = parseMenuText(zone.menu);
    expect(r.unread, isEmpty);
    expect(r.lines.length, 33);
    final count = <String, int>{};
    for (final l in r.lines) {
      count[l.section] = (count[l.section] ?? 0) + 1;
    }
    expect(count, {
      'Plats africains': 20,
      'Grillades': 4,
      'Autres plats': 3,
      'Accompagnements': 5,
      'Emballage': 1,
    });
    MenuLine dish(String start) =>
        r.lines.firstWhere((l) => l.name.startsWith(start));
    expect(dish('Cuisses de poulet (3 pièces)').price, 2000);
    expect(dish('Riz gras').price, 1500);
    expect(dish('Saka-saka').price, 1000);
    expect(dish('Barquette').price, 200);
    expect(dish('Bouillon de mboto').name, 'Bouillon de mboto / mbessé');
  });

  test('autres écritures de prix', () {
    final r = parseMenuText('# Boissons\nJus de bissap ; 1 000\n'
        'Eau minérale 500F\nCafé - 300 fcfa\nPlat sans prix 12a');
    expect(r.lines.map((l) => (l.name, l.price)).toList(), [
      ('Jus de bissap', 1000),
      ('Eau minérale', 500),
      ('Café', 300),
    ]);
    expect(r.unread, ['Plat sans prix 12a']);
  });

  test('cuisines : suggestions de plats', () {
    expect(kCuisines, contains('Congolaise (Brazzaville)'));
    expect(kCuisines, contains('Angolaise'));
    expect(dishSuggestions('s').isEmpty, isTrue); // 2 lettres minimum
    final saka = dishSuggestions('saka');
    expect(saka.first.name, startsWith('Saka-saka'));
    // Les cuisines du restaurant passent en premier.
    final muamba = dishSuggestions('moamb', cuisines: ['Angolaise']);
    expect(muamba.first.name, startsWith('Muamba'));
    expect(dishSuggestions('frites').first.section, 'Accompagnements');
    expect(dishSuggestions('bissap').first.section, 'Boissons');
    // Sans accents.
    expect(dishSuggestions('ndole').first.name, 'Ndolé');
  });

  testWidgets('admin : coller le menu, aperçu, import avec option',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('fr');
    final calls = <Map<String, dynamic>>[];
    salesBackendOverride = (f, d) async {
      calls.add({'f': f, ...d});
      return {'created': 30, 'skipped': [], 'published': true};
    };
    tester.view.physicalSize = const Size(1280, 900);
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
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMenuImport(context,
                sellerUid: 'crisp', sellerName: 'Le Crisp\'nCroc'),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, menu);
    await tester.pumpAndSettle();
    expect(find.text('Aperçu : 30 plat(s), 4 rubrique(s)'), findsOneWidget);
    expect(find.textContaining('7 accompagnements en option'), findsOneWidget);
    await tester.tap(find.text('Importer 30 plat(s)'));
    await tester.pumpAndSettle();
    final c = calls.single;
    expect(c['f'], 'kitungaImportMenu');
    expect(c['sellerUid'], 'crisp');
    expect(c['portions'], 50);
    expect((c['items'] as List).length, 30);
    expect(((c['sideOption'] as Map)['choices'] as List).length, 7);
    expect(find.textContaining('30 plat(s) ajouté(s)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    salesBackendOverride = null;
  });
}
