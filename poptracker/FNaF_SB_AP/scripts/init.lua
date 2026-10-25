-- FNaF Security Breach Archipelago : pack généré par outils/make_poptracker.py
ScriptHost:LoadScript("scripts/items_map.lua")
Tracker:AddItems("items/items.json")
Tracker:AddMaps("maps/maps.json")
ScriptHost:LoadScript("scripts/ids.lua")
Tracker:AddLocations("locations/locations.json")
Tracker:AddLayouts("layouts/tracker.json")
if Archipelago then
    ScriptHost:LoadScript("scripts/autotracking.lua")
end
