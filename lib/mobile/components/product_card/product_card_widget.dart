import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couleur associée à un type de commerce (pastilles, tuiles).
Color kitungaCategoryColor(FlutterFlowTheme theme, String category) {
  switch (category) {
    case 'Restaurant':
      return Color(0xFFE8710A);
    case 'Fast Food':
      return Color(0xFFD99A00);
    case 'Pharmacie':
      return Color(0xFF1E9E5A);
    case 'Magasin':
      return Color(0xFF2F6FDE);
    default:
      return theme.primary;
  }
}

/// Icône associée à un type de commerce.
IconData kitungaCategoryIcon(String category) {
  switch (category) {
    case 'Restaurant':
      return Icons.restaurant_rounded;
    case 'Fast Food':
      return Icons.fastfood_rounded;
    case 'Pharmacie':
      return Icons.local_pharmacy_rounded;
    case 'Magasin':
      return Icons.local_grocery_store_rounded;
    default:
      return Icons.checkroom_rounded;
  }
}

/// Prix au format local : 12 500 F.
String kitungaPrice(num value) {
  final digits = value.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(' ');
    b.write(digits[i]);
  }
  return '$b F';
}

/// Carte produit (accueil, page d'un commerce) : photo, badge express,
/// étiquette ou stock bas, nom, prix et bouton +.
class KitungaProductCard extends StatelessWidget {
  const KitungaProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final ProductRecord product;
  final VoidCallback onTap;

  /// Hauteur conseillée d'une cellule de grille.
  static const double gridExtent = 252.0;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = product;
    final outOfStock = p.quantity <= 0;
    // Médicament sur ordonnance : commandable avec une ordonnance validée
    // (étiquette mise en évidence, carte non grisée).
    final prescription = p.requiresPrescription;
    final blocked = outOfStock;
    final lowStock = p.quantity > 0 && p.quantity <= 5;
    final label = prescription
        ? 'Sur ordonnance'
        : outOfStock
            ? 'Rupture de stock'
            : lowStock
                ? 'Plus que ${p.quantity} en stock'
                : p.specifications;
    final highlight = blocked || lowStock || prescription;

    return Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(18.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.0),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: theme.divider),
          ),
          padding: EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.0),
                    child: Container(
                      width: double.infinity,
                      height: 130.0,
                      color: theme.primaryBackground,
                      child: KitungaImage(
                        p.prodImg,
                        width: double.infinity,
                        height: 130.0,
                        fallbackIcon: Icons.image_outlined,
                        placeholder: kitungaNoPhoto(theme, p, 130.0),
                      ),
                    ),
                  ),
                  if (p.instantDisponibilty && !blocked)
                    Positioned(
                      left: 8.0,
                      top: 8.0,
                      child: Container(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(8.0, 3.0, 8.0, 3.0),
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: Colors.white, size: 14.0),
                            Text(
                              'Express',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8.0),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  label.isNotEmpty ? label : ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: highlight ? theme.primary : theme.secondaryText,
                    fontSize: 11.0,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 2.0),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              Spacer(),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 0.0, 0.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        kitungaPrice(p.salePrice > 0 ? p.salePrice : p.price) +
                            (p.unit.isNotEmpty && p.unit != 'pièce'
                                ? ' / ${p.unit}'
                                : ''),
                        style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 34.0,
                      height: 34.0,
                      decoration: BoxDecoration(
                        color: blocked ? theme.divider : theme.primary,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(
                          prescription
                              ? Icons.lock_outline_rounded
                              : Icons.add_rounded,
                          color: blocked ? theme.secondaryText : Colors.white,
                          size: 22.0),
                    ),
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

/// Ligne produit (menus de restaurant, fast-food, pharmacie) : nom,
/// description, prix et statut à gauche, photo et bouton + à droite.
class KitungaProductRow extends StatelessWidget {
  const KitungaProductRow({
    super.key,
    required this.product,
    required this.onTap,
  });

  final ProductRecord product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = product;
    final outOfStock = p.quantity <= 0;
    final blocked = outOfStock;
    final status = p.requiresPrescription
        ? 'Sur ordonnance'
        : outOfStock
            ? 'Indisponible'
            : '';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.interTight(
                      color: blocked ? theme.secondaryText : theme.primaryText,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.description.trim().isNotEmpty) ...[
                    SizedBox(height: 4.0),
                    Text(
                      p.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme.secondaryText,
                        fontSize: 13.0,
                        height: 1.35,
                      ),
                    ),
                  ],
                  SizedBox(height: 8.0),
                  Row(
                    children: [
                      Text(
                        kitungaPrice(p.salePrice > 0 ? p.salePrice : p.price) +
                            (p.unit.isNotEmpty && p.unit != 'pièce'
                                ? ' / ${p.unit}'
                                : ''),
                        style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (status.isNotEmpty) ...[
                        SizedBox(width: 10.0),
                        Text(
                          status,
                          style: GoogleFonts.inter(
                            color: theme.primary,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (p.instantDisponibilty) ...[
                        SizedBox(width: 10.0),
                        Icon(Icons.bolt_rounded,
                            size: 15.0, color: theme.primary),
                        Text(
                          'Express',
                          style: GoogleFonts.inter(
                            color: theme.primary,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 14.0),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.0),
                  child: Opacity(
                    opacity: blocked ? 0.55 : 1.0,
                    child: KitungaImage(
                      p.prodImg,
                      width: 96.0,
                      height: 96.0,
                      fallbackIcon: Icons.image_outlined,
                      // Ligne : largeur fixe (sinon largeur infinie).
                      placeholder: kitungaNoPhoto(theme, p, 96.0, width: 96.0),
                    ),
                  ),
                ),
                Positioned(
                  right: -6.0,
                  bottom: -6.0,
                  child: Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      color: blocked ? theme.divider : theme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.secondaryBackground, width: 2.0),
                    ),
                    child: Icon(
                      p.requiresPrescription
                          ? Icons.lock_outline_rounded
                          : Icons.add_rounded,
                      size: 18.0,
                      color: blocked ? theme.secondaryText : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Visible par les clients : publié par le vendeur. Les anciens produits
/// sans le champ « on_sale » restent visibles.
bool kitungaIsPublished(ProductRecord p) => !p.hasOnSale() || p.onSale;

/// Vignette d'un produit sans photo (plats de restaurant notamment) :
/// fond chaud, icône de la rubrique et nom du produit.
/// [width] : largeur de la vignette ; null = toute la largeur disponible
/// (cartes de la grille). Dans une ligne, passer une largeur fixe.
Widget kitungaNoPhoto(FlutterFlowTheme theme, ProductRecord p, double size,
    {double? width}) {
  final section = p.section.toLowerCase();
  final icon = section.contains('boisson')
      ? Icons.local_drink_rounded
      : section.contains('dessert')
          ? Icons.icecream_rounded
          : section.contains('grill')
              ? Icons.outdoor_grill_rounded
              : section.contains('accompagnement')
                  ? Icons.rice_bowl_rounded
                  : section.contains('petit')
                      ? Icons.free_breakfast_rounded
                      : Icons.restaurant_menu_rounded;
  return Container(
    width: width ?? double.infinity,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF1E6), Color(0xFFFFE0D2)],
      ),
    ),
    padding: EdgeInsets.all(size > 100 ? 12.0 : 6.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFFE8710A), size: size * 0.32),
        if (size > 100) ...[
          const SizedBox(height: 6.0),
          Text(p.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.interTight(
                  color: const Color(0xFF8A4A12),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700)),
        ],
      ],
    ),
  );
}
