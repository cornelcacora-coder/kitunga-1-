import '/flutter_flow/flutter_flow_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Image robuste : image de l'application (« assets/… ») ou image distante
/// qui passe par le cache, et si le cache échoue,
/// retente un chargement direct avant d'afficher l'icône de remplacement.
/// Chaque échec est noté dans le journal avec sa cause.
class KitungaImage extends StatelessWidget {
  const KitungaImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fallbackIcon = Icons.image_not_supported_outlined,
    this.placeholder,
  });

  final String url;
  final double? width;
  final double? height;
  final IconData fallbackIcon;

  /// Affiché à la place de l'icône quand il n'y a pas d'image.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final src = url.trim();
    Widget box({Widget? child}) => Container(
          width: width,
          height: height,
          color: theme.primaryBackground,
          alignment: Alignment.center,
          child: child,
        );
    final missing = placeholder ??
        box(child: Icon(fallbackIcon, color: theme.secondaryText, size: 28.0));

    // Image fournie avec l'application (assets/…).
    if (src.startsWith('assets/')) {
      return Image.asset(src,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => missing);
    }
    if (src.isEmpty || !src.startsWith('http')) {
      if (src.isNotEmpty) debugPrint('Adresse d\'image invalide : "$src"');
      return missing;
    }
    return CachedNetworkImage(
      imageUrl: src,
      width: width,
      height: height,
      fit: BoxFit.cover,
      fadeInDuration: Duration(milliseconds: 250),
      placeholder: (_, __) => box(),
      errorWidget: (_, __, cacheError) {
        debugPrint('Image (cache) en échec : $src → $cacheError');
        // Second essai sans le cache.
        return Image.network(
          src,
          width: width,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : box(),
          errorBuilder: (_, directError, __) {
            debugPrint('Image (direct) en échec : $src → $directError');
            return missing;
          },
        );
      },
    );
  }
}
