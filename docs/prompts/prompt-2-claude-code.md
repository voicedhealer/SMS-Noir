PROMPT 2 — CLAUDE CODE : Application Flutter « Numéro Inconnu »

Tu vas construire l'application Flutter qui consomme le moteur narratif livré au Prompt 1. L'app est un client mince : elle ne contient AUCUN contenu narratif, ne connaît pas le graphe, et ne décide de rien. Elle affiche ce que le serveur envoie et joue les timers.

RÈGLES ABSOLUES
Aucun code avant la fin de la Phase 0. La Phase 0 est un audit, rien d'autre.
Les docs du repo font autorité : docs/LOGIQUE.md (contrat des functions, règle d'arrêt sur interaction, contraintes client), docs/ARCHITECTURE.md, docs/bible-narrative.md (lecture seule, jamais modifiée), docs/TODO.md (points d'entrée du prompt 2).
À chaque fin de phase : STOP. Résumé + docs à jour + attente de ma validation explicite.
Documentation vivante obligatoire. DESIGN.md devient un vrai document en Phase 1 (il n'était qu'un squelette). ARCHITECTURE.md, LOGIQUE.md, MEMOIRE.md, TODO.md maintenus à chaque phase. Une phase sans docs à jour est une phase non terminée.
Contraintes client non négociables (elles préservent l'anti-spoiler et l'intégrité de l'état) :
Le client n'écrit JAMAIS dans player_progress ni player_messages. Tout passe par get-state / advance.
Le client ne lit JAMAIS nodes, messages, choices, chapters, contacts en direct.
Le client ne fait jamais confiance à un état local : la vérité vient de get-state. Une écriture interdite échoue silencieusement (UPDATE 0, aucune exception) — ne jamais interpréter l'absence d'erreur comme un succès.
Le client ne calcule aucune variable, n'applique aucun effect, ne teste aucune condition. Il ne les reçoit même pas.
Aucune clé de service dans l'app : uniquement l'anon key + auth utilisateur.
Zéro contenu narratif en dur. Pas un texte de Léna, pas un libellé de choix, pas un nom de contact dans le code Dart.
STACK

Flutter (dernière stable), Dart null-safe · supabase_flutter · Riverpod (justifie si tu proposes autre chose) · iOS + Android, portrait uniquement · backend local via supabase start.

L'EXPÉRIENCE À PRODUIRE

L'app doit être indiscernable d'une vraie messagerie. C'est le cœur du produit : si l'illusion casse, l'histoire ne fonctionne plus. Trois écrans.

Écran 1 — Liste des conversations. Avatar, nom, dernier message, horodatage, pastille de non-lus. Une seule conversation au chapitre 1, mais architecture multi-conversations dès maintenant (twist chapitre 4 : second puis troisième contact, et une conversation de groupe). Le nom affiché vient du serveur (display_name_initial → display_name) : Léna s'affiche « Numéro inconnu » jusqu'à ce qu'elle se nomme, puis bascule. Cette bascule doit être visible et un peu marquante — c'est un micro-événement narratif, pas un détail technique.

Écran 2 — Conversation (le cœur).

Bulles reçues à gauche, réponses joueur à droite. Densité et typo d'une vraie messagerie.
Typing indicator pendant typing_seconds avant chaque message reçu. Le doc prévoit par endroits un typing intermittent (apparaît/disparaît deux fois, ex. N2) — propose un mécanisme et documente-le.
Séparateurs horaires (content_type='separator') : pastille centrée, libellé exact du serveur (« 23h31 »). Discrets mais lisibles.
Photos : miniature dans le fil, zoomables en plein écran — le zoom est une mécanique de jeu (3 des 6 interactions cachées), pas un confort de lecture.
Note vocale : lecteur inline, réécoutable (la réécoute est une interaction cachée).
Zone de choix en bas. Le bouton kind='ignore' est visuellement distinct (plus effacé) — c'est un vrai choix, jamais un timeout.
Défilement auto vers le bas, retour possible dans l'historique.

Écran 3 — Fin de chapitre. Sortie du fil, plein écran : message system du N22, titre du chapitre suivant, compte à rebours vers chapter_unlocked_at (purement décoratif, seul le serveur débloque). Prévoir la place d'un futur bouton premium (non fonctionnel ici).

LES DEUX MÉCANIQUES DÉLICATES

A — Le déroulé temporel. advance renvoie des messages avec delay_seconds et typing_seconds. Le client les joue séquentiellement ; pendant le déroulé, les choix ne sont pas affichés. Cas obligatoires :

App fermée/arrière-plan pendant un déroulé : à la réouverture, get-state fait foi. Messages déjà joués = historique (délais 0, instantané) ; le reste est repris. Jamais de timers rejoués, jamais de message perdu.
Silences longs : jusqu'à 90s au chapitre 1 (N19, « Léna est hors ligne »). Le statut de présence fait partie de la tension — propose comment le rendre.
Bouton skip de développement (debug uniquement, absent en release). Indispensable, tu vas tester ce flux des dizaines de fois.

B — Les interactions cachées (règle d'arrêt). Voir docs/LOGIQUE.md, déjà formalisée avec ses 4 contraintes UI. Besoin :

Découvertes, jamais annoncées : pas de bouton « interaction ici ». Un zoom, une réécoute, une relance discrète.
Atteignables sans frustration : latence perceptible avant de pouvoir continuer, affordance subtil (la photo invite au tap, un « + » discret pour la relance N8).
Usage unique : consommée, elle disparaît (le serveur filtre via interactions_faites, le client ne la ré-propose pas).
Le joueur qui ne veut pas interagir continue via {continue: true} — le geste est une des trois décisions UI en suspens : propose et argumente.
DIRECTION VISUELLE

Sombre, sobre, crédible. Ce n'est pas une app de jeu : aucun élément ludique visible (pas de score, pas de barre de progression, pas de badge). On doit pouvoir jeter un œil à l'écran dans le métro et croire à de vrais SMS.

Palette sombre (thriller nocturne) · une seule couleur d'accent discrète pour les bulles du joueur · typographie système (SF Pro / Roboto), c'est ce qui vend l'illusion · aucune animation gratuite — seules comptent l'arrivée d'un message, le typing, et la bascule d'identité · les variables (confiance, lucidite, indices) ne sont JAMAIS affichées, elles n'existent pas pour le joueur.

Documente tout dans DESIGN.md : palette exacte, échelle typo, espacements, composants. Ce fichier doit permettre de reconstruire l'UI sans toi.

PHASE 0 — AUDIT (aucun code)
Lis docs/LOGIQUE.md (contrat exact, payloads, 8 codes d'erreur, idempotence, continue), ARCHITECTURE.md, TODO.md (points d'entrée + 3 décisions UI), DESIGN.md, bible-narrative.md §9.
Vérifie l'environnement : Flutter et version, Xcode/Android SDK, supabase start, functions en local, émulateur.
Appelle réellement get-state et advance en local (curl ou script), documente les payloads observés, confirme que le contrat correspond à la réalité, signale tout écart.
Établis le mapping réponse serveur → widget : chaque content_type, chaque kind de choix, chaque état de nœud (ai_moment_pending, chapter_end, nœud en pause sur interaction). Identifie les cas non couverts.
Prends position sur les 3 décisions UI en suspens de TODO.md : propose, argumente, ne tranche pas seul.
STOP.
PHASE 1 — SQUELETTE, MODÈLES, CLIENT API

Projet Flutter, arborescence claire (lib/models, services, providers, screens, widgets, theme) · modèles Dart typés depuis le contrat réel (pas depuis le schéma SQL — le client ne voit qu'une projection) · service d'appel : getState(), advance(choiceId), advance(continue:true), gestion des 8 codes d'erreur, timeouts, retry raisonnable, idempotence respectée (un double-tap ne double-avance pas) · auth Supabase (anonyme suffit pour le MVP, argumente sinon) · thème complet + DESIGN.md rédigé. STOP.

PHASE 2 — ÉCRAN DE CONVERSATION

Fil de messages (bulles, séparateurs, photos + visionneuse zoomable, lecteur audio réécoutable, message système) · moteur de déroulé temporel (file séquentielle, délais, typing intermittent, scroll auto, reprise propre après arrière-plan) · zone de choix (reply/ignore, désactivée pendant le déroulé, anti-double-tap) · bouton skip debug · widget-tests sur le déroulé (ordre, timings, reprise), pas seulement du visuel. STOP.

PHASE 3 — INTERACTIONS CACHÉES, LISTE, FIN DE CHAPITRE

Les 6 interactions du chapitre 1 (zoom N10/N16/N21, réécoute N17, relance N8 à 2 questions exclusives, insistance N13), découvertes et non annoncées, usage unique, avec le geste de continuation retenu en Phase 0 · écran liste multi-conversations avec bascule d'identité · écran de fin + compte à rebours · recette manuelle : les deux parties (« allié » et « refus ») jouées en entier sur émulateur, les 6 interactions atteignables, le prénom révélé sur les trois branches, et rien ne casse en tuant l'app au milieu du N19. STOP.

HORS PÉRIMÈTRE

ai-chat et saisie libre du N9 (Prompt 3 — le N9 se traverse via continue) · notifications, cron de déblocage, premium (Prompt 4) · médias réels (placeholders placeholder:// en base : prévois un fallback d'affichage propre) · chapitres 2 à 5.

Deux points sur lesquels je serais attentif à sa Phase 0 : sa proposition pour le geste de continuation (c'est la décision la plus délicate — trop visible, l'interaction cachée devient un bouton ; trop discrète, le joueur reste bloqué), et sa façon de rendre « Léna est hors ligne » pendant les 90 secondes du N19. Ce sont les deux endroits où l'UI peut faire ou défaire la tension que le contenu a construite.