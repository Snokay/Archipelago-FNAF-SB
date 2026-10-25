"""
Construit la version distribuée du mod (2026-10-22, sur le modèle de RE Village) :

  build/release/FNaF_SB_Archipelago_<version>_launcher/
    FNaF_SB_AP_Launcher.exe        launcher (PyInstaller) : installation, room, options, hébergement
    files/ue4ss/...                UE4SS pris dans le jeu (version testée avec le mod), sans les mods de dev
    files/mod/ArchipelagoSB/...    le mod (scripts Lua, images, pont/FNaF_SB_AP_Pont.exe lancé par le mod)
    files/apworld/fr|en/fnafsb.apworld
    files/version.json, files/options.json
  build/release/FNaF_SB_Archipelago_<version>_launcher.zip

    python make_release.py 0.9.1.0 [--jeu "<dossier Quarters>"]
Nécessite : pip install pyinstaller websockets
"""

import argparse
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ICI = Path(__file__).resolve().parent
RACINE = ICI.parent
JEU_DEFAUT = Path(r"D:\Steam\steamapps\common\Quarters")

# Ce qu'on prend de l'UE4SS du jeu (relatif à fnaf9/Binaries/Win64) ; le reste (dumps, journaux,
# mods de test, mods de triche) n'est jamais distribué.
UE4SS_FICHIERS = ["dwmapi.dll", "ue4ss/UE4SS.dll", "ue4ss/LICENSE"]
UE4SS_DOSSIERS = ["ue4ss/Mods/shared", "ue4ss/Mods/Keybinds"]


def reglages_ue4ss(win64):
    """Réglages d'origine d'UE4SS (avant nos essais), rechargement à chaud coupé : il fait planter le jeu
    avec ce mod (touches et hooks fantômes)."""
    source = win64 / "ue4ss" / "UE4SS-settings.ini.bak-avant-hotreload"
    if not source.exists():
        source = win64 / "ue4ss" / "UE4SS-settings.ini"
    lignes = []
    for ligne in source.read_text(encoding="utf-8", errors="replace").splitlines():
        if ligne.replace(" ", "").startswith("EnableHotReloadSystem="):
            ligne = "EnableHotReloadSystem = 0"
        lignes.append(ligne)
    return "\n".join(lignes) + "\n"


def apworld(dest, lang):
    """Paquet .apworld (zip du dossier fnafsb) avec lang.py réglé sur la langue."""
    source = RACINE / "apworld" / "fnafsb"
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(source.rglob("*")):
            if not f.is_file() or "__pycache__" in f.parts:
                continue
            nom = "fnafsb/" + f.relative_to(source).as_posix()
            if nom == "fnafsb/lang.py":
                texte = f.read_text(encoding="utf-8").replace('LANG = "fr"', f'LANG = "{lang}"')
                z.writestr(nom, texte)
            else:
                z.write(f, nom)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("version")
    a.add_argument("--jeu", default=str(JEU_DEFAUT))
    args = a.parse_args()
    win64 = Path(args.jeu) / "fnaf9" / "Binaries" / "Win64"
    nom = f"FNaF_SB_Archipelago_{args.version}_launcher"
    sortie = RACINE / "build" / "release" / nom
    if sortie.exists():
        shutil.rmtree(sortie)
    files = sortie / "files"

    for rel in UE4SS_FICHIERS:
        (files / "ue4ss" / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(win64 / rel, files / "ue4ss" / rel)
    for rel in UE4SS_DOSSIERS:
        # sans les copies d'origine que le launcher laisse a cote (*.avant_archipelago) sur la machine de build
        shutil.copytree(win64 / rel, files / "ue4ss" / rel, ignore=shutil.ignore_patterns("*.log", "*.avant_*"))
    (files / "ue4ss" / "ue4ss" / "UE4SS-settings.ini").write_text(reglages_ue4ss(win64), encoding="utf-8")

    shutil.copytree(RACINE / "mod" / "ArchipelagoSB", files / "mod" / "ArchipelagoSB",
                    ignore=shutil.ignore_patterns("__pycache__", "*.bak*"))
    for lang in ("fr", "en"):
        apworld(files / "apworld" / lang / "fnafsb.apworld", lang)
    (files / "version.json").write_text(json.dumps({"version": args.version}), encoding="utf-8")
    sys.path.insert(0, str(ICI))
    import options_schema
    (files / "options.json").write_text(json.dumps(options_schema.build(), indent=1, ensure_ascii=False),
                                        encoding="utf-8")

    travail = RACINE / "build" / "pyinstaller"
    assets = ICI / "assets"
    subprocess.run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--onefile", "--windowed",
                    "--name", "FNaF_SB_AP_Launcher", "--icon", str(assets / "icon.ico"),
                    "--add-data", f"{assets / 'logo.png'};.", "--add-data", f"{assets / 'embleme.png'};.", "--add-data", f"{assets / 'icon.ico'};.",
                    "--distpath", str(sortie), "--workpath", str(travail), "--specpath", str(travail),
                    str(ICI / "launcher.py")], check=True)
    # pont sans fenêtre, rangé dans le mod : le mod le lance au démarrage du jeu (room enregistrée)
    subprocess.run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--onefile", "--windowed",
                    "--name", "FNaF_SB_AP_Pont", "--icon", str(assets / "icon.ico"),
                    "--paths", str(RACINE / "client"), "--hidden-import", "websockets",
                    "--collect-submodules", "websockets",
                    "--distpath", str(files / "mod" / "ArchipelagoSB" / "pont"), "--workpath", str(travail / "pont"),
                    "--specpath", str(travail), str(RACINE / "client" / "pont_auto.py")], check=True)

    archive = sortie.parent / (nom + ".zip")
    if archive.exists():
        archive.unlink()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(sortie.rglob("*")):
            if f.is_file():
                z.write(f, nom + "/" + f.relative_to(sortie).as_posix())
    print("version prête :", archive)


if __name__ == "__main__":
    main()
