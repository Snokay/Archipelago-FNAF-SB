"""
Point d'entrée de FNaF_SB_AP_Pont.exe (sans fenêtre), installé dans ue4ss/Mods/ArchipelagoSB/pont/ et lancé
par le mod au démarrage du jeu : le jeu se connecte à la room enregistrée sans ouvrir le launcher.
"""
import sys
from pathlib import Path

import pont_ap

if __name__ == "__main__":
    # .../fnaf9/Binaries/Win64/ue4ss/Mods/ArchipelagoSB/pont/FNaF_SB_AP_Pont.exe -> dossier Win64
    exe = Path(sys.executable if getattr(sys, "frozen", False) else __file__).resolve()
    win64 = Path(sys.argv[1]) if len(sys.argv) > 1 else exe.parents[4]
    pont_ap.auto(str(win64))
