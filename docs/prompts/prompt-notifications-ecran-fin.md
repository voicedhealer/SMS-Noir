# PROMPT — Notifications locales + refonte de l'écran de fin de chapitre

*À traiter comme une phase à part entière, avec Phase 0 d'audit comme d'habitude. S'appuie sur l'addendum technique déjà en place (mécanisme de déblocage `chapter_unlocked_at`, déjà posé côté serveur).*

## Contexte

L'écran de fin de chapitre actuel affiche un compte à rebours brut, sans action possible — le joueur n'a rien à faire d'autre que regarder un chiffre descendre. Retour de test : ça n'incite à rien et risque de faire fermer l'app pour de bon plutôt que d'y faire revenir. Refonte complète de l'écran + ajout d'un vrai système de notification locale pour fermer la boucle proprement.

## 1. Notifications locales — le système

**Objectif** : quand le joueur choisit « Me prévenir », l'app programme une notification locale qui se déclenche exactement quand `chapter_unlocked_at` est atteint, même si l'app est fermée entre-temps.

**Comportement attendu** :
- Au tap sur « Me prévenir dans 8h », demander la permission de notification si elle n'a pas déjà été accordée (première fois seulement — ne jamais redemander si déjà refusée, respecter le choix du joueur).
- Si permission accordée : programmer une notification locale calée sur `chapter_unlocked_at` (le serveur fait déjà foi sur ce timestamp, le client ne fait que programmer un rappel local dessus — pas de nouvelle logique de déblocage à inventer).
- Si permission refusée : le bouton reste utilisable mais bascule sur un état informatif (« Vous pourrez revenir consulter l'histoire » ou équivalent) sans notification réelle — ne jamais bloquer le joueur ni le culpabiliser pour avoir refusé.
- Si le joueur rouvre l'app avant l'échéance et retape sur le bouton : la notification existante est reprogrammée, pas dupliquée (une seule notification active à la fois par chapitre).
- Si le chapitre est débloqué autrement entre-temps (achat), annuler la notification programmée — elle n'a plus lieu d'être.

**Texte de la notification** (à traiter comme du contenu narratif, pas juste un texte technique) :
> **Titre** : Numéro Inconnu
> **Corps** : Léna vous attend. Le chapitre 2 est disponible.

Prévoir ce texte comme un champ de contenu (`chapters.notification_text` ou équivalent), pas en dur — les chapitres suivants auront leur propre texte d'accroche.

**Plateformes** : implémentation native standard (permissions iOS/Android via le package Flutter déjà pressenti pour les notifications, `flutter_local_notifications` ou équivalent déjà utilisé pour les autres notifications locales du projet si applicable — vérifier l'existant avant d'ajouter une dépendance).

## 2. Refonte de l'écran de fin de chapitre

**Disposition** : texte centré verticalement dans l'écran, pas plaqué en haut. Suppression totale de l'affichage du compte à rebours en chiffres — le timing reste géré en interne (pour la notification et le déblocage), mais n'est plus montré brut au joueur.

**Contenu, dans l'ordre** :
1. Le message de cliffhanger du chapitre (texte narratif existant, machine à écrire comme déjà en place)
2. Séparateur visuel discret
3. Teaser du chapitre suivant : label « Chapitre 2 — Chloé » (petit, gris, majuscules espacées) puis une phrase d'accroche courte (nouveau champ de contenu à prévoir par chapitre, ex. `chapters.teaser_text`)

**Trois actions, dans cet ordre exact, hiérarchie visuelle décroissante** :
1. **Bouton plein (le plus visible)** : « Me prévenir dans 8h » (le texte s'adapte à `unlock_delay_minutes` du chapitre, jamais codé en dur) → déclenche le système de notification du point 1.
2. **Bouton contour, juste en dessous** : « Débloquer ce chapitre » → achat local du chapitre. *(Le système de paiement lui-même n'est pas dans le périmètre de ce prompt — le bouton peut être stubé/désactivé avec une note si l'intégration d'achat n'existe pas encore ; dis-le si c'est le cas.)*
3. **Lien discret, tout en bas, le moins visible** : « Voir toutes les offres » → renvoie vers un écran de formules à construire séparément (pas dans ce prompt) — pour l'instant, un simple placeholder ou une désactivation propre suffit.

**Sous les trois actions** : garder le lien existant « Un retour, une note, une idée ? Écrivez-nous ».

## Phase 0 — Audit attendu

Avant de coder : vérifier l'état actuel de l'écran de fin de chapitre, confirmer si un package de notifications locales est déjà présent dans le projet (probable, vu les vibrations et rappels déjà en place ailleurs) ou s'il faut l'ajouter, et signaler si le système d'achat/paiement existe déjà sous une forme quelconque avant de stuber le bouton 2.

## Ce qui n'est pas dans ce prompt

Le système de paiement réel (achat local vs offre complète). L'écran « toutes les offres ». Le contenu réel du teaser du chapitre 2 (à écrire au moment d'écrire le chapitre en détail — un placeholder suffit pour l'instant).
