-- ============================================================================
-- Bucket des médias narratifs
--
-- **Privé, volontairement.** Un bucket public exposerait des objets aux noms
-- parfaitement devinables — `photo-N21-porte-cles.jpg` livrerait la révélation
-- de fin de chapitre à quiconque tape l'URL. Ce serait le seul trou dans une
-- architecture entièrement construite autour de l'anti-spoiler : RLS sans
-- policy sur le contenu, GRANT refusés, filtrage dans get-state. Le média est
-- du contenu narratif comme le reste.
--
-- Conséquence : `messages.media_url` stocke un **chemin d'objet**
-- (« photo-N16-plaque.jpg »), pas une URL. Les Edge Functions le transforment
-- en URL signée au moment de répondre, et seulement pour les messages que le
-- joueur a déjà reçus. Le contrat client ne change pas : il reçoit toujours une
-- URL utilisable — simplement éphémère.
--
-- Aucune policy sur storage.objects : la RLS y est active par défaut, donc seul
-- `service_role` (les Edge Functions) accède aux fichiers.
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media',
  'media',
  false,
  26214400, -- 25 Mo : large pour 3 photos et un vocal de 24 s
  array['image/jpeg', 'image/png', 'image/webp', 'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/wav']
)
on conflict (id) do nothing;
