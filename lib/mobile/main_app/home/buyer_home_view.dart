import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accueil des clients et des visiteurs : recherche, bannières, catégories,
/// rangées par type de commerce puis liste complète.
class BuyerHomeView extends StatefulWidget {
  const BuyerHomeView({super.key, required this.sellers});

  /// Comptes vendeurs (rôle « Seller »).
  final List<UserRecord> sellers;

  @override
  State<BuyerHomeView> createState() => _BuyerHomeViewState();
}

class _BuyerHomeViewState extends State<BuyerHomeView> {
  final _searchController = TextEditingController();
  String _query = '';
  int _bannerIndex = 0;

  static const _categories = [
    (name: 'Boutique', image: 'assets/images/images__14_-removebg-preview.png'),
    (name: 'Restaurant', image: 'assets/images/images__1_-removebg-preview.png'),
    (name: 'Pharmacie', image: 'assets/images/tlchargement-removebg-preview.png'),
    (name: 'Magasin', image: 'assets/images/images__5_-removebg-preview.png'),
    (name: 'Fast Food', image: 'assets/images/images-removebg-preview.png'),
  ];

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

  static const _rows = [
    (category: 'Boutique', title: 'Boutiques à la une'),
    (category: 'Restaurant', title: 'Restaurants populaires'),
    (category: 'Pharmacie', title: 'Pharmacies'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openShop(UserRecord seller) {
    context.pushNamed(
      ShopDetailPageWidget.routeName,
      queryParameters: {
        'userRef': serializeParam(seller.reference, ParamType.DocumentReference),
        'isSameSeller': serializeParam(false, ParamType.bool),
      }.withoutNulls,
    );
  }

  void _openCategory(String category) {
    context.pushNamed(
      ShopsWidget.routeName,
      queryParameters: {
        'tag': serializeParam(category, ParamType.String),
      }.withoutNulls,
    );
  }

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
    final isGuest =
        valueOrDefault(currentUserDocument?.role, '') == 'Guest' ||
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
                      icon: Icon(Icons.close_rounded,
                          color: theme.secondaryText),
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
          _sectionHeader('Catégories'),
          _buildCategories(theme),
          for (final row in _rows)
            ..._buildCategoryRow(theme, row.category, row.title),
          if (widget.sellers.isNotEmpty) ...[
            _sectionHeader('Tous les commerces'),
            for (final seller in widget.sellers) _shopTile(theme, seller),
          ],
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onSeeAll}) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 28.0, 12.0, 12.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                'Voir tout',
                style: GoogleFonts.inter(
                  color: theme.primary,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
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

  Widget _buildCategories(FlutterFlowTheme theme) {
    return SizedBox(
      height: 104.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 14.0),
        itemBuilder: (context, i) {
          final c = _categories[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18.0),
            onTap: () => _openCategory(c.name),
            child: SizedBox(
              width: 72.0,
              child: Column(
                children: [
                  Container(
                    width: 72.0,
                    height: 72.0,
                    padding: EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: theme.primaryBackground,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Image.asset(c.image, fit: BoxFit.contain),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: theme.primaryText,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCategoryRow(
      FlutterFlowTheme theme, String category, String title) {
    final shops = widget.sellers.where((s) => s.category == category).toList();
    if (shops.isEmpty) return [];
    return [
      _sectionHeader(title, onSeeAll: () => _openCategory(category)),
      SizedBox(
        height: 206.0,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          itemCount: shops.length,
          separatorBuilder: (_, __) => SizedBox(width: 14.0),
          itemBuilder: (context, i) => _shopCard(theme, shops[i]),
        ),
      ),
    ];
  }

  Widget _image(String url, {double? width, double? height}) {
    final theme = FlutterFlowTheme.of(context);
    final placeholder = Container(
      width: width,
      height: height,
      color: theme.primaryBackground,
      child: Icon(Icons.storefront_rounded, color: theme.secondaryText),
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }

  Widget _verified(FlutterFlowTheme theme, UserRecord s) => s.verified
      ? Padding(
          padding: EdgeInsetsDirectional.only(start: 4.0),
          child: Icon(Icons.verified_rounded, color: theme.primary, size: 16.0),
        )
      : SizedBox.shrink();

  String _subtitle(UserRecord s) =>
      [s.category, s.horraire].where((e) => e.trim().isNotEmpty).join(' · ');

  /// Carte de commerce pour les rangées horizontales.
  Widget _shopCard(FlutterFlowTheme theme, UserRecord s) {
    return InkWell(
      borderRadius: BorderRadius.circular(18.0),
      onTap: () => _openShop(s),
      child: SizedBox(
        width: 230.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18.0),
                  child: _image(s.businessCover, width: 230.0, height: 130.0),
                ),
                Positioned(
                  left: 12.0,
                  bottom: -18.0,
                  child: Container(
                    padding: EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: _image(s.photoUrl, width: 40.0, height: 40.0),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.0),
            Row(
              children: [
                Flexible(
                  child: Text(
                    s.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.interTight(
                      color: theme.primaryText,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _verified(theme, s),
              ],
            ),
            SizedBox(height: 2.0),
            Text(
              _subtitle(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: theme.secondaryText,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ligne compacte pour la liste complète et les résultats de recherche.
  Widget _shopTile(FlutterFlowTheme theme, UserRecord s) {
    return InkWell(
      onTap: () => _openShop(s),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14.0),
              child: _image(s.photoUrl.isNotEmpty ? s.photoUrl : s.businessCover,
                  width: 56.0, height: 56.0),
            ),
            SizedBox(width: 14.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          s.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.interTight(
                            color: theme.primaryText,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _verified(theme, s),
                    ],
                  ),
                  SizedBox(height: 3.0),
                  Text(
                    _subtitle(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: theme.secondaryText,
                      fontSize: 13.0,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.secondaryText),
          ],
        ),
      ),
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
      _sectionHeader(
          '${results.length} résultat${results.length > 1 ? 's' : ''}'),
      for (final s in results) _shopTile(theme, s),
    ];
  }
}
