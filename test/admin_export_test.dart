import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kitunga/noc/ui/admin_export.dart';

/// Export PDF, Excel et Word : fichiers valides, accents et montants.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final data = AdminExportData(
    title: 'Commandes',
    subtitle: '30 derniers jours · onglet « Toutes » · 3 commandes',
    fileName: 'commandes',
    headers: ['Référence', 'Client', 'Commerce', 'Zone', 'Montant', 'Statut'],
    flex: [3, 3, 3, 2, 2, 2],
    moneyColumns: {4},
    rows: [
      ['KTG-241000', 'Grâce Loemba', 'Pharmacie du Centre', 'Poto-Poto', 2500, 'Livrée'],
      ['KTG-241001', 'Élodie & Co <test>', 'Chez Paul', 'Bacongo', 1234567, 'À confirmer'],
      ['KTG-241002', 'Jean', null, '', 0, 'Annulée'],
    ],
  );
  final now = DateTime(2026, 11, 8, 10, 30);

  setUpAll(() => initializeDateFormatting('fr'));

  Map<String, String> unzip(List<int> bytes) => {
        for (final f in ZipDecoder().decodeBytes(bytes))
          f.name: utf8.decode(f.content as List<int>),
      };

  test('Excel : classeur valide, montants en nombres, texte échappé', () {
    final files = unzip(buildXlsx(data, now));
    expect(files.keys, containsAll([
      '[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels', 'xl/worksheets/sheet1.xml', 'xl/styles.xml',
    ]));
    final sheet = files['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('<v>1234567</v>'));
    expect(sheet, contains('Élodie &amp; Co &lt;test&gt;'));
    expect(sheet, contains('<autoFilter ref="A5:F8"/>'));
    expect(sheet, contains('state="frozen"'));
    expect(files['xl/workbook.xml'], contains('name="Commandes"'));
  });

  test('Word : document valide, en-tête répété, montants formatés', () {
    final files = unzip(buildDocx(data, now));
    final doc = files['word/document.xml']!;
    expect(doc, contains('<w:tblHeader/>'));
    expect(doc, contains('1\u202F234\u202F567 F'));
    expect(doc, contains('w:orient="landscape"'));
    expect(doc, contains('Élodie &amp; Co &lt;test&gt;'));
  });

  test('PDF : document généré avec les polices accentuées', () async {
    final bytes = await buildPdf(data, now);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(10000));
  });

  test('noms de fichiers', () async {
    final x = await buildAdminExport(data, AdminExportFormat.excel, now: now);
    expect(x.name, 'kitunga_commandes_2026-11-08_10-30.xlsx');
    final w = await buildAdminExport(data, AdminExportFormat.word, now: now);
    expect(w.name.endsWith('.docx'), isTrue);
    // Fichiers d'exemple pour contrôle visuel (variable KITUNGA_EXPORT_DIR).
    final dir = Platform.environment['KITUNGA_EXPORT_DIR'];
    if (dir != null) {
      for (final f in AdminExportFormat.values) {
        final out = await buildAdminExport(data, f, now: now);
        File('$dir/${out.name}').writeAsBytesSync(out.bytes);
      }
    }
  });
}
