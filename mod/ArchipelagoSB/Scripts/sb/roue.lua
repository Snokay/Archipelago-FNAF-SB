-- Roue des bonus. Clavier : G ouvre, clic utilise, G referme sans rien utiliser.
-- Manette : fleche bas maintenue, on vise au stick droit, on relache stick pousse pour utiliser.
-- Le temps ralentit pendant que la roue est ouverte ; l'objectif est rappele sous la roue.
local O = require("sb.outils")
local S = require("sb.securite")
local B = require("sb.bonus")
local H = require("sb.hud")
local M = {}

M.RALENTI = 0.25   -- vitesse du jeu pendant que la roue est ouverte
M.RAYON = 300      -- distance des cases au centre (unites d'ecran)

local roue, cases, survol, ouverte = nil, {}, nil, false
local clicAvant = false
local sourisAvant = nil   -- la souris ne change la case visee que si elle bouge (sinon le stick decide)
local stickAvant = false

-- widgets detruits avec le niveau : ne pas les relire apres un chargement
O.surChargement[#O.surChargement + 1] = function()
    roue, cases, survol, ouverte = nil, {}, nil, false
end

local function pc() return FindFirstOf("MainGamePC_C") end

local function ecran()
    local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
    local p = pc()
    local souris = wll:GetMousePositionOnViewport(p)
    local taille = wll:GetViewportSize(p)
    local echelle = wll:GetViewportScale(p)
    return souris.X, souris.Y, taille.X / echelle / 2, taille.Y / echelle / 2
end

local function axe(nom)
    local v = 0
    pcall(function() v = pc():GetInputAnalogKeyState({KeyName = FName(nom)}) end)
    return v or 0
end

local function appuye(nom)
    local v = false
    pcall(function() v = pc():IsInputKeyDown({KeyName = FName(nom)}) end)
    return v == true
end

local function caseAngle(dx, dy)
    local pas = 2 * math.pi / #B.liste
    local a = math.atan(dx, -dy)   -- 0 = en haut, sens horaire
    return math.floor(((a + 2 * math.pi + pas / 2) % (2 * math.pi)) / pas) + 1
end

-- Case visee : stick droit pousse ; stick qui revient au centre = plus rien ; sinon souris qui a bouge
local function caseVisee()
    local sx, sy = axe("Gamepad_RightX"), axe("Gamepad_RightY")
    local pousse = sx * sx + sy * sy > 0.5 * 0.5
    local relache = stickAvant and not pousse
    stickAvant = pousse
    if pousse then return caseAngle(sx, -sy) end
    if relache then return nil end
    local mx, my, cx, cy = ecran()
    local bouge = sourisAvant and (math.abs(mx - sourisAvant[1]) + math.abs(my - sourisAvant[2]) > 2)
    sourisAvant = {mx, my}
    if not bouge then return survol end
    local dx, dy = mx - cx, my - cy
    if dx * dx + dy * dy < 70 * 70 then return nil end
    return caseAngle(dx, dy)
end

local function aide(en)
    if H.modeManette then return en and "Aim with the right stick" or "Vise au stick droit" end
    return en and "Aim with the mouse" or "Vise avec la souris"
end

local function construire()
    local tree, C = H.arbre(), H.couleur
    local en = O.LANGUE == "en"
    local racine = H.creer("CanvasPanel", tree)
    racine:SetVisibility(3)   -- ne capte pas les clics : le jeu les voit (IsInputKeyDown)
    -- voile sombre sur tout l'ecran
    local voile = H.creer("Border", tree)
    voile:SetBrushColor(C(0, 0, 0, 0.55))
    local sv = racine:AddChildToCanvas(voile)
    sv:SetAnchors({Minimum = {X = 0, Y = 0}, Maximum = {X = 1, Y = 1}})
    sv:SetOffsets({Left = 0, Top = 0, Right = 0, Bottom = 0})

    -- centre : nom, description et stock du bonus vise ; largeur limitee, les textes longs vont a la ligne
    local centre = H.creer("VerticalBox", tree)
    local function ligne(t, taille, c)
        local w = H.texte(tree, t, taille, c)
        pcall(function() w:SetAutoWrapText(true) end)
        pcall(function() w:SetJustification(1) end)
        local sl = centre:AddChildToVerticalBox(w)
        sl:SetHorizontalAlignment(0)   -- toute la largeur, le texte se centre lui-meme
        sl:SetPadding({Left = 0, Top = 4, Right = 0, Bottom = 0})
        return w
    end
    local titre = ligne("BONUS", 22, C(1, 0.25, 0.8))
    local desc = ligne("", 16, C(1, 1, 1))
    local detail = ligne(aide(en), 14, C(0.75, 0.75, 0.85))
    local largeur = H.creer("SizeBox", tree)
    largeur:SetWidthOverride(380)
    largeur:SetContent(centre)
    local sc = racine:AddChildToCanvas(largeur)
    sc:SetAnchors({Minimum = {X = 0.5, Y = 0.5}, Maximum = {X = 0.5, Y = 0.5}})
    sc:SetAlignment({X = 0.5, Y = 0.5})
    sc:SetAutoSize(true)

    cases = {}
    local pas = 2 * math.pi / #B.liste
    for i, b in ipairs(B.liste) do
        local neon = C(b.neon[1], b.neon[2], b.neon[3])
        local stock = B.stock[b.id] or 0
        local cadre = H.creer("Border", tree)
        cadre:SetBrushColor(C(b.neon[1], b.neon[2], b.neon[3], 0.35))
        cadre:SetPadding({Left = 3, Top = 3, Right = 3, Bottom = 3})
        local fond = H.creer("Border", tree)
        fond:SetBrushColor(C(0.02, 0.0, 0.05, 0.9))
        fond:SetPadding({Left = 14, Top = 10, Right = 14, Bottom = 10})
        cadre:SetContent(fond)
        local col = H.creer("VerticalBox", tree)
        fond:SetContent(col)
        local tex
        for _, nom in ipairs(type(b.icone) == "table" and b.icone or {b.icone}) do
            tex = H.iconeObjet(nom)
            if tex then break end
        end
        tex = tex or H.texture("ap.png")
        if tex then
            local img = H.creer("Image", tree)
            img:SetBrushFromTexture(tex, false)
            local boite = H.creer("SizeBox", tree)
            boite:SetWidthOverride(72)
            boite:SetHeightOverride(72)
            boite:SetContent(img)
            col:AddChildToVerticalBox(boite):SetHorizontalAlignment(2)
        end
        col:AddChildToVerticalBox(H.texte(tree, "x" .. stock, 22, stock > 0 and neon or C(0.5, 0.5, 0.55)))
            :SetHorizontalAlignment(2)
        local sl = racine:AddChildToCanvas(cadre)
        sl:SetAnchors({Minimum = {X = 0.5, Y = 0.5}, Maximum = {X = 0.5, Y = 0.5}})
        sl:SetAlignment({X = 0.5, Y = 0.5})
        sl:SetAutoSize(true)
        local a = (i - 1) * pas
        sl:SetPosition({X = M.RAYON * math.sin(a), Y = -M.RAYON * math.cos(a)})
        if stock <= 0 then cadre:SetRenderOpacity(0.4) end
        cases[i] = {cadre = cadre, b = b, stock = stock}
    end

    -- rappel de l'objectif sous la roue (seul acces a l'objectif a la manette)
    local obj = H.creer("VerticalBox", tree)
    obj:AddChildToVerticalBox(H.texte(tree, en and "GOAL" or "OBJECTIF", 14, C(0.3, 0.9, 1.0))):SetHorizontalAlignment(2)
    for _, l in ipairs(H.lignesObjectif(en)) do
        obj:AddChildToVerticalBox(H.texte(tree, l.t, 15, l.fait and C(0.4, 1.0, 0.5) or C(1, 1, 1)))
            :SetHorizontalAlignment(2)
    end
    local so = racine:AddChildToCanvas(obj)
    so:SetAnchors({Minimum = {X = 0.5, Y = 0.5}, Maximum = {X = 0.5, Y = 0.5}})
    so:SetAlignment({X = 0.5, Y = 0})
    so:SetAutoSize(true)
    so:SetPosition({X = 0, Y = M.RAYON + 110})

    local sr = H.canvas():AddChildToCanvas(racine)
    sr:SetAnchors({Minimum = {X = 0, Y = 0}, Maximum = {X = 1, Y = 1}})
    sr:SetOffsets({Left = 0, Top = 0, Right = 0, Bottom = 0})
    return racine, titre, detail, desc
end

local function surligner(i, titre, detail, desc)
    if i == survol then return end
    local C, en = H.couleur, O.LANGUE == "en"
    if survol and cases[survol] then
        local c = cases[survol]
        c.cadre:SetBrushColor(C(c.b.neon[1], c.b.neon[2], c.b.neon[3], 0.35))
        c.cadre:SetRenderScale({X = 1, Y = 1})
    end
    survol = i
    if i and cases[i] then
        local c = cases[i]
        c.cadre:SetBrushColor(C(c.b.neon[1], c.b.neon[2], c.b.neon[3], 1))
        c.cadre:SetRenderScale({X = 1.15, Y = 1.15})
        titre:SetText(FText(c.b.nom))
        titre:SetColorAndOpacity({SpecifiedColor = C(c.b.neon[1], c.b.neon[2], c.b.neon[3]), ColorUseRule = 0})
        desc:SetText(FText(c.b.desc and c.b.desc[en and 2 or 1] or ""))
        local action
        if H.modeManette then action = en and "Release D-pad down to use" or "Relâche flèche bas pour utiliser"
        else action = en and "Click to use, G to close" or "Clic pour utiliser, G pour fermer" end
        detail:SetText(FText(c.stock > 0 and (action .. (en and "  -  left: " or "  -  reste ") .. c.stock)
            or (en and "None in reserve" or "Aucun en réserve")))
    else
        titre:SetText(FText("BONUS"))
        titre:SetColorAndOpacity({SpecifiedColor = C(1, 0.25, 0.8), ColorUseRule = 0})
        desc:SetText(FText(""))
        detail:SetText(FText(aide(en)))
    end
end

local function modeSouris(actif)
    local p = pc()
    local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    p.bShowMouseCursor = actif and not H.modeManette
    pcall(function() p:SetIgnoreLookInput(actif) end)
    if not actif then pcall(function() p:ResetIgnoreLookInput() end) end
    if actif then
        pcall(function() wbl:SetInputMode_GameAndUIEx(p, nil, 0, false) end)
    else
        pcall(function() wbl:SetInputMode_GameOnly(p) end)
    end
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    pcall(function() gs:SetGlobalTimeDilation(p, actif and M.RALENTI or 1.0) end)
end

function M.fermer(utiliser)
    if not ouverte then return end
    ouverte = false
    local choix = survol
    if roue and roue:IsValid() then roue:RemoveFromParent() end
    roue, survol = nil, nil
    modeSouris(false)
    if utiliser and choix then B.choisir(choix) end
end

function M.ouvrir()
    if ouverte or not O.enPartie() then return end
    if not S.peutAgir() then O.afficher(O.LANGUE == "en" and "Not now!" or "Pas maintenant !", 2.0) return end
    if not H.support() then return end
    H.fermerBienvenue()
    local racine, titre, detail, desc = construire()
    roue, ouverte, survol, sourisAvant, stickAvant = racine, true, nil, nil, false
    modeSouris(true)
    clicAvant = true   -- ignore un clic deja enfonce a l'ouverture
    local pas = 0
    local function suivre()
        if not ouverte or roue ~= racine then return end
        pas = pas + 1
        racine:SetRenderOpacity(math.min(1, pas / 10))
        local ok, i = pcall(caseVisee)
        if ok then surligner(i, titre, detail, desc) end
        local clic = appuye("LeftMouseButton")
        if clic and not clicAvant and survol then M.fermer(true) return end
        clicAvant = clic
        -- un screamer ou une scene arrive pendant que la roue est ouverte : on la referme
        if not S.peutAgir() then M.fermer(false) return end
        O.apres(16, suivre)
    end
    suivre()
end

-- G ouvre, et referme SANS utiliser (seul le clic utilise : la souris peut etre restee sur une case)
function M.basculer()
    if ouverte then M.fermer(false) else M.ouvrir() end
end

O.touche(Key.G, M.basculer)

-- Surveillance dans le fil du jeu (20 fois par seconde) : fleche bas de la manette (seule touche libre en
-- exploration, haut/gauche/droite = objets) et dernier peripherique utilise, pour les icones de touches.
-- Rien pendant les chargements (controleur absent ou en destruction, Gregory pas controle) ; peu d'appels
-- par passage : en mode clavier on ne regarde que la manette, et inversement.
local maintenu, carteFermee = false, false
-- touches preparees une fois (pas de FName recree 20 fois par seconde)
local TOUCHES = {}
for _, nom in ipairs({"Gamepad_DPad_Down", "Gamepad_RightX", "Gamepad_RightY", "Gamepad_LeftY", "W", "Z",
                      "LeftMouseButton"}) do
    TOUCHES[nom] = {KeyName = FName(nom)}
end
local tour = 0
LoopInGameThreadWithDelay(50, function()
    -- roue fermee : une verification sur deux suffit (100 ms pour sentir l'appui)
    tour = tour + 1
    if not ouverte and tour % 2 == 0 then return end
    local ok, err = pcall(function()
        if not O.stable then
            if not ouverte then maintenu = false end
            return
        end
        local p = pc()
        if not p or not p:IsValid() or O.supprime(p) or not O.gregoryRendu() then
            if not ouverte then maintenu = false end
            return
        end
        local function touche(nom)
            local okT, v = pcall(p.IsInputKeyDown, p, TOUCHES[nom])
            return okT and v == true
        end
        local function analogique(nom)
            local okT, v = pcall(p.GetInputAnalogKeyState, p, TOUCHES[nom])
            return okT and tonumber(v) or 0
        end
        local bas = touche("Gamepad_DPad_Down")
        local sx, sy = analogique("Gamepad_RightX"), analogique("Gamepad_RightY")
        local pousse = sx * sx + sy * sy > 0.5 * 0.5

        if H.modeManette then
            if not bas and not pousse and (touche("W") or touche("Z") or touche("LeftMouseButton")) then
                H.changerMode(false)
            end
        elseif bas or pousse or math.abs(analogique("Gamepad_LeftY")) > 0.5 then
            H.changerMode(true)
        end

        if bas and not maintenu then
            maintenu = true
            -- la carte de bienvenue ouverte se ferme d'abord (sans ouvrir la roue)
            if H.bienvenueOuverte() then H.fermerBienvenue() carteFermee = true
            elseif not ouverte then M.ouvrir() end
        elseif not bas and maintenu then
            maintenu = false
            if carteFermee then carteFermee = false
            elseif ouverte then M.fermer(pousse) end
        end
    end)
    if not ok then O.log("erreur surveillance manette", tostring(err)) end
end)

return M
