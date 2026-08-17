-- Micro-choix à trois axes (chapitre 1 V3.1).
--
-- Trois nouveautés, toutes génériques : elles resserviront aux chapitres 2 à 6.
--
-- 1. `choices.after_position` — un choix peut s'afficher AU MILIEU d'un nœud,
--    après un message donné, au lieu d'attendre la fin.
-- 2. `kind = 'micro'` — un choix affiché comme une réponse ordinaire mais qui
--    ne change pas de nœud.
-- 3. `player_progress.node_cursor` — où on en est dans le nœud courant.
--
-- L'alternative était de découper chaque nœud à chaque pause : le chapitre 1
-- serait passé de 21 à ~45 nœuds, et on en a quatre autres à écrire. Une table
-- de nœuds qu'on ne peut plus relire est une dette narrative, pas technique.

-- ---------------------------------------------------------------------------
-- 1. Où le choix s'affiche dans le nœud
-- ---------------------------------------------------------------------------
alter table choices add column after_position int check (after_position >= 0);

comment on column choices.after_position is
  'Le choix s''affiche une fois le message de cette position délivré, et le '
  'déroulé s''y arrête. NULL = après tous les messages du nœud (comportement '
  'historique). Plusieurs choix partageant la même valeur forment un bloc.';

-- ---------------------------------------------------------------------------
-- 2. Le micro-choix : affiché comme une réponse, mais on reste dans le nœud
-- ---------------------------------------------------------------------------
--
-- `interaction` ne convenait pas : une interaction est CACHÉE, déclenchée par
-- un geste (zoom, relance). Un micro-choix est offert franchement, à égalité
-- avec les réponses structurantes — c'est même tout l'enjeu : le joueur ne
-- doit pas pouvoir distinguer un choix qui ramifie d'un choix qui ne fait
-- qu'enregistrer une posture.
alter table choices drop constraint choices_kind_check;
alter table choices add constraint choices_kind_check
  check (kind in ('reply', 'ignore', 'interaction', 'micro'));

-- Un reply/ignore mène toujours quelque part. Une interaction et un micro-choix
-- restent sur place.
alter table choices drop constraint reply_needs_target;
alter table choices add constraint reply_needs_target
  check (kind in ('interaction', 'micro') or next_node_id is not null);

-- Un micro-choix ne ramifie JAMAIS : c'est la règle 3 de la grammaire des trois
-- axes. La faire tenir par la base plutôt que par la vigilance : une seule
-- ligne de seed distraite suffirait à créer une branche fantôme.
alter table choices add constraint micro_ne_ramifie_pas
  check (kind <> 'micro' or next_node_id is null);

-- ---------------------------------------------------------------------------
-- 3. Où on en est dans le nœud courant
-- ---------------------------------------------------------------------------
alter table player_progress add column node_cursor int not null default 0;
alter table player_progress add column node_gate int;

comment on column player_progress.node_cursor is
  'Position du prochain message à délivrer dans le nœud courant. Remis à 0 à '
  'chaque entrée dans un nœud.';

comment on column player_progress.node_gate is
  'Pause actuellement ouverte (`choices.after_position`), ou NULL si le nœud '
  'est déroulé jusqu''au bout. Marqueur EXPLICITE, et pas déduit du curseur : '
  'une pause posée sur le dernier message d''un nœud laisse le curseur au même '
  'endroit avant et après la réponse, et se rouvrirait indéfiniment.';

-- ---------------------------------------------------------------------------
-- 4. Les variables de posture
-- ---------------------------------------------------------------------------
--
-- `enquete` mesure la POSTURE (le joueur creuse-t-il ?), là où `indices`
-- mesure les DÉCOUVERTES. Un joueur peut beaucoup enquêter et trouver peu.
--
-- `micro` est le décompte des micro-choix par axe. `structurel` garde la part
-- des variables qui vient des choix structurants, pour que la part de posture
-- puisse être recalculée à chaque fois sans jamais se cumuler à elle-même.
-- Voir docs/LOGIQUE.md § La grammaire des trois axes.
alter table player_progress alter column variables set default
  '{"confiance": 3, "lucidite": 0, "enquete": 0, "indices": [], "refus": false,
    "branche_ch1": null, "interactions_faites": [], "contacts_reveles": [],
    "micro": {"n": 0, "proteger": 0, "enquete": 0, "raison": 0},
    "structurel": {"confiance": 3, "lucidite": 0}}'::jsonb;

-- Reprise des parties en cours : la valeur atteinte devient la part
-- structurelle, puisqu'aucun micro-choix n'existait avant cette migration.
update player_progress set variables = variables
  || jsonb_build_object(
       'enquete', 0,
       'micro', '{"n": 0, "proteger": 0, "enquete": 0, "raison": 0}'::jsonb,
       'structurel', jsonb_build_object(
         'confiance', coalesce(variables -> 'confiance', '3'::jsonb),
         'lucidite',  coalesce(variables -> 'lucidite',  '0'::jsonb)))
where not (variables ? 'structurel');
