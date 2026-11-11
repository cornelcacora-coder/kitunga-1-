#!/usr/bin/env bash
# Met en ligne TOUTES les fonctions Kitunga (sauf corsProxy, voir README),
# puis le site admin. À lancer depuis le dossier kitunga-1- :
#   bash scripts/deployer_tout.sh
set -e
cd "$(dirname "$0")/.."
FUNCS=$(grep -oE "^exports\.([A-Za-z0-9_]+)" firebase/functions/index.js \
  | sed 's/exports\.//' | grep -v "^corsProxy$")
echo "Fonctions mises en ligne : $(echo "$FUNCS" | wc -l)"
bash scripts/deployer.sh $FUNCS
