# Paiement Kitunga côté serveur

Le prix, le stock, la commande et le remboursement sont calculés par les
Cloud Functions, plus par l'application. Le client ne peut donc plus changer
le montant ni commander un article épuisé.

## Fonctions

| Fonction | Type | Rôle |
|---|---|---|
| `kitungaStartPayment` | appel (onCall) | Relit le panier, recalcule prix + livraison + stock, envoie la demande MTN, crée `Paiement/{referenceId}` |
| `kitungaConfirmPayment` | appel (onCall) | Vérifie MTN ; si payé : stock décrémenté (produit et variantes), commande + articles créés, panier vidé (transaction) |
| `kitungaRefundOrder` | déclencheur `Orders/{id}` | Commande payée puis refusée/annulée : virement MTN vers le client, une seule fois |
| `kitungaStartSubscription` | appel (onCall) | Abonnement client : prix de la formule fixé par le serveur, demande MTN |
| `kitungaConfirmSubscription` | appel (onCall) | Si payé : `User.subscribe_close_at` prolongé (30, 90 ou 365 jours) |
| `kitungaReconcilePayments` | toutes les 5 min | Termine les paiements validés chez MTN mais jamais confirmés (client parti trop tôt) |
| `kitungaCreatePartner` | appel (onCall) | Un administrateur crée un commerçant ou un livreur sans quitter sa session |

## Abonnement client

- Obligatoire pour commander (rôle `User`) : l'application, les règles
  Firestore (Cart, Orders) et `kitungaStartPayment` le vérifient.
- Formules : Mensuel 250 F (30 j), Trimestriel 500 F (90 j), Annuel 1000 F (365 j).
- La formule choisie à l'inscription (`User.subscribe_type`) est un simple
  choix : elle est présélectionnée sur la page web et n'active rien sans paiement.
- Payé **hors de l'application** sur `web/abonnement.html` (règle Google Play
  sur les services numériques). L'application ne contient ni lien ni bouton
  de paiement d'abonnement : il faut communiquer l'adresse aux clients
  (SMS, WhatsApp, réseaux sociaux).
- La page est publiée avec l'hébergement Firebase :
  `flutter build web && firebase deploy --only hosting -P kitunga-xtvpe4`
  puis `https://kitunga-xtvpe4.web.app/abonnement.html`.
- Les clients déjà inscrits n'ont pas de date de fin : ils doivent payer
  avant de commander. Pour offrir une période (ex. 30 jours de lancement),
  renseigner `subscribe_close_at` dans la console Firebase.

Paramètres de `kitungaStartPayment` : `sellerPath` (ex. `User/abc`), `zone`,
`deliveryLocation`, `phone`. Réponse : `{referenceId, amount, subtotal, fee}`.
`kitungaConfirmPayment({referenceId})` renvoie `status` :
`pending` (redemander quelques secondes plus tard), `failed`, `paid`
(avec `orderPath`) ou `paid_refund` (payé mais plus disponible : à rembourser).

## Mise en place (une fois)

Les anciennes clés MTN étaient dans l'application : il faut les **révoquer**
sur le portail MTN et en créer de nouvelles, puis :

```bash
cd firebase
firebase functions:secrets:set MOMO_COLLECTION_USER         -P kitunga-xtvpe4
firebase functions:secrets:set MOMO_COLLECTION_KEY          -P kitunga-xtvpe4
firebase functions:secrets:set MOMO_COLLECTION_SUBSCRIPTION -P kitunga-xtvpe4
firebase functions:secrets:set MOMO_DISBURSEMENT_USER         -P kitunga-xtvpe4
firebase functions:secrets:set MOMO_DISBURSEMENT_KEY          -P kitunga-xtvpe4
firebase functions:secrets:set MOMO_DISBURSEMENT_SUBSCRIPTION -P kitunga-xtvpe4
```

Optionnel (fichier `functions/.env`) : `MOMO_BASE_URL` (par défaut
`https://proxy.momoapi.mtn.com`) et `MOMO_TARGET_ENV` (par défaut `mtncongo`).
Le remboursement nécessite un compte MTN **Disbursement** approvisionné.

## Déploiement

```bash
cd firebase
firebase deploy --only firestore:rules,functions:kitungaStartPayment,functions:kitungaConfirmPayment,functions:kitungaRefundOrder,functions:kitungaStartSubscription,functions:kitungaConfirmSubscription,functions:kitungaReconcilePayments,functions:kitungaCreatePartner -P kitunga-xtvpe4
```

Les règles limitent la lecture des profils et des commandes. Les anciennes
versions de l'application demandent aux livreurs une liste que ces règles
refusent : publier d'abord `kitungaCreatePartner`, le web et l'application, puis
déployer les règles une fois les livreurs passés à la nouvelle version.

## Tests

```bash
cd firebase/functions
node --test kitunga/pricing.test.js          # calcul des prix
firebase emulators:exec --only firestore --project demo-kitunga \
  "node --test kitunga/payments.emulator.test.js"   # parcours complet, MTN simulé
firebase emulators:exec --only firestore --project demo-kitunga \
  "node --test kitunga/rules.emulator.test.js"      # règles Firestore
firebase emulators:exec --only firestore --project demo-kitunga \
  "node --test kitunga/partners.emulator.test.js"   # création de partenaire
```

L'émulateur demande Java 21 ou plus récent. Lancer ces fichiers un par un :
ils utilisent la même base de test.

## Remboursement automatique

`kitungaRefundOrder` ne vire l'argent que si tout est vérifié : commande arrêtée
alors qu'elle était encore en attente, paiement écrit par le serveur, réussi et
lié à cette commande, montants identiques, paiement confirmé par MTN. Le montant
et le numéro viennent du paiement, jamais de la commande. Sinon :
`refund_status = "À traiter manuellement"` et le motif dans `refund_error`.

## Activer dans l'application

L'écran de paiement est déjà prêt (`lib/backend/server_payment.dart`).
Après le déploiement et la configuration des secrets, passer
`const kServerPayment = false;` à `true`, recompiler et publier.
L'ancien paiement direct reste utilisé tant que la valeur est `false`.

## Administration : catalogue et partenaires (kitunga/catalog.js)

Pages web admin (menu latéral à sections dépliables, `lib/noc/admin/`) :
`/categories`, `/produits`, `/commercants`, `/livreurs`, `/clients`, en plus
de `/gestion` et `/commercial`. Toutes les écritures passent par ces fonctions,
réservées à l'admin et journalisées dans `audit_logs` :

- `kitungaCatalogQuery` : lectures (vues `categories`, `products`, `partners`,
  `clients`). À la première ouverture, les 5 catégories d'origine sont
  recopiées dans la collection `Categories`.
- `kitungaSaveCategory`, `kitungaDeleteCategory` : renommer une catégorie
  met à jour `User.category` de ses commerces ; une catégorie utilisée ne se
  supprime qu'en indiquant où déplacer ses commerces (`reassignTo`).
- `kitungaSaveProduct`, `kitungaDeleteProduct` : mêmes champs que
  l'application vendeur (`on_sale` = publié, photo obligatoire pour publier ;
  `sale_price` = prix de vente ; `instant_disponibilty` = livraison express ;
  `specifications` = mise en avant). La suppression retire le produit des
  paniers non commandés ; les commandes gardent leur copie.
- `kitungaSavePartner` : fiche d'un commerçant, d'un livreur ou d'un client
  (client : nom et téléphone seulement). Création : `kitungaCreatePartner`.
  « Supprimer » un compte = `kitungaSetAccountStatus` (désactivé, réactivable).
- `kitungaPublicCategories` : catégories visibles, lues par l'application
  mobile (`lib/backend/kitunga_categories.dart`), avec les 5 d'origine en
  secours. L'application masque les commerces désactivés et leurs produits.

Images : envoyées par l'interface dans le dossier Storage de l'admin ; le
serveur n'accepte que des adresses Firebase Storage ou `asset:assets/…`.
