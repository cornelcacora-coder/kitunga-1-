# Scripts de mise en ligne Kitunga

À lancer depuis le terminal de VS Code, à la racine du projet.

- `bash scripts/deployer_tout.sh` : met en ligne toutes les fonctions (sauf
  corsProxy) puis le site. Le plus simple après une série de changements.
- `bash scripts/deployer.sh <fonctions…>` : met en ligne les fonctions citées,
  puis le site admin. Sans paramètre : le site seulement. Ensuite, purger le
  cache Cloudflare.
- `bash scripts/storage_cors.sh` : règle CORS du stockage (déjà faite).
- `bash scripts/deployer_regles_stockage.sh` : règles du stockage
  (dossier privé des ordonnances).

Ne pas mettre `corsProxy` dans la liste : l'outil Firebase ne connaît pas les
tarifs de us-west1 et exige `--force` pour cette fonction. Si elle doit être
redéployée : `firebase deploy --only functions:functions:corsProxy --force`
(depuis `firebase/`, avec `--account` et `-P kitunga-xtvpe4`).

- `bash scripts/mtn_cles.sh` : installe ou remplace les clés MTN MoMo
  (secrets Firebase, jamais dans le code), puis remet en ligne les fonctions
  de paiement et de remboursement.
- `bash scripts/airtel_cles.sh` : installe ou remplace les clés Airtel Money
  (« Client ID » et « Client Secret » du portail Airtel Africa). **À lancer
  une première fois avant `deployer_tout.sh`** : les fonctions de paiement
  en ont besoin. Sans compte Airtel pour l'instant, tapez `absent` : le
  client qui choisit Airtel Money est invité à payer avec MTN MoMo.

- `bash scripts/deployer_regles_firestore.sh` : règles Firestore. **Seulement
  après la publication de la nouvelle version Android** (voir
  docs/ECOSYSTEME_REALISE.md).
