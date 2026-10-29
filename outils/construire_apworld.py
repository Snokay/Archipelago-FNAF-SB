# Genere les donnees de l'apworld (apworld/fnafsb/data/*.json) a partir des donnees extraites du jeu :
# donnees/emplacements.json (cartes), donnees/noms.json (noms officiels FR/EN), donnees/zones.json (logique).
# Les numeros sont stables : ils suivent l'ordre des listes ci-dessous (ajouter a la fin, ne pas reordonner).
import json, os, collections

ICI = os.path.dirname(os.path.abspath(__file__))
DON = os.path.join(ICI, '..', 'donnees')
SORTIE = os.path.join(ICI, '..', 'apworld', 'fnafsb', 'data')
os.makedirs(SORTIE, exist_ok=True)

emplacements = json.load(open(os.path.join(DON, 'emplacements.json'), encoding='utf-8'))
noms = json.load(open(os.path.join(DON, 'noms.json'), encoding='utf-8'))
zones = json.load(open(os.path.join(DON, 'zones.json'), encoding='utf-8'))
OBJ = noms['objets']

# ---------- Ordre de l'histoire ----------
# Le jeu n'ouvre une mission qu'apres ses DependentMissions (MissionDataTable) et certaines zones qu'a un
# point de l'histoire (champ "histoire" de zones.json). Une mission exige donc aussi tout ce qu'exigent les
# missions d'avant (et leurs zones) ; une zone, tout ce qu'exigent les missions qui l'ouvrent. Sans ca, la
# logique placait par exemple le laissez-passer de la garderie derriere Showtime : partie bloquee.
_mdt = json.load(open(os.path.join(ICI, 'json', 'MissionDataTable.json'), encoding='utf-8'))
AVANT = {r['Name']: [v['Value'] for x in r['Value'] if x['Name'] == 'DependentMissions' for v in x['Value']]
         for r in _mdt['Exports'][0]['Table']['Data']}


def fusion(*exiges):
    out = {}
    for e in exiges:
        for k in ('badges', 'billets'):
            if e.get(k):
                out[k] = max(out.get(k, 0), e[k])
        for o in e.get('objets', []):
            out.setdefault('objets', [])
            if o not in out['objets']:
                out['objets'].append(o)
    return out


# Zone de depart (Rockstar Row, autour de la loge de Freddy) : la partie commence dans la carte Backstage,
# pas dans le hall. Emplacements atteints sans rien au tout debut (releves en partie test le 23/10). Le
# pass photo ouvre la sortie : toutes les autres zones l'exigent, et l'apworld le place dans l'un de ces
# emplacements (DEPART dans __init__.py).
DEPART = ['MAP_Backstage_Gameplay:PhotoPassCollectible2', 'MAP_Backstage_Gameplay:PresentCollectible2_5',
          'MAP_Backstage_Gameplay:MessageCollectible_2', 'MAP_Backstage_Gameplay:PresentCollectible_2']
for z in zones['zones']:
    z['exige'] = fusion(z.get('exige', {}), {'objets': ['objet:PhotoPass']})
ZONE_DEPART = {'nom': 'depart', 'dossier': None, 'fr': 'Depart (Rockstar Row)', 'en': 'Start (Rockstar Row)',
               'exige': {}}
zones['zones'].insert(0, ZONE_DEPART)
# Couloir technique de "Sortez d'ici" : la piñata de Chica s'y ramasse avant le hall, sans badge ni lampe (le
# reste du secteur technique vient bien plus tard). Seul autre spot possible du billet d'entree (joueur 27/10).
COULOIR_SORTIE = ['MAP_UtiliDoorsGameplay:PresentCollectible2_2']
ZONE_SORTIE = {'nom': 'sortie', 'dossier': None, 'fr': 'Couloir de sortie', 'en': 'Exit hallway',
               'exige': {'objets': ['objet:PhotoPass']}}
zones['zones'].insert(1, ZONE_SORTIE)

_zone = {z['nom']: z for z in zones['zones']}
_mission = {m['mission']: m for m in zones['missions']}
_memo = {}


def exige_mission(nom):
    if nom not in _memo:
        _memo[nom] = {}   # garde-fou contre une boucle
        m = _mission.get(nom)
        propre = [exige_zone(m['zone']), m.get('exige', {})] if m else []
        # missions annexes sans DependentMissions mais ouvertes a une heure precise de l'histoire
        propre += [exige_mission(h) for h in (m.get('histoire', []) if m else [])]
        _memo[nom] = fusion(*propre, *(exige_mission(d) for d in AVANT.get(nom, [])))
    return _memo[nom]


# Missions forcement faites avant (histoire + DependentMissions, en chaine) : sert a reperer les emplacements
# atteints seulement apres un combat (les yeux de Roxy n'y vont que si Roxy est battue, sinon 6 h trop tot)
_avant_memo = {}


def missions_avant(nom):
    if nom not in _avant_memo:
        _avant_memo[nom] = set()
        m = _mission.get(nom, {})
        res = set()
        for h in m.get('histoire', []) + AVANT.get(nom, []) + (_zone[m['zone']].get('histoire', []) if m else []):
            res |= {h} | missions_avant(h)
        _avant_memo[nom] = res
    return _avant_memo[nom]


def exige_zone(nom):
    z = _zone[nom]
    return fusion(z.get('exige', {}), *(exige_mission(m) for m in z.get('histoire', [])))


_zones_completes = {n: exige_zone(n) for n in _zone}
for m in zones['missions']:
    m['exige'] = exige_mission(m['mission'])
for z in zones['zones']:
    z['exige'] = _zones_completes[z['nom']]
_fin_histoire = [exige_mission(m) for m in zones['fin'].get('histoire', [])]
zones['fin']['exige'] = fusion(zones['fin'].get('exige', {}), *_fin_histoire)
zones['fin']['fins'] = {k: fusion(v, *_fin_histoire) for k, v in zones['fin'].get('fins', {}).items()}

BASE_OBJ = 7_210_000
BASE_EMP = 7_220_000


# Noms du jeu trop proches pour les hints (joueurs 29/10) : le billet de la loge de Chica s'appelait comme le
# billet d'entree progressif
RENOMS = {'PartyPassChicaRoom': ('Billet de la loge de Chica', "Chica's Greenroom Pass"),
          'MontyMysteryMix': ('Mystery Mix de Monty', 'Monty Mystery Mix')}


def nom_objet(code):
    if code in RENOMS:
        return RENOMS[code]
    n = OBJ.get(code)
    return (n['fr'], n['en']) if n else (code, code)


# ---------- Objets ----------
objets = []


def ajoute(code, fr, en, genre, classe, nombre=1):
    objets.append({'id': BASE_OBJ + len(objets), 'code': code, 'fr': fr, 'en': en, 'genre': genre,
                   'classe': classe, 'nombre': nombre})


# Progression
ajoute('badge', 'Badge de securite progressif', 'Progressive Security Badge', 'progression', 'progression', 10)
HISTOIRE = ('CompPass', 'PhotoPass', 'DaycarePass', 'BackstagePass', 'AdmissionPass', 'DancePass', 'BowlingTicket',
          'MazerciseTicket', 'PartyPassChicaRoom', 'ChicaBeak', 'RoxyEyes', 'MontyClaws', 'ScrewDriver', 'Flashlight',
          'FlashBeacon', 'Fazergun', 'Map', 'UtilityHallwayMap', 'PerformanceDisk', 'MrHippoMagnet', 'MontyMysteryMix',
          'MazerciseControlKey', 'DamagedHead')
for c in HISTOIRE:
    fr, en = nom_objet(c)
    ajoute('objet:' + c, fr, en, 'progression', 'progression')
ajoute('prog:PartyPass_', "Billet d'entree", 'Party Pass', 'progression', 'progression', 9)
# Utiles
ajoute('prog:FlashlightUpgrade_', 'Amelioration de lampe progressive', 'Progressive Flashlight Upgrade', 'utile', 'useful', 6)
ajoute('prog:FreddyUpgrade_', 'Amelioration de Freddy progressive', 'Progressive Freddy Upgrade', 'utile', 'useful', 4)
ajoute('prog:FlashBeaconUpgrade_', 'Amelioration de Faz Camera progressive', 'Progressive Faz Camera Upgrade', 'utile', 'useful', 2)
ajoute('prog:GregoryUpgrade_Stamina_', 'Fizzy Faz progressif', 'Progressive Fizzy Faz', 'utile', 'useful', 5)
for c in ('GregoryUpgrade_Shoes', 'GregoryUpgrade_Stealth'):
    fr, en = nom_objet(c)
    ajoute('objet:' + c, fr, en, 'utile', 'useful')
# Collectibles (remplissage), dans l'ordre de conservation : les premiers restent le plus longtemps
PRIORITE = [('c_golden_', 1), ('c_plush_', 2), ('RareCollectible', 3), ('c_mask_', 4), ('c_magnet_', 4), ('c_key_', 4),
            ('c_gokart', 4), ('c_pinata', 4), ('UncommonCollectible', 5), ('RetroCD', 5), ('c_poster', 6),
            ('CommonCollectible', 7), ('c_shirt', 8)]


def priorite(code):
    for p, n in PRIORITE:
        if code.startswith(p):
            return n
    return 6


for code, n in OBJ.items():
    if n['categorie'] in ('Toys', 'Trophy', 'Food', 'Clothing', 'RetroCD') and not code.startswith('GregoryUpgrade') \
            and code not in ('Wallet',):
        # Mystery Mix : objet d'histoire ET boisson (categorie Food) ; le doublon de remplissage donnait le meme
        # objet du jeu (le mod le prenait pour celui de l'histoire). Garde pour ne pas decaler les id, hors du pool
        doublon = code in HISTOIRE
        objets.append({'id': BASE_OBJ + len(objets), 'code': 'objet:' + code,
                       'fr': n['fr'] + (' (inutilise)' if doublon else ''), 'en': n['en'] + (' (unused)' if doublon else ''),
                       'genre': 'inutilise' if doublon else 'collectible', 'classe': 'filler', 'nombre': 1,
                       'priorite': priorite(code)})
# Messages (notes et mails ramasses dans le monde) : aussi des objets de remplissage
for m in sorted({e['objet'] for e in emplacements if e['type'] == 'message' and e['objet'] not in ('', '?')}):
    objets.append({'id': BASE_OBJ + len(objets), 'code': 'message:' + m, 'fr': 'Message : ' + m, 'en': 'Message: ' + m,
                   'genre': 'message', 'classe': 'filler', 'nombre': 1, 'priorite': 6})
# Bonus (memes id que bonus.lua) et pieges (noms trolls, sans description)
for i, (fr, en) in enumerate((('Recharge de la lampe', 'Flashlight Recharge'), ('Recharge de Freddy', 'Freddy Recharge'),
                              ('Recharge de la Faz Camera', 'Faz Camera Recharge'), ('Endurance illimitee', 'Unlimited Stamina'),
                              ('Choc', 'Shock'))):
    ajoute('bonus:' + ('lampe', 'freddy', 'flashs', 'endurance', 'choc')[i], fr, en, 'bonus', 'filler')
for code, fr, en in (('piege:alerte', 'Signalement au StaffBot', 'StaffBot Report'),
                     ('piege:screamer', 'Visite surprise', 'Surprise Visit'),
                     ('piege:bornes', 'Fizzy Faz renverse', 'Spilled Fizzy Faz'),
                     ('piege:lampe', 'Piles empruntees', 'Borrowed Batteries'),
                     ('piege:lent', 'Chewing-gum sous les chaussures', 'Gum Under Your Shoes'),
                     ('piege:entrave', 'Lacets noues', 'Tied Shoelaces'),
                     ('piege:turbo', 'Cafe pour les animatroniques', 'Animatronic Coffee')):
    ajoute(code, fr, en, 'piege', 'trap')

# Noms uniques (Archipelago l'exige) : doublons numerotes
for langue in ('fr', 'en'):
    vus = collections.Counter(o[langue] for o in objets)
    rang = collections.Counter()
    for o in objets:
        if vus[o[langue]] > 1:
            rang[o[langue]] += 1
            o[langue] = '%s %d' % (o[langue], rang[o[langue]])

# ---------- Emplacements ----------
REGLES = {k: v for k, v in json.load(open(os.path.join(DON, 'regles_emplacements.json'), encoding='utf-8')).items()
          if not k.startswith('_')}
ZONE = {z['dossier']: z for z in zones['zones']}
GENRE_NOM = {'cadeau': ('Cadeau', 'Present'), 'message': ('Message', 'Message'), 'cd': ('CD retro', 'Retro CD'),
             'badge': ('Porte-badge', 'Badge Holder'), 'special': ('Objet', 'Item')}
locs = []
for e in emplacements:
    z = ZONE_DEPART if e['id'] in DEPART else ZONE_SORTIE if e['id'] in COULOIR_SORTIE else ZONE.get(e['zone'].split('/')[0])
    # regle "zone" : check range dans le mauvais dossier par le jeu (ex. dome du comptoir des prix sous StageArea)
    if REGLES.get(e['id'], {}).get('zone'):
        z = next(x for x in zones['zones'] if x['nom'] == REGLES[e['id']]['zone'])
    if not z:
        continue
    gfr, gen = GENRE_NOM[e['type']]
    fr, en = nom_objet(e['objet'])
    if e['type'] == 'message':
        fr = en = e['objet']
    loc = {'id': BASE_EMP + len(locs), 'cle': e['id'], 'genre': e['type'], 'zone': z['nom'],
           'fr': '%s - %s (%s)' % (z['fr'], gfr, fr), 'en': '%s - %s (%s)' % (z['en'], gen, en)}
    # regles propres a l'emplacement (porte de niveau, piece de Freddy, moment de l'histoire, ratable)
    r = REGLES.get(e['id'])
    if r:
        ex = fusion(r.get('exige', {}), *(exige_mission(h) for h in r.get('histoire', [])))
        if ex:
            loc['exige'] = ex
        if r.get('exclu'):
            loc['exclu'] = True
    avant = set()
    for h in (r or {}).get('histoire', []) + z.get('histoire', []):
        avant |= {h} | missions_avant(h)
    if 'StopRoxy' in avant:
        loc['apres_roxy'] = True
    # CD retro : n'apparaissent qu'a la fin du jeu (joueur 29/10) -> exigent la fin la plus facile (logique et
    # PopTracker) ; l'apworld n'y met jamais d'objet important
    if e['type'] == 'cd':
        fin_facile = min(zones['fin']['fins'].values(), key=lambda f: f.get('badges', 0))
        loc['exige'] = fusion(loc.get('exige', {}), zones['fin'].get('exige', {}), fin_facile)
    locs.append(loc)
# Missions dont le nom affiche dans le jeu (DisplayName de MissionDataTable) n'est pas leur cle
NOM_AFFICHE = {'DJMusicMan': 'RepairRobotHead', 'PartsAndService': 'PartsandService',
               'MoonlightSerenade': 'Moonlight_Serenade', 'UpgradeFreddy': 'RoxyEyes'}
for m in zones['missions']:
    cle = NOM_AFFICHE.get(m['mission'], m['mission'])
    n = noms['missions'].get(cle, {'fr': m['mission'], 'en': m['mission']})
    z = next(x for x in zones['zones'] if x['nom'] == m['zone'])
    loc = {'id': BASE_EMP + len(locs), 'cle': 'mission:' + m['mission'], 'genre': 'mission', 'zone': m['zone'],
           'fr': 'Mission - ' + n['fr'], 'en': 'Mission - ' + n['en'], 'exige': m.get('exige', {})}
    # missions de la fin du jeu : jamais d'objet important (le joueur ne doit pas attendre la fin pour avancer)
    if m.get('exclu'):
        loc['exclu'] = True
    if m['mission'] == 'StopRoxy' or 'StopRoxy' in missions_avant(m['mission']):
        loc['apres_roxy'] = True
    locs.append(loc)
for langue in ('fr', 'en'):
    vus = collections.Counter(l[langue] for l in locs)
    rang = collections.Counter()
    for l in locs:
        if vus[l[langue]] > 1:
            rang[l[langue]] += 1
            l[langue] = '%s %d' % (l[langue], rang[l[langue]])

json.dump(objets, open(os.path.join(SORTIE, 'items.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
json.dump(locs, open(os.path.join(SORTIE, 'locations.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
json.dump(zones, open(os.path.join(SORTIE, 'zones.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print(len(objets), 'objets differents,', sum(o['nombre'] for o in objets if o['genre'] in ('progression', 'utile')),
      'progression/utiles,', sum(1 for o in objets if o['genre'] == 'collectible'), 'collectibles,', len(locs), 'emplacements')
