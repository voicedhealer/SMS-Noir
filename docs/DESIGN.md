# DESIGN.md — principes UI

> **Squelette.** L'UI est le périmètre du **prompt 2** (app Flutter). Ce fichier ne fixe ici que les
> principes déjà contraints par la narration et par le moteur, pour que rien ne soit rendu impossible
> par une décision technique prise au prompt 1.

## Intention

Réalisme total. L'app **est** une messagerie — pas une app de jeu qui imite une messagerie.
Aucune rupture du 4e mur : pas de score visible, pas de barre de progression, pas de « chapitre 1/5 »
tapageur. Ce que le joueur gagne (`confiance`, `lucidite`, `indices`) ne s'affiche jamais en chiffres.

## Écrans

| Écran | Contenu |
|---|---|
| **Liste des conversations** | Une entrée par contact. Ch. 1 : Léna seule. Puis Karim (ch. 3, dont un groupe à trois), puis un numéro inconnu (ch. 4), puis Chloé (ch. 5, fin cachée) |
| **Fil de conversation** | Bulles, séparateurs horaires, médias (photo, vocal), zone de saisie |

## Principes retenus

- **Bulles** : entrantes / sortantes distinctes. Médias intégrés au fil (photo cliquable, vocal avec
  lecteur et **réécoute** possible — la réécoute est une interaction de gameplay, pas un confort).
- **Typing indicator** : joué côté client à partir des délais renvoyés par `advance`. C'est lui qui
  porte le rythme et la tension ; il n'est pas décoratif.
- **Séparateurs horaires** : matérialisent les ellipses (messages de type `separator`). Au ch. 1,
  les vraies attentes sont proscrites (délais ≤ 90 s, bible §9) : l'ellipse remplace l'attente.
- **Interactions cachées** : jamais signalées par un bouton « indice ». Ce sont des gestes naturels
  d'une messagerie — zoomer sur une photo, réécouter un vocal, relancer, insister. Le joueur qui
  ne les fait pas ne doit pas se sentir puni ; celui qui les fait ne doit pas voir de récompense
  clignoter. Une `inline_response` arrive comme un message ordinaire.
- **« Ignorer » est un bouton explicite**, jamais un timeout réel (chapitre §Conventions : trop
  ambigu). Ne pas répondre est un choix assumé du joueur, pas une absence d'action.
- **Statut « Léna est hors ligne »** (N19) : message de type `system` dans le fil. Le silence de 90 s
  du N19 est le plus long du chapitre — c'est un effet dramatique, pas un temps mort à combler.
  Vibration discrète à 60 s si activée.
- **Fin de chapitre** : écran dédié (« Quelqu'un est entré chez Léna. Quelqu'un sait qu'elle
  cherche. ») puis compte à rebours de déblocage (8 h ; immédiat en premium, bible §9). Doit savoir
  afficher « **Chapitre 2 : Chloé** — à venir » alors que le chapitre 2 n'a pas encore de contenu.
- **Saisie libre (moment IA, N9)** : champ de texte normal. L'IA ne mentionne **jamais** être une IA.
  Consentement RGPD à la première saisie libre (bible §9).

## Contraintes remontant du moteur

- Le client joue les timers ; le serveur ne fait qu'envoyer les délais.
- L'historique doit pouvoir être **rejoué instantanément** au retour dans l'app (pas de re-timing des
  messages déjà reçus).
- Le client ne connaît jamais la suite : ni `next_node_id`, ni `effects`, ni les choix verrouillés.
  L'UI ne peut donc pas griser un choix indisponible — il n'existe simplement pas.
