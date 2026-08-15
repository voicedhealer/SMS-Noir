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

Nom du contact, et **en sous-titre le statut de présence** : « en ligne » · « en train d'écrire… » ·
« hors ligne ». C'est exactement là qu'une vraie messagerie l'affiche.

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
| `image` | Miniature dans le fil, tap → visionneuse plein écran zoomable |
| `audio` | Lecteur inline, **réécoutable** |
| `system` | Jamais une bulle — statut de présence, ou écran de fin (voir plus bas) |

**Médias `placeholder://`** : cartouche neutre aux couleurs `mediaAbsentFond` / `mediaAbsentBord`,
avec une icône de type. Neutre et jamais alarmant — le joueur ne doit pas croire à une panne
réseau. Les 4 médias réels restent à produire.

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

### Comment elles se déclenchent

| Interaction | Geste |
|---|---|
| Zoom récépissé (N10), autocollant (N16), porte-clés (N21) | Tap sur la photo → visionneuse. Le zoom lui-même est la mécanique |
| Réécoute du vocal (N17) | Rejouer l'audio. La réplique n'apparaît **qu'après** la réécoute |
| Relance (N8) | Un « + » discret près de la zone de choix, ouvrant les deux questions |
| Insistance (N13) | Nœud en pause : le geste est proposé par le contenu lui-même |

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
| Interactions cachées (branchement des gestes) | — | Phase 3 |
| Liste des conversations | — | Phase 3 |
| Écran de fin de chapitre | — | Phase 3 |

Le lecteur audio simule la lecture : les fichiers n'existent pas encore. Son signal de **réécoute**
est en revanche réel — c'est lui qui portera l'interaction cachée du N17 en Phase 3.

## Outils de développement

Un **bouton skip** du déroulé temporel, indispensable pour tester ce flux des dizaines de fois.
Piloté par `Env.outilsDebug`, absent en release. Il ne doit exister aucun chemin par lequel il
apparaisse en production.
