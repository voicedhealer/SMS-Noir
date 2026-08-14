# PROMPT 1 — CLAUDE CODE : Fondations du moteur narratif « Numéro Inconnu »

*À coller dans Claude Code à la racine du nouveau projet. Prérequis : les fichiers `docs/bible-narrative.md`, `docs/chapitre-1-v2.md` et `docs/schema-supabase-v2.md` sont présents dans le repo (fournis par Vivien).*

---

Tu vas poser les fondations d'un moteur d'histoires interactives par messagerie (type Friendzoné) : base Supabase, contenu du chapitre 1, et Edge Functions du moteur. Projet : app Flutter (plus tard) + Supabase (maintenant).

## RÈGLES ABSOLUES

1. **Aucun code avant la fin de la Phase 0.** La Phase 0 est un audit + mise en place documentaire, rien d'autre.
2. **`docs/bible-narrative.md` est la source de vérité narrative.** Tu ne modifies JAMAIS ce fichier. Si tu détectes une incohérence entre la bible et le chapitre 1, tu la signales et tu t'arrêtes — tu ne « corriges » pas de ta propre initiative (certaines incohérences sont des éléments de gameplay volontaires, voir bible §7).
3. **À chaque fin de phase : STOP.** Tu présentes un résumé de ce qui a été fait + les fichiers docs mis à jour, et tu attends ma validation explicite avant la phase suivante.
4. **Documentation vivante obligatoire.** Tu maintiens les fichiers de la section « Système documentaire » à CHAQUE phase. Une phase sans mise à jour des docs est une phase non terminée.
5. **Sécurité** : aucune clé/secret en dur dans le code. Variables d'environnement uniquement. RLS activé sur TOUTES les tables dès leur création.
6. **Contenu narratif** : tu recopies fidèlement les textes du chapitre 1 depuis `docs/chapitre-1-v2.md`. Tu n'améliores pas, tu ne reformules pas, tu ne traduis pas. Le contenu est validé tel quel.

## SYSTÈME DOCUMENTAIRE (à créer en Phase 0, à maintenir ensuite)

```
docs/
├── bible-narrative.md      # FOURNI — lecture seule, source de vérité
├── chapitre-1-v2.md        # FOURNI — contenu à seeder, lecture seule
├── schema-supabase-v2.md   # FOURNI — schéma de référence
├── ARCHITECTURE.md         # TU LE CRÉES — état technique réel : tables, functions,
│                           #   flux de données, décisions prises et POURQUOI
├── LOGIQUE.md              # TU LE CRÉES — règles du moteur : cycle de vie d'un nœud,
│                           #   application des effects/conditions, format JSONB exact,
│                           #   contrat des Edge Functions (payloads entrée/sortie)
├── DESIGN.md               # TU LE CRÉES — squelette pour l'instant (UI = Prompt 2) :
│                           #   principes retenus (liste de conversations, bulles,
│                           #   typing indicator, séparateurs horaires, interactions cachées)
├── MEMOIRE.md              # TU LE CRÉES — journal de bord : à chaque phase, ce qui a été
│                           #   fait, les choix pris, les pièges rencontrés, ce qui reste.
│                           #   C'est le fichier qu'un futur Claude Code lira en premier.
└── TODO.md                 # TU LE CRÉES — reste à faire, bugs connus, questions ouvertes
```

Crée aussi un `CLAUDE.md` à la racine, court, qui pointe vers ces docs et rappelle les règles absolues ci-dessus (pour que toute future session les recharge automatiquement).

---

## PHASE 0 — AUDIT (obligatoire, aucun code)

1. Lis intégralement `docs/bible-narrative.md`, `docs/chapitre-1-v2.md`, `docs/schema-supabase-v2.md`.
2. Vérifie l'environnement : CLI Supabase installée ? Projet Supabase lié (`supabase status` / config existante) ? Structure du repo ?
3. Croise le chapitre 1 avec le schéma : liste chaque nœud (N1→N22), compte les messages, les choix, les interactions, les variables utilisées. Vérifie que TOUT est représentable dans le schéma (ex. : les `inline_response` des interactions, le type `separator`, les délais, le nœud `ai_moment` N9 avec son fallback N21).
4. Signale toute ambiguïté ou impossibilité AVANT de coder. Exemples de points à vérifier explicitement :
   - N9 (ai_moment) arrive APRÈS N20 dans le flux mais s'appelle N9 : confirme que le code de nœud est un label libre sans contrainte d'ordre.
   - Les interactions cachées (zoom, réécoute, relance) : certaines donnent une `inline_response` sans changer de nœud, d'autres ajoutent des effects silencieux. Confirme le mapping.
   - Le chapitre 2 n'existe pas encore : `chapter_end` du N22 doit fonctionner sans chapitre suivant (compte à rebours vers un chapitre « à venir »).
5. Crée le système documentaire (fichiers ci-dessus, avec leur contenu initial : ARCHITECTURE et LOGIQUE décrivent le PLAN, MEMOIRE ouvre le journal, TODO liste les phases).
6. **STOP — présente ton audit et attends validation.**

## PHASE 1 — MIGRATION

- Crée la migration SQL complète depuis `docs/schema-supabase-v2.md` : tables de contenu (stories, contacts, chapters, nodes, messages, choices), tables joueur (player_progress, player_messages, ai_usage), index, contraintes, RLS (anti-spoiler : aucune lecture client du contenu sauf la vitrine `stories` publiées ; joueur en lecture seule de ses données).
- Applique la migration en local (`supabase db reset` ou migration up) et vérifie qu'elle passe sans erreur.
- Mets à jour ARCHITECTURE.md (schéma réel), LOGIQUE.md (format exact des JSONB `effects` et `conditions` avec exemples), MEMOIRE.md, TODO.md.
- **STOP — validation.**

## PHASE 2 — SEED DU CHAPITRE 1

- Crée un script de seed (SQL ou TypeScript, ton choix argumenté) qui insère : l'histoire « Numéro Inconnu » (status `draft`), le contact Léna, le chapitre 1, les 22 nœuds, tous les messages (avec délais, typing, push, séparateurs), tous les choix (reply/ignore/interaction avec effects, conditions, inline_response), le nœud N9 en `ai_moment` (system prompt copié depuis les consignes du doc, fallback N21), le N22 en `chapter_end`.
- Les médias (photos, vocal TTS) n'existent pas encore : mets des `media_url` placeholder du type `placeholder://photo-N16-plaque` et liste-les dans TODO.md pour que Vivien sache exactement quoi produire.
- Écris un script de vérification qui parcourt le graphe depuis le nœud d'entrée et confirme : aucun nœud orphelin, aucun choix vers un nœud inexistant, tous les chemins mènent à N22, les 6 interactions cachées présentes.
- Mets à jour les docs. **STOP — validation.**

## PHASE 3 — EDGE FUNCTIONS `get-state` ET `advance`

- `get-state` : retourne les conversations du joueur, l'historique (`player_messages`), et le nœud courant avec UNIQUEMENT ses messages et choix visibles (jamais les `next_node_id`, jamais les `effects`, jamais les choix dont les `conditions` ne sont pas remplies). Crée la progression si première visite.
- `advance` : reçoit `choice_id` → valide l'appartenance au nœud courant ET les conditions → applique les `effects` sur `variables` → écrit les `player_messages` (le choix du joueur + les messages du nœud suivant, ou l'`inline_response` si interaction sans changement de nœud) → met à jour `current_node_id` → retourne les nouveaux messages avec leurs délais (le client jouera les timers). Si le nœud atteint est `chapter_end` : pose `chapter_unlocked_at = now() + unlock_delay` et retourne l'état de fin de chapitre.
- Gestion d'erreurs propre (choix invalide, progression corrompue, double-appel idempotent).
- Tests : un script qui simule une partie complète (parcours « allié » et parcours « refus ») via les deux functions et vérifie l'état final des variables attendu (se référer au chapitre 1 pour les valeurs).
- Mets à jour LOGIQUE.md avec le contrat exact des deux functions (payloads JSON entrée/sortie). **STOP — validation.**

## HORS PÉRIMÈTRE (ne pas toucher, prompts suivants)

App Flutter (Prompt 2) · Edge Function `ai-chat` (Prompt 3) · Notifications, cron de déblocage, premium (Prompt 4). Le nœud N9 est seedé mais son exécution IA sera branchée au Prompt 3 — `advance` doit juste savoir le reconnaître et renvoyer un état `ai_moment_pending`.
