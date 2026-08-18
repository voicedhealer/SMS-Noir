-- ============================================================================
-- VÉRIFICATION DU GRAPHE — « Numéro Inconnu », chapitre 1
--
-- Usage :
--   docker exec -i supabase_db_SMS-Noir psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < scripts/verify-graph.sql
--
-- Sort en erreur (exit code non nul) si un seul contrôle échoue.
-- ============================================================================

\set ON_ERROR_STOP on
\pset footer off

-- Périmètre : les nœuds du chapitre 1 de l'histoire
create temp view _n as
  select n.* from nodes n
    join chapters c on c.id = n.chapter_id
    join stories  s on s.id = c.story_id
  where s.slug = 'numero-inconnu' and c.position = 1;

create temp view _entry as
  select c.entry_node_id as id from chapters c
    join stories s on s.id = c.story_id
  where s.slug = 'numero-inconnu' and c.position = 1;

-- Toutes les arêtes du graphe : choix, transitions automatiques, fallback IA
create temp view _edges as
  select n.id as src, ch.next_node_id as dst
    from _n n join choices ch on ch.node_id = n.id
   where ch.next_node_id is not null
  union
  select n.id, n.next_node_id        from _n n where n.next_node_id is not null
  union
  select n.id, n.ai_fallback_node_id from _n n where n.ai_fallback_node_id is not null;

-- Atteignabilité depuis le nœud d'entrée
create temp view _reach as
  with recursive r as (
    select id from _entry
    union
    select e.dst from r join _edges e on e.src = r.id
  ) select id from r;

-- Atteignabilité INVERSE depuis N22 : qui peut arriver à la fin ?
create temp view _back as
  with recursive b as (
    select id from _n where code = 'N22'
    union
    select e.src from b join _edges e on e.dst = b.id
  ) select id from b;

create temp table _report (ordre int, controle text, attendu text, obtenu text, statut text);

drop function if exists _chk(int, text, text, text);
create function _chk(p_ordre int, p_ctrl text, p_attendu text, p_obtenu text) returns void
language sql as $$
  insert into _report values (p_ordre, p_ctrl, p_attendu, p_obtenu,
    case when p_attendu = p_obtenu then 'OK' else 'ECHEC' end);
$$;

\o /dev/null

-- ---------------------------------------------------------------------------
-- STRUCTURE
-- ---------------------------------------------------------------------------
select _chk(1, 'Nombre de nœuds (N1..N22, sans N15)', '21', (select count(*)::text from _n));
select _chk(2, 'Nœud d''entrée défini', 'N1',
  coalesce((select code from _n where id = (select id from _entry)), '<absent>'));
select _chk(3, 'Un seul chapter_end, et c''est N22', 'N22',
  coalesce((select string_agg(code, ',' order by code) from _n where kind = 'chapter_end'), '<aucun>'));
select _chk(4, 'Un seul ai_moment, et c''est N9', 'N9',
  coalesce((select string_agg(code, ',' order by code) from _n where kind = 'ai_moment'), '<aucun>'));
select _chk(5, 'Le fallback du N9 pointe sur N21', 'N21',
  coalesce((select f.code from _n n join _n f on f.id = n.ai_fallback_node_id where n.code = 'N9'), '<absent>'));
select _chk(6, 'N9 porte un prompt système structuré', 'oui',
  (select case when ai_system_prompt like '%# Ta voix%'
                and ai_system_prompt like '%# Ce que tu ignores%'
                and ai_system_prompt like '%# Interdits absolus%'
                and ai_system_prompt like '%# Ce que tu renvoies%'
               then 'oui' else 'non' end from _n where code = 'N9'));

-- L'étanchéité narrative est dans le prompt, pas seulement dans le code.
select _chk(8, 'Le prompt verrouille l''étanchéité narrative', 'oui',
  (select case when ai_system_prompt like '%intelligence artificielle%'
                and ai_system_prompt like '%N''invente jamais%'
                and ai_system_prompt like '%tu ne le reconnais pas%'
               then 'oui' else 'non' end from _n where code = 'N9'));

-- Et surtout : le prompt ne NOMME pas ce qu'elle doit taire.
--
-- Ce contrôle garde une leçon apprise à la sonde. Le prompt disait « Tu ne
-- parleras pas de Karim ce soir », et Léna a répondu « Karim n'est plus là
-- depuis longtemps » — un fait inventé sur un personnage du chapitre 3.
-- Nommer l'interdit apprend au modèle que la chose existe. Voir LOGIQUE.md.
select _chk(50, 'Le prompt ne nomme aucun interdit (personnage ni date)', 'oui',
  (select case when ai_system_prompt not like '%Karim%'
                and ai_system_prompt not like '%12 mars%'
               then 'oui' else 'non' end from _n where code = 'N9'));

select _chk(9, 'La liste d''autorisation de detail_perso y figure', 'oui',
  (select case when ai_system_prompt like '%prenom%' and ai_system_prompt like '%ville%'
                and ai_system_prompt like '%metier%' and ai_system_prompt like '%animal%'
                and ai_system_prompt like '%autre chose que ces quatre catégories%'
               then 'oui' else 'non' end from _n where code = 'N9'));
select _chk(7, 'Chapitre 2 stub présent (cible du compte à rebours)', 'Chloé/480',
  coalesce((select c.title || '/' || c.unlock_delay_minutes from chapters c
              join stories s on s.id = c.story_id
            where s.slug = 'numero-inconnu' and c.position = 2), '<absent>'));

-- ---------------------------------------------------------------------------
-- INTÉGRITÉ DU GRAPHE
-- ---------------------------------------------------------------------------
select _chk(10, 'Aucun nœud orphelin (tous atteignables depuis N1)', '',
  coalesce((select string_agg(code, ', ' order by code) from _n
            where id not in (select id from _reach)), ''));

select _chk(11, 'Tous les chemins mènent à N22', '',
  coalesce((select string_agg(code, ', ' order by code) from _n
            where id not in (select id from _back)), ''));

select _chk(12, 'Aucun choix vers un nœud hors du chapitre 1', '',
  coalesce((select string_agg(distinct n.code, ', ') from _n n
              join choices ch on ch.node_id = n.id
            where ch.next_node_id is not null
              and ch.next_node_id not in (select id from _n)), ''));

select _chk(13, 'Aucune impasse (nœud sans sortie autre que N22)', '',
  coalesce((select string_agg(code, ', ' order by code) from _n
            where id not in (select src from _edges) and kind <> 'chapter_end'), ''));

select _chk(14, 'Tout nœud sans reply/ignore a une transition auto', '',
  coalesce((select string_agg(n.code, ', ' order by n.code) from _n n
            where n.kind = 'scripted'
              and n.next_node_id is null
              and not exists (select 1 from choices ch
                              where ch.node_id = n.id and ch.kind in ('reply','ignore'))), ''));

-- ---------------------------------------------------------------------------
-- LES 6 INTERACTIONS CACHÉES (bible §8)
-- ---------------------------------------------------------------------------
select _chk(20, 'Relance N8 — PROFIL_SUSPECT', 'oui',
  (select case when count(*) = 1 then 'oui' else 'non' end from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N8' and ch.kind = 'interaction' and ch.effects->'append'->>'indices' = 'PROFIL_SUSPECT'));
select _chk(21, 'Relance N8 — BORNAGE', 'oui',
  (select case when count(*) = 1 then 'oui' else 'non' end from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N8' and ch.kind = 'interaction' and ch.effects->'append'->>'indices' = 'BORNAGE'));
select _chk(22, 'Relance N8 — les 2 questions s''excluent (même clé)', 'RELANCE_N8',
  coalesce((select distinct ch.effects->'append'->>'interactions_faites' from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N8' and ch.kind = 'interaction'
     and ch.effects->'append'->>'interactions_faites' = 'RELANCE_N8'), '<absent>'));
-- V3.2 : le zoom du récépissé remonte du N10 au N8. Au N10 il n'était visible
-- que sur la branche « appelez la police », et l'incohérence n°1 restait
-- inaccessible aux deux autres — la fin cachée ne doit pas dépendre d'un choix
-- structurant pris au hasard.
select _chk(23, 'Zoom récépissé au N8 — lucidite +1', '1',
  coalesce((select (ch.effects->'inc'->>'lucidite') from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N8' and ch.kind = 'interaction'
     and ch.effects->'append'->>'interactions_faites' = 'ZOOM_RECEPISSE'), '<absent>'));

select _chk(51, 'Le N10 ne porte plus d''interaction', '0',
  (select count(*)::text from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N10' and ch.kind = 'interaction'));
select _chk(24, 'Insister N13 — lucidite +1', '1',
  coalesce((select (ch.effects->'inc'->>'lucidite') from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N13' and ch.kind = 'interaction'), '<absent>'));
select _chk(25, 'Zoom autocollant N16 — AUTOCOLLANT', 'AUTOCOLLANT',
  coalesce((select ch.effects->'append'->>'indices' from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N16' and ch.kind = 'interaction'), '<absent>'));
select _chk(26, 'Réécoute vocal N17 — lucidite +1', '1',
  coalesce((select (ch.effects->'inc'->>'lucidite') from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N17' and ch.kind = 'interaction'), '<absent>'));
select _chk(27, 'Zoom téléphone N21 — TELEPHONE', 'TELEPHONE',
  coalesce((select ch.effects->'append'->>'indices' from _n n join choices ch on ch.node_id = n.id
   where n.code = 'N21' and ch.kind = 'interaction'), '<absent>'));
select _chk(28, '6 interactions sur 7 lignes, réparties sur 5 nœuds', '5/7',
  (select count(distinct n.code) || '/' || count(*) from _n n join choices ch on ch.node_id = n.id
   where ch.kind = 'interaction'));

-- ---------------------------------------------------------------------------
-- COHÉRENCE DU MOTEUR
-- ---------------------------------------------------------------------------
select _chk(30, 'Chaque interaction est à usage unique (condition not_contains)', '',
  coalesce((select string_agg(n.code || '#' || ch.position, ', ') from _n n join choices ch on ch.node_id = n.id
            where ch.kind = 'interaction'
              and ch.conditions->'not_contains'->>'interactions_faites'
                  is distinct from ch.effects->'append'->>'interactions_faites'), ''));

select _chk(31, 'Aucune interaction sans effet ni réponse', '',
  coalesce((select string_agg(n.code || '#' || ch.position, ', ') from _n n join choices ch on ch.node_id = n.id
            where ch.kind = 'interaction' and ch.next_node_id is null
              and ch.effects = '{}'::jsonb and ch.inline_response is null), ''));

select _chk(32, 'Tout reply/ignore a une cible', '',
  coalesce((select string_agg(n.code || '#' || ch.position, ', ') from _n n join choices ch on ch.node_id = n.id
            where ch.kind in ('reply','ignore') and ch.next_node_id is null), ''));

select _chk(33, 'refus=true posé par le nœud N11 (et lui seul)', 'N11',
  coalesce((select string_agg(code, ',' order by code) from _n
            where effects->'set'->>'refus' = 'true'), '<aucun>'));

select _chk(34, 'Aucun effect ne code le plafond de confiance (règle moteur)', '',
  coalesce((select string_agg(n.code || '#' || ch.position, ', ') from _n n join choices ch on ch.node_id = n.id
            where ch.effects::text ilike '%plafond%' or ch.effects->'set' ? 'confiance'), ''));

select _chk(35, 'Les 4 branches ch.1 sont toutes atteignables', 'allié,curieux,empathie,prudent',
  (select string_agg(distinct ch.effects->'set'->>'branche_ch1', ',' order by ch.effects->'set'->>'branche_ch1')
   from _n n join choices ch on ch.node_id = n.id where ch.effects->'set' ? 'branche_ch1'));

select _chk(36, 'Les 5 indices du chapitre sont tous attribuables',
  'AUTOCOLLANT,BORNAGE,PLAQUE,PROFIL_SUSPECT,TELEPHONE',
  (select string_agg(distinct ch.effects->'append'->>'indices', ',' order by ch.effects->'append'->>'indices')
   from _n n join choices ch on ch.node_id = n.id where ch.effects->'append' ? 'indices'));

-- ---------------------------------------------------------------------------
-- CONTENU
-- ---------------------------------------------------------------------------
select _chk(40, 'Règle de rythme ch.1 : aucun délai > 90 s', '',
  coalesce((select string_agg(n.code || '#' || m.position || '=' || m.delay_seconds || 's', ', ')
            from _n n join messages m on m.node_id = n.id where m.delay_seconds > 90), ''));

-- Une position peut porter plusieurs variantes (conditions mutuellement
-- exclusives, ex. N9#0) depuis l'ajout de messages.conditions : on compte les
-- positions DISTINCTES, pas les lignes, sinon toute variante fausse ce contrôle.
select _chk(41, 'Positions des messages contiguës depuis 0', '',
  coalesce((select string_agg(code, ', ' order by code) from (
              select n.code, count(distinct m.position) nb, max(m.position) mx, min(m.position) mn
              from _n n join messages m on m.node_id = n.id group by n.code
            ) t where mn <> 0 or mx <> nb - 1), ''));

-- Le contenu référence 5 médias (3 photos, 1 vocal, 1 vidéo de transition).
-- Qu'ils soient encore en placeholder ou déjà téléversés ne regarde pas ce
-- script : c'est leur PRÉSENCE qui est structurelle.
select _chk(42, 'Le chapitre référence 5 médias', '5',
  (select count(*)::text from _n n join messages m on m.node_id = n.id
   where m.content_type in ('image', 'audio', 'video')));

select _chk(43, 'Aucun média sans URL', '',
  coalesce((select string_agg(n.code || '#' || m.position, ', ') from _n n join messages m on m.node_id = n.id
            where m.content_type in ('image','audio','video') and m.media_url is null), ''));

-- 69 lignes pour 66 positions distinctes : N9#1 (ex-N9#0, décalée par la vidéo
-- de transition en position 0), N21#0, N21#2, N22#1 portent chacune 2
-- variantes (refus true/false) — voir messages.conditions, LOGIQUE.md.
select _chk(44, 'Nombre total de messages', '69',
  (select count(*)::text from _n n join messages m on m.node_id = n.id));

select _chk(45, 'Nombre total de choix', '93',
  (select count(*)::text from _n n join choices ch on ch.node_id = n.id));

select _chk(46, 'Répartition des choix (ignore/interaction/reply)', '0/7/26',
  (select count(*) filter (where ch.kind='ignore') || '/' ||
          count(*) filter (where ch.kind='interaction') || '/' ||
          count(*) filter (where ch.kind='reply')
   from _n n join choices ch on ch.node_id = n.id));

select _chk(47, 'Séparateurs horaires (ellipses narratives)', '6',
  (select count(*)::text from _n n join messages m on m.node_id = n.id where m.content_type = 'separator'));

-- ---------------------------------------------------------------------------
-- RÉVÉLATION D'IDENTITÉ
-- ---------------------------------------------------------------------------
select _chk(50, 'Léna arrive anonyme (display_name_initial)', 'Numéro inconnu',
  coalesce((select ct.display_name_initial from contacts ct join stories s on s.id = ct.story_id
            where s.slug = 'numero-inconnu' and ct.code = 'lena'), '<absent>'));

select _chk(51, 'Carte d''enregistrement sur les 3 branches vers N8', 'N5,N6,N7',
  coalesce((select string_agg(distinct n.code, ',' order by n.code)
            from _n n join messages m on m.node_id = n.id
            where m.content_type = 'contact_card'), '<absente>'));

-- La révélation n'est plus automatique : c'est le geste du joueur. Ce contrôle
-- garantit qu'elle arrive quand même à celui qui n'a jamais enregistré.
select _chk(55, 'Filet de sécurité : révélation garantie en fin de chapitre', 'N22',
  coalesce((select string_agg(code, ',' order by code) from _n
            where effects ? 'reveal_contact'), '<absent>'));

select _chk(56, 'Le contact porte un numéro à afficher', '06 39 98 41 07',
  coalesce((select ct.phone_number from contacts ct join stories s on s.id = ct.story_id
            where s.slug = 'numero-inconnu' and ct.code = 'lena'), '<absent>'));

select _chk(52, 'Tout reveal_contact cible un contact existant', '',
  coalesce((select string_agg(n.code, ', ') from _n n
            where n.effects ? 'reveal_contact'
              and not exists (select 1 from contacts ct join stories s on s.id = ct.story_id
                              where s.slug = 'numero-inconnu'
                                and ct.code = n.effects->>'reveal_contact')), ''));

select _chk(53, 'Léna se nomme sur chaque nœud qui pose une carte', '3',
  (select count(distinct n.code)::text from _n n
   where exists (select 1 from messages m where m.node_id = n.id and m.content_type = 'contact_card')
     and exists (select 1 from messages m where m.node_id = n.id and m.body like '%Léna%')));

-- Q7 : aucun chemin ne prive le joueur de la carte. (La révélation elle-même
-- est garantie par le filet du N22, contrôle 55.)
select _chk(54, 'Aucun chemin vers N22 n''évite la carte', 'aucun',
  coalesce((with recursive e as (
      select n.id src, ch.next_node_id dst from _n n join choices ch on ch.node_id = n.id
        where ch.next_node_id is not null
      union select n.id, n.next_node_id from _n n where n.next_node_id is not null
      union select n.id, n.ai_fallback_node_id from _n n where n.ai_fallback_node_id is not null
    ), p as (
      select (select id from _entry) node, 0 prof
      union all
      select e.dst, p.prof + 1 from p join e on e.src = p.node
        where p.prof < 40
          and e.dst not in (select distinct m.node_id from messages m
                            where m.content_type = 'contact_card')
    )
    select 'chemin trouvé' from p
      join _n n on n.id = p.node where n.code = 'N22' limit 1), 'aucun'));

select _chk(60, 'Mise en scène du grand silence (N20#0)', '30/40',
  coalesce((select m.phantom_typing_at || '/' || m.haptic_at
            from _n n join messages m on m.node_id = n.id
            where n.code = 'N20' and m.position = 0), '<absente>'));

select _chk(61, 'Tout battement tombe dans son attente', '',
  coalesce((select string_agg(n.code || '#' || m.position, ', ')
            from _n n join messages m on m.node_id = n.id
            where coalesce(m.phantom_typing_at, -1) >= m.delay_seconds
               or coalesce(m.haptic_at, -1) >= m.delay_seconds), ''));

select _chk(70, 'Séquence d''intronisation : 4 panneaux', '4',
  (select jsonb_array_length(intro_panels)::text from stories where slug = 'numero-inconnu'));

select _chk(71, 'Le premier panneau date l''histoire (bible §3)', 'Jeudi 13 août 2026',
  coalesce((select intro_panels->0->'lines'->>0 from stories where slug = 'numero-inconnu'), '<absent>'));

-- ---------------------------------------------------------------------------
-- RAPPORT
-- ---------------------------------------------------------------------------
\o
\echo ''
\echo '=============================================================================='
\echo '  VÉRIFICATION DU GRAPHE — chapitre 1 « Le mauvais numéro »'
\echo '=============================================================================='

select lpad(ordre::text, 3) as "#",
       rpad(controle, 58)   as "Contrôle",
       statut               as "Statut",
       case when statut = 'ECHEC'
            then 'attendu [' || attendu || '] obtenu [' || obtenu || ']'
            else '' end     as "Détail"
from _report order by ordre;

drop function _chk(int, text, text, text);

do $$
declare v_ko int; v_tot int;
begin
  select count(*) filter (where statut = 'ECHEC'), count(*) into v_ko, v_tot from _report;
  if v_ko > 0 then
    raise exception E'\n\n  %/% CONTRÔLES EN ÉCHEC — voir le rapport ci-dessus.\n', v_ko, v_tot;
  end if;
  raise notice E'\n\n  ✅  % / % contrôles OK — le graphe du chapitre 1 est sain.\n', v_tot, v_tot;
end $$;
