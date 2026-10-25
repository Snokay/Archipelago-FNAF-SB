"""
Planches d'affiches perso (contenu fun, 2026-10-23) : les affiches du jeu sont rangées sur des planches
(une texture pour plusieurs cadres). On repart de la planche d'origine (extraite du pak, décodée en PNG)
et on colle chaque image perso dans son emplacement, recadrée au centre à ses proportions.

    python construire_affiches.py <dossier des planches d'origine en PNG>
Sortie : mod/ArchipelagoSB/images/affiches_*.png (posées en jeu par sb/affiches.lua)
"""
import sys
from pathlib import Path
from PIL import Image, ImageOps

RACINE = Path(__file__).resolve().parents[1]
VISUEL = RACINE / "visuel"
SORTIE = RACINE / "mod" / "ArchipelagoSB" / "images"

# emplacements en pixels d'un aperçu 700x700 de la planche (mis à l'échelle de la vraie taille)
PLANCHES = {
    "ENV_TEX_Posters_Office_02_A_TGA": ("affiches_fnaf2.png", {
        (2, 2, 209, 226): "image1.png", (213, 2, 420, 226): "image12.png", (425, 2, 632, 226): "image4.png",
        (2, 231, 397, 454): "image13.png", (401, 231, 609, 454): "image14.png",
        (2, 458, 397, 686): "image11.png", (401, 458, 609, 686): "image10.png"}),
    "ENV_TEX_Posters_Office_01_A": ("affiches_fnaf1.png", {
        (483, 350, 628, 522): "image2.png", (89, 526, 198, 662): "image3.png", (199, 526, 309, 662): "image15.png",
        (310, 526, 428, 662): "image11.webp", (429, 526, 565, 692): "image5.png",
        # dessins "My Fun Day" visibles sur le mur de Rockstar Row : gateau, Freddy et notes, smileys, cadeau
        (221, 2, 347, 170): "image6.jpg", (351, 2, 479, 170): "image7.jpg",
        (221, 175, 347, 345): "image8.jpg", (221, 349, 347, 520): "image9.jpg",
        (483, 175, 611, 345): "image16.jpg", (89, 349, 217, 520): "image18.jpg"}),
    # dessins aux pizzas (couloir de Rockstar Row), grille de 5 colonnes de 140 : Chica, Freddy, (Chica et
    # Bonnie), trio, (Bonnie et Freddy)
    "ENV_TEX_Posters_Office_03_A_TGA": ("affiches_dessins.png", {
        (2, 405, 138, 592): "image19.jpg", (142, 405, 278, 592): "image17.png", (422, 405, 558, 592): "image20.jpg"}),
}


# affiches seules (une image par texture, posée dans la zone opaque de l'affiche d'origine)
SEULES = {"Poster_RoxyNegal": ("poster_roxy.png", "Poster.png")}


def sans_bandes(im):
    """Retire les bandes noires (captures de téléphone)."""
    gris = im.convert("L").point(lambda v: 255 if v > 18 else 0)
    boite = gris.getbbox()
    return im.crop(boite) if boite else im


def recadrer(im, w, h):
    im = sans_bandes(ImageOps.exif_transpose(im).convert("RGB"))   # photos de telephone : sens EXIF
    r = w / h
    if im.width / im.height > r:
        nw = int(im.height * r)
        im = im.crop(((im.width - nw) // 2, 0, (im.width - nw) // 2 + nw, im.height))
    else:
        nh = int(im.width / r)
        haut = max(0, (im.height - nh) // 3)   # un peu vers le haut : les visages
        im = im.crop((0, haut, im.width, haut + nh))
    return im.resize((w, h), Image.LANCZOS)


def main():
    source = Path(sys.argv[1])
    for planche, (sortie, cases) in PLANCHES.items():
        fond = Image.open(source / f"{planche}.png").convert("RGBA")
        k = fond.width / 700
        for (x0, y0, x1, y1), nom in cases.items():
            b = [round(v * k) for v in (x0, y0, x1, y1)]
            img = recadrer(Image.open(VISUEL / nom), b[2] - b[0], b[3] - b[1]).convert("RGBA")
            # on garde la transparence d'origine de la planche (bords des feuilles)
            img.putalpha(fond.crop(b).getchannel("A"))
            fond.paste(img, b[:2])
        fond.save(SORTIE / sortie)
        print("planche :", SORTIE / sortie)
    for texture, (sortie, nom) in SEULES.items():
        fond = Image.open(source / f"{texture}.png").convert("RGBA")
        b = fond.getchannel("A").getbbox()
        img = recadrer(Image.open(VISUEL / nom), b[2] - b[0], b[3] - b[1]).convert("RGBA")
        img.putalpha(fond.crop(b).getchannel("A"))
        fond.paste(img, b[:2])
        fond.save(SORTIE / sortie)
        print("affiche :", SORTIE / sortie)


if __name__ == "__main__":
    main()
