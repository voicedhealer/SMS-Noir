# TODO.md

## 🔴 Question ouverte — réponse de Vivien requise avant la Phase 2

- [ ] **Q5 — `player_messages.contact_id` = fil de conversation (`not null`) ?** *(écart C)*
      Le schéma de référence prévoyait `null` pour les messages du joueur ; les réponses du joueur
      seraient alors rattachables à aucun fil dès qu'il y a plusieurs contacts (twist ch. 4).
      `sender` porte déjà « qui parle ». *Recommandé : oui, garder `not null`.* Déjà en base,
      réversible avant le seed.

## Phases

- [x] **Phase 0 — Audit** : environnement, lecture des 3 sources, audit croisé chapitre ↔ schéma,
      système documentaire. ✅ validée.
- [x] **Phase 1 — Migration** : `supabase init`, `20260814190318_initial_schema.sql`
      (9 tables, 28 index, 21 CHECK, 16 FK, 7 UNIQUE, RLS + 4 policies, 1 trigger),
      `supabase db reset` vert, RLS et contraintes vérifiées fonctionnellement.
      ⏸ En attente de validation.
- [ ] **Phase 2 — Seed chapitre 1** : histoire (`draft`), contact Léna, chapitre 1 + stub chapitre 2,
      21 nœuds, ~62 messages, ~33 choix, N9 `ai_moment` (fallback N21), N22 `chapter_end`
      + script de vérification du graphe.
- [ ] **Phase 3 — Edge Functions** `get-state` et `advance` + script de partie simulée
      (parcours « allié » et parcours « refus »).

## Checklist du script de vérification (Phase 2)

- [ ] Aucun nœud orphelin (tous atteignables depuis `chapters.entry_node_id` = N1)
- [ ] Aucun `next_node_id` pointant vers un nœud inexistant
- [ ] Tous les chemins mènent à **N22**
- [ ] Tout nœud sans choix `reply`/`ignore` a un `nodes.next_node_id` (sauf N9 et N22)
- [ ] Les **6 interactions cachées** présentes :
  - [ ] Relance N8 — 2 questions, `RELANCE_N8` → `PROFIL_SUSPECT` / `BORNAGE`
  - [ ] Zoom récépissé N10 → `lucidite +1`
  - [ ] Insister N13 → `lucidite +1`
  - [ ] Zoom autocollant N16 → `AUTOCOLLANT`
  - [ ] Réécoute vocal N17 → `lucidite +1`
  - [ ] Zoom téléphone N21 → `TELEPHONE` *(cf. Q3)*
- [ ] Aucun `delay_seconds > 90` (règle de rythme du ch. 1)
- [ ] `ai_fallback_node_id` du N9 = N21 · N22 est bien le seul `chapter_end`

## 🎬 Médias à produire (Vivien) — 4 fichiers

Seedés en `placeholder://…`, à remplacer par des URL de bucket Storage.

- [ ] `placeholder://photo-N10-recepisse` — **N10** · capture d'un récépissé de main courante,
      tampon « sans suite ». ⚠️ **La date doit être celle d'il y a 2 mois** alors que Léna dit
      chercher depuis 7 mois — *incohérence volontaire, lisible au zoom, ne pas « corriger »*.
- [ ] `placeholder://photo-N16-plaque` — **N16** · photo sombre, arrière d'une berline grise, plaque
      partielle « …-843-… », **autocollant « SENTINEL PRO — Gardiennage & Sûreté » lisible au zoom**.
- [ ] `placeholder://audio-N17-reperage` — **N17** · 🎙 **SCRIPT TTS n°1 « Repérage »**, 24 s, voix
      jeune femme chuchotée, tendue, souffle court, débit irrégulier. Texte exact dans
      `chapitre-1-v2.md` §N17. ⚠️ **Mixer un jingle de radio très faible en fond** — c'est l'indice
      de l'incohérence audio, **ne pas nettoyer l'audio**.
- [ ] `placeholder://photo-N21-porteclés` — **N21** · photo floue d'intérieur : établi, cartons, et
      au mur un trousseau avec porte-clés artisanal (deux silhouettes gravées main). ⚠️ **Au zoom,
      en arrière-plan sur l'établi : un téléphone à coque rose, écran fissuré.**

## Confort / plus tard

- [ ] **`supabase db reset` finit sur une erreur 502** : imgproxy et pooler ne démarrent pas.
      Sans impact aujourd'hui (base, API, auth, Edge Functions tournent, la migration s'applique).
      À traiter quand le Storage d'images servira (production des médias).
- [ ] Mettre à jour la CLI Supabase (v2.75.0 → v2.114.0) avant de figer le format des migrations ?
- [ ] Lier le projet au Supabase distant : `supabase link --project-ref eszsdfbalmpnpefnvnsh`.
      Tout est local pour l'instant ; le distant est vide. À faire avant de pousser la migration
      (`supabase db push`), pas avant.
- [ ] **MCP Supabase configuré** (`.mcp.json`, scope projet, même `project_ref`) mais **pas encore
      authentifié** : lancer `claude /mcp` dans un terminal classique (pas l'extension IDE) →
      `supabase` → `Authenticate`. Utile surtout à partir du moment où le distant sert vraiment
      (push de migration, logs, advisors de sécurité, Edge Functions déployées).
- [ ] **Typing intermittent** : le N2 (« en train d'écrire » qui apparaît/disparaît deux fois) et le
      N13 (hésitation par à-coups) ne sont pas exprimables — `messages` n'a qu'un `typing_seconds`.
      Convention UI à trancher au prompt 2 (jitter côté client sur les longues durées) plutôt qu'une
      colonne de plus. Non bloquant.
- [ ] **N19 « Léna est hors ligne »** : modélisable en `content_type='system'`. À confirmer au seed.
- [ ] Durée du silence du N19 (60 s puis 90 s) : « paramétrable en base pour tes tests » — c'est
      `delay_seconds`, à ajuster au ressenti après le prompt 2.

## Hors périmètre du prompt 1

App Flutter (prompt 2) · `ai-chat`, quota, `detail_perso` (prompt 3) · notifications locales + FCM,
cron `pg_cron` de déblocage, `unlock-chapter`, premium (prompt 4).
