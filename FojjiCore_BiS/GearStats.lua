local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local L = FDJ.L
local Gear = FDJ.Gear

local Measure = {}
Gear.Measure = Measure

Measure.LIST = {
    { id = "STR", label = "Strength", group = "attr" },
    { id = "AGI", label = "Agility", group = "attr" },
    { id = "STA", label = "Stamina", group = "attr" },
    { id = "INT", label = "Intellect", group = "attr" },
    { id = "SPI", label = "Spirit", group = "attr" },
    { id = "AP", label = "Attack Power", group = "off" },
    { id = "RAP", label = "Ranged Attack Power", group = "off" },
    { id = "SP", label = "Spell Damage", group = "off" },
    { id = "HEAL", label = "Healing", group = "off" },
    { id = "DPS", label = "Weapon DPS", group = "off", pct = false },
    { id = "FAP", label = "Feral Attack Power", group = "off" },
    { id = "HIT", label = "Hit", group = "off", pct = true },
    { id = "CRIT", label = "Crit", group = "off", pct = true },
    { id = "SPELLHIT", label = "Spell Hit", group = "off", pct = true },
    { id = "SPELLCRIT", label = "Spell Crit", group = "off", pct = true },
    { id = "HASTE", label = "Haste", group = "off", pct = true },
    { id = "MP5", label = "Mana per 5", group = "off" },
    { id = "ARMOR", label = "Armor", group = "def" },
    { id = "DEF", label = "Defense", group = "def" },
    { id = "DODGE", label = "Dodge", group = "def", pct = true },
    { id = "PARRY", label = "Parry", group = "def", pct = true },
    { id = "BLOCK", label = "Block", group = "def", pct = true },
    { id = "BLOCKVAL", label = "Block Value", group = "def" },
    { id = "FIRE", label = "Fire Resistance", group = "res" },
    { id = "NATURE", label = "Nature Resistance", group = "res" },
    { id = "FROST", label = "Frost Resistance", group = "res" },
    { id = "SHADOW", label = "Shadow Resistance", group = "res" },
    { id = "ARCANE", label = "Arcane Resistance", group = "res" },
}
Measure.BY_ID = {}
for _, s in ipairs(Measure.LIST) do Measure.BY_ID[s.id] = s end

local STAT_FIELDS = {
    { "RESISTANCE0", "ARMOR" }, { "RESISTANCE2", "FIRE" }, { "RESISTANCE3", "NATURE" }, { "RESISTANCE4", "FROST" },
    { "RESISTANCE5", "SHADOW" }, { "RESISTANCE6", "ARCANE" },
    { "BLOCK_VALUE", "BLOCKVAL" }, { "RANGED_ATTACK_POWER", "RAP" }, { "FERAL_ATTACK_POWER", "FAP" }, { "ATTACK_POWER", "AP" },
    { "STRENGTH", "STR" }, { "AGILITY", "AGI" }, { "STAMINA", "STA" }, { "INTELLECT", "INT" }, { "SPIRIT", "SPI" },
    { "HEALTH", false }, { "SPELL_HEALING", "HEAL" }, { "HEAL", "HEAL" }, { "SPELL_DAMAGE", "SP" }, { "SPELL_POWER", "SP" },
    { "CRIT", false }, { "HIT", false }, { "HASTE", false }, { "DEFENSE", "DEF" }, { "DODGE", false },
    { "PARRY", false }, { "BLOCK", false }, { "MANA_REGENERATION", "MP5" }, { "POWER_REGEN0", "MP5" },
    { "DAMAGE_PER_SECOND", "DPS" },
}

local EQUIP = {
    { "critical strike with spells by ([%d%.]+)%%", "SPELLCRIT" },
    { "critical strike.-by ([%d%.]+)%%", "CRIT" },
    { "hit with spells by ([%d%.]+)%%", "SPELLHIT" },
    { "chance to hit by ([%d%.]+)%%", "HIT" },
    { "haste by ([%d%.]+)%%", "HASTE" },
    { "attack speed by ([%d%.]+)%%", "HASTE" },
    { "damage and healing done by magical spells and effects by up to (%d+)", "SP" },
    { "healing done by spells and effects by up to (%d+)", "HEAL" },
    { "attack power by (%d+) in cat", "FAP" },
    { "ranged attack power by (%d+)", "RAP" },
    { "%+(%d+) ranged attack power", "RAP" },
    { "%+(%d+) attack power", "AP" },
    { "attack power by (%d+)", "AP" },
    { "(%d+) mana per 5 sec", "MP5" },
    { "defense %+(%d+)", "DEF" },
    { "defense skill by (%d+)", "DEF" },
    { "dodge an attack by ([%d%.]+)%%", "DODGE" },
    { "parry an attack by ([%d%.]+)%%", "PARRY" },
    { "block attacks with a shield by ([%d%.]+)%%", "BLOCK" },
    { "block value of your shield by (%d+)", "BLOCKVAL" },
}

local EQUIP_PREFIX = ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"

local cache = {}

local function equipLines(itemID)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return {} end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or type(data) ~= "table" or not data.lines then return {} end
    local out = {}
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not FDJ.Secret(text) and text:sub(1, #EQUIP_PREFIX) == EQUIP_PREFIX then
            out[#out + 1] = strtrim(text:sub(#EQUIP_PREFIX + 1))
        end
    end
    return out
end

function Measure.Item(itemID)
    if not itemID then return nil end
    local hit = cache[itemID]
    if hit then return hit end
    local name, link = C_Item.GetItemInfo(itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    local ok, raw = pcall(get, link or ("item:" .. itemID))
    local stats, effects = {}, {}
    for key, value in pairs(ok and type(raw) == "table" and raw or {}) do
        if type(value) == "number" then
            for _, k in ipairs(STAT_FIELDS) do
                if key:find(k[1], 1, true) then
                    if k[2] then stats[k[2]] = (stats[k[2]] or 0) + value end
                    break
                end
            end
        end
    end
    local fromGame = {}
    for k in pairs(stats) do fromGame[k] = true end
    for _, text in ipairs(equipLines(itemID)) do
        local lower, matched = text:lower(), false
        for _, rule in ipairs(EQUIP) do
            local n = lower:match(rule[1])
            if n then
                matched = true
                local id, v = rule[2], tonumber(n) or 0
                if Measure.BY_ID[id].pct then
                    if fromGame[id] then
                        stats[id] = 0
                        fromGame[id] = nil
                    end
                    stats[id] = (stats[id] or 0) + v
                elseif not fromGame[id] then
                    stats[id] = (stats[id] or 0) + v
                end
                break
            end
        end
        if not matched then effects[#effects + 1] = text end
    end
    local _, _, _, loc = C_Item.GetItemInfoInstant(itemID)
    hit = { stats = stats, effects = effects, loc = loc }
    cache[itemID] = hit
    return hit
end

local D = {
    melee = { STR = 1, AGI = 0.6, STA = 0.15, AP = 0.5, ARMOR = 0.005, DPS = 7, HIT = 12, CRIT = 11, HASTE = 7 },
    agility = { AGI = 1, STR = 0.5, STA = 0.15, AP = 0.5, ARMOR = 0.005, DPS = 7, HIT = 12, CRIT = 11, HASTE = 7 },
    feral = { STR = 1, AGI = 1.1, STA = 0.2, AP = 0.5, FAP = 0.5, ARMOR = 0.01, HIT = 12, CRIT = 11 },
    ranged = { AGI = 1, INT = 0.15, STA = 0.1, RAP = 0.45, AP = 0.45, ARMOR = 0.005, DPS = 7, HIT = 11, CRIT = 11, HASTE = 6 },
    caster = { SP = 1, INT = 0.25, SPI = 0.1, STA = 0.1, MP5 = 0.5, SPELLHIT = 10, SPELLCRIT = 8, HASTE = 6 },
    healer = { HEAL = 1, SP = 1, INT = 0.6, SPI = 0.5, STA = 0.1, MP5 = 1.6, SPELLCRIT = 5, HASTE = 4 },
    tank = { STA = 1, STR = 0.5, AGI = 0.7, ARMOR = 0.05, DEF = 1.5, DODGE = 12, PARRY = 10, BLOCK = 6, BLOCKVAL = 0.4, HIT = 6, CRIT = 3, AP = 0.15, DPS = 2 },
}
local SPEC_ROLE = {
    WARRIOR = { arms = "melee", fury = "melee", protection = "tank" },
    PALADIN = { holy = "healer", protection = "tank", retribution = "melee" },
    HUNTER = { beastmastery = "ranged", marksmanship = "ranged", survival = "ranged" },
    ROGUE = { assassination = "agility", combat = "agility", subtlety = "agility" },
    PRIEST = { discipline = "healer", holy = "healer", shadow = "caster" },
    SHAMAN = { elemental = "caster", enhancement = "melee", restoration = "healer" },
    MAGE = { arcane = "caster", fire = "caster", frost = "caster" },
    WARLOCK = { affliction = "caster", demonology = "caster", destruction = "caster" },
    DRUID = { balance = "caster", feralcombat = "feral", restoration = "healer" },
}

function Measure.Role(class, spec)
    local map = SPEC_ROLE[class] or {}
    return map[spec or ""] or (class == "HUNTER" and "ranged") or (class == "ROGUE" and "agility")
        or ((class == "WARRIOR" or class == "PALADIN") and "melee") or "caster"
end

function Measure.Defaults(class, spec)
    local out = {}
    for k, v in pairs(D[Measure.Role(class, spec)] or D.caster) do out[k] = v end
    return out
end

local function saved()
    if not FDJ.db then return {} end
    FDJ.db.bisWeights = FDJ.db.bisWeights or {}
    return FDJ.db.bisWeights
end

local function myClass()
    local _, c = UnitClass("player")
    return c
end

function Measure.StatValues(class, spec)
    class = class or myClass()
    spec = spec or Gear.SpecOf()
    local mine = saved()[class .. ":" .. tostring(spec)]
    if type(mine) == "table" and next(mine) then return mine, true end
    return Measure.Defaults(class, spec), false
end

function Measure.SetStatValue(id, value, class, spec)
    class = class or myClass()
    spec = spec or Gear.SpecOf()
    local key = class .. ":" .. tostring(spec)
    local w = saved()[key]
    if not w then
        w = Measure.Defaults(class, spec)
        saved()[key] = w
    end
    w[id] = (value and value ~= 0) and value or nil
    FDJ:Emit("FDJ_GEAR_WEIGHTS")
end

function Measure.ResetStatValues(class, spec)
    saved()[(class or myClass()) .. ":" .. tostring(spec or Gear.SpecOf())] = nil
    FDJ:Emit("FDJ_GEAR_WEIGHTS")
end

local WEIGHT_KEYS = {
    strength = "STR", agility = "AGI", stamina = "STA", intellect = "INT", spirit = "SPI",
    ap = "AP", attackpower = "AP", rap = "RAP", rangedattackpower = "RAP",
    spelldamage = "SP", spellpower = "SP", healing = "HEAL", bonushealing = "HEAL",
    dps = "DPS", meleedps = "DPS", rangeddps = "DPS", weapondps = "DPS",
    hitrating = "HIT", hit = "HIT", meleehit = "HIT", spellhit = "HIT", hitpercent = "HIT",
    critrating = "CRIT", crit = "CRIT", meleecrit = "CRIT", spellcrit = "CRIT", critpercent = "CRIT",
    hasterating = "HASTE", haste = "HASTE", spellhaste = "HASTE",
    mp5 = "MP5", manaregen = "MP5", armor = "ARMOR", defenserating = "DEF", defense = "DEF",
    dodgerating = "DODGE", dodge = "DODGE", parryrating = "PARRY", parry = "PARRY",
    blockrating = "BLOCK", block = "BLOCK", blockvalue = "BLOCKVAL",
    fireresist = "FIRE", natureresist = "NATURE", frostresist = "FROST", shadowresist = "SHADOW", arcaneresist = "ARCANE",
}
for _, s in ipairs(Measure.LIST) do
    WEIGHT_KEYS[s.id:lower()] = s.id
    WEIGHT_KEYS[s.label:lower():gsub("[^%a]", "")] = s.id
end

local WEIGHT_OUT = {
    STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit", AP = "Ap", RAP = "Rap",
    SP = "SpellDamage", HEAL = "Healing", DPS = "Dps", HIT = "Hit", CRIT = "Crit", HASTE = "Haste", MP5 = "Mp5",
    SPELLHIT = "SpellHit", SPELLCRIT = "SpellCrit", FAP = "FeralAp",
    ARMOR = "Armor", DEF = "Defense", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", BLOCKVAL = "BlockValue",
    FIRE = "FireResist", NATURE = "NatureResist", FROST = "FrostResist", SHADOW = "ShadowResist", ARCANE = "ArcaneResist",
}

function Measure.FromText(text, class, spec)
    text = text or ""
    local body = text:match("%((.-)%)") or text
    local got, n = {}, 0
    for key, value in body:gmatch("([%a][%w%s_]-)%s*[=:]%s*\"?(%-?[%d%.]+)\"?") do
        local id = WEIGHT_KEYS[key:lower():gsub("[^%a]", "")]
        local v = tonumber(value)
        if id and v then
            got[id] = v
            n = n + 1
        end
    end
    if n == 0 then
        FDJ.Print(L.BIS_WEIGHTS_BAD)
        return false
    end
    saved()[(class or myClass()) .. ":" .. tostring(spec or Gear.SpecOf())] = got
    FDJ:Emit("FDJ_GEAR_WEIGHTS")
    FDJ.Print(L.BIS_WEIGHTS_IMPORTED:format(n))
    return true
end

function Measure.ToText(class, spec)
    class = class or myClass()
    spec = spec or Gear.SpecOf()
    local w = Measure.StatValues(class, spec)
    local parts = {}
    for _, s in ipairs(Measure.LIST) do
        if w[s.id] then parts[#parts + 1] = ("%s=%s"):format(WEIGHT_OUT[s.id] or s.id, tostring(w[s.id])) end
    end
    local c = class:sub(1, 1) .. class:sub(2):lower()
    local specName = spec
    for _, sp in ipairs(Gear.Specs()) do if sp.key == spec then specName = sp.name end end
    specName = tostring(specName):gsub("%s", "")
    return ('( Pawn: v1: "FojjiCore %s": Class=%s, Spec=%s, %s )'):format(specName, c, specName, table.concat(parts, ", "))
end

local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18, 19 }
Measure.SLOTS = SLOTS

function Measure.Sum(set)
    local total, effects, missing = {}, {}, 0
    local mh = set[16] and Measure.Item(set[16])
    local isTwoHander = mh and mh.loc == "INVTYPE_2HWEAPON"
    local _, class = UnitClass("player")
    local dpsSlot = class == "HUNTER" and 18 or 16
    for _, slot in ipairs(SLOTS) do
        local id = set[slot]
        if id and not (slot == 17 and isTwoHander) then
            local item = Measure.Item(id)
            if item then
                for k, v in pairs(item.stats) do
                    if k ~= "DPS" or slot == dpsSlot then total[k] = (total[k] or 0) + v end
                end
                for _, e in ipairs(item.effects) do effects[#effects + 1] = e end
            else
                missing = missing + 1
            end
        end
    end
    return total, effects, missing
end

function Measure.Value(total, weights)
    local s = 0
    for k, v in pairs(total) do s = s + (weights[k] or 0) * v end
    return s
end

function Measure.ItemValue(itemID, weights)
    local item = Measure.Item(itemID)
    if not item then return nil end
    return Measure.Value(item.stats, weights or Measure.StatValues())
end

function Measure.Worn(unit)
    local set = {}
    for _, slot in ipairs(SLOTS) do
        local id = GetInventoryItemID(unit or "player", slot)
        if id then set[slot] = id end
    end
    return set
end

function Measure.PlannedSet(charKey, keepWorn)
    local set = {}
    for _, g in ipairs(Gear.GROUPS) do
        local picks = Gear.ItemsIn(g, charKey)
        for i, slot in ipairs(g.slots) do
            local id = picks[i]
            if not id and keepWorn then id = GetInventoryItemID("player", slot) end
            set[slot] = id
        end
    end
    return set
end

function Measure.GearScore(set, weights)
    local total, _, missing = Measure.Sum(set)
    return math.floor(Measure.Value(total, weights) + 0.5), missing
end

local scores = {}
local queue, inspecting, lastAsk = nil, nil, 0

local function avgItemLevel(set)
    local sum, n = 0, 0
    for _, slot in ipairs(SLOTS) do
        local id = set[slot]
        if id then
            local _, _, _, ilvl = C_Item.GetItemInfo(id)
            if ilvl then sum, n = sum + ilvl, n + 1 end
        end
    end
    return n > 0 and math.floor(sum / n + 0.5) or nil
end

local function specOfUnit(unit, class)
    if UnitIsUnit(unit, "player") then return Gear.SpecOf() end
    local spec = FojjiCore and FojjiCore.GetSpec and FojjiCore.GetSpec(unit)
    return spec and spec.key or nil
end

local function readGear(unit)
    local _, class = UnitClass(unit)
    local set = {}
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink(unit, slot)
        local id = link and not FDJ.Secret(link) and tonumber(link:match("item:(%d+)"))
        if id then set[slot] = id end
    end
    if not next(set) then return nil end
    return { set = set, class = class, spec = specOfUnit(unit, class) }
end

local function scoreGear(gear)
    local score, missing = Measure.GearScore(gear.set, Measure.StatValues(gear.class, gear.spec))
    return score, avgItemLevel(gear.set), missing
end

local function measure(unit)
    local gear = readGear(unit)
    if not gear then return nil end
    return scoreGear(gear)
end

local function addLine(tooltip, data)
    if not data or not data.score then return end
    local text = L.BIS_GS_LINE:format(FDJ.Paint("amber", tostring(data.score)))
    if data.ilvl then text = text .. FDJ.Paint("dim", "  ·  ") .. L.BIS_ILVL_LINE:format(data.ilvl) end
    tooltip:AddLine(text, 0.85, 0.87, 0.9)
end

local function unitToken(guid)
    for _, u in ipairs({ "mouseover", "target", "focus", "player" }) do
        if UnitExists(u) then
            local g = UnitGUID(u)
            if g and not FDJ.Secret(g) and g == guid then return u end
        end
    end
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, (IsInRaid() and 40 or 4) do
            local u = prefix .. i
            if UnitExists(u) then
            local g = UnitGUID(u)
            if g and not FDJ.Secret(g) and g == guid then return u end
        end
        end
    end
end

local function tooltipUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if unit == nil then return nil end
    if FDJ.Secret(unit) then
        return UnitExists("mouseover") and "mouseover" or nil
    end
    return unit
end

local function store(guid, gear, tries)
    local score, ilvl, missing = scoreGear(gear)
    if missing > 0 and (tries or 0) < 5 then
        C_Timer.After(0.6, function() store(guid, gear, (tries or 0) + 1) end)
        return
    end
    scores[guid] = { score = score, ilvl = ilvl, t = GetTime() }
    local tipUnit = tooltipUnit(GameTooltip)
    local tipGuid = tipUnit and UnitGUID(tipUnit)
    if tipGuid and not FDJ.Secret(tipGuid) and tipGuid == guid and GameTooltip:IsShown() then
        addLine(GameTooltip, scores[guid])
        GameTooltip:Show()
    end
end

local function canAsk(unit)
    if InCombatLockdown() then return false end
    if InspectFrame and InspectFrame:IsShown() then return false end
    if not (CanInspect and CanInspect(unit)) then return false end
    if CheckInteractDistance then
        local ok, near = pcall(CheckInteractDistance, unit, 1)
        if ok and not near then return false end
    end
    return GetTime() - lastAsk > 1.5
end

local function unitTooltip(tooltip)
    if tooltip ~= GameTooltip or not (Gear.Enabled() and Gear.Options().gearScore) then return end
    local unit = tooltipUnit(tooltip)
    if not unit or not UnitIsPlayer(unit) or not UnitIsFriend("player", unit) then return end
    local guid = UnitGUID(unit)
    if not guid or FDJ.Secret(guid) then return end
    if UnitIsUnit(unit, "player") then
        if not scores[guid] or scores[guid].stale then
            local score, ilvl = measure("player")
            scores[guid] = { score = score, ilvl = ilvl, t = GetTime() }
        end
    end
    local data = scores[guid]
    if data then addLine(tooltip, data) end
    if (not data or GetTime() - data.t > 300) and not UnitIsUnit(unit, "player") and canAsk(unit) then
        lastAsk = GetTime()
        inspecting = guid
        NotifyInspect(unit)
    end
end

local function onUnitTooltip(tooltip)
    pcall(unitTooltip, tooltip)
end

FDJ:On("PLAYER_EQUIPMENT_CHANGED", function()
    local me = UnitGUID("player")
    if me and scores[me] then scores[me].stale = true end
end)
FDJ:On("FDJ_GEAR_WEIGHTS", function()
    local me = UnitGUID("player")
    if me and scores[me] then scores[me].stale = true end
end)
FDJ:On("ZONE_CHANGED_NEW_AREA", function()
    local me = UnitGUID("player")
    for guid in pairs(scores) do if guid ~= me then scores[guid] = nil end end
end)

FDJ:On("INSPECT_READY", function(guid)
    if not guid or FDJ.Secret(guid) or guid ~= inspecting then return end
    inspecting = nil
    local unit = unitToken(guid)
    local gear = unit and readGear(unit)
    if gear then store(guid, gear) end
    if not (InspectFrame and InspectFrame:IsShown()) and ClearInspectPlayer then ClearInspectPlayer() end
end)

FDJ:On("PLAYER_LOGIN", function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnitTooltip)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", onUnitTooltip)
    end
end)
