import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '/mobile/deliverer/kitunga_deliverer_pages.dart'
    show KitungaDelivererCourses, KitungaDelivererMap;
import '/mobile/components/messaging/kitunga_messages.dart'
    show KitungaConversationsPage;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:google_fonts/google_fonts.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '/backend/backend.dart';
import '/sales/sales_home_widget.dart';
import '/backend/acquisition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase();
  // Module commercial : code reçu à l'installation (sans attendre).
  KitungaAcquisition.start();

  // Données de formatage des dates en français (voir dateTimeFormat).
  await initializeDateFormatting('fr');

  await FlutterFlowTheme.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _MyAppState extends State<MyApp> {
  // Mode clair par défaut ; le mode sombre s'active depuis le menu latéral
  // et le choix est mémorisé.
  ThemeMode _themeMode = FlutterFlowTheme.themeMode == ThemeMode.system
      ? ThemeMode.light
      : FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.path;
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  final authUserSub = authenticatedUserStream.listen((_) {});

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = kitungaFirebaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  @override
  void dispose() {
    authUserSub.cancel();

    super.dispose();
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Kitunga | Marketplace',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr', ''), Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

class NavBarPage extends StatefulWidget {
  NavBarPage({
    Key? key,
    this.initialPage,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  }) : super(key: key);

  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

/// This is the private State class that goes with NavBarPage.
class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'Home';
  late Widget? _currentPage;

  // Rôle relu dans Firestore : un compte Commercial a son propre accueil.
  late final Stream<String> _role = FirebaseAuth.instance
      .authStateChanges()
      .switchMap<String>((user) => user == null
          ? Stream.value('')
          : UserRecord.getDocument(UserRecord.collection.doc(user.uid))
              .map((u) => u.role)
              .handleError((_) {}));

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required int currentIndex,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required VoidCallback onTap,
  }) {
    final isSelected = index == currentIndex;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isSelected)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: Color(0xFFE51A1A),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Icon(
                activeIcon,
                color: Colors.white,
                size: 20.0,
              ),
            )
          else
            Container(
              height: 30.0,
              alignment: Alignment.center,
              child: Icon(
                inactiveIcon,
                color: Color(0xFF1E242B),
                size: 22.0,
              ),
            ),
          SizedBox(height: 2.0),
          Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Color(0xFFE51A1A) : Color(0xFF1E242B),
              fontSize: 11.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.0),
          if (isSelected)
            Container(
              width: 30.0,
              height: 2.0,
              decoration: BoxDecoration(
                color: Color(0xFFE51A1A),
                borderRadius: BorderRadius.circular(2.0),
              ),
            )
          else
            SizedBox(height: 2.0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _role,
      builder: (context, snapshot) => snapshot.data == 'Commercial'
          ? const SalesHomeWidget()
          : _buildTabs(context, deliverer: snapshot.data == 'Deliver'),
    );
  }

  Widget _buildTabs(BuildContext context, {bool deliverer = false}) {
    // Livreur : Accueil, Mes courses, Carte, Messages, Profil.
    final items = deliverer
        ? const [
            ('Home', 'Accueil', Icons.home_rounded, Icons.home_outlined),
            ('Order', 'Courses', Icons.two_wheeler_rounded,
                Icons.two_wheeler_outlined),
            ('Map', 'Carte', Icons.map_rounded, Icons.map_outlined),
            ('Messages', 'Messages', Icons.forum_rounded,
                Icons.forum_outlined),
            ('Profile', 'Profil', Icons.person_rounded,
                Icons.person_outline_rounded),
          ]
        : const [
            ('Home', 'Accueil', Icons.home_rounded, Icons.home_outlined),
            ('Order', 'Commandes', Icons.shopping_bag_rounded,
                Icons.shopping_bag_outlined),
            ('Profile', 'Profil', Icons.person_rounded,
                Icons.person_outline_rounded),
          ];
    final tabs = <String, Widget>{
      'Home': HomeWidget(),
      'Order': deliverer ? const KitungaDelivererCourses() : OrderWidget(),
      if (deliverer) 'Map': const KitungaDelivererMap(),
      if (deliverer) 'Messages': const KitungaConversationsPage(),
      'Profile': ProfileWidget(),
    };
    final keys = items.map((i) => i.$1).toList();
    final currentIndex = keys.indexOf(_currentPageName);

    return Scaffold(
      resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
      body: _currentPage ?? tabs[_currentPageName] ?? tabs['Home'],
      bottomNavigationBar: Visibility(
        visible: responsiveVisibility(
          context: context,
          tabletLandscape: false,
          desktop: false,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16.0,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: deliverer ? 6.0 : 20.0, vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (!deliverer && items[i].$1 == 'Profile')
                      Container(
                        width: 1.0,
                        height: 26.0,
                        color: Color(0xFFE5E7EB),
                      ),
                    _buildNavItem(
                      context: context,
                      index: i,
                      currentIndex: currentIndex,
                      label: items[i].$2,
                      activeIcon: items[i].$3,
                      inactiveIcon: items[i].$4,
                      onTap: () => safeSetState(() {
                        _currentPage = null;
                        _currentPageName = items[i].$1;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
