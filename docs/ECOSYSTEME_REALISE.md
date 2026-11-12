# KITUNGA — Écosystème des cinq acteurs : ce qui est livré

Date : 12 novembre 2026 · Branche : `feat/module-commercial`
Complète [ECOSYSTEME_AUDIT_ET_PLAN.md](ECOSYSTEME_AUDIT_ET_PLAN.md) (audit et
plan). Ce document est la référence technique après réalisation des lots A
à H.

---

## 1. Architecture

Inchangée dans ses technologies : application Flutter (client, vendeur,
livreur), administration et support en Flutter Web, Cloud Firestore, Cloud
Functions (Node 22, us-west1), FCM, Storage, MTN MoMo (Airtel prêt).

**Le serveur est la source de vérité.** Toute action qui engage une autre
personne ou de l'argent passe par une fonction serveur qui vérifie le rôle,
la ressource et l'état de départ. Les règles Firestore interdisent à
l'application d'écrire les champs calculés par le serveur.

Temps réel : écoute Firestore directe pour les commandes (règles en place),
appels serveur rafraîchis pour la messagerie (4 s), les tickets (10 s) et le
suivi du livreur (10 s), afin de ne pas dépendre du déploiement des règles.

---

## 2. Cycle de vie : trois statuts distincts

| Champ | Écrit par | Valeurs |
|---|---|---|
| `status` (inchangé) | application et serveur | `En attente`, `En préparation`, `Pret`, `encours`, `Livrer`, `Reçu`, `Non Reçu`, `Refusée`, `Annulée` |
| `delivery_status` | serveur seul | `not_ready`, `searching`, `offered`, `to_pickup`, `to_customer`, `arrived`, `delivered`, `failed`, `disputed`, `cancelled` |
| `finance_status` | serveur seul | `unpaid`, `paid`, `refund_pending`, `refunded`, `refund_manual`, `settled` |

Chaque changement est historisé dans `Orders/{id}/history` (avant, après,
quand, rôle et compte de l'auteur, motif). Les rôles sont déduits quand
l'application écrit elle-même le statut.

```
Client paie ─► En attente ─(vendeur)─► En préparation ─(vendeur)─► Pret
   │                                                         │
   │                    dispatch : proposition 60 s ◄────────┘
   │                    (refus / expiration → suivant ; 3 essais → ouverte à tous)
   ▼
encours : to_pickup ─(récupérée)─► to_customer ─(arrivé)─► arrived
   └─(code client + photo)─► Livrer ─► règlement financier (une fois)
         └─(client)─► Reçu  /  Non Reçu → ticket support + litige
```

---

## 3. Collections ajoutées

| Collection | Contenu | Accès direct depuis l'app |
|---|---|---|
| `Orders/{id}/history` | historique des statuts | aucun (via `kitungaOrderHistory`) |
| `Missions` | propositions de course (livreur, expiration, raison, réponse) | aucun |
| `DeliveryTracking` | dernière position du livreur pendant la course (effacée 24 h après) | aucun |
| `DelivererAvailability` | historique en service / pause / hors service | aucun |
| `Conversations` (+ `messages`) | messagerie d'une commande, annonces | aucun |
| `Tickets` (+ `messages`) | demandes au support, notes internes | aucun |
| `Ledger` | grand livre (ventes, livraisons, commission, annulations, versements) | aucun |
| `Settings/delivery_pricing`, `Settings/dispatch`, `Settings/finance` | réglages de l'admin | aucun |

Nouveaux champs utilisateur : `delivery_state`, `delivery_zones`, `vehicle`,
`last_position` (livreur en service uniquement), `shop_zone` (commerce).

---

## 4. Fonctions serveur (API)

**Livreur** : `kitungaSetDelivererStatus` (état, quartiers),
`kitungaSetVehicle`, `kitungaDelivererPing` (position, en service
seulement), `kitungaRespondMission` (accepter / refuser), `kitungaTakeDelivery`
(course ouverte), `kitungaDeliveryStep` (récupérée, arrivé),
`kitungaDeliveryPosition`, `kitungaConfirmDelivery`,
`kitungaReportDeliveryIssue`, `kitungaMyEarnings`.

**Tous les acteurs d'une commande** : `kitungaOrderContacts`,
`kitungaDeliveryTracking`, `kitungaOrderHistory`, `kitungaOpenOrderChat`,
`kitungaSendMessage`, `kitungaConversationMessages`,
`kitungaMyConversations`, `kitungaCreateTicket`, `kitungaMyTickets`,
`kitungaTicketThread`, `kitungaTicketReply`, `kitungaDeliveryQuote`.

**Support (et admin)** : `kitungaSupportQueue`, `kitungaTicketUpdate`
(statut, priorité, attribution, escalade), `kitungaSupportUserLookup`,
`kitungaSupportAgents`.

**Équipe Kitunga (admin et support)** : `kitungaStaffOpenDirect` (message
direct à un client, commerce ou livreur), `kitungaStaffInbox` (boîte
partagée, non-lus), `kitungaOrderConversations` (conversations d'une
commande, pour un litige).

**Admin** : `kitungaAdminSupervision`, `kitungaAdminDelivererHistory`,
`kitungaAdminAnnounce`, `kitungaAdminDispatchSettings`,
`kitungaOrderMissions`, `kitungaAdminDeliveryPricing`,
`kitungaAdminFinanceSettings`, `kitungaAdminFinanceOverview`,
`kitungaAdminAccountLedger`, `kitungaAdminRecordPayout`,
`kitungaAdminSetSupport`, `kitungaPaymentOptions`.

**Déclencheurs et tâches** : `kitungaOrderEvents` (notifications, dispatch,
tickets d'incident), `kitungaOrderLifecycle` (statuts calculés, historique),
`kitungaOrderFinance` (règlement / annulation), `kitungaExpireOffers`
(chaque minute), `kitungaStaleReadyOrders` (10 min), `kitungaPurgePositions`
(6 h).

---

## 5. Événements et notifications

| Événement | Destinataires |
|---|---|
| Nouvelle commande | commerce |
| Acceptée | client |
| Prête | livreur choisi (proposition 60 s), puis suivants, puis tous ceux du quartier |
| Prise en charge | client, commerce |
| Récupérée | client (« Votre livreur arrive ») |
| Arrivé | client |
| Livrée | client |
| Refusée / annulée | client / commerce |
| Problème de livraison | admins + ticket urgent au support |
| Non reçue | ticket support |
| Prête depuis 20 min sans livreur | admins |
| Message | autre participant |
| Message direct de l'équipe | la personne ; sa réponse : tous les admins et agents du support |
| Ticket : nouveau / réponse / résolu / escalade | support / auteur / admins |
| Versement | commerce ou livreur |
| Annonce | groupe choisi par l'admin |

---

## 6. Permissions

| Action | Client | Vendeur | Livreur | Support | Admin |
|---|:-:|:-:|:-:|:-:|:-:|
| Voir / écrire la messagerie de **sa** commande | ✅ | ✅ | ✅ | lecture | lecture |
| Historique d'une commande | la sienne | la sienne | la sienne | ✅ | ✅ |
| Créer un ticket | ✅ | ✅ | ✅ | — | — |
| Traiter les tickets, notes internes | — | — | — | ✅ | ✅ |
| Escalader | — | — | — | ✅ | — |
| Accepter / refuser une course | — | — | ✅ | — | — |
| Attribuer un livreur, annuler une commande | — | — | — | — | ✅ |
| Remboursements, suspension, tarifs, règles financières, versements | — | — | — | ❌ | ✅ |
| Donner le rôle Support | — | — | — | ❌ | ✅ |

Toutes les actions sensibles de l'admin et du support sont journalisées
(`audit_logs`).

---

## 7. Réglages (admin)

- **Opérations › Tarif et attribution** : frais selon la distance (base,
  prix au km, coefficient route, minimum, maximum, arrondi) ; attribution
  automatique (durée d'une proposition, essais, capacité par véhicule :
  moto ou voiture — pas de vélo).
- **Gestion › Finances** : commission Kitunga (0 % par défaut, comme
  avant), part du livreur (100 % des frais par défaut).
- **Support client › Équipe** : donner le rôle Support à un compte.

---

## 8. Interfaces

- **Livreur** : barre Accueil / Courses / Carte / Messages / Profil ;
  accueil (disponibilité, gains du jour, proposition avec compte à
  rebours, course en cours, nouvelles courses, aperçu, assistance) ;
  course en cours (carte, étapes, itinéraire, récupération, arrivée, remise) ;
  Mes gains.
- **Client** : suivi en direct (carte, étapes, livreur), Message / Appeler /
  WhatsApp, Aide & support, Mes messages.
- **Vendeur** : Mes revenus, Messages, Aide & support, quartier du commerce.
- **Admin (web)** : Messages (boîte partagée, nouveau message, bouton
  « Écrire » sur les livreurs, comptes, personnes d'une commande, tickets),
  conversations d'une commande dans son détail, Supervision en direct, Tarif et attribution, Finances,
  Support client, attribution et historique dans le détail d'une commande.
- **Support (web)** : `/support` — file, filtres, recherche, fil, notes
  internes, attribution, priorité, statut, escalade, recherche d'utilisateur.

---

## 9. Tests

- Serveur (émulateur Firestore) : 260 tests, dont le **scénario complet à
  cinq acteurs** (`scenario.emulator.test.js` : paiement → vendeur →
  proposition → acceptation → récupération → suivi → messages → incident →
  ticket → arrivée → remise → règlement → supervision → résolution), les
  doubles requêtes (acceptation, versement), l'expiration, les refus, et
  les règles de sécurité.
- Application : tests d'écran pour chaque nouvel écran (livreur, messagerie,
  support, gains, finances, supervision).

---

## 10. Reste à faire (hors code ou à décider)

1. **Déployer les règles Firestore** (`firebase/firestore.rules`) après la
   publication de la version Android : elles protègent tous les nouveaux
   champs serveur.
2. **Publier la version Android** (nouveaux écrans, GPS du livreur).
3. **Créer les comptes du support** (admin › Support client › Équipe).
4. **Renseigner le quartier de chaque commerce** (frais à la distance et
   point de collecte).
5. **Clés Airtel** : `scripts/airtel_cles.sh` dès réception.
6. **Versements automatiques MoMo** : aujourd'hui l'admin verse puis
   enregistre ; l'envoi automatique (MTN Disbursement) peut être ajouté.
7. Points d'amélioration : position GPS du client à la commande (destination
   exacte), position du commerce, notation des livreurs par les clients,
   préférences de notification par utilisateur.

---

## 11. Espace livreur professionnel (mise à jour)

**Audit de départ** : navigation, disponibilité, propositions, course en
cours, suivi, messagerie, support et gains existaient déjà. Il manquait :
documents et vérification, note des clients, performances, retraits, retard,
arrivée au commerce, incidents chez le commerce, alerte de sécurité, heure
d'arrivée estimée, onglets « Proposées » et « Refusées », accusés de lecture.

**Ajouté et testé**

| Fonction | Serveur | Écran |
|---|---|---|
| Documents (identité, permis, carte grise, assurance) : dépôt dans un dossier privé, validation ou refus motivé par l'admin, expiration, badge « vérifié » | `kitungaSubmitDocument`, `kitungaMyDocuments`, `kitungaAdminDocuments`, `kitungaAdminReviewDocument` | Mes documents ; bandeau d'état sur l'accueil ; admin › Supervision › Documents |
| Option « livreurs vérifiés seulement » pour l'attribution (désactivée par défaut) | `Settings/dispatch.require_verified` | admin › Tarif et attribution |
| Note du client (1 à 5 étoiles, une fois) et moyenne | `kitungaRateDelivery` | carte « Notez votre livreur » ; ★ dans l'en-tête du livreur |
| Performances : livraisons, taux de réussite (annulations des autres non imputées), acceptation, temps moyen, distance, gains du mois, graphique 8 semaines | `kitungaMyPerformance` | Mes performances |
| Demande de retrait (plafonnée, une à la fois) ; l'admin verse ou refuse avec motif | `kitungaRequestWithdrawal`, `kitungaMyWithdrawals`, `kitungaAdminWithdrawals`, `kitungaAdminDecideWithdrawal` | Mes gains ; admin › Finances |
| Gains du mois | `kitungaMyEarnings.month` | Mes gains |
| Arrivée au commerce (le vendeur est prévenu) | `kitungaArrivedAtShop` | Course en cours |
| Retard annoncé (client et commerce prévenus) | `kitungaReportDelay` | Course en cours ; suivi client |
| Incidents : commerce fermé, commande pas prête / incorrecte, produit manquant, panne, accident, GPS, paiement | `kitungaReportDeliveryIssue` | Signaler un problème |
| Alerte de sécurité (accident, danger, santé) avec position, contact d'urgence, ticket urgent | `kitungaSafetyAlert`, `kitungaSetEmergencyContact` | Sécurité et urgence ; bouton SOS (course, accueil) |
| Heure d'arrivée estimée | calcul local (distance × 1,3, 22 km/h) | Course en cours ; suivi client |
| Onglets Proposées, Refusées, recherche | `kitungaMyMissions` | Courses |
| Accusés de lecture (✓ / ✓✓), recherche de conversations | `kitungaConversationMessages.otherReadAt` | Messages |
| Rubrique « Mon activité de livreur » | — | Profil, menu ☰ |

**Nouvelles collections** : `DelivererDocuments`, `Withdrawals`,
`SafetyAlerts`. **Storage** : `documents/{uid}/` privé (déployer les règles de
stockage : `bash scripts/deployer_regles_stockage.sh`).

**Non réalisable sans service externe** : numéros masqués (fournisseur
d'appels), retrait automatique MoMo (compte MTN Disbursement approvisionné).
Le mode hors connexion se limite à l'affichage de l'état réseau et aux
nouvelles tentatives : aucune action critique n'est validée sans le serveur.
