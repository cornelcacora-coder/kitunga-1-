import 'package:flutter/material.dart';

/// Horaires d'ouverture d'un commerce, du lundi au dimanche.
///
/// Enregistrés comme avant dans le champ texte User.Horraire, sous une forme
/// lisible et relisible, par exemple :
///   « Lun-Ven 8h00-20h00 · Sam 9h00-14h00 · Dim fermé »
///   « Tous les jours dès 10h30 »
/// Les anciens horaires libres (« 8h - 18h ») restent compris.
typedef DayHours = ({bool open, int from, int? to}); // minutes ; to null = « dès »

const kDayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const kDayLong = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche', //
];

/// Semaine proposée quand on définit les horaires : lundi-samedi 8h-18h.
final List<DayHours> kDefaultWeek = [
  for (var i = 0; i < 7; i++) (open: i < 6, from: 8 * 60, to: 18 * 60),
];

String hourLabel(int minutes) =>
    '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';

String _range(DayHours d) => !d.open
    ? 'fermé'
    : d.to == null
        ? 'dès ${hourLabel(d.from)}'
        : '${hourLabel(d.from)}-${hourLabel(d.to!)}';

/// Texte enregistré : jours consécutifs identiques regroupés.
String formatWeek(List<DayHours> week) {
  assert(week.length == 7);
  if (week.every((d) => !d.open)) return '';
  if (week.every((d) => _range(d) == _range(week.first))) {
    return 'Tous les jours ${_range(week.first)}';
  }
  final parts = <String>[];
  var i = 0;
  while (i < 7) {
    var j = i;
    while (j + 1 < 7 && _range(week[j + 1]) == _range(week[i])) {
      j++;
    }
    final days = i == j
        ? kDayShort[i]
        : '${kDayShort[i]}${j == i + 1 ? ', ' : '-'}${kDayShort[j]}';
    parts.add('$days ${_range(week[i])}');
    i = j + 1;
  }
  return parts.join(' · ');
}

int? _minutes(String h, String? m) {
  final hh = int.tryParse(h);
  final mm = int.tryParse(m ?? '0');
  if (hh == null || mm == null || hh > 24 || mm > 59) return null;
  return hh * 60 + mm;
}

final _rangeRe = RegExp(
    r'^(?:(fermée?)|dès\s*(\d{1,2})\s*[hH:]\s*(\d{2})?|(\d{1,2})\s*[hH:]\s*(\d{2})?\s*(?:-|–|à)\s*(\d{1,2})\s*[hH:]\s*(\d{2})?)$',
    caseSensitive: false);

DayHours? _parseRange(String s) {
  final m = _rangeRe.firstMatch(s.trim());
  if (m == null) return null;
  if (m[1] != null) return (open: false, from: 8 * 60, to: 18 * 60);
  if (m[2] != null) {
    final f = _minutes(m[2]!, m[3]);
    return f == null ? null : (open: true, from: f, to: null);
  }
  final f = _minutes(m[4]!, m[5]);
  final t = _minutes(m[6]!, m[7]);
  if (f == null || t == null || f == t) return null;
  return (open: true, from: f, to: t);
}

/// Relit un texte d'horaires (format ci-dessus ou ancien « 8h - 18h », alors
/// valable tous les jours). null si le texte n'est pas compris.
List<DayHours>? parseWeek(String text) {
  final s = text.trim();
  if (s.isEmpty) return null;
  final all = RegExp(r'^tous les jours\s+(.*)$', caseSensitive: false)
      .firstMatch(s);
  if (all != null) {
    final d = _parseRange(all[1]!);
    return d == null ? null : List.filled(7, d);
  }
  final whole = _parseRange(s);
  if (whole != null) return List.filled(7, whole);
  final week = List<DayHours?>.filled(7, null);
  for (final part in s.split('·')) {
    final m = RegExp(r'^\s*([A-Za-zé]{3})(?:\s*([-,])\s*([A-Za-zé]{3}))?\s+(.*)$')
        .firstMatch(part);
    if (m == null) return null;
    final a = kDayShort.indexWhere((d) => d.toLowerCase() == m[1]!.toLowerCase());
    final b = m[3] == null
        ? a
        : kDayShort.indexWhere((d) => d.toLowerCase() == m[3]!.toLowerCase());
    final d = _parseRange(m[4]!);
    if (a < 0 || b < a || d == null) return null;
    if (m[2] == ',') {
      week[a] = d;
      week[b] = d;
    } else {
      for (var i = a; i <= b; i++) {
        week[i] = d;
      }
    }
  }
  // Jours non cités : fermés.
  return [
    for (final d in week) d ?? (open: false, from: 8 * 60, to: 18 * 60),
  ];
}

bool _openAt(DayHours d, int minute) {
  if (!d.open) return false;
  if (d.to == null) return minute >= d.from;
  return d.from < d.to!
      ? minute >= d.from && minute < d.to!
      : minute >= d.from; // jusqu'à minuit, la suite le lendemain
}

/// Statut d'ouverture à l'instant [now] pour des horaires de semaine.
({bool open, String label})? weekStatus(List<DayHours> week, DateTime now) {
  final today = now.weekday - 1; // 0 = lundi
  final minute = now.hour * 60 + now.minute;
  final d = week[today];
  final y = week[(today + 6) % 7];
  // Horaires de la veille qui passent minuit (ex. 18h-2h).
  final fromYesterday = y.open && y.to != null && y.to! < y.from &&
      minute < y.to!;
  if (fromYesterday) {
    return (open: true, label: 'Ouvert · ferme à ${hourLabel(y.to!)}');
  }
  if (_openAt(d, minute)) {
    return (
      open: true,
      label: d.to == null
          ? 'Ouvert depuis ${hourLabel(d.from)}'
          : 'Ouvert · ferme à ${hourLabel(d.to! % (24 * 60))}',
    );
  }
  if (d.open && minute < d.from) {
    return (open: false, label: 'Fermé · ouvre à ${hourLabel(d.from)}');
  }
  for (var k = 1; k <= 7; k++) {
    final n = week[(today + k) % 7];
    if (n.open) {
      final when = k == 1 ? 'demain' : kDayLong[(today + k) % 7].toLowerCase();
      return (open: false, label: 'Fermé · ouvre $when à ${hourLabel(n.from)}');
    }
  }
  return (open: false, label: 'Fermé');
}

/// Choix des horaires du lundi au dimanche (listes déroulantes).
/// [initial] : texte enregistré ; [onChanged] reçoit le nouveau texte.
class KitungaHoursPicker extends StatefulWidget {
  const KitungaHoursPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.textStyle,
    this.accent = const Color(0xFFE51A1A),
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final TextStyle? textStyle;

  /// Couleur des interrupteurs et boutons (rouge Kitunga).
  final Color accent;

  @override
  State<KitungaHoursPicker> createState() => _KitungaHoursPickerState();
}

class _KitungaHoursPickerState extends State<KitungaHoursPicker> {
  late List<DayHours>? _week = parseWeek(widget.initial);
  late final String _legacy =
      _week == null ? widget.initial.trim() : ''; // ancien texte non compris

  static final _opens = [for (var m = 0; m < 24 * 60; m += 30) m];
  static final _closes = [for (var m = 30; m <= 24 * 60; m += 30) m];

  void _set(int day, DayHours d) {
    setState(() => _week = [
          for (var i = 0; i < 7; i++) i == day ? d : _week![i],
        ]);
    widget.onChanged(formatWeek(_week!));
  }

  void _copyMonday() {
    setState(() => _week = List.filled(7, _week!.first));
    widget.onChanged(formatWeek(_week!));
  }

  Widget _drop(int? value, List<int?> items, ValueChanged<int?> onPick,
          {String Function(int?)? label}) =>
      DropdownButton<int?>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        style: widget.textStyle,
        items: [
          for (final m in items)
            DropdownMenuItem(
              value: m,
              child: Text(label != null ? label(m) : hourLabel(m!)),
            ),
        ],
        onChanged: onPick,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.textStyle ?? theme.textTheme.bodyMedium;
    final week = _week;
    if (week == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_legacy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text('Horaires actuels : « $_legacy »', style: style),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: widget.accent),
            onPressed: () {
              setState(() => _week = List.of(kDefaultWeek));
              widget.onChanged(formatWeek(_week!));
            },
            icon: const Icon(Icons.schedule_rounded, size: 18.0),
            label: Text(_legacy.isEmpty
                ? 'Définir les horaires'
                : 'Choisir les horaires jour par jour'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                SizedBox(
                    width: 82.0,
                    child: Text(kDayLong[i],
                        style: style?.copyWith(fontWeight: FontWeight.w600))),
                Switch(
                  activeThumbColor: Colors.white,
                  activeTrackColor: widget.accent,
                  value: week[i].open,
                  onChanged: (v) => _set(i,
                      (open: v, from: week[i].from, to: week[i].to)),
                ),
                const SizedBox(width: 6.0),
                if (!week[i].open)
                  Expanded(child: Text('Fermé', style: style))
                else
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6.0,
                      children: [
                        _drop(week[i].from, _opens,
                            (v) => _set(i, (open: true, from: v!, to: week[i].to))),
                        Text('à', style: style),
                        _drop(week[i].to, [..._closes, null],
                            (v) => _set(i, (open: true, from: week[i].from, to: v)),
                            label: (m) => m == null ? 'non précisée' : hourLabel(m)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: widget.accent),
            onPressed: _copyMonday,
            icon: const Icon(Icons.copy_all_rounded, size: 18.0),
            label: const Text('Appliquer les horaires du lundi à tous les jours'),
          ),
        ),
        Text('Enregistré : ${formatWeek(week).isEmpty ? 'fermé toute la semaine' : formatWeek(week)}',
            style: style?.copyWith(fontSize: (style.fontSize ?? 14) - 1.5)),
      ],
    );
  }
}
