#!/usr/bin/env python3
"""
Rejoue la migration de contenu sur une base PEUPLÉE.

Usage :
  supabase db reset && supabase functions serve &
  python3 scripts/test-migration-peuplee.py

Pourquoi ce test existe : **un `db reset` local ne peut pas voir cette classe de
défaut.** Il applique les migrations sur une base vide, où les `delete` ne
suppriment rien et où aucune clé étrangère n'est tendue. Une migration de
contenu peut donc être verte en local pendant des mois et casser à la première
base peuplée.

C'est arrivé le 17 août 2026, trois fois dans la même migration :

  · `contacts` supprimé avant `messages` qui les référence
  · les chapitres pointant encore leur nœud d'entrée
  · `delete from stories`, qui emportait TOUTES les progressions par cascade —
    dans la migration même censée les préserver

Le test fait donc ce que le reset ne fait jamais : il joue une partie, puis
rejoue la migration par-dessus.

Sort en code 1 au premier écart.
"""

import importlib.util
import pathlib
import subprocess
import sys

_s = importlib.util.spec_from_file_location(
    'sim', pathlib.Path(__file__).with_name('simulate-playthrough.py'))
sim = importlib.util.module_from_spec(_s)
_s.loader.exec_module(sim)

CONTENEUR = 'supabase_db_SMS-Noir'


def sql(requete: str) -> str:
    return subprocess.run(
        ['docker', 'exec', '-i', CONTENEUR, 'psql', '-U', 'postgres', '-d', 'postgres',
         '-qAt', '-c', requete],
        capture_output=True, text=True, check=True).stdout.strip()


def rejouer_migration() -> tuple[bool, str]:
    fichier = sorted(pathlib.Path('supabase/migrations')
                     .glob('*_contenu_chapitre_1.sql'))[-1]
    r = subprocess.run(
        ['docker', 'exec', '-i', CONTENEUR, 'psql', '-U', 'postgres', '-d', 'postgres',
         '-v', 'ON_ERROR_STOP=1', '-q'],
        stdin=fichier.open(), capture_output=True, text=True)
    return r.returncode == 0, (r.stderr or '').strip()


if __name__ == '__main__':
    print('=' * 78)
    print('  MIGRATION DE CONTENU, REJOUÉE SUR UNE BASE PEUPLÉE')
    print('=' * 78)

    # 1. Une vraie partie : progression, messages délivrés, consentement posé.
    p = sim.Partie('peuplee@test.local', 'peuplée')
    p.choisir('Bonsoir, qui')
    p.choisir("Quelqu'un qui a reçu")
    sql("update player_progress set ai_consent_at = now() "
        "where user_id = (select id from auth.users where email = 'peuplee@test.local');")

    avant = {
        'progressions': sql('select count(*) from player_progress;'),
        'messages': sql('select count(*) from player_messages;'),
        'comptes': sql('select count(*) from auth.users;'),
    }
    print(f"  avant  · {avant['progressions']} progression(s) · "
          f"{avant['messages']} message(s) délivré(s) · {avant['comptes']} compte(s)")

    # 2. La migration passe-t-elle par-dessus ?
    ok, erreur = rejouer_migration()
    sim.verifier('La migration se rejoue sur une base peuplée', ok, True)
    if not ok:
        print(f'\n  {erreur[:400]}')

    # 3. Ce qui devait survivre a-t-il survécu ?
    apres = {
        'progressions': sql('select count(*) from player_progress;'),
        'comptes': sql('select count(*) from auth.users;'),
        'consentements': sql('select count(*) from player_progress where ai_consent_at is not null;'),
    }
    print(f"  après  · {apres['progressions']} progression(s) · "
          f"{apres['comptes']} compte(s) · {apres['consentements']} consentement(s)")

    # Le cœur de la règle : réinitialiser n'est pas effacer.
    sim.verifier('Les comptes survivent', apres['comptes'], avant['comptes'])
    sim.verifier('Les progressions survivent', apres['progressions'], avant['progressions'])
    sim.verifier('Les consentements survivent', apres['consentements'], '1')

    # Et le pointeur narratif, lui, DOIT avoir été remis à zéro : les nœuds
    # d'avant n'existent plus.
    sim.verifier('Le pointeur narratif est remis à zéro',
                 sql('select count(*) from player_progress where current_node_id is not null;'), '0')
    sim.verifier('Le contenu est bien celui de la V3.2',
                 sql("select count(*) from choices where kind = 'micro';"), '63')

    print('\n' + '=' * 78)
    if sim.ECHECS:
        print(f'  ❌  {len(sim.ECHECS)} ÉCHEC(S)')
        for e in sim.ECHECS:
            print(f'      · {e}')
        sys.exit(1)
    print('  ✅  La migration tient sur une base peuplée.')
    print('=' * 78)
