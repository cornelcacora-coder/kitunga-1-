import 'dart:async';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/kitunga_categories.dart';
import '/backend/kitunga_banners.dart';
import '/mobile/main_app/search/kitunga_search_page.dart' show openKitungaSearch;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/main_app/home/home_sections.dart' show KitungaHomeProducts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accueil des clients et des visiteurs fidèle à la maquette Kitunga.
class BuyerHomeView extends StatefulWidget {
  const BuyerHomeView({
    super.key,
    required this.sellers,
    this.onOpenDrawer,
  });

  /// Comptes vendeurs (rôle « Seller »).
  final List<UserRecord> sellers;

  /// Callback pour ouvrir le menu latéral (drawer).
  final VoidCallback? onOpenDrawer;

  @override
  State<BuyerHomeView> createState() => _BuyerHomeViewState();
}

class _BuyerHomeViewState extends State<BuyerHomeView> {
  final _searchController = TextEditingController();
  String _query = '';

  // Carrousel bannière
  final PageController _bannerController = PageController();
  int _bannerPage = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    KitungaBannerStore.instance.addListener(_onBanners);
    // Auto-scroll toutes les 4 secondes
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final count = _bannerSlides.length;
      if (count > 1 && _bannerController.hasClients) {
        final next = (_bannerPage + 1) % count;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  // Publicités et promotions du carrousel, gérées par l'admin (page
  // « Publicités ») ; les 3 bannières d'origine tant qu'elles ne sont pas
  // chargées.
  List<KitungaBanner> get _bannerSlides => KitungaBannerStore.instance.list;

  void _onBanners() {
    if (!mounted) return;
    setState(() {
      final count = _bannerSlides.length;
      if (_bannerPage >= count) _bannerPage = 0;
    });
  }

  /// Catégories gérées par l'admin (les 5 d'origine en secours).
  static List<KitungaCategory> get _categories =>
      KitungaCategoryStore.instance.list;

  static const _rows = [
    (category: 'Boutique', title: 'Boutiques à la une'),
    (category: 'Restaurant', title: 'Restaurants populaires'),
    (category: 'Pharmacie', title: 'Pharmacies'),
  ];

  @override
  void dispose() {
    _bannerTimer?.cancel();
    KitungaBannerStore.instance.removeListener(_onBanners);
    _searchController.dispose();
    _bannerController.dispose();
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

  List<UserRecord> get _certifiedSellers {
    final verified = widget.sellers.where((s) => s.verified).toList();
    if (verified.isNotEmpty) return verified;
    return widget.sellers.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;
    final nameParts = currentUserDisplayName.trim().split(' ');
    final firstName = nameParts.first.trim();
    final displayName = firstName.isNotEmpty ? firstName : 'OKOMBI';

    return Stack(
      children: [
        if (!isDark)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 290.0,
            child: IgnorePointer(
              child: CustomPaint(
                painter: HeaderBackgroundWavesPainter(),
              ),
            ),
          ),
        ListView(
          padding: EdgeInsets.only(
            top: topInset + 4.0,
            bottom: 32.0,
          ),
          children: [
            // 1. Barre d'en-tête (Menu, Logo Kitunga, Mode Nuit, Panier)
            _buildHeader(context, theme),

            // 2. Salutation ("Bonjour, OKOMBI 👋")
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Bonjour, ',
                      style: GoogleFonts.interTight(
                        color: theme.primaryText,
                        fontSize: 24.0,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: displayName.toUpperCase(),
                          style: GoogleFonts.interTight(
                            color: const Color(0xFFE51A1A),
                            fontSize: 24.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const TextSpan(
                          text: ' 👋',
                          style: TextStyle(fontSize: 22.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Que souhaitez-vous commander aujourd\'hui ?',
                    style: GoogleFonts.inter(
                      color: theme.secondaryText,
                      fontSize: 14.0,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Barre de recherche avec icône micro rouge
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 14.0, 20.0, 0.0),
              child: Container(
                height: 52.0,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E242B) : Colors.white,
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C3238) : const Color(0xFFF1F4F8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0C000000),
                      blurRadius: 10.0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(left: 14.0, right: 6.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFE51A1A),
                      size: 24.0,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Rechercher une boutique, un restaurant...',
                          hintStyle: GoogleFonts.inter(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                            fontSize: 13.5,
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: GoogleFonts.inter(
                          color: theme.primaryText,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF9CA3AF), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    // Recherche avancée : produits et commerces, filtres, tri.
                    InkWell(
                      onTap: () =>
                          openKitungaSearch(context, query: _query.trim()),
                      borderRadius: BorderRadius.circular(20.0),
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE51A1A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 20.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_query.trim().isNotEmpty)
              ..._buildSearchResults(theme)
            else ...[
              const SizedBox(height: 18.0),

              // 4. Bannière Hero promotionnelle ("Tout au même endroit")
              _buildHeroBanner(context),

              const SizedBox(height: 22.0),

              // 5. Section "Explorer par catégorie"
              _buildCategoriesSection(context),

              const SizedBox(height: 22.0),

              // 6. Section "Commerces certifiés"
              _buildCertifiedSection(context, theme),

              // 7. Produits : Tendances, Nouveautés, Nos produits.
              const KitungaHomeProducts(),

              // Reste des sections si l'utilisateur défile
              for (final row in _rows)
                ..._buildCategoryRow(theme, row.category, row.title),
            ],
          ],
        ),
      ],
    );
  }

  /// Barre d'en-tête fidèle à la maquette
  Widget _buildHeader(BuildContext context, FlutterFlowTheme theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bouton Menu latéral (Hamburger)
          InkWell(
            onTap: () {
              if (widget.onOpenDrawer != null) {
                widget.onOpenDrawer!();
              } else {
                Scaffold.maybeOf(context)?.openDrawer();
              }
            },
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              width: 38.0,
              height: 38.0,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF2C3238) : const Color(0xFFF1F4F8),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_rounded,
                color: theme.primaryText,
                size: 22.0,
              ),
            ),
          ),

          // Logo Kitunga centré avec chariot et slogan
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 34.0,
                    height: 34.0,
                    child: Image.asset(
                      'assets/logo/kitunga_logo.png',
                      alignment: Alignment.topCenter,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 5.0),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KITUNGA',
                        style: GoogleFonts.interTight(
                          color: const Color(0xFFE51A1A),
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Achetez. Vivez mieux !',
                        style: GoogleFonts.inter(
                          color: theme.secondaryText,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      CustomPaint(
                        size: const Size(48.0, 3.0),
                        painter: SmileUnderlinePainter(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Actions à droite : Bouton mode nuit + Panier
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton Mode Sombre / Clair (cercle blanc harmonisé avec le panier)
              InkWell(
                onTap: () {
                  setDarkModeSetting(
                    context,
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  );
                },
                borderRadius: BorderRadius.circular(20.0),
                child: Container(
                  width: 38.0,
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E242B) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C3238) : const Color(0xFFF1F4F8),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 6.0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.nightlight_round,
                    color: isDark ? const Color(0xFFFFD200) : const Color(0xFF1E242B),
                    size: 19.0,
                  ),
                ),
              ),
              const SizedBox(width: 6.0),

              // Bouton Panier avec badge dynamique lié au panier réel
              ListenableBuilder(
                listenable: FFAppState(),
                builder: (context, _) {
                  final cartCount = FFAppState().cartitems.length;
                  return InkWell(
                    onTap: () {
                      context.pushNamed(CartLastWidget.routeName);
                    },
                    borderRadius: BorderRadius.circular(20.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38.0,
                          height: 38.0,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E242B) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF2C3238) : const Color(0xFFF1F4F8),
                              width: 1.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 6.0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: theme.primaryText,
                            size: 20.0,
                          ),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            top: -2.0,
                            right: -2.0,
                            child: Container(
                              width: 17.0,
                              height: 17.0,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE51A1A),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$cartCount',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bannière Hero carrousel avec PageView et points de pagination
  Widget _buildHeroBanner(BuildContext context) {
    // Aucune bannière diffusée (toutes désactivées par l'admin).
    if (_bannerSlides.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // ── Carrousel ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(26.0),
            child: SizedBox(
              height: 200.0,
              child: ScrollConfiguration(
                // Permet le drag souris sur Flutter Web
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: PageView.builder(
                  controller: _bannerController,
                  itemCount: _bannerSlides.length,
                  onPageChanged: (i) => setState(() => _bannerPage = i),
                  itemBuilder: (context, idx) {
                  final slide = _bannerSlides[idx];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo de fond
                      KitungaBannerImage(slide.image, color: slide.color),

                      // Dégradé rouge sur la gauche
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color.lerp(slide.color, Colors.black, 0.08)!,
                              slide.color,
                              slide.color.withOpacity(0.92),
                              slide.color.withOpacity(0.35),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 0.52, 0.70, 0.88],
                          ),
                        ),
                      ),

                      // Textes et bouton
                      Positioned(
                        left: 18.0,
                        top: 14.0,
                        bottom: 14.0,
                        right: 120.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (slide.badge.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4.0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      color: slide.accent,
                                      borderRadius: BorderRadius.circular(6.0),
                                    ),
                                    child: Text(
                                      slide.badge,
                                      style: GoogleFonts.inter(
                                        color: slide.color,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                if (slide.title1.isNotEmpty)
                                Text(
                                  slide.title1,
                                  maxLines: 1,
                                  style: GoogleFonts.interTight(
                                    color: Colors.white,
                                    fontSize: 21.0,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    height: 1.1,
                                  ),
                                ),
                                if (slide.title2.isNotEmpty)
                                Text(
                                  slide.title2,
                                  maxLines: 1,
                                  style: GoogleFonts.interTight(
                                    color: slide.accent,
                                    fontSize: 29.0,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  slide.subtitle,
                                  maxLines: 2,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => openKitungaBanner(context, slide),
                              borderRadius: BorderRadius.circular(20.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 7.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 6.0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      slide.button,
                                      style: GoogleFonts.inter(
                                        color: slide.color,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: slide.color,
                                      size: 16.0,
                                    ),
                                  ],
                                ),
                              ),
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
          ),

          const SizedBox(height: 12.0),

          // ── Points de pagination ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_bannerSlides.length, (i) {
              final isActive = i == _bannerPage;
              return GestureDetector(
                onTap: () => _bannerController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: isActive ? 24.0 : 7.0,
                  height: 7.0,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFE51A1A)
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Section "Explorer par catégorie"
  Widget _buildCategoriesSection(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4.0,
                    height: 18.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE51A1A),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Explorer par catégorie',
                    style: GoogleFonts.interTight(
                      color: theme.primaryText,
                      fontSize: 17.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.pushNamed(ShopsWidget.routeName),
                child: Row(
                  children: [
                    Text(
                      'Voir plus',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE51A1A),
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2.0),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFE51A1A),
                      size: 16.0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.0),
        SizedBox(
          height: 104.0,
          // Reconstruit quand la liste de l'admin arrive du serveur.
          child: ListenableBuilder(
            listenable: KitungaCategoryStore.instance,
            builder: (context, _) => ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14.0),
            itemBuilder: (context, i) {
              final c = _categories[i];
              return InkWell(
                borderRadius: BorderRadius.circular(18.0),
                onTap: () => _openCategory(c.name),
                child: Column(
                  children: [
                    Container(
                      width: 66.0,
                      height: 66.0,
                      padding: kitungaCategoryPadding(
                          c.image, const EdgeInsets.all(11.0)),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: c.pastel,
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                      child: KitungaCategoryImage(c.image),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      c.name,
                      style: GoogleFonts.inter(
                        color: theme.primaryText,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          ),
        ),
      ],
    );
  }

  /// Section "Commerces certifiés"
  Widget _buildCertifiedSection(
      BuildContext context, FlutterFlowTheme theme) {
    final certifiedShops = _certifiedSellers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4.0,
                    height: 22.0,
                    margin: const EdgeInsets.only(top: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE51A1A),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commerces certifiés',
                        style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 17.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Vérifiés par l\'équipe Kitunga',
                        style: GoogleFonts.inter(
                          color: theme.secondaryText,
                          fontSize: 12.0,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.pushNamed(ShopsWidget.routeName),
                borderRadius: BorderRadius.circular(20.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE51A1A),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir plus',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 3.0),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 15.0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14.0),
        SizedBox(
          height: 146.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: certifiedShops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14.0),
            itemBuilder: (context, i) {
              final s = certifiedShops[i];
              return InkWell(
                borderRadius: BorderRadius.circular(16.0),
                onTap: () => _openShop(s),
                child: SizedBox(
                  width: 220.0,
                  height: 135.0,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16.0),
                        child: _image(
                          s.businessCover.isNotEmpty
                              ? s.businessCover
                              : s.photoUrl,
                          width: 220.0,
                          height: 135.0,
                        ),
                      ),
                      // Badge de certification rouge avec coche blanche (rosace)
                      Positioned(
                        top: 10.0,
                        right: 10.0,
                        child: _verifiedRosetteBadge(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Badge rosace de certification rouge avec coche blanche
  Widget _verifiedRosetteBadge() {
    return Container(
      width: 32.0,
      height: 32.0,
      decoration: BoxDecoration(
        color: const Color(0xFFE51A1A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 18.0,
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onSeeAll}) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20.0, 28.0, 12.0, 12.0),
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

  List<Widget> _buildCategoryRow(
      FlutterFlowTheme theme, String category, String title) {
    final shops = widget.sellers.where((s) => s.category == category).toList();
    if (shops.isEmpty) return [];
    return [
      _sectionHeader(title, onSeeAll: () => _openCategory(category)),
      SizedBox(
        height: 236.0,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          itemCount: shops.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14.0),
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
          padding: const EdgeInsetsDirectional.only(start: 4.0),
          child: Icon(Icons.verified_rounded, color: theme.primary, size: 16.0),
        )
      : const SizedBox.shrink();

  String _subtitle(UserRecord s) =>
      [s.category, s.horraire].where((e) => e.trim().isNotEmpty).join(' · ');

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
                    padding: const EdgeInsets.all(2.0),
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
            const SizedBox(height: 24.0),
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
            const SizedBox(height: 2.0),
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

  Widget _shopTile(FlutterFlowTheme theme, UserRecord s) {
    return InkWell(
      onTap: () => _openShop(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14.0),
              child: _image(
                  s.photoUrl.isNotEmpty ? s.photoUrl : s.businessCover,
                  width: 56.0,
                  height: 56.0),
            ),
            const SizedBox(width: 14.0),
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
                  const SizedBox(height: 3.0),
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
    // Lien vers la recherche dans les produits de tous les commerces.
    final products = Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 0.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE51A1A),
          side: const BorderSide(color: Color(0x55E51A1A)),
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.0)),
        ),
        onPressed: () => openKitungaSearch(context, query: _query.trim()),
        icon: const Icon(Icons.shopping_bag_outlined, size: 18.0),
        label: Text('Chercher « ${_query.trim()} » dans les produits',
            overflow: TextOverflow.ellipsis),
      ),
    );
    if (results.isEmpty) {
      return [
        products,
        Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 48.0, 32.0, 0.0),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48.0, color: theme.secondaryText),
              const SizedBox(height: 12.0),
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
      products,
      _sectionHeader(
          '${results.length} résultat${results.length > 1 ? 's' : ''}'),
      for (final s in results) _shopTile(theme, s),
    ];
  }
}

/// Peintre pour les vagues organiques rouges du haut de page (fidèle à la maquette, fond blanc sous le logo)
class HeaderBackgroundWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Décoration douce coin supérieur gauche (s'arrête bien avant le logo)
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE51A1A),
          Color(0xFFFF4D4D),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.28, 65));

    final pathLeft = Path();
    pathLeft.moveTo(0, 0);
    pathLeft.lineTo(size.width * 0.26, 0);
    pathLeft.quadraticBezierTo(
      size.width * 0.12,
      35,
      0,
      50,
    );
    pathLeft.close();
    canvas.drawPath(pathLeft, leftPaint);

    // 2. Vague fluide descendante sur le côté droit
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFE51A1A),
          Color(0xFFD81010),
          Color(0xFFFF3333),
        ],
      ).createShader(
          Rect.fromLTWH(size.width * 0.60, 0, size.width * 0.40, 260));

    final pathRight = Path();
    pathRight.moveTo(size.width * 0.72, 0);
    pathRight.lineTo(size.width, 0);
    pathRight.lineTo(size.width, 180);
    pathRight.cubicTo(
      size.width * 0.85,
      170,
      size.width * 0.74,
      120,
      size.width * 0.88,
      70,
    );
    pathRight.cubicTo(
      size.width * 0.96,
      40,
      size.width * 0.85,
      20,
      size.width * 0.72,
      0,
    );
    pathRight.close();
    canvas.drawPath(pathRight, rightPaint);

    // 3. Voile doux translucide rouge le long du côté droit
    final softPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0x35E51A1A),
          Color(0x15FF4D4D),
          Color(0x00FFFFFF),
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.55, 0, size.width * 0.45, 280));
    final softPath = Path();
    softPath.moveTo(size.width * 0.62, 0);
    softPath.lineTo(size.width, 0);
    softPath.lineTo(size.width, 270);
    softPath.cubicTo(
      size.width * 0.75,
      230,
      size.width * 0.68,
      160,
      size.width * 0.84,
      100,
    );
    softPath.cubicTo(
      size.width * 0.94,
      60,
      size.width * 0.80,
      25,
      size.width * 0.62,
      0,
    );
    softPath.close();
    canvas.drawPath(softPath, softPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Peintre pour le sourire rouge sous le slogan du logo
class SmileUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE51A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
