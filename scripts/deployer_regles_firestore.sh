#!/usr/bin/env bash
# Règles Firestore (firebase/firestore.rules) : protègent les champs et
# collections tenus par le serveur (statuts calculés, propositions de course,
# finances, tickets, messagerie…).
#
# À lancer APRÈS la publication de la nouvelle version Android : les
# anciennes versions de l'application écrivent encore certains champs que
# ces règles refusent.
set -e
cd "$(dirname "$0")/../firebase"
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
firebase deploy --only firestore:rules -P kitunga-xtvpe4 \
  --account ntemoconsultingntemoconsulting@gmail.com --non-interactive
echo "OK — règles Firestore en ligne."
