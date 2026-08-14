# MEMOIRE.md — journal de bord

*Fichier à lire en premier par toute nouvelle session Claude Code. Ordre antéchronologique : l'entrée la plus récente est en haut.*

---

## 2026-08-14 (3/3) — Phase 1 (migration) : **TERMINÉE, en attente de validation**

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

## 2026-08-14 (2/3) — Phase 0 (audit) : **TERMINÉE, validée**

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

## 2026-08-14 (1/3) — Phase 0 : blocage initial, fichiers sources manquants

Le repo ne contenait que `README.md` (1 commit, `05f2fad`), la bible et le prompt. Les fichiers
`chapitre-1-v2.md` et `schema-supabase-v2.md` étaient absents.

**Décision prise : ne rien inventer** — reconstituer un chapitre ou un schéma « plausible » aurait
violé la règle 3 (recopie fidèle) et produit un travail à jeter. Audit d'environnement fait,
système documentaire créé, bible lue, puis STOP.

Rangement effectué : `bible-narrative.md` déplacé de la racine vers `docs/`,
`prompt-1-claude-code.md` vers `docs/prompts/`. Aucune modification de contenu.
