/// Réglages de l'espace vendeur selon l'activité du commerce.
library;

import '/backend/kitunga_units.dart';
import '/backend/kitunga_cuisines.dart';

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
      'Restaurant' => kRestaurantSections,
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
/// Unités de vente de l'activité (voir lib/backend/kitunga_units.dart).
List<String> sellerUnits(String category) => unitsFor(category);

/// L'unité de vente est proposée pour toutes les activités (plat, portion,
/// boîte, kg, paire…).
bool sellerUsesUnits(String category) => true;

/// Libellé du produit selon l'activité.
String sellerItemLabel(String category) => switch (category) {
      'Restaurant' => 'plat',
      'Fast Food' => 'produit ou menu',
      'Pharmacie' => 'produit',
      'Magasin' => 'article',
      _ => 'produit',
    };
