import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import 'categories_page.dart';
import 'home_sections.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accueil des clients et des visiteurs : recherche, bannières, catégories,
/// commerces certifiés, nouveaux produits et tous les commerces.
class BuyerHomeView extends StatefulWidget {
  const BuyerHomeView({super.key, required this.sellers});

  /// Comptes vendeurs (rôle « Seller »).
  final List<UserRecord> sellers;

  @override
  State<BuyerHomeView> createState() => _BuyerHomeViewState();
}

class _BuyerHomeViewState extends State<BuyerHomeView> {
  final _searchController = TextEditingController();
  // Produits les plus récents (section « Nos produits »).
  late final Stream<List<ProductRecord>> _newProducts = queryProductRecord(
    queryBuilder: (q) => q.orderBy('created_at', descending: true),
    limit: 10,
  );
  String _query = '';
  int _bannerIndex = 0;

  static const _banners = [
    (image: 'assets/images/Cover.png', title: '', subtitle: ''),
    (
      image: 'assets/images/Girl_Bag2.jpg',
      title: 'Tout au même endroit',
      subtitle: 'Boutiques, restaurants et pharmacies',
    ),
    (
      image: 'assets/images/Gemini_Generated_Image_xb96ubxb96ubxb96.png',
      title: 'Les meilleurs plats',
      subtitle: 'Commandez chez les restaurants de votre ville',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserRecord> get _certified =>
      widget.sellers.where((s) => s.verified).toList();

  List<UserRecord> get _searchResults {
    final q = _query.trim().toLowerCase();
    return widget.sellers
        .where((s) =>
            s.displayName.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final firstName = currentUserDisplayName.trim().split(' ').first;
    final isGuest = valueOrDefault(currentUserDocument?.role, '') == 'Guest' ||
        firstName.isEmpty;

    return ListView(
      padding: EdgeInsets.only(bottom: 32.0),
      children: [
        // Salutation
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 8.0, 20.0, 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGuest ? 'Bienvenue' : 'Bonjour, $firstName',
                style: GoogleFonts.interTight(
                  color: theme.primaryText,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.0),
              Text(
                'Que souhaitez-vous commander aujourd\'hui ?',
                style: GoogleFonts.inter(
                  color: theme.secondaryText,
                  fontSize: 14.0,
                ),
              ),
            ],
          ),
        ),
        // Recherche
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 0.0),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
            decoration: InputDecoration(
              hintText: 'Rechercher une boutique, un restaurant…',
              hintStyle:
                  GoogleFonts.inter(color: theme.secondaryText, fontSize: 15.0),
              prefixIcon:
                  Icon(Icons.search_rounded, color: theme.secondaryText),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon:
                          Icon(Icons.close_rounded, color: theme.secondaryText),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                        FocusScope.of(context).unfocus();
                      },
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
        ),
        if (_query.trim().isNotEmpty)
          ..._buildSearchResults(theme)
        else ...[
          SizedBox(height: 20.0),
          _buildBanners(theme),
          KitungaSectionHeader(
            title: 'Explorer par catégorie',
            subtitle: 'Trouvez le bon commerce en un geste',
            onMore: () => openSeeMore(context, KitungaCategoriesPage()),
          ),
          _buildCategories(),
          if (_certified.isNotEmpty) ...[
            KitungaSectionHeader(
              title: 'Commerces certifiés',
              subtitle: 'Vérifiés par l\'équipe Kitunga',
              onMore: () => openSeeMore(
                context,
                KitungaShopListPage(
                  title: 'Commerces certifiés',
                  subtitle: 'Vérifiés par l\'équipe Kitunga',
                  shops: _certified,
                ),
              ),
            ),
            _shopRow(_certified),
          ],
          _buildNewProducts(),
          if (widget.sellers.isNotEmpty) ...[
            KitungaSectionHeader(
              title: 'Tous nos commerces',
              subtitle: 'Boutiques, restaurants, pharmacies et plus',
              onMore: () => openSeeMore(
                context,
                KitungaShopListPage(
                  title: 'Tous nos commerces',
                  subtitle: '${widget.sellers.length} commerces sur Kitunga',
                  shops: widget.sellers,
                ),
              ),
            ),
            _shopRow(widget.sellers),
          ],
        ],
      ],
    );
  }

  Widget _buildBanners(FlutterFlowTheme theme) {
    return Column(
      children: [
        CarouselSlider(
          items: _banners.map((b) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(b.image, fit: BoxFit.cover),
                    if (b.title.isNotEmpty) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xB3000000)],
                            stops: [0.35, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title,
                              style: GoogleFonts.interTight(
                                color: Colors.white,
                                fontSize: 20.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2.0),
                            Text(
                              b.subtitle,
                              style: GoogleFonts.inter(
                                color: Color(0xE6FFFFFF),
                                fontSize: 13.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
          options: CarouselOptions(
            height: 170.0,
            viewportFraction: 0.9,
            enableInfiniteScroll: true,
            autoPlay: true,
            autoPlayInterval: Duration(seconds: 5),
            autoPlayCurve: Curves.easeInOut,
            onPageChanged: (i, _) => setState(() => _bannerIndex = i),
          ),
        ),
        SizedBox(height: 10.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: Duration(milliseconds: 250),
              margin: EdgeInsets.symmetric(horizontal: 3.0),
              width: i == _bannerIndex ? 18.0 : 6.0,
              height: 6.0,
              decoration: BoxDecoration(
                color: i == _bannerIndex ? theme.primary : theme.divider,
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 104.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: kitungaCategories.length,
        separatorBuilder: (_, __) => SizedBox(width: 14.0),
        itemBuilder: (context, i) => KitungaCategoryTile(
          name: kitungaCategories[i].name,
          image: kitungaCategories[i].image,
        ),
      ),
    );
  }

  /// Rangée horizontale de cartes de commerces.
  Widget _shopRow(List<UserRecord> shops) {
    return SizedBox(
      height: KitungaShopCard.rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: shops.length,
        separatorBuilder: (_, __) => SizedBox(width: 14.0),
        itemBuilder: (context, i) => KitungaShopCard(shop: shops[i]),
      ),
    );
  }

  /// « Nos produits » : rangée horizontale des produits les plus récents.
  Widget _buildNewProducts() {
    return StreamBuilder<List<ProductRecord>>(
      stream: _newProducts,
      builder: (context, snapshot) {
        final products =
            (snapshot.data ?? []).where(kitungaIsPublished).toList();
        if (products.isEmpty) return SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KitungaSectionHeader(
              title: 'Nos produits',
              subtitle: 'Les nouveautés de nos commerçants',
              onMore: () => openSeeMore(context, KitungaProductListPage()),
            ),
            // Même présentation que les autres sections : rangée horizontale.
            SizedBox(
              height: KitungaProductCard.gridExtent,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: products.length,
                separatorBuilder: (_, __) => SizedBox(width: 14.0),
                itemBuilder: (context, i) => SizedBox(
                  width: 170.0,
                  child: KitungaProductCard(
                    product: products[i],
                    onTap: () => openKitungaProduct(context, products[i]),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildSearchResults(FlutterFlowTheme theme) {
    final results = _searchResults;
    if (results.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.fromLTRB(32.0, 48.0, 32.0, 0.0),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48.0, color: theme.secondaryText),
              SizedBox(height: 12.0),
              Text(
                'Aucun commerce ne correspond à « ${_query.trim()} ».',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: theme.secondaryText, fontSize: 14.0),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      KitungaSectionHeader(
          title: '${results.length} résultat${results.length > 1 ? 's' : ''}'),
      for (final s in results) KitungaShopListTile(shop: s),
    ];
  }
}
