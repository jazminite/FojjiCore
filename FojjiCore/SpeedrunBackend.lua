local _, Addon = ...
FojjiCoreNS = Addon
Addon.IsForever = false
Addon.AuraAPI = WeakAuras

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
    print("|cff66b3ffFojji|r|cffff4444Core|r: " .. tostring(Addon.Tr and Addon.Tr(message) or message))
end
