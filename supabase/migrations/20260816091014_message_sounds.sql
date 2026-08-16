-- ============================================================================
-- Sons de message, par histoire
--
-- Deux effets très courts : réception d'un message de Léna, envoi d'une réponse
-- du joueur. Paramétrables comme la musique d'intronisation — ce sont des
-- éléments d'ambiance propres à une histoire, pas des constantes de l'app.
--
-- La base dit seulement QUOI jouer ; le client décide QUAND. Les quatre cas où
-- le son est interdit — typing fantôme, silence du N19, messages décoratifs,
-- historique restitué — sont des règles de mise en scène : voir
-- docs/DESIGN.md § Sons de message.
-- ============================================================================

alter table stories
  add column sound_received_url text,
  add column sound_sent_url text;

comment on column stories.sound_received_url is
  'Chemin d''objet du son de réception, signé à la volée. NULL = silencieux.';
comment on column stories.sound_sent_url is
  'Chemin d''objet du son d''envoi, signé à la volée. NULL = silencieux.';
