/// Réglages de l'espace vendeur selon l'activité du commerce.
library;

/// Nom donné au classement des produits.
String sellerSectionLabel(String category) => switch (category) {
      'Restaurant' || 'Fast Food' => 'Rubrique du menu',
      'Magasin' => 'Rayon',
      'Pharmacie' => 'Catégorie de produit',
      _ => 'Catégorie',
    };

/// Pluriel du classement (titres de pages).
String sellerSectionsTitle(String category) => switch (category) {
      'Restaurant' || 'Fast Food' => 'Rubriques du menu',
      'Magasin' => 'Rayons',
      _ => 'Catégories de produits',
    };

/// Suggestions proposées au vendeur (il peut saisir les siennes).
List<String> sellerSectionSuggestions(String category) => switch (category) {
      'Restaurant' => [
          'Entrées',
          'Plats principaux',
          'Grillades',
          'Accompagnements',
          'Desserts',
          'Boissons',
        ],
      'Fast Food' => [
          'Menus',
          'Burgers',
          'Pizzas',
          'Sandwichs',
          'Poulet',
          'Accompagnements',
          'Sauces',
          'Boissons',
        ],
      'Magasin' => [
          'Épicerie',
          'Boissons',
          'Produits frais',
          'Hygiène',
          'Entretien',
        ],
      'Pharmacie' => [
          'Médicaments',
          'Hygiène',
          'Soins',
          'Bébé',
          'Matériel médical',
        ],
      _ => ['Vêtements', 'Chaussures', 'Accessoires', 'Beauté'],
    };

/// Unités de vente (magasins et pharmacies).
const sellerUnits = ['pièce', 'kg', 'g', 'litre', 'paquet', 'carton', 'boîte'];

/// L'unité de vente est utile pour ces activités.
bool sellerUsesUnits(String category) =>
    category == 'Magasin' || category == 'Pharmacie';

/// Libellé du produit selon l'activité.
String sellerItemLabel(String category) => switch (category) {
      'Restaurant' => 'plat',
      'Fast Food' => 'produit ou menu',
      'Pharmacie' => 'produit',
      'Magasin' => 'article',
      _ => 'produit',
    };
