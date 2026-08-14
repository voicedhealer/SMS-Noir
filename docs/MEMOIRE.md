# MEMOIRE.md — journal de bord

*Fichier à lire en premier par toute nouvelle session Claude Code. Ordre antéchronologique : l'entrée la plus récente est en haut.*

---

## 2026-08-14 (4/4) — Phase 2 (seed du chapitre 1) : **TERMINÉE, en attente de validation**

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

## 2026-08-14 (3/4) — Phase 1 (migration) : **TERMINÉE, validée** (commit `051384c`)

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

## 2026-08-14 (2/4) — Phase 0 (audit) : **TERMINÉE, validée**

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

## 2026-08-14 (1/4) — Phase 0 : blocage initial, fichiers sources manquants

Le repo ne contenait que `README.md` (1 commit, `05f2fad`), la bible et le prompt. Les fichiers
`chapitre-1-v2.md` et `schema-supabase-v2.md` étaient absents.

**Décision prise : ne rien inventer** — reconstituer un chapitre ou un schéma « plausible » aurait
violé la règle 3 (recopie fidèle) et produit un travail à jeter. Audit d'environnement fait,
système documentaire créé, bible lue, puis STOP.

Rangement effectué : `bible-narrative.md` déplacé de la racine vers `docs/`,
`prompt-1-claude-code.md` vers `docs/prompts/`. Aucune modification de contenu.
