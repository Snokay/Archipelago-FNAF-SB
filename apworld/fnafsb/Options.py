from dataclasses import dataclass
from Options import Choice, Range, Toggle, DefaultOnToggle, PerGameCommonOptions, DeathLink, ProgressionBalancing

from .lang import LANG

# Memes cles et memes numeros de choix dans les deux langues ; les choix acceptent les mots des deux
# langues (alias), un YAML fait avec la version FR marche avec la version EN.
FR = LANG == "fr"


def text(fr, en):
    return fr if FR else en


class Fin(Choice):
    __doc__ = text(
        """Fin a faire pour gagner (en plus des collectibles demandes).
        n_importe_laquelle : n'importe quelle fin du jeu.
        toutes : toutes les fins principales.
        Les autres choix demandent une fin precise.""",
        """Ending needed to win (on top of the requested collectibles).
        any: any ending of the game.
        all: every main ending.
        The other choices ask for one specific ending.""")
    display_name = text("Fin", "Ending")
    if FR:
        option_n_importe_laquelle = 0
        option_quai_de_chargement = 1
        option_fazer_blast = 2
        option_vip = 3
        option_burntrap = 4
        option_ruelle = 5
        option_toutes = 6
        alias_any = 0
        alias_loading_dock = 1
        alias_vip_ending = 3
        alias_alley = 5
        alias_all = 6
    else:
        option_any = 0
        option_loading_dock = 1
        option_fazer_blast = 2
        option_vip = 3
        option_burntrap = 4
        option_alley = 5
        option_all = 6
        alias_n_importe_laquelle = 0
        alias_quai_de_chargement = 1
        alias_ruelle = 5
        alias_toutes = 6
    default = 0


class Cadeaux(Range):
    __doc__ = text("Nombre de cadeaux a ouvrir pour gagner (0 = aucun, 76 ou plus = tous). L'amelioration de lampe "
                   "de la garderie (ratable apres Moon) et le cadeau Mystery Mix cache de l'arcade ouest ne comptent pas.",
                   "Number of presents to open to win (0 = none, 76 or more = all). The Daycare flashlight upgrade "
                   "(missable after Moon) and the hidden Mystery Mix present of the West Arcade do not count.")
    display_name = text("Cadeaux a ouvrir", "Presents to open")
    range_start = 0
    range_end = 77
    default = 0


class Messages(Range):
    __doc__ = text("Nombre de messages a ramasser pour gagner (0 = aucun, 52 = tous).",
                   "Number of messages to pick up to win (0 = none, 52 = all).")
    display_name = text("Messages a ramasser", "Messages to pick up")
    range_start = 0
    range_end = 52
    default = 0


class CD(Range):
    __doc__ = text("Nombre de CD retro a trouver pour gagner (0 = aucun, 16 = tous).",
                   "Number of Retro CDs to find to win (0 = none, 16 = all).")
    display_name = text("CD retro a trouver", "Retro CDs to find")
    range_start = 0
    range_end = 16
    default = 0


class ChecksMissions(DefaultOnToggle):
    __doc__ = text("Chaque mission terminee est un check.", "Every finished mission is a check.")
    display_name = text("Missions", "Missions")


class ChecksMessages(DefaultOnToggle):
    __doc__ = text("Les messages ramasses sont des checks.", "Picked up messages are checks.")
    display_name = text("Messages comme checks", "Messages as checks")


class ChecksCD(DefaultOnToggle):
    __doc__ = text("Les CD retro sont des checks.", "Retro CDs are checks.")
    display_name = text("CD retro comme checks", "Retro CDs as checks")


class DebutRapide(DefaultOnToggle):
    __doc__ = text("Multiworld : les objets qui ouvrent le debut du Pizzaplex restent pres de toi (Bon d'entree "
                   "gratuit a sa place, Pass garderie et lampe torche dans tes premiers emplacements), le 1er badge au tout debut de n'importe quel "
                   "jeu, pour ne pas attendre la fin du jeu d'un autre joueur. Sans effet en solo.",
                   "Multiworld: the items that open the start of the Pizzaplex stay close to you (Complimentary "
                   "Pass at its spot, Daycare Pass and flashlight in your first locations), the 1st badge at the very start of any game, so you "
                   "don't wait for the end of someone else's game. No effect in solo.")
    display_name = text("Debut rapide", "Quick start")


class EquilibrageSB(ProgressionBalancing):
    # plus haut que le 50 d'Archipelago : nos objets de progression ne finissent pas au fond du jeu d'un autre
    default = 80


class PourcentBonus(Range):
    __doc__ = text(
        """Part des objets de remplissage remplaces par des bonus (recharges, endurance...).
        Avec les pieges, au plus 100 % : au-dela, les deux sont ramenes a 100 % au total.""",
        """Share of filler items replaced by bonuses (recharges, stamina...).
        With traps, at most 100 %: above that, both are scaled down to 100 % in total.""")
    display_name = text("% de bonus", "% of bonuses")
    range_start = 0
    range_end = 100
    default = 30


class PourcentPieges(Range):
    __doc__ = text("Part des objets de remplissage remplaces par des pieges.",
                   "Share of filler items replaced by traps.")
    display_name = text("% de pieges", "% of traps")
    range_start = 0
    range_end = 100
    default = 20


class DureeBornes(Range):
    __doc__ = text("Duree d'une panne des bornes de sauvegarde, en minutes.",
                   "How long a save station outage lasts, in minutes.")
    display_name = text("Duree de panne des bornes", "Save station outage length")
    range_start = 1
    range_end = 15
    default = 5


class DureePiege(Choice):
    """Base des durees des pieges, par demi-minute (valeur = nombre de 30 s)."""
    option_30s = 1
    option_1min = 2
    option_1min30 = 3
    option_2min = 4
    option_2min30 = 5
    option_3min = 6
    option_3min30 = 7
    option_4min = 8
    option_4min30 = 9
    option_5min = 10


class DureeRalenti(DureePiege):
    __doc__ = text("Duree du piege qui ralentit Gregory.",
                   "How long the trap that slows Gregory down lasts.")
    display_name = text("Duree du ralenti", "Slowdown length")
    default = 1


class DureeEntrave(DureePiege):
    __doc__ = text("Duree du piege qui empeche de courir et de sauter.",
                   "How long the no running / no jumping trap lasts.")
    display_name = text("Duree sans course ni saut", "No running / jumping length")
    default = 1


class DureeTurbo(DureePiege):
    __doc__ = text("Duree du piege qui accelere tout ce qui peut te tuer ou donner l'alerte.",
                   "How long the trap that speeds up everything that can kill you or raise the alarm lasts.")
    display_name = text("Duree des ennemis acceleres", "Sped-up enemies length")
    default = 2


class Vitesse(Choice):
    """Base des multiplicateurs de vitesse (valeur = pourcentage)."""
    option_x1_25 = 125
    option_x1_5 = 150
    option_x1_75 = 175
    option_x2 = 200
    option_x2_5 = 250
    option_x3 = 300
    option_x3_5 = 350
    option_x4 = 400
    option_x4_5 = 450
    option_x5 = 500
    default = 150


class VitesseTurbo(Vitesse):
    __doc__ = text("Multiplicateur de vitesse du piege des ennemis acceleres (x1_25 a x5).",
                   "Speed multiplier of the sped-up enemies trap (x1_25 to x5).")
    display_name = text("Vitesse des ennemis", "Enemy speed")


class VitesseEndurance(Vitesse):
    __doc__ = text("Multiplicateur de vitesse de Gregory pendant le bonus d'endurance illimitee (x1_25 a x5).",
                   "Gregory's speed multiplier during the unlimited stamina bonus (x1_25 to x5).")
    display_name = text("Vitesse de Gregory (endurance)", "Gregory speed (stamina)")


class ModeDeathLink(Choice):
    __doc__ = text(
        """Mort recue d'un autre joueur.
        classique : Gregory meurt directement.
        screamer : un animatronique vient te faire un vrai screamer mortel.""",
        """Death received from another player.
        classic: Gregory dies right away.
        screamer: an animatronic comes to give you a real deadly jumpscare.""")
    display_name = text("Mode DeathLink", "DeathLink Mode")
    if FR:
        option_classique = 0
        option_screamer = 1
        alias_classic = 0
    else:
        option_classic = 0
        option_screamer = 1
        alias_classique = 0
    default = 1


@dataclass
class FNaFSBOptions(PerGameCommonOptions):
    fin: Fin
    cadeaux: Cadeaux
    messages: Messages
    cd: CD
    checks_missions: ChecksMissions
    checks_messages: ChecksMessages
    checks_cd: ChecksCD
    debut_rapide: DebutRapide
    progression_balancing: EquilibrageSB
    pourcent_bonus: PourcentBonus
    pourcent_pieges: PourcentPieges
    duree_bornes: DureeBornes
    duree_ralenti: DureeRalenti
    duree_entrave: DureeEntrave
    duree_turbo: DureeTurbo
    vitesse_turbo: VitesseTurbo
    vitesse_endurance: VitesseEndurance
    death_link: DeathLink
    mode_death_link: ModeDeathLink
