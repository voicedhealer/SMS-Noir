# TODO.md

## 🔴 Addendum transition N20-N9 — TERMINÉ côté code, deux témoins visuels dus à Vivien

Phases A, B et C terminées, vérifiées côté back/tests — voir MEMOIRE.md 2026-08-18/19. Aucun outil
d'automatisation de tap n'est disponible sur cette machine (pas d'accès d'aide autorisé) : deux
correctifs UI n'ont pu être vérifiés que par lecture de code + tests widget sur média `placeholder`,
jamais à l'œil sur device en conditions réelles.

- [ ] **Vidéo de transition N20→N9 (Phase B).** Le bon message vidéo arrive en position 0 du N9 côté
      serveur, l'app démarre et tourne avec `video_player` sans crash. La lecture elle-même — plein
      écran, bonne durée (~6 s), enchaînement propre sur le texte suivant — reste à confirmer en
      jouant.
- [ ] **Zoom plein écran de la visionneuse photo (Phase C).** `SizedBox.expand` + `BoxFit.contain`
      posés à la place du rendu à taille intrinsèque — non exerçables en test widget
      (`Image.network` a besoin d'une base non disponible en test). À confirmer en zoomant une vraie
      photo (N10, N16 ou N21) sur device.
- [x] **Carte d'entrée + consentement avant l'intro** — confirmé sur simulateur iOS le 19/08
      (voir MEMOIRE.md) : image, dégradé, icône, titre, accroche, case, lien, bouton, tout au
      rendez-vous. Reste un réglage d'équilibre visuel, pas un bug — voir plus bas.

## 🟡 Écran d'accueil — réglage d'équilibre visuel, pas fonctionnel

Vu sur simulateur (2026-08-19) : l'espace entre l'accroche et la case de consentement est assez
généreux (`Spacer()` non contraint dans `EntryCardScreen`). Fonctionnellement correct, juste
peut-être trop lâche à l'usage — à trancher par Vivien, pas resserré d'initiative sans son avis.

## 🟡 Flakiness connue, sans rapport avec le contenu — `test-ai-moment.py` § quota

Le test de quota compare `date.today()` (Python, horloge locale) au jour calculé par `ai-chat`
(`new Date().toISOString()`, horloge Docker en UTC). Juste après minuit heure locale (CEST), les
deux jours divergent brièvement et le test échoue à tort. Se résorbe seul après minuit UTC ; à
regarder seulement si ça devient gênant en CI (comparer sur un jour calculé côté serveur plutôt que
recalculé côté test).

## ❓ À trancher — longueur des répliques de Léna

Le prompt dit « une à deux phrases », et lui demande par ailleurs des phrases
courtes souvent sans verbe. Les deux se contredisent : le modèle produit
régulièrement trois fragments (« T'as raison. Je devrais. Mais je sais même pas
où est Chloé. ») qui sonnent parfaitement juste. Soit on aligne le prompt sur
« deux à trois fragments courts », soit on assume l'écart. En attendant la
sonde tolère trois et coupe à quatre.

## ♿ Accessibilité — les trois réglages qui manquent

Demandés dans l'addendum V3.2 §5, non livrés avec l'écran de Réglages :

- [ ] **Police adaptée à la dyslexie** (OpenDyslexic ou équivalent)
- [ ] **Interlignage augmenté**
- [ ] **Contraste renforcé**

Ils supposent une refonte du thème : `AppText` et `AppColors` sont des
constantes, il faudrait les dériver d'un état. Ce n'est pas difficile, c'est
transversal — chaque écran les lit.

Rien n'est affiché en attendant, volontairement : trois interrupteurs qui ne font
rien se lisent comme une panne. Même règle que le bouton « Continuer
maintenant ». Voir DESIGN.md § L'écran de Réglages.

## 🔍 Relire les tirages de la sonde, pas seulement les compteurs

La voix chaleureuse de la V3.2 pousse Léna à **combler les blancs** : elle a
inventé un chien dont le joueur n'avait pas parlé, et une crise de panique qu'il
aurait empêchée. La seconde est passée — elle interprète une présence réelle,
elle ne contredit rien.

**Ça s'aggravera aux chapitres 3 et 5**, quand Léna aura du passé commun à
évoquer : plus il y a de matière partagée, plus il y a de blancs plausibles à
remplir, et moins l'invention se distingue du souvenir.

Aucun détecteur mécanique n'attrapera ça. À chaque nouveau moment IA :
**relire les tirages de `probe-lena.py`**, pas seulement regarder s'il sort vert.

## 🔴 Bloquant avant mise en production

- [ ] **Deux champs de la politique de confidentialité** : identité du
      responsable de traitement, et adresse de contact. Marqués « À COMPLÉTER »
      dans `app/lib/screens/privacy_text.dart`. Je ne les invente pas — un
      document qui désigne un responsable fictif ne protège personne et
      tromperait le joueur sur qui détient ses données.

- [x] ~~Politique de confidentialité (`PRIVACY_URL`)~~ — levé : le texte est
      désormais **embarqué** dans l'app, section Confidentialité des Réglages.

## 📊 Coût IA — mesurer par PARTIE, pas par échange

Au chapitre 1 il y a **un** moment IA. Aux chapitres 3 et 5 il y en aura **trois par partie**, et
le prompt système grossira à chaque fois : Léna aura de plus en plus de choses à ne pas révéler.

Le coût par échange est trompeur — l'entrée domine largement (prompt système rejoué à chaque tour :
1 813 tokens d'entrée pour 107 de sortie sur deux échanges). **La bonne unité est le coût d'une
partie complète.**

- [ ] Quand les moments des ch. 3 et 5 existeront, ajouter une mesure par partie plutôt que par
      jour. `ai_usage` est indexée par `(user_id, day)` : il faudra soit une agrégation par
      `player_progress`, soit une colonne de cumul sur la progression elle-même.
- [ ] Surveiller la croissance du prompt système : c'est lui qui pilote le coût, et il ne fera que
      grossir. Un prompt à 8 000 caractères multiplierait la facture par trois sans que personne
      ne s'en aperçoive.

## 🔴 Prompt 3 — décisions requises avant la Phase 1

### A1 — Modèle Mistral

**Recommandé : `mistral-small-latest`.** Le moment N9 tient à peu de choses — rester en
personnage, ne rien inventer sur les chapitres 2-5, produire un JSON strict. C'est de la qualité de
suivi d'instruction, pas de la puissance brute. Un modèle plus petit (`ministral-8b`) coûterait
moins mais dériverait davantage sur exactement ce qui compte ici.

Le coût reste marginal : 2 à 4 échanges par joueur, sorties plafonnées à deux phrases.
⚠️ **Le nom exact du modèle est à vérifier au catalogue Mistral du jour** — je ne l'affirme pas de
mémoire. L'appel est isolé derrière une interface : en changer est une ligne.

### A2 — Détection de sortie de cadre : les deux, en couches

| Couche | Où | Rôle |
|---|---|---|
| **Pré-filtre serveur** | avant l'appel | Injection de prompt (« ignore tes instructions », « system prompt », « tu es une IA »), insultes manifestes. Déterministe, gratuit, **impossible à négocier** |
| **Classification par le modèle** | dans sa réponse JSON | Tonalité `sincere` / `evasif` / `hostile` — un jugement, pas une règle |
| **Décision serveur** | après | C'est le serveur qui applique les effets et coupe. Le modèle n'écrit jamais une variable |

Le pré-filtre passe **avant** l'appel : on ne paie pas pour une tentative d'injection, et on ne
laisse pas le modèle décider s'il doit s'ignorer lui-même.

### A3 — `detail_perso` : liste d'autorisation, pas d'exclusion

Le prompt demande une liste d'exclusion. **Une liste d'exclusion sur du texte libre est un filtre
faible** : elle ne rattrape que ce qu'on a prévu, et une donnée de santé formulée autrement passe.

Proposition : le modèle renvoie **une catégorie** (`prenom` · `ville` · `metier` · `animal`) en plus
de la valeur, et le serveur **n'accepte que ces quatre-là**. Tout le reste devient `null`. La liste
d'exclusion reste, en second filet, sur la valeur elle-même.

Un `detail_perso` à `null` est un cas normal — le payoff du ch. 4 doit s'en accommoder.

### A4 — Consentement : en base, pas en local

`player_progress.ai_consent_at timestamptz`. Le consentement RGPD doit être **auditable** et suivre
la cascade de suppression du compte ; un indicateur local ne prouve rien et disparaîtrait sans
trace. Refus → l'histoire continue par le fallback, sans pénalité, et on ne redemande pas.

### 🔴 A5 — Manque : rien ne compte les échanges d'un moment IA

`ai_usage` compte les échanges **par jour**, pour le quota. Rien ne mémorise « où en est-on dans CE
moment IA ». Conséquence : un joueur qui ferme l'app au 3ᵉ échange et revient repartirait de zéro.

→ Colonne `player_progress.ai_exchanges`, remise à zéro à l'entrée dans un `ai_moment`.
**Le décompte doit être serveur**, jamais tenu par le modèle ni par le client.

### A6 — Journal des coûts

`console.log` des tokens suffit pour commencer, mais ne permet aucune estimation agrégée.
Proposition : deux colonnes sur `ai_usage` (`tokens_in`, `tokens_out`), cumulées par jour. Coût
nul, et on saura ce que coûte réellement un joueur.

## 🔴 Décisions UI — prompt 2, Phase 0

### ✅ Tranchées par l'addendum — le champ de saisie, pièce centrale

`docs/prompts/addenum-au -prompt-2.md`. **D1 (geste de continuation) et D2 (silence du N19) sont
remplacées** : les deux reposent sur le même composant, un champ de saisie **toujours actif**.

**Un composant, trois modes visuellement identiques** — si l'apparence changeait selon le mode, le
joueur saurait instantanément quels moments « comptent », et perdrait le doute qui fait tout
l'intérêt du champ décoratif.

| Mode | Quand | Effet d'un envoi |
|---|---|---|
| `decorative` | Le nœud propose des `reply`/`ignore` | Le texte s'affiche à droite, **non délivré**. Rien n'est envoyé au serveur |
| `continuation` | `awaiting_interaction` ou `can_continue` sans réponse à donner | Le texte s'affiche à droite, puis déclenche `advance {continue:true}` |
| `ai_input` | `ai_moment_pending` (**prompt 3**) | Saisie réelle, envoyée à `ai-chat` |

Le mode se déduit entièrement du contrat : aucune connaissance du graphe côté client.

**Règles non négociables du mode décoratif** : les messages sont persistés **localement** (les
relire une fois la tension retombée fait partie du plaisir), affichés en **non délivré**, et
**aucun feedback ne trahit jamais leur inutilité** — pas d'erreur, pas de grisage, pas de
« Léna ne peut pas répondre ».

**Fallback de continuation** : pour le joueur qui n'écrit rien et ne touche à rien, une affordance
très discrète après **25 s** d'inactivité. À spécifier dans DESIGN.md en Phase 1.

**Conséquence technique à ne pas rater** : un message décoratif n'existe pas côté serveur, donc
`get-state` ne le renverra jamais. Pour qu'il reste à sa place dans le fil après redémarrage, il
doit être **ancré au dernier `seq` serveur connu au moment de l'écriture**, et ré-intercalé au
rechargement. Même stockage local que le curseur d'affichage (D4).

### ✅ D5 — Le typing fantôme du N19 *(tranchée)*

Deux colonnes `messages.phantom_typing_at` / `haptic_at`, seedées sur **N20#0** à **45** et **60**.
Offsets en secondes depuis le début du délai du message porteur ; le faux typing dure 2 s puis
s'éteint sans message. Sémantique dans LOGIQUE.md § Mise en scène d'une attente.

### ✅ D6 — Le temps de fiction *(tranchée)*

Aucun horodatage ne vient de l'horloge système, **sauf** le compte à rebours de fin de chapitre.
L'horloge de fiction se dérive du fil : chaque séparateur réancre, chaque message avance de son
`delay_seconds`. Zéro coût de contenu, déterministe. LOGIQUE.md § Le temps de fiction.

### Historique — D5 tel que posé

Vers 45-50 s du grand silence : le typing apparaît 2 s puis disparaît, **sans qu'aucun message
n'arrive**. L'addendum le désigne comme l'élément le plus important de la séquence. Le serveur n'a
aucune notion de « faux typing ».

| Option | Verdict |
|---|---|
| Heuristique client : tout `delay_seconds >= 60` déclenche un typing fantôme | ❌ S'appliquerait aussi au N11, N16, N17, N21. Un effet dramatique qui se produit cinq fois n'est plus un effet |
| Message `system` invisible portant l'instruction | ⚠️ Surcharge un type qui signifie déjà « présence », et `body` est ailleurs du texte affiché |
| **Deux colonnes de mise en scène sur `messages`** | ✅ **Recommandé** |

**Proposition** : `messages.phantom_typing_at int` et `messages.haptic_at int` — des secondes
**dans l'attente** portée par `delay_seconds`. Seedées uniquement là où le chapitre les demande :
sur **N20#0** (le séparateur « 00h34 », qui porte les 90 s), `phantom_typing_at = 47`,
`haptic_at = 60`.

*Pourquoi* : explicite, greppable, vérifiable par script, et ça se généralise aux vraies attentes
des chapitres 2-5 sans rien réinventer. Le coût est une petite migration + deux valeurs au seed.

### 🔴 D6 — « vu 00h29 » : le client ne connaît pas l'heure de fiction *(découvert en intégrant l'addendum)*

L'addendum veut un statut qui passe de « en ligne » à **« vu 00h29 »** puis « hors ligne ». Or
`00h29` est une heure **de fiction** : le joueur joue à n'importe quelle heure réelle, et le client
n'a aucun moyen de la déduire — les séparateurs donnent bien « 23h31 » et « 00h34 », mais
l'intervalle entre les deux est une ellipse, pas du temps réel.

**Proposition, sans schéma ni code : le message `system` porte déjà le libellé de présence.**
Il suffit de seeder la séquence dans le contenu, là où elle appartient — remplacer l'unique
`system` de N19#6 (« Léna est hors ligne ») par deux :

1. `« Vu à 00h29 »` — à l'entrée du silence
2. `« Léna est hors ligne »` — quelques secondes plus tard

Le client se contente d'afficher le `body` du dernier `system` reçu comme sous-titre de l'en-tête.
Aucune heure inventée côté client, aucune colonne de plus. **C'est une modification de contenu :
elle a besoin de ton feu vert, et `chapitre-1-v2.md` devra être patché en même temps** (règle Q8).

### En attente de ta réponse (inchangées)

- **D3 — typing intermittent** : seuil `typing_seconds >= 15`, qui isole exactement N2#0 (40/40) et
  N13#0 (50/50). Rafales ≈ 5 s visible / 3 s masqué.
- **D4 — curseur d'affichage local** : le client retient le `seq` du dernier message affiché ;
  au rechargement, tout ce qui précède est instantané, le reste se déroule. État de *présentation*,
  pas de jeu — la vérité reste `get-state`.

---

## 🔴 Questions ouvertes — contenu

- [ ] **Q9 — Jour J : le 13 ou le 14 août 2026 ?** Tu as indiqué « Jeudi 14 août 2026 », mais le
      14 août 2026 est un **vendredi**. Le chapitre affiche « jeudi — 22h47 » et le suspect vient
      « tous les jeudis » : la date aurait posé une contradiction sur le premier écran du jeu.
      **J'ai retenu jeudi 13 août 2026** — une seule valeur à changer (`stories.intro_panels`)
      si tu préfères garder le 14 et ajuster le jour partout ailleurs.
- [ ] **Q10 — La dispute du « 12 mars ».** La bible la situe « la veille » de la disparition, elle-même
      à J-7 mois, soit **mi-janvier**. Mars ≠ janvier. L'écart préexistait ; l'ancrage de date le rend
      simplement visible. Est-ce une **quatrième incohérence plantée** (le 12 mars serait ce que Léna
      *dit*, pas ce qui s'est passé — ce qui serait très cohérent avec sa culpabilité), ou un simple
      écart à corriger ? Ça change ce qu'on écrira au ch. 3.

## Questions ouvertes (prompt 1)

*Aucune.* Q1→Q8 tranchées. Les décisions et leur raison sont dans MEMOIRE.md et ARCHITECTURE.md.

## Phases — prompt 2 (app Flutter)

- [x] **Phase 0 — Audit** : environnement, payloads réels confrontés au contrat, mapping
      serveur → widget, 6 angles morts, décisions UI. ✅ validée.
- [x] **Phase 1 — Squelette, modèles, client API** : projet Flutter, modèles depuis le contrat,
      `EngineApi` (8 codes d'erreur, rejeu asymétrique, anti-double-tap), session anonyme vérifiée,
      thème complet, **DESIGN.md rédigé**, 16 tests, app validée sur simulateur iOS.
      ⏸ En attente de validation.
- [x] **Phase 2 — Écran de conversation** : fil complet, moteur de déroulé (délais, typing
      intermittent, battements de mise en scène, skip debug, reprise), horloge de fiction,
      mémoire locale, champ de saisie à 3 modes. **39 tests verts.**
      ⏸ En attente de validation.
- [x] **Phase 3 — Interactions cachées, liste, fin de chapitre** : règle de déclenchement dérivée
      du contrat (média → geste, sinon « + » discret), liste multi-conversations avec bascule
      d'identité et heure de fiction, écran de fin plein écran avec compte à rebours réel,
      séquence d'intronisation. **45 tests verts.**
      ⏸ En attente de validation · recette manuelle partielle, voir ci-dessous.

### Recette manuelle — ce qui a été vu, ce qui reste à voir

Vérifié sur simulateur iOS : intro complète (4 panneaux, fondus), 4 s de vide, déroulé du N1 avec
typing, photo réelle du N16 dans le fil, bascule « Numéro inconnu » → « Léna », écran de fin avec
compte à rebours, liste avec aperçu et heure de fiction.

⚠️ **Non vérifié à la main** : les six interactions déclenchées par un vrai geste, la reprise en
tuant l'app pendant les 90 s du N19, et **le son à l'oreille** — le lecteur est réel et les fichiers
sont servis correctement (MIME `audio/mpeg`, requêtes Range en 206, MP3 valides), mais je ne peux
pas entendre le simulateur. Automatiser un tap sur le simulateur demande l'autorisation
d'accès d'aide de macOS, refusée sur cette machine. Le comportement est couvert par les tests
widget, mais il n'a pas été joué au doigt. **À faire par Vivien** : `app/tool/run_local.sh`.

## Phases — prompt 1 (moteur) · terminé

- [x] **Phase 0 — Audit** : environnement, lecture des 3 sources, audit croisé chapitre ↔ schéma,
      système documentaire. ✅ validée.
- [x] **Phase 1 — Migration** : `supabase init`, `20260814190318_initial_schema.sql`
      (9 tables, 28 index, 21 CHECK, 16 FK, 7 UNIQUE, RLS + 4 policies, 1 trigger),
      `supabase db reset` vert, RLS et contraintes vérifiées fonctionnellement.
      ⏸ En attente de validation.
- [x] **Phase 2 — Seed chapitre 1** : `supabase/seed.sql` (21 nœuds, 67 messages, 33 choix,
      stub du chapitre 2) + `scripts/verify-graph.sql` (40 contrôles, tous OK). ✅ validée
      (commit `0580fad`), complétée par le correctif Q6 (révélation d'identité).
- [x] **Phase 3 — Edge Functions** `get-state` et `advance` + `scripts/simulate-playthrough.py`
      (parcours « allié », « refus » avec test du plafond, branche N6, erreurs, idempotence,
      anti-spoiler). 51 contrôles, tous OK. ✅ **Prompt 1 terminé.**

## Tests de l'app — `cd app && flutter test`

16 tests. Ils tiennent lieu de **contrat exécutable** : les payloads viennent d'une capture réelle
du moteur, donc un changement de forme côté serveur les fait tomber. Couvrent la désérialisation,
la séparation réponses / interactions (protection de mécanique du N17), les 8 codes d'erreur, la
politique de rejeu asymétrique (`choice_id` retenté, `continue` jamais), l'anti-double-tap et le
seuil de typing intermittent.

## Vérification du graphe — `scripts/verify-graph.sql`

```
docker exec -i supabase_db_SMS-Noir psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < scripts/verify-graph.sql
```

40 contrôles, sortie en erreur si un seul échoue : structure (nœuds, entrée, `chapter_end`,
`ai_moment` + fallback, stub ch. 2), intégrité du graphe (orphelins, convergence vers N22,
impasses, transitions auto), les **6 interactions cachées**, cohérence moteur (usage unique,
`refus` porté par le seul N11, aucun `effect` ne code le plafond de `confiance`, 4 branches,
5 indices), contenu (délai ≤ 90 s, positions contiguës, médias, décomptes) et révélation
d'identité (`display_name_initial`, `reveal_contact` sur N5/N7 ciblant un contact existant).

⚠️ **Tester le seed avec `supabase db reset`, jamais seulement avec `psql`.** La CLI envoie le
fichier en **batch** (toutes les requêtes analysées avant exécution) : une `create function`
utilisée dans le même fichier passe en `psql` et échoue sous la CLI. C'est pour ça que le seed
n'utilise aucune fonction et résout les nœuds par jointure sur `code`.

## Simulation de partie — `scripts/simulate-playthrough.py`

```
supabase start && supabase functions serve &     # laisser tourner
python3 scripts/simulate-playthrough.py
```

Joue deux parties entières de N1 à N22 via les Edge Functions, puis relit les variables en
`service_role` (le client ne les voit jamais). Sort en code 1 au premier écart.

- **« allié »** — confiance 7, 4 indices, branche `allié`, Léna révélée au N5, compte à rebours posé.
- **« refus »** — `refus` posé par le nœud N11, **confiance écrêtée à 6** alors que les gains
  valent 7 : c'est le test qui protège la règle du plafond.
- **branche N6** — Léna rembarrée puis insistante : vérifie qu'elle se nomme là aussi (V2.1).
- **Robustesse** — choix hors nœud, choix inexistant, requête vide, appel non authentifié,
  `continue` mal placé, rejeu du même `choice_id`, et inspection des réponses brutes pour
  confirmer qu'aucun `next_node_id` / `effects` / `conditions` / variable ne fuit.

## Fidélité du texte — `scripts/verify-fidelity.py`

```
python3 scripts/verify-fidelity.py
```

Compare **dans les deux sens** les répliques de Léna du chapitre et les textes en base : une
réplique du doc absente de la base, ou un texte en base absent du doc, fait échouer le script.
C'est le garde-fou de la règle 6 (recopie fidèle, jamais de reformulation) et le détecteur de
divergence entre la base et sa source de vérité. **58 = 58 actuellement.**

À relancer après toute modification de `docs/chapitre-1-v2.md` ou du seed.

## ✍️ Contenu manquant (Vivien) — pour le prompt 4

- [ ] **`push_text` absent sur 5 des 6 messages à notification.** Seul le N11 en a un
      (« Léna : 1 nouveau message »). Les N4, N6, N14, N19 et N20 ont `push_notification = true`
      mais `push_text = null`. Sans texte, les notifications locales du prompt 4 devront se replier
      sur un libellé générique — ce qui gâche l'effet, surtout au N19 (« il sort »).

## 🔊 Sons de message — en place, personnalisables

**Rien à produire.** L'app sonne déjà : sons système neutres sur iOS, assets synthétisés sobres sur
Android. Voir DESIGN.md § Sons de message.

Pour donner à une histoire son identité sonore, déposer des fichiers dans `media/` — ils prennent
le dessus. Le script les repère par mot-clé : `reception`, `envoi`, `frappe`.

- [ ] Écouter les trois sons et dire s'ils conviennent. Les identifiants iOS sont trois constantes
      dans `services/system_sounds.dart`, triviales à changer ; les assets Android sont dans
      `app/assets/sounds/`.


## 🎬 Médias à produire (Vivien) — 4 fichiers

**Toute la chaîne technique est prête et testée.** Il ne manque que les fichiers :

1. Déposer les quatre fichiers dans `media/` — noms exacts, specs et pièges de production
   dans **`media/README.md`**.
2. `scripts/upload-media.sh` — téléverse dans le bucket, remplace les `placeholder://`, affiche
   l'état. Rejouable, et accepte les fichiers **un par un**.

- [x] `photo-N10-recepisse` — livré. Capture d'un mail de la police, 720×1466.
      Lisible **sans zoomer**. Date « 12 juin 2026 » = l'incohérence des 2 mois. ✅
- [x] `photo-N16-plaque` — livré, 2816×1536. Macaron « SENTINEL PRO » lisible à 5× sur téléphone. ✅
      ⚠️ voir « Plaque du N16 » ci-dessous.
- [x] `photo-N21-porte-cles` — livré, 2816×1536, remplacé le 2026-08-19 (composition revue :
      trousseau sur crochet, ampoule au-dessus, à gauche du cadre). Silhouettes gravées nettes
      au zoom ; téléphone à coque rose visible mais discret sur l'établi, à confirmer sur
      device. ✅
- [x] `audio-N17-reperage` — livré, MP3 22,1 s. ⚠️ fond radio à vérifier à l'oreille (non contrôlable ici).

### ⚠️ Plaque du N16 — décision de contenu

La photo ne montre **aucune plaque** : le véhicule est cadré de trois-quarts arrière et
l'emplacement de la plaque porte une **retouche visible** (masquage sombre). Deux conséquences :

- `chapitre-1-v2.md` décrit « plaque partielle « …-843-… » » — la photo ne correspond pas.
- La retouche se lit comme une censure, ce qui est une rupture du 4e mur dans une photo
  censée être prise par Léna.

La réplique « C'est tout ce que j'arrive à choper sans m'approcher » couvre en partie l'absence.
Trois options : reprendre la photo avec une plaque factice lisible, salir la zone de façon
diégétique (boue, reflet, angle) plutôt que par un aplat, ou aligner le texte du chapitre sur
la photo. **Non bloquant** : l'indice `PLAQUE` vient du choix au N14, pas d'un zoom.

### ⚠️ La date du N10 vieillira

« 12 juin 2026 » ne se lit comme « il y a 2 mois » que si le joueur joue vers août 2026. Rien
dans le jeu ne donne la date du jour — les séparateurs ne portent que des heures. Dans un an, la
même capture dira « il y a 14 mois » et l'incohérence changera de sens. À garder en tête pour les
chapitres suivants : soit une date relative, soit un rafraîchissement périodique de la capture.

⚠️ **Lisibilité au zoom** : ≥ 2400 px sur le côté long pour N16 et N21, et surtout le détail doit
occuper **≥ 15 % de la largeur** du cadre. La visionneuse plafonne à 5× — elle grossit, elle
n'invente pas. À vérifier **sur un téléphone**, pas sur un écran d'ordinateur.


## Confort / plus tard

- [ ] **`supabase db reset` finit sur une erreur 502** : imgproxy et pooler ne démarrent pas.
      Sans impact aujourd'hui (base, API, auth, Edge Functions tournent, la migration s'applique).
      À traiter quand le Storage d'images servira (production des médias).
- [x] ~~Mettre à jour la CLI Supabase~~ — fait (2.75.0 → **2.114.0**), sous la contrainte : la 2.75
      ne savait plus valider les jetons ES256 émis par sa propre auth.
- [ ] Lier le projet au Supabase distant : `supabase link --project-ref eszsdfbalmpnpefnvnsh`.
      Tout est local pour l'instant ; le distant est vide. À faire avant de pousser la migration
      (`supabase db push`), pas avant.
- [ ] **MCP Supabase configuré** (`.mcp.json`, scope projet, même `project_ref`) mais **pas encore
      authentifié** : lancer `claude /mcp` dans un terminal classique (pas l'extension IDE) →
      `supabase` → `Authenticate`. Utile surtout à partir du moment où le distant sert vraiment
      (push de migration, logs, advisors de sécurité, Edge Functions déployées).
- [ ] **Typing intermittent** : le N2 (« en train d'écrire » qui apparaît/disparaît deux fois) et le
      N13 (hésitation par à-coups) ne sont pas exprimables — `messages` n'a qu'un `typing_seconds`.
      Convention UI à trancher au prompt 2 (jitter côté client sur les longues durées) plutôt qu'une
      colonne de plus. Non bloquant.
- [ ] **N19 « Léna est hors ligne »** : modélisable en `content_type='system'`. À confirmer au seed.
- [ ] Durée du silence du N19 (60 s puis 90 s) : « paramétrable en base pour tes tests » — c'est
      `delay_seconds`, à ajuster au ressenti après le prompt 2.

## Mapping serveur → widget (établi en Phase 0 du prompt 2)

| Ce que renvoie le serveur | Widget | Note |
|---|---|---|
| `content_type: 'text'`, `sender: 'contact'` | Bulle gauche | |
| `content_type: 'text'`, `sender: 'player'` | Bulle droite, couleur d'accent | |
| `content_type: 'separator'` | Pastille centrée, `body` tel quel (« 23h31 ») | Jamais reformaté côté client |
| `content_type: 'image'` | Miniature dans le fil → visionneuse plein écran zoomable | Le zoom est une **mécanique de jeu** |
| `content_type: 'audio'` | Lecteur inline réécoutable | La réécoute est une **interaction cachée** |
| `content_type: 'system'` **+ nœud `chapter_end`** | **Écran de fin plein écran** | Sort du fil |
| `content_type: 'system'` (autre) | **Sous-titre de présence** de l'en-tête — le `body` EST le libellé affiché | Jamais une bulle |
| `media_url` en `placeholder://…` | Cartouche de remplacement lisible | Les médias réels n'existent pas encore |
| `choices[].kind: 'reply'` | Bouton de réponse | |
| `choices[].kind: 'ignore'` | Bouton effacé, visuellement distinct | Vrai choix, jamais un timeout |
| `choices[].kind: 'interaction'` | **Jamais un bouton** — un geste (tap média, réécoute, « + » discret) | Le `label` peut être un spoiler (N17) |
| `awaiting_interaction: true` | Aucune zone de choix — champ de saisie en mode `continuation` | Écrire fait avancer |
| `can_continue: true` | Autorise `advance {continue:true}` | |
| `ai_moment_pending: true` | Champ en mode `ai_input` — **apparence strictement identique** aux deux autres modes | Traversé par `continue` en attendant le prompt 3 |
| `chapter_end` non nul | Écran 3 + compte à rebours décoratif | Seul le serveur débloque |

**Cas non couverts par le contrat**, à traiter côté client : le retour « en ligne » (jamais
annoncé, déduit de l'arrivée d'un message) · les **messages décoratifs**, qui n'existent que
localement et doivent être ancrés à un `seq` serveur pour rester à leur place · le repli de `push_text` quand il est `null`
(5 messages sur 6 — prompt 4) · le fait que `seq` soit un ordinal **global** et non un index.

## Prochaine session — prompt 2 (app Flutter)

Points d'entrée pour la reprise :

1. `docs/MEMOIRE.md` — où en est le projet et pourquoi.
2. `docs/LOGIQUE.md § Contrat des Edge Functions` — payloads exacts de `get-state` et `advance`.
3. `docs/LOGIQUE.md § Contraintes client` et `§ Règle d'arrêt sur interaction` — ce que l'app a
   le droit de faire, et ce qu'elle doit offrir sur un nœud en pause.
4. `docs/DESIGN.md` — principes UI déjà arrêtés.

Décisions UI en suspens pour le prompt 2 : le typing intermittent (N2, N13), l'affichage du
message `system` de fin de chapitre (N22#4) en plein écran plutôt que dans le fil, et le geste de
continuation quand `node.can_continue` est vrai sans signaler l'interaction disponible.

## Hors périmètre du prompt 1

App Flutter (prompt 2) · `ai-chat`, quota, `detail_perso` (prompt 3) · notifications locales + FCM,
cron `pg_cron` de déblocage, `unlock-chapter`, premium (prompt 4).
