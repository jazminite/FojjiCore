local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local ENTRANCES = {
    hallofthanes = { f = 1, at = { 49.8, 87.6 } },
    lordaeron = { f = 1, at = { 61.2, 21.4 }, side = "left" },
    ragefire = { f = 1, at = { 61.0, 7.5 }, side = "left" },
    wailing = { f = 1, at = { 46.1, 58.8 }, side = "left" },
    deadmines = {
        f = 1, at = { 29.5, 13.5 },
        links = { { f = 1, to = 2, at = { 61.5, 61.0 } } },
    },
    shadowfang = {
        f = 1, at = { 70.5, 60.5 },
        links = {
            { f = 1, to = 7, at = { 14.5, 86.4 } },
            { f = 7, to = 6, at = { 51.5, 91.5 } },
        },
    },
    blackfathom = {
        f = 1, at = { 45.5, 8.5 },
        links = {
            { f = 1, to = 2, at = { 61.5, 70.0 } },
            { f = 2, to = 3, at = { 47.0, 70.0 }, kind = "swim" },
        },
    },
    stockade = { f = 1, at = { 50.0, 81.5 } },
    gnomeregan = {
        f = 1, at = { 64.2, 27.8 },
        links = {
            { f = 1, to = 2, at = { 54.5, 40.9 }, kind = "jump" },
            { f = 1, to = 2, at = { 48.7, 87.7 } },
            { f = 2, to = 3, at = { 24.5, 50.0 } },
            { f = 3, to = 4, at = { 37.0, 72.0 } },
        },
    },
    kraul = { f = 1, at = { 71.4, 84.0 }, side = "left" },
    sm_graveyard = { f = 1, at = { 84.1, 83.1 }, side = "left" },
    excavation = { f = 1, at = { 7.8, 62.0 } },
    dalaran = {
        f = 2, at = { 19.0, 83.8 },
        links = {
            { f = 1, to = 2, at = { 61.0, 56.0 } },
            { f = 2, to = 1, at = { 64.2, 59.3 } },
        },
    },
}

for _, d in ipairs(FDJ.Dungeons or {}) do
    local e = ENTRANCES[d.key]
    if e then
        d.entrance = { f = e.f, at = e.at, side = e.side }
        d.links = e.links
    end
end

function FDJ.Entrance(d)
    if not d then return nil end
    if d.entrance then return d.entrance end
    local learned = FDJ.db and FDJ.db.entrances and FDJ.db.entrances[d.key]
    if learned then return { f = learned.f, at = { learned.x, learned.y }, learned = true } end
end

FDJ:On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    if isLogin or isReload then return end
    C_Timer.After(1.5, function()
        local d = FDJ.CurrentDungeon and FDJ.CurrentDungeon()
        if not d or d.entrance or not FDJ.db then return end
        FDJ.db.entrances = FDJ.db.entrances or {}
        if FDJ.db.entrances[d.key] then return end
        local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if not mapID or FDJ.Secret(mapID) then return end
        for i, floor in ipairs(d.floors) do
            if floor[1] == mapID then
                local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
                if not ok then return end
                local x, y = FDJ.XY(pos)
                if x and y and not FDJ.Secret(x) and x > 0 and y > 0 then
                    FDJ.db.entrances[d.key] = { f = i, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10 }
                    FDJ:Emit("FDJ_ENTRANCE", d)
                end
                return
            end
        end
    end)
end)
