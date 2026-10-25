-- Tout ramassable (Collectible) se supprime au chargement si le joueur possede deja son objet.
-- En archi, l'objet a pu etre recu du multiworld avant que le joueur passe a son emplacement : l'emplacement
-- disparaitrait et son check deviendrait impossible. On le recree aussitot au meme endroit, en retirant
-- l'objet du joueur le temps de la creation (meme methode que pour les pistolets de Fazer Blast).
local O = require("sb.outils")
local Ob = require("sb.objets")
local R = require("sb.ramassage")
local M = {}

local enCreation = false
local essais = {}   -- emplacement -> nombre de recreations (garde-fou contre une boucle)
local classeBase = nil

local function estRamassable(a)
    if not classeBase or not classeBase:IsValid() then
        classeBase = StaticFindObject("/Game/Blueprints/Objects/Collectibles/Collectible.Collectible_C")
    end
    local ok, r = pcall(function() return classeBase and a:IsA(classeBase) end)
    return ok and r == true
end

O.hook("/Script/Engine.Actor:K2_DestroyActor", function(self)
    if enCreation or not R.modeAP then return end
    local a = self:get()
    if not estRamassable(a) then return end
    -- Deja ramasse (par le joueur ou dans la sauvegarde) : suppression normale
    local okC, fini = pcall(function() return a.CollectComplete == true end)
    if okC and fini then return end
    local id = R.emplacement(a)
    if R.estFait(id) then return end
    local objet = O.s(a.ItemName)
    if not O.possede(objet) then return end
    essais[id] = (essais[id] or 0) + 1
    if essais[id] > 3 then return end
    local classe, transform = a:GetClass(), a:GetTransform()
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
            enCreation = true
            O.retirer(objet)
            local nouveau = gs:BeginDeferredActorSpawnFromClass(O.gregory(), classe, transform, 1, nil)
            R.alias[nouveau:GetFName():ToString()] = id
            -- Reglages poses dans la carte (sinon valeurs par defaut : autre motif, autre sac)
            for _, prop in ipairs({"ItemName", "Variant", "ColorChoice"}) do
                pcall(function() nouveau[prop] = a[prop] end)
            end
            gs:FinishSpawningActor(nouveau, transform)
            Ob.donneParMod = true
            O.rendre(objet)
            Ob.donneParMod = false
        end)
        enCreation = false
        Ob.donneParMod = false
        O.log(ok and "emplacement recree :" or "recreation impossible :", id, "(" .. objet .. ")", ok and "" or tostring(err))
    end)
end)

-- Les cadeaux, eux, ne disparaissent pas : si le joueur possede deja leur contenu, ils s'affichent
-- ouverts au chargement (ForceOpened) et refusent l'interaction. En mode archi, un cadeau dont
-- l'emplacement n'est pas fait est remis ferme et ouvrable.
local function aDejaObjet(a)
    return O.possede(O.s(a.ItemName))
end

local function refermer(self)
    if not R.modeAP then return end
    local a = self:get()
    if R.estFait(R.emplacement(a)) or not aDejaObjet(a) then return end
    O.apres(300, function()
        if not a:IsValid() then return end
        pcall(function() a["Reset Animation"](a) end)
        -- Le couvercle : variable IsOpen de son animation (BoingyBoxABP), animation relancee depuis le debut,
        -- et le couvercle fixe (StaticLid) reaffiche
        local etapes = {}
        -- (tableau UE4SS : ForEach, pas ipairs)
        pcall(function()
            a:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.SkeletalMeshComponent")):ForEach(function(_, e)
                local comp = e:get()
                pcall(function()
                    local anim = comp:GetAnimInstance()
                    if anim and anim:IsValid() then anim.IsOpen = false etapes[#etapes + 1] = "IsOpen" end
                    comp:SetAnimInstanceClass(comp.AnimClass)
                    etapes[#etapes + 1] = "anim relancee (" .. comp:GetFName():ToString() .. ")"
                end)
            end)
        end)
        pcall(function() a.StaticLid:SetVisibility(true, true) etapes[#etapes + 1] = "couvercle" end)
        a.CollectComplete = false
        a.CanCollect = true
        O.log("cadeau remis ferme :", R.emplacement(a), table.concat(etapes, ", "))
    end)
end
-- Le jeu l'ouvre au chargement par l'une de ces fonctions selon le cas
local P = "/Game/Blueprints/Objects/Collectibles/PresentCollectible.PresentCollectible_C:"
for _, f in ipairs({"ForceOpened", "OnLoadCollected", "ReceiveBeginPlay"}) do O.hook(P .. f, refermer) end

O.hook("/Game/Blueprints/Objects/Collectibles/Collectible.Collectible_C:CanPlayerInteract", function(self, peut, raison)
    if not R.modeAP then return end
    local a = self:get()
    -- (CollectComplete n'est pas fiable ici : le jeu le met a vrai des qu'on recoit l'objet)
    if R.estFait(R.emplacement(a)) or not aDejaObjet(a) then return end
    pcall(function() peut:set(true) raison:set(0) end)
end)

-- Des qu'on recoit un objet, le jeu marque ses ramassables comme deja pris (meme sans les avoir vus) :
-- on remet ceux dont l'emplacement n'est pas fait
function M.rouvrir(objet)
    if not R.modeAP then return end
    for _, a in ipairs(FindAllOf("Collectible_C") or {}) do
        pcall(function()
            if a:IsValid() and O.s(a.ItemName) == objet and not R.estFait(R.emplacement(a)) then
                a.CollectComplete = false
                a.CanCollect = true
                pcall(function() a["Reset Animation"](a) end)
                O.log("emplacement remis ouvrable apres reception :", R.emplacement(a))
            end
        end)
    end
end

Ob.surDon = M.rouvrir

return M
