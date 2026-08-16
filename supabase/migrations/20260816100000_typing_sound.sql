-- ============================================================================
-- Son de frappe
--
-- Joué au démarrage de l'indicateur « en train d'écrire… », en plus des sons
-- de réception et d'envoi.
--
-- ⚠️ Uniquement sur le typing RÉEL. Le typing fantôme du N19 reste muet : un
-- son laisserait croire qu'un message arrive, et son extinction sans message
-- perdrait tout son sens. La distinction est côté client, qui seul sait
-- lequel des deux il joue — voir docs/DESIGN.md § Sons de message.
-- ============================================================================

alter table stories add column sound_typing_url text;

comment on column stories.sound_typing_url is
  'Chemin d''objet du son de frappe, signé à la volée. NULL = silencieux. '
  'Jamais joué sur le typing fantôme.';
