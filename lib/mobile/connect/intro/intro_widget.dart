import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'intro_model.dart';
export 'intro_model.dart';

/// First loading page
class IntroWidget extends StatefulWidget {
  const IntroWidget({super.key});

  static String routeName = 'Intro';
  static String routePath = '/intro';

  @override
  State<IntroWidget> createState() => _IntroWidgetState();
}

class _IntroWidgetState extends State<IntroWidget>
    with TickerProviderStateMixin {
  late IntroModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  bool _postersLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Affiches chargées à l'avance : pas d'écran noir au premier défilement.
    if (!_postersLoaded) {
      _postersLoaded = true;
      for (final slide in _introSlides) {
        precacheImage(AssetImage(slide.image), context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => IntroModel());
    // Le carrousel démarre sur la première diapositive.
    _model.carouselCurrentIndex = 0;

    _model.emailTextController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();

    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.black,
        body: Builder(
          builder: (context) {
            final slide = _introSlides[
                _model.carouselCurrentIndex % _introSlides.length];
            return Stack(
              fit: StackFit.expand,
              children: [
                // Fond plein écran : passe en fondu d'une affiche à l'autre.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  child: _introBackdrop(slide.image),
                ),
                // Dégradé léger, seulement derrière les contrôles.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.35),
                        ],
                        stops: const [0.0, 0.08, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    // Colonne limitée seulement sur les grands écrans.
                    constraints: BoxConstraints(
                        maxWidth: _isWideScreen(context)
                            ? 480.0
                            : double.infinity),
                    child: _buildMobileIntro(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _introSlides = [
    (
      image: 'assets/images/intro_poster1.jpg',
      aspect: 1100 / 1430,
      title: 'Faites vos achats en un clic',
      text:
          'Boutiques, magasins, restaurants, fast-foods et pharmacies réunis dans une seule application.',
    ),
    (
      image: 'assets/images/intro_poster2.jpg',
      aspect: 768 / 1376,
      title: 'Passez des commandes instantanées',
      text:
          'Une solution rapide pour vos achats, vos repas et vos produits pharmaceutiques.',
    ),
    (
      image: 'assets/images/intro_poster3.jpg',
      aspect: 768 / 1376,
      title: 'Augmentez la visibilité de vos produits',
      text:
          'Une plateforme incontournable pour le commerce local et la restauration.',
    ),
  ];

  /// Fond plein écran fait des couleurs de l'affiche en cours : étirée puis
  /// floutée, elle prolonge les couleurs des bords de l'affiche.
  Widget _introBackdrop(String image) {
    return ClipRect(
      key: ValueKey(image),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
            sigmaX: 36.0, sigmaY: 36.0, tileMode: TileMode.clamp),
        child: Image.asset(
          image,
          fit: BoxFit.fill,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  // Marges des fichiers intro_poster*.jpg, en largeurs d'affiche : à garder
  // égales à celles de tool/intro_posters.py.
  static const _posterMarginX = 0.35;
  static const _posterMarginY = 0.60;

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width > 600.0;

  /// L'affiche d'origine tient en entier entre le haut de l'écran et les
  /// contrôles du bas ; son décor prolongé remplit tout le reste de l'écran.
  Widget _introPoster(
      BuildContext context, ({String image, double aspect}) slide) {
    final safeArea = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, screen) {
        final areaTop = safeArea.top;
        final areaHeight = screen.maxHeight - areaTop - safeArea.bottom - 104.0;
        final isWide = _isWideScreen(context);
        // Sur ordinateur, les côtés se fondent dans le fond : l'affiche reste
        // en dehors de cette zone.
        final coreWidth = min(
            isWide ? screen.maxWidth * 0.84 : screen.maxWidth,
            areaHeight * slide.aspect);
        final coreHeight = coreWidth / slide.aspect;
        final poster = ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: (screen.maxWidth - coreWidth) / 2 -
                    coreWidth * _posterMarginX,
                top: areaTop +
                    (areaHeight - coreHeight) / 2 -
                    coreWidth * _posterMarginY,
                width: coreWidth * (1 + 2 * _posterMarginX),
                height: coreHeight + coreWidth * 2 * _posterMarginY,
                child: Image.asset(slide.image, fit: BoxFit.fill),
              ),
            ],
          ),
        );
        if (!isWide) return poster;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.08, 0.92, 1.0],
          ).createShader(bounds),
          child: poster,
        );
      },
    );
  }

  Widget _buildMobileIntro(BuildContext context) {
    final index = _model.carouselCurrentIndex % _introSlides.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 200 || constraints.maxWidth < 100) {
          return const SizedBox.shrink();
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Affiches entières (ni coupées ni étirées), au-dessus du fond.
              CarouselSlider(
                items: _introSlides
                    .map((s) =>
                        _introPoster(context, (image: s.image, aspect: s.aspect)))
                    .toList(),
                carouselController: _model.carouselController ??=
                    CarouselSliderController(),
                options: CarouselOptions(
                  height: double.infinity,
                  initialPage: 0,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: true,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 4),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  autoPlayCurve: Curves.easeInOutCubic,
                  onPageChanged: (i, _) =>
                      safeSetState(() => _model.carouselCurrentIndex = i),
                ),
              ),

              // 2. Barre supérieure : Logo Kitunga + Bouton « Passer »
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18.0, vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge discret Kitunga
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 5.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/logo/kitunga_logo.png',
                                width: 22.0,
                                height: 22.0,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                'KITUNGA',
                                style: GoogleFonts.interTight(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bouton Passer
                        Material(
                          color: Colors.black.withOpacity(0.4),
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () =>
                                context.pushNamed(OnboardingWidget.routeName),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0, vertical: 7.0),
                              child: Text(
                                'Passer',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Bas de page : Indicateurs discrets et Bouton d'action direct
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22.0, 0.0, 22.0, 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Points de pagination
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _introSlides.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              width: i == index ? 22.0 : 7.0,
                              height: 6.0,
                              decoration: BoxDecoration(
                                color: i == index
                                    ? const Color(0xFFE51A1A)
                                    : Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18.0),

                        // Bouton Commencer moderne et impactant
                        SizedBox(
                          width: double.infinity,
                          height: 54.0,
                          child: ElevatedButton(
                            onPressed: () =>
                                context.pushNamed(OnboardingWidget.routeName),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE51A1A),
                              foregroundColor: Colors.white,
                              elevation: 6.0,
                              shadowColor: const Color(0x80E51A1A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Commencer',
                                  style: GoogleFonts.interTight(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 19.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
