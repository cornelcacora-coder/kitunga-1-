import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/kitunga_categories.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/mobile/main_app/search/kitunga_filters.dart';
import '/mobile/main_app/search/kitunga_search_page.dart'
    show kPriceRanges, priceRangeLabel;

/// Recherche, filtres et tri des produits, partout dans l'application
/// (vitrines des commerces, Tendances, Nouveautés, Nos produits).
///
/// Barre : champ de recherche, bouton « Filtres » (nombre de filtres actifs),
/// bouton de tri ; puis les filtres actifs en pastilles supprimables.
class KitungaProductToolbar extends StatefulWidget {
  const KitungaProductToolbar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.count,
    this.hint = 'Rechercher un produit…',
    this.sections = const [],
    this.cuisines = const [],
    this.showCategory = true,
    this.showTag = true,
  });

  final ProductFilter filter;
  final ValueChanged<ProductFilter> onChanged;

  /// Nombre de résultats pour un filtre (bouton « Voir N résultats »).
  final int Function(ProductFilter) count;
  final String hint;

  /// Rayons / rubriques proposés (vitrine d'un commerce).
  final List<String> sections;
  final List<String> cuisines;
  final bool showCategory;
  final bool showTag;

  @override
  State<KitungaProductToolbar> createState() => _KitungaProductToolbarState();
}

class _KitungaProductToolbarState extends State<KitungaProductToolbar> {
  late final _search = TextEditingController(text: widget.filter.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openFilters() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => KitungaProductFilterSheet(
          filter: widget.filter,
          count: widget.count,
          onApply: widget.onChanged,
          sections: widget.sections,
          cuisines: widget.cuisines,
          showCategory: widget.showCategory,
          showTag: widget.showTag,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final f = widget.filter;
    final active = <(String, ProductFilter)>[
      if (f.section != null) (f.section!, f.copyWith(section: () => null)),
      if (f.category != null) (f.category!, f.copyWith(category: () => null)),
      if (f.cuisine != null)
        ('Cuisine ${f.cuisine}', f.copyWith(cuisine: () => null)),
      if (f.minPrice != null || f.maxPrice != null)
        (
          priceRangeLabel(f.minPrice, f.maxPrice),
          f.copyWith(minPrice: () => null, maxPrice: () => null)
        ),
      if (f.tag != null && widget.showTag)
        (
          f.tag == 'Nouveauté' ? 'Nouveautés' : 'Tendances',
          f.copyWith(tag: () => null)
        ),
      if (f.inStock) ('Disponibles', f.copyWith(inStock: false)),
      if (f.express) ('Express ⚡', f.copyWith(express: false)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) => widget.onChanged(f.copyWith(query: v)),
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.inter(
                      color: theme.primaryText, fontSize: 15.0),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.inter(
                        color: theme.secondaryText, fontSize: 14.5),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: theme.secondaryText),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              widget.onChanged(f.copyWith(query: ''));
                            },
                          ),
                    filled: true,
                    fillColor: theme.primaryBackground,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              _iconButton(
                theme,
                tooltip: 'Filtres',
                icon: Icons.tune_rounded,
                badge: f.activeCount,
                onTap: _openFilters,
              ),
              const SizedBox(width: 8.0),
              PopupMenuButton<ProductSort>(
                tooltip: 'Trier',
                onSelected: (s) => widget.onChanged(f.copyWith(sort: s)),
                itemBuilder: (_) => [
                  for (final e in productSortLabels.entries)
                    CheckedPopupMenuItem(
                      value: e.key,
                      checked: f.sort == e.key,
                      child: Text(e.value),
                    ),
                ],
                child: _iconButton(theme,
                    tooltip: 'Trier',
                    icon: Icons.swap_vert_rounded,
                    badge: f.sort == ProductSort.relevance ? 0 : 1,
                    onTap: null),
              ),
            ],
          ),
        ),
        if (active.isNotEmpty)
          SizedBox(
            height: 46.0,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0.0),
              children: [
                for (final a in active)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InputChip(
                      label: Text(a.$1),
                      onDeleted: () => widget.onChanged(a.$2),
                      labelStyle: GoogleFonts.inter(
                          color: theme.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700),
                      backgroundColor: theme.primary.withValues(alpha: 0.08),
                      deleteIconColor: theme.primary,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                  ),
                TextButton(
                  onPressed: () => widget.onChanged(f.cleared()),
                  child: const Text('Tout effacer'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _iconBox(FlutterFlowTheme theme, IconData icon, int badge) => SizedBox(
        width: 48.0,
        height: 48.0,
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          backgroundColor: theme.primary,
          child: Icon(icon, color: theme.primaryText),
        ),
      );

  Widget _iconButton(FlutterFlowTheme theme,
          {required String tooltip,
          required IconData icon,
          required int badge,
          required VoidCallback? onTap}) =>
      Material(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0),
          onTap: onTap,
          // Sans action propre (menu de tri) : l'infobulle est celle du menu.
          child: onTap == null
              ? _iconBox(theme, icon, badge)
              : Tooltip(message: tooltip, child: _iconBox(theme, icon, badge)),
        ),
      );
}

/// Fenêtre des filtres produits : rayon, catégorie, cuisine, prix, mise en
/// avant, disponibilité, express, tri.
class KitungaProductFilterSheet extends StatefulWidget {
  const KitungaProductFilterSheet({
    super.key,
    required this.filter,
    required this.count,
    required this.onApply,
    this.sections = const [],
    this.cuisines = const [],
    this.showCategory = true,
    this.showTag = true,
  });

  final ProductFilter filter;
  final int Function(ProductFilter) count;
  final ValueChanged<ProductFilter> onApply;
  final List<String> sections;
  final List<String> cuisines;
  final bool showCategory;
  final bool showTag;

  @override
  State<KitungaProductFilterSheet> createState() =>
      _KitungaProductFilterSheetState();
}

class _KitungaProductFilterSheetState extends State<KitungaProductFilterSheet> {
  late ProductFilter _f = widget.filter;

  Widget _title(FlutterFlowTheme theme, String t) => Padding(
        padding: const EdgeInsets.only(top: 18.0, bottom: 10.0),
        child: Text(t,
            style: GoogleFonts.inter(
                color: theme.primaryText,
                fontSize: 14.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _choice(FlutterFlowTheme theme, String label, bool selected,
          VoidCallback onTap) =>
      ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(onTap),
        labelStyle: GoogleFonts.inter(
            color: selected ? Colors.white : theme.primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 13.0),
        selectedColor: theme.primary,
        backgroundColor: theme.primaryBackground,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      );

  Widget _group(FlutterFlowTheme theme, String title, String allLabel,
          String? value, List<String> options, void Function(String?) set) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(theme, title),
          Wrap(spacing: 8.0, runSpacing: 8.0, children: [
            _choice(theme, allLabel, value == null, () => set(null)),
            for (final o in options)
              _choice(theme, o, value == o, () => set(o)),
          ]),
        ],
      );

  Widget _switch(FlutterFlowTheme theme, String title, String subtitle,
          bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: Colors.white,
        activeTrackColor: theme.primary,
        title: Text(title,
            style: GoogleFonts.inter(
                color: theme.primaryText, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style:
                GoogleFonts.inter(color: theme.secondaryText, fontSize: 12.5)),
        value: value,
        onChanged: (v) => setState(() => onChanged(v)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final count = widget.count(_f);
    final categories = [
      for (final c in KitungaCategoryStore.instance.list) c.name,
    ];
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: Material(
        color: theme.secondaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10.0),
                  width: 42.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                      color: theme.alternate,
                      borderRadius: BorderRadius.circular(2.0)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 12.0, 8.0, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Filtrer et trier',
                          style: GoogleFonts.interTight(
                              color: theme.primaryText,
                              fontSize: 19.0,
                              fontWeight: FontWeight.w800)),
                    ),
                    TextButton(
                      onPressed: () => setState(() =>
                          _f = _f.cleared().copyWith(
                              sort: ProductSort.relevance)),
                      child: const Text('Réinitialiser'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(theme, 'Trier par'),
                      Wrap(spacing: 8.0, runSpacing: 8.0, children: [
                        for (final e in productSortLabels.entries)
                          _choice(theme, e.value, _f.sort == e.key,
                              () => _f = _f.copyWith(sort: e.key)),
                      ]),
                      if (widget.sections.length > 1)
                        _group(theme, 'Rayon', 'Tous', _f.section,
                            widget.sections,
                            (v) => _f = _f.copyWith(section: () => v)),
                      if (widget.showCategory)
                        _group(theme, 'Catégorie', 'Toutes', _f.category,
                            categories,
                            (v) => _f = _f.copyWith(category: () => v)),
                      if (widget.cuisines.isNotEmpty)
                        _group(theme, 'Cuisine', 'Toutes', _f.cuisine,
                            widget.cuisines,
                            (v) => _f = _f.copyWith(cuisine: () => v)),
                      _title(theme, 'Prix'),
                      Wrap(spacing: 8.0, runSpacing: 8.0, children: [
                        _choice(
                            theme,
                            'Tous les prix',
                            _f.minPrice == null && _f.maxPrice == null,
                            () => _f = _f.copyWith(
                                minPrice: () => null, maxPrice: () => null)),
                        for (final r in kPriceRanges)
                          _choice(
                              theme,
                              priceRangeLabel(r.$1, r.$2),
                              _f.minPrice == r.$1 && _f.maxPrice == r.$2,
                              () => _f = _f.copyWith(
                                  minPrice: () => r.$1,
                                  maxPrice: () => r.$2)),
                      ]),
                      if (widget.showTag)
                        _group(
                            theme,
                            'Mise en avant',
                            'Tout',
                            _f.tag == null
                                ? null
                                : (_f.tag == 'Nouveauté'
                                    ? 'Nouveautés'
                                    : 'Tendances'),
                            const ['Nouveautés', 'Tendances'],
                            (v) => _f = _f.copyWith(
                                tag: () => v == null
                                    ? null
                                    : (v == 'Nouveautés'
                                        ? 'Nouveauté'
                                        : 'Tendance'))),
                      const SizedBox(height: 8.0),
                      _switch(
                          theme,
                          'Disponibles uniquement',
                          'Masque les produits en rupture de stock',
                          _f.inStock,
                          (v) => _f = _f.copyWith(inStock: v)),
                      _switch(theme, 'Livraison express ⚡',
                          'Produits livrés en priorité', _f.express,
                          (v) => _f = _f.copyWith(express: v)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 16.0),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0)),
                  ),
                  onPressed: () {
                    widget.onApply(_f);
                    Navigator.pop(context);
                  },
                  child: Text(
                      count == 0
                          ? 'Aucun résultat'
                          : 'Voir $count résultat${count > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 15.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
