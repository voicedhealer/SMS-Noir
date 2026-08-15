ADDENDUM — Décisions UI tranchées (à intégrer dès la Phase 0)

Ces deux points ne sont plus en suspens. Ils reposent sur le même mécanisme, à concevoir comme tel.

Le champ de saisie décoratif

Le champ de saisie de la conversation est toujours actif, même quand aucun choix n'est proposé. Le joueur peut écrire et envoyer ce qu'il veut.

Ces messages s'affichent dans le fil, à droite, comme de vraies réponses du joueur.
Ils sont purement décoratifs : jamais envoyés au serveur, aucun effet sur l'histoire, aucune écriture en base côté contenu narratif. Ils sont persistés localement pour rester visibles dans l'historique après coup (relire ses propres messages paniqués une fois la tension retombée fait partie du plaisir).
Pendant les silences, ils s'affichent en état non délivré (une seule coche grise, ou aucune coche — à toi de proposer le rendu le plus crédible). Ils ne "passent" jamais.
Interdit : aucun feedback qui trahirait leur inutilité (pas de message d'erreur, pas de grisage, pas de "Léna ne peut pas répondre maintenant").
1. Le silence du N19 — occuper sans remplir

Aucune narration off, aucun overlay, aucun raccourcissement du délai. Le silence est le contenu de la scène ; l'expliquer ou l'abréger le détruit. Tout se joue avec les codes d'une vraie messagerie :

Le statut du contact passe de « en ligne » à « vu 00h29 » puis « hors ligne ». Rien d'autre, aucun texte explicatif.
Le joueur peut écrire (champ décoratif ci-dessus) : ses messages s'accumulent en non-délivrés. Il agit sur son angoisse au lieu de la subir.
Vers 45-50s : le typing indicator apparaît 2 secondes puis disparaît sans qu'aucun message n'arrive. Élément le plus important de la séquence. À rendre configurable côté client (le serveur n'a pas de notion de "faux typing" — propose le mécanisme le plus propre, éventuellement un message de type system invisible portant l'instruction, à arbitrer avec moi).
Vibration discrète unique vers 60s, sans notification.
2. Le geste de continuation — le même champ

Quand un nœud est en pause sur une interaction disponible (N13, N16, N21), le joueur continue en écrivant n'importe quoi dans le champ de saisie. Ce geste déclenche advance({continue: true}).

Aucun bouton « continuer » : il révélerait par sa présence qu'une interaction existe.
Le geste est celui d'une vraie conversation — tu réponds, ça avance.
Le message écrit s'affiche dans le fil (décoratif) avant que la suite ne se déroule.
Prévoir un fallback pour le joueur qui n'écrit rien et ne touche à rien : après un délai raisonnable (à proposer, ~20-30s), un affordance très discret apparaît. À documenter dans DESIGN.md.

Ces trois usages du champ de saisie (décoratif pendant les silences, geste de continuation, et plus tard saisie réelle des moments IA au Prompt 3) doivent partager le même composant, avec un mode explicite : decorative / continuation / ai_input. Documente ce composant et ses modes dans DESIGN.md — c'est la pièce d'UI la plus chargée de sens du projet.

Un point à surveiller quand il implémentera : le mode ai_input du Prompt 3 devra être visuellement identique aux deux autres. Si le champ change d'apparence quand l'IA écoute vraiment, le joueur comprend instantanément quels moments "comptent" — et il perd le doute qui rend le champ décoratif intéressant.