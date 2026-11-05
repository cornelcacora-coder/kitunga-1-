import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Administration : commerces et produits sans image, à faire compléter
/// par les commerçants.
class NOCMissingImagesWidget extends StatefulWidget {
  const NOCMissingImagesWidget({super.key});

  @override
  State<NOCMissingImagesWidget> createState() => _NOCMissingImagesWidgetState();
}

class _NOCMissingImagesWidgetState extends State<NOCMissingImagesWidget> {
  late final Stream<List<UserRecord>> _sellers = queryUserRecord(
    queryBuilder: (q) => q.where('role', isEqualTo: 'Seller'),
  );
  late final Stream<List<ProductRecord>> _products = queryProductRecord();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 720.0,
      ),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: StreamBuilder<List<UserRecord>>(
        stream: _sellers,
        builder: (context, sellerSnap) => StreamBuilder<List<ProductRecord>>(
          stream: _products,
          builder: (context, productSnap) {
            if (!sellerSnap.hasData || !productSnap.hasData) {
              return SizedBox(
                height: 200.0,
                child: Center(
                    child: CircularProgressIndicator(color: theme.primary)),
              );
            }
            final sellers = sellerSnap.data!;
            final byRef = {for (final s in sellers) s.reference.path: s};
            final shops = sellers
                .where((s) =>
                    s.photoUrl.trim().isEmpty || s.businessCover.trim().isEmpty)
                .toList();
            final products = productSnap.data!
                .where((p) => p.prodImg.trim().isEmpty)
                .toList();

            return ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 32.0),
              children: [
                Text(
                  'Images à compléter',
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 22.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.0),
                Text(
                  'Commerces et produits sans image : à faire compléter par les commerçants pour une vitrine professionnelle.',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 13.5),
                ),
                _title(theme, 'Commerces', shops.length),
                if (shops.isEmpty) _ok(theme),
                for (final s in shops)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipOval(
                      child: KitungaImage(s.photoUrl,
                          width: 44.0,
                          height: 44.0,
                          fallbackIcon: Icons.storefront_rounded),
                    ),
                    title: Text(s.displayName,
                        style: GoogleFonts.inter(
                            color: theme.primaryText,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        if (s.photoUrl.trim().isEmpty) 'logo manquant',
                        if (s.businessCover.trim().isEmpty)
                          'couverture manquante',
                        if (s.phoneNumber.isNotEmpty) s.phoneNumber,
                      ].join(' · '),
                      style: GoogleFonts.inter(
                          color: theme.primary, fontSize: 12.5),
                    ),
                  ),
                _title(theme, 'Produits sans photo', products.length),
                if (products.isEmpty) _ok(theme),
                for (final p in products)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: theme.primaryBackground,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Icon(Icons.image_not_supported_outlined,
                          color: theme.secondaryText),
                    ),
                    title: Text(p.name,
                        style: GoogleFonts.inter(
                            color: theme.primaryText,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      byRef[p.sellerRef?.path]?.displayName ??
                          'Commerce inconnu',
                      style: GoogleFonts.inter(
                          color: theme.secondaryText, fontSize: 12.5),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _title(FlutterFlowTheme theme, String text, int count) => Padding(
        padding: EdgeInsets.only(top: 24.0, bottom: 4.0),
        child: Text(
          '$text ($count)',
          style: GoogleFonts.interTight(
            color: theme.primaryText,
            fontSize: 17.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _ok(FlutterFlowTheme theme) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Tout est complet.',
            style: GoogleFonts.inter(color: Color(0xFF1E9E5A))),
      );
}
