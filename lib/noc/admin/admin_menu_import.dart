import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart' show salesCall, fcfa;
import '/noc/ui/admin_kit.dart';

/// Import d'un menu de restaurant (admin) : on colle le menu tel qu'il est
/// écrit, l'aperçu s'affiche, puis les plats sont créés en une fois
/// (fonction kitungaImportMenu).
typedef MenuLine = ({String section, String name, int price});

/// Lit un menu collé : lignes de rubrique (« # Grillades », « NOS GRILLADES »
/// ou ligne sans prix) puis lignes de plats « Nom ....... 2500 FCFA » ou
/// « Nom ; 2500 ». Renvoie les plats et les lignes non comprises.
({List<MenuLine> lines, List<String> unread}) parseMenuText(String text) {
  var section = '';
  final lines = <MenuLine>[];
  final unread = <String>[];
  final priceAtEnd =
      RegExp(r'^(.*?)[\s.;:\-–_…]*(\d{1,3}(?:[\s.  ]?\d{3})*|\d+)\s*(?:f\s*cfa|fcfa|cfa|f|frs?)?\s*$',
          caseSensitive: false);
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      section = _sectionName(line.substring(1));
      continue;
    }
    final m = priceAtEnd.firstMatch(line);
    final name = m == null
        ? ''
        : m[1]!.replaceAll(RegExp(r'[.…_]{2,}'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final price = m == null
        ? null
        : int.tryParse(m[2]!.replaceAll(RegExp(r'[\s.  ]'), ''));
    if (m != null && name.isNotEmpty && price != null && price > 0) {
      lines.add((section: section, name: name, price: price));
    } else if (!RegExp(r'\d').hasMatch(line)) {
      // Ligne sans chiffre : titre de rubrique.
      section = _sectionName(line);
    } else {
      unread.add(line);
    }
  }
  return (lines: lines, unread: unread);
}

/// « NOS PLATS AFRICAINS » → « Plats africains ».
String _sectionName(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceFirst(RegExp(r'^(nos|notre|les)\s+', caseSensitive: false), '');
  s = s.replaceAll(':', '').trim();
  if (s.isEmpty) return '';
  final lower = s.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

Future<void> showMenuImport(BuildContext context,
    {required String sellerUid, required String sellerName}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdminThemeScope(
        child: _MenuImportDialog(sellerUid: sellerUid, sellerName: sellerName)),
  );
}

class _MenuImportDialog extends StatefulWidget {
  const _MenuImportDialog({required this.sellerUid, required this.sellerName});

  final String sellerUid;
  final String sellerName;

  @override
  State<_MenuImportDialog> createState() => _MenuImportDialogState();
}

class _MenuImportDialogState extends State<_MenuImportDialog> {
  final _text = TextEditingController();
  final _portions = TextEditingController(text: '50');
  bool _sideOption = true;
  bool _busy = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _portions.dispose();
    super.dispose();
  }

  List<MenuLine> _sides(List<MenuLine> lines) => [
        for (final l in lines)
          if (l.section.toLowerCase().contains('accompagnement')) l,
      ];

  Future<void> _import(List<MenuLine> lines) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final sides = _sides(lines);
    try {
      final r = await salesCall('kitungaImportMenu', {
        'sellerUid': widget.sellerUid,
        'portions': int.tryParse(_portions.text.trim()) ?? 50,
        'items': [
          for (final l in lines)
            {'section': l.section, 'name': l.name, 'price': l.price},
        ],
        if (_sideOption && sides.isNotEmpty)
          'sideOption': {
            'name': 'Accompagnement',
            'choices': [
              for (final s in sides) {'label': s.name, 'price': s.price},
            ],
          },
      });
      final skipped = (r['skipped'] as List? ?? const []).length;
      setState(() {
        _busy = false;
        _result = '${r['created']} plat(s) ajouté(s)'
            '${skipped > 0 ? ' · $skipped déjà présent(s), ignoré(s)' : ''}'
            '${r['published'] == true ? ' · publiés' : ' · en brouillon (photo à ajouter)'}';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseMenuText(_text.text);
    final sides = _sides(parsed.lines);
    final sections = <String, List<MenuLine>>{};
    for (final l in parsed.lines) {
      sections.putIfAbsent(l.section.isEmpty ? 'Sans rubrique' : l.section,
          () => []).add(l);
    }
    final wide = MediaQuery.sizeOf(context).width > 900;
    final input = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            'Collez le menu : une rubrique par ligne (ex. « NOS GRILLADES » ou '
            '« # Grillades »), puis un plat par ligne avec son prix '
            '(ex. « Brochette de bœuf ....... 2500 FCFA »).',
            style: AdminText.label(size: 12.5)),
        const SizedBox(height: 10.0),
        Expanded(
          child: TextField(
            controller: _text,
            enabled: !_busy,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            onChanged: (_) => setState(() {
              _result = null;
            }),
            style: AdminText.body(size: 13.0),
            decoration: const InputDecoration(
                hintText: 'NOS PLATS AFRICAINS\n'
                    'Poisson salé aux aubergines ....... 2500 FCFA\n'
                    'Saka-saka avec poisson salé ....... 2500 FCFA\n\n'
                    'NOS ACCOMPAGNEMENTS\nRiz gras ....... 500 FCFA'),
          ),
        ),
      ],
    );
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Aperçu : ${parsed.lines.length} plat(s), ${sections.length} rubrique(s)',
            style: AdminText.strong(size: 13.5)),
        const SizedBox(height: 8.0),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AdminColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminRadius.md),
              border: Border.all(color: AdminColors.border),
            ),
            child: parsed.lines.isEmpty
                ? Center(
                    child: Text('L\'aperçu apparaît ici.',
                        style: AdminText.label()))
                : ListView(
                    padding: const EdgeInsets.all(12.0),
                    children: [
                      for (final e in sections.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
                          child: Text(e.key.toUpperCase(),
                              style: AdminText.caps(color: AdminColors.red)),
                        ),
                        for (final l in e.value)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(l.name,
                                        style: AdminText.body(size: 13.0))),
                                Text(fcfa(l.price),
                                    style: AdminText.strong(size: 13.0)),
                              ],
                            ),
                          ),
                      ],
                      if (parsed.unread.isNotEmpty) ...[
                        const SizedBox(height: 10.0),
                        Text('Lignes non comprises (ignorées) :',
                            style: AdminText.strong(
                                size: 12.5, color: AdminColors.orange)),
                        for (final u in parsed.unread)
                          Text('• $u', style: AdminText.label(size: 12.0)),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000.0, maxHeight: 720.0),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AdminIconBadge(Icons.restaurant_menu_rounded,
                      round: false, size: 42.0),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text('Importer le menu · ${widget.sellerName}',
                        style: AdminText.h2()),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: input),
                          const SizedBox(width: 16.0),
                          Expanded(child: preview),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: input),
                          const SizedBox(height: 12.0),
                          Expanded(child: preview),
                        ],
                      ),
              ),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  SizedBox(
                    width: 120.0,
                    child: TextField(
                      controller: _portions,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      style: AdminText.body(size: 13.5),
                      decoration:
                          const InputDecoration(labelText: 'Portions / plat'),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                        'Quantité disponible de chaque plat. Le restaurant '
                        'l\'ajuste ensuite depuis son application (0 = épuisé).',
                        style: AdminText.label(size: 12.0)),
                  ),
                ],
              ),
              if (sides.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _sideOption,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _sideOption = v ?? false),
                  title: Text(
                      'Proposer aussi les ${sides.length} accompagnements en '
                      'option sur chaque plat',
                      style: AdminText.body(size: 13.5)),
                ),
              if (_error != null)
                Text(_error!, style: AdminText.strong(color: AdminColors.red)),
              if (_result != null)
                Text(_result!, style: AdminText.strong(color: AdminColors.green)),
              const SizedBox(height: 8.0),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10.0,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: Text(_result == null ? 'Annuler' : 'Fermer'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy || parsed.lines.isEmpty || _result != null
                        ? null
                        : () => _import(parsed.lines),
                    icon: _busy
                        ? const SizedBox(
                            width: 16.0,
                            height: 16.0,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.0, color: Colors.white))
                        : const Icon(Icons.download_done_rounded),
                    label: Text('Importer ${parsed.lines.length} plat(s)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
