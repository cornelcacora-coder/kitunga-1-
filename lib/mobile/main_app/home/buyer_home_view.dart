import 'dart:async';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
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
    // Auto-scroll toutes les 4 secondes
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_bannerController.hasClients) {
        final next = (_bannerPage + 1) % _bannerSlides.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  // Données des slides du carrousel avec les 3 images de assets/logo/
  static const _bannerSlides = [
    (
      image: 'assets/logo/image1.png',
      title1: 'Tout au même',
      title2: 'endroit',
      subtitle: 'Boutiques, restaurants\net pharmacies',
    ),
    (
      image: 'assets/logo/image2.png',
      title1: 'Livraison',
      title2: 'rapide',
      subtitle: 'Recevez vos commandes\nà domicile',
    ),
    (
      image: 'assets/logo/image3.png',
      title1: 'Paiement',
      title2: 'sécurisé',
      subtitle: 'Achetez en toute\nconfiance',
    ),
  ];

  static const _categories = [
    (
      name: 'Boutique',
      image: 'assets/images/images__14_-removebg-preview.png',
      bg: Color(0xFFF3E8FF),
    ),
    (
      name: 'Restaurant',
      image: 'assets/images/images__1_-removebg-preview.png',
      bg: Color(0xFFFEECE4),
    ),
    (
      name: 'Pharmacie',
      image: 'assets/images/tlchargement-removebg-preview.png',
      bg: Color(0xFFE5F8ED),
    ),
    (
      name: 'Magasin',
      image: 'assets/images/images__5_-removebg-preview.png',
      bg: Color(0xFFFEEDEA),
    ),
    (
      name: 'Fast Food',
      image: 'assets/images/images-removebg-preview.png',
      bg: Color(0xFFFFF2E5),
    ),
  ];

  static const _rows = [
    (category: 'Boutique', title: 'Boutiques à la une'),
    (category: 'Restaurant', title: 'Restaurants populaires'),
    (category: 'Pharmacie', title: 'Pharmacies'),
  ];

  @override
  void dispose() {
    _bannerTimer?.cancel();
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
    final topInset = MediaQuery.of(context).padding.top;
    final nameParts = currentUserDisplayName.trim().split(' ');
    final firstName = nameParts.first.trim();
    final displayName = firstName.isNotEmpty ? firstName : 'OKOMBI';

    return ListView(
      padding: EdgeInsets.only(
        top: topInset,
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
                        color: const Color(0xFF1E242B),
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
                      color: const Color(0xFF6B7280),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(color: const Color(0xFFF1F4F8), width: 1.2),
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
                            color: const Color(0xFF9CA3AF),
                            fontSize: 13.5,
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1E242B),
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
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Recherche vocale bientôt disponible'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20.0),
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE51A1A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
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

              // Reste des sections si l'utilisateur défile
              for (final row in _rows)
                ..._buildCategoryRow(theme, row.category, row.title),
            ],
          ],
        );
  }

  /// Barre d'en-tête fidèle à la maquette
  Widget _buildHeader(BuildContext context, FlutterFlowTheme theme) {
    return Container(
      color: Colors.white,
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
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF1F4F8), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Color(0xFF1E242B),
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
                          color: const Color(0xFF1E242B),
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
              // Bouton Mode Sombre / Clair (cercle noir avec croissant blanc)
              InkWell(
                onTap: () {
                  setDarkModeSetting(
                    context,
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  );
                },
                borderRadius: BorderRadius.circular(18.0),
                child: Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.nightlight_round,
                    color: Colors.white,
                    size: 17.0,
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFF1F4F8), width: 1.0),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 6.0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Color(0xFF1E242B),
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
                      Image.asset(
                        slide.image,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                      ),

                      // Dégradé rouge sur la gauche
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFFD60808),
                              const Color(0xFFE51A1A),
                              const Color(0xFFE51A1A).withOpacity(0.92),
                              const Color(0xFFE51A1A).withOpacity(0.35),
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
                                Text(
                                  slide.title2,
                                  maxLines: 1,
                                  style: GoogleFonts.interTight(
                                    color: const Color(0xFFFFD200),
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
                              onTap: () {
                                context.pushNamed(ShopsWidget.routeName);
                              },
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
                                      'Découvrir',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE51A1A),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFFE51A1A),
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
                      color: const Color(0xFF1E242B),
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
          child: ListView.separated(
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
                      padding: const EdgeInsets.all(11.0),
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                      child: Image.asset(c.image, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      c.name,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E242B),
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
                          color: const Color(0xFF1E242B),
                          fontSize: 17.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Vérifiés par l\'équipe Kitunga',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6B7280),
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
    if (results.isEmpty) {
      return [
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
    // 1. Décoration douce coin supérieur gauche (s'arrête bien avant le logo pour laisser le fond propre)
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE51A1A),
          Color(0xFFFF4D4D),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.22, 50));

    final pathLeft = Path();
    pathLeft.moveTo(0, 0);
    pathLeft.lineTo(size.width * 0.20, 0);
    pathLeft.quadraticBezierTo(
      size.width * 0.10,
      25,
      0,
      35,
    );
    pathLeft.close();
    canvas.drawPath(pathLeft, leftPaint);

    // 2. Vague fluide descendante sur le côté droit (derrière la salutation et le micro de recherche)
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
          Rect.fromLTWH(size.width * 0.65, 0, size.width * 0.35, 290));

    final pathRight = Path();
    pathRight.moveTo(size.width * 0.78, 0);
    pathRight.lineTo(size.width, 0);
    pathRight.lineTo(size.width, 270);
    pathRight.cubicTo(
      size.width * 0.80,
      240,
      size.width * 0.75,
      175,
      size.width * 0.90,
      115,
    );
    pathRight.cubicTo(
      size.width * 0.98,
      75,
      size.width * 0.90,
      35,
      size.width * 0.78,
      0,
    );
    pathRight.close();
    canvas.drawPath(pathRight, rightPaint);

    // 3. Voile doux translucide rouge le long du côté droit
    final softPaint = Paint()
      ..color = const Color(0x22E51A1A)
      ..style = PaintingStyle.fill;
    final softPath = Path();
    softPath.moveTo(size.width * 0.72, 0);
    softPath.lineTo(size.width, 0);
    softPath.lineTo(size.width, 285);
    softPath.cubicTo(
      size.width * 0.76,
      250,
      size.width * 0.70,
      170,
      size.width * 0.86,
      110,
    );
    softPath.cubicTo(
      size.width * 0.95,
      70,
      size.width * 0.85,
      30,
      size.width * 0.72,
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
