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
firebase deploy --only functions:kitungaStartPayment,functions:kitungaConfirmPayment,functions:kitungaRefundOrder -P kitunga-xtvpe4
```

## Tests

```bash
cd firebase/functions
node --test kitunga/pricing.test.js          # calcul des prix
firebase emulators:exec --only firestore --project demo-kitunga \
  "node --test kitunga/payments.emulator.test.js"   # parcours complet, MTN simulé
```

## Étape suivante (application)

Une fois les fonctions déployées, l'écran de paiement de l'application devra
appeler `kitungaStartPayment` puis `kitungaConfirmPayment` (paquet
`cloud_functions`) au lieu d'appeler MTN directement.
