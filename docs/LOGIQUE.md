# LOGIQUE.md — règles du moteur

> **Statut au 2026-08-14 : PLAN, aucun code.**
> ⛔ Les formats JSONB exacts (`effects`, `conditions`) et les contrats des Edge Functions
> ne seront **figés** qu'après réception de `docs/schema-supabase-v2.md` et de
> `docs/chapitre-1-v2.md`. Ce qui suit est le cadre de raisonnement, pas une spécification arrêtée.

## Vocabulaire

| Terme | Définition |
|---|---|
| **Nœud** (`node`) | Une unité du graphe narratif. Porte des `messages` (ce que le personnage envoie) et des `choices` (ce que le joueur peut faire) |
| **Code de nœud** | Label libre : `N1`…`N22`. ⚠️ **N'implique aucun ordre** — N9 arrive après N20 dans le flux du ch. 1 |
| **Choix** | Une action joueur. Trois natures : `reply` (répondre), `ignore` (ne pas répondre), `interaction` (action cachée : zoom, réécoute, relance, insister) |
| **Interaction cachée** | Un choix qui peut ne **pas** faire changer de nœud : il renvoie une `inline_response` et/ou applique des `effects` silencieux, puis le joueur reste sur le nœud courant |
| **`inline_response`** | Réponse immédiate à une interaction, sans transition de nœud |
| **Séparateur** | Message de type `separator` : marque une ellipse temporelle dans le fil |
| **`ai_moment`** | Nœud à saisie libre traité par une IA (N9). Seedé au prompt 1, exécuté au prompt 3. Possède un **fallback** (N21) si l'IA est indisponible |
| **`chapter_end`** | Nœud terminal de chapitre (N22). Pose `chapter_unlocked_at = now() + unlock_delay` |

## Cycle de vie d'un nœud

```
      ┌──────────────────────────────────────────────────────┐
      │  Nœud courant (player_progress.current_node_id)      │
      └──────────────────────────────────────────────────────┘
                              │
                    get-state │  filtre anti-spoiler :
                              │  - messages du nœud
                              │  - choix DONT les conditions sont remplies
                              │  - jamais next_node_id, jamais effects
                              ▼
                    ┌───────────────────┐
                    │  Le joueur choisit│
                    └───────────────────┘
                              │ advance(choice_id)
                              ▼
            ┌─────────────────────────────────────┐
            │ 1. Le choix appartient-il au nœud   │  non ─▶ erreur
            │    courant ?                        │
            │ 2. Ses conditions sont-elles        │  non ─▶ erreur
            │    remplies ?                       │
            └─────────────────────────────────────┘
                              │ oui
                              ▼
            ┌─────────────────────────────────────┐
            │ 3. Appliquer les effects sur        │
            │    player_progress.variables        │
            │    (dont le plafond confiance ≤ 6   │
            │     si refus = true)                │
            └─────────────────────────────────────┘
                              │
              ┌───────────────┴────────────────┐
              │                                │
      next_node_id absent            next_node_id présent
      (interaction cachée)                     │
              │                                ▼
              ▼                    ┌────────────────────────────┐
   écrire l'inline_response        │ écrire le message joueur   │
   dans player_messages            │ + les messages du nœud     │
   le nœud courant NE CHANGE PAS   │   suivant (avec délais)    │
                                   │ current_node_id ← suivant  │
                                   └────────────────────────────┘
                                                │
                            ┌───────────────────┴──────────────┐
                            │ type du nœud atteint ?           │
                            ├──────────────────────────────────┤
                            │ standard    → renvoyer messages  │
                            │ ai_moment   → ai_moment_pending  │
                            │ chapter_end → poser              │
                            │   chapter_unlocked_at et         │
                            │   renvoyer l'état de fin         │
                            └──────────────────────────────────┘
```

Les **délais** ne sont pas attendus côté serveur : ils sont renvoyés au client avec chaque message,
et c'est le client qui joue les timers (et le typing indicator).

## Règles moteur transverses (source : bible)

1. **Plafond `confiance` = 6 quand `refus = true`** (bible §6). Appliqué par le moteur à chaque
   écriture de `confiance`, **pas** encodé dans les `effects` du contenu.
2. **Ne jamais corriger une incohérence narrative** (bible §7) : elles sont la matière première de
   `lucidite`. Le moteur les transporte telles quelles.
3. **`detail_perso` est une donnée personnelle** (bible §9, RGPD) : un seul élément anodin,
   consentement à la première saisie libre, effacement en cascade avec la progression du joueur.
4. **Idempotence** : un double-appel de `advance` avec le même `choice_id` depuis le même nœud ne
   doit pas appliquer les `effects` deux fois.

## Format JSONB `effects`

⛔ **À figer sur `schema-supabase-v2.md`.** Direction envisagée : une liste d'opérations
déclaratives (`set` / `inc` / `append`) sur les variables de `player_progress.variables`, de façon à
rester lisible en base et vérifiable par le script de Phase 2. Exemples réels à écrire ici en Phase 1.

## Format JSONB `conditions`

⛔ **À figer sur `schema-supabase-v2.md`.** Direction envisagée : une expression déclarative
évaluée contre `variables`, suffisamment expressive pour les seuils de fins de la bible §6
(`confiance >= 7 ET indices >= 3`, `lucidite >= 4 ET a_repondu_a_chloe`). Exemples réels en Phase 1.

## Contrat des Edge Functions

⛔ **À rédiger en Phase 3** (payloads JSON entrée/sortie complets, codes d'erreur).

Invariants déjà acquis, quelle que soit la forme finale :

**`get-state`**
- Crée la progression si c'est la première visite.
- Renvoie : conversations du joueur, historique `player_messages`, nœud courant.
- Ne renvoie **jamais** : `next_node_id`, `effects`, ni les choix dont les `conditions` sont fausses.

**`advance`**
- Entrée : `choice_id`.
- Erreurs à traiter proprement : choix invalide (n'appartient pas au nœud courant), conditions non
  remplies, progression corrompue, double-appel (idempotent).
- Sortie : les nouveaux `player_messages` avec leurs délais ; ou l'`inline_response` seule si
  l'interaction ne change pas de nœud ; ou `ai_moment_pending` si le nœud atteint est le N9 ;
  ou l'état de fin de chapitre si le nœud atteint est un `chapter_end`.
