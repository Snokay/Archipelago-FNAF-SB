-- Icone de chargement : le logo Archipelago qui tourne a la place de Helpy et sa pizza.
-- PizzaHelpy est un flipbook de 35 images (une seule visible a la fois, l'animation du jeu passe de
-- l'une a l'autre). On change la texture des 35 images MODELES de la classe : chaque ecran de chargement
-- cree ensuite les copie. Les modeles gardent aussi nos textures en vie.
-- La classe (et nos textures avec elle) peut etre ramassee entre deux passages, meme en pleine partie :
-- on ne garde que des chemins (O.retrouver), jamais les objets.
-- Images : outils/construire_chargement.py -> images/chargement/ap_00..34.png
local O = require("sb.outils")
local H = require("sb.hud")

local CLASSE = "/Game/Blueprints/UI/Loading/PizzaHelpy.PizzaHelpy_C"
-- dans l'ordre des images Helpy_Anim_pizza (0000 -> 0048)
local IMAGES = {
    "Image_8085", "Image_8089", "Image_8090", "Image_8091", "Image_8095", "Image_8096", "Image_8097",
    "Image_8102", "Image_8103", "Image_8104", "Image_8105", "Image_8106", "Image_8107", "Image_8108",
    "Image_8109", "Image_8110", "Image_8111", "Image_8112", "Image_8113", "Image_8114", "Image_8116",
    "Image_8117", "Image_8118", "Image_8120", "Image_8121", "Image_8122", "Image_8123", "Image_8124",
    "Image_8125", "Image_8126", "Image_8127", "Image_8130", "Image_8131", "Image_8132", "Image_8133",
}

-- Encore l'image de Helpy ? (la texture est tenue par le modele, donc lisible tant qu'il existe)
local function helpy(img)
    local res = img.Brush.ResourceObject
    return res and res:IsValid() and res:GetFName():ToString():find("^Helpy_Anim") ~= nil
end

local tour = 0
O.boucle(2000, function()
    if not O.calme() then return false end
    -- en partie, une fois toutes les 30 s : chercher une classe dechargee coute cher (freezes)
    tour = tour + 1
    if O.stable and tour % 15 ~= 0 then return false end
    local cls = O.retrouver(CLASSE)
    -- au menu seulement, on charge la classe nous-memes (en partie, ca ferait une saccade a chaque fois)
    if not cls and not O.stable then
        cls = LoadAsset(CLASSE)
        if not (cls and cls:IsValid()) then return false end
    end
    if not cls then return false end
    local premier = O.retrouver(CLASSE .. ":WidgetTree." .. IMAGES[1])
    if not premier or not helpy(premier) then return false end
    local textures = {}
    for i = 1, #IMAGES do
        textures[i] = H.texture(string.format("chargement/ap_%02d.png", i - 1))
        if not textures[i] then return false end
    end
    for i, nom in ipairs(IMAGES) do
        local img = O.retrouver(CLASSE .. ":WidgetTree." .. nom)
        if img then img:SetBrushFromTexture(textures[i], false) end
    end
    -- ecrans de chargement deja crees
    for _, w in ipairs(FindAllOf("PizzaHelpy_C") or {}) do
        if O.vivant(w) then
            for i, nom in ipairs(IMAGES) do
                local img = w[nom]
                if img and img:IsValid() then img:SetBrushFromTexture(textures[i], false) end
            end
        end
    end
    O.log("icone de chargement remplacee")
    return false
end)

return {}
