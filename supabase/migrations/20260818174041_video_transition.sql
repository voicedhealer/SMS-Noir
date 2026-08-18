-- Transition vidéo N20→N9 (addendum transition N20-N9 §2).
--
-- Même famille que l'écran noir narratif du N19 (content_type = 'narration') :
-- un message plein écran, sans bouton ni interaction, qui referme dès que le
-- message suivant arrive — voir docs/LOGIQUE.md § Écran noir narratif. La
-- vidéo n'a pas besoin d'un nœud dédié ni d'un re-câblage des choix du N20 :
-- elle est simplement le premier message du N9 (position 0), les choix du N20
-- continuent de pointer directement vers N9 comme avant.
--
-- Le texte incrusté (« Léna rentre chez elle. ») vit DANS le fichier vidéo,
-- pas en surimpression côté app : contrairement à la narration, il n'y a rien
-- à synchroniser côté client.
alter table messages drop constraint messages_content_type_check;
alter table messages add constraint messages_content_type_check
  check (content_type in ('text', 'image', 'audio', 'system', 'separator',
                          'contact_card', 'narration', 'video'));

alter table player_messages drop constraint player_messages_content_type_check;
alter table player_messages add constraint player_messages_content_type_check
  check (content_type in ('text', 'image', 'audio', 'system', 'separator',
                          'contact_card', 'narration', 'video'));

-- Une vidéo est un média comme une image ou un vocal : sans URL, rien à jouer.
alter table messages drop constraint media_needs_url;
alter table messages add constraint media_needs_url
  check (content_type not in ('image', 'audio', 'video') or media_url is not null);

-- Le bucket refusait déjà tout ce qui n'était pas jpeg/png/webp/mp3/mp4-audio/
-- aac/wav (`allowed_mime_types`, media_bucket.sql) : video/mp4 doit y entrer
-- explicitement, sinon le téléversement échoue silencieusement en 400. Taille
-- inchangée (25 Mo) : le fichier traité (crop + audio retiré) pèse ~5 Mo.
update storage.buckets
set allowed_mime_types = array_append(allowed_mime_types, 'video/mp4')
where id = 'media' and not ('video/mp4' = any(allowed_mime_types));
