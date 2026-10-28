-- Pieges et DeathLink. Tout passe par la file de la porte de securite.
-- Pieges recus hors ligne : 1 a la connexion, le reste en reserve, 1 a chaque mort. Jeu relance = reserve oubliee.
local O = require("sb.outils")
local S = require("sb.securite")
local Sc = require("sb.screamer")
local M = {}

M.DUREE_BORNES = 300   -- s sans sauvegarde (option de l'apworld)

-- Alerte : Chica, Roxy et Monty foncent sur la position du joueur
local function alerte()
    local g = O.gregory()
    if not g then return end
    local ai = FindFirstOf("AIManagementSystem")
    local types = {}
    for t = 0, 2 do types[#types + 1] = {AIType = t, AISubType = O.sousType(t)} end
    ai:SendGeneralAlert(g:K2_GetActorLocation(), types, 3)
end

-- Bornes de sauvegarde en panne (glitch, comme quand Vanny les pirate) pendant DUREE_BORNES
local finBornes = nil

O.hook("/Game/Blueprints/UI/SaveGameUI.SaveGameUI_C:Construct", function(self)
    if not finBornes then return end
    local w = self:get()
    O.apres(50, function() w:RemoveFromParent() end)
end)

local function appliquerBornes(dispo)
    pcall(function() FindFirstOf("FNAFSaveGameSystem"):SetIsSavingAllowed(dispo) end)
    pcall(function() FindFirstOf("WorldStateSystem"):SetPowerStationAvailable(dispo) end)
    for _, b in ipairs(FindAllOf("SaveGameActor_C") or {}) do
        if b:IsValid() then
            local avant = b.Glitching
            b.IsActive = dispo
            b.Glitching = not dispo
            -- "Setup Display" du Blueprint change l'ecran (Helpy glitche a terre quand la borne est en panne)
            if avant ~= b.Glitching then pcall(function() b["Setup Display"](b) end) end
            if dispo then pcall(function() b.Play_sfx_saveStation_screen_glitch_lp:Stop() end) end
        end
    end
end

local function bornes()
    local deja = finBornes ~= nil
    finBornes = math.max(finBornes or 0, os.time()) + M.DUREE_BORNES
    if deja then return end
    -- Reappliquer toutes les 5 s : les bornes des zones chargees en route doivent aussi tomber en panne
    O.boucle(5000, function()
        local fini = os.time() >= finBornes
        ExecuteInGameThread(function()
            if fini then
                finBornes = nil
                appliquerBornes(true)
                O.log("bornes de sauvegarde reparees")
            else
                appliquerBornes(false)
            end
        end)
        return fini
    end)
    appliquerBornes(false)
end

-- Lampe a plat (les bornes de recharge de la lampe sont partout, aucun risque de blocage)
local function lampe()
    local i = O.inv()
    if i then i:SetPowerLevel_Fazwatch(0) end
end

-- Effets a duree (idees de Zinoxe) : reappliques en boucle, le jeu remet ses valeurs a chaque changement
-- d'allure, apres une mort ou un chargement. Un 2e piege du meme type rallonge la duree.
M.DUREE_LENT = 30       -- s
M.VITESSE_LENT = 0.5    -- x la vitesse de marche, course comprise
M.DUREE_ENTRAVE = 30    -- s sans courir ni sauter
M.DUREE_TURBO = 20      -- s d'animatroniques acceleres
M.VITESSE_TURBO = 2.0

local finDe = {}
local function temporaire(nom, duree, ms, tic, fin)
    local deja = finDe[nom] ~= nil
    finDe[nom] = math.max(finDe[nom] or 0, os.time()) + duree
    pcall(tic)
    if deja then return end
    O.boucle(ms, function()
        if os.time() >= finDe[nom] then
            finDe[nom] = nil
            local ok, err = pcall(fin)
            O.log("fin du piege", nom, ok and "" or tostring(err))
            return true
        end
        pcall(tic)
        return false
    end)
end

-- Vitesses de Gregory pour les pieges ralenti et entrave. Les vitesses de reference du Blueprint sont baissees
-- (sinon chaque depart de course remet la pleine vitesse le temps que le plafond repasse), plafond en secours.
-- Les deux pieges partagent ce reglage : s'ils se chevauchent, la fin de l'un garde l'effet de l'autre.
local vitesses = nil   -- valeurs d'origine (nombres, pas l'objet : Gregory change a chaque mort)
local function brider(g)
    if not vitesses then
        local v = g.DefaultWalkSpeed
        if not v or v < 50 then v = 300 end
        vitesses = {DefaultWalkSpeed = v, RunSpeed = g.RunSpeed, SuperRunSpeed = g.SuperRunSpeed}
        O.log("vitesses : marche", v, "course", vitesses.RunSpeed, "super", vitesses.SuperRunSpeed)
    end
    local m = vitesses.DefaultWalkSpeed * (finDe.lent and M.VITESSE_LENT or 1)
    local cible = {DefaultWalkSpeed = m, RunSpeed = m, SuperRunSpeed = m}
    for k, v in pairs(cible) do
        if g[k] ~= v then g[k] = v end
    end
    local cm = g.CharacterMovement
    if cm.MaxWalkSpeed > m + 1 then cm.MaxWalkSpeed = m end
end
local function liberer()
    local g = O.gregory()
    if not (g and vitesses) then vitesses = nil return end
    if finDe.lent or finDe.entrave then brider(g) return end
    for k, v in pairs(vitesses) do g[k] = v end
    g:SetupWalkSpeed()
    vitesses = nil
end

-- Gregory au ralenti, qu'il marche ou qu'il coure
local function lent()
    temporaire("lent", M.DUREE_LENT, 100, function()
        local g = O.gregory()
        if g then brider(g) end
    end, liberer)
end

-- Plus de course ni de saut
local sautsAvant = nil
local function entrave()
    temporaire("entrave", M.DUREE_ENTRAVE, 100, function()
        local g = O.gregory()
        if not g then return end
        if sautsAvant == nil then sautsAvant = g.JumpMaxCount O.log("entrave : sauts", sautsAvant) end
        g.CanSprint = false
        g.JumpMaxCount = 0
        if g.IsSprinting then g:StopSprinting() end
        brider(g)
    end, function()
        local g = O.gregory()
        if g then
            g.CanSprint = true
            g.JumpMaxCount = (sautsAvant and sautsAvant > 0) and sautsAvant or 1
        end
        sautsAvant = nil
        liberer()
    end)
end

-- Acceleres (le temps passe plus vite pour eux) : tout ce qui peut tuer ou donner l'alerte, Vanny, Moon,
-- endos et StaffBots de securite compris. Pas Sun (garderie, inoffensif) ni Vanessa (sa capture attend un
-- game over), pas ceux figes par le bonus Choc (dilatation 0)
local DANGERS = {"AISeeker_C", "Vanny_C", "Endo_C", "Moonman_C", "AIMoonMan_C", "AILilMusicMan_C",
    "StaffBotSecurityPatrol_C", "StaffBotSecurityPatrol_Nightmarrion_C"}
local function animatroniques(f)
    local vus = {}
    for _, c in ipairs(DANGERS) do
        for _, a in ipairs(FindAllOf(c) or {}) do
            if a:IsValid() and not O.supprime(a) then
                local nom = a:GetFullName()
                local classe = a:GetClass():GetFName():ToString()
                if not vus[nom] and not (classe:find("Sun") or classe:find("Vanessa")) then
                    vus[nom] = true
                    f(a)
                end
            end
        end
    end
end
local function turbo()
    temporaire("turbo", M.DUREE_TURBO, 1000, function()
        if not O.gregory() then return end
        animatroniques(function(a)
            if a.CustomTimeDilation > 0 then a.CustomTimeDilation = M.VITESSE_TURBO end
        end)
    end, function()
        animatroniques(function(a)
            if a.CustomTimeDilation > 1 then a.CustomTimeDilation = 1.0 end
        end)
    end)
end

local effets = {
    screamer = function() Sc.lancer(false) end,
    alerte = alerte,
    bornes = bornes,
    lampe = lampe,
    lent = lent,
    entrave = entrave,
    turbo = turbo,
}
M.noms = {screamer = "Screamer", alerte = "Alerte", bornes = "Bornes en panne", lampe = "Lampe a plat",
    lent = "Gregory au ralenti", entrave = "Ni course ni saut", turbo = "Animatroniques x2"}

-- texte : message troll avec le joueur qui a trouve le piege, affiche quand il tombe
local function declencher(type, texte)
    if not effets[type] then O.log("piege inconnu", type) return end
    S.ajouter("piege " .. type, function()
        effets[type]()
        -- l'alerte envoie des animatroniques : le piege suivant attend comme apres un screamer
        -- (alerte + screamer a 1 s d'ecart = plantage, 25/10)
        if type == "alerte" then S.verrouiller() end
        if texte then O.afficher(texte, 5.0) end
    end)
end

local reserve = {}

function M.recevoir(type, horsLigne, texte)
    if horsLigne then
        reserve[#reserve + 1] = {type = type, texte = texte}
    else
        declencher(type, texte)
    end
end

-- A la connexion au serveur : un seul des pieges recus hors ligne part tout de suite
function M.connexion()
    if #reserve > 0 then
        O.log(#reserve, "pieges recus hors ligne, 1 tout de suite, le reste a chaque mort")
        local p = table.remove(reserve, 1)
        declencher(p.type, p.texte)
    end
end

function M.reserveRestante() return #reserve end

S.surMort[#S.surMort + 1] = function()
    if #reserve > 0 then
        O.log("mort : un piege de la reserve arrive (" .. (#reserve - 1) .. " restants)")
        local p = table.remove(reserve, 1)
        declencher(p.type, p.texte)
    end
end

-- DeathLink recu : passe devant les pieges. mode "classique" (mort directe) ou "screamer"
function M.deathLink(mode)
    S.ajouter("DeathLink", function()
        if mode == "screamer" then Sc.lancer(true) else O.gregory():Kill() end
    end, true)
end

return M
