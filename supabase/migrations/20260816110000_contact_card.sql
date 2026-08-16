-- ============================================================================
-- Carte d'enregistrement de contact
--
-- Une carte discrète, posée DANS le fil : « Numéro inconnu / 06 … », avec deux
-- gestes — enregistrer, ou plus tard. C'est le geste qui révèle l'identité, à
-- la place de l'effect automatique.
--
-- Le motif est générique parce qu'il resservira :
--   • Léna   (ch. 1) — elle se nomme, on propose de l'enregistrer
--   • Karim  (ch. 3) — même carte, même anodine
--   • Le suspect (ch. 4) — la MÊME carte anodine devient inquiétante, parce que
--     personne ne lui a donné ce numéro. C'est sa banalité qui fera l'effet :
--     surtout ne rien lui ajouter de spécial.
--
-- Filet de sécurité : si le joueur n'enregistre jamais, la révélation se fait
-- quand même à la fin du chapitre. Un geste facultatif ne doit jamais bloquer
-- l'histoire.
-- ============================================================================

alter table messages drop constraint messages_content_type_check;
alter table messages add constraint messages_content_type_check
  check (content_type in ('text', 'image', 'audio', 'system', 'separator', 'contact_card'));

-- Une carte ne porte ni corps ni média : le contact suffit à la construire.
alter table messages drop constraint text_needs_body;
alter table messages add constraint text_needs_body
  check (content_type not in ('text', 'system', 'separator') or body is not null);

alter table player_messages drop constraint player_messages_content_type_check;
alter table player_messages add constraint player_messages_content_type_check
  check (content_type in ('text', 'image', 'audio', 'system', 'separator', 'contact_card'));

-- Le numéro affiché sur la carte.
alter table contacts add column phone_number text;

comment on column contacts.phone_number is
  'Numéro affiché sur la carte d''enregistrement. Plage ARCEP réservée à la fiction '
  '(06 39 98 xx xx) : jamais un numéro réel, qui appartiendrait à quelqu''un.';
