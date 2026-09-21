local _, Addon = ...
local version, _, _, interface = GetBuildInfo()
local isForever = type(version) == "string" and version:match("^1%.60%.") ~= nil and type(interface) == "number" and interface >= 16000 and interface < 16100
if not isForever then
    error("FojjiCore: the Forever integration requires a Forever 1.60.x client.")
end
Addon.AuraAPI = ForeverAuras
Addon.AuraSaved = ForeverAurasSaved
assert(type(Addon.AuraAPI) == "table" and type(Addon.AuraAPI.GetData) == "function" and type(Addon.AuraAPI.ScanEvents) == "function", "FojjiCore requires a working ForeverAuras installation on Forever.")
assert(type(Addon.AuraSaved) == "table", "FojjiCore: ForeverAuras saved settings are not initialized.")

local chatPrefix = "|TInterface\\AddOns\\FojjiCore\\textures\\F_icon_teal.png:16:16:0:0|t |cff66b3ffFojji|r|cffff4444Core|r: "

function Addon.Print(message)
    print(chatPrefix .. message)
end
