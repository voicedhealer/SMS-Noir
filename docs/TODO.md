# TODO.md

## 🔴 Bloquant — action de Vivien requise

- [ ] **Fournir `docs/chapitre-1-v2.md`** — sans lui : pas d'audit croisé (Phase 0), pas de seed (Phase 2).
- [ ] **Fournir `docs/schema-supabase-v2.md`** — sans lui : pas de migration (Phase 1).
- [ ] **Démarrer Docker Desktop** avant la Phase 1 (`supabase db reset` en dépend). Daemon actuellement arrêté.

## Phases

- [x] **Phase 0 — Audit** *(partielle)* : environnement audité, système documentaire créé,
      bible lue. ⛔ Étapes 1/3/4 (audit croisé chapitre ↔ schéma) en attente des fichiers manquants.
- [ ] **Phase 1 — Migration** : migration SQL complète, RLS sur toutes les tables, application locale.
- [ ] **Phase 2 — Seed chapitre 1** : histoire (`draft`), contact Léna, chapitre, 22 nœuds, messages,
      choix, N9 `ai_moment`, N22 `chapter_end` + script de vérification du graphe.
- [ ] **Phase 3 — Edge Functions** `get-state` et `advance` + script de partie simulée
      (parcours « allié » et parcours « refus »).

## Checklist de vérification Phase 2 (source : bible §8)

Le script de vérification du graphe devra confirmer la présence des **6 interactions cachées** :

- [ ] Relance N8 (PROFIL_SUSPECT / BORNAGE)
- [ ] Zoom récépissé N10 (`lucidite`)
- [ ] Insister N13 (`lucidite`)
- [ ] Zoom autocollant N16 (AUTOCOLLANT → Sentinel Pro)
- [ ] Réécoute vocal N17 (`lucidite`)
- [ ] Zoom téléphone N21 (TELEPHONE — coque rose fissurée)

Plus : aucun nœud orphelin · aucun choix vers un nœud inexistant · tous les chemins mènent à N22.

## Médias à produire (Vivien)

Liste à compléter en Phase 2, une fois `chapitre-1-v2.md` dépouillé. Les `media_url` seront seedées
en placeholder (`placeholder://photo-N16-plaque`) et listées ici avec leur nœud d'origine.

Déjà identifiés depuis la bible, à confirmer sur le chapitre :

- [ ] Photo récépissé de signalement — N10 (la date doit rester celle de J-2 mois, **incohérence volontaire**)
- [ ] Photo autocollant — N16 (mention **Sentinel Pro** lisible au zoom)
- [ ] Vocal TTS — N17 (**son de fond urbain/radio** audible : c'est l'indice, ne pas nettoyer l'audio)
- [ ] Photo téléphone — N21 (coque rose fissurée)

## Questions ouvertes

- **Confirmer que `code` de nœud est un label libre** (N9 arrive après N20 dans le flux) — à vérifier
  sur `schema-supabase-v2.md` dès réception.
- **Mapping des interactions cachées** : lesquelles renvoient une `inline_response` sans changer de nœud,
  lesquelles ajoutent des `effects` silencieux ? À trancher sur le chapitre réel.
- **`chapter_end` sans chapitre suivant** : quel affichage pour le compte à rebours vers un chapitre
  « à venir » ? (décision UI, sera tranchée au prompt 2, mais l'état renvoyé par `advance` doit le permettre).
- **Mise à jour de la CLI Supabase** : v2.75.0 installée, v2.114.0 disponible. Utile avant de figer
  le format des migrations ?

## Hors périmètre du prompt 1

App Flutter (prompt 2) · Edge Function `ai-chat` (prompt 3) · Notifications, cron de déblocage,
premium (prompt 4).
