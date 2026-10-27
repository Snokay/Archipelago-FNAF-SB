-- Objets recus d'Archipelago. Codes envoyes par le client :
--   objet:<NomDuJeu>      objet du jeu (laissez-passer, piece de Freddy, collectible...)
--   prog:<Prefixe>        prochain objet de la serie (FlashlightUpgrade_ -> _0, _1...)
--   badge                 niveau de securite +1
--   bonus:<id>            bonus en reserve (voir bonus.lua)
--   piege:<type>          piege (voir pieges.lua)
local O = require("sb.outils")
local B = require("sb.bonus")
local P = require("sb.pieges")
local M = {}

M.recus = {}          -- objets du jeu recus d'Archipelago (le ramassage dans le monde ne les retire pas)
M.donneParMod = false -- vrai pendant nos AwardItem : ce n'est pas un ramassage du joueur

local function donner(nom)
    local i = O.inv()
    if not i then return false end
    M.recus[nom] = true
    local deja = i:HasItem(FName(nom))
    -- la lampe gardee rangee pendant la garderie est deja dans l'inventaire : il faut quand meme la rendre
    if deja and not (nom == "Flashlight" and O.lampeRangee) then return true end
    if not deja then
        M.donneParMod = true
        pcall(function() i:AwardItem(FName(nom), false) end)  -- pas la fenetre du jeu : le mod affiche le sien
        M.donneParMod = false
    end
    -- la lampe rangee par le mod (ramassee dans le monde avant d'etre recue) : on la rend utilisable
    if nom == "Flashlight" then
        -- seulement si le mod l'a rangee pendant cette session, et partie stable (sinon le jeu gere seul)
        if O.lampeRangee then
            local function rendre()
                if not O.stable then O.apres(1000, rendre) return end
                O.lampeEnMain(O.gregory(), true)
            end
            rendre()
        end
    end
    if M.surDon then O.apres(200, function() M.surDon(nom) end) end
    return true
end

-- Niveau de securite : il ne vient que des badges recus. Ramasser un porte-badge (un check) fait +1
-- dans le jeu : on remet le niveau voulu juste apres.
M.niveauVoulu = nil

-- Niveau temporaire : la porte de la salle d'un porte-badge (garderie, securite du Monty Golf...) lit le
-- niveau que le jeu vient de donner. On le laisse tant que le joueur reste pres du porte-badge, sinon il
-- est enferme (softlock du 25/10 au Monty Golf) ; le vrai niveau revient a RAYON_TEMPORAIRE ou au chargement.
M.temporaire = nil  -- {pos = position du joueur au ramassage, niveau = niveau donne par le jeu}
M.RAYON_TEMPORAIRE = 3000
-- Niveau qu'il faut pour sortir de la salle du porte-badge (le +1 du jeu peut ne pas suffire si le joueur
-- arrive avec moins de badges qu'en vanilla)
local SORTIE = {securitybadgedaycare = 1, securitybadgeprizecounter = 2, securitybadgekitchen = 2}

-- Garderie : la zone de jeu est grande (le rayon lachait avant le bouton de sortie, niveau 1). Niveau 1
-- garanti du ramassage de son porte-badge a la fin de la mission EscapeDaycare, meme apres un chargement.
local PORTE_BADGE_GARDERIE = "MAP_Daycare_Gameplay:PRE_BadgeHolder_Daycare_2"
local function garderieEnCours()
    local R = package.loaded["sb.ramassage"]
    if not (R and R.estFait and R.estFait(PORTE_BADGE_GARDERIE)) then return false end
    local ok, fini = pcall(function()
        return FindFirstOf("FNAFMissionSystem"):IsCompletedMission(FName("EscapeDaycare"))
    end)
    return ok and fini == false
end

local function niveauApplique()
    local n = M.niveauVoulu
    if not n then return n end
    if M.temporaire and M.temporaire.niveau > n then n = M.temporaire.niveau end
    if n < 1 and garderieEnCours() then n = 1 end
    return math.min(n, M.NIVEAU_MAX or n)
end

function M.definirNiveau(n)
    M.niveauVoulu = n
    if M.temporaire and n >= M.temporaire.niveau then M.temporaire = nil end
    local i = O.inv()
    local voulu = niveauApplique()
    if i and i.SecurityLevel ~= voulu then i:SetSecurityLevel(voulu) end
end

local function verifierNiveau()
    local i = O.inv()
    local voulu = niveauApplique()
    if i and voulu and i.SecurityLevel ~= voulu then
        O.log("niveau de securite remis a", voulu, "(le jeu l'avait mis a", i.SecurityLevel .. ")")
        i:SetSecurityLevel(voulu)
    end
end

O.hook("/Script/fnaf9.FNAFInventorySystem:AwardItem", function(self, item)
    if M.donneParMod then return end
    -- Nom lu tout de suite : le parametre du hook n'existe plus 300 ms apres (le relire faisait planter le
    -- jeu au porte-badge des endos, traces Zinoxe 27/10)
    local nom = O.s(item)
    if nom:find("^SecurityBadge") then
        O.apres(300, function()
            local i, g = O.inv(), O.gregory()
            local donne = i and tonumber(i.SecurityLevel)
            if donne then donne = math.max(donne, SORTIE[nom:lower()] or 0) end
            if donne and M.niveauVoulu and donne > M.niveauVoulu and g then
                local p = g:K2_GetActorLocation()
                M.temporaire = {pos = {X = p.X, Y = p.Y}, niveau = donne}
                O.log("niveau", donne, "garde le temps de sortir de la salle du porte-badge (vrai niveau",
                    M.niveauVoulu .. ")")
            end
            verifierNiveau()
        end)
        O.apres(2000, verifierNiveau)
    end
end)

O.surChargement[#O.surChargement + 1] = function() M.temporaire = nil end

-- Plafond : 10 badges dans la seed. Le +1 d'un porte-badge (celui des endos ne passe pas par AwardItem) ou un
-- autre mod menait au niveau 11, que le jeu ne gere pas : plantage en quittant la zone (Zinoxe, 26/10)
M.NIVEAU_MAX = 10
local plafonnement = false
O.hook("/Script/fnaf9.FNAFInventorySystem:SetSecurityLevel", function(self)
    if plafonnement then return end
    local i = self:get()
    local n = tonumber(i.SecurityLevel)
    if n and n > M.NIVEAU_MAX then
        plafonnement = true
        pcall(function() i:SetSecurityLevel(M.NIVEAU_MAX) end)
        plafonnement = false
        O.log("niveau de securite", n, "ramene a", M.NIVEAU_MAX)
    end
end)

O.hook("/Script/fnaf9.FNAFMissionSystem:CompleteMission", function(self, mission)
    if O.s(mission) == "EscapeDaycare" then O.apres(1000, verifierNiveau) end
end)

-- Apres un chargement dans la garderie (porte-badge deja pris, mission pas finie) : niveau 1 remis
local garderieVue = false
O.boucle(2000, function()
    if not O.stable or not M.niveauVoulu or M.niveauVoulu >= 1 then return false end
    local enCours = garderieEnCours()
    if enCours and not garderieVue then O.log("garderie : niveau 1 garde jusqu'a la fin de EscapeDaycare") end
    garderieVue = enCours
    if enCours then verifierNiveau() end
    return false
end)

O.boucle(1000, function()
    if not M.temporaire or not O.stable then return false end
    local g = O.gregory()
    if not g then return false end
    if O.dist2D(g:K2_GetActorLocation(), M.temporaire.pos) > M.RAYON_TEMPORAIRE then
        M.temporaire = nil
        O.log("sorti de la salle du porte-badge : retour au vrai niveau", M.niveauVoulu)
        verifierNiveau()
    end
    return false
end)

-- Sans client (tests), le niveau voulu part du niveau de la sauvegarde
O.boucle(2000, function()
    if M.niveauVoulu then return true end
    ExecuteInGameThread(function()
        local i = O.inv()
        if not M.niveauVoulu and O.enPartie() and i then M.niveauVoulu = i.SecurityLevel end
    end)
    return M.niveauVoulu ~= nil
end)

-- muet : application silencieuse (le client rejoue la liste complete des objets a chaque connexion)
function M.recevoir(code, horsLigne, muet)
    local afficher = O.afficher
    if muet then O.afficher = function(texte) O.log("(muet)", texte) end end
    local ok, err = pcall(M.recevoirCode, code, horsLigne)
    O.afficher = afficher
    if not ok then O.log("erreur objet", code, tostring(err)) end
end

function M.recevoirCode(code, horsLigne)
    local genre, valeur = code:match("^(%w+):?(.*)$")
    if genre == "piege" then
        P.recevoir(valeur, horsLigne)
    elseif genre == "bonus" then
        B.recevoir(valeur)
    elseif genre == "badge" then
        M.definirNiveau((M.niveauVoulu or 0) + 1)
        O.afficher("Recu : badge de securite (niveau " .. M.niveauVoulu .. ")")
    elseif genre == "prog" then
        local i = O.inv()
        for n = 0, 9 do
            local nom = valeur .. n
            -- Numeros qui n'existent pas sautes (la lampe s'arrete a _5, les billets commencent a _1)
            local okV, valide = pcall(function() return i:IsItemValid(FName(nom)) end)
            if okV and valide == false then
                -- rien
            elseif not M.recus[nom] and not i:HasItem(FName(nom)) then
                donner(nom)
                O.afficher("Recu : " .. nom)
                return
            end
            M.recus[nom] = true
        end
        O.log("serie deja complete :", valeur)
    elseif genre == "message" then
        local i = O.inv()
        M.recus[valeur] = true
        M.donneParMod = true
        pcall(function() i:AwardMessage(FName(valeur), false) end)
        M.donneParMod = false
        if M.surDon then O.apres(200, function() M.surDon(valeur) end) end
        O.afficher("Recu : message " .. valeur)
    elseif genre == "objet" then
        local i = O.inv()
        local deja = i and i:HasItem(FName(valeur))
        donner(valeur)
        O.afficher((deja and "Deja possede : " or "Recu : ") .. valeur)
    else
        O.log("code inconnu", code)
    end
end

return M
