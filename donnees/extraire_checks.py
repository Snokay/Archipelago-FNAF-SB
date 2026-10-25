# Lit les cartes du jeu (converties en JSON par UAssetGUI) et liste les emplacements ramassables
import json, glob, re, subprocess, os, sys, collections
CLES = re.compile(rb'/Game/Blueprints/Objects/Collectibles/|PRE_BadgeHolder')
cartes = [f for f in glob.glob('cartes/**/*.umap', recursive=True) if CLES.search(open(f,'rb').read())]
print(len(cartes), 'cartes avec des ramassables', file=sys.stderr)
os.makedirs('json', exist_ok=True)
lignes = []
exemples = {}
for f in cartes:
    nom = os.path.basename(f)[:-5]
    js = f'json/{nom}.json'
    if not os.path.exists(js):
        subprocess.run(['./uassetgui/UAssetGUI.exe', 'tojson', f, js, 'VER_UE4_27'], timeout=300)
    try:
        j = json.load(open(js, encoding='utf-8'))
    except Exception as e:
        print('ERREUR', nom, e, file=sys.stderr); continue
    imp, ex = j['Imports'], j['Exports']
    def classe(e):
        ci = e.get('ClassIndex')
        return imp[-ci-1]['ObjectName'] if ci and ci < 0 else ''
    def props(e):
        return {p['Name']: p for p in (e.get('Data') or []) if isinstance(p, dict) and 'Name' in p}
    def valeur(p):
        v = p.get('Value')
        if isinstance(v, list):
            return v
        return v
    for e in ex:
        c = classe(e)
        if not (('Collect' in c or 'BadgeHolder' in c or 'Pass' in c or 'Ticket' in c or 'MrHippo' in c
                 or 'MontyMysteryMix' in c or 'MazerciseControlKey' in c) and c.endswith('_C')):
            continue
        p = props(e)
        if c not in exemples:
            exemples[c] = {k: (str(valeur(v))[:60]) for k, v in p.items()}
        objet = ''
        for champ in ('ItemName', 'BadgeAward', 'MessageName', 'Message', 'ItemAward', 'P_FazerBlasterName'):
            if champ in p and p[champ].get('Value') not in (None, 'None'):
                objet = str(p[champ]['Value']); break
        # position : RelativeLocation du composant racine
        x = y = z = ''
        rc = p.get('RootComponent', {}).get('Value')
        if isinstance(rc, int) and rc > 0:
            for q in (ex[rc-1].get('Data') or []):
                if isinstance(q, dict) and q.get('Name') == 'RelativeLocation':
                    v = q['Value'][0]['Value'] if isinstance(q.get('Value'), list) else {}
                    x, y, z = round(v.get('X', 0)), round(v.get('Y', 0)), round(v.get('Z', 0))
        lignes.append((nom, e['ObjectName'], c, objet, x, y, z))
with open('emplacements.tsv', 'w', encoding='utf-8') as o:
    o.write('carte\tacteur\tclasse\tobjet\tx\ty\tz\n')
    for l in lignes: o.write('\t'.join(map(str, l)) + '\n')
json.dump(exemples, open('exemples_classes.json', 'w', encoding='utf-8'), indent=1)
print(len(lignes), 'emplacements', file=sys.stderr)
