#!/usr/bin/env bash
# Installe (ou remplace) les clés MTN MoMo dans le coffre-fort de Firebase
# (Secret Manager), puis remet en ligne les fonctions de paiement pour
# qu'elles utilisent les nouvelles valeurs. Les clés ne sont JAMAIS écrites
# dans le code ni dans un fichier : vous les collez quand on vous les demande.
#
# Correspondance avec le courrier de MTN :
#   MOMO_COLLECTION_USER         = COLLECTION « API user »
#   MOMO_COLLECTION_KEY          = COLLECTION « API key »
#   MOMO_COLLECTION_SUBSCRIPTION = COLLECTION « Clé primaire »
#   MOMO_DISBURSEMENT_USER         = DISBURSEMENT « API user »
#   MOMO_DISBURSEMENT_KEY          = DISBURSEMENT « API key »
#   MOMO_DISBURSEMENT_SUBSCRIPTION = DISBURSEMENT « Clé primaire »
# (les clés secondaires ne servent qu'en secours, si la primaire est changée).
set -e
cd "$(dirname "$0")/../firebase"
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
ACC="--account ntemoconsultingntemoconsulting@gmail.com"
for S in MOMO_COLLECTION_USER MOMO_COLLECTION_KEY MOMO_COLLECTION_SUBSCRIPTION \
         MOMO_DISBURSEMENT_USER MOMO_DISBURSEMENT_KEY MOMO_DISBURSEMENT_SUBSCRIPTION; do
  echo
  echo "=== $S : collez la valeur puis Entrée (elle ne s'affiche pas)"
  firebase functions:secrets:set "$S" -P kitunga-xtvpe4 $ACC
done
F=functions:functions
firebase deploy --only "$F:kitungaStartPayment,$F:kitungaConfirmPayment,$F:kitungaStartSubscription,$F:kitungaConfirmSubscription,$F:kitungaReconcilePayments,$F:kitungaRefundOrder" \
  -P kitunga-xtvpe4 $ACC --non-interactive
echo "OK — les paiements et remboursements utilisent les nouvelles clés MTN."
