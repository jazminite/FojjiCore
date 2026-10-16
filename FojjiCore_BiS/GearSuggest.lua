local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local L = FDJ.L
local Gear = FDJ.Gear

local Advisor = {}
Gear.Advisor = Advisor

local ARMOR_TIER = { cloth = 1, leather = 2, mail = 3, plate = 4 }
local CLASS_ARMOR = {
    MAGE = { 1 }, PRIEST = { 1 }, WARLOCK = { 1 },
    ROGUE = { 2 }, DRUID = { 2 },
    HUNTER = { 2, 40, 3 }, SHAMAN = { 2, 40, 3 },
    WARRIOR = { 3, 40, 4 }, PALADIN = { 3, 40, 4 },
}
local KIND_ID = {
    axe = 0, greataxe = 1, bow = 2, gun = 3, mace = 4, maul = 5, polearm = 6, sword = 7, greatsword = 8,
    staff = 10, fist = 13, dagger = 15, thrown = 16, crossbow = 18, wand = 19,
}
local WIELDS = {
    WARRIOR = "axe greataxe mace maul sword greatsword polearm staff fist dagger bow gun crossbow thrown",
    PALADIN = "axe greataxe mace maul sword greatsword polearm",
    HUNTER = "axe greataxe sword greatsword polearm staff fist dagger bow gun crossbow",
    ROGUE = "mace sword fist dagger bow gun crossbow thrown",
    PRIEST = "mace staff dagger wand",
    SHAMAN = "axe greataxe mace maul staff fist dagger",
    MAGE = "sword staff dagger wand",
    WARLOCK = "sword staff dagger wand",
    DRUID = "mace maul staff fist dagger",
}
local OFFHAND_ARMOR = { WARRIOR = { 6 }, PALADIN = { 6, 7 }, SHAMAN = { 6, 9 }, DRUID = { 8 } }

local OFFHAND_FROM = { ROGUE = 1, WARRIOR = 20, HUNTER = 20 }

local canWield = {}
for c, kinds in pairs(WIELDS) do
    local set = {}
    for kind in kinds:gmatch("%a+") do set[KIND_ID[kind]] = true end
    canWield[c] = set
end

local function class()
    local _, c = UnitClass("player")
    return c
end

local function maxArmor(c, level)
    local rule = CLASS_ARMOR[c] or { 1 }
    if rule[2] and level >= rule[2] then return rule[3] end
    return rule[1]
end

function Advisor.CanWear(itemID, c, level)
    c = c or class()
    level = level or FDJ.Level()
    local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
    if not loc or loc == "" then return false end
    if classID == 2 then
        if loc == "INVTYPE_WEAPONOFFHAND" and not (OFFHAND_FROM[c] and level >= OFFHAND_FROM[c]) then return false end
        return canWield[c] and canWield[c][subID] or false
    end
    if classID == 4 then
        if loc == "INVTYPE_CLOAK" or loc == "INVTYPE_NECK" or loc == "INVTYPE_FINGER" or loc == "INVTYPE_TRINKET" or loc == "INVTYPE_HOLDABLE" then
            return true
        end
        if subID == 0 then return true end
        if subID >= 6 then
            for _, s in ipairs(OFFHAND_ARMOR[c] or {}) do if s == subID then return true end end
            return false
        end
        return subID <= maxArmor(c, level)
    end
    return false
end

local BODY_ARMOR = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true, INVTYPE_WRIST = true,
    INVTYPE_HAND = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
}
local MAIN_STATS = { STR = true, AGI = true, INT = true, SPI = true, AP = true, SP = true, HEAL = true }

local blocked = {}
local LEVEL_LINE = ITEM_MIN_LEVEL and ("^" .. ITEM_MIN_LEVEL:gsub("%%d", "%%d+") .. "$")
local function redLine(itemID)
    if blocked[itemID] ~= nil then return blocked[itemID] end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return false end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or type(data) ~= "table" or not data.lines then return false end
    local red = false
    for i, line in ipairs(data.lines) do
        local c = line.leftColor
        local text = line.leftText
        if i > 1 and c and text and c.r and c.r > 0.9 and c.g < 0.2 and c.b < 0.2 then
            if not (LEVEL_LINE and text:match(LEVEL_LINE)) then red = true break end
        end
        c = line.rightColor
        text = line.rightText
        if c and text and c.r and c.r > 0.9 and c.g < 0.2 and c.b < 0.2 then red = true break end
    end
    blocked[itemID] = red
    return red
end
Advisor.Blocked = redLine

local function reachable(itemID, req)
    local at = req or 0
    local boss = Gear.Source(itemID)
    local low
    for _, src in ipairs(FDJ.LootSources[itemID] or {}) do
        local d = src.boss and src.boss.dungeon
        if d and d.range and (not low or d.range[1] < low) then low = d.range[1] end
    end
    if low then at = math.max(at, low) end
    if not boss then
        local q = Gear.QuestFor(itemID)
        if q then at = math.max(at, q.req or q.lv or 0) end
    end
    return at
end
Advisor.Reachable = reachable

local function dpsFactor(groupKey, c, weights)
    if c == "HUNTER" then return groupKey == "ranged" and 1 or 0 end
    if groupKey == "mainhand" then return 1 end
    if groupKey == "ranged" then return 0 end
    if groupKey == "offhand" then return (weights.DPS or 0) >= 5 and 0.5 or 0 end
    return 1
end

function Advisor.Rate(itemID, weights, c, level, groupKey)
    local name, link, _, ilvl, req = C_Item.GetItemInfo(itemID)
    if not name then return nil end
    c = c or class()
    level = level or FDJ.Level()
    weights = weights or Gear.Measure.StatValues(c)
    local item = Gear.Measure.Item(itemID)
    if not item then return nil end
    local worth = Gear.Measure.Value(item.stats, weights)
    if worth <= 0 and not item.stats.DPS then return false end
    local score = (ilvl or 0) * 0.05 + worth
    if item.stats.DPS and weights.DPS then
        score = score - item.stats.DPS * weights.DPS * (1 - dpsFactor(groupKey, c, weights))
    end
    local _, _, _, _, _, wClass, wSub = C_Item.GetItemInfoInstant(itemID)
    if groupKey == "ranged" and wClass == 2 and wSub == 19 and item.stats.DPS and not weights.DPS then
        score = score + item.stats.DPS * 2
    end
    local useful, wrong = 0, 0
    for k in pairs(item.stats) do
        if MAIN_STATS[k] then
            if (weights[k] or 0) > 0.2 then useful = useful + 1 else wrong = wrong + 1 end
        end
    end
    if c == class() and level <= FDJ.Level() and redLine(itemID) then return false end
    if wrong > 0 and useful == 0 then return false end
    local _, _, _, loc, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
    if classID == 4 and BODY_ARMOR[loc] and subID and subID >= 1 and subID <= 4 then
        local best = maxArmor(c, math.max(level, req or 0))
        score = score - (best - subID) * math.max(4, score * 0.25)
    end
    return score, ilvl or 0, reachable(itemID, req)
end

local pending, failed = {}, {}
local function want(itemID)
    if C_Item.GetItemInfo(itemID) then return true end
    if failed[itemID] then return nil end
    local asked = pending[itemID]
    if not asked then
        pending[itemID] = GetTime()
        C_Item.RequestLoadItemDataByID(itemID)
        return false
    end
    if GetTime() - asked > 8 then
        pending[itemID] = nil
        failed[itemID] = true
        return nil
    end
    return false
end

local pools = {}
function Advisor.Pool(group, c, level)
    local cacheKey = tostring(c) .. ":" .. tostring(level) .. ":" .. group.key
    if pools[cacheKey] then return pools[cacheKey] end
    local out = {}
    local seen = {}
    local function consider(itemID)
        if seen[itemID] then return end
        seen[itemID] = true
        local g = Gear.SlotFor(itemID)
        if g == group and Advisor.CanWear(itemID, c, level) then out[#out + 1] = itemID end
    end
    for itemID in pairs(FDJ.LootSources) do consider(itemID) end
    for itemID in pairs(Gear.QuestRewards()) do consider(itemID) end
    pools[cacheKey] = out
    return out
end

local ranked, stale = {}, false
function Advisor.ForgetRanked() stale = true end

function Advisor.Contenders(group, opts)
    opts = opts or {}
    if stale then wipe(ranked); stale = false end
    local c, level = opts.class or class(), opts.level or FDJ.Level()
    local reach = opts.reach or 0
    local weights = opts.weights or Gear.Measure.StatValues(c, opts.spec)
    local sig = {}
    for k, v in pairs(weights) do sig[#sig + 1] = tostring(k) .. "=" .. tostring(v) end
    table.sort(sig)
    local key = table.concat({ group.key, c, level, reach, opts.any and 1 or 0, table.concat(sig) }, "|")
    local hit = ranked[key]
    if hit then return hit[1], 0, hit[2] end
    local list, waiting, nextLevel = Advisor.RankSlot(group, c, level, reach, weights, opts.any)
    if waiting == 0 then ranked[key] = { list, nextLevel } end
    return list, waiting, nextLevel
end

function Advisor.RankSlot(group, c, level, reach, weights, any)
    local opts = { any = any }
    local list, ahead, waiting = {}, {}, 0
    for _, itemID in ipairs(Advisor.Pool(group, c, level)) do
        local ready = want(itemID)
        if ready then
            local score, ilvl, req = Advisor.Rate(itemID, weights, c, level, group.key)
            if score then
                local e = { id = itemID, score = score, ilvl = ilvl, req = req }
                if opts.any or req <= level + reach then
                    list[#list + 1] = e
                else
                    ahead[#ahead + 1] = e
                end
            end
        elseif ready == false then
            waiting = waiting + 1
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    local nextLevel
    if #list == 0 and not opts.any then
        for _, e in ipairs(ahead) do
            if not nextLevel or e.req < nextLevel then nextLevel = e.req end
        end
    end
    return list, waiting, nextLevel
end

function Advisor.Loading()
    local n = 0
    for id in pairs(pending) do
        if C_Item.GetItemInfo(id) then pending[id] = nil else n = n + 1 end
    end
    return n
end

local FOREVER_ITEM = 200000
local FOREVER_EDGE = 1.05
local FOREVER_MIN_REQ, FOREVER_MIN_ILVL = 55, 58

local FACTION_TWIN = { [12543] = 12545, [12545] = 12543 }

local otherSide
local function otherFactionOnly(itemID)
    if not otherSide then
        otherSide = {}
        local side = UnitFactionGroup("player")
        for _, q in pairs(FDJ.QuestBook or {}) do
            if q.side and q.side ~= side then
                for _, id in ipairs(q.gives or {}) do otherSide[id] = true end
            end
        end
    end
    return otherSide[itemID] and not (Gear.QuestFor and Gear.QuestFor(itemID))
end

function Advisor.Curated(group, opts)
    opts = opts or {}
    local c, level = opts.class or class(), opts.level or FDJ.Level()
    local spec = opts.spec or (Gear.SpecOf and Gear.SpecOf())
    local lists = Gear.PreRaidFor and Gear.PreRaidFor(c, spec)
    local ids = lists and lists[group.key]
    if not ids then return nil, 0 end
    local weights = opts.weights or Gear.Measure.StatValues(c, spec)
    local out, waiting = {}, 0
    for _, id in ipairs(ids) do
        if C_Item.GetItemInfoInstant(id) and Gear.SlotFor(id) == group and Advisor.CanWear(id, c, level)
            and not otherFactionOnly(id) then
            local ready
            if opts.instant then
                if C_Item.GetItemInfo(id) then
                    ready = true
                elseif want(id) == nil then
                    ready = nil
                else
                    ready = "later"
                end
            else
                ready = want(id)
            end
            local req = ready and select(5, C_Item.GetItemInfo(id))
            if ready and level >= 60 and req and req > 0 and req < 40 then
                ready = nil
            end
            if ready == "later" then
                out[#out + 1] = { id = id, score = 0, curated = true }
            elseif ready then
                local score = Advisor.Rate(id, weights, c, level, group.key)
                out[#out + 1] = { id = id, score = score or 0, curated = true }
            elseif ready == false then
                waiting = waiting + 1
            end
        end
    end
    return out, waiting
end

local function blend(curated, contenders)
    local out, seen = {}, {}
    local top = curated[1]
    local fresh
    for _, e in ipairs(contenders) do
        local _, _, _, ilvl, req = C_Item.GetItemInfo(e.id)
        local endgame = (tonumber(req) or 0) >= FOREVER_MIN_REQ or (tonumber(ilvl) or 0) >= FOREVER_MIN_ILVL
        if e.id >= FOREVER_ITEM and endgame and (not fresh or e.score > fresh.score) then fresh = e end
    end
    if fresh and top and top.score > 0 and fresh.score > top.score * FOREVER_EDGE then
        out[1], seen[fresh.id] = fresh, true
    end
    for _, e in ipairs(curated) do
        if not seen[e.id] then out[#out + 1], seen[e.id] = e, true end
    end
    for _, e in ipairs(contenders) do
        local _, _, _, ilvl, req = C_Item.GetItemInfo(e.id)
        local endgame = (tonumber(req) or 0) >= 45 or (tonumber(ilvl) or 0) >= 50
        if not seen[e.id] and endgame then out[#out + 1], seen[e.id] = e, true end
    end
    return out
end

Advisor.PRESETS = {
    { key = "lv20", level = 20 },
    { key = "lv30", level = 30 },
    { key = "lv40", level = 40 },
    { key = "lv50", level = 50 },
    { key = "preraid", level = 60 },
    { key = "phase1", level = 60, raid = true },
}

function Advisor.PresetName(p)
    if p.key == "preraid" then return L.BIS_PRESET_PRERAID end
    if p.key == "phase1" then return L.BIS_PRESET_PHASE1 end
    return L.BIS_PRESET_LEVEL:format(p.level)
end

function Advisor.HasRaidLoot()
    for _, d in ipairs(FDJ.Dungeons or {}) do
        if d.raid then return true end
    end
    return false
end

function Advisor.Assemble(replace, done, opts)
    opts = opts or {}
    local level = opts.level or FDJ.Level()
    local tries = 0
    local results, listed = {}, {}
    local todo = {}
    for _, g in ipairs(Gear.GROUPS) do
        if not g.optional then todo[#todo + 1] = g end
    end
    local cacheKey
    do
        local c, spec = class(), Gear.SpecOf and Gear.SpecOf() or "any"
        local w = Gear.Measure.StatValues(c, spec)
        local parts = {}
        for k, v in pairs(w) do parts[#parts + 1] = k .. "=" .. v end
        table.sort(parts)
        cacheKey = table.concat({ c, spec, level, UnitFactionGroup("player") or "", FojjiCore_Version or "",
            opts.raid and "raid" or "", table.concat(parts, ",") }, "|")
    end
    local function cacheStore()
        if not FDJ.db then return end
        FDJ.db.templateCache = FDJ.db.templateCache or {}
        local saved = {}
        for g, list in pairs(results) do
            local ids = {}
            for i = 1, math.min(#list, 6) do ids[i] = list[i].id end
            saved[g.key] = ids
        end
        FDJ.db.templateCache[cacheKey] = saved
    end
    local function finish()
        if not opts.fromCache then cacheStore() end
        if opts.list then
            Gear.NewList(Gear.UnusedName(opts.list), false)
            replace = true
        end
        local mhGroup, ohGroup
        for g in pairs(results) do
            if g.key == "mainhand" then mhGroup = g elseif g.key == "offhand" then ohGroup = g end
        end
        local tank = Gear.Measure.Role and Gear.Measure.Role(class(), Gear.SpecOf and Gear.SpecOf()) == "tank"
        if tank and mhGroup and ohGroup then
            local one, shield = {}, {}
            for _, e in ipairs(results[mhGroup]) do
                local _, _, _, loc = C_Item.GetItemInfoInstant(e.id)
                if loc ~= "INVTYPE_2HWEAPON" then one[#one + 1] = e end
            end
            for _, e in ipairs(results[ohGroup]) do
                local _, _, _, loc = C_Item.GetItemInfoInstant(e.id)
                if loc == "INVTYPE_SHIELD" then shield[#shield + 1] = e end
            end
            results[mhGroup], results[ohGroup] = one, shield
        elseif mhGroup and ohGroup and listed[mhGroup] then
        elseif mhGroup and ohGroup then
            local best2H, best1H
            for _, e in ipairs(results[mhGroup]) do
                local _, _, _, loc = C_Item.GetItemInfoInstant(e.id)
                if loc == "INVTYPE_2HWEAPON" then best2H = best2H or e else best1H = best1H or e end
                if best2H and best1H then break end
            end
            local oh = results[ohGroup][1]
            local pair = (best1H and best1H.score or 0) + (oh and oh.score or 0)
            if best2H and best2H.score >= pair then
                results[mhGroup] = { best2H }
                results[ohGroup] = {}
            elseif best1H then
                results[mhGroup] = { best1H }
            end
        end
        local weights = Gear.Measure.StatValues(class(), Gear.SpecOf and Gear.SpecOf())
        for g, list in pairs(results) do
            if listed[g] then
                local best, seen = {}, {}
                for _, e in ipairs(list) do
                    if not seen[e.id] then seen[e.id] = true; best[#best + 1] = e end
                end
                results[g] = best
            else
                local merged, seen = {}, {}
                for _, e in ipairs(list) do merged[#merged + 1] = e end
                for _, slot in ipairs(g.slots) do
                    local worn = GetInventoryItemID("player", slot)
                    if worn then
                        local score = Advisor.Rate(worn, weights, class(), level, g.key)
                        if score then merged[#merged + 1] = { id = worn, score = score } end
                    end
                end
                table.sort(merged, function(a, b) return a.score > b.score end)
                local best = {}
                for _, e in ipairs(merged) do
                    if not seen[e.id] then
                        seen[e.id] = true
                        best[#best + 1] = e
                    end
                end
                results[g] = best
            end
        end
        if mhGroup and ohGroup and results[mhGroup] and results[mhGroup][1] then
            local _, _, _, loc = C_Item.GetItemInfoInstant(results[mhGroup][1].id)
            if loc == "INVTYPE_2HWEAPON" then results[ohGroup] = {} end
        end
        local s = Gear.ActivePicks()
        local filled = 0
        for g, list in pairs(results) do
            if replace or not s[g.key] or #s[g.key] == 0 then
                local picks = {}
                for i = 1, math.min(#list, Gear.SlotCount(g)) do picks[i] = list[i].id end
                s[g.key] = picks
                if #picks > 0 then filled = filled + 1 end
            end
        end
        if Gear.MarkAuto then Gear.MarkAuto(opts.auto) end
        if not opts.quiet then FDJ.Print(L.BIS_SUGGESTED:format(filled, level)) end
        FDJ:Emit("FDJ_WISHES")
        if done then done(true, 0) end
    end
    local fixed = level >= 60 and not opts.raid and Gear.PreRaidPicksFor
        and Gear.PreRaidPicksFor(class(), Gear.SpecOf and Gear.SpecOf())
    if fixed then
        for _, g in ipairs(todo) do
            local list = {}
            for _, id in ipairs(fixed[g.key] or {}) do
                local use = id
                if otherFactionOnly(id) then use = FACTION_TWIN[id] end
                if use then
                    want(use)
                    list[#list + 1] = { id = use, score = 0 }
                end
            end
            results[g] = list
            listed[g] = true
        end
        opts.fromCache = true
        finish()
        return
    end
    local cached = FDJ.db and FDJ.db.templateCache and FDJ.db.templateCache[cacheKey]
    if cached then
        for _, g in ipairs(todo) do
            local list = {}
            for i, id in ipairs(cached[g.key] or {}) do list[i] = { id = id, score = 0 } end
            results[g] = list
            listed[g] = true
        end
        opts.fromCache = true
        finish()
        return
    end
    local function pass()
        local waitingGroups, waiting, i = {}, 0, 0
        local function step()
            if opts.quiet and InCombatLockdown() then
                C_Timer.After(1, step)
                return
            end
            i = i + 1
            local g = todo[i]
            if not g then
                tries = tries + 1
                if #waitingGroups > 0 and tries < 20 then
                    if done then done(false, waiting) end
                    todo = waitingGroups
                    C_Timer.After(0.5, pass)
                    return
                end
                if #waitingGroups > 0 then opts.fromCache = true end
                finish()
                return
            end
            local list, w = Advisor.Contenders(g, { level = level })
            if level >= 60 and not opts.raid then
                local curated, cw = Advisor.Curated(g, { level = level })
                if curated and #curated > 0 then
                    list = blend(curated, list)
                    listed[g] = true
                end
                w = w + (cw or 0)
            end
            results[g] = list
            if w > 0 then
                waitingGroups[#waitingGroups + 1] = g
                waiting = waiting + w
            end
            C_Timer.After(0, step)
        end
        step()
    end
    pass()
end

local arrived = {}
FDJ:On("GET_ITEM_INFO_RECEIVED", function(itemID, success)
    if not pending[itemID] then return end
    pending[itemID] = nil
    if success == false then failed[itemID] = true end
    stale = true
    local g = Gear.SlotFor(itemID)
    if g then arrived[g.key] = true end
    local busy = Advisor.Loading() > 20
    FDJ.Debounce("bisitems", busy and 1.2 or 0.3, function()
        local keys = arrived
        arrived = {}
        FDJ:Emit("FDJ_GEAR_ITEMS", keys)
    end)
end)
FDJ:On("SKILL_LINES_CHANGED", function() wipe(blocked); stale = true end)
FDJ:On("PLAYER_LEVEL_UP", function() wipe(blocked); stale = true end)
FDJ:On("FDJ_GEAR_WEIGHTS", function() stale = true end)
FDJ:On("PLAYER_EQUIPMENT_CHANGED", function() stale = true end)
