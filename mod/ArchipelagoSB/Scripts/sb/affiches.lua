-- Affiches perso : les affiches du jeu sont rangees sur des planches (une texture pour plusieurs cadres,
-- voir outils/construire_affiches.py). Chaque maillage qui utilise une de ces planches recoit la notre
-- (materiau dynamique, meme emplacement de texture).
-- Version ciblee : les composants qui portent les affiches sont connus d'avance (affiches_cibles.lua, genere
-- par outils/affiches_cibles.py depuis les cartes du jeu). Toutes les 3 s on les demande par leur nom :
-- une zone pas chargee repond nil. Pas de parcours du decor, pas de pointeur garde entre deux passages.
local O = require("sb.outils")
local H = require("sb.hud")
local CIBLES = require("sb.affiches_cibles")

local PLANCHES = {
    ENV_TEX_Posters_Office_02_A_TGA = "affiches_fnaf2.png",
    ENV_TEX_Posters_Office_01_A = "affiches_fnaf1.png",
    ENV_TEX_Posters_Office_03_A_TGA = "affiches_dessins.png",
    Poster_RoxyNegal = "poster_roxy.png",   -- decalcomanie (loge de Roxy)
}
-- Materiaux qui n'ecrasent pas la texture mais heritent de celle du parent (MAT_Master_Posters, emplacement
-- "Base Color", planche FNaF 1 par defaut) : invisibles pour la lecture des surcharges, donc listes ici
local HERITES = {
    ENV_MAT_Posters_Office_01_A = {param = "Base Color", fichier = "affiches_fnaf1.png"},
    MAT_Master_Posters = {param = "Base Color", fichier = "affiches_fnaf1.png"},
}

local materiaux = {}   -- nom complet du materiau du jeu -> {param, fichier} ou false
local erreurs = {}     -- erreurs deja ecrites au journal (une fois chacune)

-- emplacement de texture qui porte une planche d'affiches (une seule lecture par materiau)
local function planche(mat)
    -- notre materiau dynamique : affiche deja posee
    if mat:GetClass():GetFName():ToString() == "MaterialInstanceDynamic" then return false end
    local nom = mat:GetFullName()
    if materiaux[nom] == nil then
        materiaux[nom] = HERITES[mat:GetFName():ToString()] or false
        pcall(function()
            mat.TextureParameterValues:ForEach(function(_, e)
                local v = e:get()
                -- emplacement sans texture (MI_CeilingA...) : demander le nom d'un objet nul plantait UE4SS
                local tex = v.ParameterValue
                if not tex or not tex:IsValid() then return end
                local fichier = PLANCHES[tex:GetFName():ToString()]
                if fichier then materiaux[nom] = {param = v.ParameterInfo.Name:ToString(), fichier = fichier} end
            end)
        end)
    end
    return materiaux[nom]
end

local function decal(comp)
    local mat = comp:GetDecalMaterial()
    local p = mat and mat:IsValid() and planche(mat)
    if not p then return end
    local tex = H.texture(p.fichier)
    if tex then
        comp:CreateDynamicMaterialInstance():SetTextureParameterValue(FName(p.param), tex)
        O.log("affiche posee :", p.fichier, "sur", comp:GetOuter():GetFName():ToString())
    end
end

local function maillage(comp)
    for i = 0, comp:GetNumMaterials() - 1 do
        local mat = comp:GetMaterial(i)
        local p = mat and mat:IsValid() and planche(mat)
        if p then
            local tex = H.texture(p.fichier)
            if tex then
                local mid = comp:CreateDynamicMaterialInstance(i, mat, FName("None"))
                mid:SetTextureParameterValue(FName(p.param), tex)
                O.log("affiche posee :", p.fichier, "sur", comp:GetOuter():GetFName():ToString())
            end
        end
    end
end

-- carte de chaque affiche ("/Game/.../MAP_X.MAP_X:PersistentLevel..." -> MAP_X)
for _, c in ipairs(CIBLES) do c.carte = c[2]:match("/([%w_]+)%.[%w_]+:PersistentLevel") end

O.boucle(3000, function()
    if not O.stable then return false end
    -- Seulement les affiches des cartes chargees : chercher par son nom un objet d'une zone pas chargee
    -- coutait jusqu'a 800 ms (freeze toutes les 3 s)
    local charges = {}
    for _, lv in ipairs(FindAllOf("Level") or {}) do
        pcall(function() if lv:IsValid() then charges[lv:GetOuter():GetFName():ToString()] = true end end)
    end
    for _, c in ipairs(CIBLES) do
        local comp = charges[c.carte] and O.retrouver(c[2]) or nil
        if comp and not O.supprime(comp) then
            local ok, err = pcall(c[1] == "decal" and decal or maillage, comp)
            if not ok and not erreurs[tostring(err)] then
                erreurs[tostring(err)] = true
                O.log("affiches : erreur", tostring(err))
            end
        end
    end
    return false
end)

return {}
