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
    -- ramassable le plus proche de Gregory (tete, cadeau, billet...)
    local g = O.gregory()
    local a, meilleur = nil, 1e12
    for _, classe in ipairs({"Collectible_C", "PresentCollectible_C", "CollectibleStaffbotHead_C"}) do
        for _, c in ipairs(FindAllOf(classe) or {}) do
            local ok, d = pcall(function() return O.dist2D(c:K2_GetActorLocation(), g:K2_GetActorLocation()) end)
            if ok and c:IsValid() and d < meilleur then a, meilleur = c, d end
        end
    end
    if not a then O.afficher("SONDE : aucun ramassable ici", 4) return end
    O.log("SONDE TETE ===", a:GetFullName(), "objet", O.s(a.ItemName), "distance", math.floor(meilleur))
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
    O.afficher("SONDE : ramassable dissequé (" .. n .. " lignes au journal)", 4)
end

-- ù : mode AP simule sans serveur, tete pas encore recue (pour tester missions_objets.lua)
local function simulerAP()
    require("sb.ramassage").modeAP = true
    Ob.recus["DamagedHead"] = nil
    O.log("SONDE mode AP simule, tete non recue")
    O.afficher("SONDE : mode AP simule, tete non recue", 4)
end

-- ^ : charge les classes des objets d'histoire et journalise leurs reglages par defaut (champs propres a la
-- classe, hors Collectible_C) et ceux de leurs composants (UpdateMission_... du billet de la loge de Chica)
local CLASSES = {"BackstagePass", "BowlingTicket", "ChicaGreenroomCollectible", "CollectibleStaffbotHead",
    "ComplimentaryPass", "DancePassCollectible", "FlashBeaconCollect", "InvisibleCollectible",
    "LaserGunCollectible_Prize", "MazerciseControlKey", "MazercizeTicket", "MontyMysteryMix", "MrHippoMagnet",
    "PhotoPassCollectible"}
local DOSSIER = "/Game/Blueprints/Objects/Collectibles/"

local function valeurs(objet, classe, prefixe)
    pcall(function()
        classe:ForEachProperty(function(p)
            local nom = p:GetFName():ToString()
            if nom ~= "UberGraphFrame" then
                local ok, v = pcall(function() return O.s(objet[nom]) end)
                O.log("SONDE CLASSE", prefixe, nom, "=", ok and tostring(v) or "?")
            end
        end)
    end)
end

local function classesObjets()
    for _, nom in ipairs(CLASSES) do
        local chemin = DOSSIER .. nom
        local essais = {}
        for _, cible in ipairs({chemin .. "." .. nom .. "_C", chemin .. "." .. nom}) do
            local ok, err = pcall(function() return LoadAsset(cible) end)
            essais[#essais + 1] = cible .. " -> " .. (ok and "ok" or tostring(err))
        end
        local classe = StaticFindObject(chemin .. "." .. nom .. "_C")
        local cdo = StaticFindObject(chemin .. ".Default__" .. nom .. "_C")
        if not classe or not classe:IsValid() or not cdo or not cdo:IsValid() then
            O.log("SONDE CLASSE", nom, ": introuvable |", table.concat(essais, " | "),
                "| classe", tostring(classe and classe:IsValid()), "cdo", tostring(cdo and cdo:IsValid()))
        else
            O.log("SONDE CLASSE ===", nom)
            valeurs(cdo, classe, nom)
            -- composants de mission (UpdateMissionComponent : MissionName, MissionStateIndex, bShouldComplete)
            local champs = {}
            pcall(function()
                classe:ForEachProperty(function(p)
                    local champ = p:GetFName():ToString()
                    if champ:find("ission") then champs[#champs + 1] = champ end
                end)
            end)
            for _, champ in ipairs(champs) do
                local ok, err = pcall(function()
                    local c = StaticFindObject(chemin .. "." .. nom .. "_C:" .. champ .. "_GEN_VARIABLE")
                    if not c or not c:IsValid() then error("modele introuvable") end
                    O.log("SONDE CLASSE", nom, "composant", champ, "| mission =", O.s(c.MissionName),
                        "| avancement =", tostring(c.MissionStateIndex), "| terminer =", tostring(c.bShouldComplete),
                        "| sauver =", tostring(c.bShouldSave))
                end)
                if not ok then O.log("SONDE CLASSE", nom, "composant", champ, "illisible :", tostring(err)) end
            end
            -- composants ajoutes dans le Blueprint (SimpleConstructionScript)
            pcall(function()
                local scs = classe.SimpleConstructionScript
                for _, n in ipairs(scs:GetAllNodes()) do
                    local noeud = n:get()
                    local modele = noeud.ComponentTemplate
                    if modele and modele:IsValid() then
                        local cc = modele:GetClass()
                        local nomC = cc:GetFName():ToString()
                        if nomC:find("ission") or modele:GetFName():ToString():find("ission") then
                            O.log("SONDE CLASSE", nom, "composant", modele:GetFName():ToString(), "(" .. nomC .. ")")
                            valeurs(modele, cc, nom .. "." .. modele:GetFName():ToString())
                        end
                    end
                end
            end)
        end
    end
    O.afficher("SONDE : classes des objets lues (journal)", 4)
end

O.touche(Key.OEM_SIX, classesObjets)
O.touche(Key.OEM_THREE, simulerAP)
O.touche(Key.OEM_PLUS, dissequerTete)
O.touche(Key.ZERO, retirerRoxy)
O.touche(Key.OEM_FOUR, terminerRoxy)
O.touche(Key.EIGHT, donnerTete)
O.touche(Key.NINE, retirerTete)
O.touche(Key.FIVE, etat)
O.touche(Key.SIX, etapeSuivante)
O.touche(Key.SEVEN, avancer)
