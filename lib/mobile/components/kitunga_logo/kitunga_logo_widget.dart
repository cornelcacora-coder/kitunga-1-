import 'package:flutter/material.dart';

/// Logo Kitunga complet (panier + « KITUNGA »), posé directement sur la page,
/// sans cadre ni fond.
class KitungaLogo extends StatelessWidget {
  const KitungaLogo({super.key, this.size = 40.0});

  /// Hauteur du logo.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/kitunga_logo.png',
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
