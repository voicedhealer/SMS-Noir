-- L'aparté : ligne de contexte discrète, générique — pas un détail du N9.
--
-- Voir docs/DESIGN.md § L'aparté et docs/LOGIQUE.md § L'aparté pour le
-- mécanisme complet. En bref : un nœud peut porter un texte bref affiché dans
-- le flux de la conversation (sous la dernière bulle, avant la zone de choix)
-- quand ce nœud attend une action du joueur — signaler un silence volontaire,
-- un changement de contexte mineur, ou ici, cadrer l'attente d'une vraie
-- réponse au moment IA. Jamais un indice, jamais une consigne.
--
-- Piloté par le contenu, comme `messages.body` pour la narration de l'écran
-- noir — pas codé en dur pour un nœud en particulier. Nul = rien à afficher,
-- le comportement d'aujourd'hui pour tous les nœuds sauf le N9.
alter table nodes add column aparte text;

comment on column nodes.aparte is
  'Ligne de contexte discrète (gris, centrée, sous la dernière bulle) affichée '
  'quand ce nœud attend une action du joueur (ni déroulé, ni typing en cours). '
  'Générique : réutilisable par tout nœud futur, pas réservé aux ai_moment. '
  'Null = rien à afficher.';
