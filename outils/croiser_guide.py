# Croise les checks de l'apworld avec donnees/guide_missions.json (mission ou le guide ramasse l'objet).
# Sortie : donnees/guide_croise.json (cle -> mission la plus tot) + liste des checks introuvables.
import json, re
from pathlib import Path
R = Path(__file__).resolve().parent.parent
G = json.loads((R / "donnees/guide_missions.json").read_text(encoding="utf-8"))
N = json.loads((R / "donnees/noms.json").read_text(encoding="utf-8"))
L = json.loads((R / "apworld/fnafsb/data/locations.json").read_text(encoding="utf-8"))
E = {e["id"]: e for e in json.loads((R / "donnees/emplacements.json").read_text(encoding="utf-8"))}
ORDRE = [k for k in G if not k.startswith("_")]
def n(s): return re.sub(r"[^a-z0-9]", "", s.lower().replace("piñata", "pinata").replace("ñ", "n"))
guide = {}
for m in ORDRE:
    for nom in G[m]:
        guide.setdefault(n(nom), m)   # la premiere mission (ordre de l'histoire) gagne
def titre(l):
    e = E.get(l["cle"], {})
    ob = e.get("objet") or ""
    if l["genre"] == "message":
        t = N["messages"].get("Loc_MessageData_%s_Title" % ob, {}).get("en")
        return t or ob
    return N["objets"].get(ob, {}).get("en") or re.sub(r".*\((.*)\).*", r"\1", l["en"])
res, manque = {}, []
for l in L:
    if l["genre"] == "mission":
        continue
    t = titre(l)
    m = guide.get(n(t))
    if m:
        res[l["cle"]] = {"mission": m, "nom": t}
    else:
        manque.append((l["zone"], l["cle"], t))
(R / "donnees/guide_croise.json").write_text(json.dumps(res, indent=1, ensure_ascii=False), encoding="utf-8")
print("trouves", len(res), "| introuvables", len(manque))
for z, c, t in sorted(manque): print("  ?", z, "|", c, "|", t)
