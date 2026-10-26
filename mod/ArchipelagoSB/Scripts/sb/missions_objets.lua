-- Objets qui font avancer l'histoire quand on les ramasse (la tete abimee termine "Le point faible de Roxy" et
-- demarre "Reparez la tete de robot"). En archi, c'est la reception de l'objet qui doit le faire, pas le
-- ramassage : sinon un objet parti dans un autre monde fait avancer l'histoire sans etre la, et un objet recu
-- sans ramassage la laisse bloquee.
-- Ramassage : on vide les reglages de mission des ramassables poses (il ne reste que le check). Le crochet
-- "OnPlayerHoverEnter" ne passait pas pour la tete (test 26/10) : recherche ciblee sur leur classe.
-- Reception : on fait nous-memes ce qu'aurait fait le ramassage (deja fait : rien ne change).
local O = require("sb.outils")
local Ob = require("sb.objets")
local R = require("sb.ramassage")

-- objet -> classe du ramassable et missions de son ramassage (ses reglages "End/Start Mission Name")
local LIEES = {
    DamagedHead = {classe = "CollectibleStaffbotHead_C", fin = "RoxysWeakness", debut = "DJMusicMan"},
}

local AUCUNE = "None"

local function neutraliser(a)
    for _, champ in ipairs({"End Mission Name", "Start Mission Name"}) do
        local ok, v = pcall(function() return O.s(a[champ]) end)
        if ok and v ~= "nil" and v ~= AUCUNE then
            a[champ] = FName(AUCUNE)
            O.log("ramassage sans effet sur l'histoire :", O.s(a.ItemName), champ, v)
        end
    end
end

local vus = {}
O.boucle(3000, function()
    if not R.modeAP or not O.enPartie() then return end
    for _, m in pairs(LIEES) do
        local trouves = FindAllOf(m.classe) or {}
        if vus[m.classe] ~= #trouves then
            vus[m.classe] = #trouves
            local a = trouves[1]
            local okF, f = pcall(function() return O.s(a["End Mission Name"]) end)
            O.log("ramassables", m.classe, ":", #trouves, "| fin =", okF and f or "illisible", tostring(not okF and f or ""))
        end
        for _, a in ipairs(trouves) do
            if a:IsValid() then
                local ok, err = pcall(neutraliser, a)
                if not ok then O.log("ramassable non neutralise :", m.classe, tostring(err)) end
            end
        end
    end
end)

O.boucle(3000, function()
    if not R.modeAP or not O.enPartie() then return end
    local ms = FindFirstOf("FNAFMissionSystem")
    if not ms or not ms:IsValid() then return end
    for objet, m in pairs(LIEES) do
        if Ob.recus[objet] then
            if m.fin and not ms:IsCompletedMission(FName(m.fin)) then
                ms:CompleteMission(FName(m.fin))
                O.log("recu", objet, ": mission terminee", m.fin)
            end
            if m.debut and not ms:IsCompletedMission(FName(m.debut)) and not ms:IsActiveMission(FName(m.debut)) then
                ms:AddActiveMission(FName(m.debut))
                O.log("recu", objet, ": mission demarree", m.debut)
            end
        end
    end
end)
