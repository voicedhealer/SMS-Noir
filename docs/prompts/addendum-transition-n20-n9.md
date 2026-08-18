# ADDENDUM — Transition N20→N9, tutoiement déplacé, corrections d'affichage

*Suite au premier test complet de la V3.2 sur appareil. Plusieurs corrections, de la plus structurante à la plus simple.*

---

## 1. Restructuration N20 / transition / N9 — le tutoiement change de place

**Constat du test** : le tutoiement et le remerciement arrivaient au N20, immédiatement après le retour de l'entrepôt — trop tôt. Léna vient de trembler, pleurer, avoir peur : ce n'est pas le moment de renégocier une intimité. Le passage sonnait précipité.

**Le N20 redevient sobre**, vouvoiement conservé, uniquement le retour et l'état de choc :

> C'est bon, je suis dans ma voiture, il ne m'a pas vue... enfin je crois, je vois une ombre, c'est quoi ! ... oula c'était juste un animal et la lune, il faut que je redescende en émotion car je deviens parano.

**Micro-choix inchangés** (protéger/enquêter/raisonner déjà validés).

**Choix structurant inchangé** : « Rentre chez toi, on fait le point demain. » / « Il faut porter ça à la police, maintenant. » → mène désormais vers l'écran de transition (§2), pas directement vers N9.

**Le tutoiement, le remerciement et la demande de prénom se déplacent ensemble à l'ouverture du N9**, une fois qu'elle est vraiment posée chez elle :

> Je suis rentrée, je respire un peu mieux... Ça vous dérange si l'on se tutoie ? Après ce qu'on vient de vivre, le « vous » me paraît un peu ridicule, qu'en penses-tu ?
>
> Et merci pour cette présence, même à distance, ça me donne de la force, ce dont j'avais grand besoin.
>
> Dis... je ne sais rien de toi, même pas ton prénom...

⚠️ **Le glissement vouvoiement → tutoiement dans la première phrase est volontaire** (« Ça vous dérange » puis « qu'en penses-tu »). Ne pas l'harmoniser, ne pas le "corriger" — c'est le moment même de la bascule, elle hésite en le disant. Le tutoiement s'applique pleinement à partir de la phrase suivante et pour tout le reste du chapitre.

*(Reste inchangé : `refus = true` maintient le vouvoiement intégral, y compris dans ce nœud — adapter la formulation en conséquence si nécessaire, ex. « Ça ne vous dérange pas si je continue à vous vouvoyer, je crois que j'en ai besoin ce soir. »)*

Le prompt système du moment IA (Prompt 3) doit être vérifié en cohérence : il suppose déjà le tutoiement par défaut à l'entrée du N9, ce qui reste vrai — seul le contenu du message d'ouverture change.

---

## 2. Écran de transition N20 → N9 — fixer le lieu et le temps

**Constat du test** : rien ne signale au joueur que Léna a quitté sa voiture pour rentrer chez elle. Le saut de lieu est invisible, ce qui laisse penser qu'elle est toujours dans sa voiture au moment du tutoiement.

**Solution** : un écran de transition vidéo bref entre N20 et N9, même famille que l'écran noir narratif du N19 (§1 de l'addendum précédent) mais avec un fond vidéo plutôt qu'un fond noir pur.

**Média fourni** : `lena-rentre-chez-elle.mp4` (~8s, plan sur une silhouette féminine vue de dos entrant dans un hall d'immeuble la nuit, le visage n'apparaît jamais, finit sur un flou progressif). Fichier joint séparément.

**Traitement demandé** :
- Vidéo en fond plein écran, muette (le son doit être retiré du fichier source ou coupé à la lecture — à vérifier lequel des deux est déjà fait).
- Texte incrusté sur la fin de la vidéo, au moment du flou : **« Léna rentre chez elle. »** — même traitement machine à écrire que les autres écrans narratifs, ou fondu simple si le calage est plus simple techniquement.
- Musique narrative existante en fond (le segment déjà utilisé pour les transitions, ou silence si aucun segment n'est prévu à cet endroit — à trancher selon ce qui est disponible).
- Aucune interaction possible pendant la lecture, pas de bouton skip visible (même logique que l'écran noir : c'est un sas, pas un menu).
- À la fin (vidéo + texte), transition automatique vers la conversation, entrée dans le N9.

**Stockage** : suivre le même modèle que les autres médias narratifs (`content_type` dédié ou équivalent déjà en place pour l'écran noir du N19) — c'est du contenu, pas une propriété codée en dur du nœud.

---

## 3. Corrections d'affichage remontées en jouant

Cinq points distincts, tous constatés sur appareil réel :

**3.1 — Visionneuse photo : cadre fixe autour du zoom.** En plein écran, l'image est actuellement contenue dans un cadre qui garde sa taille d'origine, le zoom s'appliquant à l'intérieur de ce cadre — d'où une bande visible autour de l'image agrandie. Attendu : l'image occupe tout l'écran en plein écran (fond noir uniforme, aucune bordure), et le pinch-to-zoom s'applique directement sur l'image, centré sur le point de pincement. Comportement de référence : visionneuse photo standard (iMessage, WhatsApp).

**3.2 — Horodatage incrusté dans les bulles photo/audio.** L'addendum précédent (heure sous la bulle, un seul horodatage par groupe) a été appliqué au texte mais pas aux médias — l'heure reste en surimpression dans le coin de l'image. Harmoniser : même traitement que le texte, heure sous le média, un seul par groupe.

**3.3 — Le clavier masque les choix actifs.** Quand des choix (structurants ou micro-choix) sont affichés et que le joueur tape sur le champ de saisie, le clavier prend l'écran et pousse les choix hors du cadre visible (parfois jusqu'à couper le premier choix sous la barre de titre). Attendu : l'ouverture du clavier ne doit jamais masquer des choix actifs — soit le contenu défile pour garder les choix visibles au-dessus du clavier, soit une autre solution équivalente. Le joueur ne doit jamais perdre sa position ni les options affichées en ouvrant simplement le champ.

**3.4 — Les choix apparaissent avant que le joueur ait fini de lire.** Ajouter un court délai (1-2s selon la longueur du dernier message, à ajuster en jouant) après l'affichage du dernier message avant que les choix ne deviennent actifs/cliquables. Pas de bouton ni d'indicateur visible qui signalerait ce délai — le joueur doit juste se sentir moins bousculé, sans comprendre mécaniquement pourquoi.

**3.5 — Perte de position pendant la lecture.** Quand le joueur remonte manuellement dans le fil pour relire, l'arrivée de nouveaux messages ou choix ne doit pas le ramener automatiquement en bas. Défilement auto désactivé tant que l'utilisateur n'est pas déjà proche du bas du fil.

**Contrainte commune à 3.3, 3.4, 3.5** : aucune solution ne doit introduire de bouton explicite type "Répondre maintenant" ou "Continuer" — cela révélerait au joueur qu'un choix approche, ce qui casse le principe déjà établi (jamais d'indicateur distinguant un moment "mesuré" d'un moment normal, jamais d'élément qui trahit qu'une interaction cachée existe).

---

## 4. Point à vérifier séparément, non résolu

Sur le nœud N13 (« Pourquoi moi ? »), une capture antérieure montrait le bouton "+" (interaction cachée « insister ») visible sans qu'aucun choix de réponse classique ne s'affiche en dessous. Vérifier si c'est le comportement attendu à ce nœud (les choix normaux arrivent après l'interaction) ou un défaut d'affichage distinct des points 3.3/3.4 ci-dessus.

---

## Rappel de ce qui ne change pas

Le reste du graphe, la grammaire des trois axes, les indices, les 6 interactions cachées et leurs emplacements (y compris le déplacement N10→N8 déjà traité), le prompt système du moment IA (sauf vérification de cohérence avec §1), et tous les autres écrans narratifs sont inchangés.
