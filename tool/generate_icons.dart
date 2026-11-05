import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  print('Chargement de assets/logo/LOGO-1.png...');
  final file = File('assets/logo/LOGO-1.png');
  if (!file.existsSync()) {
    print('Fichier introuvable : ${file.path}');
    return;
  }

  final bytes = file.readAsBytesSync();
  final original = img.decodeImage(bytes);
  if (original == null) {
    print('Impossible de décoder l\'image');
    return;
  }

  print('Original: ${original.width} x ${original.height}');

  // 1. Découpage automatique des marges transparentes éventuelles (crop)
  // pour s'assurer que le panier et le texte sont bien au centre
  final cropped = img.trim(original, mode: img.TrimMode.transparent);
  print('Après trim: ${cropped.width} x ${cropped.height}');

  // 2. Générer l'icône standard 1024x1024 sur fond blanc avec marge sécurisée (padding)
  // L'icône occupera environ 75% de la surface pour laisser une belle marge respirante
  final iconSize = 1024;
  final standardBg = img.Image(width: iconSize, height: iconSize, numChannels: 4);
  img.fill(standardBg, color: img.ColorRgba8(255, 255, 255, 255)); // Fond blanc

  // Calcul de la taille de destination en conservant l'aspect ratio
  final maxInnerSize = (iconSize * 0.78).round(); // ~800px
  double scale;
  if (cropped.width > cropped.height) {
    scale = maxInnerSize / cropped.width;
  } else {
    scale = maxInnerSize / cropped.height;
  }
  final targetW = (cropped.width * scale).round();
  final targetH = (cropped.height * scale).round();

  final scaledLogo = img.copyResize(cropped, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);

  final destX = ((iconSize - targetW) / 2).round();
  final destY = ((iconSize - targetH) / 2).round();

  img.compositeImage(standardBg, scaledLogo, dstX: destX, dstY: destY);

  final standardIconPath = 'assets/logo/app_icon_1024.png';
  File(standardIconPath).writeAsBytesSync(img.encodePng(standardBg));
  print('Généré : $standardIconPath');

  // 3. Générer l'icône Google Play Store 512x512 (exigence exacte du Play Store)
  final playStoreIcon = img.copyResize(standardBg, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  final playStoreIconPath = 'assets/logo/playstore_icon_512x512.png';
  File(playStoreIconPath).writeAsBytesSync(img.encodePng(playStoreIcon));
  print('Généré : $playStoreIconPath (pour la fiche Google Play Console)');

  // 4. Générer l'adaptive icon foreground (fond transparent, zone sécurisée ~66% pour cercle Android)
  final adaptiveForeground = img.Image(width: iconSize, height: iconSize, numChannels: 4);
  img.fill(adaptiveForeground, color: img.ColorRgba8(0, 0, 0, 0)); // Fond transparent

  // Android découpe l'icône (et l'écran de démarrage Android 12+) dans un
  // CERCLE dont la zone garantie fait 66dp sur 108dp (~61 %). On fait donc
  // tenir la diagonale du logo dans ce cercle, sinon les coins (le texte
  // « KITUNGA ») sont coupés.
  final adaptiveSafeDiameter = iconSize * 0.60; // 61 % moins une petite marge
  final adaptiveScale = adaptiveSafeDiameter /
      sqrt(cropped.width * cropped.width + cropped.height * cropped.height);
  final adaptiveW = (cropped.width * adaptiveScale).round();
  final adaptiveH = (cropped.height * adaptiveScale).round();
  final scaledAdaptiveLogo = img.copyResize(cropped, width: adaptiveW, height: adaptiveH, interpolation: img.Interpolation.cubic);

  final adaptiveX = ((iconSize - adaptiveW) / 2).round();
  final adaptiveY = ((iconSize - adaptiveH) / 2).round();

  img.compositeImage(adaptiveForeground, scaledAdaptiveLogo, dstX: adaptiveX, dstY: adaptiveY);

  final adaptiveForegroundPath = 'assets/logo/adaptive_foreground_1024.png';
  File(adaptiveForegroundPath).writeAsBytesSync(img.encodePng(adaptiveForeground));
  print('Généré : $adaptiveForegroundPath');

  print('Toutes les icônes sources ont été générées avec succès !');
}
