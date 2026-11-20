/// Cuisines des restaurants et plats courants, pour aider le commerçant à
/// remplir son menu (suggestions) et le client à trouver un restaurant
/// (filtre « Cuisine »). Le commerçant peut toujours saisir ses propres plats.
library;

/// Rubriques de menu proposées aux restaurants.
const kRestaurantSections = [
  'Entrées',
  'Plats africains',
  'Plats d\'ailleurs',
  'Grillades',
  'Poissons',
  'Accompagnements',
  'Sauces',
  'Desserts',
  'Boissons',
  'Petit-déjeuner',
  'Menus & formules',
];

typedef KitungaDish = ({String name, String section});

KitungaDish _d(String name, [String section = 'Plats africains']) =>
    (name: name, section: section);

/// Cuisines (ordre d'affichage) et leurs plats courants.
final Map<String, List<KitungaDish>> kCuisineDishes = {
  'Congolaise (Brazzaville)': [
    _d('Saka-saka (feuilles de manioc)'),
    _d('Saka-saka au poisson salé'),
    _d('Poulet à la moambé'),
    _d('Liboké de poisson'),
    _d('Maboké de poisson'),
    _d('Poisson salé aux aubergines'),
    _d('Poisson d\'eau douce'),
    _d('Bouillon sauvage'),
    _d('Bouillon de poisson'),
    _d('Mbika (pâte de graines de courge)'),
    _d('Ngoulou (porc) braisé', 'Grillades'),
    _d('Ntaba (chèvre braisée)', 'Grillades'),
    _d('Mosseka', 'Grillades'),
    _d('Soupe de porc'),
    _d('Légumes verts + poisson'),
    _d('Ngaï-ngaï (oseille)'),
    _d('Chikwangue', 'Accompagnements'),
    _d('Foufou', 'Accompagnements'),
    _d('Bananes plantains frites', 'Accompagnements'),
    _d('Manioc', 'Accompagnements'),
    _d('Mikaté (beignets)', 'Petit-déjeuner'),
  ],
  'Congolaise (RDC)': [
    _d('Pondu'),
    _d('Fumbwa'),
    _d('Makayabu (poisson salé)'),
    _d('Liboké'),
    _d('Poulet moambé'),
    _d('Ntaba', 'Grillades'),
    _d('Kwanga', 'Accompagnements'),
    _d('Fufu', 'Accompagnements'),
    _d('Makemba (bananes plantains)', 'Accompagnements'),
  ],
  'Angolaise': [
    _d('Muamba de galinha (poulet à la moambé)'),
    _d('Calulu de poisson'),
    _d('Mufete (poisson grillé)', 'Grillades'),
    _d('Kizaca (feuilles de manioc)'),
    _d('Feijão de óleo de palma (haricots)'),
    _d('Caldeirada de cabrito (chèvre)'),
    _d('Cabidela de galinha'),
    _d('Funje', 'Accompagnements'),
  ],
  'Camerounaise': [
    _d('Ndolé'),
    _d('Poulet DG'),
    _d('Eru'),
    _d('Koki'),
    _d('Mbongo tchobi'),
    _d('Okok'),
    _d('Taro sauce jaune'),
    _d('Soya (brochettes)', 'Grillades'),
    _d('Poisson braisé', 'Grillades'),
    _d('Beignets haricots', 'Petit-déjeuner'),
  ],
  'Gabonaise': [
    _d('Poulet nyembwé'),
    _d('Sauce odika'),
    _d('Feuilles de manioc'),
    _d('Bâton de manioc', 'Accompagnements'),
  ],
  'Ivoirienne': [
    _d('Attiéké poisson'),
    _d('Attiéké poulet'),
    _d('Garba'),
    _d('Kedjenou de poulet'),
    _d('Sauce graine'),
    _d('Placali'),
    _d('Alloco', 'Accompagnements'),
    _d('Foutou banane', 'Accompagnements'),
  ],
  'Sénégalaise': [
    _d('Thiéboudienne (tchiep) poisson'),
    _d('Tchiep poulet'),
    _d('Yassa poulet'),
    _d('Mafé'),
    _d('Thiéré'),
    _d('Domoda'),
    _d('Pastels', 'Entrées'),
    _d('Fataya', 'Entrées'),
  ],
  'Malienne': [
    _d('Riz gras'),
    _d('Tiguadèguèna (mafé)'),
    _d('Fakoye'),
    _d('Tô', 'Accompagnements'),
  ],
  'Nigériane': [
    _d('Jollof rice'),
    _d('Egusi soup'),
    _d('Pepper soup'),
    _d('Moi-moi'),
    _d('Suya', 'Grillades'),
    _d('Pounded yam', 'Accompagnements'),
  ],
  'Ghanéenne': [
    _d('Waakye'),
    _d('Banku et tilapia'),
    _d('Kenkey'),
    _d('Kelewele', 'Accompagnements'),
  ],
  'Togolaise / Béninoise': [
    _d('Pâte rouge (amiwo)'),
    _d('Gboma dessi'),
    _d('Akassa', 'Accompagnements'),
  ],
  'Éthiopienne': [
    _d('Doro wat', 'Plats d\'ailleurs'),
    _d('Tibs', 'Plats d\'ailleurs'),
    _d('Injera', 'Accompagnements'),
  ],
  'Maghrébine': [
    _d('Couscous poulet', 'Plats d\'ailleurs'),
    _d('Couscous viande', 'Plats d\'ailleurs'),
    _d('Couscous royal', 'Plats d\'ailleurs'),
    _d('Tajine de poulet', 'Plats d\'ailleurs'),
    _d('Pastilla', 'Plats d\'ailleurs'),
    _d('Harira', 'Entrées'),
    _d('Brochettes kefta', 'Grillades'),
  ],
  'Libanaise': [
    _d('Chawarma poulet', 'Plats d\'ailleurs'),
    _d('Chawarma viande', 'Plats d\'ailleurs'),
    _d('Falafel', 'Plats d\'ailleurs'),
    _d('Houmous', 'Entrées'),
    _d('Taboulé', 'Entrées'),
    _d('Kebbé', 'Entrées'),
  ],
  'Française': [
    _d('Steak frites', 'Plats d\'ailleurs'),
    _d('Poulet rôti', 'Plats d\'ailleurs'),
    _d('Croque-monsieur', 'Plats d\'ailleurs'),
    _d('Quiche lorraine', 'Plats d\'ailleurs'),
    _d('Salade niçoise', 'Entrées'),
    _d('Omelette', 'Petit-déjeuner'),
    _d('Crêpes', 'Desserts'),
  ],
  'Italienne': [
    _d('Pizza margherita', 'Plats d\'ailleurs'),
    _d('Pizza reine', 'Plats d\'ailleurs'),
    _d('Spaghetti bolognaise', 'Plats d\'ailleurs'),
    _d('Pâtes carbonara', 'Plats d\'ailleurs'),
    _d('Lasagnes', 'Plats d\'ailleurs'),
    _d('Tiramisu', 'Desserts'),
  ],
  'Portugaise': [
    _d('Bacalhau (morue)', 'Plats d\'ailleurs'),
    _d('Frango piri-piri', 'Grillades'),
    _d('Pastel de nata', 'Desserts'),
  ],
  'Américaine (fast-food)': [
    _d('Burger', 'Plats d\'ailleurs'),
    _d('Cheeseburger', 'Plats d\'ailleurs'),
    _d('Burrito bowl au poulet', 'Plats d\'ailleurs'),
    _d('Burrito bowl au bœuf', 'Plats d\'ailleurs'),
    _d('Hot-dog', 'Plats d\'ailleurs'),
    _d('Poulet frit', 'Plats d\'ailleurs'),
    _d('Nuggets', 'Plats d\'ailleurs'),
    _d('Wrap au poulet', 'Plats d\'ailleurs'),
    _d('Frites', 'Accompagnements'),
  ],
  'Mexicaine': [
    _d('Tacos', 'Plats d\'ailleurs'),
    _d('Burrito', 'Plats d\'ailleurs'),
    _d('Quesadilla', 'Plats d\'ailleurs'),
    _d('Chili con carne', 'Plats d\'ailleurs'),
  ],
  'Chinoise': [
    _d('Riz cantonais', 'Plats d\'ailleurs'),
    _d('Nouilles sautées', 'Plats d\'ailleurs'),
    _d('Bœuf aux oignons à la chinoise', 'Plats d\'ailleurs'),
    _d('Poulet aux oignons à la chinoise', 'Plats d\'ailleurs'),
    _d('Porc aigre-doux', 'Plats d\'ailleurs'),
    _d('Nems', 'Entrées'),
  ],
  'Japonaise': [
    _d('Sushis', 'Plats d\'ailleurs'),
    _d('Makis', 'Plats d\'ailleurs'),
    _d('Ramen', 'Plats d\'ailleurs'),
  ],
  'Indienne': [
    _d('Poulet tikka masala', 'Plats d\'ailleurs'),
    _d('Butter chicken', 'Plats d\'ailleurs'),
    _d('Biryani', 'Plats d\'ailleurs'),
    _d('Samoussas', 'Entrées'),
    _d('Naan', 'Accompagnements'),
  ],
  'Turque': [
    _d('Kebab', 'Plats d\'ailleurs'),
    _d('Döner', 'Plats d\'ailleurs'),
  ],
  'Grillades & braisés': [
    _d('Cuisse / aile de poulet', 'Grillades'),
    _d('Poulet braisé', 'Grillades'),
    _d('Demi-poulet', 'Grillades'),
    _d('Côtes de porc', 'Grillades'),
    _d('Brochette de bœuf', 'Grillades'),
    _d('Brochette de poulet', 'Grillades'),
    _d('Saucisse', 'Grillades'),
    _d('Chèvre braisée', 'Grillades'),
    _d('Poisson braisé', 'Grillades'),
  ],
  'Poissons & fruits de mer': [
    _d('Capitaine braisé', 'Poissons'),
    _d('Tilapia braisé', 'Poissons'),
    _d('Bar braisé', 'Poissons'),
    _d('Crevettes sautées', 'Poissons'),
    _d('Gambas grillées', 'Poissons'),
  ],
  'Végétarienne': [
    _d('Salade composée', 'Entrées'),
    _d('Légumes sautés', 'Plats d\'ailleurs'),
    _d('Haricots en sauce'),
  ],
  'Petit-déjeuner': [
    _d('Omelette', 'Petit-déjeuner'),
    _d('Pain beurre', 'Petit-déjeuner'),
    _d('Croissant', 'Petit-déjeuner'),
    _d('Beignets', 'Petit-déjeuner'),
    _d('Bouillie', 'Petit-déjeuner'),
    _d('Café', 'Boissons'),
    _d('Thé', 'Boissons'),
    _d('Chocolat chaud', 'Boissons'),
  ],
  'Pâtisserie & desserts': [
    _d('Gâteau', 'Desserts'),
    _d('Salade de fruits', 'Desserts'),
    _d('Glace', 'Desserts'),
    _d('Crêpes', 'Desserts'),
    _d('Beignets sucrés', 'Desserts'),
  ],
};

/// Accompagnements courants (produits à part et option des plats).
const kCommonSides = [
  'Riz blanc',
  'Riz gras',
  'Riz aux petits légumes',
  'Bananes plantains',
  'Frites',
  'Manioc',
  'Chikwangue',
  'Foufou',
  'Attiéké',
  'Pâtes',
  'Légumes verts',
  'Petits pois',
  'Sauce aux champignons',
];

/// Boissons courantes.
const kCommonDrinks = [
  'Eau minérale',
  'Jus de bissap',
  'Jus de gingembre',
  'Jus d\'ananas',
  'Jus de baobab (bouye)',
  'Soda',
  'Café',
  'Thé',
];

/// Toutes les cuisines, dans l'ordre d'affichage.
List<String> get kCuisines => kCuisineDishes.keys.toList();

/// Catégories de commerce qui ont des cuisines (restaurants).
bool hasCuisines(String category) =>
    category == 'Restaurant' || category == 'Fast Food';

/// Texte comparable : minuscules, sans accents.
String _norm(String v) => v
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('œ', 'oe');

/// Suggestions de plats pour une saisie : d'abord les cuisines du
/// restaurant, puis les autres ; sans doublon ; au plus [limit].
List<KitungaDish> dishSuggestions(String query,
    {List<String> cuisines = const [], int limit = 8}) {
  final q = _norm(query.trim());
  if (q.length < 2) return const [];
  final ordered = [
    for (final c in cuisines)
      if (kCuisineDishes.containsKey(c)) c,
    for (final c in kCuisineDishes.keys)
      if (!cuisines.contains(c)) c,
  ];
  final seen = <String>{};
  final out = <KitungaDish>[];
  for (final c in ordered) {
    for (final d in kCuisineDishes[c]!) {
      if (!_norm(d.name).contains(q) || !seen.add(_norm(d.name))) continue;
      out.add(d);
      if (out.length >= limit) return out;
    }
  }
  for (final s in [...kCommonSides, ...kCommonDrinks]) {
    if (out.length >= limit) break;
    if (_norm(s).contains(q) && seen.add(_norm(s))) {
      out.add((
        name: s,
        section: kCommonDrinks.contains(s) ? 'Boissons' : 'Accompagnements',
      ));
    }
  }
  return out;
}
