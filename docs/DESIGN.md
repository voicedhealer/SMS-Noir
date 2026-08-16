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
- **Largeur max de bulle** : 78 % de l'écran. Au-delà, le fil cesse de ressembler à une conversation.
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
| 1 | « Jeudi 13 août 2026. » | 2 s |
| 2 | « Jeudi soir. » / « Rien de prévu. » | 2 s |
| 3 | « Le téléphone posé à côté de vous. » / « La soirée sera tranquille. » | 2 s |
| 4 | « 22h47. » | **2,5 s** — c'est le basculement |

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

**Seule exception : le compte à rebours de fin de chapitre**, qui est du temps réel.

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
| `decorative` | Le nœud propose des `reply`/`ignore` | Le texte s'affiche à droite, **non délivré**. Rien n'est envoyé au serveur |
| `continuation` | `awaiting_interaction` ou `can_continue` sans réponse à donner | Le texte s'affiche à droite, puis déclenche `advance {continue: true}` |
| `ai_input` | `ai_moment_pending` — **prompt 3** | Saisie réelle, envoyée à `ai-chat` |

Le mode se déduit **entièrement du contrat serveur**. Le client ne connaît pas le graphe.

### ⚠️ Les trois modes doivent être visuellement identiques

Si le champ change d'apparence quand l'IA écoute vraiment, le joueur comprend instantanément quels
moments « comptent » — et il perd le doute qui rend le mode décoratif intéressant. **Aucun indice
visuel ne distingue les modes. Jamais.**

### Règles du mode décoratif

- Les messages s'affichent à droite comme de vraies réponses, en état **non délivré** : bulle
  `bulleJoueurNonDelivre`, une seule coche grise. Ils ne « passent » jamais.
- Ils sont **persistés localement** : relire ses propres messages paniqués une fois la tension
  retombée fait partie du plaisir.
- **Aucun feedback ne trahit jamais leur inutilité** : pas de message d'erreur, pas de grisage du
  champ, pas de « Léna ne peut pas répondre maintenant ». Interdit.

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

Sortie du fil, plein écran.

**Règle de basculement** : un message `content_type: 'system'` sur un nœud `kind: 'chapter_end'` ne
va pas dans le fil — il devient le texte de cet écran. (Un `system` ailleurs est un statut de
présence. Un `system` n'est jamais une bulle, dans les deux cas.)

Contenu : le texte du message système, le titre du chapitre suivant, et un compte à rebours vers
`unlocked_at`. **Le compte à rebours est purement décoratif** — seul le serveur débloque, et
l'horloge du téléphone n'a aucun pouvoir.

Quand `next_chapter_pending` est vrai, le chapitre suivant est annoncé comme « à venir » : il existe
mais n'a pas encore de contenu.

Prévoir la place d'un futur bouton premium (déblocage immédiat) — non fonctionnel au prompt 2.

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
