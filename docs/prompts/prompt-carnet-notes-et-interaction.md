# PROMPT — Correction du geste d'interaction + Carnet de notes narratif

*À traiter comme une phase à part entière, Phase 0 d'audit comme d'habitude. Deux sujets liés : le premier corrige un défaut trouvé en jouant, le second est une nouvelle fonctionnalité qui en atténue les conséquences.*

## Contexte

Retour de test : le bouton « + » pour l'interaction du N16 (zoom sur l'autocollant) intrigue sans rien faire tant qu'on n'appuie pas dessus — confusion avec les boutons « + » d'ajout de pièce jointe des autres messageries. Deux causes distinctes à traiter séparément.

---

## 1. Bug — le zoom photo ne devrait jamais passer par le « + »

**Règle déjà établie, à ré-auditer** : une interaction cachée portée par un média (photo) se déclenche par un geste sur le média lui-même (tap pour zoomer), jamais par un bouton séparé. Le « + » est réservé aux interactions textuelles (relance, insistance) qui révèlent une ou deux options de réponse supplémentaires.

**Action** : vérifier N16 (zoom sur l'autocollant) et tous les autres nœuds à interaction média (N10, N21) — confirmer qu'ils déclenchent bien au tap sur l'image, sans bouton « + » associé. Si un « + » apparaît sur un nœud à interaction média, c'est un bug d'implémentation à corriger, pas une variante acceptable.

## 2. Refonte — l'affordance des interactions textuelles cachées

**Constat** : même correctement utilisé (uniquement pour les interactions textuelles comme N8-relance, N13-insister), le « + » évoque un bouton d'ajout de contenu dans l'esprit du joueur, ce qui n'est pas son rôle ici.

**Nouvelle affordance** : remplacer le bouton flottant « + » par une **quatrième option, visuellement plus discrète, mêlée aux choix normaux** — même emplacement que les choix structurants/micro-choix, mais dans un style visuellement atténué (texte plus petit, couleur plus sourde, pas de fond de bulle ou fond plus transparent). Elle reste facultative et non annoncée comme spéciale — elle se présente comme une option parmi d'autres, juste moins mise en avant, ce qui invite sans révéler qu'elle « débloque » quelque chose.

**Contrainte inchangée** : toujours à usage unique, toujours filtrée côté serveur comme aujourd'hui — seul l'habillage visuel change, pas le mécanisme.

Documente ce changement dans DESIGN.md, remplace toute mention du « bouton + » par la nouvelle description.

---

## 3. Nouvelle fonctionnalité — le carnet de notes narratif

**Objectif** : donner un sens tangible à l'exploration. Aujourd'hui, trouver un indice caché ne produit aucune trace visible pour le joueur après coup — ça n'encourage pas à chercher. Un carnet consultable comble ce manque, **sans jamais devenir un élément de jeu visible** (pas de score, pas de compteur, pas de liste des indices manquants).

### Nom et accès

Nom d'écran proposé : **« Ce qu'on sait »**. Accessible via une icône discrète dans l'**en-tête de la conversation** (pas dans la liste des conversations, où vit déjà l'icône Réglages — les deux ne doivent jamais être confondues). Une icône simple type carnet/liste, sobre, cohérente avec le reste de l'identité visuelle.

### Contenu et règles strictes

- **Uniquement les indices concrets déjà trouvés** (objets, faits recueillis) — jamais les variables numériques (`confiance`, `lucidite`, `enquete`), jamais un compteur de progression (« 3/6 »), jamais de placeholder pour un indice non encore trouvé.
- **Si rien n'est trouvé** : un texte simple, style « Rien de noté pour l'instant. » — pas de « 0/6 ».
- **Persiste sur toute l'histoire**, pas seulement le chapitre en cours — les indices du ch.1 resserviront aux ch.3-4.
- **Ne contient jamais** les moments IA (souvenirs, confidences) ni les incohérences/doutes narratifs — uniquement les indices factuels listés ci-dessous. La distinction est volontaire : le carnet documente l'enquête, pas la relation.
- **Source de données** : la liste `indices` déjà présente dans `player_progress.variables` — aucune nouvelle logique de jeu à inventer, seulement un écran de lecture qui affiche ces codes avec leur texte narratif associé (fourni ci-dessous, à stocker comme contenu — pas en dur dans le Dart).

### Textes des 5 indices du chapitre 1 (contenu final, à intégrer tel quel)

| Code | Texte à afficher dans le carnet |
|---|---|
| `PROFIL_SUSPECT` | Un homme, la cinquantaine. Toujours seul, toujours le jeudi. Il regarde autour de lui avant d'entrer. |
| `BORNAGE` | Le dernier signal du téléphone de Chloé a borné à 400 mètres de l'entrepôt Verdier. |
| `AUTOCOLLANT` | Un macaron sur la vitre arrière de sa voiture : Sentinel Pro. |
| `PLAQUE` | Une Peugeot 508 grise. Plaque partielle : ...843... |
| `TELEPHONE` | Un téléphone à coque rose, abandonné sur un établi. Chloé avait exactement le même. |

Ton volontairement bref et factuel, comme une note prise rapidement — pas une fiche encyclopédique. Ordre d'affichage : chronologique, dans l'ordre où le joueur les a découverts (pas un ordre fixe imposé).

### Le mécanisme « tu lis quoi ? » — à intégrer, pas à reporter

Correction par rapport à une première lecture trop prudente : ce n'est pas un nouveau mécanisme à inventer, c'est une question **déjà présente dans le dialogue du N16** qui n'a aujourd'hui aucune fonction :

> 🔍 « Il y a un autocollant sur la vitre arrière. » → *« Oui, mais je n'arrive pas à le lire d'ici, et vous ? »*

Léna demande déjà au joueur ce qu'il voit. Il s'agit de brancher le champ de saisie sur ce moment précis plutôt que de laisser la question sans suite fonctionnelle.

**Décision de conception : ne jamais valider le contenu de la réponse.** N'importe quel texte tapé par le joueur à ce moment déclenche l'indice `AUTOCOLLANT` — qu'il ait écrit « Sentinel Pro », une faute de frappe, une devinette fausse, ou même « je sais pas ». Ce qui compte narrativement, c'est le geste de répondre à Léna comme un vrai interlocuteur, pas l'exactitude du mot. Exiger une réponse correcte pénaliserait les fautes de frappe et les variantes sans aucun bénéfice — et nécessiterait une validation de texte libre côté serveur qu'on a toujours évitée pour le champ décoratif.

**Comportement attendu** :
- Le joueur peut toujours ignorer la question et continuer sans répondre (le geste de zoom seul suffit à débloquer l'indice, comme aujourd'hui) — cette réponse textuelle est un mode de déclenchement supplémentaire, pas un remplacement obligatoire.
- S'il répond, Léna peut accuser réception brièvement avant d'enchaîner sur la suite du nœud (texte à écrire séparément si retenu — signale-le-moi, je fournirai la réplique).
- Le texte tapé par le joueur n'est jamais renvoyé au serveur pour validation de contenu — seul le fait qu'une réponse ait été envoyée à ce moment précis compte comme signal de déclenchement.

Documente ce pattern comme réutilisable : d'autres nœuds à venir (ch.3-5) pourraient avoir le même type de question ouverte dans leur dialogue existant, à repérer plutôt qu'à toujours construire un bouton séparé.

## Phase 0 — Audit attendu

Vérifier l'état actuel des interactions média vs texte dans le code existant, confirmer où vit la liste `indices` en base, et signaler si `player_progress.variables` est le bon endroit pour lire ces données ou s'il faut une projection dédiée pour cet écran (probablement via `get-state`, à ne jamais exposer les autres nœuds/graphe comme toujours).
