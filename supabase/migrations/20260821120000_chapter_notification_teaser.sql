-- Contenu du déblocage de chapitre : texte de notification et teaser.
--
-- Voir docs/prompts/prompt-notifications-ecran-fin.md et docs/LOGIQUE.md
-- § L'écran de fin de chapitre. Deux champs de contenu par chapitre — jamais
-- codés en dur côté client, comme tout le reste du contenu narratif :
--
--   • notification_text : le corps de la notification locale programmée
--     quand le joueur tape « Me prévenir ». Porté par le chapitre qui
--     DÉBLOQUE (le suivant), pas celui qui vient de finir — c'est lui qu'on
--     attend.
--   • teaser_text : la phrase d'accroche courte affichée sur l'écran de fin,
--     sous le label « CHAPITRE N — titre ». Distinct de `stories.tagline`
--     (accroche de l'HISTOIRE entière, carte d'entrée) : celui-ci accroche
--     UN chapitre en particulier.
--
-- Les deux sont nullables : un chapitre sans texte de notification ne bloque
-- rien (le bouton « Me prévenir » reste inerte plutôt que d'envoyer un
-- corps vide), un chapitre sans teaser n'affiche simplement pas cette ligne.
alter table chapters add column notification_text text;
alter table chapters add column teaser_text text;

comment on column chapters.notification_text is
  'Corps de la notification locale programmée pour le déblocage de CE '
  'chapitre. Null = le bouton « Me prévenir » reste inerte, aucune '
  'notification vide.';
comment on column chapters.teaser_text is
  'Phrase d''accroche courte de CE chapitre, affichée sur l''écran de fin du '
  'chapitre précédent. Null = pas de ligne d''accroche affichée.';

-- Texte donné explicitement par Vivien dans le prompt — contenu, pas
-- improvisé. Le teaser du chapitre 2 reste à écrire (hors périmètre de ce
-- prompt) : `teaser_text` reste null pour l'instant.
update chapters
   set notification_text = 'Léna vous attend. Le chapitre 2 est disponible.'
 where position = 2
   and story_id = (select id from stories where slug = 'numero-inconnu');
