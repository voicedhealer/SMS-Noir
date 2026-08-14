# MEMOIRE.md — journal de bord

*Fichier à lire en premier par toute nouvelle session Claude Code. Ordre antéchronologique : l'entrée la plus récente est en haut.*

---

## 2026-08-14 — Phase 0 (audit) : **BLOQUÉE, fichiers sources manquants**

### Ce qui a été fait

- Audit de l'environnement local (voir ARCHITECTURE.md § Environnement).
- Lecture intégrale de `docs/bible-narrative.md` (seul fichier source présent).
- Mise en place du système documentaire : `CLAUDE.md`, `docs/ARCHITECTURE.md`,
  `docs/LOGIQUE.md`, `docs/DESIGN.md`, `docs/MEMOIRE.md`, `docs/TODO.md`.
- Rangement : `bible-narrative.md` déplacé de la racine vers `docs/`,
  `prompt-1-claude-code.md` vers `docs/prompts/`. Aucune modification de contenu.

### Le blocage

Le prompt 1 pose comme prérequis trois fichiers dans `docs/`. **Deux sont absents du repo :**

| Fichier | État | Conséquence |
|---|---|---|
| `docs/bible-narrative.md` | ✅ présent (7,5 ko) | — |
| `docs/chapitre-1-v2.md` | ❌ **absent** | Étapes 1, 3, 4 de la Phase 0 impossibles. Phase 2 (seed) impossible. |
| `docs/schema-supabase-v2.md` | ❌ **absent** | Phase 1 (migration) impossible. |

Le repo ne contenait que `README.md` (1 commit, `05f2fad Initial commit`), la bible et le prompt.

**Décision : ne rien inventer.** Reconstituer un chapitre 1 de 22 nœuds ou un schéma Supabase
« plausible » violerait la règle 3 (contenu recopié fidèlement, jamais reformulé) et produirait
un travail à jeter. L'audit croisé chapitre ↔ schéma demandé à l'étape 3 est le cœur de la
Phase 0 : il n'a pas de sens sans ses deux entrées.

### Ce qui a quand même pu être audité

Depuis la bible seule, on connaît : les 4 personnages, la chronologie interne, les 7 variables
(`confiance`, `lucidite`, `indices`, `refus`, `branche_ch1`, `detail_perso`, `loyaute`), les 3 fins,
les 4 incohérences plantées et les **6 interactions cachées du ch. 1** (bible §8) —
qui serviront de checklist de vérification en Phase 2 :

1. Relance N8 (PROFIL_SUSPECT / BORNAGE)
2. Zoom récépissé N10 (`lucidite`)
3. Insister N13 (`lucidite`)
4. Zoom autocollant N16 (AUTOCOLLANT → Sentinel Pro)
5. Réécoute vocal N17 (`lucidite`)
6. Zoom téléphone N21 (TELEPHONE — coque rose fissurée)

### Pièges déjà identifiés (à ne pas oublier plus tard)

- **N9 arrive après N20 dans le flux.** Le code de nœud est un **label**, pas un ordre.
  Le schéma ne doit imposer aucune contrainte d'ordonnancement sur `code`. À confirmer sur le doc réel.
- **Ne jamais « corriger » les incohérences de la bible §7.** Elles alimentent `lucidite`.
  En particulier : la date du récépissé N10, les 50s d'hésitation N13, le son de fond du vocal N17.
- **Plafond `confiance` = 6 si `refus=true`** (bible §6) : c'est une règle moteur, pas juste narrative.
  Elle devra vivre dans l'application des `effects`, pas dans le contenu.
- **`chapter_end` du N22 sans chapitre 2.** Le déblocage (8h, immédiat en premium) doit fonctionner
  en pointant vers un chapitre « à venir » inexistant.
- **Docker n'est pas démarré** : `supabase db reset` échouera tant que le daemon est arrêté.

### Prochaine étape

Vivien fournit `docs/chapitre-1-v2.md` et `docs/schema-supabase-v2.md` → reprise de la Phase 0
aux étapes 1, 3 et 4 (audit croisé), puis STOP et validation avant la Phase 1.
