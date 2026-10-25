-- Fins : chaque fin joue sa video, on la reconnait au nom du fichier (LoadingDockEnding-Full_8.mp4...)
local O = require("sb.outils")
local M = {}

M.surFin = nil   -- fonction(fin), posee par le client (goal)

O.hook("/Game/Cinematics/EndGameCinematicPlayerUI.EndGameCinematicPlayerUI_C:OnMediaOpened", function(self, url)
    local fichier = O.s(url):match("([^/\\]+)%.mp4$") or O.s(url)
    local fin = fichier:gsub("%-Full_%d+$", "")
    O.log("FIN", fin)
    if M.surFin then pcall(M.surFin, fin) end
end)

return M
