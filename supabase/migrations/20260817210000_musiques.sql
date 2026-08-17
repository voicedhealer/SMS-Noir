-- Les deux autres segments musicaux (addendum V3.2 §4).
--
-- Un même morceau découpé en trois : l'intro (15 s), l'écran noir du N19 (60 s),
-- l'écran de fin (60 s). Les fichiers sont découpés EN AMONT plutôt que joués à
-- partir d'un offset : les durées d'écran peuvent bouger, un offset calculé
-- dériverait en silence.
--
-- Les deux premiers sont coupés net par le retour à la conversation ; seul
-- celui de la fin joue jusqu'au bout et culmine.
alter table stories
  add column narration_music_url text,
  add column chapter_end_music_url text;

comment on column stories.narration_music_url is
  'Segment 2 — écran noir du N19. Coupure nette au retour de Léna : le fichier '
  'doit durer EXACTEMENT le silence (60 s), sinon la reprise du segment 3 saute.';
comment on column stories.chapter_end_music_url is
  'Segment 3 — écran de fin. Le seul qui joue jusqu''au bout et qui culmine.';
