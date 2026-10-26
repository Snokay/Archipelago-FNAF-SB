# Liste les acteurs poses dans les cartes (outils/json, exports UAssetGUI) qui ont un objet (ItemName) ET un
# reglage qui parle de mission : ce sont les ramassables qui font avancer l'histoire quand on les prend.
# Sert a remplir LIEES dans mod/.../sb/missions_objets.lua.
import json, os, glob

ICI = os.path.dirname(os.path.abspath(__file__))


def proprietes(export):
    res = {}
    for p in export.get("Data") or []:
        if not isinstance(p, dict):
            continue
        nom, val = p.get("Name"), p.get("Value")
        if isinstance(val, (str, int, float, bool)):
            res[nom] = val
        elif isinstance(val, list):  # structures (ex. FMissionUpdate) : on aplatit un niveau
            for q in val:
                if isinstance(q, dict) and isinstance(q.get("Value"), (str, int, float, bool)):
                    res[f"{nom}.{q.get('Name')}"] = q.get("Value")
    return res


for f in sorted(glob.glob(os.path.join(ICI, "json", "*.json"))):
    try:
        d = json.load(open(f, encoding="utf-8"))
    except Exception:
        continue
    carte = os.path.splitext(os.path.basename(f))[0]
    for e in d.get("Exports") or []:
        p = proprietes(e)
        missions = {k: v for k, v in p.items() if "ission" in k and v not in ("None", "", None)}
        objet = p.get("ItemName") or p.get("BadgeAward")
        if missions and objet:
            print(f"{carte}:{e.get('ObjectName')}  objet={objet}")
            exports = d["Exports"]
            for k, v in missions.items():
                if isinstance(v, int) and 0 < v <= len(exports):  # lien vers un composant de l'acteur
                    c = exports[v - 1]
                    cp = {a: b for a, b in proprietes(c).items() if not isinstance(b, bool) or b}
                    print(f"    {k} -> {c.get('ObjectName')} {cp}")
                else:
                    print(f"    {k} = {v}")
