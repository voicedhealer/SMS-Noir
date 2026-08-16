# NUMÉRO INCONNU — Chapitre 1 V3.1 : Le mauvais numéro

**Ce qui change vs V3 :** les micro-choix suivent désormais une grammaire constante à trois axes — **Protéger · Enquêter · Raisonner** — chacun alimentant faiblement une variable. L'intrigue, les 6 interactions cachées, les 4 incohérences, le moment IA et les indices restent inchangés.

---

## LA GRAMMAIRE DES TROIS AXES

Chaque micro-choix propose **exactement trois options**, une par axe. Toujours dans le même ordre : protéger, enquêter, raisonner.

| Axe | Ce que le joueur fait | Effet | Alimente |
|---|---|---|---|
| 🛡 **Protéger** | Il s'inquiète pour elle, la met en garde, la rassure | `confiance +0.5` | Fins « la sauver » |
| 🔍 **Enquêter** | Il creuse, demande des détails, cherche avec elle | `enquete +0.5` (→ indices) | Options d'enquête ch. 4-5 |
| 🧠 **Raisonner** | Il prend du recul, doute, questionne la logique | `lucidite +0.5` | Fin cachée |

**Règles absolues :**

1. **Raisonner n'est jamais puni.** Douter ne fait jamais baisser la `confiance`. Un joueur qui doute est un bon joueur — il trouve les incohérences. Le punir l'entraînerait à ne plus douter, et il raterait la fin cachée.
2. **Les effets sont faibles (+0.5).** C'est le **motif** sur tout le chapitre qui compte, pas l'occurrence. Vingt micro-choix ne doivent pas saturer les compteurs.
3. **Aucun micro-choix ne ramifie.** Même `next_node_id` pour les trois options. Seule la réplique suivante de Léna varie.
4. **Les trois options sonnent comme de vrais messages.** Courts, parfois sans majuscule ni ponctuation dans l'urgence. Jamais des libellés de menu.
5. **Les choix structurants (12) restent inchangés** et gardent leurs effets forts. La grammaire ne s'applique qu'aux micro-choix.

**Ce que ça produit :** un joueur qui protège systématiquement arrive au ch. 5 avec une Léna qui lui fait totalement confiance mais sans avoir rien vu venir. Celui qui raisonne à chaque fois aura repéré toutes les incohérences, mais moins de complicité. Personne ne lui aura jamais dit qu'il jouait une variable — il aura juste été lui-même.

**Nouvelle variable :** `enquete` (0-10, départ 0). Aux paliers 4 et 8, elle débloque des options d'enquête aux ch. 4-5. Distincte de `indices` (liste d'objets trouvés) : `enquete` mesure la posture, `indices` les découvertes.

**Délais V3.1 :** 3-8s en conversation, 15-25s pour une hésitation ou une ellipse, un seul long silence (N19, 60s).

---

## SÉQUENCE D'OUVERTURE

### N1 — Le premier message
*Séparateur : « jeudi — 22h47 »*

⏱ 4s
**[Léna]** C'est bon. J'ai trouvé où il la garde.
⏱ 5s
**[Léna]** J'y vais ce soir. Si t'as pas de nouvelles de moi avant 2h du mat, tu sais quoi faire.

**CHOIX STRUCTURANT :**
- A. « Je crois que vous vous trompez de numéro » → N2
- B. « Qui ça, "elle" ? » → N3 *(confiance +1)*
- C. [Ignorer] → N4

### N2 — L'erreur
⏱ 20s *(typing intermittent)*
**[Léna]** Merde.
⏱ 4s
**[Léna]** Merde merde merde. C'est pas le numéro de Karim ?

**MICRO-CHOIX :**
- 🛡 « Vous allez bien ? » → *« Non. Pas vraiment. »*
- 🔍 « Qui est Karim ? » → *« Personne. Enfin si. Mais c'est pas le sujet. »*
- 🧠 « Vous envoyez ça à n'importe qui ? » → *« Une chance sur deux. J'ai perdu. »*

⏱ 4s
**[Léna]** Putain. Un chiffre. J'ai raté d'un chiffre.

**CHOIX STRUCTURANT :**
- A. « Votre message était inquiétant. Ça va ? » → N5 *(confiance +1, branche = "empathie")*
- B. « Bonne soirée » → N6

### N3 — Tu joues le jeu
⏱ 12s
**[Léna]** Attends
⏱ 5s
**[Léna]** T'es pas Karim.

**MICRO-CHOIX :**
- 🛡 « Non. Mais votre message m'inquiète. » → *« Il devrait pas. C'est pas ton problème. »*
- 🔍 « Pourquoi, j'écris comme lui ? » → *« Non. Justement. »*
- 🧠 « Vous en êtes sûre après un seul message ? » → *« Certaine. Il aurait déjà appelé. »*

⏱ 5s
**[Léna]** Karim me demanderait jamais ça. T'es qui ?

**CHOIX STRUCTURANT :**
- A. « Quelqu'un qui a reçu votre message par erreur. Et qui s'inquiète, là » → N5 *(confiance +1, branche = "empathie")*
- B. « Et vous, c'est quoi cette histoire ? » → N7 *(branche = "curieux")*

### N4 — Ignoré
*Séparateur : « 23h02 »* ⏱ 15s
🔔 PUSH
**[Léna]** Karim ?
⏱ 6s
**[Léna]** Réponds, c'est pas le moment de me lâcher.

**MICRO-CHOIX :**
- 🛡 « Ce n'est pas Karim. Mais il se passe quoi ? » → *« Rien qui te regarde. Désolée. »*
- 🔍 « Vous attendez quoi de lui exactement ? » → *« Qu'il décroche. Comme d'hab, non. »*
- 🧠 « Vous vous trompez de numéro. » → *« Évidemment. »*

⏱ 8s
**[Léna]** Une chance sur deux avec ce foutu nouveau tel.

**CHOIX STRUCTURANT :**
- A. « C'est quoi cette histoire ? » → N7 *(branche = "curieux")*
- B. « Vous devriez vérifier vos numéros avant d'envoyer ce genre de trucs » → N6 *(lucidite +1)*

### N5 — Elle se livre
⏱ 15s
**[Léna]** Désolée. J'aurais jamais dû envoyer ça à un inconnu.
⏱ 6s
**[Léna]** C'est ma sœur. Chloé. Elle a disparu il y a 7 mois.

**MICRO-CHOIX :**
- 🛡 « Je suis désolé. » → *« Ouais. Tout le monde l'est. »*
- 🔍 « Disparu comment ? » → *« Un soir elle était là. Le lendemain non. Son sac est resté. »*
- 🧠 « Et la police n'a rien fait ? » → *« J'y viens. »*

⏱ 6s
**[Léna]** La police a classé. "Départ volontaire". Mon cul.
⏱ 10s
**[Léna]** Moi c'est Léna, au passage. Puisqu'on en est là.

*(→ carte d'enregistrement du contact)*
→ N8

### N6 — Elle décroche... presque
⏱ 12s
**[Léna]** Ouais. Désolée du dérangement.
*Séparateur : « 23h18 »* ⏱ 25s
🔔 PUSH
**[Léna]** En fait non. J'ai personne d'autre.

**MICRO-CHOIX :**
- 🛡 « Je vous écoute. » → *« Merci. »*
- 🔍 « Personne pour quoi ? » → *« Pour savoir où je suis. Ce soir. »*
- 🧠 « Il est presque minuit, vous savez. » → *« Je sais. C'est ce soir ou jamais. »*

⏱ 6s
**[Léna]** Ma sœur a disparu il y a 7 mois et ce soir je sais enfin où chercher.
⏱ 8s
**[Léna]** Léna. Je m'appelle Léna, tant qu'à vous déranger.

*(→ carte d'enregistrement du contact)*

**CHOIX STRUCTURANT :**
- A. « Ok. Je vous écoute » → N8 *(confiance +1)*
- B. « Appelez la police, pas un inconnu » → N10
- C. [Ignorer] → N11

### N7 — Elle teste
⏱ 15s
**[Léna]** Quelqu'un qui cherche sa sœur. Depuis 7 mois.
⏱ 5s
**[Léna]** Et toi t'es le mec au bout d'un mauvais numéro qui pose beaucoup de questions.

**MICRO-CHOIX :**
- 🛡 « J'arrête si vous voulez. » → *« Surtout pas. »*
- 🔍 « Votre sœur, elle s'appelle comment ? » → *« Chloé. »*
- 🧠 « C'est un reproche ? » → *« Non. Un constat. »*

⏱ 6s
**[Léna]** Ça tombe bien. Tout le monde a arrêté d'en poser sur Chloé.
⏱ 8s
**[Léna]** Léna, au fait. Puisqu'on en est là.

*(→ carte d'enregistrement du contact)*
→ N8

---

## LE DILEMME CENTRAL

### N8 — La demande
⏱ 10s
**[Léna]** Voilà le truc. Ce soir je vais à l'ancien entrepôt Verdier, route de Lacan.

**MICRO-CHOIX :**
- 🛡 « Seule ?? » → *« T'as une meilleure idée ? »*
- 🔍 « Pourquoi cet endroit précisément ? » → *« J'y viens. »*
- 🧠 « Comment vous avez repéré cet endroit ? » → *« En cherchant. Pendant des mois. »*

⏱ 6s
**[Léna]** Un type louche y va tous les jeudis à 23h30. Je l'ai suivi deux fois.

**MICRO-CHOIX :**
- 🛡 « Vous l'avez suivi ? C'est dangereux. » → *« Je sais. »*
- 🔍 « Il fait quoi, là-bas ? » → *« Il charge des trucs. Il ressort. »*
- 🧠 « Louche comment ? Ça veut rien dire. » → *« ...T'as raison. Mais je le sens. »*

⏱ 6s
**[Léna]** Si j'y vais et qu'il m'arrive un truc, il faut que quelqu'un sache où je suis.

🔍 **INTERACTION CACHÉE — Relance (« + ») :** une seule des deux, mutuellement exclusives.
- « C'est qui, ce type ? » → *« Aucune idée de son nom. La cinquantaine, toujours seul, toujours le jeudi. »* *(indices + PROFIL_SUSPECT)*
- « Pourquoi cet entrepôt ? » → *« Le dernier signal du tel de Chloé a borné à 400m de là. La police dit que ça prouve rien. 400 mètres. »* *(indices + BORNAGE)*

⏱ 5s
**[Léna]** T'as rien demandé, je sais. Mais t'es là.

**CHOIX STRUCTURANT :**
- A. « N'y allez pas seule. Appelez la police » → N10 *(lucidite +1)*
- B. « Ok. Je garde mon téléphone à côté de moi » → N12 *(confiance +2, branche = "allié")*
- C. « Pourquoi moi ? Vous ne me connaissez pas » → N13 *(lucidite +1)*

### N10 — Le refus raisonnable
⏱ 12s
**[Léna]** La police ? Vous croyez que j'ai pas essayé ?
⏱ 5s
**[Léna]** 📷 *[Capture : mail de classement sans suite]*

**MICRO-CHOIX :**
- 🛡 « C'est dégueulasse. » → *« Ouais. Bienvenue. »*
- 🔍 « Ils ont dit quoi exactement ? » → *« Que partir n'est pas un crime. Mot pour mot. »*
- 🧠 « Vous avez signalé quand ? » → *« ...En juin. »* ⚠️ *(lucidite +1 — appuie l'incohérence n°1)*

🔍 **INTERACTION CACHÉE — Zoom sur la capture :** date du 12 juin, deux mois avant. Or elle cherche depuis 7 mois. *(lucidite +1)*

⏱ 8s
**[Léna]** Alors oui, un inconnu au bout d'un mauvais numéro, c'est tout ce qui me reste. Ironique, hein.

**CHOIX STRUCTURANT :**
- A. « Ok... je reste en ligne. Mais n'entrez pas dans ce bâtiment » → N12 *(confiance +1, branche = "prudent")*
- B. « Je suis désolé. Je ne peux pas » → N11

### N11 — Le refus assumé
⏱ 20s
**[Léna]** Je comprends. Vraiment.
⏱ 5s
**[Léna]** Merci quand même d'avoir répondu.
*Séparateur : « 23h58 »* ⏱ 25s
🔔 PUSH
**[Léna]** Je vous dérange une dernière fois. Je suis devant l'entrepôt.

**MICRO-CHOIX :**
- 🛡 « Ne faites pas de bêtise. » → *« Trop tard pour ça. »*
- 🔍 « Qu'est-ce que vous voulez ? » → *« Que quelqu'un sache. C'est tout. »*
- 🧠 « Je vous avais dit non. » → *« Je sais. C'est pour ça que je demande rien. »*

⏱ 6s
**[Léna]** Si dans une heure je n'ai rien envoyé, appelez le 17. Entrepôt Verdier, route de Lacan.
⏱ 5s
**[Léna]** Vous n'êtes pas obligé de répondre. Juste de lire.

*(→ `refus = true` : vouvoiement jusqu'au ch. 3, confiance plafonnée à 6, callback ch. 2)*

**CHOIX STRUCTURANT :**
- A. « Je lis. Soyez prudente » → N14 *(confiance +1)*
- B. [Ignorer] → N14

### N12 — Tu acceptes de veiller
⏱ 8s
**[Léna]** Merci. Sérieux.

**MICRO-CHOIX :**
- 🛡 « Prenez soin de vous. » → *« J'essaierai. »*
- 🔍 « Envoyez-moi votre position. » → *« Non. Si ça tourne mal, t'as l'adresse. Ça suffit. »*
- 🧠 « Vous avez prévu quoi, exactement ? » → *« Regarder. Rien d'autre. Promis. »*

→ N14

### N13 — « Pourquoi moi ? »
⏱ 22s *(typing intermittent — incohérence n°2)*
**[Léna]** Franchement ? Le hasard. Mauvais numéro, bon timing.

🔍 **INTERACTION CACHÉE — Insister (« + ») :** « ...22 secondes pour répondre ça ? » →
*« J'hésitais à te dire un truc. Une autre fois. Pas ce soir. »* *(lucidite +1)*

**MICRO-CHOIX :**
- 🛡 « Peu importe. Je suis là. » → *« Merci. »*
- 🔍 « Vous auriez insisté avec n'importe qui ? » → *« Non. Justement. »*
- 🧠 « Ça ne me rassure pas, cette réponse. » → *« Moi non plus, si tu veux tout savoir. »*

⏱ 6s
**[Léna]** T'as répondu comme quelqu'un qui s'en fout pas. C'est rare.
→ N14

---

## LA NUIT DE L'ENTREPÔT

### N14 — Elle y va
⏱ 8s
**[Léna]** Ok. J'y vais. Le tel en silencieux mais je te lis.

**MICRO-CHOIX :**
- 🛡 « Restez dans la voiture. » → *« On verra. »*
- 🔍 « Écrivez-moi tout ce que vous voyez. » → *« Compte sur moi. »*
- 🧠 « Vous avez un plan si ça tourne mal ? » → *« Courir. C'est un plan, non ? »*

*Séparateur : « 23h31 »* ⏱ 20s
🔔 PUSH
**[Léna]** Je suis devant. Sa caisse est là. Une berline grise, la même que les deux dernières fois.

**CHOIX STRUCTURANT :**
- A. « Prenez la plaque en photo » → N16 *(indices + PLAQUE)*
- B. « Restez cachée. Décrivez-moi » → N17
- C. « Repartez. Maintenant » → N18

### N16 — La plaque
⏱ 18s
**[Léna]** 📷 *[Photo : arrière d'une 508 grise, plaque cramée par le reflet, « 843 » au centre, macaron sur la lunette]*
⏱ 4s
**[Léna]** C'est tout ce que j'arrive à choper sans m'approcher.

🔍 **INTERACTION CACHÉE — Zoom sur le macaron :** « SENTINEL PRO ». *(indices + AUTOCOLLANT)*

**MICRO-CHOIX :**
- 🛡 « Ne prenez plus de photos, c'est trop risqué. » → *« Trop tard. »*
- 🔍 « Il y a un autocollant sur la vitre. » → *« Où ça ? ...Ah. J'avais pas vu. »*
- 🧠 « Une plaque partielle, ça sert à quoi ? » → *« À rien. Ou à tout. On verra. »*

→ N19

### N17 — La note vocale
⏱ 20s
🎤 **[Léna]** *Note vocale — 22s* *(fond sonore incohérent — incohérence n°3)*

🔍 **INTERACTION CACHÉE — Réécouter :** « C'est quoi ce bruit derrière vous ? » →
*« Quel bruit ? ...La radio d'une caisse qui passait, j'imagine. Concentre-toi. »* *(lucidite +1)*

**MICRO-CHOIX :**
- 🛡 « N'approchez pas. » → *« Deux minutes. »*
- 🔍 « Il y a quelqu'un au premier ? » → *« Une silhouette. Elle bouge. »*
- 🧠 « Vous êtes où exactement, là ? » → *« Devant. Pourquoi ? »* ⚠️ *(lucidite +1)*

⏱ 6s
**[Léna]** Je vais me rapprocher.

**CHOIX STRUCTURANT :**
- A. « NON. Restez où vous êtes » → N19
- B. « Ok mais restez loin de la porte » → N19 *(confiance +1)*

### N18 — Tu la supplies de partir
⏱ 10s
**[Léna]** J'ai pas fait tout ça pour repartir.

**MICRO-CHOIX :**
- 🛡 « Ça ne ramènera pas Chloé si vous y passez. » → *« ...Je sais. »*
- 🔍 « Vous cherchez quoi, concrètement ? » → *« Une preuve. N'importe laquelle. »*
- 🧠 « Vous vous mettez en danger pour une intuition. » → *« C'est tout ce que j'ai. »*

⏱ 6s
**[Léna]** Chloé aurait pas abandonné, elle. C'est moi qui l'ai abandonnée la première.
→ N19

---

## L'INCIDENT

### N19 — Il sort

⏱ 25s *(« Léna est hors ligne »)*
🔔 PUSH
**[Léna]** il sort
⏱ 3s
**[Léna]** il met un sac dans le coffre

**MICRO-CHOIX :** *(urgence — messages courts, sans majuscule)*
- 🛡 « cachez-vous » → *« je suis derrière la benne »*
- 🔍 « quelle taille le sac » → *« grand. lourd. il le porte à deux mains »*
- 🧠 « j'appelle la police ? » → *« NON. pas encore. »*

⏱ 4s
**[Léna]** il regarde vers moi

**MICRO-CHOIX :**
- 🛡 « NE BOUGEZ PAS » → *(pas de réponse)*
- 🔍 « il vous voit ? » → *(pas de réponse)*
- 🧠 « Léna répondez » → *(pas de réponse)*

⏱ 3s
**[Léna]** merde

*(« Léna est hors ligne » — ⏱ 60s. Typing fantôme à 30s, vibration à 40s. Les messages du joueur restent non délivrés, sans « Vu. ».)*
→ N20

### N20 — Le retour
🔔 PUSH — *Séparateur : « 00h34 »*
*(Les messages décoratifs reçoivent leur « Vu. » d'un coup.)*
**[Léna]** C'est bon. Je suis dans ma caisse. Il m'a pas vue. Je crois.

**MICRO-CHOIX :**
- 🛡 « Vous m'avez fait flipper. » → *« Toi ? Je tremble encore. »*
- 🔍 « Il vous a vue ou pas ? » → *« Je sais pas. C'est ça le pire. »*
- 🧠 « Vous avez pris la plaque au moins ? » → *« ...Merde. Attends. »*

⏱ 5s
**[Léna]** Mon cœur va exploser.

**CHOIX STRUCTURANT :**
- A. « Rentrez chez vous. On fait le point demain » → N9
- B. « Il faut porter ça à la police. Maintenant » → N9 *(lucidite +1)*

### N9 — 🤖 MOMENT IA : la décompression
⏱ 15s
**[Léna]** Je tremble encore. C'est con, hein.
⏱ 6s
**[Léna]** Dis... ça fait 2h que tu me suis dans ce délire et je sais rien de toi. Un vrai truc. N'importe lequel. J'ai besoin de penser à autre chose cinq minutes.

*(Saisie libre. Consignes inchangées.)*

### N21 — La photo
⏱ 12s
**[Léna]** Attends. Avant qu'il sorte, j'ai pris ça par la fenêtre du bas.
⏱ 5s
**[Léna]** 📷 *[Photo : établi, trousseau au mur, téléphone rose fissuré au fond]*

**MICRO-CHOIX :**
- 🛡 « Vous avez pris ce risque pour ça ? » → *« Regarde d'abord. »*
- 🔍 « Il y a un téléphone sur l'établi. » → *« ...Où ça. Montre. »* ⚠️ *(enquete +1)*
- 🧠 « Qu'est-ce que je dois voir ? » → *« Le mur. À droite. »*

⏱ 6s
**[Léna]** Tu vois le porte-clés ? Zoome.

🔍 **INTERACTION CACHÉE — Zoom :** silhouettes gravées nettes, téléphone rose visible au fond. *(indices + TELEPHONE)*
→ N22

### N22 — FIN DU CHAPITRE 1
⏱ 5s
**[Léna]** Chloé avait exactement le même. C'est moi qui lui avais offert.

**MICRO-CHOIX :**
- 🛡 « ...Merde. » → *« Ouais. »*
- 🔍 « Vous êtes sûre que c'est le même ? » → *« Certaine. »*
- 🧠 « Ça peut être une coïncidence. » → *« Attends. »*

⏱ 6s
**[Léna]** Il n'en existe que deux au monde. Je les avais fait graver. Un pour elle, un pour moi.
⏱ 6s
**[Léna]** Et le mien a disparu de mon appart il y a 3 semaines.

**🔒 ÉCRAN DE FIN DE CHAPITRE**
« Quelqu'un est entré chez Léna. Quelqu'un sait qu'elle cherche. »
**Chapitre 2 : Chloé** — disponible dans 8h

---

## Récapitulatif

| | V2 | V3.1 |
|---|---|---|
| Messages consécutifs max | 6 | 3 |
| Interventions du joueur | 12 | 12 structurants + 22 micro = 34 |
| Délai max hors N19 | 90s | 25s |
| Silence N19 | 90s | 60s |
| Grammaire des micro-choix | — | 3 axes constants |

**Amplitude des variables sur le chapitre :** un joueur mono-axe termine à ~+11 sur son axe (22 micro-choix × 0.5), un joueur équilibré à ~+3,5 sur chacun. C'est le motif qui compte, pas l'occurrence.

## Notes d'implémentation

- Micro-choix = `choices` avec **le même `next_node_id`**. Variante de réponse via `inline_response` ou message conditionnel — à arbitrer selon l'existant.
- Ordre d'affichage constant : 🛡 protéger, 🔍 enquêter, 🧠 raisonner. **Sans jamais afficher les icônes au joueur** — l'ordre suffit à créer une habitude inconsciente.
- Effets : `+0.5` sur `confiance` / `enquete` / `lucidite` respectivement. Les ⚠️ portent un effet supplémentaire.
- **Raisonner ne fait JAMAIS baisser la confiance.** Règle à documenter dans LOGIQUE.md.
- Nouvelle variable `enquete` (0-10, départ 0) à ajouter au schéma et à la bible §6.
- Au N19 second bloc, les trois options n'ont aucune réponse : le silence est la réponse. Ne pas ajouter de variante par souci de symétrie.
