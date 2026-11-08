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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (table) _header(),
          for (var i = 0; i < visible.length; i++)
            table ? _row(visible[i], i) : _compactRow(visible[i]),
          _footer(sorted.length, start, visible.length, page, pages),
        ],
      );
    });
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AdminColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminRadius.sm),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            _sized(
              widget.columns[i],
              widget.columns[i].sortKey == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(widget.columns[i].label.toUpperCase(),
                          style: AdminText.caps()),
                    )
                  : InkWell(
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
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(widget.columns[i].label.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: AdminText.caps(
                                      color: _sort == i
                                          ? AdminColors.ink
                                          : AdminColors.faint)),
                            ),
                            const SizedBox(width: 2.0),
                            Icon(
                              _sort != i
                                  ? Icons.unfold_more_rounded
                                  : _asc
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                              size: 14.0,
                              color: _sort == i
                                  ? AdminColors.ink
                                  : AdminColors.faint,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          if (widget.actions != null) SizedBox(width: widget.actionsWidth),
        ],
      ),
    );
  }

  Widget _row(T r, int i) {
    final hl = widget.highlight?.call(r) ?? false;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = i),
      onExit: (_) => setState(() => _hover = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : () => widget.onTap!(r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
          decoration: BoxDecoration(
            color: hl
                ? AdminColors.redSoft
                : _hover == i
                    ? AdminColors.surfaceAlt
                    : Colors.transparent,
            border: Border(
                bottom: BorderSide(color: AdminColors.border)),
          ),
          child: Row(
            children: [
              for (final c in widget.columns)
                _sized(
                  c,
                  Padding(
                    padding: const EdgeInsets.only(right: 10.0),
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

  Widget _compactRow(T r) {
    return InkWell(
      onTap: widget.onTap == null ? null : () => widget.onTap!(r),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AdminColors.border)),
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

  Widget _footer(int total, int start, int count, int page, int pages) {
    return Padding(
      padding: const EdgeInsets.only(top: 14.0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10.0,
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
              Text('${start + 1}–${start + count} sur $total',
                  style: AdminText.label()),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageButton(Icons.chevron_left_rounded, 'Page précédente',
                  page > 0 ? () => setState(() => _page = page - 1) : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('Page ${page + 1} / $pages',
                    style: AdminText.strong(size: 13.0)),
              ),
              _pageButton(Icons.chevron_right_rounded, 'Page suivante',
                  page < pages - 1 ? () => setState(() => _page = page + 1) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageButton(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null ? AdminColors.greySoft : AdminColors.surface,
        shape: CircleBorder(side: BorderSide(color: AdminColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
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
