"""
Cœur du launcher (sans fenêtre) : recherche des dossiers, installation / désinstallation d'UE4SS et
du mod, état de l'installation, mise à jour depuis GitHub, lancement du jeu, rapport de bug.
Repris du launcher de RE Village (2026-10-22) et adapté à Security Breach (Unreal Engine 4.27, UE4SS).

Fichiers lus dans le dossier "files" posé à côté du launcher (voir make_release.py) :
  files/ue4ss/...              -> <jeu>/fnaf9/Binaries/Win64/ (dwmapi.dll, ue4ss/UE4SS.dll, réglages, shared...)
  files/mod/ArchipelagoSB/...  -> <jeu>/fnaf9/Binaries/Win64/ue4ss/Mods/ArchipelagoSB/
  files/apworld/fr|en/fnafsb.apworld -> <Archipelago>/custom_worlds/ (langue choisie)
  files/version.json           -> {"version": "..."}
  files/options.json           -> options de l'apworld (écran « Mes options »)
Tout fichier du jeu remplacé est d'abord copié en <nom>.avant_archipelago et remis à la désinstallation.
La liste (fichiers posés, copies, ligne ajoutée à mods.txt) est gardée dans ue4ss/archipelago_sb_install.json.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import time
import winreg
import zipfile
from pathlib import Path

GAME_FOLDER = "Quarters"            # nom du dossier Steam de Security Breach
STEAM_APP_ID = 747660
WIN64 = Path("fnaf9") / "Binaries" / "Win64"
EXE = "fnaf9-Win64-Shipping.exe"
MANIFEST = "ue4ss/archipelago_sb_install.json"      # relatif à Win64
MOD_LINE = "ArchipelagoSB : 1"
SETTINGS_INI = "ue4ss/UE4SS-settings.ini"           # posé seulement s'il n'existe pas (réglages du joueur gardés)
BACKUP_SUFFIX = ".avant_archipelago"
APWORLD = "fnafsb.apworld"
EXE_NAME = "FNaF_SB_AP_Launcher"


def base_dir():
    return Path(sys.executable).parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent


def resource(name):
    """Fichier embarqué dans l'exe (PyInstaller) ou dans assets/ en développement."""
    if getattr(sys, "frozen", False):
        return Path(sys._MEIPASS) / name
    return Path(__file__).resolve().parent / "assets" / name


FILES = base_dir() / "files"
SETTINGS_DIR = Path(os.environ.get("APPDATA", str(Path.home()))) / "FNaF SB Archipelago"
SETTINGS_FILE = SETTINGS_DIR / "settings.json"
LOG_FILE = SETTINGS_DIR / "launcher.log"


def is_french():
    try:
        import locale
        return (locale.getlocale()[0] or locale.getdefaultlocale()[0] or "").lower().startswith(("fr", "french"))
    except (ValueError, TypeError):
        return False


FR = is_french()
APWORLD_LANG = "fr" if FR else "en"


def tr(fr, en):
    return fr if FR else en


def log_line(msg):
    try:
        SETTINGS_DIR.mkdir(parents=True, exist_ok=True)
        if LOG_FILE.exists() and LOG_FILE.stat().st_size > 2 << 20:
            LOG_FILE.replace(LOG_FILE.with_suffix(".old.log"))
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + str(msg) + "\n")
    except OSError:
        pass


def load_settings():
    try:
        return json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_settings(settings):
    SETTINGS_DIR.mkdir(parents=True, exist_ok=True)
    SETTINGS_FILE.write_text(json.dumps(settings, indent=1, ensure_ascii=False), encoding="utf-8")


def bundled_version():
    try:
        return json.loads((FILES / "version.json").read_text(encoding="utf-8"))["version"]
    except (OSError, ValueError, KeyError):
        return "dev"


# --- Mise à jour depuis GitHub (même principe que RE Village) ----------------------------------

GITHUB_REPO = "Snokay/Archipelago-FNAF-SB"


def version_tuple(text):
    return tuple(int(n) for n in re.findall(r"\d+", text or "")[:4]) or (0,)


def check_update():
    """(version, url du _launcher.zip, page de la release) si une version plus récente existe, sinon None."""
    import urllib.request
    req = urllib.request.Request(f"https://api.github.com/repos/{GITHUB_REPO}/releases?per_page=10",
                                 headers={"User-Agent": "FNaF-SB-AP-Launcher", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=10) as r:
        releases = json.loads(r.read().decode())
    current = version_tuple(bundled_version())
    best = None
    for rel in releases:
        if rel.get("draft"):
            continue
        asset = next((a for a in rel.get("assets", []) if a["name"].endswith("_launcher.zip")), None)
        version = re.sub(r"^v|-.*$", "", rel.get("tag_name", ""))
        if asset and version_tuple(version) > current and (best is None or version_tuple(version) > version_tuple(best[0])):
            best = (version, asset["browser_download_url"], rel.get("html_url"))
    return best


def apply_update(url, game_dir, ap_dir, log):
    """Télécharge et installe la mise à jour. Renvoie le script de remplacement de l'exe (lancé après
    la fermeture du launcher : un exe ne peut pas se remplacer lui-même), ou None hors exe."""
    import urllib.request
    if game_running():
        raise RuntimeError(tr("Le jeu est lancé : ferme-le avant de mettre à jour", "The game is running: close it first"))
    work = SETTINGS_DIR / "update"
    if work.exists():
        shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    archive = work / "update.zip"
    log(tr("Téléchargement de la mise à jour…", "Downloading the update…"))
    req = urllib.request.Request(url, headers={"User-Agent": "FNaF-SB-AP-Launcher"})
    with urllib.request.urlopen(req, timeout=120) as r, archive.open("wb") as f:
        shutil.copyfileobj(r, f)
    with zipfile.ZipFile(archive) as z:
        z.extractall(work / "new")
    roots = [p for p in (work / "new").iterdir() if p.is_dir()]
    new_root = roots[0] if roots else work / "new"
    if not (new_root / "files").exists():
        raise RuntimeError(tr("Archive de mise à jour invalide", "Invalid update archive"))
    old_files = base_dir() / "files"
    if old_files.exists():
        shutil.rmtree(old_files)
    shutil.copytree(new_root / "files", old_files)
    log(tr(f"Fichiers du mod mis à jour ({bundled_version()})", f"Mod files updated ({bundled_version()})"))
    if game_dir and read_manifest(game_dir) is not None:
        install(game_dir, ap_dir, log)
    new_exe = new_root / f"{EXE_NAME}.exe"
    if not getattr(sys, "frozen", False) or not new_exe.exists():
        return None
    target = base_dir() / f"{EXE_NAME}.exe"
    staged = base_dir() / f"{EXE_NAME}.update.exe"
    shutil.copy2(new_exe, staged)
    script = work / "swap.bat"
    script.write_text(
        "@echo off\r\n"
        ":wait\r\ntimeout /t 1 /nobreak >nul\r\n"
        f"tasklist /FI \"PID eq {os.getpid()}\" | find \"{os.getpid()}\" >nul && goto wait\r\n"
        f"move /Y \"{staged}\" \"{target}\" >nul\r\n"
        f"start \"\" \"{target}\"\r\n", encoding="utf-8")
    return script


def run_detached(script):
    subprocess.Popen(["cmd", "/c", str(script)], creationflags=0x08000000 | 0x00000008, close_fds=True)


# --- Recherche des dossiers -------------------------------------------------------------------

def reg_value(root, key, name):
    try:
        with winreg.OpenKey(root, key) as k:
            return winreg.QueryValueEx(k, name)[0]
    except OSError:
        return None


def win64(game_dir):
    return Path(game_dir) / WIN64


def find_game_dir():
    steam = reg_value(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam", "SteamPath")
    libraries = []
    if steam:
        libraries.append(Path(steam))
        vdf = Path(steam) / "steamapps" / "libraryfolders.vdf"
        if vdf.exists():
            for path in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(encoding="utf-8", errors="replace")):
                libraries.append(Path(path.replace("\\\\", "\\")))
    for lib in libraries:
        candidate = lib / "steamapps" / "common" / GAME_FOLDER
        if (win64(candidate) / EXE).exists():
            return candidate
    return None


def find_archipelago_dir():
    for root in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
        for view in (0, winreg.KEY_WOW64_32KEY):
            try:
                base = winreg.OpenKey(root, r"Software\Microsoft\Windows\CurrentVersion\Uninstall", 0,
                                      winreg.KEY_READ | view)
            except OSError:
                continue
            with base:
                for i in range(winreg.QueryInfoKey(base)[0]):
                    try:
                        with winreg.OpenKey(base, winreg.EnumKey(base, i)) as k:
                            name = winreg.QueryValueEx(k, "DisplayName")[0]
                            if str(name).startswith("Archipelago"):
                                location = Path(winreg.QueryValueEx(k, "InstallLocation")[0])
                                if (location / "ArchipelagoLauncher.exe").exists():
                                    return location
                    except OSError:
                        continue
    for candidate in (Path(r"C:\ProgramData\Archipelago"), Path(r"C:\Archipelago"), Path(r"D:\Archipelago")):
        if (candidate / "ArchipelagoLauncher.exe").exists():
            return candidate
    return None


def _process(name):
    try:
        out = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {name}", "/NH"], capture_output=True,
                             text=True, creationflags=0x08000000).stdout
        return name.lower() in out.lower()
    except OSError:
        return False


def game_running():
    return _process(EXE)


def crash_reporter_open():
    """Fenêtre de rapport de plantage d'Unreal restée ouverte après un crash : elle garde les fichiers
    du jeu ouverts (installation refusée par Windows, erreur 1224)."""
    return _process("CrashReportClient.exe")


# --- État -------------------------------------------------------------------------------------

def read_manifest(game_dir):
    try:
        return json.loads((win64(game_dir) / MANIFEST).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def mods_txt(game_dir):
    return win64(game_dir) / "ue4ss" / "Mods" / "mods.txt"


def other_mods(game_dir):
    """Mods UE4SS actifs qui ne sont pas les nôtres (conflits possibles)."""
    ours = {"ArchipelagoSB", "Keybinds"}
    path = mods_txt(game_dir)
    if not path.exists():
        return []
    found = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"\s*([^;:\s][^:]*?)\s*:\s*1\s*$", line)
        if m and m.group(1) not in ours:
            found.append(m.group(1))
    return found


def status(game_dir, ap_dir):
    """Liste de (clé, niveau, texte) : niveau = "ok", "warn" ou "bad"."""
    rows = []
    game_ok = bool(game_dir) and (win64(game_dir) / EXE).exists()
    rows.append(("game", "ok" if game_ok else "bad",
                 tr("Security Breach trouvé", "Security Breach found") if game_ok else
                 tr("Jeu introuvable : choisis le dossier « Quarters » du jeu",
                    "Game not found: pick the game's \"Quarters\" folder")))
    if not game_ok:
        return rows
    ue4ss = (win64(game_dir) / "ue4ss" / "UE4SS.dll").exists() and (win64(game_dir) / "dwmapi.dll").exists()
    rows.append(("ue4ss", "ok" if ue4ss else "warn",
                 tr("Présent", "Present") if ue4ss else tr("Absent : installé avec le mod", "Missing: installed with the mod")))
    manifest = read_manifest(game_dir)
    current = bundled_version()
    if manifest is None:
        rows.append(("mod", "bad", tr("Pas installé", "Not installed")))
    else:
        installed = manifest.get("version", "?")
        missing = [f for f in manifest.get("files", []) if not (win64(game_dir) / f).exists()]
        if missing:
            rows.append(("mod", "bad", tr(f"Installé ({installed}) mais {len(missing)} fichier(s) manquant(s) : réinstalle",
                                          f"Installed ({installed}) but {len(missing)} file(s) missing: reinstall")))
        elif installed != current:
            rows.append(("mod", "warn", tr(f"Version {installed} installée, {current} disponible : mets à jour",
                                           f"Version {installed} installed, {current} available: update")))
        else:
            rows.append(("mod", "ok", tr(f"Version {installed}", f"Version {installed}")))
    others = other_mods(game_dir)
    rows.append(("others", "warn" if others else "ok",
                 tr(f"{len(others)} autre(s) mod(s) UE4SS actif(s) : {', '.join(others[:4])}"
                    f"{' …' if len(others) > 4 else ''} — en cas de plantage, désactive-les dans ue4ss/Mods/mods.txt",
                    f"{len(others)} other active UE4SS mod(s): {', '.join(others[:4])}"
                    f"{' …' if len(others) > 4 else ''} — if the game crashes, turn them off in ue4ss/Mods/mods.txt")
                 if others else tr("Aucun", "None")))
    if ap_dir and (ap_dir / "ArchipelagoLauncher.exe").exists():
        world = ap_dir / "custom_worlds" / APWORLD
        lang = apworld_lang(world)
        rows.append(("apworld", "ok" if world.exists() else "warn",
                     tr(f"Installé dans Archipelago ({lang.upper()})", f"Installed in Archipelago ({lang.upper()})")
                     if world.exists() else
                     tr("Pas installé (utile seulement pour héberger / générer)",
                        "Not installed (only needed to host / generate)")))
    else:
        rows.append(("apworld", "warn", tr("Archipelago non trouvé (utile seulement pour héberger / générer)",
                                           "Archipelago not found (only needed to host / generate)")))
    return rows


# --- Installation -----------------------------------------------------------------------------

def _copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.copy2(src, dst)
    except OSError as e:
        if not isinstance(e, PermissionError) and getattr(e, "winerror", None) not in (32, 33, 1224):
            raise
        raise RuntimeError(tr("Fichier du jeu encore ouvert : ferme le jeu et sa fenêtre de rapport de plantage "
                              "(CrashReportClient), puis relance l'installation",
                              "Game file still open: close the game and its crash report window "
                              "(CrashReportClient), then run the install again"))


def _add_mod_line(game_dir):
    """Active le mod dans mods.txt (avant Keybinds, que UE4SS veut en dernier). Vrai si mods.txt a été créé."""
    path = mods_txt(game_dir)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"{MOD_LINE}\n\n; Built-in keybinds, do not move up!\nKeybinds : 1\n", encoding="utf-8")
        return True
    lines = [l for l in path.read_text(encoding="utf-8", errors="replace").splitlines()
             if not re.match(r"\s*ArchipelagoSB\s*:", l)]
    at = next((i for i, l in enumerate(lines) if re.match(r"\s*(;.*keybinds|Keybinds\s*:)", l, re.I)), len(lines))
    lines.insert(at, MOD_LINE)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return False


def _remove_mod_line(game_dir, created):
    path = mods_txt(game_dir)
    if not path.exists():
        return
    if created:
        path.unlink()
        return
    lines = [l for l in path.read_text(encoding="utf-8", errors="replace").splitlines()
             if not re.match(r"\s*ArchipelagoSB\s*:", l)]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# Le moteur coupe ses sons quand la fenêtre perd le focus (Wwise non) : la musique du concert jouée par le
# mod se coupait en Alt+Tab alors que le reste du jeu continuait. Bloc entre repères, retiré à la
# désinstallation.
ENGINE_INI = Path(os.environ.get("LOCALAPPDATA", "")) / "fnaf9" / "Saved" / "Config" / "WindowsNoEditor" / "Engine.ini"
INI_DEBUT, INI_FIN = "; archipelago_sb debut", "; archipelago_sb fin"
INI_BLOC = f"\n{INI_DEBUT}\n[Audio]\nUnfocusedVolumeMultiplier=1.0\n{INI_FIN}\n"


def _add_engine_ini():
    try:
        texte = ENGINE_INI.read_text(encoding="utf-8") if ENGINE_INI.exists() else ""
        if INI_DEBUT in texte or "UnfocusedVolumeMultiplier" in texte:
            return
        ENGINE_INI.parent.mkdir(parents=True, exist_ok=True)
        ENGINE_INI.write_text(texte + INI_BLOC, encoding="utf-8")
    except OSError:
        pass


def _remove_engine_ini():
    try:
        texte = ENGINE_INI.read_text(encoding="utf-8")
        if INI_DEBUT in texte and INI_FIN in texte:
            avant, reste = texte.split(INI_DEBUT, 1)
            ENGINE_INI.write_text(avant.rstrip("\n") + "\n" + reste.split(INI_FIN, 1)[1].lstrip("\n"), encoding="utf-8")
    except OSError:
        pass


def install(game_dir, ap_dir, log):
    root = win64(game_dir)
    if not (root / EXE).exists():
        raise RuntimeError(tr(f"{EXE} introuvable dans {root}", f"{EXE} not found in {root}"))
    if game_running():
        raise RuntimeError(tr("Le jeu est lancé : ferme-le avant d'installer", "The game is running: close it first"))
    if crash_reporter_open():
        raise RuntimeError(tr("La fenêtre de rapport de plantage du jeu (CrashReportClient) est encore ouverte : "
                              "ferme-la, elle bloque les fichiers du jeu", "The game's crash report window "
                              "(CrashReportClient) is still open: close it, it locks the game files"))
    old = read_manifest(game_dir) or {}
    backups = dict(old.get("backups", {}))
    created_mods_txt = old.get("created_mods_txt", False)
    # ancienne version du mod retirée (ses fichiers), copies d'origine gardées
    for rel in old.get("files", []):
        if (root / rel).exists():
            (root / rel).unlink()
    mod_dir = root / "ue4ss" / "Mods" / "ArchipelagoSB"
    if mod_dir.exists():
        shutil.rmtree(mod_dir)

    placed = []
    src_root = FILES / "ue4ss"
    for src in sorted(src_root.rglob("*")):
        if not src.is_file():
            continue
        rel = src.relative_to(src_root).as_posix()
        dst = root / rel
        if rel == SETTINGS_INI and dst.exists():
            continue   # réglages UE4SS du joueur gardés
        if dst.exists() and rel not in backups:
            shutil.copy2(dst, dst.with_name(dst.name + BACKUP_SUFFIX))
            backups[rel] = rel + BACKUP_SUFFIX
        _copy(src, dst)
        placed.append(rel)
    for src in sorted((FILES / "mod").rglob("*")):
        if src.is_file():
            rel = "ue4ss/Mods/" + src.relative_to(FILES / "mod").as_posix()
            _copy(src, root / rel)
            placed.append(rel)
    if _add_mod_line(game_dir):
        created_mods_txt = True
    _add_engine_ini()
    log(tr(f"{len(placed)} fichiers copiés, mod activé dans mods.txt", f"{len(placed)} files copied, mod enabled in mods.txt"))
    if backups:
        log(tr(f"{len(backups)} fichier(s) d'origine mis de côté (*{BACKUP_SUFFIX})",
               f"{len(backups)} original file(s) set aside (*{BACKUP_SUFFIX})"))
    manifest = root / MANIFEST
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({"version": bundled_version(), "files": placed, "backups": backups,
                                    "created_mods_txt": created_mods_txt}, indent=1), encoding="utf-8")
    if ap_dir:
        install_apworld(ap_dir, log)
    log(tr("Installation terminée.", "Install complete."))


def apworld_lang(path):
    try:
        with zipfile.ZipFile(path) as z:
            text = z.read("fnafsb/lang.py").decode("utf-8")
        return "en" if 'LANG = "en"' in text else "fr"
    except (OSError, KeyError, zipfile.BadZipFile):
        return "fr"


def install_apworld(ap_dir, log):
    target = ap_dir / "custom_worlds" / APWORLD
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(FILES / "apworld" / APWORLD_LANG / APWORLD, target)
    log(tr(f"apworld installé : {target}", f"apworld installed: {target}"))


def uninstall(game_dir, ap_dir, log, quiet=False):
    """Retire ce que le mod a posé et remet les fichiers d'origine. Les sauvegardes du jeu ne sont
    jamais touchées."""
    root = win64(game_dir)
    manifest = read_manifest(game_dir)
    if manifest is None:
        if not quiet:
            log(tr("Le mod n'est pas installé ici", "The mod is not installed here"))
        return
    if game_running():
        raise RuntimeError(tr("Le jeu est lancé : ferme-le avant de désinstaller", "The game is running: close it first"))
    removed = 0
    for rel in manifest.get("files", []):
        if (root / rel).exists():
            (root / rel).unlink()
            removed += 1
    for folder in (root / "ue4ss" / "Mods" / "ArchipelagoSB", root / "ue4ss" / "ArchipelagoSB"):
        if folder.exists():
            shutil.rmtree(folder, ignore_errors=True)
    restored = 0
    for rel, backup in manifest.get("backups", {}).items():
        if (root / backup).exists():
            (root / backup).replace(root / rel)
            restored += 1
    _remove_mod_line(game_dir, manifest.get("created_mods_txt", False))
    _remove_engine_ini()
    (root / MANIFEST).unlink()
    if ap_dir:
        world = ap_dir / "custom_worlds" / APWORLD
        if world.exists():
            world.unlink()
            log(tr("apworld supprimé", "apworld removed"))
    log(tr(f"Désinstallé : {removed} fichiers supprimés, {restored} fichier(s) d'origine remis",
           f"Uninstalled: {removed} files removed, {restored} original file(s) restored"))


# --- Room enregistrée (le mod lance le pont tout seul au démarrage du jeu) ----------------------

CONNECTION = "ue4ss/ArchipelagoSB/connection.json"   # relatif à Win64
PONT_LOG = "ue4ss/ArchipelagoSB/pont.log"
PONT_EXE = "ue4ss/Mods/ArchipelagoSB/pont/FNaF_SB_AP_Pont.exe"


def read_connection(game_dir):
    try:
        return json.loads((win64(game_dir) / CONNECTION).read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        return {}


def write_connection(game_dir, uri, slot, password):
    path = win64(game_dir) / CONNECTION
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"uri": uri, "slot": slot, "password": password}, indent=1), encoding="utf-8")


def clear_connection(game_dir):
    """Room effacée : le jeu ne se connecte plus à rien (un pont en cours s'arrête tout seul)."""
    path = win64(game_dir) / CONNECTION
    if path.exists():
        path.unlink()


def start_pont(game_dir):
    """Jeu déjà lancé : on démarre le pont nous-mêmes (il refuse de tourner en double)."""
    exe = win64(game_dir) / PONT_EXE
    if exe.exists():
        subprocess.Popen([str(exe)], creationflags=0x08000000 | 0x00000008, close_fds=True)


def pont_log_tail(game_dir, lines=14):
    try:
        text = (win64(game_dir) / PONT_LOG).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    return "\n".join(text.splitlines()[-lines:])


# --- Lancement ----------------------------------------------------------------------------------

def launch_game():
    os.startfile(f"steam://rungameid/{STEAM_APP_ID}")


def open_path(path):
    os.startfile(str(path))


# --- Rapport de bug ---------------------------------------------------------------------------

def bug_report(game_dir):
    """Zip des journaux sur le Bureau (launcher et pont, UE4SS, jeu, dernier plantage) ; sans mot de passe."""
    desktop = Path(os.environ.get("USERPROFILE", str(Path.home()))) / "Desktop"
    if not desktop.exists():
        desktop = SETTINGS_DIR
    target = desktop / time.strftime("FNaF_SB_AP_rapport_%Y%m%d_%H%M%S.zip")
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("launcher_version.txt", bundled_version())
        for log in (LOG_FILE, LOG_FILE.with_suffix(".old.log")):
            if log.exists():
                z.write(log, log.name)
        settings = load_settings()
        if settings:
            settings.pop("password", None)
            z.writestr("launcher_settings.json", json.dumps(settings, indent=1, ensure_ascii=False))
        if game_dir and win64(game_dir).exists():
            root = win64(game_dir)
            for rel in ("ue4ss/UE4SS.log", "ue4ss/Mods/mods.txt", MANIFEST, PONT_LOG, "ue4ss/ArchipelagoSB/journal.log",
                        "ue4ss/ArchipelagoSB/journal.1.log", "ue4ss/ArchipelagoSB/traces.log"):
                if (root / rel).exists():
                    z.write(root / rel, rel.replace("/", "_"))
            mods = root / "ue4ss" / "Mods"
            if mods.exists():
                z.writestr("dossier_mods.txt", "\n".join(sorted(p.name for p in mods.iterdir())))
        saved = Path(os.environ.get("LOCALAPPDATA", "")) / "fnaf9" / "Saved"
        if (saved / "Logs" / "fnaf9.log").exists():
            z.write(saved / "Logs" / "fnaf9.log", "fnaf9.log")
        crashes = sorted((saved / "Crashes").glob("*"), key=lambda p: p.stat().st_mtime) if (saved / "Crashes").exists() else []
        if crashes and time.time() - crashes[-1].stat().st_mtime < 3 * 86400:
            context = crashes[-1] / "CrashContext.runtime-xml"
            if context.exists():
                z.write(context, "dernier_plantage.xml")
    return target
