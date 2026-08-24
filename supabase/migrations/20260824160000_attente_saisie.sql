-- « Et vous ? » — quand une question du dialogue attend une vraie réponse écrite.
--
-- Léna demande déjà, au N16 : « Oui, mais je n'arrive pas à le lire d'ici, et
-- vous ? » La question existait dans le contenu sans aucune suite : le champ de
-- saisie était en mode `continuation`, donc y écrire faisait AVANCER le nœud —
-- le joueur sautait au N19 en croyant avoir répondu, et perdait l'indice
-- AUTOCOLLANT sans jamais le savoir. Constaté le 24 août 2026.
--
-- Un seul concept, une seule colonne : « ce nœud attend une réponse écrite ».
--   null            → il n'en attend pas (cas de tous les nœuds sauf N16)
--   { conditions, reponse }
--     conditions : quand l'attente est active. `{}` = dès l'entrée dans le
--                  nœud. Au N16 elle ne l'est qu'après le micro-choix 🔍 —
--                  sur 🛡 ou 🧠 Léna ne pose jamais la question, et le zoom
--                  reste la seule voie vers l'indice.
--     reponse    : ce que Léna répond à la tentative, quelle qu'elle soit.
--
-- **Le contenu de la réponse n'est JAMAIS validé.** « Sentinel Pro », une
-- faute de frappe, une devinette fausse ou « je sais pas » déclenchent
-- identiquement l'interaction disponible du nœud. Ce qui compte narrativement
-- est le geste de répondre à Léna comme à un interlocuteur, pas l'exactitude —
-- et valider du texte libre côté serveur est précisément ce qu'on s'est
-- toujours interdit pour ce champ.
alter table nodes add column if not exists attente_saisie jsonb;

comment on column nodes.attente_saisie is
  'Le nœud attend une réponse écrite : {conditions, reponse}. null = non. '
  'Gate aussi l''affichage de nodes.aparte quand elle est renseignée.';
