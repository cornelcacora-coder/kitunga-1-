import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/backend/server_payment.dart';

/// Catégories de commerce de l'application, gérées par l'admin (page
/// /categories). Lues par la fonction kitungaPublicCategories ; tant qu'elles
/// ne sont pas chargées (ou hors connexion), ce sont les 5 d'origine.
typedef KitungaCategory = ({String name, String image, Color pastel});

/// Catégories d'origine, incluses dans l'application.
const kitungaDefaultCategories = <KitungaCategory>[
  (
    name: 'Boutique',
    image: 'assets/images/categories/boutique.png',
    pastel: Color(0xFFFFE4E1),
  ),
  (
    name: 'Restaurant',
    image: 'assets/images/categories/restaurant.png',
    pastel: Color(0xFFFFEBD6),
  ),
  (
    name: 'Pharmacie',
    image: 'assets/images/categories/pharmacie.png',
    pastel: Color(0xFFE2F5E9),
  ),
  (
    name: 'Magasin',
    image: 'assets/images/categories/magasin.png',
    pastel: Color(0xFFE2EDFB),
  ),
  (
    name: 'Fast Food',
    image: 'assets/images/categories/fastfood.png',
    pastel: Color(0xFFFFF3D1),
  ),
];

/// Conversion d'une catégorie reçue du serveur (null si inutilisable).
KitungaCategory? kitungaCategoryFromServer(Map<String, dynamic> m) {
  final name = (m['name'] as String? ?? '').trim();
  if (name.isEmpty) return null;
  var image = (m['image'] as String? ?? '').trim();
  // Image incluse dans l'application : « asset:assets/… ».
  if (image.startsWith('asset:')) image = image.substring(6);
  final hex = (m['color'] as String? ?? '').replaceFirst('#', '');
  final n = int.tryParse(hex, radix: 16);
  return (
    name: name,
    image: image,
    pastel: hex.length == 6 && n != null
        ? Color(0xFF000000 | n)
        : const Color(0xFFF2F2F5),
  );
}

class KitungaCategoryStore extends ChangeNotifier {
  KitungaCategoryStore._();

  static final instance = KitungaCategoryStore._();

  /// Remplace le serveur dans les tests.
  @visibleForTesting
  static Future<Map<String, dynamic>> Function()? fetchOverride;

  List<KitungaCategory> _list = kitungaDefaultCategories;
  DateTime? _lastTry;
  bool _loading = false;
  bool _loaded = false;

  /// Liste actuelle ; lance le chargement au premier appel (puis au plus une
  /// tentative par minute tant qu'il échoue, et une mise à jour par heure).
  List<KitungaCategory> get list {
    _refreshIfNeeded();
    return _list;
  }

  void _refreshIfNeeded() {
    final now = DateTime.now();
    final wait =
        _loaded ? const Duration(hours: 1) : const Duration(minutes: 1);
    if (_loading || (_lastTry != null && now.difference(_lastTry!) < wait)) {
      return;
    }
    _lastTry = now;
    _loading = true;
    // Après la construction en cours (notifyListeners pendant un build).
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final res = await (fetchOverride?.call() ??
          kitungaCallFunction('kitungaPublicCategories', const {}));
      final parsed = [
        for (final c in (res['categories'] as List? ?? const []))
          if (c is Map) kitungaCategoryFromServer(Map<String, dynamic>.from(c)),
      ].whereType<KitungaCategory>().toList();
      if (parsed.isNotEmpty) {
        _list = List.unmodifiable(parsed);
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {
      // Hors connexion ou non connecté : on garde la liste actuelle.
    } finally {
      _loading = false;
    }
  }

  /// Rechargement immédiat (ex. tirer pour actualiser).
  Future<void> reload() {
    _lastTry = DateTime.now();
    _loading = true;
    return _load();
  }

  @visibleForTesting
  void resetForTest() {
    _list = kitungaDefaultCategories;
    _lastTry = null;
    _loading = false;
    _loaded = false;
  }
}

/// Image d'une catégorie : incluse dans l'application ou en ligne.
class KitungaCategoryImage extends StatelessWidget {
  const KitungaCategoryImage(this.image, {super.key});

  final String image;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.storefront_outlined, color: Color(0xFF8A8F98));
    if (image.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: image,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => fallback,
      );
    }
    if (image.isEmpty) return fallback;
    return Image.asset(image,
        fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
  }
}

/// Commerce désactivé par l'admin (« Supprimer ») : masqué de l'application.
bool kitungaShopIsActive(UserRecord u) =>
    u.snapshotData['account_status'] != 'suspended';

/// Commerces désactivés, pour retirer leurs produits des listes publiques.
/// (Le filtre sur le rôle est exigé par les règles Firestore.)
Stream<Set<String>> kitungaSuspendedShopPaths() => queryUserRecord(
      queryBuilder: (q) => q
          .where('role', isEqualTo: 'Seller')
          .where('account_status', isEqualTo: 'suspended'),
    ).map((l) => {for (final u in l) u.reference.path});
