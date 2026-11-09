import '/backend/backend.dart';
import '/mobile/main_app/search/kitunga_filters.dart'
    show ProductSort, productSortLabels, productPrice, searchNorm;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import '/index.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shop_detail_page_model.dart';
import '/mobile/components/form_styles/form_styles.dart';
export 'shop_detail_page_model.dart';

class ShopDetailPageWidget extends StatefulWidget {
  const ShopDetailPageWidget({
    super.key,
    this.userRef,
    this.isSameSeller,
  });

  /// The refered user database
  final DocumentReference? userRef;

  final bool? isSameSeller;

  static String routeName = 'ShopDetailPage';
  static String routePath = '/shopDetailPage';

  @override
  State<ShopDetailPageWidget> createState() => _ShopDetailPageWidgetState();
}

class _ShopDetailPageWidgetState extends State<ShopDetailPageWidget> {
  late ShopDetailPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ShopDetailPageModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  static const _filters = [
    (label: 'Tous', value: ''),
    (label: 'Nouveautés', value: 'Nouveauté'),
    (label: 'Tendances', value: 'Tendance'),
  ];

  void _openProduct(ProductRecord p, UserRecord shop) {
    context.pushNamed(
      ProductViewWidget.routeName,
      queryParameters: {
        'productRef': serializeParam(p.reference, ParamType.DocumentReference),
        'sellerRef':
            serializeParam(shop.reference, ParamType.DocumentReference),
      }.withoutNulls,
    );
  }

  Widget _netImage(String url, FlutterFlowTheme theme,
      {double? width,
      double? height,
      IconData icon = Icons.storefront_rounded,
      Widget? placeholder}) {
    return KitungaImage(url,
        width: width,
        height: height,
        fallbackIcon: icon,
        placeholder: placeholder);
  }

  Widget _pill(
      FlutterFlowTheme theme, IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(10.0, 5.0, 12.0, 5.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.0, color: color),
          SizedBox(width: 5.0),
          Text(
            text,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// En-tête : couverture, logo, nom, informations et description.
  Widget _header(FlutterFlowTheme theme, UserRecord shop) {
    final catColor = kitungaCategoryColor(theme, shop.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _netImage(
                shop.businessCover.isNotEmpty
                    ? shop.businessCover
                    : shop.photoUrl,
                theme,
                width: double.infinity,
                height: 220.0,
                placeholder: kitungaShopPlaceholder(context, shop,
                    width: double.infinity, height: 220.0, cover: true)),
            // Voile en haut pour garder le bouton retour lisible.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment(0.0, -0.2),
                      colors: [Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Material(
                  color: theme.secondaryBackground,
                  shape: CircleBorder(),
                  elevation: 2.0,
                  child: IconButton(
                    onPressed: () => context.safePop(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: theme.primaryText),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20.0,
              bottom: -38.0,
              child: Container(
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10.0,
                      offset: Offset(0.0, 3.0),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _netImage(shop.photoUrl, theme,
                      width: 76.0,
                      height: 76.0,
                      placeholder: kitungaShopPlaceholder(context, shop,
                          width: 76.0, height: 76.0)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 48.0),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      shop.displayName,
                      style: GoogleFonts.interTight(
                        color: theme.primaryText,
                        fontSize: 24.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (shop.verified)
                    Padding(
                      padding: EdgeInsetsDirectional.only(start: 6.0),
                      child: Icon(Icons.verified_rounded,
                          color: theme.primary, size: 22.0),
                    ),
                ],
              ),
              SizedBox(height: 10.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  if (shop.category.isNotEmpty)
                    _pill(theme, Icons.storefront_rounded, shop.category,
                        catColor),
                  if (shop.horraire.trim().isNotEmpty)
                    _pill(theme, Icons.schedule_rounded, shop.horraire.trim(),
                        theme.secondaryText),
                  // Restaurants : temps moyen de préparation.
                  if ((shop.snapshotData['prep_minutes'] as num?) != null)
                    _pill(
                        theme,
                        Icons.timer_outlined,
                        'Prêt en ~${(shop.snapshotData['prep_minutes'] as num).toInt()} min',
                        theme.secondaryText),
                  if (shop.verified)
                    _pill(theme, Icons.verified_outlined, 'Certifié',
                        theme.primary),
                ],
              ),
              if (shop.bio.trim().isNotEmpty) ...[
                SizedBox(height: 12.0),
                Text(
                  shop.bio.trim(),
                  style: GoogleFonts.inter(
                    color: theme.secondaryText,
                    fontSize: 14.0,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Catalogue adapté à la catégorie du commerce ──────────────────────
  String _search = '';
  String _chip = '';

  /// Tri et disponibilité choisis par le client dans la vitrine.
  ProductSort _sort = ProductSort.relevance;
  bool _inStock = false;
  final _sectionKeys = <String, GlobalKey>{};
  late Stream<List<ProductRecord>> _productStream = _loadProducts();

  Stream<List<ProductRecord>> _loadProducts() => queryProductRecord(
        queryBuilder: (q) => q.where('seller_ref', isEqualTo: widget!.userRef),
      );

  bool _isMenu(String category) =>
      category == 'Restaurant' || category == 'Fast Food';

  String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll('ç', 'c');

  /// Regroupe les produits par rubrique (ou rayon). Sans rubrique saisie,
  /// un seul groupe au nom adapté à l'activité.
  Map<String, List<ProductRecord>> _group(
      List<ProductRecord> products, String category) {
    final hasSections = products.any((p) => p.section.trim().isNotEmpty);
    final fallback = switch (category) {
      'Restaurant' || 'Fast Food' => 'Au menu',
      'Pharmacie' => 'Produits disponibles',
      'Magasin' => 'Tous les rayons',
      _ => 'Tous les articles',
    };
    final groups = <String, List<ProductRecord>>{};
    for (final p in products) {
      final key = !hasSections
          ? fallback
          : (p.section.trim().isEmpty ? 'Autres' : p.section.trim());
      groups.putIfAbsent(key, () => []).add(p);
    }
    return groups;
  }

  Widget _searchField(FlutterFlowTheme theme, String hint) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 12.0),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.inter(color: theme.secondaryText, fontSize: 15.0),
          prefixIcon: Icon(Icons.search_rounded, color: theme.secondaryText),
          // Tri et « disponibles uniquement ».
          suffixIcon: PopupMenuButton<Object>(
            tooltip: 'Trier et filtrer',
            icon: Badge(
              isLabelVisible: _inStock || _sort != ProductSort.relevance,
              smallSize: 8.0,
              backgroundColor: theme.primary,
              child: Icon(Icons.tune_rounded, color: theme.secondaryText),
            ),
            onSelected: (v) => setState(() {
              if (v is ProductSort) _sort = v;
              if (v == 'stock') _inStock = !_inStock;
            }),
            itemBuilder: (_) => [
              for (final e in productSortLabels.entries)
                CheckedPopupMenuItem<Object>(
                  value: e.key,
                  checked: _sort == e.key,
                  child: Text(e.key == ProductSort.relevance
                      ? 'Ordre du commerce'
                      : e.value),
                ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<Object>(
                value: 'stock',
                checked: _inStock,
                child: const Text('Disponibles uniquement'),
              ),
            ],
          ),
          filled: true,
          fillColor: theme.primaryBackground,
          contentPadding: EdgeInsets.symmetric(vertical: 14.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.0),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _chips(FlutterFlowTheme theme, List<String> labels,
      {required bool scrollTo}) {
    return SizedBox(
      height: 48.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 8.0),
        children: [
          for (final label in ['', ...labels])
            if (!(scrollTo && label.isEmpty))
              Padding(
                padding: EdgeInsetsDirectional.only(end: 8.0),
                child: ChoiceChip(
                  label: Text(label.isEmpty ? 'Tous' : label),
                  selected: _chip == label,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _chip = label);
                    // Menu : on fait défiler jusqu'à la rubrique.
                    final key = _sectionKeys[label];
                    if (scrollTo && key?.currentContext != null) {
                      Scrollable.ensureVisible(key!.currentContext!,
                          duration: Duration(milliseconds: 350),
                          curve: Curves.easeInOut);
                    }
                  },
                  labelStyle: GoogleFonts.inter(
                    color: _chip == label ? Colors.white : theme.primaryText,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: theme.primary,
                  backgroundColor: theme.primaryBackground,
                  side: BorderSide.none,
                  shape: StadiumBorder(),
                ),
              ),
        ],
      ),
    );
  }

  Widget _sectionTitle(FlutterFlowTheme theme, String title, int count,
      {Key? key}) {
    return Padding(
      key: key,
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 18.0, 20.0, 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 18.0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.inter(
              color: theme.secondaryText,
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<ProductRecord> products, UserRecord shop) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0.0),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14.0,
        crossAxisSpacing: 14.0,
        mainAxisExtent: KitungaProductCard.gridExtent,
      ),
      itemBuilder: (context, i) => KitungaProductCard(
        product: products[i],
        onTap: () => _openProduct(products[i], shop),
      ),
    );
  }

  Widget _rows(
      FlutterFlowTheme theme, List<ProductRecord> products, UserRecord shop) {
    return Column(
      children: [
        for (var i = 0; i < products.length; i++) ...[
          if (i > 0)
            Divider(
                height: 1.0,
                indent: 20.0,
                endIndent: 20.0,
                color: theme.divider),
          KitungaProductRow(
            product: products[i],
            onTap: () => _openProduct(products[i], shop),
          ),
        ],
      ],
    );
  }

  Widget _info(FlutterFlowTheme theme, IconData icon, String text) {
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 12.0),
      padding: EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.primary, size: 20.0),
          SizedBox(width: 10.0),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: theme.primaryText,
                fontSize: 13.0,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(FlutterFlowTheme theme, String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32.0, 32.0, 32.0, 0.0),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 44.0, color: theme.secondaryText),
          SizedBox(height: 10.0),
          Text(
            text,
            textAlign: TextAlign.center,
            style:
                GoogleFonts.inter(color: theme.secondaryText, fontSize: 14.0),
          ),
        ],
      ),
    );
  }

  /// Catalogue : présentation selon la catégorie du commerce.
  Widget _catalog(FlutterFlowTheme theme, UserRecord shop) {
    final category = shop.category;
    return StreamBuilder<List<ProductRecord>>(
      stream: _productStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              children: [
                Text(
                  'Impossible de charger les produits.',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 14.0),
                ),
                SizedBox(height: 12.0),
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _productStream = _loadProducts()),
                  style: FilledButton.styleFrom(backgroundColor: theme.primary),
                  icon: Icon(Icons.refresh_rounded),
                  label: Text('Réessayer'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.all(40.0),
            child:
                Center(child: CircularProgressIndicator(color: theme.primary)),
          );
        }

        final q = _norm(_search.trim());
        // Les clients ne voient que les produits publiés (pas les brouillons).
        final published = snapshot.data!.where(kitungaIsPublished).toList();
        final all = published
            .where((p) =>
                q.isEmpty ||
                _norm(p.name).contains(q) ||
                _norm(p.description).contains(q))
            .where((p) =>
                !_inStock || !p.hasQuantity() || p.quantity > 0)
            .toList();
        // Tri choisi par le client (sinon l'ordre du commerce).
        switch (_sort) {
          case ProductSort.priceAsc:
            all.sort((a, b) => productPrice(a).compareTo(productPrice(b)));
          case ProductSort.priceDesc:
            all.sort((a, b) => productPrice(b).compareTo(productPrice(a)));
          case ProductSort.name:
            all.sort((a, b) => searchNorm(a.name).compareTo(searchNorm(b.name)));
          case ProductSort.newest:
            all.sort((a, b) => (b.createdAt ?? DateTime(2000))
                .compareTo(a.createdAt ?? DateTime(2000)));
          case ProductSort.relevance:
            break;
        }
        final groups = _group(all, category);
        final menu = _isMenu(category);
        final pharmacy = category == 'Pharmacie';

        // Pastilles : rubriques si le vendeur en a créé, sinon les
        // étiquettes existantes (Nouveautés / Tendances).
        final useSections = groups.length > 1;
        final tagLabels = _filters
            .where((f) =>
                f.value.isNotEmpty &&
                all.any((p) => p.specifications == f.value))
            .map((f) => f.label)
            .toList();
        List<ProductRecord> byChip(List<ProductRecord> ps) {
          if (_chip.isEmpty || useSections || menu) return ps;
          final tag = _filters
              .firstWhere((f) => f.label == _chip, orElse: () => _filters.first)
              .value;
          return tag.isEmpty
              ? ps
              : ps.where((p) => p.specifications == tag).toList();
        }

        final searchHint = switch (category) {
          'Restaurant' || 'Fast Food' => 'Rechercher un plat…',
          'Pharmacie' => 'Rechercher un produit par son nom…',
          _ => 'Rechercher un article…',
        };

        final children = <Widget>[
          if (pharmacy)
            _info(theme, Icons.medical_information_outlined,
                'Médicaments sur ordonnance : envoyez la photo de votre ordonnance depuis la fiche du médicament. Une fois validée par la pharmacie, vous pouvez commander pendant 7 jours.'),
          _searchField(theme, searchHint),
        ];

        if (published.isEmpty) {
          children.add(
              _empty(theme, 'Ce commerce n\'a pas encore publié de produits.'));
          return Column(children: children);
        }
        if (all.isEmpty) {
          children.add(_empty(
              theme, 'Aucun produit ne correspond à « ${_search.trim()} ».'));
          return Column(children: children);
        }

        if (menu || pharmacy) {
          // Menu / pharmacie : rubriques empilées, lignes produits.
          if (useSections) {
            children.add(_chips(theme, groups.keys.toList(), scrollTo: true));
          }
          groups.forEach((name, products) {
            final key = _sectionKeys.putIfAbsent(name, () => GlobalKey());
            children.add(_sectionTitle(theme, name, products.length, key: key));
            children.add(_rows(theme, products, shop));
          });
        } else {
          // Boutique / magasin : filtres puis grille.
          final labels = useSections ? groups.keys.toList() : tagLabels;
          if (labels.isNotEmpty) {
            children.add(_chips(theme, labels, scrollTo: false));
          }
          final shown = useSections && _chip.isNotEmpty
              ? (groups[_chip] ?? <ProductRecord>[])
              : byChip(all);
          children.add(Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 4.0, 20.0, 0.0),
            child: Text(
              '${shown.length} ${category == 'Magasin' ? 'article' : 'produit'}${shown.length > 1 ? 's' : ''}',
              style: GoogleFonts.inter(
                color: theme.secondaryText,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ));
          children.add(_grid(shown, shop));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
      body: KitungaScaffoldBackground(
        child: StreamBuilder<UserRecord>(
        stream: UserRecord.getDocument(widget!.userRef!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: theme.primary),
            );
          }
          final shop = snapshot.data!;
          return ListView(
            padding: EdgeInsets.only(bottom: 32.0),
            children: [
              _header(theme, shop),
              SizedBox(height: 24.0),
              _catalog(theme, shop),
            ],
          );
        },
      ),
      ),
    );
  }
}
