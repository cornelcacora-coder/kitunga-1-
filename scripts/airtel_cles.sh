#!/usr/bin/env bash
# Installe (ou remplace) les clés Airtel Money dans le coffre-fort de
# Firebase (Secret Manager), puis remet en ligne les fonctions de paiement.
# Les clés ne sont JAMAIS écrites dans le code ni dans un fichier : vous les
# collez quand on vous les demande (elles ne s'affichent pas).
#
# Correspondance avec le portail Airtel Africa (developers.airtel.africa,
# application de production, pays Congo « CG ») :
#   AIRTEL_CLIENT_ID     = « Client ID »
#   AIRTEL_CLIENT_SECRET = « Client Secret »
#
# Pas encore de compte marchand Airtel ? Tapez  absent  pour les deux :
# le reste fonctionne, et le client qui choisit Airtel Money est invité à
# payer avec MTN MoMo. Relancez ce script quand vous aurez les vraies clés.
set -e
cd "$(dirname "$0")/../firebase"
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
ACC="--account ntemoconsultingntemoconsulting@gmail.com"
for S in AIRTEL_CLIENT_ID AIRTEL_CLIENT_SECRET; do
  echo
  echo "=== $S : collez la valeur (ou absent) puis Entrée"
  firebase functions:secrets:set "$S" -P kitunga-xtvpe4 $ACC
done
F=functions:functions
firebase deploy --only "$F:kitungaStartPayment,$F:kitungaConfirmPayment,$F:kitungaStartSubscription,$F:kitungaConfirmSubscription,$F:kitungaReconcilePayments,$F:kitungaRefundOrder" \
  -P kitunga-xtvpe4 $ACC --non-interactive
echo "OK — les paiements utilisent les clés Airtel Money."
