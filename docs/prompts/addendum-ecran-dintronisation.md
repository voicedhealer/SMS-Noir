## ADDENDUM — Écran d'intronisation (avant la première conversation)

Séquence d'ouverture jouée **une seule fois**, à la toute première ouverture de l'histoire (jamais rejouée ensuite, sauf réinitialisation). Elle précède le premier `get-state` — aucun impact sur le moteur, c'est du client pur.

**Trois panneaux, texte seul, fond noir, typographie du thème :**

1. « Jeudi soir. » / « Rien de prévu. »
2. « Le téléphone posé à côté de vous. » / « La soirée sera tranquille. »
3. « 22h47. »

**Rythme** : chaque panneau apparaît en fondu (~800ms), reste lisible ~2s, disparaît en fondu. Le troisième panneau (« 22h47. ») reste seul un peu plus longtemps (~2,5s) — c'est le basculement.

**Puis** : transition vers l'écran de conversation, **vide**. En-tête « Numéro inconnu » / « en ligne ». Aucun message. **4 secondes de silence total.** Puis l'indicateur « en train d'écrire… » démarre, et le déroulé normal du N1 commence.

**Contraintes :**
- Aucun bouton, aucun skip visible. La séquence dure ~10s au total, elle ne mérite pas d'être passée. (Un skip au tap peut être ajouté en debug uniquement.)
- Aucune mention de jeu, de fiction, de chapitre, de mécanique. Pas de tutoriel. Le joueur comprend par l'usage.
- Le texte est en dur côté client pour cette histoire — mais prévois-le paramétrable par histoire (`stories.intro_panels` en JSONB, ou équivalent) puisque l'architecture est multi-histoires. Argumente si tu préfères une autre approche.
- Les 4 secondes de vide sont volontaires et non négociables : c'est le calme qui rend l'intrusion violente. Ne pas les réduire pour « fluidifier ».
- Persistance : un indicateur local suffit (l'intro n'est pas de l'état de jeu). Si le joueur réinstalle, la revoir n'est pas grave.

Documente la séquence dans `DESIGN.md` avec ses timings exacts.

---