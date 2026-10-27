-- Outils communs : journal, hooks, inventaire, petites fonctions de distance
local M = {}


-- Journal du mod garde sur plusieurs sessions (UE4SS.log est reecrit a chaque lancement) : joint au rapport
-- de bug par le launcher. Au-dela de 1 Mo, l'ancien part dans journal.1.log.
local JOURNAL = "ue4ss/ArchipelagoSB/journal.log"
local journal
pcall(function()
    local f = io.open(JOURNAL, "r")
    if f then
        local taille = f:seek("end")
        f:close()
        if taille > 1024 * 1024 then
            os.remove("ue4ss/ArchipelagoSB/journal.1.log")
            os.rename(JOURNAL, "ue4ss/ArchipelagoSB/journal.1.log")
        end
    end
    journal = io.open(JOURNAL, "a")
    if journal then
        journal:write("\n===== lancement du jeu " .. os.date("%Y-%m-%d %H:%M:%S") .. " =====\n")
        journal:flush()
    end
end)

function M.log(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    local ligne = table.concat(t, " ")
    print("[AP-SB] " .. ligne .. "\n")
    if journal then
        pcall(function()
            journal:write(os.date("%H:%M:%S ") .. ligne .. "\n")
            journal:flush()
        end)
    end
end

-- Traces (diagnostic du plantage des endos, 27/10) : chaque boucle et minuteur du mod ecrit son nom avant de
-- tourner. Apres un plantage, la derniere ligne de traces.log dit ce qui tournait. Fichier repris a zero a
-- chaque lancement et au-dela de 2 Mo.
M.TRACES = true
local TRACES = "ue4ss/ArchipelagoSB/traces.log"
local traces = M.TRACES and io.open(TRACES, "w") or nil
local function tracer(nom)
    if not traces then return end
    pcall(function()
        if traces:seek("end") > 2 * 1024 * 1024 then
            traces:close()
            traces = io.open(TRACES, "w")
        end
        traces:write(os.date("%H:%M:%S ") .. nom .. "\n")
        traces:flush()
    end)
end
local function nomDe(f)
    local ok, info = pcall(debug.getinfo, f, "S")
    if not ok or not info then return "?" end
    return tostring(info.short_src):match("([^/\\]+)$") .. ":" .. tostring(info.linedefined)
end

-- MOUCHARD DE PERF (TEMPORAIRE, a retirer) : chronometre chaque boucle, hook, minuteur et notification du
-- mod ; toutes les 10 s, les 6 plus couteux au journal ("PERF").
M.PERF = false   -- futur "mode diagnostic" du launcher
if M.PERF then
    local stats, debut = {}, os.clock()
    local function mesure(f, genre)
        local info = debug.getinfo(f, "S")
        local cle = genre .. " " .. (info.short_src or "?"):match("[^/\\]+$") .. ":" .. tostring(info.linedefined)
        return function(...)
            local t0 = os.clock()
            local r = table.pack(pcall(f, ...))
            local d = (os.clock() - t0) * 1000
            local s = stats[cle]
            if not s then s = {n = 0, total = 0, max = 0} stats[cle] = s end
            s.n, s.total = s.n + 1, s.total + d
            if d > s.max then s.max = d end
            if not r[1] then error(r[2], 0) end
            return table.unpack(r, 2, r.n)
        end
    end
    M.mesure = mesure
    local function enrober(nom, genre, position)
        local orig = _G[nom]
        if type(orig) ~= "function" then return end
        _G[nom] = function(...)
            local a = table.pack(...)
            if type(a[position]) == "function" then a[position] = mesure(a[position], genre) end
            return orig(table.unpack(a, 1, a.n))
        end
    end
    enrober("LoopInGameThreadWithDelay", "boucle", 2)
    enrober("ExecuteInGameThreadWithDelay", "apres", 2)
    enrober("ExecuteInGameThread", "fil", 1)
    enrober("RegisterHook", "hook", 2)
    enrober("NotifyOnNewObject", "nouvel", 2)
    enrober("LoopAsync", "async", 2)
    local orig = LoopInGameThreadWithDelay
    orig(10000, function()
        local l = {}
        for k, s in pairs(stats) do l[#l + 1] = {k, s} end
        table.sort(l, function(a, b) return a[2].total > b[2].total end)
        local dt = (os.clock() - debut) * 1000
        for i = 1, math.min(6, #l) do
            local k, s = l[i][1], l[i][2]
            M.log(string.format("PERF %-34s total %7.1f ms  max %6.1f ms  appels %6d", k, s.total, s.max, s.n))
        end
        M.log(string.format("PERF ---- (sur %.0f ms)", dt))
        stats, debut = {}, os.clock()
    end)
end

-- Message a l'ecran, en attendant un vrai affichage : notre propre exemplaire du widget de sous-titres
-- du jeu (les fonctions de sous-titres du jeu n'affichaient rien avec un texte a nous). Aussi au journal.
local widget, generation = nil, 0
function M.afficher(texte, duree)
    M.log("ECRAN", texte)
    generation = generation + 1
    local g = generation
    local ok, err = pcall(function()
        local pc = FindFirstOf("MainGamePC_C")
        if not widget or not widget:IsValid() then
            local chemin = "/Game/Blueprints/UI/Subtitles/WI_Subtitles.WI_Subtitles_C"
            local cls = StaticFindObject(chemin)
            if not cls or not cls:IsValid() then cls = LoadAsset(chemin) end
            local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
            widget = wbl:Create(pc, cls, pc)
            widget:AddToViewport(50)
        end
        widget.RichText:SetText(FText(texte))
        widget.RichText:SetVisibility(0)
        widget:SetVisibility(0)
    end)
    if not ok then M.log("affichage impossible :", tostring(err)) return end
    M.apres(math.floor((duree or 4.0) * 1000), function()
        if g == generation and widget and widget:IsValid() then widget:SetVisibility(1) end
    end)
end

-- Joue un son du jeu (evenement Wwise, ex. "/Game/Audio/Assets/.../Play_sfx_fazcam_recharge") sur Gregory
function M.son(chemin)
    local ok, err = pcall(function()
        local nom = chemin:match("([^/]+)$")
        local evt = StaticFindObject(chemin .. "." .. nom)
        if not evt or not evt:IsValid() then evt = LoadAsset(chemin .. "." .. nom) end
        local akgs = StaticFindObject("/Script/AkAudio.Default__AkGameplayStatics")
        akgs:PostEventAttached(evt, FindFirstOf("Gregory_C"), FName("None"), false, "")
    end)
    if not ok then M.log("son impossible :", chemin, tostring(err)) end
end

-- Texte lisible d'une valeur UE4SS (FName, FString, parametre de hook...)
function M.s(v)
    if v == nil then return "nil" end
    local ok, r = pcall(function() return v:get() end)
    if ok and r ~= nil and r ~= v then v = r end
    local ok2, r2 = pcall(function() return v:ToString() end)
    if ok2 and r2 then return r2 end
    return tostring(v)
end

-- Partie stable : Gregory present et controle par le joueur depuis 3 s d'affilee. Les boucles frequentes
-- (roue, logo) attendent ce signal : interroger le joueur et Gregory pendant le chargement d'un niveau,
-- alors qu'ils sont encore en construction, faisait planter le jeu.
M.stable = false
M.chargement = false
local gregoryVu, suite = nil, 0

-- Chargement de niveau (mort, sauvegarde, retour au menu) : pendant que l'ancien monde est detruit, ses
-- objets restent visibles en memoire mais leur niveau n'existe plus (lire leur nom plantait le jeu).
-- On ne touche plus a rien jusqu'au monde suivant ; la stabilite revient 3 s apres.
M.surChargement = {}   -- fonctions appelees au debut de chaque chargement (vider les listes d'objets)
local function debutChargement(qui)
    if not M.chargement then M.log("chargement de niveau (" .. qui .. ")") end
    M.chargement, M.stable, suite, gregoryVu = true, false, 0, nil
    for _, f in ipairs(M.surChargement) do pcall(f) end
end
local okPre = pcall(RegisterLoadMapPreHook, function() debutChargement("avant") end)
pcall(RegisterLoadMapPostHook, function()
    -- si le signal "avant" n'existe pas dans cette version d'UE4SS, on decroche au moins ici
    if not M.chargement then debutChargement("apres") end
    M.chargement = false
end)
if not okPre then M.log("signal de debut de chargement indisponible") end

local function vivant(x)
    return x ~= nil and x:IsValid() and not M.supprime(x)
end
M.vivant = vivant

-- Garder un objet du jeu entre deux appels = garder son CHEMIN, jamais l'objet : le ramasse-miettes passe
-- aussi en pleine partie, et relire un objet libere (meme IsValid) plantait le jeu. retrouver() redemande
-- l'objet au moteur, qui repond nil s'il n'existe plus.
function M.chemin(x)
    local ok, nom = pcall(function() return x:GetFullName() end)
    return ok and nom and nom:match("^%S+ (.+)$") or nil
end

function M.retrouver(chemin)
    if not chemin then return nil end
    local x = StaticFindObject(chemin)
    if x and x:IsValid() then return x end
end

LoopInGameThreadWithDelay(1000, function()
    if M.chargement then return end
    local ok = pcall(function()
        local g = FindFirstOf("Gregory_C")
        local pc = FindFirstOf("MainGamePC_C")
        local nom = (vivant(g) and vivant(pc) and vivant(pc.Pawn)
            and pc.Pawn:GetFullName() == g:GetFullName()) and g:GetFullName() or nil
        suite = (nom and nom == gregoryVu) and suite + 1 or 0
        gregoryVu = nom
        M.stable = suite >= 3
    end)
    if not ok then M.stable, suite = false, 0 end
end)

-- Au menu ou partie stable (jamais pendant un chargement) : pour toucher aux assets du jeu sans risque
function M.calme()
    if M.chargement then return false end
    if M.stable then return true end
    for _, c in ipairs({"TitlePC_C", "SplashPC_C"}) do
        if vivant(FindFirstOf(c)) then return true end
    end
    return false
end

function M.enPartie()
    if M.chargement then return false end
    return vivant(FindFirstOf("Gregory_C"))
end

-- Boucle dans le fil du jeu (remplace LoopAsync) : f() renvoie vrai pour s'arreter. LoopAsync faisait
-- tourner le Lua sur un 2e fil en meme temps que le fil du jeu : avec la roue et les animations (fil du
-- jeu, tres frequents), les deux se marchaient dessus ("Ref was not function", plantages aleatoires).
function M.boucle(ms, f)
    local nom = "boucle " .. nomDe(f)
    if M.mesure then f = M.mesure(f, "o.boucle") end
    local poignee
    poignee = LoopInGameThreadWithDelay(ms, function()
        tracer(nom)
        local ok, fini = pcall(f)
        if not ok then M.log("erreur boucle", tostring(fini)) end
        if ok and fini == true and poignee then pcall(CancelDelayedAction, poignee) end
    end)
    return poignee
end

-- Hooks sur les fonctions des Blueprints (/Game/...) : poses seulement partie stable, DECROCHES a chaque
-- chargement de niveau puis raccroches dans le nouveau monde. Un rechargement (mort, sauvegarde) detruit et
-- recree ces Blueprints : un hook reste sur l'ancienne fonction faisait planter UE4SS quelques secondes
-- apres ("Freed invalid callbacks"). Meme chose pour les hooks poses au menu.
local direct = RegisterHook
local hooksJeu = {}   -- {chemin, fn, pre, post}
function M.hook(chemin, fn)
    if chemin:sub(1, 6) ~= "/Game/" then
        local ok, err = pcall(direct, chemin, fn)
        if not ok then M.log("hook impossible", chemin, tostring(err)) end
        return
    end
    hooksJeu[#hooksJeu + 1] = {chemin = chemin, fn = fn}
end

local function decrocher()
    for _, h in ipairs(hooksJeu) do
        if h.pre then pcall(UnregisterHook, h.chemin, h.pre, h.post) end
        h.pre, h.post = nil, nil
    end
end
-- Un essai rate (Blueprint pas encore charge) coute ~15 ms : chaque seconde les 10 premieres secondes de
-- la partie (la plupart des Blueprints arrivent la), puis toutes les 5 s.
local essaisHooks = 0
M.surChargement[#M.surChargement + 1] = function() decrocher() essaisHooks = 0 end

-- Aussi appele directement quand on sait qu'un Blueprint vient d'etre charge par le jeu (Fazer Blast)
function M.accrocherHooks()
    for _, h in ipairs(hooksJeu) do
        if not h.pre then
            local ok, pre, post = pcall(direct, h.chemin, h.fn)
            if ok and pre then h.pre, h.post = pre, post end
        end
    end
end

M.boucle(1000, function()
    if not M.stable then return false end
    essaisHooks = essaisHooks + 1
    if essaisHooks > 10 and essaisHooks % 5 ~= 0 then return false end
    M.accrocherHooks()
    return false
end)

-- Execute f dans le fil du jeu apres ms millisecondes, erreurs au journal. Minuteur du fil du jeu :
-- l'ancien ExecuteWithDelay + ExecuteInGameThread passait par un 2e fil, et a haute frequence (animations)
-- UE4SS corrompait ses references Lua ("Ref was not function") puis plantait.
function M.apres(ms, f)
    local nom = traces and ("apres " .. nomDe(f)) or nil
    ExecuteInGameThreadWithDelay(math.max(1, math.floor(ms)), function()
        if nom then tracer(nom) end
        local ok, err = pcall(f)
        if not ok then M.log("erreur", tostring(err)) end
    end)
end

function M.touche(k, f, mods)
    local function lancer()
        ExecuteInGameThread(function()
            local ok, err = pcall(f)
            if not ok then M.log("erreur touche", tostring(err)) end
        end)
    end
    if mods then RegisterKeyBind(k, mods, lancer) else RegisterKeyBind(k, lancer) end
end

function M.inv()
    local i = FindFirstOf("FNAFInventorySystem")
    if i and i:IsValid() then return i end
end

-- Possession / retrait / don d'un objet OU d'un message (les messages ont leurs propres fonctions)
function M.possede(nom)
    local i = M.inv()
    if not i or nom == nil or nom == "None" then return false end
    local ok1, a = pcall(function() return i:HasItem(FName(nom)) end)
    if ok1 and a then return true end
    local ok2, b = pcall(function() return i:HasMessage(FName(nom)) end)
    return ok2 and b == true
end
function M.retirer(nom)
    local i = M.inv()
    pcall(function() i:RemoveItem(FName(nom)) end)
    pcall(function() i:RemoveMessage(FName(nom)) end)
end
function M.estMessage(nom)
    local ok, v = pcall(function() return M.inv():IsMessageValid(FName(nom)) end)
    return ok and v == true
end
function M.rendre(nom)
    local i = M.inv()
    if M.estMessage(nom) then pcall(function() i:AwardMessage(FName(nom), false) end)
    else pcall(function() i:AwardItem(FName(nom), false) end) end
end

function M.gregory()
    if M.chargement then return nil end
    local g = FindFirstOf("Gregory_C")
    if vivant(g) then return g end
end

-- Vrai si le joueur controle Gregory (pas un screamer, pas Freddy, pas une camera)
function M.gregoryRendu()
    if M.chargement then return false end
    local ok, r = pcall(function()
        local pc, g = FindFirstOf("MainGamePC_C"), FindFirstOf("Gregory_C")
        if not (vivant(pc) and vivant(g) and vivant(pc.Pawn)) then return false end
        return pc.Pawn:GetFullName() == g:GetFullName()
    end)
    return ok and r
end

-- Sous-type d'un animatronique selon l'histoire (0 Chica, 1 Roxy, 2 Monty) : brise (1) si Freddy a deja
-- pris sa piece, sinon normal (0). Un normal apparu en fin de partie restait invisible.
function M.sousType(type)
    local brise = false
    pcall(function()
        local f = FindFirstOf("WorldStateSystem").FreddyState
        brise = ({[0] = f.HasChicaBeak, [1] = f.HasRoxyEyes, [2] = f.HasMontyClaws})[type] == true
    end)
    -- Ou une version brisee deja presente dans le monde (l'histoire peut la briser sans la piece)
    if not brise then
        local classe = ({[0] = "ShatteredChica_C", [1] = "ShatteredRoxy_C", [2] = "ShatteredMonty_C"})[type]
        for _, a in ipairs(FindAllOf(classe) or {}) do
            if a:IsValid() and not M.supprime(a) then brise = true break end
        end
    end
    return brise and 1 or 0
end

function M.dist2D(a, b)
    return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2)
end

-- Un acteur supprime reste en memoire (et visible pour FindAllOf) jusqu'au ramasse-miettes du moteur
function M.supprime(x)
    local ok, v = pcall(function() return x:HasAnyInternalFlags(EInternalObjectFlags.PendingKill) end)
    return ok and v == true
end

-- Attend que Gregory soit rendu (sondage toutes les 0,1 s, 2 s au plus), puis f
function M.quandRendu(f)
    local n = 0
    local function essai()
        n = n + 1
        if not M.gregoryRendu() and n < 20 then
            M.apres(100, essai)
            return
        end
        f()
    end
    essai()
end

-- Lampe tenue par Gregory (objet attache a la main, a part de l'inventaire) : la ranger ou la rendre.
-- Journal de chaque etape : savoir ce qui marche sur cette version du jeu.
function M.lampeEnMain(g, oui)
    if not g then return end
    local fait = {}
    local function essai(nom, f) if pcall(f) then fait[#fait + 1] = nom end end
    essai("etat", function() g["Force Flashlight State"](g, false, oui) end)
    essai("HasFlashlight", function() g.HasFlashlight = oui end)
    essai("CanToggle", function() g.CanToggleFlashlight = oui end)
    essai("mesh", function() g.FlashLightMesh:SetHiddenInGame(not oui, true) end)
    essai("acteur", function()
        local a = g.FlashlightActor
        if not (a and a:IsValid()) then a = g:GetFlashlightActor() end
        a:SetActorHiddenInGame(not oui)
    end)
    if oui then
        -- pas de SwitchItem/RaiseArms ici : appeles juste apres un chargement, ils plantaient le jeu (25/10)
    else
        -- la main restait en pose "tient la lampe" : plus d'objet tenu, bras baisses, jauge cachee
        essai("main", function() g:SwitchItem(nil) end)
        essai("bras", function() g:LowerArms() end)
        essai("batterie", function() g:ForceHideBatteryLevelWidget() end)
    end
    M.lampeRangee = not oui
    M.log(oui and "lampe rendue :" or "lampe rangee :", table.concat(fait, ", "))
end

return M
