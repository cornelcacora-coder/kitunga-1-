import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Abonnement client : payé par MTN MoMo sur la page web Kitunga, activé
/// par le serveur (User.subscribe_close_at). Seuls les clients (rôle User)
/// doivent être abonnés pour commander.
bool kitungaSubscriptionActive() {
  final until = currentUserDocument?.subscribeCloseAt;
  return until != null && until.isAfter(DateTime.now());
}

/// Abonnement réel d'un utilisateur : seule la date de fin fait foi, comme
/// pour le droit de commander (pas is_subscribed ni la formule choisie).
bool kitungaUserSubscribed(UserRecord user) {
  final until = user.subscribeCloseAt;
  return until != null && until.isAfter(DateTime.now());
}

String kitungaSubscriptionLabel(UserRecord user) {
  if (!kitungaUserSubscribed(user)) return 'Sans abonnement';
  return user.subscribeType.isNotEmpty ? user.subscribeType : 'Abonné';
}

/// Rôles qui commandent sans abonnement : même liste que les règles
/// Firestore (canOrder) et le serveur (ROLES_WITHOUT_SUBSCRIPTION).
const kRolesWithoutSubscription = ['Seller', 'Deliver', 'Admin'];

bool kitungaCanOrder() {
  if (currentUserReference == null) return false;
  final role = valueOrDefault(currentUserDocument?.role, 'User');
  if (kRolesWithoutSubscription.contains(role)) return true;
  // Guest, Commercial ou rôle inconnu : pas de commande.
  return role == 'User' && kitungaSubscriptionActive();
}

/// Message affiché à un client sans abonnement actif. Aucun lien vers la
/// page de paiement : Google Play l'interdit pour un service numérique.
const kitungaSubscriptionRequired =
    'Un abonnement Kitunga actif est nécessaire pour commander '
    '(Mensuel 250 F, Trimestriel 500 F ou Annuel 1000 F).';
