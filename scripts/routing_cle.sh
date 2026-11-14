#!/usr/bin/env bash
# Clé du service d'itinéraires réels (frais à la distance par la route,
# heure d'arrivée, tracé sur la carte). La clé n'est jamais écrite dans le
# code : vous la collez quand on vous la demande (elle ne s'affiche pas).
#
# Valeur à coller, au choix :
#   google:VOTRE_CLÉ   Google Maps « Directions API » (vraies routes ET
#                      circulation en temps réel) — recommandé.
#   ors:VOTRE_CLÉ      OpenRouteService (vraies routes, sans circulation,
#                      gratuit jusqu'à ~2000 calculs par jour).
#   absent             pas encore de clé : l'application utilise une
#                      estimation et l'indique comme telle.
#
# À lancer une première fois AVANT deployer_tout.sh (les fonctions de
# paiement et de suivi en ont besoin), puis à chaque changement de clé.
set -e
cd "$(dirname "$0")/../firebase"
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
ACC="--account ntemoconsultingntemoconsulting@gmail.com"
echo "=== ROUTING_API_KEY : collez google:CLÉ, ors:CLÉ ou absent, puis Entrée"
firebase functions:secrets:set ROUTING_API_KEY -P kitunga-xtvpe4 $ACC
F=functions:functions
firebase deploy --only "$F:kitungaDeliveryQuote,$F:kitungaDeliveryPosition,$F:kitungaStartPayment,$F:kitungaConfirmPayment,$F:kitungaStartSubscription,$F:kitungaConfirmSubscription,$F:kitungaReconcilePayments,$F:kitungaRefundOrder,$F:kitungaPaymentOptions" \
  -P kitunga-xtvpe4 $ACC --non-interactive
echo "OK — les itinéraires utilisent la nouvelle clé."
