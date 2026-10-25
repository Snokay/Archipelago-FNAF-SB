-- Le nom de Zinoxe en neon rose au-dessus du circuit de Roxy (suite de sa lettre, message RoxyBoss1 :
-- "Je l'ai eteint. Puis rallume. Puis eteint."). Texte 3D du moteur + 2 lumieres roses devant, qui
-- clignote de temps en temps. Recree dans chaque nouveau monde.
local O = require("sb.outils")

local TEXTE = "ZINOXE"
-- mur nord du circuit (bannieres Roxy Racers a Y 49035, Z 2744, de X 11600 a 24200), tourne vers la piste
local POS = {X = 17900, Y = 48900, Z = 3100}
local TAILLE = 420
local ROSE = {R = 255, G = 40, B = 190, A = 255}

local texte, lumieres, gen = nil, {}, 0

O.surChargement[#O.surChargement + 1] = function()
    texte, lumieres, gen = nil, {}, gen + 1
end

local function apparaitre(classe, pos, lacet)
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local c = StaticFindObject(classe)
    local a = math.rad(lacet) / 2
    local t = {Translation = pos, Rotation = {X = 0, Y = 0, Z = math.sin(a), W = math.cos(a)},
               Scale3D = {X = 1, Y = 1, Z = 1}}
    local acteur = gs:BeginDeferredActorSpawnFromClass(O.gregory(), c, t, 1, nil)
    gs:FinishSpawningActor(acteur, t)
    return acteur
end

local function allumer(oui)
    if texte and texte:IsValid() then texte:SetVisibility(oui, false) end
    for _, l in ipairs(lumieres) do
        if l:IsValid() then l:SetVisibility(oui, false) end
    end
end

-- allume ~8 s, puis eteint / rallume / eteint, et on recommence (s'arrete au chargement suivant)
local SEQUENCE = {{true, 8000}, {false, 300}, {true, 150}, {false, 500}, {true, 200}, {false, 1500}}
local function clignoter(g, i)
    if g ~= gen or not texte then return end
    local etape = SEQUENCE[i]
    allumer(etape[1])
    O.apres(etape[2], function() clignoter(g, i % #SEQUENCE + 1) end)
end

local function poser()
    local acteur = apparaitre("/Script/Engine.TextRenderActor", POS, -90)
    local tr = acteur.TextRender
    tr:K2_SetText(FText(TEXTE))
    tr:SetTextRenderColor(ROSE)
    tr:SetWorldSize(TAILLE)
    tr:SetHorizontalAlignment(1)   -- centre
    tr:SetVerticalAlignment(1)     -- centre
    texte = tr
    for _, dx in ipairs({-600, 600}) do
        local l = apparaitre("/Script/Engine.PointLight", {X = POS.X + dx, Y = POS.Y - 350, Z = POS.Z}, 0)
        local c = l.PointLightComponent
        c:SetMobility(2)               -- mobile (lumiere ajoutee en jeu)
        c:SetLightColor({R = 1.0, G = 0.15, B = 0.75, A = 1.0}, true)
        c:SetIntensity(20000)
        c:SetAttenuationRadius(1800)
        lumieres[#lumieres + 1] = c
    end
    O.log("neon pose :", TEXTE)
    clignoter(gen, 1)
end

O.boucle(2000, function()
    if not O.stable or texte then return false end
    local ok, err = pcall(poser)
    if not ok then
        O.log("neon impossible", tostring(err))
        return true
    end
    return false
end)

return {}
