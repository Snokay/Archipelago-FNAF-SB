-- Pieges et DeathLink. Tout passe par la file de la porte de securite.
-- Pieges recus hors ligne : 1 a la connexion, le reste en reserve, 1 a chaque mort. Jeu relance = reserve oubliee.
local O = require("sb.outils")
local S = require("sb.securite")
local Sc = require("sb.screamer")
local M = {}

M.DUREE_BORNES = 300   -- s sans sauvegarde (option de l'apworld)

-- Alerte : Chica, Roxy et Monty foncent sur la position du joueur
local function alerte()
    local g = O.gregory()
    if not g then return end
    local ai = FindFirstOf("AIManagementSystem")
    local types = {}
    for t = 0, 2 do types[#types + 1] = {AIType = t, AISubType = O.sousType(t)} end
    ai:SendGeneralAlert(g:K2_GetActorLocation(), types, 3)
end

-- Bornes de sauvegarde en panne (glitch, comme quand Vanny les pirate) pendant DUREE_BORNES
local finBornes = nil

O.hook("/Game/Blueprints/UI/SaveGameUI.SaveGameUI_C:Construct", function(self)
    if not finBornes then return end
    local w = self:get()
    O.apres(50, function() w:RemoveFromParent() end)
end)

local function appliquerBornes(dispo)
    pcall(function() FindFirstOf("FNAFSaveGameSystem"):SetIsSavingAllowed(dispo) end)
    pcall(function() FindFirstOf("WorldStateSystem"):SetPowerStationAvailable(dispo) end)
    for _, b in ipairs(FindAllOf("SaveGameActor_C") or {}) do
        if b:IsValid() then
            local avant = b.Glitching
            b.IsActive = dispo
            b.Glitching = not dispo
            -- "Setup Display" du Blueprint change l'ecran (Helpy glitche a terre quand la borne est en panne)
            if avant ~= b.Glitching then pcall(function() b["Setup Display"](b) end) end
            if dispo then pcall(function() b.Play_sfx_saveStation_screen_glitch_lp:Stop() end) end
        end
    end
end

local function bornes()
    local deja = finBornes ~= nil
    finBornes = math.max(finBornes or 0, os.time()) + M.DUREE_BORNES
    if deja then return end
    -- Reappliquer toutes les 5 s : les bornes des zones chargees en route doivent aussi tomber en panne
    O.boucle(5000, function()
        local fini = os.time() >= finBornes
        ExecuteInGameThread(function()
            if fini then
                finBornes = nil
                appliquerBornes(true)
                O.log("bornes de sauvegarde reparees")
            else
                appliquerBornes(false)
            end
        end)
        return fini
    end)
    appliquerBornes(false)
end

-- Lampe a plat (les bornes de recharge de la lampe sont partout, aucun risque de blocage)
local function lampe()
    local i = O.inv()
    if i then i:SetPowerLevel_Fazwatch(0) end
end

local effets = {
    screamer = function() Sc.lancer(false) end,
    alerte = alerte,
    bornes = bornes,
    lampe = lampe,
}
M.noms = {screamer = "Screamer", alerte = "Alerte", bornes = "Bornes en panne", lampe = "Lampe a plat"}

-- texte : message troll avec le joueur qui a trouve le piege, affiche quand il tombe
local function declencher(type, texte)
    if not effets[type] then O.log("piege inconnu", type) return end
    S.ajouter("piege " .. type, function()
        effets[type]()
        -- l'alerte envoie des animatroniques : le piege suivant attend comme apres un screamer
        -- (alerte + screamer a 1 s d'ecart = plantage, 25/10)
        if type == "alerte" then S.verrouiller() end
        if texte then O.afficher(texte, 5.0) end
    end)
end

local reserve = {}

function M.recevoir(type, horsLigne, texte)
    if horsLigne then
        reserve[#reserve + 1] = {type = type, texte = texte}
    else
        declencher(type, texte)
    end
end

-- A la connexion au serveur : un seul des pieges recus hors ligne part tout de suite
function M.connexion()
    if #reserve > 0 then
        O.log(#reserve, "pieges recus hors ligne, 1 tout de suite, le reste a chaque mort")
        local p = table.remove(reserve, 1)
        declencher(p.type, p.texte)
    end
end

function M.reserveRestante() return #reserve end

S.surMort[#S.surMort + 1] = function()
    if #reserve > 0 then
        O.log("mort : un piege de la reserve arrive (" .. (#reserve - 1) .. " restants)")
        local p = table.remove(reserve, 1)
        declencher(p.type, p.texte)
    end
end

-- DeathLink recu : passe devant les pieges. mode "classique" (mort directe) ou "screamer"
function M.deathLink(mode)
    S.ajouter("DeathLink", function()
        if mode == "screamer" then Sc.lancer(true) else O.gregory():Kill() end
    end, true)
end

return M
