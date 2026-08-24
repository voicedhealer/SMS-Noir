-- Le carnet de notes narratif — « Ce qu'on sait ».
--
-- Les indices EXISTAIENT déjà : `player_progress.variables.indices` est une
-- liste de codes, alimentée par les `effects.append` du contenu. Ce qui
-- manquait, c'est leur texte : trouver un indice caché ne laissait aucune
-- trace lisible pour le joueur, ce qui n'encourage pas à chercher.
--
-- Cette table ne porte donc AUCUNE logique de jeu. C'est du contenu narratif,
-- au même titre qu'une réplique : un code, et ce qu'on en écrit dans le carnet.
create table if not exists clues (
  id       uuid primary key default gen_random_uuid(),
  story_id uuid not null references stories(id) on delete cascade,
  code     text not null,
  texte    text not null,
  unique (story_id, code)
);

comment on table clues is
  'Texte narratif des indices. La liste de ceux TROUVÉS vit dans '
  'player_progress.variables.indices — jamais ici.';

-- Même régime que tout le contenu : RLS activé, aucune policy select.
-- Le client ne lit jamais cette table directement ; `get-state` lui renvoie
-- une projection filtrée aux seuls indices déjà trouvés. Lui ouvrir la table
-- reviendrait à lui livrer la liste des indices qu'il n'a pas encore, c'est-à-
-- dire la carte de ce qu'il reste à chercher.
alter table clues enable row level security;

-- Chapitre 1. Ton volontairement bref et factuel — une note prise vite, pas
-- une fiche encyclopédique.
insert into clues (story_id, code, texte)
select s.id, v.code, v.texte
from (values
  ('PROFIL_SUSPECT',
   'Un homme, la cinquantaine. Toujours seul, toujours le jeudi. Il regarde autour de lui avant d''entrer.'),
  ('BORNAGE',
   'Le dernier signal du téléphone de Chloé a borné à 400 mètres de l''entrepôt Verdier.'),
  ('AUTOCOLLANT',
   'Un macaron sur la vitre arrière de sa voiture : Sentinel Pro.'),
  ('PLAQUE',
   'Une Peugeot 508 grise. Plaque partielle : ...843...'),
  ('TELEPHONE',
   'Un téléphone à coque rose, abandonné sur un établi. Chloé avait exactement le même.')
) as v(code, texte)
join stories s on s.slug = 'numero-inconnu'
on conflict (story_id, code) do update set texte = excluded.texte;
