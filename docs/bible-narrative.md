# BIBLE NARRATIVE — Numéro Inconnu
*Source de vérité du projet. Toute contribution (humaine ou Claude Code) doit être cohérente avec ce document. En cas de conflit, ce fichier gagne. Version 1.0 — chapitres 1 validé, 2-5 en structure.*

> **Modifications apportées à ce fichier**, sur autorisation explicite de Vivien.
> Ce document est en lecture seule par défaut ; chaque exception est listée ici.
>
> - **§3** — ancrage des dates sur le Jour J (jeudi 13 août 2026).
> - **§6** — grammaire des trois axes, variable `enquete`, règle « raisonner
>   n'est jamais puni ». Ajouté avec le chapitre 1 V3.1.

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

**Jour J = jeudi 13 août 2026.** L'histoire est explicitement datée, et la séquence d'intronisation
l'annonce au joueur dès le premier panneau. **Toute date figurant sur un média se calcule par
rapport au 13 août 2026, jamais par rapport à la date réelle du jour où l'on joue.** C'est ce qui
garde les incohérences plantées lisibles indéfiniment : sans ancrage, le récépissé du N10 aurait
dit « il y a 2 mois » en 2026, puis « il y a 14 mois » un an plus tard, et l'indice aurait changé
de sens tout seul.

Dates absolues qui en découlent :

| Repère | Date |
|---|---|
| Disparition de Chloé (J-7 mois) | mi-janvier 2026 (~12 janvier) |
| Dispute avec Léna (« le 12 mars ») | ⚠️ voir note ci-dessous |
| Premier signalement (J-2 mois) | **12 juin 2026** — la date du mail du N10 (62 jours avant J : bien « 2 mois ») |
| Disparition du porte-clés (J-3 semaines) | 23 juillet 2026 |
| **Jour J, chapitre 1** | **jeudi 13 août 2026, 22h47** |

📅 **Pourquoi le 13 et non le 14** : le 14 août 2026 tombe un **vendredi**. Or le chapitre affiche
« jeudi — 22h47 » en tout premier séparateur, et le suspect vient à l'entrepôt « tous les jeudis ».
Annoncer « jeudi 14 août » aurait posé une contradiction sur le premier écran du jeu. Le 13 août
2026 est bien un jeudi, et tout le reste de la chronologie se décale d'un jour sans conséquence.

⚠️ **Incohérence à arbitrer** : la dispute est datée « le 12 mars » et située « la veille » de la
disparition, mais la disparition tombe à J-7 mois, soit mi-janvier. Mars ≠ janvier. Cette date était
déjà dans la bible avant l'ancrage — l'ancrage ne fait que la rendre visible. Deux lectures
possibles : c'est une quatrième incohérence plantée (le 12 mars est ce que Léna *dit*, pas ce qui
s'est passé), ou c'est un simple écart à corriger. **À trancher par Vivien** — voir docs/TODO.md.

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
| `lucidite` | 0-5 ch. 1, extensible | Incohérences repérées (§7) **+ posture « raisonner »** |
| `enquete` | 0-10 (départ 0) | **Posture « enquêter » uniquement** — paliers 2 et 6 |
| `indices` | liste | Interactions cachées + choix d'enquête |
| `refus` | bool | Branche N11 |
| `branche_ch1` | code | Callbacks d'ouverture ch. 2 |
| `detail_perso` | texte (RGPD §9) | Moment IA N9 |
| `loyaute` (ch. 3+) | leña / karim / neutre | Ce que le joueur répercute du privé vers le groupe |

**La grammaire des trois axes** *(ajoutée en V3.1 — voir « Modifications » en tête de fichier)*

Chaque micro-choix offre trois options, toujours dans le même ordre : **protéger ·
enquêter · raisonner**. Aucune ne ramifie, aucune n'est étiquetée, et le joueur
ne sait jamais qu'il alimente quoi que ce soit.

Ce qui compte n'est pas *combien de fois* il a choisi un axe, mais **quelle
part** de ses micro-choix c'était. Un joueur qui raisonne aux trois quarts finit
au même endroit qu'il en ait rencontré vingt ou soixante — la posture est une
proportion, pas un compteur. La formule exacte est dans `docs/LOGIQUE.md`.

`enquete` mesure la **posture** (le joueur creuse-t-il ?), `indices` les
**découvertes**. On peut beaucoup chercher et trouver peu.

**Règle absolue : raisonner n'est jamais puni.** Douter ne fait jamais baisser la
`confiance`. Un joueur qui doute est un bon joueur — c'est lui qui trouve les
incohérences du §7. Le punir lui apprendrait à ne plus douter, et il raterait la
fin cachée.

**Fins (déterminées ch. 5) :**
1. **La sauver** : confiance ≥ 7 ET ≥ 3 indices — le joueur guide Léna dans la nuit finale
2. **Trop tard** : par défaut — vérité découverte, mais après le drame
3. **Fin cachée** : lucidite ≥ 4 ET a répondu à Chloé (ch. 5) — la vérité complète, y compris le 12 mars et le rôle réel de Karim

Aux chapitres 4-5, `enquete ≥ 2` ouvre les options d'enquête, `enquete ≥ 6` les
options avancées.

Le palier bas est ce qui rend la **rejouabilité visible** : un joueur ordinaire
doit ouvrir quelque chose, sinon il ne saura jamais qu'il y avait quelque chose
à ouvrir. Le palier haut récompense la posture assumée.

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
