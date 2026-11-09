import '/backend/backend.dart';
import '/backend/kitunga_hours.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ouvre la page d'un commerce.
void openKitungaShop(BuildContext context, UserRecord shop) {
  context.pushNamed(
    ShopDetailPageWidget.routeName,
    queryParameters: {
      'userRef': serializeParam(shop.reference, ParamType.DocumentReference),
      'isSameSeller': serializeParam(false, ParamType.bool),
    }.withoutNulls,
  );
}

/// Ouvre la fiche d'un produit.
void openKitungaProduct(BuildContext context, ProductRecord product) {
  context.pushNamed(
    ProductViewWidget.routeName,
    queryParameters: {
      'productRef':
          serializeParam(product.reference, ParamType.DocumentReference),
      'sellerRef':
          serializeParam(product.sellerRef, ParamType.DocumentReference),
      'isSameSeller': serializeParam(false, ParamType.bool),
    }.withoutNulls,
  );
}

/// Image distante : fond uni pendant le chargement, icône si absente.
Widget kitungaNetImage(
  BuildContext context,
  String url, {
  double? width,
  double? height,
  Widget? placeholder,
}) =>
    KitungaImage(url,
        width: width,
        height: height,
        fallbackIcon: Icons.storefront_rounded,
        placeholder: placeholder);

/// Initiales d'un commerce (2 lettres au plus) : « Mama Loboko » → « ML ».
String kitungaInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
  return letters.isEmpty ? 'K' : letters;
}

/// Visuel de remplacement d'un commerce sans image : dégradé dans la
/// couleur de sa catégorie, avec l'icône (couverture) ou les initiales (logo).
Widget kitungaShopPlaceholder(
  BuildContext context,
  UserRecord shop, {
  double? width,
  double? height,
  bool cover = false,
}) {
  final theme = FlutterFlowTheme.of(context);
  final color = kitungaCategoryColor(theme, shop.category);
  return Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, Colors.black, 0.3)!],
      ),
    ),
    child: cover
        ? Icon(kitungaCategoryIcon(shop.category),
            color: Color(0x40FFFFFF), size: 64.0)
        : Text(
            kitungaInitials(shop.displayName),
            style: GoogleFonts.interTight(
              color: Colors.white,
              fontSize: (height ?? 40.0) * 0.38,
              fontWeight: FontWeight.w800,
            ),
          ),
  );
}

/// Carte de commerce : couverture, logo à cheval, nom, badge, infos.
/// [width] nul : la carte prend toute la largeur (pages « Voir plus »).
class KitungaShopCard extends StatelessWidget {
  const KitungaShopCard({
    super.key,
    required this.shop,
    this.width = 230.0,
    this.coverHeight = 112.0,
  });

  final UserRecord shop;
  final double? width;
  final double coverHeight;

  /// Hauteur d'une rangée horizontale de ces cartes (couverture de 112).
  static const double rowHeight = 192.0;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final s = shop;
    // Restaurant : sa cuisine principale (« Congolaise ») plutôt que la
    // catégorie, quand elle est renseignée.
    final cuisines = (s.snapshotData['cuisines'] as List? ?? const []);
    final kind = cuisines.isNotEmpty
        ? 'Cuisine ${'${cuisines.first}'.split(' (').first.toLowerCase()}'
        : s.category;
    final subtitle =
        [kind, s.horraire].where((e) => e.trim().isNotEmpty).join(' · ');
    return SizedBox(
      width: width,
      child: Material(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.0),
          onTap: () => openKitungaShop(context, s),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
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
                          BorderRadius.vertical(top: Radius.circular(18.0)),
                      child: kitungaNetImage(
                        context,
                        s.businessCover.isNotEmpty
                            ? s.businessCover
                            : s.photoUrl,
                        width: width ?? double.infinity,
                        height: coverHeight,
                        placeholder: kitungaShopPlaceholder(context, s,
                            width: width ?? double.infinity,
                            height: coverHeight,
                            cover: true),
                      ),
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
                          child: kitungaNetImage(context, s.photoUrl,
                              width: 38.0,
                              height: 38.0,
                              placeholder: kitungaShopPlaceholder(context, s,
                                  width: 38.0, height: 38.0)),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(12.0, 24.0, 12.0, 12.0),
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
                          if (s.verified)
                            Padding(
                              padding: EdgeInsetsDirectional.only(start: 4.0),
                              child: Icon(Icons.verified_rounded,
                                  color: theme.primary, size: 16.0),
                            ),
                        ],
                      ),
                      SizedBox(height: 2.0),
                      Text(
                        subtitle,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Statut d'ouverture calculé à partir des horaires saisis par le commerçant
/// (« 8h - 18h », « 08h30 à 22h »…). Renvoie null si les horaires ne sont pas
/// exploitables : rien n'est alors affiché, plutôt qu'un statut inventé.
({bool open, String label})? kitungaOpeningStatus(String horaire,
    [DateTime? now]) {
  // Horaires du lundi au dimanche (« Lun-Ven 8h00-20h00 · Dim fermé »).
  final week = horaire.contains('·') ||
          horaire.toLowerCase().startsWith('tous les jours')
      ? parseWeek(horaire)
      : null;
  if (week != null) return weekStatus(week, now ?? DateTime.now());
  final m = RegExp(
          r'(\d{1,2})\s*[hH:]\s*(\d{2})?\s*(?:-|–|à|a)\s*(\d{1,2})\s*[hH:]\s*(\d{2})?')
      .firstMatch(horaire);
  if (m == null) return null;
  final open = int.parse(m[1]!) * 60 + int.parse(m[2] ?? '0');
  final close = int.parse(m[3]!) * 60 + int.parse(m[4] ?? '0');
  if (open >= 24 * 60 || close > 24 * 60 || open == close) return null;
  final t = now ?? DateTime.now();
  final current = t.hour * 60 + t.minute;
  // Horaires qui passent minuit (ex. 18h - 2h) gérés.
  final isOpen = open < close
      ? current >= open && current < close
      : current >= open || current < close;
  String fmt(int mins) =>
      '${mins ~/ 60}h${mins % 60 == 0 ? '' : (mins % 60).toString().padLeft(2, '0')}';
  return (
    open: isOpen,
    label: isOpen
        ? 'Ouvert · ferme à ${fmt(close)}'
        : 'Fermé · ouvre à ${fmt(open)}',
  );
}

/// Ligne de commerce (listes, résultats de recherche) : logo, nom, badge,
/// catégorie et statut d'ouverture réel.
class KitungaShopListTile extends StatelessWidget {
  const KitungaShopListTile({super.key, required this.shop});

  final UserRecord shop;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final s = shop;
    final status = kitungaOpeningStatus(s.horraire);
    final catColor = kitungaCategoryColor(theme, s.category);
    return InkWell(
      onTap: () => openKitungaShop(context, s),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: kitungaNetImage(
                context,
                s.photoUrl.isNotEmpty ? s.photoUrl : s.businessCover,
                width: 60.0,
                height: 60.0,
                placeholder: kitungaShopPlaceholder(context, s,
                    width: 60.0, height: 60.0),
              ),
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
                      if (s.verified)
                        Padding(
                          padding: EdgeInsetsDirectional.only(start: 4.0),
                          child: Icon(Icons.verified_rounded,
                              color: theme.primary, size: 16.0),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (s.category.isNotEmpty)
                        Text(
                          s.category,
                          style: GoogleFonts.inter(
                            color: catColor,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (status != null)
                        Text(
                          status.label,
                          style: GoogleFonts.inter(
                            color: status.open
                                ? Color(0xFF1E9E5A)
                                : theme.secondaryText,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
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
}


/// Bandeau du panier quand le commerce est fermé (le serveur refuse alors
/// le paiement) : le client le sait avant de payer.
class KitungaClosedNotice extends StatelessWidget {
  const KitungaClosedNotice({super.key, required this.sellerRef, this.now});

  final DocumentReference sellerRef;

  /// Tests : heure imposée.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<UserRecord>(
      stream: UserRecord.getDocument(sellerRef),
      builder: (context, snap) {
        final shop = snap.data;
        final status =
            shop == null ? null : kitungaOpeningStatus(shop.horraire, now);
        if (status == null || status.open) return const SizedBox.shrink();
        return KitungaClosedBanner(
            name: shop!.displayName, label: status.label, theme: theme);
      },
    );
  }
}

class KitungaClosedBanner extends StatelessWidget {
  const KitungaClosedBanner(
      {super.key, required this.name, required this.label, required this.theme});

  final String name;
  final String label;
  final FlutterFlowTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: theme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, color: theme.error),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              '${name.isEmpty ? 'Ce commerce' : name} est fermé en ce moment '
              '(${label.replaceFirst('Fermé · ', '')}). Votre panier est gardé : '
              'vous pourrez commander dès son ouverture.',
              style: GoogleFonts.inter(
                  color: theme.primaryText, fontSize: 13.0, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
