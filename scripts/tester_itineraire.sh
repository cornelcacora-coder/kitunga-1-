#!/usr/bin/env bash
# Vérifie que la clé ROUTING_API_KEY fonctionne : demande à Google le trajet
# réel Poto-Poto → Bacongo (Brazzaville). La clé n'est jamais affichée.
set -u
cd "$(dirname "$0")/../firebase"
export NODE_OPTIONS="--network-family-autoselection-attempt-timeout=5000"
ERR=$(mktemp)
OUT=$(firebase functions:secrets:access ROUTING_API_KEY \
  --account ntemoconsultingntemoconsulting@gmail.com --project kitunga-xtvpe4 2>"$ERR")
CODE=$?
if [ $CODE -ne 0 ]; then
  echo "ÉCHEC : lecture du secret impossible. Message de Firebase :"
  grep -v -E 'AIza|google:|ors:' "$ERR" | tail -n 5
  rm -f "$ERR"; exit 1
fi
rm -f "$ERR"
VAL=$(printf '%s' "$OUT" | tr -d '[:space:]')
PREFIX_OK=1
case "$VAL" in
  google:*) KEY="${VAL#google:}" ;;
  AIza*) KEY="$VAL"; PREFIX_OK=0
    echo "ATTENTION : la clé a été enregistrée SANS « google: » devant."
    echo "            Le serveur ne la reconnaît pas et utilise encore l'estimation." ;;
  absent) echo "ÉCHEC : la valeur enregistrée est « absent » (aucune clé)."; exit 1 ;;
  "") echo "ÉCHEC : la valeur enregistrée est vide."; exit 1 ;;
  *) echo "ÉCHEC : valeur inattendue (${#VAL} caractères, commence par « ${VAL:0:3}… »)."; exit 1 ;;
esac
echo "Clé lue (se termine par …${KEY: -4}). Appel de Google Routes API…"
RES=$(curl -s -X POST "https://routes.googleapis.com/directions/v2:computeRoutes" \
  -H "Content-Type: application/json" \
  -H "X-Goog-Api-Key: $KEY" \
  -H "X-Goog-FieldMask: routes.distanceMeters,routes.duration" \
  -d '{"origin":{"location":{"latLng":{"latitude":-4.2560,"longitude":15.2850}}},
       "destination":{"location":{"latLng":{"latitude":-4.2860,"longitude":15.2450}}},
       "travelMode":"DRIVE","routingPreference":"TRAFFIC_AWARE","regionCode":"cg"}')
unset KEY VAL OUT
echo "$RES" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  let j;try{j=JSON.parse(s)}catch(e){console.log("ÉCHEC : réponse illisible :",s.slice(0,300));return}
  const r=j.routes&&j.routes[0];
  if(r&&r.distanceMeters){console.log("OK — Poto-Poto → Bacongo : "+(r.distanceMeters/1000).toFixed(1)+" km par la route, "+Math.ceil(parseInt(r.duration)/60)+" min avec la circulation.");}
  else if(j.error){console.log("ÉCHEC Google ("+j.error.status+") : "+j.error.message);}
  else console.log("Réponse vide : "+s.slice(0,300));
});'
if [ $PREFIX_OK -eq 0 ]; then
  echo
  echo "→ Relancez : bash scripts/routing_cle.sh  et collez cette fois  google:VOTRE_CLÉ"
  echo "  (les 7 caractères « google: » collés juste devant la clé, sans espace)."
fi
