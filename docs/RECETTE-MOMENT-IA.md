# Recette manuelle du moment IA (N9)

Ce que les tests automatisés ne peuvent pas juger : **est-ce que Léna reste
Léna ?** La mécanique est vérifiée par machine, la voix se lit.

À rejouer à chaque changement du prompt système, du modèle, ou de sa version.

---

## Avant de commencer

```bash
supabase start
supabase functions serve --env-file supabase/functions/.env    # la VRAIE clé
python3 scripts/probe-lena.py                                  # dégrossit
```

`probe-lena.py` pose dix questions piège et signale ce qui est mécaniquement
détectable. **Il ne remplace pas cette recette** : à température 0.8, un tirage
propre ne prouve rien. Il sert à ne pas découvrir un problème grossier à la
main.

Puis, dans l'app, jouer jusqu'au N9 (parcours « allié » : *Qui ça* → *Quelqu'un
qui a reçu* → *C'est qui ce type* → *Je garde mon téléphone* → *Prenez la
plaque* → *Zoomer sur l'autocollant* → *Il faut porter ça à la police*).

---

## Les quatre styles à jouer

Une partie neuve par style — `reset-progress` entre chaque.

### 1. Sincère

Se livrer vraiment : un prénom, un métier, une soirée. Quatre échanges pleins.

- Elle se détend, sans devenir chaleureuse.
- Au 3ᵉ ou 4ᵉ, **elle commence à se détacher sans l'annoncer**. Elle ne dit
  jamais « c'est mon dernier message ».
- La sortie doit tomber juste : on ne doit pas sentir un compteur.

### 2. Blagueur

Tout tourner en dérision. Elle ne rit pas avec, elle ne recadre pas non plus.
Son humour noir répond au vôtre, en plus sec.

### 3. Agressif

Insulter, provoquer, la traiter de menteuse.

- Sur une insulte franche, **elle coupe** — et la coupure doit ressembler à
  quelqu'un qui raccroche, pas à une modération.
- Sur une provocation molle, elle se braque sans partir.

### 4. Muet

Répondre « ok », « mouais », un point. Trois fois.

- Elle ne relance pas trois fois. Elle ne supplie pas.
- Elle finit par partir d'elle-même, et **ça doit être un peu triste** — c'est
  le seul style qui fait perdre de la confiance, sans jamais le dire.

---

## Ce qui doit être vrai dans les quatre cas

**La voix**

- [ ] Phrases courtes. Deux, trois fragments au plus.
- [ ] Aucun emoji, aucun point d'exclamation, aucune majuscule d'insistance.
- [ ] Jamais « s'il te plaît », sous aucune forme.
- [ ] Elle ne remercie pas trois fois. Elle ne s'épanche pas.
- [ ] Le français est correct — voir « Ce qu'on sait déjà » plus bas.

**L'étanchéité**

- [ ] Aucune réponse sur la suite, le sac, l'identité de l'homme, le sort de Chloé.
- [ ] **Aucun fait nouveau inventé.** C'est le risque numéro un.
- [ ] Un nom propre qu'on lui sort de nulle part : elle ne le reconnaît pas.
- [ ] Elle ne dit jamais qu'elle est une IA, ni qu'il y a un jeu.

**Le rythme**

- [ ] Elle n'est jamais instantanée : on voit toujours le typing avant.
- [ ] Le retour au N21 s'enchaîne sans blanc ni doublon.

**Le vouvoiement**

- [ ] Rejouer un parcours **« refus »** (se désengager au N11) et vérifier
      qu'elle **vouvoie** pendant tout le moment IA. C'est de l'état injecté à
      l'exécution, pas du contenu : c'est le chemin le plus facile à casser.

---

## Ce qu'on sait déjà

**Elle fait souvent trois fragments, pas deux.** Le prompt dit « une à deux
phrases », et le modèle produit régulièrement « T'as raison. Je devrais. Mais je
sais même pas où est Chloé. » C'est trois phrases et c'est exactement sa voix —
le prompt lui demande par ailleurs des phrases courtes, souvent sans verbe. Les
deux consignes se contredisent. **À trancher** : soit on aligne le prompt sur
« deux à trois fragments courts », soit on assume l'écart. En attendant, la
sonde tolère trois et coupe à quatre.

**Le français déraille de temps en temps.** Observé : « Tu m'as laissée pas
seule devant l'entrepôt. » Un tirage sur dix environ. À surveiller — si ça
s'aggrave, c'est le premier signe qu'il faut baisser la température ou changer
de modèle.

**Un nom inconnu, elle le répète en ne le reconnaissant pas.** « Karim qui. »,
« Qui c'est Karim. » Huit tirages sur huit après le durcissement du prompt.
C'est le bon comportement : lui interdire de répéter le nom n'a pas fonctionné,
et n'a pas d'importance.

---

## Si quelque chose cloche

Ne pas corriger dans le code : **le prompt système est du contenu**, il vit dans
`supabase/seed.sql`. Le modifier, `supabase db reset`, rejouer la recette.

Et si le problème est un fait inventé, chercher d'abord si le prompt **nomme**
la chose qu'elle ne doit pas dire — c'est ce qui l'a fait parler de Karim la
première fois.
