#!/usr/bin/env python3
"""
Génère les blocs MESSAGES et CHOIX du seed à partir du chapitre V3.2.

Usage :
  python3 scripts/generate-seed-content.py        # réécrit supabase/seed.sql
  python3 scripts/generate-seed-content.py --dry  # montre sans écrire

Pourquoi générer plutôt que transcrire : la V3.2 réécrit 54 répliques et 66
libellés. Recopier ça à la main, c'est garantir des écarts silencieux entre le
document et la base — exactement ce que verify-fidelity existe pour attraper,
mais après coup. En dérivant le seed du document, les deux ne PEUVENT plus
diverger.

Ce qui est parsé : les messages, les micro-choix, les choix structurants — la
partie régulière, et 90 % du volume. Ce qui reste déclaré ici à la main : les
interactions cachées, les médias, les cartes de contact et les délais. Elles
sont peu nombreuses, irrégulières, et méritent d'être lues plutôt que devinées.
"""

import re
import sys
import json
import pathlib

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOC = RACINE / 'docs' / 'chapitre-1-v3.2.md'
SEED = RACINE / 'supabase' / 'seed.sql'

AXE = {'🛡': 'proteger', '🔍': 'enquete', '🧠': 'raison'}

# --- Ce que le document ne dit pas ------------------------------------------

#: Délai d'entrée dans le nœud (le temps que Léna « mette » à répondre).
#: Repris de la V3.1 là où il portait une ellipse ou une hésitation ; ailleurs,
#: convention V3.1 : 3-8 s en conversation, 15-25 s pour une hésitation.
ENTREE = {
    'N1': 4, 'N2': 20, 'N3': 12, 'N4': 15, 'N5': 15, 'N6': 12, 'N7': 15,
    'N8': 10, 'N10': 12, 'N11': 20, 'N12': 8, 'N13': 22, 'N14': 8,
    'N16': 18, 'N17': 20, 'N18': 10, 'N19': 25, 'N20': 60, 'N9': 15,
    'N21': 12, 'N22': 6,
}
#: Délai d'un message qui suit dans le même nœud.
SUITE = 5
#: Séparateurs : le délai réel masqué par l'ellipse.
SEPARATEUR = {'jeudi — 22h47': 0, '23h02': 15, '23h18': 25, '23h58': 25,
              '23h31': 20, '00h34': 60}
#: Hésitations visibles : typing = delay (le « en train d'écrire » qui dure).
TYPING_LONG = {('N2', 0), ('N13', 0)}

MEDIA = {
    'capture du mail de classement sans suite': ('image', 'photo-N10-recepisse.png'),
    'note vocale — 22s, chuchotée': ('audio', 'audio-N17-reperage.mp3'),
}

def echapper(t):
    return t.replace('$$', '')


def effets(texte):
    """« confiance +1, branche = "empathie" » -> dict d'effects."""
    if not texte:
        return {}
    out = {}
    for cle in ('confiance', 'lucidite', 'enquete'):
        m = re.search(rf'{cle}\s*([+-]\d+)', texte)
        if m:
            out.setdefault('inc', {})[cle] = int(m.group(1))
    m = re.search(r'branche\s*=\s*"(\w+)"', texte)
    if m:
        out.setdefault('set', {})['branche_ch1'] = m.group(1)
    m = re.search(r'indices\s*\+\s*(\w+)', texte)
    if m:
        out.setdefault('append', {})['indices'] = m.group(1)
    if 'refus' in texte:
        out.setdefault('set', {})['refus'] = True
    return out


def parser():
    lignes = DOC.read_text().splitlines()
    noeuds, courant = {}, None
    for l in lignes:
        m = re.match(r'^## (N\d+)\b', l)
        if m:
            courant = m.group(1)
            noeuds[courant] = {'messages': [], 'micro': [], 'structurants': []}
            continue
        if not courant:
            continue
        n = noeuds[courant]

        m = re.match(r'^\*Séparateur : « (.+?) »\*', l)
        if m:
            n['messages'].append(('separator', m.group(1), None))
            continue

        m = re.match(r'^\*\*\[Léna\]\*\* (?:📷|🎤) \*\[(.+?)\]\*\s*$', l)
        if m:
            n['messages'].append(('media', m.group(1), None))
            continue

        m = re.match(r'^\*\*\[Léna\]\*\* (.+?)\s*$', l)
        if m:
            n['messages'].append(('text', m.group(1), None))
            continue

        if l.startswith('**MICRO-CHOIX'):
            n['micro'].append({'apres': len(n['messages']) - 1, 'options': []})
            continue

        m = re.match(r'^- (🛡|🔍|🧠) « (.+?) »(?:\s*→\s*\*« (.+?) »\*)?(?:\s*⚠️\s*\*\((.+?)\)\*)?\s*$', l)
        if m and n['micro']:
            axe, label, reponse, extra = m.groups()
            n['micro'][-1]['options'].append({
                'axe': AXE[axe], 'label': label, 'reponse': reponse,
                'effets': effets(extra)})
            continue

        m = re.match(r'^- ([A-C])\. « (.+?) »\s*→\s*\*?\*?(N\d+)\*?\*?(?:\s*\*\((.+?)\)\*)?\s*$', l)
        if m:
            _, label, cible, eff = m.groups()
            n['structurants'].append({'label': label, 'cible': cible, 'effets': effets(eff)})
            continue
    return noeuds


def sql_messages(noeuds, ordre):
    lignes, premier = [], True
    for code in ordre:
        lignes.append(f'\n-- {code}')
        for pos, (kind, texte, _) in enumerate(noeuds[code]['messages']):
            cast = '::text' if premier else ''
            if kind == 'separator':
                d, ty, ct, body, media = SEPARATEUR.get(texte, 10), 0, 'separator', texte, f'null{cast}'
            elif kind == 'media':
                ct2, fichier = MEDIA[texte]
                d, ty, ct, body, media = (ENTREE[code] if pos == 0 else SUITE), 3, ct2, None, f'$${fichier}$$'
            else:
                d = ENTREE[code] if pos == 0 else SUITE
                ty = d if (code, pos) in TYPING_LONG else 3
                ct, body, media = 'text', texte, f'null{cast}'
            b = f'$${echapper(body)}$$' if body is not None else f'null{cast}'
            lignes.append(f"('{code}', {pos}, '{ct}', {b}, {media}, {d}, {ty}, false, null{cast}),")
            premier = False
    lignes[-1] = lignes[-1][:-1]
    return '\n'.join(lignes)


def sql_micro(noeuds, ordre):
    lignes, premier = [], True
    for code in ordre:
        for i, bloc in enumerate(noeuds[code]['micro']):
            lignes.append(f"\n-- {code} · pause après le message {bloc['apres']}")
            for j, o in enumerate(bloc['options']):
                eff = {'motif': o['axe'], **o['effets']}
                cast = '::text' if premier else ''
                if o['reponse']:
                    charge = [{'sender': 'contact', 'content_type': 'text',
                               'body': o['reponse'], 'delay_seconds': 4, 'typing_seconds': 3}]
                    inline = '$$' + json.dumps(charge, ensure_ascii=False) + '$$'
                else:
                    inline = f'null{cast}'
                lignes.append("('%s', %d, $$%s$$, %d, %s, $$%s$$)," % (
                    code, 10 + i * 10 + j, echapper(o['label']), bloc['apres'], inline,
                    json.dumps(eff, ensure_ascii=False)))
                premier = False
    lignes[-1] = lignes[-1][:-1]
    return '\n'.join(lignes)


if __name__ == '__main__':
    noeuds = parser()
    ordre = ['N1','N2','N3','N4','N5','N6','N7','N8','N10','N11','N12','N13','N14',
             'N16','N17','N18','N19','N20','N9','N21','N22']
    manquants = [c for c in ordre if c not in noeuds]
    if manquants:
        sys.exit(f'nœuds absents du document : {manquants}')

    print(f"  {len(ordre)} nœuds")
    print(f"  {sum(len(noeuds[c]['messages']) for c in ordre)} messages")
    print(f"  {sum(len(noeuds[c]['micro']) for c in ordre)} blocs de micro-choix, "
          f"{sum(len(b['options']) for c in ordre for b in noeuds[c]['micro'])} options")
    print(f"  {sum(len(noeuds[c]['structurants']) for c in ordre)} choix structurants")
    for c in ordre:
        for b in noeuds[c]['micro']:
            if len(b['options']) != 3:
                print(f"  ⚠️  {c} pause {b['apres']} : {len(b['options'])} options au lieu de 3")

    if '--dry' in sys.argv:
        sys.exit(0)
