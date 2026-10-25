"""
Génère le pack PopTracker de Security Breach (2026-10-22, sur le modèle de celui de RE Village) :
  build/poptracker/FNaF_SB_AP/          pack (variantes fr / en)
  build/poptracker/FNaF_SB_AP_<version>.zip

Données : apworld/fnafsb/data (ids, noms, zones et règles = mêmes que la génération) et
donnees/emplacements.json (positions dans le monde). Une carte par étage = la vraie carte du jeu
(Fazwatch, extraite du pak), points aux vraies coordonnées ; les missions (sans position) sur un onglet
à part. Icônes = vraies icônes d'inventaire. Suivi automatique : objets reçus, checks faits, et les
checks absents de la partie (options) sont masqués grâce à slot_data["emplacements"].

    python make_poptracker.py 0.9.1.0
"""

import json
import math
import re
import shutil
import subprocess
import sys
import unicodedata
import zipfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ICI = Path(__file__).resolve().parent
RACINE = ICI.parent
sys.path.insert(0, str(ICI))
import textures_ue  # noqa: E402
DATA = RACINE / "apworld" / "fnafsb" / "data"
OUT = RACINE / "build" / "poptracker" / "FNaF_SB_AP"


def constantes_apworld():
    """HORS_AP / JAMAIS de l'apworld : objets jamais melanges (le joueur les ramasse comme dans le jeu de
    base). Le tracker ne les affiche pas et ses regles ne les demandent pas."""
    import ast
    arbre = ast.parse((RACINE / "apworld" / "fnafsb" / "__init__.py").read_text(encoding="utf-8"))
    vals = {}
    for n in arbre.body:
        if isinstance(n, ast.Assign) and len(n.targets) == 1 and getattr(n.targets[0], "id", "") in ("HORS_AP", "JAMAIS"):
            vals[n.targets[0].id] = ast.literal_eval(n.value)
    hors = vals.get("HORS_AP", {})
    return set(hors), set(hors.values()) | set(vals.get("JAMAIS", set()))


HORS_EMPLACEMENTS, HORS_OBJETS = constantes_apworld()

ROSE, CYAN, FOND = (255, 63, 180), (63, 230, 255), (11, 6, 20)
VUE = "vue_d_ensemble"


def police(taille):
    for nom in ("bahnschrift.ttf", "segoeuib.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(nom, taille)
        except OSError:
            continue
    return ImageFont.load_default()


def slug(texte):
    texte = unicodedata.normalize("NFKD", texte).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", texte.lower()).strip("_")


def code_item(code):
    """Code AP de l'objet -> code PopTracker."""
    return "badge" if code == "badge" else slug(code.replace("objet:", "").replace("prog:", "prog_"))


def regle(exige):
    """Exigences de l'apworld -> règle PopTracker ("badge:2,flashlight")."""
    morceaux = []
    if exige.get("badges"):
        morceaux.append(f"badge:{exige['badges']}")
    if exige.get("billets"):
        morceaux.append(f"prog_partypass:{exige['billets']}")
    morceaux += [code_item(o) for o in exige.get("objets", []) if o not in HORS_OBJETS]
    return ",".join(morceaux)


# --- images ---------------------------------------------------------------------------------------

def titre_neon(img, titre):
    """Titre rose avec un halo (texte flouté ajouté par-dessus) en haut à gauche."""
    halo = Image.new("RGB", img.size, (0, 0, 0))
    ImageDraw.Draw(halo).text((24, 16), titre, font=police(40), fill=ROSE)
    img = ImageChops.add(img, halo.filter(ImageFilter.GaussianBlur(8)))
    ImageDraw.Draw(img).text((24, 16), titre, font=police(40), fill=ROSE)
    return img


LOGO = Path(__file__).resolve().parent.parent / "mod" / "ArchipelagoSB" / "images" / "logo_menu.png"


def avec_logo(img, taille=170):
    """Logo "Security Breach Archipelago by Snokayy" en haut a droite (comme le logo du pack Ratchet)."""
    if not LOGO.exists() or img.width < taille * 3:
        return img
    logo = Image.open(LOGO).convert("RGBA").resize((taille, taille), Image.LANCZOS)
    img = img.convert("RGBA")
    img.alpha_composite(logo, (img.width - taille - 12, 8))
    return img.convert("RGB")


def fond_neon(w, h, titre):
    """Fond violet nuit quadrillé (onglet des missions, sans carte)."""
    img = Image.new("RGB", (w, h), FOND)
    d = ImageDraw.Draw(img)
    for x in range(0, w, 50):
        d.line([(x, 0), (x, h)], fill=(28, 16, 48))
    for y in range(0, h, 50):
        d.line([(0, y), (w, y)], fill=(28, 16, 48))
    return titre_neon(img, titre)


def icone(chemin, source):
    """Icône d'objet = vraie icône d'inventaire du jeu, ramenée à 64 px (+ version éteinte)."""
    im = source.copy()
    im.thumbnail((64, 64), Image.LANCZOS)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    img.paste(im, ((64 - im.width) // 2, (64 - im.height) // 2), im)
    img.save(chemin)
    gris = Image.new("RGBA", img.size)
    gris.paste(img.convert("LA").convert("RGBA"), (0, 0), img)
    Image.blend(Image.new("RGBA", img.size, (0, 0, 0, 0)), gris, 0.45).save(chemin.with_name(chemin.stem + "_off.png"))


def coffre(chemin, ouvert):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    couleur = (90, 80, 110, 255) if ouvert else ROSE + (255,)
    d.rounded_rectangle([4, 10, 27, 27], radius=4, fill=(20, 10, 34, 255), outline=couleur, width=3)
    if not ouvert:
        d.rectangle([4, 10, 27, 15], fill=couleur)
    img.save(chemin)


# --- textures du jeu ------------------------------------------------------------------------------

PAK = "D:/Steam/steamapps/common/Quarters/fnaf9/Content/Paks/fnaf9-WindowsNoEditor.pak"
CLE = "0x85F7D4007015493ED0359C9007266038F8F7B1F96988F19A610103874CC95286"
EXTRAIT = ICI / "extrait"


def texture_jeu(chemin):
    """/Game/... -> image Pillow (extraite du pak au besoin, voir textures_ue.py)."""
    base = "fnaf9/Content/" + chemin[len("/Game/"):]
    if not (EXTRAIT / (base + ".uexp")).exists():
        dans_pak = set((ICI / "liste_pak.txt").read_text(encoding="utf-8").split())
        fichiers = [base + e for e in (".uasset", ".uexp", ".ubulk") if base + e in dans_pak]
        args = [a for f in fichiers for a in ("-i", f)]
        subprocess.run([str(ICI / "repak" / "repak.exe"), "-a", CLE, "unpack", "-q", "-f", "-o", str(EXTRAIT)]
                       + args + [PAK], check=True)
    return textures_ue.lire(str(EXTRAIT / (base + ".uexp")))


def icones_inventaire():
    """Code AP de l'objet -> chemin de son icône d'inventaire (InventoryDataTable)."""
    inv = json.loads((ICI / "json" / "InventoryDataTable.json").read_text(encoding="utf-8"))
    imports = inv["Imports"]
    lignes = {r["Name"]: r for r in inv["Exports"][0]["Table"]["Data"]}
    def icone(ligne):
        ic = [p["Value"] for p in lignes[ligne]["Value"] if p["Name"] == "ItemIcon"]
        return imports[-imports[-ic[0] - 1]["OuterIndex"] - 1]["ObjectName"] if ic and ic[0] < 0 else None

    def chemin(code):
        if code == "badge":
            return icone("SecurityBadgeKitchen")
        if code.startswith("prog:"):   # série : icône du premier de la série qui en a une
            prefixe = code[len("prog:"):]
            for ligne in sorted(l for l in lignes if l.startswith(prefixe)):
                if icone(ligne):
                    return icone(ligne)
        return icone(code.replace("objet:", ""))
    return chemin


# Catégories du tracker (en bas, comme le pack Ratchet) : code AP -> catégorie
CATEGORIES = [
    ("cles", "Clés & passes", "Keys & passes",
     ["badge", "prog:PartyPass_", "objet:CompPass", "objet:PhotoPass", "objet:DaycarePass", "objet:BackstagePass",
      "objet:AdmissionPass", "objet:DancePass", "objet:BowlingTicket", "objet:MazerciseTicket",
      "objet:PartyPassChicaRoom", "objet:Map", "objet:UtilityHallwayMap"]),
    ("freddy", "Freddy", "Freddy",
     ["objet:ChicaBeak", "objet:RoxyEyes", "objet:MontyClaws", "prog:FreddyUpgrade_"]),
    ("defense", "Défense", "Defense",
     ["objet:Flashlight", "prog:FlashlightUpgrade_", "objet:FlashBeacon", "prog:FlashBeaconUpgrade_", "objet:Fazergun"]),
    ("gregory", "Gregory", "Gregory",
     ["prog:GregoryUpgrade_Stamina_", "objet:GregoryUpgrade_Shoes", "objet:GregoryUpgrade_Stealth"]),
    ("quete", "Quête", "Quest items",
     ["objet:ScrewDriver", "objet:PerformanceDisk", "objet:MrHippoMagnet", "objet:MontyMysteryMix",
      "objet:MazerciseControlKey", "objet:DamagedHead"]),
]


# --- cartes d'étage -----------------------------------------------------------------------------
# Cartes du jeu (Fazwatch) : une texture 2048 px par étage, toutes cadrées pareil par BP_MiniMap_Plane
# (MAP_MinimapPlane : centre X 2325 / Y 35290, plan de 50 000 unités tourné de 180°). L'étage d'un
# sous-niveau vient de MapReference_DT (StreamingLevels).

ETAGES = [  # nom dans MapReference_DT, texture, fr, en
    ("Main", "Floor00", "Rez-de-chaussée", "Main floor"),
    ("Level1", "Floor01", "Niveau 1", "Floor 1"),
    ("Level2", "Floor02", "Niveau 2", "Floor 2"),
    ("Level3", "Floor03", "Niveau 3", "Floor 3"),
    ("Level4", "Floor05", "Niveau 4", "Floor 4"),
    ("Basement1", "Basement1", "Sous-sol 1", "Basement 1"),
    ("Basement2", "Basement2", "Sous-sol 2", "Basement 2"),
]
CENTRE, COTE, PX = (2325.0, 35290.0), 50000.0, 2048


def monde_vers_carte(x, y):
    return PX / 2 - (x - CENTRE[0]) / COTE * PX, PX / 2 - (y - CENTRE[1]) / COTE * PX


def transformations():
    """Sous-niveau -> (X, Y, Z, lacet) : MAP_TheWorld place certains sous-niveaux décalés et tournés
    (Fazer Blast, Monty Golf, cuisine, égouts...). Les positions relevées dans leurs fichiers sont locales."""
    chemin = ICI / "json" / "MAP_TheWorld.json"
    if not chemin.exists():
        subprocess.run([str(ICI / "uassetgui" / "UAssetGUI.exe"), "tojson",
                        str(ICI / "cartes" / "fnaf9" / "Content" / "Maps" / "World" / "MAP_TheWorld.umap"),
                        str(chemin), "VER_UE4_27"], check=True)
    d = json.loads(chemin.read_text(encoding="utf-8"))
    out = {}
    for e in d["Exports"]:
        data = e.get("Data")
        if not isinstance(data, list):
            continue
        p = {x.get("Name"): x for x in data if isinstance(x, dict)}
        if "LevelTransform" not in p or "WorldAsset" not in p:
            continue
        wa = p["WorldAsset"]["Value"]
        nom = (wa.get("AssetPath", {}).get("AssetName") if isinstance(wa, dict) else str(wa)) or ""
        tr = {q["Name"]: q["Value"][0]["Value"] for q in p["LevelTransform"]["Value"]
              if isinstance(q.get("Value"), list) and q["Value"]}
        f = lambda v: float(v) if v not in (None, "") else 0.0
        t, r = tr.get("Translation", {}), tr.get("Rotation", {})
        lacet = 2 * math.atan2(f(r.get("Z")), f(r.get("W"))) if r.get("W") is not None else 0.0
        out[nom.rsplit(".", 1)[-1]] = (f(t.get("X")), f(t.get("Y")), f(t.get("Z")), lacet)
    return out


def vers_monde(pos, tr):
    x, y, z = pos
    tx, ty, tz, a = tr
    return [tx + x * math.cos(a) - y * math.sin(a), ty + x * math.sin(a) + y * math.cos(a), tz + z]


def etages_des_niveaux():
    d = json.loads((ICI / "json" / "MapReference_DT.json").read_text(encoding="utf-8"))
    etage = {}
    for r in d["Exports"][0]["Table"]["Data"]:
        for p in r["Value"]:
            if p["Name"].startswith("StreamingLevels"):
                for v in p["Value"]:
                    etage.setdefault(v["Value"], r["Name"])
    return etage


def ecarter(px, w, h, haut=76):
    """Écarte les points trop proches pour qu'ils restent cliquables."""
    px = [list(p) for p in px]
    for _ in range(120):
        bouge = False
        for i in range(len(px)):
            for j in range(i + 1, len(px)):
                dx, dy = px[j][0] - px[i][0], px[j][1] - px[i][1]
                dist = math.hypot(dx, dy)
                if dist < 26:
                    if dist < 0.01:
                        dx, dy, dist = 1.0, 0.0, 1.0
                    pousse = (26 - dist) / 2
                    px[i][0] -= dx / dist * pousse
                    px[i][1] -= dy / dist * pousse
                    px[j][0] += dx / dist * pousse
                    px[j][1] += dy / dist * pousse
                    bouge = True
        if not bouge:
            break
    return [(int(min(max(x, 16), w - 16)), int(min(max(y, haut), h - 16))) for x, y in px]


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else "0.9.1.0"
    locs = [l for l in json.loads((DATA / "locations.json").read_text(encoding="utf-8"))
            if l["cle"] not in HORS_EMPLACEMENTS]
    items = json.loads((DATA / "items.json").read_text(encoding="utf-8"))
    zones = json.loads((DATA / "zones.json").read_text(encoding="utf-8"))["zones"]
    def pos_valide(p):
        try:
            return [float(v) for v in p[:3]] if p and len(p) >= 3 else None
        except ValueError:
            return None
    emplacements = json.loads((RACINE / "donnees" / "emplacements.json").read_text(encoding="utf-8"))
    # positions manquantes (quelques objets) et missions : onglet "Missions" à part
    decalages = transformations()
    positions = {e["id"]: pos_valide(e.get("pos")) for e in emplacements}
    positions = {e["id"]: vers_monde(positions[e["id"]], decalages.get(e["carte"], (0, 0, 0, 0)))
                 for e in emplacements if positions.get(e["id"])}

    # étage de chaque check : par son sous-niveau, sinon l'étage où il tombe sur la carte (hauteur la
    # plus proche si plusieurs)
    niveaux = etages_des_niveaux()
    cartes = {n: texture_jeu(f"/Game/Blueprints/Player/UI/CameraMaps/UniformSize/minimaps_{t}_2k") for n, t, _, _ in ETAGES}
    alpha = {n: im.getchannel("A").load() for n, im in cartes.items()}
    # Etage d'un check : 1) son sous-niveau dans MapReference_DT (noms compares sans "MAP_" ni casse :
    # la table ecrit "MainLobby_Gameplay", nos emplacements "MAP_MainLobby_Gameplay") ; 2) sinon l'etage
    # majoritaire des checks connus du meme dossier de zone (Daycare/Airlock_Rooms -> celui de Daycare...) ;
    # 3) sinon la carte du jeu ou il tombe, hauteur la plus proche. Avant, tout passait par 3) : les checks
    # de l'entree de la garderie etaient repartis sur trois etages.
    def norm(n):
        n = n.lower()
        return re.sub(r"[^a-z0-9]", "", n[4:] if n.startswith("map_") else n)
    par_nom = {norm(k): v for k, v in niveaux.items()}
    etage = {}
    for e in emplacements:
        if e["id"] in positions and par_nom.get(norm(e["carte"])):
            etage[e["id"]] = par_nom[norm(e["carte"])]
    zone_de = {e["id"]: e.get("zone", "") for e in emplacements}
    def par_dossier(zone):
        morceaux = zone.split("/")
        for i in range(len(morceaux), 0, -1):
            prefixe = "/".join(morceaux[:i])
            vote = {}
            for k, n in connus.items():   # seulement les etages donnes par le jeu
                z = zone_de.get(k, "")
                if z == prefixe or z.startswith(prefixe + "/"):
                    vote[n] = vote.get(n, 0) + 1
            if vote:
                return max(vote, key=vote.get)
    hauteurs = {}
    for k, n in etage.items():
        hauteurs.setdefault(n, []).append(positions[k][2])
    hauteur = {n: sorted(v)[len(v) // 2] for n, v in hauteurs.items()}
    connus = dict(etage)
    for k, (x, y, z) in positions.items():
        if k in connus:
            continue
        n = par_dossier(zone_de.get(k, ""))
        # le dossier ne suffit pas quand la hauteur dit autre chose (comptoir des prix rangé sous StageArea
        # mais au 3e, comme El Chip)
        if n and z > hauteur[n] + 800:
            n = None
        if not n:
            u, v = monde_vers_carte(x, y)
            dedans = [m for m in hauteur if 0 <= u < PX and 0 <= v < PX and alpha[m][int(u), int(v)] > 0]
            n = min(dedans or list(hauteur), key=lambda m: abs(hauteur[m] - z))
        etage[k] = n
    # on vide le dossier sans le supprimer (il peut être ouvert dans un explorateur)
    if OUT.exists():
        for f in OUT.iterdir():
            shutil.rmtree(f) if f.is_dir() else f.unlink()
    (OUT / "images" / "items").mkdir(parents=True)
    (OUT / "scripts").mkdir()
    (OUT / "maps").mkdir()
    (OUT / "layouts").mkdir()
    coffre(OUT / "images" / "chest_closed.png", False)
    coffre(OUT / "images" / "chest_opened.png", True)

    # objets suivis : progression + améliorations (une fois chacun), avec leur vraie icône d'inventaire
    suivis, vus = [], set()
    for i in items:
        if i["classe"] in ("progression", "useful") and i["code"] not in vus and i["code"] not in HORS_OBJETS:
            vus.add(i["code"])
            suivis.append(i)
    ranges = {c for _, _, _, codes in CATEGORIES for c in codes}
    for i in suivis:
        if i["code"] not in ranges:
            print("objet sans catégorie dans le tracker :", i["code"])
    icone_de = icones_inventaire()
    for it in suivis:
        icone(OUT / "images" / "items" / f"{code_item(it['code'])}.png", texture_jeu(icone_de(it["code"])))

    # cartes : une par étage (vraie carte du jeu recadrée) + un onglet pour les missions
    maps, points = [], {}
    for n, _, fr, en in ETAGES:
        ici = [l for l in locs if l["cle"] in positions and etage.get(l["cle"]) == n]
        if not ici:
            continue
        im = cartes[n]
        uv = [monde_vers_carte(*positions[l["cle"]][:2]) for l in ici]
        x0, y0, x1, y1 = im.getchannel("A").getbbox()
        x0, y0 = min([x0] + [u for u, _ in uv]) - 60, min([y0] + [v for _, v in uv]) - 130
        x1, y1 = max([x1] + [u for u, _ in uv]) + 60, max([y1] + [v for _, v in uv]) + 60
        x0, y0, x1, y1 = int(max(x0, 0)), int(max(y0, 0)), int(min(x1, PX)), int(min(y1, PX))
        echelle = min(1.0, 1600 / (x1 - x0))
        w, h = int((x1 - x0) * echelle), int((y1 - y0) * echelle)
        img = Image.new("RGBA", (w, h), FOND + (255,))
        img.alpha_composite(im.crop((x0, y0, x1, y1)).resize((w, h), Image.LANCZOS))
        img = avec_logo(titre_neon(img.convert("RGB"), fr.upper() + "  /  " + en.upper()))
        img.save(OUT / "images" / f"map_{n}.png")
        pix = ecarter([((u - x0) * echelle, (v - y0) * echelle) for u, v in uv], w, h)
        for l, xy in zip(ici, pix):
            points.setdefault(l["id"], []).append((n, xy))
        maps.append({"name": f"map_{n}", "location_size": 22, "location_border_thickness": 2,
                     "img": f"images/map_{n}.png"})
    sans = [l for l in locs if l["id"] not in points]
    if sans:
        # nom à côté de chaque case (français, anglais en dessous : l'image sert aux deux variantes)
        par_col, col, ligne = 20, 470, 44
        W, H = 40 + col * ((len(sans) + par_col - 1) // par_col), 130 + par_col * ligne
        img = fond_neon(W, H, "MISSIONS")
        d = ImageDraw.Draw(img)
        for i, l in enumerate(sans):
            x, y = 40 + col * (i // par_col), 120 + (i % par_col) * ligne
            points.setdefault(l["id"], []).append(("missions", (x, y)))
            d.text((x + 22, y - 17), l["fr"], font=police(17), fill=(235, 225, 245))
            if l["en"] != l["fr"]:
                d.text((x + 22, y + 2), l["en"], font=police(14), fill=(150, 135, 175))
        img = avec_logo(img)
        img.save(OUT / "images" / "map_missions.png")
        maps.append({"name": "map_missions", "location_size": 22, "location_border_thickness": 2,
                     "img": "images/map_missions.png"})
    (OUT / "maps" / "maps.json").write_text(json.dumps(maps, indent=1), encoding="utf-8")

    # objets
    def item_defs(lang):
        out = []
        for it in suivis:
            c = code_item(it["code"])
            d = {"name": it[lang], "img": f"images/items/{c}.png", "codes": c}
            if (it.get("nombre") or 1) > 1:
                d.update(type="consumable", max_quantity=it["nombre"], disabled_img=f"images/items/{c}_off.png",
                         disabled_img_mods="@disabled")
            else:
                d.update(type="toggle", disabled_img=f"images/items/{c}_off.png", disabled_img_mods="@disabled")
            out.append(d)
        return out

    noms_zone = {z["nom"]: z for z in zones}
    for lang in ("fr", "en"):
        vdir = OUT / lang
        for sous in ("items", "locations", "scripts"):
            (vdir / sous).mkdir(parents=True)
        (vdir / "items" / "items.json").write_text(json.dumps(item_defs(lang), ensure_ascii=False, indent=1), encoding="utf-8")
        locs_json, id_map, deja = [], {}, set()
        for l in locs:
            z = noms_zone[l["zone"]]
            regles = [r for r in (regle(z["exige"]), regle(l.get("exige", {}))) if r]
            nom = l[lang]
            while nom in deja:
                nom += " "
            deja.add(nom)
            locs_json.append({"name": nom, "chest_unopened_img": "images/chest_closed.png",
                              "chest_opened_img": "images/chest_opened.png",
                              "map_locations": [{"map": f"map_{m}", "x": xy[0], "y": xy[1]} for m, xy in points.get(l["id"], [])],
                              "sections": [{"name": "Check", "item_count": 1,
                                            "access_rules": [",".join(regles)] if regles else []}]})
            id_map[l["id"]] = f"@{nom}/Check"
        (vdir / "locations" / "locations.json").write_text(json.dumps(locs_json, ensure_ascii=False, indent=1), encoding="utf-8")
        lignes = ["-- généré par outils/make_poptracker.py", "LOCATION_MAPPING = {"]
        lignes += [f"  [{lid}] = {json.dumps(path, ensure_ascii=False)}," for lid, path in sorted(id_map.items())]
        lignes.append("}")
        (vdir / "scripts" / "ids.lua").write_text("\n".join(lignes) + "\n", encoding="utf-8")

    lignes = ["-- généré par outils/make_poptracker.py", "ITEM_MAPPING = {"]
    # tous les objets dont le code est suivi (ex. le 2e Mystery Mix, rangé en remplissage)
    lignes += [f"  [{it['id']}] = {json.dumps(code_item(it['code']))}," for it in items if it["code"] in vus]
    lignes.append("}")
    (OUT / "scripts" / "items_map.lua").write_text("\n".join(lignes) + "\n", encoding="utf-8")

    (OUT / "scripts" / "init.lua").write_text('''-- FNaF Security Breach Archipelago : pack généré par outils/make_poptracker.py
ScriptHost:LoadScript("scripts/items_map.lua")
Tracker:AddItems("items/items.json")
Tracker:AddMaps("maps/maps.json")
ScriptHost:LoadScript("scripts/ids.lua")
Tracker:AddLocations("locations/locations.json")
Tracker:AddLayouts("layouts/tracker.json")
if Archipelago then
    ScriptHost:LoadScript("scripts/autotracking.lua")
end
''', encoding="utf-8")
    (OUT / "scripts" / "autotracking.lua").write_text('''-- Suivi automatique Archipelago
local function reset()
    for _, c in pairs(ITEM_MAPPING) do
        local o = Tracker:FindObjectForCode(c)
        if o then
            if o.Type == "consumable" then o.AcquiredCount = 0 else o.Active = false end
        end
    end
    for _, path in pairs(LOCATION_MAPPING) do
        local s = Tracker:FindObjectForCode(path)
        if s then s.AvailableChestCount = s.ChestCount end
    end
end

-- Checks absents de cette partie (options : missions, messages ou CD coupés) : marqués faits pour
-- disparaître de la carte. slot_data.emplacements = {cle = id} des checks actifs.
local function masquer_inactifs(slot_data)
    if not slot_data or not slot_data.emplacements then return end
    local actifs = {}
    for _, id in pairs(slot_data.emplacements) do actifs[tonumber(id)] = true end
    for id, path in pairs(LOCATION_MAPPING) do
        if not actifs[id] then
            local s = Tracker:FindObjectForCode(path)
            if s then s.AvailableChestCount = 0 end
        end
    end
end

function on_clear(slot_data)
    Tracker.BulkUpdate = true
    pcall(reset)
    pcall(masquer_inactifs, slot_data)
    Tracker.BulkUpdate = false
end

function on_item(index, item_id, item_name, player)
    local c = ITEM_MAPPING[item_id]
    if not c then return end
    local o = Tracker:FindObjectForCode(c)
    if not o then return end
    if o.Type == "consumable" then o.AcquiredCount = o.AcquiredCount + 1 else o.Active = true end
end

function on_location(location_id, location_name)
    local path = LOCATION_MAPPING[location_id]
    if not path then return end
    local s = Tracker:FindObjectForCode(path)
    if s then s.AvailableChestCount = 0 end
end

Archipelago:AddClearHandler("clear", on_clear)
Archipelago:AddItemHandler("item", on_item)
Archipelago:AddLocationHandler("location", on_location)
''', encoding="utf-8")

    # disposition (comme le pack Ratchet) : cartes en onglets, objets en bas rangés par catégorie.
    # Un layout par langue (titres traduits) ; celui de la racine sert de repli.
    largeurs = {"cles": 5, "freddy": 2, "defense": 3, "gregory": 3, "quete": 3}
    def layout(lang):
        groupes = []
        for cle, fr, en, codes in CATEGORIES:
            codes = [code_item(c) for c in codes if c in vus]
            n = largeurs[cle]
            groupes.append({"type": "group", "header": fr if lang == "fr" else en,
                            "content": {"type": "itemgrid", "item_margin": "4,3", "h_alignment": "left",
                                        "item_size": 56, "rows": [codes[i:i + n] for i in range(0, len(codes), n)]}})
        objets = {"type": "array", "orientation": "horizontal", "content": groupes}
        onglets = [{"title": fr if lang == "fr" else en, "content": {"type": "map", "maps": [f"map_{n}"]}}
                   for n, _, fr, en in ETAGES if any(m["name"] == f"map_{n}" for m in maps)]
        if sans:
            onglets.append({"title": "Missions", "content": {"type": "map", "maps": ["map_missions"]}})
        vue = {"type": "container", "background": "#0b0614", "content": {
            "type": "dock", "dropshadow": True, "content": [
                {"type": "dock", "dock": "bottom", "content": [objets]},
                {"type": "tabbed", "tabs": onglets}]}}
        return {"tracker_default": vue, "tracker_horizontal": vue, "tracker_vertical": vue,
                "tracker_broadcast": objets}
    (OUT / "layouts" / "tracker.json").write_text(json.dumps(layout("fr"), ensure_ascii=False, indent=1), encoding="utf-8")
    for lang in ("fr", "en"):
        (OUT / lang / "layouts").mkdir(exist_ok=True)
        (OUT / lang / "layouts" / "tracker.json").write_text(json.dumps(layout(lang), ensure_ascii=False, indent=1),
                                                            encoding="utf-8")

    manifest = {"name": "FNaF Security Breach Archipelago", "game_name": "Five Nights at Freddy's Security Breach",
                "package_uid": "fnaf_sb_archipelago_snokayy", "package_version": version, "platform": "pc",
                "author": "Snokayy", "min_poptracker_version": "0.25.6", "target_poptracker_version": "0.35.4",
                "variants": {"fr": {"display_name": "Français", "flags": ["ap"]},
                             "en": {"display_name": "English", "flags": ["ap"]}}}
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")

    archive = OUT.parent / f"FNaF_SB_AP_{version}.zip"
    if archive.exists():
        archive.unlink()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(OUT.rglob("*")):
            if f.is_file():
                z.write(f, "FNaF_SB_AP/" + f.relative_to(OUT).as_posix())
    n = sum(len(v) for v in points.values())
    print(f"pack prêt : {archive} ({len(locs)} checks, {n} points sur {len(maps)} cartes, {len(suivis)} objets suivis)")


if __name__ == "__main__":
    main()
