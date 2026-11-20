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
    bio: 'Tu manges comme à la maison ! Dès 10h30, nous vous livrons des '
        'plats savoureux, faits comme à la maison, partout à Brazzaville. '
        'Plats africains, grillades, liboké, bouillons. 39 rue des Cheminots, Ouenzé '
        '(vers Général Ndeguet). WhatsApp : 06 793 23 29 · '
        'Portable : 06 537 63 82.',
    hours: 'Tous les jours dès 10h30',
    // Menu complet de l'affiche « Notre Menu ».
    menu: _zoneMenu,
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
Poisson salé aux aubergines ....... 2500 FCFA
Ailes de poulet aux petits pois couscous ....... 2000 FCFA
Liboké de ndzombo oseille ....... 2500 FCFA
Poulet yassa riz blanc ....... 2000 FCFA
Corvina légumes verts ....... 2000 FCFA
Côtes pimentées ....... 2000 FCFA
Ngoki à la moambé ....... 2500 FCFA
Riz gras poulet bananes ....... 1500 FCFA
Ragoût viande couscous ....... 2500 FCFA
Poulet mayo ....... 2000 FCFA
Bouillon de côtes fumées épinards ....... 2000 FCFA
Liboké de silure ....... 2500 FCFA
Attiéké poisson ou poulet bananes ....... 1500 FCFA
Poulet aux courges ....... 2000 FCFA
Poisson fumé bouillon coco ....... 2500 FCFA
Queue de bœuf sautée ....... 2500 FCFA
Ailes de poulet sautées aubergines vertes ....... 2000 FCFA
Haricots blancs tripes ....... 2000 FCFA
Pâtes à la bolognaise ....... 1500 FCFA
Cuisses de poulet (3 pièces) épinards ou coco ....... 2000 FCFA

NOS GRILLADES
Côtes grillées ....... 1500 FCFA
Cuisses de poulet grillées ....... 1500 FCFA
Ailes de poulet grillées ....... 1500 FCFA
Poisson grillé ....... 1500 FCFA

AUTRES PLATS
Bouillon d'antilope ....... 2500 FCFA
Ngoulou mako ....... 2500 FCFA
Bouillon de mboto / mbessé ....... 2500 FCFA

NOS ACCOMPAGNEMENTS
Saka-saka ....... 1000 FCFA
Oseille ....... 500 FCFA
Frites ....... 500 FCFA
Bananes ....... 500 FCFA
Asperges ....... 1000 FCFA

EMBALLAGE
Barquette plastique ....... 200 FCFA
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
