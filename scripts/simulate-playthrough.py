#!/usr/bin/env python3
"""
Simulation de parties complètes via get-state et advance.

Usage :
  supabase start
  supabase functions serve &        # laisser tourner
  python3 scripts/simulate-playthrough.py

Deux parcours, joués intégralement de N1 à N22 par les Edge Functions, puis
vérification de l'état final des variables (lu en service_role, le client ne
les voit jamais) :

  • « allié » — le joueur s'engage. Vérifie les gains de confiance, la collecte
    d'indices, les interactions cachées et la branche.
  • « refus » — le joueur se désengage au N11. Vérifie que `refus` est bien posé
    par le NŒUD, et surtout que le PLAFOND de confiance à 6 tient : le dernier
    gain devrait porter la confiance à 7, il doit être écrêté.

Sort en code 1 au premier écart.
"""

import json
import subprocess
import sys
import urllib.error
import urllib.request

# ---------------------------------------------------------------------------
# Environnement (jamais de secret en dur : tout vient de `supabase status`)
# ---------------------------------------------------------------------------

def env_supabase() -> dict:
    out = subprocess.run(['supabase', 'status', '-o', 'env'],
                         capture_output=True, text=True, check=True).stdout
    env = {}
    for line in out.splitlines():
        if '=' in line:
            k, _, v = line.partition('=')
            env[k.strip()] = v.strip().strip('"')
    return env


ENV = env_supabase()
API = ENV.get('API_URL', 'http://127.0.0.1:54321')
ANON = ENV['ANON_KEY']
SERVICE = ENV['SERVICE_ROLE_KEY']


def http(url: str, payload=None, token: str | None = None, method='POST', headers=None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    h = {'Content-Type': 'application/json', 'apikey': ANON}
    if token:
        h['Authorization'] = f'Bearer {token}'
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            body = r.read().decode()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        raise RuntimeError(f'HTTP {e.code} sur {url}\n{detail}') from None


# ---------------------------------------------------------------------------
# Joueur de test
# ---------------------------------------------------------------------------

def nouveau_joueur(email: str) -> str:
    """Crée (ou recrée) un utilisateur et renvoie son access_token."""
    existants = http(f'{API}/auth/v1/admin/users?per_page=1000', None, SERVICE, 'GET',
                     {'apikey': SERVICE})
    for u in existants.get('users', []):
        if u['email'] == email:
            http(f'{API}/auth/v1/admin/users/{u["id"]}', None, SERVICE, 'DELETE',
                 {'apikey': SERVICE})
    http(f'{API}/auth/v1/admin/users',
         {'email': email, 'password': 'motdepasse-test', 'email_confirm': True},
         SERVICE, 'POST', {'apikey': SERVICE})
    jeton = http(f'{API}/auth/v1/token?grant_type=password',
                 {'email': email, 'password': 'motdepasse-test'})
    return jeton['access_token']


def variables_en_base(email: str) -> dict:
    """Lit l'état réel du joueur en service_role — le client ne le voit jamais."""
    users = http(f'{API}/auth/v1/admin/users?per_page=1000', None, SERVICE, 'GET',
                 {'apikey': SERVICE})
    uid = next(u['id'] for u in users['users'] if u['email'] == email)
    rows = http(
        f'{API}/rest/v1/player_progress?user_id=eq.{uid}'
        f'&select=variables,chapter_unlocked_at,current_node_id',
        None, SERVICE, 'GET', {'apikey': SERVICE})
    return rows[0]


# ---------------------------------------------------------------------------
# Actions de jeu
# ---------------------------------------------------------------------------

class Partie:
    def __init__(self, email: str, nom: str):
        self.email = email
        self.nom = nom
        self.token = nouveau_joueur(email)
        self.etat = http(f'{API}/functions/v1/get-state', {}, self.token)
        self.journal: list[str] = []

    @property
    def noeud(self) -> dict | None:
        return self.etat.get('node')

    def _avancer(self, payload: dict) -> dict:
        r = http(f'{API}/functions/v1/advance', payload, self.token)
        self.etat = {**self.etat, 'node': r['node'], 'conversations': r['conversations'],
                     'chapter_end': r['chapter_end'], 'ai_moment_pending': r['ai_moment_pending']}
        return r

    def choisir(self, debut_du_label: str) -> dict:
        """Joue le choix dont le libellé commence par le texte donné."""
        n = self.noeud
        assert n, 'aucun nœud courant'
        for c in n['choices']:
            if c['label'].startswith(debut_du_label):
                r = self._avancer({'choice_id': c['id']})
                self.journal.append(f"  {n['code']:>4} · « {c['label'][:58]} »")
                return r
        dispo = ' | '.join(c['label'][:40] for c in n['choices'])
        raise AssertionError(f"[{self.nom}] {n['code']} : choix « {debut_du_label} » absent. Dispo : {dispo}")

    def continuer(self) -> dict:
        n = self.noeud
        assert n, 'aucun nœud courant'
        r = self._avancer({'continue': True})
        self.journal.append(f"  {n['code']:>4} · (continuer)")
        return r


# ---------------------------------------------------------------------------
# Vérifications
# ---------------------------------------------------------------------------

ECHECS: list[str] = []


def verifier(nom: str, obtenu, attendu):
    ok = obtenu == attendu
    statut = 'OK   ' if ok else 'ECHEC'
    print(f'   {statut} │ {nom:<52} │ {obtenu!r}')
    if not ok:
        ECHECS.append(f'{nom} : attendu {attendu!r}, obtenu {obtenu!r}')


# ---------------------------------------------------------------------------
# PARCOURS 1 — « allié »
# ---------------------------------------------------------------------------

def parcours_allie():
    print('\n' + '=' * 78)
    print("  PARCOURS « ALLIÉ » — le joueur s'engage")
    print('=' * 78)
    p = Partie('allie@test.local', 'allié')

    verifier('Nœud d\'entrée', p.noeud['code'], 'N1')
    verifier('Léna encore anonyme', p.etat['conversations'][0]['display_name'], 'Numéro inconnu')
    verifier('Aucun next_node_id exposé',
             all('next_node_id' not in c for c in p.noeud['choices']), True)

    p.choisir('Qui ça')                       # confiance 3 -> 4
    p.choisir('Quelqu\'un qui a reçu')        # confiance 5, branche empathie, -> N5 -> N8
    verifier('Chaîne auto N5 → N8 déroulée', p.noeud['code'], 'N8')
    verifier('Léna révélée au N5', p.etat['conversations'][0]['display_name'], 'Léna')

    p.choisir("C'est qui, ce type ?")          # relance : indices PROFIL_SUSPECT
    verifier('Relance N8 consommée : la 2e question disparaît',
             any(c['label'].startswith('Pourquoi cet entrepôt') for c in p.noeud['choices']), False)

    p.choisir('Ok. Je garde mon téléphone')   # confiance 7, branche allié -> N12 -> N14
    verifier('Chaîne auto N12 → N14', p.noeud['code'], 'N14')

    p.choisir('Prenez la plaque')             # indices PLAQUE -> N16
    verifier('Arrêt sur interaction au N16', p.noeud['code'], 'N16')
    verifier('N16 en attente d\'interaction', p.noeud['awaiting_interaction'], True)

    p.choisir("Zoomer sur l'autocollant")     # AUTOCOLLANT puis enchaîne N19 -> N20
    verifier('Enchaînement après interaction N16 → N20', p.noeud['code'], 'N20')

    p.choisir('Il faut porter ça à la police')  # lucidite 1 -> N9
    verifier('Moment IA atteint', p.noeud['code'], 'N9')
    verifier('ai_moment_pending', p.etat['ai_moment_pending'], True)

    p.continuer()                              # fallback N9 -> N21
    verifier('Fallback du moment IA → N21', p.noeud['code'], 'N21')

    p.choisir('Zoomer sur la photo')          # TELEPHONE puis N22
    verifier('Fin de chapitre atteinte', p.noeud['code'], 'N22')

    etat = variables_en_base(p.email)
    v = etat['variables']
    print()
    verifier('confiance', v['confiance'], 7)
    verifier('lucidite', v['lucidite'], 1)
    verifier('refus', v['refus'], False)
    verifier('branche_ch1', v['branche_ch1'], 'allié')
    verifier('indices', sorted(v['indices']),
             sorted(['PROFIL_SUSPECT', 'PLAQUE', 'AUTOCOLLANT', 'TELEPHONE']))
    verifier('Léna révélée', v['contacts_reveles'], ['lena'])
    verifier('Compte à rebours posé', etat['chapter_unlocked_at'] is not None, True)
    verifier('Chapitre 2 annoncé', p.etat['chapter_end']['next_chapter_title'], 'Chloé')
    verifier('Chapitre 2 sans contenu', p.etat['chapter_end']['next_chapter_pending'], True)
    return p


# ---------------------------------------------------------------------------
# PARCOURS 2 — « refus » (et test du plafond de confiance)
# ---------------------------------------------------------------------------

def parcours_refus():
    print('\n' + '=' * 78)
    print('  PARCOURS « REFUS » — le joueur se désengage · test du plafond')
    print('=' * 78)
    p = Partie('refus@test.local', 'refus')

    p.choisir('Qui ça')                        # confiance 4
    p.choisir("Quelqu'un qui a reçu")          # confiance 5, empathie -> N5 -> N8
    p.choisir("N'y allez pas seule")           # lucidite 1 -> N10
    verifier('Nœud du refus raisonnable', p.noeud['code'], 'N10')

    p.choisir('Zoomer sur la capture')         # lucidite 2 (incohérence volontaire du récépissé)
    verifier('Zoom N10 non répétable',
             any(c['label'].startswith('Zoomer') for c in p.noeud['choices']), False)
    verifier('Le nœud ne bouge pas après une interaction', p.noeud['code'], 'N10')

    p.choisir('Je suis désolé')                # -> N11 : le NŒUD pose refus = true
    verifier('Branche du refus', p.noeud['code'], 'N11')

    p.choisir('Je lis. Soyez prudente')        # confiance 5 -> 6 -> N14
    p.choisir('Restez cachée')                 # -> N17
    p.choisir('C\'est quoi ce bruit')          # lucidite 3 (incohérence audio)
    verifier('Le nœud ne bouge pas après la réécoute', p.noeud['code'], 'N17')

    # Ce gain porterait la confiance à 7. refus = true -> il doit être écrêté à 6.
    p.choisir('Ok mais restez à distance')     # -> N19 -> N20
    p.choisir('Il faut porter ça à la police')  # lucidite 4 -> N9
    p.continuer()                              # fallback -> N21
    p.choisir('Zoomer sur la photo')           # TELEPHONE -> N22

    etat = variables_en_base(p.email)
    v = etat['variables']
    print()
    verifier('refus posé par le nœud N11', v['refus'], True)
    verifier('confiance ÉCRÊTÉE à 6 (vaudrait 7 sans le plafond)', v['confiance'], 6)
    verifier('lucidite', v['lucidite'], 4)
    verifier('branche_ch1', v['branche_ch1'], 'empathie')
    verifier('indices', sorted(v['indices']), ['TELEPHONE'])
    verifier('Fin de chapitre atteinte', p.noeud['code'], 'N22')
    return p


# ---------------------------------------------------------------------------
# Robustesse
# ---------------------------------------------------------------------------

def erreurs_et_idempotence():
    print('\n' + '=' * 78)
    print('  GESTION D\'ERREURS ET IDEMPOTENCE')
    print('=' * 78)
    p = Partie('erreurs@test.local', 'erreurs')

    # Choix appartenant à un autre nœud
    autre = http(f'{API}/rest/v1/choices?select=id,label&limit=200', None, SERVICE, 'GET',
                 {'apikey': SERVICE})
    ids_n1 = {c['id'] for c in p.noeud['choices']}
    etranger = next(c['id'] for c in autre if c['id'] not in ids_n1)
    try:
        http(f'{API}/functions/v1/advance', {'choice_id': etranger}, p.token)
        verifier('Choix hors nœud courant rejeté', 'accepté', 'rejeté')
    except RuntimeError as e:
        verifier('Choix hors nœud courant rejeté', 'HTTP 403' in str(e), True)

    # Choix inexistant
    try:
        http(f'{API}/functions/v1/advance',
             {'choice_id': '00000000-0000-0000-0000-000000000000'}, p.token)
        verifier('Choix inexistant rejeté', 'accepté', 'rejeté')
    except RuntimeError as e:
        verifier('Choix inexistant rejeté', 'HTTP 403' in str(e), True)

    # Requête vide
    try:
        http(f'{API}/functions/v1/advance', {}, p.token)
        verifier('Requête sans choix rejetée', 'accepté', 'rejeté')
    except RuntimeError as e:
        verifier('Requête sans choix rejetée', 'HTTP 400' in str(e), True)

    # Sans authentification
    try:
        http(f'{API}/functions/v1/get-state', {}, None)
        verifier('Appel non authentifié rejeté', 'accepté', 'rejeté')
    except RuntimeError as e:
        verifier('Appel non authentifié rejeté', 'HTTP 401' in str(e), True)

    # `continue` sur un nœud qui attend un choix
    try:
        http(f'{API}/functions/v1/advance', {'continue': True}, p.token)
        verifier('Continuation refusée quand un choix est attendu', 'accepté', 'rejeté')
    except RuntimeError as e:
        verifier('Continuation refusée quand un choix est attendu', 'HTTP 409' in str(e), True)

    # Idempotence : rejouer le MÊME choix ne réapplique rien
    cible = next(c for c in p.noeud['choices'] if c['label'].startswith('Qui ça'))
    r1 = http(f'{API}/functions/v1/advance', {'choice_id': cible['id']}, p.token)
    avant = variables_en_base(p.email)['variables']
    r2 = http(f'{API}/functions/v1/advance', {'choice_id': cible['id']}, p.token)
    apres = variables_en_base(p.email)['variables']
    verifier('Rejeu signalé comme tel', r2['idempotent_replay'], True)
    verifier('Rejeu : confiance inchangée', apres['confiance'], avant['confiance'])
    verifier('Rejeu : nœud inchangé', r2['node']['code'], r1['node']['code'])
    verifier('Rejeu : mêmes messages renvoyés',
             [m['body'] for m in r2['new_messages']], [m['body'] for m in r1['new_messages']])

    # Anti-spoiler : le contenu narratif ne doit jamais transiter
    fuite = json.dumps(r1)
    verifier('Aucun next_node_id dans la réponse', 'next_node_id' in fuite, False)
    verifier('Aucun effects dans la réponse', '"effects"' in fuite, False)
    verifier('Aucun conditions dans la réponse', '"conditions"' in fuite, False)
    verifier('Aucune variable dans la réponse', 'confiance' in fuite, False)


# ---------------------------------------------------------------------------

if __name__ == '__main__':
    allie = parcours_allie()
    refus = parcours_refus()
    erreurs_et_idempotence()

    print('\n' + '=' * 78)
    print('  CHEMINS PARCOURUS')
    print('=' * 78)
    for nom, p in (('allié', allie), ('refus', refus)):
        print(f'\n  ── {nom} ──')
        print('\n'.join(p.journal))

    print('\n' + '=' * 78)
    if ECHECS:
        print(f'  ❌  {len(ECHECS)} ÉCHEC(S)')
        for e in ECHECS:
            print(f'      · {e}')
        sys.exit(1)
    print('  ✅  Tous les contrôles sont passés.')
    print('=' * 78)
