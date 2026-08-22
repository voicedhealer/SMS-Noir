# LOGIQUE.md — règles du moteur

> **Statut au 2026-08-14 : prompt 1 terminé.** Tout ce document décrit du code qui tourne :
> les formats JSONB sont ceux du seed, et le contrat des Edge Functions est celui que
> `scripts/simulate-playthrough.py` exerce à chaque exécution.
> Implémentation : `supabase/functions/_shared/engine.ts` (effects, conditions, plafonds).

## Vocabulaire

| Terme | Définition |
|---|---|
| **Nœud** (`node`) | Unité du graphe. Porte des `messages` et des `choices` |
| **Code de nœud** | Label libre : `N1`…`N22`. ⚠️ **Aucun ordre implicite** — N9 arrive après N20, et **N15 n'existe pas** |
| **Choix** | `reply` (répondre) · `ignore` (bouton explicite, jamais de timeout) · `interaction` (geste caché : zoom, réécoute, relance, insister) |
| **Interaction cachée** | Choix qui ne change généralement **pas** de nœud : renvoie une `inline_response` et/ou applique des `effects` silencieux |
| **Séparateur** | `content_type='separator'` : ellipse narrative (`body='23h31'`) masquant un délai réel court |
| **`ai_moment`** | Nœud à saisie libre (N9). Seedé au prompt 1, exécuté au prompt 3. Sort via `ai_fallback_node_id` (N21) |
| **`chapter_end`** | Nœud terminal (N22). Pose `chapter_unlocked_at` |

## Cycle de vie d'un nœud

```
      ┌──────────────────────────────────────────────────────┐
      │  Nœud courant (player_progress.current_node_id)      │
      └──────────────────────────────────────────────────────┘
                              │
                    get-state │  filtre anti-spoiler :
                              │  - messages du nœud
                              │  - choix DONT les conditions sont remplies
                              │  - jamais next_node_id / effects / conditions
                              ▼
                    ┌───────────────────┐
                    │  Le joueur agit   │
                    └───────────────────┘
                              │ advance(choice_id)
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 1. Le choix appartient-il au nœud courant ?  non ─▶ 403 │
   │ 2. Ses conditions sont-elles remplies ?      non ─▶ 403 │
   │ 3. Déjà consommé (idempotence) ?             oui ─▶ état inchangé │
   └────────────────────────────────────────────────────────┘
                              │
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 4. Écrire le message joueur                            │
   │    (SAUF si kind='ignore' → on n'écrit rien du joueur) │
   │ 5. Appliquer choices.effects sur variables             │
   └────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴────────────────┐
     next_node_id NULL                next_node_id présent
     (interaction sur place)                   │
              │                                ▼
              ▼                  ┌──────────────────────────────┐
   écrire l'inline_response      │ 6. Appliquer nodes.effects   │
   dans player_messages          │    du nœud ATTEINT (N11)     │
   le nœud courant NE CHANGE PAS │ 7. Écrire ses messages       │
   (mais les effects, eux,       │ 8. current_node_id ← atteint │
    ont bien été appliqués)      └──────────────────────────────┘
                                                │
                            ┌───────────────────┴──────────────┐
                            │ kind du nœud atteint ?           │
                            ├──────────────────────────────────┤
                            │ scripted    → si next_node_id    │
                            │   (auto) : enchaîner (§ Auto)    │
                            │ ai_moment   → ai_moment_pending  │
                            │ chapter_end → poser              │
                            │   chapter_unlocked_at et         │
                            │   renvoyer l'état de fin         │
                            └──────────────────────────────────┘
```

Les **délais ne sont pas attendus côté serveur** : ils sont renvoyés avec chaque message et joués
par le client (timers locaux + typing indicator + notifications locales programmées).

## Transitions automatiques (`nodes.next_node_id`)

8 nœuds du ch. 1 n'ont aucun choix de sortie et enchaînent seuls :

| Nœud | Enchaîne vers | Contexte |
|---|---|---|
| N5, N7 | N8 | Léna se livre / elle teste |
| N6 | *(a des choix)* | — non concerné, listé ici pour mémoire : c'est la 3e branche vers N8 |
| N12 | N14 | « Merci. Sérieux. » |
| N13 | N14 | après l'interaction « Insister » (optionnelle) |
| N16 | N19 | après l'interaction « Zoom autocollant » (optionnelle) |
| N18 | N19 | « J'ai pas fait tout ça pour repartir. » |
| N19 | N20 | l'incident |
| N21 | N22 | après le zoom sur le porte-clés |

Le schéma de référence ne sait exprimer une transition que via `choices.next_node_id` :
d'où l'ajout de la colonne `nodes.next_node_id` (écart A, ARCHITECTURE.md).

### Règle d'arrêt sur interaction *(validée — contrainte pour l'UI du prompt 2)*

**`advance` ne déroule jamais la chaîne automatique d'un trait. Il s'arrête sur le premier nœud
qui offre au moins une `interaction` encore disponible** (conditions vraies, pas encore dans
`interactions_faites`), et ce nœud devient le `current_node_id`.

Sans cette règle, les interactions cachées des nœuds auto-enchaînés (**N13, N16, N21**) seraient
traversées avant que le joueur ait pu agir : trois des six interactions du chapitre deviendraient
mécaniquement inatteignables.

**Conséquence côté serveur** — `advance` renvoie alors un état où le nœud courant n'a aucun choix
`reply`/`ignore`, seulement une ou plusieurs `interaction`. Ce n'est pas un cas d'erreur : c'est
l'état normal d'un nœud « en pause sur interaction ».

**Contrainte pour l'UI (prompt 2)** — dans cet état, l'app doit :

1. Dérouler les messages du nœud, puis **rester en attente** au lieu d'afficher des boutons de réponse.
2. Offrir **un moyen de continuer sans interagir** — l'interaction n'est jamais obligatoire
   (chapitre §Conventions). Concrètement : un geste de continuation discret, ou la simple poursuite
   du fil après un délai. Ce geste appelle `advance` sur la transition automatique du nœud.
3. Ne **jamais** signaler qu'une interaction est disponible ici (pas de bouton « indice », pas de
   pastille). Le geste doit rester naturel : zoomer sur une photo, réécouter un vocal, insister.
   Le joueur qui passe à côté ne doit pas le sentir ; celui qui la trouve ne doit voir aucune
   récompense clignoter.
4. Cas particulier du **N21** : le zoom est *quasi obligatoire, guidé par Léna* (« Tu vois le
   porte-clés ? Zoome. »). Même mécanique technique, mais l'incitation est portée par le texte —
   pas par un élément d'interface.

## Règles moteur transverses

1. **`refus` et le plafond de `confiance` sont deux mécanismes distincts** — voir § ci-dessous.
   Ne jamais les confondre.
2. **`confiance` bornée à [0,10]**, `lucidite` à [0,5] au ch. 1 (chapitre §Variables).
3. **`kind='ignore'` n'écrit aucun message joueur** — le joueur n'a rien dit. Il avance quand même.
4. **Ne jamais corriger une incohérence narrative** (bible §7) : elles alimentent `lucidite`.
   Le moteur les transporte telles quelles.
5. **`detail_perso` est une donnée personnelle** (bible §9, RGPD) : un seul élément anodin,
   consentement demandé depuis la carte d'entrée (avant l'intronisation, une fois pour toutes —
   voir § Le moment IA), effacement en cascade.
6. **Idempotence** : rejouer `advance` avec le même `choice_id` depuis le même nœud ne doit pas
   appliquer les `effects` deux fois (voir § Interactions à usage unique).

## Convention de contenu : typing intermittent

Un `typing_seconds >= 15` **est la marque, dans le contenu, d'une hésitation visible** : le client
joue alors l'indicateur en rafales (≈ 5 s visible / 3 s masqué, en boucle) au lieu d'un affichage
continu. En dessous du seuil, affichage continu.

Au chapitre 1, le seuil isole exactement **N2#0** (40/40, « en train d'écrire » qui apparaît et
disparaît deux fois) et **N13#0** (50/50, hésitation par à-coups). Partout ailleurs
`typing_seconds = 3`.

⚠️ **C'est une convention de contenu, pas un réglage technique.** Un chapitre futur qui écrirait
`typing_seconds = 20` pour de simples raisons de rythme déclencherait une hésitation dramatique
sans le vouloir. Au-dessus de 15 s, le typing *raconte* quelque chose.

## Mise en scène d'une attente : `phantom_typing_at` et `haptic_at`

Certaines attentes ne sont pas du temps mort, ce sont des scènes. Deux colonnes de `messages`
permettent d'y placer des battements :

| Colonne | Effet |
|---|---|
| `phantom_typing_at` | Un **faux** « en train d'écrire » apparaît, dure **2 s**, puis s'éteint **sans qu'aucun message n'arrive** |
| `haptic_at` | Vibration discrète unique, **sans notification** |

**Sémantique — la seule chose à ne pas se tromper** : les deux valeurs sont des **offsets en
secondes depuis le DÉBUT du délai du message qui les porte**. Ni depuis le début du nœud, ni depuis
la fin de l'attente. Une contrainte en base refuse toute valeur `>= delay_seconds` : un battement
hors de son attente ne se produirait jamais.

La durée de 2 s du faux typing est une **constante du client**, pas une donnée de contenu.

**Chapitre 1** — un seul usage, le grand silence du N19 (90 s, le plus long). Il est porté par le
séparateur « 00h34 » du **N20#0** : `phantom_typing_at = 45`, `haptic_at = 60`.

*Pourquoi pas une heuristique client (« tout délai > 60 s »)* : elle frapperait aussi N11, N16, N17
et N21. Un effet dramatique qui se produit cinq fois n'en est plus un.

## Le temps de fiction

**Aucun horodatage affiché ne vient de l'horloge système.** Ni le « vu », ni les bulles, ni le
dernier message de la liste des conversations. Un joueur qui joue à 14 h verrait « vu 14h12 » deux
lignes sous un séparateur « 00h29 », et l'illusion tomberait.

**Seule exception : le compte à rebours de fin de chapitre**, qui est du temps réel — c'est une
attente réelle, pas une heure d'histoire.

### Le mécanisme : une horloge ancrée sur les séparateurs

Le client dérive l'heure de fiction **sans aucune donnée supplémentaire** :

1. Chaque `separator` porte une heure de fiction dans son `body` (« 23h31 », « jeudi — 22h47 »).
   Il **réancre** l'horloge.
2. Chaque message suivant avance l'horloge de son propre `delay_seconds`.
3. L'heure de fiction d'un message est celle de l'horloge à son affichage.

```
séparateur « 23h31 »            -> ancre  = 23h31
  message  delay 4              -> 23h31
  image    delay 60             -> 23h32
  texte    delay 4              -> 23h32
  « il sort »       delay 60    -> 23h33
  … « merde »       delay 2     -> 23h34   <- « vu 23h34 » pendant le silence
séparateur « 00h34 »            -> réancre = 00h34
```

**Pourquoi cette solution plutôt qu'une colonne `fiction_time` par message** : zéro coût de contenu,
zéro valeur à oublier au chapitre 3, et surtout **déterministe** — elle ne dépend d'aucune horloge,
donc elle donne le même résultat au premier affichage et après un rechargement. Chaque séparateur
recale l'horloge, si bien qu'une dérive ne peut jamais s'accumuler au-delà d'une ellipse.

Quand un chapitre a besoin d'une heure précise à un instant donné, il lui suffit de poser un
séparateur : le mécanisme existe déjà, c'est celui des ellipses.

## Les médias : bucket privé et URLs signées

Le bucket `media` est **privé**. Un bucket public exposerait des objets aux noms
parfaitement devinables — `photo-N21-porte-cles.jpg` livrerait la révélation de fin de chapitre à
quiconque tape l'URL. Ce serait le seul trou dans une architecture entièrement bâtie sur
l'anti-spoiler.

| | |
|---|---|
| En base | `messages.media_url` contient un **chemin d'objet** (`photo-N16-plaque.jpg`), ou `placeholder://…` tant que le fichier n'existe pas |
| Dans la réponse | Un **chemin signé relatif** : `/storage/v1/object/sign/media/…?token=…`, valable 6 h |
| Côté client | Le client préfixe avec sa propre base Supabase |

**Pourquoi un chemin relatif et non une URL absolue** : à l'intérieur du réseau Docker, Supabase se
signe lui-même sur `http://kong:8000`, un hôte que ni un téléphone ni un émulateur ne sait résoudre.
Laisser le client préfixer règle aussi, gratuitement, le cas du `10.0.2.2` de l'émulateur Android.

**Seuls les médias déjà reçus sont signés** : la signature se fait au moment de construire la
réponse, sur les messages de l'historique et de la salve courante. Le contenu à venir reste
inatteignable, comme le reste du graphe.

Un média illisible ne fait jamais tomber la conversation : le client retombe sur son cartouche de
repli, celui des `placeholder://`.

## Un geste débloque une option

Le vocal du N17 en est le premier cas, et le motif resservira.

L'option « C'est quoi ce bruit derrière vous ? » **n'existe qu'à la deuxième
écoute**. Un joueur qui écoute une fois et passe à la suite ne la verra jamais —
et c'est voulu : l'incohérence n°3 (une radio en fond alors qu'elle est dehors,
seule) ne se remarque qu'en réécoutant.

Le compteur vit **côté client**, dans la bulle audio, et déclenche l'interaction
à partir de la seconde lecture (`message_widgets.dart`). Le serveur ne sait rien
du nombre d'écoutes : il ne connaît que l'interaction, et sa condition de
non-répétition habituelle.

C'est le bon partage. Compter les écoutes côté serveur supposerait de lui
envoyer un événement à chaque appui sur « lecture » — du bruit réseau pour une
information qui ne change rien à l'état de la partie tant que le geste n'a pas
été fait deux fois. **Le client compte le geste, le serveur en enregistre
l'effet.**

⚠️ Rien ne signale l'option au joueur. C'est la règle générale des interactions
cachées, et elle est la même que pour les micro-choix : il ne doit jamais savoir
quels moments comptent.

## Quand une règle change, ses gardiens aussi

**Règle de méthode, née de quatre récidives.** À chaque fois qu'une règle de
contenu a changé, le contrôle qui la gardait lui a survécu — et il a fallu le
découvrir en le voyant échouer, ou pire, passer à tort.

| règle abandonnée | gardien resté en place |
|---|---|
| « ne parle pas de Karim » dans le prompt | `verify-graph` exigeait `%Karim%` |
| « le 12 mars » dans le prompt | `verify-graph` exigeait `%12 mars%` |
| 21 nœuds, 71 messages, 33 choix | trois contrôles de comptage |
| « une à deux phrases » | la sonde coupait à trois |

**Donc : quand une règle de contenu change, on liste ses gardiens DANS LE MÊME
COMMIT.** Un contrôle qui survit à sa règle est pire qu'une absence de contrôle —
il donne du vert sur une règle morte, et il fait échouer la règle vivante.

**Corollaire, appris à ses dépens : protéger explicitement une donnée ne sert à
rien si une clé étrangère peut l'emporter par ailleurs.** Une migration
réinitialisait soigneusement les progressions sans les effacer — puis supprimait
trois lignes plus bas la ligne `stories` qui les tenait en `ON DELETE CASCADE`.
La partie visible de la règle était vérifiée, la porte à côté était ouverte.

Quand on protège une donnée, remonter ses références : `\d+ table` dans psql,
et lire les `on delete` autant que les `delete`.

Les gardiens possibles, à balayer à chaque fois : `verify-graph.sql`,
`verify-fidelity.py`, `simulate-playthrough.py`, `test-micro-choix.py`,
`test-ai-moment.py`, `probe-lena.py`, les tests Flutter, et les contraintes de
la base — `messages` **et** `player_messages`, qui s'oublie tout seul.

## La grammaire des trois axes

Chaque micro-choix offre trois options — **protéger · enquêter · raisonner** —
toujours dans cet ordre, jamais étiquetées. Aucune ne ramifie : même suite pour
les trois, seule la réplique de Léna change.

### Le contenu ne porte aucun nombre

Un micro-choix déclare une posture, pas une valeur :

```json
"effects": { "motif": "raison" }
```

C'est la décision structurante de V3.1. Au chapitre 5, retoucher l'équilibrage
voudra dire changer une constante du moteur, pas rouvrir trois cents lignes de
seed. Les nombres vivent dans `engine.ts`, la posture vit dans le contenu.

### La formule

Le serveur tient un décompte (`variables.micro`) et dérive la valeur :

```
part   = (micro_axe + 1) / (micro_n + 3)     ← lissée, neutre = 1/3
motif  = max(0, (part − 1/3) ÷ (2/3))         ← 0 si équilibré, 1 si mono-axe
apport = round(AMPLITUDE_axe × motif)
valeur = clamp(structurel + apport, bornes)
```

| axe | variable | amplitude |
|---|---|---|
| protéger | `confiance` | 3 |
| enquêter | `enquete` | 10 |
| raisonner | `lucidite` | 3 |

`enquete` prend toute sa plage : elle n'a aucun effet structurel, elle **est** la
posture. `confiance` et `lucidite` gardent leurs effets structurels déjà
équilibrés sur six chapitres — la posture n'y est qu'un modificateur.

**Pourquoi une proportion et pas un `+0.5` par choix.** Avec un incrément fixe,
un raisonneur saturait `lucidite` (max 5) à mi-chapitre : tous ses choix
suivants devenaient inertes, et « le motif compte » cessait d'être vrai au
moment précis où le joueur s'affirmait. Avec une proportion, **aucun choix n'est
jamais inerte** — un « protéger » tardif fait baisser la part « raisonner ».

**Pourquoi le lissage `+1 / +3`.** Sans lui, le tout premier micro-choix
donnerait 100 % à son axe et ferait bondir la variable d'un coup. On part du
neutre, un tiers par axe, et on converge vers la vraie proportion.

**Mesuré** — un joueur à 80 % « raisonner » obtient lucidité **+2**, qu'il ait
rencontré 20 ou 60 micro-choix. Un mono-axe pur : +3. Un joueur équilibré : +0.

### Raisonner n'est jamais puni

`motif` ne peut pas être négatif — c'est le `max(0, …)` de la formule, et c'est
une règle, pas un détail d'implémentation. Un joueur qui ne protège jamais ne
**perd** pas de confiance, il n'en gagne simplement pas par la posture. Le punir
lui apprendrait à ne plus douter, et il raterait la fin cachée.

### `structurel` : pourquoi une part séparée

Les gains des choix structurants s'accumulent dans `variables.structurel`, pas
dans la variable publique. Sans ça, la part de posture — recalculée à chaque
micro-choix — se cumulerait à elle-même et la variable dériverait à chaque tour.
`deriverAxes()` est **idempotente** : elle ne lit jamais la valeur publique.

## L'écran noir narratif (`content_type = 'narration'`)

Pendant les 60 s où Léna ne répond plus (N19), l'app quitte la conversation et
bascule en plein écran. C'est le seul moment du chapitre où le joueur cesse
d'être dans une messagerie.

**La narration est une chose qui ARRIVE DANS LE FIL, pas une propriété du nœud.**
C'est pour ça qu'elle est un message et pas une colonne sur `nodes` : elle a une
position, elle est délivrée par le déroulé comme le reste, et un chapitre pourra
en poser plusieurs sans qu'on touche au schéma.

Son `body` porte les lignes et leurs décalages :

```json
[{"texte": "Léna ne répond plus...", "a": 0}, {"texte": "…", "a": 20}]
```

**La durée n'est écrite nulle part.** L'écran tient tant que rien n'est arrivé
derrière : c'est le message SUIVANT qui le referme, et son `delay_seconds` qui
en donne la durée. Les deux ne peuvent donc pas se désynchroniser — il n'y a
rien à tenir en accord.

Trois règles de mise en scène :

- **Aucune sortie, aucun bouton, aucun champ de saisie.** Le joueur ne peut rien
  faire, et c'est le sujet. Un champ actif sur un écran noir sans fil visible ne
  ressemblerait à rien de réel et laisserait croire qu'une action est possible.
- **La dernière ligne est inachevée** — « ou prévenir la ». Elle est coupée par
  le retour de Léna. Ne jamais la compléter, ne jamais la faire disparaître
  proprement : la coupure est l'effet.
- **La narration ne laisse aucune trace dans le fil.** En remontant la
  conversation, on ne la relit pas : c'était un moment, pas un message.

## La transition vidéo (`content_type = 'video'`)

Même famille que l'écran noir, fond vidéo plutôt que noir pur : Léna rentre chez
elle entre le N20 et le N9 (addendum transition N20-N9 §2). Même principes —
un message dans le fil, pas une propriété de nœud ; aucune sortie, aucun
bouton ; la durée à l'écran vient du `delay_seconds` du message SUIVANT, pas
d'elle-même — avec deux différences :

- **Pas de `body`, un `media_url`.** Le texte incrusté (« Léna rentre chez
  elle. ») vit DANS le fichier vidéo, pas en JSON à décoder et superposer :
  rien à synchroniser côté client, contrairement aux lignes de la narration.
- **Pas de nœud de transition séparé.** La vidéo est simplement la position 0
  du N9 : les choix structurants du N20 continuent de pointer directement vers
  `N9`, sans re-câblage. Le mécanisme de `derouler()` ne distingue pas les
  `content_type` — il les écrit tous de la même façon — donc rien à changer
  côté moteur pour ce nouveau type, seulement la contrainte CHECK qui
  l'autorise (migration `20260818174041_video_transition.sql`).

Côté client, l'en-tête de conversation (nom du contact, présence) est masqué
pendant la vidéo — contrairement à l'écran noir, qui le garde pour vendre
l'absence de Léna. Cette vidéo montre une scène, elle ne mime pas un silence :
le chrome de messagerie n'a rien à y faire. Voir `VideoTransitionScreen`
(`app/lib/screens/video_transition_screen.dart`) et
`ConversationState.videoEnCours`.

## L'aparté (`nodes.aparte`)

Une ligne de contexte discrète, posée sous la dernière bulle et avant la zone de choix — décrite
côté design dans DESIGN.md § L'aparté. Aujourd'hui utilisée pour un seul cas (N9, saisie libre :
« Léna attend une vraie réponse... »), mais le mécanisme est générique : n'importe quel nœud pourra
en porter un.

**Une colonne sur `nodes`, pas un message.** Contrairement à la narration ou à la vidéo, l'aparté
n'est pas une chose qui ARRIVE dans le fil à une position donnée : c'est une propriété du nœud,
valable tant que le joueur y est et peut agir. Un message ne conviendrait pas — il faudrait le
rejouer à chaque tour de saisie libre, avec une position à inventer à chaque fois pour un contenu
qui ne change pas. `nodes.aparte` (texte, nullable) est lu une fois avec le reste du nœud.
`NULL` = ce nœud n'en porte pas, comportement par défaut de tous les nœuds sauf ceux qui en
déclarent un explicitement (migration `20260818174040_node_aparte.sql`).

**Le serveur transmet, il ne décide pas de l'afficher.** `etatNoeud()` renvoie `aparte` telle
quelle (`noeud.aparte ?? null`) dans le nœud courant, exposée par `get-state` et `advance` via
`ClientNode.aparte`. C'est tout : le serveur ne sait pas si le joueur est en train de lire un
déroulé ou si Léna « écrit », cet état n'existe que côté client.

**Le client décide seul du moment.** `ConversationState.aparteEnCours` : `null` pendant un déroulé
ou pendant que le contact « écrit », sinon `node?.aparte`. Concrètement, il disparaît dès l'envoi du
joueur ou la réponse de Léna, et réapparaît avant le tour suivant si le nœud courant en porte
toujours un — sans aller-retour serveur, uniquement en réagissant à l'état de lecture déjà connu du
client. Voir le widget `Aparte` (`app/lib/widgets/message_widgets.dart`).

## Les pauses en cours de nœud (`after_position`)

Un choix peut s'afficher **au milieu** d'un nœud, après un message donné. Le
déroulé s'arrête là, le joueur répond, et la suite sort.

- `choices.after_position` — la position du message après lequel le choix
  s'affiche. `NULL` = choix de fin de nœud, comportement historique.
- `player_progress.node_cursor` — le prochain message à délivrer.
- `player_progress.node_gate` — la pause **actuellement ouverte**, ou `NULL`.

**Pourquoi `node_gate` en plus du curseur.** On pourrait croire la pause
déductible du curseur (`curseur − 1`). C'est faux pour une pause posée sur le
**dernier** message d'un nœud : le curseur vaut la même chose avant et après la
réponse, et la pause se rouvrirait indéfiniment. Le marqueur est explicite.

**Pourquoi pas un nœud par pause.** C'était l'autre voie : découper N8 en
N8a/N8b/N8c. Le chapitre 1 serait passé de 21 à ~45 nœuds, et il en reste quatre
à écrire. Une table de nœuds qu'on ne peut plus relire est une dette narrative
avant d'être technique.

### RÈGLE GÉNÉRALE — le joueur ne doit jamais pouvoir détecter quand il est mesuré

Elle dépasse les micro-choix, et elle vaut pour tout ce qu'on ajoutera aux
chapitres suivants. Deux applications déjà en production :

- le **champ de saisie** ne change pas d'apparence au moment IA, alors que le
  texte y part vraiment vers un modèle ;
- un **micro-choix** est renvoyé avec `kind: "reply"`, jamais `"micro"`.

Dans les deux cas, l'information existe côté serveur et n'a aucune raison
d'atteindre le client. Si le joueur savait quels moments comptent, il jouerait
ces moments-là — et ce qu'on mesure cesserait d'être lui.

À vérifier par un test à chaque nouveau mécanisme mesuré, pas par relecture :
c'est une contrainte esthétique, donc la première à tomber lors d'une refonte.

### Ce que le client ne doit jamais savoir

Un micro-choix est renvoyé au client avec `kind: "reply"`, **jamais `"micro"`**.
S'il pouvait distinguer un choix qui ramifie d'un choix qui n'enregistre qu'une
posture, le joueur saurait quels moments comptent — et la grammaire des trois
axes ne mesurerait plus rien de sincère. C'est la même règle que l'apparence
identique du champ de saisie au moment IA.

Deux garde-fous côté serveur :

- on ne répond qu'à la pause **ouverte** (`choix_hors_pause` sinon) — sans quoi
  deux options du même bloc pourraient être jouées, et la posture comptée deux
  fois pour un seul moment de fiction ;
- `micro_ne_ramifie_pas`, une contrainte de base : un micro-choix ne peut pas
  porter de `next_node_id`. Une ligne de seed distraite suffirait à créer une
  branche fantôme.

## Le moment IA (N9)

Saisie libre : le joueur écrit ce qu'il veut, Léna répond via un modèle de langage. 2 à 4 échanges,
puis elle raccroche et l'histoire repart au N21.

### Le mode dégradé prime sur la fonctionnalité

Clé absente · API en erreur · timeout · quota atteint · JSON illisible :
**dans tous ces cas, Léna raccroche en personnage et l'histoire repart au fallback.** Jamais de
message d'erreur technique, jamais de blocage. Le joueur ne doit pas pouvoir deviner qu'il y avait
une IA derrière, ni qu'elle est tombée.

Le consentement refusé n'est **pas** une panne — voir § Le refus de consentement à un moment IA
plus bas : un vrai équivalent scripté, pas un raccrochage générique.

Deux répliques de sortie, et deux seulement :
« Merci. J'en avais besoin. Bon, je rentre. » (fin normale, quota, panne) ·
« Ok. Laisse tomber. Je rentre. » (hostilité, sortie de cadre).

### Ce que le modèle fait, et ce qu'il ne fait pas

| Le modèle | Le serveur |
|---|---|
| Écrit la réplique | Décide de raccrocher ou non |
| **Classe** la tonalité (`sincere`/`evasif`/`hostile`) | **Applique** les effets sur les variables |
| **Propose** un `detail_perso` et sa catégorie | **Filtre** et décide de le garder |
| — | Compte les échanges |

**Le modèle n'écrit jamais une variable.** Le décompte est tenu par
`player_progress.ai_exchanges`, remis à zéro à l'entrée du nœud — jamais par le modèle, jamais par
le client. Sans lui, un joueur qui ferme l'app en plein échange repartirait de zéro et pourrait
tourner indéfiniment.

Effets : `sincere` → confiance +2 · `evasif` → −1 · `hostile` → coupure sans gain. Le plafond
`confiance ≤ 6 si refus` s'applique comme partout, puisque tout passe par le même chemin d'écriture.

### Consentement : demandé une fois, depuis la carte d'entrée

Demandé **avant l'intronisation**, pas à la première saisie libre du N9 — le joueur n'a pas encore
touché à l'histoire que la décision est déjà prise. Écrit une seule fois
(`player_progress.ai_consent_at` / `ai_consent_refuse`), jamais redemandé.

`ai-chat` accepte `{consent}` **indépendamment du nœud courant** : ce n'est plus réservé à un
`ai_moment`, puisque la carte d'entrée l'appelle alors que le joueur est encore au nœud d'entrée
(N1). Refuser à ce stade n'a rien à refermer — l'histoire continue normalement. Ce qui se passe en
atteignant réellement un `ai_moment` avec un refus déjà posé : voir
§ Le refus de consentement à un moment IA.

`get-state` expose `ai_consent_decided` (`ai_consent_at` posé OU `ai_consent_refuse` vrai) :
c'est ce booléen, jamais un état local, qui fait réafficher la carte d'entrée. Un indicateur
purement client ne prouverait rien et disparaîtrait sans trace (RGPD, bible §9).

**Chemin de repli, toujours en place** : `!ai_consent_at` à l'entrée d'un vrai message de saisie
libre renvoie encore `{consent_required: true}`, pour une progression antérieure à la carte
d'entrée ou un client qui l'aurait contournée. Ne devrait plus se déclencher en usage normal.

### Sortie de cadre : en couches

1. **Pré-filtre serveur, avant l'appel** — injection de prompt, insultes manifestes. Déterministe
   et gratuit. Une injection ne doit jamais atteindre le modèle, ne serait-ce que pour ne pas la
   payer. Et on ne demande pas à un modèle de décider s'il doit s'ignorer lui-même.
2. **Classification par le modèle** — un jugement sur la tonalité, pas une règle.
3. **Décision serveur** — c'est lui qui coupe et qui applique.

### `detail_perso` : liste d'autorisation, jamais d'exclusion

**Règle permanente, valable pour tous les moments IA à venir (ch. 3, ch. 5).**

Le modèle renvoie une **catégorie** en plus de la valeur. Le serveur n'accepte que
`prenom` · `ville` · `metier` · `animal`. **Tout le reste devient `null`.**

*Pourquoi pas une liste d'exclusion* : sur du texte libre, elle ne rattrape que ce qu'on a prévu.
« Je suis en rémission » ou « je vais à la mosquée le vendredi » passeraient. Une liste
d'autorisation ferme par défaut ; c'est la seule posture défendable pour des données sensibles.

Filets supplémentaires sur la valeur retenue : longueur ≤ 40, pas de suite de 4 chiffres, et une
liste de termes sensibles (santé, croyances, opinions, vie intime, origines, coordonnées).

Un `detail_perso` à `null` est un **cas normal** : le payoff du chapitre 4 doit savoir s'en passer.

⚠️ Le texte brut du joueur va dans `player_messages` (`source = 'player_free'`) et suit la cascade
de suppression du compte. Seul `detail_perso` est conservé comme donnée exploitée.

### Prompt système

Il vit dans `nodes.ai_system_prompt`, **jamais dans le code** : c'est du contenu narratif, et
l'architecture est multi-histoires. Il est **générique quant à l'état de la partie** — le
vouvoiement (`refus`), le numéro d'échange et le rappel de raccrochage sont injectés à l'exécution
dans un second message système. C'est de l'état, pas du contenu.

⚠️ Sa place est le **seed**, pas une migration : les migrations passent avant le seed, qui
réécraserait aussitôt la valeur.

### Fournisseur

`mistral-small-2603`, **version épinglée** et non un alias `-latest` : Mistral déconseille les
alias en production, et un changement de modèle sous les pieds changerait la voix de Léna sans
prévenir. Surchargeable par `MISTRAL_MODEL` pour essayer autre chose sans redéployer.

Sortie contrainte par `json_schema` avec `strict: true`, et non l'ancien `json_object` qui se
contente de demander poliment du JSON. Le parsing reste défensif malgré tout : clôtures Markdown
retirées, chaque champ validé, tonalité inconnue traitée comme `evasif` — jamais comme `sincere`,
la seule qui fait gagner de la confiance.

L'appel est isolé derrière l'interface `FournisseurIA` : changer de maison ne touche à rien
d'autre.

### Quota et coûts

50 échanges par joueur et par jour (`ai_usage`), vérifiés **avant** tout appel. Les tokens entrée
et sortie sont cumulés par jour dans la même table, pour pouvoir chiffrer le coût réel par joueur.

Sortie plafonnée à 160 tokens — Léna écrit deux phrases — timeout de 12 s, aucune reprise.

### Ne jamais nommer dans le prompt ce qu'elle ne doit pas dire

Le prompt disait « Tu ne parleras pas de Karim ce soir ». Résultat, la première
sonde a produit : « Karim n'est plus là depuis longtemps. Tu devrais le
savoir. » — un **fait inventé**, sur un personnage du chapitre 3.

Nommer l'interdit apprend au modèle que la chose existe et qu'elle compte. La
règle qui marche est générique : *tout nom, lieu, date ou fait que tu n'as pas
vécu ce soir, tu ne le reconnais pas*. Après ce changement, huit tirages sur
huit répondent « Karim qui. » ou « T'as dû te tromper de personne. »

Ça vaudra pour les moments IA des chapitres 3 et 5, où la liste des choses à
taire sera bien plus longue : **on décrit ce qu'elle sait, jamais ce qu'elle
doit cacher.**

### Le prompt système est du CONTENU

Il vit dans `supabase/seed.sql`, pas dans une migration : une migration passe
avant le seed, qui le réécraserait. Le modifier suppose un `supabase db reset`,
puis un passage complet de `docs/RECETTE-MOMENT-IA.md`.

## Le refus de consentement à un moment IA (`nodes.ai_refus_node_id`)

Refuser l'IA ne doit coûter au joueur **aucune opportunité de jeu** — pas seulement lui éviter une
erreur technique. Avant ce mécanisme, un refus passait par le même `raccrocher()` qu'une panne
d'API : aucun effet appliqué, `detail_perso` toujours `null`. Mécaniquement identique à un joueur
qui aurait eu la malchance de tomber sur un quota épuisé — sauf que lui l'a choisi. Un joueur qui
refuse perdait donc, sans compensation, tout ce qu'un moment IA peut rapporter (jusqu'à plusieurs
points de `confiance`, un `detail_perso` réutilisé plus tard).

**Un équivalent scripté, pas un raccrochage.** `nodes.ai_refus_node_id` (nullable, comme
`ai_fallback_node_id`) désigne un nœud `scripted` ordinaire, joué à la place de la saisie libre —
généralement un bloc de micro-choix classique (🛡 protéger · 🔍 enquêter · 🧠 raisonner, voir
§ La grammaire des trois axes), qui applique ses `effects` comme n'importe quel autre nœud du
chapitre. **Aucune calibration spéciale requise** : le système proportionnel des trois axes
empêche déjà mécaniquement qu'une posture donnée devienne dominante — le même principe qui
protège `raisonner` de toute pénalité protège ici le joueur qui refuse de tout gain artificiel.
`detail_perso` reste `null` sur ce chemin : ce n'est pas un cas spécial, c'est le même état qu'un
joueur qui n'a simplement rien partagé d'exploitable (le ch. 4 gère déjà ce cas).

**Null = pas d'équivalent scripté pour ce nœud, comportement historique inchangé** (raccrochage
direct vers `ai_fallback_node_id`, comme une panne technique). Chaque `ai_moment` — y compris ceux
des chapitres 3 et 5 — active ce mécanisme en écrivant simplement son propre `ai_refus_node_id`,
sans toucher au moteur.

### Refus explicite ≠ panne technique — deux routes distinctes, jamais confondues

Un point sur lequel il ne faut jamais transiger : **`ai_refus_node_id` ne se déclenche QUE sur un
refus explicite** (`player_progress.ai_consent_refuse = true`). Une clé absente, une API en erreur,
un timeout, un quota dépassé, une sortie de cadre — tout ça reste sur `ai_fallback_node_id`, le
raccrochage générique existant, inchangé. Mélanger les deux routerait un joueur qui n'a jamais
touché au consentement vers un contenu écrit spécifiquement pour celui qui a dit non, ce qui
n'aurait aucun sens narratif.

Concrètement, deux points d'entrée distincts, jamais partagés :

- **`derouler()` (`_shared/moteur.ts`)** — le chemin normal. Dès qu'un `ai_moment` est atteint,
  AVANT même d'exposer le composer en saisie libre : si `progression.ai_consent_refuse` est vrai
  et que le nœud a un `ai_refus_node_id`, le déroulé s'enchaîne directement sur ce nœud, exactement
  comme un `next_node_id` ordinaire. **Le joueur qui refuse ne voit jamais le champ de saisie
  libre** — aucun risque qu'il tape un message pour rien.
- **`ai-chat`, branche `ai_consent_refuse`** — chemin de repli seulement, pour une progression
  antérieure à ce mécanisme (ou un client qui aurait quand même affiché le composer). Même
  distinction : équivalent scripté si disponible, sinon comportement historique.

Les pannes techniques, elles, ne passent **jamais** par `derouler()` pour en décider — elles ne
sont détectées qu'au moment de l'appel au modèle, donc uniquement dans `ai-chat`, qui garde son
`raccrocher()` d'origine sans y toucher.

### Une ligne d'ouverture peut basculer sur le consentement, pas seulement sur `refus`

`messages.conditions` conditionnait déjà une réplique sur `refus` (tutoiement/vouvoiement, voir
§ `refus`). Le même mécanisme s'étend au consentement IA : dans `derouler()`, l'appel qui délivre
les messages d'un nœud reçoit une copie de `vars` enrichie de `ai_consent_refuse` — une colonne de
`player_progress`, pas une des 5 variables du chapitre 1 — construite pour cet appel seulement,
**jamais réinjectée dans les variables persistées** (sinon elle polluerait `player_progress.variables`
à la sauvegarde suivante, avec une clé qui fait déjà doublon ailleurs). Un message peut donc porter
`{"eq": {"ai_consent_refuse": true}}` exactement comme il porterait `{"eq": {"refus": true}}`, sans
qu'aucun état supplémentaire ne soit écrit en base.

## Contraintes client *(prompt 2)*

**Le client n'écrit jamais en base. L'état vient toujours de `get-state`.**

Ce n'est pas une convention de style, c'est une contrainte structurelle : les tables joueur n'ont
**aucune policy `insert`/`update`/`delete`**. Un client qui tenterait d'écrire échouerait — et pas
toujours bruyamment :

| Tentative côté client | Ce qui se passe réellement |
|---|---|
| `insert into player_progress` | ❌ erreur `new row violates row-level security policy` |
| `insert into player_messages` | ❌ même erreur |
| **`update player_progress set variables = …`** | ⚠️ **`UPDATE 0` — aucune erreur, aucune ligne modifiée** |

⚠️ **Le cas de l'`UPDATE` est le piège.** Faute de policy `update`, aucune ligne n'est visible en
écriture : Postgres ne lève pas d'exception, il modifie zéro ligne et renvoie un succès. Un client
qui écrirait sa progression en local croirait donc avoir réussi, afficherait un état divergent, et
le prochain `get-state` le contredirait sans prévenir. Symptôme typique : des variables ou des
messages qui « reviennent en arrière » de façon inexplicable après un redémarrage de l'app.

**Règles qui en découlent, pour l'app Flutter :**

1. **Ne jamais écrire dans `player_progress` ni `player_messages`.** Toute mutation passe par
   `advance` (ou `ai-chat`, prompt 3).
2. **Ne jamais faire confiance à un état local.** Le cache local sert à l'affichage hors-ligne et à
   rejouer l'historique, jamais de référence. `get-state` fait autorité, toujours.
3. **Ne jamais dériver une variable côté client** (`confiance`, `lucidite`, `indices`…). Le client
   ne les voit même pas : elles ne sortent pas de `get-state`. C'est voulu — cf. anti-triche.
4. **Un succès d'écriture non vérifié n'est pas un succès.** Si du code client venait à écrire un
   jour, il devrait contrôler le nombre de lignes affectées, pas l'absence d'erreur.

## Révélation d'identité d'un contact

Un contact peut arriver anonyme et être révélé plus tard — ou ne jamais l'être. C'est un ressort
narratif récurrent, pas un cas particulier du chapitre 1 :

| Contact | Arrivée | Révélation |
|---|---|---|
| **Léna** | ch. 1, numéro inconnu | se nomme au **N5**, **N6** et **N7** — les trois branches vers le N8. Chacune pose une **carte d'enregistrement** ; c'est le geste du joueur qui révèle |
| **Karim** | ch. 3, numéro inconnu (Léna crée le groupe) | à définir |
| **Le suspect** | ch. 4, numéro inconnu | **jamais** — il reste anonyme jusqu'au bout |

Le mécanisme tient en deux moitiés :

1. **`contacts.display_name_initial`** — le nom affiché *avant* révélation (« Numéro inconnu »).
   `null` = contact connu dès le départ.
2. **Le geste du joueur** sur une carte d'enregistrement (`content_type: 'contact_card'`), qui
   appelle `reveal-contact`. **Ce n'est pas un choix narratif** : aucun nœud ne bouge, aucune
   variable de jeu n'est touchée.
3. **L'effect `reveal_contact`** en filet de sécurité, posé sur le nœud de fin de chapitre :
   `nodes.effects = {"reveal_contact": "lena"}`. Le joueur qui n'a jamais enregistré voit le
   contact nommé à la fin — un geste facultatif ne bloque jamais l'histoire.

Les deux alimentent la même liste, `player_progress.variables.contacts_reveles` (sans doublon).

**Garde-fou de `reveal-contact`** : on n'accepte que les contacts dont une carte a **déjà été
délivrée** au joueur. Sans lui, un client modifié pourrait nommer le suspect du chapitre 4 avant de
l'avoir rencontré — un spoiler gratuit dans une architecture qui en interdit partout ailleurs.

Le nom à afficher se calcule donc côté serveur, à chaque `get-state` :

```
nom_affiché = si code ∈ contacts_reveles  ->  display_name
              sinon                       ->  coalesce(display_name_initial, display_name)
```

**Pourquoi l'état vit dans `variables` et pas dans le contenu** : la révélation dépend du chemin
parcouru. Deux joueurs au même instant n'en sont pas au même point — l'un a croisé le N5, l'autre
non. C'est un état de partie, comme `indices` ou `interactions_faites`.

**Pourquoi sur le nœud et pas sur un choix** : plusieurs chemins mènent à la révélation (N5 *et*
N7), exactement comme pour `refus` au N11. Poser l'effect sur chaque choix entrant serait fragile.

**Un contact jamais révélé n'est la cible d'aucun `reveal_contact`** — il n'y a rien à désactiver,
il suffit de ne pas poser l'effect. Le suspect du ch. 4 garde son `display_name_initial` pour
toujours.

**Pourquoi les trois branches** : N5, N6 et N7 sont les trois seuls chemins vers le N8. Ne couvrir
que N5 et N7 laissait la branche du N6 atteindre N22 sans jamais nommer Léna. Le contrôle n° 54 de
`verify-graph.sql` interdit désormais toute route de N1 à N22 qui éviterait un nœud de révélation :
si un chapitre futur rouvre ce trou, le script le dira.

## `refus` : deux mécanismes à ne pas confondre

Le refus du joueur produit **deux choses de nature complètement différente**. Les mélanger est
l'erreur la plus facile à commettre ici.

| | **Poser `refus = true`** | **Plafonner `confiance` à 6** |
|---|---|---|
| **Nature** | Un `effect`, **contenu** | Une **règle permanente du moteur** — jamais un `effect` |
| **Où ça vit** | `nodes.effects` du **N11** : `{"set": {"refus": true}}` | En dur dans `advance` |
| **Quand ça joue** | **Une seule fois**, à l'entrée du N11 | **À chaque gain de `confiance`**, indéfiniment, tant que `refus` est vrai |
| **Portée** | Le nœud N11 | Toute la partie (ch. 1 → ch. 3 inclus, bible §6) |
| **Si on l'oubliait** | La branche du refus n'existerait plus | La `confiance` dépasserait 6 sur les gains ultérieurs |

**`refus = true` est posé sur le nœud, pas sur un choix**, parce que les deux chemins d'entrée du
N11 (N6-C « Ignorer », N10-B « Je ne peux pas être responsable de ça ») doivent tous deux le poser.
C'est le seul usage de `nodes.effects` du chapitre 1.

**Le plafond, lui, n'est écrit nulle part dans le contenu.** `advance` l'applique après chaque
écriture de `confiance`, de façon inconditionnelle :

```
confiance ← clamp(confiance + gain, 0, refus ? 6 : 10)
```

Pourquoi pas un `effect` : le plafond doit s'appliquer aux gains qui arrivent **après** le N11
(N11-A `confiance +1`, N17-B `confiance +1`, et le moment IA N9 `confiance +2`) — et à tous ceux
des chapitres 2 et 3. L'encoder dans les `effects` du contenu obligerait à le répéter sur chaque
gain de chaque chapitre : une seule ligne oubliée et la règle de la bible tombe silencieusement.

⚠️ Corollaire pour le prompt 3 : le `confiance +2` du moment IA passe par le même chemin d'écriture,
donc par le même plafond. `ai-chat` ne doit pas écrire `confiance` directement.

## Interactions à usage unique

Sans garde-fou, un joueur peut rezoomer sur le récépissé du N10 et empiler `lucidite +1`.
Mécanisme retenu, **sans changement de schéma** : une liste `interactions_faites` dans
`player_progress.variables`.

- Toute interaction porte `effects.append.interactions_faites = "<code>"`.
- Toute interaction porte `conditions` : « `<code>` absent de `interactions_faites` ».
- `get-state` masque donc naturellement une interaction déjà consommée.

C'est aussi ce qui implémente la contrainte du **N8 : « UNE relance optionnelle »** alors que deux
questions sont proposées. Les deux entrées (`PROFIL_SUSPECT`, `BORNAGE`) écrivent la **même** clé
`RELANCE_N8`, donc poser une question retire l'autre. Le joueur choisit laquelle — il ne peut pas
avoir les deux indices.

## Format JSONB `effects`

`motif` : `"proteger" | "enquete" | "raison"` — l'axe d'un micro-choix. Voir
§ La grammaire des trois axes. C'est le seul effect qui ne porte aucun nombre.


Liste d'opérations déclaratives sur `player_progress.variables`. Trois opérateurs suffisent
à tout le chapitre 1 :

```jsonc
// N8 choix B — « Ok. Je garde mon téléphone à côté de moi »
{ "inc": { "confiance": 2 }, "set": { "branche_ch1": "allié" } }

// N8 interaction — « C'est qui, ce type ? »
{ "append": { "indices": "PROFIL_SUSPECT", "interactions_faites": "RELANCE_N8" } }

// N10 interaction — zoom sur le récépissé
{ "inc": { "lucidite": 1 }, "append": { "interactions_faites": "ZOOM_RECEPISSE_N10" } }

// nodes.effects du N11 — le refus assumé
{ "set": { "refus": true } }
```

| Opérateur | Effet |
|---|---|
| `set` | Affectation directe (`branche_ch1`, `refus`) |
| `inc` | Incrément borné (`confiance`, `lucidite`) — les bornes et le plafond `refus` sont appliqués par le moteur |
| `append` | Ajout à une liste, **sans doublon** (`indices`, `interactions_faites`) |
| `reveal_contact` | Ajoute un code de contact à `contacts_reveles` — voir § Révélation d'identité |

## Format JSONB `conditions`

Expression déclarative évaluée contre `variables`. `{}` = toujours vrai. Les clés d'un même objet
sont en **ET**.

```jsonc
{}                                                  // toujours disponible
{ "not_contains": { "interactions_faites": "RELANCE_N8" } }   // relance N8 pas encore utilisée
{ "gte": { "confiance": 7 }, "count_gte": { "indices": 3 } }  // fin « La sauver » (ch. 5)
{ "eq": { "refus": true } }                         // variante vouvoiement
```

Opérateurs prévus : `eq`, `gte`, `lte`, `contains`, `not_contains`, `count_gte`.
Le chapitre 1 n'utilise en pratique que `not_contains` (interactions à usage unique) et `eq`
(variantes de réplique scriptée, voir ci-dessous) ; les autres sont posés maintenant pour les
seuils de fins de la bible §6, pour ne pas avoir à migrer plus tard.

### `messages.conditions` : des variantes sur une réplique scriptée

Jusqu'à l'addendum transition N20-N9, un message d'un nœud était **toujours** délivré : seul
`choices.conditions` existait. L'ouverture du N9 a besoin d'une réplique différente selon `refus`
(tutoiement demandé, ou vouvoiement maintenu) — et le vouvoiement/tutoiement n'est **pas** une
variable du moteur, c'est du texte écrit tel quel, sans branche serveur. `messages.conditions`
comble ce trou avec le même format et le même évaluateur que `choices.conditions` :

```jsonc
// N9#0 — deux lignes, une seule position
{ "eq": { "refus": false } }   // « Ça vous dérange si l'on se tutoie ? »
{ "eq": { "refus": true } }    // « Ça ne vous dérange pas si je continue à vous vouvoyer... »
```

Deux conséquences sur le schéma :

- **`position` n'est plus unique par nœud** — deux variantes d'une même réplique partagent la
  même position (`unique (node_id, position)` a été retiré). L'exclusivité mutuelle des conditions
  à une position donnée n'est pas vérifiable en contrainte SQL déclarative (elle dépend des
  valeurs runtime des variables) ; elle est garantie côté contenu
  (`generate-seed-content.py`, dict `VARIANTES`) et vérifiée par `verify-graph.sql`.
- **`position` reste un repère de curseur, jamais un index de tableau.** Un message dont la
  condition échoue est simplement absent du lot renvoyé au joueur ; les positions des messages
  suivants ne bougent pas. `ecrireMessagesDuNoeud` calcule `finPosition` sur la dernière position
  du nœud AVANT filtrage, pour la même raison.

**Étendu à N21#0, N21#2 et N22#1** dans la foulée : ces répliques tutoient, mais la bible §2 dit que
le vouvoiement tient tout le chapitre si `refus = true`. Avant l'addendum N20-N9, l'incohérence
passait inaperçue (le N20, loin en amont, ne conditionnait rien) ; une fois le N9 conditionnel, la
laisser tomber au premier nœud suivant aurait cassé la continuité pour cette branche. Simple
déclinaison grammaticale tu → vous, pas une réécriture — et volontairement limitée aux `messages` :
les micro-choix de N21/N22 (`choices.inline_response`) restent en tutoiement, hors du mécanisme
`messages.conditions`.

## Format JSONB `inline_response`

Réponse à une interaction qui ne change pas de nœud. Même structure qu'un message, en liste
(une interaction peut produire un échange court) :

```jsonc
// N13 — interaction « Insister »
[
  { "sender": "player",  "content_type": "text",
    "body": "...50 secondes pour répondre ça ?" },
  { "sender": "contact", "content_type": "text", "delay_seconds": 12, "typing_seconds": 4,
    "body": "J'hésitais à te dire un truc. Une autre fois. Pas ce soir." }
]
```

Le N17 (réécoute du vocal) suit exactement ce patron : la réécoute fait apparaître la réplique
joueur « C'est quoi ce bruit derrière vous ? », suivie de la réponse de Léna.

## Contrat des Edge Functions

Types TypeScript de référence : `supabase/functions/_shared/types.ts`.
Les deux endpoints sont en **POST**, authentifiés par le JWT du joueur
(`Authorization: Bearer …`). Sans jeton valide : `401`.

### Ce qui ne sort JAMAIS

`next_node_id` · `effects` · `conditions` · les choix dont les `conditions` sont fausses ·
**les variables de partie** (`confiance`, `lucidite`, `indices`…). Le joueur ne voit jamais ses
compteurs : c'est à la fois l'anti-triche et le refus du 4e mur (DESIGN.md).
*Vérifié par `scripts/simulate-playthrough.py`, qui inspecte les réponses brutes.*

### `get-state`

Entrée : `{}` — l'identité vient du jeton. Crée la progression à la première visite, entre dans le
nœud d'entrée et déroule sa chaîne.

```jsonc
{
  "story": { "slug": "numero-inconnu", "title": "Numéro Inconnu" },
  "conversations": [
    { "contact_id": "uuid", "display_name": "Numéro inconnu",  // ou « Léna » après révélation
      "avatar_url": null, "revealed": false }
  ],
  "history": [                       // tout l'historique, ordonné par seq
    { "seq": 1, "contact_id": "uuid", "sender": "contact", "content_type": "separator",
      "body": "jeudi — 22h47", "media_url": null,
      "delay_seconds": 0, "typing_seconds": 0,   // toujours 0 : l'historique se rejoue d'un bloc
      "push_notification": false, "push_text": null }
  ],
  "node": {
    "code": "N1", "kind": "scripted",
    "choices": [ { "id": "uuid", "position": 0, "label": "…", "kind": "reply" } ],
    "awaiting_interaction": false,
    "can_continue": false
  },
  "chapter_end": null,
  "ai_moment_pending": false
}
```

### `advance`

Deux formes d'entrée :

| Entrée | Effet |
|---|---|
| `{ "choice_id": "uuid" }` | Applique un choix (`reply`, `ignore` ou `interaction`) |
| `{ "continue": true }` | Franchit la transition automatique du nœud courant. Sur un `ai_moment`, emprunte le **fallback** — le chemin prévu quand l'IA est indisponible |

```jsonc
{
  "new_messages": [                  // à dérouler AVEC leurs délais (timers côté client)
    { "seq": 12, "contact_id": "uuid", "sender": "player", "content_type": "text",
      "body": "Qui ça, \"elle\" ?", "media_url": null,
      "delay_seconds": 0, "typing_seconds": 0, "push_notification": false, "push_text": null },
    { "seq": 13, "contact_id": "uuid", "sender": "contact", "content_type": "text",
      "body": "Attends", "media_url": null,
      "delay_seconds": 25, "typing_seconds": 3, "push_notification": false, "push_text": null }
  ],
  "node": { /* comme get-state, ou null */ },
  "conversations": [ /* renvoyées à chaque coup : une révélation peut changer un nom */ ],
  "chapter_end": null,
  "ai_moment_pending": false,
  "idempotent_replay": false
}
```

Au N22, `chapter_end` est renseigné :

```jsonc
{
  "chapter_title": "Le mauvais numéro",
  "next_chapter_title": "Chloé",
  "unlocked_at": "2026-08-15T03:58:00.000Z",   // now() + unlock_delay_minutes du chapitre suivant
  "next_chapter_pending": true                  // le stub existe, son contenu non
}
```

### Erreurs

Toutes de la forme `{ "error": { "code": "…", "message": "…" } }`.

| Statut | Code | Quand |
|---|---|---|
| 400 | `requete_invalide` | Ni `choice_id` ni `continue` |
| 401 | `non_authentifie` | Jeton absent ou invalide |
| 403 | `choix_invalide` | Le choix n'appartient pas au nœud courant — **même réponse si le choix n'existe pas du tout**, pour ne rien révéler du graphe |
| 403 | `choix_verrouille` | `conditions` non remplies (interaction déjà consommée, par exemple) |
| 409 | `choix_attendu` | `continue` sur un nœud qui propose des réponses |
| 409 | `sans_suite` | `continue` sur un nœud sans transition automatique |
| 409 | `progression_corrompue` | Aucun nœud courant |
| 500 | `erreur_interne` | Le détail reste dans les logs serveur |

### Idempotence

Un `advance` rejouant le **même `choice_id`** (retransmission réseau) ne réapplique aucun `effect` :
il renvoie à l'identique les messages produits au premier appel, avec `idempotent_replay: true` et
des délais à 0 — ils ont déjà été joués.

Le mécanisme repose sur `player_progress.last_choice_id` et `last_choice_seq` (le `seq` du premier
message produit par ce coup, qui sert de curseur). Sans cette trace, le second appel serait rejeté
en `403` : le choix n'appartient plus au nœud courant, qui a avancé.

### Où le client doit appeler `continue`

Quand `node.can_continue` est vrai. Deux situations :

1. **`awaiting_interaction: true`** — le nœud est en pause sur une interaction cachée (N13, N16,
   N21). Le joueur qui n'interagit pas doit pouvoir poursuivre. Voir § Règle d'arrêt sur interaction.
2. **`ai_moment_pending: true`** — le moment IA (N9). Au prompt 3, la saisie libre appellera
   `ai-chat` ; en attendant, `continue` emprunte le fallback vers le N21.

## Fin de chapitre (N22)

`chapter_unlocked_at = now() + unlock_delay_minutes` du **chapitre suivant** (position + 1),
calculé **une seule fois**, à l'entrée du nœud `chapter_end` (`calculerDeblocage()`, moteur.ts) —
jamais réévalué ensuite. **Aucun cron ne tourne dessus** : rien ne « débloque » activement le
chapitre suivant à l'échéance, le timestamp est juste une donnée que le client compare à l'heure
courante pour savoir si la suite est disponible. Un futur `unlock-chapter` (prompt 4, achat
premium) resterait le seul autre écrivain de cette colonne.

Le chapitre 2 est seedé comme **stub** : `position=2`, `title='Chloé'`,
`unlock_delay_minutes=480` (8 h, bible §9), `entry_node_id = null`, aucun nœud. C'est ce qui permet
au N22 de fonctionner sans chapitre 2 écrit : l'écran de fin a une cible réelle vers laquelle
programmer un rappel, et le déblocage effectif constatera simplement qu'il n'y a pas encore de
contenu à servir (`next_chapter_pending`).

### Contrat `ChapterEndState` — tout le contenu du prochain chapitre, jamais rien en dur côté client

```ts
{
  chapter_title: string
  next_chapter_title: string | null
  next_chapter_position: number | null        // « Chapitre N — titre », N jamais codé en dur
  unlocked_at: string | null
  next_chapter_pending: boolean
  next_chapter_unlock_delay_minutes: number | null   // « Me prévenir dans Xh »
  next_chapter_notification_text: string | null      // corps de la notification locale
  next_chapter_teaser_text: string | null             // accroche courte sur l'écran de fin
}
```

Les quatre derniers champs viennent de `chapters.notification_text`/`teaser_text` (nullable —
migration `20260821120000_chapter_notification_teaser.sql`) et `chapters.unlock_delay_minutes`
(déjà existant), tous lus sur le chapitre **suivant**, jamais le courant : c'est lui qu'on attend,
c'est son contenu qui doit apparaître sur l'écran de fin du chapitre qu'on vient de terminer.

## Notification locale de déblocage de chapitre

Programmée **côté client** (`app/lib/services/notifications_locales.dart`,
`flutter_local_notifications`) quand le joueur tape « Me prévenir » sur l'écran de fin — le serveur
ne programme rien, il ne fait que fournir la cible (`unlocked_at`) et le contenu
(`next_chapter_notification_text`) sur lesquels le client cale un rappel local.

**Un seul identifiant fixe, jamais un par chapitre.** L'histoire est strictement linéaire : à un
instant donné, un joueur ne peut avoir qu'un seul « prochain chapitre » en attente de déblocage.
Reprogrammer (le joueur retape sur le bouton, ou rouvre l'écran après avoir déjà programmé) réécrit
la même notification — jamais une deuxième. Pas besoin de dériver un id par chapitre pour ça.

**La permission n'est jamais demandée avant le tap.** `DarwinInitializationSettings` désactive
explicitement les trois permissions à l'initialisation (`requestAlertPermission` etc. à `false`) —
sans ça, iOS demanderait la permission dès le lancement de l'app, avant même que le joueur ait vu
le bouton. La demande réelle n'a lieu que dans `NotificationsLocales.programmer()`, au moment du
tap. Si déjà refusée, l'OS ne réaffiche pas l'invite de lui-même — le service ne la redemande donc
jamais, il relit juste le résultat renvoyé par l'OS.

**`tz.UTC` comme repère de programmation, jamais le fuseau réel de l'appareil.** `TZDateTime.from`
convertit l'instant donné en UTC en interne avant de le réétiqueter avec le repère fourni :
l'instant réel programmé ne dépend donc pas du repère choisi, seul l'affichage en dépendrait — or
rien de tout ça n'est jamais montré au joueur. Détecter le fuseau réel de l'appareil (ex. via un
package séparé) n'apporte donc rien ici et n'a volontairement pas été ajouté.

**Aucune méthode du service ne lève jamais.** Une plateforme sans implémentation enregistrée
(desktop non supporté, environnement de test) doit se comporter comme s'il n'y avait simplement
jamais de notification possible — jamais un crash de l'écran de fin de chapitre. Même principe que
`MusiqueNarrative` pour une musique absente ou illisible : chaque opération est enveloppée dans un
`try/catch` qui renvoie un résultat neutre (`false`, ou rien) plutôt que de propager l'exception.
**Mais jamais silencieux pour autant** : chaque `catch` logue l'erreur (`debugPrint`) avant
d'absorber — sans ça, une vraie erreur de permission ou de configuration sur un appareil réel se
lirait exactement comme un refus normal de l'utilisateur, invisible en debug comme en production.

**`annuler()` a un vrai appelant dès aujourd'hui : `reinitialiser()`.** « Effacer ma progression »
(Réglages, un vrai geste joueur, pas seulement l'outil de développement) efface la partie — un
rappel resté programmé pour un chapitre qui n'existe plus sonnerait plus tard pour une partie qui
n'a plus cours. C'est le seul déclencheur réel aujourd'hui : aucun système d'achat n'existe encore
pour débloquer un chapitre autrement avant l'échéance naturelle, donc aucun appel à `annuler()`
n'est câblé sur un tel événement — la méthode reste prête pour ce futur point d'intégration.
