# Récupérer les mises à jour et publier la version Android

Branche de travail : `feat/module-commercial` (pas encore fusionnée dans `main`).

## 1. Récupérer le code

Depuis le dossier `kitunga-1-` :

```bash
git status                      # s'il y a des modifications locales : git stash
git fetch origin
git checkout feat/module-commercial
git pull origin feat/module-commercial
flutter pub get
(cd firebase/functions && npm install)
```

⚠️ **Ne plus régénérer ni pousser le code depuis FlutterFlow** : une grande partie
de l'application a été réécrite à la main (panier, produit, commandes, suivi,
profil, compte, cartes, police Poppins…). Un export FlutterFlow écraserait tout.

## 2. Vérifier que tout compile

```bash
flutter analyze lib          # attendu : 0 erreur (des « info » restent, normal)
flutter test                 # attendu : tout passe sauf test/widget_test.dart
                             # (ancien test d'exemple FlutterFlow, échoue depuis toujours)
```

## 3. Clés et fichiers locaux (jamais dans Git)

| Fichier | Contenu | Comment |
|---|---|---|
| `android/local.properties` | `MAPS_API_KEY=…` (cartes Google Maps) | `bash scripts/cle_google_maps.sh`, la clé est transmise **en privé** par le propriétaire |
| `android/key.properties` + fichier `.jks` | signature Play Store | ceux que vous utilisez déjà |

Sans `MAPS_API_KEY`, l'application fonctionne mais garde les cartes OpenStreetMap.

## 4. Numéro de version

Dans `pubspec.yaml`, la ligne `version: 2.0.4+7` : le nombre après `+` doit être
**plus grand** que celui de la dernière version publiée sur Play Console
(Test et publication → Versions). Exemple : `version: 2.1.0+8`.

## 5. Compiler et publier

```bash
flutter build appbundle --release
# fichier : build/app/outputs/bundle/release/app-release.aab
```

Play Console → KITUNGA → **Tests internes** → Créer une version → envoyer le `.aab`.
Installer depuis le lien de test interne (la carte Google ne s'affiche qu'avec la
version signée par Play Store).

## 6. Test complet avant la production

Quatre comptes : client **abonné**, vendeur, livreur, admin.

1. Client : accueil → bouton **+** → panier → « Localiser » → payer un petit montant MTN.
2. Vendeur : notification « Nouvelle commande » → Accepter → « Commande prête ».
3. Livreur : proposition (60 s) → accepter → carte → récupérer → remettre (code + photo).
4. Client : suivi sur la carte → « J'ai reçu ma commande ».
5. Une 2e commande **sans réponse du vendeur** : rappel à 10 min, annulation à 30 min.
6. Compte (client et livreur) : modifier le profil et la photo, second numéro,
   mot de passe, e-mail.
7. Frais de livraison : toujours des multiples de 500 F (1 000, 1 500, 2 000…).

## 7. Mise en ligne côté serveur (compte propriétaire uniquement)

À lancer par le propriétaire du projet Firebase, dans cet ordre :

```bash
bash scripts/deployer_tout.sh              # fonctions + site admin (recompilé)
bash scripts/deployer_regles_stockage.sh   # si pas encore fait
# … publication Android et test complet (étapes 5 et 6) …
bash scripts/deployer_regles_firestore.sh  # en DERNIER, après le test réussi
```

Après chaque mise en ligne du site : purger le cache Cloudflare de kitunga.site.

## 8. Ensuite

Quand le test est réussi : fusionner `feat/module-commercial` dans `main`
(pull request sur GitHub), puis repartir de `main`.
