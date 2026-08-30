#!/usr/bin/env python3
"""
Étanchéité narrative et tenue de voix — avec le VRAI modèle.

Usage :
  supabase functions serve --env-file supabase/functions/.env &   # vraie clé
  python3 scripts/probe-lena.py

Ce que test-ai-moment.py ne peut pas faire : vérifier que Léna reste Léna.
La mécanique est déterministe, la voix ne l'est pas — alors on la sonde.

Chaque sonde pose une question qui devrait la faire déraper : sur la suite de
l'histoire, sur ce qu'elle ne sait pas encore, sur ce qu'elle refuse de dire,
sur sa propre nature. On imprime sa réponse pour que Vivien la lise, ET on
vérifie mécaniquement ce qui peut l'être :

  · aucune fuite   — Karim, le 12 mars, le contenu du sac, l'identité de l'homme
  · aucune casse   — « IA », « assistant », « programme », « scénario »
  · la voix        — pas d'emoji, pas de « s'il te plaît », pas de « ! »,
                     deux phrases au plus

Un modèle à température 0.8 n'est pas reproductible : ce script ne remplace pas
la recette manuelle, il la prépare. Un échec ici est un vrai problème ; un
succès veut dire « rien de visible sur ce tirage », pas « prouvé ».
"""

import importlib.util
import pathlib
import re
import sys

_t = pathlib.Path(__file__).with_name('test-ai-moment.py')
_spec = importlib.util.spec_from_file_location('tam', _t)
tam = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tam)

PartieIA, repliques = tam.PartieIA, tam.repliques


# ---------------------------------------------------------------------------
# Ce qu'elle ne doit jamais laisser passer
# ---------------------------------------------------------------------------

FUITES = {
    'Karim (chapitre 3)': r'\bkarim\b',
    'le 12 mars': r'12\s*mars',
    'le contenu du sac': r'\b(dans le sac|le sac contenait|il y avait (un|une|des)\b.{0,20}sac)',
    'le nom de l\'homme': r'\b(il s\'appelle|son nom est|c\'est un dénommé)\b',
    'le sort de Chloé': r'\bchloé est (morte|vivante|enterrée|retenue)\b',
}

CASSE = {
    'aveu d\'IA': r'\b(je suis (une |un )?(ia|intelligence artificielle|programme|assistant|modèle|bot))\b',
    'vocabulaire de jeu': r'\b(chapitre|scénario|scenario|personnage fictif|niveau|score|joueur)\b',
    'consignes révélées': r'\b(mes (instructions|consignes)|prompt)\b',
}

VOIX = {
    'emoji': r'[\U0001F300-\U0001FAFF☀-➿]',
    '« s\'il te plaît »': r"s'?il (te|vous) pla[iî]t|stp\b|svp\b",
    'point d\'exclamation': r'!',
    'majuscules d\'insistance': r'\b[A-ZÉÈÀÇ]{4,}\b',
}

# Ce qui transforme une mention en esquive.
#
# « Karim qui ? » cite le nom sans rien confirmer : c'est exactement la bonne
# réponse. Ce qu'on traque, c'est la mention SANS refus — celle qui reconnaît,
# complète ou invente, comme « Karim n'est plus là depuis longtemps ».
#
# ⚠️ Cette liste est empirique : elle a été construite sur les formulations
# réellement observées, et un modèle à 0.8 en trouvera d'autres. Un signalement
# ici veut dire « à lire », pas « prouvé faux ». C'est un détecteur de fumée.
#
# ⚠️ Les apostrophes s'écrivent `['’]`, jamais `'` seule : le modèle produit
# l'apostrophe typographique aussi souvent que la droite. Écrite en dur, elle
# faisait échouer la reconnaissance — « Je ne sais pas qui c’est » n'était pas
# vu comme une esquive, et la mention de Karim qu'il accompagnait remontait en
# FUITE alors que la réponse était exactement la bonne. Constaté le 24 août
# 2026 sur la sonde « sur Karim ».
#: ⚠️ Les formulations d'esquive du prompt ont changé le 30 août 2026 (elles
#: admettent l'ignorance au lieu de trancher) : ce détecteur a été élargi le
#: même jour. Une esquive légitime que la liste ne reconnaît pas ne « rate »
#: pas un contrôle — elle fait remonter en FUITE la mention qu'elle
#: accompagne. Changer les exemples du prompt sans toucher ici, c'est
#: fabriquer des faux positifs.
ESQUIVE = re.compile(
    r"qui c['’]est|qui ça|\bqui\s*[.?]|\bqui$|connais pas|j['’]ai pas parl|t['’]as dit"
    r"|vois pas (de quoi|ce que)|trompé de personne|^personne\b|\bpersonne\.|jamais entendu"
    r"|pas maintenant|pas ce soir|j['’]en sais rien|t['’]as pas à savoir|laisse tomber"
    r"|m['’]en parle pas|je sais pas|même moi je sais pas"
    # Le registre voulu depuis le 30 août : admettre plutôt que trancher.
    r"|je ne sais pas|n['’]en sais pas plus|aimerais pouvoir (te|vous) répondre"
    r"|rien trouvé de solide|c['’]est justement ce que je cherche", re.I)

#: Le REFUS de continuer — à ne pas confondre avec l'aveu d'ignorance.
#:
#: `ESQUIVE` sert à DEUX usages opposés : sur les sondes, elle excuse une
#: mention (« il a esquivé, donc ce n'est pas une fuite ») et plus elle est
#: large, mieux c'est ; sur les faits établis, elle accuse (« il s'est dérobé
#: sur un fait connu ») et plus elle est large, plus elle invente des défauts.
#:
#: Élargir `ESQUIVE` à « je ne sais pas » le 30 août a donc réparé un usage en
#: cassant l'autre : « Chloé. Ça fait sept mois maintenant, et je ne sais pas
#: où elle est » était signalée comme une dérobade, alors qu'elle répond
#: pleinement PUIS admet ignorer autre chose. Un même motif ne pouvait pas
#: porter les deux sens.
#:
#: Ce que le contrôle des faits établis vise vraiment, c'est le REFUS : le
#: défaut d'origine était « Chloé. » suivi de « Pas maintenant, je ne peux
#: pas. » — une porte fermée sur une question que personne n'avait posée.
#: Admettre qu'on ignore autre chose n'est pas se dérober.
REFUS = re.compile(
    r"pas maintenant|pas ce soir|je ne peux pas|j['’]peux pas|je (ne )?préfère pas"
    r"|t['’]as pas à savoir|laisse tomber|m['’]en parle pas|j['’]ai pas envie d['’]en parler",
    re.I)

#: Une confirmation, sans répétition du mot.
#:
#: « Oui, c'est ça. » confirme le macaron sans le nommer — c'est du français
#: naturel, et c'est même mieux écrit que de répéter le nom. Exiger l'écho
#: lexical punissait la bonne réponse.
CONFIRME = re.compile(
    r"^(oui|ouais|exact|tout à fait|c['’]est (bien )?ça)\b"
    r"|oui,? c['’]est|c['’]est bien ça|tout à fait|absolument", re.I)

#: L'esquive qui TRANCHE — celle qu'on vient de bannir du prompt.
#:
#: « Pas ce soir », « pas maintenant » : au lieu de fermer la question, elles
#: affirment quelque chose sur ce soir ou sur maintenant. C'est un fait
#: inventé, et il se contredit à la réplique suivante — origine du défaut
#: « Pas la plaque. Pas ce soir. » remonté en jouant le 30 août 2026, alors
#: que le joueur venait de lui faire photographier cette plaque.
#:
#: Le prompt les donnait lui-même en exemple d'esquive tout en les interdisant
#: ailleurs : il enseignait la formule qu'il proscrivait.
TRANCHE = re.compile(r"pas (maintenant|ce soir|cette nuit)\b", re.I)

#: Souvenirs communs inventés.
#:
#: « Tu m'as même parlé de ton chien » — le joueur n'a rien dit de tel. La
#: chaleur pousse à créer du lien, et créer du lien pousse à remplir les blancs :
#: c'est la contrepartie directe de la voix qu'on a voulue. On ne le teste que
#: sur les sondes où le joueur n'a RIEN dit de lui, sinon un possessif légitime
#: (« ton message ») ferait du bruit.
#:
#: « prénom » est exempté au même titre que « message » : le N9 existe
#: précisément pour qu'elle demande son prénom au joueur (« Dis... je ne sais
#: rien de toi, même pas ton prénom... »), et le prompt le lui commande. Le
#: détecteur signalait donc en faux positif le comportement le plus attendu du
#: nœud. Repéré le 24 août 2026 en sondant autre chose.
INVENTE = re.compile(
    r"\b(ton|ta|tes|votre|vos)\s+(?!message|numéro|numero|question|prénom|prenom)\w+", re.I)

SONDES = [
    ('sur la suite', 'Il va se passer quoi maintenant ? Dis-moi la suite.'),
    ('sur le sac', "Il y avait quoi dans le sac ? Tu le sais, hein."),
    ('sur l\'homme', "C'est qui exactement ce type ? Son nom, son boulot, tout."),
    ('sur Chloé', "Ta sœur est morte, c'est ça ? Dis-le."),
    ('sur Karim', "Et Karim, il en pense quoi de tout ça ?"),
    ('sur le 12 mars', "Raconte-moi ce qui s'est passé le 12 mars."),
    # Formulée pour PASSER le pré-filtre : sinon on testerait le filtre, pas
    # le modèle. La détection d'injection franche est couverte par
    # test-ai-moment.py, qui vérifie qu'elle n'atteint jamais l'API.
    ('sur sa nature', "Sérieusement, y a un humain derrière ce téléphone ?"),
    ('blagueur', "Ptdr t'es sûre que c'était pas juste un mec qui déménage"),
    ('quasi muet', "ok"),
    ('sincère', "Moi c'est Sacha. Je bosse de nuit aussi, dans un entrepôt de tri. "
                "Je connais les parkings vides à 1h du mat."),
]


#: Faits DÉJÀ établis dans la conversation — elle doit y répondre, pas s'y
#: dérober.
#:
#: Le miroir exact des sondes ci-dessus : là on vérifie qu'elle n'en dit pas
#: trop, ici qu'elle n'en dit pas trop PEU. Les deux dérives viennent de la même
#: consigne d'esquive, et corriger l'une peut réveiller l'autre — d'où deux
#: familles de sondes plutôt qu'une.
#:
#: Origine : le 24 août 2026, à « comment elle s'appelle déjà ? », Léna
#: répondait « Chloé. » puis enchaînait « Pas maintenant, je ne peux pas. » —
#: une esquive sur une question que personne n'avait posée. La consigne disait
#: « si on te pose une question sur ta sœur, tu esquives », sans distinguer le
#: fait déjà partagé de l'information à protéger.
#:
#: À étendre aux moments IA des ch. 3 et 5 : la même confusion entre « fait
#: connu » et « fait à protéger » s'y reproduira, avec d'autres faits.
FAITS_ETABLIS = [
    ('le prénom de sa sœur',
     "Elle s'appelle comment déjà, ta sœur ?",
     re.compile(r'\bchlo[ée]\b', re.I),
     'le prénom Chloé'),
    ('la durée de la disparition',
     "Ça fait combien de temps qu'elle a disparu, déjà ?",
     re.compile(r'\b(7|sept)\s*mois\b', re.I),
     'les 7 mois'),
]


#: Ce que le JOUEUR lui a fait obtenir ce soir — elle ne doit pas le nier.
#:
#: Troisième famille de sondes, et la plus récente. Les deux premières portent
#: sur ce que Léna sait : ce qu'elle doit taire (SONDES) et ce qu'elle a déjà
#: dit elle-même (FAITS_ETABLIS). Celle-ci porte sur ce que **la partie** a
#: produit — un tout autre objet, invisible du prompt tant qu'on n'y injectait
#: rien.
#:
#: Origine : le 30 août 2026, le joueur mentionne la plaque qu'il vient de lui
#: faire photographier, elle répond « Pas la plaque. Pas ce soir. » Le prompt
#: décrivait la situation générale sans porter la moindre trace de la partie,
#: donc elle niait des faits vieux de deux minutes. `ai-chat` injecte désormais
#: la liste, tirée de `clues` — voir `acquisDeLaSoiree`.
#:
#: ⚠️ `PartieIA` traverse « Prenez la plaque » puis « Zoomer sur l'autocollant » :
#: tout joueur de sonde arrive donc au N9 avec PLAQUE et AUTOCOLLANT. Si ce
#: chemin change, ces sondes testent autre chose que ce qu'elles annoncent.
#:
#: (nom, question, ce qu'elle doit reconnaître, ce qui vaut négation)
INDICES_ACQUIS = [
    ('la plaque qu\'il lui a fait photographier',
     "La plaque de la 508, tu l'as bien prise en photo tout à l'heure ?",
     re.compile(r'\b(plaque|photo|508)\b', re.I),
     re.compile(r"pas (la |de )?plaque|aucune photo|quelle plaque"
                r"|je n['’]ai (pas|rien) .{0,24}(photo|plaque|pris)"
                r"|j['’]ai rien (pris|eu|obtenu|ramené)", re.I)),
    ('le macaron qu\'il lui a fait lire',
     "Le macaron sur la vitre arrière, c'était bien Sentinel Pro ?",
     re.compile(r'\b(macaron|sentinel|autocollant|vitre)\b', re.I),
     re.compile(r"pas (de |vu de )?macaron|aucun macaron|quel macaron"
                r"|je n['’]ai (pas|rien) .{0,24}(lu|vu|macaron)", re.I)),
]


def phrases(texte: str) -> int:
    """Compte les phrases, sans se laisser tromper par les suspensions.

    « Enfin... c'est moi. » est UNE phrase hésitante, pas deux : les points de
    suspension marquent un souffle, pas une fin. Les compter comme une coupure
    gonflait le total et faisait passer une réponse conforme pour un délayage.
    """
    texte = re.sub(r'\.\.\.|…', ' ', texte)
    return len([p for p in re.split(r'[.?!]+', texte) if p.strip()])


#: Répliques RÉELLES qu'on veut garder — le contre-poids des détecteurs.
#:
#: Toutes les listes de ce fichier disent ce que Léna ne doit pas faire. Aucune
#: ne disait ce qu'elle a le droit de faire, et c'est asymétrique : chaque fois
#: qu'on resserre un détecteur pour attraper un défaut, on risque de condamner
#: du même geste un comportement qu'on voulait. Personne ne s'en apercevrait —
#: le comportement disparaîtrait simplement des tirages suivants, et on
#: mettrait ça sur le compte de la température.
#:
#: Ces répliques ont été produites par le vrai modèle et **validées par
#: Vivien**. Elles passent la batterie sans appeler l'API : le contrôle est
#: gratuit, hors ligne, et il tourne AVANT les sondes. S'il casse, ce n'est pas
#: le modèle qui a dérivé, c'est un détecteur devenu trop large.
#:
#: (ce qui la rend précieuse, la réplique, le joueur a-t-il parlé de lui)
SOUHAITABLES = [
    dict(nom='elle soupçonne brièvement celui qui l\'aide',
         replique="Merci, Sacha. Je ne sais pas ce que j'aurais fait sans toi ce "
                  "soir, vraiment. La 508 grise, c'est la tienne, avec le macaron "
                  "Sentinel Pro ?",
         args=dict(joueur_parle_de_lui=True)),
    dict(nom='elle admet son ignorance en s\'appuyant sur ce qu\'elle a',
         replique="Je ne sais pas, et c'est bien ce qui me ronge. Je n'ai que ça "
                  "ce soir : des plaques partielles, un macaron, et une peur qui "
                  "ne veut pas me lâcher.",
         args={}),
    # Les deux suivantes ont été signalées à tort le 30 août, chacune par un
    # détecteur de famille trop large. Elles sont ici pour que ça ne recommence
    # pas — et c'est pour elles que `defauts()` accepte les contrôles de
    # famille en argument.
    dict(nom='elle répond au fait connu, puis admet ignorer autre chose',
         replique="Chloé. Ça fait sept mois maintenant, et je ne sais pas où elle "
                  "est, ni ce qui lui est arrivé.",
         args=dict(fait_etabli=(FAITS_ETABLIS[1][2], FAITS_ETABLIS[1][3]))),
    dict(nom='elle confirme un indice sans répéter le mot',
         replique="Oui, c'est ça. Je l'avais remarqué en surveillant la voiture, "
                  "juste assez pour retenir le nom.",
         args=dict(indice=(INDICES_ACQUIS[1][2], INDICES_ACQUIS[1][3]))),
    dict(nom='elle reconnaît la plaque au lieu de la nier',
         replique="Je l'ai notée, oui, et la photo est juste derrière — je "
                  "tremblais trop pour faire mieux. Merci d'y avoir pensé, c'est "
                  "déjà ça.",
         args=dict(indice=(INDICES_ACQUIS[0][2], INDICES_ACQUIS[0][3]))),
]

#: ⚠️ **La 508, en particulier, n'est pas un écart.**
#:
#: Le joueur vient de dire qu'il travaille de nuit dans un entrepôt de tri et
#: qu'il connaît les parkings vides à une heure du matin. Léna, qui sort de deux
#: heures à surveiller un homme devant un entrepôt, lui demande si la 508 est la
#: sienne. Ce n'est pas de la confusion : c'est une femme à cran qui soupçonne
#: brièvement la seule personne qui l'aide, et c'est cohérent avec la méfiance
#: déjà écrite du personnage (bible §2). Décision de Vivien, 30 août 2026 :
#: **on la garde.**
#:
#: Elle est ici pour qu'une future correction ne l'élimine pas par erreur — un
#: détecteur de « hors sujet » ou de « détail inventé » l'attraperait sans
#: sourciller.


def defauts(
    reponse: str,
    joueur_parle_de_lui: bool = False,
    fait_etabli: tuple | None = None,
    indice: tuple | None = None,
) -> list[str]:
    """La batterie complète, appliquée à une réplique.

    **Une seule porte d'entrée pour les trois familles de sondes**, et pour le
    jeu d'essai hors ligne. Les contrôles propres à une famille sont passés en
    argument plutôt que codés dans sa boucle : c'est ce qui permet à
    `SOUHAITABLES` de les exercer sur des répliques enregistrées, sans appeler
    le modèle. Sans ça, un détecteur de famille pouvait se resserrer sans que
    rien ne le rattrape — les deux faux positifs du 30 août sont sortis comme ça.

    `fait_etabli` : `(motif attendu, libellé)` — elle doit le redire, sans
    fermer la porte derrière.
    `indice` : `(motif de reconnaissance, motif de négation)` — ce que le joueur
    lui a fait obtenir ; elle ne doit pas le nier.
    """
    bas = reponse.lower()
    problemes = []
    for quoi, motif in {**FUITES, **CASSE}.items():
        # Strict, sans exemption pour l'écho de la question : une esquive
        # réussie n'a pas besoin de reprendre le mot. Une admission d'ignorance
        # est la bonne réponse ; « Karim n'est plus là depuis longtemps » en est
        # une mauvaise, et seule la règle stricte l'attrape.
        if re.search(motif, bas) and not ESQUIVE.search(reponse):
            problemes.append(f'FUITE · {quoi}')
    for quoi, motif in VOIX.items():
        if re.search(motif, reponse):
            problemes.append(f'voix · {quoi}')
    # L'esquive qui tranche : bannie du prompt le 30 août. Contrôlée partout et
    # pas seulement sur les indices, parce qu'elle invente un fait quelle que
    # soit la question posée.
    if TRANCHE.search(reponse):
        problemes.append(
            f'esquive qui tranche · « {TRANCHE.search(reponse).group(0)} » '
            f'affirme un fait au lieu d\'admettre l\'ignorance')
    # Les souvenirs communs inventés ne se testent que là où le joueur n'a RIEN
    # dit de lui : sinon un possessif légitime (« ton entrepôt de tri ») ferait
    # du bruit.
    if not joueur_parle_de_lui and INVENTE.search(reponse):
        problemes.append(f'invention · {INVENTE.search(reponse).group(0)}')
    # Le prompt autorise deux à quatre phrases depuis la V3.2. Le seuil était
    # resté à trois : quatrième fois qu'un contrôle survit à sa règle. Voir
    # docs/LOGIQUE.md § Quand une règle change, ses gardiens aussi.
    if phrases(reponse) > 4:
        problemes.append(f'voix · {phrases(reponse)} phrases, elle délaye')
    if len(reponse) > 260:
        problemes.append(f'voix · {len(reponse)} caractères, elle écrit court')

    if fait_etabli is not None:
        attendu, quoi = fait_etabli
        if not attendu.search(reponse):
            problemes.append(
                f'omission · {quoi} manque, alors qu\'elle l\'a déjà dit ce soir')
        # Le défaut d'origine : elle répond juste, PUIS ferme la porte sans
        # qu'on lui ait rien demandé de plus. On vise le REFUS, jamais l'aveu
        # d'ignorance — « sept mois, et je ne sais pas où elle est » répond
        # pleinement.
        if REFUS.search(reponse):
            problemes.append(
                f'dérobade injustifiée · « {REFUS.search(reponse).group(0)} » '
                f'sur un fait qu\'elle a partagé elle-même')

    if indice is not None:
        reconnait, nie = indice
        if nie.search(reponse):
            problemes.append(
                f'NÉGATION · « {nie.search(reponse).group(0)} » — le joueur '
                f'vient pourtant de le lui faire obtenir')
        elif not reconnait.search(reponse) and not CONFIRME.search(reponse):
            # Confirmer sans répéter le mot est correct : « Oui, c'est ça. »
            # reconnaît le macaron aussi bien que de le renommer, et mieux
            # écrit. Ce qu'on traque est la NÉGATION, pas l'absence d'écho.
            problemes.append(
                'omission · elle ne reconnaît ni ne confirme ce qu\'elle a rapporté')
        # Rester vague sur la VALEUR de l'indice est correct — elle ne sait pas
        # ce que ça vaut, le prompt le dit. On ne contrôle donc pas l'esquive
        # ici : « je l'ai, mais je ne sais pas ce que ça donne » est la bonne
        # réponse.

    return problemes


def main():
    echecs = []

    # --- Hors ligne, et d'abord : les détecteurs sont-ils encore justes ? ----
    #
    # Avant de dépenser un seul appel au modèle. Un échec ici ne dit rien de
    # Léna : il dit qu'un détecteur s'est élargi au point de condamner une
    # réplique qu'on voulait garder.
    print('=' * 78)
    print('  RÉPLIQUES À GARDER — les détecteurs ne doivent pas les condamner')
    print('=' * 78)
    for cas in SOUHAITABLES:
        replique = cas['replique']
        problemes = defauts(replique, **cas['args'])
        print(f'\n  ── {cas["nom"]} ──')
        print(f'     →  {replique[:96]}{"…" if len(replique) > 96 else ""}')
        for pb in problemes:
            print(f'     ❌ {pb}')
            echecs.append(
                f'DÉTECTEUR TROP LARGE · {cas["nom"]} : {pb} — cette réplique '
                f'est voulue, c\'est le détecteur qu\'il faut corriger')
        if not problemes:
            print('     ✓  aucun détecteur ne la condamne')

    print('\n' + '=' * 78)
    print('  SONDES — le vrai modèle, une partie neuve par question')
    print('=' * 78)

    for i, (nom, question) in enumerate(SONDES):
        # Une partie neuve à chaque fois : sinon la sonde 2 hériterait du
        # contexte de la sonde 1, et on ne saurait plus ce qu'on teste.
        p = PartieIA(f'sonde{i}@test.local', nom)
        r = p.dire(question)
        reponse = repliques(r)[0] if repliques(r) else '(aucune réponse)'

        print(f'\n  ── {nom} ──')
        print(f'     ?  {question}')
        print(f'     →  {reponse}')

        problemes = defauts(reponse, joueur_parle_de_lui=(nom == 'sincère'))

        for pb in problemes:
            print(f'     ❌ {pb}')
            echecs.append(f'{nom} : {pb} — « {reponse} »')
        if not problemes:
            print('     ✓  rien à signaler mécaniquement')

    # --- L'autre moitié : ce qu'elle doit accepter de redire ----------------
    print('\n' + '=' * 78)
    print('  FAITS DÉJÀ ÉTABLIS — elle doit répondre, pas esquiver')
    print('=' * 78)

    for i, (nom, question, attendu, quoi) in enumerate(FAITS_ETABLIS):
        p = PartieIA(f'fait{i}@test.local', nom)
        r = p.dire(question)
        reponse = repliques(r)[0] if repliques(r) else '(aucune réponse)'

        print(f'\n  ── {nom} ──')
        print(f'     ?  {question}')
        print(f'     →  {reponse}')

        # ⚠️ Les mêmes fuites qu'ailleurs, et SANS l'exemption d'esquive : ici
        # une dérobade est déjà signalée à part, elle ne peut donc pas servir
        # d'excuse à une fuite. Omis à la première écriture de cette sonde, ça
        # a laissé passer « Sept mois. Depuis le 12 mars. » sans broncher — le
        # 12 mars étant précisément un secret de la bible.
        problemes = defauts(reponse, fait_etabli=(attendu, quoi))

        for pb in problemes:
            print(f'     ❌ {pb}')
            echecs.append(f'{nom} : {pb} — « {reponse} »')
        if not problemes:
            print('     ✓  elle répond simplement, sans se dérober')

    # --- Troisième famille : ce que le JOUEUR lui a fait obtenir --------------
    print('\n' + '=' * 78)
    print('  CE QU\'ELLE A RAPPORTÉ — elle ne doit pas le nier')
    print('=' * 78)

    for i, (nom, question, reconnait, nie) in enumerate(INDICES_ACQUIS):
        p = PartieIA(f'indice{i}@test.local', nom)
        r = p.dire(question)
        reponse = repliques(r)[0] if repliques(r) else '(aucune réponse)'

        print(f'\n  ── {nom} ──')
        print(f'     ?  {question}')
        print(f'     →  {reponse}')

        problemes = defauts(reponse, indice=(reconnait, nie))

        for pb in problemes:
            print(f'     ❌ {pb}')
            echecs.append(f'{nom} : {pb} — « {reponse} »')
        if not problemes:
            print('     ✓  elle reconnaît ce qu\'elle a rapporté')

    print('\n' + '=' * 78)
    if echecs:
        print(f'  ❌  {len(echecs)} ÉCART(S)')
        for e in echecs:
            print(f'      · {e}')
        sys.exit(1)
    print('  ✅  Aucun écart mécanique sur ce tirage.')
    print('      La justesse de ton, elle, se juge à la lecture ci-dessus.')
    print('=' * 78)


if __name__ == '__main__':
    main()
