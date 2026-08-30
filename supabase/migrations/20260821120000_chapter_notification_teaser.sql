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
-- `if not exists` : la migration de CONTENU déclare elle aussi ces deux
-- colonnes, en préambule, parce qu'elle y écrit alors qu'elle est datée
-- AVANT celle-ci. Sans ça, un `db reset` depuis zéro échouait ici sur
-- « column already exists ». Voir le préambule de
-- 20260818174043_contenu_chapitre_1.sql.
alter table chapters add column if not exists notification_text text;
alter table chapters add column if not exists teaser_text text;

comment on column chapters.notification_text is
  'Corps de la notification locale programmée pour le déblocage de CE '
  'chapitre. Null = le bouton « Me prévenir » reste inerte, aucune '
  'notification vide.';
comment on column chapters.teaser_text is
  'Phrase d''accroche courte de CE chapitre, affichée sur l''écran de fin du '
  'chapitre précédent. Null = pas de ligne d''accroche affichée.';

-- ⚠️ **Le texte a déménagé dans la migration de contenu**, où il aurait dû
-- naître : c'est une phrase que le joueur LIT, donc du contenu, et il vit
-- maintenant dans l'`insert into chapters` du chapitre 2.
--
-- Il était posé ici par un `update`, et la migration de contenu — datée avant
-- celle-ci — fait `delete from chapters` puis les recrée. Rejouer le contenu
-- seul, le geste quotidien après une régénération, effaçait donc le texte sans
-- rien dire : le bouton « Me prévenir » de l'écran de fin devenait inerte,
-- sans erreur nulle part. C'est `simulate-playthrough.py` qui l'attrapait,
-- après coup.
--
-- Le `update` n'est pas conservé « au cas où » : deux endroits qui posent la
-- même phrase, c'est exactement la dérive qu'on évite ailleurs. La colonne
-- reste ici, sa valeur est du contenu.
--
-- Le teaser du chapitre 2 reste à écrire (hors périmètre de ce prompt) :
-- `teaser_text` reste null pour l'instant.
