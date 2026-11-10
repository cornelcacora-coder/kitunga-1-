import '/backend/backend.dart';
import '/backend/kitunga_options.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/components/product_card/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Résultat de la personnalisation d'un produit avant l'ajout au panier.
typedef KitungaCustomization = ({
  String summary,
  int unitPrice,
  int quantity,
});

/// Fenêtre de personnalisation : options, suppléments, variantes, quantité.
/// Renvoie null si le client ferme sans ajouter.
Future<KitungaCustomization?> showKitungaCustomizeSheet(
    BuildContext context, ProductRecord product) {
  return showModalBottomSheet<KitungaCustomization>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomizeSheet(product: product),
  );
}

class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet({required this.product});

  final ProductRecord product;

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late final List<KitungaOptionGroup> _groups = widget.product.options;
  final KitungaSelection _selection = {};
  int _quantity = 1;

  int get _basePrice => widget.product.salePrice > 0
      ? widget.product.salePrice
      : widget.product.price.round();

  void _toggle(int g, int c) {
    final group = _groups[g];
    final chosen = _selection.putIfAbsent(g, () => <int>{});
    setState(() {
      if (group.single) {
        chosen
          ..clear()
          ..add(c);
      } else if (chosen.contains(c)) {
        chosen.remove(c);
      } else if (group.max == 0 || chosen.length < group.max) {
        chosen.add(c);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '« ${group.name} » : ${group.max} choix maximum.')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = widget.product;
    final missing = missingRequired(_groups, _selection);
    final unit = unitPriceWithOptions(_basePrice, _groups, _selection);
    // Quantité limitée par le stock du produit et des variantes choisies
    // (ex. plus que 2 en taille M).
    var maxQty = p.quantity > 0 ? p.quantity : 1;
    _selection.forEach((g, chosen) {
      for (final c in chosen) {
        final stock = _groups[g].choices[c].stock;
        if (stock != null && stock > 0 && stock < maxQty) maxQty = stock;
      }
    });
    if (_quantity > maxQty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _quantity > maxQty) setState(() => _quantity = maxQty);
      });
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.0),
            Container(
              width: 40.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: theme.divider,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14.0),
                        child:
                            KitungaImage(p.prodImg, width: 72.0, height: 72.0),
                      ),
                      SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: GoogleFonts.interTight(
                                color: theme.primaryText,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'À partir de ${kitungaPrice(_basePrice)}',
                              style: GoogleFonts.inter(
                                  color: theme.secondaryText, fontSize: 13.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  for (var g = 0; g < _groups.length; g++) _group(theme, g),
                  SizedBox(height: 20.0),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Quantité',
                          style: GoogleFonts.interTight(
                            color: theme.primaryText,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _qtyButton(theme, Icons.remove_rounded,
                          _quantity > 1 ? () => setState(() => _quantity--) : null),
                      SizedBox(
                        width: 44.0,
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.interTight(
                            color: theme.primaryText,
                            fontSize: 17.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _qtyButton(
                          theme,
                          Icons.add_rounded,
                          _quantity < maxQty
                              ? () => setState(() => _quantity++)
                              : null),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (missing.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'À choisir : ${missing.join(', ')}',
                          style: GoogleFonts.inter(
                              color: theme.primary, fontSize: 13.0),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 56.0,
                      child: ElevatedButton(
                        onPressed: missing.isNotEmpty
                            ? null
                            : () => Navigator.of(context).pop((
                                  summary:
                                      selectionSummary(_groups, _selection),
                                  unitPrice: unit,
                                  quantity: _quantity,
                                )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          disabledBackgroundColor: theme.divider,
                          foregroundColor: Colors.white,
                          elevation: 0.0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0)),
                        ),
                        child: Text(
                          'Ajouter au panier · ${kitungaPrice(unit * _quantity)}',
                          style: GoogleFonts.interTight(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(FlutterFlowTheme theme, int g) {
    final group = _groups[g];
    final chosen = _selection[g] ?? <int>{};
    return Padding(
      padding: EdgeInsets.only(top: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsetsDirectional.fromSTEB(8.0, 3.0, 8.0, 3.0),
                decoration: BoxDecoration(
                  color: group.required
                      ? theme.primary.withValues(alpha: 0.10)
                      : theme.primaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  group.rule,
                  style: GoogleFonts.inter(
                    color:
                        group.required ? theme.primary : theme.secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.0),
          for (var c = 0; c < group.choices.length; c++)
            _choice(theme, g, c, chosen.contains(c)),
        ],
      ),
    );
  }

  Widget _choice(FlutterFlowTheme theme, int g, int c, bool selected) {
    final group = _groups[g];
    final choice = group.choices[c];
    final disabled = choice.soldOut;
    return InkWell(
      borderRadius: BorderRadius.circular(12.0),
      onTap: disabled ? null : () => _toggle(g, c),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(
              group.single
                  ? (selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded)
                  : (selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded),
              color: disabled
                  ? theme.divider
                  : (selected ? theme.primary : theme.secondaryText),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Text(
                choice.label,
                style: GoogleFonts.inter(
                  color: disabled ? theme.secondaryText : theme.primaryText,
                  fontSize: 15.0,
                  decoration: disabled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              disabled
                  ? 'Épuisé'
                  : [
                      if (choice.stock != null && choice.stock! <= 5)
                        'Plus que ${choice.stock}',
                      choice.price > 0
                          ? '+${kitungaPrice(choice.price)}'
                          : 'Inclus',
                    ].join(' · '),
              style: GoogleFonts.inter(
                color: disabled ? theme.primary : theme.secondaryText,
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(
          FlutterFlowTheme theme, IconData icon, VoidCallback? onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        child: Container(
          width: 40.0,
          height: 40.0,
          decoration: BoxDecoration(
            color: theme.primaryBackground,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Icon(icon,
              color: onTap == null ? theme.divider : theme.primaryText),
        ),
      );
}
