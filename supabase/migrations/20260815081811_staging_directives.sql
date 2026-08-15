-- ============================================================================
-- Directives de mise en scène pendant une attente
--
-- Certaines attentes ne sont pas du temps mort : ce sont des scènes. Au N19,
-- 90 secondes de silence pendant lesquelles Léna est peut-être en train de se
-- faire repérer. Le vide EST le contenu — mais un vide uniforme s'en prive.
-- Deux battements le rendent cruel : un faux « en train d'écrire » qui s'éteint
-- sans message, et une vibration.
--
-- Le serveur n'a pas de notion de « faux typing » : ces colonnes la lui donnent,
-- de façon explicite et vérifiable, plutôt que par une heuristique cliente qui
-- s'appliquerait à toutes les longues attentes et diluerait l'effet.
--
-- SÉMANTIQUE — à ne pas se tromper au chapitre 3 :
--   Les deux valeurs sont des **offsets en secondes depuis le DÉBUT du délai du
--   message qui les porte**, pas depuis le début du nœud ni depuis la fin.
--   Elles doivent donc rester < delay_seconds de ce message.
--
--   Exemple, le grand silence du chapitre 1 : il est porté par le séparateur
--   « 00h34 » (N20#0, delay_seconds = 90). phantom_typing_at = 45 place le faux
--   typing à 45 s dans ces 90 s ; haptic_at = 60 place la vibration à 60 s.
--
--   Le faux typing dure 2 secondes puis s'éteint sans qu'aucun message n'arrive.
--   Cette durée est une constante du client, pas une donnée de contenu.
-- ============================================================================

alter table messages
  add column phantom_typing_at int check (phantom_typing_at is null or phantom_typing_at >= 0),
  add column haptic_at         int check (haptic_at is null or haptic_at >= 0);

-- Un battement placé au-delà de l'attente ne se produirait jamais : autant le
-- refuser à l'écriture plutôt que de le chercher plus tard.
alter table messages
  add constraint battements_dans_l_attente check (
    (phantom_typing_at is null or phantom_typing_at < delay_seconds)
    and (haptic_at is null or haptic_at < delay_seconds)
  );

comment on column messages.phantom_typing_at is
  'Offset en secondes depuis le début du délai de CE message : instant où un faux '
  '« en train d''écrire » apparaît, dure 2 s, puis s''éteint sans qu''aucun message n''arrive.';

comment on column messages.haptic_at is
  'Offset en secondes depuis le début du délai de CE message : vibration discrète unique, '
  'sans notification.';
