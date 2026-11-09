# Scripts de mise en ligne Kitunga

À lancer depuis le terminal de VS Code, à la racine du projet.

- `bash scripts/deployer.sh <fonctions…>` : met en ligne les fonctions citées,
  puis le site admin. Sans paramètre : le site seulement. Ensuite, purger le
  cache Cloudflare.
- `bash scripts/storage_cors.sh` : règle CORS du stockage (déjà faite).

Ne pas mettre `corsProxy` dans la liste : l'outil Firebase ne connaît pas les
tarifs de us-west1 et exige `--force` pour cette fonction. Si elle doit être
redéployée : `firebase deploy --only functions:functions:corsProxy --force`
(depuis `firebase/`, avec `--account` et `-P kitunga-xtvpe4`).
