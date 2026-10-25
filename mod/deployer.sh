#!/bin/sh
# Copie le mod dans le jeu (le jeu doit etre relance ensuite). Le dossier pont/ (pont sans fenetre pose par
# le launcher) est garde.
JEU="D:/Steam/steamapps/common/Quarters/fnaf9/Binaries/Win64/ue4ss/Mods"
ICI="$(dirname "$0")"
mkdir -p "$JEU/ArchipelagoSB"
find "$JEU/ArchipelagoSB" -mindepth 1 -maxdepth 1 ! -name pont -exec rm -rf {} +
cp -r "$ICI/ArchipelagoSB/." "$JEU/ArchipelagoSB/"
echo "mod copie dans $JEU/ArchipelagoSB"
