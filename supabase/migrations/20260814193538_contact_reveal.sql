-- ============================================================================
-- Révélation d'identité d'un contact
--
-- Problème : au chapitre 1, Léna n'est qu'un numéro inconnu. Afficher « Léna »
-- dans la liste de conversations dès le premier message trahit le titre même de
-- l'histoire avant la première seconde de jeu.
--
-- Mécanisme généralisé, car il resservira :
--   • Léna    — ch. 1, se nomme au N5 / N7           -> révélée en cours de chapitre
--   • Karim   — ch. 3, arrive aussi en numéro inconnu -> révélé plus tard
--   • Suspect — ch. 4, JAMAIS révélé                  -> reste anonyme jusqu'au bout
--
-- Deux moitiés :
--   1. contacts.display_name_initial — le nom AVANT révélation (ici)
--   2. l'effect `reveal_contact` posé sur le nœud de révélation, appliqué par le
--      moteur dans player_progress.variables.contacts_reveles (voir LOGIQUE.md)
--
-- L'état de révélation est par joueur : deux joueurs sur des branches différentes
-- n'en sont pas au même point. Il vit donc dans variables, pas dans le contenu.
-- ============================================================================

alter table contacts add column display_name_initial text;

comment on column contacts.display_name_initial is
  'Nom affiché tant que le contact n''est pas révélé (ex. « Numéro inconnu »). '
  'NULL = contact connu dès le départ. La révélation est portée par l''effect '
  'reveal_contact d''un nœud, et mémorisée dans player_progress.variables.contacts_reveles.';

comment on column contacts.display_name is
  'Nom réel, affiché une fois le contact révélé. Pour un contact jamais révélé '
  '(le suspect, ch. 4), il n''est simplement la cible d''aucun effect reveal_contact.';
