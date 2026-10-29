-- Liaison avec le pont Archipelago (client/pont_ap.py) par deux fichiers texte, une commande par ligne,
-- champs separes par des tabulations :
--   ue4ss/ArchipelagoSB/vers_jeu.txt   : ecrit par le pont, lu ici
--   ue4ss/ArchipelagoSB/vers_pont.txt  : ecrit ici, lu par le pont
-- Les objets recus sont appliques de facon idempotente (on peut les rejouer sans doublon) : a chaque
-- connexion et a chaque chargement de partie, le jeu repart de la liste complete du serveur.
local O = require("sb.outils")
local Ob = require("sb.objets")
local H = require("sb.hud")
local P = require("sb.pieges")
local B = require("sb.bonus")
local R = require("sb.ramassage")
local F = require("sb.fins")
local S = require("sb.securite")
local M = {}

local DOSSIER = "ue4ss/ArchipelagoSB/"
local ENTREE = DOSSIER .. "vers_jeu.txt"
local SORTIE = DOSSIER .. "vers_pont.txt"

M.connecte = false
local objets = {}       -- index -> {code, de, nom}
local enAttente = {}    -- lignes recues pendant la session, appliquees au "pret"
local enSession = false

local function ecrire(...)
    local f = io.open(SORTIE, "a")
    if not f then return end
    f:write(table.concat({...}, "\t") .. "\n")
    f:close()
end

local function decouper(ligne)
    local t = {}
    for champ in (ligne .. "\t"):gmatch("([^\t]*)\t") do t[#t + 1] = champ end
    return t
end

-- ---------- application des objets (idempotente) ----------
-- notifier : une notif "Recu" pour chaque objet reellement redonne (sauvegarde rechargee sans lui, objet
-- recu pendant la deconnexion). Pas pour un objet arrive en direct : il a deja la sienne.
local function appliquerTout(notifier)
    if not O.enPartie() or not O.inv() then return end
    local function notif(o) if notifier and o then H.recu(o.nom, o.de, o.code) end end
    local badges, series, parBadge, parSerie = 0, {}, {}, {}
    for index, o in pairs(objets) do
        local genre, valeur = o.code:match("^(%w+):?(.*)$")
        if genre == "badge" then
            badges = badges + 1
            parBadge[#parBadge + 1] = {index, o}
        elseif genre == "prog" then
            series[valeur] = (series[valeur] or 0) + 1
            parSerie[valeur] = parSerie[valeur] or {}
            table.insert(parSerie[valeur], {index, o})
        elseif genre == "objet" or genre == "message" then
            Ob.recus[valeur] = true
            if not O.possede(valeur) then
                Ob.recevoir(o.code, false, true)
                notif(o)
            end
        end
    end
    local i = O.inv()
    local niveauAvant = tonumber(i.SecurityLevel) or 0
    Ob.definirNiveau(badges)
    -- badges qui font monter le niveau : les derniers recus
    table.sort(parBadge, function(a, b) return a[1] < b[1] end)
    for n = niveauAvant + 1, math.min(badges, #parBadge) do notif(parBadge[n][2]) end
    -- Series : les k premiers objets valides de la serie, pas un de plus
    for prefixe, k in pairs(series) do
        table.sort(parSerie[prefixe], function(a, b) return a[1] < b[1] end)
        local donnes = 0
        for n = 0, 9 do
            if donnes >= k then break end
            local nom = prefixe .. n
            local ok, valide = pcall(function() return i:IsItemValid(FName(nom)) end)
            if not ok or valide then
                Ob.recus[nom] = true
                donnes = donnes + 1
                if not O.possede(nom) then
                    Ob.recevoir("objet:" .. nom, false, true)
                    local o = parSerie[prefixe][donnes]
                    notif(o and o[2])
                end
            end
        end
    end
end

-- Nouveau chargement de partie (Gregory recree) : on reapplique tout
local dernierGregory = nil
O.boucle(2000, function()
    if not O.stable then return false end
    local g = O.gregory()
    local nom = g and g:GetFullName() or nil
    if nom and nom ~= dernierGregory then
        dernierGregory = nom
        if M.connecte then
            O.apres(1000, function() appliquerTout(true) end)
            H.premiereFois()
        end
    end
    return false
end)

-- ---------- commandes du pont ----------
local function traiter(c)
    local cmd = c[1]
    if cmd == "session" then
        enSession = true
        objets = {}
        O.LANGUE = c[2]
        P.DUREE_BORNES = tonumber(c[3]) or P.DUREE_BORNES
        P.DUREE_LENT = tonumber(c[6]) or P.DUREE_LENT
        P.DUREE_ENTRAVE = tonumber(c[7]) or P.DUREE_ENTRAVE
        P.DUREE_TURBO = tonumber(c[8]) or P.DUREE_TURBO
        P.VITESSE_TURBO = tonumber(c[9]) or P.VITESSE_TURBO
        P.VITESSE_ENDURANCE = tonumber(c[10]) or P.VITESSE_ENDURANCE
    elseif cmd == "garder" then
        R.garder(c)
    elseif cmd == "contenu" then
        R.contenus[c[2]] = {nom = c[3], joueur = c[4] or "", code = c[5] or ""}
    elseif cmd == "fait" then
        R.marquerFait(c[2])
    elseif cmd == "objet" then
        local index = tonumber(c[2])
        local nouveau = objets[index] == nil
        objets[index] = {code = c[3], de = c[4], nom = c[5]}
        if not enSession and nouveau and c[6] == "1" then
            H.recu(c[5], c[4], c[3])
            appliquerTout(false)   -- arrive en direct : deja notifie
        end
    elseif cmd == "piege" then
        P.recevoir(c[2], c[3] == "1", c[4] ~= "" and c[4] or nil)
    elseif cmd == "bonus" then
        B.stock[c[2]] = tonumber(c[3]) or 0
    elseif cmd == "deathlink" then
        M.mortRecue = os.time()
        if c[3] and c[3] ~= "" then O.afficher(c[3], 5.0) end
        P.deathLink(c[2])
    elseif cmd == "objectif" then
        H.majObjectif({pseudo = c[2], seed = c[3], fin = c[4], fins = c[5],
            cadeaux = {tonumber(c[6]) or 0, tonumber(c[7]) or 0}, messages = {tonumber(c[8]) or 0, tonumber(c[9]) or 0},
            cd = {tonumber(c[10]) or 0, tonumber(c[11]) or 0}})
    elseif cmd == "goal" then
        H.ouvrirGoal()
    elseif cmd == "bienvenue_vue" then
        H.vue = true   -- carte deja montree pour cette partie AP
    elseif cmd == "recu" then
        H.recu(c[2], c[3])
    elseif cmd == "envoye" then
        H.envoye(c[2], c[3])
    elseif cmd == "affiche" then
        O.afficher(c[2], 4.0)
    elseif cmd == "pret" then
        enSession = false
        M.connecte = true
        R.modeAP = true
        appliquerTout(true)
        P.connexion()
        O.afficher(O.LANGUE == "en" and "Archipelago: connected" or "Archipelago : connecte", 3.0)
        H.premiereFois()
    end
end

-- Ce qui est deja dans le fichier vient d'une session precedente (pont ferme depuis) : ignore, sinon le
-- jeu se croyait connecte a l'ancienne room. Le pont renvoie la session quand il recoit "bonjour".
local position = 0
do
    local f = io.open(ENTREE, "r")
    if f then position = f:seek("end") f:close() end
end
O.boucle(500, function()
    local f = io.open(ENTREE, "r")
    if not f then return false end
    local taille = f:seek("end")
    if taille < position then position = 0 end   -- fichier remis a zero par le pont
    if taille > position then
        f:seek("set", position)
        local bloc = f:read(taille - position)
        -- seulement les lignes completes
        local fin = bloc:match(".*()\n")
        if fin then
            position = position + fin
            local lignes = bloc:sub(1, fin)
            ExecuteInGameThread(function()
                for brute in lignes:gmatch("([^\n]*)\n") do
                    local ligne = brute:gsub("\r$", "")
                    if ligne ~= "" then
                        local ok, err = pcall(traiter, decouper(ligne))
                        if not ok then O.log("erreur commande", ligne, tostring(err)) end
                    end
                end
            end)
        end
    end
    f:close()
    return false
end)

-- ---------- evenements vers le pont ----------
R.surCheck = function(id, objet, genre) ecrire("check", id, genre or "") end
F.surFin = function(fin) ecrire("fin", fin) end
B.surUtilisation = function(id) ecrire("bonus", id) end
H.surPremiereFois = function() ecrire("bienvenue") end
-- Mort du joueur (pas celle causee par un DeathLink recu) -> DeathLink sortant
S.surMort[#S.surMort + 1] = function()
    if M.mortRecue and os.time() - M.mortRecue < 15 then return end
    -- (le screamer du DeathLink peut tuer plusieurs secondes apres son lancement)
    if O.mortDeathLink and os.time() - O.mortDeathLink < 30 then return end
    ecrire("mort")
end

-- Le jeu vient de demarrer : le pont renvoie toute la session (le pont cree le dossier d'echange)
ecrire("bonjour")

-- Room enregistree par le launcher (connection.json) : on lance le pont sans fenetre, le jeu se connecte
-- sans que le launcher soit ouvert. Le pont refuse de tourner en double et s'arrete avec le jeu.
local function lancerPont()
    local f = io.open(DOSSIER .. "connection.json", "r")
    if not f then return end
    f:close()
    local rel = H.dossier .. "/pont/FNaF_SB_AP_Pont.exe"
    local e = io.open(rel, "rb")
    if not e then O.log("pont introuvable :", rel) return end
    e:close()
    -- chemin absolu obligatoire : LaunchURL du moteur prenait le chemin relatif pour une adresse web et
    -- l'ouvrait dans le navigateur ("telecharger FNaF_SB_AP_Pont.exe"). Lance par Windows directement
    -- (une fenetre de console peut clignoter une fraction de seconde).
    local exe = rel
    pcall(function()
        local p = StaticFindObject("/Script/Engine.Default__BlueprintPathsLibrary"):ConvertRelativePathToFull(rel, "")
        local s = p:ToString()
        if s and s ~= "" then exe = s end
    end)
    exe = exe:gsub("/", "\\")
    -- Le pont qui demarre vide vers_jeu.txt puis y reecrit la session. On partait de la fin de l'ancien
    -- fichier : si la nouvelle session etait aussi longue, "session" et "pret" etaient sautes et le mod
    -- restait hors mode AP (objets ramasses gardes, fenetre du jeu au lieu de la notif). Fichier efface ici :
    -- tout ce qui arrive ensuite est nouveau.
    os.remove(ENTREE)
    position = 0
    os.execute('start "" /min "' .. exe .. '"')
    O.log("pont lance :", exe)
end
ExecuteInGameThread(function() pcall(lancerPont) end)

return M
