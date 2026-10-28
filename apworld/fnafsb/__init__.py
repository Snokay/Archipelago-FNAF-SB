"""
APWorld pour Five Nights at Freddy's Security Breach.

Les donnees (data/*.json) sont GENEREES par outils/construire_apworld.py a partir des cartes et des
tables du jeu (emplacements, noms officiels FR/EN) et de donnees/zones.json (logique) : ne pas les
editer a la main.

Logique : une region par zone du Pizzaplex, atteignable selon ce qu'exige la zone (badges de
securite = niveau, laissez-passer, objets). Les missions sont des checks rattaches a leur zone.
"""

import json
import pkgutil
import math
from typing import Dict, Any

from BaseClasses import ItemClassification, Item, Location, LocationProgressType, Region
from worlds.AutoWorld import World, WebWorld
from ..generic.Rules import set_rule, add_item_rule

from .Options import FNaFSBOptions
from .lang import LANG


def charger(nom):
    return json.loads(pkgutil.get_data(__name__, "data/" + nom).decode("utf-8"))


OBJETS = charger("items.json")
EMPLACEMENTS = charger("locations.json")
ZONES = charger("zones.json")

JEU = "Five Nights at Freddy's Security Breach"
VICTOIRE = "Victoire" if LANG == "fr" else "Victory"
CLASSE = {"progression": ItemClassification.progression, "useful": ItemClassification.useful,
          "filler": ItemClassification.filler, "trap": ItemClassification.trap}

# Le pass photo ouvre la sortie de la zone de depart (Rockstar Row) : melange n'importe ou, il bloquait la
# partie des le debut. Il est place au hasard dans un emplacement de cette zone, dans ce monde-ci.
PASS_DEPART = "objet:PhotoPass"
# Objets qui ouvrent la sortie de la salle ou on les trouve (softlocks vecus en partie test) : dans ce
# monde-ci ils ne peuvent etre qu'a leur place d'origine ; en multiworld ils peuvent partir dans un autre jeu.
# Badges de la cuisine et du bureau des prix : en solo une copie du badge progressif y reste toujours ; en multiworld
# voir la regle des badges dans create_items.
VANILLA = {"MAP_MainLobby_Gameplay:ComplimentaryPass_3": "objet:CompPass",
           # garderie : plus de badge fixe (25/10), le mod garde le niveau 1 jusqu'a la fin de EscapeDaycare
           "MAP_Kitchen_Gameplay:PRE_BadgeHolder_2": "badge",
           "MAP_EastArcade_Gameplay2:PRE_BadgeHolder_PrizeCounter_2": "badge",  # autre chemin du 2e badge (El Chip)
           "mission:ChicaBeak": "objet:ChicaBeak"}  # la porte de sortie des egouts exige la boite vocale
# Hors d'Archipelago, comme la FazWatch : ni melange ni check, le joueur le ramasse comme dans le jeu de base
# Le pass coulisses, le billet de la loge de Chica et le Mystery Mix y etaient (leur ramassage fait avancer
# l'histoire) : depuis le 26/10 le mod fait avancer leur mission a la reception (sb/missions_objets.lua), ils
# sont melanges et les missions concernees les exigent (donnees/zones.json).
HORS_AP = {"MAP_MainLobby_Gameplay:PresentCollectible_2": "objet:ScrewDriver"}
# Donnes par le jeu sans emplacement (MapBot de l'entrepot) et exiges par une porte : jamais melanges
# FazMap : donnee par le MapBot (mission Carte gratuite) et jamais retiree par le mod (le joueur garde sa
# carte) ; aucune porte ne l'exige, la melanger ne faisait qu'un doublon inutile (joueur 25/10)
JAMAIS = {"objet:UtilityHallwayMap", "objet:Map"}


class FNaFSBItem(Item):
    game = JEU


class FNaFSBLocation(Location):
    game = JEU


class FNaFSBWeb(WebWorld):
    theme = "partyTime"


class FNaFSBWorld(World):
    """
    Gregory est enferme dans le Mega Pizzaplex de Freddy Fazbear. Badges, laissez-passer et pieces de
    Freddy sont melanges dans le multiworld ; les cadeaux, messages et missions envoient des objets.
    """
    game = JEU
    web = FNaFSBWeb()
    options_dataclass = FNaFSBOptions
    options: FNaFSBOptions

    item_name_to_id = {o[LANG]: o["id"] for o in OBJETS}
    location_name_to_id = {e[LANG]: e["id"] for e in EMPLACEMENTS}
    item_name_groups = {
        "Bonus": {o[LANG] for o in OBJETS if o["genre"] == "bonus"},
        "Collectibles": {o[LANG] for o in OBJETS if o["genre"] == "collectible"},
    }

    PAR_NOM = {o[LANG]: o for o in OBJETS}
    PAR_CODE = {o["code"]: o for o in OBJETS}

    # ---------- logique ----------
    def _nom(self, code):
        return self.PAR_CODE[code][LANG]

    def _peut(self, state, exige):
        if not exige:
            return True
        p = self.player
        if exige.get("badges") and not state.has(self._nom("badge"), p, exige["badges"]):
            return False
        if exige.get("billets") and not state.has(self._nom("prog:PartyPass_"), p, exige["billets"]):
            return False
        return all(state.has(self._nom(c), p) for c in exige.get("objets", []))

    def _actifs(self):
        o = self.options
        res = []
        for e in EMPLACEMENTS:
            if e["genre"] == "mission" and not o.checks_missions:
                continue
            if e["genre"] == "message" and not o.checks_messages:
                continue
            if e["genre"] == "cd" and not o.checks_cd:
                continue
            if e["cle"] in HORS_AP:
                continue
            res.append(e)
        return res

    # Multiworld, option debut rapide : ce qui ouvre le debut du jeu, sinon le joueur reste bloque a l'entree
    # du Pizzaplex. Dans NOS emplacements du depart : la "sphere 1" des autres jeux n'est pas fiable (test
    # 25/10 : boutique de Sly de Hollow Knight vue en sphere 1 a la generation, sphere 19 en vrai).
    # Le 1er badge (sortie de la garderie) ne peut etre chez nous que sur un porte-badge : sphere 1 de
    # n'importe quel jeu.
    # Le billet d'entree, lui, reste chez le joueur (sa place ou la piñata du couloir de sortie) : voir create_items.
    DEBUT_LOCAL = ["objet:DaycarePass", "objet:Flashlight"]
    PINATA_SORTIE = "MAP_UtiliDoorsGameplay:PresentCollectible2_2"
    DEBUT = ["badge"]

    def generate_early(self):
        if self.options.debut_rapide and len(self.multiworld.player_ids) > 1:
            for code in self.DEBUT_LOCAL:
                self.multiworld.local_early_items[self.player][self._nom(code)] = 1
            for code in self.DEBUT:
                self.multiworld.early_items[self.player][self._nom(code)] = 1

    def create_regions(self):
        menu = Region("Menu", self.player, self.multiworld)
        self.multiworld.regions.append(menu)
        regions = {}
        for z in ZONES["zones"]:
            r = Region(z[LANG], self.player, self.multiworld)
            regions[z["nom"]] = r
            self.multiworld.regions.append(r)
            entree = menu.connect(r)
            set_rule(entree, lambda state, ex=z["exige"]: self._peut(state, ex))
        for e in self._actifs():
            r = regions[e["zone"]]
            loc = FNaFSBLocation(self.player, e[LANG], e["id"], r)
            if e.get("exige"):
                set_rule(loc, lambda state, ex=e["exige"]: self._peut(state, ex))
            # ratable (plus atteignable apres un moment de l'histoire) : jamais d'objet important
            if e.get("exclu"):
                loc.progress_type = LocationProgressType.EXCLUDED
            r.locations.append(loc)
        # objets hors AP (et objets de sortie dont l'emplacement est desactive) : evenements a leur place,
        # la logique sait qu'on les a une fois la zone atteinte
        actifs = {e["cle"] for e in self._actifs()}
        evenements = dict(HORS_AP)
        evenements.update({c: v for c, v in VANILLA.items() if c not in actifs and v != "badge"})
        for e in EMPLACEMENTS:
            if e["cle"] in evenements:
                r = regions[e["zone"]]
                nom = self._nom(evenements[e["cle"]])
                loc = FNaFSBLocation(self.player, e[LANG], None, r)
                if e.get("exige"):
                    set_rule(loc, lambda state, ex=e["exige"]: self._peut(state, ex))
                loc.place_locked_item(FNaFSBItem(nom, ItemClassification.progression, None, self.player))
                r.locations.append(loc)
        # Victoire : fin du jeu (le client la confirme avec les compteurs de collectibles)
        fin = Region("Fin" if LANG == "fr" else "End", self.player, self.multiworld)
        self.multiworld.regions.append(fin)
        entree = menu.connect(fin)
        # Exigences de la fin choisie (le quai de chargement demande le niveau 7) ; "n'importe laquelle" :
        # la plus facile, "toutes" : chacune
        fins = ZONES["fin"]["fins"]
        choix = self.FINS[self.options.fin.value]
        if choix in fins:
            liste = [fins[choix]]
        elif choix == "toutes":
            liste = list(fins.values())
        else:
            liste = [min(fins.values(), key=lambda e: e.get("badges", 0))]
        exige = {"badges": max(e.get("badges", 0) for e in liste),
                 "objets": sorted({o for e in liste for o in e.get("objets", [])})}
        # Collectibles demandes : toutes les zones doivent etre atteignables (ils y sont repartis)
        if self.options.cadeaux or self.options.messages or self.options.cd:
            set_rule(entree, lambda state: self._peut(state, exige)
                     and all(self._peut(state, z["exige"]) for z in ZONES["zones"]))
        else:
            set_rule(entree, lambda state: self._peut(state, exige))
        victoire = FNaFSBLocation(self.player, VICTOIRE, None, fin)
        victoire.place_locked_item(FNaFSBItem(VICTOIRE, ItemClassification.progression, None, self.player))
        fin.locations.append(victoire)
        self.multiworld.completion_condition[self.player] = lambda state: state.has(VICTOIRE, self.player)

    # ---------- objets ----------
    def create_item(self, name: str) -> Item:
        o = self.PAR_NOM[name]
        return FNaFSBItem(name, CLASSE[o["classe"]], o["id"], self.player)

    @classmethod
    def stage_create_items(cls, multiworld):
        # Pass photo (sortie du depart) : chaque FNaF SB donne un emplacement de depart et les pass y sont melanges.
        # Avec 2 FNaF SB ou plus, un pass peut tomber au depart d'un autre (sphere 0, toujours atteignable) ;
        # jamais dans un autre jeu (sphere 1 pas fiable, voir DEBUT_LOCAL).
        mondes = sorted(multiworld.get_game_worlds(JEU), key=lambda w: w.player)
        places = [w.place_pass for w in mondes]
        multiworld.random.shuffle(places)
        for w, place in zip(mondes, places):
            place.place_locked_item(w.create_item(w._nom(PASS_DEPART)))

    def get_filler_item_name(self) -> str:
        bonus = [o[LANG] for o in OBJETS if o["genre"] == "bonus"]
        return self.random.choice(bonus)

    def create_items(self):
        # pass photo : un emplacement de depart tire au hasard, rempli dans stage_create_items (hors du tirage general)
        depart = [e for e in self._actifs() if e["zone"] == "depart"]
        self.place_pass = self.multiworld.get_location(self.random.choice(depart)[LANG], self.player)
        places = len(self._actifs()) - 1
        actifs = {e["cle"]: e for e in self._actifs()}
        solo = len(self.multiworld.player_ids) == 1
        retires = {}  # code -> copies deja placees hors du tirage
        for cle, code in VANILLA.items():
            if code == "badge" and not solo:
                continue  # multiworld : regle commune aux badges, plus bas
            if cle not in actifs:
                if code != "badge":
                    retires[code] = retires.get(code, 0) + 1  # emplacement desactive : le jeu le donne lui-meme
                continue
            nom = self._nom(code)
            # Billet d'entree : avant le portique du hall, le jeu n'a que 2 spots (sa place et la piñata de Chica du
            # couloir de sortie) ; toujours chez le joueur, sur l'un des deux (joueur 27/10)
            if code == "objet:CompPass":
                spots = [c for c in (cle, self.PINATA_SORTIE) if c in actifs]
                place = actifs[self.random.choice(spots)]
                self.multiworld.get_location(place[LANG], self.player).place_locked_item(self.create_item(nom))
                retires[code] = retires.get(code, 0) + 1
                places -= 1
                continue
            if solo:
                self.multiworld.get_location(actifs[cle][LANG], self.player).place_locked_item(self.create_item(nom))
                retires[code] = retires.get(code, 0) + 1
                places -= 1
            else:
                for e in self._actifs():
                    if e["cle"] != cle:
                        add_item_rule(self.multiworld.get_location(e[LANG], self.player),
                                      lambda item, nom=nom: not (item.player == self.player and item.name == nom))
        # Multiworld : nos badges progressifs partent dans n'importe quel jeu, mais s'ils restent dans le notre
        # ce n'est que sur un porte-badge (leur place dans le jeu de base ; 10 copies identiques). En solo, les
        # porte-badges de la cuisine et du bureau des prix en gardent un (sortie de la cuisine = niveau 2).
        if not solo:
            badge = self._nom("badge")
            for e in self._actifs():
                if "BadgeHolder" not in e["cle"]:
                    add_item_rule(self.multiworld.get_location(e[LANG], self.player),
                                  lambda item, badge=badge: not (item.player == self.player and item.name == badge))
        # Yeux de Roxy : installes sur Freddy, ils font passer a 6 h (fin du jeu ouverte) ; recus trop tot, le
        # joueur sautait Roxy et le reste (joueur 25/10). Places d'office dans ce monde, sur un emplacement
        # atteint seulement apres le combat (4 places : laisses au remplissage, ils restaient parfois sans place)
        apres = [e for e in self._actifs() if e.get("apres_roxy") and not e.get("exclu")]
        self.multiworld.get_location(self.random.choice(apres)[LANG], self.player).place_locked_item(
            self.create_item(self._nom("objet:RoxyEyes")))
        retires["objet:RoxyEyes"] = retires.get("objet:RoxyEyes", 0) + 1
        places -= 1
        pool = []
        for o in OBJETS:
            if (o["genre"] in ("progression", "utile") and o["code"] != PASS_DEPART and o["code"] not in HORS_AP.values()
                    and o["code"] not in JAMAIS):
                pool += [self.create_item(o[LANG]) for _ in range(o["nombre"] - retires.get(o["code"], 0))]
        # Remplissage : collectibles (les plus "cool" d'abord). Les messages ne sont jamais des objets : le
        # joueur garde le message qu'il ramasse (lore et messages perso toujours lisibles a leur place)
        remplissage = [o for o in OBJETS if o["genre"] == "collectible"]
        remplissage.sort(key=lambda o: (o.get("priorite", 6), self.random.random()))
        reste = places - len(pool)
        if reste < 0:
            raise Exception("%s : pas assez d'emplacements (%d) pour les objets de progression (%d)"
                            % (JEU, places, len(pool)))
        remplissage = remplissage[:reste]
        # Bonus et pieges remplacent les remplissages les moins interessants (fin de liste), 100 % au plus
        pb, pp = self.options.pourcent_bonus.value, self.options.pourcent_pieges.value
        if pb + pp > 100:
            pb, pp = pb * 100 / (pb + pp), pp * 100 / (pb + pp)
        manque = reste - len(remplissage)  # pas assez de remplissage : complete avec des bonus
        nb_pieges = math.floor(len(remplissage) * pp / 100)
        nb_bonus = math.floor(len(remplissage) * pb / 100)
        garde = len(remplissage) - nb_pieges - nb_bonus
        pool += [self.create_item(o[LANG]) for o in remplissage[:garde]]
        bonus = [o[LANG] for o in OBJETS if o["genre"] == "bonus"]
        pieges = [o[LANG] for o in OBJETS if o["genre"] == "piege"]
        # Pieges a parts egales entre les types (le reste au hasard)
        tirage = pieges * (nb_pieges // len(pieges)) + self.random.sample(pieges, nb_pieges % len(pieges))
        pool += [self.create_item(n) for n in tirage]
        pool += [self.create_item(self.random.choice(bonus)) for _ in range(nb_bonus + manque)]
        self.multiworld.itempool += pool

    # ---------- client ----------
    FINS = ["n_importe_laquelle", "LoadingDockEnding", "FazerblastEnding", "VIPEnding", "BurntrapEnding",
            "GregoryInAlleyEnding", "toutes"]

    def _garder(self):
        """Objets que le mod laisse au joueur quand il les ramasse : hors AP, jamais melanges, et objets de
        sortie restes a leur place dans cette seed (ou dont l'emplacement est desactive)."""
        codes = set(HORS_AP.values()) | JAMAIS
        actifs = {e["cle"]: e for e in self._actifs()}
        for cle, code in VANILLA.items():
            if code == "badge":
                continue
            if cle not in actifs:
                codes.add(code)
                continue
            item = self.multiworld.get_location(actifs[cle][LANG], self.player).item
            if item and item.player == self.player and item.name == self._nom(code):
                codes.add(code)
        return sorted(c.split(":", 1)[1] for c in codes)

    def fill_slot_data(self) -> Dict[str, Any]:
        o = self.options
        return {
            "langue": LANG,
            "fin": self.FINS[o.fin.value],
            "cadeaux": o.cadeaux.value,
            "messages": o.messages.value,
            "cd": o.cd.value,
            "duree_bornes": o.duree_bornes.value * 60,
            "duree_ralenti": o.duree_ralenti.value * 30,
            "duree_entrave": o.duree_entrave.value * 30,
            "duree_turbo": o.duree_turbo.value * 30,
            "vitesse_turbo": o.vitesse_turbo.value / 100,
            "vitesse_endurance": o.vitesse_endurance.value / 100,
            "death_link": bool(o.death_link.value),
            "mode_death_link": "screamer" if o.mode_death_link.value == 1 else "classique",
            "emplacements": {e["cle"]: e["id"] for e in self._actifs()},
            # ratables : ne comptent pas pour l'objectif de collectibles
            "hors_compte": [e["cle"] for e in EMPLACEMENTS if e.get("exclu")],
            "garder": self._garder(),
            "objets": {str(ob["id"]): ob["code"] for ob in OBJETS},
        }
