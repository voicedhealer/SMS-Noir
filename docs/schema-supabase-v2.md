# NUMÉRO INCONNU — Schéma Supabase V2

**Changements vs V1 :** anti-spoiler (le client ne lit plus jamais le contenu directement), multi-conversations natif, notifications app fermée, rate limit IA, RGPD sur `detail_perso`.

## Vue d'ensemble

```
stories ──< chapters ──< nodes ──< messages
   │                        └──< choices ──> (next_node_id)
   └──< contacts  (Léna, Karim, ???)

players ──< player_progress ──< player_messages
                └── (conversations dérivées des contacts rencontrés)
```

## Tables de contenu

```sql
create table stories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  tagline text,
  genre text not null default 'thriller',
  cover_url text,
  status text not null default 'draft'
    check (status in ('draft','published','archived')),
  is_premium boolean not null default false,
  created_at timestamptz not null default now()
);

-- V2 : personnages/contacts (multi-conversations)
create table contacts (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references stories(id) on delete cascade,
  code text not null,                     -- 'lena', 'karim', 'inconnu'
  display_name text not null,            -- nom affiché dans la liste de conversations
  avatar_url text,
  unique (story_id, code)
);

create table chapters (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references stories(id) on delete cascade,
  position int not null,
  title text not null,
  unlock_delay_minutes int not null default 0,
  entry_node_id uuid,
  unique (story_id, position)
);

create table nodes (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references chapters(id) on delete cascade,
  code text not null,                     -- 'N19'
  kind text not null default 'scripted'
    check (kind in ('scripted','ai_moment','chapter_end')),
  ai_system_prompt text,
  ai_max_exchanges int default 4,
  ai_fallback_node_id uuid references nodes(id),
  effects jsonb not null default '{}',
  unique (chapter_id, code)
);

alter table chapters
  add constraint fk_entry_node foreign key (entry_node_id) references nodes(id);

create table messages (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references nodes(id) on delete cascade,
  position int not null,
  contact_id uuid not null references contacts(id),  -- V2 : qui parle
  content_type text not null default 'text'
    check (content_type in ('text','image','audio','system','separator')),
  body text,                              -- texte, ou libellé du séparateur ('23h31')
  media_url text,                         -- TTS/images : bucket Storage
  delay_seconds int not null default 4,
  typing_seconds int not null default 3,
  push_notification boolean not null default false,
  push_text text,
  unique (node_id, position)
);

create table choices (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references nodes(id) on delete cascade,
  position int not null,
  label text not null,
  kind text not null default 'reply'      -- V2 : reply | ignore | interaction
    check (kind in ('reply','ignore','interaction')),
  -- 'interaction' = actions cachées (zoom, réécoute, relance) :
  -- non affichées comme réponses, déclenchées par un geste UI
  next_node_id uuid references nodes(id), -- null pour une interaction qui reste dans le nœud
  inline_response jsonb,                  -- V2 : réponse de Léna à une interaction sans changer de nœud
  effects jsonb not null default '{}',
  conditions jsonb not null default '{}',
  unique (node_id, position)
);
```

## Tables joueur

```sql
create table player_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  story_id uuid not null references stories(id) on delete cascade,
  current_node_id uuid references nodes(id),
  current_message_position int not null default 0,
  variables jsonb not null default
    '{"confiance": 3, "lucidite": 0, "indices": [], "refus": false, "branche_ch1": null}',
  detail_perso text,                      -- ⚠️ RGPD : voir section dédiée
  chapter_unlocked_at timestamptz,
  completed_at timestamptz,
  ending_code text,
  updated_at timestamptz not null default now(),
  unique (user_id, story_id)
);

create table player_messages (
  id uuid primary key default gen_random_uuid(),
  progress_id uuid not null references player_progress(id) on delete cascade,
  contact_id uuid references contacts(id),  -- null = message du joueur
  sender text not null default 'contact'
    check (sender in ('contact','player')),
  content_type text not null default 'text',
  body text,
  media_url text,
  source text not null default 'scripted'
    check (source in ('scripted','player_choice','player_free','ai')),
  created_at timestamptz not null default now()
);
create index on player_messages (progress_id, contact_id, created_at);

-- V2 : rate limit IA
create table ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  exchanges int not null default 0,
  primary key (user_id, day)
);
```

## RLS V2 — anti-spoiler (changement majeur)

```sql
-- Contenu narratif : AUCUNE lecture directe par le client.
-- (RLS activé, aucune policy select pour authenticated → tout passe par Edge Functions)
alter table stories enable row level security;
alter table contacts enable row level security;
alter table chapters enable row level security;
alter table nodes enable row level security;
alter table messages enable row level security;
alter table choices enable row level security;

-- Seule exception : la vitrine (liste des histoires publiées)
create policy "browse published stories" on stories
  for select to authenticated using (status = 'published');

-- Joueur : lecture seule de SES données ; écritures via Edge Functions uniquement
alter table player_progress enable row level security;
create policy "read own progress" on player_progress
  for select using (auth.uid() = user_id);

alter table player_messages enable row level security;
create policy "read own messages" on player_messages
  for select using (
    progress_id in (select id from player_progress where user_id = auth.uid())
  );
-- Pas de policy insert/update côté client : le moteur serveur écrit tout.
```

Pourquoi : en V1, un joueur curieux pouvait lire les 3 fins et toutes les branches via l'API REST. En V2, il ne peut recevoir que le nœud courant, servi par le serveur. Les variables deviennent aussi infalsifiables (plus de triche possible sur `confiance` ou `indices`).

## Edge Functions (le vrai moteur)

| Fonction | Rôle |
|---|---|
| `get-state` | Retourne : conversations du joueur, historique, nœud courant avec SEULEMENT ses messages/choix (jamais les `next_node_id` des autres branches ni les `effects` — le client n'a pas besoin de les connaître) |
| `advance` | Reçoit un `choice_id` (ou `interaction_id`) → valide qu'il appartient bien au nœud courant → applique `effects` → avance `current_node_id` → retourne les nouveaux messages à dérouler |
| `ai-chat` | Moment IA : vérifie `nodes.kind='ai_moment'` + quota `ai_usage` (ex. 20 échanges/jour) → appelle l'API (Mistral Small ou Claude Haiku) avec system prompt + garde-fous → écrit dans `player_messages` (source='ai') → détecte fin d'échange → bascule vers `ai_fallback_node_id` |
| `unlock-chapter` | Vérifie `chapter_unlocked_at <= now()` (ou achat premium validé) → débloque. L'horloge du téléphone n'a aucun pouvoir. |

Petit détail qui compte : `advance` retourne les messages avec leurs `delay_seconds`, mais c'est le CLIENT qui joue les délais (timers locaux). Le serveur, lui, considère le nœud comme atteint. Compromis assumé : un client modifié pourrait afficher les messages plus vite, mais jamais lire au-delà du nœud courant.

## Notifications app fermée (V2)

Deux mécanismes complémentaires :

1. **Notifications locales programmées (Flutter, `flutter_local_notifications`)** : quand l'app déroule un nœud avec des délais, elle programme immédiatement les notifs locales des messages `push_notification=true` à venir. App tuée → les notifs partent quand même. App rouverte avant → elles sont annulées et remplacées par l'affichage normal.
2. **Push serveur (FCM)** : uniquement pour le déblocage de chapitre (« Léna t'a envoyé un message » 8h plus tard) — événement côté serveur, cron Supabase (`pg_cron`) qui scanne les `chapter_unlocked_at` échus.

## RGPD — `detail_perso` et saisies libres

- **Consentement** : première saisie libre → petit écran unique : « Tes réponses libres sont traitées par une IA pour personnaliser l'histoire et peuvent être conservées. » (case à cocher, lien privacy policy)
- **Minimisation** : l'IA a pour consigne de ne stocker qu'UN élément anodin (prénom, ville, métier) — jamais santé, religion, orientation, etc. (liste d'exclusion dans le system prompt + filtre serveur)
- **Effacement** : suppression du compte → cascade sur `player_progress` (donc `detail_perso`) et `player_messages`. Prévoir aussi un bouton « réinitialiser l'histoire » qui purge tout.
- **Sous-traitant IA** : à mentionner dans la privacy policy (Mistral = données en Europe, argument de choix).

## Flux V2 (côté app)

1. Ouverture → `get-state` → liste des conversations + historique + nœud courant
2. L'app déroule les messages (timers locaux, notifs locales programmées, écriture différée via `advance` en mode "ack")
3. Choix `reply` → `advance` → suite · Bouton `ignore` → `advance` avec le choix ignore
4. `interaction` (zoom, réécoute, relance) → `advance` → si `inline_response` : messages additionnels sans changer de nœud
5. `ai_moment` → saisie libre → `ai-chat` (quota vérifié) → réponses → bascule auto vers le fallback
6. `chapter_end` → `chapter_unlocked_at` posé serveur → écran de fin + compte à rebours

## Prompts Claude Code — ordre confirmé

1. **Prompt 1** — Migration (ce schéma) + seed complet du chapitre 1 V2 + Edge Functions `get-state`/`advance`
2. **Prompt 2** — App Flutter : liste conversations, écran messagerie (bulles, typing, délais, séparateurs), choix + interactions cachées
3. **Prompt 3** — Edge Function `ai-chat` + quota + garde-fous + `detail_perso`
4. **Prompt 4** — Déblocages, notifs locales + FCM + cron, écran de fin de chapitre
