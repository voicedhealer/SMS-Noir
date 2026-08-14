# BIBLE NARRATIVE — Numéro Inconnu
*Source de vérité du projet. Toute contribution (humaine ou Claude Code) doit être cohérente avec ce document. En cas de conflit, ce fichier gagne. Version 1.0 — chapitres 1 validé, 2-5 en structure.*

## 1. Pitch

22h47, le joueur reçoit un SMS destiné à un certain Karim : une inconnue, Léna, part enquêter seule sur la disparition de sa sœur Chloé. Mauvais numéro... en apparence. Le joueur devient son seul contact. Cinq chapitres, trois fins, et une question qui monte : pourquoi LUI ?

## 2. Personnages

| Personnage | Rôle | Voix/ton | Ce qu'il sait / cache |
|---|---|---|---|
| **Léna** | Protagoniste, contact principal | Directe, phrases courtes, ponctuation minimale sous stress, humour noir, ne dit JAMAIS « s'il te plaît ». Vouvoie si `refus=true` (jusqu'au ch. 3 inclus) | Cache : un événement du **12 mars** (dispute violente avec Chloé la veille de sa disparition — sa culpabilité), et le fait qu'elle n'a signalé la disparition qu'au bout de 5 mois |
| **Chloé** | La disparue, sœur cadette de Léna | N'apparaît qu'en fin cachée : trois mots, ch. 5 | Vivante. Sa « disparition » est une fuite volontaire — mais quelqu'un l'a retrouvée avant Léna |
| **Karim** | Ami/ex de Léna, contact n°2 | Poli, posé, questions précises — trop précises | Ambigu : protecteur sincère OU informateur de quelqu'un. Sa vraie allégeance est fixée par la branche (voir §6) |
| **Le suspect** | Homme de l'entrepôt, contact n°3 | Froid, courtois, jamais menaçant frontalement — c'est ça qui glace | Sait tout des échanges joueur/Léna (voir §5). Lié à la société **Sentinel Pro** |

## 3. Chronologie interne (ne jamais contredire)

- **J-7 mois** : disparition de Chloé. La veille : dispute violente avec Léna (« le 12 mars »)
- **J-5 mois → J-2 mois** : Léna cherche seule, ne signale RIEN à la police (culpabilité + une raison révélée au ch. 4)
- **J-2 mois** : premier signalement (date visible sur le récépissé du N10 — incohérence volontaire repérable)
- **J-3 semaines** : le porte-clés de Léna disparaît de son appartement
- **Jour J (ch. 1)** : jeudi, 22h47, premier message au joueur
- **Ch. 2** : lendemain matin · **Ch. 3** : J+2 et J+3 · **Ch. 4** : J+5 · **Ch. 5** : nuit de J+6

## 4. Le « mauvais numéro » — résolution du mystère central

Le numéro du joueur diffère de celui de Karim **d'un seul chiffre**. Léna a réellement fait une faute de frappe (nouveau téléphone, N4 : « une chance sur deux avec ce foutu nouveau tel »).
MAIS : le suspect, qui lit le téléphone de Léna (voir §5), a d'abord cru que le joueur était un complice recruté par elle. C'est pour ça qu'il s'intéresse au joueur — le hasard du mauvais numéro est vrai, l'attention qu'il attire est la vraie menace. Résolution au ch. 4-5. La question « pourquoi moi ? » a donc une réponse double : hasard (objectif) + paranoïa du suspect (conséquence).
**Interdit :** ne jamais réécrire ça en « Léna avait choisi le joueur exprès » — ça contredirait N4 et N13.

## 5. Arrivée des contacts — mécanismes canon

| Contact | Quand | Mécanisme | Règle d'or |
|---|---|---|---|
| **Karim** | Ch. 3 | Léna crée un **groupe à trois** : « Je vous mets en contact. S'il m'arrive un truc, vous êtes deux à savoir. » Puis Karim écrit **en privé** au joueur (il a vu son numéro dans le groupe) : « Ce que je vais te dire, Léna ne doit pas le voir. » | Toujours plausible : c'est Léna qui possède les deux numéros |
| **Le suspect** | Ch. 4 | Numéro inconnu, **aucune explication donnée**. Explication implicite déjà plantée : intrusion chez Léna (porte-clés, J-3 semaines) → accès à son téléphone → il lit tout depuis le ch. 1. Léna panique : « Personne n'a ce numéro à part moi. » | NE JAMAIS expliquer frontalement. Le joueur doit faire le lien porte-clés → téléphone lui-même |
| **Chloé** | Ch. 5, fin cachée seulement | Trois mots : « Arrête de m'aider. » | Aucune explication avant l'épilogue de la fin cachée |

Sensation visée : trois mécanismes différents = trois frissons différents (légitime / intrusion / mystère). La notification du suspect arrive **pendant** une conversation active avec Léna.

## 6. Variables et fins

| Variable | Plage | Alimentée par |
|---|---|---|
| `confiance` | 0-10 (départ 3, plafond 6 si `refus`) | Choix empathiques, moment IA, loyauté dans le groupe |
| `lucidite` | 0-5 ch. 1, extensible | Incohérences repérées (voir §7) |
| `indices` | liste | Interactions cachées + choix d'enquête |
| `refus` | bool | Branche N11 |
| `branche_ch1` | code | Callbacks d'ouverture ch. 2 |
| `detail_perso` | texte (RGPD §9) | Moment IA N9 |
| `loyaute` (ch. 3+) | leña / karim / neutre | Ce que le joueur répercute du privé vers le groupe |

**Fins (déterminées ch. 5) :**
1. **La sauver** : confiance ≥ 7 ET ≥ 3 indices — le joueur guide Léna dans la nuit finale
2. **Trop tard** : par défaut — vérité découverte, mais après le drame
3. **Fin cachée** : lucidite ≥ 4 ET a répondu à Chloé (ch. 5) — la vérité complète, y compris le 12 mars et le rôle réel de Karim

## 7. Incohérences plantées (le carburant de `lucidite`)

| # | Où | Incohérence | Payoff |
|---|---|---|---|
| 1 | N10 (zoom récépissé) | Signalement daté de J-2 mois alors qu'elle « cherche depuis 7 mois » | Ch. 3 : confrontable — pourquoi 5 mois de silence ? |
| 2 | N13 (insister) | 50s d'hésitation + « J'hésitais à te dire un truc » | Ch. 3 : elle admet cacher quelque chose |
| 3 | N17 (réécoute vocal) | Son de fond urbain/radio alors qu'elle est censée être seule en zone déserte | Ch. 3 : où était-elle VRAIMENT ? (réponse ch. 4 : elle appelait depuis sa voiture garée ailleurs — elle avait déjà repéré les lieux une 3e fois qu'elle cache) |
| 4 | Ch. 2 (à écrire) | Karim « ne répond pas depuis des jours » selon Léna — mais son groupe se crée en 2 min au ch. 3 | Le joueur attentif note que Léna et Karim se parlaient déjà |

**Règle :** chaque incohérence a une explication canonique (colonne payoff). Aucune n'est un trou de scénario — Claude Code ne doit jamais les « corriger ».

## 8. Interactions cachées ch. 1 (récap)

Relance N8 (PROFIL_SUSPECT / BORNAGE) · Zoom récépissé N10 (lucidite) · Insister N13 (lucidite) · Zoom autocollant N16 (AUTOCOLLANT → Sentinel Pro) · Réécoute vocal N17 (lucidite) · Zoom téléphone N21 (TELEPHONE — coque rose fissurée : c'est bien le tel de Chloé, confirmé ch. 4).

## 9. Contraintes transverses

- **Ton général** : réalisme total, aucune rupture du 4e mur, l'IA (moments libres) ne mentionne jamais être une IA
- **Rythme** : ch. 1 sans friction (délais ≤ 90s, ellipses = séparateurs horaires) ; vraies attentes à partir du ch. 2 ; déblocage chapitre = 8h (premium : immédiat)
- **RGPD** : `detail_perso` = un seul élément anodin, consentement à la première saisie libre, effacement en cascade
- **Audio** : scripts TTS fournis dans les chapitres (texte + jeu + sons de fond porteurs d'indices), production par Vivien, stockage URL en base
- **Langue** : tout le contenu joueur en français

## 10. Ce qui reste à écrire

- Chapitres 2-5 en version nœud-par-nœud (structures validées, détails à produire après le moteur)
- Prompts système des moments IA ch. 3-5
- Textes des 3 fins + épilogue fin cachée
