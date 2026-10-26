-- Ramassages dans le monde = checks.
-- Un objet deja possede fait derailler son ramassage (porte-badge qui refuse, mission jamais finie) :
-- quand le joueur vise un objet qu'il a deja, on le retire le temps du ramassage. Ramasser les objets de
-- l'histoire doit toujours rester possible, c'est ce qui fait avancer les missions.
local O = require("sb.outils")
local Ob = require("sb.objets")
local M = {}

M.modeAP = false      -- connecte : l'objet ramasse est retire (il viendra d'Archipelago), sauf s'il a deja ete recu
M.surCheck = nil      -- fonction(emplacement, objet, genre), posee par le client
-- Objets jamais retires au ramassage (cles en minuscules : le code AP "ScrewDriver" = objet "Screwdriver")
-- Billet de la loge de Chica (sans lui, Fazer Blast ne se lance pas) et Mystery Mix (scriptes ; aussi pour les seeds
-- generees avant qu'il soit hors AP)
local JAMAIS_BASE = {fazwatch = true, map = true, partypasschicaroom = true,
    montymysterymix = true}
M.jamaisRetires = {fazwatch = true, map = true, partypasschicaroom = true,
    montymysterymix = true}
-- Liste envoyee par le pont (slot_data "garder") : objets hors AP et objets de sortie restes a leur place
function M.garder(c)
    M.jamaisRetires = {}
    for k in pairs(JAMAIS_BASE) do M.jamaisRetires[k] = true end
    for i = 2, #c do
        if c[i] ~= "" then M.jamaisRetires[c[i]:lower()] = true end
    end
end
function M.garde(nom) return nom ~= nil and M.jamaisRetires[tostring(nom):lower()] == true end
M.ignorer = {}        -- objet -> heure : le prochain don de cet objet n'est pas un check

local retenus = {}

local function objetsVises(a)
    local t = {}
    for _, champ in ipairs({"ItemName", "BadgeAward"}) do
        local ok, v = pcall(function() return O.s(a[champ]) end)
        if ok and v ~= "nil" and v ~= "None" and not v:find("Object") then t[#t + 1] = v end
    end
    return t
end

local function survol(self)
    local i = O.inv()
    local a = self:get()
    if not i or a.CollectComplete == true or a["HasAlreadyCollected?"] == true then return end
    for _, nom in ipairs(objetsVises(a)) do
        if O.possede(nom) then
            O.retirer(nom)
            retenus[a:GetFullName() .. "|" .. nom] = nom
            O.log("deja possede :", nom, "retire le temps du ramassage")
        end
    end
end

-- Pas ramasse finalement : on rend l'objet. 20 s, car l'animation de la boite Freddy dure ~15 s.
local function finSurvol(self)
    local prefixe = self:get():GetFullName() .. "|"
    O.apres(20000, function()
        local i = O.inv()
        for cle, nom in pairs(retenus) do
            if cle:sub(1, #prefixe) == prefixe then
                retenus[cle] = nil
                if i and not O.possede(nom) then
                    Ob.donneParMod = true
                    O.rendre(nom)
                    Ob.donneParMod = false
                end
            end
        end
    end)
end

for _, classe in ipairs({"/Game/Blueprints/Objects/Collectibles/Collectible.Collectible_C",
    "/Game/Model_Assets/SetsPRE/PRE_BadgeHolder.PRE_BadgeHolder_C"}) do
    O.hook(classe .. ":OnPlayerHoverEnter", function(self) pcall(survol, self) end)
    O.hook(classe .. ":OnPlayerHoverExit", function(self) pcall(finSurvol, self) end)
end

-- Identifiant d'emplacement : carte + nom de l'acteur pose dans la carte
-- Un emplacement recree par le mod (recreation.lua) a un nouveau nom : il garde l'identifiant d'origine
M.alias = {}
-- Objets crees par le jeu pendant une sequence (yeux de Roxy apres son combat, tete du StaffBot) : leur nom
-- genere change d'une partie a l'autre (griffes de Monty vues en "MAP_TheWorld:..._CAT_2147435131"), on les
-- reconnait a leur objet
local PAR_OBJET = {
    RoxyEyes = "Map_RoxyBossBattle:RoxyEyes_GEN_VARIABLE_InvisibleCollectible_C_CAT_0",
    DamagedHead = "MAP_RoxyRacer_Gameplay:CollectibleStaffbotHead_GEN_VARIABLE_CollectibleStaffbotHead_C_CAT_1",
}
local function emplacement(a)
    local nom = a:GetFName():ToString()
    local alias = M.alias[nom]
    if alias then return alias end
    if nom:find("_GEN_VARIABLE_") then
        local ok, objet = pcall(function() return O.s(a.ItemName) end)
        if ok and PAR_OBJET[objet] then return PAR_OBJET[objet] end
    end
    local plein = a:GetFullName()
    local carte = plein:match("/([^/.]+)%.[^:]+:PersistentLevel") or "?"
    return carte .. ":" .. a:GetFName():ToString()
end
M.emplacement = emplacement

-- Mode AP : l'objet ramasse dans le monde est retire (le vrai objet vient d'Archipelago). Le jeu le donne
-- parfois apres l'animation de ramassage (pass photo) : un seul essai a 1 s le ratait. On guette 10 s.
local function retirerDuMonde(objet)
    if not M.modeAP or Ob.recus[objet] or M.garde(objet) then return end
    -- les messages restent au joueur (check seulement, pas d'objet AP) : messages perso toujours lisibles
    if O.estMessage(objet) then return end
    local essais = 0
    local function essai()
        essais = essais + 1
        if Ob.recus[objet] then return end
        if O.possede(objet) then
            O.retirer(objet)
            O.log("objet du monde retire (il viendra d'Archipelago) :", objet)
            -- la lampe retiree de l'inventaire restait en main : on l'eteint et on la range
            if objet == "Flashlight" then
                O.lampeEnMain(O.gregory(), false)
            end
        elseif essais < 20 then
            O.apres(500, essai)
        end
    end
    O.apres(500, essai)
end

local fenetreCheck  -- plus bas (fenetre de ramassage du jeu)
local faits = {}
function M.estFait(id) return faits[id] == true end
function M.marquerFait(id) faits[id] = true end
local dernierObjet = nil  -- un message ramasse passe aussi par OnCollect : un seul check pour les deux
local function check(a, objet)
    local id = emplacement(a)
    pcall(fenetreCheck, id)
    -- retrait meme si l'emplacement est deja fait (sauvegarde rechargee : le ramassage redonne l'objet)
    dernierObjet = objet
    retirerDuMonde(objet)
    -- PresentCollectible herite de Collectible : son OnCollect peut passer deux fois
    if faits[id] then return end
    faits[id] = true
    O.log("CHECK", id, "(" .. objet .. ")")
    if M.surCheck then
        local c = a:GetClass():GetFName():ToString()
        local genre = c:find("Present") and "cadeau" or c:find("Message") and "message" or c:find("Tape") and "cd"
            or c:find("BadgeHolder") and "badge" or "special"
        pcall(M.surCheck, id, objet, genre)
    end
end

-- En mode AP, la fenetre "objet ramasse" du jeu montrait l'objet d'origine (ex. "Bon pour une photo").
-- On ne la coupe pas (la cacher ou l'arreter cassait son cycle : rond violet en boucle) : on remplace son
-- texte et son icone par le vrai contenu du check (envoye par le pont a la connexion).
local HUD = "/Game/Blueprints/UI/PlayerHUD.PlayerHUD_C"
M.contenus = {}        -- cle d'emplacement -> {nom, joueur ("" = moi), code}
local affiche = nil    -- contenu a montrer dans la fenetre en cours
local afficheJusqua = 0
local function remplacer(hud)
    if not affiche or os.clock() > afficheJusqua or not hud or not hud:IsValid() then return end
    local H = require("sb.hud")
    local en = O.LANGUE == "en"
    local texte, tex
    if affiche.joueur == "" then
        texte = affiche.nom .. (en and " obtained" or " obtenu")
        if affiche.code ~= "" then pcall(function() tex = H.iconeJeu(affiche.code) end) end
    else
        texte = (en and "You sent " or "Tu as envoye ") .. affiche.nom .. (en and " to " or " a ") .. affiche.joueur
    end
    tex = tex or H.texture("ap.png")
    pcall(function() hud.Informational:SetText(FText(texte)) end)
    if tex then pcall(function() hud.InformationItemImage:SetBrushFromTexture(tex, false) end) end
end
-- appele a chaque check ramasse : la fenetre du jeu est deja partie (ou part juste apres)
fenetreCheck = function(id)
    if not M.modeAP or not M.contenus[id] then return end
    affiche, afficheJusqua = M.contenus[id], os.clock() + 4
    O.log("fenetre ramassage :", id, affiche.nom, affiche.joueur)
    for _, d in ipairs({1, 300}) do
        O.apres(d, function() remplacer(FindFirstOf("PlayerHUD_C")) end)
    end
end
for _, f in ipairs({":ShowCollectedItemDisplay", ":Setup Collected Display"}) do
    O.hook(HUD .. f, function(self) remplacer(self:get()) end)
end

for _, chemin in ipairs({"/Game/Blueprints/Objects/Collectibles/Collectible.Collectible_C:OnCollect",
    "/Game/Blueprints/Objects/Collectibles/PresentCollectible.PresentCollectible_C:OnCollect"}) do
    O.hook(chemin, function(self)
        local a = self:get()
        pcall(check, a, O.s(a.ItemName))
    end)
end
-- Recompenses donnees par un script (Fazerblaster a la fin de Fazer Blast...) : aucun ramassage, mais
-- en mode AP l'objet ne doit pas rester si le joueur ne l'a pas recu. Chaque objet donne ainsi est un
-- check "recompense:<objet>" et il est retire. Ce que le jeu rend apres l'avoir pris (objet deja recu
-- d'AP) n'est pas touche, ni ce que le mod donne lui-meme.
O.hook("/Script/fnaf9.FNAFInventorySystem:AwardItem", function(self, item)
    if Ob.donneParMod then return end
    local objet = O.s(item)
    -- Don vide d'un script du jeu (zone des endos, 26/10) : le traiter comme un objet faisait planter le jeu
    if objet == "None" or objet == "nil" or objet == "" then return end
    -- Objet pret par le jeu le temps d'une sequence (pistolet de la table de Fazer Blast) : pas un check
    if M.ignorer[objet] and os.time() - M.ignorer[objet] < 30 then
        M.ignorer[objet] = nil
        return
    end
    -- Laisser OnCollect passer d'abord : si c'etait un ramassage dans le monde, il est deja compte
    O.apres(300, function()
        -- objet d'un ramassage dans le monde donne en retard : on relance le retrait
        if objet == dernierObjet then return retirerDuMonde(objet) end
        if Ob.recus[objet] or M.garde(objet) then return end
        local id = "recompense:" .. objet
        if not faits[id] then
            faits[id] = true
            O.log("CHECK", id)
            if M.surCheck then pcall(M.surCheck, id, objet, "recompense") end
        end
        retirerDuMonde(objet)
    end)
end)

-- Missions : 1 check par mission terminee (pas par etape), sauf le mode Survie
local function missionFinie(nom, rattrapage)
    if nom == "Survival" then return end
    local id = "mission:" .. nom
    if faits[id] then return end
    faits[id] = true
    -- La recompense de la mission arrive par un objet invisible cree par le jeu (griffes de Monty...) : son
    -- nom genere n'est pas un emplacement, la fenetre de ramassage affiche donc le contenu de la mission
    if not rattrapage then pcall(fenetreCheck, id) end
    O.log("CHECK", id, rattrapage and "(rattrapage)" or "")
    if M.surCheck then pcall(M.surCheck, id, nom, "mission") end
end
O.hook("/Script/fnaf9.FNAFMissionSystem:CompleteMission", function(self, mission)
    missionFinie(O.s(mission))
end)

-- Le jeu ne passe pas toujours par CompleteMission (Sortez d'ici, Que la lumiere soit, Echappez-vous de la
-- garderie : checks partis 2 h plus tard chez un joueur, 26/10) : on lui demande regulierement ce qui est fini.
-- Questions oui/non seulement (lire FFNAFMissionState en boucle faisait planter UE4SS).
local MISSIONS = {"FreeFreddy", "GetOut", "NoReEntry", "SlideIntoFun", "LetThereBeLight", "EscapeDaycare",
    "TakeMap", "KitchenOffice", "LoadingDock", "PrizeCounter", "FindFreddy", "LostAndFound", "RehearsalSpace",
    "Backstage", "Showtime", "PartsAndService", "PartyPass", "MoonlightSerenade", "RoxysWeakness", "DJMusicMan",
    "StopRoxy", "UpgradeFreddy", "ChicaBeak", "MontyClaws", "FazerBlast", "DumpsterDiving", "MontyMysteryMix",
    "PowerOn", "OfficeToOffice", "MontyGolf", "ThrillSeeker", "Warehouse", "RechargeTime", "PlanA", "GetOut!"}
O.boucle(5000, function()
    if not M.modeAP or not O.enPartie() then return end
    local ms = FindFirstOf("FNAFMissionSystem")
    if not ms or not ms:IsValid() then return end
    for _, nom in ipairs(MISSIONS) do
        if not faits["mission:" .. nom] and ms:IsCompletedMission(FName(nom)) then missionFinie(nom, true) end
    end
end)

-- Messages (notes, mails) : chaque message a un nom unique dans le jeu, c'est son identifiant
local messagesVus = {}
O.hook("/Script/fnaf9.FNAFInventorySystem:AwardMessage", function(self, message)
    if Ob.donneParMod then return end
    local nom = O.s(message)
    if messagesVus[nom] then return end
    -- Ramasse dans le monde : deja compte par OnCollect (l'emplacement), on ne refait pas de check.
    -- Sinon (message donne par l'histoire), c'est un check a part.
    if nom == dernierObjet then messagesVus[nom] = true return end
    messagesVus[nom] = true
    local id = "message:" .. nom
    if faits[id] then return end
    faits[id] = true
    O.log("CHECK", id)
    if M.surCheck then pcall(M.surCheck, id, nom, "message_histoire") end
end)

-- Lampe rangee par le mod (pas encore recue d'AP) : un clic affichait encore la jauge de batterie
O.hook("/Game/Blueprints/Player/Gregory.Gregory_C:ToggleFlashlight", function(self)
    if not O.lampeRangee then return end
    pcall(function() self:get():ForceHideBatteryLevelWidget() end)
end)

O.hook("/Game/Model_Assets/SetsPRE/PRE_BadgeHolder.PRE_BadgeHolder_C:Collect_SecurityBadge", function(self)
    local a = self:get()
    pcall(check, a, O.s(a.BadgeAward))
end)

return M
