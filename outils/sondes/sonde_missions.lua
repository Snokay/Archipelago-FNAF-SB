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

O.touche(Key.FIVE, etat)
O.touche(Key.SIX, etapeSuivante)
O.touche(Key.SEVEN, avancer)
