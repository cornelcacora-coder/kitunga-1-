/// Options d'un produit : groupes (Taille, Accompagnement, Suppléments…)
/// contenant des choix, avec supplément de prix et stock facultatifs.
///
/// Stocké dans le champ « options » du produit, sous forme de liste de
/// cartes : compatible avec les produits existants (champ absent = aucune
/// option).
library;

class KitungaOptionChoice {
  KitungaOptionChoice({required this.label, this.price = 0, this.stock});

  String label;

  /// Supplément ajouté au prix du produit (0 = inclus).
  int price;

  /// Stock propre à ce choix (variante). Nul : non suivi.
  int? stock;

  bool get soldOut => stock != null && stock! <= 0;

  Map<String, dynamic> toMap() => {
        'label': label,
        'price': price,
        if (stock != null) 'stock': stock,
      };

  static KitungaOptionChoice fromMap(Map m) => KitungaOptionChoice(
        label: '${m['label'] ?? ''}',
        price: (m['price'] as num?)?.round() ?? 0,
        stock: (m['stock'] as num?)?.round(),
      );
}

class KitungaOptionGroup {
  KitungaOptionGroup({
    required this.name,
    this.required = false,
    this.max = 1,
    List<KitungaOptionChoice>? choices,
  }) : choices = choices ?? [];

  String name;

  /// Le client doit choisir au moins une option.
  bool required;

  /// Nombre maximal de choix (1 = un seul choix, 0 = sans limite).
  int max;

  List<KitungaOptionChoice> choices;

  bool get single => max == 1;

  /// Règle affichée au client : « Obligatoire · 1 choix », « Jusqu'à 3 »…
  String get rule {
    final parts = <String>[required ? 'Obligatoire' : 'Facultatif'];
    if (single) {
      parts.add('1 choix');
    } else if (max > 1) {
      parts.add('jusqu\'à $max choix');
    } else {
      parts.add('plusieurs choix');
    }
    return parts.join(' · ');
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'required': required,
        'max': max,
        'choices': choices.map((c) => c.toMap()).toList(),
      };

  static KitungaOptionGroup fromMap(Map m) => KitungaOptionGroup(
        name: '${m['name'] ?? ''}',
        required: m['required'] == true,
        max: (m['max'] as num?)?.round() ?? 1,
        choices: ((m['choices'] as List?) ?? [])
            .whereType<Map>()
            .map(KitungaOptionChoice.fromMap)
            .where((c) => c.label.trim().isNotEmpty)
            .toList(),
      );

  KitungaOptionGroup copy() => fromMap(toMap());
}

List<KitungaOptionGroup> parseOptionGroups(List? raw) => (raw ?? [])
    .whereType<Map>()
    .map(KitungaOptionGroup.fromMap)
    .where((g) => g.name.trim().isNotEmpty && g.choices.isNotEmpty)
    .toList();

List<Map<String, dynamic>> encodeOptionGroups(List<KitungaOptionGroup> groups) =>
    groups.map((g) => g.toMap()).toList();

/// Sélection du client : pour chaque groupe (par index), les choix retenus.
typedef KitungaSelection = Map<int, Set<int>>;

/// Groupes obligatoires sans choix (vide = sélection valide).
List<String> missingRequired(
        List<KitungaOptionGroup> groups, KitungaSelection selection) =>
    [
      for (var i = 0; i < groups.length; i++)
        if (groups[i].required && (selection[i]?.isEmpty ?? true))
          groups[i].name,
    ];

/// Prix unitaire : prix de base + suppléments des choix retenus.
int unitPriceWithOptions(int basePrice, List<KitungaOptionGroup> groups,
    KitungaSelection selection) {
  var total = basePrice;
  selection.forEach((g, choices) {
    for (final c in choices) {
      total += groups[g].choices[c].price;
    }
  });
  return total;
}

/// Résumé conservé dans le panier et la commande :
/// « Taille : M · Suppléments : Fromage, Œuf ».
String selectionSummary(
    List<KitungaOptionGroup> groups, KitungaSelection selection) {
  final parts = <String>[];
  for (var i = 0; i < groups.length; i++) {
    final chosen = (selection[i] ?? <int>{}).toList()..sort();
    if (chosen.isEmpty) continue;
    parts.add(
        '${groups[i].name} : ${chosen.map((c) => groups[i].choices[c].label).join(', ')}');
  }
  return parts.join(' · ');
}
