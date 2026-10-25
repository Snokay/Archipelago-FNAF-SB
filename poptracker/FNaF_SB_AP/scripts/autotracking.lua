-- Suivi automatique Archipelago
local function reset()
    for _, c in pairs(ITEM_MAPPING) do
        local o = Tracker:FindObjectForCode(c)
        if o then
            if o.Type == "consumable" then o.AcquiredCount = 0 else o.Active = false end
        end
    end
    for _, path in pairs(LOCATION_MAPPING) do
        local s = Tracker:FindObjectForCode(path)
        if s then s.AvailableChestCount = s.ChestCount end
    end
end

-- Checks absents de cette partie (options : missions, messages ou CD coupés) : marqués faits pour
-- disparaître de la carte. slot_data.emplacements = {cle = id} des checks actifs.
local function masquer_inactifs(slot_data)
    if not slot_data or not slot_data.emplacements then return end
    local actifs = {}
    for _, id in pairs(slot_data.emplacements) do actifs[tonumber(id)] = true end
    for id, path in pairs(LOCATION_MAPPING) do
        if not actifs[id] then
            local s = Tracker:FindObjectForCode(path)
            if s then s.AvailableChestCount = 0 end
        end
    end
end

function on_clear(slot_data)
    Tracker.BulkUpdate = true
    pcall(reset)
    pcall(masquer_inactifs, slot_data)
    Tracker.BulkUpdate = false
end

function on_item(index, item_id, item_name, player)
    local c = ITEM_MAPPING[item_id]
    if not c then return end
    local o = Tracker:FindObjectForCode(c)
    if not o then return end
    if o.Type == "consumable" then o.AcquiredCount = o.AcquiredCount + 1 else o.Active = true end
end

function on_location(location_id, location_name)
    local path = LOCATION_MAPPING[location_id]
    if not path then return end
    local s = Tracker:FindObjectForCode(path)
    if s then s.AvailableChestCount = 0 end
end

Archipelago:AddClearHandler("clear", on_clear)
Archipelago:AddItemHandler("item", on_item)
Archipelago:AddLocationHandler("location", on_location)
