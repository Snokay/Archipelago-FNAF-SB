-- Fazer Blast avec un Fazerblaster deja recu : le pistolet de la table (et celui du prix) se detruit au
-- chargement si le joueur en a deja un ("PlayerHasBlaster"), la mission ne peut plus avancer.
-- Tant que la mission n'est pas finie, on fait croire au pistolet que le joueur n'en a pas, et au moment
-- de le prendre on met celui du joueur de cote ; il est rendu a la fin de la mission.
local O = require("sb.outils")
local Ob = require("sb.objets")
local R = require("sb.ramassage")
local M = {}

local CLASSE = "/Game/Blueprints/Objects/Collectibles/LaserGunCollectible"
local deCote = false

local function missionFinie()
    local ok, fini = pcall(function() return FindFirstOf("FNAFMissionSystem"):IsCompletedMission(FName("FazerBlast")) end)
    return ok and fini == true
end

-- Plus de LoadAsset de la classe en pleine partie : charge a cote du streaming de la zone, il faisait
-- planter le moteur dans l'ascenseur de Fazer Blast ("Could not find SuperStruct InteractIgnoresTrace",
-- 25/10). Le hook se pose quand le jeu charge la classe lui-meme (O.hook, ou au 1er pistolet supprime) ;
-- le pistolet recree ne se resupprime pas, le Fazerblaster du joueur est retire le temps de la creation.
O.hook(CLASSE .. ".LaserGunCollectible_C:PlayerHasBlaster", function(self, retour)
    if missionFinie() then return end
    local i = O.inv()
    if i and i:HasItem(FName("Fazergun")) then
        pcall(function() retour:set(false) end)
        return false
    end
end)

-- Le pistolet se detruit pendant son propre chargement (le hook passe apres, trop tard) : on en recree
-- un au meme endroit, en retirant le Fazerblaster du joueur juste le temps de la creation (meme image).
local enCreation = false
local recreations = 0
-- Il ne se supprime pas pendant son chargement mais juste apres : on guette sa suppression
O.hook("/Script/Engine.Actor:K2_DestroyActor", function(self)
    local a = self:get()
    local okC, classe = pcall(function() return a:GetClass() end)
    if not okC then return end
    local nomClasse = classe:GetFName():ToString()
    if not nomClasse:find("LaserGunCollectible") then return end
    -- Supprime parce que le joueur vient de le prendre : surtout ne pas le recreer
    if enCreation or deCote or missionFinie() then return end
    -- Garde-fou : le pistolet recree peut refaire la meme verification et se resupprimer en boucle
    recreations = recreations + 1
    if recreations > 4 then O.log("Fazer Blast : trop de recreations, abandon") return end
    local i = O.inv()
    if not i or not i:HasItem(FName("Fazergun")) then return end
    local transform = a:GetTransform()
    ExecuteInGameThread(function()
        pcall(O.accrocherHooks)  -- la classe est chargee (un pistolet existe) : hooks PlayerHasBlaster/survol
        local ok, err = pcall(function()
            local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
            enCreation = true
            i:RemoveItem(FName("Fazergun"))
            local nouveau = gs:BeginDeferredActorSpawnFromClass(O.gregory(), classe, transform, 1, nil)
            gs:FinishSpawningActor(nouveau, transform)
            Ob.donneParMod = true
            i:AwardItem(FName("Fazergun"), false)
            Ob.donneParMod = false
            enCreation = false
        end)
        enCreation = false
        Ob.donneParMod = false
        if not ok then O.log("Fazer Blast : recreation impossible", tostring(err)) end
    end)
end)

-- Au moment de prendre le pistolet de la table : celui du joueur est mis de cote (sinon doublon)
O.hook(CLASSE .. ".LaserGunCollectible_C:OnPlayerHoverEnter", function(self)
    if missionFinie() then return end
    -- Le pistolet de la table est prete pour le mini-jeu : seul celui du prix est un check
    pcall(function()
        if self:get():GetClass():GetFName():ToString():find("_Game") then R.ignorer["Fazergun"] = os.time() end
    end)
    local i = O.inv()
    if i and i:HasItem(FName("Fazergun")) then
        -- Celui en main d'abord : Gregory reprend sa lampe, sinon le pistolet reste equipe sans objet
        pcall(function()
            local g = O.gregory()
            local eq = g.EquippedItem
            if eq and eq:IsValid() and eq:GetClass():GetFName():ToString():find("LaserGun") then
                g:SwitchItem(g.FlashlightActor.ChildActor)
            end
        end)
        i:RemoveItem(FName("Fazergun"))
        deCote = true
        O.log("Fazer Blast : Fazerblaster du joueur mis de cote")
    end
end)

-- Rendu a la fin de la mission (si le jeu ne l'a pas deja donne comme prix)
O.hook("/Script/fnaf9.FNAFMissionSystem:CompleteMission", function(self, mission)
    if O.s(mission) ~= "FazerBlast" or not deCote then return end
    O.apres(3000, function()
        deCote = false
        local i = O.inv()
        if i and not i:HasItem(FName("Fazergun")) then
            Ob.donneParMod = true
            pcall(function() i:AwardItem(FName("Fazergun"), false) end)
            Ob.donneParMod = false
        end
        O.log("Fazer Blast : Fazerblaster du joueur rendu")
    end)
end)

return M
