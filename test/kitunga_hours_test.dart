import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitunga/backend/kitunga_hours.dart';
import 'package:kitunga/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';

/// Horaires du lundi au dimanche (listes déroulantes).
void main() {
  // 9 novembre 2026 = lundi.
  DateTime at(int weekday, int h, [int m = 0]) =>
      DateTime(2026, 11, 8 + weekday, h, m);

  test('texte enregistré : jours identiques regroupés', () {
    expect(formatWeek(kDefaultWeek), 'Lun-Sam 8h00-18h00 · Dim fermé');
    final w = [
      for (var i = 0; i < 7; i++)
        i < 5
            ? (open: true, from: 8 * 60, to: 20 * 60)
            : i == 5
                ? (open: true, from: 9 * 60, to: 14 * 60)
                : (open: false, from: 0, to: 0),
    ];
    expect(formatWeek(w), 'Lun-Ven 8h00-20h00 · Sam 9h00-14h00 · Dim fermé');
    expect(formatWeek(List.filled(7, (open: true, from: 630, to: null))),
        'Tous les jours dès 10h30');
    expect(formatWeek(List.filled(7, (open: false, from: 0, to: 0))), '');
  });

  test('relecture : nouveau format, ancien « 8h - 18h », texte libre', () {
    final w = parseWeek('Lun-Ven 8h00-20h00 · Sam 9h00-14h00 · Dim fermé')!;
    expect(w[4], (open: true, from: 480, to: 1200));
    expect(w[5].from, 540);
    expect(w[6].open, isFalse);
    expect(formatWeek(parseWeek(formatWeek(w))!), formatWeek(w));
    expect(parseWeek('8h - 18h')!.every((d) => d.open && d.from == 480),
        isTrue);
    expect(parseWeek('Tous les jours dès 10h30')![3],
        (open: true, from: 630, to: null));
    expect(parseWeek('Le matin seulement'), isNull);
    expect(parseWeek(''), isNull);
  });

  test('ouvert ou fermé selon le jour et l\'heure', () {
    const h = 'Lun-Ven 8h00-20h00 · Sam 9h00-14h00 · Dim fermé';
    expect(kitungaOpeningStatus(h, at(1, 10))!.label,
        'Ouvert · ferme à 20h00');
    expect(kitungaOpeningStatus(h, at(6, 7))!.label,
        'Fermé · ouvre à 9h00');
    expect(kitungaOpeningStatus(h, at(6, 15))!.label,
        'Fermé · ouvre lundi à 8h00');
    expect(kitungaOpeningStatus(h, at(7, 12))!.label,
        'Fermé · ouvre demain à 8h00');
    expect(kitungaOpeningStatus('Tous les jours dès 10h30', at(3, 11))!.open,
        isTrue);
    // Soirée qui passe minuit.
    const night = 'Lun-Sam 18h00-2h00 · Dim fermé';
    expect(kitungaOpeningStatus(night, at(1, 23))!.open, isTrue);
    expect(kitungaOpeningStatus(night, at(2, 1))!.open, isTrue);
    expect(kitungaOpeningStatus(night, at(2, 3))!.open, isFalse);
    // Anciens horaires : toujours compris.
    expect(kitungaOpeningStatus('8h - 18h', at(1, 9))!.open, isTrue);
  });

  testWidgets('sélecteur : définir, fermer un jour, appliquer le lundi',
      (tester) async {
    final values = <String>[];
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: KitungaHoursPicker(initial: '', onChanged: values.add),
        ),
      ),
    ));
    await tester.tap(find.text('Définir les horaires'));
    await tester.pumpAndSettle();
    expect(values.last, 'Lun-Sam 8h00-18h00 · Dim fermé');
    for (final d in kDayShort) {
      expect(find.text(d), findsOneWidget); // écran étroit : jours abrégés
    }
    // Samedi fermé.
    await tester.tap(find.byType(Switch).at(5));
    await tester.pumpAndSettle();
    expect(values.last, 'Lun-Ven 8h00-18h00 · Sam, Dim fermé');
    // Lundi : ouverture 9h00 dans la liste déroulante.
    await tester.tap(find.byType(DropdownButton<int?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('9h00').last);
    await tester.pumpAndSettle();
    expect(values.last, startsWith('Lun 9h00-18h00 · Mar-Ven 8h00-18h00'));
    await tester.tap(find.text('Appliquer les horaires du lundi à tous les jours'));
    await tester.pumpAndSettle();
    expect(values.last, 'Tous les jours 9h00-18h00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sélecteur : anciens horaires affichés puis repris',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KitungaHoursPicker(
            initial: 'Ouvert le matin', onChanged: (_) {}),
      ),
    ));
    expect(find.text('Horaires actuels : « Ouvert le matin »'), findsOneWidget);
    expect(find.text('Choisir les horaires jour par jour'), findsOneWidget);
  });
}
