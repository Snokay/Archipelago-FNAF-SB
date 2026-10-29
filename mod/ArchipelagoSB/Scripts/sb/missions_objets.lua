-- Objets qui font avancer l'histoire quand on les ramasse (pass coulisses, tete abimee, Mystery Mix...). En
-- archi, c'est la reception de l'objet qui doit le faire, pas le ramassage : sinon un objet parti dans un autre
-- monde fait avancer l'histoire sans etre la, et un objet recu sans ramassage la laisse bloquee.
-- Ramassage : on vide les reglages de mission des ramassables poses (il ne reste que le check). Le crochet
-- "OnPlayerHoverEnter" ne passait pas pour la tete (test 26/10) : recherche ciblee sur leur classe.
-- Reception : on rejoue les actions du ramassage, dans l'ordre. Terminer ou faire avancer une mission attend
-- qu'elle soit active (le moment ou on ramasserait l'objet dans le jeu de base).
-- Valeurs lues dans les Blueprints des objets (sonde, 26/10).
local O = require("sb.outils")
local Ob = require("sb.objets")
local R = require("sb.ramassage")

-- objet -> classe du ramassable, reglages a vider (champs de l'acteur, composants UpdateMissionComponent) et
-- actions du ramassage : {mission, "terminer" | "demarrer" | avancement}
local LIEES = {
    DamagedHead = {classe = "CollectibleStaffbotHead_C", apresShowtime = true, champs = {"End Mission Name", "Start Mission Name"},
        actions = {{"RoxysWeakness", "terminer"}, {"DJMusicMan", "demarrer"}}},
    BackstagePass = {classe = "BackstagePass_C", composants = {"UpdateMissionOnCollect", "UpdateBackstageMission"},
        lieu = "MAP_Backstage_RehearsalRoom:BackstagePass_2", actions = {{"RehearsalSpace", "terminer"}, {"Backstage", "demarrer"}}},
    PartyPassChicaRoom = {classe = "ChicaGreenroomCollectible_C", apresShowtime = true,
        lieu = "MAP_Backstage_Gameplay:ChicaGreenroomCollectible_4",
        composants = {"UpdateMission_PartyPass", "UpdateMission_MoonlightSerenade"},
        actions = {{"PartyPass", "terminer"}, {"MoonlightSerenade", "demarrer"}}},
    MontyMysteryMix = {classe = "MontyMysteryMix_C", apresShowtime = true, composants = {"UpdateMissionOnCollect"},
        actions = {{"MontyMysteryMix", 1}}},
    MazerciseControlKey = {classe = "MazerciseControlKey_C", apresShowtime = true, composants = {"UpdateMissionOnCollect"},
        actions = {{"ThrillSeeker", 3}}},
    PhotoPass = {classe = "PhotoPassCollectible_C", champs = {"MissionToUpdate"}, composants = {"UpdateMissionOnCollect"},
        actions = {{"FreeFreddy", 3}}},
}

local AUCUNE = "None"

-- Terminer une mission fait passer l'heure, et le jeu lance Moon : au mauvais moment (Freddy casse dans le
-- couloir de la salle de repetition, Yochix 27/10) c'etait la mort en boucle. Les objets d'apres les coulisses
-- attendent donc la fin de Showtime (Freddy de nouveau la).
-- Pass coulisses et billet de la loge de Chica : leur mission s'active en chemin (couloir du Freddy casse) ;
-- recus tot, ils la terminaient sur place -> Moon en boucle (Yochix 27/10 et 29/10, malgre un rayon de
-- 1500 u autour du pass). Ils attendent que leur emplacement d'origine soit ouvert : Gregory est alle dans
-- la salle (ou l'objet arrive apres, une fois la mission en attente).

local function moment(ms, m)
    if m.apresShowtime and not ms:IsCompletedMission(FName("Showtime")) then return false end
    if m.lieu and not R.estFait(m.lieu) then return false end
    return true
end

-- Seeds d'avant (objet laisse a sa place, slot_data "garder") : le jeu de base s'en occupe
local function gere(objet) return R.modeAP and not R.garde(objet) end

local function vider(a, objet, cible, champ)
    local ok, v = pcall(function() return O.s(cible[champ]) end)
    if ok and v ~= "nil" and v ~= AUCUNE then
        cible[champ] = FName(AUCUNE)
        O.log("ramassage sans effet sur l'histoire :", objet, champ, v)
    end
end

local function neutraliser(a, objet, m)
    for _, champ in ipairs(m.champs or {}) do vider(a, objet, a, champ) end
    for _, nom in ipairs(m.composants or {}) do
        local c = a[nom]
        if c and c:IsValid() then vider(a, objet, c, "MissionName") end
    end
end

O.boucle(3000, function()
    if not R.modeAP or not O.enPartie() then return end
    for objet, m in pairs(LIEES) do
        if gere(objet) then
            for _, a in ipairs(FindAllOf(m.classe) or {}) do
                if a:IsValid() then
                    local ok, err = pcall(neutraliser, a, objet, m)
                    if not ok then O.log("ramassable non neutralise :", m.classe, tostring(err)) end
                end
            end
        end
    end
end)

local function avancement(ms, mission)
    local etat, valide = {}, {}
    ms:GetMissionState(FName(mission), etat, valide)
    local n = etat.InfoState
    if type(n) == "userdata" then n = n:get() end
    return tonumber(n) or 0
end

-- vrai si l'action est faite (ou n'a plus lieu d'etre), faux si elle attend que la mission soit active
local function jouer(ms, objet, mission, action)
    local nom = FName(mission)
    if ms:IsCompletedMission(nom) then return true end
    if action == "demarrer" then
        if not ms:IsActiveMission(nom) then
            ms:AddActiveMission(nom)
            O.log("recu", objet, ": mission demarree", mission)
        end
        return true
    end
    if not ms:IsActiveMission(nom) then return false end
    if action == "terminer" then
        ms:CompleteMission(nom)
        O.log("recu", objet, ": mission terminee", mission)
    elseif avancement(ms, mission) < action then
        ms:SetMissionInfoState(nom, action)
        O.log("recu", objet, ": mission", mission, "a l'avancement", action)
    end
    return true
end

local finis = {}  -- objet -> toutes ses actions jouees (cette session)
O.boucle(3000, function()
    if not R.modeAP or not O.enPartie() then return end
    local ms = FindFirstOf("FNAFMissionSystem")
    if not ms or not ms:IsValid() then return end
    for objet, m in pairs(LIEES) do
        if Ob.recus[objet] and not finis[objet] and gere(objet) and moment(ms, m) then
            local tout = true
            for _, a in ipairs(m.actions) do
                local ok, fait = pcall(jouer, ms, objet, a[1], a[2])
                if not ok then O.log("action impossible :", objet, a[1], tostring(fait)) end
                if not (ok and fait) then tout = false break end
            end
            finis[objet] = tout
        end
    end
end)
O.surChargement[#O.surChargement + 1] = function() finis = {} end
