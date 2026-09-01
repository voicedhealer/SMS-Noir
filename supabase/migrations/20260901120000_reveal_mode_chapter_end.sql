-- Le rythme de la révélation de fin de chapitre : minuté, ou mené par le joueur.
--
-- Test utilisateur (1er septembre 2026) : l'écran de fin enchaînait trop vite
-- après le dernier message, et ses trois phrases tombaient sur un minuteur fixe
-- de 1,4 s codé dans le widget. Un rythme fixe ne peut pas convenir à tout le
-- monde — et cet écran est justement celui qu'on veut laisser absorber.
--
-- ⚠️ **Ce champ ne concerne QUE les nœuds `chapter_end`.** Il ne s'applique pas
-- aux écrans noirs narratifs (`content_type = 'narration'`, N14/N19), et il ne
-- doit pas devenir un réglage générique de « tout écran plein écran ». Les deux
-- mécaniques sont opposées, et elles coexistent :
--
--   • une **narration** est minutée PAR LE CONTENU — les décalages de chaque
--     ligne vivent dans le `body`, la durée de l'écran est le `delay_seconds`
--     du message suivant, et le générateur calcule le dernier repère pour que
--     la dernière lettre tombe pile. C'est le contrôle 62 de verify-graph, et
--     il continue de s'appliquer à tous les écrans narration à venir ;
--   • un **chapter_end** livre une révélation à absorber. Il n'a pas de
--     synchronisation à tenir : c'est le joueur qui avance, phrase par phrase.
--
-- D'où un champ sur le NŒUD plutôt qu'une colonne générique : le mode de
-- timing appartient au type d'objet qui le porte. Décision de Vivien.
--
-- `null` = `user_paced`, le défaut de ce genre de nœud — c'est sa fonction même
-- que de laisser lire. Un futur `chapter_end` qui voudrait un minuteur le
-- déclare explicitement.
alter table nodes add column if not exists reveal_mode text
  check (reveal_mode is null or reveal_mode in ('timed', 'user_paced'));

comment on column nodes.reveal_mode is
  'chapter_end seulement : ''user_paced'' (défaut, null compris) laisse le '
  'joueur avancer phrase par phrase ; ''timed'' rétablirait un minuteur. Sans '
  'effet sur les écrans narration, minutés par le contenu (voir contrôle 62).';
