-- Blague secrete, jamais annoncee : le screamer du MapBot (connu pour etre nul) est remplace par un vrai.
local Sc = require("sb.screamer")

local fait = false
Sc.surMapBot = function()
    if fait then return end
    fait = true
    Sc.annulerScreamer(function() Sc.lancer(false, true) end)
end
