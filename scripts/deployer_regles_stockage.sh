#!/usr/bin/env bash
# Règles du stockage Firebase (firebase/storage.rules) : dossier privé des
# ordonnances. Sans effet sur les photos de produits et de profils.
set -e
cd "$(dirname "$0")/../firebase"
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
firebase deploy --only storage -P kitunga-xtvpe4 \
  --account ntemoconsultingntemoconsulting@gmail.com --non-interactive
