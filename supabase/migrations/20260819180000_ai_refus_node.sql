-- Le refus de consentement à un moment IA : un équivalent scripté, pas un
-- raccrochage silencieux.
--
-- Voir docs/LOGIQUE.md § Le refus de consentement à un moment IA pour le
-- mécanisme complet. En bref : un `ai_moment` peut désigner un nœud scripté
-- de repli, joué à la place de la saisie libre quand le joueur a explicitement
-- refusé le consentement IA (`player_progress.ai_consent_refuse`) — jamais en
-- cas de panne technique (clé absente, API en erreur, quota, hors cadre), qui
-- gardent le raccrochage silencieux existant vers `ai_fallback_node_id`.
--
-- Générique et réutilisable : n'importe quel `ai_moment`, dans n'importe quel
-- chapitre, peut en désigner un. Null = pas encore d'équivalent scripté pour
-- ce nœud, comportement inchangé (raccrochage direct vers `ai_fallback_node_id`,
-- comme n'importe quelle autre sortie de cadre).
alter table nodes add column ai_refus_node_id uuid references nodes(id);

comment on column nodes.ai_refus_node_id is
  'Nœud scripté joué à la place de la saisie libre quand le consentement IA a '
  'été explicitement refusé (ai_consent_refuse) — jamais pour une panne '
  'technique, qui reste couverte par ai_fallback_node_id. Générique, '
  'réutilisable par tout ai_moment futur. Null = pas d''équivalent scripté, '
  'raccrochage direct inchangé.';
