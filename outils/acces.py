# Acces par les portes : pour chaque emplacement, le plus petit niveau de badge (et l'objet de porte) qu'il
# faut pour l'atteindre depuis la loge de Freddy, calcule sur les vraies cartes d'etage du jeu.
#   sol = remplissage des cartes Fazwatch, murs = traits clairs, escaliers/ascenseurs = violet (relient les
#   etages), portes de securite = portes_securite.tsv (niveau, objet, billet) fermees si non satisfaites.
# Sortie : donnees/acces_portes.json {cle: {"badges": n, "objets": [...]}} + cartes de controle colorees.
#     python acces.py
import csv, json, os, sys
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw

sys.argv = sys.argv[:1]
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import make_poptracker as MP  # noqa: E402

RAYON_PORTE = 8        # px (1 px = ~24 unites) : bouche le passage d'une porte fermee
NIVEAUX = range(0, 13)
SORTIE = os.path.join(ICI, "..", "donnees", "acces_portes.json")
CONTROLE = os.path.join(ICI, "..", "visuel", "controle_acces")
os.makedirs(CONTROLE, exist_ok=True)

# --- cartes -----------------------------------------------------------------------------------------
noms_etages = [n for n, _, _, _ in MP.ETAGES]
cartes = {n: np.array(MP.texture_jeu(f"/Game/Blueprints/Player/UI/CameraMaps/UniformSize/minimaps_{t}_2k"))
          for n, t, _, _ in MP.ETAGES}
sol, violet = {}, {}
for n, a in cartes.items():
    r, g, b, al = [a[..., i].astype(int) for i in range(4)]
    vi = (al > 100) & (b > r + 40) & (b > g + 40)
    clair = (r + g + b) > 420
    sol[n] = (al > 100) & ~clair
    violet[n] = vi

# --- emplacements et portes dans le monde -----------------------------------------------------------
dec = MP.transformations()
niv = MP.etages_des_niveaux()
emps = json.load(open(os.path.join(ICI, "..", "donnees", "emplacements.json"), encoding="utf-8"))


def pos(p):
    try:
        return [float(v) for v in p[:3]]
    except (TypeError, ValueError):
        return None


hauteurs = {}
for e in emps:
    p = pos(e.get("pos"))
    if p and e["carte"] in niv:
        hauteurs.setdefault(niv[e["carte"]], []).append(MP.vers_monde(p, dec.get(e["carte"], (0, 0, 0, 0)))[2])
hauteur = {n: sorted(v)[len(v) // 2] for n, v in hauteurs.items()}


def etage_de(carte, x, y, z):
    if carte in niv:
        return niv[carte]
    u, v = MP.monde_vers_carte(x, y)
    if not (0 <= u < MP.PX and 0 <= v < MP.PX):
        return None
    ui, vi_ = int(u), int(v)
    dedans = [n for n in hauteur if sol[n][max(0, vi_ - 6):vi_ + 7, max(0, ui - 6):ui + 7].any()]
    return min(dedans or list(hauteur), key=lambda n: abs(hauteur[n] - z))


points = {}   # cle -> (etage, u, v)
for e in emps:
    p = pos(e.get("pos"))
    if not p:
        continue
    x, y, z = MP.vers_monde(p, dec.get(e["carte"], (0, 0, 0, 0)))
    n = etage_de(e["carte"], x, y, z)
    if n:
        u, v = MP.monde_vers_carte(x, y)
        points[e["id"]] = (n, int(u), int(v))

portes = []
for r in csv.DictReader(open(os.path.join(ICI, "portes_securite.tsv"), encoding="utf-8"), delimiter="\t"):
    if not r["pos"]:
        continue
    x, y, z = MP.vers_monde([float(v) for v in r["pos"].split()], dec.get(r["carte"], (0, 0, 0, 0)))
    n = etage_de(r["carte"], x, y, z)
    if not n:
        continue
    u, v = MP.monde_vers_carte(x, y)
    objet = r["objet"] if r["objet"] not in ("", "None") else None
    portes.append({"etage": n, "u": int(u), "v": int(v), "niveau": int(r["niveau"] or 0),
                   "objet": objet, "billet": r["billet"] == "True"})
OBJETS_PORTES = sorted({p["objet"] for p in portes if p["objet"]})
print(len(points), "emplacements places,", len(portes), "portes, objets de porte :", OBJETS_PORTES)

# disque de chaque porte (pre-calcule)
yy, xx = np.ogrid[-RAYON_PORTE:RAYON_PORTE + 1, -RAYON_PORTE:RAYON_PORTE + 1]
DISQUE = (xx * xx + yy * yy) <= RAYON_PORTE * RAYON_PORTE


def atteignables(niveau, objets):
    """Emplacements atteignables avec ce niveau et ces objets (portes non satisfaites fermees)."""
    labels, debut = {}, {}
    total = 0
    for n in noms_etages:
        m = sol[n] | violet[n]
        m = m.copy()
        for p in portes:
            if p["etage"] != n:
                continue
            ouverte = p["niveau"] <= niveau and (not p["objet"] or p["objet"] in objets) \
                and (not p["billet"] or "billet" in objets)
            if not ouverte:
                y0, x0 = p["v"] - RAYON_PORTE, p["u"] - RAYON_PORTE
                ys, xs = slice(max(0, y0), y0 + 2 * RAYON_PORTE + 1), slice(max(0, x0), x0 + 2 * RAYON_PORTE + 1)
                d = DISQUE[ys.start - y0:ys.stop - y0, xs.start - x0:xs.stop - x0][:m[ys, xs].shape[0], :m[ys, xs].shape[1]]
                m[ys, xs] &= ~d
        lab, nb = ndimage.label(m)
        labels[n] = lab
        debut[n] = total
        total += nb + 1
    # union-find : escaliers/ascenseurs (violet au meme endroit sur deux etages)
    parent = list(range(total))

    def racine(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i, a in enumerate(noms_etages):
        for b in noms_etages[i + 1:]:
            commun = ndimage.binary_dilation(violet[a], iterations=4) & violet[b]
            for la, lb in set(zip(labels[a][commun].tolist(), labels[b][commun].tolist())):
                if la and lb:
                    parent[racine(debut[a] + la)] = racine(debut[b] + lb)

    def composante(n, u, v):
        lab = labels[n]
        for r in range(0, 9):
            fen = lab[max(0, v - r):v + r + 1, max(0, u - r):u + r + 1]
            vals = fen[fen > 0]
            if vals.size:
                return racine(debut[n] + int(np.bincount(vals).argmax()))
        return None
    dep = composante(*points[DEPART])
    return {k for k, (n, u, v) in points.items() if composante(n, u, v) == dep}


DEPART = "MAP_Backstage_Gameplay:PhotoPassCollectible2"
ensembles = [frozenset()] + [frozenset({o}) for o in OBJETS_PORTES] + [frozenset({"billet"})]
if "PhotoPass" in OBJETS_PORTES:
    ensembles = [frozenset()] + [frozenset({"PhotoPass"})] + \
        [frozenset({"PhotoPass", o}) for o in OBJETS_PORTES if o != "PhotoPass"] + [frozenset({"PhotoPass", "billet"})]

acces = {}
for objets in ensembles:
    for niveau in NIVEAUX:
        ok = atteignables(niveau, objets)
        for k in ok:
            if k not in acces or (len(objets), niveau) < (len(acces[k][1]), acces[k][0]):
                acces[k] = (niveau, objets)
    print("objets", sorted(objets) or "-", ":", len([k for k in acces]), "emplacements atteints au total")

resultat = {}
for k in points:
    if k in acces:
        n, objs = acces[k]
        ex = {}
        if n:
            ex["badges"] = n
        objs = sorted(("prog:PartyPass_" if o == "billet" else "objet:" + o) for o in objs)
        billets = [o for o in objs if o.startswith("prog:")]
        if billets:
            ex["billets"] = 1
        objs = [o for o in objs if not o.startswith("prog:")]
        if objs:
            ex["objets"] = objs
        resultat[k] = ex
    else:
        resultat[k] = None   # pas atteint par l'analyse : on ne touche pas a sa regle
json.dump(resultat, open(SORTIE, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print(sum(1 for v in resultat.values() if v is not None), "/", len(resultat), "emplacements analyses ->", SORTIE)

# --- cartes de controle : couleur = niveau requis, croix = pas atteint ------------------------------
COUL = [(80, 255, 80), (160, 255, 60), (230, 230, 40), (255, 190, 40), (255, 140, 40), (255, 90, 40),
        (255, 40, 40), (220, 40, 120), (180, 40, 200), (120, 60, 255), (60, 120, 255), (40, 200, 255), (255, 255, 255)]
for n in noms_etages:
    im = Image.fromarray(cartes[n]).convert("RGBA")
    fond = Image.new("RGBA", im.size, (10, 6, 20, 255))
    fond.alpha_composite(im)
    d = ImageDraw.Draw(fond)
    for p in portes:
        if p["etage"] == n:
            d.rectangle((p["u"] - 5, p["v"] - 5, p["u"] + 5, p["v"] + 5), outline=(255, 255, 255, 255), width=2)
            d.text((p["u"] + 7, p["v"] - 7), (str(p["niveau"]) if p["niveau"] else "") + (p["objet"] or "")[:8]
                   + ("B" if p["billet"] else ""), fill=(255, 255, 255, 255))
    for k, (e, u, v) in points.items():
        if e != n:
            continue
        ex = resultat.get(k)
        if ex is None:
            d.line((u - 8, v - 8, u + 8, v + 8), fill=(255, 0, 0, 255), width=3)
            d.line((u - 8, v + 8, u + 8, v - 8), fill=(255, 0, 0, 255), width=3)
        else:
            c = COUL[min(ex.get("badges", 0), 12)]
            d.ellipse((u - 9, v - 9, u + 9, v + 9), fill=c + (255,), outline=(0, 0, 0, 255), width=2)
            etiquette = str(ex.get("badges", 0)) + ("+" + ",".join(o.split(":")[1][:6] for o in ex.get("objets", [])
                                                                  if o != "objet:PhotoPass") if ex.get("objets") else "")
            d.text((u + 10, v - 6), etiquette, fill=(255, 255, 255, 255))
    bb = fond.getbbox()
    fond.save(os.path.join(CONTROLE, f"acces_{n}.png"))
print("cartes de controle ->", CONTROLE)
