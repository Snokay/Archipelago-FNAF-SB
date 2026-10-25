# Noms officiels du jeu en anglais (tables de chaines) et en francais (Game.locres) -> donnees/noms.json
import struct, json, glob, os, sys, subprocess

R = os.path.abspath('repak/repak.exe')
PAK = 'D:/Steam/steamapps/common/Quarters/fnaf9/Content/Paks/fnaf9-WindowsNoEditor.pak'
CLE = '0x85F7D4007015493ED0359C9007266038F8F7B1F96988F19A610103874CC95286'


class Lecteur:
    def __init__(self, d, pos=0):
        self.d, self.p = d, pos

    def i32(self):
        v = struct.unpack_from('<i', self.d, self.p)[0]
        self.p += 4
        return v

    def u32(self):
        v = struct.unpack_from('<I', self.d, self.p)[0]
        self.p += 4
        return v

    def fstring(self):
        n = self.i32()
        if n == 0:
            return ''
        if n < 0:  # UTF-16
            n = -n
            s = self.d[self.p:self.p + 2 * n].decode('utf-16-le')
            self.p += 2 * n
        else:
            s = self.d[self.p:self.p + n].decode('latin-1')
            self.p += n
        return s.rstrip('\x00')


def table_chaines(uexp):
    # StringTable : (apres l'en-tete d'objet) Namespace, nombre, puis paires cle/valeur.
    # On cherche le debut en essayant chaque position plausible.
    d = open(uexp, 'rb').read()
    for debut in range(0, 64):
        try:
            L = Lecteur(d, debut)
            ns = L.fstring()
            n = L.i32()
            if not (0 < n < 5000) or not ns:
                continue
            paires = {}
            for _ in range(n):
                k = L.fstring()
                v = L.fstring()
                paires[k] = v
            return ns, paires
        except Exception:
            continue
    raise ValueError('table illisible ' + uexp)


def locres(chemin):
    d = open(chemin, 'rb').read()
    L = Lecteur(d)
    magic = d[:16]
    L.p = 16
    version = d[16]
    L.p = 17
    off_chaines = struct.unpack_from('<q', d, L.p)[0]
    L.p += 8
    if version >= 2:
        L.u32()  # nombre d'entrees
    # tableau des chaines
    P = Lecteur(d, off_chaines)
    nb = P.i32()
    chaines = []
    for _ in range(nb):
        s = P.fstring()
        if version >= 2:
            P.i32()  # compteur de references
        chaines.append(s)
    out = {}
    nb_ns = L.u32()
    for _ in range(nb_ns):
        if version >= 2:
            L.u32()
        ns = L.fstring()
        nb_k = L.u32()
        for _ in range(nb_k):
            if version >= 2:
                L.u32()
            k = L.fstring()
            L.u32()  # hash du texte source
            idx = L.i32()
            out[(ns, k)] = chaines[idx] if 0 <= idx < len(chaines) else ''
    return out


os.makedirs('extrait', exist_ok=True)
for lang in ('fr', 'en'):
    subprocess.run([R, '-a', CLE, 'unpack', '-q', '-f', '-o', 'extrait', '-i',
                    'fnaf9/Content/Localization/Game/%s/Game.locres' % lang, PAK])

base = 'extrait/fnaf9/Content/Data/Localizations/Base_Game_Loc/'
noms = {'objets': {}, 'missions': {}, 'messages': {}}
fr = locres('extrait/fnaf9/Content/Localization/Game/fr/Game.locres')
for table, genre, suffixe in (('Loc_Inventory', 'objets', '_DisplayName'), ('Loc_Missions', 'missions', ''),
                              ('Loc_EmployeeMessages', 'messages', '')):
    ns, paires = table_chaines(base + table + '.uexp')
    for k, v in paires.items():
        if genre == 'objets':
            if not k.endswith('_DisplayName'):
                continue
            nom = k[len('Loc_Inventory_'):-len('_DisplayName')]
        elif genre == 'missions':
            if '_Task_' in k:
                continue
            nom = k[len('Loc_Mission_'):]
        else:
            if not k.endswith('_Title') and not k.endswith('_Subject'):
                continue
            nom = k
        noms[genre][nom] = {'en': v, 'fr': fr.get((ns, k), v)}
    print(table, ns, len(paires), 'entrees,', sum(1 for x in noms[genre].values() if x['fr'] != x['en']), 'traduites', file=sys.stderr)

os.makedirs('../donnees', exist_ok=True)
json.dump(noms, open('../donnees/noms.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print(json.dumps({g: list(v.items())[:3] for g, v in noms.items()}, ensure_ascii=False, indent=1))

# Objets : la table d'inventaire donne la cle de traduction exacte de chaque objet (et sa categorie)
inv = json.load(open('json/InventoryDataTable.json', encoding='utf-8'))['Exports'][0]['Table']['Data']
ns_inv, p_inv = table_chaines(base + 'Loc_Inventory.uexp')
objets = {}
for r in inv:
    champs = {x.get('Name'): x for x in r['Value']}
    t = champs.get('ItemDisplayName', {})
    cle = t.get('Value')
    en = p_inv.get(cle) if cle else t.get('CultureInvariantString')
    if not en:
        en = t.get('CultureInvariantString') or r['Name']
    objets[r['Name']] = {'en': en, 'fr': fr.get((ns_inv, cle), en) if cle else en,
                         'categorie': str(champs.get('Category', {}).get('Value', '')).split('::')[-1]}
noms['objets'] = objets
json.dump(noms, open('../donnees/noms.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print('objets', len(objets), file=sys.stderr)
