"""
Pont Archipelago <-> Five Nights at Freddy's Security Breach.

Le mod (UE4SS, Lua) n'a pas de connexion reseau : ce programme parle au serveur Archipelago et
echange avec le mod par deux fichiers texte (une commande par ligne, champs separes par des tabulations)
dans <jeu>/Binaries/Win64/ue4ss/ArchipelagoSB/ :
    vers_jeu.txt   ecrit ici, lu par le mod (client.lua)
    vers_pont.txt  ecrit par le mod, lu ici

Ce que le pont garde sur le serveur (stockage de donnees, cle par partie et par joueur) : fins faites,
emplacements ramasses par type (objectif de collectibles), bonus utilises, dernier piege vu.

    python pont_ap.py --serveur archipelago.gg:12345 --pseudo Gregory [--mdp ...] [--jeu "<dossier du jeu>"]
"""

import argparse
import asyncio
import json
import os
import random
import sys
import time

import websockets

JEU = "Five Nights at Freddy's Security Breach"
JEU_DEFAUT = r"D:\Steam\steamapps\common\Quarters\fnaf9\Binaries\Win64"

# Textes des pieges (un au hasard), references de la commu FNaF ; {j} = joueur qui a envoye le piege
TROLLS = {
    "fr": {
        "alerte": ["ALERTE : {j} a contacté le StaffBot !",
                   "{j} a signalé un enfant perdu. L'enfant perdu, c'est toi.",
                   "Vanny a reçu ta position. Merci {j} !",
                   "{j} a appuyé sur le gros bouton rouge. Il ne fallait pas.",
                   "Toutes les unités : {j} dit que tu te caches dans les conduits.",
                   "{j} a prévenu la sécurité. La sécurité, c'est Vanessa. Bonne chance."],
        "screamer": ["{j} t'a envoyé un ami...",
                     "{j} : « IT'S ME »",
                     "Livraison spéciale de la part de {j} : un câlin animatronique.",
                     "{j} t'a offert la formule anniversaire Mega Deluxe.",
                     "La morsure de 87 ? Non, juste un cadeau de {j}.",
                     "{j} a laissé la porte ouverte. Comme en 1993."],
        "bornes": ["{j} a renversé son Fizzy Faz sur les bornes de sauvegarde",
                   "{j} a débranché les bornes pour recharger son téléphone",
                   "Bornes de sauvegarde en pause syndicale (merci {j})",
                   "{j} a demandé à Dave de réparer les bornes. Dave est nul.",
                   "{j} a donné les bornes à manger à Chica"],
        "lampe": ["{j} t'a emprunté tes piles",
                  "« Économise ta batterie », disait le Phone Guy. {j} ne l'a pas écouté.",
                  "{j} a mis tes piles dans un Lil' Music Man",
                  "{j} : « Il fait noir, hein ? »",
                  "Plus de jus : {j} a branché une Fazwatch de plus"],
    },
    "en": {
        "alerte": ["ALERT: {j} called the StaffBot!",
                   "{j} reported a lost child. The lost child is you.",
                   "Vanny just got your location. Thanks {j}!",
                   "{j} pressed the big red button. They shouldn't have.",
                   "All units: {j} says you're hiding in the vents.",
                   "{j} called security. Security is Vanessa. Good luck."],
        "screamer": ["{j} sent you a friend...",
                     "{j}: \"IT'S ME\"",
                     "Special delivery from {j}: one animatronic hug.",
                     "{j} booked you the Mega Deluxe Party Package.",
                     "The Bite of '87? No, just a gift from {j}.",
                     "{j} left the door open. Like it's 1993."],
        "bornes": ["{j} spilled their Fizzy Faz on the save stations",
                   "{j} unplugged the save stations to charge their phone",
                   "Save stations are on a union break (thanks {j})",
                   "{j} asked Dave to fix the save stations. Dave sucks.",
                   "{j} fed the save stations to Chica"],
        "lampe": ["{j} borrowed your batteries",
                  "\"Conserve your power,\" said Phone Guy. {j} didn't listen.",
                  "{j} put your batteries in a Lil' Music Man",
                  "{j}: \"Dark in here, isn't it?\"",
                  "Out of juice: {j} plugged in one more Fazwatch"],
    },
}


def log(*a):
    print("[pont]", *a, flush=True)


class Pont:
    def __init__(self, serveur, pseudo, mdp, jeu):
        self.uri = serveur if "://" in serveur else "ws://" + serveur
        self.pseudo, self.mdp = pseudo, mdp
        self.dossier = os.path.join(jeu, "ue4ss", "ArchipelagoSB")
        os.makedirs(self.dossier, exist_ok=True)
        self.entree = os.path.join(self.dossier, "vers_pont.txt")
        self.sortie = os.path.join(self.dossier, "vers_jeu.txt")
        for f in (self.entree, self.sortie):
            open(f, "w", encoding="utf-8").close()
        self.position = 0
        self.ws = None
        self.slot = None
        self.slot_data = {}
        self.joueurs = {}
        self.noms_objets = {}       # jeu -> id -> nom
        self.objets = []            # tous les objets recus (dans l'ordre du serveur)
        self.faits = set()
        self.contenus = {}          # cle d'emplacement -> (objet, joueur ou "" si moi, code de notre jeu)
        self.etat = {"fins": [], "ramasses": {}, "bonus": {}, "dernier_piege": -1}
        self.cle_etat = None
        self.mort_envoyee = 0
        self.mort_recue = 0
        self.gagne = False
        self.session_faite = False

    # ---------- fichiers d'echange ----------
    def vers_jeu(self, *champs):
        with open(self.sortie, "a", encoding="utf-8") as f:
            f.write("\t".join(str(c).replace("\t", " ").replace("\n", " ") for c in champs) + "\n")

    def lire_jeu(self):
        try:
            taille = os.path.getsize(self.entree)
        except OSError:
            return []
        if taille < self.position:
            self.position = 0
        if taille == self.position:
            return []
        with open(self.entree, encoding="utf-8", errors="replace") as f:
            f.seek(self.position)
            bloc = f.read()
        fin = bloc.rfind("\n")
        if fin < 0:
            return []
        self.position += len(bloc[:fin + 1].encode("utf-8"))
        return [l.split("\t") for l in bloc[:fin].split("\n") if l.strip()]

    # ---------- reseau ----------
    async def envoyer(self, *paquets):
        await self.ws.send(json.dumps(list(paquets)))

    def nom_objet(self, jeu, id_):
        return self.noms_objets.get(jeu, {}).get(id_, "objet %s" % id_)

    def langue(self):
        return self.slot_data.get("langue", "fr")

    async def sauver_etat(self):
        if not self.cle_etat or self.ws is None:
            return
        await self.envoyer({"cmd": "Set", "key": self.cle_etat, "default": {}, "want_reply": False,
                            "operations": [{"operation": "replace", "value": self.etat}]})

    async def connecter(self):
        async with websockets.connect(self.uri, max_size=None, ping_interval=None) as ws:
            self.ws = ws
            log("connexion a", self.uri)
            await self.envoyer({"cmd": "GetDataPackage"})
            await self.envoyer({
                "cmd": "Connect", "password": self.mdp, "game": JEU, "name": self.pseudo,
                "uuid": "fnafsb-pont-%d" % random.randint(0, 1 << 30),
                "version": {"major": 0, "minor": 6, "build": 0, "class": "Version"},
                "items_handling": 0b111, "tags": [], "slot_data": True})
            await asyncio.gather(self.ecouter(), self.boucle_jeu())

    async def ecouter(self):
        async for message in self.ws:
            for p in json.loads(message):
                try:
                    await self.paquet(p)
                except Exception as e:
                    log("erreur paquet", p.get("cmd"), e)

    async def paquet(self, p):
        cmd = p.get("cmd")
        if cmd == "RoomInfo":
            self.seed = p.get("seed_name", "")
        elif cmd == "DataPackage":
            for jeu, d in p["data"]["games"].items():
                self.noms_objets[jeu] = {v: k for k, v in d["item_name_to_id"].items()}
        elif cmd == "ConnectionRefused":
            log("connexion refusee :", p.get("errors"))
            raise SystemExit(1)
        elif cmd == "Connected":
            self.slot = p["slot"]
            self.session_faite = False
            # le serveur renvoie la liste complete juste apres ; sans ca, une room remise a zero gardait les
            # objets de la connexion d'avant
            self.objets = []
            self.slot_data = p.get("slot_data") or {}
            self.joueurs = {j["slot"]: j["alias"] for j in p.get("players", [])}
            self.infos_slots = p.get("slot_info", {})
            self.faits = set(p.get("checked_locations", []))
            self.cle_etat = "fnafsb_%s_%d" % (getattr(self, "seed", "") or self.pseudo, self.slot)
            if self.slot_data.get("death_link"):
                await self.envoyer({"cmd": "ConnectUpdate", "tags": ["DeathLink"]})
            await self.envoyer({"cmd": "Get", "keys": [self.cle_etat]})
            # contenu de nos emplacements : la fenetre de ramassage du jeu affiche le vrai objet tout de suite
            ids = [int(i) for i in self.slot_data.get("emplacements", {}).values()]
            if ids:
                await self.envoyer({"cmd": "LocationScouts", "locations": ids, "create_as_hint": 0})
            log("connecte, joueur", self.slot, "-", len(self.faits), "emplacements deja faits")
        elif cmd == "Retrieved":
            v = p.get("keys", {}).get(self.cle_etat)
            if isinstance(v, dict):
                self.etat.update(v)
            self.session()
        elif cmd == "ReceivedItems":
            debut, nouveaux = p["index"], p["items"]
            # Le premier paquet apres la connexion est la liste complete ; les suivants arrivent en direct
            # (meme a l'index 0 si on n'avait encore rien recu)
            if not self.session_faite:
                self.objets = list(nouveaux) if debut == 0 else self.objets + list(nouveaux)
                return
            while len(self.objets) < debut:
                self.objets.append(None)
            self.objets[debut:debut + len(nouveaux)] = nouveaux
            for i, it in enumerate(nouveaux):
                await self.objet_recu(debut + i, it, en_direct=True)
            await self.sauver_etat()
        elif cmd == "LocationInfo":
            inverse = {v: k for k, v in self.slot_data.get("emplacements", {}).items()}
            for it in p.get("locations", []):
                cle = inverse.get(it["location"])
                if cle is None:
                    continue
                moi = it["player"] == self.slot
                nom = self.nom_objet(self.slot_info_jeu(it["player"]), it["item"])
                qui = "" if moi else self.joueurs.get(it["player"], "?")
                code = self.slot_data.get("objets", {}).get(str(it["item"]), "") if moi else ""
                self.contenus[cle] = (nom, qui, code)
                self.vers_jeu("contenu", cle, nom, qui, code)
        elif cmd == "PrintJSON" and p.get("type") == "ItemSend":
            it = p["item"]
            # Envoye a un autre joueur depuis un de mes emplacements
            if it["player"] == self.slot and p.get("receiving") != self.slot:
                jeu_dest = self.slot_info_jeu(p.get("receiving"))
                nom = self.nom_objet(jeu_dest, it["item"])
                qui = self.joueurs.get(p.get("receiving"), "?")
                self.vers_jeu("envoye", nom, qui)
        elif cmd == "Bounced" and "DeathLink" in p.get("tags", []):
            d = p.get("data", {})
            if d.get("source") != self.pseudo and time.time() - self.mort_envoyee > 5:
                self.mort_recue = time.time()
                qui = d.get("source", "?")
                texte = ("%s died: you go with them!" if self.langue() == "en" else "%s est mort : tu le suis !") % qui
                self.vers_jeu("deathlink", self.slot_data.get("mode_death_link", "classique"), texte)
        elif cmd == "RoomUpdate":
            for l in p.get("checked_locations", []):
                self.faits.add(l)

    def slot_info_jeu(self, slot):
        return getattr(self, "infos_slots", {}).get(str(slot), {}).get("game", "")

    # ---------- session avec le jeu ----------
    def code_objet(self, it):
        return self.slot_data.get("objets", {}).get(str(it["item"]))

    def session(self):
        sd = self.slot_data
        self.vers_jeu("session", self.langue(), sd.get("duree_bornes", 300), sd.get("mode_death_link", "classique"),
                      1 if sd.get("death_link") else 0)
        # objets que le mod laisse au joueur au ramassage (hors AP, objets de sortie restes a leur place)
        self.vers_jeu("garder", *sd.get("garder", []))
        for cle, (nom, qui, code) in self.contenus.items():
            self.vers_jeu("contenu", cle, nom, qui, code)
        inverse = {v: k for k, v in sd.get("emplacements", {}).items()}
        for l in self.faits:
            if l in inverse:
                self.vers_jeu("fait", inverse[l])
        bonus_recus = {}
        pieges_hors_ligne = []
        for i, it in enumerate(self.objets):
            if it is None:
                continue
            code = self.code_objet(it) or ""
            if code.startswith("bonus:"):
                bonus_recus[code[6:]] = bonus_recus.get(code[6:], 0) + 1
            elif code.startswith("piege:"):
                if i > self.etat["dernier_piege"]:
                    pieges_hors_ligne.append((i, code[6:], it))
            else:
                de = self.joueurs.get(it["player"], "") if it["player"] != self.slot else ""
                self.vers_jeu("objet", i, code, de, self.nom_objet(JEU, it["item"]), 0)
        for id_, n in bonus_recus.items():
            self.vers_jeu("bonus", id_, max(0, n - self.etat["bonus"].get(id_, 0)))
        for i, type_, it in pieges_hors_ligne:
            self.vers_jeu("piege", type_, 1, self.texte_piege(type_, it))
            self.etat["dernier_piege"] = max(self.etat["dernier_piege"], i)
        self.envoyer_objectif()
        if self.etat.get("bienvenue"):
            self.vers_jeu("bienvenue_vue")
        self.vers_jeu("pret")
        self.session_faite = True
        log("session envoyee au jeu :", len(self.objets), "objets,", len(pieges_hors_ligne), "pieges hors ligne")
        asyncio.ensure_future(self.sauver_etat())

    def texte_piege(self, type_, it):
        modeles = TROLLS.get(self.langue(), TROLLS["fr"]).get(type_)
        return random.choice(modeles).format(j=self.joueurs.get(it["player"], "?")) if modeles else ""

    async def objet_recu(self, index, it, en_direct):
        code = self.code_objet(it) or ""
        de = self.joueurs.get(it["player"], "") if it["player"] != self.slot else ""
        if code.startswith("piege:"):
            if index > self.etat["dernier_piege"]:
                self.vers_jeu("piege", code[6:], 0, self.texte_piege(code[6:], it))
                self.etat["dernier_piege"] = index
        elif code.startswith("bonus:"):
            id_ = code[6:]
            recus = sum(1 for x in self.objets if x and self.code_objet(x) == code)
            self.vers_jeu("bonus", id_, max(0, recus - self.etat["bonus"].get(id_, 0)))
            self.vers_jeu("recu", self.nom_objet(JEU, it["item"]), de)
        else:
            self.vers_jeu("objet", index, code, de, self.nom_objet(JEU, it["item"]), 1)

    # ---------- evenements du jeu ----------
    async def boucle_jeu(self):
        while True:
            for c in self.lire_jeu():
                try:
                    await self.evenement(c)
                except Exception as e:
                    log("erreur evenement", c, e)
            await asyncio.sleep(0.3)

    async def evenement(self, c):
        cmd = c[0]
        if cmd == "bonjour":
            if self.slot is not None and self.cle_etat:
                log("le jeu vient de demarrer : session renvoyee")
                self.session()
        elif cmd == "check":
            cle, genre = c[1], (c[2] if len(c) > 2 else "")
            r = self.etat["ramasses"].setdefault(genre, [])
            if cle not in r:
                r.append(cle)
                await self.sauver_etat()
            id_ = self.slot_data.get("emplacements", {}).get(cle)
            if id_ is not None and id_ not in self.faits:
                self.faits.add(id_)
                await self.envoyer({"cmd": "LocationChecks", "locations": [id_]})
                log("check envoye :", cle)
            await self.verifier_objectif()
        elif cmd == "fin":
            if c[1] not in self.etat["fins"]:
                self.etat["fins"].append(c[1])
                await self.sauver_etat()
            log("fin faite :", c[1])
            await self.verifier_objectif()
        elif cmd == "bonus":
            self.etat["bonus"][c[1]] = self.etat["bonus"].get(c[1], 0) + 1
            await self.sauver_etat()
        elif cmd == "bienvenue":
            # carte de bienvenue montree : plus jamais pour cette partie (memorise sur le serveur)
            self.etat["bienvenue"] = True
            await self.sauver_etat()
        elif cmd == "mort":
            if self.slot_data.get("death_link") and time.time() - self.mort_recue > 15:
                self.mort_envoyee = time.time()
                await self.envoyer({"cmd": "Bounce", "tags": ["DeathLink"],
                                    "data": {"time": time.time(), "source": self.pseudo,
                                             "cause": "%s s'est fait attraper au Pizzaplex" % self.pseudo}})
                log("DeathLink envoye")

    def compte(self, genre):
        # ramasses de ce type, sans les ratables (amelioration de lampe de la garderie, apres Moon) ;
        # repli pour les seeds generees avant que le slot_data les donne
        hors = set(self.slot_data.get("hors_compte", ["MAP_Daycare_Gameplay:PresentCollectible3_5"]))
        return len([c for c in self.etat["ramasses"].get(genre, []) if c not in hors])

    def envoyer_objectif(self):
        # Pour la carte de bienvenue du jeu : fin demandee, fins faites, compteurs faits / exiges
        sd = self.slot_data
        champs = [self.pseudo, getattr(self, "seed", ""), sd.get("fin", "n_importe_laquelle"), ",".join(self.etat["fins"])]
        for genre, cle in (("cadeau", "cadeaux"), ("message", "messages"), ("cd", "cd")):
            champs += [self.compte(genre), sd.get(cle, 0)]
        self.vers_jeu("objectif", *champs)

    async def verifier_objectif(self):
        self.envoyer_objectif()
        if self.gagne:
            return
        sd = self.slot_data
        fin = sd.get("fin", "n_importe_laquelle")
        fins = self.etat["fins"]
        principales = ["LoadingDockEnding", "FazerblastEnding", "VIPEnding", "BurntrapEnding", "GregoryInAlleyEnding"]
        if fin == "n_importe_laquelle":
            fin_ok = len(fins) > 0
        elif fin == "toutes":
            fin_ok = all(f in fins for f in principales)
        else:
            fin_ok = fin in fins
        compteurs_ok = all(self.compte(genre) >= sd.get(cle, 0)
                           for genre, cle in (("cadeau", "cadeaux"), ("message", "messages"), ("cd", "cd")))
        if fin_ok and compteurs_ok:
            self.gagne = True
            await self.envoyer({"cmd": "StatusUpdate", "status": 30})
            # carte du goal dans le jeu, une seule fois par partie (memorise sur le serveur)
            if not self.etat.get("goal_vu"):
                self.etat["goal_vu"] = True
                await self.sauver_etat()
                self.vers_jeu("goal")
            log("OBJECTIF ATTEINT")
        elif fin_ok:
            manque = []
            for genre, cle in (("cadeau", "cadeaux"), ("message", "messages"), ("cd", "cd")):
                n = sd.get(cle, 0) - self.compte(genre)
                if n > 0:
                    manque.append("%d %s" % (n, cle))
            self.vers_jeu("affiche", ("Fin faite ! Il manque : " if self.langue() == "fr" else "Ending done! Still missing: ")
                          + ", ".join(manque))


def tourner(serveur, pseudo, mdp, jeu, arret):
    """Pour le launcher : fait tourner le pont dans un fil jusqu'a arret (threading.Event),
    avec reconnexion automatique. Le journal passe par log() (remplacable par le launcher)."""
    pont = Pont(serveur, pseudo, mdp or None, jeu)

    async def session():
        tache = asyncio.ensure_future(pont.connecter())
        while not arret.is_set() and not tache.done():
            await asyncio.sleep(0.5)
        if not tache.done():
            tache.cancel()
            try:
                await tache
            except asyncio.CancelledError:
                pass
        else:
            tache.result()   # remonte l'erreur de connexion

    while not arret.is_set():
        try:
            asyncio.run(session())
        except Exception as e:
            if arret.is_set():
                break
            log("deconnecte (%s), nouvel essai dans 5 s" % e)
            arret.wait(5)
    log("pont arrete")


def auto(win64):
    """Pont lancé tout seul par le mod au démarrage du jeu (FNaF_SB_AP_Pont.exe, sans fenêtre) : lit la room
    enregistrée par le launcher (ue4ss/ArchipelagoSB/connection.json), écrit son journal dans pont.log,
    s'arrête quand le jeu est fermé ou quand la room est effacée. Un seul pont à la fois."""
    import ctypes
    import threading
    dossier = os.path.join(win64, "ue4ss", "ArchipelagoSB")
    connexion = os.path.join(dossier, "connection.json")
    ctypes.windll.kernel32.CreateMutexW(None, False, "FNaF_SB_AP_Pont")
    if ctypes.windll.kernel32.GetLastError() == 183:   # ERROR_ALREADY_EXISTS : un pont tourne déjà
        return
    global log
    journal = open(os.path.join(dossier, "pont.log"), "a", encoding="utf-8")

    def log(*a):
        journal.write(time.strftime("%Y-%m-%d %H:%M:%S ") + " ".join(str(x) for x in a) + "\n")
        journal.flush()
    try:
        with open(connexion, encoding="utf-8") as f:
            c = json.load(f)
    except (OSError, ValueError):
        log("aucune room enregistree")
        return
    arret = threading.Event()

    # Liste des processus lue directement dans Windows (Toolhelp32). L'ancienne version lançait tasklist
    # toutes les 5 s : un processus de plus à chaque fois, analysé par l'antivirus -> freeze du jeu toutes
    # les 5 s.
    from ctypes import wintypes

    class PROCESSENTRY32W(ctypes.Structure):
        _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                    ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
                    ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                    ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", ctypes.c_long),
                    ("dwFlags", wintypes.DWORD), ("szExeFile", ctypes.c_wchar * 260)]

    k32 = ctypes.windll.kernel32
    k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE

    def jeu_lance():
        cliche = k32.CreateToolhelp32Snapshot(0x2, 0)   # TH32CS_SNAPPROCESS
        if not cliche or cliche == wintypes.HANDLE(-1).value:
            return True
        try:
            e = PROCESSENTRY32W()
            e.dwSize = ctypes.sizeof(PROCESSENTRY32W)
            ok = k32.Process32FirstW(cliche, ctypes.byref(e))
            while ok:
                if e.szExeFile.lower() == "fnaf9-win64-shipping.exe":
                    return True
                ok = k32.Process32NextW(cliche, ctypes.byref(e))
            return False
        finally:
            k32.CloseHandle(cliche)

    def surveiller():
        debut, absent = time.time(), 0
        while not arret.is_set():
            arret.wait(5)
            if not os.path.exists(connexion):
                log("room effacee : arret")
                arret.set()
            absent = 0 if jeu_lance() else absent + 1
            if absent >= 2 and time.time() - debut > 60:
                log("jeu ferme : arret")
                arret.set()
    threading.Thread(target=surveiller, daemon=True).start()
    log("pont automatique :", c.get("slot"), "sur", c.get("uri"))
    tourner(c["uri"], c["slot"], c.get("password", ""), win64, arret)


def main():
    a = argparse.ArgumentParser(description="Pont Archipelago pour FNaF Security Breach")
    a.add_argument("--serveur", default=None)
    a.add_argument("--pseudo", default=None)
    a.add_argument("--mdp", default="")
    a.add_argument("--jeu", default=JEU_DEFAUT, help="dossier fnaf9/Binaries/Win64")
    args = a.parse_args()
    serveur = args.serveur or input("Serveur (ex. archipelago.gg:38281) : ").strip()
    pseudo = args.pseudo or input("Pseudo : ").strip()
    pont = Pont(serveur, pseudo, args.mdp or None, args.jeu)
    while True:
        try:
            asyncio.run(pont.connecter())
        except SystemExit:
            raise
        except Exception as e:
            log("deconnecte (%s), nouvel essai dans 5 s" % e)
            time.sleep(5)


if __name__ == "__main__":
    main()
