import '/backend/backend.dart' show ProductRecord;
import '/mobile/components/product_card/product_card_widget.dart'
    show kitungaNoPhoto;
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'my_products_card_model.dart';
export 'my_products_card_model.dart';

class MyProductsCardWidget extends StatefulWidget {
  const MyProductsCardWidget({
    super.key,
    String? title,
    int? price,
    String? cover,
    this.product,
  })  : this.title = title ?? 'Hamburger Royal',
        this.price = price ?? 0,
        this.cover = cover ??
            '';

  final String title;
  final int price;
  final String cover;

  /// Produit affiché : sert à la vignette quand il n'a pas de photo.
  final ProductRecord? product;

  @override
  State<MyProductsCardWidget> createState() => _MyProductsCardWidgetState();
}

class _MyProductsCardWidgetState extends State<MyProductsCardWidget> {
  late MyProductsCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MyProductsCardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: Container(
        width: 180.0,
        height: 200.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).lightGrey,
          boxShadow: [
            BoxShadow(
              blurRadius: 2.0,
              color: Color(0x1A000000),
              offset: Offset(
                0.0,
                1.0,
              ),
              spreadRadius: 0.0,
            )
          ],
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KitungaImage(
              getCORSProxyUrl(
                widget!.cover,
              ),
              width: double.infinity,
              height: 140.0,
              placeholder: widget.product == null
                  ? null
                  : kitungaNoPhoto(
                      FlutterFlowTheme.of(context), widget.product!, 140.0),
            ),
            Padding(
              padding: EdgeInsets.all(10.0),
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valueOrDefault<String>(
                        widget!.title,
                        'Hamburger Royal Hamburger Royal',
                      ),
                      maxLines: 1,
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.interTight(
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 14.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleMedium
                                .fontStyle,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget!.price.toString(),
                            '5000',
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyLarge.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).primary,
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .fontStyle,
                                  ),
                        ),
                        Text(
                          'F',
                          style:
                              FlutterFlowTheme.of(context).bodyLarge.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).primary,
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .fontStyle,
                                  ),
                        ),
                      ],
                    ),
                  ].divide(SizedBox(height: 4.0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
