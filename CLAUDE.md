# Numéro Inconnu — moteur d'histoires interactives par messagerie

App **Flutter** (plus tard) + **Supabase** (maintenant : base, contenu, Edge Functions).

## À lire en premier, dans cet ordre

1. `docs/MEMOIRE.md` — journal de bord : où en est le projet, quels choix ont été pris, quels pièges éviter.
2. `docs/TODO.md` — reste à faire, bugs connus, questions ouvertes.
3. `docs/ARCHITECTURE.md` — état technique réel (tables, functions, flux).
4. `docs/LOGIQUE.md` — règles du moteur (cycle de vie d'un nœud, effects/conditions, contrats Edge Functions).
5. `docs/DESIGN.md` — principes UI.

## RÈGLES ABSOLUES

1. **`docs/bible-narrative.md` est la source de vérité narrative. Ne JAMAIS la modifier.**
   En cas de conflit avec un autre document, la bible gagne.
2. **Ne jamais « corriger » une incohérence narrative.** Les incohérences de la bible §7 sont
   du **gameplay volontaire** (elles alimentent la variable `lucidite`). Si tu en détectes une :
   tu la signales, tu t'arrêtes, tu attends. Tu ne corriges pas de ta propre initiative.
3. **Contenu narratif recopié fidèlement** depuis les fichiers de chapitre. On n'améliore pas,
   on ne reformule pas, on ne traduit pas. Le contenu est validé tel quel.
4. **STOP à chaque fin de phase.** Résumé de ce qui a été fait + docs mis à jour, puis attente
   d'une validation explicite de Vivien avant la phase suivante.
5. **Documentation vivante obligatoire.** Les docs ci-dessus sont mis à jour à CHAQUE phase.
   Une phase sans mise à jour des docs est une phase non terminée.
6. **Sécurité.** Aucune clé ni secret en dur dans le code : variables d'environnement uniquement.
   **RLS activé sur TOUTES les tables dès leur création.**
7. **Langue.** Tout le contenu joueur est en français. Les docs aussi.

## Découpage en prompts (périmètres)

| Prompt | Périmètre |
|---|---|
| **1 (en cours)** | Migration Supabase · seed du chapitre 1 · Edge Functions `get-state` et `advance` |
| 2 | App Flutter (UI) |
| 3 | Edge Function `ai-chat` (exécution du nœud `ai_moment` N9) |
| 4 | Notifications, cron de déblocage de chapitre, premium |

Ne pas déborder sur un prompt suivant. Le nœud N9 est **seedé** au prompt 1, mais son exécution IA
arrive au prompt 3 : `advance` doit seulement savoir le reconnaître et renvoyer `ai_moment_pending`.
