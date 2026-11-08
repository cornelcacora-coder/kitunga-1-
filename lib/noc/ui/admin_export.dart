import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'admin_export_save_stub.dart'
    if (dart.library.js_interop) 'admin_export_save_web.dart';
import 'admin_kit.dart';

/// Export des tableaux de l'administration en PDF, Excel (.xlsx) et Word
/// (.docx), générés dans le navigateur à partir des lignes affichées
/// (mêmes filtres que la page).
class AdminExportData {
  AdminExportData({
    required this.title,
    required this.fileName,
    required this.headers,
    required this.rows,
    this.subtitle,
    this.flex,
    this.moneyColumns = const {},
  });

  /// Titre du document (ex. « Commandes »).
  final String title;

  /// Précisions : période, filtres, nombre de lignes.
  final String? subtitle;

  /// Base du nom de fichier, sans extension (ex. « commandes »).
  final String fileName;
  final List<String> headers;

  /// Valeurs : texte ou nombre (les nombres restent des nombres dans Excel).
  final List<List<Object?>> rows;

  /// Largeurs relatives des colonnes (PDF et Word).
  final List<int>? flex;

  /// Colonnes de montants en FCFA (index).
  final Set<int> moneyColumns;
}

enum AdminExportFormat { pdf, excel, word }

final _num = NumberFormat.decimalPattern('fr');

/// Texte affiché d'une valeur (PDF, Word).
String exportText(AdminExportData d, int col, Object? v) {
  if (v == null) return '';
  if (v is num) {
    final s = _num.format(v);
    return d.moneyColumns.contains(col) ? '$s F' : s;
  }
  return v.toString();
}

String _stamp(DateTime now) => DateFormat('yyyy-MM-dd_HH-mm').format(now);

String _generated(DateTime now) =>
    'Généré le ${DateFormat('d MMMM yyyy à HH:mm', 'fr').format(now)}';

/// Fabrique le fichier demandé (octets, nom, type).
Future<({Uint8List bytes, String name, String mime})> buildAdminExport(
    AdminExportData d, AdminExportFormat f,
    {DateTime? now}) async {
  final at = now ?? DateTime.now();
  final base = 'kitunga_${d.fileName}_${_stamp(at)}';
  switch (f) {
    case AdminExportFormat.pdf:
      return (
        bytes: await buildPdf(d, at),
        name: '$base.pdf',
        mime: 'application/pdf'
      );
    case AdminExportFormat.excel:
      return (
        bytes: buildXlsx(d, at),
        name: '$base.xlsx',
        mime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
    case AdminExportFormat.word:
      return (
        bytes: buildDocx(d, at),
        name: '$base.docx',
        mime:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      );
  }
}

// ── PDF ──────────────────────────────────────────────────────────────────

Future<Uint8List> buildPdf(AdminExportData d, DateTime now) async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  pw.MemoryImage? logo;
  try {
    logo = pw.MemoryImage(
        (await rootBundle.load('assets/logo/kitunga_logo.png'))
            .buffer
            .asUint8List());
  } catch (_) {}

  const red = PdfColor.fromInt(0xFFE51A1A);
  const ink = PdfColor.fromInt(0xFF16181D);
  const muted = PdfColor.fromInt(0xFF6F737C);
  const zebra = PdfColor.fromInt(0xFFF6F7FA);
  const line = PdfColor.fromInt(0xFFE6E8EE);

  final doc = pw.Document(
    title: 'Kitunga — ${d.title}',
    author: 'Kitunga Administration',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final flex = d.flex ?? List.filled(d.headers.length, 1);
  final numeric = {
    for (var c = 0; c < d.headers.length; c++)
      if (d.rows.isNotEmpty && d.rows.every((r) => r[c] == null || r[c] is num))
        c,
  };

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
    header: (context) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: red, width: 2))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.Image(logo, height: 38),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(d.title,
                    style: pw.TextStyle(
                        font: bold, fontSize: 17, color: ink)),
                if (d.subtitle != null)
                  pw.Text(d.subtitle!,
                      style: const pw.TextStyle(fontSize: 9.5, color: muted)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('KITUNGA — Administration',
                  style: pw.TextStyle(font: bold, fontSize: 9, color: red)),
              pw.Text(_generated(now),
                  style: const pw.TextStyle(fontSize: 8.5, color: muted)),
            ],
          ),
        ],
      ),
    ),
    footer: (context) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('${d.rows.length} ligne${d.rows.length > 1 ? 's' : ''}',
              style: const pw.TextStyle(fontSize: 8.5, color: muted)),
          pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8.5, color: muted)),
        ],
      ),
    ),
    build: (context) => [
      if (d.rows.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Text('Aucune donnée pour ces filtres.',
              style: const pw.TextStyle(color: muted)),
        )
      else
        pw.TableHelper.fromTextArray(
          headers: d.headers,
          data: [
            for (final r in d.rows)
              [for (var c = 0; c < r.length; c++) exportText(d, c, r[c])],
          ],
          border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: line, width: 0.6)),
          headerDecoration: const pw.BoxDecoration(color: red),
          headerStyle:
              pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 9),
          headerAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 8.8, color: ink),
          oddRowDecoration: const pw.BoxDecoration(color: zebra),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          cellAlignments: {
            for (final c in numeric) c: pw.Alignment.centerRight,
          },
          headerAlignments: {
            for (final c in numeric) c: pw.Alignment.centerRight,
          },
          columnWidths: {
            for (var c = 0; c < flex.length; c++)
              c: pw.FlexColumnWidth(flex[c].toDouble()),
          },
        ),
    ],
  ));
  return doc.save();
}

// ── Excel (.xlsx) ────────────────────────────────────────────────────────

String _xml(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // Caractères de contrôle interdits en XML.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _colName(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

ArchiveFile _file(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

Uint8List _zip(List<ArchiveFile> files) {
  final a = Archive();
  for (final f in files) {
    a.addFile(f);
  }
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

const _xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

Uint8List buildXlsx(AdminExportData d, DateTime now) {
  final cols = d.headers.length;
  final rows = StringBuffer();
  var r = 0;
  String inline(int row, int col, String v, int style) =>
      '<c r="${_colName(col)}$row" t="inlineStr" s="$style"><is><t xml:space="preserve">${_xml(v)}</t></is></c>';

  // Titre, précisions, date, puis l'en-tête du tableau (ligne 5).
  rows.write('<row r="${++r}" ht="24" customHeight="1">${inline(r, 0, 'Kitunga — ${d.title}', 2)}</row>');
  rows.write('<row r="${++r}">${inline(r, 0, d.subtitle ?? '', 5)}</row>');
  rows.write('<row r="${++r}">${inline(r, 0, _generated(now), 5)}</row>');
  r++;
  final headerRow = ++r;
  rows.write('<row r="$headerRow" ht="20" customHeight="1">');
  for (var c = 0; c < cols; c++) {
    rows.write(inline(headerRow, c, d.headers[c], 1));
  }
  rows.write('</row>');
  for (final line in d.rows) {
    r++;
    rows.write('<row r="$r">');
    for (var c = 0; c < cols; c++) {
      final v = c < line.length ? line[c] : null;
      if (v is num) {
        rows.write(
            '<c r="${_colName(c)}$r" s="${d.moneyColumns.contains(c) ? 4 : 6}"><v>$v</v></c>');
      } else {
        rows.write(inline(r, c, v?.toString() ?? '', 3));
      }
    }
    rows.write('</row>');
  }

  // Largeur des colonnes selon le contenu le plus long (bornée).
  final widths = List.generate(cols, (c) {
    var w = d.headers[c].length;
    for (final line in d.rows.take(500)) {
      final v = c < line.length ? exportText(d, c, line[c]) : '';
      if (v.length > w) w = v.length;
    }
    return (w + 3).clamp(10, 60);
  });

  final lastRef = '${_colName(cols - 1)}${headerRow + d.rows.length}';
  final sheet = '$_xmlHead'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheetViews><sheetView workbookViewId="0" showGridLines="0">'
      '<pane ySplit="$headerRow" topLeftCell="A${headerRow + 1}" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>'
      '<cols>${[for (var c = 0; c < cols; c++) '<col min="${c + 1}" max="${c + 1}" width="${widths[c]}" customWidth="1"/>'].join()}</cols>'
      '<sheetData>$rows</sheetData>'
      '${d.rows.isEmpty ? '' : '<autoFilter ref="A$headerRow:$lastRef"/>'}'
      '<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>'
      '<pageSetup orientation="landscape"/>'
      '</worksheet>';

  const styles = '$_xmlHead'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0 &quot;F&quot;"/></numFmts>'
      '<fonts count="4">'
      '<font><sz val="11"/><color rgb="FF16181D"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="15"/><color rgb="FFE51A1A"/><name val="Calibri"/></font>'
      '<font><sz val="10"/><color rgb="FF6F737C"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE51A1A"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2"><border/>'
      '<border><left/><right/><top/><bottom style="thin"><color rgb="FFE6E8EE"/></bottom><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="7">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="3" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';

  final sheetName = _xml(d.title.length > 31 ? d.title.substring(0, 31) : d.title)
      .replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ');
  return _zip([
    _file('[Content_Types].xml',
        '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>'),
    _file('_rels/.rels',
        '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>'),
    _file('xl/workbook.xml',
        '$_xmlHead<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="$sheetName" sheetId="1" r:id="rId1"/></sheets>'
        '${d.rows.isEmpty ? '' : '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">\'$sheetName\'!\$A\$$headerRow:\$${_colName(cols - 1)}\$${headerRow + d.rows.length}</definedName></definedNames>'}'
        '</workbook>'),
    _file('xl/_rels/workbook.xml.rels',
        '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>'),
    _file('xl/worksheets/sheet1.xml', sheet),
    _file('xl/styles.xml', styles),
  ]);
}

// ── Word (.docx) ─────────────────────────────────────────────────────────

Uint8List buildDocx(AdminExportData d, DateTime now) {
  // Page A4 paysage, marges de 1,27 cm : largeur utile 15 398 twips.
  const usable = 15398;
  final flex = d.flex ?? List.filled(d.headers.length, 1);
  final total = flex.fold(0, (s, f) => s + f);
  final widths = [for (final f in flex) (usable * f / total).round()];

  String run(String text,
          {bool bold = false, String color = '16181D', int size = 18}) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>'
      '${bold ? '<w:b/>' : ''}<w:color w:val="$color"/><w:sz w:val="$size"/></w:rPr>'
      '<w:t xml:space="preserve">${_xml(text)}</w:t></w:r>';
  String para(String runs, {int after = 60, String align = 'left'}) =>
      '<w:p><w:pPr><w:spacing w:after="$after"/><w:jc w:val="$align"/></w:pPr>$runs</w:p>';
  String cell(int c, String text,
      {String? fill, bool bold = false, String color = '16181D', bool right = false}) =>
      '<w:tc><w:tcPr><w:tcW w:w="${widths[c]}" w:type="dxa"/>'
      '${fill == null ? '' : '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>'}'
      '<w:vAlign w:val="center"/></w:tcPr>'
      '${para(run(text, bold: bold, color: color, size: 17), after: 0, align: right ? 'right' : 'left')}</w:tc>';

  final numeric = {
    for (var c = 0; c < d.headers.length; c++)
      if (d.rows.isNotEmpty && d.rows.every((r) => r[c] == null || r[c] is num))
        c,
  };
  final table = StringBuffer()
    ..write('<w:tbl><w:tblPr><w:tblW w:w="$usable" w:type="dxa"/>'
        '<w:tblBorders><w:bottom w:val="single" w:sz="4" w:color="E6E8EE"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="E6E8EE"/></w:tblBorders>'
        '<w:tblLayout w:type="fixed"/>'
        '<w:tblCellMar><w:top w:w="70" w:type="dxa"/><w:left w:w="100" w:type="dxa"/>'
        '<w:bottom w:w="70" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar>'
        '</w:tblPr><w:tblGrid>${[for (final w in widths) '<w:gridCol w:w="$w"/>'].join()}</w:tblGrid>')
    // En-tête répété sur chaque page.
    ..write('<w:tr><w:trPr><w:tblHeader/></w:trPr>')
    ..write([
      for (var c = 0; c < d.headers.length; c++)
        cell(c, d.headers[c],
            fill: 'E51A1A', bold: true, color: 'FFFFFF', right: numeric.contains(c))
    ].join())
    ..write('</w:tr>');
  for (var i = 0; i < d.rows.length; i++) {
    final line = d.rows[i];
    table.write('<w:tr><w:trPr><w:cantSplit/></w:trPr>');
    for (var c = 0; c < d.headers.length; c++) {
      table.write(cell(c, exportText(d, c, c < line.length ? line[c] : null),
          fill: i.isOdd ? 'F6F7FA' : null, right: numeric.contains(c)));
    }
    table.write('</w:tr>');
  }
  table.write('</w:tbl>');

  final body = StringBuffer()
    ..write(para(
        run('KITUNGA — ', bold: true, color: 'E51A1A', size: 32) +
            run(d.title, bold: true, size: 32),
        after: 40))
    ..write(para(run(d.subtitle ?? '', color: '6F737C', size: 19), after: 20))
    ..write(para(run(_generated(now), color: '6F737C', size: 17), after: 200))
    ..write(d.rows.isEmpty
        ? para(run('Aucune donnée pour ces filtres.', color: '6F737C'))
        : table.toString())
    ..write(para(
        run('${d.rows.length} ligne${d.rows.length > 1 ? 's' : ''}',
            color: '6F737C', size: 16),
        after: 0))
    ..write('<w:sectPr><w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>'
        '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" '
        'w:header="400" w:footer="400" w:gutter="0"/></w:sectPr>');

  return _zip([
    _file('[Content_Types].xml',
        '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>'),
    _file('_rels/.rels',
        '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>'),
    _file('word/document.xml',
        '$_xmlHead<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body</w:body></w:document>'),
  ]);
}

// ── Bouton ───────────────────────────────────────────────────────────────

/// Remplace le téléchargement dans les tests (fichier reçu).
@visibleForTesting
void Function(Uint8List bytes, String name, String mime)? adminExportSaveOverride;

/// Bouton « Exporter » : PDF, Excel ou Word des lignes affichées.
class AdminExportButton extends StatelessWidget {
  const AdminExportButton({super.key, required this.data});

  /// Données au moment du clic (null si rien à exporter encore).
  final AdminExportData? Function() data;

  Future<void> _export(BuildContext context, AdminExportFormat f) async {
    final messenger = ScaffoldMessenger.of(context);
    final d = data();
    if (d == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Les données sont encore en cours de chargement.')));
      return;
    }
    try {
      final file = await buildAdminExport(d, f);
      (adminExportSaveOverride ?? saveAdminFile)(file.bytes, file.name, file.mime);
      messenger.showSnackBar(SnackBar(
          content: Text('${file.name} téléchargé'),
          backgroundColor: const Color(0xFF136B3D)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Export impossible : $e'),
          backgroundColor: AdminColors.redDeep));
    }
  }

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<AdminExportFormat> item(
            AdminExportFormat f, IconData icon, Color color, String label,
            String hint) =>
        PopupMenuItem(
          value: f,
          child: Row(
            children: [
              Container(
                width: 34.0,
                height: 34.0,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(icon, size: 18.0, color: color),
              ),
              const SizedBox(width: 12.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AdminText.strong(size: 13.5)),
                  Text(hint, style: AdminText.label(size: 11.5)),
                ],
              ),
            ],
          ),
        );
    return PopupMenuButton<AdminExportFormat>(
      tooltip: 'Exporter',
      position: PopupMenuPosition.under,
      onSelected: (f) => _export(context, f),
      itemBuilder: (_) => [
        item(AdminExportFormat.pdf, Icons.picture_as_pdf_rounded,
            const Color(0xFFD93025), 'PDF', 'Prêt à imprimer'),
        item(AdminExportFormat.excel, Icons.table_chart_rounded,
            const Color(0xFF1D7044), 'Excel (.xlsx)', 'Calculs et filtres'),
        item(AdminExportFormat.word, Icons.description_rounded,
            const Color(0xFF2B579A), 'Word (.docx)', 'Rapport modifiable'),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.file_download_outlined, size: 18.0),
          label: const Text('Exporter'),
        ),
      ),
    );
  }
}
