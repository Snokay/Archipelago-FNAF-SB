# Images de l'icone de chargement : le logo neon du projet (6 animatroniques) tourne d'un tour
# complet sur les 35 images du flipbook PizzaHelpy du jeu -> mod/ArchipelagoSB/images/chargement/ap_NN.png
import os
from PIL import Image

N = 35          # nombre d'images Helpy_Anim_pizza dans PizzaHelpy
TAILLE = 512     # taille du fichier seulement (a l ecran : cadre 1024 de Helpy)
ICI = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(ICI, "..", "visuel", "Icônes animatroniques néon multicolores.png")
SORTIE = os.path.join(ICI, "..", "mod", "ArchipelagoSB", "images", "chargement")

os.makedirs(SORTIE, exist_ok=True)
logo = Image.open(SOURCE).convert("RGBA")
# taille du logo dans le cadre de Helpy (0.82 = trop gros en jeu)
cote = int(TAILLE * 0.45)
logo = logo.resize((cote, cote), Image.LANCZOS)
base = Image.new("RGBA", (TAILLE, TAILLE), (0, 0, 0, 0))
base.paste(logo, ((TAILLE - cote) // 2, (TAILLE - cote) // 2), logo)

for i in range(N):
    # sens horaire (rotate tourne dans le sens inverse)
    img = base.rotate(-360.0 * i / N, resample=Image.BICUBIC)
    img.save(os.path.join(SORTIE, "ap_%02d.png" % i))
print(N, "images ->", os.path.normpath(SORTIE))
