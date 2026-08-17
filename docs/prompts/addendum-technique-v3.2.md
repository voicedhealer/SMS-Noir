# ADDENDUM TECHNIQUE — Chapitre 1 V3.2

*À traiter après le re-seed de la V3.2. Sept ajouts, du plus structurant au plus simple.*

---

## 1. Écran noir narratif (N19)

Remplace l'attente passive de 60 secondes par une séquence plein écran.

**Déclenchement :** à l'entrée du silence du N19 (le `delay_seconds` du premier message du N20). L'app bascule de la conversation vers un écran noir plein écran, puis revient à la conversation à l'arrivée du message.

**Contenu (trois lignes, texte fourni par le contenu, pas en dur) :**
1. `Léna ne répond plus...`
2. `Il fait nuit, elle est seule, et vous êtes à des kilomètres. L'a-t-il enlevée ? Est-elle rentrée ?`
3. `Vous ne pouvez rien faire d'autre qu'attendre, ou prévenir la`

**Rythme :** ligne 1 immédiatement, ligne 2 à +20s, ligne 3 à +40s. La troisième ligne est **volontairement inachevée** — elle est coupée par le retour de Léna. Ne jamais la compléter, ne jamais la faire disparaître proprement : la coupure est l'effet.

**Où le stocker :** propose le mécanisme. Piste : un `content_type` dédié (`narration`) sur un message porteur, ou un champ sur le nœud. Il faut que ce soit du contenu, pas du code — les chapitres suivants en auront d'autres.

**Interaction :** aucune sortie possible, aucun bouton. Le champ de saisie décoratif reste-t-il accessible ? À arbitrer : le joueur devrait pouvoir continuer d'écrire ses messages non délivrés pendant l'écran noir, mais ça complique l'affichage. Propose.

---

## 2. Effet machine à écrire

Le texte de l'écran noir (§1) et celui de l'écran de fin de chapitre (§3) s'affichent caractère par caractère.

- Vitesse : ~45 ms par caractère. Pauses allongées sur les points de suspension (~400 ms).
- **Accessibilité** : la vitesse doit respecter le réglage « ralentir le rythme » des Réglages. Un tap affiche immédiatement la ligne en cours en entier, sans accélérer la séquence globale ni sauter les lignes suivantes.
- Ne s'applique qu'aux écrans narratifs, jamais aux bulles de conversation.

---

## 3. Écran de fin de chapitre — refonte

Le message système actuel devient une séquence en trois temps, même traitement que §1 et §2 :

> Quelqu'un est entré chez Léna.
> *(pause)*
> Quelqu'un sait qu'elle cherche.
> *(pause)*
> Et ce quelqu'un a désormais votre numéro.

Puis, après un temps :

> **La suite de Numéro Inconnu, prochainement.**
> *Un retour, une note, une idée ? Écrivez-nous.*

Puis le compte à rebours existant. Rappel : le bouton « Continuer maintenant » reste masqué tant que le premium n'existe pas.

---

## 4. Musique — trois segments d'un même morceau

Vivien fournit **trois fichiers découpés en amont** (plus fiable qu'un offset calculé — les durées d'écran peuvent bouger) :

| Segment | Où | Comportement |
|---|---|---|
| 1 | Séquence d'intro | Démarre au panneau 1, **coupure nette** à l'entrée dans la conversation |
| 2 | Écran noir du N19 | Reprend musicalement là où le segment 1 s'est arrêté, monte progressivement sans culminer, **coupure nette** au retour de Léna |
| 3 | Écran de fin de chapitre | Reprend là où le segment 2 s'est arrêté, joue **jusqu'au bout** — seul segment qui culmine |

Mêmes contraintes que la musique d'intro : catégorie `ambient`, respecte le mode silencieux, n'interrompt pas la musique de l'utilisateur, jamais en boucle. Champs de contenu paramétrables comme `stories.intro_music_url`.

---

## 5. Vibrations

Absentes aujourd'hui, à ajouter :

- **Vibration légère à l'arrivée de chaque message reçu**, uniquement lorsque le son est coupé (mode silencieux ou sons désactivés dans les Réglages). Comme une vraie messagerie.
- La vibration existante à 40s du silence N19 est conservée.
- **Aucune vibration** sur : messages décoratifs, typing fantôme, historique restitué, séparateurs. Mêmes exclusions que les sons — et de préférence par construction, pas par condition.
- À rendre désactivable dans les Réglages.

---

## 6. Prompt système du moment IA — révision

Trois modifications :

**a) Le prénom est demandé explicitement.** La réplique d'ouverture du N9 le demande directement. Le modèle doit extraire le prénom en priorité (catégorie `prenom`, déjà dans la liste d'autorisation) et **l'utiliser dans ses réponses suivantes** au cours du même échange.

**b) Tutoiement par défaut.** Léna tutoie à partir du N20. Le prompt doit refléter ça — et vouvoyer si `refus = true`, comme aujourd'hui.

**c) Le style change.** Les anciennes consignes (« phrases courtes », « ponctuation minimale », « ne dit jamais s'il te plaît ») produisaient un personnage sec et désagréable, qui a fait décrocher au test. Remplacer par les règles de la bible §2 révisée :

- Phrases construites, liées par des virgules. Pas de fragments empilés.
- Vulnérabilité avant mordant : elle vient de vivre une peur réelle, elle est reconnaissante, elle se confie.
- Elle remercie, elle s'excuse, elle reconnaît ce que le joueur lui apporte.
- L'humour ou la sécheresse ne sont que des réflexes de défense ponctuels, jamais la posture par défaut.

⚠️ Rejouer la sonde `probe-lena.py` après modification, et vérifier qu'aucune consigne ne nomme un interdit (règle établie en Prompt 3 phase 3).

---

## 7. Réécoute du vocal — précision sur le mécanisme

Confirmation du fonctionnement attendu au N17 : l'option « C'est quoi ce bruit derrière vous ? » **n'apparaît qu'à la deuxième écoute** du vocal. Un joueur qui écoute une fois et passe à la suite ne la verra jamais.

Vérifier que c'est bien ce qui est implémenté, et le documenter dans LOGIQUE.md — le mécanisme « un geste débloque une option » resservira aux chapitres suivants.

---

## Rappels sur ce qui ne change pas

- Le graphe est inchangé : 21 nœuds, mêmes transitions, mêmes indices, mêmes interactions cachées.
- La grammaire des trois axes et la formule de proportion sont inchangées.
- Les micro-choix ne ramifient jamais, `kind: "reply"` uniforme, le joueur ne doit jamais pouvoir détecter quand il est mesuré.
- Bible §2 à mettre à jour avec les nouvelles règles d'écriture (autorisation accordée, signalement explicite comme pour §3 et §6).
