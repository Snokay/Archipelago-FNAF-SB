# Lecture des textures cuites du jeu (UE 4.27, premiere mip stockee dans le .uexp) -> image Pillow.
# Formats geres : PF_DXT1, PF_DXT5 (decodes par Pillow via un en-tete DDS) et PF_B8G8R8A8.
# Usage : python textures_ue.py fichier.uexp [...] -> fichier.png a cote
import io, re, struct, sys
from PIL import Image


def lire(uexp):
    d = open(uexp, "rb").read()
    m = re.search(rb"PF_[A-Za-z0-9]+\x00", d)
    if not m:
        raise ValueError("format de pixels introuvable : " + uexp)
    fmt = m.group(0)[:-1].decode()
    # avant le nom du format : largeur, hauteur, 1, longueur de la chaine
    w, h = struct.unpack_from("<ii", d, m.start() - 16)
    # apres : 0, nombre de mips, cuit, drapeaux, nb d'elements, taille sur disque, position (int64), donnees
    drapeaux, taille = struct.unpack_from("<ii", d, m.end() + 12)
    if drapeaux & 0x100:   # premiere mip dans le .ubulk, a la position indiquee
        pos = struct.unpack_from("<q", d, m.end() + 24)[0]
        px = open(uexp[:-5] + ".ubulk", "rb").read()[pos:pos + taille]
    else:
        debut = m.end() + 32
        px = d[debut:debut + taille]
    if fmt == "PF_B8G8R8A8":
        return Image.frombytes("RGBA", (w, h), px, "raw", "BGRA")
    if fmt in ("PF_DXT1", "PF_DXT5"):
        fourcc = fmt[3:].encode()
        lin = len(px)
        # DDS : magie, 7 champs, reserve, format de pixels (taille, drapeau FOURCC, code, 5 masques), 5 champs
        entete = struct.pack("<4s7I44s2I4s5I5I", b"DDS ", 124, 0x81007, h, w, lin, 0, 1,
                             b"\0" * 44, 32, 4, fourcc, 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0)
        return Image.open(io.BytesIO(entete + px)).convert("RGBA")
    raise ValueError("format non gere : " + fmt)


if __name__ == "__main__":
    for f in sys.argv[1:]:
        im = lire(f)
        sortie = f.rsplit(".", 1)[0] + ".png"
        im.save(sortie)
        print(sortie, im.size)
