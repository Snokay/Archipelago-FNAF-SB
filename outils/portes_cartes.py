# Portes a condition lues dans les cartes du jeu : niveau de securite, objet, billet exiges
import json, glob, os, subprocess, re, sys, collections

os.makedirs('json', exist_ok=True)
cartes = []
for f in glob.glob('cartes/**/*.umap', recursive=True):
    d = open(f, 'rb').read()
    if b'RequiredSecurityLevel' in d or b'RequiredInventoryItem' in d or b'RequiresPartyPass' in d:
        cartes.append(f)
print(len(cartes), 'cartes avec des portes a condition', file=sys.stderr)

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
        props = {p['Name']: p.get('Value') for p in (e.get('Data') or []) if isinstance(p, dict) and 'Name' in p}
        if not any(k in props for k in ('RequiredSecurityLevel', 'RequiredInventoryItem', 'RequiresPartyPass')):
            continue
        # le composant appartient a un acteur : son "Outer"
        outer = e.get('OuterIndex', 0)
        proprio = ex[outer - 1]['ObjectName'] if isinstance(outer, int) and outer > 0 else '?'
        ci = ex[outer - 1].get('ClassIndex') if isinstance(outer, int) and outer > 0 else None
        classe = imp[-ci - 1]['ObjectName'] if ci and ci < 0 else '?'
        lignes.append((zone, nom, proprio, classe, str(props.get('RequiredInventoryItem', '')),
                       str(props.get('RequiredSecurityLevel', '')), str(props.get('RequiresPartyPass', ''))))

with open('portes_cartes.tsv', 'w', encoding='utf-8') as o:
    o.write('zone\tcarte\tacteur\tclasse\tobjet\tniveau\tbillet\n')
    for l in lignes:
        o.write('\t'.join(l) + '\n')
print(len(lignes), 'portes', file=sys.stderr)
