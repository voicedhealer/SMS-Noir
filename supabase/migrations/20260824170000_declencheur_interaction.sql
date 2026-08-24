-- Comment se déclenche une interaction cachée : par un GESTE sur un média, ou
-- par une CHOSE QUE LE JOUEUR DIT.
--
-- La règle existait (DESIGN.md § Les interactions cachées) mais n'était écrite
-- nulle part : le client la DEVINAIT, en regardant si le nœud courant avait
-- apporté un média. Deux défauts, tous deux visibles en jouant :
--
--  1. **L'inférence bascule dans le temps.** Elle regardait ce qui SUIT le
--     dernier média dans le fil ; dès que le joueur répondait à un micro-choix,
--     son propre message s'y intercalait et le nœud cessait de « porter un
--     média ». Au N16, le « + » apparaissait alors en proposant « Zoomer sur
--     l'autocollant » en clair — un bouton pour un geste, et l'indice annoncé
--     dans son libellé.
--  2. **Elle raisonne par nœud, or le N8 est mixte** : il porte le zoom du
--     récépissé ET deux relances textuelles. Les trois recevaient le même
--     traitement, quel qu'il fût.
--
-- Le contenu le déclare donc maintenant, et le client n'a plus rien à déduire.
--   'geste' : zoom sur une photo, réécoute d'un vocal
--   'texte' : une relance, une insistance — ce que le joueur DIT
alter table choices add column if not exists declencheur text
  check (declencheur is null or declencheur in ('geste', 'texte'));

comment on column choices.declencheur is
  'Interactions seules : ''geste'' (sur le média) ou ''texte'' (le joueur le '
  'dit). Null pour tout autre kind. Le client ne le devine plus.';
