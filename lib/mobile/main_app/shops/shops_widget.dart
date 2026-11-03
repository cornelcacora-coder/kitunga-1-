import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/ads_comp/ads_comp_widget.dart';
import '/mobile/components/alert_info/alert_info_widget.dart';
import '/mobile/components/user_card/user_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import '/mobile/main_app/home/home_sections.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'shops_model.dart';
import '/mobile/components/form_styles/form_styles.dart';
export 'shops_model.dart';

/// Page d'inscription utilisateur
class ShopsWidget extends StatefulWidget {
  const ShopsWidget({
    super.key,
    this.tag,
  });

  final String? tag;

  static String routeName = 'Shops';
  static String routePath = '/shops';

  @override
  State<ShopsWidget> createState() => _ShopsWidgetState();
}

class _ShopsWidgetState extends State<ShopsWidget> {
  late ShopsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ShopsModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _query = '';
  String _filter = ''; // '', 'open', 'verified'
  late Stream<List<UserRecord>> _shops = _load();

  Stream<List<UserRecord>> _load() => queryUserRecord(
        queryBuilder: (q) => q
            .where('role', isEqualTo: 'Seller')
            .where('category', isEqualTo: widget!.tag),
      );

  String get _category => widget!.tag ?? 'Boutique';

  String get _plural => switch (_category) {
        'Restaurant' => 'Restaurants',
        'Pharmacie' => 'Pharmacies',
        'Magasin' => 'Magasins',
        'Fast Food' => 'Fast-foods',
        _ => 'Boutiques',
      };

  String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = kitungaCategories.firstWhere((c) => c.name == _category,
        orElse: () => kitungaCategories.first);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
      body: KitungaScaffoldBackground(
        child: SafeArea(
        child: StreamBuilder<List<UserRecord>>(
          stream: _shops,
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final q = _norm(_query.trim());
            final shown = all.where((s) {
              if (q.isNotEmpty &&
                  !_norm(s.displayName).contains(q) &&
                  !_norm(s.bio).contains(q)) {
                return false;
              }
              if (_filter == 'verified' && !s.verified) return false;
              if (_filter == 'open' &&
                  kitungaOpeningStatus(s.horraire)?.open != true) {
                return false;
              }
              return true;
            }).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: _header(
                        theme, cat.image, all.length, snapshot.hasData)),
                SliverToBoxAdapter(child: _searchAndFilters(theme)),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _message(
                      theme,
                      Icons.wifi_off_rounded,
                      'Impossible de charger les commerces',
                      'Vérifiez votre connexion internet puis réessayez.',
                      action: FilledButton.icon(
                        onPressed: () => setState(() => _shops = _load()),
                        style: FilledButton.styleFrom(
                            backgroundColor: theme.primary),
                        icon: Icon(Icons.refresh_rounded),
                        label: Text('Réessayer'),
                      ),
                    ),
                  )
                else if (!snapshot.hasData)
                  SliverList.list(
                    children: List.generate(
                      3,
                      (_) => Container(
                        height: 230.0,
                        margin: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
                        decoration: BoxDecoration(
                          color: theme.primaryBackground,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                    ),
                  )
                else if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: all.isEmpty
                        ? _message(
                            theme,
                            Icons.storefront_outlined,
                            'Aucun commerce pour le moment',
                            'Les ${_plural.toLowerCase()} arrivent bientôt sur Kitunga.')
                        : _message(
                            theme,
                            Icons.search_off_rounded,
                            'Aucun résultat',
                            'Modifiez votre recherche ou retirez le filtre.'),
                  )
                else
                  SliverList.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
                      child: _ShopCategoryCard(shop: shown[i]),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 24.0)),
              ],
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _header(FlutterFlowTheme theme, String image, int count, bool loaded) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 20.0, 4.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.safePop(),
            tooltip: 'Retour',
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryBackground,
              minimumSize: Size(44.0, 44.0),
            ),
            icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
          ),
          SizedBox(width: 12.0),
          Container(
            width: 44.0,
            height: 44.0,
            padding: EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: kitungaCategoryBackground(context, _category),
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Image.asset(image, fit: BoxFit.contain),
          ),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _plural,
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 21.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  !loaded
                      ? 'Chargement…'
                      : count == 0
                          ? 'Bientôt disponible'
                          : '$count commerce${count > 1 ? 's' : ''} sur Kitunga',
                  style: GoogleFonts.inter(
                    color: theme.secondaryText,
                    fontSize: 13.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilters(FlutterFlowTheme theme) {
    Widget chip(String label, String value, IconData icon) {
      final selected = _filter == value;
      return Padding(
        padding: EdgeInsetsDirectional.only(end: 8.0),
        child: ChoiceChip(
          avatar: value.isEmpty
              ? null
              : Icon(icon,
                  size: 16.0,
                  color: selected ? Colors.white : theme.secondaryText),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filter = value),
          labelStyle: GoogleFonts.inter(
            color: selected ? Colors.white : theme.primaryText,
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
          ),
          selectedColor: theme.primary,
          backgroundColor: theme.primaryBackground,
          side: BorderSide.none,
          shape: StadiumBorder(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 8.0),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
            decoration: InputDecoration(
              hintText: 'Rechercher un commerce ou une spécialité…',
              hintStyle:
                  GoogleFonts.inter(color: theme.secondaryText, fontSize: 15.0),
              prefixIcon:
                  Icon(Icons.search_rounded, color: theme.secondaryText),
              filled: true,
              fillColor: theme.primaryBackground,
              contentPadding: EdgeInsets.symmetric(vertical: 15.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48.0,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 4.0),
            children: [
              chip('Tous', '', Icons.apps_rounded),
              chip('Ouverts maintenant', 'open', Icons.schedule_rounded),
              chip('Certifiés', 'verified', Icons.verified_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _message(
      FlutterFlowTheme theme, IconData icon, String title, String text,
      {Widget? action}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48.0, color: theme.secondaryText),
            SizedBox(height: 12.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 17.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.0),
            Text(
              text,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(color: theme.secondaryText, fontSize: 14.0),
            ),
            if (action != null) ...[SizedBox(height: 16.0), action],
          ],
        ),
      ),
    );
  }
}

/// Carte d'un commerce dans la liste d'une catégorie : couverture avec
/// statut d'ouverture, logo, nom, spécialité et horaires.
class _ShopCategoryCard extends StatelessWidget {
  const _ShopCategoryCard({required this.shop});

  final UserRecord shop;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final s = shop;
    final status = kitungaOpeningStatus(s.horraire);
    final specialty = s.bio.trim();
    return Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(20.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.0),
        onTap: () => openKitungaShop(context, s),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: theme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.0)),
                    child: kitungaNetImage(
                      context,
                      s.businessCover.isNotEmpty ? s.businessCover : s.photoUrl,
                      width: double.infinity,
                      height: 140.0,
                      placeholder: kitungaShopPlaceholder(context, s,
                          width: double.infinity, height: 140.0, cover: true),
                    ),
                  ),
                  if (status != null)
                    Positioned(
                      top: 12.0,
                      left: 12.0,
                      child: Container(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            10.0, 4.0, 10.0, 4.0),
                        decoration: BoxDecoration(
                          color: status.open
                              ? Color(0xFF1E9E5A)
                              : Color(0xCC121212),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Text(
                          status.open ? 'Ouvert' : 'Fermé',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16.0,
                    bottom: -22.0,
                    child: Container(
                      padding: EdgeInsets.all(3.0),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: kitungaNetImage(context, s.photoUrl,
                            width: 48.0,
                            height: 48.0,
                            placeholder: kitungaShopPlaceholder(context, s,
                                width: 48.0, height: 48.0)),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 30.0, 16.0, 14.0),
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
                              fontSize: 17.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (s.verified)
                          Padding(
                            padding: EdgeInsetsDirectional.only(start: 5.0),
                            child: Icon(Icons.verified_rounded,
                                color: theme.primary, size: 18.0),
                          ),
                      ],
                    ),
                    if (specialty.isNotEmpty) ...[
                      SizedBox(height: 3.0),
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: theme.secondaryText,
                          fontSize: 13.0,
                        ),
                      ),
                    ],
                    if (s.horraire.trim().isNotEmpty) ...[
                      SizedBox(height: 8.0),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 15.0, color: theme.secondaryText),
                          SizedBox(width: 5.0),
                          Flexible(
                            child: Text(
                              status?.label ?? s.horraire.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: status?.open == true
                                    ? Color(0xFF1E9E5A)
                                    : theme.secondaryText,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
