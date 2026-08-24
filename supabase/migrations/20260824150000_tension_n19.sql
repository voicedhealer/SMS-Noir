-- Effet de tension du N19 : bordure rouge sur les bulles + battement de cœur.
--
-- Deux colonnes de CONTENU sur `messages`, et une de persistance sur
-- `player_messages`.
--
-- Pourquoi un drapeau PAR MESSAGE et non par nœud : le client ne connaît pas
-- le graphe — `ClientMessage` ne porte aucune référence au nœud, par
-- construction. Une bulle ne peut donc pas savoir qu'elle appartient au N19.
-- Le contrat porte en revanche déjà des directives de mise en scène par
-- message (`phantom_typing_at`, `haptic_at`) : `tension` rejoint cette
-- famille, sans jamais exposer la structure narrative.
--
-- `ambience_sound_url` vit sur le message et NON sur le nœud, à dessein : le
-- son doit démarrer au premier message porteur de tension, or à cet instant le
-- nœud exposé au client peut encore être le précédent. Le poser sur le nœud
-- puis le recopier sur le message créerait deux sources de vérité à garder
-- synchronisées. Décision de Vivien, 24 août 2026.
alter table messages
  add column if not exists tension boolean not null default false,
  add column if not exists ambience_sound_url text;

comment on column messages.tension is
  'Renforcement sensoriel de ce message (bordure rouge). Directive de mise en '
  'scène, même famille que phantom_typing_at — jamais une info de graphe.';
comment on column messages.ambience_sound_url is
  'Son d''ambiance en boucle, démarré à la livraison de CE message et coupé au '
  'premier message sans tension. Renseigné sur le message DÉCLENCHEUR seul.';

-- `player_messages` ne persiste ni les délais ni les autres directives : elles
-- n'ont aucun sens sur un message déjà lu. `tension`, si — les bulles du N19
-- doivent rester rouges quand le joueur remonte le fil plus tard, « c'est
-- cohérent avec ce qui s'est vraiment passé à ce moment de l'histoire »
-- (Vivien). C'est la seule directive de mise en scène qui survit à sa
-- livraison, et c'est voulu.
alter table player_messages
  add column if not exists tension boolean not null default false;

comment on column player_messages.tension is
  'Copie persistée de messages.tension : seule directive de mise en scène qui '
  'survit à la livraison, pour que la relecture du fil garde l''effet.';
