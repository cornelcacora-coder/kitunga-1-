/// Unités de vente proposées selon l'activité du commerce. La première de
/// chaque liste est l'unité par défaut d'un nouveau produit. Le champ reste
/// libre : une unité absente de la liste peut être saisie.
const kUnitsByCategory = <String, List<String>>{
  'Restaurant': [
    'plat', 'portion', 'assiette', 'menu', 'demi (½)', 'entier', 'part',
    'pièce', 'brochette', 'barquette', 'bol', 'verre', 'bouteille',
    'canette', 'litre',
  ],
  'Fast Food': [
    'menu', 'pièce', 'portion', 'part', 'barquette', 'boîte', 'cornet',
    'gobelet', 'verre', 'bouteille', 'canette', 'litre',
  ],
  'Pharmacie': [
    'boîte', 'plaquette', 'comprimé', 'gélule', 'flacon', 'tube', 'sachet',
    'ampoule', 'pot', 'seringue', 'unité', 'ml',
  ],
  'Boutique': [
    'pièce', 'paire', 'ensemble', 'lot', 'unité', 'taille unique', 'mètre',
    'douzaine', 'paquet', 'boîte',
  ],
  'Magasin': [
    'pièce', 'kg', 'g', 'litre', 'cl', 'ml', 'paquet', 'carton', 'sac',
    'boîte', 'bouteille', 'canette', 'pack', 'lot', 'douzaine', 'botte',
    'régime', 'tas', 'seau', 'bidon',
  ],
};

/// Toutes les unités connues (catégorie inconnue ou nouvelle).
List<String> get kAllUnits => {
      for (final l in kUnitsByCategory.values) ...l,
    }.toList();

/// Unités proposées pour une catégorie de commerce.
List<String> unitsFor(String? category) =>
    kUnitsByCategory[category] ?? kAllUnits;
