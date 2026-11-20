import 'package:flutter_test/flutter_test.dart';
import 'package:kitunga/backend/kitunga_units.dart';

void main() {
  test('unités de vente selon l\'activité', () {
    expect(unitsFor('Restaurant').first, 'plat');
    expect(unitsFor('Restaurant'), containsAll(['portion', 'assiette', 'menu']));
    expect(unitsFor('Pharmacie'), containsAll(['boîte', 'plaquette', 'flacon']));
    expect(unitsFor('Boutique'), contains('paire'));
    expect(unitsFor('Magasin'), containsAll(['kg', 'litre', 'carton']));
    // Catégorie créée par l'admin : toutes les unités, sans doublon.
    final all = unitsFor('Boulangerie');
    expect(all.toSet().length, all.length);
    expect(all, containsAll(['plat', 'boîte', 'kg', 'paire']));
  });
}
