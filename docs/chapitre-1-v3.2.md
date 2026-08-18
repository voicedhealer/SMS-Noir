# NUMÉRO INCONNU — Chapitre 1 V3.2

> **Source de vérité du chapitre 1.** Remplace `chapitre-1-v3.1.md`, conservé en
> archive. C'est de ce fichier que le seed est **généré** —
> `scripts/generate-seed-content.py` — et non recopié : le document et la base
> ne peuvent donc plus diverger.
>
> **Précisions apportées à la rédaction d'origine**, validées par Vivien :
> - Le mail de la police **remonte du N10 au N8**, avec son zoom. Déplacement
>   volontaire : au N10 il n'était visible que sur la branche « appelez la
>   police », et l'incohérence n°1 restait inaccessible aux deux autres. La fin
>   cachée ne doit pas dépendre d'un choix structurant pris au hasard.
> - Les **délais** ne figurent pas dans ce document : convention V3.1 appliquée
>   (3-8 s en conversation, 15-25 s pour une hésitation, N19 à 60 s), délais
>   d'ellipse conservés. Ils vivent dans le générateur, pas ici.

**Ce qui change vs V3.1 :** tous les dialogues réécrits après test sur appareil réel. Léna écrit en phrases construites, elle est vulnérable avant d'être piquante, elle remercie. La grammaire des trois axes est conservée, la structure du graphe est inchangée.

---

## RÈGLES D'ÉCRITURE (bible §2 révisée)

**Ces règles remplacent les anciennes consignes « phrases courtes, ponctuation minimale, ne dit jamais s'il te plaît » qui produisaient un personnage désagréable.**

1. **Léna écrit en phrases liées par des virgules.** Un point ne s'emploie qu'en fin de phrase, ou pour une phrase courte qui doit tomber sec. Jamais de fragments empilés.
2. **La vulnérabilité passe avant le mordant.** Elle a peut-être perdu sa sœur, elle a peur, elle est seule. L'humour ou la sécheresse arrivent en réflexe de défense, jamais à la place de l'émotion.
3. **Elle remercie, elle s'excuse, elle reconnaît ce que le joueur lui apporte.** Un joueur qui aide et se fait rembarrer décroche.
4. **Elle vouvoie jusqu'au N20**, puis demande à tutoyer après la peur partagée. Si `refus = true`, le vouvoiement est maintenu tout le chapitre — elle n'a pas gagné ce droit.
5. **Exception aux fragments : le N19 uniquement**, quand elle tape en tremblant. Et même là, elle lie ses phrases.
6. **Politesse et détresse cohabitent** : elle garde ses réflexes de politesse, et les enfreint quand le besoin de réconfort prend le dessus.

## GRAMMAIRE DES MICRO-CHOIX (inchangée)

Trois options, toujours dans le même ordre, jamais d'icône affichée : 🛡 **Protéger** · 🔍 **Enquêter** · 🧠 **Raisonner**. Effets faibles et proportionnels (voir LOGIQUE.md). Aucun micro-choix ne ramifie.

---

## N1 — LE PREMIER MESSAGE

*Séparateur : « jeudi — 22h47 »*

**[Léna]** Salut Karim ! Je pense avoir trouvé où ma sœur est retenue...

**[Léna]** J'y vais ce soir pour vérifier, être sûre ! Si tu n'as pas de nouvelles de moi avant 2h du matin, alors tu sais ce que tu dois faire !

**[Léna]** S'il te plaît Karim, veille sur moi juste le temps que je regarde, j'ai personne d'autre pour ça.

**CHOIX STRUCTURANT :**
- A. « Je ne suis pas Karim ! Vous faites erreur. » → N2
- B. « Bonsoir, qui êtes-vous ? On se connaît ? » → N3 *(confiance +1)*
- C. « On ne se connaît pas. » → N4

---

## N2 — L'ERREUR

**[Léna]** Oula, désolée ! Je pensais envoyer ce sms à mon ami Karim, et visiblement ce n'est pas vous...

**MICRO-CHOIX :**
- 🛡 « Vous avez besoin d'aide ? » → *« Oui ! Je sais que vous n'y êtes pour rien, vous ne me connaissez pas, mais votre aide serait précieuse... »*
- 🔍 « Vous alliez où, ce soir ? » → *« Je qualifierais ça de "sortie imprévue", et pas pour me divertir dans un bar ou un restaurant en tout cas. »*
- 🧠 « C'est vraiment une erreur, ou vous vouliez que quelqu'un lise ? » → *« Quelle drôle de question... Non, bien sûr que non. »*

**[Léna]** C'est un nouveau portable, je me suis trompée d'un chiffre en enregistrant son numéro, j'étais pourtant sûre de moi... rooo.

**CHOIX STRUCTURANT :**
- A. « Votre message était inquiétant, ça va ? » → N5 *(confiance +1, branche = "empathie")*
- B. « Bonne soirée. » → N6

---

## N3 — TU JOUES LE JEU

**[Léna]** Attendez, vous n'êtes pas Karim.

**MICRO-CHOIX :**
- 🛡 « Non, mais votre message m'inquiète. » → *« Il ne devrait pas, ce n'est pas votre problème... enfin, je crois. »*
- 🔍 « Pourquoi, j'écris comme lui ? » → *« Non, justement. »*
- 🧠 « Vous en êtes sûre après un seul message ? » → *« Certaine, il aurait déjà appelé. »*

**[Léna]** Karim ne me demanderait jamais ça, qui êtes-vous ?

**CHOIX STRUCTURANT :**
- A. « Quelqu'un qui a reçu votre message par erreur, et qui s'inquiète un peu, là. » → N5 *(confiance +1, branche = "empathie")*
- B. « Et vous, c'est quoi cette histoire ? » → N7 *(branche = "curieux")*

---

## N4 — IGNORÉ

*Séparateur : « 23h02 »* · 🔔 PUSH

**[Léna]** Karim ? Réponds, ce n'est vraiment pas le moment de me lâcher.

**MICRO-CHOIX :**
- 🛡 « Ce n'est pas Karim, mais il se passe quoi ? » → *« Rien qui vous regarde, désolée. »*
- 🔍 « Vous attendez quoi de lui exactement ? » → *« Qu'il décroche, comme d'habitude, non. »*
- 🧠 « On ne se connaît pas, vous vous trompez de numéro. » → *« Évidemment. »*

**[Léna]** Une chance sur deux avec ce nouveau téléphone, et je la rate.

**CHOIX STRUCTURANT :**
- A. « C'est quoi cette histoire ? » → N7 *(branche = "curieux")*
- B. « Vous devriez vérifier vos numéros avant d'envoyer ce genre de messages. » → N6 *(lucidite +1)*

---

## N5 — ELLE SE LIVRE

**[Léna]** Désolée, j'aurais jamais dû envoyer ça à un inconnu, mais puisque vous êtes là... c'est ma sœur, Chloé, elle a disparu il y a 7 mois.

**MICRO-CHOIX :**
- 🛡 « Je suis désolé pour vous. » → *« Merci, c'est déjà plus que ce que j'entends d'habitude. »*
- 🔍 « Disparu comment ? » → *« Un soir elle était là, le lendemain non, plus aucun message, plus rien. »*
- 🧠 « Et la police n'a rien fait ? » → *« J'y viens, et croyez-moi, vous allez comprendre pourquoi je fais ça toute seule. »*

**[Léna]** Moi c'est Léna, au passage. Puisqu'on en est là.

*(→ carte d'enregistrement du contact · révélation d'identité)*
→ **N8**

---

## N6 — ELLE DÉCROCHE... PRESQUE

**[Léna]** Ouais, désolée du dérangement.

*Séparateur : « 23h18 »* · 🔔 PUSH

**[Léna]** En fait non, je n'ai personne d'autre.

**MICRO-CHOIX :**
- 🛡 « Je vous écoute. » → *« Merci, vraiment. »*
- 🔍 « Personne pour quoi ? » → *« Pour savoir où je suis, ce soir. »*
- 🧠 « Il est presque minuit, vous savez. » → *« Je sais, c'est ce soir ou jamais. »*

**[Léna]** Ma sœur a disparu il y a 7 mois, et ce soir je sais enfin où chercher.

**[Léna]** Léna, je m'appelle Léna, tant qu'à vous déranger.

*(→ carte d'enregistrement du contact · révélation d'identité)*

**CHOIX STRUCTURANT :**
- A. « D'accord, je vous écoute. » → N8 *(confiance +1)*
- B. « Appelez la police, pas un inconnu. » → N10
- C. « Je ne peux pas vous aider. » → N11

---

## N7 — ELLE TESTE

**[Léna]** Une personne qui recherche sa sœur depuis plus de 7 mois, et vous, la personne qui reçoit le message destiné à un autre, comme une bouteille à la mer portant un mot...

**MICRO-CHOIX :**
- 🛡 « J'arrête si vous voulez. » → *« Je peux vous demander une chose, une seule, s'il vous plaît ? »*
- 🔍 « Votre sœur, elle s'appelle comment ? » → *« Chloé. »*
- 🧠 « Et si j'ouvre cette bouteille, quel serait ce message ? » → *« Un appel à l'aide. »*

**[Léna]** Plus personne ne croit en mon histoire, plus personne ne pose de questions, les gens préfèrent oublier qu'imaginer le pire...

**[Léna]** Vous recevez ma bouteille, mais je ne vous ai même pas dit mon nom, je m'appelle Léna.

*(→ carte d'enregistrement du contact · révélation d'identité)*
→ **N8**

---

## N8 — LA DEMANDE

**[Léna]** La police a classé le dossier en à peine 2 semaines ! Sous le motif « départ volontaire », c'est le retour que j'ai eu... Alors qu'elle avait laissé ses clés et son sac dans son appartement. Qui fait ça ? Personne.

**[Léna]** 📷 *[capture du mail de classement sans suite]*

🔍 **INTERACTION CACHÉE — zoom sur la capture :** date du 12 juin, deux mois avant, alors qu'elle cherche depuis 7 mois. *(lucidite +1 — incohérence n°1)*

**MICRO-CHOIX :**
- 🛡 « C'est révoltant. » → *« Merci de le dire, vous savez, à force on finit par douter de soi. »*
- 🔍 « Ils vous ont dit quoi exactement ? » → *« Qu'une majeure a le droit de partir sans prévenir, et que je devrais accepter qu'elle ait voulu couper les ponts. »*
- 🧠 « Vous avez signalé quand exactement ? » → *« ...En juin. Je sais ce que vous allez dire. »* ⚠️ *(lucidite +1)*

**[Léna]** Pour moi elle a été enlevée, ou tuée... mon dieu j'espère que non. Depuis je cherche seule, et ce soir pour la première fois depuis des mois j'ai une piste, je pense savoir où aller vérifier, un ancien entrepôt sur la route de Lacan.

**MICRO-CHOIX :**
- 🛡 « Vous comptez y aller seule ? » → *« Je n'ai personne qui ne m'ait pas abandonnée, et je n'ai plus la patience d'attendre, je dois y aller, je dois savoir... pour elle je dois le faire. »*
- 🔍 « Pourquoi cet endroit précisément ? » → *« Le dernier signal du téléphone de Chloé a borné à 400 mètres de là, et la police m'a dit que ça ne prouvait rien, 400 mètres. »*
- 🧠 « Mais comment avez-vous trouvé cet endroit ? » → *« En cherchant pendant des mois, en recoupant des indices, des détails que personne ne voulait recouper avec moi. »*

**[Léna]** J'ai repéré un homme qui y va tous les jeudis vers 23h30, une fois la nuit tombée. Je l'ai suivi plusieurs fois, je sais ce n'est pas bien ! Mais à chaque fois il charge des cartons dans sa voiture avant de repartir, qui déménage ou travaille seul à cette heure-là ?

**[Léna]** Je vous demande juste une chose, si jamais il m'arrive quelque chose... j'ai peur ! Il faut que quelqu'un sache où je suis.

🔍 **INTERACTION CACHÉE — relance (« + ») :** une seule des deux, mutuellement exclusives.
- « Vous l'avez déjà vu de près ? » → *« La cinquantaine, toujours seul, il ne parle à personne et personne ne le connaît dans le coin, il regarde toujours autour de lui avant d'ouvrir la porte, c'est vraiment suspect ! Enfin, pour moi... »* *(indices + PROFIL_SUSPECT)*
- « Et s'il vous a repérée ? » → *« Je fais attention, je change de place à chaque fois, je ne peux pas vous jurer que non... mais je suis encore là, donc il est fort probable que non. »* *(indices + BORNAGE)*

**[Léna]** Vous n'aviez rien demandé, je sais, vous vouliez sûrement passer une soirée tranquille et vous êtes tombé sur moi. Je m'en excuse d'avance, car ça ne doit pas être facile de se retrouver embarqué dans cette histoire. Mais si j'ai raison, vous aurez participé à l'arrestation d'un criminel et épaulé une jeune femme à bout de nerfs.

**CHOIX STRUCTURANT :**
- A. « N'y allez pas seule, retournez voir la police d'abord. » → N10 *(lucidite +1)*
- B. « D'accord, je garde mon téléphone à côté de moi, mais soyez prudente ! Vraiment. » → N12 *(confiance +2, branche = "allié")*
- C. « Pourquoi moi ? Vous ne me connaissez pas, et si j'étais quelqu'un de pire ? » → N13 *(lucidite +1)*

---

## N10 — LE REFUS RAISONNABLE

**[Léna]** J'y suis retournée trois fois, ils m'ont dit que je devenais insistante, la dernière fois on m'a demandé si je n'avais pas besoin de voir quelqu'un. C'est clairement pas ce que j'attends d'eux, mais juste qu'ils fassent leur travail, simplement.

**MICRO-CHOIX :**
- 🛡 « Ils n'avaient pas le droit de vous dire ça. » → *« Merci, ça fait du bien de l'entendre, j'ai fini par croire que c'était moi le problème. »*
- 🔍 « Ils ont regardé le bornage au moins ? » → *« Ils l'ont noté, classé, et rien fait, pour eux ce n'est pas anormal de passer un appel à cet endroit, rien ne les choque ! Un dossier de plus dans une pile de dossiers, ils sont débordés, je peux le comprendre, mais là on n'est pas sur un défaut de stationnement. »*
- 🧠 « Et si vous aviez raison, mais que ce soit dangereux ? » → *« Alors ce sera dangereux, mais je ne peux pas passer une nuit de plus à ne rien faire. »*

**[Léna]** Alors oui, un inconnu au bout d'un mauvais numéro, c'est tout ce qu'il me reste, c'est assez ironique quand on y pense.

**CHOIX STRUCTURANT :**
- A. « D'accord, je reste en ligne, mais n'entrez pas dans ce bâtiment. » → N12 *(confiance +1, branche = "prudent")*
- B. « Je suis désolé, je ne peux pas. » → N11

---

## N11 — LE REFUS ASSUMÉ

**[Léna]** Je comprends, vraiment. Merci quand même d'avoir répondu.

*Séparateur : « 23h58 »* · 🔔 PUSH

**[Léna]** Je vous dérange une dernière fois, je suis devant l'entrepôt.

**MICRO-CHOIX :**
- 🛡 « Ne faites pas de bêtise. » → *« C'est un peu tard pour ça. »*
- 🔍 « Qu'est-ce que vous voulez ? » → *« Que quelqu'un sache, c'est tout. »*
- 🧠 « Je vous avais dit non. » → *« Je sais, c'est pour ça que je ne demande rien. »*

**[Léna]** Si dans une heure je n'ai rien envoyé, appelez le 17 : entrepôt Verdier, route de Lacan. Vous n'êtes pas obligé de répondre, juste de lire.

*(→ `refus = true` : vouvoiement maintenu tout le chapitre, confiance plafonnée à 6, callback ch. 2)*

**CHOIX STRUCTURANT :**
- A. « Je lis, soyez prudente. » → N14 *(confiance +1)*
- B. « ... » → N14

---

## N12 — TU ACCEPTES DE VEILLER

**[Léna]** Merci, vraiment. Vous ne pouvez pas savoir ce que ça change de ne pas être complètement seule ce soir.

→ **N14**

---

## N13 — « POURQUOI MOI ? »

*(⏱ 22s, typing intermittent — incohérence n°2)*

**[Léna]** Franchement ? Le hasard, un mauvais numéro et un bon timing.

🔍 **INTERACTION CACHÉE — insister (« + ») :** « 22 secondes pour répondre ça ? » → *« J'hésitais à vous dire quelque chose, une autre fois, pas ce soir. »* *(lucidite +1)*

**MICRO-CHOIX :**
- 🛡 « Peu importe, je suis là. » → *« Merci, j'en avais besoin. »*
- 🔍 « Vous auriez insisté avec n'importe qui ? » → *« Non, justement, et c'est peut-être ça qui devrait m'inquiéter. »*
- 🧠 « Ça ne me rassure pas, cette réponse. » → *« Moi non plus, si vous voulez tout savoir. »*

→ **N14**

---

## N14 — ELLE Y VA

**[Léna]** Je me rends à l'entrepôt, mon téléphone sera en silencieux, je ne veux pas qu'il me repère ! Mais je vous lis. S'il vous plaît, gardez votre téléphone près de vous, juste ce soir... Je pars maintenant.

**MICRO-CHOIX :**
- 🛡 « Restez dans votre voiture le plus longtemps possible. » → *« Oui, mais je suis trop loin, je ne vois pas grand-chose d'ici. »*
- 🔍 « Décrivez-moi tout, même ce qui vous paraît sans importance. » → *« D'accord, ça permettra de me relire au cas où j'oublierais un détail par la suite, et au passage ça m'occupera l'esprit et calmera cette peur viscérale. »*
- 🧠 « Vous êtes vraiment sûre de vouloir faire ça ? » → *« Non. Mais je n'ai pas le choix, personne d'autre ne le fera. »*

*Séparateur : « 23h31 »*

**[Léna]** Je me suis approchée, tout près ! Accroupie derrière un muret, il fait noir et mon cœur bat à 200 battements par minute, pourvu qu'il ne m'arrive rien !

**[Léna]** Je vois sa voiture, une berline Peugeot 508 grise avec un macaron derrière, j'ai du mal à lire et j'ai peur de me lever, il va me repérer. C'est la même voiture que les autres fois. Que dois-je faire ?

**CHOIX STRUCTURANT :**
- A. « Prenez la plaque en photo, discrètement mais avec le flash. » → N16 *(indices + PLAQUE)*
- B. « Restez cachée, à couvert, et décrivez-moi ce que vous voyez, sans prendre de risque. » → N17
- C. « Je ne le sens pas, partez maintenant tant que vous le pouvez, on avisera plus tard. » → N18

---

## N16 — LA PLAQUE

**[Léna]** 📷 *[photo de la 508]*

**[Léna]** C'est tout ce que j'arrive à avoir sans m'approcher, la lumière du lampadaire tape en plein dessus et mon flash empire les choses, je vais me faire griller.

🔍 **INTERACTION CACHÉE — zoom sur le macaron :** « SENTINEL PRO » lisible. *(indices + AUTOCOLLANT)*

**MICRO-CHOIX :**
- 🛡 « Ne prenez plus de photos, c'est trop risqué. » → *« Je sais bien, mais je voulais au moins avoir le courage de faire ça, ça ne suffira peut-être pas, ou peut-être que si. »*
- 🔍 « Il y a un autocollant sur la vitre arrière. » → *« Oui, mais je n'arrive pas à le lire d'ici, et vous ? »*
- 🧠 « Une plaque à moitié lisible, ça sert à quoi ? » → *« À rien peut-être, ou alors c'est le début d'un indice, on verra bien. J'ai fait mon maximum toute seule, et pourtant j'ai l'impression d'être lâche et de ne pas avoir eu le courage d'affronter ça. »*

→ **N19**

---

## N17 — LA NOTE VOCALE

**[Léna]** 🎤 *[note vocale — 22s, chuchotée]*

> **🎙 SCRIPT TTS — « Repérage »** *(voix jeune femme, chuchotée, tendue, souffle court)*
> « Il y a de la lumière au premier, une fenêtre condamnée avec des planches, mais elles sont récentes, le bois est encore clair... attendez... quelqu'un vient de passer devant la lumière, il porte quelque chose, un carton je crois, je ne vois pas bien. Je vais essayer de me rapprocher. »
>
> **🎧 À mixer en fond, très faible :** un jingle radio avec une bribe de voix d'animateur. **Ne jamais nettoyer** — c'est l'incohérence n°3.

🔍 **INTERACTION CACHÉE — réécouter :** l'option « C'est quoi ce bruit derrière vous ? » apparaît à la deuxième écoute → *« Quel bruit ? ...Une voiture qui passait je suppose, il y en a parfois. Concentrez-vous s'il vous plaît. »* *(lucidite +1)*

**MICRO-CHOIX :**
- 🛡 « N'approchez pas, restez où vous êtes. » → *« Deux minutes, juste deux minutes et je repars. »*
- 🔍 « Il y a quelqu'un d'autre avec lui au premier ? » → *« Je ne sais pas, je n'ai vu qu'une silhouette, mais elle bougeait vite comme si elle savait où aller. »*
- 🧠 « Vous êtes où exactement, là ? » → *« Devant, derrière le muret, pourquoi cette question ? »* ⚠️ *(lucidite +1)*

**CHOIX STRUCTURANT :**
- A. « Non, vous n'approchez pas, c'est non. » → N19
- B. « D'accord mais restez loin de la porte, vraiment loin. » → N19 *(confiance +1)*

---

## N18 — TU LA SUPPLIES DE PARTIR

**[Léna]** Je n'ai pas fait tout ça pour repartir maintenant, pas alors que je suis à vingt mètres.

**MICRO-CHOIX :**
- 🛡 « Ça ne ramènera pas Chloé si vous y passez. » → *« ...Je sais. Je sais que vous avez raison, et c'est bien ça le problème. »*
- 🔍 « Vous cherchez quoi exactement, concrètement ? » → *« Une preuve, n'importe laquelle, quelque chose que la police ne pourra pas classer d'un revers de main. »*
- 🧠 « Vous vous mettez en danger pour une intuition. » → *« C'est tout ce que j'ai, une intuition, c'est tout ce qu'il me reste, ça ne vaut pas grand-chose je sais ! Je n'ai que ça en 7 mois. »*

**[Léna]** Chloé n'aurait pas abandonné, elle. C'est moi qui l'ai abandonnée la première.

→ **N19**

---

## N19 — L'INCIDENT

*(⏱ 25s · statut « Léna est hors ligne »)* · 🔔 PUSH

**[Léna]** Il sort, de l'entrepôt, il s'approche de ma position, mince...

**[Léna]** Il est en train de mettre un sac dans son coffre, il a l'air lourd, j'espère que ce n'est pas...

**MICRO-CHOIX :** *(urgence)*
- 🛡 « Cachez-vous. » → *« Je suis derrière le muret, je ne bouge pas, je l'entends, je le sens pas loin de moi. »*
- 🔍 « Quelle taille, le sac ? » → *« Grand, lourd, il le porte à deux mains et galère à le soulever. »*
- 🧠 « J'appelle la police ? » → *« Non pas encore, attendez, ça se trouve c'est des déchets, il me faut plus de preuves, si on rate notre coup on n'aura pas de deuxième chance, déjà que la police me prend pour une folle. »*

**[Léna]** Il regarde vers moi, j'ai croisé son regard, je suis en danger ?

**MICRO-CHOIX :** *(aucune réponse — le silence est la réponse)*
- 🛡 « NE BOUGEZ PLUS, ça va aller ! »
- 🔍 « Il vous voit ? »
- 🧠 « Léna répondez, s'il vous plaît, ou j'appelle la police ! »

**[Léna]** merde

### 🖤 ÉCRAN NOIR NARRATIF — 60 secondes

*(Bascule plein écran. Texte en effet machine à écrire, ~45ms/caractère. Musique : segment 2, reprise à l'offset où l'intro s'est coupée, montée progressive sans culminer.)*

> *Léna ne répond plus...*
>
> *(20s)*
>
> *Il fait nuit, elle est seule, et vous êtes à des kilomètres. L'a-t-il enlevée ? Est-elle rentrée ?*
>
> *(20s)*
>
> *Vous ne pouvez rien faire d'autre qu'attendre, ou prévenir la*

*(Coupure nette — musique et texte s'interrompent en pleine phrase. Retour à la conversation.)*

→ **N20**

---

## N20 — LE RETOUR

*Séparateur : « 00h34 »* · 🔔 PUSH
*(Tous les messages décoratifs du joueur reçoivent leur « Vu. » d'un coup.)*

**[Léna]** C'est bon, je suis dans ma voiture, il ne m'a pas vue... enfin je crois, je vois une ombre, c'est quoi ! ... oula c'était juste un animal et la lune, il faut que je redescende en émotion car je deviens parano.

**MICRO-CHOIX :**
- 🛡 « Vous m'avez fait une peur bleue. » → *« Désolée de vous embarquer là-dedans, je tremble encore de tout mon corps, je n'arrive pas à tenir mon téléphone droit, je ne sais même pas si je pourrai conduire pour le retour, en plus je pleure, il me faut un peu de temps pour encaisser tout ça, je crois... »*
- 🔍 « Il vous a vue ou pas, dites-moi la vérité. » → *« Je ne sais pas, il a regardé dans ma direction et il s'est arrêté, et c'est ça le pire, ne pas savoir. »*
- 🧠 « Vous êtes vraiment en sécurité là ? » → *« Il me semble que oui, j'ai les portes verrouillées, j'ai appuyé genre 10 fois sur le bouton pour être sûre, mon moteur est allumé, et je suis pratiquement prête à partir, mon état émotionnel lui c'est autre chose. »*

**CHOIX STRUCTURANT :**
- A. « Rentre chez toi, on fait le point demain. » → N9
- B. « Il faut porter ça à la police, maintenant. » → N9 *(lucidite +1)*

*(Les deux choix ci-dessus mènent directement à N9 — pas de nœud de transition séparé : l'écran vidéo ci-dessous est la position 0 du N9, voir §2 de l'addendum.)*

---

## N9 — 🤖 MOMENT IA : LA DÉCOMPRESSION

### 🎥 ÉCRAN DE TRANSITION VIDÉO

*(Plein écran, muette, ~5 s : Léna rentre chez elle, vue de dos, entre dans un hall d'immeuble la nuit. Texte incrusté DANS la vidéo elle-même [« Léna rentre chez elle. »] — aucune superposition côté app, rien à synchroniser. Aucune interaction, aucun bouton skip, musique en silence [aucun segment narratif déclenché]. Enchaîne automatiquement sur la suite : c'est le délai du message suivant qui donne sa durée à l'écran, même mécanisme que l'écran noir du N19. `content_type = 'video'`, media `lena-rentre-chez-elle.mp4`, déclarée à la main comme le system du N22 — voir generate-seed-content.py.)*

**[Léna]** Je suis rentrée, je respire un peu mieux... Ça vous dérange si l'on se tutoie ? Après ce qu'on vient de vivre, le « vous » me paraît un peu ridicule, qu'en penses-tu ?

⚠️ **Le glissement vouvoiement → tutoiement dans cette phrase est volontaire** (« Ça vous dérange » puis « qu'en penses-tu »). Ne pas l'harmoniser, ne pas le « corriger » — c'est le moment même de la bascule, elle hésite en le disant. Le tutoiement s'applique pleinement à partir de la phrase suivante et pour tout le reste du chapitre.

*(Variante si `refus = true` — remplace la ligne ci-dessus, elle n'a pas gagné ce droit :)*
> Je suis rentrée, je respire un peu mieux... Ça ne vous dérange pas si je continue à vous vouvoyer, je crois que j'en ai besoin ce soir.

**[Léna]** Et merci pour cette présence, même à distance, ça me donne de la force, ce dont j'avais grand besoin.

**[Léna]** Dis... je ne sais rien de toi, même pas ton prénom...

*(→ tutoiement à partir d'ici, sauf si `refus = true`, où le vouvoiement tient tout le chapitre — bible §2)*

*(Saisie libre. Le prénom est demandé explicitement et stocké en `detail_perso` — catégorie `prenom` de la liste d'autorisation. Léna l'utilise dans ses réponses suivantes, et le réutilisera à l'ouverture du chapitre 2. Elle tutoie, sauf si `refus = true`. 2-4 échanges, puis raccrochage vers N21.)*

---

## N21 — LA PHOTO

**[Léna]** Je t'ai pas dit, mais je me suis approchée de l'entrepôt, je sais c'était risqué, c'est pour ça que je ne te l'ai pas dit, je ne voulais pas que tu t'inquiètes pour moi. Donc avant qu'il sorte j'ai pris une photo par une fenêtre, un peu floue et mal prise, j'étais accroupie, mais je pense avoir trouvé des preuves...

*(Variante si `refus = true` — remplace la ligne ci-dessus, le vouvoiement tient tout le chapitre, bible §2 :)*
> Je ne vous ai pas dit, mais je me suis approchée de l'entrepôt, je sais c'était risqué, c'est pour ça que je ne vous l'ai pas dit, je ne voulais pas que vous vous inquiétiez pour moi. Donc avant qu'il sorte j'ai pris une photo par une fenêtre, un peu floue et mal prise, j'étais accroupie, mais je pense avoir trouvé des preuves...

**[Léna]** 📷 *[photo de l'intérieur de l'entrepôt]*

**MICRO-CHOIX :**
- 🛡 « Tu as pris ce risque juste pour ça ? » → *« Regarde bien s'il te plaît, tu comprendras, tu as un regard extérieur. »*
- 🔍 « Il y a un téléphone posé sur l'établi. » → *« Ah ouais ! Mais j'ai pas vu ça moi, où ça ? »* ⚠️ *(enquete)*
- 🧠 « Qu'est-ce que je suis censé voir ? » → *« Le mur, à droite, au-dessus de l'établi. »*

**[Léna]** Tu vois le trousseau accroché au mur ? Zoome sur le porte-clés.

*(Variante si `refus = true` :)*
> Vous voyez le trousseau accroché au mur ? Zoomez sur le porte-clés.

🔍 **INTERACTION CACHÉE — zoom :** silhouettes gravées nettes, téléphone rose fissuré visible au fond. *(indices + TELEPHONE)*

→ **N22**

---

## N22 — LE CLIFFHANGER

**[Léna]** Chloé avait exactement le même, c'est moi qui le lui avais offert.

**MICRO-CHOIX :**
- 🛡 « Tu es sûre de toi, vraiment ? » → *« Sûre et certaine. »*
- 🔍 « Ça peut être une coïncidence, non ? » → *« Attends, écoute-moi, je vais t'expliquer pourquoi. »*
- 🧠 « ...Ben ça alors ! » → *« Ouais. Attends, c'est pas fini. »*

**[Léna]** Je t'explique, il n'en existe que deux au monde, je les avais fait graver pour nous deux, un pour elle et un pour moi, lors d'un voyage où on était en vacances. Ça symbolisait notre amitié, nous quoi !

*(Variante si `refus = true` :)*
> Je vous explique, il n'en existe que deux au monde, je les avais fait graver pour nous deux, un pour elle et un pour moi, lors d'un voyage où on était en vacances. Ça symbolisait notre amitié, nous quoi !

**[Léna]** Et le mien a disparu de mon appartement il y a trois semaines, impossible de mettre la main dessus, et là...

### 🖤 ÉCRAN DE FIN DE CHAPITRE

*(Plein écran. Effet machine à écrire, pauses entre les lignes. Musique : segment 3, reprise à l'offset du N19, cette fois jusqu'au bout — c'est le seul segment qui culmine.)*

> Quelqu'un est entré chez Léna.
>
> *(pause)*
>
> Quelqu'un sait qu'elle cherche.
>
> *(pause)*
>
> Et ce quelqu'un a désormais votre numéro.

*(temps)*

> **La suite de Numéro Inconnu, prochainement.**
>
> *Un retour, une note, une idée ? Écrivez-nous.*

*(Puis compte à rebours vers le chapitre 2.)*

---

## RÉCAPITULATIF DES INCOHÉRENCES PLANTÉES

| # | Où | Quoi | Payoff |
|---|---|---|---|
| 1 | N8 (zoom capture + micro-choix 🧠) | Signalement en juin, mais recherche depuis 7 mois | Ch. 3 — les 5 mois de silence |
| 2 | N13 (22s d'hésitation + insister) | « J'hésitais à vous dire quelque chose » | Ch. 3 — elle cache quelque chose depuis le début |
| 3 | N17 (réécoute du vocal) | Radio en fond alors qu'elle est dehors, seule | Ch. 4 — elle appelait depuis sa voiture, repérage caché |
| 4 | — (bible §7) | Le 12 mars | Ch. 3 — le jour où elle a cru voir Chloé |

## NOUVEAUTÉS À IMPLÉMENTER

Voir le document d'addendum technique : écran noir narratif du N19, effet machine à écrire, trois segments musicaux issus d'un même morceau, vibration à l'arrivée des messages quand le son est coupé, prompt système IA modifié pour demander le prénom, tutoiement à partir du N20.
