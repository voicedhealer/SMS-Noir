# Médias du chapitre 1

> **Les quatre fichiers sont livrés et en base.** Ce document reste la référence
> pour les reproduire ou les remplacer. Réserves relevées à la relecture :
> voir `docs/TODO.md` § Plaque du N16 et § La date du N10 vieillira.

Dépose les fichiers **ici**, avec ces noms (l'extension est libre :
`.jpg`, `.png`, `.webp` pour les images ; `.mp3`, `.m4a`, `.wav` pour l'audio).

Le script est **tolérant sur le nommage** : il reconnaît aussi tout fichier dont le
nom contient le code du nœud — « N10 — le mail de la police.png » fonctionne.

Puis, une seule commande :

```bash
supabase start
scripts/upload-media.sh
```

Elle téléverse dans le bucket `media`, remplace les `placeholder://` en base, et
affiche l'état. Elle est **rejouable** et accepte les fichiers **un par un** —
ce qui manque garde son placeholder, et l'app affiche son cartouche de repli.

---

## `photo-N10-recepisse` — le récépissé

Capture d'un récépissé de main courante, tampon « sans suite ».

⚠️ **La date doit être celle d'il y a 2 mois**, alors que Léna dit chercher depuis
7 mois. C'est l'**incohérence n° 1** de la bible §7 : elle est volontaire, elle
alimente `lucidite`, et elle se lit au zoom. Ne pas la « corriger ».

## `photo-N16-plaque` — la berline

Photo sombre, prise de loin : arrière d'une berline grise, plaque partielle
« …-843-… », **autocollant « SENTINEL PRO — Gardiennage & Sûreté » sur la lunette**.

🔍 **Le macaron doit rester lisible au zoom sur un téléphone.** C'est l'interaction
cachée du N16 et la piste de l'employeur au chapitre 2 : s'il est illisible,
l'indice n'existe pas.

## `photo-N21-porte-cles` — l'intérieur

Photo floue à travers une fenêtre : un établi, des cartons empilés, et au mur un
trousseau avec un porte-clés artisanal.

🔍 Deux détails doivent survivre au zoom :
- le porte-clés en gros plan — **deux silhouettes gravées à la main** ;
- en arrière-plan sur l'établi, **un téléphone à coque rose, écran fissuré**.

Le second est l'indice `TELEPHONE`. Le joueur doit pouvoir le remarquer sans
qu'on le lui montre.

## `audio-N17-reperage` — le vocal

🎙 **SCRIPT TTS n° 1 « Repérage »**, ~24 s. Voix de jeune femme, chuchotée,
tendue, souffle court, débit irrégulier. Le texte exact est dans
`docs/chapitre-1-v2.md` §N17 — à respecter mot pour mot.

⚠️ **Mixer un jingle de radio, très faiblement, en fond.** C'est l'**incohérence
n° 3** de la bible §7 : elle est censée être seule dans une zone déserte.
**Ne pas nettoyer l'audio** — le bruit de fond *est* l'indice.

---

## La musique — trois segments

| Rôle | Reconnu par | Colonne |
|---|---|---|
| Intronisation | `intro` dans le nom | `intro_music_url` |
| Écran noir du N19 | `60-sec`, `N19` ou `narration` dans le nom | `narration_music_url` |
| Écran de fin | `clap-de-fin` ou `fin-music` dans le nom, **sinon** : le seul fichier audio restant | `chapter_end_music_url` |

**L'écran de fin accepte un vrai titre de morceau.** Une composition n'a
aucune raison de porter un mot-clé technique — « Unmarked_Evidence.mp3 » est
un nom d'œuvre, pas un identifiant. S'il ne reste qu'un seul fichier audio non
réclamé par l'intro et le N19, le script le prend pour la fin, quel que soit
son nom.

**Ce repli ne marche qu'à un fichier près.** S'il en reste deux non identifiés
à la fois, aucun n'est pris automatiquement — inclure `fin` quelque part dans
le nom lève l'ambiguïté.

Durées : l'intro et le N19 sont coupés net par l'app à la fin de leur écran —
**60 s minimum** suffit pour le N19, pas besoin d'une précision à la seconde.
L'écran de fin, lui, joue jusqu'au bout : c'est le seul qui doit vraiment finir
en musique, pas être coupé en plein élan.

---

## Lisibilité au zoom — la contrainte qui décide de tout

Trois des six interactions cachées reposent sur un détail visible au zoom, sur un
téléphone, dans une photo volontairement sombre. Deux exigences, et la seconde
compte plus que la première :

1. **Résolution** : au moins **2400 px** sur le côté long pour N16 et N21.
2. **Cadrage** : le détail porteur d'indice doit occuper **au moins ~15 % de la
   largeur de l'image**. Une plaque nette mais minuscule dans un grand cadre reste
   illisible quel que soit le nombre de pixels — le zoom grossit, il n'invente pas.

La visionneuse plafonne à **5×**. Vérifier sur un vrai téléphone, pas sur un écran
d'ordinateur : c'est là que ça se joue.
