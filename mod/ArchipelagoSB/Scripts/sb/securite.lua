-- Porte de securite : un piege ou un DeathLink ne part qu'a un moment sur, et un seul a la fois.
-- Chaque regle ici vient d'un bug vecu en test (softlock, ecran noir, joueur sans corps...).
local O = require("sb.outils")
local M = {}

local REPIT_MORT = 8   -- s apres l'ecran de mort : le jeu recharge encore (screamer sans camera sinon)
local MARGE = 3        -- s sures d'affilee avant de partir (une scene enchaine plusieurs morceaux)
M.DUREE_SCREAMER = 8   -- s entre deux screamers (le jeu refuse un screamer juste apres un autre)

local derniereMort = nil
local verrou = nil
M.restes = {}          -- JumpscarePawn qu'on a supprimes : encore en memoire un moment, a ignorer
M.surMort = {}         -- fonctions appelees a chaque mort

function M.verrouiller() verrou = os.time() end

O.hook("/Game/Blueprints/UI/GameOverUI.GameOverUI_C:Construct", function()
    derniereMort = os.time()
    for _, f in ipairs(M.surMort) do pcall(f) end
end)

function M.momentSur()
    for _, w in ipairs(FindAllOf("GameOverUI_C") or {}) do
        local ok, vu = pcall(function() return w:IsValid() and w:IsInViewport() end)
        if ok and vu then derniereMort = os.time() return false, "ecran de mort" end
    end
    if derniereMort and os.time() - derniereMort < REPIT_MORT then return false, "reapparition" end
    if verrou and os.time() - verrou < M.DUREE_SCREAMER then return false, "piege precedent" end
    local g = O.gregory()
    if not g then return false, "pas de Gregory" end
    -- Garderie : les animatroniques n'y vont jamais (Sun/Moon seulement). Alerte puis screamer avec Chica
    -- en pleine garderie = plantage du jeu (25/10). Boite tiree des checks et portes de la garderie.
    local okP, pos = pcall(function() return g:K2_GetActorLocation() end)
    if okP and pos and pos.X > -22000 and pos.X < -11600 and pos.Y > 26000 and pos.Y < 40000
            and pos.Z > 500 and pos.Z < 2800 then
        return false, "garderie"
    end
    local pc = FindFirstOf("MainGamePC_C")
    if not pc or not pc:IsValid() then return false, "pas de controleur" end
    if pc["IsPlaySequenceRunning?"] == true then return false, "cinematique" end
    -- Le drapeau repasse a faux entre deux morceaux d'une scene : on regarde aussi la scene en cours
    -- (un screamer pendant que Freddy portait Gregory a bloque l'histoire pour de bon)
    local okH, joue = pcall(function()
        local sp = pc.CinematicSequenceHandler.CurrentSequencePlayer
        return sp:IsValid() and sp:IsPlaying()
    end)
    if okH and joue then return false, "cinematique" end
    local okA, parent = pcall(function()
        local p = g:GetAttachParentActor()
        return p and p:IsValid()
    end)
    if okA and parent then return false, "Gregory accroche" end
    -- Dans Freddy, une camera ou un screamer : on attend (jamais d'ejection, une scene avec Freddy peut etre obligatoire)
    if not O.gregoryRendu() then return false, "Gregory pas controle" end
    for _, p in ipairs(FindAllOf("JumpscarePawn_C") or {}) do
        local okC, possede = pcall(function() return p.Controller ~= nil and p.Controller:IsValid() end)
        if p:IsValid() and not M.restes[p:GetFullName()] and (not okC or possede) then
            return false, "screamer en cours"
        end
    end
    return true
end

-- Pour les bonus : le joueur controle Gregory, hors cinematique et hors screamer (un choc pendant un
-- screamer cassait tout). Plus souple que momentSur : pas d'attente apres une mort ou un piege.
function M.peutAgir()
    local pc = FindFirstOf("MainGamePC_C")
    if not pc or not pc:IsValid() or pc["IsPlaySequenceRunning?"] == true then return false end
    if not O.gregoryRendu() then return false end
    for _, p in ipairs(FindAllOf("JumpscarePawn_C") or {}) do
        local okC, possede = pcall(function() return p.Controller ~= nil and p.Controller:IsValid() end)
        if p:IsValid() and not M.restes[p:GetFullName()] and (not okC or possede) then return false end
    end
    return true
end

-- File d'attente : chaque action attend son moment sur, puis la suivante passe
local file = {}
local occupe = false

local function suivante()
    if occupe or #file == 0 then return end
    occupe = true
    local action = table.remove(file, 1)
    local suite, dernierMotif = 0, nil
    local function essai(premier)
        local sur, motif = M.momentSur()
        suite = sur and suite + 1 or 0
        if sur and (premier or suite > MARGE) then
            O.log("PART", action.nom)
            local ok, err = pcall(action.f)
            if not ok then O.log("erreur", action.nom, tostring(err)) end
            O.apres(1000, function() occupe = false suivante() end)
            return
        end
        if not sur and motif ~= dernierMotif then O.log("ATTENTE", action.nom, ":", motif) end
        dernierMotif = sur and nil or motif
        O.apres(1000, function() essai(false) end)
    end
    essai(true)
end

-- prioritaire : passe devant (DeathLink)
function M.ajouter(nom, f, prioritaire)
    if prioritaire then table.insert(file, 1, {nom = nom, f = f}) else file[#file + 1] = {nom = nom, f = f} end
    suivante()
end

function M.enAttente() return #file + (occupe and 1 or 0) end

return M
