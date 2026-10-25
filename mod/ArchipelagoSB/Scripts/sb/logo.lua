-- Logo Security Breach Archipelago a la place du logo du jeu (et de celui de Ruin) : ecran de lancement
-- (WI_SplashScreen), ecran "appuie sur une touche" et menu principal (TitleUI).
-- Remplace a la creation de chaque image (NotifyOnNewObject : avant son premier affichage, l'ecran de
-- lancement passe trop vite pour une boucle), plus un filet hors partie pour les ecrans qui remettent leur
-- logo eux-memes. Pas de hook sur les Blueprints du menu : accroches au menu, ils faisaient planter le jeu
-- au chargement de la partie.
local O = require("sb.outils")
local H = require("sb.hud")

local LOGOS = {SBLogo_LogoWithText = true, RuinLogo_LogoWithText = true, Logo_Ruin = true}

local function remplacer(img)
    local res = img.Brush.ResourceObject
    if not res or not res:IsValid() or not LOGOS[res:GetFName():ToString()] then return end
    local tex = H.texture("logo_menu.png", img)
    if tex then img:SetBrushFromTexture(tex, false) end
end

-- Seulement au menu ou sur l'ecran de lancement (jamais pendant un chargement ni en partie : toucher aux
-- images pendant le chargement d'un niveau faisait planter le jeu)
local function auMenu()
    -- en partie : sortie immediate (le hook voit passer chaque image creee, Fazwatch comprise)
    if O.chargement or O.stable then return false end
    for _, c in ipairs({"TitlePC_C", "SplashPC_C"}) do
        local pc = FindFirstOf(c)
        if pc and pc:IsValid() and not O.supprime(pc) then return true end
    end
    return false
end

NotifyOnNewObject("/Script/UMG.Image", function(img)
    if O.stable then return end
    -- seulement sur le fil du jeu (un objet cree pendant un chargement l'est sur le fil de chargement)
    local okT, jeu = pcall(IsInGameThread)
    if okT and jeu and auMenu() then pcall(remplacer, img) end
end)

LoopInGameThreadWithDelay(500, function()
    if not auMenu() then return end
    for _, img in ipairs(FindAllOf("Image") or {}) do
        if img:IsValid() then pcall(remplacer, img) end
    end
end)

return {}
