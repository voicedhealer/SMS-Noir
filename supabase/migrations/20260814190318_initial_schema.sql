-- ============================================================================
-- NUMÉRO INCONNU — schéma initial
-- Référence : docs/schema-supabase-v2.md
-- Écarts validés en Phase 0 : voir docs/ARCHITECTURE.md § Écarts au schéma
--   A. nodes.next_node_id          (transitions automatiques)
--   B. player_messages.seq         (ordre d'affichage déterministe)
--   C. player_messages.contact_id  (= fil de conversation, not null)
-- ============================================================================

-- ============================================================================
-- 1. CONTENU NARRATIF
-- ============================================================================

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

-- Personnages/contacts : un fil de conversation par contact (multi-conversations natif).
create table contacts (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references stories(id) on delete cascade,
  code text not null,                       -- 'lena', 'karim', 'inconnu'
  display_name text not null,               -- nom affiché dans la liste de conversations
  avatar_url text,
  unique (story_id, code)
);

create table chapters (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references stories(id) on delete cascade,
  position int not null check (position > 0),
  title text not null,
  unlock_delay_minutes int not null default 0 check (unlock_delay_minutes >= 0),
  entry_node_id uuid,                       -- FK ajoutée après la création de nodes
  unique (story_id, position)
);

create table nodes (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references chapters(id) on delete cascade,
  code text not null,                       -- 'N19' — label libre, AUCUN ordre implicite
  kind text not null default 'scripted'
    check (kind in ('scripted','ai_moment','chapter_end')),
  -- Écart A : transition automatique, pour les nœuds qui enchaînent sans aucun choix
  -- (ch. 1 : N5, N7, N12, N18, N19 + N13, N16, N21 après leur interaction).
  next_node_id uuid references nodes(id),
  ai_system_prompt text,
  ai_max_exchanges int default 4 check (ai_max_exchanges is null or ai_max_exchanges > 0),
  ai_fallback_node_id uuid references nodes(id),
  effects jsonb not null default '{}',
  unique (chapter_id, code),
  -- Un ai_moment sort par ai_fallback_node_id, jamais par next_node_id.
  constraint ai_moment_has_no_next
    check (kind <> 'ai_moment' or next_node_id is null),
  -- Un chapter_end est terminal.
  constraint chapter_end_is_terminal
    check (kind <> 'chapter_end' or next_node_id is null)
);

comment on column nodes.code is
  'Label libre (N1..N22). N''implique aucun ordre : au ch. 1, N9 arrive après N20 et N15 n''existe pas.';
comment on column nodes.next_node_id is
  'Écart A — transition automatique quand le nœud n''a aucun choix reply/ignore.';
comment on column nodes.effects is
  'Effets appliqués à l''ENTRÉE du nœud. Ch. 1 : uniquement N11 -> {"set":{"refus":true}}.';

alter table chapters
  add constraint fk_entry_node foreign key (entry_node_id) references nodes(id);

create table messages (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references nodes(id) on delete cascade,
  position int not null check (position >= 0),
  contact_id uuid not null references contacts(id),   -- qui parle
  content_type text not null default 'text'
    check (content_type in ('text','image','audio','system','separator')),
  body text,                                -- texte, ou libellé du séparateur ('23h31')
  media_url text,                           -- TTS/images : bucket Storage
  delay_seconds int not null default 4 check (delay_seconds >= 0),
  typing_seconds int not null default 3 check (typing_seconds >= 0),
  push_notification boolean not null default false,
  push_text text,
  unique (node_id, position),
  -- Un message porteur de texte doit avoir un corps ; un média doit avoir une URL.
  constraint text_needs_body
    check (content_type not in ('text','system','separator') or body is not null),
  constraint media_needs_url
    check (content_type not in ('image','audio') or media_url is not null)
);

comment on column messages.body is
  'Séparateur : libellé horaire affiché (« 23h31 »). Le délai réel masqué par l''ellipse est dans delay_seconds.';

create table choices (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references nodes(id) on delete cascade,
  position int not null check (position >= 0),
  label text not null,
  kind text not null default 'reply'
    check (kind in ('reply','ignore','interaction')),
  -- 'interaction' = actions cachées (zoom, réécoute, relance) :
  -- non affichées comme réponses, déclenchées par un geste UI.
  next_node_id uuid references nodes(id), -- null pour une interaction qui reste dans le nœud
  inline_response jsonb,                  -- réponse à une interaction sans changement de nœud
  effects jsonb not null default '{}',
  conditions jsonb not null default '{}',
  unique (node_id, position),
  -- Seule une interaction peut rester sur place ; un reply/ignore mène toujours quelque part.
  constraint reply_needs_target
    check (kind = 'interaction' or next_node_id is not null)
);

comment on column choices.inline_response is
  'Liste de messages ([{sender, content_type, body, delay_seconds, ...}]) jouée sans changer de nœud.';
comment on column choices.conditions is
  'Ch. 1 : not_contains sur interactions_faites, pour rendre les interactions cachées non répétables.';

-- Index sur les clés étrangères non couvertes par une contrainte unique
create index idx_contacts_story on contacts (story_id);
create index idx_chapters_story on chapters (story_id);
create index idx_nodes_chapter on nodes (chapter_id);
create index idx_nodes_next on nodes (next_node_id);
create index idx_nodes_ai_fallback on nodes (ai_fallback_node_id);
create index idx_messages_contact on messages (contact_id);
create index idx_choices_next on choices (next_node_id);
create index idx_stories_status on stories (status);

-- ============================================================================
-- 2. DONNÉES JOUEUR
-- ============================================================================

create table player_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  story_id uuid not null references stories(id) on delete cascade,
  current_node_id uuid references nodes(id),
  current_message_position int not null default 0 check (current_message_position >= 0),
  variables jsonb not null default
    '{"confiance": 3, "lucidite": 0, "indices": [], "refus": false, "branche_ch1": null}',
  detail_perso text,                        -- ⚠️ RGPD (bible §9) : un seul élément anodin
  chapter_unlocked_at timestamptz,
  completed_at timestamptz,
  ending_code text,
  updated_at timestamptz not null default now(),
  unique (user_id, story_id)
);

comment on column player_progress.variables is
  'confiance (0-10, plafond 6 si refus) · lucidite (0-5 ch.1) · indices [] · refus · branche_ch1. '
  'La clé interactions_faites [] est ajoutée à l''exécution (interactions cachées non répétables).';
comment on column player_progress.detail_perso is
  'RGPD : élément anodin donné au moment IA N9. Effacé en cascade avec la progression.';

create index idx_progress_current_node on player_progress (current_node_id);
create index idx_progress_story on player_progress (story_id);

create table player_messages (
  id uuid primary key default gen_random_uuid(),
  progress_id uuid not null references player_progress(id) on delete cascade,
  -- Écart B : ordre d'affichage. created_at vaut now() = heure de DÉBUT de transaction, donc
  -- identique pour tous les messages écrits par un même advance -> inutilisable pour trier.
  seq bigserial not null,
  -- Écart C : fil de conversation (le contact), y compris pour les messages du joueur.
  -- C'est `sender` qui dit qui parle. Sans ça, les réponses du joueur ne sont rattachables
  -- à aucun fil dès qu'il y a plusieurs contacts (twist ch. 4).
  contact_id uuid not null references contacts(id),
  sender text not null default 'contact'
    check (sender in ('contact','player')),
  content_type text not null default 'text'
    check (content_type in ('text','image','audio','system','separator')),
  body text,
  media_url text,
  source text not null default 'scripted'
    check (source in ('scripted','player_choice','player_free','ai')),
  created_at timestamptz not null default now()  -- informatif seulement
);

comment on column player_messages.seq is
  'Écart B — clé de tri du fil. created_at est informatif seulement.';
comment on column player_messages.contact_id is
  'Écart C — fil de conversation, pas locuteur. Voir sender pour savoir qui parle.';

-- Tri du fil : par conversation, dans l'ordre d'écriture
create index idx_player_messages_thread on player_messages (progress_id, contact_id, seq);
create index idx_player_messages_progress_seq on player_messages (progress_id, seq);

-- Rate limit IA (prompt 3)
create table ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  exchanges int not null default 0 check (exchanges >= 0),
  primary key (user_id, day)
);

-- updated_at auto sur player_progress
create function set_updated_at() returns trigger
  language plpgsql
  set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_player_progress_updated_at
  before update on player_progress
  for each row execute function set_updated_at();

-- ============================================================================
-- 3. RLS — anti-spoiler
-- Le client ne lit JAMAIS le contenu narratif. Tout passe par les Edge Functions
-- (service_role, qui contourne RLS). Seule exception : la vitrine des histoires publiées.
-- ============================================================================

alter table stories          enable row level security;
alter table contacts         enable row level security;
alter table chapters         enable row level security;
alter table nodes            enable row level security;
alter table messages         enable row level security;
alter table choices          enable row level security;
alter table player_progress  enable row level security;
alter table player_messages  enable row level security;
alter table ai_usage         enable row level security;

-- Contenu : aucune policy select pour contacts/chapters/nodes/messages/choices.
-- RLS activé + zéro policy = zéro ligne visible côté client. C'est voulu.

-- Seule exception : la vitrine (liste des histoires publiées).
-- NB : le ch. 1 est seedé en status='draft' -> vitrine vide tant qu'on ne publie pas. Normal.
create policy "browse published stories" on stories
  for select to authenticated using (status = 'published');

-- Joueur : lecture seule de SES données. Aucune policy insert/update/delete :
-- le moteur serveur écrit tout.
create policy "read own progress" on player_progress
  for select to authenticated using (auth.uid() = user_id);

create policy "read own messages" on player_messages
  for select to authenticated using (
    progress_id in (select id from player_progress where user_id = auth.uid())
  );

create policy "read own ai usage" on ai_usage
  for select to authenticated using (auth.uid() = user_id);
