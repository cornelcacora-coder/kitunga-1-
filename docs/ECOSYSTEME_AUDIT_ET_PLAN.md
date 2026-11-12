# KITUNGA — Audit de l'existant et plan d'intervention « écosystème des cinq acteurs »

Date : 12 novembre 2026 · Branche : `feat/module-commercial` (commit `b90b40f`)

Ce document répond aux phases 1 (audit) et 2 (conception) du cahier des
charges. Il décrit ce qui existe **réellement** dans KITUNGA, ce qui manque,
les risques, puis l'ordre des développements. Rien n'est supprimé, aucun
statut de commande stocké n'est renommé, aucune donnée de production n'est
modifiée.

---

## 1. Technologies réellement utilisées

| Couche | Technologie | Remarque |
|---|---|---|
| Application mobile (client, vendeur, livreur) | Flutter 3.47 / Dart 3.13, base FlutterFlow, GoRouter | Une seule application ; l'écran dépend du rôle. |
| Administration | Flutter Web (même code), pages `lib/noc/` | Le web n'ouvre que l'administration. |
| Base de données | Cloud Firestore (projet `kitunga-xtvpe4`) | Pas de SQL : documents + règles de sécurité. |
| Serveur | Cloud Functions Node 22 (gen 1, us-west1), 85 fonctions | Source de vérité pour paiements, livraison, admin. |
| Fichiers | Firebase Storage (CORS configuré) | Photos produits, preuves de livraison, ordonnances (privées). |
| Notifications | Firebase Cloud Messaging + centre de notifications (collection `Notifications`) | |
| Paiement | MTN MoMo (production), Airtel Money (prêt, en attente des clés) | Clés dans Secret Manager. |
| Carte / GPS | flutter_map + OpenStreetMap, geolocator | |

**Le cahier des charges cite Laravel, React Native, PostgreSQL et Redis :
KITUNGA n'utilise aucune de ces technologies.** Les remplacer serait une
réécriture complète sans bénéfice. Les besoins visés sont couverts par Firebase :

| Besoin | Réponse dans KITUNGA |
|---|---|
| Temps réel (WebSockets) | Écoute Firestore en direct (`snapshots()`), déjà utilisée par l'application |
| Transactions / anti-double | Transactions Firestore côté serveur (déjà utilisées : prise de course, paiements) |
| Files d'attente / tâches | Déclencheurs Firestore + tâches planifiées (Cloud Scheduler) |
| Cache | Inutile à ce volume |
| Autorisations | Règles Firestore + contrôles dans chaque fonction |

---

## 2. Acteurs et rôles existants

| Acteur | Rôle stocké (`User.role`) | État |
|---|---|---|
| Client | `User` (et `Guest` avant inscription) | ✅ |
| Vendeur | `Seller` | ✅ |
| Livreur | `Deliver` | ✅ |
| Administrateur | `Admin` (attribué depuis la console) | ✅ |
| Support client | — | ❌ **inexistant** |
| (en plus) Agents commerciaux | `sales_agents` (module commercial) | ✅ |

---

## 3. Inventaire par domaine

✅ existe et fonctionne · 🟡 partiel · ❌ absent

### Commandes
- ✅ Paiement d'abord, puis commande créée par le serveur (`payments.js`), prix recalculés côté serveur.
- ✅ Statuts : `En attente`, `En préparation`, `Pret`, `encours`, `Livrer`, `Reçu`, `Non Reçu`, `Refusée`, `Annulée` (`lib/backend/order_status.dart`).
- ✅ Horaires d'ouverture contrôlés, ordonnances (pharmacies), retours / échanges, remboursement automatique en cas de refus.
- 🟡 Les passages vendeur (accepter, préparer, prête) sont écrits par l'application et contrôlés par les règles Firestore. **Les règles les plus récentes ne sont pas encore déployées** (prévu après la publication Android).
- ❌ Historique des transitions (qui, quand, depuis quel statut).
- ❌ Statut de livraison et statut financier séparés du statut de commande.

### Livraison
- ✅ Prise de course « premier qui accepte » en transaction (pas de double attribution).
- ✅ Attribution, annulation et livraison forcée par l'admin (`admin_orders.js`).
- ✅ Remise sécurisée : code à 4 chiffres + photo, reçu numéroté, signalement de problème.
- ✅ En service / hors service, quartiers couverts (`order_events.js`).
- ✅ Course en cours : carte, étape « récupérée », itinéraire, position partagée toutes les 15 s, suivi en direct côté client (`delivery_tracking.js`).
- ✅ Alerte admin pour une commande prête depuis 20 minutes sans livreur.
- ✅ Frais de livraison selon la distance commerce → client, tarif réglable par l'admin.
- 🟡 Pas de statut « en pause » ; pas de refus explicite ni d'expiration de proposition.
- ❌ Attribution automatique (dispatch) par distance / charge / véhicule.
- ❌ Étape « arrivé chez le client », historique des positions, purge des positions.
- ❌ Type de véhicule, capacité, note du livreur.

### Communication
- ✅ Notifications push + centre de notifications pour chaque événement de commande.
- ✅ Boutons Appeler / WhatsApp entre client, commerce et livreur, limités aux personnes de la commande.
- ✅ Rappels admin aux clients (abonnement).
- ❌ Messagerie dans l'application.
- ❌ Annonces de l'admin aux vendeurs et livreurs (seulement aux clients).
- ❌ Préférences de notification.

### Support client
- 🟡 Coordonnées NTEMO CONSULTING (téléphone, WhatsApp, e-mail) dans l'application.
- ❌ Tickets, rôle Support, file de traitement, escalade.

### Finances
- ✅ Encaissement MoMo, rattrapage automatique, remboursements, journal `Paiement`.
- ✅ Abonnements clients (300 / 500 / 1000 F).
- ✅ Commissions des agents commerciaux (module commercial).
- ❌ **Aucune règle de commission sur les ventes des vendeurs n'existe.**
- ❌ **Aucune règle de rémunération des livreurs n'existe.**
- ❌ Soldes vendeurs et livreurs, versements, historique financier par acteur.

### Administration
- ✅ Tableau de bord, commandes, livraisons, carte par zone, alertes, catalogue, partenaires, clients et abonnements, publicités, remboursements, module commercial, tarif de livraison, journal d'audit (`audit_logs`).
- 🟡 Pas de vue de la disponibilité des livreurs ni de leur historique.
- ❌ Incidents (en dehors des signalements de livraison), tickets, rapports financiers par acteur.

---

## 4. Problèmes et risques relevés

| # | Risque | Gravité | Action |
|---|---|---|---|
| R1 | Dernières règles Firestore non déployées : en production, l'application peut encore écrire certains champs sensibles. | Haute | Déployer les règles dès la publication de la nouvelle version Android. |
| R2 | Historique Git public contenant d'anciennes clés MTN. | Haute | Rendre le dépôt privé (décision du propriétaire). |
| R3 | Anciens mots de passe stockés en clair dans `User.password`. | Haute | Vérifier et nettoyer en production (action manuelle). |
| R4 | Transitions vendeur écrites par l'application, sans historique. | Moyenne | Lot A : transitions par le serveur + historique. |
| R5 | Positions GPS conservées sans durée limite (`DeliveryTracking`). | Moyenne | Purge automatique après livraison (lot B). |
| R6 | Branche `main` en retard de 36 commits. | Moyenne | Fusion après validation. |
| R7 | `test/widget_test.dart` (test de démonstration) échoue toujours. | Faible | À supprimer ou remplacer. |

---

## 5. Architecture cible (adaptée à Firebase)

### 5.1 Trois statuts distincts, sans casser l'existant
Le champ `Orders.status` garde ses valeurs actuelles (l'application installée
en dépend). Deux champs sont ajoutés, écrits uniquement par le serveur :

- `delivery_status` : `searching` → `offered` → `accepted` → `to_pickup` →
  `picked_up` → `to_customer` → `arrived` → `delivered`, ou `failed`,
  `reassigning`, `cancelled`.
- `finance_status` : `paid` → `settled` (vendeur et livreur crédités), ou
  `refund_pending`, `refunded`.

Chaque transition est vérifiée par le serveur (rôle, ressource, état de
départ) et enregistrée dans `Orders/{id}/history` (qui, quand, avant, après,
motif).

### 5.2 Missions et dispatch
- Collection `Missions/{id}` : une proposition = un livreur, une commande, une
  date d'expiration (par exemple 60 s), un statut (`offered`, `accepted`,
  `declined`, `expired`, `cancelled`).
- Acceptation en transaction : une seule mission acceptée par commande
  (protection contre la double attribution, déjà en place pour la prise de course).
- Score de dispatch : distance réelle (dernière position récente < 2 min,
  sinon centre du quartier, signalé comme « position estimée »), quartier
  couvert, missions actives, type de véhicule ou capacité, refus récents. La
  raison du choix est enregistrée (`dispatch_reason`) pour l'admin.
- Si personne ne répond : nouvelle tentative, puis élargissement, puis alerte
  admin (déjà en place après 20 min).
- L'attribution manuelle par l'admin est conservée.

### 5.3 Messagerie
- `Conversations/{id}` liées à une commande (client ↔ livreur, client ↔
  vendeur, vendeur ↔ livreur) ou à un ticket. `participants` limite la
  lecture ; les messages sont écrits par le serveur (contrôle des droits,
  notification, compteur de non-lus).
- Ouverte seulement pendant la commande ; consultable ensuite en lecture seule.

### 5.4 Support
- Nouveau rôle `Support`, attribué par l'admin.
- `Tickets/{id}` : catégorie, priorité, statut, agent, commande liée, pièces
  jointes (Storage privé), réponses, notes internes, escalade vers l'admin.
- Droits du support : lire les tickets, les commandes liées et l'historique
  de livraison, répondre, escalader. **Pas** de remboursement, de suspension
  de compte, de tarif ni de paiement : ces actions restent à l'admin.

### 5.5 Finances
- `Ledger/{id}` : écritures en double (débit / crédit) par acteur, créées par
  le serveur une seule fois par commande (clé idempotente = id de commande +
  type). Les soldes se calculent à partir des écritures.
- Les montants dépendent de **règles à fixer par la direction** (voir § 7) :
  rien n'est inventé.

### 5.6 Données de position
- Position conservée seulement pendant la course ; supprimée 24 h après la
  livraison (trace minimale gardée pour les litiges : départ, récupération,
  remise).
- Une position plus ancienne que 2 minutes s'affiche comme
  « dernière position connue il y a X min », jamais comme actuelle (déjà le cas
  côté client).

---

## 6. Plan d'intervention (lots livrables, dans l'ordre)

Chaque lot est testé (émulateur Firestore + tests d'interface), commité et
déployable seul.

| Lot | Contenu | Dépend d'une décision ? |
|---|---|---|
| **A. Fondations des statuts** | Transitions vendeur et livreur par le serveur, `delivery_status`, historique `history`, en pause / hors service, étape « arrivé », purge des positions. | Non |
| **B. Missions et dispatch** | `Missions` avec expiration, accepter / refuser, réessai, réaffectation, raison du choix, vue admin de disponibilité. | Durée d'une proposition, types de véhicule |
| **C. Espace livreur** | Navigation Accueil / Mes courses / Carte / Messages / Profil, tableau du jour, tous les états (pause, aucune mission, incident, hors connexion). | Non (gains : lot F) |
| **D. Messagerie** | Conversations liées aux commandes, non-lus, notifications, annonces admin. | Garder WhatsApp en plus ? |
| **E. Support** | Rôle Support, tickets, espace de travail, escalade, notes internes. | Qui sont les agents ? |
| **F. Finances** | Grand livre, soldes, gains livreurs, reversements vendeurs, rapports admin. | **Oui : règles de rémunération et de commission** |
| **G. Supervision admin** | Indicateurs : livreurs disponibles ou en pause, livraisons échouées, incidents, tickets, finances. | Non |
| **H. Tests et documentation** | Scénario complet multi-acteurs, tests de sécurité des règles, mise à jour de ce document. | Non |

Ce qui est hors de portée de l'équipe de développement et reste à la charge
du propriétaire : déploiements en production, clés (MTN, Airtel), publication
Android, rendre le dépôt privé.

---

## 7. Décisions attendues de la direction

1. **Rémunération du livreur** : frais de livraison en entier, un pourcentage
   ou un montant fixe par course ?
2. **Commission Kitunga sur les ventes des vendeurs** : aujourd'hui, aucune.
   En faut-il une, et de combien ?
3. **Reversement aux vendeurs et aux livreurs** : l'argent arrive sur le
   compte MTN de Kitunga. À quelle fréquence et par quel moyen le reverser
   (MoMo Disbursement, manuel) ?
4. **Support** : qui sont les agents (comptes à créer) ?
5. **Dispatch** : durée d'une proposition (60 s proposé) ; types de véhicule
   à gérer (moto, vélo, voiture) ?
6. **Messagerie** : messagerie interne en plus des boutons Appeler / WhatsApp
   existants ?
