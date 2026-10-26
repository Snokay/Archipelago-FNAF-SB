-- TEST (26/10) : valider une mission quand l'objet AP est recu. Mission suivie : DJMusicMan ("Reparez la tete
-- de robot"). Touches : ( etat de la mission ; - valide sa prochaine etape (CompleteMissionTask) ; è avance
-- l'etat d'avancement (SetMissionInfoState, ce que lisent les MissionStateCondition du decor).
-- Les hooks journalisent ce que fait le jeu (etapes, avancement, missions), ex. au ramassage de la vraie tete.
local O = require("sb.outils")

local MISSION = "DJMusicMan"

O.hook("/Script/fnaf9.FNAFMissionSystem:CompleteMissionTask", function(self, mission, idx)
    O.log("SONDE etape finie :", O.s(mission), "etape", tostring(idx:get()))
end)
O.hook("/Script/fnaf9.FNAFMissionSystem:SetMissionInfoState", function(self, mission, n)
    O.log("SONDE avancement :", O.s(mission), "->", tostring(n:get()))
end)
O.hook("/Script/fnaf9.FNAFMissionSystem:AddActiveMission", function(self, mission)
    local nom = O.s(mission)
    if nom ~= "None" then O.log("SONDE mission active :", nom) end
end)
O.hook("/Script/fnaf9.FNAFMissionSystem:CompleteMission", function(self, mission)
    O.log("SONDE mission finie :", O.s(mission))
end)

-- {avancement, etapes} ou nil + erreur
local function lire(ms)
    local etat, valide = {}, {}
    ms:GetMissionState(FName(MISSION), etat, valide)
    local champs = {}
    for k, v in pairs(etat) do champs[#champs + 1] = tostring(k) .. ":" .. type(v) end
    O.log("SONDE champs lus :", table.concat(champs, " "))
    local info = etat.InfoState
    if type(info) == "userdata" then info = info:get() end
    local faites = {}
    pcall(function()
        local t = etat.CompletedTasks
        if type(t) == "userdata" and t.get then t = t:get() end
        if type(t) == "table" then
            for _, v in ipairs(t) do faites[#faites + 1] = type(v) == "userdata" and v:get() or v end
        else
            t:ForEach(function(_, v) faites[#faites + 1] = v:get() end)
        end
    end)
    return info, faites
end

local function etat()
    local ms = FindFirstOf("FNAFMissionSystem")
    local active, finie = ms:IsActiveMission(FName(MISSION)), ms:IsCompletedMission(FName(MISSION))
    local ok, info, faites = pcall(lire, ms)
    local msg
    if ok then
        msg = string.format("%s active=%s finie=%s avancement=%s etapes=[%s]", MISSION, tostring(active),
            tostring(finie), tostring(info), table.concat(faites, ","))
    else
        msg = string.format("%s active=%s finie=%s (lecture impossible : %s)", MISSION, tostring(active),
            tostring(finie), tostring(info))
    end
    msg = msg .. string.format(" tete abimee=%s reparee=%s", tostring(O.possede("DamagedHead")),
        tostring(O.possede("FixedHead")))
    local ms2 = FindFirstOf("FNAFMissionSystem")
    msg = msg .. string.format(" | RoxysWeakness active=%s finie=%s", tostring(ms2:IsActiveMission(FName("RoxysWeakness"))),
        tostring(ms2:IsCompletedMission(FName("RoxysWeakness"))))
    O.log("SONDE", msg)
    O.afficher(msg, 6)
    return ok and info or nil, ok and faites or {}
end

local function etapeSuivante()
    local _, faites = etat()
    local vues, n = {}, 0
    for _, v in ipairs(faites) do vues[v] = true end
    while vues[n] do n = n + 1 end
    O.log("SONDE validation de l'etape", n, "de", MISSION)
    FindFirstOf("FNAFMissionSystem"):CompleteMissionTask(FName(MISSION), n)
    O.apres(500, etat)
end

local function avancer()
    local info = etat()
    local n = (tonumber(info) or 0) + 1
    O.log("SONDE avancement force a", n, "pour", MISSION)
    FindFirstOf("FNAFMissionSystem"):SetMissionInfoState(FName(MISSION), n)
    O.apres(500, etat)
end

-- _ : donne la tete abimee comme une reception AP (sans ramassage) ; ç : la retire
local Ob = require("sb.objets")
local function donnerTete()
    O.log("SONDE tete donnee comme par AP")
    Ob.donneParMod = true
    pcall(function() O.inv():AwardItem(FName("DamagedHead"), true) end)
    Ob.donneParMod = false
    Ob.recus["DamagedHead"] = true  -- comme une vraie reception AP
    O.apres(4000, etat)
end
local function retirerTete()
    O.retirer("DamagedHead")
    O.log("SONDE tete retiree")
    O.apres(500, etat)
end

-- à : retire "Le point faible de Roxy" des missions actives (avant de ramasser la tete : le jeu ignore-t-il
-- alors sa fin ?) ; ) : la termine, comme le ferait une reception AP
local ROXY = "RoxysWeakness"
local function etatRoxy()
    local ms = FindFirstOf("FNAFMissionSystem")
    local msg = string.format("%s active=%s finie=%s", ROXY, tostring(ms:IsActiveMission(FName(ROXY))),
        tostring(ms:IsCompletedMission(FName(ROXY))))
    O.log("SONDE", msg)
    O.afficher(msg, 6)
end
local function retirerRoxy()
    FindFirstOf("FNAFMissionSystem"):RemoveActiveMission(FName(ROXY))
    O.log("SONDE", ROXY, "retiree des missions actives")
    O.apres(500, etatRoxy)
end
local function terminerRoxy()
    FindFirstOf("FNAFMissionSystem"):CompleteMission(FName(ROXY))
    O.log("SONDE", ROXY, "terminee par le mod")
    O.apres(500, function() etatRoxy() O.apres(2000, etat) end)
end

-- = : liste les reglages et fonctions de la tete posee au sol (classe et parents jusqu'a Collectible_C)
local function dissequerTete()
    local a = FindFirstOf("CollectibleStaffbotHead_C")
    if not a or not a:IsValid() then O.afficher("SONDE : pas de tete au sol ici", 4) return end
    local classe = a:GetClass()
    local n = 0
    while classe and classe:IsValid() do
        local nomClasse = classe:GetFName():ToString()
        pcall(function()
            classe:ForEachProperty(function(p)
                local nom = p:GetFName():ToString()
                local ok, v = pcall(function() return O.s(a[nom]) end)
                O.log("SONDE TETE", nomClasse, "reglage", nom, "=", ok and tostring(v) or "?")
                n = n + 1
            end)
        end)
        pcall(function()
            classe:ForEachFunction(function(f)
                O.log("SONDE TETE", nomClasse, "fonction", f:GetFName():ToString())
                n = n + 1
            end)
        end)
        if nomClasse == "Collectible_C" then break end
        classe = classe:GetSuperStruct()
    end
    O.afficher("SONDE : tete dissequee (" .. n .. " lignes au journal)", 4)
end

-- ù : mode AP simule sans serveur, tete pas encore recue (pour tester missions_objets.lua)
local function simulerAP()
    require("sb.ramassage").modeAP = true
    Ob.recus["DamagedHead"] = nil
    O.log("SONDE mode AP simule, tete non recue")
    O.afficher("SONDE : mode AP simule, tete non recue", 4)
end

O.touche(Key.OEM_THREE, simulerAP)
O.touche(Key.OEM_PLUS, dissequerTete)
O.touche(Key.ZERO, retirerRoxy)
O.touche(Key.OEM_FOUR, terminerRoxy)
O.touche(Key.EIGHT, donnerTete)
O.touche(Key.NINE, retirerTete)
O.touche(Key.FIVE, etat)
O.touche(Key.SIX, etapeSuivante)
O.touche(Key.SEVEN, avancer)
