#!/usr/bin/env bash
# Autorise le site à lire les images du stockage Firebase (déjà appliqué le
# 2026-11-09 ; à relancer seulement si la règle est perdue).
set -e
cd "$(dirname "$0")/.."
ACC=ntemoconsultingntemoconsulting@gmail.com
gcloud storage buckets update gs://kitunga-xtvpe4.firebasestorage.app \
  --cors-file=firebase/storage.cors.json --project kitunga-xtvpe4 --account "$ACC"
