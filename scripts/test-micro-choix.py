#!/usr/bin/env python3
"""
Le mécanisme des micro-choix, éprouvé avant qu'une ligne de contenu l'utilise.

Usage :
  supabase start && supabase functions serve &
  python3 scripts/test-micro-choix.py

Le N8 porte le premier bloc de micro-choix du chapitre, juste après « Voilà le
truc. Ce soir je vais à l'ancien entrepôt Verdier ». C'est ce bloc réel qu'on
exerce ici — la première version de ce script posait une pause d'essai, avant
que le contenu n'existe.

Vérifie trois choses que le contenu ne pourra plus révéler seul :
  · la pause coupe le nœud au bon endroit, et la suite sort après la réponse
  · le client ne peut pas distinguer un micro-choix d'une réponse structurante
  · la formule de proportion donne le même résultat sur 20 et sur 60 choix

Sort en code 1 au premier écart.
"""

import importlib.util
import json
import pathlib
import sys

_spec = importlib.util.spec_from_file_location(
    'sim', pathlib.Path(__file__).with_name('simulate-playthrough.py'))
sim = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sim)

API, SERVICE, http, Partie, verifier = sim.API, sim.SERVICE, sim.http, sim.Partie, sim.verifier


def sql(requete: str) -> str:
    import subprocess
    return subprocess.run(
        ['docker', 'exec', '-i', 'supabase_db_SMS-Noir',
         'psql', '-U', 'postgres', '-d', 'postgres', '-qAt', '-c', requete],
        capture_output=True, text=True, check=True).stdout.strip()


def titre(t: str):
    print('\n' + '=' * 78)
    print(f'  {t}')
    print('=' * 78)


# ---------------------------------------------------------------------------
# La pose d'essai
# ---------------------------------------------------------------------------

#: Le premier bloc du N8, en V3.2 — après la capture du mail de la police.
MICRO = [
    ("C'est révoltant.", 'proteger',
     'Merci de le dire, vous savez, à force on finit par douter de soi.'),
    ('Ils vous ont dit quoi exactement ?', 'enquete',
     "Qu'une majeure a le droit de partir sans prévenir, et que je devrais "
     "accepter qu'elle ait voulu couper les ponts."),
    ('Vous avez signalé quand exactement ?', 'raison',
     '...En juin. Je sais ce que vous allez dire.'),
]



def aller_au_n8(email: str) -> Partie:
    p = Partie(email, 'micro')
    p.choisir('Bonsoir, qui', puis_franchir=False)
    p.choisir("Quelqu'un qui a reçu", puis_franchir=False)
    p.franchir_pauses(arret_sur='N8')   # le N5 porte lui aussi un bloc
    assert p.noeud['code'] == 'N8', p.noeud['code']
    return p


def progression(email: str) -> dict:
    users = http(f'{API}/auth/v1/admin/users?per_page=1000', None, SERVICE, 'GET',
                 {'apikey': SERVICE})
    uid = next(u['id'] for u in users['users'] if u['email'] == email)
    return http(f'{API}/rest/v1/player_progress?user_id=eq.{uid}'
                f'&select=id,variables,node_cursor,node_gate', None, SERVICE, 'GET',
                {'apikey': SERVICE})[0]


# ---------------------------------------------------------------------------

def la_pause_coupe_le_noeud():
    titre('LA PAUSE — le nœud s\'arrête au bon endroit, puis repart')
    p = aller_au_n8('micro-pause@test.local')

    etat = progression(p.email)
    # Le bloc du N8 est posé après le message 1 (la capture du mail).
    verifier('Le déroulé s\'arrête sur la pause', etat['node_gate'], 1)
    verifier('Le curseur est derrière le message de la pause', etat['node_cursor'], 2)

    # Un seul message du N8 est sorti : celui de la position 0.
    total = int(sql("select count(*) from messages m join nodes n on n.id = m.node_id"
                    " where n.code = 'N8';"))
    # Filtré sur CE joueur : sans ça le compte ramasse toutes les parties de
    # test déjà en base et le contrôle passe par accident sur une base neuve.
    sortis = int(sql(f"select count(*) from player_messages pm"
                     f" where pm.progress_id = '{etat['id']}'::uuid"
                     f" and pm.source = 'scripted' and pm.body in"
                     f" (select body from messages m join nodes n on n.id = m.node_id"
                     f"  where n.code = 'N8');"))
    verifier(f'Deux des {total} messages du N8 sont sortis', sortis, 2)

    verifier('Trois options offertes', len(p.noeud['choices']), 3)
    verifier('Aucune n\'est signalée comme micro-choix',
             sorted({c['kind'] for c in p.noeud['choices']}), ['reply'])
    verifier('Le nœud n\'annonce pas qu\'on peut continuer', p.noeud['can_continue'], False)

    r = p.choisir('Pourquoi cet endroit')
    corps = [m['body'] for m in r['new_messages']]
    verifier('La réplique du joueur s\'affiche', corps[0], 'Ils vous ont dit quoi exactement ?')
    verifier('La variante de Léna suit', corps[1], MICRO[1][2])
    verifier('Puis le reste du nœud sort', len(corps) > 2, True)

    etat = progression(p.email)
    # Le N8 porte DEUX blocs : la pause ne se referme pas, elle avance.
    verifier('La pause a avancé au bloc suivant', etat['node_gate'], 2)
    verifier('On est toujours dans le N8', p.noeud['code'], 'N8')
    verifier('Trois options à nouveau', len(p.noeud['choices']), 3)


def on_ne_repond_pas_deux_fois():
    titre('LA GARDE — une pause refermée ne se rejoue pas')
    p = aller_au_n8('micro-garde@test.local')

    # L'attaque n'est pas de rejouer LE MÊME choix — ça, l'idempotence le gère
    # déjà et c'est même souhaitable sur une retransmission réseau. C'est d'en
    # jouer un AUTRE sur la pause qu'on vient de refermer : sans garde, la
    # posture serait comptée deux fois pour un seul moment de fiction.
    autre = next(c['id'] for c in p.noeud['choices'] if c['label'].startswith('Vous avez signalé'))
    p.choisir("C'est révoltant", puis_franchir=False)
    avant = progression(p.email)['variables']['micro']['n']

    try:
        http(f'{API}/functions/v1/advance', {'choice_id': autre}, p.token)
        verifier('Une seconde réponse à la même pause est refusée', 'acceptée', 'refusée')
    except RuntimeError as e:
        verifier('Une seconde réponse à la même pause est refusée',
                 'choix_hors_pause' in str(e), True)
    verifier('Le décompte n\'a pas bougé',
             progression(p.email)['variables']['micro']['n'], avant)


def la_posture_ne_ramifie_pas():
    titre('LA GRAMMAIRE — trois postures, une seule suite')
    arrivees = {}
    for label, axe, _ in MICRO:
        # Le trajet jusqu'au N8 traverse déjà le bloc du N5 : on mesure l'ÉCART,
        # pas l'absolu.
        p = aller_au_n8(f'micro-{axe}@test.local')
        avant = progression(p.email)['variables']['micro']
        p.choisir(label[:18], puis_franchir=False)
        arrivees[axe] = p.noeud['code']
        apres = progression(p.email)['variables']['micro']
        verifier(f'{axe:<9} → un choix de plus sur son axe',
                 apres[axe] - avant[axe], 1)
        verifier(f'{axe:<9} → un seul choix compté au total',
                 apres['n'] - avant['n'], 1)
    verifier('Les trois axes mènent au même endroit', len(set(arrivees.values())), 1)

    # Un seul micro-choix ne doit presque rien changer : c'est le lissage.
    etat = progression('micro-raison@test.local')
    verifier('Deux choix ne font pas bondir la lucidité',
             etat['variables']['lucidite'] <= 1, True)


def la_proportion_est_stable():
    titre('LA FORMULE — 20 et 60 micro-choix, même résultat')
    p = aller_au_n8('micro-formule@test.local')
    resultats = {}
    for n in (20, 60):
        # On pose directement le décompte : ce qu'on teste ici est la formule,
        # pas le chemin qui y mène.
        raison, autres = int(n * 0.8), n - int(n * 0.8)
        sql(f"""update player_progress set variables = variables || jsonb_build_object(
                  'micro', jsonb_build_object('n', {n}, 'raison', {raison},
                                              'proteger', {autres}, 'enquete', 0))
                where id = (select id from player_progress
                            where user_id = (select id from auth.users
                                             where email = 'micro-formule@test.local'));""")
        # Un tour de moteur suffit à redériver.
        etat_avant = progression(p.email)
        p.choisir('Vous avez signalé', puis_franchir=False) if etat_avant['node_gate'] is not None else None
        etat = progression(p.email)
        resultats[n] = (etat['variables']['lucidite'], etat['variables']['confiance'])
        print(f"   {n:>2} micro-choix à 80 % « raisonner » → lucidite "
              f"{etat['variables']['lucidite']}, confiance {etat['variables']['confiance']}")

    verifier('20 et 60 donnent la même lucidité', resultats[20][0], resultats[60][0])
    verifier('20 et 60 donnent la même confiance', resultats[20][1], resultats[60][1])
    verifier('Une posture nette se voit', resultats[60][0] >= 2, True)


if __name__ == '__main__':
    la_pause_coupe_le_noeud()
    on_ne_repond_pas_deux_fois()
    la_posture_ne_ramifie_pas()
    la_proportion_est_stable()

    print('\n' + '=' * 78)
    if sim.ECHECS:
        print(f'  ❌  {len(sim.ECHECS)} ÉCHEC(S)')
        for e in sim.ECHECS:
            print(f'      · {e}')
        sys.exit(1)
    print('  ✅  Le mécanisme des micro-choix tient.')
    print('=' * 78)
