#!/usr/bin/env bash
# Mise en ligne Kitunga : fonctions données en paramètres, puis le site admin.
#   bash scripts/deployer.sh kitungaStartPayment kitungaSaveProduct
#   bash scripts/deployer.sh            (site seulement)
# Ne jamais ajouter corsProxy ici (voir scripts/README.md).
set -e
cd "$(dirname "$0")/.."
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
ACC="--account ntemoconsultingntemoconsulting@gmail.com"
if [ $# -gt 0 ]; then
  ONLY=$(for f in "$@"; do printf "functions:functions:%s," "$f"; done | sed 's/,$//')
  (cd firebase && firebase deploy --only "$ONLY" -P kitunga-xtvpe4 $ACC --non-interactive)
fi
firebase deploy --only hosting -P kitunga-xtvpe4 $ACC --non-interactive
echo "OK — purgez le cache Cloudflare puis Ctrl+Maj+R."
