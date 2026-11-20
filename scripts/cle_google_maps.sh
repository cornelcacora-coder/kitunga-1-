#!/usr/bin/env bash
# Clé Google Maps des cartes de l'application Android (client et livreur).
# Elle est écrite dans android/local.properties, qui n'est JAMAIS envoyé
# sur GitHub. À faire une fois sur l'ordinateur qui compile l'application
# Android (puis recompiler). Sans clé, l'application garde OpenStreetMap.
set -e
cd "$(dirname "$0")/.."
F=android/local.properties
read -r -s -p "Collez la clé Google Maps (AIza…, invisible), puis Entrée : " K; echo
K=$(printf '%s' "$K" | tr -d '[:space:]')
case "$K" in
  AIza*) ;;
  "") echo "Rien n'a été collé : arrêt."; exit 1 ;;
  *) echo "Ce n'est pas une clé Google (elle commence par AIza) : arrêt."; exit 1 ;;
esac
touch "$F"
grep -v '^MAPS_API_KEY=' "$F" > "$F.tmp" || true
printf 'MAPS_API_KEY=%s\n' "$K" >> "$F.tmp"
mv "$F.tmp" "$F"
echo "OK — clé enregistrée (se termine par …${K: -4}) dans $F."
unset K
git check-ignore -q "$F" && echo "Vérifié : ce fichier n'est pas envoyé sur GitHub." \
  || echo "ATTENTION : $F n'est pas ignoré par git, ne le commitez pas !"
echo "Recompilez maintenant l'application Android (flutter build appbundle)."
