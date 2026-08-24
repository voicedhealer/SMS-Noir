# DESIGN.md — l'application

> **Statut : Phase 2 du prompt 2 terminée.** L'écran de conversation existe et tourne
> (`app/lib/screens/conversation_screen.dart`, `app/lib/widgets/`). Restent à construire en Phase 3 :
> les interactions cachées, la liste des conversations et l'écran de fin.
> Ce document doit permettre de reconstruire l'UI sans son auteur.

## Le principe qui gouverne tout

**L'app doit être indiscernable d'une vraie messagerie.** Si l'illusion casse, l'histoire ne
fonctionne plus — le joueur cesse de croire à Léna et se met à jouer à un jeu.

Trois conséquences non négociables :

1. **Aucun élément ludique visible.** Pas de score, pas de barre de progression, pas de badge, pas
   de « chapitre 1/5 ». Les variables (`confiance`, `lucidite`, `indices`) ne sont **jamais**
   affichées — le serveur ne les envoie même pas au client.
2. **Aucune rupture du 4e mur.** Pas de didascalie, pas de narration off, pas d'infobulle
   pédagogique.
3. **On doit pouvoir jeter un œil à l'écran dans le métro et croire à de vrais SMS.**

C'est le critère d'arbitrage de tout choix visuel : *est-ce qu'une vraie messagerie ferait ça ?*

## Palette

Sombre, un thriller nocturne. Une seule couleur d'accent dans tout le produit.
Valeurs de référence : `app/lib/theme/tokens.dart`.

| Jeton | Hex | Usage |
|---|---|---|
| `fond` | `#0B0D10` | Fond général. **Pas un noir pur** : sur OLED il « creuse » et détache les bulles comme des vignettes |
| `surface` | `#101317` | Barre d'en-tête, barre de saisie |
| `separateurLigne` | `#1B1F25` | Filets de séparation |
| `bulleContact` | `#1A1D22` | Bulle reçue |
| `texteContact` | `#E4E6EA` | Texte reçu |
| **`bulleJoueur`** | **`#2B5566`** | **Unique accent du produit** — bleu-vert profond, désaturé |
| `texteJoueur` | `#EAF2F5` | Texte envoyé |
| `bulleJoueurNonDelivre` | `#1F3C48` | Message décoratif non délivré |
| `textePrincipal` | `#E4E6EA` | |
| `texteSecondaire` | `#8A9199` | Sous-titre de présence, aperçus |
| `texteTertiaire` | `#5E666E` | Horodatages, mentions discrètes |
| `separateurFond` / `separateurTexte` | `#14171B` / `#6E767F` | Pastille d'ellipse horaire |
| `pastille` | `#3E7A91` | Compteur de non-lus |
| `mediaAbsentFond` / `mediaAbsentBord` | `#191D22` / `#262B32` | Média `placeholder://` |

**Pourquoi cet accent** : assez présent pour distinguer les deux voix d'un coup d'œil, assez sourd
pour ne pas égayer un thriller. Un bleu iMessage ou un vert WhatsApp serait plus « vrai » mais
rendrait l'écran joyeux — et rapprocherait trop l'app d'une messagerie identifiable.

## Typographie

**Aucune police n'est embarquée, volontairement.** `fontFamily` reste nul : Flutter prend SF Pro sur
iOS et Roboto sur Android. C'est précisément ce qui vend l'illusion — une police custom, même belle,
signalerait « application » en une fraction de seconde.

| Style | Taille | Graisse | Interligne | Usage |
|---|---|---|---|---|
| `corpsMessage` | 16 | regular | 1.35 | Texte des bulles (`letterSpacing: -0.1`) |
| `titreEnTete` | 17 | 600 | 1.2 | Nom du contact |
| `sousTitrePresence` | 12 | regular | 1.2 | « en ligne » · « hors ligne » |
| `separateur` | 12 | 500 | — | Pastille horaire (`letterSpacing: 0.4`) |
| `libelleChoix` | 15 | regular | 1.25 | Boutons de réponse |
| `titreConversation` | 16 | 600 | — | Liste des conversations |
| `apercuConversation` | 14 | regular | 1.25 | Dernier message |
| `horodatage` | 12 | regular | — | |
| `titreFinChapitre` | 26 | 300 | 1.3 | Écran de fin |
| `compteARebours` | 32 | 200 | — | `letterSpacing: 2` |

## Espacement et formes

Échelle base 4 : `4 · 8 · 12 · 16 · 20 · 24`.

- **Rayon de bulle** : 18, uniforme, sans queue. Les messageries modernes ont abandonné la pointe.
- **Sons — trois étages**, dans cet ordre : le fichier fourni par le contenu, le son
  court du système (**iOS seulement** — Android n'expose pas d'API pour un son bref et
  neutre, on n'y obtient que la sonnerie choisie par l'utilisateur), puis **rien**.
  Quand rien n'a sonné, un message **reçu** déclenche une vibration légère. C'est ce
  qui donne un signal sur Android sans aucun fichier, et ça couvre le mode silencieux
  sans avoir à interroger l'appareil.

  La vibration passe par le **même point** que le son : elle hérite donc des quatre
  interdits par construction — pas de séparateur, pas de message système, pas de carte
  de contact, pas de message décoratif. Et rien pendant le silence du N19.

- **Horodatage** : **sous** la bulle, jamais dedans, dans le gris discret, aligné du
  même côté que ses bulles. À l'intérieur, il forçait la bulle à s'élargir au-delà de
  son texte — « Disparu comment ? » occupait deux fois la place nécessaire, avec un
  vide en dessous. Dehors, la bulle épouse ses mots.

  **La règle vaut à égalité pour les trois types de bulle** — texte, photo, vocal.
  Une incrustation avait survécu sur les médias : l'heure restait en surimpression
  dans le coin de la vignette, et à côté de la durée du vocal, exactement comme avant
  la refonte — parce que photo et audio passent par un widget séparé du texte, et la
  correction de l'un n'avait pas traversé vers l'autre. `PhotoBubble` et `AudioBubble`
  ne connaissent plus d'heure du tout : c'est `_Element`, dans l'écran de conversation,
  qui pose le même `MessageFooter` sous les trois.

- **Une seule heure par groupe**, sous le dernier message. Un groupe = **même
  émetteur et même minute de fiction**, sans rien entre les deux. La minute compte
  autant que l'émetteur : grouper sur le seul émetteur ferait disparaître un
  changement d'heure au milieu d'une série, et l'heure de fiction est la seule
  horloge dont dispose le joueur. Trois « 22h47 » empilés ne sont pas trois
  informations.

- **Deux niveaux d'espacement** : `interBulles` = **3** dans un groupe,
  `interGroupes` = **14** entre deux. C'est ce blanc qui dit qu'on a changé de tour
  de parole — bien plus sûrement que le côté de l'écran.

- **Nom de l'émetteur** : jamais en tête-à-tête, l'en-tête le dit déjà. Réservé à la
  conversation de groupe (ch. 3 : Léna, Karim, le joueur), sous le même traitement
  que l'heure. Le mécanisme existe déjà — `estGroupe` s'allume dès que le fil compte
  plus d'un contact.

- **« Vu. » et la coche « non délivré »** suivent la même règle : dans le pied du
  groupe, jamais sous chaque bulle.

- **Largeur max de bulle** : **72 %** de l'écran (`AppSpacing.largeurMaxBulle`).
  Les bulles forment une colonne régulière de chaque côté, et laissent en face un
  couloir vide qui ne se referme jamais — c'est ce couloir, plus que l'alignement,
  qui dit que chaque interlocuteur a son côté. Plus large, les deux colonnes se
  rejoignent au milieu et le fil cesse de ressembler à une conversation.
- **Entre deux bulles du même locuteur** : 3.
- **Entre deux prises de parole** : 10.
- **Marges du fil** : 16 horizontal.

## Animations

Rien de gratuit. Trois seulement :

| Animation | Durée | Pourquoi elle existe |
|---|---|---|
| Arrivée d'un message | 220 ms | Sans elle, les messages « apparaissent » et cassent le rythme |
| Apparition du typing | 160 ms | |
| **Bascule d'identité** | 900 ms | Le seul moment où l'on accorde du temps : « Numéro inconnu » → « Léna » est un micro-événement narratif |

Pas de transition de page élaborée, pas de rebond, pas de parallaxe.

---

## Écran 0 — La séquence d'intronisation

Jouée **une seule fois**, à la toute première ouverture. Aucun bouton, aucun skip visible : elle
dure une dizaine de secondes et ne mérite pas d'être passée. (Un skip au tap existe en debug.)
Aucune mention de jeu, de chapitre ou de mécanique — le joueur comprend par l'usage.

**Le texte vient du serveur** (`stories.intro_panels`) : c'est du contenu narratif, pas de
l'interface, et l'architecture est multi-histoires.

| # | Panneau | Durée lisible |
|---|---|---|
| 1 | « Jeudi 13 août 2026 » | 2 s |
| 2 | « Jeudi soir » / « Rien de prévu » | 2 s |
| 3 | « Le téléphone posé à côté de vous » / « La soirée sera tranquille » | 2 s |
| 4 | « 22h47 » | **2,5 s** — c'est le basculement |

**Aucun point final.** Ces lignes ne sont pas des phrases : ce sont des cartons.
Le point les referme, le fondu suffit à les ponctuer — et sur « 22h47 », il
transformait un basculement en constat.

Fondu d'entrée et de sortie : **800 ms** chacun. Fond noir, typographie du thème, texte centré.

**Le premier panneau date l'histoire**, et ce n'est pas décoratif : c'est ce qui garde les
incohérences plantées lisibles indéfiniment. Sans lui, le mail du N10 dirait « il y a 2 mois » en
2026 puis « il y a 14 mois » un an plus tard. Voir bible §3.

### Musique

Fichier fourni par histoire (`stories.intro_music_url`, signé comme les autres médias).
`scripts/upload-media.sh` la repère par élimination : un audio de `media/` qui n'appartient à
aucun nœud.

- Démarre avec le premier panneau, **fondu montant de 500 ms**. Volume modéré (45 %).
- **Coupure nette à la transition** — pas de fondu descendant, pas de continuation sous le fil.
  Le silence brutal fait partie de l'effet.

  ⚠️ **La coupure est un acte explicite, pas un effet de bord du `dispose()` d'un widget.** La
  musique appartient à un service à instance unique (`services/intro_music.dart`) : `demarrer()`
  coupe toujours ce qui jouait avant, et l'arrêt est déclenché au moment précis de la bascule.
  Le lecteur avait d'abord été confié à l'écran d'intro — et le bouton de réinitialisation, qui
  reconstruit l'écran, laissait un lecteur orphelin tourner sans que personne ne détienne plus la
  référence pour l'arrêter.
- Catégorie **ambient** : respecte le mode silencieux du téléphone, ne coupe pas la musique que le
  joueur écoutait déjà.
- **Une seule lecture, jamais en boucle.** Si le morceau dépasse la séquence, il est coupé par la
  transition — c'est voulu.
- Aucun contrôle à l'écran. Une musique absente ou illisible ne bloque jamais l'histoire : la
  séquence se joue en silence.

### Puis : les 4 secondes de vide

Transition vers l'écran de conversation, **vide**. En-tête « Numéro inconnu » / « en ligne ».
Aucun message. **4 secondes de silence total**, puis le fil démarre : le séparateur, le typing,
et le premier message de Léna.

⚠️ **Ces 4 secondes ne sont pas négociables.** C'est le calme qui rend l'intrusion violente. Ne
jamais les réduire pour « fluidifier ». Un test les verrouille.

Corollaire côté serveur : à la première visite, `get-state` renvoie les messages du nœud d'entrée
dans `new_messages` (avec leurs délais) et **non** dans `history`. Sans ça, le tout premier message
de l'histoire apparaîtrait d'un bloc, sans attente ni typing.

## Les horodatages sont du temps de fiction

**Aucune heure affichée ne vient de l'horloge système** — ni sur les bulles, ni sur le « vu », ni
dans la liste des conversations. Un joueur qui joue à 14 h verrait « vu 14h12 » deux lignes sous un
séparateur « 00h29 », et l'illusion tomberait.

Le client dérive l'heure du fil lui-même : chaque séparateur réancre l'horloge, chaque message
l'avance de son `delay_seconds`. Déterministe, donc identique après un rechargement.
Implémentation : `app/lib/services/fiction_clock.dart` · règle : LOGIQUE.md § Le temps de fiction.

**Seule exception : l'échéance de déblocage de fin de chapitre** (`unlocked_at`), qui est du temps
réel — même si elle ne s'affiche plus en chiffres qui défilent, voir § Écran de fin de chapitre.

## Écran 1 — Liste des conversations

Avatar, nom, dernier message, horodatage, pastille de non-lus. Une seule conversation au chapitre 1,
mais **l'architecture est multi-conversations dès maintenant** : au chapitre 4 un deuxième puis un
troisième contact écrivent, et un groupe apparaît. Le coût est nul aujourd'hui, il serait élevé après.

Le nom vient **entièrement du serveur** (`display_name`, déjà arbitré selon `revealed`). Le client
n'a aucune logique de nommage.

### La bascule d'identité

Quand `revealed` passe de `false` à `true`, le nom change en place, sur 900 ms. Ce n'est pas un
rafraîchissement de donnée : c'est le moment où l'inconnue devient quelqu'un. Un fondu croisé sur le
libellé suffit — pas de confettis, pas de badge « nouveau contact ».

---

## Écran 2 — Conversation

### En-tête

**Avatar · nom · pastille de statut · sous-titre de présence.**

L'avatar est générique tant que le contact n'est pas révélé — une initiale en dirait déjà trop.
Le sous-titre porte « en ligne » · « en train d'écrire… » · « hors ligne », exactement là où une
vraie messagerie l'affiche.

La **pastille de statut** est la seule entorse assumée à la couleur d'accent unique : un point vert
« en ligne » est une convention que tout le monde lit sans y penser depuis quinze ans, la
réinventer coûterait plus cher que l'entorse. Elle est désaturée (`#4E8C6A`), elle n'égaie rien.
Pendant les 90 s du N19, c'est elle qui rend le vide lisible comme intentionnel plutôt que comme
une panne.

Le statut vient des messages `content_type: 'system'`, dont le **`body` est le libellé à afficher
tel quel**. Le client n'invente jamais de statut, et un `system` ne crée **jamais** de bulle.

Le retour « en ligne » n'est jamais annoncé par le serveur : le client rebascule à l'arrivée du
message suivant.

### Le fil

**Il s'empile depuis le BAS**, contre le champ de saisie, comme toute vraie messagerie : quand la
conversation est plus courte que l'écran — tout début de chapitre — le vide se retrouve **en haut**,
jamais entre le dernier choix et le champ. Sans ça, la liste occupant toute la hauteur posait son
contenu en haut et laissait un grand trou au-dessus du champ (repéré par Vivien au N1). Réalisé
par `Align(bottomCenter)` + `shrinkWrap`, et non par `reverse: true` : inverser la liste ancrerait
aussi le contenu en bas, mais renverserait du même coup le repère de défilement (offset 0 = bas),
celui-là même que règlent les protections du § Le fil ne vole jamais la position de lecture.

| Élément | Rendu |
|---|---|
| Texte reçu | Bulle gauche, `bulleContact` |
| Texte envoyé | Bulle droite, `bulleJoueur` |
| `separator` | Pastille centrée, `body` **affiché tel quel** (« 23h31 ») — jamais reformaté, jamais recalculé |
| `image` | Miniature dans le fil, tap → visionneuse plein écran zoomable. **Heure de fiction en surimpression**, coin bas-droit, sur un voile sombre — nos photos sont volontairement très sombres |
| `audio` | Lecteur inline réel (just_audio) : lecture/pause, progression, durée, **puis l'heure de fiction sous la durée**. Réécoutable |

Les médias portent leur heure au même titre que les bulles texte. Une messagerie où seules les
phrases sont horodatées ne ressemble à rien.
| `system` | Jamais une bulle — statut de présence, ou écran de fin (voir plus bas) |

**Médias `placeholder://`** : cartouche neutre aux couleurs `mediaAbsentFond` / `mediaAbsentBord`,
avec une icône de type. Neutre et jamais alarmant — le joueur ne doit pas croire à une panne
réseau. Les 4 médias réels restent à produire.

### La carte d'enregistrement de contact

Posée **dans le fil**, jamais en modale : c'est un objet de messagerie, pas une interruption. Elle
arrive juste après le message où le contact se nomme, et **reste consultable** ensuite.

```
┌──────────────────────────────┐
│  (?)  Numéro inconnu         │
│       06 39 98 41 07         │
├──────────────────────────────┤
│    Enregistrer le contact    │
├──────────────────────────────┤
│          Plus tard           │
└──────────────────────────────┘
```

| Geste | Effet |
|---|---|
| **Enregistrer** | L'en-tête bascule sur `display_name` et l'avatar. **C'est ce geste qui révèle** — il remplace l'effect automatique |
| **Plus tard** | Rien. Le contact reste anonyme, la carte reste consultable, l'histoire continue |

**Aucun impact narratif** : c'est un geste, pas un choix. Aucun nœud ne bouge, aucune variable de
jeu n'est touchée. Le serveur le traite comme tel (`reveal-contact`, jamais `advance`).

**Filet de sécurité** : si le joueur n'enregistre jamais, le nœud de fin de chapitre porte
`reveal_contact` et la révélation se fait quand même. Un geste facultatif ne bloque jamais
l'histoire. Deux contrôles du script de graphe le garantissent.

Actions **empilées en pleine largeur** : « Enregistrer le contact » déborde sur deux lignes dès
qu'on le met sur une demi-largeur, et une carte de messagerie n'a pas de libellés qui débordent.

Une fois enregistrée, la carte reste mais ne propose plus rien — elle devient une trace.

#### Le motif resservira, et c'est le point

- **Karim** (ch. 3) — même carte, même anodine.
- **Le suspect** (ch. 4) — **la même carte anodine devient inquiétante**, parce que personne ne lui
  a donné ce numéro. C'est sa banalité qui fera l'effet : ne rien lui ajouter de spécial, pas de
  couleur d'alerte, pas de libellé différent. La carte doit être exactement celle de Léna.

Le numéro vient de `contacts.phone_number`, dans la **plage ARCEP réservée à la fiction**
(06 39 98 xx xx) : jamais un numéro réel, qui appartiendrait à quelqu'un.

#### Avatar

Générique pour l'instant. Un effect `set_avatar` existe déjà côté moteur : il pose un chemin
d'objet dans `variables.avatars[code]`, qui prend le pas sur `contacts.avatar_url` et est signé
comme les autres médias. Léna enverra une photo de profil plus tard — le mécanisme l'attend.

### Le marqueur « Vu. »

Sous la dernière bulle du joueur qui a été lue, aligné à droite, minuscule et sans icône. Dans une
messagerie il se remarque à peine — **sauf quand on l'attend**, et c'est exactement ce que le N19
provoque.

**Il est piloté par la fiction, jamais automatique**, et il arrive **avant** la réponse :

> Le marqueur descend dès qu'elle commence à s'occuper de sa réponse — c'est-à-dire à l'entrée dans
> l'attente d'un message qu'elle va **taper**. Bien avant l'indicateur de frappe, et donc bien avant
> le message lui-même.

L'enchaînement est celui d'une vraie messagerie : **elle lit → elle tape → elle répond.**
Un « Vu. » qui apparaîtrait après les points serait absurde — elle aurait répondu à un message
qu'elle n'avait pas encore lu.

Un message **sans frappe** (`typing_seconds == 0`) ne déclenche rien : un séparateur ou une ellipse
ne prouve pas qu'elle a lu. C'est ce qui tient le silence du N19, dont les 90 secondes sont portées
par le séparateur « 00h34 » — le marqueur ne tombe qu'à son retour, sur le premier message qu'elle
compose.

Une **règle dérivée** double le mécanisme, indispensable pour reconstruire un fil restitué depuis
l'historique où plus aucun événement n'est émis : un message du joueur est vu dès qu'un vrai
message du contact apparaît après lui. On garde le plus avancé des deux.

| Situation | Résultat |
|---|---|
| Le joueur répond, Léna enchaîne | Vu. |
| Silence du N19, elle est hors ligne | **rien** — les messages s'empilent, non lus |
| Elle revient au N20 | **tous vus d'un coup**, le marqueur descend d'un bloc |
| Après la fin du chapitre | jamais vu — elle n'a pas lu |

*Pourquoi pas une colonne* : le déclencheur est déjà dans le contenu — c'est lui qui décide quand
elle reparle. Aucune valeur à seeder, aucune à oublier au chapitre 3. Si un chapitre a un jour
besoin de « elle a lu mais n'a pas répondu », il faudra une marque explicite ; le cas ne se présente
pas au chapitre 1.

*Un seul marqueur dans tout le fil*, sous le dernier message vu — la convention des vraies
messageries. Le poser sous chaque bulle ferait du bruit, et l'effet du N20 se lit tout aussi bien :
le marqueur saute d'un coup jusqu'au dernier message écrit pendant le silence.

### Zone de choix

Boutons empilés en bas, au-dessus de la barre de saisie.

- `reply` : bouton normal.
- `ignore` : **visuellement plus effacé** (texte `texteSecondaire`, pas de fond). C'est un vrai
  choix, jamais un timeout — il doit se lire comme une option, pas comme un abandon.
- Pendant le déroulé d'une salve de messages, **la zone de choix n'est pas affichée**. Elle
  apparaît quand le dernier message est arrivé.
- Anti-double-tap : le premier tap verrouille la zone (garde déjà en place dans `EngineApi`).

---

## Le champ de saisie — la pièce la plus chargée de sens

**Un seul composant, trois modes, une seule apparence.**

| Mode | Quand | Ce que fait l'envoi |
|---|---|---|
| `decorative` | Le nœud propose des `reply`/`ignore`, ou rien du tout (silence, N19) | Le texte s'affiche à droite, **non délivré**. Rien n'est envoyé au serveur |
| `continuation` | `awaiting_interaction` ou `can_continue` sans réponse à donner | Le texte s'affiche à droite, puis déclenche `advance {continue: true}` |
| `ai_input` | `ai_moment_pending` — **prompt 3** | Saisie réelle, envoyée à `ai-chat` |

Le mode se déduit **entièrement du contrat serveur**. Le client ne connaît pas le graphe.

**Le verrouillage du champ est une notion à part, orthogonale au mode** : dès qu'un `reply`/`ignore`
ou une interaction relancée (« + » discret) sont **affichés à l'écran**, le champ ignore tout geste —
voir § Verrouillage ci-dessous. `decorative` couvre donc deux situations différentes à ce niveau :
choix affichés (verrouillé) et silence sans rien à proposer, comme le N19 (toujours actif). Le
mode, lui, ne distingue pas les deux — seule la présence de choix compte.

### Le mode `ai_input` en pratique

Le texte part vraiment vers `ai-chat`. Trois différences invisibles pour le joueur :

- **La réplique s'affiche avant la réponse du serveur.** Dans une messagerie, ce qu'on envoie
  apparaît sans attendre que l'autre ait lu. Le serveur la réécrit ensuite avec son vrai `seq`.
- **Le typing tourne pendant tout l'appel réseau**, puis le déroulé prend le relais avec le délai
  du message. Une réponse instantanée trahirait la machine.
- **Une panne ne fige rien** : le typing s'arrête, le champ reste utilisable, et le serveur a de
  toute façon fait raccrocher Léna.

### ⚠️ Les trois modes doivent être visuellement identiques

Si le champ change d'apparence quand l'IA écoute vraiment, le joueur comprend instantanément quels
moments « comptent » — et il perd le doute qui rend le mode décoratif intéressant. **Aucun indice
visuel ne distingue les modes. Jamais.** Ça reste vrai même verrouillé (voir plus bas) : le
verrouillage change l'interactivité, jamais l'aspect.

### Verrouillage — quand des choix sont affichés

**Correction de Vivien (2026-08-21) sur la version précédente de cette règle.** Le champ ignore
tout geste dès que `ChoiceArea` ou `DiscreetPlus` affichent quelque chose à l'écran — plus de focus,
plus de clavier, plus de curseur clignotant. Avant ce correctif, le champ restait cliquable :
le curseur s'activait et clignotait sans ouvrir le clavier, un geste parasite qui cassait
l'immersion sans rien apporter, puisqu'un choix visible est déjà la vraie réponse attendue.

- **Toujours sans changement d'aspect** : `IgnorePointer`, jamais `TextField(enabled: false)` —
  ce dernier grise le champ, ce que la règle ci-dessus interdit. Un joueur qui compare une capture
  d'écran ne doit rien voir de différent entre verrouillé et actif.
- **Ne couvre que la présence de choix**, pas le mode `decorative` en entier : le silence du N19
  (aucun choix affiché) laisse le champ actif — voir § Le silence du N19, « le joueur peut écrire ».
  `continuation` (le geste sur un nœud en pause) n'affiche jamais de choix non plus : intact.
- **Seul `ai_input` reste toujours actif**, choix ou pas — c'est le seul mode où le champ sert
  vraiment à quelque chose au-delà de l'ambiance.

### Règles du mode décoratif

- Les messages s'affichent à droite comme de vraies réponses, en état **non délivré** : bulle
  `bulleJoueurNonDelivre`, une seule coche grise. Ils ne « passent » jamais.
- Ils sont **persistés localement** : relire ses propres messages paniqués une fois la tension
  retombée fait partie du plaisir.
- **Aucun feedback ne trahit jamais leur inutilité, quand le champ reste actif** : pas de message
  d'erreur, pas de grisage, pas de « Léna ne peut pas répondre maintenant ». Le verrouillage
  ci-dessus n'est pas une exception à cette règle — il ne se déclenche que quand un vrai choix est
  de toute façon affiché, donc rien n'est perdu qui n'ait déjà sa réponse à l'écran.

### Ancrage technique

Un message décoratif n'existe pas côté serveur : `get-state` ne le renverra jamais. Il est stocké
localement avec le **`seq` du dernier message serveur connu au moment de l'écriture**, et
ré-intercalé à cette position au rechargement. Même stockage local que le curseur d'affichage.

Ces textes libres **ne quittent jamais l'appareil**. Au prompt 3, `ai-chat` ne recevra que la saisie
du mode `ai_input` — le serveur ne connaît pas l'historique décoratif et ne doit pas le connaître.

### Le geste de continuation

Sur un nœud en pause (N13, N16, N21), **écrire n'importe quoi fait avancer**. C'est le geste d'une
vraie conversation : tu réponds, ça avance. Aucun bouton « continuer » — sa seule présence
révélerait qu'une interaction existe ici.

**Fallback** pour le joueur qui n'écrit rien et ne touche à rien : après **25 s** d'inactivité, une
affordance très discrète apparaît. Toute action du joueur (scroll, tap sur un média, ouverture du
zoom) **remet le compteur à zéro** — et la fenêtre passe à **30 s** si le nœud contient un média
non encore ouvert, puisque dans 3 cas sur 6 le média *est* l'interaction.

---

## L'aparté — un pattern générique, pas un détail du moment IA

Une ligne de contexte discrète, posée **dans le flux de la conversation**, sous la dernière bulle
et avant la zone de choix : gris, plus petit que le texte normal, centrée. Une ligne de narration
qui cadre un moment — sans être un indice, ni une consigne, ni jamais dans le champ de saisie
lui-même (qui ne change jamais d'aspect selon le mode, voir plus haut).

**Ce n'est pas une pièce du moment IA.** Le N9 est aujourd'hui le seul nœud du chapitre 1 à s'en
servir, mais le mécanisme ne le sait pas et ne doit pas le savoir — n'importe quel nœud futur peut
en porter un : signaler un silence volontaire, préciser un changement de contexte mineur, ou —
l'usage actuel — cadrer l'attente d'une vraie réponse à la saisie libre (« Léna attend une vraie
réponse... »).

**Piloté par le contenu, comme la narration de l'écran noir** : un champ `nodes.aparte` (texte,
nullable), pas une chaîne codée en dur dans le client ni une condition sur le mode du composer.
`null` = ce nœud n'en porte pas, le comportement par défaut pour tous les nœuds sauf ceux qui en
déclarent un explicitement. Voir LOGIQUE.md § L'aparté pour le mécanisme complet côté serveur.

**Affiché seulement quand le joueur peut agir** : ni pendant un déroulé, ni pendant que le contact
« écrit ». Il disparaît dès que Léna répond ou que le joueur envoie, et réapparaît avant chaque
tour suivant si le nœud courant en porte toujours un.

## La carte d'entrée — la « pochette » de l'histoire

Un seul écran, affiché **une seule fois**, avant même le premier panneau de l'intronisation. Le
joueur n'a pas encore vu le titre de l'histoire que la décision de consentement est déjà prise :
plus simple à comprendre hors contexte (pas de moment IA en cours à interrompre pour poser la
question), et ça évite d'interrompre l'échange avec Léna la première fois qu'il compte vraiment.

**Structure, de haut en bas** :
- Moitié supérieure de l'écran : image de couverture (`stories.cover_url`), plein cadre, bord à
  bord y compris sous la barre de statut. Dégradé transparent → noir sur son tiers inférieur, pour
  que l'image se dissolve dans le fond plutôt que de s'arrêter net sur un bord.
- Icône de l'app, petite, centrée, à la jonction entre l'image et le texte.
- Titre de l'histoire, blanc plein.
- Accroche, gris clair, centrée, sur fond noir uni (jamais sur l'image, pour la lisibilité).
- Case de consentement IA + texte, avec « Politique de confidentialité » en lien souligné. Case
  **non cochée par défaut** (bible §9 — un consentement ne se présume pas).
- Bouton « Entrer », blanc plein, texte noir, pleine largeur, en bas.

**Le bouton « Entrer » est inactif tant que la case n'est pas cochée** — consentement obligatoire,
décision explicite de Vivien qui revient sur le choix précédent (le bouton était auparavant
toujours actif, la case ne décidant que de la valeur envoyée). Un tap, une fois actif, envoie
`{consent: true}` et referme l'écran d'un coup ; il n'y a pas de second écran à traverser.

⚠️ **Réserve RGPD signalée et sciemment acceptée** : la case porte sur un traitement précis (l'IA du
N9), pas sur les conditions d'utilisation en général — en conditionner l'accès à l'histoire entière
est le genre de chose qui peut fragiliser le caractère « librement donné » du consentement (RGPD,
art. 7§4). Conséquence concrète : le chemin « consentement refusé » (`ai_consent_refuse`,
`nodes.ai_refus_node_id`, la variante vouvoiement de la clôture du N9) ne se déclenche plus en usage
normal depuis cette carte — il ne reste accessible que par le chemin de repli ci-dessous (progression
antérieure à la carte d'entrée, ou client qui l'aurait contournée). Le mécanisme n'est pas retiré :
il devient juste rarement emprunté.

Titre, accroche et image viennent tous du serveur (`stories.title/tagline/cover_url`), rien n'est
codé en dur — pensé pour resservir tel quel avec les futures histoires de la bibliothèque. Un ancien
écran de consentement séparé (`ConsentScreen`) reste utilisable en repli, à la première saisie
libre — une progression antérieure à la carte d'entrée, ou un client qui l'aurait contournée — mais
ne devrait plus s'y déclencher en usage normal. Voir LOGIQUE.md § Consentement.

**Animation d'entrée, une seule fois, jamais en boucle** : l'image apparaît en fondu doublé d'un
flou qui se dissipe (~700 ms) — impression de mise au point, comme un souvenir qui se précise. Puis
icône, titre, accroche, case et bouton apparaissent en fondu séquentiel, décalés d'une centaine de
millisecondes chacun. Respecte le réglage d'accessibilité « réduire les animations »
(`MediaQuery.disableAnimations`) : dans ce cas, tout apparaît directement, sans transition.

⚠️ **Le lien vers la politique de confidentialité manque encore** (`PRIVACY_URL`). Le texte reste
affiché tel quel (« Politique de confidentialité » souligné), mais le lien ne mène nulle part tant
que l'URL n'est pas configurée — **l'app ne peut pas sortir dans cet état** : le RGPD impose de
pouvoir consulter le traitement auquel on consent.

---

## Les interactions cachées

Six au chapitre 1. Elles sont **découvertes, jamais annoncées**.

### ⚠️ Protection de mécanique, pas confort de lecture

Le serveur renvoie les interactions dans le **même tableau `choices`** que les réponses, distinguées
par `kind: 'interaction'`. **Le client doit impérativement les filtrer.**

Ce n'est pas une question de mise en page. Au **N17**, le label de l'interaction vaut
« C'est quoi ce bruit derrière vous ? » — soit l'indice lui-même. L'afficher comme un bouton
donnerait au joueur l'incohérence audio qu'il est censé repérer seul, et détruirait la mécanique
de `lucidite`. Une interaction ne devient **jamais** un bouton.

### Comment elles se déclenchent — une règle, pas une liste

Le client ne connaît pas le graphe : il ne peut pas dire « au N16, c'est un zoom ». La règle se
déduit du **contrat**, et couvre les six sans exception :

> **Si le nœud courant a apporté un média, l'interaction se déclenche par le geste sur ce média**
> (zoomer une photo, réécouter un vocal). **Sinon, c'est une chose que le joueur dit**, et elle
> passe par le « + » discret.

| Nœud | Média apporté | Déclencheur |
|---|---|---|
| N10, N16, N21 | photo | Tap → visionneuse, puis **le zoom lui-même** |
| N17 | vocal | **Réécoute** — la réplique n'existe qu'après |
| N8 | aucun | « + » → les deux questions, mutuellement exclusives |
| N13 | aucun | « + » → l'insistance |

Seul le **dernier média du fil** est actif : zoomer une vieille photo ne déclenche rien, et ne
signale rien non plus.

### Le « + » discret

Une icône `+` à gauche, couleur tertiaire, à l'emplacement où une vraie messagerie met son bouton
de pièce jointe — c'est exactement ce qu'on veut qu'il ait l'air d'être. **Il n'annonce jamais son
contenu** : les répliques ne s'ouvrent qu'au tap, dans une feuille. Au N8 il porterait sinon les
deux pistes d'enquête en clair ; au N17, l'indice lui-même.

### Règles communes

- **Usage unique** : consommée, elle disparaît. Le serveur la retire de `choices` via
  `interactions_faites` — le client n'a qu'à ne pas la ré-proposer.
- **Aucune récompense visible.** Pas d'animation de succès, pas de « +1 indice ». Celui qui trouve
  ne doit rien voir clignoter ; celui qui passe à côté ne doit pas le sentir.
- **Affordance subtile** : la photo invite au tap par sa seule présence, le vocal par son lecteur.

---

## « Et vous ? » — quand une question attend une vraie réponse

Certaines questions du dialogue attendent une réponse **écrite**. Au N16, sur la branche 🔍, Léna
demande déjà « Oui, mais je n'arrive pas à le lire d'ici, et vous ? » — la question existait dans le
contenu sans aucune suite fonctionnelle.

**N'importe quel texte déclenche l'interaction du nœud.** « Sentinel Pro », une faute de frappe,
une devinette fausse ou « je sais pas » : identiques. Ce qui compte narrativement est le geste de
répondre à Léna comme à un interlocuteur, pas l'exactitude du mot — et valider du texte libre côté
serveur est précisément ce qu'on s'interdit pour ce champ. Léna accuse réception sans se prononcer
sur la justesse (« Merci d'avoir essayé, ça compte pour moi que vous cherchiez avec moi. »).

**Le zoom reste ouvert en parallèle.** Écrire est une voie de plus vers l'indice, jamais un passage
obligé — et sur les branches 🛡 et 🧠, où Léna ne pose pas la question, c'est même la seule.

**L'apparence du champ ne change jamais**, conformément à la règle qui gouverne tout le reste : ce
qui change est ce que le geste produit, pas ce qu'il montre.

⚠️ **Avant cette mécanique, écrire à ce moment faisait perdre l'indice.** Le N16 n'expose aucun
`reply` et `can_continue` y est vrai : le champ était donc en mode `continuation`, et y écrire
appelait `advance {continue}` — le joueur sautait au N19 **en croyant avoir répondu**. Un bug
invisible en jouant, puisque rien ne signalait l'échec. `envoyerTexte` teste donc l'attente
**avant** le mode continuation.

**L'aparté annonce l'attente, et suit exactement ses conditions.** Posé sur le nœud
(`nodes.aparte`), il ne s'affiche que lorsque `attente_saisie` est ouverte : sans ce filtre il
apparaîtrait dès l'arrivée de la photo, sur les trois branches, en annonçant une attente qui
n'existe pas encore. **Et il disparaît dès que le joueur écrit** — l'invite a fait son travail,
la laisser au-dessus de sa propre réponse n'apporte plus rien. Vaut pour tous les apartés, moment
IA compris.

**Réutilisable tel quel** : un nœud des ch. 3-5 qui pose une question ouverte dans son dialogue n'a
besoin que d'un `attente_saisie` renseigné — conditions, réplique d'accusé de réception — et de
l'interaction que la réponse déclenche. Rien à écrire côté client.

## L'effet de tension — bordure rouge, et parfois un battement

**Un marqueur par message, pas une propriété de nœud.** `tension` se pose au cas par cas, sur la
bulle dont le contenu le justifie — pas sur une scène entière décrétée « tendue ». Le N19 en est
l'usage le plus dense, mais il n'en a pas l'exclusivité.

| | Traitement |
|---|---|
| Bulles de Léna en tension | Bordure fine `tensionBordure` + voile `tensionVoile` de la même teinte, à l'intérieur |
| Bulles du joueur, séparateurs, présence | **Rien**, jamais |
| Fond sonore | Seulement là où un message porte une URL d'ambiance — voir plus bas |

**Où il s'applique aujourd'hui :**

| Message | Visuel | Son |
|---|---|---|
| N19 #0 → #3, micro-choix compris | ✅ | `heartbeat-n19.mp3` en boucle, 30 %, coupure nette |
| N14 #2 — « mon cœur bat à 200 battements par minute » | ✅ | **aucun** |

Le N14 est le premier usage hors N19, et il illustre la règle : le texte décrivait lui-même
l'accélération cardiaque, et l'absence de rouge s'y voyait en jouant. **Le visuel et le son sont
deux décisions séparées** — le battement reste réservé au N19, parce qu'un fond sonore qui revient
à chaque frayeur cesserait d'en être un.

**Fixe, jamais clignotant ni pulsé.** Une animation détournerait la lecture dans un moment déjà
chargé en urgence. Et le voile reste sous 12 % d'opacité : **le texte doit rester parfaitement
lisible**, c'est la contrainte qui prime sur l'effet.

Le rouge `#6B2C2C` a été **validé sur appareil** le 24 août 2026 : « suffisamment pour attirer
l'attention et la garder, on sent qu'il se passe quelque chose de grave. »

**Le client ne sait pas de quel nœud sort une bulle, et n'a pas à le savoir.** Chaque message porte
un drapeau `tension`, de la même famille que `phantom_typing_at` ou `haptic_at` : une directive de
mise en scène, jamais une information de graphe. C'est précisément ce qui permet d'en poser un sur
le N14 sans rien changer au code. Le message déclencheur porte en plus l'URL du son ; les
suivants laissent la boucle tourner, et **la première réplique de Léna sans tension la referme**.
Une bulle du joueur ne referme jamais rien — sinon le battement s'arrêterait dès la première
réponse à un micro-choix.

**La bordure survit à la relecture, le son non.** `player_messages.tension` est la seule directive
de mise en scène persistée : remonter le fil plus tard montre toujours les bulles rouges, « c'est
cohérent avec ce qui s'est vraiment passé à ce moment de l'histoire ». Rejouer un battement de
cœur en relisant, en revanche, n'aurait aucun sens.

**`SonAmbiance` est un lecteur séparé de `MusiqueNarrative`**, et volontairement générique : les
chapitres suivants auront d'autres nappes à poser sous une scène. La musique narrative coupe
systématiquement ce qui jouait avant — une ambiance, elle, se superpose. Les deux s'enregistrent
auprès du même `IndicateurSonore`, qui coupe tout d'un tap sans avoir à savoir qui joue.

## Le silence du N19 — occuper sans remplir

90 secondes, le plus long silence du chapitre. **Le silence est le contenu de la scène : l'expliquer
ou l'abréger le détruit.** Aucune narration off, aucun overlay, aucun raccourcissement.

Tout se joue avec les codes d'une vraie messagerie :

1. Le statut passe à **« hors ligne »** dans le sous-titre. Rien d'autre, aucun texte explicatif.
2. Le joueur peut écrire — ses messages s'accumulent en **non délivrés**. Il agit sur son angoisse
   au lieu de la subir.
3. **À 45 s : le typing apparaît 2 secondes, puis s'éteint sans qu'aucun message n'arrive.**
   C'est l'élément le plus important de la séquence. Le contraste avec le vide est ce qui rend ces
   deux secondes cruelles — un écran uniformément mort s'en priverait.
4. **Vibration discrète unique à 60 s**, sans notification.

Les deux battements ne sont pas des constantes du client : ils sont **portés par le contenu**,
via `messages.phantom_typing_at` et `haptic_at` sur le séparateur « 00h34 » qui porte les 90 s.
Un futur chapitre peut donc en placer ailleurs sans toucher au code. Sémantique exacte des offsets :
LOGIQUE.md § Mise en scène d'une attente.

⚠️ **Le faux typing est visuellement identique au vrai.** C'est tout son intérêt : le joueur ne peut
pas savoir, avant l'extinction, qu'aucun message ne viendra.

Le sous-titre « hors ligne » est ce qui rend le vide **lisible comme intentionnel** plutôt que comme
un bug — c'est tout l'argument en faveur de cet emplacement.

*Mécanisme du typing fantôme : voir TODO.md § D5, en attente d'arbitrage.*

---

## Écran 3 — Fin de chapitre

Sortie du fil, plein écran, contenu **centré verticalement** — jamais plaqué en haut, refonte
prompt 4 (notifications + fin de chapitre).

**Règle de basculement** : un message `content_type: 'system'` sur un nœud `kind: 'chapter_end'` ne
va pas dans le fil — il devient le texte de cet écran. (Un `system` ailleurs est un statut de
présence. Un `system` n'est jamais une bulle, dans les deux cas.)

**Contenu, dans l'ordre** :

1. **Le cliffhanger**, en trois temps machine à écrire (inchangé) — le texte du message système,
   découpé sur la ponctuation forte.
2. **Séparateur discret**, une simple ligne de 32px.
3. **Le teaser du chapitre suivant** : label « CHAPITRE {position} — {titre} » (petit, gris,
   majuscules espacées — jamais le titre seul : le numéro vient de `next_chapter_position`, jamais
   codé en dur, pour rester correct au chapitre 3, 4…), puis `next_chapter_teaser_text` si le
   chapitre le porte déjà (null tant que non écrit — pas de ligne affichée, pas de placeholder
   inventé).
4. **Trois actions**, hiérarchie visuelle décroissante — voir ci-dessous.
5. « La suite de {nom de l'app}, prochainement. » et « Un retour, une note, une idée ? Écrivez-nous »
   (ce dernier reste un texte décoratif, pas un lien — aucune destination n'existe à ce jour).
6. « Revenir aux messages » — inchangé, referme l'écran.

**Plus de compte à rebours en chiffres.** L'ancien `hh:mm:ss` recalculé chaque seconde a disparu :
le joueur programme un rappel plutôt que de regarder un chiffre descendre. `unlocked_at` reste lu
(c'est la date qu'on programme), simplement plus jamais affiché brut.

### Les trois actions

| # | Apparence | Libellé | Comportement |
|---|---|---|---|
| 1 | Bouton plein, le plus visible | « Me prévenir dans {délai lisible} » | Programme la notification locale — voir § Notification locale de déblocage, LOGIQUE.md |
| 2 | Bouton contour | « Débloquer ce chapitre » | Stubé : aucun système d'achat n'existe. Tap → `SnackBar` « bientôt disponible », jamais un bouton grisé (se lirait comme une panne, pas comme une fonctionnalité à venir) |
| 3 | Lien discret, le moins visible | « Voir toutes les offres » | Même stub — écran à construire séparément |

Le délai (« dans 8h ») vient de `next_chapter_unlock_delay_minutes`, formaté par
`services/duree_lisible.dart` — jamais un « 8h » codé en dur : un futur chapitre choisira peut-être
un autre délai.

**Le bouton « Me prévenir » a trois états, jamais un grisage** (même principe que le champ de
saisie — un état informatif reste un vrai bouton) :

- **Initial** : le libellé ci-dessus, tapable.
- **Programmé** (permission accordée) : « Vous serez prévenu·e », non tapable une seconde fois —
  ici un vrai état terminal, pas un moment IA à cacher.
- **Refusé** : « Vous pourrez revenir consulter l'histoire », reste tapable (referme l'écran) —
  jamais un blocage, jamais une culpabilisation pour avoir refusé la permission.

Quand `next_chapter_pending` est vrai, le chapitre suivant existe (stub) mais n'a pas encore de
contenu — les trois actions restent affichées (rien n'empêche de programmer un rappel pour un
chapitre encore en écriture), seul le teaser reste absent tant que `teaser_text` est null.

---

## État de l'implémentation

| Composant | Fichier | Statut |
|---|---|---|
| Jetons, thème | `theme/tokens.dart`, `theme/app_theme.dart` | ✅ |
| Bulle, séparateur, photo, visionneuse, audio, typing | `widgets/message_widgets.dart` | ✅ |
| Champ de saisie et ses 3 modes, zone de choix | `widgets/composer.dart` | ✅ |
| Moteur de déroulé (délais, typing intermittent, battements, skip, reprise) | `services/playback.dart` | ✅ |
| Horloge de fiction | `services/fiction_clock.dart` | ✅ |
| Mémoire locale (curseur, file en attente, décoratifs) | `services/local_store.dart` | ✅ |
| Écran de conversation | `screens/conversation_screen.dart` | ✅ |
| Séquence d'intronisation | `screens/intro_screen.dart` | ✅ |
| Aiguillage d'entrée | `screens/root_screen.dart` | ✅ |
| Carte d'entrée (couverture, icône, titre, accroche, consentement, animations) | `screens/entry_card_screen.dart` | ✅ |
| Interactions cachées (geste et « + ») | `widgets/composer.dart`, `conversation_screen.dart` | ✅ |
| Liste des conversations | `screens/conversation_list_screen.dart` | ✅ |
| Écran de fin de chapitre | `screens/chapter_end_screen.dart` | ✅ |

Le lecteur audio simule la lecture : les fichiers n'existent pas encore. Son signal de **réécoute**
est en revanche réel — c'est lui qui portera l'interaction cachée du N17 en Phase 3.

## Le son — deux usages, deux politiques

Elles ne sont pas interchangeables : une note vocale et une musique d'ambiance n'ont pas les mêmes
droits sur le téléphone du joueur. Voir `services/audio_session_config.dart`.

| | Musique d'intronisation | Note vocale de Léna |
|---|---|---|
| Catégorie iOS | `ambient` | `playback` |
| Mode silencieux | **respecté** — si le téléphone est en silencieux, son propriétaire a dit non | **ignoré**, comme dans toutes les messageries |
| Autre audio en cours | **mixé**, jamais coupé | interrompu |
| Boucle | jamais | jamais |

**Pourquoi le vocal passe outre le silencieux** : le joueur l'a tapé explicitement, et il porte un
indice — le fond sonore urbain de la bible §7 n° 3. Un vocal muet rendrait cette incohérence
inatteignable, donc supprimerait une des six interactions cachées.

## Sons de message

Deux effets très courts (100-200 ms) : réception d'un message de Léna, envoi d'une réponse du
joueur. Discrets, type messagerie, **jamais ludiques** — un son qui « récompense » casserait
l'illusion aussi sûrement qu'un score à l'écran.

### Trois niveaux, dans cet ordre

| # | Source | Quand |
|---|---|---|
| 1 | **Fichier de l'histoire** (`stories.sound_*_url`) | S'il existe. Il gagne toujours : une histoire peut avoir son identité sonore |
| 2 | **Son système** | Là où le téléphone en offre de courts et neutres — c'est-à-dire **iOS** |
| 3 | **Asset de repli** synthétisé, sobre | Partout ailleurs, donc **Android** |

*Pourquoi pas les sons système partout* : Android n'a pas d'API publique pour « un son de message
court et sobre ». On n'y récupère que le son de notification **choisi par l'utilisateur**, dont on
ne maîtrise ni la durée ni le caractère — ça peut être un jingle de trois secondes. La contrainte
« 100-200 ms, discret, jamais ludique » y serait invérifiable.

### ⚠️ Jamais le tri-tone SMS

Les identifiants système retenus sont volontairement **neutres** : un « tink » mat (1057) à la
réception, un tock sec (1306) à l'envoi, le tock du clavier (1104) à la frappe.

Le tri-tone SMS (1003) et le whoosh d'envoi (1004) sont **exclus**. Ce sont les sons que tout le
monde reconnaît : dans une histoire qui s'ouvre sur « vous recevez un SMS d'un inconnu », les jouer
ferait quitter l'app au joueur pour vérifier ses vrais messages. L'illusion est déjà portée par
l'interface, le typing et l'heure de fiction — le son n'a pas besoin d'imiter le système, il a
besoin de ne pas détonner.

Ces identifiants ne sont pas documentés par Apple. Stables depuis des années et très employés, mais
ce sont des constantes à ajuster à l'oreille : elles sont isolées dans
`services/system_sounds.dart` exprès.

### Mode silencieux

Niveaux 1 et 3 en catégorie **`ambient`**, comme la musique d'intronisation : respecte le mode
silencieux et n'interrompt pas ce que l'utilisateur écoute. Le niveau 2 passe par
`AudioServicesPlaySystemSound`, qui respecte l'interrupteur silencieux nativement.

Un bip de messagerie n'a aucune raison de passer outre — contrairement à la note vocale, que le
joueur tape explicitement et qui reste en `playback`.

### Ce qui sonne, et ce qui ne sonne jamais

La décision tient dans une fonction pure, `SoundEffects.pour()`, testée sans audio : c'est la seule
pièce capable de détruire un effet du chapitre, elle ne doit pas dépendre d'un lecteur.

| Cas | Son |
|---|---|
| Message de Léna (texte, photo, vocal) | réception |
| Réponse du joueur | envoi |
| **Démarrage du typing réel** | frappe — une seule fois par message, pas à chaque rafale |
| **Séparateur horaire** | ❌ ce n'est pas un message |
| **Changement de présence** (`system`) | ❌ |
| **Message décoratif** | ❌ il ne part pas — le faire sonner mentirait au joueur |
| **Typing fantôme** | ❌ **par construction** — le moteur ne signale que le typing réel |
| **Historique restitué** à la réouverture | ❌ **par construction** |

Les deux derniers ne sont pas des conditions mais des propriétés du chemin de code : le son est
déclenché par la **livraison** d'un message. Le typing fantôme n'en délivre aucun — c'est tout
l'enjeu, un bip laisserait croire qu'un message est arrivé et l'extinction sans message perdrait
son sens. Et l'historique est versé directement dans le fil sans passer par le moteur, donc pas de
rafale de bips au retour dans l'app.

Le **silence du N19** en découle : « Léna est hors ligne » ne sonne pas, et les 90 secondes qui
suivent ne délivrent rien.

## Le système sonore — recommandation et indicateur

Deux ajouts transverses, tous deux liés à la même distinction : un son **narratif** (musique
d'ambiance des écrans noirs — intro, N19, fin de chapitre — et note vocale) contre les bips de
messagerie et le typing, déjà attendus dans une messagerie et couverts § Sons de message ci-dessus.
Les seconds ne concernent ni la recommandation ci-dessous ni l'indicateur : personne ne s'étonne
qu'une messagerie fasse un petit bruit à la réception.

### Recommandation casque, sur la carte d'entrée

Une ligne discrète sous l'accroche : icône haut-parleur, « Casque ou haut-parleur recommandé »,
`texteTertiaire`, même registre que le reste de l'écran — une recommandation de confort, pas un
avertissement. Affichée que l'histoire porte une accroche ou non : ce n'est pas du contenu narratif,
donc pas conditionné par ce que l'histoire fournit.

### L'indicateur — pendant la lecture

Une icône haut-parleur discrète apparaît près de la zone de statut système **dès qu'un son
narratif joue**, avec une pulsation légère tant qu'il joue — jamais éteinte complètement, c'est une
présence continue, pas un clignotement. Tapable : coupe tout net, sans passer par les Réglages du
téléphone.

**Ce que « son narratif » couvre précisément** : tout ce qui passe par `MusiqueNarrative` (musique
d'intronisation, écran noir du N19, écran de fin) et la note vocale (`AudioBubble`). Rien d'autre —
en particulier jamais les sons de `SoundEffects` (réception, envoi, frappe), qui restent muets pour
cet indicateur comme pour la recommandation ci-dessus.

**Générique et transversal, pas propre à un écran** : monté une seule fois au niveau de l'app
(`MaterialApp.builder`, `main.dart`), au-dessus de tout le reste — un écran noir narratif et une
bulle vocale dans le fil n'ont aucune zone de statut en commun autrement. `IndicateurSonore`
(`services/indicateur_sonore.dart`) est un registre à instance unique : chaque source s'enregistre
avec son propre arrêt en démarrant, se désinscrit en s'arrêtant naturellement ; l'indicateur reste
affiché tant qu'au moins une source est active. Un futur chapitre qui ajoute une nouvelle source
sonore narrative (chapitre 3, 5) n'a rien à changer dans le registre ni dans l'icône — juste à
s'enregistrer au bon moment, comme `MusiqueNarrative` et `AudioBubble` le font déjà.

**Le tap coupe, ne met jamais juste en pause** : le registre vide sa liste immédiatement (avant même
d'appeler les arrêts), pour que l'icône disparaisse sans attendre qu'une source asynchrone confirme
qu'elle s'est bien arrêtée.

## Pause automatique — sans bouton

**Il n'y a pas de bouton pause, et il ne doit pas y en avoir** : ce serait un objet de jeu, et rien
dans une messagerie ne met une conversation en pause.

Le vrai besoin est ailleurs : quand le joueur doit s'interrompre, le déroulé ne doit pas continuer
sans lui. Il se gèle donc **quand l'app passe en arrière-plan**, et reprend à l'ouverture. Aucun
élément ajouté à l'écran, et c'est le comportement attendu — les messages arrivent quand on regarde.

- Le déroulé s'arrête **au message en cours**. Ce qui reste est persisté avec ses délais (la file
  en attente de D4).
- À la reprise, le message dont l'attente était entamée **repart de son début**. On ne mémorise pas
  la fraction écoulée, et c'est volontaire : reprendre à 3 secondes d'un silence de 90 en
  supprimerait tout l'effet.
- **Si le joueur reste dans l'app sans pouvoir suivre, on ne fait rien.** Il remontera le fil,
  comme avec de vrais SMS.

## Outils de développement

Skip du déroulé, skip de l'intro, bouton de réinitialisation. Tous pilotés par `Env.outilsDebug`.

⚠️ **`kReleaseMode` est dans la constante elle-même**, pas seulement sur les points d'appel. Un
oubli de garde en aval livrerait l'outil en production — c'était le cas du skip de l'intro, qu'un
simple tap escamotait. Une seule source de vérité, et tout est `const` donc l'arbre est élagué.

Vérifié sur un vrai binaire release : `Réinitialiser l'histoire`, `restart_alt` et `fast_forward`
sont **absents** des chaînes de `App.framework`, alors que `Message`, `Messages` et `en ligne` y
figurent. Contrôle à refaire si un nouvel outil de debug est ajouté.

## L'écran de Réglages

**Accessible depuis la liste des conversations uniquement.** Une icône discrète dans l'en-tête,
là où une vraie messagerie met ses paramètres. Jamais depuis le fil avec Léna : là-bas, aucun
élément ne doit rappeler qu'on est dans une app.

Apparence : liste sobre avec interrupteurs, même noir que le reste. Un écran de réglages
d'application ordinaire, pas un menu de jeu.

| Section | Contenu |
|---|---|
| Son | Sons · Vibrations |
| Accessibilité | Ralentir le rythme |
| Confidentialité | Politique en **texte intégral embarqué** |
| Données | Effacer ma progression |

**Rien d'autre.** Pas de statistiques, pas de progression, pas de chapitres débloqués : ce sont
des objets de jeu, et cette app n'en est pas une.

Les réglages ne sont **pas cloisonnés par joueur**, contrairement au LocalStore. Couper le son ou
ralentir le rythme est une préférence de la personne qui tient le téléphone, pas de la partie : la
perdre en réinitialisant serait absurde, et franchement pénible pour qui a besoin du réglage
d'accessibilité.

La politique est **embarquée et pas liée** : lisible hors ligne, impossible à pointer vers une
page morte, versionnée avec le code qu'elle décrit. C'est aussi ce qui lève le blocage
`PRIVACY_URL` — l'écran de consentement du moment IA a enfin quelque chose à montrer.

## Le clavier ne masque jamais les choix

Les choix (structurants, micro-choix, interactions cachées) vivent **dans la
liste défilable**, en dernière position — pas dans une zone fixe sous elle.

Une zone fixe ne peut que déborder quand le clavier ouvre et mange la moitié
de l'écran : sur un bloc chargé (plusieurs réponses + interactions), la somme
de leurs hauteurs pouvait dépasser l'espace restant une fois le clavier
ouvert. En release, un débordement de `Column` est **clipé en silence** — pas
de hachures jaune-noir, juste du contenu qui disparaît sous la barre de titre.
Une liste, elle, ne déborde jamais : elle défile.

Seul le champ de saisie reste fixe en bas — c'est la seule chose qui doit
toujours être joignable, quoi qu'il arrive au reste.

Taper le champ est un geste **délibéré** : contrairement à une livraison
spontanée, il a le droit de ramener le joueur en bas pour voir ce qu'il peut
répondre, même s'il était remonté relire. Ce n'est pas lui voler sa position,
c'est répondre à son geste.

## Le silence avant les choix

Les choix apparaissent dès l'affichage du dernier message, mais ne répondent pas au tap pendant
un court silence — de **1 à 2 s**, selon la longueur de ce message (900 ms + 10 ms/caractère,
borné). Sans ça, un joueur qui lit encore tape parfois avant d'avoir fini, surtout sur un bloc de
plusieurs messages.

**Rien à l'écran ne distingue le silence de l'état normal.** Pas de grisé, pas d'icône d'attente :
`TextButton.styleFrom` fixe la même couleur pour tous les états, verrouillé ou non. Le joueur se
sent juste moins bousculé — il ne doit jamais pouvoir repérer mécaniquement pourquoi. Même règle
pour le « + » des interactions cachées : verrouillé pendant le même silence.

## Le fil ne vole jamais la position de lecture

Remonter dans le fil pour relire ne doit jamais être interrompu par une nouvelle livraison —
c'est le réflexe de toute vraie messagerie. Le défilement automatique vers le bas ne s'applique
que si le joueur est **déjà à moins de 120 px du bas** au moment où le nouveau contenu arrive ; au-
delà, sa position ne bouge pas d'un pixel.
