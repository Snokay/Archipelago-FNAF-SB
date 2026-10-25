-- Musique du concert de Showtime remplacee par "ZINOXE EL DICTATOR" (musique IA de Zinoxe, musique/showtime.mp3).
-- Le pupitre de scene (StageControlBoard:PlayAmbient) lance la musique sur son emetteur Wwise "Ak" : on le
-- rend muet (SetOutputBusVolume 0) et on joue le mp3 depuis la scene avec le lecteur media du moteur
-- (MediaPlayer + MediaSoundComponent sur un acteur pose a cote). Arret quand le pupitre coupe son emetteur.
-- Pas de hook sur les envois de sons Wwise (appeles a chaque bruit de pas : freezes).
-- Rien n'est garde en objet entre deux appels, seulement des chemins (O.retrouver).
local O = require("sb.outils")
local H = require("sb.hud")

local FICHIER = "showtime.mp3"
local volumeMusiqueWwiseRendre = false   -- concert coupe par un chargement : volume musique a remettre
local VOLUME = 0.8   -- par rapport a la musique du jeu (Master x Musique des options)

local concert = nil   -- {acteur, joueur, son, emetteur = chemins}

-- le niveau detruit notre acteur : on oublie tout
O.surChargement[#O.surChargement + 1] = function()
    if concert then concert = nil volumeMusiqueWwiseRendre = true end
end

-- volume des options du jeu (0-1, ou 0-100 selon la version de la sauvegarde)
local function volumeJeu()
    local s = FindFirstOf("SaveGameSettings_C")
    if not O.vivant(s) then return 1.0 end
    local maitre, musique = tonumber(s.MasterVolume), tonumber(s.MusicVolume)
    -- reglages pas encore charges (tout a 0) : volume normal plutot que silence
    if not maitre or not musique or (maitre == 0 and musique == 0) then return 1.0 end
    local function n(v) return v > 1.0 and v / 100 or v end
    return n(maitre) * n(musique)
end

-- Musique du jeu (Wwise) coupee pendant le concert : la musique d'origine ne passe par aucun emetteur pres
-- de la scene (jouee par la scene cinematique), seul le volume musique de Wwise la fait taire
local function volumeMusiqueWwise(muet)
    local v = 100
    local s = FindFirstOf("SaveGameSettings_C")
    if not muet and O.vivant(s) then
        local m = tonumber(s.MusicVolume)
        if m then v = m <= 1.0 and m * 100 or m end
    end
    pcall(function()
        StaticFindObject("/Script/AkAudio.Default__AkGameplayStatics"):SetRTPCValue(nil, muet and 0.0 or v, 300, nil,
            FName("uservolume_music"))
    end)
end

local function absolu(fichier)
    local rel = H.dossier .. "/musique/" .. fichier
    local ok, p = pcall(function()
        return StaticFindObject("/Script/Engine.Default__BlueprintPathsLibrary"):ConvertRelativePathToFull(rel, "")
    end)
    if ok and p then
        local okS, s = pcall(function() return p:ToString() end)
        if okS and s and s ~= "" then return s end
    end
    return rel
end

local function muet(chemin, oui)
    local em = O.retrouver(chemin)
    if em then pcall(function() em:SetOutputBusVolume(oui and 0.0 or 1.0) end) end
end

-- Musique de fond du lieu (etat Wwise LOCATION_MUSIC) : coupee pendant le concert, remise ensuite
local etatLieu = nil
local nousMemes = false
local function etatMusique(valeur)
    pcall(function()
        StaticFindObject("/Script/AkAudio.Default__AkGameplayStatics"):SetState(FName("LOCATION_MUSIC"), FName(valeur))
    end)
end
O.hook("/Script/AkAudio.AkGameplayStatics:SetState", function(self, groupe, etat)
    local okG, g = pcall(function() return groupe:get():ToString() end)
    local okE, e = pcall(function() return etat:get():ToString() end)
    if okG and okE and g == "LOCATION_MUSIC" and e ~= "MUS_None" then etatLieu = e end
end)

local function arreter()
    local e = concert
    if not e then return end
    concert = nil
    local mp = O.retrouver(e.joueur)
    if mp then pcall(function() mp:Close() end) end
    local a = O.retrouver(e.acteur)
    if a then pcall(function() a:K2_DestroyActor() end) end
    if e.emetteur then muet(e.emetteur, false) end
    if etatLieu then etatMusique(etatLieu) end
    volumeMusiqueWwise(false)
    O.log("musique du concert arretee")
end

local function transforme(pos)
    return {Translation = pos, Rotation = {X = 0, Y = 0, Z = 0, W = 1}, Scale3D = {X = 1, Y = 1, Z = 1}}
end

-- son place sur la scene, plus faible en s'eloignant
local function jouer(pos, emetteur)
    arreter()
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local t = transforme(pos)
    local a = gs:BeginDeferredActorSpawnFromClass(O.gregory(), StaticFindObject("/Script/Engine.Actor"), t, 1, nil)
    gs:FinishSpawningActor(a, t)
    local comp = a:AddComponentByClass(StaticFindObject("/Script/MediaAssets.MediaSoundComponent"), false,
        transforme({X = 0, Y = 0, Z = 0}), false)
    if not (comp and comp:IsValid()) then error("composant son impossible") end
    a:K2_SetActorLocation(pos, false, {}, false)
    local mp = StaticConstructObject(StaticFindObject("/Script/MediaAssets.MediaPlayer"), a)
    comp:SetMediaPlayer(mp)
    -- SetMediaPlayer ne garde qu'une reference faible : le ramasse-miettes supprimait le lecteur (coupure
    -- a 45 s, 25/10). La propriete MediaPlayer du composant le retient.
    pcall(function() comp.MediaPlayer = mp end)
    -- Son place dans le jeu, comme la musique d'origine : plein volume pres de la scene, puis plus faible et
    -- plus etouffe en s'eloignant. MediaSoundComponent ne spatialise que le MONO (stereo = "dans le casque").
    local function regle(nom, f) local ok = pcall(f) if not ok then O.log("concert : reglage impossible", nom) end end
    regle("mono", function() comp.Channels = 0 end)
    regle("spatial", function() comp.bAllowSpatialization = true end)
    regle("override", function() comp.bOverrideAttenuation = true end)
    regle("attenuation", function()
        local at = comp.AttenuationOverrides
        at.bAttenuate = true
        at.bSpatialize = true
        at.AttenuationShapeExtents = {X = 1500, Y = 0, Z = 0}   -- rayon a plein volume autour de la scene
        at.FalloffDistance = 11000                               -- meme portee que l'originale (Wwise : 11000)
        at.bAttenuateWithLPF = true                              -- de loin, son etouffe
        at.LPFRadiusMin = 1500
        at.LPFRadiusMax = 11000
        at.LPFFrequencyAtMax = 2500
    end)
    pcall(function()
        local at, l = comp.AttenuationOverrides, comp:K2_GetComponentLocation()
        O.log("concert : canaux", tostring(comp.Channels), "spatial", tostring(comp.bAllowSpatialization),
            "portee", tostring(at.FalloffDistance), "rayon", tostring(at.AttenuationShapeExtents.X),
            "position", math.floor(l.X), math.floor(l.Y), math.floor(l.Z))
    end)
    pcall(function() comp:SetVolumeMultiplier(VOLUME * volumeJeu()) end)
    -- pas de bIsUISound : son "dans le casque", plus de salle (joueur 25/10). Le lecteur reste actif en pause.
    pcall(function() a:SetTickableWhenPaused(true) end)
    pcall(function() comp:SetTickableWhenPaused(true) end)
    mp.PlayOnOpen = true
    mp:SetLooping(true)
    pcall(function() comp:Start() end)
    local chemin = absolu(FICHIER)
    local ok = mp:OpenFile(chemin)
    mp:SetLooping(true)
    concert = {acteur = O.chemin(a), joueur = O.chemin(mp), son = O.chemin(comp), emetteur = emetteur}
    if emetteur then muet(emetteur, true) end
    etatMusique("MUS_None")
    volumeMusiqueWwise(true)
    concert.debut = os.clock()
    -- le volume coupe ne suffisait pas : on arrete l'emetteur du pupitre (notre propre Stop est ignore)
    -- et on note les emetteurs actifs pres de la scene, pour trouver celui qui joue encore la musique
    O.apres(500, function()
        local em = emetteur and O.retrouver(emetteur)
        if em then nousMemes = true pcall(function() em:Stop() end) nousMemes = false end
        local actifs = {}
        for _, c in ipairs(FindAllOf("AkComponent") or {}) do
            local ok, info = pcall(function()
                if not c:IsValid() or not c:HasActiveEvents() then return nil end
                local l = c:K2_GetComponentLocation()
                local d = math.sqrt((l.X - pos.X) ^ 2 + (l.Y - pos.Y) ^ 2 + (l.Z - pos.Z) ^ 2)
                if d > 8000 then return nil end
                return c:GetFullName():match("[^%.]+%.[^%.]+$") .. " (" .. math.floor(d) .. ")"
            end)
            if ok and info then actifs[#actifs + 1] = info end
        end
        O.log("emetteurs actifs pres de la scene :", table.concat(actifs, " | "))
    end)
    O.log("musique du concert :", chemin, ok and "ouverte" or "ECHEC ouverture")
end

-- le joueur change le volume de la musique dans les options : on suit (seulement pendant le concert)
O.boucle(2000, function()
    if volumeMusiqueWwiseRendre and O.stable then
        volumeMusiqueWwiseRendre = false
        volumeMusiqueWwise(false)
    end
    if not concert then return false end
    local c = O.retrouver(concert.son)
    if c then pcall(function() c:SetVolumeMultiplier(VOLUME * volumeJeu()) end) end
    -- diagnostic (musique coupee en route, 25/10) : etat du lecteur seulement quand il change
    local mp = O.retrouver(concert.joueur)
    local etat = "lecteur disparu"
    if mp then
        local okJ, joue = pcall(function() return mp:IsPlaying() end)
        local okT, t = pcall(function() return mp:GetTime().Ticks / 1e7 end)
        etat = (okJ and joue) and "joue" or "arrete"
        concert.t = math.floor(os.clock() - (concert.debut or os.clock()))
    end
    local g, a = O.gregory(), O.retrouver(concert.acteur)
    if g and a then
        pcall(function()
            local p, q = g:K2_GetActorLocation(), a:K2_GetActorLocation()
            concert.d = math.floor(math.sqrt((p.X - q.X) ^ 2 + (p.Y - q.Y) ^ 2 + (p.Z - q.Z) ^ 2))
        end)
    end
    -- hors de portee (au-dela de la portee du son) : le spectacle est fini pour nous
    if concert.d and concert.d > 12000 then O.apres(1, arreter) return false end
    if etat ~= concert.etat then
        concert.etat = etat
        O.log("concert :", etat, "a", tostring(concert.t), "s, distance", tostring(concert.d))
    end
    return false
end)

local function objet(p)
    local ok, x = pcall(function() return p:get() end)
    return ok and x or nil
end

O.hook("/Game/Blueprints/Objects/StageControlBoard.StageControlBoard_C:PlayAmbient", function(self)
    local b = objet(self)
    if not (b and b:IsValid()) then return end
    -- le pupitre relance son ambiance a chaque rechargement de la scene (couloir du sous-sol, 25/10) :
    -- notre musique seulement pendant le spectacle, pas apres
    local okF, fini = pcall(function() return FindFirstOf("FNAFMissionSystem"):IsCompletedMission(FName("Showtime")) end)
    if okF and fini then return end
    local chemin = O.chemin(b)
    O.apres(1, function()
        local p = O.retrouver(chemin)
        if not p then return end
        local ak = p.Ak
        local pos = p:K2_GetActorLocation()
        local ok, err = pcall(jouer, {X = pos.X, Y = pos.Y, Z = pos.Z}, ak and ak:IsValid() and O.chemin(ak) or nil)
        if not ok then O.log("musique du concert impossible", tostring(err)) end
    end)
end)

-- Fin du spectacle = mission Showtime terminee (on coupe nous-memes l'emetteur du pupitre au debut, son
-- Stop de fin n'arrive donc plus : la musique continuait apres le show, 25/10)
O.hook("/Script/fnaf9.FNAFMissionSystem:CompleteMission", function(self, mission)
    if concert and O.s(mission) == "Showtime" then O.apres(1, arreter) end
end)

-- le pupitre coupe son emetteur a la fin du spectacle (appel rare ; sortie immediate hors concert)
O.hook("/Script/AkAudio.AkGameObject:Stop", function(self)
    if not concert or nousMemes then return end
    local c = objet(self)
    if c and c:IsValid() and O.chemin(c) == concert.emetteur then
        O.apres(1, arreter)
    end
end)

return {}
