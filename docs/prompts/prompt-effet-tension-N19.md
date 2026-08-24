# PROMPT — Effet de tension N19 : bordure rouge + battement de cœur

## Contexte

Le N19 (l'incident — Denis qui sort, croise le regard de Léna) est le pic de tension physique du chapitre 1. Aujourd'hui, rien ne distingue visuellement ou sonorement ce moment des autres échanges. Ajout d'un renforcement sensoriel, strictement borné à ce nœud.

## Portée exacte

Le traitement s'applique **du premier message du N19 (« il sort, de l'entrepôt... ») jusqu'au dernier (« merde »)**, micro-choix compris. Il s'arrête net à l'entrée de l'écran noir narratif qui suit — ne pas le prolonger dans le silence des 60 secondes, qui a déjà son propre traitement (musique, texte).

Nœuds concernés : uniquement les messages et micro-choix du N19 lui-même, pas N18 (avant) ni l'écran noir (après).

## 1. Effet visuel — bordure rouge + overlay

**Bulles concernées** : tous les messages de Léna affichés pendant le N19 (les deux blocs), pas les bulles du joueur.

**Traitement** :
- Une bordure fine rouge autour de chaque bulle de Léna pendant cette séquence (couleur à définir dans la palette existante — un rouge sourd, pas un rouge vif de type alerte système, cohérent avec le reste de l'identité sombre de l'app).
- Un overlay rouge très transparent à l'intérieur de la bulle, en fond, **suffisamment léger pour ne jamais gêner la lecture du texte** — c'est une contrainte non négociable, le texte doit rester parfaitement lisible.

**Ce que ça ne doit pas faire** :
- Ne pas affecter les bulles déjà affichées avant le N19 quand on remonte le fil (l'effet est local à ce nœud, pas un changement de thème global).
- Ne pas clignoter ni pulser — un effet fixe, pas une animation qui distrairait de la lecture dans un moment déjà chargé en urgence.
- Ne pas s'appliquer aux bulles du joueur, aux séparateurs, ni au statut de présence.

## 2. Bruitage — battement de cœur

**Fichier fourni séparément** : `heartbeat-x2.5.mp3` — version accélérée du bruitage de cœur (pitch préservé, ×2.5 par rapport à l'original), retenue après écoute comparative de cinq variantes.

**Comportement** :
- Démarre au premier message du N19, s'arrête net à la fin du nœud (dernier message « merde »), avant la transition vers l'écran noir.
- **En boucle** pendant toute la durée du nœud (le fichier accéléré dure moins de 9 secondes, le nœud dure plus longtemps avec ses micro-choix — prévoir un bouclage propre, sans coupure audible au raccord).
- Volume modéré, en fond — ne doit jamais couvrir les sons de message ni gêner la lecture.
- Mêmes contraintes que tout le système sonore déjà en place : catégorie `ambient`, respecte le mode silencieux, coupure nette (pas de fondu) à la sortie du nœud — cohérent avec la règle déjà appliquée à `MusiqueNarrative`.
- **Déclenche l'indicateur sonore visuel** (icône haut-parleur, déjà spécifiée dans un précédent prompt) comme tout autre son narratif.

**Stockage** : même modèle que les autres médias sonores du chapitre — un champ de contenu associé au nœud N19, pas une valeur codée en dur, pour rester cohérent avec le principe déjà établi partout ailleurs.

## Phase 0 — Audit attendu

Vérifier comment les bulles sont actuellement stylées pour confirmer la meilleure façon d'appliquer un style conditionnel par nœud sans dupliquer le composant de bulle. Vérifier le mécanisme de bouclage audio déjà utilisé (s'il y en a un) avant d'en écrire un nouveau.

## Fichiers

`heartbeat-x2.5.mp3` fourni en pièce jointe — pitch préservé, généré par accélération temporelle (`atempo`), pas par simple changement de vitesse de lecture.
