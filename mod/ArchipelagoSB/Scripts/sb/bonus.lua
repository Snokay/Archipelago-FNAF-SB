-- Bonus recus : stockes en reserve, utilises quand le joueur veut (roue des bonus, sb/roue.lua)
local O = require("sb.outils")
local S = require("sb.securite")
local M = {}

M.DUREE_ENDURANCE = 60   -- s d'endurance illimitee
M.RAYON_CHOC = 2000      -- u autour du joueur
M.DUREE_CHOC = 10        -- s d'etourdissement

local finEndurance = nil
local function endurance()
    local deja = finEndurance ~= nil
    finEndurance = math.max(finEndurance or 0, os.time()) + M.DUREE_ENDURANCE
    O.inv().bUnlimitedStamina = true
    if deja then return end
    O.boucle(1000, function()
        local fini = os.time() >= finEndurance
        if fini then
            ExecuteInGameThread(function()
                finEndurance = nil
                local i = O.inv()
                if i then i.bUnlimitedStamina = false end
                O.log("fin de l'endurance illimitee")
            end)
        end
        return fini
    end)
end

-- Choc : assomme les animatroniques autour (pas Vanny ni Vanessa, scriptees : les assommer les a deja cassees)
local function choc()
    local g = O.gregory()
    if not g then return end
    local loc = g:K2_GetActorLocation()
    local n = 0
    for _, a in ipairs(FindAllOf("AISeeker_C") or {}) do
        if a:IsValid() and not O.supprime(a) then
            local classe = a:GetClass():GetFName():ToString()
            if not classe:find("Vann") and O.dist2D(a:K2_GetActorLocation(), loc) < M.RAYON_CHOC then
                pcall(function() a:StunForDuration(M.DUREE_CHOC) end)
                -- Les versions brisees ignorent l'etourdissement (Roxy brisee continuait), Monty aussi (ses
                -- lunettes le protegent, comme du flash de la Faz Camera ; joueur 25/10) : on les fige
                O.log("choc sur", classe)
                if classe:find("Shattered") or classe:find("Monty") or classe:find("Gator") then
                    pcall(function() a.CustomTimeDilation = 0.0 end)
                    O.apres(M.DUREE_CHOC * 1000, function()
                        if a:IsValid() then a.CustomTimeDilation = 1.0 end
                    end)
                end
                n = n + 1
            end
        end
    end
    O.log("choc :", n, "animatronique(s) assomme(s)")
end

-- Chaque bonus a son son, pris dans le jeu (bornes de recharge, Faz Camera, Fazerblaster)
local A = "/Game/Audio/Assets/"
M.liste = {
    {id = "lampe", desc = {"Remplit la batterie de la lampe torche.", "Fully recharges the flashlight."}, icone = "Flashlight", neon = {1.0, 0.85, 0.2}, nom = "Recharge de la lampe", f = function() O.inv():ResetFlashlightPower() end,
        son = A .. "PropActors/FlashlightRechargeStation/Play_sfx_rechargeStation_flashlight_charging_complete"},
    {id = "freddy", desc = {"Remplit la batterie de Freddy.", "Fully recharges Freddy."}, icone = "FreddyUpgrade_0", neon = {1.0, 0.2, 0.25}, nom = "Recharge de Freddy", f = function() O.inv():ResetFreddyPower() end,
        son = A .. "PropActors/FreddyRechargeStation/Play_sfx_rechargeStation_charge_complete"},
    {id = "flashs", desc = {"Recharge tous les flashs de la Faz Camera.", "Refills every Faz Camera flash."}, icone = "FlashBeacon", neon = {0.25, 0.5, 1.0}, nom = "Recharge de la Faz Camera", f = function() O.inv():ResetFlashes() end,
        son = A .. "PropActors/Equippables/FashBeacon/Play_sfx_fazcam_recharge"},
    {id = "endurance", desc = {"Cours sans t'essouffler pendant 60 secondes.", "Run without getting tired for 60 seconds."}, icone = {"GregoryUpgrade_Stamina_0", "GregoryUpgrade_Stamina_1", "GregoryUpgrade_Stamina_2", "GregoryUpgrade_Stamina_3", "MontyMysteryMix", "GregoryUpgrade_Shoes"}, neon = {0.3, 1.0, 0.4}, nom = "Endurance illimitee", f = endurance,
        son = A .. "Hour6/Play_sfx_fazerblaster_recharge_fullyCharged"},
    {id = "choc", desc = {"Assomme les animatroniques proches pendant 10 secondes.", "Stuns nearby animatronics for 10 seconds."}, icone = "Fazergun", neon = {0.7, 0.3, 1.0}, nom = "Choc", f = choc,
        son = A .. "PropActors/Equippables/FashBeacon/Play_Gregory_FlashBeacon_Trigger"},
}
local parId = {}
for _, b in ipairs(M.liste) do parId[b.id] = b end

M.stock = {}            -- id -> nombre en reserve
M.utilises = {}         -- id -> nombre deja utilises (le client le gardera sur le serveur)
local selection = 1

function M.recevoir(id)
    if not parId[id] then O.log("bonus inconnu", id) return end
    M.stock[id] = (M.stock[id] or 0) + 1
    O.afficher("Bonus en reserve : " .. parId[id].nom .. " (" .. M.stock[id] .. ")")
end

function M.utiliser()
    local b = M.liste[selection]
    if (M.stock[b.id] or 0) <= 0 then
        O.afficher("Pas de " .. b.nom .. " en reserve", 3.0)
        return
    end
    if not O.enPartie() then return end
    if not S.peutAgir() then
        O.afficher("Pas maintenant !", 2.0)
        return
    end
    M.stock[b.id] = M.stock[b.id] - 1
    M.utilises[b.id] = (M.utilises[b.id] or 0) + 1
    local ok, err = pcall(b.f)
    if ok and b.son then O.son(b.son) end
    O.afficher(b.nom .. " !  (reste " .. M.stock[b.id] .. ")", 3.0)
    if not ok then O.log("erreur bonus", b.nom, tostring(err)) end
    if M.surUtilisation then pcall(M.surUtilisation, b.id) end
end

-- Utilise le bonus numero i de la liste (roue, raccourcis)
function M.choisir(i)
    selection = i
    M.utiliser()
end

return M
