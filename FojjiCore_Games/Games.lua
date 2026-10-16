local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever and Addon.DJ) then return end
local FDJ = Addon.DJ

local Games = {}
Addon.Games = Games
FDJ.Games = Games

local UNITS = { "player" }
for i = 1, 4 do UNITS[#UNITS + 1] = "party" .. i end
for i = 1, 40 do UNITS[#UNITS + 1] = "raid" .. i end
local hexCache, hexAt = {}, 0
function Games.ClassHex(name)
    if not name then return "ffffff" end
    local now = GetTime()
    if now - hexAt > 5 then wipe(hexCache) hexAt = now end
    local hit = hexCache[name]
    if hit then return hit end
    local hex = "ffffff"
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) and FDJ.Short(GetUnitName(unit, true)) == name then
            local _, class = UnitClass(unit)
            local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then hex = ("%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
            break
        end
    end
    hexCache[name] = hex
    return hex
end

function Games.Window(f)
    local name = f and f.GetName and f:GetName()
    if not name or f.gamesWindow then return end
    f.gamesWindow = true
    local function saved()
        FojjiCoreDB.gameWindows = FojjiCoreDB.gameWindows or {}
        return FojjiCoreDB.gameWindows
    end
    local p = saved()[name]
    if p and p[1] then
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    end
    local moved = f.OnMoved
    f.OnMoved = function(self)
        if moved then moved(self) end
        local a, _, b, x, y = self:GetPoint(1)
        if a then saved()[name] = { a, b, x, y } end
    end
    if Games.Chess and Games.Chess.Watch then Games.Chess.Watch(f) end
end

function Games.Near(name)
    if not name then return false end
    if name == FDJ.PlayerName() then return true end
    if UnitInParty and UnitInParty(name) then return true end
    if UnitInRaid and UnitInRaid(name) then return true end
    return false
end

function Games.Slash(cmd, rest)
    if cmd == "chess" and Games.Chess then
        local arg = (rest or ""):lower()
        if arg == "bot" or arg == "computer" or arg == "ai" or arg == "practice" then
            local P = FojjiCoreDB and FojjiCoreDB.chess or {}
            Games.Chess.PlayComputer(P.mins or 0, P.colour or "r", P.inc or 0)
        else
            Games.Chess.Toggle()
        end
        return true
    end
    if (cmd == "word" or cmd == "wordle" or cmd == "daily") and Games.DailyWord then
        Games.DailyWord.Toggle()
        return true
    end
    if cmd == "games" and Games.Chess and Games.Chess.ShowGames then
        Games.Chess.ShowGames()
        return true
    end
    if (cmd == "deathroll" or cmd == "dr") and Games.Deathroll then
        if (rest or ""):lower() == "debug" then
            Games.Deathroll.debug = not Games.Deathroll.debug
            FDJ.Print("Deathroll debug " .. (Games.Deathroll.debug and "on: rolls are echoed in chat." or "off."))
            return true
        end
        Games.Deathroll.Setup()
        return true
    end
    return false
end
