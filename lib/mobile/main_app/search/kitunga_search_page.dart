import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/backend/kitunga_categories.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import '/mobile/main_app/home/home_sections.dart' show KitungaPagedGrid;
import 'kitunga_filters.dart';

/// Recherche client : produits de tous les commerces et commerces, avec
/// filtres (catégorie, prix, disponibilité, livraison express, nouveautés,
/// ouvert maintenant, certifié) et tris.
class KitungaSearchPage extends StatefulWidget {
  const KitungaSearchPage({
    super.key,
    this.initialQuery = '',
    this.showShops = false,
    this.productsOverride,
    this.shopsOverride,
  });

  final String initialQuery;

  /// Ouvre directement l'onglet Commerces.
  final bool showShops;

  /// Données fournies directement (tests).
  final Stream<List<ProductRecord>>? productsOverride;
  final Stream<List<UserRecord>>? shopsOverride;

  @override
  State<KitungaSearchPage> createState() => _KitungaSearchPageState();
}

/// Ouvre la recherche.
void openKitungaSearch(BuildContext context,
    {String query = '', bool shops = false}) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          KitungaSearchPage(initialQuery: query, showShops: shops)));
}

class _KitungaSearchPageState extends State<KitungaSearchPage>
    with SingleTickerProviderStateMixin {
  late final _controller = TextEditingController(text: widget.initialQuery);
  late final _tabs =
      TabController(length: 2, vsync: this, initialIndex: widget.showShops ? 1 : 0);
  late ProductFilter _pf = ProductFilter(query: widget.initialQuery);
  late ShopFilter _sf = ShopFilter(query: widget.initialQuery);

  late final Stream<List<ProductRecord>> _products = widget.productsOverride ??
      queryProductRecord(limit: 600);
  late final Stream<List<UserRecord>> _shops = widget.shopsOverride ??
      queryUserRecord(
          queryBuilder: (q) => q.where('role', isEqualTo: 'Seller'));

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  bool get _onShops => _tabs.index == 1;

  void _setQuery(String q) => setState(() {
        _pf = _pf.copyWith(query: q);
        _sf = _sf.copyWith(query: q);
      });

  Future<void> _openFilters(List<ProductRecord> products,
      Map<String, UserRecord> shopsByPath, List<UserRecord> shops) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        shops: _onShops,
        // Cuisines réellement proposées par les restaurants inscrits.
        cuisines: ({for (final s in shops) ...shopCuisines(s)}.toList()
          ..sort()),
        product: _pf,
        shop: _sf,
        countProducts: (f) => filterProducts(products, shopsByPath, f).length,
        countShops: (f) => filterShops(shops, f).length,
        onApply: (p, s) => setState(() {
          _pf = p;
          _sf = s;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      body: SafeArea(
        child: StreamBuilder<List<UserRecord>>(
          stream: _shops,
          builder: (context, shopSnap) => StreamBuilder<List<ProductRecord>>(
            stream: _products,
            builder: (context, prodSnap) {
              final shops = shopSnap.data ?? const <UserRecord>[];
              final byPath = {for (final s in shops) s.reference.path: s};
              final products = prodSnap.data ?? const <ProductRecord>[];
              final ready = shopSnap.hasData && prodSnap.hasData;
              final foundProducts = filterProducts(products, byPath, _pf);
              final foundShops = filterShops(shops, _sf);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(theme),
                  TabBar(
                    controller: _tabs,
                    labelColor: theme.primary,
                    unselectedLabelColor: theme.secondaryText,
                    indicatorColor: theme.primary,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: 'Produits${ready ? ' (${foundProducts.length})' : ''}'),
                      Tab(text: 'Commerces${ready ? ' (${foundShops.length})' : ''}'),
                    ],
                  ),
                  _toolbar(theme, products, byPath, shops),
                  Expanded(
                    child: !ready
                        ? Center(
                            child:
                                CircularProgressIndicator(color: theme.primary))
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              foundProducts.isEmpty
                                  ? _empty(theme, 'Aucun produit trouvé')
                                  : KitungaPagedGrid<ProductRecord>(
                                      items: foundProducts,
                                      perPage: 10,
                                      itemExtent: KitungaProductCard.gridExtent,
                                      itemBuilder: (context, p) =>
                                          KitungaProductCard(
                                        product: p,
                                        onTap: () =>
                                            openKitungaProduct(context, p),
                                      ),
                                    ),
                              foundShops.isEmpty
                                  ? _empty(theme, 'Aucun commerce trouvé')
                                  : KitungaPagedGrid<UserRecord>(
                                      items: foundShops,
                                      perPage: 10,
                                      itemExtent: 182.0,
                                      itemBuilder: (context, s) =>
                                          KitungaShopCard(
                                              shop: s,
                                              width: null,
                                              coverHeight: 96.0),
                                    ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(FlutterFlowTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 4.0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Container(
              height: 48.0,
              padding: const EdgeInsets.only(left: 12.0, right: 4.0),
              decoration: BoxDecoration(
                color: theme.primaryBackground,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: theme.primary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: widget.initialQuery.isEmpty,
                      textInputAction: TextInputAction.search,
                      onChanged: _setQuery,
                      style: GoogleFonts.inter(
                          color: theme.primaryText, fontSize: 14.0),
                      decoration: InputDecoration(
                        hintText: 'Produit, plat, boutique…',
                        hintStyle: GoogleFonts.inter(
                            color: theme.secondaryText, fontSize: 14.0),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Effacer',
                      icon: Icon(Icons.close_rounded,
                          size: 20.0, color: theme.secondaryText),
                      onPressed: () {
                        _controller.clear();
                        _setQuery('');
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(FlutterFlowTheme theme, String label, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InputChip(
        label: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.primary)),
        backgroundColor: theme.primary.withValues(alpha: 0.1),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        deleteIconColor: theme.primary,
        onDeleted: onClear,
      ),
    );
  }

  Widget _toolbar(FlutterFlowTheme theme, List<ProductRecord> products,
      Map<String, UserRecord> byPath, List<UserRecord> shops) {
    final active = _onShops ? _sf.activeCount : _pf.activeCount;
    final chips = <Widget>[
      if (!_onShops) ...[
        if (_pf.category != null)
          _chip(theme, _pf.category!,
              () => setState(() => _pf = _pf.copyWith(category: () => null))),
        if (_pf.minPrice != null || _pf.maxPrice != null)
          _chip(
              theme,
              priceRangeLabel(_pf.minPrice, _pf.maxPrice),
              () => setState(() => _pf =
                  _pf.copyWith(minPrice: () => null, maxPrice: () => null))),
        if (_pf.cuisine != null)
          _chip(theme, _pf.cuisine!,
              () => setState(() => _pf = _pf.copyWith(cuisine: () => null))),
        if (_pf.inStock)
          _chip(theme, 'Disponibles',
              () => setState(() => _pf = _pf.copyWith(inStock: false))),
        if (_pf.express)
          _chip(theme, '⚡ Express',
              () => setState(() => _pf = _pf.copyWith(express: false))),
        if (_pf.tag != null)
          _chip(theme, _pf.tag == 'Nouveauté' ? 'Nouveautés' : 'Tendances',
              () => setState(() => _pf = _pf.copyWith(tag: () => null))),
      ] else ...[
        if (_sf.category != null)
          _chip(theme, _sf.category!,
              () => setState(() => _sf = _sf.copyWith(category: () => null))),
        if (_sf.cuisine != null)
          _chip(theme, _sf.cuisine!,
              () => setState(() => _sf = _sf.copyWith(cuisine: () => null))),
        if (_sf.openNow)
          _chip(theme, 'Ouvert maintenant',
              () => setState(() => _sf = _sf.copyWith(openNow: false))),
        if (_sf.verified)
          _chip(theme, 'Certifiés',
              () => setState(() => _sf = _sf.copyWith(verified: false))),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 4.0),
      child: Row(
        children: [
          Badge(
            isLabelVisible: active > 0,
            label: Text('$active'),
            backgroundColor: theme.primary,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.primaryText,
                side: BorderSide(color: theme.alternate),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _openFilters(products, byPath, shops),
              icon: const Icon(Icons.tune_rounded, size: 18.0),
              label: const Text('Filtres'),
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          PopupMenuButton<Object>(
            tooltip: 'Trier',
            icon: Icon(Icons.sort_rounded, color: theme.primaryText),
            onSelected: (v) => setState(() {
              if (v is ProductSort) _pf = _pf.copyWith(sort: v);
              if (v is ShopSort) _sf = _sf.copyWith(sort: v);
            }),
            itemBuilder: (_) => [
              if (!_onShops)
                for (final e in productSortLabels.entries)
                  CheckedPopupMenuItem<Object>(
                      value: e.key,
                      checked: _pf.sort == e.key,
                      child: Text(e.value))
              else
                for (final e in shopSortLabels.entries)
                  CheckedPopupMenuItem<Object>(
                      value: e.key,
                      checked: _sf.sort == e.key,
                      child: Text(e.value)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(FlutterFlowTheme theme, String title) {
    final filtered = _onShops ? _sf.activeCount > 0 : _pf.activeCount > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 52.0, color: theme.secondaryText),
            const SizedBox(height: 12.0),
            Text(title,
                style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 17.0,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4.0),
            Text(
                filtered
                    ? 'Essayez d\'enlever un filtre.'
                    : 'Essayez un autre mot.',
                style: GoogleFonts.inter(color: theme.secondaryText)),
            if (filtered)
              TextButton(
                onPressed: () => setState(() {
                  _pf = _pf.cleared();
                  _sf = _sf.cleared();
                }),
                child: const Text('Effacer les filtres'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Libellé d'une fourchette de prix (« 2 000 – 5 000 F », « Jusqu'à … »).
String priceRangeLabel(int? min, int? max) {
  String f(int v) => v
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
  if (min != null && max != null) return '${f(min)} – ${f(max)} F';
  if (max != null) return 'Jusqu\'à ${f(max)} F';
  if (min != null) return 'Dès ${f(min)} F';
  return 'Tous les prix';
}

/// Fourchettes de prix proposées.
const kPriceRanges = <(int?, int?)>[
  (null, 2000),
  (2000, 5000),
  (5000, 10000),
  (10000, 25000),
  (25000, null),
];

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.shops,
    required this.cuisines,
    required this.product,
    required this.shop,
    required this.countProducts,
    required this.countShops,
    required this.onApply,
  });

  final bool shops;
  final List<String> cuisines;
  final ProductFilter product;
  final ShopFilter shop;
  final int Function(ProductFilter) countProducts;
  final int Function(ShopFilter) countShops;
  final void Function(ProductFilter, ShopFilter) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProductFilter _p = widget.product;
  late ShopFilter _s = widget.shop;

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
        onSelected: (_) => onTap(),
        labelStyle: GoogleFonts.inter(
            color: selected ? Colors.white : theme.primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 13.0),
        selectedColor: theme.primary,
        backgroundColor: theme.primaryBackground,
        side: BorderSide.none,
        shape: const StadiumBorder(),
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
            style: GoogleFonts.inter(color: theme.secondaryText, fontSize: 12.5)),
        value: value,
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final categories = [for (final c in KitungaCategoryStore.instance.list) c.name];
    final count =
        widget.shops ? widget.countShops(_s) : widget.countProducts(_p);
    // Material (et non un simple fond) : l'effet au toucher reste visible.
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
                    child: Text(
                        widget.shops ? 'Filtrer les commerces' : 'Filtrer les produits',
                        style: GoogleFonts.interTight(
                            color: theme.primaryText,
                            fontSize: 19.0,
                            fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _p = _p.cleared();
                      _s = _s.cleared();
                    }),
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
                    _title(theme, 'Catégorie'),
                    Wrap(spacing: 8.0, runSpacing: 8.0, children: [
                      _choice(
                          theme,
                          'Toutes',
                          (widget.shops ? _s.category : _p.category) == null,
                          () => setState(() {
                                _p = _p.copyWith(category: () => null);
                                _s = _s.copyWith(category: () => null);
                              })),
                      for (final c in categories)
                        _choice(
                            theme,
                            c,
                            (widget.shops ? _s.category : _p.category) == c,
                            () => setState(() {
                                  _p = _p.copyWith(category: () => c);
                                  _s = _s.copyWith(category: () => c);
                                })),
                    ]),
                    if (widget.cuisines.isNotEmpty) ...[
                      _title(theme, 'Cuisine'),
                      Wrap(spacing: 8.0, runSpacing: 8.0, children: [
                        _choice(
                            theme,
                            'Toutes',
                            (widget.shops ? _s.cuisine : _p.cuisine) == null,
                            () => setState(() {
                                  _p = _p.copyWith(cuisine: () => null);
                                  _s = _s.copyWith(cuisine: () => null);
                                })),
                        for (final c in widget.cuisines)
                          _choice(
                              theme,
                              c,
                              (widget.shops ? _s.cuisine : _p.cuisine) == c,
                              () => setState(() {
                                    _p = _p.copyWith(cuisine: () => c);
                                    _s = _s.copyWith(cuisine: () => c);
                                  })),
                      ]),
                    ],
                    if (!widget.shops) ...[
                      _title(theme, 'Prix'),
                      Wrap(spacing: 8.0, runSpacing: 8.0, children: [
                        _choice(
                            theme,
                            'Tous les prix',
                            _p.minPrice == null && _p.maxPrice == null,
                            () => setState(() => _p = _p.copyWith(
                                minPrice: () => null, maxPrice: () => null))),
                        for (final r in kPriceRanges)
                          _choice(
                              theme,
                              priceRangeLabel(r.$1, r.$2),
                              _p.minPrice == r.$1 && _p.maxPrice == r.$2,
                              () => setState(() => _p = _p.copyWith(
                                  minPrice: () => r.$1, maxPrice: () => r.$2))),
                      ]),
                      _title(theme, 'Mise en avant'),
                      Wrap(spacing: 8.0, runSpacing: 8.0, children: [
                        _choice(theme, 'Tout', _p.tag == null,
                            () => setState(() => _p = _p.copyWith(tag: () => null))),
                        _choice(theme, 'Nouveautés', _p.tag == 'Nouveauté',
                            () => setState(
                                () => _p = _p.copyWith(tag: () => 'Nouveauté'))),
                        _choice(theme, 'Tendances', _p.tag == 'Tendance',
                            () => setState(
                                () => _p = _p.copyWith(tag: () => 'Tendance'))),
                      ]),
                      const SizedBox(height: 8.0),
                      _switch(theme, 'Disponibles uniquement',
                          'Masque les produits en rupture de stock', _p.inStock,
                          (v) => setState(() => _p = _p.copyWith(inStock: v))),
                      _switch(theme, 'Livraison express ⚡',
                          'Produits livrés en priorité', _p.express,
                          (v) => setState(() => _p = _p.copyWith(express: v))),
                    ] else ...[
                      const SizedBox(height: 8.0),
                      _switch(theme, 'Ouvert maintenant',
                          'Selon les horaires du commerce', _s.openNow,
                          (v) => setState(() => _s = _s.copyWith(openNow: v))),
                      _switch(theme, 'Commerces certifiés',
                          'Vérifiés par Kitunga', _s.verified,
                          (v) => setState(() => _s = _s.copyWith(verified: v))),
                    ],
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
                  widget.onApply(_p, _s);
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
