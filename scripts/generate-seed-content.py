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
#: Le contenu vit dans une migration datée, pas dans le seed. En développement
#: on réécrit la PLUS RÉCENTE ; une nouvelle n'est créée qu'à la publication
#: (`--publier`), sinon chaque régénération produirait une migration de plus.
def cible() -> pathlib.Path:
    migs = sorted((RACINE / 'supabase' / 'migrations').glob('*_contenu_chapitre_1.sql'))
    if '--publier' in sys.argv or not migs:
        import datetime
        horodatage = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
        return RACINE / 'supabase' / 'migrations' / f'{horodatage}_contenu_chapitre_1.sql'
    return migs[-1]


SEED = cible()

AXE = {'🛡': 'proteger', '🔍': 'enquete', '🧠': 'raison'}

ORDRE = ['N1', 'N2', 'N3', 'N4', 'N5', 'N6', 'N7', 'N8', 'N10', 'N11', 'N12',
         'N13', 'N14', 'N16', 'N17', 'N18', 'N19', 'N20', 'N9', 'N21', 'N22']

# ---------------------------------------------------------------------------
# Ce que le document ne dit pas
# ---------------------------------------------------------------------------

#: Délai d'entrée dans le nœud — le temps que Léna « met » à répondre.
#: Repris de la V3.1 là où il portait une ellipse ou une hésitation voulue ;
#: ailleurs, convention V3.1 : 3-8 s en conversation, 15-25 s pour une attente.
#: N9 est absent : sa position 0 est la vidéo de transition (délai 0, fixe),
#: pas un texte — voir DELAI_FORCE pour le délai qui la remplace en position 1.
ENTREE = {
    'N1': 4, 'N2': 20, 'N3': 12, 'N4': 15, 'N5': 15, 'N6': 12, 'N7': 15,
    'N8': 10, 'N10': 12, 'N11': 20, 'N12': 8, 'N13': 22, 'N14': 8,
    'N16': 18, 'N17': 20, 'N18': 10, 'N19': 25, 'N20': 60,
    'N21': 12, 'N22': 6,
}
SUITE = 5

#: Délai forcé pour des positions irrégulières, en dérogation à ENTREE/SUITE.
#: N9#1 (le texte qui suit la vidéo de transition, addendum §2) fixe à lui seul
#: la durée d'affichage du plein écran : la vidéo reste visible jusqu'à ce que
#: ce message arrive. Il doit donc couvrir la durée du FICHIER, marge comprise.
#: Vidéo V3 (24 août 2026) : 6,00 s pile → 8 s, soit ~2 s de garde pour le
#: chargement réseau et l'initialisation du lecteur, puis un court arrêt sur la
#: dernière image avant le retour au fil. À 6 s tout rond, la moindre latence
#: de buffer coupait la fin — or Vivien la veut entière.
#: ⚠️ À réajuster si la durée du fichier change.
DELAI_FORCE = {('N9', 1): 8}

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

    # L'écran noir du N19 : un message `narration`, posé après « merde ».
    #
    # Les lignes et leurs décalages viennent du document ; la DURÉE de l'écran,
    # elle, est le délai du message suivant (le séparateur « 00h34 », 60 s).
    # L'écran noir dure donc exactement l'attente, par construction.
    bloc = re.search(r'### 🖤 ÉCRAN NOIR NARRATIF.*?(?=\n\*\(Coupure)',
                     DOC.read_text(), re.S)
    if bloc:
        lignes_ecran, decalage = [], 0
        for l in bloc.group(0).splitlines():
            m = re.match(r'^>\s*\*\((\d+)s\)\*\s*$', l)
            if m:
                decalage += int(m.group(1))
                continue
            m = re.match(r'^>\s*\*(.+?)\*\s*$', l)
            if m:
                lignes_ecran.append({'texte': m.group(1).strip(), 'a': decalage})
        if lignes_ecran:
            noeuds['N19']['messages'].append(
                ('narration', json.dumps(lignes_ecran, ensure_ascii=False)))

    # Le cliffhanger : porté par un message `system` pour rester du CONTENU.
    # Le client le sort du fil et l'affiche en plein écran.
    noeuds['N22']['messages'].append(
        ('system', "Quelqu'un est entré chez Léna. Quelqu'un sait qu'elle cherche. "
                   "Et ce quelqu'un a désormais votre numéro."))

    # La transition N20→N9 (addendum §2) : même famille que l'écran noir du
    # N19, contenu dédié plutôt que parsé. Position 0 du N9, avant tout le
    # reste — le texte incrusté (« Léna rentre chez elle. ») vit dans le
    # fichier, rien à synchroniser côté client.
    noeuds['N9']['messages'].insert(0, ('video', 'lena-rentre-chez-elle.mp4'))
    return noeuds


# ---------------------------------------------------------------------------
# Écriture du SQL
# ---------------------------------------------------------------------------

#: Variantes conditionnelles d'une réplique scriptée — irrégulier par nature,
#: donc déclaré à la main comme MEDIA et INTERACTIONS, pas parsé depuis le
#: document. Le document ne porte que la variante par défaut (parsée
#: normalement) ; celle-ci fournit le remplacement ET sa condition.
#:
#: (nœud, position) -> [(condition, texte), ...]. Le générateur émet une ligne
#: PAR variante, chacune avec sa propre condition — jamais `{}` sur aucune des
#: deux, sinon les deux seraient toujours délivrées à la fois.
VARIANTES = {
    # Position 1, pas 0 : la position 0 est la vidéo de transition (addendum
    # §2), insérée à la main devant tout le reste du N9 (voir parser()).
    ('N9', 1): [
        ({'eq': {'refus': False}},
         "Je suis rentrée, je respire un peu mieux... Ça vous dérange si l'on "
         "se tutoie ? Après ce qu'on vient de vivre, le « vous » me paraît un "
         "peu ridicule, qu'en penses-tu ?"),
        ({'eq': {'refus': True}},
         "Je suis rentrée, je respire un peu mieux... Ça ne vous dérange pas "
         "si je continue à vous vouvoyer, je crois que j'en ai besoin ce soir."),
    ],
    # N21/N22 sont écrits en tutoiement (bascule actée au N9). Sur refus=true,
    # le vouvoiement tient tout le chapitre (bible §2) : simple déclinaison
    # grammaticale des répliques qui portent un « tu », pas une réécriture.
    # Les micro-choix (labels et inline_response, table choices) restent hors
    # champ — ce mécanisme ne couvre que messages.conditions.
    ('N21', 0): [
        ({'eq': {'refus': False}},
         "Je t'ai pas dit, mais je me suis approchée de l'entrepôt, je sais "
         "c'était risqué, c'est pour ça que je ne te l'ai pas dit, je ne "
         "voulais pas que tu t'inquiètes pour moi. Donc avant qu'il sorte "
         "j'ai pris une photo par une fenêtre, un peu floue et mal prise, "
         "j'étais accroupie, mais je pense avoir trouvé des preuves..."),
        ({'eq': {'refus': True}},
         "Je ne vous ai pas dit, mais je me suis approchée de l'entrepôt, je "
         "sais c'était risqué, c'est pour ça que je ne vous l'ai pas dit, je "
         "ne voulais pas que vous vous inquiétiez pour moi. Donc avant qu'il "
         "sorte j'ai pris une photo par une fenêtre, un peu floue et mal "
         "prise, j'étais accroupie, mais je pense avoir trouvé des preuves..."),
    ],
    ('N21', 2): [
        ({'eq': {'refus': False}},
         "Tu vois le trousseau, sur le crochet, juste sous la lumière ? "
         "Zoome sur le porte-clés."),
        ({'eq': {'refus': True}},
         "Vous voyez le trousseau, sur le crochet, juste sous la lumière ? "
         "Zoomez sur le porte-clés."),
    ],
    ('N22', 1): [
        ({'eq': {'refus': False}},
         "Je t'explique, il n'en existe que deux au monde, je les avais fait "
         "graver pour nous deux, un pour elle et un pour moi, lors d'un "
         "voyage où on était en vacances. Ça symbolisait notre amitié, nous "
         "quoi !"),
        ({'eq': {'refus': True}},
         "Je vous explique, il n'en existe que deux au monde, je les avais "
         "fait graver pour nous deux, un pour elle et un pour moi, lors d'un "
         "voyage où on était en vacances. Ça symbolisait notre amitié, nous "
         "quoi !"),
    ],
}


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
            elif kind == 'narration':
                d, ty, ct, body = 0, 0, 'narration', texte
            elif kind == 'system':
                d, ty, ct, body = 8, 0, 'system', texte
            elif kind == 'video':
                # Délai 5 s, et non 0 : le plein écran ne doit pas tomber sur
                # le message que le joueur est encore en train de lire. À 0,
                # il basculait à l'instant même où sa réponse s'affichait —
                # « je n'ai pas eu le temps de lire le message que hop, la
                # vidéo » (Vivien, 24 août 2026). Ces 5 s sont un temps de
                # lecture sur le fil, sans « en train d'écrire » (typing 0) :
                # rien n'annonce la bascule, elle arrive dans un silence.
                #
                # Sa durée À L'ÉCRAN, elle, reste donnée par le délai du
                # message SUIVANT (voir DELAI_FORCE), pas par celui-ci.
                d, ty, ct, body = 5, 0, 'video', None
                media = f'$${texte}$$'
            elif kind == 'media':
                ct, fichier = MEDIA[texte]
                d, ty, body = (ENTREE[code] if pos == 0 else SUITE), 3, None
                media = f'$${fichier}$$'
            else:
                d = DELAI_FORCE.get((code, pos), ENTREE.get(code, SUITE) if pos == 0 else SUITE)
                ty = d if (code, pos) in TYPING_LONG else 3
                ct, body = 'text', texte

            variantes = VARIANTES.get((code, pos))
            textes = [t for _, t in variantes] if variantes else [body]
            conds = [c for c, _ in variantes] if variantes else [{}]

            for texte_variante, cond in zip(textes, conds):
                b = f'$${dollars(texte_variante)}$$' if texte_variante is not None else f'null{cast}'
                push = 'true' if (code, pos) in PUSH else 'false'
                ptxt = PUSH_TEXTE.get((code, pos))
                p = f'$${ptxt}$$' if ptxt else f'null{cast}'
                cj = json.dumps(cond, ensure_ascii=False)
                lignes.append(
                    f"('{code}', {pos}, '{ct}', {b}, {media}, {d}, {ty}, {push}, {p}, $${cj}$$),")
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


#: Préambule de toute migration de contenu.
#:
#: Remplacer le contenu supprime les nœuds et les contacts. Les progressions en
#: cours les référencent : sans ce préambule, la migration échoue sur une clé
#: étrangère — constaté sur l'hébergé le 17 août 2026, la migration locale
#: passant parce que `db reset` avait déjà tout vidé.
#:
#: **On réinitialise, on n'efface pas.** Les lignes `player_progress` restent,
#: avec leur compte et leur historique de consentement RGPD ; seul le pointeur
#: narratif est remis à zéro. Voir docs/ARCHITECTURE.md.
PREAMBULE = """-- Remise à zéro des parties en cours, AVANT de toucher au contenu.
--
-- Les nœuds et les contacts vont être remplacés ; les progressions les
-- référencent. Sans ça, la migration échoue sur une clé étrangère.
--
-- On réinitialise, on n'efface pas : le compte et l'historique de consentement
-- survivent, seul le pointeur narratif est perdu. Voir ARCHITECTURE.md.
delete from player_messages;
update player_progress set
  current_node_id = null, node_cursor = 0, node_gate = null,
  last_choice_id = null, last_choice_seq = null, ai_exchanges = 0,
  variables = default, chapter_unlocked_at = null;

-- Puis le contenu, dans l'ordre des dépendances.
--
-- Un simple `delete from stories` ne suffit pas : la cascade atteint `contacts`
-- avant `messages`, qui les référence sans ON DELETE CASCADE. En local ça
-- passait — la base était vide et le delete n'avait rien à supprimer. C'est la
-- première base peuplée qui l'a révélé.
delete from messages;
delete from choices;
-- Les chapitres pointent leur nœud d'entrée : on relâche le lien avant
-- de supprimer les nœuds, sinon la clé étrangère tient.
update chapters set entry_node_id = null;
delete from nodes;
-- Les chapitres aussi : sans la cascade de `stories`, ils survivraient et
-- l'insertion buterait sur (story_id, position). Rien ne les référence côté
-- joueur, leur suppression est sans conséquence.
delete from chapters;
delete from contacts;

-- ⚠️ **On ne supprime JAMAIS la ligne `stories`.**
--
-- `player_progress.story_id` la référence en ON DELETE CASCADE : la supprimer
-- emporte toutes les progressions, avec les comptes et l'historique de
-- consentement RGPD. C'est arrivé le 17 août 2026, sur l'application de cette
-- migration même qui prétendait les protéger.
--
-- L'histoire est donc mise à jour en place, jamais recréée.

"""


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

    # En publication, la nouvelle migration part de la précédente : le squelette
    # (histoire, contacts, chapitres, nœuds) n'est pas généré, seuls les
    # messages et les choix le sont.
    precedentes = sorted((RACINE / 'supabase' / 'migrations')
                         .glob('*_contenu_chapitre_1.sql'))
    source = SEED if SEED.exists() else precedentes[-1]
    seed = source.read_text()
    seed = remplacer(
        seed, 'insert into messages', 'from (values\n',
        '\n) as v(node, pos, ctype, body, media, delay, typing, push, push_text, conditions)',
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
    # Le préambule vit en tête, sous l'en-tête de la migration.
    if 'delete from player_messages;' not in seed:
        i = seed.index('delete from stories')
        seed = seed[:i] + PREAMBULE + seed[i:]
    # L'histoire est mise à jour en place, jamais supprimée puis recréée :
    # `player_progress.story_id` la référence en ON DELETE CASCADE.
    seed = seed.replace("delete from stories where slug = 'numero-inconnu';\n", '')
    seed = seed.replace(
        "insert into stories (slug, title, tagline, genre, status, is_premium) values (",
        "insert into stories (slug, title, tagline, genre, status, is_premium) values (")
    seed = re.sub(r"(insert into stories \([^)]*\) values \([^;]*?)\n\);",
                  r"\1\n)\non conflict (slug) do update set\n"
                  r"  title = excluded.title, tagline = excluded.tagline,\n"
                  r"  genre = excluded.genre, status = excluded.status,\n"
                  r"  is_premium = excluded.is_premium;", seed, count=1)
    SEED.write_text(seed)
    print(f'  ✅ {SEED.name} régénéré depuis le chapitre V3.2')
