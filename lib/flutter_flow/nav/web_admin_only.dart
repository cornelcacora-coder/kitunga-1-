import 'package:flutter/foundation.dart' show kDebugMode;

/// Le site web (kitunga.site) ne sert que l'administration : la partie client
/// est réservée à l'application mobile. Sur le web, toute adresse qui n'est pas
/// une page d'administration renvoie vers la connexion admin (/admin).
///
/// Ne s'applique qu'au web (voir createRouter) : l'application mobile n'est
/// pas concernée. La page de paiement d'abonnement (abonnement.html) et les
/// liens commerciaux (/r/…) sont servis par l'hébergement, hors application.
const kWebAdminHome = '/admin';

/// Aperçu de l'application mobile dans le navigateur, pour le développement :
/// actif quand on lance l'application en local (`flutter run -d chrome`) ou
/// avec `--dart-define=KITUNGA_MOBILE=true`. Le site en ligne (compilé en
/// release sans ce réglage) reste réservé à l'administration.
const kWebMobilePreview =
    kDebugMode || bool.fromEnvironment('KITUNGA_MOBILE');

/// Pages d'administration autorisées sur le web.
const _webAdminPaths = {
  '/admin',
  '/supervisionDashboard',
  '/commercial',
  '/gestion',
  '/categories',
  '/publicites',
  '/produits',
  '/commercants',
  '/livreurs',
  '/clients',
  '/commandes',
  '/livraisons',
  '/alertes',
  '/zones',
  '/tarif-livraison',
  '/forgotPassword',
  '/forgotPasswordLink',
};

/// Adresse à ouvrir à la place de [uri] sur le web, ou null si elle est permise.
String? webAdminRedirect(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (_webAdminPaths.contains(path)) return null;
  // Création d'un partenaire par l'admin (formulaire réservé, gardé par rôle).
  if (path == '/sign' && uri.queryParameters['accessibility'] == 'Admin') {
    return null;
  }
  // Logo et couverture d'un partenaire, juste après sa création.
  if (path == '/addProfile' &&
      (uri.queryParameters['partnerRef'] ?? '').isNotEmpty) {
    return null;
  }
  return kWebAdminHome;
}
