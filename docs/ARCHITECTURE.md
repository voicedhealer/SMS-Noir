# ARCHITECTURE.md — état technique réel

> **Statut au 2026-08-14 : aucun code écrit.** Ce document décrit le PLAN.
> Il devient descriptif (« ce qui existe ») à partir de la Phase 1.
> ⛔ Le schéma de référence `docs/schema-supabase-v2.md` est **absent du repo** :
> la section « Modèle de données » ne peut pas encore être renseignée.

## Environnement (audité le 2026-08-14)

| Élément | État | Remarque |
|---|---|---|
| Repo git | ✅ propre, branche `main`, 1 commit (`05f2fad`) | Seul `README.md` était suivi |
| CLI Supabase | ✅ **v2.75.0** | v2.114.0 disponible — voir TODO |
| Projet Supabase local | ❌ **pas initialisé** | Pas de dossier `supabase/`, pas de `config.toml` |
| Projet Supabase distant | ❌ **non lié** | Aucun `project_ref` |
| Docker | ⚠️ **installé (28.5.1) mais daemon arrêté** | 🔴 Bloque `supabase start` / `supabase db reset` en Phase 1 |
| Deno (standalone) | ❌ absent | Non bloquant : la CLI exécute les Edge Functions dans Docker. Utile pour typecheck/tests locaux en Phase 3 |
| Flutter | ✅ présent | Hors périmètre du prompt 1 |

**Conséquence** : la Phase 1 commence par `supabase init` puis nécessite un daemon Docker démarré.

## Vue d'ensemble cible

```
┌─────────────────┐        ┌──────────────────────────────────────┐
│  App Flutter    │        │              Supabase                │
│  (prompt 2)     │        │                                      │
│                 │        │  Edge Functions                      │
│  - liste convs  │ ──────▶│   • get-state   (prompt 1)           │
│  - fil de msgs  │  HTTPS │   • advance     (prompt 1)           │
│  - timers       │ ◀──────│   • ai-chat     (prompt 3)           │
│    locaux       │        │              │                       │
└─────────────────┘        │              ▼                       │
                           │  Postgres + RLS                      │
                           │   Contenu : stories, contacts,       │
                           │     chapters, nodes, messages,       │
                           │     choices                          │
                           │   Joueur  : player_progress,         │
                           │     player_messages, ai_usage        │
                           └──────────────────────────────────────┘
```

**Principe structurant : le client ne lit jamais le contenu narratif directement.**
Toute lecture passe par une Edge Function qui filtre. Voir § Sécurité.

## Modèle de données

⛔ **En attente de `docs/schema-supabase-v2.md`.**

Ce que le prompt 1 impose déjà, et qui sera confronté au doc de référence dès réception :

**Tables de contenu** — `stories`, `contacts`, `chapters`, `nodes`, `messages`, `choices`
**Tables joueur** — `player_progress`, `player_messages`, `ai_usage`

Types de nœuds connus : nœud standard, `ai_moment` (N9), `chapter_end` (N22).
Types de messages connus : texte, média (photo, vocal), `separator` (séparateur horaire).

Variables de partie (bible §6), portées par `player_progress.variables` (JSONB) :

| Variable | Type | Plage / valeurs | Départ |
|---|---|---|---|
| `confiance` | int | 0-10, **plafond 6 si `refus=true`** | 3 |
| `lucidite` | int | 0-5 au ch. 1, extensible | 0 |
| `indices` | liste | codes d'indices collectés | `[]` |
| `refus` | bool | branche N11 | `false` |
| `branche_ch1` | code | callbacks d'ouverture du ch. 2 | — |
| `detail_perso` | texte | ⚠️ **donnée RGPD** (bible §9), saisi au moment IA N9 | — |
| `loyaute` | enum | `lena` / `karim` / `neutre` — ch. 3+ | — |

## Sécurité — RLS

Règle générale : **RLS activé sur toutes les tables dès leur création**, sans exception.

| Portée | Politique visée |
|---|---|
| `stories` | Lecture publique **uniquement** des histoires publiées (la vitrine). C'est la seule table de contenu lisible par le client |
| Autres tables de contenu | **Aucune lecture client.** Accès `service_role` seulement, via Edge Functions (anti-spoiler) |
| Tables joueur | Le joueur lit **ses** lignes, en lecture seule. Toute écriture passe par une Edge Function |

Anti-spoiler côté Edge Function (`get-state`) — ne sortent **jamais** vers le client :
`next_node_id`, `effects`, et les choix dont les `conditions` ne sont pas remplies.

Secrets : variables d'environnement uniquement, jamais en dur. `SUPABASE_SERVICE_ROLE_KEY` ne
quitte jamais le serveur.

## Edge Functions (Phase 3)

| Function | Rôle |
|---|---|
| `get-state` | Conversations du joueur + historique `player_messages` + nœud courant filtré. Crée la progression à la première visite |
| `advance` | Reçoit un `choice_id`, valide, applique les `effects`, écrit les `player_messages`, avance `current_node_id`, renvoie les nouveaux messages **avec leurs délais** (les timers sont joués par le client) |

Contrats détaillés (payloads entrée/sortie) : voir `LOGIQUE.md`.

## Décisions prises, et pourquoi

| # | Décision | Pourquoi |
|---|---|---|
| 1 | **Aucun contenu narratif ni schéma inventé** malgré les fichiers manquants | Règle 3 (recopie fidèle). Un chapitre reconstitué serait faux et à jeter ; l'audit croisé n'a pas de sens sans ses deux entrées |
| 2 | `bible-narrative.md` déplacé de la racine vers `docs/`, prompt vers `docs/prompts/` | Aligne le repo sur l'arborescence imposée par le prompt 1. Contenu inchangé |
| 3 | Les **délais sont joués par le client**, le serveur les renvoie comme données | Évite de maintenir des connexions longues ; permet de rejouer l'historique instantanément |
| 4 | Le **plafond de `confiance` (6 si `refus`) vit dans le moteur**, pas dans le contenu | Règle transverse de la bible §6 : la dupliquer dans chaque `effects` la rendrait faillible |
