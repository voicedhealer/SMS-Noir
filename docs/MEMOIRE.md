# MEMOIRE.md — journal de bord

*Fichier à lire en premier par toute nouvelle session Claude Code. Ordre antéchronologique : l'entrée la plus récente est en haut.*

---

## 2026-08-19 (7) — Refus de consentement au N9 : mécanisme prêt, contenu bloqué

Correction de Vivien sur une simplification que j'avais faite en expliquant la carte d'entrée :
« refuser l'IA n'empêche pas de lire l'histoire » était vrai sur le papier (le scripté continue
jusqu'à N22) mais trompeur en pratique — vérification du code a confirmé que `raccrocher()` sur un
refus n'applique **aucun effet** (`variables` inchangé, `detail_perso` toujours `null`), exactement
comme une panne d'API. Un joueur qui refuse était donc mécaniquement pénalisé par rapport à un
joueur qui accepte, sans jamais le savoir.

### Décision : un équivalent scripté, jamais un raccrochage

Nouvelle colonne `nodes.ai_refus_node_id` (migration `20260819180000_ai_refus_node.sql`), nullable
comme `ai_fallback_node_id` — désigne un nœud `scripted` ordinaire (bloc de micro-choix classique)
joué à la place de la saisie libre, avec ses propres `effects`. Générique et réutilisable : chaque
`ai_moment` futur (ch. 3, ch. 5) l'active en écrivant sa propre valeur, sans toucher au moteur.
Documenté comme pattern à part entière dans LOGIQUE.md § Le refus de consentement à un moment IA
(nouvelle section top-level, comme L'aparté), avec l'insistance de Vivien : **ne jamais confondre
refus explicite et panne technique** — deux routes distinctes, la seconde inchangée.

- `derouler()` (`moteur.ts`) : dès qu'un `ai_moment` est atteint avec `ai_consent_refuse` vrai et
  un `ai_refus_node_id` renseigné, le déroulé s'enchaîne directement dessus — le joueur ne voit
  **jamais** le champ de saisie libre. Sinon, comportement inchangé (breaks, attend la saisie).
- `ai-chat` garde sa propre branche `ai_consent_refuse` comme chemin de repli seulement (une
  progression antérieure à ce mécanisme) — factorisée avec `raccrocher()` via un nouveau
  `entrerNoeudEtRepondre()` partagé, pour ne pas dupliquer la construction de la réponse.
- La 3e ligne d'ouverture du N9 (demandée par Vivien pour basculer selon le consentement, pas
  seulement `refus`) : `derouler()` fusionne `ai_consent_refuse` dans une copie de `vars` **au
  seul appel qui délivre les messages**, jamais réinjectée dans les variables persistées — sinon
  ça polluerait `player_progress.variables` avec une clé qui fait déjà doublon (colonne à part).

### Bloqué : pas de texte reçu

Le message de Vivien annonçait « Texte ci-joint » pour les répliques du N9_refus (3e ligne
alternative + bloc micro-choix) mais aucun texte n'est arrivé. Rien n'est inventé à sa place
(règle 3) : `nodes.ai_refus_node_id` du N9 reste `null` pour l'instant, comportement historique
inchangé (raccrochage direct vers N21, comme avant ce chantier). Dès le texte reçu : nouveau nœud
scripté dans `docs/chapitre-1-v3.2.md` + régénération de la migration de contenu, variante
conditionnée de la 3e ligne du N9, câblage de `ai_refus_node_id`, et les tests qui vont avec
(`test-ai-moment.py` : nouveau scénario refus-avec-équivalent, sans casser les scénarios refus
existants qui couvrent le cas `ai_refus_node_id = null`).

### Vérification

Le mécanisme est neutre par défaut (`ai_refus_node_id` toujours `null` en base) : tous les tests
existants passent inchangés, y compris les scénarios de refus déjà couverts par `test-ai-moment.py`
(« Refus tenu jusqu'au N9 : elle raccroche directement » etc.) — confirme que rien n'a régressé
pendant que le mécanisme attend son contenu. `verify-graph.sql` 51/51 · `verify-fidelity.py`
114/114 · `simulate-playthrough.py` · `test-ai-moment.py` · `test-micro-choix.py`.

### Prochaine étape

Le texte de Vivien (3e ligne alternative du N9 + répliques du bloc micro-choix N9_refus), puis
reprise du chantier pour le contenu et son câblage.

---

## 2026-08-19 (6) — N21 : nouvelle photo, texte corrigé pour coller à la composition

Demande de Vivien : la photo de l'entrepôt fournie initialement décrivait un emplacement du
trousseau (« le mur, à droite, au-dessus de l'établi ») qui ne correspondait ni à l'ancienne
image ni à la nouvelle. Remplacement du média et correction du texte pour qu'ils s'accordent.

### Média : `photo-N21-porte-cles.jpeg` remplacé

Nouvelle composition : trousseau accroché à un crochet sur le mur en bois à gauche du cadre,
éclairé directement par une ampoule suspendue au-dessus — le point le plus lumineux de la photo.
Téléphone à coque rose toujours visible, discret, sur l'établi à droite.

Fichier déposé sous un nom temporaire (`N21 — l'entrepôt-new.jpeg`) à côté de l'ancien
(`N21 — l'entrepôt.jpeg`, qui matchait déjà par correspondance floue sur le code nœud dans
`upload-media.sh`) : les deux fichiers auraient rendu `trouver()` ambigu — deux noms contenant
« N21 ». Résolu en supprimant l'ancien et en renommant le nouveau vers le nom canonique
`photo-N21-porte-cles.jpeg` (déjà la clé de `generate-seed-content.py`), sur le même principe que
`photo-N16-plaque.png`. `messages.media_url` ne change donc pas de valeur — seul l'objet dans le
bucket change de contenu.

Vérifié aux pixels (crop + agrandissement) : les deux silhouettes gravées à la main sont nettes
au zoom ; le téléphone rose reste identifiable sur l'établi, dans le flou de vitre déjà voulu par
la mise en scène (« photo floue à travers une fenêtre »). `docs/TODO.md` § Livraison des médias et
`media/README.md` mis à jour pour décrire la nouvelle composition (crochet + ampoule comme repères
visuels de référence pour toute réplique future).

### Pas de « zone de zoom » à recaler — la mécanique n'en a pas

Vivien demandait de vérifier que la zone de zoom de l'interaction cachée suive la nouvelle
position du trousseau. Il n'existe pas de zone stockée : `PhotoViewer` (`message_widgets.dart`)
déclenche l'interaction sur **tout** pincement au-delà d'un seuil d'échelle (`scale > 1.15`), où
que le joueur touche l'image — `InteractiveViewer` générique, `maxScale: 5`. Rien à recaler côté
mécanique ; la seule chose qui compte est la lisibilité du détail une fois zoomé (voir plus haut),
couverte par `media/README.md` § Lisibilité au zoom.

### Texte : message commun ET micro-choix corrigés, source d'abord

Édité `docs/chapitre-1-v3.2.md` (source de vérité du contenu, pas la bible) avant la migration,
comme l'exige la règle 6 :
- Message commun (`N21#2`) : « Tu vois le trousseau, sur le crochet, juste sous la lumière ? Zoome
  sur le porte-clés. » — et sa variante vouvoiement (`refus = true`), déclinée mécaniquement
  (tu→vous) sur le même principe que les autres répliques du chapitre.
- Micro-choix 🧠 (« Qu'est-ce que je suis censé voir ? ») : la réponse ne révèle plus l'emplacement
  à l'avance — « Attends, je vais te guider, regarde bien l'image. »

**Piège trouvé en régénérant** : `scripts/generate-seed-content.py` régénère la plupart des
messages depuis le doc, mais les variantes tu/vous de `N21#2` sont dans une table Python à part
(`VARIANTES_REFUS` ou équivalent, ligne ~283) — éditer le seul doc n'aurait rien changé en base. Le
premier passage de régénération n'a mis à jour QUE le micro-choix (dérivé du doc) et a laissé
l'ancien texte du message commun (codé en dur dans le script). Corrigé en éditant aussi le script,
puis reconfirmé par un diff de migration propre sur les deux lignes attendues.

### Vérification

**Ordre important, découvert en cours de route** : `verify-graph.sql`, `verify-fidelity.py`,
`simulate-playthrough.py`, `test-micro-choix.py`, `test-ai-moment.py` doivent tourner **avant**
`scripts/upload-media.sh`, pas après. `signerMedias()` (moteur.ts) ne transforme `media_url` en URL
signée que si l'objet existe dans `storage.objects` — vide juste après un `db reset`. Une fois
`upload-media.sh` rejoué, la table se repeuple et `simulate-playthrough.py` échoue sur un contrôle
qui compare `media_url` à un nom de fichier brut (`lena-rentre-chez-elle.mp4`), puisqu'il devient
une URL signée. Pas une régression : reproduit et confirmé en isolant l'ordre (reset → suite de
tests → upload-media.sh en dernier, pour laisser le bucket dans son état réel de livraison).

`verify-graph.sql` 51/51 · `verify-fidelity.py` 114/114 · `simulate-playthrough.py` ✅ ·
`test-micro-choix.py` ✅ · `test-ai-moment.py` ✅ (dont le contrôle d'étanchéité sur `aparte`,
inchangé) · `test-migration-peuplee.py` ✅.

### Prochaine étape

Validation de Vivien — en particulier sur device pour la lisibilité du téléphone au zoom (le
README documente cette vérification comme ne se jugeant jamais sur écran d'ordinateur).

---

## 2026-08-19 (5) — L'apparté généralisé : `ContexteSaisieLibre` devient `nodes.aparte`

Correction de Vivien sur l'entrée (3) : la ligne de contexte du N9 avait été codée en dur pour le
mode `aiInput` (`mode == ComposerMode.aiInput` dans `conversation_screen.dart`). Elle ne doit rien
savoir du moment IA — n'importe quel nœud futur doit pouvoir en porter une, pour signaler un
silence volontaire, préciser un changement de contexte mineur, etc.

### Le même principe que l'écran noir narratif, appliqué différemment

« Piloté par le contenu, pas en dur dans le code » — mais pas de la même façon que la narration.
La narration est un **message** (elle arrive à une position, une fois). L'aparté est une
**propriété du nœud** (`nodes.aparte`, texte nullable) : valable tant que le joueur y est, affichée
avant chaque tour de saisie tant que le nœud courant en porte un. Un message aurait fallu le
rejouer à chaque tour avec une position à inventer pour un contenu qui ne change pas — mauvais
ajustement. Détail complet : LOGIQUE.md § L'aparté (nouvelle section, mécanisme serveur/client) et
DESIGN.md § L'aparté (nouvelle section indépendante, plus un détail du § champ de saisie).

### Fil des changements

- Migration `20260818174040_node_aparte.sql` (datée avant le contenu du chapitre 1, qui la
  consomme) : `alter table nodes add column aparte text`.
- `moteur.ts` : `aparte` ajouté au select de nœud et à `etatNoeud()` — transmise telle quelle, sans
  logique. Le commentaire en place est volontairement explicite : le serveur ne sait pas si le
  joueur est en train de lire un déroulé ou si Léna « écrit », cet état est purement client.
- `types.ts` (`ClientNode`) et `game_state.dart` (`StoryNode`) : champ ajouté des deux côtés.
- Contenu du N9 (`20260818174043_contenu_chapitre_1.sql`, bloc `update nodes` écrit à la main) :
  `aparte = 'Léna attend une vraie réponse...'` — vérifié que `generate-seed-content.py` ne touche
  pas à ce bloc et que la valeur survit à une régénération.
- `ContexteSaisieLibre` → `Aparte` (`widgets/message_widgets.dart`) : texte devient `required`, plus
  de valeur par défaut codée en dur.
- `ConversationState.aparteEnCours` (nouveau getter) remplace la condition sur le mode du composer
  dans `conversation_screen.dart` — même logique d'affichage (hors déroulé, hors typing) mais lue
  depuis `node?.aparte` plutôt qu'un cas particulier.

### Gardiens mis à jour

`test-ai-moment.py` : le test d'étanchéité sur les champs de `ClientNode` (liste exacte attendue)
a cassé dès l'ajout d'`aparte` — corrigé en l'ajoutant à la liste, plus un test de valeur
(« aparté transmis tel quel ») qui n'existait pas avant. Illustration directe de LOGIQUE.md
§ Quand une règle change, ses gardiens aussi.

### Vérification

Serveur : `verify-graph.sql` 51/51, `verify-fidelity.py` 114/114, `simulate-playthrough.py`,
`test-ai-moment.py` (dont le nouveau test de valeur sur `aparte`), `test-migration-peuplee.py`.
Client : `flutter analyze` propre, `flutter test` (groupe `ai_moment_test.dart` mis à jour pour le
renommage, mêmes assertions de disparition/réapparition qu'avant).

### Prochaine étape

Validation de Vivien. Rien de committé — la même règle que pour l'écran d'accueil (4) et l'icône
adaptative encore en attente de vérification manuelle.

---

## 2026-08-19 (4) — Écran d'accueil complet, à partir de `docs/prompts/prompt-ajout-ecran-accueil.md`

Reprend et remplace la carte d'entrée minimale de la veille (titre + accroche + tap) par la vraie
« pochette » de l'histoire décrite dans le prompt : image de couverture, icône, titre, accroche,
consentement IA inline, bouton — un seul écran, plus le duo carte-puis-`ConsentScreen`.

### Ce qui change par rapport à la veille : consentement fusionné, pas séquentiel

L'ancien flux : tap sur la carte → `ConsentScreen` (case obligatoire pour activer « Continuer »,
ou « Refuser » séparé). Le nouveau, demandé par le prompt : case et bouton « Entrer » sur le MÊME
écran, bouton **toujours actif** quel que soit l'état de la case — coché ou non, un tap envoie la
valeur et referme l'écran en un geste. `ConsentScreen` (le composant) n'est pas supprimé : il reste
le repli défensif de la première saisie libre du N9 (voir LOGIQUE.md § Consentement, inchangé), mais
`RootScreen` ne le montre plus jamais dans le flux normal.

### `stories.cover_url` : la colonne existait déjà, juste jamais branchée

Trouvé en lisant le schéma initial — pas de migration nécessaire. Il manquait seulement : le select
de `chargerHistoire`, l'exposition dans `get-state` (`signerObjet`, même mécanisme que la musique),
et le téléversement — `upload-media.sh` étendu avec un bloc dédié (`poser_story cover_url`, même
famille que le bloc musique, pas la boucle `MEDIAS` qui pose des `messages.media_url`).

Image fournie (`image_perso_ecran_accueil_num_iconnu.png`, silhouettes line-art gris, fond
**réellement transparent** — vérifié RGBA, alpha 0 aux coins, à la différence du fond blanc opaque
de l'icône de l'app la veille) déplacée vers `media/cover-numero-inconnu.png`, le nom que le prompt
attendait.

### Icône de l'app réutilisée DANS l'écran, pas seulement comme icône système

`assets/icon/icon.png` (déjà produite pour `flutter_launcher_icons`) ajoutée au bundle Flutter —
un seul fichier déclaré, pas tout `assets/icon/` : les deux autres (source brute, foreground
adaptatif) ne servent qu'à la génération d'icônes système, rien à faire dans l'app elle-même.

### Un vrai piège Flutter : `MediaQuery.of` interdit dans `initState`

Première version de l'animation d'entrée lisait `MediaQuery.of(context).disableAnimations` dans
`initState()`, pour savoir s'il fallait jouer le fondu ou tout montrer directement. Ça compile,
mais lève à l'exécution (« dependOnInheritedWidgetOfExactType... called before initState()
completed ») — attrapé par les tests, pas par `flutter analyze`. Déplacé dans
`didChangeDependencies()`, gardé par un drapeau pour ne s'exécuter qu'une fois même si la méthode
est rappelée plus tard.

### Vérification

Serveur : `verify-graph.sql` 51/51, `verify-fidelity.py` 114/114, `simulate-playthrough.py`,
`test-ai-moment.py` (consentement inchangé, y compris le test du chemin en amont de la veille).
Client : `flutter analyze` propre, `flutter test` 114/114 (nouveau groupe « Carte d'entrée » réécrit
pour le flux fusionné — plus de test sur un `ConsentScreen` intermédiaire, un nouveau test capture
le corps envoyé à `ai-chat` pour prouver que la case décochée envoie bien `{consent: false}` sans
jamais bloquer le bouton ; nouveau fichier `entry_card_screen_test.dart` pour l'animation, le
réglage de réduction des animations, et l'absence d'image de couverture).

**Premier smoke-test visuel réussi de la session** sur simulateur iOS : image, dégradé, icône,
titre, accroche, case décochée, lien souligné, bouton — tout au rendez-vous, cohérent avec le
mockup. Espace assez généreux entre l'accroche et la case de consentement sur cet écran (`Spacer()`
non contraint) : à resserrer si Vivien le juge trop lâche à l'usage, pas corrigé d'initiative.

### Prochaine étape

Validation de Vivien, notamment sur l'équilibre visuel (espacement) que le smoke-test a permis de
voir mais pas de juger à ma place.

---

## 2026-08-19 (3) — Deux précisions : ligne de contexte du N9, consentement avant l'intro

Deux corrections de Vivien sur des points antérieurs (prompt 3 / UI), traitées ensemble.

### 1. Ligne de contexte de la saisie libre : dans le fil, pas sous le champ

Nouveau widget `ContexteSaisieLibre` (`widgets/message_widgets.dart`) : « Léna attend une vraie
réponse... », gris, centré, plus petit que le texte normal — posé dans la liste défilable du fil
(`conversation_screen.dart`), sous la dernière bulle et avant la zone de choix. Jamais sous le champ
de saisie lui-même, qui ne doit jamais changer d'aspect selon le mode. Affichée quand
`mode == aiInput`, hors déroulé, hors typing — disparaît dès que Léna « écrit » ou que le joueur
envoie, réapparaît avant chaque tour suivant.

### 2. Consentement IA : déplacé avant l'intronisation, carte d'entrée minimale

Jusqu'ici demandé à la première saisie libre du N9 (`ConsentScreen` inline, déclenché par
`consent_required` côté `ai-chat`). Déplacé en amont : une carte d'entrée minimale (titre, accroche
si l'histoire en porte une, « Toucher pour entrer ») précède désormais tout, y compris le premier
panneau de l'intronisation — c'est elle qui porte le consentement, une fois pour toutes.

**Changement serveur non trivial** : `ai-chat` exigeait d'être *au* nœud `ai_moment` pour traiter
`{consent}` (`noeud.kind !== 'ai_moment'` levait `pas_un_moment_ia`). La carte d'entrée appelle ce
même endpoint alors que le joueur est encore au nœud d'entrée (N1) — il a fallu déplacer la branche
consentement AVANT cette garde, et simplifier `enregistrerConsentement` pour qu'elle n'exige plus un
nœud précis. Un seul point d'attention gardé : refuser alors qu'un `ai_moment` attend réellement une
réponse (chemin de repli, plus l'usage normal depuis la carte) raccroche toujours immédiatement,
comme avant — refuser depuis la carte d'entrée, elle, ne referme rien puisque rien n'est encore
engagé. Sans cette distinction, `test-ai-moment.py` (le test de consentement déjà existant, en
place avant cette session) aurait cassé : première tentative de refonte trop uniforme, corrigée
avant de committer.

`get-state` expose maintenant `story.tagline` et `ai_consent_decided` (`ai_consent_at` posé OU
`ai_consent_refuse` vrai) — c'est ce booléen serveur, jamais un drapeau local, qui fait réafficher
la carte d'entrée. Nouveau `screens/entry_card_screen.dart`, portée volontairement minimale : la
vraie bibliothèque (plusieurs histoires) l'absorbera plus tard, pas de raison de la construire
maintenant pour une seule histoire.

### Vérification

Serveur : `test-ai-moment.py` (le test de consentement existant, inchangé dans ses attentes, plus un
nouveau `consentement_amont()` couvrant l'appel depuis le nœud d'entrée — accepté et refusé, et le
refus qui tient jusqu'au N9) · `verify-graph.sql` 51/51 · `verify-fidelity.py` 114/114 ·
`simulate-playthrough.py` · `test-micro-choix.py` · `test-migration-peuplee.py` (en isolation).
Client : `flutter analyze` propre, `flutter test` 109/109 (108 + nouveaux tests sur la carte
d'entrée et la ligne de contexte, y compris sa disparition pendant l'attente réseau).

### Prochaine étape

Validation de Vivien. Comme pour les Phases B/C de l'addendum transition, la carte d'entrée et
l'écran de consentement n'ont pas été vus tourner sur device — mêmes limites d'automatisation de
tap sur cette machine.

---

## 2026-08-19 (2) — Addendum transition N20-N9, Phase C : visionneuse photo plein écran

Dernière phase de l'addendum (§3.1). Bug confirmé en lisant `PhotoViewer`
(`app/lib/widgets/message_widgets.dart`) : `Image.network(...)` n'avait ni `fit`
ni conteneur dimensionné, et rendait donc à sa taille intrinsèque à l'intérieur
d'`InteractiveViewer` — d'où le cadre visible autour de l'image une fois
agrandie, exactement ce que le rapport décrivait.

**Correctif** : le chemin image réelle passe maintenant par `SizedBox.expand`
+ `Image.network(fit: BoxFit.contain)`, avant même le zoom — comportement de
référence (iMessage, WhatsApp) : l'image occupe tout l'écran disponible sans
recadrage, fond noir uniforme si l'aspect ne correspond pas. Le chemin
placeholder (média pas encore produit) est inchangé dans l'esprit — cartouche
neutre, taille modeste, pas de raison de le forcer plein écran — juste
recentré (`Center`) pour rester cohérent avec le nouveau body.

**Pourquoi pas de test automatisé sur le chemin réel** : `Image.network` a
besoin d'une base (`Env.supabaseUrl`), qui lève une erreur si aucune n'est
configurée — ce qu'aucun test widget de ce projet ne fournit (même contrainte
déjà contournée par PhotoBubble/AudioBubble/VideoTransitionScreen, toujours
testés en `placeholder://`). Le correctif est donc vérifié par lecture du
code, pas par un test qui exercerait réellement `SizedBox.expand` +
`BoxFit.contain` — à la différence du chemin placeholder, qui lui est
couvert (`test/photo_viewer_test.dart`, 2 tests). Même limite que la lecture
vidéo réelle de la Phase B : pas d'outil de tap disponible sur cette machine
pour confirmer à l'œil sur device.

`flutter analyze` propre, `flutter test` 104/104 (102 + 2 nouveaux).

### Prochaine étape

Validation de Vivien — dernière phase de cet addendum. Les deux témoins
visuels dus (vidéo N9 de la Phase B, zoom photo de cette phase) restent à
confirmer en jouant sur device.

---

## 2026-08-19 — Addendum transition N20-N9, Phase B : écran de transition vidéo

Phase A validée par Vivien (deux ajustements appliqués, committée — voir entrée du 18/08). Cette
entrée couvre la Phase B : l'écran vidéo entre N20 et N9.

### Choix d'architecture : un message, pas un nœud

L'addendum §2 demandait un écran « même famille que l'écran noir narratif du N19 ». En lisant
comment le N19 est réellement implémenté (`content_type = 'narration'`, un message dans le fil, pas
une propriété de nœud — voir LOGIQUE.md § Écran noir narratif), la conséquence pratique est que la
vidéo n'a besoin ni d'un nœud dédié, ni d'un re-câblage des choix structurants du N20 : elle est
simplement la **position 0 du N9** (`content_type = 'video'`), et les deux choix du N20 continuent de
pointer directement vers `N9` comme avant. `derouler()` ne distingue pas les `content_type` — rien à
changer côté moteur, seulement la contrainte CHECK qui autorise la nouvelle valeur.

Différence avec la narration : pas de `body` JSON à décoder et superposer — le texte incrusté
(« Léna rentre chez elle. ») vit dans le fichier vidéo lui-même. Rien à synchroniser côté client.

La durée à l'écran suit le même principe que la narration : c'est le `delay_seconds` du message
SUIVANT (le texte de tutoiement, ex-N9#0 décalée en N9#1) qui la donne, pas un champ sur la vidéo
elle-même. Fixé à 6 s pour couvrir les 5,07 s réelles du fichier avec une marge — `SUITE` (5 s, la
valeur générique) l'aurait coupée court de 67 ms. `ENTREE['N9']` (l'ancien délai d'entrée, 15 s)
devient mort et a été retiré : la position 0 n'est plus un texte qui en aurait besoin.

### Différence côté client : pas de chrome de conversation

L'écran noir du N19 GARDE l'en-tête (nom, présence) : c'est ce qui vend l'absence de Léna pendant le
silence. La vidéo, elle, montre une scène — la garder aurait cassé l'effet plein écran demandé par
l'addendum (« vidéo en fond plein écran »). `ConversationScreen` masque donc l'AppBar quand
`videoEnCours != null`, en plus du swap de body déjà utilisé pour la narration.

### Un bug trouvé et corrigé le jour même : `upload-media.sh` a failli écraser la musique de fin

En ajoutant `media/lena-rentre-chez-elle.mp4` (la version traitée) au dossier `media/`, le fichier
source BRUT gardé à côté (`media/Léna rentre chez elle.mp4` — filigrane visible, audio non coupé,
défaut de continuité capillaire) s'est fait ramasser par le repli du script de téléversement
(« le seul .mp4 encore non réclamé », `trouver_musique`) et écrasé la vraie musique de fin de
chapitre (`Unmarked_Evidence.mp3`) sous le nom `fin-music.mp4`. Repéré en relisant la sortie du
script, pas anticipé à l'écriture. **Corrigé** : exclusion explicite du fichier brut dans
`trouver_musique()`, script relancé (`Unmarked_Evidence.mp3` reprend correctement `fin-music.mp3`),
objet `fin-music.mp4` orphelin supprimé du bucket local. N'a touché QUE le stack local — le projet
distant n'a jamais été lié ni sollicité cette session, donc rien à réparer côté hébergé.

### Vérification : verte côté back, incomplète côté visuel

`verify-graph.sql` 51/51 (5 médias au lieu de 4, 69 messages au lieu de 68) · `verify-fidelity.py`
(114/114, inchangé — la vidéo n'ajoute aucun texte) · `simulate-playthrough.py` (les deux chemins
vérifient explicitement que N9 s'ouvre sur la vidéo avant le texte de tutoiement/vouvoiement) ·
`test-micro-choix.py` · `test-migration-peuplee.py` (en isolation) · `flutter test` 102/102 (100
existants + 2 nouveaux sur `VideoTransitionScreen`, avec un média en `placeholder://` pour éviter
toute lecture réseau réelle en test widget — même convention que PhotoBubble/AudioBubble).

`video_player` ajouté à `pubspec.yaml` (2.11.1) ; `flutter analyze` propre ; l'app **démarre et
tourne** sur simulateur iOS avec le nouveau plugin natif (pod résolu, aucun crash au lancement, testé
jusqu'au N1). **Non vérifié visuellement à l'écran N9 lui-même** : aucun outil d'automatisation de
tap n'est disponible sur cette machine (même limite déjà notée dans le journal du prompt 2 — accès
d'aide non autorisé), et dérouler les ~20 nœuds jusqu'au N9 à la main dépasse le raisonnable pour
cette session. Le mécanisme est vérifié bout en bout côté serveur (le bon message vidéo, avec le bon
`media_url`, arrive bien en position 0 du N9, sur les deux branches `refus`) et côté rendu isolé
(widget test : fond noir, aucune interaction) — seule la lecture vidéo RÉELLE sur device n'a pas
d'témoin visuel dans cette session. À confirmer par Vivien en jouant la partie jusqu'au N9.

### Prochaine étape

Validation de Vivien sur la Phase B (notamment la lecture vidéo réelle, que je n'ai pas pu observer)
→ **Phase C** (visionneuse photo plein écran, `PhotoViewer`).

---

## 2026-08-18 — Addendum transition N20-N9 : **Phase A terminée, en attente de validation**

Suite au premier test complet de la V3.2 sur appareil (`docs/prompts/addendum-transition-n20-n9.md`).
Découpage en 3 phases (validé par Vivien) : **A** contenu N20/N9, **B** écran de transition vidéo,
**C** correctif visionneuse photo. Cette entrée couvre la Phase A.

### Le média fourni ne correspondait pas à sa description — trois écarts, tranchés un par un

`lena-rentre-chez-elle.mp4` annoncé « ~8s » : en réalité **5,07 s** (`ffprobe`). Piste audio AAC
présente alors que l'addendum la croyait déjà coupée : retirée à la source (`-an`), pas comptée sur
un mute côté lecteur. Deux défauts non mentionnés par l'addendum, remontés puis tranchés par Vivien :
filigrane « CapCut AI » en haut à gauche → **recadré** (`crop=2560:1290:0:150`, sécurité vérifiée sur
5 frames : la tête du sujet ne descend jamais sous 250 px de la zone coupée) ; la couleur des cheveux
change 3 fois en 5 s (artefact de génération IA) → **gardé tel quel**, décision explicite de Vivien
après explication du risque pour l'illusion « indiscernable d'une vraie messagerie ». Fichier traité :
`media/lena-rentre-chez-elle.mp4`. Pas encore uploadé (Storage = Phase B).

### Le contenu : tutoiement déplacé du N20 au N9

Le N20 redevient sobre (retour + état de choc, vouvoiement). Tutoiement, remerciement et demande de
prénom se déplacent à l'ouverture du N9. Mécanisme neuf : **`messages.conditions`** (migration
`20260818174042_message_conditions.sql`), même format et même évaluateur que `choices.conditions` —
voir LOGIQUE.md § `messages.conditions`. N9#0 porte deux variantes (tutoiement demandé si
`refus=false`, vouvoiement maintenu si `refus=true`), vérifiées explicitement par
`simulate-playthrough.py` (les deux chemins, pas seulement l'un des deux).

Deux pièges pendant l'implémentation, tous deux corrigés dans la foulée :
- La contrainte `unique (node_id, position)` sur `messages` empêchait deux variantes à la même
  position — retirée dans la même migration, avec commentaire expliquant pourquoi l'exclusivité
  mutuelle n'est pas vérifiable en SQL déclaratif (elle dépend des variables runtime).
- Le doc avait d'abord noté les choix structurants du N20 comme `→ *(transition)* → N9` en
  anticipant la Phase B — mais l'écran de transition n'existe pas encore, donc le générateur ne
  savait pas résoudre la cible. Remis en `→ N9` direct ; la Phase B repointera ces deux choix vers
  l'écran de transition quand il existera.

### Deux défauts pré-existants trouvés en passant — arbitrage de Vivien

Confirmé en comparant contre l'état du dernier commit (`git stash` puis rejeu), donc antérieurs à
l'addendum :
- `test-ai-moment.py` : sur le chemin « allié » (protéger constant), la confiance atteint déjà 9
  avant le N9, et le bonus « sincère » (+2, serveur) se heurte au plafond global de 10 (`engine.ts`,
  `confiance: { min: 0, max: 10 }`). **Ce n'est pas un bug, le plafond fait son travail** — le test
  supposait à tort un delta fixe. **Corrigé** : `apres_gain()` calcule `min(avant + gain, plafond)`,
  les deux assertions du parcours nominal court visent désormais la saturation plutôt qu'un +2 sec.
  Le plafond lui-même n'a pas bougé.
- `test-migration-peuplee.py` attendait `63` micro-choix ; le contenu réel (confirmé par
  `verify-graph.sql` #45/#46, qui lui est à jour : 93 choix − 33 hors micro = 60) en compte 60 depuis
  un ajustement d'une phase antérieure jamais répercuté ici. **Corrigé** (chiffre stale, pas un
  désaccord de fond) : `63` → `60`.

Repéré en le relançant, sans rapport avec la Phase A : le test de quota de `test-ai-moment.py`
compare le jour calculé côté Python (`date.today()`, horloge locale) au jour calculé côté Edge
Function (`new Date().toISOString()`, horloge Docker en UTC). Juste après minuit heure locale (CEST,
donc encore la veille en UTC), les deux jours divergent et le test échoue faussement. Rien à corriger
dans le contenu ni le moteur — se résorbe de lui-même une fois passé minuit UTC. Pas dans le
périmètre des deux ajustements demandés.

### N21/N22 : le mécanisme messages.conditions étendu à leur tour

Signalé en fin de Phase A comme « hors périmètre », **requalifié par Vivien en conséquence directe**
du mécanisme qu'on vient de construire : avant l'addendum, l'incohérence tutoiement/N21-N22 sur
`refus=true` passait inaperçue parce que le N20 (vouvoiement) précédait de loin ; maintenant que le
N9 conditionne explicitement la bascule, laisser N21/N22 tutoyer envers un joueur qui a refusé casse
la continuité pile après le nœud qui vient de la poser. Traité avec le même mécanisme que N9#0, sans
réécriture de fond — pure déclinaison grammaticale tu → vous sur les trois répliques concernées :
N21#0 (« Je t'ai pas dit... »), N21#2 (« Tu vois le trousseau... »), N22#1 (« Je t'explique... »).
Volontairement limité aux `messages` : les micro-choix de N21/N22 (`choices.inline_response`)
restent en tutoiement, le mécanisme réutilisé ne couvre pas `choices`. Voir LOGIQUE.md
§ `messages.conditions`.

### Suite de vérification, complète et verte (Phase A, version finale)

`verify-graph.sql` 51/51 (68 messages au lieu de 65 : N9#0, N21#0, N21#2, N22#1 portent chacune 2
variantes) · `verify-fidelity.py` (114/114) · `simulate-playthrough.py` (chemins allié et refus,
variantes N9, N21 et N22 toutes vérifiées explicitement sur les deux chemins, pas seulement
supposées correctes) · `test-micro-choix.py` · `test-migration-peuplee.py` (en isolation après
`db reset` — le compteur de consentements est sensible à l'ordre d'exécution des scripts sur une
même base, à ne jamais lancer après une autre suite sans reset entre les deux) · `flutter test`
(100/100). Prompt système IA (N9) relu : suppose déjà le prénom demandé à l'ouverture du N9 et
l'heure « une heure du matin » — cohérent avec la nouvelle structure sans modification.

`probe-lena.py` (vrai modèle) non relancé : rien dans la Phase A ne touche au prompt système ou au
comportement conversationnel, seul le contenu scripté change.

### Prochaine étape

Phase A validée par Vivien, committée → **Phase B** (écran de transition vidéo) puis **Phase C**
(visionneuse photo plein écran).

---

## 2026-08-16 (2) — PROMPT 3, Phase 0 (audit du moment IA) : **TERMINÉE, en attente de validation**

### L'existant est en place

`nodes.ai_system_prompt` seedé (726 caractères, verbatim des consignes du chapitre) ·
`kind='ai_moment'` · `ai_fallback_node_id` → N21 · `ai_max_exchanges = 4` · table `ai_usage`
(`user_id`, `day`, `exchanges`) avec RLS · `player_messages.source` accepte déjà `ai` et
`player_free` · le chemin `continue` traverse déjà le N9 par son fallback, exercé par la simulation.

**Cascades RGPD vérifiées** : `player_progress → users` en CASCADE (donc `detail_perso`),
`player_messages → player_progress` en CASCADE, `ai_usage → users` en CASCADE. Supprimer le compte
purge tout.

### Le manque qui compte : rien ne compte les échanges d'un moment

`ai_usage` compte par **jour**, pour le quota. Rien ne mémorise où l'on en est **dans ce
moment-là**. Un joueur qui ferme l'app au 3ᵉ échange et revient repartirait à zéro — et pourrait
tourner indéfiniment. Il faut `player_progress.ai_exchanges`, remis à zéro à l'entrée du nœud.
C'est la seule vraie lacune structurelle de l'audit (TODO A5).

### Le point où je m'écarte du prompt

Le prompt demande une **liste d'exclusion** pour `detail_perso`. Sur du texte libre, une liste
d'exclusion ne rattrape que ce qu'on a prévu : « je suis en rémission » ou « je vais à la mosquée le
vendredi » passeraient. Je propose l'inverse — le modèle renvoie une **catégorie**, et le serveur
n'accepte que `prenom`/`ville`/`metier`/`animal`. Une liste d'autorisation ferme par défaut ; la
liste d'exclusion reste en second filet. Voir TODO A3.

### Décisions proposées

Modèle `mistral-small-latest` (le N9 tient à la qualité de suivi d'instruction, pas à la
puissance) · détection de sortie de cadre **en couches**, pré-filtre serveur avant l'appel ·
consentement **en base** (`ai_consent_at`), auditable et purgé avec le compte · coûts journalisés
en colonnes plutôt qu'en `console.log`.

### Prochaine étape

Validation de A1→A6 → **Phase 1** : prompt système définitif, Edge Function `ai-chat`, mode dégradé.

---

## 2026-08-16 — PROMPT 2, Phase 3 : **TERMINÉE, en attente de validation**

Séquence d'intronisation, interactions cachées, liste des conversations, écran de fin. 45 tests.

### La trouvaille de la phase : une règle plutôt qu'une table

Le client ne connaît pas le graphe — il ne peut donc pas dire « au N16, c'est un zoom ». La règle
se déduit du contrat et couvre les six interactions sans exception :

> Si le nœud courant a apporté un **média**, l'interaction se déclenche par le geste sur ce média.
> Sinon, c'est une chose que le joueur **dit**, et elle passe par le « + » discret.

N10/N16/N21 → zoom · N17 → réécoute · N8/N13 → « + ». Aucun code de nœud dans le code Dart.
Seul le **dernier** média du fil est actif : zoomer une vieille photo ne déclenche rien.

### Deux défauts d'affichage vus à l'écran, pas par les tests

- `AnimatedSwitcher` **centre son enfant par défaut** : le nom du contact se retrouvait au milieu
  de la ligne dans la liste. Corrigé par un `layoutBuilder` aligné à gauche, aux deux endroits.
- L'aperçu du dernier message était **vide** en fin de chapitre : le dernier message du N22 est un
  `system`, qui ne s'affiche pas. On remonte désormais jusqu'au dernier vrai contenu.

Aucun test ne les aurait attrapés — ils ne cassaient rien, ils étaient juste faux à l'œil.

### Reste

La recette manuelle est partielle : les six interactions n'ont pas été jouées **au doigt** (pas
d'autorisation d'accès d'aide sur cette machine pour automatiser un tap). Couvertes par les tests
widget, à confirmer par Vivien.

---

## 2026-08-15 (2) — Chaîne des médias : bucket, upload, URLs signées

Préparée pendant que Vivien produit les fichiers. **Testée de bout en bout avec des fichiers
factices**, puis placeholders restaurés — il n'y aura qu'à déposer les vrais et lancer une commande.

- Migration `media_bucket` : bucket **privé**. Un bucket public aurait exposé
  `photo-N21-porte-cles.jpg` — la révélation de fin de chapitre — à qui tape l'URL. C'eût été le
  seul trou dans une architecture entièrement bâtie sur l'anti-spoiler.
- `messages.media_url` stocke un **chemin d'objet** ; les Edge Functions le signent (6 h) au moment
  de répondre, et uniquement pour les messages déjà reçus.
- `scripts/upload-media.sh` : téléverse et remplace les placeholders. Rejouable, tolère les fichiers
  livrés un par un.
- `media/README.md` : specs, pièges de production, et la contrainte de lisibilité au zoom.

### Deux pièges trouvés en testant

1. **Le délimiteur `:` de mon tableau bash entrait en collision avec le `://` du placeholder** :
   `${entree%%:*}` renvoyait `placeholder`, l'update ne matchait rien, et les uploads réussissaient
   quand même — un échec parfaitement silencieux. Le placeholder se déduit désormais du nom de base.
2. **Supabase se signe lui-même sur `http://kong:8000`**, son hôte interne : l'URL était valide et
   inutilisable depuis un téléphone. Le serveur renvoie maintenant un **chemin relatif**, que le
   client préfixe avec sa propre base — ce qui règle du même coup le `10.0.2.2` de l'émulateur.

Vérifié : chemin signé téléchargeable depuis la base client (HTTP 200), et refusé sans jeton
(HTTP 400) — le bucket est bien privé.

---

## 2026-08-15 — PROMPT 2, Phase 2 (écran de conversation) : **TERMINÉE, en attente de validation**

D5 et D6 validées. Deux colonnes `phantom_typing_at` / `haptic_at` en base, seedées sur N20#0 (45 et
60), sémantique documentée dans LOGIQUE.md. Temps de fiction : mécanisme retenu, l'horloge ancrée sur
les séparateurs.

### Ce qui existe

`services/playback.dart` (moteur de déroulé), `services/fiction_clock.dart`,
`services/local_store.dart`, `widgets/message_widgets.dart`, `widgets/composer.dart`,
`providers/conversation_controller.dart`, `screens/conversation_screen.dart`.
**39 tests verts** (16 contrat, 14 déroulé + horloge, 9 widget), `flutter analyze` propre,
écran vérifié sur simulateur iOS.

### Le temps de fiction, sans coût de contenu

Plutôt qu'une colonne `fiction_time` sur chaque message — 68 valeurs à seeder, une à oublier à
chaque chapitre — l'horloge se dérive du fil : **chaque séparateur réancre, chaque message avance
l'horloge de son `delay_seconds`**. Déterministe (aucune horloge réelle n'entre en jeu), donc
identique au premier affichage et après rechargement, et la dérive ne peut jamais dépasser une
ellipse puisque le séparateur suivant recale.

Vérifié à l'écran : la barre d'état du simulateur affiche 12:23 pendant que les bulles portent 22h47.

### Deux pièges rencontrés

1. **Mon horloge de test sérialisait les attentes concurrentes.** Le moteur en a plusieurs en
   parallèle — le délai d'un message, et par-dessus les rafales de typing. En les faisant avancer
   l'une après l'autre, le test des rafales échouait pour une mauvaise raison. Les attentes avancent
   désormais **ensemble**. Sans ce correctif, j'aurais « corrigé » un moteur qui allait bien.
2. **Riverpod interdit de toucher à `state` pendant un cycle de vie.** `onDispose` appelait
   `interrompre()`, qui publiait l'état : les 9 tests widget tombaient d'un coup. La publication est
   coupée avant l'interruption.

### Décisions

- **Le mode du champ de saisie se déduit du contrat**, jamais du graphe : `ai_moment` → `aiInput`,
  aucune réponse mais `can_continue` → `continuation`, sinon `decorative`.
- **Le curseur d'affichage ET la file en attente** sont persistés localement. Le serveur écrit tous
  les messages d'un nœud dès son entrée : sans la file (avec ses délais), une reprise après
  fermeture afficherait la fin du N19 d'un bloc.
- **Le lecteur audio simule la lecture** — les fichiers n'existent pas. Son signal de *réécoute* est
  en revanche réel : c'est lui qui portera l'interaction cachée du N17 en Phase 3.

### Non vérifié

Le déroulé n'a pas pu être observé **en vol sur l'appareil** : automatiser un tap sur le simulateur
demande l'autorisation d'accès d'aide de macOS, refusée ici. Le comportement est couvert par les
tests widget (choix masqués pendant le déroulé, typing sur les dernières secondes, messages dans
l'ordre, retour des choix). À confirmer à la main lors de la recette de Phase 3, qui la prévoit.

### Prochaine étape

**Phase 3** : les 6 interactions cachées, la liste des conversations, l'écran de fin, et la recette
manuelle des deux parties sur émulateur.

---

## 2026-08-14 (7) — PROMPT 2, Phase 1 (squelette, modèles, client API) : **TERMINÉE, validée** (commit `964d2c4`)

### Ce qui existe

`app/` — projet Flutter 3.41.9, Riverpod, arborescence `config / models / services / providers /
theme / screens / widgets`. Modèles typés depuis le **contrat**, client API avec les 8 codes
d'erreur, session anonyme, thème sombre complet, **DESIGN.md rédigé** (il n'était qu'un squelette).
16 tests unitaires verts, `flutter analyze` propre, app lancée et vérifiée sur simulateur iOS.

### Trois vrais bugs trouvés, dont deux invisibles autrement

1. **Accents corrompus (UTF-8).** Un test a échoué sur « Numéro » : sans `charset` dans le
   `Content-Type`, le paquet `http` de Dart décode en **latin1**. En production « Léna » se serait
   affichée « LÃ©na » — dans TOUT le contenu du jeu. Corrigé des deux côtés : `charset=utf-8`
   côté serveur, et `utf8.decode(bodyBytes)` côté client pour ne dépendre de personne.
2. **GRANT manquants après mise à jour de la CLI.** Les privilèges par défaut du rôle `postgres`
   n'accordent pas `SELECT` aux rôles API : les tables devenaient illisibles **même en
   `service_role`** (erreur 42501), donc les Edge Functions ne voyaient plus l'histoire. Migration
   `explicit_grants` : le schéma déclare désormais lui-même qui a droit à quoi. Bénéfice de bord —
   le contenu narratif est maintenant refusé *avant* la RLS, deux verrous au lieu d'un.
3. **Session persistée invalide.** Après régénération des clés, l'app restaurait une session signée
   par une paire que le serveur ne reconnaissait plus, et affichait une erreur au lancement.
   `sessionProvider` **vérifie** désormais la session avant de s'en servir, la rafraîchit si elle a
   expiré, et repart sur une connexion anonyme propre si elle est morte. Cas réel, pas artefact.

### La mise à jour de CLI n'était pas optionnelle

`supabase stop` / `start` a régénéré les clés de signature en **ES256** (asymétriques). La CLI 2.75
ne savait pas les valider : sa propre passerelle rejetait les jetons émis par sa propre auth
(`{"msg":"Invalid JWT"}`). Passage en **2.114.0**. À retenir : sur cette pile, un redémarrage peut
changer le format des jetons — si tout tombe en 401 d'un coup, regarder l'`alg` du JWT avant de
chercher ailleurs.

### Décisions de conception

- **Riverpod** : l'état de jeu est asynchrone, dérivé et invalidé en bloc à chaque
  resynchronisation. `FutureProvider` + `invalidate` dit exactement ça.
- **`EngineApi` prend un fournisseur de jeton, pas un `SupabaseClient`** : testable sans initialiser
  toute la pile.
- **Politique de rejeu asymétrique** : un `choice_id` est retenté (le serveur est idempotent
  dessus), **`continue` ne l'est jamais** — le serveur n'a pas de clé d'idempotence pour lui, et un
  rejeu ferait avancer deux fois. En cas d'échec, on resynchronise sur `get-state`.
- **Anti-double-tap** dans le service : deux appels concurrents partagent le même `Future`.
- **Aucune police embarquée** : SF Pro / Roboto système. C'est ce qui vend l'illusion.

### Prochaine étape

Validation → **Phase 2** : écran de conversation, moteur de déroulé temporel, zone de choix,
bouton skip debug, widget-tests sur le déroulé.
D5 (typing fantôme) et D6 (« vu 00h29 ») restent en attente d'arbitrage — ni l'une ni l'autre ne
bloquait la Phase 1.

---

## 2026-08-14 (6) — PROMPT 2, Phase 0 (audit app Flutter) : **TERMINÉE, validée**

### Environnement

Flutter **3.41.9** stable / Dart 3.11.5 · Xcode **26.6** · Android SDK **36.1.0** · 2 émulateurs
(iOS Simulator, Medium Phone API 36.1) · `flutter doctor` tout vert. Stack Supabase et Edge
Functions actives en local (`get-state` répond 401 sans jeton : normal).

🔴 **`enable_anonymous_sign_ins = false`** dans `supabase/config.toml`. L'auth anonyme est le choix
retenu pour le MVP : à activer en Phase 1.

### Le contrat correspond à la réalité

Les payloads de `get-state` et `advance` ont été capturés sur une partie réelle et confrontés à
LOGIQUE.md § Contrat : **conforme**, y compris les cas particuliers (image, audio, séparateur,
system, `awaiting_interaction`, `ai_moment_pending`, `chapter_end`). Aucun `next_node_id`,
`effects`, `conditions` ni variable ne transite.

### Six écarts / angles morts relevés

1. **Reprise après arrière-plan — le vrai trou.** Le serveur écrit *tous* les messages d'un nœud
   dès son entrée. `get-state` ne dit donc pas où le client s'était arrêté d'afficher : si l'app
   meurt pendant les 90 s du N19, la réouverture fait apparaître la fin du nœud d'un bloc.
   `player_progress.current_message_position` existe dans le schéma mais n'a jamais été utilisé.
   → Décision D4, ci-dessous.
2. **Les interactions arrivent dans le même tableau `choices` que les réponses.** Au N17, le label
   de l'interaction est `« C'est quoi ce bruit derrière vous ? »` : l'afficher comme un bouton
   **donnerait l'indice gratuitement**. Le client doit impérativement filtrer sur `kind`.
3. **Deux natures de `label` pour `kind='interaction'`** : un geste (« Zoomer sur l'autocollant »,
   jamais affiché) ou une réplique du joueur (« C'est quoi ce bruit… », affichée seulement après
   la réécoute). Le client ne peut pas les distinguer par le contrat — il les traite par nœud.
4. **`system` n'est jamais une bulle**, et recouvre deux choses : présence (« Léna est hors ligne »,
   N19) et écran de fin (N22#4). Règle proposée : `system` + `node.kind == 'chapter_end'` → plein
   écran, sinon → statut de présence.
5. **`push_notification: true` avec `push_text: null` sur 5 des 6 messages concernés** (seul le N11
   a un texte). Un repli sera nécessaire au prompt 4.
6. **`seq` est un `bigserial` global**, partagé entre tous les joueurs (observé : 1 → 319 sur
   6 parties). C'est un ordinal croissant opaque, **pas** un index de message : ne jamais s'en
   servir pour calculer une position.

### Signal exploitable trouvé en base

Le typing intermittent n'a pas besoin d'un nouveau champ : **`typing_seconds >= 15` isole
exactement N2#0 (40/40) et N13#0 (50/50)**, les deux hésitations décrites par le chapitre. Partout
ailleurs `typing_seconds = 3`.

### Décisions UI

Vivien a fourni un **addendum** (`docs/prompts/addenum-au -prompt-2.md`) qui tranche D1 et D2 d'un
seul geste : le **champ de saisie toujours actif**, avec trois modes visuellement identiques
(`decorative` / `continuation` / `ai_input`). Écrire n'importe quoi fait avancer un nœud en pause —
donc aucun bouton « continuer », donc rien qui trahisse l'existence d'une interaction cachée.
Ma proposition d'auto-continuation temporisée survit uniquement comme **fallback** (25 s) pour le
joueur qui ne touche à rien.

Le mode se déduit entièrement du contrat serveur : le client n'a toujours aucune connaissance du
graphe.

Restent **quatre points ouverts** (TODO.md § Décisions UI) : D3 (typing intermittent),
D4 (curseur d'affichage local), et deux soulevés par l'intégration de l'addendum —
**D5** (mécanisme du typing fantôme, arbitrage explicitement demandé) et **D6** (« vu 00h29 » est
une heure de fiction que le client ne peut pas connaître).

### Deux conséquences techniques de l'addendum, faciles à rater

- **Un message décoratif n'existe pas côté serveur.** `get-state` ne le renverra jamais : pour
  qu'il reste à sa place dans le fil après redémarrage, il doit être **ancré au dernier `seq`
  serveur connu** au moment de l'écriture, puis ré-intercalé. Même stockage local que D4.
- **Ces textes libres ne quittent jamais l'appareil.** C'est bon pour le RGPD, et ça vaut aussi au
  prompt 3 : `ai-chat` ne doit recevoir que la saisie du mode `ai_input`, jamais l'historique
  décoratif — le serveur ne le connaît pas, il ne doit pas se mettre à le connaître.

### Prochaine étape

Validation des 4 décisions → **Phase 1** : projet Flutter, modèles, client API, thème, DESIGN.md.

---

## 2026-08-14 (5/5) — Phase 3 (Edge Functions) : **TERMINÉE, validée** (commit `6097b0f`)

### Ce qui a été fait

- `get-state` et `advance`, avec un `_shared/` en 4 morceaux : `types.ts` (contrat client),
  `engine.ts` (effects / conditions / plafonds, **sans dépendance Supabase, testable seul**),
  `moteur.ts` (base + parcours du graphe), `http.ts` (CORS, erreurs typées).
- Migration `20260814194049_advance_idempotency.sql` : `last_choice_id` + `last_choice_seq`.
- `scripts/simulate-playthrough.py` : **47 contrôles**, tous OK.

### Trois décisions de conception

1. **`advance` déroule la chaîne** des transitions automatiques d'un seul appel et s'arrête là où
   le joueur doit agir. Sinon le client devrait enchaîner N5 → N8 lui-même, donc connaître le graphe.
2. **`{continue: true}`** en seconde forme d'entrée : indispensable pour les nœuds en pause sur
   interaction (N13, N16, N21) que le joueur ne veut pas explorer. Sans ça, il resterait bloqué.
3. **`continue` sur un `ai_moment` emprunte `ai_fallback_node_id`.** Sans ça, **aucune partie ne
   pouvait franchir le N9** avant le prompt 3 — donc aucune simulation complète. C'est le chemin
   déjà prévu pour « IA indisponible », on ne fait que l'emprunter.

### Le contrat qui a demandé un arbitrage

`ClientNode` ne porte **pas** ses messages. Ils sont déjà dans l'historique au moment où le nœud
est atteint : `advance` les renvoie avec leurs délais (le client joue les timers), `get-state` les
rend via `history` avec des délais à 0 (rejeu instantané). Les porter aux deux endroits aurait
conduit le client à rejouer les timers de messages déjà vus à chaque réouverture de l'app.

### Ce que la simulation prouve vraiment

Le parcours « refus » est construit pour que les gains de confiance vaillent **7** : le test échoue
si le plafond à 6 saute. C'est le garde-fou de la règle la plus facile à casser par inadvertance,
puisqu'elle ne vit nulle part dans le contenu. Le script inspecte aussi les réponses brutes pour
confirmer qu'aucun `next_node_id`, `effects`, `conditions` ni variable ne fuit.

### Pièges rencontrés

- Un helper `contactDuFil()` écrit avec un cache module jamais alimenté aurait planté au premier
  appel. Remplacé par `contactDuNoeud()`, qui résout le fil par le locuteur des messages du nœud —
  et qui fonctionnera tel quel au ch. 3, quand un nœud appartiendra au fil de Karim.
- `--no-verify-jwt` sur `functions serve` ne dispense pas d'un vrai jeton : le code appelle
  `auth.getUser()` lui-même. Le script crée donc un vrai utilisateur via l'API admin.

### Clôture — Q7 et Q8 refermées

- **Q7** : la réplique de révélation est ajoutée au **N6** avec son ton propre (« Léna. Je m'appelle
  Léna, tant qu'à vous déranger. ») — Léna y a été rembarrée puis revient, elle est plus formelle.
  Les **trois** branches vers le N8 révèlent donc le prénom, chacune à sa manière. Un contrôle
  (n° 54) interdit désormais toute route de N1 à N22 qui éviterait un nœud de révélation.
- **Q8** : `docs/chapitre-1-v2.md` est patché en **V2.1**, avec un encadré en tête qui explique le
  quoi et le pourquoi. Une source de vérité qui diverge de la base est pire que pas de source.
- `scripts/verify-fidelity.py` compare désormais les deux **dans les deux sens** : 58 = 58.
  À relancer après toute modification du chapitre ou du seed.

### Prochaine étape

**Prompt 1 terminé.** Restent les prompts 2 (Flutter), 3 (`ai-chat`), 4 (notifications, cron,
premium). Aucune question ouverte. Points d'entrée de la prochaine session listés dans TODO.md.

---

## 2026-08-14 (4/5) — Phase 2 (seed du chapitre 1) : **TERMINÉE, validée** (commit `0580fad`)

Écart C validé par Vivien (`contact_id` = fil de conversation). Phase 1 committée (`051384c`).

### Ce qui a été fait

- `supabase/seed.sql` — **SQL et non TypeScript** : Deno n'est pas installé, `db reset` exécute
  `seed.sql` automatiquement (une commande reproduit tout l'état), et le contenu est statique donc
  versionnable et diffable à côté de la migration.
- Seedé : histoire (`draft`), contact Léna, chapitre 1, **stub du chapitre 2**, **21 nœuds**,
  **65 messages**, **33 choix** (23 reply / 3 ignore / **7 interaction**), N9 `ai_moment`
  (prompt verbatim, fallback N21, 4 échanges), N22 `chapter_end`.
- `scripts/verify-graph.sql` — **36 contrôles**, tous OK depuis un `db reset` propre.

### Le piège qui a coûté le plus de temps

Le seed passait en `psql` mais **échouait sous `supabase db reset`** :
`function _seed_node(unknown) does not exist`.

Cause : **la CLI Supabase envoie le fichier en batch**, donc toutes les requêtes sont *analysées*
avant que la première ne s'exécute. Une fonction créée dans le fichier n'existe pas encore au
moment où les requêtes suivantes sont analysées — alors qu'en `psql`, chaque requête est envoyée
et exécutée séquentiellement, et ça marche.

**Règle à retenir : jamais de `create function` utilisée dans le même fichier de seed.** Les nœuds
sont désormais résolus par jointure sur `code`. Corollaire : tester le seed avec
`supabase db reset`, jamais seulement avec `psql`, sinon le bug reste invisible.

### Fidélité du texte au chapitre (règle 6) — vérifiée automatiquement

54 répliques de Léna extraites de `chapitre-1-v2.md` et comparées à la base :
**52 retrouvées à l'identique en messages, 2 en `inline_response`**, plus les **4 réponses inline**
des interactions, mot pour mot. Zéro divergence, zéro reformulation.

### Décisions de seed (paramètres techniques, pas du contenu)

- **Délais** : ⏱ explicite → sa valeur · séparateur → le délai réel masqué par l'ellipse ·
  absent du doc → 4 s (défaut de la colonne).
- **Typing** : 3 s par défaut, 0 pour séparateurs et messages système, = au délai là où le doc
  décrit une hésitation visible (N2 40 s, N13 50 s).
- **`inline_response`** : réplique joueur immédiate, réponse de Léna à 8 s / typing 4.
- **« Léna est hors ligne »** (N19) : deux messages `system`, un à l'entrée du nœud et un après
  « merde ». Le silence de 90 s est porté par le séparateur « 00h34 » du N20.
- **Écran de fin** (« Quelqu'un est entré chez Léna… ») : message `system` en N22#4, pour ne pas
  perdre le texte narratif. Le client le sort du fil et l'affiche en plein écran.
- **Zooms N10, N16, N21** : `inline_response` nulle, effets **silencieux**. Le doc ne donne aucune
  réponse de Léna à ces gestes — le zoom lui-même est le retour. Ne pas inventer de réplique.

### Correctif Q6 — révélation d'identité (validé et intégré après coup)

Léna ne se nommait **jamais** du chapitre : afficher « Léna » dans la liste de conversations
trahissait le titre de l'histoire dès la première seconde. Vivien a validé un correctif de contenu
(« Moi c'est Léna, au passage. Puisqu'on en est là. », délai 12 s, au N5 et au N7) et demandé un
mécanisme généralisable — Karim arrive aussi anonyme au ch. 3, et le suspect n'est jamais révélé.

- Migration `20260814193538_contact_reveal.sql` : `contacts.display_name_initial`.
- Effect `reveal_contact` posé sur `nodes.effects` de N5 et N7 → le moteur alimentera
  `variables.contacts_reveles`. Sur le nœud et non sur un choix, exactement comme `refus` au N11 :
  plusieurs chemins mènent à la révélation.
- 4 contrôles de plus dans `verify-graph.sql` (**40/40**). Totaux : 67 messages, 33 choix.

⚠️ **Deux trous restent ouverts, tous deux côté contenu** (TODO Q7 et Q8) :
la branche du N6 atteint N22 **sans passer par N5 ni N7**, donc un joueur peut finir le chapitre
sans jamais connaître le prénom de Léna ; et `docs/chapitre-1-v2.md` ne contient pas le correctif,
donc la base diverge de 2 messages de sa source de vérité.

### Prochaine étape

**Phase 3** : Edge Functions `get-state` et `advance` + simulation de partie complète.

---

## 2026-08-14 (3/5) — Phase 1 (migration) : **TERMINÉE, validée** (commit `051384c`)

Vivien a validé Q1→Q4 (`nodes.next_node_id` oui · `player_messages.seq` oui, indexé, `created_at`
informatif seulement · indice `TELEPHONE` attribué au zoom du ch. 1 · `ai_system_prompt` recopié
verbatim). Docker lancé.

### Ce qui a été fait

- `supabase init` puis `supabase start`.
- Migration `supabase/migrations/20260814190318_initial_schema.sql` — 9 tables, 28 index,
  21 CHECK, 16 FK, 7 UNIQUE, RLS sur les 9 tables, 4 policies, 1 trigger `updated_at`.
- `supabase db reset` : migration appliquée sans erreur.
- Vérifications fonctionnelles (pas seulement déclaratives) — détail dans ARCHITECTURE.md :
  RLS anti-spoiler prouvée table par table, 6 contraintes CHECK prouvées comme rejetantes,
  écart B démontré en conditions réelles.
- Deux précisions doc demandées par Vivien intégrées dans LOGIQUE.md : la distinction
  `refus`/plafond de `confiance`, et la règle d'arrêt sur interaction en tant que contrainte UI.

### Le piège de l'écart B, démontré

4 messages écrits dans **une même transaction** (ce que fera `advance`) :
`count(distinct created_at) = 1`, `count(distinct seq) = 4`. Sans la colonne `seq`, l'ordre du fil
aurait été indéterminé — et de façon **intermittente**, donc quasi indiagnostiquable en production.

### Écart C — introduit pendant la Phase 1, à valider

Le schéma de référence prévoyait `player_messages.contact_id = null` pour les messages du joueur.
En l'implémentant, il devient évident que **les réponses du joueur ne seraient rattachables à
aucun fil** dès qu'il y a plusieurs contacts (twist ch. 4, que le schéma V2 revendique justement
comme fonctionnalité phare). J'ai donc fait de `contact_id` le **fil de conversation** (`not null`),
`sender` portant déjà « qui parle ». Réversible, mais à trancher avant le seed.

### Pièges rencontrés

- **`supabase db reset` finit sur une erreur 502** : imgproxy et pooler ne démarrent pas. La
  migration s'applique quand même, base + API + auth tournent. Ne pas croire à un échec de migration.
- **`psql` n'est pas installé** sur la machine → passer par
  `docker exec -i supabase_db_SMS-Noir psql -U postgres -d postgres`.
- **Piège de test RLS** : un `insert ... select ... from stories` sous le rôle `authenticated`
  renvoie `INSERT 0 0` non pas parce que l'insert est refusé, mais parce que le `select` source est
  filtré par RLS. Faux négatif : il faut tester avec un `values` explicite pour voir la vraie erreur.
- La triche par `UPDATE` sur `player_progress` échoue **silencieusement** (`UPDATE 0`), sans lever
  d'erreur. Comportement correct, mais à connaître.

### Prochaine étape

Validation → **Phase 2** : seed du chapitre 1 (21 nœuds, ~62 messages, ~33 choix) + script de
vérification du graphe.

---

## 2026-08-14 (2/5) — Phase 0 (audit) : **TERMINÉE, validée**

Vivien a fourni `chapitre-1-v2.md` et `schema-supabase-v2.md`. Audit croisé effectué.

### Décompte du chapitre 1

| Élément | Compte |
|---|---|
| Nœuds | **21** (N1→N22, **N15 n'existe pas**) |
| Messages | ~62 dont **6 séparateurs** et **4 médias** (3 photos, 1 vocal) |
| Choix | ~33 → 23 `reply` · 3 `ignore` · **7 `interaction`** |
| Interactions cachées | **6** (7 lignes : le N8 en propose 2, mutuellement exclusives) |
| Variables | 5 au ch. 1 (`confiance`, `lucidite`, `indices`, `refus`, `branche_ch1`) + `detail_perso` (N9) |
| Indices | 5 codes : `PROFIL_SUSPECT`, `BORNAGE`, `PLAQUE`, `AUTOCOLLANT`, `TELEPHONE` |
| Branches `branche_ch1` | 4 : `empathie`, `curieux`, `allié`, `prudent` |

Décomptes à confirmer ligne à ligne pendant le seed (Phase 2).

### Graphe — vérifié à la main, il est sain

Aucun nœud orphelin, aucun choix vers un nœud inexistant, tous les chemins convergent
(N14 → N16/N17/N18 → N19 → N20 → N9 → N21 → **N22**). Délai maximum : **90 s**, la règle de
rythme du ch. 1 (≤ 90 s) est respectée partout.

### Les 3 points que le prompt demandait de confirmer — réponses

1. **N9 après N20 : confirmé sans problème.** `nodes.code` est un `text` avec `unique (chapter_id, code)`,
   aucune contrainte d'ordre. Le flux est porté par les `next_node_id`, jamais par le code. C'est un
   pur label. (Corollaire : l'absence de N15 est également sans conséquence technique.)
2. **Interactions cachées : mapping établi.** Les 6 restent sur leur nœud (`next_node_id = null`) et
   renvoient une `inline_response`, sauf le N16 dont la sortie vers N19 est portée par le nœud, pas
   par l'interaction. Toutes appliquent des `effects` silencieux. Détail dans LOGIQUE.md.
3. **`chapter_end` sans chapitre 2 : résolu** par un **stub** de chapitre 2 (`position=2`,
   `title='Chloé'`, `unlock_delay_minutes=480`, `entry_node_id=null`, zéro nœud). Le compte à rebours
   a une cible réelle, rien n'est inventé côté contenu.

### Les 2 vrais trous trouvés dans le schéma (→ écarts à valider)

- **A. Pas de transition automatique.** 8 nœuds enchaînent sans aucun choix (N5, N7, N12, N18, N19,
  et N13/N16/N21 après leur interaction). Le schéma ne sait exprimer une transition que via
  `choices.next_node_id`. → ajout de `nodes.next_node_id` (nullable).
- **B. Ordre des `player_messages` indéterminé.** `created_at default now()` renvoie l'heure de
  **début de transaction** : tous les messages écrits par un même `advance` porteraient un timestamp
  identique, et l'index `(progress_id, contact_id, created_at)` ne suffit pas à les ordonner.
  → ajout de `player_messages.seq` (`bigserial`). **Piège subtil, aurait produit des fils mélangés
  de manière intermittente et très pénible à diagnostiquer.**

### Pièges à ne pas oublier

- **Interactions répétables.** Rien n'empêchait de rezoomer sur le récépissé N10 pour empiler
  `lucidite +1`. Mécanisme retenu : liste `interactions_faites` dans `variables` + `conditions`
  en `not_contains`. C'est aussi ce qui implémente « **UNE** relance » au N8 : les 2 questions
  écrivent la même clé `RELANCE_N8`, donc en poser une retire l'autre.
- **N13/N16/N21 auto-enchaînent MAIS portent une interaction.** Si `advance` déroule la chaîne
  automatique d'un trait, ces interactions deviennent inatteignables. Il doit s'arrêter au premier
  nœud offrant une interaction disponible.
- **`refus = true` se pose sur `nodes.effects` du N11**, pas sur un choix : les deux chemins d'entrée
  (N6-C, N10-B) doivent le poser. C'est le seul usage de `nodes.effects` du chapitre.
- **Plafond `confiance ≤ 6` si `refus`** : règle du **moteur**, jamais dans les `effects` du contenu.
- **Incohérences volontaires (bible §7)** : date du récépissé N10, 50 s d'hésitation N13, son de fond
  du vocal N17. Ne jamais les « corriger » — y compris à la production des médias : **le vocal ne
  doit pas être nettoyé de son bruit de fond**, c'est l'indice.
- **Histoire seedée en `draft`** (imposé) alors que la policy RLS de la vitrine filtre sur
  `published` → la liste des histoires sera vide côté client. Normal, ne pas « déboguer » ça.
- **Docker toujours arrêté** : à démarrer avant la Phase 1.

### Ambiguïtés remontées à Vivien (bloquent la Phase 1/2)

Voir TODO.md § Questions ouvertes — 4 questions : les 2 écarts de schéma (A, B), le moment
d'attribution de l'indice `TELEPHONE` (N21 ou ch. 2 ?), et le contenu exact de `ai_system_prompt`
(le doc donne des « consignes moteur », pas un prompt système rédigé — le rédiger serait de
l'écriture, donc hors règle 6).

### Prochaine étape

Validation de Vivien sur les 4 questions → **Phase 1** : `supabase init`, migration complète, RLS,
`supabase db reset`.

---

## 2026-08-14 (1/5) — Phase 0 : blocage initial, fichiers sources manquants

Le repo ne contenait que `README.md` (1 commit, `05f2fad`), la bible et le prompt. Les fichiers
`chapitre-1-v2.md` et `schema-supabase-v2.md` étaient absents.

**Décision prise : ne rien inventer** — reconstituer un chapitre ou un schéma « plausible » aurait
violé la règle 3 (recopie fidèle) et produit un travail à jeter. Audit d'environnement fait,
système documentaire créé, bible lue, puis STOP.

Rangement effectué : `bible-narrative.md` déplacé de la racine vers `docs/`,
`prompt-1-claude-code.md` vers `docs/prompts/`. Aucune modification de contenu.
