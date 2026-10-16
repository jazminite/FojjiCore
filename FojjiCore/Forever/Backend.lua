local _, Addon = ...
FojjiCoreNS = Addon
local version, _, _, interface = GetBuildInfo()
local foreverClient = type(version) == "string" and version:match("^1%.60%.") ~= nil and type(interface) == "number" and interface >= 16000 and interface < 16100
local retail = type(interface) == "number" and interface >= 120000
if not (foreverClient or retail) then
    error("FojjiCore: this build needs WoW Forever or Retail.")
end
Addon.IsForever = true
Addon.ForeverClient = foreverClient
Addon.IsRetail = retail and not foreverClient
Addon.AuraAPI = ForeverAuras
Addon.AuraSaved = ForeverAurasSaved
assert(type(Addon.AuraAPI) == "table" and type(Addon.AuraAPI.GetData) == "function" and type(Addon.AuraAPI.ScanEvents) == "function", "FojjiCore requires a working ForeverAuras installation.")
assert(type(Addon.AuraSaved) == "table", "FojjiCore: ForeverAuras saved settings are not initialized.")

local chatPrefix = "|TInterface\\AddOns\\FojjiCore\\textures\\F_icon_teal.png:16:16:0:0|t |cff66b3ffFojji|r|cffff4444Core|r: "

Addon.Tr = Addon.Tr or function(text) return text end

local reported = {}
function Addon.Report(err)
    err = tostring(err)
    if reported[err] then return end
    reported[err] = true
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) else print(err) end
end

function Addon.Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then Addon.Report(err) end
    end
end
Addon.Localize = Addon.Localize or function(fs) return fs end
Addon.LocalFont = Addon.LocalFont or function(path) return path end

function Addon.Print(message)
    print(chatPrefix .. tostring(Addon.Tr and Addon.Tr(message) or message))
end
