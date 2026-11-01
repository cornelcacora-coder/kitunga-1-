import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Abonnement client : payé par MTN MoMo sur la page web Kitunga, activé
/// par le serveur (User.subscribe_close_at). Seuls les clients (rôle User)
/// doivent être abonnés pour commander.
bool kitungaSubscriptionActive() {
  final until = currentUserDocument?.subscribeCloseAt;
  return until != null && until.isAfter(DateTime.now());
}

bool kitungaCanOrder() {
  if (currentUserReference == null) return false;
  final role = valueOrDefault(currentUserDocument?.role, 'User');
  if (role == 'Guest') return false;
  return role != 'User' || kitungaSubscriptionActive();
}

/// Message affiché à un client sans abonnement actif. Aucun lien vers la
/// page de paiement : Google Play l'interdit pour un service numérique.
const kitungaSubscriptionRequired =
    'Un abonnement Kitunga actif est nécessaire pour commander '
    '(Mensuel 250 F, Trimestriel 500 F ou Annuel 1000 F).';
