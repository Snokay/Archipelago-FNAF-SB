# Portes de securite (BP_DoorMaster et derivees) : structure DoorEntryRequirements dans chaque carte
import json, glob, os, subprocess, sys

cartes = [f for f in glob.glob('cartes/**/*.umap', recursive=True) if b'DoorEntryRequirements' in open(f, 'rb').read()]
print(len(cartes), 'cartes avec des portes a exigences', file=sys.stderr)


def cherche(valeur, out):
    # parcourt une propriete (structures imbriquees) et releve les champs d'exigence
    if isinstance(valeur, list):
        for v in valeur:
            cherche(v, out)
    elif isinstance(valeur, dict):
        n = valeur.get('Name')
        if n in ('RequiredSecurityLevel', 'RequiredItem', 'RequiredInventoryItem', 'RequiresPartyPass', 'RequiredPawn'):
            out[n] = valeur.get('Value')
        cherche(valeur.get('Value'), out)


lignes = []
for f in cartes:
    chemin = f.replace(os.sep, '/')
    nom = os.path.basename(chemin)[:-5]
    zone = chemin.split('/Maps/')[1].rsplit('/', 1)[0] if '/Maps/' in chemin else '?'
    js = 'json/' + nom + '.json'
    if not os.path.exists(js):
        subprocess.run(['./uassetgui/UAssetGUI.exe', 'tojson', f, js, 'VER_UE4_27'], timeout=300)
    try:
        j = json.load(open(js, encoding='utf-8'))
    except Exception as e:
        print('ERREUR', nom, e, file=sys.stderr)
        continue
    imp, ex = j['Imports'], j['Exports']
    for e in ex:
        data = [p for p in (e.get('Data') or []) if isinstance(p, dict)]
        req = [p for p in data if p.get('Name') in ('DoorEntryRequirements', 'NormalDoorEntryRequirements')]
        if not req:
            continue
        out = {}
        cherche(req, out)
        if not out:
            continue
        ci = e.get('ClassIndex')
        classe = imp[-ci - 1]['ObjectName'] if ci and ci < 0 else '?'
        pos = ''
        # l'exigence est souvent sur le composant "Door" : la position est celle de son acteur (outer)
        acteur = e
        if not any(p.get('Name') == 'RootComponent' for p in data) and e.get('OuterIndex', 0) > 0:
            acteur = ex[e['OuterIndex'] - 1]
        data_a = [p for p in (acteur.get('Data') or []) if isinstance(p, dict)]
        rc = next((p.get('Value') for p in data_a if p.get('Name') == 'RootComponent'), None)
        if isinstance(rc, int) and rc > 0:
            for q in (ex[rc - 1].get('Data') or []):
                if isinstance(q, dict) and q.get('Name') == 'RelativeLocation':
                    v = q['Value'][0]['Value']
                    pos = '%d %d %d' % tuple(float(v[k] or 0) for k in 'XYZ')
        lignes.append((zone, nom, acteur['ObjectName'], classe, str(out.get('RequiredSecurityLevel', '')),
                       str(out.get('RequiredItem', out.get('RequiredInventoryItem', ''))), str(out.get('RequiresPartyPass', '')), pos))

with open('portes_securite.tsv', 'w', encoding='utf-8') as o:
    o.write('zone\tcarte\tacteur\tclasse\tniveau\tobjet\tbillet\tpos\n')
    for l in lignes:
        o.write('\t'.join(l) + '\n')
print(len(lignes), 'portes', file=sys.stderr)
