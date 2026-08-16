-- ============================================================================
-- Moment IA : décompte, consentement, coûts
-- ============================================================================

-- Où en est-on DANS ce moment IA. `ai_usage` compte par jour, pour le quota ;
-- rien ne mémorisait la position dans l'échange en cours. Sans ça, un joueur
-- qui ferme l'app au 3e échange repart de zéro — et peut tourner indéfiniment.
-- Remis à zéro à l'entrée du nœud, tenu par le SERVEUR : jamais par le modèle,
-- jamais par le client.
alter table player_progress
  add column ai_exchanges int not null default 0 check (ai_exchanges >= 0);

-- Consentement RGPD (bible §9). En base, pas en local : il doit être auditable
-- et suivre la cascade de suppression du compte. Un indicateur local ne prouve
-- rien et disparaîtrait sans trace.
alter table player_progress
  add column ai_consent_at timestamptz,
  add column ai_consent_refuse boolean not null default false;

comment on column player_progress.ai_consent_at is
  'Horodatage du consentement au traitement IA. NULL = jamais donné.';
comment on column player_progress.ai_consent_refuse is
  'Le joueur a refusé. On ne redemande pas, et l''histoire continue par le fallback.';

-- Coût réel par joueur : cumulé par jour, pour pouvoir chiffrer avant d'ouvrir
-- les vannes.
alter table ai_usage
  add column tokens_in bigint not null default 0,
  add column tokens_out bigint not null default 0;
