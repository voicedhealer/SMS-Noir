#!/usr/bin/env python3
"""
Contrôle de fidélité : le texte en base est-il EXACTEMENT celui du chapitre ?

Règle 6 du prompt 1 : le contenu narratif est recopié fidèlement, jamais
reformulé, jamais « amélioré ». Ce script est le garde-fou de cette règle.

⚠️ **Son sens a changé en V3.2.** Le seed n'est plus transcrit à la main, il est
généré depuis le chapitre — une divergence de recopie est donc devenue
impossible par construction. Ce que ce script attrape désormais, c'est tout le
reste : un générateur qu'on a oublié de relancer, un seed non appliqué, une
retouche faite directement en base, un parseur qui laisse tomber une réplique en
silence. C'est-à-dire les écarts qu'on ne verrait plus du tout, faute de les
relire à l'œil.

Il compare dans les deux sens :
  • toute réplique de Léna du chapitre doit exister en base (message ou inline_response)
  • tout texte en base doit exister dans le chapitre — une divergence côté base
    signalerait une reformulation ou un ajout non documenté

Usage : python3 scripts/verify-fidelity.py
Sort en code 1 au premier écart.
"""

import re
import subprocess
import sys

CHAPITRE = 'docs/chapitre-1-v3.2.md'
CONTENEUR = 'supabase_db_SMS-Noir'


def sql(requete: str) -> list[str]:
    out = subprocess.run(
        ['docker', 'exec', '-i', CONTENEUR, 'psql', '-U', 'postgres', '-d', 'postgres',
         '-qAt', '-c', requete],
        capture_output=True, text=True, check=True).stdout
    return [l.strip() for l in out.split('\n') if l.strip()]


def nettoyer(texte: str) -> str:
    """Retire l'annotation de gameplay et les guillemets d'une réplique du doc."""
    texte = texte.strip()
    # Annotation en fin de ligne : *(lucidite +1 — …)*
    texte = re.sub(r'\s*\*\([^)]*\)\*\s*$', '', texte).strip()
    # Réplique citée entre guillemets français
    m = re.fullmatch(r'«\s*(.+?)\s*»', texte)
    return m.group(1).strip() if m else texte


def repliques_du_chapitre() -> set[str]:
    source = open(CHAPITRE, encoding='utf-8').read()
    trouvees = set()
    for ligne in source.split('\n'):
        # Réplique sur sa propre ligne : **[Léna]** …
        m = re.match(r'^\s*(?:🎤\s*)?\*\*\[Léna\]\*\*\s+(.+)$', ligne)
        if m:
            texte = m.group(1).strip()
            # Médias et didascalies ne portent pas de texte de message
            if texte.startswith(('📷', '🎤', '*')):
                continue
            trouvees.add(nettoyer(texte))

    # Réponses de Léna aux micro-choix et aux interactions : « → *« … »* ».
    # C'est la forme dominante en V3.2 — 63 micro-choix, dont 60 avec réponse.
    for m in re.finditer(r'→\s*\*«\s*(.+?)\s*»\*', source):
        trouvees.add(m.group(1).strip())

    # Ancienne forme, conservée pour les chapitres qui l'utiliseraient encore.
    for m in re.finditer(r'\*\*\[Léna\]\*\*\s*«\s*(.+?)\s*»', source):
        trouvees.add(m.group(1).strip())

    # Variante conditionnelle d'une réplique (ex. refus=true), en citation :
    # *(Variante si `refus = true` — …)* suivi de « > texte ». D'autres blocs du
    # document utilisent aussi la citation Markdown (script TTS, notes de tête/
    # pied de fichier, segments de narration N19/N22 — déjà couverts par leur
    # propre format) : on ne capture QUE le bloc qui suit immédiatement un
    # marqueur « Variante si », pas toute citation du document.
    lignes = source.split('\n')
    for i, ligne in enumerate(lignes):
        if 'Variante si' not in ligne:
            continue
        for suite in lignes[i + 1:]:
            m = re.match(r'^>\s*(.+)$', suite)
            if not m:
                break
            trouvees.add(nettoyer(m.group(1).strip()))
    return trouvees


def textes_en_base() -> set[str]:
    messages = sql("select body from messages where content_type = 'text';")
    # Seules les répliques de Léna : dans une inline_response, le message 'player'
    # est le libellé du geste du joueur, pas du texte narratif.
    inline = sql("""select m->>'body'
                    from choices c, lateral jsonb_array_elements(c.inline_response) m
                    where c.inline_response is not null and m->>'sender' = 'contact';""")
    return set(messages) | set(inline)


def main() -> int:
    doc = repliques_du_chapitre()
    base = textes_en_base()

    manquantes = sorted(doc - base)
    en_trop = sorted(base - doc)

    print('=' * 78)
    print('  FIDÉLITÉ DU TEXTE — chapitre 1 (règle 6 : recopie fidèle)')
    print('=' * 78)
    print(f'  Répliques de Léna dans {CHAPITRE} : {len(doc)}')
    print(f'  Textes de Léna en base                        : {len(base)}')
    print()

    for t in manquantes:
        print(f'  ❌ DANS LE DOC, ABSENTE EN BASE : {t[:96]}')
    for t in en_trop:
        print(f'  ❌ EN BASE, ABSENTE DU DOC      : {t[:96]}')

    if manquantes or en_trop:
        print(f'\n  {len(manquantes) + len(en_trop)} divergence(s). La base et la source de vérité')
        print('  ne racontent pas la même histoire — corriger avant d\'aller plus loin.')
        return 1

    print('  ✅  Aucune divergence : la base dit exactement ce que dit le chapitre.')
    print('=' * 78)
    return 0


if __name__ == '__main__':
    sys.exit(main())
