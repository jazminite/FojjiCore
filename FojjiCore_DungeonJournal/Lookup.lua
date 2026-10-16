local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

FDJ.ByKey = {}
FDJ.ByInstance = {}
FDJ.QuestHome = {}
FDJ.LootSources = {}
FDJ.NpcBoss = {}
FDJ.QuestNeeds = {}
FDJ.GiverQuests = {}
FDJ.TagOf = {}

local SEQ = { 0, 4, 5, 6, 7, 8, 9, 10, 11, 1, 2, 3 }

for _, id in ipairs(FDJ.ItemTags.added) do FDJ.TagOf[id] = "added" end
for _, id in ipairs(FDJ.ItemTags.reworked) do FDJ.TagOf[id] = "reworked" end

for index, d in ipairs(FDJ.Dungeons) do
    d.index = index
    FDJ.ByKey[d.key] = d
    local same = FDJ.ByInstance[d.instance]
    if not same then
        same = {}
        FDJ.ByInstance[d.instance] = same
    end
    same[#same + 1] = d
    for b, boss in ipairs(d.bosses) do
        boss.index = b
        boss.dungeon = d
        if boss.npc then FDJ.NpcBoss[boss.npc] = boss end
        for _, alt in ipairs(boss.alt or {}) do FDJ.NpcBoss[alt] = boss end
        for i, item in ipairs(boss.loot) do
            local list = FDJ.LootSources[item]
            if not list then
                list = {}
                FDJ.LootSources[item] = list
            end
            list[#list + 1] = { boss = boss, odds = boss.odds and boss.odds[i] or nil }
        end
    end
    for _, qid in ipairs(d.quests) do
        local home = FDJ.QuestHome[qid]
        if not home then
            home = {}
            FDJ.QuestHome[qid] = home
        end
        home[#home + 1] = d
    end
end

local faceByName = {}
for _, d in ipairs(FDJ.Dungeons) do
    for _, boss in ipairs(d.bosses) do
        if boss.face then faceByName[boss.n:lower()] = boss.face end
    end
end

function Addon.BossPortrait(npc, name)
    local boss = npc and FDJ.NpcBoss[npc]
    if boss and boss.face then return boss.face end
    return type(name) == "string" and faceByName[name:lower()] or nil
end

for qid, q in pairs(FDJ.QuestBook) do
    q.id = qid
    for _, item in ipairs(q.need or {}) do
        local list = FDJ.QuestNeeds[item]
        if not list then
            list = {}
            FDJ.QuestNeeds[item] = list
        end
        list[#list + 1] = qid
    end
    if q.by then
        local list = FDJ.GiverQuests[q.by]
        if not list then
            list = {}
            FDJ.GiverQuests[q.by] = list
        end
        list[#list + 1] = qid
    end
end

function FDJ.DungeonTitle(d)
    if d.family then return d.family .. ": " .. d.name end
    return d.name
end

function FDJ.FloorLabel(d, index)
    local floor = d.floors[index]
    if floor and floor[2] then return floor[2] end
    if #d.floors == 1 then return FDJ.L.MAP end
    return FDJ.L.LEVEL_N:format(index)
end

local zoneArt = {}

local function worldTiles(mapID)
    if zoneArt[mapID] ~= nil then return zoneArt[mapID] or nil end
    local found = false
    if C_Map.GetMapArtLayerTextures then
        local ok, tiles = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
        if ok and type(tiles) == "table" and #tiles > 0 then
            local cols = 4
            if C_Map.GetMapArtLayers then
                local ok2, layers = pcall(C_Map.GetMapArtLayers, mapID)
                local layer = ok2 and type(layers) == "table" and layers[1]
                if layer and layer.layerWidth and layer.tileWidth and layer.tileWidth > 0 then
                    cols = math.ceil(layer.layerWidth / layer.tileWidth)
                end
            end
            found = { list = tiles, wide = cols }
        end
    end
    zoneArt[mapID] = found
    return found or nil
end

function FDJ.ChartTiles(chartID)
    local chart = FDJ.Charts[chartID]
    if not chart then
        local art = chartID and chartID > 0 and worldTiles(chartID)
        if art then return art.list, art end
        return nil
    end
    if chart.image then return { chart.image }, chart end
    if not chart.list then
        if chart.seq then
            local list = {}
            for i, offset in ipairs(SEQ) do list[i] = chart.seq + offset end
            chart.list = list
        else
            chart.list = chart.tiles
        end
    end
    return chart.list, chart
end

function FDJ.ItemNameOf(itemID)
    local name, _, quality = C_Item.GetItemInfo(itemID)
    return name, quality
end

function FDJ.RangeColor(d)
    local level = FDJ.Level()
    local lo, hi = d.range[1], d.range[2]
    if level < lo - 2 then return FDJ.Colors.bad end
    if level < lo then return FDJ.Colors.amber end
    if level <= hi then return FDJ.Colors.good end
    if level <= hi + 5 then return FDJ.Colors.muted end
    return FDJ.Colors.dim
end

function FDJ.ListRangeColor(d, faded)
    if FDJ.Level() > d.range[2] + 2 then return faded or FDJ.Colors.dim end
    return FDJ.RangeColor(d)
end

function FDJ.FitsLevel(d)
    local level = FDJ.Level()
    return level >= d.range[1] - 2 and level <= d.range[2] + 2
end

local ZONE_HINTS = {
    ["Durotar"] = 1411, ["Mulgore"] = 1412, ["The Barrens"] = 1413, ["Alterac Mountains"] = 1416,
    ["Arathi Highlands"] = 1417, ["Badlands"] = 1418, ["Blasted Lands"] = 1419, ["Tirisfal Glades"] = 1420,
    ["Silverpine Forest"] = 1421, ["Western Plaguelands"] = 1422, ["Eastern Plaguelands"] = 1423,
    ["Hillsbrad Foothills"] = 1424, ["The Hinterlands"] = 1425, ["Dun Morogh"] = 1426, ["Searing Gorge"] = 1427,
    ["Burning Steppes"] = 1428, ["Elwynn Forest"] = 1429, ["Deadwind Pass"] = 1430, ["Duskwood"] = 1431,
    ["Loch Modan"] = 1432, ["Redridge Mountains"] = 1433, ["Stranglethorn Vale"] = 1434, ["Swamp of Sorrows"] = 1435,
    ["Westfall"] = 1436, ["Wetlands"] = 1437, ["Teldrassil"] = 1438, ["Darkshore"] = 1439, ["Ashenvale"] = 1440,
    ["Thousand Needles"] = 1441, ["Stonetalon Mountains"] = 1442, ["Desolace"] = 1443, ["Feralas"] = 1444,
    ["Dustwallow Marsh"] = 1445, ["Tanaris"] = 1446, ["Azshara"] = 1447, ["Felwood"] = 1448,
    ["Un'Goro Crater"] = 1449, ["Moonglade"] = 1450, ["Silithus"] = 1451, ["Winterspring"] = 1452,
    ["Stormwind City"] = 1453, ["Orgrimmar"] = 1454, ["Ironforge"] = 1455, ["Thunder Bluff"] = 1456,
    ["Darnassus"] = 1457, ["Undercity"] = 1458, ["Blackrock Mountain"] = 1427,
}

local ENTRANCES = {
    { { "ragefire" }, "Orgrimmar", 51.8, 49.6 },
    { { "hallofthanes" }, "Ironforge", 43.5, 52.0 },
    { { "lordaeron" }, "Tirisfal Glades", 63.4, 67.4 },
    { { "excavation" }, "Wetlands", 47.7, 56.2 },
    { { "dalaran" }, "Alterac Mountains", 8.5, 59.3 },
    { { "wailing" }, "The Barrens", 46.0, 36.6 },
    { { "deadmines" }, "Westfall", 42.5, 71.7 },
    { { "shadowfang" }, "Silverpine Forest", 44.9, 67.6 },
    { { "blackfathom" }, "Ashenvale", 14.3, 14.0 },
    { { "stockade" }, "Stormwind City", 50.4, 66.4 },
    { { "gnomeregan" }, "Dun Morogh", 24.4, 39.8 },
    { { "kraul" }, "The Barrens", 42.6, 90.0 },
    { { "sm_graveyard", "sm_library", "sm_armory", "sm_cathedral" }, "Tirisfal Glades", 84.8, 30.8 },
    { { "downs" }, "The Barrens", 50.8, 92.9 },
    { { "uldaman" }, "Badlands", 44.2, 12.0 },
    { { "zulfarrak" }, "Tanaris", 38.8, 20.1 },
    { { "maraudon" }, "Desolace", 29.1, 62.6 },
    { { "sunken" }, "Swamp of Sorrows", 69.6, 53.6 },
    { { "brd", "lbrs", "ubrs" }, "Searing Gorge", 34.8, 85.3 },
    { { "brd", "lbrs", "ubrs" }, "Burning Steppes", 29.4, 38.3 },
    { { "dm_east", "dm_north", "dm_west" }, "Feralas", 59.2, 43.6 },
    { { "scholomance" }, "Western Plaguelands", 69.8, 73.3 },
    { { "stratholme" }, "Eastern Plaguelands", 31.3, 15.7 },
}

function FDJ.ZoneList()
    local groups = {}
    for name, id in pairs(ZONE_HINTS) do
        if name ~= "Blackrock Mountain" then
            local info = C_Map.GetMapInfo(id)
            local parent = info and info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
            local key = parent and parent.name or "?"
            groups[key] = groups[key] or { id = parent and parent.mapID }
            table.insert(groups[key], { name = info and info.name or name, id = id })
        end
    end
    local out = {}
    for continent, list in pairs(groups) do
        table.sort(list, function(a, b) return a.name < b.name end)
        out[#out + 1] = { name = continent, id = list.id, zones = list }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function plain(text)
    return (text or ""):lower():gsub("^the ", ""):gsub("[^%a]", "")
end

function FDJ.Entrances(mapID)
    local out = {}
    local found = {}
    if mapID and C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap then
        local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
        if ok and type(list) == "table" then
            for _, e in ipairs(list) do
                local name = plain(e.name)
                local keys = {}
                for _, d in ipairs(FDJ.Dungeons) do
                    if plain(d.name) == name or plain(d.family) == name or plain(FDJ.DungeonTitle(d)) == name then keys[#keys + 1] = d.key end
                end
                local x, y
                if e.position then x, y = FDJ.XY(e.position) end
                if #keys > 0 and x then
                    out[#out + 1] = { keys = keys, m = mapID, x = x, y = y }
                    for _, k in ipairs(keys) do found[k] = true end
                end
            end
        end
    end
    for _, e in ipairs(ENTRANCES) do
        if not found[e[1][1]] then
            local m = FDJ.ZoneMap(e[2])
            if m then out[#out + 1] = { keys = e[1], m = m, x = e[3] / 100, y = e[4] / 100 } end
        end
    end
    return out
end

function FDJ.EntranceSpot(key)
    for _, e in ipairs(ENTRANCES) do
        for _, k in ipairs(e[1]) do
            if k == key then
                local m = FDJ.ZoneMap(e[2])
                if m then return { m = m, x = e[3] / 100, y = e[4] / 100, zone = e[2] } end
            end
        end
    end
end

local zoneNames

local function scanZones()
    zoneNames = {}
    local roots = { 947, 1414, 1415, 946, 12, 13 }
    if C_Map.GetFallbackWorldMapID then table.insert(roots, 1, C_Map.GetFallbackWorldMapID()) end
    for _, root in ipairs(roots) do
        local ok, children = pcall(C_Map.GetMapChildrenInfo, root, nil, true)
        if ok and type(children) == "table" then
            for _, info in ipairs(children) do
                if info.name and not zoneNames[info.name:lower()] then zoneNames[info.name:lower()] = info.mapID end
            end
        end
    end
end

function FDJ.ZoneMap(name)
    if not name then return nil end
    local hint = ZONE_HINTS[name]
    if hint and C_Map.GetMapInfo(hint) then return hint end
    if not zoneNames then scanZones() end
    return zoneNames[name:lower()]
end

local seedCache = {}

function FDJ.GiverSpot(name)
    if not name then return nil end
    local cached = seedCache[name]
    if cached ~= nil then return cached or nil end
    local seed = FDJ.Givers[name]
    local mapID = seed and FDJ.ZoneMap(seed[1])
    if mapID then
        cached = { m = mapID, x = seed[2] / 100, y = seed[3] / 100, how = "known" }
    end
    seedCache[name] = cached or false
    return cached
end

function FDJ.MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or "?"
end

function FDJ.CurrentDungeon()
    local _, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return nil end
    local list = FDJ.ByInstance[instanceID]
    if not list then return nil end
    if #list == 1 then return list[1] end
    local key = FDJ.char and FDJ.char.lastDungeon
    for _, d in ipairs(list) do
        if d.key == key then return d end
    end
    return list[1]
end

local HOME_SIDE = {
    hallofthanes = "Alliance", deadmines = "Alliance", stockade = "Alliance", gnomeregan = "Alliance",
    ragefire = "Horde", lordaeron = "Horde", wailing = "Horde", shadowfang = "Horde", kraul = "Horde",
}

function FDJ.DungeonSide(d)
    return d and HOME_SIDE[d.key]
end

local FACTION_RGB = {
    Alliance = { 64, 140, 255 },
    Horde = { 230, 56, 48 },
}

function FDJ.FactionIcon(d, size)
    local side = FDJ.DungeonSide(d)
    if not side then return "" end
    local c = FACTION_RGB[side]
    local px = math.max(6, math.floor((size or 14) * 0.5))
    return ("|T%sui-dot:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t  "):format(FDJ.media, px, px, c[1], c[2], c[3])
end

function FDJ.FactionTag(d)
    local side = FDJ.DungeonSide(d)
    if not side then return nil end
    local c = FACTION_RGB[side]
    local label = side == "Alliance" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde")
    return ("|cff%02x%02x%02x%s|r"):format(c[1], c[2], c[3], label)
end

function FDJ.IsEnemyDungeon(d)
    local side = FDJ.DungeonSide(d)
    return side ~= nil and side ~= FDJ.Faction()
end

function FDJ.SuggestedDungeon()
    local here = FDJ.CurrentDungeon()
    if here then return here end
    local level, faction = FDJ.Level(), FDJ.Faction()
    local best, bestScore
    for _, d in ipairs(FDJ.Dungeons) do
        if level >= d.range[1] - 1 and level <= d.range[2] and not FDJ.IsEnemyDungeon(d) then
            local mid = (d.range[1] + d.range[2]) / 2
            local score = math.abs(level - mid) - (FDJ.DungeonSide(d) == faction and 1.5 or 0)
            if not bestScore or score < bestScore then best, bestScore = d, score end
        end
    end
    if best then return best end
    for _, d in ipairs(FDJ.Dungeons) do
        if not FDJ.IsEnemyDungeon(d) and level < d.range[1] then return d end
    end
    return FDJ.Dungeons[#FDJ.Dungeons]
end

function FDJ.DungeonsInZone(mapID)
    local out = {}
    if not mapID then return out end
    for _, d in ipairs(FDJ.Dungeons) do
        if FDJ.ZoneMap(d.zone) == mapID then out[#out + 1] = d end
    end
    return out
end

function FDJ.NpcFromGUID(guid)
    if type(guid) ~= "string" or FDJ.Secret(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

function FDJ.ItemFromLink(link)
    if type(link) ~= "string" or FDJ.Secret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local asked, queue, queued, pumping = {}, {}, {}, false

local function hasInfo(itemID)
    local ok, name = pcall(C_Item.GetItemInfo, itemID)
    return ok and name ~= nil
end

local function pump()
    local sent = 0
    while sent < 8 and #queue > 0 do
        local itemID = table.remove(queue, 1)
        queued[itemID] = nil
        if not hasInfo(itemID) then
            asked[itemID] = GetTime()
            pcall(C_Item.RequestLoadItemDataByID, itemID)
            sent = sent + 1
        end
    end
    if #queue > 0 then
        C_Timer.After(0.25, pump)
    else
        pumping = false
    end
end

local function request(itemID, first)
    if type(itemID) ~= "number" or queued[itemID] then return end
    local t = asked[itemID]
    if t and GetTime() - t < 2 then return end
    if hasInfo(itemID) then return end
    queued[itemID] = true
    if first then table.insert(queue, 1, itemID) else queue[#queue + 1] = itemID end
    if not pumping then
        pumping = true
        C_Timer.After(0, pump)
    end
end
FDJ.RequestItem = request

function FDJ.Prefetch(d, background)
    if not d then return end
    for _, boss in ipairs(d.bosses) do
        for _, itemID in ipairs(boss.loot) do request(itemID, not background) end
    end
    for _, qid in ipairs(d.quests) do
        local q = FDJ.QuestBook[qid]
        for _, itemID in ipairs(q and q.need or {}) do request(itemID) end
        for _, itemID in ipairs(q and q.gives or {}) do request(itemID) end
    end
end

local warmed = {}
FDJ:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(3, function()
        for _, d in ipairs({ FDJ.CurrentDungeon(), FDJ.SuggestedDungeon() }) do
            if d and not warmed[d] then
                warmed[d] = true
                FDJ.Prefetch(d, true)
            end
        end
    end)
end)

do
    local unknown
    local watcher = CreateFrame("Frame")
    local function learn(unit)
        if not unknown or not UnitExists(unit) or UnitIsPlayer(unit) then return end
        local guid = UnitGUID(unit)
        if not guid or FDJ.Secret(guid) then return end
        local npc = tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
        local boss = npc and unknown[npc]
        if not boss then return end
        local level = UnitLevel(unit)
        if not level or FDJ.Secret(level) or level <= 0 then return end
        boss.lv = level
        FDJ.db.bossLv = FDJ.db.bossLv or {}
        FDJ.db.bossLv[npc] = level
        unknown[npc] = nil
        if not next(unknown) then watcher:UnregisterAllEvents() unknown = nil end
        FDJ:Emit("FDJ_KILLS")
    end
    watcher:SetScript("OnEvent", function(_, event)
        pcall(learn, event == "PLAYER_TARGET_CHANGED" and "target" or "mouseover")
    end)
    FDJ:On("PLAYER_LOGIN", function()
        if not FDJ.db then return end
        local saved = FDJ.db.bossLv or {}
        for _, d in ipairs(FDJ.Dungeons or {}) do
            for _, boss in ipairs(d.bosses) do
                if boss.npc and not boss.lv then
                    if saved[boss.npc] then boss.lv = saved[boss.npc]
                    else unknown = unknown or {}; unknown[boss.npc] = boss end
                end
            end
        end
    end)
    FDJ:On("PLAYER_ENTERING_WORLD", function()
        if unknown and FDJ.InInstance() then
            watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
            watcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        else
            watcher:UnregisterAllEvents()
        end
    end)
end
