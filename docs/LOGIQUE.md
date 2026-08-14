# LOGIQUE.md — règles du moteur

> **Statut au 2026-08-14 : Phase 1 terminée.** Les colonnes qui portent ces formats existent en base
> (`effects`, `conditions`, `inline_response`, `nodes.next_node_id`). Les **formats JSONB ci-dessous
> sont désormais le contrat** : ils seront appliqués tels quels au seed (Phase 2) puis interprétés
> par le moteur (Phase 3). Le contrat exact des Edge Functions sera rédigé en Phase 3.

## Vocabulaire

| Terme | Définition |
|---|---|
| **Nœud** (`node`) | Unité du graphe. Porte des `messages` et des `choices` |
| **Code de nœud** | Label libre : `N1`…`N22`. ⚠️ **Aucun ordre implicite** — N9 arrive après N20, et **N15 n'existe pas** |
| **Choix** | `reply` (répondre) · `ignore` (bouton explicite, jamais de timeout) · `interaction` (geste caché : zoom, réécoute, relance, insister) |
| **Interaction cachée** | Choix qui ne change généralement **pas** de nœud : renvoie une `inline_response` et/ou applique des `effects` silencieux |
| **Séparateur** | `content_type='separator'` : ellipse narrative (`body='23h31'`) masquant un délai réel court |
| **`ai_moment`** | Nœud à saisie libre (N9). Seedé au prompt 1, exécuté au prompt 3. Sort via `ai_fallback_node_id` (N21) |
| **`chapter_end`** | Nœud terminal (N22). Pose `chapter_unlocked_at` |

## Cycle de vie d'un nœud

```
      ┌──────────────────────────────────────────────────────┐
      │  Nœud courant (player_progress.current_node_id)      │
      └──────────────────────────────────────────────────────┘
                              │
                    get-state │  filtre anti-spoiler :
                              │  - messages du nœud
                              │  - choix DONT les conditions sont remplies
                              │  - jamais next_node_id / effects / conditions
                              ▼
                    ┌───────────────────┐
                    │  Le joueur agit   │
                    └───────────────────┘
                              │ advance(choice_id)
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 1. Le choix appartient-il au nœud courant ?  non ─▶ 403 │
   │ 2. Ses conditions sont-elles remplies ?      non ─▶ 403 │
   │ 3. Déjà consommé (idempotence) ?             oui ─▶ état inchangé │
   └────────────────────────────────────────────────────────┘
                              │
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 4. Écrire le message joueur                            │
   │    (SAUF si kind='ignore' → on n'écrit rien du joueur) │
   │ 5. Appliquer choices.effects sur variables             │
   └────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴────────────────┐
     next_node_id NULL                next_node_id présent
     (interaction sur place)                   │
              │                                ▼
              ▼                  ┌──────────────────────────────┐
   écrire l'inline_response      │ 6. Appliquer nodes.effects   │
   dans player_messages          │    du nœud ATTEINT (N11)     │
   le nœud courant NE CHANGE PAS │ 7. Écrire ses messages       │
   (mais les effects, eux,       │ 8. current_node_id ← atteint │
    ont bien été appliqués)      └──────────────────────────────┘
                                                │
                            ┌───────────────────┴──────────────┐
                            │ kind du nœud atteint ?           │
                            ├──────────────────────────────────┤
                            │ scripted    → si next_node_id    │
                            │   (auto) : enchaîner (§ Auto)    │
                            │ ai_moment   → ai_moment_pending  │
                            │ chapter_end → poser              │
                            │   chapter_unlocked_at et         │
                            │   renvoyer l'état de fin         │
                            └──────────────────────────────────┘
```

Les **délais ne sont pas attendus côté serveur** : ils sont renvoyés avec chaque message et joués
par le client (timers locaux + typing indicator + notifications locales programmées).

## Transitions automatiques (`nodes.next_node_id`)

8 nœuds du ch. 1 n'ont aucun choix de sortie et enchaînent seuls :

| Nœud | Enchaîne vers | Contexte |
|---|---|---|
| N5, N7 | N8 | Léna se livre / elle teste |
| N12 | N14 | « Merci. Sérieux. » |
| N13 | N14 | après l'interaction « Insister » (optionnelle) |
| N16 | N19 | après l'interaction « Zoom autocollant » (optionnelle) |
| N18 | N19 | « J'ai pas fait tout ça pour repartir. » |
| N19 | N20 | l'incident |
| N21 | N22 | après le zoom sur le porte-clés |

Le schéma de référence ne sait exprimer une transition que via `choices.next_node_id` :
d'où l'ajout de la colonne `nodes.next_node_id` (écart A, ARCHITECTURE.md).

### Règle d'arrêt sur interaction *(validée — contrainte pour l'UI du prompt 2)*

**`advance` ne déroule jamais la chaîne automatique d'un trait. Il s'arrête sur le premier nœud
qui offre au moins une `interaction` encore disponible** (conditions vraies, pas encore dans
`interactions_faites`), et ce nœud devient le `current_node_id`.

Sans cette règle, les interactions cachées des nœuds auto-enchaînés (**N13, N16, N21**) seraient
traversées avant que le joueur ait pu agir : trois des six interactions du chapitre deviendraient
mécaniquement inatteignables.

**Conséquence côté serveur** — `advance` renvoie alors un état où le nœud courant n'a aucun choix
`reply`/`ignore`, seulement une ou plusieurs `interaction`. Ce n'est pas un cas d'erreur : c'est
l'état normal d'un nœud « en pause sur interaction ».

**Contrainte pour l'UI (prompt 2)** — dans cet état, l'app doit :

1. Dérouler les messages du nœud, puis **rester en attente** au lieu d'afficher des boutons de réponse.
2. Offrir **un moyen de continuer sans interagir** — l'interaction n'est jamais obligatoire
   (chapitre §Conventions). Concrètement : un geste de continuation discret, ou la simple poursuite
   du fil après un délai. Ce geste appelle `advance` sur la transition automatique du nœud.
3. Ne **jamais** signaler qu'une interaction est disponible ici (pas de bouton « indice », pas de
   pastille). Le geste doit rester naturel : zoomer sur une photo, réécouter un vocal, insister.
   Le joueur qui passe à côté ne doit pas le sentir ; celui qui la trouve ne doit voir aucune
   récompense clignoter.
4. Cas particulier du **N21** : le zoom est *quasi obligatoire, guidé par Léna* (« Tu vois le
   porte-clés ? Zoome. »). Même mécanique technique, mais l'incitation est portée par le texte —
   pas par un élément d'interface.

## Règles moteur transverses

1. **`refus` et le plafond de `confiance` sont deux mécanismes distincts** — voir § ci-dessous.
   Ne jamais les confondre.
2. **`confiance` bornée à [0,10]**, `lucidite` à [0,5] au ch. 1 (chapitre §Variables).
3. **`kind='ignore'` n'écrit aucun message joueur** — le joueur n'a rien dit. Il avance quand même.
4. **Ne jamais corriger une incohérence narrative** (bible §7) : elles alimentent `lucidite`.
   Le moteur les transporte telles quelles.
5. **`detail_perso` est une donnée personnelle** (bible §9, RGPD) : un seul élément anodin,
   consentement à la première saisie libre, effacement en cascade.
6. **Idempotence** : rejouer `advance` avec le même `choice_id` depuis le même nœud ne doit pas
   appliquer les `effects` deux fois (voir § Interactions à usage unique).

## Contraintes client *(prompt 2)*

**Le client n'écrit jamais en base. L'état vient toujours de `get-state`.**

Ce n'est pas une convention de style, c'est une contrainte structurelle : les tables joueur n'ont
**aucune policy `insert`/`update`/`delete`**. Un client qui tenterait d'écrire échouerait — et pas
toujours bruyamment :

| Tentative côté client | Ce qui se passe réellement |
|---|---|
| `insert into player_progress` | ❌ erreur `new row violates row-level security policy` |
| `insert into player_messages` | ❌ même erreur |
| **`update player_progress set variables = …`** | ⚠️ **`UPDATE 0` — aucune erreur, aucune ligne modifiée** |

⚠️ **Le cas de l'`UPDATE` est le piège.** Faute de policy `update`, aucune ligne n'est visible en
écriture : Postgres ne lève pas d'exception, il modifie zéro ligne et renvoie un succès. Un client
qui écrirait sa progression en local croirait donc avoir réussi, afficherait un état divergent, et
le prochain `get-state` le contredirait sans prévenir. Symptôme typique : des variables ou des
messages qui « reviennent en arrière » de façon inexplicable après un redémarrage de l'app.

**Règles qui en découlent, pour l'app Flutter :**

1. **Ne jamais écrire dans `player_progress` ni `player_messages`.** Toute mutation passe par
   `advance` (ou `ai-chat`, prompt 3).
2. **Ne jamais faire confiance à un état local.** Le cache local sert à l'affichage hors-ligne et à
   rejouer l'historique, jamais de référence. `get-state` fait autorité, toujours.
3. **Ne jamais dériver une variable côté client** (`confiance`, `lucidite`, `indices`…). Le client
   ne les voit même pas : elles ne sortent pas de `get-state`. C'est voulu — cf. anti-triche.
4. **Un succès d'écriture non vérifié n'est pas un succès.** Si du code client venait à écrire un
   jour, il devrait contrôler le nombre de lignes affectées, pas l'absence d'erreur.

## Révélation d'identité d'un contact

Un contact peut arriver anonyme et être révélé plus tard — ou ne jamais l'être. C'est un ressort
narratif récurrent, pas un cas particulier du chapitre 1 :

| Contact | Arrivée | Révélation |
|---|---|---|
| **Léna** | ch. 1, numéro inconnu | se nomme au **N5** et au **N7** |
| **Karim** | ch. 3, numéro inconnu (Léna crée le groupe) | à définir |
| **Le suspect** | ch. 4, numéro inconnu | **jamais** — il reste anonyme jusqu'au bout |

Le mécanisme tient en deux moitiés :

1. **`contacts.display_name_initial`** — le nom affiché *avant* révélation (« Numéro inconnu »).
   `null` = contact connu dès le départ.
2. **L'effect `reveal_contact`** sur le nœud où l'identité se dévoile :
   `nodes.effects = {"reveal_contact": "lena"}`. Le moteur ajoute le code du contact à
   `player_progress.variables.contacts_reveles` (liste, sans doublon).

Le nom à afficher se calcule donc côté serveur, à chaque `get-state` :

```
nom_affiché = si code ∈ contacts_reveles  ->  display_name
              sinon                       ->  coalesce(display_name_initial, display_name)
```

**Pourquoi l'état vit dans `variables` et pas dans le contenu** : la révélation dépend du chemin
parcouru. Deux joueurs au même instant n'en sont pas au même point — l'un a croisé le N5, l'autre
non. C'est un état de partie, comme `indices` ou `interactions_faites`.

**Pourquoi sur le nœud et pas sur un choix** : plusieurs chemins mènent à la révélation (N5 *et*
N7), exactement comme pour `refus` au N11. Poser l'effect sur chaque choix entrant serait fragile.

**Un contact jamais révélé n'est la cible d'aucun `reveal_contact`** — il n'y a rien à désactiver,
il suffit de ne pas poser l'effect. Le suspect du ch. 4 garde son `display_name_initial` pour
toujours.

⚠️ **Un joueur peut terminer le chapitre 1 sans jamais connaître le nom de Léna** : la branche
du N6 (N2-B ou N4-B → N6 → N8/N10/N11) atteint N22 sans passer par N5 ni N7. Ce n'est pas un bug
du mécanisme — c'est un trou de contenu, voir TODO Q7. Le moteur, lui, se comporte correctement :
la conversation reste « Numéro inconnu ».

## `refus` : deux mécanismes à ne pas confondre

Le refus du joueur produit **deux choses de nature complètement différente**. Les mélanger est
l'erreur la plus facile à commettre ici.

| | **Poser `refus = true`** | **Plafonner `confiance` à 6** |
|---|---|---|
| **Nature** | Un `effect`, **contenu** | Une **règle permanente du moteur** — jamais un `effect` |
| **Où ça vit** | `nodes.effects` du **N11** : `{"set": {"refus": true}}` | En dur dans `advance` |
| **Quand ça joue** | **Une seule fois**, à l'entrée du N11 | **À chaque gain de `confiance`**, indéfiniment, tant que `refus` est vrai |
| **Portée** | Le nœud N11 | Toute la partie (ch. 1 → ch. 3 inclus, bible §6) |
| **Si on l'oubliait** | La branche du refus n'existerait plus | La `confiance` dépasserait 6 sur les gains ultérieurs |

**`refus = true` est posé sur le nœud, pas sur un choix**, parce que les deux chemins d'entrée du
N11 (N6-C « Ignorer », N10-B « Je ne peux pas être responsable de ça ») doivent tous deux le poser.
C'est le seul usage de `nodes.effects` du chapitre 1.

**Le plafond, lui, n'est écrit nulle part dans le contenu.** `advance` l'applique après chaque
écriture de `confiance`, de façon inconditionnelle :

```
confiance ← clamp(confiance + gain, 0, refus ? 6 : 10)
```

Pourquoi pas un `effect` : le plafond doit s'appliquer aux gains qui arrivent **après** le N11
(N11-A `confiance +1`, N17-B `confiance +1`, et le moment IA N9 `confiance +2`) — et à tous ceux
des chapitres 2 et 3. L'encoder dans les `effects` du contenu obligerait à le répéter sur chaque
gain de chaque chapitre : une seule ligne oubliée et la règle de la bible tombe silencieusement.

⚠️ Corollaire pour le prompt 3 : le `confiance +2` du moment IA passe par le même chemin d'écriture,
donc par le même plafond. `ai-chat` ne doit pas écrire `confiance` directement.

## Interactions à usage unique

Sans garde-fou, un joueur peut rezoomer sur le récépissé du N10 et empiler `lucidite +1`.
Mécanisme retenu, **sans changement de schéma** : une liste `interactions_faites` dans
`player_progress.variables`.

- Toute interaction porte `effects.append.interactions_faites = "<code>"`.
- Toute interaction porte `conditions` : « `<code>` absent de `interactions_faites` ».
- `get-state` masque donc naturellement une interaction déjà consommée.

C'est aussi ce qui implémente la contrainte du **N8 : « UNE relance optionnelle »** alors que deux
questions sont proposées. Les deux entrées (`PROFIL_SUSPECT`, `BORNAGE`) écrivent la **même** clé
`RELANCE_N8`, donc poser une question retire l'autre. Le joueur choisit laquelle — il ne peut pas
avoir les deux indices.

## Format JSONB `effects`

Liste d'opérations déclaratives sur `player_progress.variables`. Trois opérateurs suffisent
à tout le chapitre 1 :

```jsonc
// N8 choix B — « Ok. Je garde mon téléphone à côté de moi »
{ "inc": { "confiance": 2 }, "set": { "branche_ch1": "allié" } }

// N8 interaction — « C'est qui, ce type ? »
{ "append": { "indices": "PROFIL_SUSPECT", "interactions_faites": "RELANCE_N8" } }

// N10 interaction — zoom sur le récépissé
{ "inc": { "lucidite": 1 }, "append": { "interactions_faites": "ZOOM_RECEPISSE_N10" } }

// nodes.effects du N11 — le refus assumé
{ "set": { "refus": true } }
```

| Opérateur | Effet |
|---|---|
| `set` | Affectation directe (`branche_ch1`, `refus`) |
| `inc` | Incrément borné (`confiance`, `lucidite`) — les bornes et le plafond `refus` sont appliqués par le moteur |
| `append` | Ajout à une liste, **sans doublon** (`indices`, `interactions_faites`) |
| `reveal_contact` | Ajoute un code de contact à `contacts_reveles` — voir § Révélation d'identité |

## Format JSONB `conditions`

Expression déclarative évaluée contre `variables`. `{}` = toujours vrai. Les clés d'un même objet
sont en **ET**.

```jsonc
{}                                                  // toujours disponible
{ "not_contains": { "interactions_faites": "RELANCE_N8" } }   // relance N8 pas encore utilisée
{ "gte": { "confiance": 7 }, "count_gte": { "indices": 3 } }  // fin « La sauver » (ch. 5)
{ "eq": { "refus": true } }                         // variante vouvoiement
```

Opérateurs prévus : `eq`, `gte`, `lte`, `contains`, `not_contains`, `count_gte`.
Le chapitre 1 n'utilise en pratique que `not_contains` (interactions à usage unique) ; les autres
sont posés maintenant pour les seuils de fins de la bible §6, pour ne pas avoir à migrer plus tard.

## Format JSONB `inline_response`

Réponse à une interaction qui ne change pas de nœud. Même structure qu'un message, en liste
(une interaction peut produire un échange court) :

```jsonc
// N13 — interaction « Insister »
[
  { "sender": "player",  "content_type": "text",
    "body": "...50 secondes pour répondre ça ?" },
  { "sender": "contact", "content_type": "text", "delay_seconds": 12, "typing_seconds": 4,
    "body": "J'hésitais à te dire un truc. Une autre fois. Pas ce soir." }
]
```

Le N17 (réécoute du vocal) suit exactement ce patron : la réécoute fait apparaître la réplique
joueur « C'est quoi ce bruit derrière vous ? », suivie de la réponse de Léna.

## Contrat des Edge Functions

Types TypeScript de référence : `supabase/functions/_shared/types.ts`.
Les deux endpoints sont en **POST**, authentifiés par le JWT du joueur
(`Authorization: Bearer …`). Sans jeton valide : `401`.

### Ce qui ne sort JAMAIS

`next_node_id` · `effects` · `conditions` · les choix dont les `conditions` sont fausses ·
**les variables de partie** (`confiance`, `lucidite`, `indices`…). Le joueur ne voit jamais ses
compteurs : c'est à la fois l'anti-triche et le refus du 4e mur (DESIGN.md).
*Vérifié par `scripts/simulate-playthrough.py`, qui inspecte les réponses brutes.*

### `get-state`

Entrée : `{}` — l'identité vient du jeton. Crée la progression à la première visite, entre dans le
nœud d'entrée et déroule sa chaîne.

```jsonc
{
  "story": { "slug": "numero-inconnu", "title": "Numéro Inconnu" },
  "conversations": [
    { "contact_id": "uuid", "display_name": "Numéro inconnu",  // ou « Léna » après révélation
      "avatar_url": null, "revealed": false }
  ],
  "history": [                       // tout l'historique, ordonné par seq
    { "seq": 1, "contact_id": "uuid", "sender": "contact", "content_type": "separator",
      "body": "jeudi — 22h47", "media_url": null,
      "delay_seconds": 0, "typing_seconds": 0,   // toujours 0 : l'historique se rejoue d'un bloc
      "push_notification": false, "push_text": null }
  ],
  "node": {
    "code": "N1", "kind": "scripted",
    "choices": [ { "id": "uuid", "position": 0, "label": "…", "kind": "reply" } ],
    "awaiting_interaction": false,
    "can_continue": false
  },
  "chapter_end": null,
  "ai_moment_pending": false
}
```

### `advance`

Deux formes d'entrée :

| Entrée | Effet |
|---|---|
| `{ "choice_id": "uuid" }` | Applique un choix (`reply`, `ignore` ou `interaction`) |
| `{ "continue": true }` | Franchit la transition automatique du nœud courant. Sur un `ai_moment`, emprunte le **fallback** — le chemin prévu quand l'IA est indisponible |

```jsonc
{
  "new_messages": [                  // à dérouler AVEC leurs délais (timers côté client)
    { "seq": 12, "contact_id": "uuid", "sender": "player", "content_type": "text",
      "body": "Qui ça, \"elle\" ?", "media_url": null,
      "delay_seconds": 0, "typing_seconds": 0, "push_notification": false, "push_text": null },
    { "seq": 13, "contact_id": "uuid", "sender": "contact", "content_type": "text",
      "body": "Attends", "media_url": null,
      "delay_seconds": 25, "typing_seconds": 3, "push_notification": false, "push_text": null }
  ],
  "node": { /* comme get-state, ou null */ },
  "conversations": [ /* renvoyées à chaque coup : une révélation peut changer un nom */ ],
  "chapter_end": null,
  "ai_moment_pending": false,
  "idempotent_replay": false
}
```

Au N22, `chapter_end` est renseigné :

```jsonc
{
  "chapter_title": "Le mauvais numéro",
  "next_chapter_title": "Chloé",
  "unlocked_at": "2026-08-15T03:58:00.000Z",   // now() + unlock_delay_minutes du chapitre suivant
  "next_chapter_pending": true                  // le stub existe, son contenu non
}
```

### Erreurs

Toutes de la forme `{ "error": { "code": "…", "message": "…" } }`.

| Statut | Code | Quand |
|---|---|---|
| 400 | `requete_invalide` | Ni `choice_id` ni `continue` |
| 401 | `non_authentifie` | Jeton absent ou invalide |
| 403 | `choix_invalide` | Le choix n'appartient pas au nœud courant — **même réponse si le choix n'existe pas du tout**, pour ne rien révéler du graphe |
| 403 | `choix_verrouille` | `conditions` non remplies (interaction déjà consommée, par exemple) |
| 409 | `choix_attendu` | `continue` sur un nœud qui propose des réponses |
| 409 | `sans_suite` | `continue` sur un nœud sans transition automatique |
| 409 | `progression_corrompue` | Aucun nœud courant |
| 500 | `erreur_interne` | Le détail reste dans les logs serveur |

### Idempotence

Un `advance` rejouant le **même `choice_id`** (retransmission réseau) ne réapplique aucun `effect` :
il renvoie à l'identique les messages produits au premier appel, avec `idempotent_replay: true` et
des délais à 0 — ils ont déjà été joués.

Le mécanisme repose sur `player_progress.last_choice_id` et `last_choice_seq` (le `seq` du premier
message produit par ce coup, qui sert de curseur). Sans cette trace, le second appel serait rejeté
en `403` : le choix n'appartient plus au nœud courant, qui a avancé.

### Où le client doit appeler `continue`

Quand `node.can_continue` est vrai. Deux situations :

1. **`awaiting_interaction: true`** — le nœud est en pause sur une interaction cachée (N13, N16,
   N21). Le joueur qui n'interagit pas doit pouvoir poursuivre. Voir § Règle d'arrêt sur interaction.
2. **`ai_moment_pending: true`** — le moment IA (N9). Au prompt 3, la saisie libre appellera
   `ai-chat` ; en attendant, `continue` emprunte le fallback vers le N21.

## Fin de chapitre (N22)

`chapter_unlocked_at = now() + unlock_delay_minutes` du **chapitre suivant** (position + 1).
Le chapitre 2 est seedé comme **stub** : `position=2`, `title='Chloé'`,
`unlock_delay_minutes=480` (8 h, bible §9), `entry_node_id = null`, aucun nœud.

C'est ce qui permet au N22 de fonctionner sans chapitre 2 écrit : le compte à rebours a une cible
réelle, l'app affiche « Chapitre 2 : Chloé — disponible dans 8h », et le déblocage effectif
(`unlock-chapter`, prompt 4) constatera simplement qu'il n'y a pas encore de contenu à servir.
Le déblocage immédiat premium reste une décision serveur (`stories.is_premium` / achat), prompt 4.
