local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local L = FDJ.L

local Gear = {}
FDJ.Gear = Gear

Gear.GROUPS = {
    { key = "head", slots = { 1 }, label = "HEADSLOT", locs = { INVTYPE_HEAD = true } },
    { key = "neck", slots = { 2 }, label = "NECKSLOT", locs = { INVTYPE_NECK = true } },
    { key = "shoulder", slots = { 3 }, label = "SHOULDERSLOT", locs = { INVTYPE_SHOULDER = true } },
    { key = "back", slots = { 15 }, label = "BACKSLOT", locs = { INVTYPE_CLOAK = true } },
    { key = "chest", slots = { 5 }, label = "CHESTSLOT", locs = { INVTYPE_CHEST = true, INVTYPE_ROBE = true } },
    { key = "wrist", slots = { 9 }, label = "WRISTSLOT", locs = { INVTYPE_WRIST = true } },
    { key = "hands", slots = { 10 }, label = "HANDSSLOT", locs = { INVTYPE_HAND = true } },
    { key = "waist", slots = { 6 }, label = "WAISTSLOT", locs = { INVTYPE_WAIST = true } },
    { key = "legs", slots = { 7 }, label = "LEGSSLOT", locs = { INVTYPE_LEGS = true } },
    { key = "feet", slots = { 8 }, label = "FEETSLOT", locs = { INVTYPE_FEET = true } },
    { key = "rings", slots = { 11, 12 }, label = "FINGER0SLOT", locs = { INVTYPE_FINGER = true } },
    { key = "trinkets", slots = { 13, 14 }, label = "TRINKET0SLOT", locs = { INVTYPE_TRINKET = true } },
    { key = "mainhand", slots = { 16 }, label = "MAINHANDSLOT",
      locs = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true } },
    { key = "offhand", slots = { 17 }, label = "SECONDARYHANDSLOT",
      locs = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_WEAPONOFFHAND = true } },
    { key = "ranged", slots = { 18 }, label = "RANGEDSLOT",
      locs = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true } },
    { key = "tabard", slots = { 19 }, label = "TABARDSLOT", locs = { INVTYPE_TABARD = true }, optional = true },
}

function Gear.TotalSlots()
    local n = 0
    for _, g in ipairs(Gear.GROUPS) do n = n + #g.slots end
    return n
end
local BY_KEY = {}
for _, g in ipairs(Gear.GROUPS) do BY_KEY[g.key] = g end

local FALLBACK_LABEL = {
    HEADSLOT = "Head", NECKSLOT = "Neck", SHOULDERSLOT = "Shoulder", BACKSLOT = "Back", CHESTSLOT = "Chest",
    WRISTSLOT = "Wrist", HANDSSLOT = "Hands", WAISTSLOT = "Waist", LEGSSLOT = "Legs", FEETSLOT = "Feet",
    FINGER0SLOT = "Rings", TRINKET0SLOT = "Trinkets", MAINHANDSLOT = "Main Hand",
    SECONDARYHANDSLOT = "Off Hand", RANGEDSLOT = "Ranged", TABARDSLOT = "Tabard",
}

function Gear.SlotName(group)
    if group.key == "rings" then return L.BIS_RINGS end
    if group.key == "trinkets" then return L.BIS_TRINKETS end
    return _G[group.label] or FALLBACK_LABEL[group.label] or group.key
end

function Gear.SlotCount(group)
    return #group.slots
end

local function owner(charKey)
    return charKey and FDJ.db and FDJ.db.chars[charKey] or FDJ.char
end

local SPEC_ICONS = {
    WARRIOR = { arms = 132355, fury = 132347, protection = 132341 },
    PALADIN = { holy = 135920, protection = 135893, retribution = 135873 },
    HUNTER = { beastmastery = 461112, marksmanship = 236179, survival = 461113 },
    ROGUE = { assassination = 236270, combat = 236286, subtlety = 132320 },
    PRIEST = { discipline = 135940, holy = 237542, shadow = 136207 },
    SHAMAN = { elemental = 136048, enhancement = 237581, restoration = 136052 },
    MAGE = { arcane = 135932, fire = 135810, frost = 135846 },
    WARLOCK = { affliction = 136145, demonology = 136172, destruction = 136186 },
    DRUID = { balance = 136096, feralcombat = 132115, restoration = 136041 },
}

local function classOf(charKey)
    local o = owner(charKey)
    if o and o.class then return o.class end
    local _, c = UnitClass("player")
    return c
end

function Gear.Specs(charKey)
    local class = classOf(charKey)
    local out = {}
    local markers = FojjiCore and FojjiCore.SpecMarkers and FojjiCore.SpecMarkers[class] or {}
    local mine = not charKey or charKey == FDJ.charKey
    for i, m in ipairs(markers) do
        local icon = SPEC_ICONS[class] and SPEC_ICONS[class][m[1]]
        if mine and GetTalentTabInfo then
            local r = { pcall(GetTalentTabInfo, i) }
            local tex = r[1] and (type(r[2]) == "number" and r[5] or r[3])
            if tex and (type(tex) == "number" or type(tex) == "string") then icon = icon or tex end
        end
        out[#out + 1] = { key = m[1], name = m[2], icon = icon or 134400 }
    end
    return out
end

local function detected()
    local spec = FojjiCore and FojjiCore.GetSpec and FojjiCore.GetSpec()
    return spec and spec.key
end

local function specOf(charKey)
    local o = owner(charKey)
    if o and o.bisSpec then return o.bisSpec end
    local mine = not charKey or charKey == FDJ.charKey
    local specs = Gear.Specs(charKey)
    return (mine and detected()) or (specs[1] and specs[1].key) or "any"
end
Gear.SpecOf = specOf

Gear.PHASES = 5
local function phaseOf(charKey)
    local o = owner(charKey)
    return math.max(1, math.min(Gear.PHASES, tonumber(o and o.bisPhase) or 1))
end
Gear.PhaseOf = phaseOf
local function fits(l, spec, phase) return l.spec == spec and (l.phase or 1) == phase end
local function slotKey(spec, phase) return phase == 1 and spec or (spec .. "#" .. phase) end

local function lists(charKey)
    local o = owner(charKey)
    if not o then return { { name = "?", picks = {} } }, 1 end
    if type(o.bisLists) ~= "table" or #o.bisLists == 0 then
        o.bisLists = { { name = L.BIS_LIST_DEFAULT, picks = type(o.bis) == "table" and o.bis or {} } }
        o.bisActive = 1
        o.bis = nil
    end
    local spec = specOf(charKey)
    o.bisSpec = spec
    for _, l in ipairs(o.bisLists) do
        l.spec = l.spec or spec
        if l.name == "Pre-raid (level 60 dungeons)" or l.name == "Pre-raid" then l.name = L.BIS_PRESET_PRERAID end
    end
    local phase = phaseOf(charKey)
    local active = tonumber(o.bisActive) or 1
    local cur = o.bisLists[active]
    if not cur or not fits(cur, spec, phase) then
        active = nil
        o.bisBySpec = o.bisBySpec or {}
        local remembered = o.bisBySpec[slotKey(spec, phase)]
        if remembered and o.bisLists[remembered] and fits(o.bisLists[remembered], spec, phase) then active = remembered end
        if not active then
            for i, l in ipairs(o.bisLists) do
                if fits(l, spec, phase) then active = i break end
            end
        end
        if not active then
            o.bisLists[#o.bisLists + 1] = { name = L.BIS_LIST_DEFAULT, spec = spec, phase = phase > 1 and phase or nil, picks = {} }
            active = #o.bisLists
        end
    end
    o.bisActive = active
    return o.bisLists, active
end
Gear.Lists = lists

local function store(charKey)
    local all, active = lists(charKey)
    local list = all[active]
    list.picks = list.picks or {}
    return list.picks
end
Gear.ActivePicks = store

local function changedLists()
    FDJ:Emit("FDJ_WISHES")
end

function Gear.ActiveName(charKey)
    local all, active = lists(charKey)
    return all[active].name, active, #all
end

function Gear.SpecLists(charKey)
    local all, active = lists(charKey)
    local spec, phase = specOf(charKey), phaseOf(charKey)
    local out = {}
    for i, l in ipairs(all) do
        if fits(l, spec, phase) then out[#out + 1] = { index = i, name = l.name, picks = l.picks, active = i == active } end
    end
    return out
end

function Gear.SetPhase(n, charKey)
    local o = owner(charKey)
    if not o then return end
    o.bisPhase = math.max(1, math.min(Gear.PHASES, tonumber(n) or 1))
    lists(charKey)
    changedLists()
end

function Gear.SetSpec(key, charKey)
    local o = owner(charKey)
    if not o or not key then return end
    o.bisSpec = key
    lists(charKey)
    changedLists()
end

function Gear.SetActive(index, charKey)
    local o = owner(charKey)
    local all = lists(charKey)
    local l = all[index]
    if not l then return end
    o.bisSpec = l.spec
    o.bisPhase = l.phase or 1
    o.bisActive = index
    o.bisBySpec = o.bisBySpec or {}
    o.bisBySpec[slotKey(l.spec, l.phase or 1)] = index
    changedLists()
end

function Gear.MoveList(from, to, charKey)
    local o = owner(charKey)
    local all, active = lists(charKey)
    if from == to or not all[from] or not all[to] then return end
    local l = table.remove(all, from)
    table.insert(all, to, l)
    if active == from then
        o.bisActive = to
    elseif from < active and to >= active then
        o.bisActive = active - 1
    elseif from > active and to <= active then
        o.bisActive = active + 1
    end
    o.bisBySpec = nil
    changedLists()
end

local function copy(picks)
    local out = {}
    for key, ids in pairs(picks or {}) do
        out[key] = {}
        for i, id in ipairs(ids) do out[key][i] = id end
    end
    return out
end

function Gear.UnusedName(name, charKey)
    local taken = {}
    for _, l in ipairs(Gear.SpecLists(charKey)) do taken[l.name] = true end
    local final, k = name, 2
    while taken[final] do
        final = name .. " " .. k
        k = k + 1
    end
    return final
end

function Gear.NewList(name, fromCurrent, charKey)
    local all, active = lists(charKey)
    local phase = phaseOf(charKey)
    all[#all + 1] = { name = name, spec = specOf(charKey), phase = phase > 1 and phase or nil, picks = fromCurrent and copy(all[active].picks) or {} }
    Gear.SetActive(#all, charKey)
end

function Gear.RenameList(name, charKey)
    local all, active = lists(charKey)
    if name and name ~= "" then all[active].name = name end
    changedLists()
end

function Gear.DeleteListAt(index, charKey)
    local o = owner(charKey)
    local all, active = lists(charKey)
    local l = all[index]
    if not l then return end
    if index == active then return Gear.DeleteList(charKey) end
    table.remove(all, index)
    o.bisActive = index < active and active - 1 or active
    o.bisBySpec = nil
    changedLists()
end

function Gear.DeleteSave(key)
    local data = FDJ.db and FDJ.db.chars[key]
    if not data or key == FDJ.charKey then return end
    data.bisLists, data.bis, data.bisActive, data.bisSpec, data.bisBySpec = nil, nil, nil, nil, nil
    if not key:match("%-%x%x%x%x%x%x+$") then FDJ.db.chars[key] = nil end
    changedLists()
end

function Gear.DeleteList(charKey)
    local o = owner(charKey)
    local all, active = lists(charKey)
    local spec, phase = all[active].spec, all[active].phase or 1
    local others = 0
    for _, l in ipairs(all) do if fits(l, spec, phase) then others = others + 1 end end
    if others <= 1 then
        all[active].picks = {}
    else
        table.remove(all, active)
        o.bisActive = nil
        o.bisBySpec = nil
    end
    changedLists()
end

local function equipLoc(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, loc = C_Item.GetItemInfoInstant(itemID)
        return loc
    end
    if GetItemInfoInstant then
        local _, _, _, loc = GetItemInfoInstant(itemID)
        return loc
    end
end

function Gear.SlotFor(itemID)
    local loc = equipLoc(itemID)
    if not loc or loc == "" then return nil end
    for _, g in ipairs(Gear.GROUPS) do
        if g.locs[loc] then return g end
    end
end

function Gear.Locate(itemID, charKey)
    if not itemID then return nil end
    for key, list in pairs(store(charKey)) do
        for rank, id in ipairs(list) do
            if id == itemID then return BY_KEY[key], rank end
        end
    end
end

local DEFAULTS = { enabled = true, key = "SHIFT-L", tooltip = true, alerts = true, altClick = true, autoSuggest = false, gearScore = true,
    alertSound = "ping", alertBig = false }

Gear.ALERT_SOUNDS = {
    { "none", "None" },
    { "ping", "Map ping", "MAP_PING", 3175 },
    { "coin", "Coins", "LOOT_WINDOW_COIN_SOUND", 120 },
    { "quest", "Quest complete", "IG_QUEST_LIST_COMPLETE", 618 },
    { "ready", "Ready check", "READY_CHECK", 8960 },
    { "levelup", "Level up", "LEVELUP", 888 },
    { "raid", "Raid warning", "RAID_WARNING", 8959 },
}

function Gear.PlayAlertSound(key)
    for _, s in ipairs(Gear.ALERT_SOUNDS) do
        if s[1] == key then
            if not s[4] or not PlaySound then return end
            local id = (SOUNDKIT and s[3] and SOUNDKIT[s[3]]) or s[4]
            pcall(PlaySound, id, "Master")
            return
        end
    end
end

function Gear.Options()
    if not FDJ.db then return DEFAULTS end
    local o = FDJ.db.bisOptions
    if type(o) ~= "table" then
        o = {}
        FDJ.db.bisOptions = o
    end
    if not o.autoOptIn then
        o.autoOptIn = true
        o.autoSuggest = false
    end
    for k, v in pairs(DEFAULTS) do
        if o[k] == nil then o[k] = v end
    end
    return o
end

function Gear.Enabled()
    return not FDJ.off and Gear.Options().enabled ~= false
end

function Gear.MarkAuto(on)
    local all, active = lists()
    local l = all[active]
    if l then l.auto = on or nil end
end
local function clearAutoPlans()
    local o = owner()
    for _, l in ipairs(o and o.bisLists or {}) do
        if l.auto then
            l.picks = {}
            l.auto = nil
        end
    end
end

function Gear.SetOption(key, value)
    Gear.Options()[key] = value
    if key == "autoSuggest" and not value then clearAutoPlans() end
    if key == "key" or key == "enabled" then Gear.ApplyKey() end
    FDJ:Emit("FDJ_WISHES")
    FDJ:Emit("FDJ_GEAR_OPTIONS", key)
end

function Gear.HasItem(itemID, charKey)
    if not Gear.Enabled() then return false end
    return Gear.Locate(itemID, charKey) ~= nil
end

function Gear.Wanted()
    local out = {}
    if not Gear.Enabled() then return out end
    local all = lists()
    for _, l in ipairs(all) do
        for key, ids in pairs(l.picks or {}) do
            local g = BY_KEY[key]
            for i = 1, math.min(g and Gear.SlotCount(g) or 1, #ids) do
                if ids[i] and not out[ids[i]] then out[ids[i]] = l.name end
            end
        end
    end
    return out
end

function Gear.ForTooltip(itemID)
    if not (Gear.Enabled() and Gear.Options().tooltip) then return nil end
    return Gear.Locate(itemID)
end

function Gear.SetsWith(itemID)
    local out = {}
    local all, active = lists()
    local function holds(l)
        for _, ids in pairs(l.picks or {}) do
            for _, id in ipairs(ids) do if id == itemID then return true end end
        end
    end
    if all[active] and holds(all[active]) then out[1] = all[active].name end
    for i, l in ipairs(all) do
        if i ~= active and holds(l) then out[#out + 1] = l.name end
    end
    return out
end

function Gear.AlertFor(itemID)
    return Gear.Enabled() and Gear.Options().alerts and Gear.Locate(itemID) ~= nil
end

function Gear.Accepts(itemID)
    return Gear.Enabled() and Gear.SlotFor(itemID) ~= nil
end

local function changed()
    FDJ:Emit("FDJ_WISHES")
end
local function edited(charKey)
    if not charKey or charKey == FDJ.charKey then Gear.MarkAuto(false) end
    changed()
end

function Gear.AddItem(itemID, charKey, quiet)
    local g = Gear.SlotFor(itemID)
    if not g then
        if not quiet then FDJ.Print(L.PLAN_NOT_GEAR) end
        return false
    end
    if Gear.HasItem(itemID, charKey) then return true end
    local s = store(charKey)
    s[g.key] = s[g.key] or {}
    table.insert(s[g.key], itemID)
    if not quiet then
        local _, link = C_Item.GetItemInfo(itemID)
        FDJ.Print(L.PLAN_ADDED:format(link or ("item " .. itemID), Gear.SlotName(g)))
    end
    edited(charKey)
    return true
end

function Gear.RemoveItem(itemID, charKey)
    local g, rank = Gear.Locate(itemID, charKey)
    if not g then return end
    table.remove(store(charKey)[g.key], rank)
    edited(charKey)
end

function Gear.ClearSlot(group, index, charKey)
    local list = store(charKey)[group.key]
    if not list then return end
    index = index or 1
    local wants = Gear.SlotCount(group)
    for i = #list, 1, -1 do
        if i == index or i > wants then table.remove(list, i) end
    end
    edited(charKey)
end

function Gear.PutInSlot(group, index, itemID, charKey)
    local s = store(charKey)
    local list = s[group.key] or {}
    s[group.key] = list
    for i = #list, 1, -1 do
        if list[i] == itemID then table.remove(list, i) end
    end
    index = math.max(1, math.min(index or 1, #list + 1))
    table.insert(list, index, itemID)
    edited(charKey)
end

function Gear.ToggleItem(itemID, charKey)
    if Gear.HasItem(itemID, charKey) then Gear.RemoveItem(itemID, charKey) else Gear.AddItem(itemID, charKey) end
end

function Gear.MoveToFront(itemID, charKey)
    local g, rank = Gear.Locate(itemID, charKey)
    if not g or rank == 1 then return end
    local list = store(charKey)[g.key]
    table.remove(list, rank)
    table.insert(list, 1, itemID)
    edited(charKey)
end

function Gear.ItemsIn(group, charKey)
    return store(charKey)[group.key] or {}
end

local function owned(itemID)
    if C_Item.GetItemCount and C_Item.GetItemCount(itemID, true) > 0 then return true end
    if GetItemCount and GetItemCount(itemID, true) > 0 then return true end
    return false
end

local stateCache = {}
function Gear.State(group, itemID)
    for _, slot in ipairs(group.slots) do
        if GetInventoryItemID("player", slot) == itemID then return "equipped" end
    end
    local hit = stateCache[itemID]
    if hit == nil then
        local ok, have = pcall(owned, itemID)
        hit = (ok and have) and true or false
        stateCache[itemID] = hit
    end
    return hit and "owned" or "missing"
end
FDJ:On("BAG_UPDATE_DELAYED", function() wipe(stateCache) end)
FDJ:On("PLAYER_EQUIPMENT_CHANGED", function() wipe(stateCache) end)
FDJ:On("PLAYERBANKSLOTS_CHANGED", function() wipe(stateCache) end)

function Gear.Done(group)
    local picks = Gear.ItemsIn(group)
    if #picks == 0 then return nil end
    for i = 1, math.min(Gear.SlotCount(group), #picks) do
        if Gear.State(group, picks[i]) ~= "equipped" then return false end
    end
    return true
end

function Gear.Progress()
    local done, total = 0, 0
    for _, g in ipairs(Gear.GROUPS) do
        local d = Gear.Done(g)
        if d ~= nil then
            total = total + 1
            if d then done = done + 1 end
        end
    end
    return done, total
end

function Gear.Source(itemID)
    local src = FDJ.LootSources[itemID] and FDJ.LootSources[itemID][1]
    return src and src.boss, src and src.odds
end

local questRewards
function Gear.QuestFor(itemID)
    if not questRewards then
        questRewards = {}
        local side = UnitFactionGroup("player")
        for qid, q in pairs(FDJ.QuestBook or {}) do
            if not q.side or q.side == side then
                for _, id in ipairs(q.gives or {}) do
                    if not questRewards[id] then questRewards[id] = qid end
                end
            end
        end
    end
    local qid = questRewards[itemID]
    return qid and FDJ.QuestBook[qid], qid
end

function Gear.QuestRewards()
    Gear.QuestFor(0)
    return questRewards
end

function Gear.ToText(charKey)
    local parts = {}
    for _, g in ipairs(Gear.GROUPS) do
        local picks = Gear.ItemsIn(g, charKey)
        if #picks > 0 then
            local ids = {}
            for i, id in ipairs(picks) do ids[i] = tostring(id) end
            parts[#parts + 1] = g.key .. "=" .. table.concat(ids, ",")
        end
    end
    local name = (Gear.ActiveName(charKey) or ""):gsub("[;=]", "")
    if name ~= "" then parts[#parts + 1] = "name=" .. name:gsub(" ", "_") end
    return "FCPLAN1:" .. table.concat(parts, ";")
end

function Gear.FromText(text)
    text = (text or ""):gsub("%s", "")
    local body = text:match("^FCPLAN1:(.*)$") or text:match("^FCBIS1:(.*)$")
    if not body then
        FDJ.Print(L.PLAN_IMPORT_BAD)
        return false
    end
    local incoming, n = {}, 0
    local name = body:match("name=([^;]+)")
    name = name and name:gsub("_", " ") or L.BIS_IMPORTED_NAME
    for key, ids in body:gmatch("(%a+)=([%d,]+)") do
        if BY_KEY[key] then
            incoming[key] = {}
            for id in ids:gmatch("%d+") do
                table.insert(incoming[key], tonumber(id))
                n = n + 1
            end
        end
    end
    if n == 0 then
        FDJ.Print(L.PLAN_IMPORT_BAD)
        return false
    end
    local final = Gear.UnusedName(name)
    Gear.NewList(final, false)
    local s = store()
    for key, list in pairs(incoming) do s[key] = list end
    FDJ.Print(L.PLAN_IMPORTED:format(n, final))
    changed()
    return true
end

function Gear.AdoptLists(fromKey)
    local src = FDJ.db and FDJ.db.chars[fromKey]
    if not src or fromKey == FDJ.charKey then return end
    local all = lists()
    local mySpecs = {}
    for _, sp in ipairs(Gear.Specs()) do mySpecs[sp.key] = true end
    local cur = specOf()
    local moved = 0
    for _, l in ipairs(type(src.bisLists) == "table" and src.bisLists or {}) do
        if not mySpecs[l.spec or ""] then l.spec = cur end
        all[#all + 1] = l
        moved = moved + 1
    end
    if moved == 0 and type(src.bis) == "table" then
        all[#all + 1] = { name = L.BIS_LIST_DEFAULT, spec = cur, picks = src.bis }
        moved = 1
    end
    src.bisLists, src.bis, src.bisActive, src.bisSpec, src.bisBySpec = nil, nil, nil, nil, nil
    if not fromKey:match("%-%x%x%x%x%x%x+$") then FDJ.db.chars[fromKey] = nil end
    if moved > 0 then FDJ.Print(L.BIS_ADOPTED:format(moved)) end
    changedLists()
end

function Gear.Characters()
    local list = {}
    for key, data in pairs(FDJ.db.chars) do
        if type(data) == "table" and (type(data.bisLists) == "table" or type(data.bis) == "table" or key == FDJ.charKey) then
            local n = 0
            if type(data.bisLists) == "table" then
                for _, l in ipairs(data.bisLists) do
                    for _, picks in pairs(l.picks or {}) do n = n + #picks end
                end
            elseif type(data.bis) == "table" then
                for _, picks in pairs(data.bis) do n = n + #picks end
            end
            if n > 0 or key == FDJ.charKey then
                local old = not key:match("%-%x%x%x%x%x%x+$")
                list[#list + 1] = { key = key, class = data.class, n = n, old = old,
                    name = data.name or key:match("^([^%-]+)") or key, me = key == FDJ.charKey }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.me ~= b.me then return a.me end
        return a.name < b.name
    end)
    return list
end

local function hookClicks()
    if Gear.hooked or not HandleModifiedItemClick or (Addon.GamepadUI and Addon.GamepadUI()) then return end
    Gear.hooked = true
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if not (IsAltKeyDown() and IsControlKeyDown()) or IsShiftKeyDown() or not Gear.Enabled() or not Gear.Options().altClick then return end
        local id = FDJ.ItemFromLink(link)
        if id and Gear.SlotFor(id) then Gear.ToggleItem(id) end
    end)
end

local function migrate()
    local char = FDJ.char
    if not char or char.bisMigrated then return end
    char.bisMigrated = true
    for itemID in pairs(char.wishes or {}) do
        if Gear.SlotFor(itemID) and Gear.AddItem(itemID, nil, true) then char.wishes[itemID] = nil end
    end
end

local keyButton = CreateFrame("Button", "FojjiCorePlanKey", UIParent)
keyButton:SetScript("OnClick", function()
    if Gear.Enabled() and Gear.ToggleWindow then Gear.ToggleWindow() end
end)
local keyPending = false
function Gear.ApplyKey()
    if InCombatLockdown and InCombatLockdown() then keyPending = true return end
    keyPending = false
    ClearOverrideBindings(keyButton)
    local key = Gear.Enabled() and Gear.Options().key
    if key and key ~= "" then SetOverrideBindingClick(keyButton, false, key, "FojjiCorePlanKey") end
end
FDJ:On("PLAYER_REGEN_ENABLED", function() if keyPending then Gear.ApplyKey() end end)

FDJ:On("PLAYER_LOGIN", function()
    hookClicks()
    pcall(migrate)
    Gear.ApplyKey()
end)
FDJ:On("PLAYER_EQUIPMENT_CHANGED", function() FDJ.Debounce("bisgear", 0.3, changed) end)

local function listIsEmpty()
    for _, picks in pairs(store()) do
        if #picks > 0 then return false end
    end
    return true
end
local filling
function Gear.AutoFill()
    if filling or not (Gear.Enabled() and Gear.Options().autoSuggest and Gear.Advisor) or not listIsEmpty() then return end
    filling = true
    Gear.Advisor.Assemble(false, function(finished) if finished then filling = nil end end, { quiet = true, auto = true })
end
