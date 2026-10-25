-- Affichage AP construit en Lua (widgets UMG crees a la volee, sans mod Blueprint) :
-- notifications "Recu / Envoye" en haut a droite, une a la fois.
local O = require("sb.outils")
local M = {}

-- Dossier du mod (images), deduit du chemin de ce script : .../ArchipelagoSB/Scripts/sb/hud.lua
local src = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
M.dossier = src:match("^(.*)/Scripts/sb/[^/]+$") or "ue4ss/Mods/ArchipelagoSB"

local hote, canvas, n = nil, nil, 0
local textures = {}

local function classe(nom) return StaticFindObject("/Script/UMG." .. nom) end
local function creer(nom, outer)
    n = n + 1
    return StaticConstructObject(classe(nom), outer, FName("APSB_" .. nom .. n))
end
local function couleur(r, g, b, a) return {R = r, G = g, B = b, A = a or 1.0} end

-- On emprunte un widget du jeu (sous-titres) comme support et on remplace son contenu par notre canvas
local function support()
    if hote and hote:IsValid() and canvas and canvas:IsValid() then return true end
    local pc = FindFirstOf("MainGamePC_C")
    if not pc or not pc:IsValid() then return false end
    local chemin = "/Game/Blueprints/UI/Subtitles/WI_Subtitles.WI_Subtitles_C"
    local cls = StaticFindObject(chemin)
    if not cls or not cls:IsValid() then cls = LoadAsset(chemin) end
    hote = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary"):Create(pc, cls, pc)
    canvas = creer("CanvasPanel", hote.WidgetTree)
    hote.WidgetTree.RootWidget = canvas
    hote:AddToViewport(60)
    return true
end

-- contexte : objet du monde pour l'import (sinon le controleur du joueur, du menu ou de l'ecran de lancement)
-- textures[fichier] = chemin de la texture importee (voir O.retrouver)
function M.texture(fichier, contexte)
    local t = O.retrouver(textures[fichier])
    if t then return t end
    local krl = StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
    -- contexte de monde : le controleur du joueur, celui du menu ou de l'ecran de lancement
    local monde = contexte
    for _, c in ipairs(monde and {} or {"MainGamePC_C", "TitlePC_C", "SplashPC_C", "PlayerController"}) do
        monde = FindFirstOf(c)
        if monde and monde:IsValid() then break end
    end
    t = krl:ImportFileAsTexture2D(monde, M.dossier .. "/images/" .. fichier)
    if t and t:IsValid() then textures[fichier] = O.chemin(t) return t end
    O.log("image introuvable :", M.dossier .. "/images/" .. fichier)
end

local function texte(outer, chaine, taille, c)
    local t = creer("TextBlock", outer)
    t:SetText(FText(chaine))
    pcall(function() t.Font.Size = taille end)
    t:SetColorAndOpacity({SpecifiedColor = c, ColorUseRule = 0})
    t:SetShadowOffset({X = 2, Y = 2})
    t:SetShadowColorAndOpacity(couleur(0, 0, 0, 0.8))
    return t
end

-- Une carte : fond sombre, liseré neon a gauche, icone, puis 3 lignes (titre, objet, joueur)
local function carte(titre, objet, ligne3, neon, icone)
    local tree = hote.WidgetTree
    local cadre = creer("Border", tree)
    cadre:SetBrushColor(couleur(0.02, 0.0, 0.05, 0.85))
    cadre:SetPadding({Left = 0, Top = 0, Right = 18, Bottom = 0})
    local rangee = creer("HorizontalBox", tree)
    cadre:SetContent(rangee)

    local lisere = creer("Border", tree)
    lisere:SetBrushColor(neon)
    local tailleLisere = creer("SizeBox", tree)
    tailleLisere:SetWidthOverride(6)
    tailleLisere:SetContent(lisere)
    rangee:AddChildToHorizontalBox(tailleLisere)

    local tex = (icone and icone:IsValid()) and icone or M.texture("ap.png")
    if tex then
        local img = creer("Image", tree)
        img:SetBrushFromTexture(tex, false)
        local boite = creer("SizeBox", tree)
        boite:SetWidthOverride(64)
        boite:SetHeightOverride(64)
        boite:SetContent(img)
        local s = rangee:AddChildToHorizontalBox(boite)
        s:SetPadding({Left = 14, Top = 10, Right = 14, Bottom = 10})
        s:SetVerticalAlignment(2)
    end

    local col = creer("VerticalBox", tree)
    col:AddChildToVerticalBox(texte(tree, titre, 14, neon))
    col:AddChildToVerticalBox(texte(tree, objet, 24, couleur(1, 1, 1)))
    col:AddChildToVerticalBox(texte(tree, ligne3, 15, couleur(0.75, 0.75, 0.85)))
    local s = rangee:AddChildToHorizontalBox(col)
    s:SetPadding({Left = 0, Top = 8, Right = 0, Bottom = 8})
    s:SetVerticalAlignment(2)
    return cadre
end

local file, enCours = {}, false
local X, Y = -30, 140

-- Apparition : glisse depuis la droite et fondu (0,25 s), reste, puis fondu de sortie
local function suivante()
    local e = table.remove(file, 1)
    if not e then enCours = false return end
    enCours = true
    local ok, err = pcall(function()
        if not support() then error("pas de controleur") end
        local c = carte(e.titre, e.objet, e.ligne3, e.neon, e.icone)
        local slot = canvas:AddChildToCanvas(c)
        slot:SetAnchors({Minimum = {X = 1, Y = 0}, Maximum = {X = 1, Y = 0}})
        slot:SetAlignment({X = 1, Y = 0})
        slot:SetAutoSize(true)
        local pas = 0
        local function anim()
            if not c:IsValid() then suivante() return end
            pas = pas + 1
            local a
            if pas <= 15 then a = pas / 15
            elseif pas <= 15 + e.duree * 60 then a = 1
            elseif pas <= 30 + e.duree * 60 then a = (30 + e.duree * 60 - pas) / 15
            else c:RemoveFromParent() suivante() return end
            local glisse = (1 - a) * 60
            c:SetRenderOpacity(a)
            slot:SetPosition({X = X + (pas <= 15 and glisse or 0), Y = Y})
            O.apres(16, anim)
        end
        anim()
    end)
    if not ok then
        O.log("notif impossible :", tostring(err))
        O.afficher(e.titre .. " : " .. e.objet .. " " .. e.ligne3)
        suivante()
    end
end

function M.notif(titre, objet, ligne3, neon, duree, icone)
    file[#file + 1] = {titre = titre, objet = objet, ligne3 = ligne3 or "", neon = neon, duree = duree or 4, icone = icone}
    if not enCours then suivante() end
end

-- Icone d'inventaire du jeu pour un code d'objet AP (objet:X, prog:Prefixe_, badge), sinon nil.
-- Les messages n'ont pas d'icone dans le jeu.
function M.iconeJeu(code)
    local inv = O.inv()
    if not inv or not code then return nil end
    local genre, valeur = code:match("^(%w+):?(.*)$")
    local nom
    if genre == "objet" then nom = valeur
    elseif genre == "badge" then nom = "SecurityBadgeKitchen"
    elseif genre == "prog" then
        for i = 0, 9 do
            local ok, v = pcall(function() return inv:IsItemValid(FName(valeur .. i)) end)
            if ok and v then nom = valeur .. i break end
        end
    end
    if not nom then return nil end
    return M.iconeObjet(nom)
end

local REFERENCE_MANQUANTE = "GregoryUpgrade_Stamina_4"

-- brute : sans ecarter l'image de remplacement
function M.iconeObjet(nom, brute)
    local inv = O.inv()
    if not inv or not nom then return nil end
    local info, trouve = {}, {}
    local ok, err = pcall(function() inv:GetItemInfo(FName(nom), info, trouve) end)
    local tex = ok and info.ItemIcon or nil
    if tex and (type(tex) ~= "userdata" or not tex:IsValid()) then tex = nil end
    -- certains objets n'ont que l'image de remplacement du jeu ("item image missing") ; le Mystery Mix
    -- en fait partie, son icone sert de reference
    if tex then
        if not M.remplacement and nom ~= REFERENCE_MANQUANTE then
            local ref = M.iconeObjet(REFERENCE_MANQUANTE, true)
            M.remplacement = ref and ref:GetFullName() or ""
        end
        if not brute and tex:GetFullName() == M.remplacement then
            tex = nil
        end
    end
    if not tex then O.log("icone du jeu introuvable :", nom, tostring(err)) end
    return tex
end

-- joueur vide = objet trouve dans son propre monde ; code = objet de notre jeu (icone du jeu)
function M.recu(objet, joueur, code)
    local en = O.LANGUE == "en"
    local de = (joueur and joueur ~= "") and ((en and "from " or "de ") .. joueur) or ""
    local icone
    if code then pcall(function() icone = M.iconeJeu(code) end) end
    M.notif(en and "RECEIVED" or "REÇU", objet, de, couleur(1.0, 0.25, 0.8), nil, icone)
end

function M.envoye(objet, joueur)
    local en = O.LANGUE == "en"
    M.notif(en and "SENT" or "ENVOYÉ", objet, (en and "to " or "à ") .. (joueur or "?"), couleur(0.3, 0.9, 1.0))
end

-- Briques partagees avec les autres affichages (roue des bonus)
M.creer, M.texte, M.couleur, M.support = creer, texte, couleur, support
function M.arbre() return hote.WidgetTree end
function M.canvas() return canvas end

-- ---------- carte de bienvenue (objectif + touches), H pour afficher / cacher ----------
M.objectif = nil   -- dernier etat envoye par le pont (commande "objectif")
M.vue = false      -- deja montree (depuis le lancement, ou pour cette partie AP : "bienvenue_vue" du pont)
local bienvenue

local NOMS_FINS = {
    LoadingDockEnding = {"Quai de chargement", "Loading Dock"},
    FazerblastEnding = {"Fazerblast", "Fazerblast"},
    VIPEnding = {"VIP", "VIP"},
    BurntrapEnding = {"Burntrap", "Burntrap"},
    GregoryInAlleyEnding = {"Ruelle", "Alley"},
}
local ORDRE_FINS = {"LoadingDockEnding", "FazerblastEnding", "VIPEnding", "BurntrapEnding", "GregoryInAlleyEnding"}

-- Ligne de la fin demandee et si elle est faite
local function ligneFin(d, en)
    local faites = {}
    for f in (d.fins .. ","):gmatch("([^,]*),") do if f ~= "" then faites[f] = true end end
    local n = 0
    for _, f in ipairs(ORDRE_FINS) do if faites[f] then n = n + 1 end end
    if d.fin == "n_importe_laquelle" then
        return (en and "Any ending" or "N'importe quelle fin"), n > 0
    elseif d.fin == "toutes" then
        return (en and "All endings" or "Toutes les fins") .. " (" .. n .. " / 5)", n >= 5
    end
    local nom = NOMS_FINS[d.fin] and NOMS_FINS[d.fin][en and 2 or 1] or d.fin
    return (en and "Ending: " or "Fin : ") .. nom, faites[d.fin] == true
end

-- Lignes de l'objectif (aussi affichees dans la roue des bonus) : {t = texte, fait = bool}
function M.lignesObjectif(en)
    local d = M.objectif
    if not d then
        return {{t = en and "Start the Archipelago bridge to see your goal" or
            "Lance le pont Archipelago pour voir ton objectif", fait = false}}
    end
    local nom, faite = ligneFin(d, en)
    local l = {{t = nom .. (faite and (en and "  -  done" or "  -  faite") or ""), fait = faite}}
    local genres = {{"cadeaux", en and "Gifts" or "Cadeaux"}, {"messages", "Messages"}, {"cd", en and "Retro CDs" or "CD rétro"}}
    for _, g in ipairs(genres) do
        local fait, exige = d[g[1]][1], d[g[1]][2]
        if exige > 0 then
            l[#l + 1] = {t = g[2] .. " : " .. math.min(fait, exige) .. " / " .. exige, fait = fait >= exige}
        end
    end
    return l
end

-- ---------- icones de touches (celles du jeu : clavier vierge + lettre, boutons Xbox) ----------
M.modeManette = false   -- dernier peripherique utilise (mis a jour par la roue, qui surveille la manette)

function M.texJeu(chemin)
    local nom = chemin:match("([^/]+)$")
    local t = O.retrouver(chemin .. "." .. nom)
    if t then return t end
    t = LoadAsset(chemin .. "." .. nom)
    if t and t:IsValid() then return t end
    O.log("texture du jeu introuvable :", chemin)
end

-- A chaque chargement, on oublie les objets du jeu gardes ici : le niveau suivant les detruit, et relire
-- un objet deja ramasse (meme pour IsValid) faisait planter le jeu. Tout est recree a la demande.
O.surChargement[#O.surChargement + 1] = function()
    hote, canvas, bienvenue = nil, nil, nil
end

-- Icone de touche a sa taille exacte : l'image recoit ses dimensions en pixels et n'est etiree par
-- aucun conteneur (alignee, pas "remplir")
local function iconeTouche(tree, spec)
    local h = 34
    local chemin
    if spec.manette then chemin = "/Game/UI_DLC/Art/Buttons/Xbox/T_Button_XB_" .. spec.manette
    elseif spec.clavier then chemin = "/Game/UI_DLC/Art/Buttons/PC/T_ButtonPCKeyBacking" end
    local tex = chemin and M.texJeu(chemin)
    local w = h
    if tex then
        local lx, ly = 0, 0
        pcall(function() lx, ly = tex:Blueprint_GetSizeX(), tex:Blueprint_GetSizeY() end)
        if lx > 0 and ly > 0 then w = math.floor(h * lx / ly + 0.5) end
    end
    local pile = creer("Overlay", tree)
    if tex then
        local img = creer("Image", tree)
        img:SetBrushFromTexture(tex, false)
        pcall(function() img:SetBrushSize({X = w, Y = h}) end)
        local sl = pile:AddChildToOverlay(img)
        sl:SetHorizontalAlignment(2)
        sl:SetVerticalAlignment(2)
    end
    if spec.clavier then
        local t = texte(tree, spec.clavier, #spec.clavier > 2 and 11 or (#spec.clavier > 1 and 13 or 16), couleur(1, 1, 1))
        t:SetShadowOffset({X = 0, Y = 0})
        local sl = pile:AddChildToOverlay(t)
        sl:SetHorizontalAlignment(2)
        sl:SetVerticalAlignment(2)
    end
    return pile
end

-- Une ligne "[icone] texte" ; spec nil = texte seul, aligne avec les autres
function M.ligneTouche(tree, spec, chaine, taille, c)
    local rangee = creer("HorizontalBox", tree)
    local marge = creer("SizeBox", tree)
    marge:SetWidthOverride(40)
    if spec then
        -- alignee a gauche et centree en hauteur (par defaut la colonne etire son contenu)
        local sl = marge:SetContent(iconeTouche(tree, spec))
        pcall(function() sl:SetHorizontalAlignment(1) sl:SetVerticalAlignment(2) end)
    end
    local s1 = rangee:AddChildToHorizontalBox(marge)
    s1:SetVerticalAlignment(2)
    local s2 = rangee:AddChildToHorizontalBox(texte(tree, chaine, taille, c))
    s2:SetVerticalAlignment(2)
    s2:SetPadding({Left = 10, Top = 0, Right = 0, Bottom = 0})
    return rangee
end

function M.changerMode(manette)
    if manette == M.modeManette then return end
    M.modeManette = manette
    if bienvenue and bienvenue:IsValid() then M.ouvrirBienvenue() end
end

function M.bienvenueOuverte() return bienvenue ~= nil and bienvenue:IsValid() end

function M.fermerBienvenue()
    if bienvenue and bienvenue:IsValid() then bienvenue:RemoveFromParent() end
    bienvenue = nil
end

function M.ouvrirBienvenue()
    M.fermerBienvenue()
    if not support() then return end
    M.vue = true
    local tree, d, en = hote.WidgetTree, M.objectif, O.LANGUE == "en"
    local rose, cyan = couleur(1.0, 0.25, 0.8), couleur(0.3, 0.9, 1.0)
    local blanc, gris, vert = couleur(1, 1, 1), couleur(0.7, 0.7, 0.8), couleur(0.4, 1.0, 0.5)

    -- liseré neon = bordure rose de 3 px autour du fond sombre
    local cadre = creer("Border", tree)
    cadre:SetBrushColor(rose)
    cadre:SetPadding({Left = 3, Top = 3, Right = 3, Bottom = 3})
    local fond = creer("Border", tree)
    fond:SetBrushColor(couleur(0.02, 0.0, 0.05, 0.92))
    fond:SetPadding({Left = 48, Top = 24, Right = 48, Bottom = 24})
    cadre:SetContent(fond)
    local col = creer("VerticalBox", tree)
    fond:SetContent(col)
    local function ajout(w, centre, haut)
        local sl = col:AddChildToVerticalBox(w)
        if centre then sl:SetHorizontalAlignment(2) end
        sl:SetPadding({Left = 0, Top = haut or 4, Right = 0, Bottom = 0})
    end

    local tex = M.texture("ap.png")
    if tex then
        local img = creer("Image", tree)
        img:SetBrushFromTexture(tex, false)
        local boite = creer("SizeBox", tree)
        boite:SetWidthOverride(128)
        boite:SetHeightOverride(128)
        boite:SetContent(img)
        ajout(boite, true, 0)
    end
    ajout(texte(tree, en and "WELCOME TO ARCHIPELAGO" or "BIENVENUE DANS ARCHIPELAGO", 30, rose), true, 12)

    ajout(texte(tree, en and "GOAL" or "OBJECTIF", 16, cyan), false, 22)
    if d then
        ajout(texte(tree, d.pseudo .. (d.seed ~= "" and ("  -  seed " .. d.seed) or ""), 14, gris), true, 0)
    end
    for _, l in ipairs(M.lignesObjectif(en)) do
        ajout(texte(tree, l.t, d and 20 or 18, l.fait and vert or (d and blanc or gris)))
    end

    ajout(texte(tree, en and "KEYS" or "TOUCHES", 16, cyan), false, 22)
    local touches
    if M.modeManette then
        touches = {
            {{manette = "Dpad_Down"}, en and "Hold: bonus wheel. Aim with the right stick, release to use"
                or "Maintenir : roue des bonus. Vise au stick droit, relâche pour utiliser"},
            {nil, en and "Your goal is also shown in the wheel" or "Ton objectif est aussi affiché dans la roue"},
        }
    else
        touches = {
            {{clavier = "G"}, en and "Bonus wheel (click to use, G to close)" or "Roue des bonus (clic pour utiliser, G pour fermer)"},
            {{clavier = "F10"}, en and "Unblock a stuck scene" or "Débloquer une scène coincée"},
            {{clavier = "H"}, en and "Show / hide this card" or "Afficher / cacher cette carte"},
        }
    end
    for _, t in ipairs(touches) do ajout(M.ligneTouche(tree, t[1], t[2], 17, blanc), false, 6) end
    local fermer = M.modeManette and {manette = "Dpad_Down"} or {clavier = "H"}
    local pied = M.ligneTouche(tree, fermer, en and "to close" or "pour fermer", 14, gris)
    ajout(pied, true, 20)

    local slot = canvas:AddChildToCanvas(cadre)
    slot:SetAnchors({Minimum = {X = 0.5, Y = 0.5}, Maximum = {X = 0.5, Y = 0.5}})
    slot:SetAlignment({X = 0.5, Y = 0.5})
    slot:SetAutoSize(true)
    bienvenue = cadre
    local pas = 0
    local function fondu()
        if bienvenue ~= cadre or not cadre:IsValid() then return end
        pas = pas + 1
        cadre:SetRenderOpacity(math.min(1, pas / 20))
        if pas < 20 then O.apres(16, fondu) end
    end
    fondu()
end

-- ---------- carte du goal (meme cadre que la bienvenue, vert et or), une fois par partie AP ----------
function M.ouvrirGoal(essai)
    essai = essai or 0
    M.fermerBienvenue()
    -- pendant la cinematique de fin le HUD peut manquer : on reessaie (2 s, jusqu'a 2 min)
    if not support() then
        if essai < 60 then O.apres(2000, function() M.ouvrirGoal(essai + 1) end) end
        return
    end
    local tree, d, en = hote.WidgetTree, M.objectif, O.LANGUE == "en"
    local or_, vert = couleur(1.0, 0.8, 0.2), couleur(0.4, 1.0, 0.5)
    local blanc, gris = couleur(1, 1, 1), couleur(0.7, 0.7, 0.8)

    local cadre = creer("Border", tree)
    cadre:SetBrushColor(vert)
    cadre:SetPadding({Left = 3, Top = 3, Right = 3, Bottom = 3})
    local fond = creer("Border", tree)
    fond:SetBrushColor(couleur(0.0, 0.04, 0.02, 0.92))
    fond:SetPadding({Left = 56, Top = 28, Right = 56, Bottom = 28})
    cadre:SetContent(fond)
    local col = creer("VerticalBox", tree)
    fond:SetContent(col)
    local function ajout(w, haut)
        local sl = col:AddChildToVerticalBox(w)
        sl:SetHorizontalAlignment(2)
        sl:SetPadding({Left = 0, Top = haut or 4, Right = 0, Bottom = 0})
    end

    local tex = M.texture("ap.png")
    if tex then
        local img = creer("Image", tree)
        img:SetBrushFromTexture(tex, false)
        local boite = creer("SizeBox", tree)
        boite:SetWidthOverride(128)
        boite:SetHeightOverride(128)
        boite:SetContent(img)
        ajout(boite, 0)
    end
    ajout(texte(tree, en and "GOAL REACHED!" or "GOAL ATTEINT !", 36, or_), 12)
    local pseudo = d and d.pseudo or ""
    ajout(texte(tree, en and ("Congratulations " .. pseudo .. ", you made it out of the Pizzaplex!")
        or ("Félicitations " .. pseudo .. ", tu t'es échappé du Pizzaplex !"), 20, blanc), 14)
    if d then
        for _, l in ipairs(M.lignesObjectif(en)) do ajout(texte(tree, l.t, 18, l.fait and vert or gris), 6) end
    end
    ajout(texte(tree, en and "Your remaining items have been sent to the multiworld."
        or "Tes objets restants ont été envoyés au multiworld.", 16, gris), 18)
    ajout(texte(tree, en and "Thanks for playing!" or "Merci d'avoir joué !", 18, or_), 10)
    local fermer = M.modeManette and {manette = "Dpad_Down"} or {clavier = "H"}
    ajout(M.ligneTouche(tree, fermer, en and "to close" or "pour fermer", 14, gris), 20)

    local slot = canvas:AddChildToCanvas(cadre)
    slot:SetAnchors({Minimum = {X = 0.5, Y = 0.5}, Maximum = {X = 0.5, Y = 0.5}})
    slot:SetAlignment({X = 0.5, Y = 0.5})
    slot:SetAutoSize(true)
    bienvenue = cadre   -- H la ferme comme la carte de bienvenue
    local pas = 0
    local function fondu()
        if bienvenue ~= cadre or not cadre:IsValid() then return end
        pas = pas + 1
        cadre:SetRenderOpacity(math.min(1, pas / 30))
        if pas < 30 then O.apres(16, fondu) end
    end
    fondu()
    O.log("carte du goal affichee")
end

function M.basculerBienvenue()
    if bienvenue and bienvenue:IsValid() then M.fermerBienvenue() else M.ouvrirBienvenue() end
end

-- Nouvel etat du pont : on garde, et on rafraichit la carte si elle est ouverte
function M.majObjectif(d)
    M.objectif = d
    if bienvenue and bienvenue:IsValid() then M.ouvrirBienvenue() end
end

-- Premiere partie chargee et connectee depuis le lancement du jeu. On attend un vrai moment sur
-- (partie chargee, Gregory controle, ni scene ni screamer, 5 s d'affilee) : ouverte pendant le chargement
-- du niveau, la carte chargeait ses textures en plein streaming et le jeu plantait.
local attenteBienvenue = false
function M.premiereFois()
    if M.vue or attenteBienvenue then return end
    attenteBienvenue = true
    local S = require("sb.securite")
    local suite = 0
    local function essai()
        if M.vue then attenteBienvenue = false return end
        local ok, sur = pcall(S.momentSur)
        suite = (ok and sur) and suite + 1 or 0
        if suite >= 5 then
            attenteBienvenue = false
            M.ouvrirBienvenue()
            if M.surPremiereFois then pcall(M.surPremiereFois) end
            return
        end
        O.apres(1000, essai)
    end
    O.apres(1000, essai)
end

O.touche(Key.H, M.basculerBienvenue)

return M
