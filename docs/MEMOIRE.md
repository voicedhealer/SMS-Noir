# MEMOIRE.md — journal de bord

*Fichier à lire en premier par toute nouvelle session Claude Code. Ordre antéchronologique : l'entrée la plus récente est en haut.*

---

## 2026-08-14 (7) — PROMPT 2, Phase 1 (squelette, modèles, client API) : **TERMINÉE, en attente de validation**

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
