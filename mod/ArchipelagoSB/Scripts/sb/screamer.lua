-- Screamer : non mortel pour le piege, mortel pour le DeathLink "Screamer".
-- Choix de l'animatronique : Vanny si elle est dans le coin, sinon Chica/Roxy/Monty le plus proche,
-- sinon on en fait apparaitre un. Jamais Vanessa (sa capture finit en ecran noir).
local O = require("sb.outils")
local S = require("sb.securite")
local M = {}

local screamerSur = false     -- vrai pendant un screamer de piege : le JumpscarePawn est rendu non mortel
local apparuEnCours = nil     -- animatronique qu'on a fait apparaitre pour ce screamer
local existantEnCours = nil   -- {a, origine} : animatronique deja present, a renvoyer apres
local relanceInterdite = {}   -- nom -> heure : un screamer de sa part juste apres est annule
local neutralises = {}        -- apparus qu'on n'a pas pu supprimer : caches, et leurs screamers annules

-- Le son reste coupe apres un screamer non mortel : le jeu le remet avec InitializeAudio apres un game over
local function retablirSon()
    local akgs = StaticFindObject("/Script/AkAudio.Default__AkGameplayStatics")
    local pc = FindFirstOf("MainGamePC_C")
    local evt = StaticFindObject("/Game/Audio/Assets/UI/Menu/InitializeAudio.InitializeAudio")
    if not pcall(function() akgs:PostEventAttached(evt, pc, FName("None"), false, "") end) then
        pcall(function() akgs:PostEventByName("InitializeAudio", pc, false) end)
    end
end

local function neutraliser(a, loin)
    if not a or not a:IsValid() then return end
    neutralises[a:GetFullName()] = true
    pcall(function() a:SetActorHiddenInGame(true) end)
    pcall(function() a:SetActorEnableCollision(false) end)
    pcall(function() a:StunForDuration(9999.0) end)
    pcall(function() a.CharacterMovement:DisableMovement() end)
    pcall(function()
        local c = a.Controller
        if c and c:IsValid() then c:UnPossess() c:K2_DestroyActor() end
    end)
    -- Loin seulement une fois Gregory rendu : la camera du screamer suit encore l'animatronique (ecran noir)
    if loin then
        pcall(function()
            local p = a:K2_GetActorLocation()
            a:K2_SetActorLocation({X = p.X, Y = p.Y, Z = p.Z + 50000}, false, {}, true)
        end)
    end
end

-- Supprime un animatronique qu'on a fait apparaitre (desinscrit du gestionnaire d'IA, sinon il reste)
local function retirerApparu(a)
    if not a or not a:IsValid() or O.supprime(a) then return end
    local nom = a:GetFullName()
    local ai = FindFirstOf("AIManagementSystem")
    if ai and ai:IsValid() then pcall(function() ai:UnRegisterAI(a) end) end
    pcall(function() a:K2_DestroyActor() end)
    O.apres(1000, function()
        for _, x in ipairs(FindAllOf("AISeeker_C") or {}) do
            if x:IsValid() and x:GetFullName() == nom and not O.supprime(x) then
                O.log("RETRAIT echec, animatronique neutralise :", nom)
                neutraliser(x, O.gregoryRendu())
            end
        end
    end)
end

-- Annule un screamer deja lance : on rend Gregory, puis on supprime le JumpscarePawn a l'image suivante
-- (le supprimer sans rendre Gregory laissait le joueur sans corps et la carte dechargee)
local function annulerScreamer(puis)
    for _, p in ipairs(FindAllOf("JumpscarePawn_C") or {}) do
        if p:IsValid() then p.IsLethal = false end
    end
    ExecuteInGameThread(function()
        local pawns = {}
        for _, p in ipairs(FindAllOf("JumpscarePawn_C") or {}) do
            if p:IsValid() then
                pcall(function() p["Possess Gregory"](p) end)
                pawns[#pawns + 1] = p
            end
        end
        O.apres(200, function()
            for _, p in ipairs(pawns) do
                if p:IsValid() then S.restes[p:GetFullName()] = true p:K2_DestroyActor() end
            end
            pcall(function() FindFirstOf("MainGamePC_C").PlayerCameraManager:StopAllCameraShakes(true) end)
            -- Le screamer coupe le son du jeu ; annule avant sa fin, le son ne revenait jamais
            retablirSon()
            if puis then puis() end
        end)
    end)
end

-- Fin du screamer (minuteur du JumpscarePawn, ~2 s apres le debut)
O.hook("/Game/Blueprints/Player/JumpscarePawn.JumpscarePawn_C:On Jumpscare Kill Timer Up", function()
    if screamerSur then retablirSon() end
    local a, e = apparuEnCours, existantEnCours
    apparuEnCours, existantEnCours = nil, nil
    -- ~1,1 s apres la fin, l'animatronique relancait son screamer : on lui retire sa cible
    for _, x in pairs({a or false, e and e.a or false}) do
        if x and x:IsValid() then pcall(function() x.CurrentJumpscareTarget = nil end) end
    end
    if a and a:IsValid() then
        neutraliser(a)
        O.quandRendu(function() retirerApparu(a) end)
    end
    if e and e.a:IsValid() then
        M.rendreAnimBrisee(e.a)
        relanceInterdite[e.a:GetFullName()] = os.time()
        pcall(function() e.a:StunForDuration(8.0) end)
        -- Renvoye a sa place des que Gregory est rendu (TeleportAI ne prend pas juste apres un screamer)
        O.quandRendu(function()
            if not e.a:IsValid() then return end
            e.a:TeleportAI(e.origine)
            local p = e.a:K2_GetActorLocation()
            if O.dist2D(p, e.origine) > 100 then e.a:K2_SetActorLocation(e.origine, false, {}, true) end
            e.a:StunForDuration(5.0)
        end)
    end
end)

M.surMapBot = nil  -- fonction(mapbot), posee par mapbot.lua

O.hook("/Game/Blueprints/Player/Gregory.Gregory_C:SpawnJumpscarePawn", function(self, transform, canEscape, isLethal, shake, actor)
    local auteur = "?"
    pcall(function() auteur = actor:get():GetFullName() end)
    local interdit = relanceInterdite[auteur] and os.time() - relanceInterdite[auteur] < 4
    if neutralises[auteur] or interdit then
        O.log("screamer d'un animatronique neutralise annule")
        annulerScreamer()
        return
    end
    if auteur:find("MapBot_C") and M.surMapBot then
        local mapbot = actor:get()
        ExecuteInGameThread(function() pcall(M.surMapBot, mapbot) end)
        return
    end
    -- Le hook passe apres la fonction : on corrige le screamer deja cree, avant son minuteur de mort
    if screamerSur then
        for _, p in ipairs(FindAllOf("JumpscarePawn_C") or {}) do
            if p:IsValid() then p.IsLethal = false p.CanEscape = false end
        end
    end
end)

-- Versions brisees (fin de partie) : appele par notre ordre, leur screamer prend la camera mais
-- l'animation ne suit pas. On la joue nous-memes (animation lue dans les fichiers du jeu), puis on
-- rend la main a leur Blueprint d'animation.
local ANIM_BRISEE = {
    ShatteredRoxy = "/Game/Animations/Shattered_Roxy/ShatteredRoxy_Jumpscare.ShatteredRoxy_Jumpscare",
    ShatteredChica = "/Game/Animations/ShatteredChica/ShatteredChica_Jumpscare.ShatteredChica_Jumpscare",
    ShatteredMonty = "/Game/Animations/ShatteredMonty/ShatteredMonty_Jumpscare.ShatteredMonty_Jumpscare",
}
local function jouerAnimBrisee(a)
    local classe = a:GetClass():GetFName():ToString()
    for cle, chemin in pairs(ANIM_BRISEE) do
        if classe:find(cle) then
            local seq = StaticFindObject(chemin)
            local ok, err = pcall(function()
                pcall(function() a.Mesh:GetAnimInstance().CanJumpscare = true end)
                a.Mesh:PlayAnimation(seq, false)
            end)
            O.log("version brisee :", cle, "animation", (seq and seq:IsValid()) and "trouvee" or "INTROUVABLE",
                ok and "jouee" or ("erreur " .. tostring(err)))
            return true
        end
    end
    return false
end
local function rendreAnimBrisee(a)
    if not a or not a:IsValid() or not a:GetClass():GetFName():ToString():find("Shattered") then return end
    pcall(function() a.Mesh:SetAnimationMode(0) end)   -- 0 = Blueprint d'animation
    pcall(function() a.Mesh:GetAnimInstance().CanJumpscare = false end)
end
M.rendreAnimBrisee = rendreAnimBrisee  -- utilisee par le hook de fin de screamer, plus haut

-- Pas d'animatronique invisible : un normal reste parfois dans le monde en fin de partie alors que
-- l'histoire l'a brise (cache par le jeu) ; son screamer etait invisible.
local function visible(a, classe)
    local cache = false
    pcall(function() cache = a.bHidden == true or not a.Mesh:IsVisible() end)
    if cache then return false end
    if not classe:find("Shattered") then
        local type = classe:find("Chica") and 0 or classe:find("Roxy") and 1 or 2
        if O.sousType(type) == 1 then return false end
    end
    return true
end

local function animatroniqueProche(loc)
    local best, bestD = nil, math.huge
    for _, a in ipairs(FindAllOf("AISeeker_C") or {}) do
        local classe = a:IsValid() and a:GetClass():GetFName():ToString() or ""
        if (classe:find("Chica") or classe:find("Roxy") or classe:find("Monty"))
            and not neutralises[a:GetFullName()] and not O.supprime(a) and visible(a, classe) then
            local p = a:K2_GetActorLocation()
            local d = (p.X - loc.X) ^ 2 + (p.Y - loc.Y) ^ 2 + (p.Z - loc.Z) ^ 2
            if d < bestD then best, bestD = a, d end
        end
    end
    return best
end

-- Vanny : seulement la Vanny des nuits (classe exacte Vanny_C, pas celle des scenes), proche ou en vue.
-- Jamais ForceSpawnVanny : le jeu peut sortir Vanessa a la place.
local function vannyProche(loc)
    local pc = FindFirstOf("MainGamePC_C")
    for _, v in ipairs(FindAllOf("Vanny_C") or {}) do
        if v:IsValid() and v:GetClass():GetFName():ToString() == "Vanny_C" then
            local p = v:K2_GetActorLocation()
            local d = O.dist2D(p, loc)
            local okV, vue = pcall(function() return pc:LineOfSightTo(v, {X = 0, Y = 0, Z = 0}, false) end)
            if (d < 2500 and math.abs(p.Z - loc.Z) < 300) or (d < 8000 and okV and vue) then return v end
        end
    end
end

local function screamerVanny(v, mortel)
    local g = O.gregory()
    local loc, fwd = g:K2_GetActorLocation(), g:GetActorForwardVector()
    local anim = v.Mesh:GetAnimInstance()
    local modeAvant, peurAvant = anim.AnimationModeEnum, anim.CanJumpscare
    S.verrouiller()
    O.log(mortel and "DEATHLINK" or "PIEGE", "screamer : Vanny")
    screamerSur = not mortel
    v:TeleportAI({X = loc.X + fwd.X * 120, Y = loc.Y + fwd.Y * 120, Z = loc.Z})
    v:Jumpscare(g)
    if mortel then return end
    -- Son screamer tue toujours en vrai : le jeu ne la sort jamais de sa pose (CanJumpscare reste vrai)
    O.apres(2000, function()
        if not v:IsValid() then return end
        anim.AnimationModeEnum = modeAvant
        anim.CanJumpscare = peurAvant
        pcall(function() v.CurrentJumpscareTarget = nil end)
        relanceInterdite[v:GetFullName()] = os.time()
    end)
    -- Son JumpscarePawn ne disparait pas tout seul (normalement le joueur est mort)
    O.apres(4000, function()
        screamerSur = false
        if not O.gregoryRendu() then return end
        for _, p in ipairs(FindAllOf("JumpscarePawn_C") or {}) do
            if p:IsValid() then S.restes[p:GetFullName()] = true p:K2_DestroyActor() end
        end
    end)
end

function M.lancer(mortel, forcerApparition, essai)
    local g = O.gregory()
    if not g then return end
    local loc = g:K2_GetActorLocation()
    local fwd = g:GetActorForwardVector()
    local quoi = mortel and "DEATHLINK" or "PIEGE"
    S.verrouiller()

    local function executer(best, apparu)
        local origine = best:K2_GetActorLocation()
        local z = (apparu and math.abs(origine.Z - loc.Z) > 300) and loc.Z or origine.Z
        local devant = {X = loc.X + fwd.X * 120, Y = loc.Y + fwd.Y * 120, Z = z}
        O.log(quoi, "screamer :", best:GetClass():GetFName():ToString(), apparu and "(apparu)" or "")
        -- Avant la teleportation : arrive devant le joueur, l'IA peut lancer son propre screamer tout de suite
        screamerSur = not mortel
        best:TeleportAI(devant)
        if O.dist2D(best:K2_GetActorLocation(), devant) > 100 then
            pcall(function() best:K2_SetActorLocation(devant, false, {}, true) end)
        end
        -- Le screamer se joue la ou est l'animatronique, camera comprise : s'il n'est pas devant le joueur,
        -- la camera part la-bas, le jeu decharge la zone du joueur (ecran noir). On annule plutot.
        if O.dist2D(best:K2_GetActorLocation(), devant) > 100 then
            screamerSur = false
            if apparu then
                retirerApparu(best)
                if (essai or 1) < 3 then M.lancer(mortel, true, (essai or 1) + 1)
                elseif mortel then g:Kill() end
            else
                best:TeleportAI(origine)
                M.lancer(mortel, true)
            end
            return
        end
        if apparu then apparuEnCours = best else existantEnCours = {a = best, origine = origine} end
        pcall(function() best.ForceJumpscare = true end)
        best:Jumpscare(g)
        if best:GetClass():GetFName():ToString():find("Shattered") then
            O.apres(100, function() if best:IsValid() then jouerAnimBrisee(best) end end)
        end
        -- Un animatronique peut ignorer Jumpscare (scripte, ou juste apres un autre screamer)
        local forceEssaye = false
        local function verifier()
            O.apres(800, function()
                local pc = FindFirstOf("MainGamePC_C")
                if pc and pc:IsValid() and pc.Pawn:GetFullName():find("JumpscarePawn_C") then
                    pcall(function() best.ForceJumpscare = false end)
                    return
                end
                if not forceEssaye and best:IsValid() then
                    forceEssaye = true
                    best:ForceJumpscarePlayer()
                    verifier()
                    return
                end
                O.log(quoi, "screamer refuse, on change d'animatronique")
                screamerSur = false
                apparuEnCours, existantEnCours = nil, nil
                if best:IsValid() then
                    if apparu then retirerApparu(best) else best:TeleportAI(origine) end
                end
                if not apparu then
                    M.lancer(mortel, true)
                elseif (essai or 1) < 3 then
                    M.lancer(mortel, true, (essai or 1) + 1)
                elseif mortel then
                    g:Kill()
                end
            end)
        end
        verifier()
        if mortel then return end
        O.apres(4000, function()
            screamerSur = false
            if best:IsValid() then
                pcall(function() best.ForceJumpscare = false end)
                if apparu then retirerApparu(best) end
            end
        end)
    end

    if not forcerApparition then
        local v = vannyProche(loc)
        if v then screamerVanny(v, mortel) return end
        local best = animatroniqueProche(loc)
        if best then executer(best, false) return end
    end
    -- Apparition a 400 u (derriere, puis a gauche, puis a droite) : sur le joueur, il le poussait sous la
    -- carte ; plus loin, il tombait de l'autre cote d'un mur. Type impose : Chica, Roxy ou Monty.
    local ai = FindFirstOf("AIManagementSystem")
    local avant = {}
    for _, a in ipairs(FindAllOf("AISeeker_C") or {}) do avant[a:GetFullName()] = true end
    local cote = ({{-fwd.X, -fwd.Y}, {-fwd.Y, fwd.X}, {fwd.Y, -fwd.X}})[essai or 1]
    local voulu = {X = loc.X + cote[1] * 400, Y = loc.Y + cote[2] * 400, Z = loc.Z}
    -- Sous-type selon l'histoire : un animatronique dont Freddy a pris la piece est brise. Une Roxy normale
    -- apparue en fin de partie restait invisible (seul le tremblement de l'ecran passait).
    local type = math.random(0, 2)
    if not pcall(function() ai:SpawnAITypeAtLocationWithSubType(type, voulu, O.sousType(type)) end) then
        ai:SpawnAITypeAtLocation(type, voulu, false)
    end
    O.apres(300, function()
        -- Le plus proche de l'endroit voulu (un autre animatronique peut arriver au meme moment, loin)
        local apparu, meilleur = nil, math.huge
        for _, a in ipairs(FindAllOf("AISeeker_C") or {}) do
            if a:IsValid() and not avant[a:GetFullName()] then
                local d = O.dist2D(a:K2_GetActorLocation(), voulu)
                if d < meilleur then apparu, meilleur = a, d end
            end
        end
        if apparu then executer(apparu, true) return end
        O.log(quoi, "screamer : aucun animatronique")
        if mortel then g:Kill() end
    end)
end

M.annulerScreamer = annulerScreamer
return M
