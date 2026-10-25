-- Deblocage (F10, deux appuis) : une scene qui ne se termine jamais laisse le jeu "en cinematique"
-- (barrieres fermees, pieges en attente). Le 2e appui termine la scene et le signale au jeu.
local O = require("sb.outils")
local M = {}

local arme = false
function M.debloquer()
    local pc = FindFirstOf("MainGamePC_C")
    local scenes = {}
    for _, p in ipairs(FindAllOf("LevelSequencePlayer") or {}) do
        pcall(function()
            if p:IsValid() and p:IsPlaying() then scenes[#scenes + 1] = p end
        end)
    end
    if not arme then
        arme = true
        O.log("DEBLOCAGE : cinematique=" .. tostring(pc["IsPlaySequenceRunning?"]) .. ", " .. #scenes ..
            " scene(s) en cours. Rappuie sur F10 pour debloquer.")
        return
    end
    arme = false
    for _, p in ipairs(scenes) do pcall(function() p:GoToEndAndStop() end) end
    local h = pc.CinematicSequenceHandler
    pcall(function() local sp = h.CurrentSequencePlayer if sp:IsValid() then sp:GoToEndAndStop() end end)
    pcall(function() h["On Sequence Finished"](h) end)
    pcall(function() pc:SetIsPlaySequenceRunning(false) end)
    O.log("DEBLOCAGE fait : cinematique=" .. tostring(pc["IsPlaySequenceRunning?"]))
end

O.touche(Key.F10, M.debloquer)

return M
