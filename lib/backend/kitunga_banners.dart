import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart'
    show openKitungaProduct;
import '/mobile/main_app/home/home_sections.dart' show openKitungaCategory;

/// Publicités et promotions du carrousel d'accueil, gérées par l'admin
/// (page /publicites). Lues par la fonction kitungaPublicBanners ; tant
/// qu'elles ne sont pas chargées (ou hors connexion), ce sont les 3 bannières
/// d'origine de l'application.
typedef KitungaBanner = ({
  String id,
  String kind, // app : promotion Kitunga · seller : publicité d'un commerce
  String title1,
  String title2,
  String subtitle,
  String button,
  String badge,
  String image, // assets/… ou https://…
  Color color,
  Color accent,
  String targetType, // shops, category, shop, product, url, none
  String targetValue,
});

KitungaBanner _default(int i, String image, String t1, String t2, String s) =>
    (
      id: 'default-$i',
      kind: 'app',
      title1: t1,
      title2: t2,
      subtitle: s,
      button: 'Découvrir',
      badge: '',
      image: image,
      color: const Color(0xFFE51A1A),
      accent: const Color(0xFFFFD200),
      targetType: 'shops',
      targetValue: '',
    );

/// Bannières d'origine, incluses dans l'application.
final kitungaDefaultBanners = <KitungaBanner>[
  _default(0, 'assets/images/Girl_Bag2.jpg', 'Tout au même', 'endroit',
      'Boutiques, restaurants\net pharmacies'),
  _default(1, 'assets/images/youngAfrican.jpg', 'Livraison', 'rapide',
      'Recevez vos commandes\nà domicile'),
  _default(2, 'assets/images/Gemini_Generated_Image_xb96ubxb96ubxb96.png',
      'Produits', 'frais', 'Alimentation, marché\net épicerie'),
];

Color _color(Object? raw, Color fallback) {
  final hex = '${raw ?? ''}'.replaceFirst('#', '');
  final n = int.tryParse(hex, radix: 16);
  return hex.length == 6 && n != null ? Color(0xFF000000 | n) : fallback;
}

/// Conversion d'une bannière reçue du serveur (null si inutilisable).
KitungaBanner? kitungaBannerFromServer(Map<String, dynamic> m) {
  var image = '${m['image'] ?? ''}'.trim();
  if (image.startsWith('asset:')) image = image.substring(6);
  final t1 = '${m['title1'] ?? ''}'.trim();
  final t2 = '${m['title2'] ?? ''}'.trim();
  if (image.isEmpty || (t1.isEmpty && t2.isEmpty)) return null;
  final target = m['target'] is Map ? m['target'] as Map : const {};
  return (
    id: '${m['id'] ?? ''}',
    kind: '${m['kind'] ?? 'app'}',
    title1: t1,
    title2: t2,
    subtitle: '${m['subtitle'] ?? ''}',
    button: '${m['button'] ?? ''}'.trim().isEmpty
        ? 'Découvrir'
        : '${m['button']}'.trim(),
    badge: '${m['badge'] ?? ''}'.trim(),
    image: image,
    color: _color(m['color'], const Color(0xFFE51A1A)),
    accent: _color(m['accent'], const Color(0xFFFFD200)),
    targetType: '${target['type'] ?? 'shops'}',
    targetValue: '${target['value'] ?? ''}',
  );
}

class KitungaBannerStore extends ChangeNotifier {
  KitungaBannerStore._();
  static final instance = KitungaBannerStore._();

  /// Remplace le serveur dans les tests.
  @visibleForTesting
  static Future<Map<String, dynamic>> Function()? fetchOverride;

  List<KitungaBanner> _list = kitungaDefaultBanners;
  DateTime? _lastTry;
  bool _loading = false;
  bool _loaded = false;

  /// Bannières à diffuser ; chargement au premier appel, puis au plus une
  /// tentative par minute en cas d'échec et une mise à jour toutes les
  /// 15 minutes.
  List<KitungaBanner> get list {
    final now = DateTime.now();
    final wait =
        _loaded ? const Duration(minutes: 15) : const Duration(minutes: 1);
    if (!_loading && (_lastTry == null || now.difference(_lastTry!) > wait)) {
      _lastTry = now;
      _loading = true;
      Future.microtask(_load);
    }
    return _list;
  }

  Future<void> _load() async {
    try {
      final res = await (fetchOverride?.call() ??
          kitungaCallPublicFunction('kitungaPublicBanners', const {}));
      final raw = res['banners'];
      if (raw is List) {
        // Liste vide = l'admin a tout désactivé : plus de carrousel.
        _list = List.unmodifiable([
          for (final b in raw)
            if (b is Map) kitungaBannerFromServer(Map<String, dynamic>.from(b)),
        ].whereType<KitungaBanner>());
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {
      // Hors connexion : on garde les bannières actuelles.
    } finally {
      _loading = false;
    }
  }

  Future<void> reload() {
    _lastTry = DateTime.now();
    _loading = true;
    return _load();
  }

  @visibleForTesting
  void resetForTest() {
    _list = kitungaDefaultBanners;
    _lastTry = null;
    _loading = false;
    _loaded = false;
  }
}

/// Tests : remplace l'enregistrement d'un clic.
@visibleForTesting
void Function(String id)? bannerClickOverride;

/// Clic sur une bannière : statistique, puis destination choisie par l'admin.
Future<void> openKitungaBanner(BuildContext context, KitungaBanner b) async {
  if (bannerClickOverride != null) {
    bannerClickOverride!(b.id);
  } else if (!b.id.startsWith('default-')) {
    kitungaCallPublicFunction('kitungaBannerClick', {'id': b.id})
        .catchError((_) => <String, dynamic>{});
  }
  switch (b.targetType) {
    case 'none':
      return;
    case 'category':
      openKitungaCategory(context, b.targetValue);
    case 'shop':
      context.pushNamed(
        ShopDetailPageWidget.routeName,
        queryParameters: {
          'userRef': serializeParam(
              FirebaseFirestore.instance.doc('User/${b.targetValue}'),
              ParamType.DocumentReference),
          'isSameSeller': serializeParam(false, ParamType.bool),
        }.withoutNulls,
      );
    case 'product':
      try {
        final p = await ProductRecord.getDocumentOnce(
            FirebaseFirestore.instance.doc('Product/${b.targetValue}'));
        if (context.mounted) openKitungaProduct(context, p);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ce produit n\'est plus disponible.')));
        }
      }
    case 'url':
      await launchURL(b.targetValue);
    default:
      context.pushNamed(ShopsWidget.routeName);
  }
}

/// Image d'une bannière, cadrée à droite (le texte est à gauche).
class KitungaBannerImage extends StatelessWidget {
  const KitungaBannerImage(this.image, {super.key, this.color});

  final String image;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(color: color ?? const Color(0xFFE51A1A));
    if (image.startsWith('assets/')) {
      return Image.asset(image,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => fallback);
    }
    if (!image.startsWith('http')) return fallback;
    // Web : image affichée par le navigateur si le stockage refuse (CORS).
    if (kIsWeb) {
      return Image.network(image,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, __, ___) => fallback);
    }
    return CachedNetworkImage(
      imageUrl: getCORSProxyUrl(image),
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// Bannière telle qu'elle apparaît dans le carrousel d'accueil (aperçu des
/// publicités des vendeurs).
class KitungaBannerView extends StatelessWidget {
  const KitungaBannerView(this.b, {super.key, this.dim = false});

  final KitungaBanner b;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 355 / 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.0),
        child: Opacity(
          opacity: dim ? 0.5 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              KitungaBannerImage(b.image, color: b.color),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(b.color, Colors.black, 0.08)!,
                      b.color,
                      b.color.withValues(alpha: 0.92),
                      b.color.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.52, 0.70, 0.88],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 100.0, 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (b.badge.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4.0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7.0, vertical: 2.0),
                            decoration: BoxDecoration(
                                color: b.accent,
                                borderRadius: BorderRadius.circular(6.0)),
                            child: Text(b.badge,
                                style: TextStyle(
                                    color: b.color,
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w800)),
                          ),
                        if (b.title1.isNotEmpty)
                          Text(b.title1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19.0,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  height: 1.1)),
                        if (b.title2.isNotEmpty)
                          Text(b.title2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: b.accent,
                                  fontSize: 26.0,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  height: 1.0)),
                        const SizedBox(height: 4.0),
                        Text(b.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: 1.2)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 6.0),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.0)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.button,
                              style: TextStyle(
                                  color: b.color,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right_rounded,
                              color: b.color, size: 16.0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
