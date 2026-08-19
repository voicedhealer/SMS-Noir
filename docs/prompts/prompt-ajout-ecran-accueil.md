SPEC — Écran d'entrée (avant la séquence d'intronisation)

Nouveau premier écran de l'app, avant tout le reste (avant même le panneau "Jeudi 13 août 2026"). C'est la "pochette" de l'histoire.

Structure
Moitié supérieure de l'écran : image de couverture (asset fourni séparément : cover-numero-inconnu.png, silhouettes illustrées style line-art gris).
Dégradé de fondu : linear-gradient appliqué en overlay sur le tiers inférieur de l'image, de transparent à noir plein, pour que les silhouettes se dissolvent progressivement dans le fond noir de l'écran plutôt que de s'arrêter net sur un bord.
Icône de l'app (bulle "?" déjà produite), petite, centrée, à la jonction entre l'image et le texte.
Titre : "Numéro inconnu" — blanc plein, 22-24px, poids 500.
Accroche : "Un mauvais numéro, une inconnue en danger, une nuit que vous ne choisirez pas." — gris clair (--text-secondary ou équivalent), 13-14px, centré, sur fond noir uni (pas sur l'image) pour garantir la lisibilité.
Case de consentement IA : checkbox + texte "J'accepte que certains de mes échanges soient traités par une IA pour personnaliser l'histoire." avec "Politique de confidentialité" en lien souligné. Texte en gris clair nettement contrasté (--text-secondary minimum, jamais plus sombre), sur fond noir uni. Case non cochée par défaut.
Bouton "Entrer" : blanc plein, texte noir, pleine largeur, en bas de l'écran.
Comportement du consentement
Le bouton "Entrer" est toujours actif, coché ou non — jamais bloqué par ce choix.
Si non coché → tous les futurs ai_moment du parcours basculent silencieusement sur leur fallback, sans jamais le signaler pendant l'histoire (mécanisme déjà en place).
L'état de la case est mémorisé (comme le reste de la progression), l'écran n'apparaît qu'une fois — pas à chaque relance de l'app.
Animation d'entrée

Au chargement de cet écran (une seule fois, à froid) :

L'image de couverture apparaît avec un effet de fondu léger doublé d'un flou qui se dissipe — l'image commence légèrement floue/désaturée et se stabilise nette en ~600-800ms. Donne une impression de mise au point, comme un souvenir qui se précise.
Le titre, l'accroche et le bouton apparaissent en fondu séquentiel après l'image (léger décalage de 100-150ms entre chacun), pas tous d'un coup.
Rien de clignotant ni de répétitif — c'est une entrée unique, jouée une fois, jamais en boucle.
Respecte le réglage d'accessibilité "réduire les animations" : dans ce cas, tout apparaît directement, sans transition.
Asset

Le fichier cover-numero-inconnu.png sera fourni séparément (illustration line-art déjà produite, silhouettes sur fond sombre). Le code ne doit pas le fusionner avec le texte — l'image reste un calque de fond indépendant, avec le dégradé et les éléments d'interface posés par-dessus en overlay, exactement comme le mockup partagé.

Point d'architecture

Cet écran est spécifique à l'histoire (stories.cover_url, stories.tagline si pas déjà en base) — pas codé en dur, pour pouvoir resservir avec les futures histoires de la bibliothèque.

Ça devrait lui donner tout ce qu'il faut pour construire l'écran, animer l'entrée, et garantir la lisibilité qui posait problème sur les deux versions précédentes.