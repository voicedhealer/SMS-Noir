# TODO.md

## 🔴 Question ouverte

- [ ] **Q6 — `contacts.display_name` de Léna au chapitre 1.** Elle est seedée `'Léna'`, mais
      **elle ne se nomme jamais dans le chapitre 1** : le joueur apprend le prénom de Chloé (N5),
      pas le sien. La liste de conversations afficherait donc « Léna » avant qu'on le sache, ce qui
      contredit le titre même de l'histoire. Le schéma n'a pas de champ « nom révélé à partir de ».
      Pistes : (a) afficher le numéro tant qu'aucun message reçu ne la nomme, (b) ajouter une colonne
      `contacts.display_name_initial`, (c) assumer « Léna » dès le début. Décision UI surtout —
      peut attendre le prompt 2, mais (b) impliquerait une migration.

## Phases

- [x] **Phase 0 — Audit** : environnement, lecture des 3 sources, audit croisé chapitre ↔ schéma,
      système documentaire. ✅ validée.
- [x] **Phase 1 — Migration** : `supabase init`, `20260814190318_initial_schema.sql`
      (9 tables, 28 index, 21 CHECK, 16 FK, 7 UNIQUE, RLS + 4 policies, 1 trigger),
      `supabase db reset` vert, RLS et contraintes vérifiées fonctionnellement.
      ⏸ En attente de validation.
- [x] **Phase 2 — Seed chapitre 1** : `supabase/seed.sql` (21 nœuds, 65 messages, 33 choix,
      stub du chapitre 2) + `scripts/verify-graph.sql` (36 contrôles, tous OK).
      ⏸ En attente de validation.
- [ ] **Phase 3 — Edge Functions** `get-state` et `advance` + script de partie simulée
      (parcours « allié » et parcours « refus »).

## Vérification du graphe — `scripts/verify-graph.sql`

```
docker exec -i supabase_db_SMS-Noir psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < scripts/verify-graph.sql
```

36 contrôles, sortie en erreur si un seul échoue : structure (nœuds, entrée, `chapter_end`,
`ai_moment` + fallback, stub ch. 2), intégrité du graphe (orphelins, convergence vers N22,
impasses, transitions auto), les **6 interactions cachées**, cohérence moteur (usage unique,
`refus` porté par le seul N11, aucun `effect` ne code le plafond de `confiance`, 4 branches,
5 indices) et contenu (délai ≤ 90 s, positions contiguës, médias, décomptes).

⚠️ **Tester le seed avec `supabase db reset`, jamais seulement avec `psql`.** La CLI envoie le
fichier en **batch** (toutes les requêtes analysées avant exécution) : une `create function`
utilisée dans le même fichier passe en `psql` et échoue sous la CLI. C'est pour ça que le seed
n'utilise aucune fonction et résout les nœuds par jointure sur `code`.

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
