# TODO.md

## Questions ouvertes

*Aucune.* Q1→Q8 tranchées. Les décisions et leur raison sont dans MEMOIRE.md et ARCHITECTURE.md.

## Phases

- [x] **Phase 0 — Audit** : environnement, lecture des 3 sources, audit croisé chapitre ↔ schéma,
      système documentaire. ✅ validée.
- [x] **Phase 1 — Migration** : `supabase init`, `20260814190318_initial_schema.sql`
      (9 tables, 28 index, 21 CHECK, 16 FK, 7 UNIQUE, RLS + 4 policies, 1 trigger),
      `supabase db reset` vert, RLS et contraintes vérifiées fonctionnellement.
      ⏸ En attente de validation.
- [x] **Phase 2 — Seed chapitre 1** : `supabase/seed.sql` (21 nœuds, 67 messages, 33 choix,
      stub du chapitre 2) + `scripts/verify-graph.sql` (40 contrôles, tous OK). ✅ validée
      (commit `0580fad`), complétée par le correctif Q6 (révélation d'identité).
- [x] **Phase 3 — Edge Functions** `get-state` et `advance` + `scripts/simulate-playthrough.py`
      (parcours « allié », « refus » avec test du plafond, branche N6, erreurs, idempotence,
      anti-spoiler). 51 contrôles, tous OK. ✅ **Prompt 1 terminé.**

## Vérification du graphe — `scripts/verify-graph.sql`

```
docker exec -i supabase_db_SMS-Noir psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < scripts/verify-graph.sql
```

40 contrôles, sortie en erreur si un seul échoue : structure (nœuds, entrée, `chapter_end`,
`ai_moment` + fallback, stub ch. 2), intégrité du graphe (orphelins, convergence vers N22,
impasses, transitions auto), les **6 interactions cachées**, cohérence moteur (usage unique,
`refus` porté par le seul N11, aucun `effect` ne code le plafond de `confiance`, 4 branches,
5 indices), contenu (délai ≤ 90 s, positions contiguës, médias, décomptes) et révélation
d'identité (`display_name_initial`, `reveal_contact` sur N5/N7 ciblant un contact existant).

⚠️ **Tester le seed avec `supabase db reset`, jamais seulement avec `psql`.** La CLI envoie le
fichier en **batch** (toutes les requêtes analysées avant exécution) : une `create function`
utilisée dans le même fichier passe en `psql` et échoue sous la CLI. C'est pour ça que le seed
n'utilise aucune fonction et résout les nœuds par jointure sur `code`.

## Simulation de partie — `scripts/simulate-playthrough.py`

```
supabase start && supabase functions serve &     # laisser tourner
python3 scripts/simulate-playthrough.py
```

Joue deux parties entières de N1 à N22 via les Edge Functions, puis relit les variables en
`service_role` (le client ne les voit jamais). Sort en code 1 au premier écart.

- **« allié »** — confiance 7, 4 indices, branche `allié`, Léna révélée au N5, compte à rebours posé.
- **« refus »** — `refus` posé par le nœud N11, **confiance écrêtée à 6** alors que les gains
  valent 7 : c'est le test qui protège la règle du plafond.
- **branche N6** — Léna rembarrée puis insistante : vérifie qu'elle se nomme là aussi (V2.1).
- **Robustesse** — choix hors nœud, choix inexistant, requête vide, appel non authentifié,
  `continue` mal placé, rejeu du même `choice_id`, et inspection des réponses brutes pour
  confirmer qu'aucun `next_node_id` / `effects` / `conditions` / variable ne fuit.

## Fidélité du texte — `scripts/verify-fidelity.py`

```
python3 scripts/verify-fidelity.py
```

Compare **dans les deux sens** les répliques de Léna du chapitre et les textes en base : une
réplique du doc absente de la base, ou un texte en base absent du doc, fait échouer le script.
C'est le garde-fou de la règle 6 (recopie fidèle, jamais de reformulation) et le détecteur de
divergence entre la base et sa source de vérité. **58 = 58 actuellement.**

À relancer après toute modification de `docs/chapitre-1-v2.md` ou du seed.

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

## Prochaine session — prompt 2 (app Flutter)

Points d'entrée pour la reprise :

1. `docs/MEMOIRE.md` — où en est le projet et pourquoi.
2. `docs/LOGIQUE.md § Contrat des Edge Functions` — payloads exacts de `get-state` et `advance`.
3. `docs/LOGIQUE.md § Contraintes client` et `§ Règle d'arrêt sur interaction` — ce que l'app a
   le droit de faire, et ce qu'elle doit offrir sur un nœud en pause.
4. `docs/DESIGN.md` — principes UI déjà arrêtés.

Décisions UI en suspens pour le prompt 2 : le typing intermittent (N2, N13), l'affichage du
message `system` de fin de chapitre (N22#4) en plein écran plutôt que dans le fil, et le geste de
continuation quand `node.can_continue` est vrai sans signaler l'interaction disponible.

## Hors périmètre du prompt 1

App Flutter (prompt 2) · `ai-chat`, quota, `detail_perso` (prompt 3) · notifications locales + FCM,
cron `pg_cron` de déblocage, `unlock-chapter`, premium (prompt 4).
