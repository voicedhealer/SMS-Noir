-- Conditions sur les messages (addendum transition N20→N9).
--
-- Jusqu'ici, un message d'un nœud était TOUJOURS délivré : seuls les choix
-- pouvaient varier selon les variables. L'ouverture du N9 a besoin d'une
-- réplique différente selon `refus` — vouvoiement gardé si le joueur a refusé
-- d'aider, tutoiement demandé sinon — et le vouvoiement/tutoiement n'est pas
-- une variable du moteur : c'est du texte écrit tel quel, sans branche
-- serveur. Sans ce mécanisme, il aurait fallu dupliquer tout le N9 (saisie
-- libre, raccrochage compris) pour une seule ligne différente.
--
-- Même format que `choices.conditions`, même évaluateur (`evaluerConditions`) :
-- aucune logique nouvelle à maintenir, juste un second endroit qui la lit.
alter table messages add column conditions jsonb not null default '{}'::jsonb;

comment on column messages.conditions is
  'Même format que choices.conditions. `{}` = toujours délivré (comportement '
  'historique). Un message dont la condition échoue est simplement absent du '
  'lot — les positions des messages suivants ne bougent pas, elles servent de '
  'repère de curseur, pas d''index de tableau.';

-- Une position peut désormais porter plusieurs variantes (une par condition),
-- ex. N9#0 : tutoiement demandé si refus=false, vouvoiement maintenu sinon.
-- L'exclusivité mutuelle des conditions à une même position n'est pas
-- vérifiable en contrainte SQL déclarative (elle dépend des valeurs runtime
-- des variables) ; elle est garantie côté contenu (generate-seed-content.py)
-- et vérifiée par scripts/verify-graph.sql, pas par le schéma.
alter table messages drop constraint messages_node_id_position_key;
