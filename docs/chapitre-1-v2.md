# NUMÉRO INCONNU — Chapitre 1 V2 : Le mauvais numéro

**Changements vs V1 :** délais compressés (max 90s), moment IA déplacé après l'entrepôt, branche du refus avec conséquences durables, 3 interactions "enquêteur", scripts vocaux complets pour TTS, callbacks préparés pour le ch. 2, bouton « Ignorer » explicite.

**V2.1 — révélation d'identité, ajoutée en phase 2/3.** Léna ne se nommait jamais du chapitre : la liste de conversations affichait « Léna » avant que le joueur le sache, ce qui trahissait le titre de l'histoire dès la première seconde. Une réplique de présentation est ajoutée sur **chacune des trois branches** qui mènent au N8 (N5, N6, N7), chacune avec son ton. Techniquement : `contacts.display_name_initial` = « Numéro inconnu » jusqu'à l'effect `reveal_contact` porté par ces trois nœuds (voir `docs/LOGIQUE.md`).

## Variables

| Variable | Valeurs | Rôle |
|---|---|---|
| `confiance` | 0 à 10 (départ : 3) | Léna se confie plus ou moins |
| `indices` | liste (départ : vide) | Débloque des options ch. 4-5 |
| `lucidite` | 0 à 5 (départ : 0) | Repérage des incohérences |
| `refus` | bool (départ : false) | Le joueur a refusé d'aider → Léna reste distante (vouvoiement, confiance plafonnée à 6 jusqu'au ch. 3) |
| `branche_ch1` | code | Mémorise le parcours pour les callbacks du ch. 2 |

## Conventions

- **[Léna]** message reçu · **⏱** délai avant affichage · **📷/🎤** photo/vocal · **🔔 PUSH** notification
- **CHOIX** : « Ignorer » est toujours un bouton explicite (jamais de timeout réel — trop ambigu)
- **🔍 INTERACTION** : action cachée du joueur (zoom, réécoute, relance) — jamais obligatoire, toujours récompensée
- **🎙 SCRIPT TTS** : texte à produire en vocal (toi), avec indications de jeu

**Règle de rythme ch. 1 :** aucun délai > 90s. Les ellipses sont narratives (« 23h12 » affiché en séparateur), pas subies. Les vraies attentes commencent au ch. 2.

---

## SÉQUENCE D'OUVERTURE

### N1 — Le premier message
*Interface messagerie vide. Séparateur : « jeudi — 22h47 »*

⏱ 4s
**[Léna]** C'est bon. J'ai trouvé où il la garde.
⏱ 6s
**[Léna]** J'y vais ce soir. Si t'as pas de nouvelles de moi avant 2h du mat, tu sais quoi faire.

**CHOIX :**
- A. « Je crois que vous vous trompez de numéro » → N2
- B. « Qui ça, "elle" ? » → N3 *(confiance +1)*
- C. [Ignorer] → N4

### N2 — L'erreur
⏱ 40s *("en train d'écrire" qui apparaît/disparaît deux fois)*
**[Léna]** Merde.
⏱ 5s
**[Léna]** Merde merde merde. C'est pas le numéro de Karim ?
**CHOIX :**
- A. « Non, désolé. Mais ça va ? Votre message était inquiétant » → N5 *(confiance +1, branche_ch1 = "empathie")*
- B. « Non. Bonne soirée » → N6

### N3 — Tu joues le jeu
⏱ 25s
**[Léna]** Attends
⏱ 8s
**[Léna]** T'es pas Karim.
⏱ 4s
**[Léna]** Karim me demanderait jamais ça. T'es qui ?
**CHOIX :**
- A. « Quelqu'un qui a reçu votre message par erreur. Et qui s'inquiète un peu, là » → N5 *(confiance +1, branche_ch1 = "empathie")*
- B. « Et vous, vous êtes qui ? C'est quoi cette histoire ? » → N7 *(branche_ch1 = "curieux")*

### N4 — Ignoré
*Séparateur : « 23h02 » (ellipse narrative, en réalité ⏱ 20s)*
🔔 PUSH
**[Léna]** Karim ?
⏱ 8s
**[Léna]** Réponds, c'est pas le moment de me lâcher.
⏱ 15s
**[Léna]** Ok t'es pas Karim. Une chance sur deux avec ce foutu nouveau tel.
**CHOIX :**
- A. « Non, en effet. C'est quoi cette histoire ? » → N7 *(branche_ch1 = "curieux")*
- B. « Vous devriez vérifier vos numéros avant d'envoyer ce genre de trucs » → N6 *(lucidite +1)*

### N5 — Elle se livre
⏱ 45s
**[Léna]** Désolée. J'aurais jamais dû envoyer ça à un inconnu.
⏱ 10s
**[Léna]** C'est ma sœur. Chloé. Elle a disparu il y a 7 mois.
⏱ 8s
**[Léna]** La police a classé. "Départ volontaire". Mon cul.
⏱ 12s
**[Léna]** Moi c'est Léna, au passage. Puisqu'on en est là.
*(V2.1 — révélation du contact)*
→ N8

### N6 — Elle décroche... presque
⏱ 20s
**[Léna]** Ouais. Désolée du dérangement.
*Séparateur : « 23h18 » (ellipse narrative, en réalité ⏱ 60s)*
🔔 PUSH
**[Léna]** En fait non. J'ai personne d'autre. Karim répond pas et j'ai plus le temps.
⏱ 6s
**[Léna]** Ma sœur a disparu il y a 7 mois et ce soir je sais enfin où chercher. Je peux vous parler ? Juste ce soir.
⏱ 10s
**[Léna]** Léna. Je m'appelle Léna, tant qu'à vous déranger.
*(V2.1 — révélation du contact, ton formel propre à cette branche)*
**CHOIX :**
- A. « Ok. Je vous écoute » → N8 *(confiance +1)*
- B. « Appelez la police, pas un inconnu » → N10
- C. [Ignorer] → N11

### N7 — Elle teste
⏱ 35s
**[Léna]** Quelqu'un qui cherche sa sœur. Depuis 7 mois.
⏱ 6s
**[Léna]** Et toi t'es le mec au bout d'un mauvais numéro qui pose beaucoup de questions.
⏱ 5s
**[Léna]** ...ce qui tombe bien. Tout le monde a arrêté d'en poser sur Chloé.
⏱ 12s
**[Léna]** Moi c'est Léna, au passage. Puisqu'on en est là.
*(V2.1 — révélation du contact)*
→ N8

---

## LE DILEMME CENTRAL

### N8 — La demande
⏱ 30s
**[Léna]** Voilà le truc. Ce soir je vais à l'ancien entrepôt Verdier, route de Lacan. Un type louche y va tous les jeudis à 23h30, je l'ai suivi deux fois.
⏱ 10s
**[Léna]** Si j'y vais et qu'il m'arrive un truc, il faut que quelqu'un sache où je suis.
⏱ 5s
**[Léna]** T'as rien demandé, je sais. Mais t'es là.

🔍 **INTERACTION — Relancer :** un bouton discret « Poser une question » permet UNE relance optionnelle avant de choisir :
- « C'est qui, ce type ? » → **[Léna]** « Aucune idée de son nom. La cinquantaine, toujours seul, toujours le jeudi. Il a chargé des cartons la dernière fois. » *(indices + PROFIL_SUSPECT)*
- « Pourquoi cet entrepôt ? » → **[Léna]** « Le dernier signal du tel de Chloé a borné à 400m de là. La police dit que ça prouve rien. 400 mètres. » *(indices + BORNAGE)*

**CHOIX :**
- A. « N'y allez pas seule. Appelez la police, vraiment » → N10 *(lucidite +1)*
- B. « Ok. Je garde mon téléphone à côté de moi » → N12 *(confiance +2, branche_ch1 = "allié")*
- C. « Pourquoi moi ? Vous ne me connaissez pas » → N13 *(lucidite +1)*

### N10 — Le refus raisonnable
⏱ 25s
**[Léna]** La police ? Vous croyez que j'ai pas essayé ?
⏱ 8s
**[Léna]** 📷 *[Capture : récépissé de main courante, tampon « sans suite »]*
⏱ 6s
**[Léna]** Trois signalements. Trois. Ils m'ont dit d'arrêter de les "harceler".

🔍 **INTERACTION — Zoom sur la capture :** la date du récépissé est celle d'il y a 2 mois... mais Léna dit chercher depuis 7 mois. Pourquoi avoir attendu 5 mois pour signaler ? *(lucidite +1, incohérence confrontable au ch. 3)*

⏱ 10s
**[Léna]** Alors oui, un inconnu au bout d'un mauvais numéro, c'est tout ce qui me reste. Ironique, hein.
**CHOIX :**
- A. « Ok... je reste en ligne ce soir. Mais promettez-moi de ne pas entrer dans ce bâtiment » → N12 *(confiance +1, branche_ch1 = "prudent")*
- B. « Je suis désolé. Je ne peux pas être responsable de ça » → N11

### N11 — Le refus assumé (conséquences durables)
⏱ 60s
**[Léna]** Je comprends. Vraiment.
⏱ 6s
**[Léna]** Merci quand même d'avoir répondu.
*Séparateur : « 23h58 » (ellipse, en réalité ⏱ 90s — le joueur croit l'histoire finie)*
🔔 PUSH — « Léna : 1 nouveau message »
**[Léna]** Je vous dérange une dernière fois. Je suis devant l'entrepôt. Si dans une heure je n'ai rien envoyé, appelez le 17 et donnez-leur cette adresse : entrepôt Verdier, route de Lacan.
⏱ 5s
**[Léna]** Vous n'êtes pas obligé de répondre. Juste de lire.
*(→ `refus = true` : Léna vouvoie jusqu'au ch. 3 inclus, confiance plafonnée à 6, et au ch. 2 elle rappellera : « Vous aviez dit non. Vous êtes encore là. Pourquoi ? » — le refus du joueur EXISTE dans l'histoire.)*
**CHOIX :**
- A. « Je lis. Soyez prudente » → N14 *(confiance +1)*
- B. [Ignorer] → N14 *(variante : elle envoie la suite sans réponse de ta part)*

### N12 — Tu acceptes de veiller
⏱ 15s
**[Léna]** Merci. Sérieux.
→ N14

### N13 — « Pourquoi moi ? »
⏱ 50s *(hésitation visible, "en train d'écrire" par à-coups — incohérence volontaire)*
**[Léna]** Franchement ? Le hasard. Mauvais numéro, bon timing.
⏱ 6s
**[Léna]** Quoique. Peut-être que si t'avais pas répondu comme ça, j'aurais pas insisté. T'as répondu comme quelqu'un qui s'en fout pas.

🔍 **INTERACTION — Insister :** bouton « ...50 secondes pour répondre ça ? » →
**[Léna]** « J'hésitais à te dire un truc. Une autre fois. Pas ce soir. » *(lucidite +1 — graine majeure du ch. 3 : elle admet cacher quelque chose dès le ch. 1)*
→ N14

---

## LA NUIT DE L'ENTREPÔT

### N14 — Elle y va
⏱ 20s
**[Léna]** Ok. J'y vais. Le tel en silencieux mais je te lis.
*Séparateur : « 23h31 » (ellipse, en réalité ⏱ 45s)*
🔔 PUSH
**[Léna]** Je suis devant. Sa caisse est là. Une berline grise, la même que les deux dernières fois.
**CHOIX :**
- A. « Prenez la plaque en photo » → N16 *(indices + PLAQUE)*
- B. « Restez cachée. Décrivez-moi ce que vous voyez » → N17
- C. « Repartez. Maintenant » → N18

### N16 — La plaque
⏱ 60s
**[Léna]** 📷 *[Photo sombre : arrière d'une berline grise, plaque partielle « ...-843-... », autocollant d'une société de sécurité sur la lunette]*
**[Léna]** C'est tout ce que j'arrive à choper sans m'approcher.

🔍 **INTERACTION — Zoom sur l'autocollant :** logo « SENTINEL PRO — Gardiennage & Sûreté » lisible. *(indices + AUTOCOLLANT — piste de l'employeur au ch. 2)*
→ N19

### N17 — La note vocale
⏱ 75s
🎤 **[Léna]** *Note vocale — 24s*

> **🎙 SCRIPT TTS n°1 — « Repérage » (voix jeune femme, chuchotée, tendue, souffle court, débit irrégulier) :**
> « Ok... il y a de la lumière au premier. Une fenêtre condamnée avec des planches — mais récentes, le bois est encore clair. Et il y a... attends... *(pause 2s)* ...quelqu'un vient de passer devant la lumière. Il porte un truc. Un carton, ou... je sais pas. *(souffle)* Je vais me rapprocher. »
>
> **🎧 Détail caché en fond sonore (à mixer) :** très faiblement, derrière sa voix, un jingle de radio ou une annonce sonore — or elle est censée être dehors, seule, dans une zone déserte. Incohérence audio.

🔍 **INTERACTION — Réécouter :** si le joueur réécoute le vocal, un choix apparaît : « C'est quoi ce bruit derrière vous ? » →
**[Léna]** « Quel bruit ? ...La radio d'une caisse qui passait, j'imagine. Concentre-toi. » *(lucidite +1 — réponse trop rapide, confrontable au ch. 3)*

**CHOIX :**
- A. « NON. Restez où vous êtes » → N19
- B. « Ok mais restez à distance de la porte » → N19 *(confiance +1)*

### N18 — Tu la supplies de partir
⏱ 40s
**[Léna]** J'ai pas fait tout ça pour repartir.
⏱ 6s
**[Léna]** Chloé aurait pas abandonné, elle. C'est moi qui l'ai abandonnée la première.
*(Graine : culpabilité de Léna — payoff ch. 4)*
→ N19

---

## L'INCIDENT

### N19 — Il sort
⏱ 60s *(silence — « Léna est hors ligne » affiché. Durée paramétrable en base pour tes tests : commencer à 60s, ajuster selon ressenti)*
🔔 PUSH
**[Léna]** il sort
⏱ 3s
**[Léna]** il met un sac dans le coffre
⏱ 3s
**[Léna]** un grand sac
⏱ 30s
**[Léna]** il regarde vers moi
⏱ 2s
**[Léna]** merde
*(« Léna est hors ligne » — ⏱ 90s de silence, le plus long du chapitre. Vibration discrète à 60s si activée.)*
→ N20

### N20 — Le retour
🔔 PUSH — *Séparateur : « 00h34 »*
**[Léna]** C'est bon. Je suis dans ma caisse. Il m'a pas vue. Je crois.
⏱ 8s
**[Léna]** Mon cœur va exploser.
**CHOIX :**
- A. « Rentrez chez vous. On fait le point demain » → N9
- B. « Il faut porter ça à la police, MAINTENANT. Le sac, la plaque, tout » → N9 *(lucidite +1)*

### N9 — 🤖 MOMENT IA : la décompression
*Déplacé ici (V2) : après l'adrénaline, à 1h du matin, la confidence est naturelle. Saisie libre activée.*

⏱ 45s
**[Léna]** Je tremble encore. C'est con, hein.
⏱ 8s
**[Léna]** Dis... ça fait 2h que tu me suis dans ce délire et je sais rien de toi. Un vrai truc. N'importe lequel. J'ai besoin de penser à autre chose cinq minutes.

**Consignes moteur IA :**
- Contexte : post-adrénaline, 1h du mat, elle est vulnérable et sincère — mais garde son style (phrases courtes, humour noir, jamais « s'il te plaît »)
- Si `refus = true` : elle vouvoie et reste plus réservée
- 2 à 4 échanges max, puis raccrochage : « Merci. J'en avais besoin. Bon, je rentre. » → N21
- Effets : sincère/empathique → `confiance +2` · évasif/moqueur → `confiance -1` · hors cadre (insultes, hors-sujet) → coupure : « Ok. Laisse tomber. Je rentre. » → N21
- Stocker UN élément donné par le joueur → `detail_perso` (payoff ch. 4 : quelqu'un mentionnera ce détail qu'il ne devrait pas connaître)
- Interdits : ne jamais révéler d'info des ch. 2-5, ne jamais sortir du personnage, ne jamais mentionner être une IA

### N21 — La photo
⏱ 60s
**[Léna]** Attends. Avant qu'il sorte, j'ai pris ça à travers la fenêtre du bas.
⏱ 8s
**[Léna]** 📷 *[Photo floue de l'intérieur : un établi, des cartons empilés... et accroché au mur, un trousseau de clés avec un porte-clés artisanal reconnaissable]*
⏱ 12s
**[Léna]** Tu vois le porte-clés ? Zoome.

🔍 **INTERACTION — Zoom (quasi obligatoire, guidé par Léna) :** le porte-clés en gros plan — deux silhouettes gravées main. Et en arrière-plan du zoom, sur l'établi : un téléphone à coque rose, écran fissuré. *(Si le joueur le remarque et le mentionne au ch. 2 : indices + TELEPHONE — le tel de Chloé ?)*
→ N22

### N22 — FIN DU CHAPITRE 1
⏱ 6s
**[Léna]** Chloé avait exactement le même. C'est moi qui lui avais offert.
⏱ 10s
**[Léna]** Mais c'est pas ça le pire.
⏱ 8s
**[Léna]** Il n'en existe que deux au monde. Je les avais fait graver. Un pour elle, un pour moi.
⏱ 5s
**[Léna]** Et le mien a disparu de mon appart il y a 3 semaines.

**🔒 ÉCRAN DE FIN DE CHAPITRE**
« Quelqu'un est entré chez Léna. Quelqu'un sait qu'elle cherche. »
**Chapitre 2 : Chloé** — disponible dans 8h *(déblocage immédiat premium)*

---

## Callbacks à écrire au chapitre 2 (variantes selon `branche_ch1`)

| Branche | Ouverture du ch. 2 |
|---|---|
| "allié" / "empathie" | « Salut. J'ai pas dormi. Toi non plus je parie. » |
| "prudent" | « T'avais raison pour la police. J'y suis allée ce matin. Tu devineras jamais ce qu'ils m'ont dit. » |
| "curieux" | « Toi qui poses toujours les bonnes questions — j'en ai une pour toi. » |
| `refus = true` | « Vous aviez dit non. Vous lisez encore. Pourquoi ? » *(vouvoiement maintenu)* |

## Interactions cachées — récap

| Interaction | Récompense | Payoff |
|---|---|---|
| Relance N8 (2 questions) | PROFIL_SUSPECT / BORNAGE | Enquête ch. 2 |
| Zoom récépissé N10 | lucidite +1 | Incohérence des 5 mois, ch. 3 |
| Insister N13 | lucidite +1 | « Je te cache un truc », ch. 3 |
| Zoom autocollant N16 | AUTOCOLLANT | Piste Sentinel Pro, ch. 2 |
| Réécoute vocal N17 | lucidite +1 | Incohérence audio, ch. 3 |
| Zoom téléphone N21 | TELEPHONE | Le tel de Chloé ?, ch. 2 |

## Architecture : prévoir le multi-conversations

L'UI doit être une liste de conversations (même si une seule existe au ch. 1). Twist prévu ch. 4 : **un second contact écrit au joueur** (Karim ? le suspect ?). Coût quasi nul maintenant, impossible à greffer proprement après.

## Production TTS — process

Chaque vocal aura son bloc 🎙 SCRIPT TTS avec : texte exact, indications de jeu (débit, émotion, pauses), et détails de mixage éventuels (sons de fond porteurs d'indices). Tu génères le fichier, on stocke l'URL dans `messages.media_url`. Le chapitre 1 n'a qu'un seul vocal (n°1 « Repérage ») — les ch. 2-5 en auront 2-3 chacun.
