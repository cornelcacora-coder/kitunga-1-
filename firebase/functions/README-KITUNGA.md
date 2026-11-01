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

## Abonnement client

- Obligatoire pour commander (rôle `User`) : l'application, les règles
  Firestore (Cart, Orders) et `kitungaStartPayment` le vérifient.
- Formules : Mensuel 250 F (30 j), Trimestriel 500 F (90 j), Annuel 1000 F (365 j).
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
firebase deploy --only firestore:rules,functions:kitungaStartPayment,functions:kitungaConfirmPayment,functions:kitungaRefundOrder,functions:kitungaStartSubscription,functions:kitungaConfirmSubscription,functions:kitungaReconcilePayments -P kitunga-xtvpe4
```

## Tests

```bash
cd firebase/functions
node --test kitunga/pricing.test.js          # calcul des prix
firebase emulators:exec --only firestore --project demo-kitunga \
  "node --test kitunga/payments.emulator.test.js"   # parcours complet, MTN simulé
```

## Activer dans l'application

L'écran de paiement est déjà prêt (`lib/backend/server_payment.dart`).
Après le déploiement et la configuration des secrets, passer
`const kServerPayment = false;` à `true`, recompiler et publier.
L'ancien paiement direct reste utilisé tant que la valeur est `false`.
