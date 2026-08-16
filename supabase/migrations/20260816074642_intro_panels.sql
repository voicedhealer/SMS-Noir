-- ============================================================================
-- Séquence d'intronisation, par histoire
--
-- Jouée une seule fois, à la toute première ouverture. Elle précède le premier
-- `get-state` et n'a aucun effet sur le moteur : c'est du client pur.
--
-- Pourquoi en base plutôt qu'en dur dans l'app : l'architecture est
-- multi-histoires. Un texte d'ouverture est du **contenu narratif**, au même
-- titre qu'un message de Léna — le mettre dans le code Dart violerait la règle
-- « zéro contenu narratif en dur » et obligerait à livrer une version de l'app
-- pour ajouter une histoire.
--
-- Format : liste de panneaux, chacun une liste de lignes.
--   [{"lines": ["Jeudi 13 août 2026."]},
--    {"lines": ["Jeudi soir.", "Rien de prévu."]}, …]
--
-- Le dernier panneau reste affiché un peu plus longtemps — c'est le
-- basculement. Les timings exacts sont côté client (DESIGN.md) : ce sont des
-- constantes de mise en scène, pas du contenu.
-- ============================================================================

alter table stories
  add column intro_panels jsonb not null default '[]'::jsonb,
  add column intro_music_url text;

comment on column stories.intro_panels is
  'Panneaux de la séquence d''ouverture : [{"lines":["…","…"]}, …]. Liste vide = pas d''intro.';

comment on column stories.intro_music_url is
  'Chemin d''objet dans le bucket media, signé par get-intro. NULL = séquence muette.';
