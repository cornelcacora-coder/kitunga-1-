import 'package:flutter/services.dart' show rootBundle;

import '/auth/firebase_auth/auth_util.dart' show currentUserUid;
import '/backend/firebase_storage/storage.dart';

/// Premiers restaurants partenaires de Kitunga : fiches prêtes à l'emploi
/// dans « Nouveau commerce ». L'admin saisit seulement l'email et le mot de
/// passe du compte ; logo, couverture, cuisines, présentation et menu sont
/// ajoutés automatiquement.
class LaunchPartner {
  const LaunchPartner({
    required this.name,
    required this.logoAsset,
    required this.coverAsset,
    required this.cuisines,
    required this.bio,
    this.phone = '',
    this.hours = '',
    this.menu = '',
    this.menuDraft = false,
  });

  final String name;
  final String logoAsset;
  final String coverAsset;
  final List<String> cuisines;
  final String bio;
  final String phone;
  final String hours;

  /// Menu à importer (format de « Importer un menu »).
  final String menu;

  /// Prix à confirmer : plats importés en brouillon (invisibles des clients
  /// jusqu'à leur publication par le restaurant ou l'admin).
  final bool menuDraft;
}

const kLaunchPartners = [
  LaunchPartner(
    name: 'Le Crisp\'nCroc',
    logoAsset: 'assets/images/partners/crispncroc.png',
    coverAsset: 'assets/images/partners/crispncroc_cover.jpg',
    cuisines: [
      'Congolaise (Brazzaville)',
      'Grillades & braisés',
      'Maghrébine',
      'Chinoise',
      'Mexicaine',
    ],
    bio: 'Plats africains, grillades et plats d\'ailleurs : saka-saka, '
        'tchiep, attiéké, brochettes, couscous, burrito bowls… '
        'Accompagnements à 500 F.',
    menu: _crispMenu,
  ),
  LaunchPartner(
    name: 'Zone de Confort',
    logoAsset: 'assets/images/partners/zone_de_confort.png',
    coverAsset: 'assets/images/partners/zone_de_confort_cover.jpg',
    cuisines: ['Congolaise (Brazzaville)', 'Grillades & braisés'],
    phone: '065376382',
    bio: 'Ne t\'inquiète plus pour ton midi, on s\'en occupe ! Plats '
        'africains à partir de 1500 F, tu manges comme à la maison. '
        'Livraison partout à Brazzaville. 39 rue des Cheminots, Ouenzé '
        '(vers Général Ndeguet). WhatsApp : 06 793 23 29 · '
        'Portable : 06 537 63 82.',
    // Plats de l'affiche, « à partir de 1500 frs » : prix à confirmer.
    menu: _zoneMenu,
    menuDraft: true,
  ),
];

/// Tests : remplace l'envoi des images.
Future<String?> Function(String asset)? launchLogoUploadOverride;

/// Envoie une image intégrée à l'application dans Firebase Storage.
Future<String?> uploadLaunchImage(String asset) async {
  if (launchLogoUploadOverride != null) return launchLogoUploadOverride!(asset);
  final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
  final ext = asset.split('.').last;
  return uploadData(
      'users/$currentUserUid/uploads/${DateTime.now().microsecondsSinceEpoch}.$ext',
      bytes);
}

const _zoneMenu = '''
NOS PLATS AFRICAINS
Ragoût de bœuf et riz ....... 1500 FCFA
Saka-saka au poisson ....... 1500 FCFA
Haricots ....... 1500 FCFA
Poulet braisé ....... 1500 FCFA
''';

const _crispMenu = '''
NOS PLATS AFRICAINS
Poisson salé aux aubergines ....... 2500 FCFA
Poisson d'eau douce ....... 3000 FCFA
Tchiep poisson/poulet ....... 2000 FCFA
Saka-saka avec poissons salé ....... 2500 FCFA
Attiéké poisson/poulet ....... 2000 FCFA
Bouillon sauvage ....... 2500 FCFA
Légumes vert + poisson ....... 3500 FCFA
Soupe de Porc ....... 2500 FCFA

NOS GRILLADES
Cuisse/Aile de poulet ....... 2000 FCFA
Côtes ....... 2000 FCFA
Poulet doux 1/2 ....... 2000 FCFA
Saucisse ....... 1000 FCFA
Brochette de bœuf ....... 2500 FCFA
Brochette de poulet ....... 2000 FCFA
Mosseka ....... 2000 FCFA
Ngoulou (porc) braisé ....... 2000 FCFA

NOS PLATS D'AILLEURS
Couscous poulet ....... 2000 FCFA
Couscous viande ....... 2500 FCFA
Couscous royal ....... 3000 FCFA
Ragoût de bœuf ....... 2500 FCFA
Bœuf/poulet aux oignons à la chinoise ....... 2000 FCFA
Burrito bowl au poulet ....... 2000 FCFA
Burrito bowl au bœuf ....... 2000 FCFA

NOS ACCOMPAGNEMENTS
Riz aux petits légumes ....... 500 FCFA
Riz gras ....... 500 FCFA
Bananes ....... 500 FCFA
Frites ....... 500 FCFA
Sauce aux champignons ....... 500 FCFA
Petits pois ....... 500 FCFA
Légumes vert ....... 500 FCFA
''';
