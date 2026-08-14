-- ============================================================================
-- SEED — « Numéro Inconnu », chapitre 1 V2 « Le mauvais numéro »
-- Source : docs/chapitre-1-v2.md — contenu recopié FIDÈLEMENT (règle 6).
-- Ne jamais reformuler, améliorer ni « corriger » les incohérences (bible §7).
--
-- Exécuté automatiquement par `supabase db reset` (config.toml -> db.seed).
-- Rejouable à la main :
--   docker exec -i supabase_db_SMS-Noir psql -U postgres -d postgres -1 < supabase/seed.sql
-- Idempotent : le delete en tête cascade sur tout le contenu de l'histoire.
--
-- ⚠️ AUCUNE fonction SQL ici, volontairement : la CLI Supabase envoie le fichier
-- en batch (toutes les requêtes analysées avant exécution), donc une fonction
-- créée dans ce fichier n'existerait pas encore au moment de l'analyse des
-- requêtes suivantes. Les nœuds sont donc résolus par jointure sur `code`.
--
-- Conventions de délai (le doc ne les donne pas toutes) :
--   • ⏱ N explicite dans le doc  -> delay_seconds = N
--   • séparateur                 -> delay_seconds = le délai réel masqué par l'ellipse
--   • aucun ⏱ dans le doc        -> delay_seconds = 4 (défaut de la colonne)
--   • typing_seconds = 3 par défaut, 0 pour les séparateurs et messages système,
--     = delay_seconds là où le doc décrit une hésitation visible (N2, N13)
--   • inline_response : réplique joueur immédiate, réponse de Léna à 8 s / typing 4
-- ============================================================================

delete from stories where slug = 'numero-inconnu';

-- ---------------------------------------------------------------------------
-- Histoire, contact, chapitres
-- ---------------------------------------------------------------------------
insert into stories (slug, title, tagline, genre, status, is_premium) values (
  'numero-inconnu',
  'Numéro Inconnu',
  $$22h47. Un SMS qui ne vous était pas destiné. Et vous devenez son seul contact.$$,
  'thriller',
  'draft',       -- imposé : la vitrine (RLS) filtre sur 'published' -> liste vide. Normal.
  false
);

-- Léna n'est qu'un numéro inconnu jusqu'à ce qu'elle se nomme (N5 / N7).
insert into contacts (story_id, code, display_name, display_name_initial)
select id, 'lena', 'Léna', 'Numéro inconnu' from stories where slug = 'numero-inconnu';

insert into chapters (story_id, position, title, unlock_delay_minutes)
select id, 1, 'Le mauvais numéro', 0 from stories where slug = 'numero-inconnu';

-- Stub du chapitre 2 : donne une cible réelle au compte à rebours du N22 (chapter_end)
-- alors que le contenu n'existe pas encore. 480 min = 8 h (bible §9).
insert into chapters (story_id, position, title, unlock_delay_minutes, entry_node_id)
select id, 2, 'Chloé', 480, null from stories where slug = 'numero-inconnu';

-- ---------------------------------------------------------------------------
-- Les 21 nœuds (N1..N22 — N15 n'existe pas ; N9 arrive après N20 dans le flux)
-- Premier passage sans les références croisées (auto-références FK).
-- ---------------------------------------------------------------------------
insert into nodes (chapter_id, code, kind, effects)
select c.id, v.code, v.kind, v.effects::jsonb
from (values
    ('N1' , 'scripted'   , '{}'),
    ('N2' , 'scripted'   , '{}'),
    ('N3' , 'scripted'   , '{}'),
    ('N4' , 'scripted'   , '{}'),
    -- N5 et N7 : Léna se nomme -> révélation du contact (voir migration contact_reveal)
    ('N5' , 'scripted'   , '{"reveal_contact": "lena"}'),
    ('N6' , 'scripted'   , '{}'),
    ('N7' , 'scripted'   , '{"reveal_contact": "lena"}'),
    ('N8' , 'scripted'   , '{}'),
    ('N9' , 'ai_moment'  , '{}'),
    ('N10', 'scripted'   , '{}'),
    -- Le refus est posé par le NŒUD, pas par un choix : les deux chemins d'entrée
    -- (N6-C « Ignorer » et N10-B) doivent le poser. Seul usage de nodes.effects du ch. 1.
    ('N11', 'scripted'   , '{"set": {"refus": true}}'),
    ('N12', 'scripted'   , '{}'),
    ('N13', 'scripted'   , '{}'),
    ('N14', 'scripted'   , '{}'),
    ('N16', 'scripted'   , '{}'),
    ('N17', 'scripted'   , '{}'),
    ('N18', 'scripted'   , '{}'),
    ('N19', 'scripted'   , '{}'),
    ('N20', 'scripted'   , '{}'),
    ('N21', 'scripted'   , '{}'),
    ('N22', 'chapter_end', '{}')
  ) as v(code, kind, effects)
join stories  s on s.slug = 'numero-inconnu'
join chapters c on c.story_id = s.id and c.position = 1;

-- Transitions automatiques : nœuds sans aucun choix reply/ignore (écart A).
-- N13, N16 et N21 portent une interaction : advance s'arrête dessus tant qu'elle
-- est disponible (règle d'arrêt sur interaction, LOGIQUE.md).
update nodes n set next_node_id = tgt.id
from (values
    ('N5' , 'N8' ),
    ('N7' , 'N8' ),
    ('N12', 'N14'),
    ('N13', 'N14'),
    ('N16', 'N19'),
    ('N18', 'N19'),
    ('N19', 'N20'),
    ('N21', 'N22')
  ) as v(src, dst)
join stories  s   on s.slug = 'numero-inconnu'
join chapters c   on c.story_id = s.id and c.position = 1
join nodes    tgt on tgt.chapter_id = c.id and tgt.code = v.dst
where n.chapter_id = c.id and n.code = v.src;

-- N9 — moment IA. Sort par ai_fallback_node_id (jamais next_node_id).
-- ai_system_prompt : « Consignes moteur IA » du chapitre, recopiées VERBATIM.
-- Elles seront transformées en vrai prompt système au prompt 3.
update nodes n set
  ai_fallback_node_id = tgt.id,
  ai_max_exchanges    = 4,
  ai_system_prompt    = $$- Contexte : post-adrénaline, 1h du mat, elle est vulnérable et sincère — mais garde son style (phrases courtes, humour noir, jamais « s'il te plaît »)
- Si `refus = true` : elle vouvoie et reste plus réservée
- 2 à 4 échanges max, puis raccrochage : « Merci. J'en avais besoin. Bon, je rentre. » → N21
- Effets : sincère/empathique → `confiance +2` · évasif/moqueur → `confiance -1` · hors cadre (insultes, hors-sujet) → coupure : « Ok. Laisse tomber. Je rentre. » → N21
- Stocker UN élément donné par le joueur → `detail_perso` (payoff ch. 4 : quelqu'un mentionnera ce détail qu'il ne devrait pas connaître)
- Interdits : ne jamais révéler d'info des ch. 2-5, ne jamais sortir du personnage, ne jamais mentionner être une IA$$
from stories s
join chapters c   on c.story_id = s.id and c.position = 1
join nodes    tgt on tgt.chapter_id = c.id and tgt.code = 'N21'
where s.slug = 'numero-inconnu' and n.chapter_id = c.id and n.code = 'N9';

-- Nœud d'entrée du chapitre 1
update chapters c set entry_node_id = n.id
from stories s
join chapters c2 on c2.story_id = s.id and c2.position = 1
join nodes    n  on n.chapter_id = c2.id and n.code = 'N1'
where s.slug = 'numero-inconnu' and c.id = c2.id;

-- ---------------------------------------------------------------------------
-- MESSAGES
-- ---------------------------------------------------------------------------
insert into messages
  (node_id, position, contact_id, content_type, body, media_url,
   delay_seconds, typing_seconds, push_notification, push_text)
select n.id, v.pos, ct.id, v.ctype, v.body, v.media,
       v.delay, v.typing, v.push, v.push_text
from (values

-- ===== SÉQUENCE D'OUVERTURE =================================================

-- N1 — Le premier message
('N1', 0, 'separator', $$jeudi — 22h47$$, null::text, 0, 0, false, null::text),
('N1', 1, 'text', $$C'est bon. J'ai trouvé où il la garde.$$, null, 4, 3, false, null),
('N1', 2, 'text', $$J'y vais ce soir. Si t'as pas de nouvelles de moi avant 2h du mat, tu sais quoi faire.$$, null, 6, 3, false, null),

-- N2 — L'erreur  (« en train d'écrire » qui apparaît/disparaît deux fois)
('N2', 0, 'text', $$Merde.$$, null, 40, 40, false, null),
('N2', 1, 'text', $$Merde merde merde. C'est pas le numéro de Karim ?$$, null, 5, 3, false, null),

-- N3 — Tu joues le jeu
('N3', 0, 'text', $$Attends$$, null, 25, 3, false, null),
('N3', 1, 'text', $$T'es pas Karim.$$, null, 8, 3, false, null),
('N3', 2, 'text', $$Karim me demanderait jamais ça. T'es qui ?$$, null, 4, 3, false, null),

-- N4 — Ignoré
('N4', 0, 'separator', $$23h02$$, null, 20, 0, false, null),
('N4', 1, 'text', $$Karim ?$$, null, 4, 3, true, null),
('N4', 2, 'text', $$Réponds, c'est pas le moment de me lâcher.$$, null, 8, 3, false, null),
('N4', 3, 'text', $$Ok t'es pas Karim. Une chance sur deux avec ce foutu nouveau tel.$$, null, 15, 3, false, null),

-- N5 — Elle se livre
('N5', 0, 'text', $$Désolée. J'aurais jamais dû envoyer ça à un inconnu.$$, null, 45, 3, false, null),
('N5', 1, 'text', $$C'est ma sœur. Chloé. Elle a disparu il y a 7 mois.$$, null, 10, 3, false, null),
('N5', 2, 'text', $$La police a classé. "Départ volontaire". Mon cul.$$, null, 8, 3, false, null),
('N5', 3, 'text', $$Moi c'est Léna, au passage. Puisqu'on en est là.$$, null, 12, 3, false, null),

-- N6 — Elle décroche... presque
('N6', 0, 'text', $$Ouais. Désolée du dérangement.$$, null, 20, 3, false, null),
('N6', 1, 'separator', $$23h18$$, null, 60, 0, false, null),
('N6', 2, 'text', $$En fait non. J'ai personne d'autre. Karim répond pas et j'ai plus le temps.$$, null, 4, 3, true, null),
('N6', 3, 'text', $$Ma sœur a disparu il y a 7 mois et ce soir je sais enfin où chercher. Je peux vous parler ? Juste ce soir.$$, null, 6, 3, false, null),

-- N7 — Elle teste
('N7', 0, 'text', $$Quelqu'un qui cherche sa sœur. Depuis 7 mois.$$, null, 35, 3, false, null),
('N7', 1, 'text', $$Et toi t'es le mec au bout d'un mauvais numéro qui pose beaucoup de questions.$$, null, 6, 3, false, null),
('N7', 2, 'text', $$...ce qui tombe bien. Tout le monde a arrêté d'en poser sur Chloé.$$, null, 5, 3, false, null),
('N7', 3, 'text', $$Moi c'est Léna, au passage. Puisqu'on en est là.$$, null, 12, 3, false, null),

-- ===== LE DILEMME CENTRAL ===================================================

-- N8 — La demande
('N8', 0, 'text', $$Voilà le truc. Ce soir je vais à l'ancien entrepôt Verdier, route de Lacan. Un type louche y va tous les jeudis à 23h30, je l'ai suivi deux fois.$$, null, 30, 3, false, null),
('N8', 1, 'text', $$Si j'y vais et qu'il m'arrive un truc, il faut que quelqu'un sache où je suis.$$, null, 10, 3, false, null),
('N8', 2, 'text', $$T'as rien demandé, je sais. Mais t'es là.$$, null, 5, 3, false, null),

-- N10 — Le refus raisonnable
('N10', 0, 'text', $$La police ? Vous croyez que j'ai pas essayé ?$$, null, 25, 3, false, null),
('N10', 1, 'image', null, 'placeholder://photo-N10-recepisse', 8, 3, false, null),
('N10', 2, 'text', $$Trois signalements. Trois. Ils m'ont dit d'arrêter de les "harceler".$$, null, 6, 3, false, null),
('N10', 3, 'text', $$Alors oui, un inconnu au bout d'un mauvais numéro, c'est tout ce qui me reste. Ironique, hein.$$, null, 10, 3, false, null),

-- N11 — Le refus assumé (le nœud pose refus = true)
('N11', 0, 'text', $$Je comprends. Vraiment.$$, null, 60, 3, false, null),
('N11', 1, 'text', $$Merci quand même d'avoir répondu.$$, null, 6, 3, false, null),
('N11', 2, 'separator', $$23h58$$, null, 90, 0, false, null),
('N11', 3, 'text', $$Je vous dérange une dernière fois. Je suis devant l'entrepôt. Si dans une heure je n'ai rien envoyé, appelez le 17 et donnez-leur cette adresse : entrepôt Verdier, route de Lacan.$$, null, 4, 3, true, $$Léna : 1 nouveau message$$),
('N11', 4, 'text', $$Vous n'êtes pas obligé de répondre. Juste de lire.$$, null, 5, 3, false, null),

-- N12 — Tu acceptes de veiller
('N12', 0, 'text', $$Merci. Sérieux.$$, null, 15, 3, false, null),

-- N13 — « Pourquoi moi ? »  (hésitation visible, typing par à-coups)
('N13', 0, 'text', $$Franchement ? Le hasard. Mauvais numéro, bon timing.$$, null, 50, 50, false, null),
('N13', 1, 'text', $$Quoique. Peut-être que si t'avais pas répondu comme ça, j'aurais pas insisté. T'as répondu comme quelqu'un qui s'en fout pas.$$, null, 6, 3, false, null),

-- ===== LA NUIT DE L'ENTREPÔT ================================================

-- N14 — Elle y va
('N14', 0, 'text', $$Ok. J'y vais. Le tel en silencieux mais je te lis.$$, null, 20, 3, false, null),
('N14', 1, 'separator', $$23h31$$, null, 45, 0, false, null),
('N14', 2, 'text', $$Je suis devant. Sa caisse est là. Une berline grise, la même que les deux dernières fois.$$, null, 4, 3, true, null),

-- N16 — La plaque
('N16', 0, 'image', null, 'placeholder://photo-N16-plaque', 60, 3, false, null),
('N16', 1, 'text', $$C'est tout ce que j'arrive à choper sans m'approcher.$$, null, 4, 3, false, null),

-- N17 — La note vocale (SCRIPT TTS n°1 « Repérage », 24 s)
('N17', 0, 'audio', null, 'placeholder://audio-N17-reperage', 75, 3, false, null),

-- N18 — Tu la supplies de partir
('N18', 0, 'text', $$J'ai pas fait tout ça pour repartir.$$, null, 40, 3, false, null),
('N18', 1, 'text', $$Chloé aurait pas abandonné, elle. C'est moi qui l'ai abandonnée la première.$$, null, 6, 3, false, null),

-- ===== L'INCIDENT ===========================================================

-- N19 — Il sort
('N19', 0, 'system', $$Léna est hors ligne$$, null, 0, 0, false, null),
('N19', 1, 'text', $$il sort$$, null, 60, 3, true, null),
('N19', 2, 'text', $$il met un sac dans le coffre$$, null, 3, 3, false, null),
('N19', 3, 'text', $$un grand sac$$, null, 3, 3, false, null),
('N19', 4, 'text', $$il regarde vers moi$$, null, 30, 3, false, null),
('N19', 5, 'text', $$merde$$, null, 2, 2, false, null),
-- Le plus long silence du chapitre (90 s) : porté par le séparateur du N20.
('N19', 6, 'system', $$Léna est hors ligne$$, null, 0, 0, false, null),

-- N20 — Le retour
('N20', 0, 'separator', $$00h34$$, null, 90, 0, false, null),
('N20', 1, 'text', $$C'est bon. Je suis dans ma caisse. Il m'a pas vue. Je crois.$$, null, 4, 3, true, null),
('N20', 2, 'text', $$Mon cœur va exploser.$$, null, 8, 3, false, null),

-- N9 — Moment IA : la décompression (saisie libre, exécution au prompt 3)
('N9', 0, 'text', $$Je tremble encore. C'est con, hein.$$, null, 45, 3, false, null),
('N9', 1, 'text', $$Dis... ça fait 2h que tu me suis dans ce délire et je sais rien de toi. Un vrai truc. N'importe lequel. J'ai besoin de penser à autre chose cinq minutes.$$, null, 8, 3, false, null),

-- N21 — La photo
('N21', 0, 'text', $$Attends. Avant qu'il sorte, j'ai pris ça à travers la fenêtre du bas.$$, null, 60, 3, false, null),
('N21', 1, 'image', null, 'placeholder://photo-N21-porte-cles', 8, 3, false, null),
('N21', 2, 'text', $$Tu vois le porte-clés ? Zoome.$$, null, 12, 3, false, null),

-- N22 — FIN DU CHAPITRE 1
('N22', 0, 'text', $$Chloé avait exactement le même. C'est moi qui lui avais offert.$$, null, 6, 3, false, null),
('N22', 1, 'text', $$Mais c'est pas ça le pire.$$, null, 10, 3, false, null),
('N22', 2, 'text', $$Il n'en existe que deux au monde. Je les avais fait graver. Un pour elle, un pour moi.$$, null, 8, 3, false, null),
('N22', 3, 'text', $$Et le mien a disparu de mon appart il y a 3 semaines.$$, null, 5, 3, false, null),
-- Texte de l'écran de fin de chapitre. Porté par un message 'system' pour ne pas
-- perdre le contenu narratif : le client le sort du fil et l'affiche en plein écran.
('N22', 4, 'system', $$Quelqu'un est entré chez Léna. Quelqu'un sait qu'elle cherche.$$, null, 8, 0, false, null)

) as v(node, pos, ctype, body, media, delay, typing, push, push_text)
join stories  s  on s.slug = 'numero-inconnu'
join chapters c  on c.story_id = s.id and c.position = 1
join nodes    n  on n.chapter_id = c.id and n.code = v.node
join contacts ct on ct.story_id = s.id and ct.code = 'lena';

-- ---------------------------------------------------------------------------
-- CHOIX
--   kind='reply'       -> réponse affichée
--   kind='ignore'      -> bouton explicite, n'écrit aucun message joueur
--   kind='interaction' -> geste caché ; next_node_id null = reste sur le nœud.
--                         conditions not_contains -> non répétable (LOGIQUE.md).
-- ---------------------------------------------------------------------------
insert into choices (node_id, position, label, kind, next_node_id, inline_response, effects, conditions)
select n.id, v.pos, v.label, v.kind, tgt.id, v.inline::jsonb, v.effects::jsonb, v.conditions::jsonb
from (values

-- N1
('N1', 0, $$Je crois que vous vous trompez de numéro$$, 'reply', 'N2', null::text, '{}', '{}'),
('N1', 1, $$Qui ça, "elle" ?$$, 'reply', 'N3', null, '{"inc": {"confiance": 1}}', '{}'),
('N1', 2, $$Ignorer$$, 'ignore', 'N4', null, '{}', '{}'),

-- N2
('N2', 0, $$Non, désolé. Mais ça va ? Votre message était inquiétant$$, 'reply', 'N5', null,
  '{"inc": {"confiance": 1}, "set": {"branche_ch1": "empathie"}}', '{}'),
('N2', 1, $$Non. Bonne soirée$$, 'reply', 'N6', null, '{}', '{}'),

-- N3
('N3', 0, $$Quelqu'un qui a reçu votre message par erreur. Et qui s'inquiète un peu, là$$, 'reply', 'N5', null,
  '{"inc": {"confiance": 1}, "set": {"branche_ch1": "empathie"}}', '{}'),
('N3', 1, $$Et vous, vous êtes qui ? C'est quoi cette histoire ?$$, 'reply', 'N7', null,
  '{"set": {"branche_ch1": "curieux"}}', '{}'),

-- N4
('N4', 0, $$Non, en effet. C'est quoi cette histoire ?$$, 'reply', 'N7', null,
  '{"set": {"branche_ch1": "curieux"}}', '{}'),
('N4', 1, $$Vous devriez vérifier vos numéros avant d'envoyer ce genre de trucs$$, 'reply', 'N6', null,
  '{"inc": {"lucidite": 1}}', '{}'),

-- N6
('N6', 0, $$Ok. Je vous écoute$$, 'reply', 'N8', null, '{"inc": {"confiance": 1}}', '{}'),
('N6', 1, $$Appelez la police, pas un inconnu$$, 'reply', 'N10', null, '{}', '{}'),
('N6', 2, $$Ignorer$$, 'ignore', 'N11', null, '{}', '{}'),

-- N8 — 3 réponses + LA relance (2 questions, une seule possible : même clé RELANCE_N8)
('N8', 0, $$N'y allez pas seule. Appelez la police, vraiment$$, 'reply', 'N10', null,
  '{"inc": {"lucidite": 1}}', '{}'),
('N8', 1, $$Ok. Je garde mon téléphone à côté de moi$$, 'reply', 'N12', null,
  '{"inc": {"confiance": 2}, "set": {"branche_ch1": "allié"}}', '{}'),
('N8', 2, $$Pourquoi moi ? Vous ne me connaissez pas$$, 'reply', 'N13', null,
  '{"inc": {"lucidite": 1}}', '{}'),
('N8', 3, $$C'est qui, ce type ?$$, 'interaction', null,
  $$[{"sender":"player","content_type":"text","body":"C'est qui, ce type ?","delay_seconds":0,"typing_seconds":0},
     {"sender":"contact","content_type":"text","body":"Aucune idée de son nom. La cinquantaine, toujours seul, toujours le jeudi. Il a chargé des cartons la dernière fois.","delay_seconds":8,"typing_seconds":4}]$$,
  '{"append": {"indices": "PROFIL_SUSPECT", "interactions_faites": "RELANCE_N8"}}',
  '{"not_contains": {"interactions_faites": "RELANCE_N8"}}'),
('N8', 4, $$Pourquoi cet entrepôt ?$$, 'interaction', null,
  $$[{"sender":"player","content_type":"text","body":"Pourquoi cet entrepôt ?","delay_seconds":0,"typing_seconds":0},
     {"sender":"contact","content_type":"text","body":"Le dernier signal du tel de Chloé a borné à 400m de là. La police dit que ça prouve rien. 400 mètres.","delay_seconds":8,"typing_seconds":4}]$$,
  '{"append": {"indices": "BORNAGE", "interactions_faites": "RELANCE_N8"}}',
  '{"not_contains": {"interactions_faites": "RELANCE_N8"}}'),

-- N10 — dont le zoom sur le récépissé : effet SILENCIEUX, aucune réponse de Léna.
-- La date du récépissé (J-2 mois) contredit les « 7 mois » : incohérence VOLONTAIRE (bible §7 n°1).
('N10', 0, $$Ok... je reste en ligne ce soir. Mais promettez-moi de ne pas entrer dans ce bâtiment$$, 'reply', 'N12', null,
  '{"inc": {"confiance": 1}, "set": {"branche_ch1": "prudent"}}', '{}'),
('N10', 1, $$Je suis désolé. Je ne peux pas être responsable de ça$$, 'reply', 'N11', null, '{}', '{}'),
('N10', 2, $$Zoomer sur la capture$$, 'interaction', null, null,
  '{"inc": {"lucidite": 1}, "append": {"interactions_faites": "ZOOM_RECEPISSE_N10"}}',
  '{"not_contains": {"interactions_faites": "ZOOM_RECEPISSE_N10"}}'),

-- N11
('N11', 0, $$Je lis. Soyez prudente$$, 'reply', 'N14', null, '{"inc": {"confiance": 1}}', '{}'),
('N11', 1, $$Ignorer$$, 'ignore', 'N14', null, '{}', '{}'),

-- N13 — insister sur les 50 s d'hésitation (bible §7 n°2)
('N13', 0, $$...50 secondes pour répondre ça ?$$, 'interaction', null,
  $$[{"sender":"player","content_type":"text","body":"...50 secondes pour répondre ça ?","delay_seconds":0,"typing_seconds":0},
     {"sender":"contact","content_type":"text","body":"J'hésitais à te dire un truc. Une autre fois. Pas ce soir.","delay_seconds":8,"typing_seconds":4}]$$,
  '{"inc": {"lucidite": 1}, "append": {"interactions_faites": "INSISTER_N13"}}',
  '{"not_contains": {"interactions_faites": "INSISTER_N13"}}'),

-- N14
('N14', 0, $$Prenez la plaque en photo$$, 'reply', 'N16', null,
  '{"append": {"indices": "PLAQUE"}}', '{}'),
('N14', 1, $$Restez cachée. Décrivez-moi ce que vous voyez$$, 'reply', 'N17', null, '{}', '{}'),
('N14', 2, $$Repartez. Maintenant$$, 'reply', 'N18', null, '{}', '{}'),

-- N16 — zoom sur l'autocollant : effet silencieux (piste Sentinel Pro, ch. 2)
('N16', 0, $$Zoomer sur l'autocollant$$, 'interaction', null, null,
  '{"append": {"indices": "AUTOCOLLANT", "interactions_faites": "ZOOM_AUTOCOLLANT_N16"}}',
  '{"not_contains": {"interactions_faites": "ZOOM_AUTOCOLLANT_N16"}}'),

-- N17 — la réplique n'est proposée qu'APRÈS une réécoute du vocal (geste client).
-- Le son de fond urbain/radio est l'incohérence n°3 de la bible §7.
('N17', 0, $$NON. Restez où vous êtes$$, 'reply', 'N19', null, '{}', '{}'),
('N17', 1, $$Ok mais restez à distance de la porte$$, 'reply', 'N19', null,
  '{"inc": {"confiance": 1}}', '{}'),
('N17', 2, $$C'est quoi ce bruit derrière vous ?$$, 'interaction', null,
  $$[{"sender":"player","content_type":"text","body":"C'est quoi ce bruit derrière vous ?","delay_seconds":0,"typing_seconds":0},
     {"sender":"contact","content_type":"text","body":"Quel bruit ? ...La radio d'une caisse qui passait, j'imagine. Concentre-toi.","delay_seconds":8,"typing_seconds":4}]$$,
  '{"inc": {"lucidite": 1}, "append": {"interactions_faites": "REECOUTE_N17"}}',
  '{"not_contains": {"interactions_faites": "REECOUTE_N17"}}'),

-- N20
('N20', 0, $$Rentrez chez vous. On fait le point demain$$, 'reply', 'N9', null, '{}', '{}'),
('N20', 1, $$Il faut porter ça à la police, MAINTENANT. Le sac, la plaque, tout$$, 'reply', 'N9', null,
  '{"inc": {"lucidite": 1}}', '{}'),

-- N21 — zoom quasi obligatoire, guidé par Léna. Effet silencieux.
-- Indice TELEPHONE attribué dès le ch. 1 (décision Q3) : le geste prouve qu'il a vu.
('N21', 0, $$Zoomer sur la photo$$, 'interaction', null, null,
  '{"append": {"indices": "TELEPHONE", "interactions_faites": "ZOOM_TELEPHONE_N21"}}',
  '{"not_contains": {"interactions_faites": "ZOOM_TELEPHONE_N21"}}')

) as v(node, pos, label, kind, target, inline, effects, conditions)
join stories  s   on s.slug = 'numero-inconnu'
join chapters c   on c.story_id = s.id and c.position = 1
join nodes    n   on n.chapter_id = c.id and n.code = v.node
left join nodes tgt on tgt.chapter_id = c.id and tgt.code = v.target;
