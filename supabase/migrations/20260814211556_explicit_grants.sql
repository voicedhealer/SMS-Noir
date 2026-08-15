-- ============================================================================
-- Privilèges explicites sur les tables
--
-- Pourquoi cette migration existe : les privilèges par défaut du rôle
-- `postgres` n'accordent aux rôles API (`anon`, `authenticated`,
-- `service_role`) que DELETE/TRUNCATE/REFERENCES/TRIGGER — pas SELECT, pas
-- INSERT, pas UPDATE. Les tables créées par nos migrations étaient donc
-- illisibles même en `service_role` (erreur 42501), y compris par les Edge
-- Functions. Constaté au passage de la CLI 2.75 à 2.114.
--
-- On ne dépend plus des privilèges ambiants : le schéma déclare lui-même qui a
-- le droit de quoi. C'est aussi ce qui rendra le déploiement distant
-- reproductible.
--
-- Le modèle est PLUS restrictif que le défaut Supabase (qui accorde tout et
-- s'en remet à la RLS seule) : ici les tables de contenu narratif n'ont
-- **ni GRANT ni policy** pour le client. Deux verrous au lieu d'un.
-- ============================================================================

-- Le moteur. Il contourne la RLS et écrit tout : c'est lui qui applique les
-- règles. Aucune de ces clés ne quitte le serveur.
grant all on all tables    in schema public to service_role;
grant all on all sequences in schema public to service_role;  -- player_messages.seq

-- Le client authentifié. Lecture seule, et uniquement sur les tables qui
-- portent une policy — la RLS filtre ensuite ligne à ligne.
--   • stories         : la vitrine (histoires publiées uniquement)
--   • player_progress : sa progression
--   • player_messages : ses messages
--   • ai_usage        : son quota
grant select on stories, player_progress, player_messages, ai_usage to authenticated;

-- Les tables de contenu (contacts, chapters, nodes, messages, choices) ne sont
-- volontairement PAS listées : aucun GRANT pour `authenticated`, en plus de
-- l'absence de policy. Le contenu narratif ne transite que par get-state.

-- `anon` n'a besoin de rien : l'app s'authentifie toujours, même anonymement
-- (une session anonyme est une session `authenticated`).

-- Ce qui sera créé plus tard hérite du même modèle.
alter default privileges in schema public
  grant all on tables to service_role;
alter default privileges in schema public
  grant all on sequences to service_role;
