# ARCHITECTURE.md — état technique réel

> **Statut au 2026-08-14 : Phase 1 terminée.** Le schéma décrit ici **existe** en base locale.
> Migration : `supabase/migrations/20260814190318_initial_schema.sql`.

## Environnement

| Élément | État | Remarque |
|---|---|---|
| Repo git | ✅ propre, branche `main` | |
| CLI Supabase | ✅ **v2.75.0** | v2.114.0 disponible — voir TODO |
| Projet Supabase local | ✅ **initialisé** (`supabase/config.toml`) | `supabase start` OK |
| Projet Supabase distant | ❌ **non lié** | Aucun `project_ref` — tout se fait en local pour l'instant |
| Docker | ✅ daemon démarré (28.5.1) | |
| Deno (standalone) | ❌ absent | Non bloquant : la CLI exécute les Edge Functions dans Docker |
| Flutter | ✅ présent | Hors périmètre du prompt 1 |

⚠️ `supabase db reset` termine sur une erreur `502` au redémarrage des conteneurs : **imgproxy** et
**pooler** ne démarrent pas. Sans effet sur le travail en cours (la base, l'API REST, l'auth et les
Edge Functions tournent) — la migration s'applique bien. À regarder si le Storage d'images devient
nécessaire (production des médias).

**Accès local** — Base : `postgresql://postgres:postgres@127.0.0.1:54322/postgres` ·
API : `http://127.0.0.1:54321` · Studio : `http://127.0.0.1:54323`.
`psql` n'est pas installé sur la machine : passer par
`docker exec -i supabase_db_SMS-Noir psql -U postgres -d postgres`.

## Vue d'ensemble cible

```
┌─────────────────┐        ┌──────────────────────────────────────┐
│  App Flutter    │        │              Supabase                │
│  (prompt 2)     │        │                                      │
│                 │        │  Edge Functions                      │
│  - liste convs  │ ──────▶│   • get-state       (prompt 1)       │
│  - fil de msgs  │  HTTPS │   • advance         (prompt 1)       │
│  - timers +     │ ◀──────│   • ai-chat         (prompt 3)       │
│    notifs       │        │   • unlock-chapter  (prompt 4)       │
│    locales      │        │              │                       │
└─────────────────┘        │              ▼                       │
                           │  Postgres + RLS                      │
                           │   Contenu : stories, contacts,       │
                           │     chapters, nodes, messages,       │
                           │     choices                          │
                           │   Joueur  : player_progress,         │
                           │     player_messages, ai_usage        │
                           └──────────────────────────────────────┘
```

**Principe structurant : le client ne lit jamais le contenu narratif directement.**
Toute lecture passe par une Edge Function qui filtre. Voir § Sécurité.

## Modèle de données

Référence : `docs/schema-supabase-v2.md`, repris **tel quel** aux écarts près (§ Écarts).
**État réel en base : 9 tables · 28 index · 21 contraintes CHECK · 16 clés étrangères ·
7 contraintes UNIQUE · RLS active sur les 9 tables · 4 policies.**

**Contenu** — `stories` › `chapters` › `nodes` › (`messages`, `choices`) · `contacts` rattachés à `stories`
**Joueur** — `player_progress` › `player_messages` · `ai_usage` (par `user_id` + jour)

Il n'y a **pas** de table `players` : le schéma référence directement `auth.users`
(le `players` du diagramme d'ensemble est une commodité de lecture).

Types de nœuds (`nodes.kind`) : `scripted` · `ai_moment` (N9) · `chapter_end` (N22).
Types de messages (`messages.content_type`) : `text` · `image` · `audio` · `system` · `separator`.
Types de choix (`choices.kind`) : `reply` · `ignore` · `interaction`.

Variables de partie, portées par `player_progress.variables` (JSONB) :

| Variable | Type | Plage / valeurs | Départ |
|---|---|---|---|
| `confiance` | int | 0-10, **plafond 6 si `refus=true`** | 3 |
| `lucidite` | int | 0-5 au ch. 1, extensible | 0 |
| `indices` | liste | `PROFIL_SUSPECT`, `BORNAGE`, `PLAQUE`, `AUTOCOLLANT`, `TELEPHONE` | `[]` |
| `refus` | bool | posé par le N11 | `false` |
| `branche_ch1` | code | `empathie` · `curieux` · `allié` · `prudent` | `null` |
| `detail_perso` | texte | ⚠️ **RGPD** — colonne dédiée, pas dans `variables`. Rempli au N9 (prompt 3) | — |
| `loyaute` | enum | `lena` / `karim` / `neutre` — **ch. 3+, hors périmètre** | — |

`interactions_faites` (liste) sera ajoutée à `variables` à l'exécution pour rendre les interactions
cachées non répétables — voir LOGIQUE.md § Interactions à usage unique.

### Écarts au schéma de référence

| # | Écart | Pourquoi | Statut |
|---|---|---|---|
| A | **`nodes.next_node_id`** (nullable) | 8 nœuds du ch. 1 enchaînent sans aucun choix (N5, N7, N12, N18, N19 → et N13, N16, N21 après leur interaction). Le schéma ne sait exprimer une transition que via `choices.next_node_id` : il manque la transition automatique | ✅ validé, en base |
| B | **`player_messages.seq`** (`bigserial`, indexé) | `created_at default now()` renvoie l'heure de **début de transaction** : tous les messages d'un même `advance` portent un timestamp identique. **Vérifié en base : 4 messages écrits par une même transaction → 1 seul `created_at` distinct, 4 `seq` distincts.** `created_at` est conservé, informatif seulement | ✅ validé, en base |
| C | **`player_messages.contact_id` `not null`** = *fil de conversation*, et non locuteur | Le schéma de référence prévoyait `null` pour les messages du joueur. Mais alors, dès qu'il y a plusieurs contacts (twist ch. 4), les réponses du joueur ne sont rattachables à aucun fil : elles tombent toutes dans un même seau `null`. `sender` porte déjà l'information « qui parle » — `contact_id` porte donc « dans quelle conversation » | ⚠️ **à valider** |

### Contraintes structurelles ajoutées (au-delà du schéma de référence)

Garde-fous statiques, tous vérifiés comme rejetant effectivement les données invalides :

| Contrainte | Empêche |
|---|---|
| `ai_moment_has_no_next` | Un `ai_moment` avec un `next_node_id` — il sort par `ai_fallback_node_id` |
| `chapter_end_is_terminal` | Un `chapter_end` avec une suite |
| `reply_needs_target` | Un `reply`/`ignore` sans `next_node_id` (seule une `interaction` peut rester sur place) |
| `media_needs_url` | Une `image`/`audio` sans `media_url` |
| `text_needs_body` | Un `text`/`system`/`separator` sans `body` |
| bornes `>= 0` | `delay_seconds`, `typing_seconds`, `position`, `exchanges` négatifs |

Volontairement **non** contraintes en base, car vérifiées par le script de Phase 2 : le délai
maximum de 90 s (règle du ch. 1 seulement — les ch. 2+ ont de vraies attentes) et la présence d'un
`ai_fallback_node_id` sur les `ai_moment` (le N9 référence le N21, qui doit exister avant lui :
une contrainte CHECK, non différable, empêcherait le seed).

## Contenu seedé (Phase 2)

`supabase/seed.sql`, exécuté automatiquement par `supabase db reset` (`config.toml` → `db.seed`).

| | |
|---|---|
| Histoire | « Numéro Inconnu », slug `numero-inconnu`, `status = 'draft'` |
| Contacts | 1 — Léna (`lena`), arrivée anonyme : `display_name_initial = 'Numéro inconnu'` |
| Chapitres | 2 — « Le mauvais numéro » (ch. 1, complet) et « Chloé » (**stub**, `unlock_delay_minutes = 480`, sans nœud) |
| Nœuds | **21** — N1..N22 sans N15 · 19 `scripted`, 1 `ai_moment` (N9), 1 `chapter_end` (N22) |
| `nodes.effects` | 3 nœuds — N11 (`refus`), N5 et N7 (`reveal_contact`) |
| Messages | **67** — 54 `text`, 6 `separator`, 4 médias (3 `image`, 1 `audio`), 3 `system` |
| Choix | **33** — 23 `reply`, 3 `ignore`, 7 `interaction` (pour 6 interactions cachées) |
| Médias | 4 `placeholder://…` — à produire, brief détaillé dans TODO.md |

**Format SQL et non TypeScript** : Deno n'est pas installé, `db reset` exécute `seed.sql` sans
outillage supplémentaire (une seule commande reproduit tout l'état), et un contenu statique gagne à
être versionnable et diffable à côté de la migration.

⚠️ **Le seed ne définit aucune fonction SQL, volontairement.** La CLI Supabase envoie le fichier en
**batch** : toutes les requêtes sont analysées avant que la première ne s'exécute, donc une fonction
créée dans le fichier n'existe pas encore au moment de l'analyse des suivantes. Le même fichier
passe en `psql` (exécution séquentielle) et échoue sous `supabase db reset`. Les nœuds sont donc
résolus par jointure sur `code`. **Corollaire : toujours tester un seed avec `db reset`.**

## Sécurité — RLS

Règle générale : **RLS activé sur toutes les tables dès leur création**, sans exception.

| Portée | Politique |
|---|---|
| `stories` | Lecture `authenticated` **uniquement** si `status = 'published'` (la vitrine). Seule table de contenu lisible par le client |
| `contacts`, `chapters`, `nodes`, `messages`, `choices` | RLS activé, **aucune policy `select`** → aucune lecture client. Accès `service_role` seulement, via Edge Functions (anti-spoiler) |
| `player_progress`, `player_messages` | `select` sur ses propres lignes (`auth.uid()`). **Aucune policy insert/update** : le moteur serveur écrit tout |
| `ai_usage` | RLS activé, aucune policy client (compteur serveur) |

Filtrage anti-spoiler dans `get-state` — ne sortent **jamais** vers le client :
`next_node_id`, `effects`, `conditions`, et les choix dont les `conditions` sont fausses.

### Vérification fonctionnelle de la RLS (Phase 1)

Testée en base sous le rôle `authenticated`, avec du contenu réellement inséré :

| Test | Résultat |
|---|---|
| Lire `contacts` / `chapters` / `nodes` / `messages` / `choices` | **0 ligne** sur chaque table (contenu invisible) |
| Lire `stories` (1 publiée + 1 brouillon en base) | **1 ligne** — seule la publiée |
| Lire sa propre progression et ses propres messages | ✅ visibles |
| Insérer une progression | ❌ `new row violates row-level security policy` |
| Insérer des messages joueur | ❌ `new row violates row-level security policy` |
| Insérer du contenu narratif | ❌ `new row violates row-level security policy` |
| **Tricher** : `update player_progress set variables = '{"confiance":10}'` | ❌ `UPDATE 0` — aucune ligne modifiable |

À noter : la triche par `UPDATE` échoue **silencieusement** (0 ligne touchée) au lieu de lever une
erreur, faute de policy `update`. Le résultat est le bon ; ne pas s'attendre à une exception.

⚠️ **Conséquence de test** : l'histoire sera seedée en `status = 'draft'` (imposé par le prompt 1),
donc la vitrine renverra une liste vide tant qu'on ne publie pas. Normal, ne pas « déboguer » ça.

Secrets : variables d'environnement uniquement, jamais en dur. `SUPABASE_SERVICE_ROLE_KEY` ne
quitte jamais le serveur.

## Edge Functions du prompt 1

| Function | Rôle |
|---|---|
| `get-state` | Conversations du joueur + historique `player_messages` + nœud courant filtré. Crée la progression à la première visite |
| `advance` | Reçoit un `choice_id`, valide, applique les `effects`, écrit les `player_messages`, avance `current_node_id`, renvoie les nouveaux messages **avec leurs délais** (les timers sont joués par le client) |

La **liste des conversations** est dérivée : `distinct contact_id` dans les `player_messages` du
joueur. Au ch. 1 il n'y en a qu'une (Léna), mais le contrat est multi-conversations dès maintenant
(twist ch. 4 : un second contact écrit au joueur — impossible à greffer proprement après).

Contrats détaillés (payloads entrée/sortie) : voir `LOGIQUE.md`.

## Décisions prises, et pourquoi

| # | Décision | Pourquoi |
|---|---|---|
| 1 | `bible-narrative.md` déplacé de la racine vers `docs/`, prompt vers `docs/prompts/` | Aligne le repo sur l'arborescence imposée par le prompt 1. Contenu inchangé |
| 2 | Les **délais sont joués par le client**, le serveur les renvoie comme données | Choix assumé du schéma V2 : un client modifié peut afficher plus vite, mais jamais lire au-delà du nœud courant |
| 3 | Le **plafond de `confiance` (6 si `refus`) vit dans le moteur**, pas dans le contenu | Règle transverse (bible §6) : la dupliquer dans chaque `effects` la rendrait faillible |
| 4 | `refus = true` posé par **`nodes.effects` du N11**, pas par un choix | Les deux chemins d'entrée au N11 (N6-C, N10-B) doivent le poser ; c'est une propriété du nœud. C'est le seul usage de `nodes.effects` au ch. 1 |
| 5 | Le **séparateur porte le délai réel** (`content_type='separator'`, `body='23h02'`, `delay_seconds=20`) | L'ellipse narrative masque un délai court : un seul objet suffit à porter les deux |
| 6 | `messages.contact_id` étant `not null`, les séparateurs sont **rattachés à Léna** | Ils vivent dans son fil. Aucun impact d'affichage : le client se fie à `content_type` |
| 7 | Trigger `trg_player_progress_updated_at` sur `player_progress` | `updated_at` fiable sans dépendre de la rigueur des Edge Functions |
| 8 | Aucune contrainte CHECK sur le délai max de 90 s | Règle du **ch. 1 seulement** (bible §9) : les ch. 2+ ont de vraies attentes. Vérifiée par script, pas par le schéma |
