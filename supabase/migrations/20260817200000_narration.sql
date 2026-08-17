-- Écran noir narratif (chapitre 1 V3.2, addendum §1).
--
-- Un `narration` bascule le client en plein écran : plus de fil, plus de champ
-- de saisie, juste du texte sur fond noir. Il sert au N19, pendant les 60 s où
-- Léna ne répond plus.
--
-- **La narration est une chose qui ARRIVE DANS LE FIL, pas une propriété du
-- nœud.** C'est pour ça qu'elle est un message et pas une colonne sur `nodes` :
-- elle a une position, elle est délivrée par le déroulé comme le reste, et un
-- chapitre pourra en poser plusieurs sans qu'on touche au schéma.
--
-- Son `body` porte les lignes et leurs décalages :
--   [{"texte": "Léna ne répond plus...", "a": 0}, …]
-- La DURÉE de l'écran n'est pas ici : c'est le `delay_seconds` du message
-- SUIVANT qui la donne. L'écran noir dure le temps de l'attente, par
-- construction — impossible de désynchroniser les deux.
alter table messages drop constraint messages_content_type_check;
alter table messages add constraint messages_content_type_check
  check (content_type in ('text', 'image', 'audio', 'system', 'separator',
                          'contact_card', 'narration'));

alter table messages drop constraint text_needs_body;
alter table messages add constraint text_needs_body
  check (content_type not in ('text', 'system', 'separator', 'narration')
         or body is not null);
