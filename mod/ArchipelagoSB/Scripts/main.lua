-- Archipelago pour FNaF Security Breach
local O = require("sb.outils")
require("sb.mapbot")
local P = require("sb.pieges")
local B = require("sb.bonus")
local Ob = require("sb.objets")
local R = require("sb.ramassage")
local F = require("sb.fins")
require("sb.depannage")
require("sb.fazerblast")
require("sb.recreation")
require("sb.client")
local H = require("sb.hud")
require("sb.roue")
require("sb.logo")
require("sb.chargement")
require("sb.messages")
require("sb.neon")
require("sb.musique")
require("sb.affiches")

-- Point d'entree du futur client
ArchipelagoSB = {recevoir = Ob.recevoir, connexion = P.connexion, deathLink = P.deathLink,
    ramassage = R, fins = F, bonus = B, objets = Ob, hud = H}

O.log("pret. G = roue des bonus, H = carte Archipelago, F10 = deblocage")
