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
ESQUIVE = re.compile(
    r"qui c['’]est|qui ça|\bqui\s*[.?]|\bqui$|connais pas|j['’]ai pas parl|t['’]as dit"
    r"|vois pas (de quoi|ce que)|trompé de personne|^personne\b|\bpersonne\.|jamais entendu"
    r"|pas maintenant|pas ce soir|j['’]en sais rien|t['’]as pas à savoir|laisse tomber"
    r"|m['’]en parle pas|je sais pas|même moi je sais pas", re.I)

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


def phrases(texte: str) -> int:
    """Compte les phrases, sans se laisser tromper par les suspensions.

    « Enfin... c'est moi. » est UNE phrase hésitante, pas deux : les points de
    suspension marquent un souffle, pas une fin. Les compter comme une coupure
    gonflait le total et faisait passer une réponse conforme pour un délayage.
    """
    texte = re.sub(r'\.\.\.|…', ' ', texte)
    return len([p for p in re.split(r'[.?!]+', texte) if p.strip()])


def main():
    echecs = []
    print('=' * 78)
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

        bas = reponse.lower()
        problemes = []
        for quoi, motif in {**FUITES, **CASSE}.items():
            # Strict, sans exemption pour l'écho de la question : une esquive
            # réussie n'a pas besoin de reprendre le mot. « Pas maintenant. »
            # est la bonne réponse ; « Karim n'est plus là depuis longtemps »
            # en est une mauvaise, et seule la règle stricte l'attrape.
            if re.search(motif, bas) and not ESQUIVE.search(reponse):
                problemes.append(f'FUITE · {quoi}')
        for quoi, motif in VOIX.items():
            if re.search(motif, reponse):
                problemes.append(f'voix · {quoi}')
        # Le prompt dit « une à deux phrases ». Le seuil est posé un cran plus
        # haut ici, à trois : « T'as raison. Je devrais. Mais je sais même pas
        # où est Chloé. » fait trois phrases ET c'est exactement sa voix — le
        # prompt lui demande par ailleurs des phrases courtes, souvent sans
        # verbe. Ce qu'on traque, c'est le délayage, pas le rythme haché.
        # Le prompt autorise deux à quatre phrases depuis la V3.2. Le seuil
        # était à trois : quatrième fois qu'un contrôle survit à sa règle.
        # Voir docs/LOGIQUE.md § Quand une règle change, ses gardiens aussi.
        # Le joueur ne parle de lui que dans la dernière sonde.
        if nom != 'sincère' and INVENTE.search(reponse):
            problemes.append(f'invention · {INVENTE.search(reponse).group(0)}')
        if phrases(reponse) > 4:
            problemes.append(f'voix · {phrases(reponse)} phrases, elle délaye')
        if len(reponse) > 260:
            problemes.append(f'voix · {len(reponse)} caractères, elle écrit court')

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

        bas = reponse.lower()
        problemes = []
        if not attendu.search(reponse):
            problemes.append(f'omission · {quoi} manque, alors qu\'elle l\'a déjà dit ce soir')
        # Le défaut d'origine : elle répond juste, PUIS se dérobe sans qu'on lui
        # ait rien demandé de plus. Répondre correctement ne suffit donc pas.
        if ESQUIVE.search(reponse):
            problemes.append(
                f'esquive injustifiée · « {ESQUIVE.search(reponse).group(0)} » '
                f'sur un fait qu\'elle a partagé elle-même')
        # ⚠️ Les mêmes fuites qu'ailleurs, et SANS l'exemption d'esquive : ici
        # une esquive est déjà signalée plus haut, elle ne peut donc pas servir
        # d'excuse à une fuite. Omis à la première écriture de cette sonde, elle
        # a laissé passer « Sept mois. Depuis le 12 mars. » sans broncher — le
        # 12 mars étant précisément un secret de la bible. Une sonde qui vérifie
        # qu'elle en dit assez doit vérifier du même geste qu'elle n'en dit pas
        # trop, sinon assouplir la réserve se paie en fuites invisibles.
        for quoi_fuite, motif in {**FUITES, **CASSE}.items():
            if re.search(motif, bas):
                problemes.append(f'FUITE · {quoi_fuite}')
        if INVENTE.search(reponse):
            problemes.append(f'invention · {INVENTE.search(reponse).group(0)}')
        for quoi_voix, motif in VOIX.items():
            if re.search(motif, reponse):
                problemes.append(f'voix · {quoi_voix}')
        if phrases(reponse) > 4:
            problemes.append(f'voix · {phrases(reponse)} phrases, elle délaye')
        if len(reponse) > 260:
            problemes.append(f'voix · {len(reponse)} caractères, elle écrit court')

        for pb in problemes:
            print(f'     ❌ {pb}')
            echecs.append(f'{nom} : {pb} — « {reponse} »')
        if not problemes:
            print('     ✓  elle répond simplement, sans se dérober')

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
