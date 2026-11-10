#!/usr/bin/env bash
# Corrige les 2 clés d'encaissement mal collées (COLLECTION « API user » et
# « API key »), puis remet en ligne les fonctions de paiement.
set -e
cd "$(dirname "$0")/../firebase"
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
ACC="--account ntemoconsultingntemoconsulting@gmail.com"
echo "=== MOMO_COLLECTION_USER : COLLECTION « API user » (36 caractères avec tirets, commence par 5d06)"
firebase functions:secrets:set MOMO_COLLECTION_USER -P kitunga-xtvpe4 $ACC
echo "=== MOMO_COLLECTION_KEY : COLLECTION « API key » (32 caractères, commence par db57)"
firebase functions:secrets:set MOMO_COLLECTION_KEY -P kitunga-xtvpe4 $ACC
F=functions:functions
firebase deploy --only "$F:kitungaStartPayment,$F:kitungaConfirmPayment,$F:kitungaStartSubscription,$F:kitungaConfirmSubscription,$F:kitungaReconcilePayments,$F:kitungaRefundOrder" \
  -P kitunga-xtvpe4 $ACC --non-interactive
echo "OK — clés d'encaissement corrigées."
