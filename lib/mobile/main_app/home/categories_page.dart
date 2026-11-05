import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart';
import 'home_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// « Toutes les catégories » : recherche, grille des types de commerce avec
/// leur nombre réel de commerces, puis la liste des commerces disponibles.
class KitungaCategoriesPage extends StatefulWidget {
  const KitungaCategoriesPage({super.key});

  @override
  State<KitungaCategoriesPage> createState() => _KitungaCategoriesPageState();
}

class _KitungaCategoriesPageState extends State<KitungaCategoriesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  late Stream<List<UserRecord>> _sellers = _loadSellers();

  Stream<List<UserRecord>> _loadSellers() => queryUserRecord(
        queryBuilder: (q) => q.where('role', isEqualTo: 'Seller'),
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String v) => v
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .trim();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme),
            _searchBar(theme),
            Expanded(
              child: StreamBuilder<List<UserRecord>>(
                stream: _sellers,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _errorState(theme);
                  if (!snapshot.hasData) return _loadingState(theme);
                  return _content(theme, snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(FlutterFlowTheme theme) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 20.0, 4.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Retour',
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryBackground,
              minimumSize: Size(44.0, 44.0),
            ),
            icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
          ),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toutes les catégories',
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 21.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.0),
                Text(
                  'Découvrez les commerces et services disponibles',
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
        ],
      ),
    );
  }

  Widget _searchBar(FlutterFlowTheme theme) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 4.0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
        decoration: InputDecoration(
          hintText: 'Rechercher un commerce ou une catégorie…',
          hintStyle:
              GoogleFonts.inter(color: theme.secondaryText, fontSize: 15.0),
          prefixIcon: Icon(Icons.search_rounded, color: theme.secondaryText),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer',
                  icon: Icon(Icons.close_rounded, color: theme.secondaryText),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: theme.primaryBackground,
          contentPadding: EdgeInsets.symmetric(vertical: 15.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _content(FlutterFlowTheme theme, List<UserRecord> sellers) {
    final q = _normalize(_query);
    final categories = kitungaCategories
        .where((c) => q.isEmpty || _normalize(c.name).contains(q))
        .toList();
    final shops = sellers
        .where((s) =>
            q.isEmpty ||
            _normalize(s.displayName).contains(q) ||
            _normalize(s.category).contains(q))
        .toList();

    if (q.isNotEmpty && categories.isEmpty && shops.isEmpty) {
      return _message(
        theme,
        Icons.search_off_rounded,
        'Aucun résultat pour « ${_query.trim()} »',
        'Essayez un autre nom de commerce ou une catégorie.',
      );
    }

    return CustomScrollView(
      slivers: [
        if (categories.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: KitungaSectionHeader(
              title: q.isEmpty ? 'Catégories' : 'Catégories trouvées',
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                // 3 colonnes, 2 sur les écrans très étroits.
                final columns = constraints.crossAxisExtent < 300 ? 2 : 3;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12.0,
                    crossAxisSpacing: 12.0,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final c = categories[i];
                      final count =
                          sellers.where((s) => s.category == c.name).length;
                      return _CategoryCard(
                        name: c.name,
                        image: c.image,
                        count: count,
                      )
                          .animate()
                          .fadeIn(delay: (40 * i).ms, duration: 250.ms)
                          .moveY(begin: 8.0, end: 0.0, curve: Curves.easeOut);
                    },
                    childCount: categories.length,
                  ),
                );
              },
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: KitungaSectionHeader(
            title: q.isEmpty ? 'Commerces disponibles' : 'Commerces trouvés',
            subtitle: shops.isEmpty
                ? null
                : '${shops.length} commerce${shops.length > 1 ? 's' : ''} sur Kitunga',
          ),
        ),
        if (shops.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 24.0),
              child: Text(
                'Aucun commerce disponible pour le moment.',
                style: GoogleFonts.inter(
                    color: theme.secondaryText, fontSize: 14.0),
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: shops.length,
            itemBuilder: (context, i) => KitungaShopListTile(shop: shops[i]),
            separatorBuilder: (_, __) => Divider(
              height: 1.0,
              indent: 94.0,
              endIndent: 20.0,
              color: theme.divider,
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 24.0)),
      ],
    );
  }

  /// Chargement : cartes squelettes à l'emplacement des catégories.
  Widget _loadingState(FlutterFlowTheme theme) {
    return GridView.count(
      crossAxisCount: 3,
      padding: EdgeInsets.fromLTRB(20.0, 28.0, 20.0, 0.0),
      mainAxisSpacing: 12.0,
      crossAxisSpacing: 12.0,
      childAspectRatio: 0.82,
      physics: NeverScrollableScrollPhysics(),
      children: List.generate(
        6,
        (_) => Container(
          decoration: BoxDecoration(
            color: theme.primaryBackground,
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
      ),
    );
  }

  Widget _errorState(FlutterFlowTheme theme) {
    return _message(
      theme,
      Icons.wifi_off_rounded,
      'Impossible de charger les commerces',
      'Vérifiez votre connexion internet puis réessayez.',
      action: FilledButton.icon(
        onPressed: () => setState(() => _sellers = _loadSellers()),
        style: FilledButton.styleFrom(backgroundColor: theme.primary),
        icon: Icon(Icons.refresh_rounded),
        label: Text('Réessayer'),
      ),
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

/// Carte d'une catégorie : image sur fond pastel, nom et nombre réel de
/// commerces.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.name,
    required this.image,
    required this.count,
  });

  final String name;
  final String image;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: kitungaCategoryBackground(context, name),
      borderRadius: BorderRadius.circular(20.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.0),
        onTap: () => openKitungaCategory(context, name),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(10.0, 12.0, 10.0, 12.0),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Image.asset(image, fit: BoxFit.contain),
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.interTight(
                  color: theme.primaryText,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.0),
              Text(
                count == 0
                    ? 'Aucun commerce'
                    : '$count commerce${count > 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                  color: theme.secondaryText,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
