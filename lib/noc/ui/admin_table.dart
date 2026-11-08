import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_kit.dart';

/// Tableau de l'administration : en-têtes triables, survol, pagination ;
/// sur un écran étroit, chaque ligne devient une fiche compacte.
class AdminColumn<T> {
  const AdminColumn({
    required this.label,
    required this.cell,
    this.flex = 2,
    this.sortKey,
    this.width,
  });

  final String label;
  final Widget Function(T row) cell;
  final int flex;

  /// Largeur fixe (sinon proportion [flex]).
  final double? width;

  /// Valeur de tri ; null = colonne non triable.
  final Comparable<Object?>? Function(T row)? sortKey;
}

class AdminTable<T> extends StatefulWidget {
  const AdminTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.compact,
    this.onTap,
    this.actions,
    this.actionsWidth = 120.0,
    this.pageSize = 5,
    this.breakpoint = 760.0,
    this.empty,
    this.initialSort,
    this.initialAscending = false,
    this.highlight,
  });

  final List<T> rows;
  final List<AdminColumn<T>> columns;

  /// Fiche d'une ligne sur écran étroit.
  final Widget Function(T row) compact;
  final void Function(T row)? onTap;

  /// Boutons d'action en fin de ligne.
  final List<Widget> Function(T row)? actions;
  final double actionsWidth;
  final int pageSize;
  final double breakpoint;
  final Widget? empty;

  /// Index de la colonne triée au départ.
  final int? initialSort;
  final bool initialAscending;

  /// Ligne mise en avant (fond teinté).
  final bool Function(T row)? highlight;

  @override
  State<AdminTable<T>> createState() => _AdminTableState<T>();
}

class _AdminTableState<T> extends State<AdminTable<T>> {
  late int? _sort = widget.initialSort;
  late bool _asc = widget.initialAscending;
  int _page = 0;
  late int _size = widget.pageSize;
  int? _hover;

  @override
  void didUpdateWidget(AdminTable<T> old) {
    super.didUpdateWidget(old);
    // Nouveau filtre : on revient à la première page si elle n'existe plus.
    if (_page * _size >= widget.rows.length) _page = 0;
  }

  List<T> get _sorted {
    final s = _sort;
    final key = s == null ? null : widget.columns[s].sortKey;
    if (key == null) return widget.rows;
    final list = [...widget.rows];
    list.sort((a, b) {
      final ka = key(a);
      final kb = key(b);
      final c = ka == null
          ? (kb == null ? 0 : 1)
          : kb == null
              ? -1
              : ka.compareTo(kb);
      return _asc ? c : -c;
    });
    return list;
  }

  Widget _sized(AdminColumn<T> c, Widget child) => c.width != null
      ? SizedBox(width: c.width, child: child)
      : Expanded(flex: c.flex, child: child);

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return widget.empty ??
          const AdminEmpty(icon: Icons.inbox_rounded, title: 'Aucun résultat');
    }
    final sorted = _sorted;
    final pages = (sorted.length / _size).ceil();
    final page = math.min(_page, pages - 1);
    final start = page * _size;
    final visible = sorted.sublist(start, math.min(start + _size, sorted.length));

    return LayoutBuilder(builder: (context, c) {
      final table = c.maxWidth >= widget.breakpoint;
      // Tableau encadré aux coins arrondis (en-tête + lignes).
      final body = Container(
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminRadius.lg),
          border: Border.all(color: AdminColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (table) _header(),
            for (var i = 0; i < visible.length; i++)
              table
                  ? _row(visible[i], i, last: i == visible.length - 1)
                  : _compactRow(visible[i], last: i == visible.length - 1),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          _footer(sorted.length, start, visible.length, page, pages),
        ],
      );
    });
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: AdminColors.surfaceAlt,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            _sized(widget.columns[i], _headerCell(i)),
          if (widget.actions != null)
            SizedBox(
              width: widget.actionsWidth,
              // Libellé seulement si la colonne est assez large.
              child: widget.actionsWidth >= 90.0
                  ? Text('ACTIONS',
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: AdminText.caps())
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _headerCell(int i) {
    final col = widget.columns[i];
    final label = Text(col.label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AdminText.caps(
            color: _sort == i ? AdminColors.ink : AdminColors.faint));
    if (col.sortKey == null) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0), child: label);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(AdminRadius.sm),
      onTap: () => setState(() {
        if (_sort == i) {
          _asc = !_asc;
        } else {
          _sort = i;
          _asc = true;
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          children: [
            Flexible(child: label),
            const SizedBox(width: 4.0),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                _sort != i
                    ? Icons.unfold_more_rounded
                    : _asc
                        ? Icons.north_rounded
                        : Icons.south_rounded,
                key: ValueKey('${_sort == i}-$_asc'),
                size: 13.0,
                color: _sort == i ? AdminColors.red : AdminColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(T r, int i, {required bool last}) {
    final hl = widget.highlight?.call(r) ?? false;
    final hover = _hover == i;
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = i),
      onExit: (_) => setState(() => _hover = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : () => widget.onTap!(r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: 62.0),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: hl
                ? AdminColors.redSoft
                : hover
                    ? AdminColors.surfaceAlt
                    : Colors.transparent,
            border: Border(
              // Liseré rouge au survol (ou ligne mise en avant).
              left: BorderSide(
                  color: hover || hl ? AdminColors.red : Colors.transparent,
                  width: 3.0),
              bottom: last
                  ? BorderSide.none
                  : BorderSide(color: AdminColors.border),
            ),
          ),
          child: Row(
            children: [
              for (final c in widget.columns)
                _sized(
                  c,
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Align(
                        alignment: Alignment.centerLeft, child: c.cell(r)),
                  ),
                ),
              if (widget.actions != null)
                SizedBox(
                  width: widget.actionsWidth,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6.0,
                    children: widget.actions!(r),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactRow(T r, {required bool last}) {
    return InkWell(
      onTap: widget.onTap == null ? null : () => widget.onTap!(r),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: AdminColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: widget.compact(r)),
            if (widget.actions != null) ...[
              const SizedBox(width: 8.0),
              Column(
                children: [
                  for (final a in widget.actions!(r))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 6.0), child: a),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Numéros de page affichés : tous si peu nombreux, sinon début, voisins
  /// de la page courante et fin (null = « … »).
  static List<int?> pageNumbers(int page, int pages) {
    if (pages <= 7) return [for (var i = 0; i < pages; i++) i];
    final set = <int>{0, pages - 1, page - 1, page, page + 1}
      ..removeWhere((p) => p < 0 || p >= pages);
    final sortedPages = set.toList()..sort();
    final out = <int?>[];
    for (var k = 0; k < sortedPages.length; k++) {
      if (k > 0 && sortedPages[k] - sortedPages[k - 1] > 1) out.add(null);
      out.add(sortedPages[k]);
    }
    return out;
  }

  Widget _footer(int total, int start, int count, int page, int pages) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12.0,
        spacing: 16.0,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Afficher', style: AdminText.label()),
              const SizedBox(width: 8.0),
              AdminSelect<int>(
                value: _size,
                items: const {5: '5', 10: '10', 20: '20', 50: '50'},
                onChanged: (v) => setState(() {
                  _size = v;
                  _page = 0;
                }),
              ),
              const SizedBox(width: 12.0),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${start + 1}–${start + count}',
                    style: AdminText.strong(size: 13.0)),
                TextSpan(text: ' sur $total', style: AdminText.label()),
              ])),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageButton(Icons.chevron_left_rounded, 'Page précédente',
                  page > 0 ? () => setState(() => _page = page - 1) : null),
              for (final n in pageNumbers(page, pages))
                n == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text('…', style: AdminText.label()))
                    : _pageNumber(n, n == page),
              _pageButton(
                  Icons.chevron_right_rounded,
                  'Page suivante',
                  page < pages - 1
                      ? () => setState(() => _page = page + 1)
                      : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageNumber(int n, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: Material(
        color: active ? AdminColors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(10.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: active ? null : () => setState(() => _page = n),
          child: Container(
            width: 36.0,
            height: 36.0,
            alignment: Alignment.center,
            decoration: active
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: adminGlow(AdminColors.red))
                : null,
            child: Text('${n + 1}',
                style: AdminText.strong(
                    size: 13.0,
                    color: active ? Colors.white : AdminColors.text)),
          ),
        ),
      ),
    );
  }

  Widget _pageButton(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Material(
          color: AdminColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
              side: BorderSide(color: AdminColors.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10.0),
            onTap: onTap,
            child: SizedBox(
              width: 36.0,
              height: 36.0,
              child: Icon(icon,
                  size: 20.0,
                  color: onTap == null ? AdminColors.faint : AdminColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Onglets en pastilles avec compteur (filtres de statut).
class AdminTabs<T> extends StatelessWidget {
  const AdminTabs({
    super.key,
    required this.value,
    required this.tabs,
    required this.onChanged,
  });

  final T value;
  final List<({T value, String label, int? count})> tabs;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Material(
                color: t.value == value ? AdminColors.red : AdminColors.surface,
                borderRadius: BorderRadius.circular(AdminRadius.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AdminRadius.pill),
                  onTap: () => onChanged(t.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 9.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AdminRadius.pill),
                      border: Border.all(
                          color: t.value == value
                              ? AdminColors.red
                              : AdminColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.label,
                            style: AdminText.strong(
                                size: 13.0,
                                color: t.value == value
                                    ? Colors.white
                                    : AdminColors.text)),
                        if (t.count != null) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7.0, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: t.value == value
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : AdminColors.greySoft,
                              borderRadius:
                                  BorderRadius.circular(AdminRadius.pill),
                            ),
                            child: Text('${t.count}',
                                style: AdminText.strong(
                                    size: 12.0,
                                    color: t.value == value
                                        ? Colors.white
                                        : AdminColors.muted)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Champ de recherche des listes (style de la charte).
class AdminSearchBox extends StatelessWidget {
  const AdminSearchBox(
      {super.key, required this.hint, required this.onChanged, this.width = 300.0});

  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        onChanged: onChanged,
        style: AdminText.body(),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search_rounded,
              size: 20.0, color: AdminColors.faint),
          fillColor: AdminColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
      ),
    );
  }
}
