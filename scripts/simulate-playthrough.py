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
    #: Posture prise par défaut aux micro-choix, quand le script ne vise qu'un
    #: choix structurant. Le rang suffit à désigner l'axe : l'ordre protéger ·
    #: enquêter · raisonner est constant, et c'est justement pour ça qu'il l'est
    #: — le client ne reçoit AUCUNE étiquette d'axe (voir LOGIQUE.md).
    RANG = {'proteger': 0, 'enquete': 1, 'raison': 2}

    def __init__(self, email: str, nom: str, posture: str = 'proteger'):
        self.email = email
        self.nom = nom
        self.posture = posture
        self.micro_vus = 0
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

    def pause_ouverte(self) -> bool:
        """Le nœud courant est-il arrêté sur une pause ?

        Lu en service_role, donc DANS LA BASE. Un client ne pourrait pas le
        savoir — un bloc de trois micro-choix est indiscernable d'un bloc de
        trois réponses structurantes, et c'est toute l'idée. Un banc d'essai,
        lui, a le droit de regarder la vérité.
        """
        rows = http(
            f'{API}/rest/v1/player_progress?select=node_gate'
            f'&user_id=eq.{self._uid()}', None, SERVICE, 'GET', {'apikey': SERVICE})
        return bool(rows) and rows[0]['node_gate'] is not None

    def _uid(self) -> str:
        if not getattr(self, '_uid_cache', None):
            users = http(f'{API}/auth/v1/admin/users?per_page=1000', None, SERVICE, 'GET',
                         {'apikey': SERVICE})
            self._uid_cache = next(u['id'] for u in users['users'] if u['email'] == self.email)
        return self._uid_cache

    def franchir_pauses(self, cible: str | None = None,
                        arret_sur: str | None = None) -> dict | None:
        """Répond aux micro-choix jusqu'à la prochaine décision structurante.

        `arret_sur` : code de nœud où s'arrêter sans franchir sa pause — utile
        pour observer une pause précise plutôt que de la traverser.
        """
        # On accumule les messages de TOUS les franchissements : traverser le
        # N5 puis enchaîner sur le N8 fait deux appels, et ne garder que le
        # dernier perdrait la carte de contact posée au N5.
        dernier, cumul = None, []
        for _ in range(12):
            n = self.noeud
            fini = (not n or not n['choices'] or not self.pause_ouverte()
                    or (arret_sur and n['code'] == arret_sur)
                    or (cible and any(c['label'].startswith(cible) for c in n['choices'])))
            reponses = [] if not n else [c for c in n['choices'] if c['kind'] == 'reply']
            if fini or not reponses:
                return {**dernier, 'new_messages': cumul} if dernier else None
            c = reponses[min(self.RANG[self.posture], len(reponses) - 1)]
            dernier = self._avancer({'choice_id': c['id']})
            cumul += dernier['new_messages']
            self.micro_vus += 1
            self.journal.append(f"  {n['code']:>4} · ({self.posture}) « {c['label'][:44]} »")
        return {**dernier, 'new_messages': cumul} if dernier else None

    def choisir(self, debut_du_label: str, puis_franchir: bool = True) -> dict:
        """Joue le choix dont le libellé commence par le texte donné.

        Franchit les pauses avant ET après, pour laisser la partie sur la
        prochaine vraie décision. En V3.2 presque chaque nœud porte un bloc de
        micro-choix : sans ça, un parcours devrait intercaler un franchissement
        après chaque ligne, et on ne lirait plus le chemin narratif.

        `puis_franchir=False` pour observer une pause plutôt que la traverser.
        """
        self.franchir_pauses(debut_du_label)
        n = self.noeud
        assert n, 'aucun nœud courant'
        for c in n['choices']:
            if c['label'].startswith(debut_du_label):
                r = self._avancer({'choice_id': c['id']})
                self.journal.append(f"  {n['code']:>4} · « {c['label'][:58]} »")
                if puis_franchir:
                    suite = self.franchir_pauses()
                    if suite:
                        # Les messages du franchissement appartiennent au même
                        # geste du point de vue du parcours : on les recolle.
                        r = {**suite,
                             'new_messages': r['new_messages'] + suite['new_messages']}
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

    p.choisir('Bonsoir, qui')                       # confiance 3 -> 4
    r = p.choisir('Quelqu\'un qui a reçu')    # confiance 5, empathie -> N5 -> N8
    verifier('Chaîne auto N5 → N8 déroulée', p.noeud['code'], 'N8')

    # La révélation n'est plus automatique : le N5 pose une carte, le geste
    # d'enregistrement la déclenche.
    verifier('Carte d\'enregistrement posée au N5',
             any(m['content_type'] == 'contact_card' for m in r['new_messages']), True)
    verifier('Léna reste anonyme tant qu\'on n\'enregistre pas',
             p.etat['conversations'][0]['display_name'], 'Numéro inconnu')

    rev = sim_reveal(p, 'lena')
    verifier('Enregistrer le contact la révèle', rev['conversations'][0]['display_name'], 'Léna')

    p.choisir("Vous l'avez déjà vu de près")          # relance : indices PROFIL_SUSPECT
    verifier('Relance N8 consommée : la 2e question disparaît',
             any(c['label'].startswith('Pourquoi cet entrepôt') for c in p.noeud['choices']), False)

    p.choisir("D'accord, je garde mon téléphone")   # confiance 7, branche allié -> N12 -> N14
    verifier('Chaîne auto N12 → N14', p.noeud['code'], 'N14')

    p.choisir('Prenez la plaque')             # indices PLAQUE -> N16
    verifier('Arrêt sur interaction au N16', p.noeud['code'], 'N16')
    verifier('N16 en attente d\'interaction', p.noeud['awaiting_interaction'], True)

    p.choisir("Zoomer sur l'autocollant")     # AUTOCOLLANT puis enchaîne N19 -> N20
    verifier('Enchaînement après interaction N16 → N20', p.noeud['code'], 'N20')

    r = p.choisir('Il faut porter ça à la police')  # lucidite 1 -> N9
    verifier('Moment IA atteint', p.noeud['code'], 'N9')
    verifier('ai_moment_pending', p.etat['ai_moment_pending'], True)
    # N9#0 est la vidéo de transition (addendum §2) : premier message 'contact'
    # du lot, avant même la réplique de Léna.
    verifier('N9 ouvre sur la vidéo de transition',
             any(m['sender'] == 'contact' and m.get('content_type') == 'video'
                 and m['media_url'] == 'lena-rentre-chez-elle.mp4'
                 for m in r['new_messages']), True)
    # refus = false ici : N9 doit ensuite ouvrir sur la demande de tutoiement,
    # pas sur la variante qui maintient le vouvoiement (messages.conditions,
    # addendum §1). new_messages[0] est l'écho du choix du joueur lui-même, et
    # la vidéo n'a pas de corps texte — on cherche le premier texte de Léna.
    ouverture_n9 = next(m['body'] for m in r['new_messages']
                         if m['sender'] == 'contact' and m['body'] is not None)
    verifier('N9 ouvre sur la demande de tutoiement (refus=false)',
             ouverture_n9.startswith('Je suis rentrée, je respire un peu mieux... Ça vous dérange si l\'on se tutoie'),
             True)

    r = p.continuer()                           # fallback N9 -> N21
    verifier('Fallback du moment IA → N21', p.noeud['code'], 'N21')
    # refus = false ici : N21 tutoie, comme le reste du chapitre depuis le N9
    # (messages.conditions, même mécanisme que N9#0 — addendum §N21/N22).
    ouverture_n21 = next(m['body'] for m in r['new_messages'] if m['sender'] == 'contact')
    verifier('N21 tutoie (refus=false)',
             ouverture_n21.startswith("Je t'ai pas dit"), True)

    r = p.choisir('Zoomer sur la photo')      # TELEPHONE puis N22
    verifier('Fin de chapitre atteinte', p.noeud['code'], 'N22')
    # `choisir` franchit les pauses après coup : new_messages couvre aussi la
    # suite du N21 et le micro-choix du N22, donc on cherche la réplique dans
    # le lot plutôt que de supposer sa position.
    verifier('N22 tutoie (refus=false)',
             any(m['sender'] == 'contact' and m['body'].startswith("Je t'explique")
                 for m in r['new_messages']), True)

    etat = variables_en_base(p.email)
    v = etat['variables']
    print()
    # 7 en V3.1, 9 en V3.2 : le parcours traverse maintenant des micro-choix, et
    # la posture par défaut du marcheur est « protéger » — donc la confiance
    # reçoit en plus l'apport de posture. Ce n'est pas une dérive du contenu,
    # c'est la grammaire des trois axes qui s'applique.
    verifier('confiance', v['confiance'], 9)
    verifier('lucidite', v['lucidite'], 1)
    verifier('refus', v['refus'], False)
    verifier('branche_ch1', v['branche_ch1'], 'allié')
    verifier('indices', sorted(v['indices']),
             sorted(['PROFIL_SUSPECT', 'PLAQUE', 'AUTOCOLLANT', 'TELEPHONE']))
    verifier('Léna révélée par le geste', v['contacts_reveles'], ['lena'])
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

    p.choisir('Bonsoir, qui')                        # confiance 4
    p.choisir("Quelqu'un qui a reçu")          # confiance 5, empathie -> N5 -> N8
    # V3.2 : la capture est au N8, donc on zoome AVANT de choisir la suite.
    # C'est tout l'intérêt du déplacement — l'incohérence n°1 n'est plus
    # réservée à la branche « appelez la police ».
    p.choisir('Zoomer sur la capture')         # lucidite 1 (récépissé daté de juin)
    p.choisir("N'y allez pas seule")           # lucidite 2 -> N10
    verifier('Nœud du refus raisonnable', p.noeud['code'], 'N10')

    verifier('Zoom N10 non répétable',
             any(c['label'].startswith('Zoomer') for c in p.noeud['choices']), False)
    verifier('Le nœud ne bouge pas après une interaction', p.noeud['code'], 'N10')

    p.choisir('Je suis désolé, je ne peux pas')                # -> N11 : le NŒUD pose refus = true
    verifier('Branche du refus', p.noeud['code'], 'N11')

    p.choisir('Je lis, soyez prudente')        # confiance 5 -> 6 -> N14
    p.choisir('Restez cachée')                 # -> N17
    p.choisir('C\'est quoi ce bruit')          # lucidite 3 (incohérence audio)
    verifier('Le nœud ne bouge pas après la réécoute', p.noeud['code'], 'N17')

    # Ce gain porterait la confiance à 7. refus = true -> il doit être écrêté à 6.
    p.choisir("D'accord mais restez loin")     # -> N19 -> N20
    r = p.choisir('Il faut porter ça à la police')  # lucidite 4 -> N9
    # refus = true ici : N9 doit garder le vouvoiement, pas demander à tutoyer.
    # La vidéo de transition (N9#0) n'a pas de corps texte, quel que soit refus.
    ouverture_n9 = next(m['body'] for m in r['new_messages']
                         if m['sender'] == 'contact' and m['body'] is not None)
    verifier('N9 maintient le vouvoiement (refus=true)',
             ouverture_n9.startswith('Je suis rentrée, je respire un peu mieux... Ça ne vous dérange pas si je continue à vous vouvoyer'),
             True)
    r = p.continuer()                           # fallback -> N21
    # refus = true : N21 vouvoie, comme le reste du chapitre (messages.conditions).
    ouverture_n21 = next(m['body'] for m in r['new_messages'] if m['sender'] == 'contact')
    verifier('N21 vouvoie (refus=true)',
             ouverture_n21.startswith('Je ne vous ai pas dit'), True)

    r = p.choisir('Zoomer sur la photo')       # TELEPHONE -> N22
    verifier('N22 vouvoie (refus=true)',
             any(m['sender'] == 'contact' and m['body'].startswith('Je vous explique')
                 for m in r['new_messages']), True)

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
# PARCOURS 3 — branche N6 (la seule qui n'a longtemps rien révélé)
# ---------------------------------------------------------------------------

def sim_reveal(partie, code):
    """Le geste « Enregistrer le contact »."""
    r = http(f'{API}/functions/v1/reveal-contact', {'contact_code': code}, partie.token)
    partie.etat = {**partie.etat, 'conversations': r['conversations']}
    return r


def parcours_branche_n6():
    """Le joueur rembarre Léna, elle revient. Ton plus formel, et elle se nomme
    quand même : c'est le trou de contenu Q7, refermé en V2.1."""
    print('\n' + '=' * 78)
    print('  BRANCHE N6 — Léna rembarrée puis insistante')
    print('=' * 78)
    p = Partie('branche6@test.local', 'N6')

    p.choisir('Je ne suis pas Karim')   # -> N2
    verifier('Toujours anonyme au N2', p.etat['conversations'][0]['display_name'], 'Numéro inconnu')

    r = p.choisir('Bonne soirée')            # -> N6
    verifier('Nœud N6 atteint', p.noeud['code'], 'N6')
    verifier('Carte posée sur la branche N6 aussi',
             any(m['content_type'] == 'contact_card' for m in r['new_messages']), True)

    # « Plus tard » : on n'enregistre pas. L'histoire continue, Léna reste anonyme.
    verifier('Sans enregistrement, elle reste anonyme',
             p.etat['conversations'][0]['display_name'], 'Numéro inconnu')
    v = variables_en_base(p.email)['variables']
    verifier('Aucune révélation en base', v['contacts_reveles'], [])
    return p


# ---------------------------------------------------------------------------
# PARCOURS 4 — la carte de contact
# ---------------------------------------------------------------------------

def parcours_carte():
    print('\n' + '=' * 78)
    print('  CARTE D\'ENREGISTREMENT — geste, filet de sécurité, garde-fou')
    print('=' * 78)
    p = Partie('carte@test.local', 'carte')

    # Garde-fou : on ne peut pas révéler un contact dont la carte n'est pas reçue.
    try:
        http(f'{API}/functions/v1/reveal-contact', {'contact_code': 'lena'}, p.token)
        verifier('Révélation refusée avant la carte', 'acceptée', 'refusée')
    except RuntimeError as e:
        verifier('Révélation refusée avant la carte', 'HTTP 403' in str(e), True)

    # On joue jusqu'à la fin SANS jamais enregistrer.
    p.choisir('Bonsoir, qui'); p.choisir("Quelqu'un qui a reçu")
    verifier('Anonyme après la carte, sans geste',
             p.etat['conversations'][0]['display_name'], 'Numéro inconnu')

    p.choisir("D'accord, je garde mon"); p.choisir('Prenez la plaque')
    p.choisir("Zoomer sur l'auto"); p.choisir('Rentre chez toi')
    p.continuer(); p.choisir('Zoomer sur la photo')

    verifier('Fin de chapitre atteinte', p.noeud['code'], 'N22')
    verifier('Filet de sécurité : révélée à la fin malgré tout',
             p.etat['conversations'][0]['display_name'], 'Léna')
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
    cible = next(c for c in p.noeud['choices'] if c['label'].startswith('Bonsoir, qui'))
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
# PARCOURS 4 — les postures
# ---------------------------------------------------------------------------

CHEMIN_ALLIE = ['Bonsoir, qui', "Quelqu'un qui a reçu", "D'accord, je garde mon",
                'Prenez la plaque', "Zoomer sur l'auto", 'Il faut porter']


def parcours_postures():
    """Le même chemin narratif, joué avec trois postures différentes.

    C'est le contrôle qui donne son sens à la grammaire des trois axes : si
    trois joueurs prennent exactement les mêmes décisions structurantes et
    finissent au même endroit avec le même profil, les micro-choix ne mesurent
    rien. On vérifie donc qu'ils divergent — et surtout COMMENT.
    """
    print('\n' + '=' * 78)
    print('  PARCOURS « POSTURES » — trois joueurs, le même chemin')
    print('=' * 78)

    profils = {}
    for posture in ('proteger', 'enquete', 'raison'):
        p = Partie(f'posture-{posture}@test.local', posture, posture)
        for cible in CHEMIN_ALLIE:
            p.choisir(cible)
        v = variables_en_base(p.email)['variables']
        profils[posture] = v
        print(f"   {posture:<9} · {p.micro_vus} micro-choix · confiance {v['confiance']}"
              f" · lucidite {v['lucidite']} · enquete {v['enquete']}")

    print()
    verifier('Protéger maximise la confiance',
             profils['proteger']['confiance'] > profils['raison']['confiance'], True)
    verifier('Enquêter maximise enquete',
             profils['enquete']['enquete'] > profils['proteger']['enquete'], True)
    verifier('Raisonner maximise la lucidité',
             profils['raison']['lucidite'] > profils['proteger']['lucidite'], True)

    # La règle la plus facile à casser sans s'en apercevoir : douter ne coûte
    # rien. On la compare à « enquêter », qui ne touche pas non plus la
    # confiance — les deux doivent finir au même niveau.
    verifier('Raisonner n\'est jamais puni (= enquêter en confiance)',
             profils['raison']['confiance'], profils['enquete']['confiance'])

    # Les paliers d'enquete servent aux ch. 4-5 : un joueur qui enquête
    # franchit les deux, un joueur qui ne le fait pas n'en franchit aucun.
    verifier('Un enquêteur franchit le palier bas (2)',
             profils['enquete']['enquete'] >= 2, True)
    verifier('Un enquêteur franchit le palier haut (6)',
             profils['enquete']['enquete'] >= 6, True)
    verifier('Un non-enquêteur n\'ouvre rien',
             profils['proteger']['enquete'] < 2, True)

    # La fin cachée demande lucidite >= 4. Elle doit rester atteignable sans
    # passer par une branche structurante particulière — c'est la raison du
    # déplacement du zoom au N8.
    verifier('La fin cachée reste atteignable en raisonnant',
             profils['raison']['lucidite'] >= 4, True)


# ---------------------------------------------------------------------------

if __name__ == '__main__':
    allie = parcours_allie()
    refus = parcours_refus()
    n6 = parcours_branche_n6()
    parcours_carte()
    parcours_postures()
    erreurs_et_idempotence()

    print('\n' + '=' * 78)
    print('  CHEMINS PARCOURUS')
    print('=' * 78)
    for nom, p in (('allié', allie), ('refus', refus), ('branche N6', n6)):
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
