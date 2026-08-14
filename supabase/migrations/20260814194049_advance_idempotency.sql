-- ============================================================================
-- Idempotence de `advance`
--
-- Cas visé : le client envoie advance(choix_X), la réponse se perd (réseau),
-- il rejoue. Sans trace, le second appel est rejeté — le choix n'appartient
-- plus au nœud courant, qui a avancé — et le joueur voit une erreur alors que
-- son coup est passé.
--
-- On mémorise le dernier choix appliqué et le `seq` du premier message qu'il a
-- produit. Un rejeu du MÊME choice_id ne réapplique rien : il renvoie à
-- l'identique les messages écrits à ce moment-là (seq >= last_choice_seq).
--
-- last_choice_seq sert aussi de curseur : il délimite ce qui a été produit par
-- le dernier coup, sans avoir à horodater (created_at vaut l'heure de début de
-- transaction, cf. écart B).
-- ============================================================================

alter table player_progress
  add column last_choice_id  uuid references choices(id),
  add column last_choice_seq bigint;

comment on column player_progress.last_choice_id is
  'Dernier choix appliqué. Un advance rejouant ce même choice_id ne réapplique aucun effect.';
comment on column player_progress.last_choice_seq is
  'seq du premier player_messages produit par ce choix — permet de rejouer la même réponse.';
