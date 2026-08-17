#!/usr/bin/env python3
"""
Génère les blocs MESSAGES et CHOIX du seed à partir du chapitre V3.2.

Usage :
  python3 scripts/generate-seed-content.py        # réécrit supabase/seed.sql
  python3 scripts/generate-seed-content.py --dry  # compte sans écrire

Pourquoi générer plutôt que transcrire : la V3.2 réécrit 54 répliques et 66
libellés. Recopier ça à la main, c'est garantir des écarts silencieux entre le
document et la base — exactement ce que verify-fidelity existe pour attraper,
mais après coup. En dérivant le seed du document, les deux ne PEUVENT plus
diverger.

Ce qui est parsé : messages, cartes de contact, micro-choix, choix structurants
— la partie régulière, et 90 % du volume. Ce qui est déclaré ici à la main :
les interactions cachées et les délais. Peu nombreux, irréguliers, ils méritent
d'être lus plutôt que devinés.
"""

import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOC = RACINE / 'docs' / 'chapitre-1-v3.2.md'
SEED = RACINE / 'supabase' / 'seed.sql'

AXE = {'🛡': 'proteger', '🔍': 'enquete', '🧠': 'raison'}

ORDRE = ['N1', 'N2', 'N3', 'N4', 'N5', 'N6', 'N7', 'N8', 'N10', 'N11', 'N12',
         'N13', 'N14', 'N16', 'N17', 'N18', 'N19', 'N20', 'N9', 'N21', 'N22']

# ---------------------------------------------------------------------------
# Ce que le document ne dit pas
# ---------------------------------------------------------------------------

#: Délai d'entrée dans le nœud — le temps que Léna « met » à répondre.
#: Repris de la V3.1 là où il portait une ellipse ou une hésitation voulue ;
#: ailleurs, convention V3.1 : 3-8 s en conversation, 15-25 s pour une attente.
ENTREE = {
    'N1': 4, 'N2': 20, 'N3': 12, 'N4': 15, 'N5': 15, 'N6': 12, 'N7': 15,
    'N8': 10, 'N10': 12, 'N11': 20, 'N12': 8, 'N13': 22, 'N14': 8,
    'N16': 18, 'N17': 20, 'N18': 10, 'N19': 25, 'N20': 60, 'N9': 15,
    'N21': 12, 'N22': 6,
}
SUITE = 5

#: Séparateurs : le délai réel que l'ellipse masque.
SEPARATEUR = {'jeudi — 22h47': 0, '23h02': 15, '23h18': 25, '23h58': 25,
              '23h31': 20, '00h34': 60}

#: Hésitations visibles : typing = delay, le « en train d'écrire » qui dure.
#: Seuil de convention : au-delà de 15 s c'est une hésitation, pas une latence.
TYPING_LONG = {('N2', 0), ('N13', 0)}

#: Notifications push. Le document les marque « 🔔 PUSH » en tête de nœud ;
#: on les pose sur le message qui réveille réellement le téléphone.
PUSH = {('N4', 1), ('N6', 2), ('N11', 3), ('N14', 2), ('N19', 1), ('N20', 1)}
PUSH_TEXTE = {('N11', 3): 'Léna : 1 nouveau message'}

MEDIA = {
    'capture du mail de classement sans suite': ('image', 'photo-N10-recepisse.png'),
    'photo de la 508': ('image', 'photo-N16-plaque.png'),
    'note vocale — 22s, chuchotée': ('audio', 'audio-N17-reperage.mp3'),
    "photo de l'intérieur de l'entrepôt": ('image', 'photo-N21-porte-cles.jpeg'),
}

#: Les 6 interactions cachées, sur 7 lignes.
#:
#: Irrégulières par nature — un geste, une condition de non-répétition, parfois
#: deux options mutuellement exclusives. Le zoom du récépissé est passé du N10
#: au N8 en V3.2 : au N10 il n'était visible que sur la branche « appelez la
#: police », et l'incohérence n°1 restait inaccessible aux deux autres.
#: (nœud, libellé, marqueur, réplique de Léna ou None, effets)
INTERACTIONS = [
    ('N8', 'Zoomer sur la capture', 'ZOOM_RECEPISSE', None,
     {'inc': {'lucidite': 1}}),
    ('N8', "Vous l'avez déjà vu de près ?", 'RELANCE_N8',
     'La cinquantaine, toujours seul, il ne parle à personne et personne ne le '
     "connaît dans le coin, il regarde toujours autour de lui avant d'ouvrir la "
     'porte, c\'est vraiment suspect ! Enfin, pour moi...',
     {'append': {'indices': 'PROFIL_SUSPECT'}}),
    ('N8', "Et s'il vous a repérée ?", 'RELANCE_N8',
     'Je fais attention, je change de place à chaque fois, je ne peux pas vous '
     'jurer que non... mais je suis encore là, donc il est fort probable que non.',
     {'append': {'indices': 'BORNAGE'}}),
    ('N13', '22 secondes pour répondre ça ?', 'INSISTER_N13',
     "J'hésitais à vous dire quelque chose, une autre fois, pas ce soir.",
     {'inc': {'lucidite': 1}}),
    ('N16', "Zoomer sur l'autocollant", 'ZOOM_AUTOCOLLANT', None,
     {'append': {'indices': 'AUTOCOLLANT'}}),
    ('N17', "C'est quoi ce bruit derrière vous ?", 'REECOUTE_N17',
     'Quel bruit ? ...Une voiture qui passait je suppose, il y en a parfois. '
     "Concentrez-vous s'il vous plaît.",
     {'inc': {'lucidite': 1}}),
    ('N21', 'Zoomer sur la photo', 'ZOOM_TELEPHONE', None,
     {'append': {'indices': 'TELEPHONE'}}),
]


def dollars(t):
    """Le seed cite en $$…$$ : un $$ dans le texte casserait la citation."""
    return t.replace('$$', '')


def effets(texte):
    """« confiance +1, branche = "empathie" » -> bloc d'effects."""
    if not texte:
        return {}
    out = {}
    for cle in ('confiance', 'lucidite', 'enquete'):
        m = re.search(rf'{cle}\s*([+-]?\d+)', texte)
        if m:
            v = m.group(1)
            out.setdefault('inc', {})[cle] = int(v if v[0] in '+-' else '+' + v)
    m = re.search(r'branche\s*=\s*"(\w+)"', texte)
    if m:
        out.setdefault('set', {})['branche_ch1'] = m.group(1)
    m = re.search(r'indices\s*\+\s*(\w+)', texte)
    if m:
        out.setdefault('append', {})['indices'] = m.group(1)
    if re.search(r'\brefus\b', texte):
        out.setdefault('set', {})['refus'] = True
    return out


# ---------------------------------------------------------------------------
# Lecture du document
# ---------------------------------------------------------------------------

def parser():
    noeuds, courant = {}, None
    for ligne in DOC.read_text().splitlines():
        m = re.match(r'^## (N\d+)\b', ligne)
        if m:
            courant = m.group(1)
            noeuds[courant] = {'messages': [], 'micro': [], 'structurants': []}
            continue
        if not courant:
            continue
        n = noeuds[courant]

        m = re.match(r'^\*Séparateur : « (.+?) »\*', ligne)
        if m:
            n['messages'].append(('separator', m.group(1)))
            continue

        if ligne.startswith("*(→ carte d'enregistrement du contact"):
            n['messages'].append(('carte', 'lena'))
            continue

        m = re.match(r'^\*\*\[Léna\]\*\* (?:📷|🎤) \*\[(.+?)\]\*\s*$', ligne)
        if m:
            n['messages'].append(('media', m.group(1)))
            continue

        m = re.match(r'^\*\*\[Léna\]\*\* (.+?)\s*$', ligne)
        if m:
            n['messages'].append(('text', m.group(1)))
            continue

        if ligne.startswith('**MICRO-CHOIX'):
            n['micro'].append({'apres': len(n['messages']) - 1, 'options': []})
            continue

        m = re.match(r'^- (🛡|🔍|🧠) « (.+?) »'
                     r'(?:\s*→\s*\*« (.+?) »\*)?'
                     r'(?:\s*⚠️\s*\*\((.+?)\)\*)?\s*$', ligne)
        if m and n['micro']:
            axe, label, reponse, extra = m.groups()
            n['micro'][-1]['options'].append(
                {'axe': AXE[axe], 'label': label, 'reponse': reponse,
                 'effets': effets(extra)})
            continue

        m = re.match(r'^- ([A-C])\. « (.+?) »\s*→\s*\*?\*?(N\d+)\*?\*?'
                     r'(?:\s*\*\((.+?)\)\*)?\s*$', ligne)
        if m:
            _, label, cible, eff = m.groups()
            n['structurants'].append(
                {'label': label, 'cible': cible, 'effets': effets(eff)})
            continue

    # Le cliffhanger : porté par un message `system` pour rester du CONTENU.
    # Le client le sort du fil et l'affiche en plein écran.
    noeuds['N22']['messages'].append(
        ('system', "Quelqu'un est entré chez Léna. Quelqu'un sait qu'elle cherche. "
                   "Et ce quelqu'un a désormais votre numéro."))
    return noeuds


# ---------------------------------------------------------------------------
# Écriture du SQL
# ---------------------------------------------------------------------------

def sql_messages(noeuds):
    lignes, premier = [], True
    for code in ORDRE:
        lignes.append(f'\n-- {code}')
        for pos, (kind, texte) in enumerate(noeuds[code]['messages']):
            cast = '::text' if premier else ''
            media = f'null{cast}'
            if kind == 'separator':
                d, ty, ct, body = SEPARATEUR.get(texte, 10), 0, 'separator', texte
            elif kind == 'carte':
                d, ty, ct, body = 2, 0, 'contact_card', None
            elif kind == 'system':
                d, ty, ct, body = 8, 0, 'system', texte
            elif kind == 'media':
                ct, fichier = MEDIA[texte]
                d, ty, body = (ENTREE[code] if pos == 0 else SUITE), 3, None
                media = f'$${fichier}$$'
            else:
                d = ENTREE[code] if pos == 0 else SUITE
                ty = d if (code, pos) in TYPING_LONG else 3
                ct, body = 'text', texte
            b = f'$${dollars(body)}$$' if body is not None else f'null{cast}'
            push = 'true' if (code, pos) in PUSH else 'false'
            ptxt = PUSH_TEXTE.get((code, pos))
            p = f'$${ptxt}$$' if ptxt else f'null{cast}'
            lignes.append(f"('{code}', {pos}, '{ct}', {b}, {media}, {d}, {ty}, {push}, {p}),")
            premier = False
    lignes[-1] = lignes[-1][:-1]
    return '\n'.join(lignes) + '\n'


def sql_micro(noeuds):
    lignes, premier = [], True
    for code in ORDRE:
        for i, bloc in enumerate(noeuds[code]['micro']):
            lignes.append(f"\n-- {code} · pause après le message {bloc['apres']}")
            for j, o in enumerate(bloc['options']):
                eff = {'motif': o['axe'], **o['effets']}
                cast = '::text' if premier else ''
                if o['reponse']:
                    charge = [{'sender': 'contact', 'content_type': 'text',
                               'body': o['reponse'], 'delay_seconds': 4,
                               'typing_seconds': 3}]
                    inline = '$$' + json.dumps(charge, ensure_ascii=False) + '$$'
                else:
                    inline = f'null{cast}'
                lignes.append("('%s', %d, $$%s$$, %d, %s, $$%s$$)," % (
                    code, 10 + i * 10 + j, dollars(o['label']), bloc['apres'],
                    inline, json.dumps(eff, ensure_ascii=False)))
                premier = False
    lignes[-1] = lignes[-1][:-1]
    return '\n'.join(lignes) + '\n'


def sql_choix(noeuds):
    """Choix structurants puis interactions cachées, dans le même bloc."""
    lignes, premier = [], True
    for code in ORDRE:
        st = noeuds[code]['structurants']
        inter = [i for i in INTERACTIONS if i[0] == code]
        if not st and not inter:
            continue
        lignes.append(f'\n-- {code}')
        for i, c in enumerate(st):
            cast = '::text' if premier else ''
            kind = 'ignore' if 'ignorer' in c['label'].lower() else 'reply'
            lignes.append("('%s', %d, $$%s$$, '%s', '%s', null%s, $$%s$$, $${}$$)," % (
                code, i, dollars(c['label']), kind, c['cible'], cast,
                json.dumps(c['effets'], ensure_ascii=False)))
            premier = False
        for k, (_, label, marqueur, reponse, eff) in enumerate(inter):
            effs = json.loads(json.dumps(eff))
            # Non répétable : le marqueur est posé avec l'effet, la condition le
            # relit. Sans ça, un même geste donnerait deux fois le même indice.
            effs.setdefault('append', {})['interactions_faites'] = marqueur
            cond = {'not_contains': {'interactions_faites': marqueur}}
            cast = '::text' if premier else ''
            if reponse:
                charge = [
                    {'sender': 'player', 'content_type': 'text', 'body': label,
                     'delay_seconds': 0, 'typing_seconds': 0},
                    {'sender': 'contact', 'content_type': 'text', 'body': reponse,
                     'delay_seconds': 8, 'typing_seconds': 4},
                ]
                inline = '$$' + json.dumps(charge, ensure_ascii=False) + '$$'
            else:
                inline = f'null{cast}'
            lignes.append("('%s', %d, $$%s$$, 'interaction', null%s, %s, $$%s$$, $$%s$$)," % (
                code, 50 + k, dollars(label), cast, inline,
                json.dumps(effs, ensure_ascii=False),
                json.dumps(cond, ensure_ascii=False)))
            premier = False
    lignes[-1] = lignes[-1][:-1]
    return '\n'.join(lignes) + '\n'


def remplacer(seed, depuis, ouvre, ferme, contenu):
    """Remplace entre deux bornes, en cherchant APRÈS un marqueur de départ.

    Le marqueur importe : « from (values » apparaît quatre fois dans le seed, et
    la première est le bloc des NŒUDS. Ancrer sur la première occurrence
    écrasait la table des nœuds par les messages.
    """
    debut = seed.index(depuis)
    i = seed.index(ouvre, debut) + len(ouvre)
    j = seed.index(ferme, i)
    return seed[:i] + contenu + seed[j:]


# ---------------------------------------------------------------------------

if __name__ == '__main__':
    noeuds = parser()
    absents = [c for c in ORDRE if c not in noeuds]
    if absents:
        sys.exit(f'nœuds absents du document : {absents}')

    ecarts = [f"{c} pause {b['apres']} : {len(b['options'])} options"
              for c in ORDRE for b in noeuds[c]['micro'] if len(b['options']) != 3]
    for e in ecarts:
        print(f'  ⚠️  {e}')

    print(f"  {len(ORDRE)} nœuds · "
          f"{sum(len(noeuds[c]['messages']) for c in ORDRE)} messages · "
          f"{sum(len(noeuds[c]['micro']) for c in ORDRE)} blocs de micro-choix "
          f"({sum(len(b['options']) for c in ORDRE for b in noeuds[c]['micro'])} options) · "
          f"{sum(len(noeuds[c]['structurants']) for c in ORDRE)} structurants · "
          f"{len(INTERACTIONS)} interactions")

    if '--dry' in sys.argv:
        sys.exit(1 if ecarts else 0)

    seed = SEED.read_text()
    seed = remplacer(
        seed, 'insert into messages', 'from (values\n',
        '\n) as v(node, pos, ctype, body, media, delay, typing, push, push_text)',
        sql_messages(noeuds))
    seed = remplacer(
        seed, 'insert into choices (node_id, position, label, kind, next_node_id',
        'select n.id, v.pos, v.label, v.kind, tgt.id, v.inline::jsonb, '
              "v.effects::jsonb, v.conditions::jsonb\nfrom (values\n",
        '\n) as v(node, pos, label, kind, target, inline, effects, conditions)',
        sql_choix(noeuds))
    seed = remplacer(
        seed, 'MICRO-CHOIX — la grammaire des trois axes',
        "select n.id, v.pos, v.label, 'micro', v.apres, v.inline::jsonb, "
              'v.effects::jsonb\nfrom (values\n',
        '\n) as v(node, pos, label, apres, inline, effects)',
        sql_micro(noeuds))
    SEED.write_text(seed)
    print('  ✅ supabase/seed.sql régénéré depuis le chapitre V3.2')
