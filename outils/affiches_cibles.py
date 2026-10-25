# Affiches ciblees : chemins exacts des composants (maillages et decalcomanies) qui portent les affiches,
# releves dans les cartes extraites -> mod/ArchipelagoSB/Scripts/sb/affiches_cibles.lua (genere).
# En jeu, affiches.lua les demande par leur nom (StaticFindObject) au lieu de parcourir tout le decor.
import glob, json, os, subprocess

ICI = os.path.dirname(os.path.abspath(__file__))
UAG = os.path.join(ICI, "uassetgui", "UAssetGUI.exe")
CIBLES = list(json.load(open(os.path.join(ICI, "..", "donnees", "maillages_affiches.json"), encoding="utf-8")))
DECALS = ["MAT_Decal_Modern2"]          # poster de Roxy (decalcomanie)
SORTIE = os.path.join(ICI, "..", "mod", "ArchipelagoSB", "Scripts", "sb", "affiches_cibles.lua")
JSON = os.path.join(ICI, "json")


def nom(d, i):
    if i < 0:
        return d["Imports"][-i - 1]["ObjectName"]
    if i > 0:
        return d["Exports"][i - 1]["ObjectName"]
    return None


def props(e):
    data = e.get("Data")
    return {p.get("Name"): p for p in data if isinstance(p, dict)} if isinstance(data, list) else {}


chemins = []
for umap in sorted(glob.glob(os.path.join(ICI, "cartes", "**", "*.umap"), recursive=True)):
    brut = open(umap, "rb").read()
    if not any(c.encode() in brut for c in CIBLES + DECALS):
        continue
    carte = os.path.splitext(os.path.basename(umap))[0]
    js = os.path.join(JSON, carte + ".json")
    if not os.path.exists(js):
        subprocess.run([UAG, "tojson", umap, js, "VER_UE4_27"], capture_output=True)
    d = json.load(open(js, encoding="utf-8"))
    rel = os.path.relpath(umap, os.path.join(ICI, "cartes", "fnaf9", "Content")).replace(os.sep, "/")
    paquet = "/Game/" + rel[:-len(".umap")]
    ex = d["Exports"]
    for e in ex:
        p = props(e)
        cible = None
        if "StaticMesh" in p and nom(d, p["StaticMesh"].get("Value", 0)) in CIBLES:
            cible = "maillage"
        elif "DecalMaterial" in p and nom(d, p["DecalMaterial"].get("Value", 0)) in DECALS:
            cible = "decal"
        if not cible:
            continue
        # chemin : remonter les "outer" jusqu'au niveau (PersistentLevel)
        morceaux, o = [e["ObjectName"]], e.get("OuterIndex", 0)
        while o > 0:
            morceaux.insert(0, ex[o - 1]["ObjectName"])
            o = ex[o - 1].get("OuterIndex", 0)
        if morceaux[0] == carte:      # le monde porte le nom du paquet : deja dans "paquet.carte"
            morceaux.pop(0)
        chemin = "%s.%s:%s" % (paquet, carte, ".".join(morceaux))
        chemins.append((cible, chemin))

with open(SORTIE, "w", encoding="utf-8") as f:
    f.write("-- GENERE par outils/affiches_cibles.py : composants qui portent les affiches (ne pas modifier)\n")
    f.write("return {\n")
    for cible, chemin in chemins:
        f.write('    {"%s", "%s"},\n' % (cible, chemin))
    f.write("}\n")
print(len(chemins), "composants ->", os.path.normpath(SORTIE))
