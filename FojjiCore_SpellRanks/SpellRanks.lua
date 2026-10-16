local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB

local SpellRanks = {}
local coins

local function say(text) FDJ.PrintAs("FojjiCore", text) end
FDJ.SpellRanks = SpellRanks

local WIDTH = 286
local ROW = 30
local BOOK_FRAMES = { "SpellBookFrame" }
local BOOK_ADDONS = { Blizzard_PlayerSpells = true, Blizzard_SpellBook = true }
local GOLD = { 1.0, 0.82, 0.30 }

local panel, seg, kindSeg, stepper, levelText, scroll, empty, rows, hint, tab
local foot, costText, costLabel, trainerButton
local host
local hooked = {}
local mode = "next"
local kind = "class"
local viewLevel

local function saved()
    if not FDJ.char then return {} end
    FDJ.char.spellView = FDJ.char.spellView or { mode = "next", level = 60, picked = true }
    return FDJ.char.spellView
end

local function setLevel(level)
    viewLevel = math.max(1, math.min(level, 60))
    saved().level = viewLevel
    SpellRanks.Refresh()
end
local scanning = false

local function classKey()
    local _, class = UnitClass("player")
    return class or "UNKNOWN"
end

local function store()
    if not FDJ.db then return nil end
    FDJ.db.spells = FDJ.db.spells or {}
    if FDJ.db.spellsVersion ~= 2 then
        wipe(FDJ.db.spells)
        FDJ.db.spellsScanned = {}
        FDJ.db.spellsVersion = 2
    end
    local key = classKey()
    FDJ.db.spells[key] = FDJ.db.spells[key] or {}
    return FDJ.db.spells[key]
end

local function rankOf(sub)
    if type(sub) ~= "string" then return nil end
    return tonumber(sub:match("(%d+)"))
end

local function keyOf(name, sub)
    if rankOf(sub) or not sub or sub == "" then return name end
    return name .. "|" .. sub
end

function SpellRanks.Off()
    return FDJ.opt and FDJ.opt.spellsOff == true
end

function SpellRanks.Enabled()
    if FDJ.off or SpellRanks.Off() then return false end
    local value = FDJ.opt and FDJ.opt.spellRanks
    return value == nil or value == true
end

local function eachKnown(fn)
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for t = 2, C_SpellBook.GetNumSpellBookSkillLines() do
            local line = C_SpellBook.GetSpellBookSkillLineInfo(t)
            if line and not line.offSpecID and not line.shouldHide then
                local first = (line.itemIndexOffset or 0) + 1
                for i = first, first + (line.numSpellBookItems or 0) - 1 do
                    local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
                    if item and item.name and not item.isPassive and not item.isOffSpec then
                        fn(item.name, item.subName, item.iconID, item.spellID or item.actionID)
                    end
                end
            end
        end
        local pet = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
        local count = pet and C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells()
        for i = 1, tonumber(count) or 0 do
            local item = C_SpellBook.GetSpellBookItemInfo(i, pet)
            if item and item.name then
                fn(item.name, item.subName, item.iconID, item.spellID or item.actionID, true)
            end
        end
        return
    end
    if HasPetSpells and GetSpellBookItemName then
        local book = BOOKTYPE_PET or "pet"
        for i = 1, tonumber((HasPetSpells())) or 0 do
            local name, sub = GetSpellBookItemName(i, book)
            if name then fn(name, sub, GetSpellBookItemTexture and GetSpellBookItemTexture(i, book), nil, true) end
        end
    end
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        local book = BOOKTYPE_SPELL or "spell"
        for t = 2, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(t)
            for i = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local name, sub = GetSpellBookItemName(i, book)
                local passive = IsPassiveSpell and IsPassiveSpell(i, book)
                if name and not passive then
                    fn(name, sub, GetSpellBookItemTexture and GetSpellBookItemTexture(i, book), nil)
                end
            end
        end
    end
end

local gen = 0
local function bump() gen = gen + 1 end
SpellRanks.Bump = bump
local knownCache, knownGen

local function knownRanks()
    if knownCache and knownGen == gen then return knownCache end
    local known = {}
    local petRanks = FDJ.char and FDJ.char.petRanks
    if FDJ.char and not petRanks then
        petRanks = {}
        FDJ.char.petRanks = petRanks
    end
    eachKnown(function(name, sub, icon, id, isPet)
        local key = keyOf(name, sub)
        local rank = rankOf(sub) or 1
        if isPet and petRanks and rank > (petRanks[key] or 0) then petRanks[key] = rank end
        local entry = known[key]
        if not entry then
            entry = { name = name, sub = (rankOf(sub) and nil) or sub, icon = icon, rank = 0, ids = {} }
            known[key] = entry
        end
        if id then entry.ids[rank] = id end
        if rank > entry.rank then entry.rank = rank end
        entry.icon = entry.icon or icon
    end)
    for key, rank in pairs(petRanks or {}) do
        local entry = known[key]
        if not entry then
            entry = { name = key, rank = 0, ids = {} }
            known[key] = entry
        end
        entry.pet = true
        if rank > entry.rank then entry.rank = rank end
    end
    knownCache, knownGen = known, gen
    return known
end

local CATEGORY = { available = true, unavailable = true, used = true, header = true }
local probe

local function serviceID(i)
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
        local ok, data = pcall(C_TooltipInfo.GetTrainerService, i)
        if ok and type(data) == "table" and type(data.id) == "number" then return data.id end
    end
    if not probe then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "FojjiCoreSpellProbe", nil, "GameTooltipTemplate")
        probe = ok and tip or false
    end
    if probe and probe.SetTrainerService and probe.GetSpell then
        probe:SetOwner(WorldFrame, "ANCHOR_NONE")
        local ok = pcall(probe.SetTrainerService, probe, i)
        local id = ok and select(2, probe:GetSpell())
        probe:Hide()
        if type(id) == "number" then return id end
    end
end

local built = {}

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local PROF_IDS = { 7620, 7731, 7732, 18248, 2550, 3102, 3413, 18260, 3273, 3274, 7924, 10846, 2575, 2576, 3564,
    10248, 2580, 2366, 2368, 3570, 11993, 2383, 8613, 8617, 8618, 10768, 2656, 2259, 3101, 3464, 11611, 2018,
    3100, 3538, 9785, 7411, 7412, 7413, 13920, 13262, 4036, 4037, 4038, 12656, 2108, 3104, 3811, 10662, 3908,
    3909, 3910, 12180, 818 }
local profNames
local function isProfession(name, id)
    if not profNames then
        profNames = {}
        for _, pid in ipairs(PROF_IDS) do local n = spellName(pid) if n then profNames[n] = true end end
    end
    if name and profNames[name] then return true end
    if id and C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.GetSpellBookItemInfo then
        local ok, slot, bank = pcall(C_SpellBook.FindSpellBookSlotForSpell, id)
        local info = ok and slot and C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if type(info) == "table" and info.skillLineIndex == 1 then return true end
    end
    return false
end

local function spellSub(id)
    if C_Spell and C_Spell.GetSpellSubtext then return C_Spell.GetSpellSubtext(id) end
    if GetSpellSubtext then return GetSpellSubtext(id) end
end

local function spellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
end

local function allowed(row, faction, race)
    if row[4] and row[4] ~= faction then return false end
    if row[6] then
        for id in tostring(row[6]):gmatch("%d+") do
            if tonumber(id) == race then return true end
        end
        return false
    end
    return true
end

local function baseline()
    local class = classKey()
    if built[class] then return built[class] end
    local rows = FDJ.SpellBase and FDJ.SpellBase[class]
    if not rows then return nil end
    local faction = (FDJ.Faction() or ""):sub(1, 1)
    local race = UnitRace and select(3, UnitRace("player"))
    local groups, complete = {}, true
    for _, row in ipairs(rows) do
        if allowed(row, faction, race) then
            local name = spellName(row[1])
            if name then
                local sub = spellSub(row[1])
                local key = keyOf(name, sub)
                local g = groups[key]
                if not g then
                    g = { name = name, list = {} }
                    if sub and sub ~= "" and not rankOf(sub) then g.sub = sub end
                    groups[key] = g
                end
                g.list[#g.list + 1] = { id = row[1], lv = row[2], cost = row[3], rank = rankOf(sub), talent = row[5] ~= nil }
            else
                complete = false
            end
        end
    end
    local out = {}
    for key, g in pairs(groups) do
        table.sort(g.list, function(a, b)
            if a.lv ~= b.lv then return a.lv < b.lv end
            return a.id < b.id
        end)
        local offset = g.list[1].talent and 1 or 0
        local entry = { name = g.name, sub = g.sub, ranks = {}, talent = g.list[1].talent or nil }
        for n, s in ipairs(g.list) do
            local rank = s.rank or (n + offset)
            entry.ranks[rank] = { lv = s.lv, cost = s.cost, id = s.id }
            entry.icon = entry.icon or spellIcon(s.id)
            if FDJ.PetSpellIDs and FDJ.PetSpellIDs[s.id] then entry.pet = true end
        end
        out[key] = entry
    end
    if complete then built[class] = out end
    return out
end

local function isPetEntry(entry, base)
    if entry.pet or (base and base.pet) then return true end
    for _, info in pairs(entry.ranks or {}) do
        if info.id and FDJ.PetSpellIDs and FDJ.PetSpellIDs[info.id] then return true end
    end
    return false
end

local function merged()
    local data = store() or {}
    local base = baseline() or {}
    local out = {}
    for key, entry in pairs(base) do out[key] = entry end
    for key, entry in pairs(data) do
        entry.pet = isPetEntry(entry, base[key]) or nil
        out[key] = entry
    end
    return out
end

local rememberTrainer

local function scanTrainer()
    if scanning or not GetNumTrainerServices or not GetTrainerServiceInfo then return end
    if IsTradeskillTrainer and IsTradeskillTrainer() then return end
    local data = store()
    if not data then return end
    scanning = true
    local saved = {}
    local canFilter = GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter
    if canFilter then
        for _, kind in ipairs({ "available", "unavailable", "used" }) do
            saved[kind] = GetTrainerServiceTypeFilter(kind)
            if not saved[kind] then pcall(SetTrainerServiceTypeFilter, kind, 1) end
        end
    end
    local services = {}
    for i = 1, GetNumTrainerServices() do
        local info = { GetTrainerServiceInfo(i) }
        local name, kind, text = info[1], nil, nil
        for j = 2, #info do
            local v = info[j]
            if type(v) == "string" then
                if CATEGORY[v] then kind = kind or v elseif v ~= "" then text = text or v end
            end
        end
        if type(name) == "string" and kind ~= "header" then
            services[#services + 1] = {
                name = name, sub = text, kind = kind, level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0,
                icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i), cost = GetTrainerServiceCost and GetTrainerServiceCost(i),
                id = serviceID(i),
            }
        end
    end
    local known = {}
    eachKnown(function(name) known[name] = true end)
    local overlap = 0
    for _, svc in ipairs(services) do
        if known[svc.name] or data[keyOf(svc.name, svc.sub)] then overlap = overlap + 1 end
    end
    local found = 0
    if overlap > 0 then
        local groups, order = {}, {}
        for _, svc in ipairs(services) do
            local key = keyOf(svc.name, svc.sub)
            if not groups[key] then
                groups[key] = {}
                order[#order + 1] = key
            end
            table.insert(groups[key], svc)
        end
        local used = {}
        for _, key in ipairs(order) do
            local list = groups[key]
            local explicit = true
            for _, svc in ipairs(list) do if not rankOf(svc.sub) then explicit = false end end
            if not explicit then
                table.sort(list, function(a, b) return (a.level or 0) < (b.level or 0) end)
            end
            local entry = { name = list[1].name, ranks = {} }
            entry.sub = (not rankOf(list[1].sub) and list[1].sub ~= "" and list[1].sub) or nil
            for n, svc in ipairs(list) do
                local rank = explicit and rankOf(svc.sub) or n
                entry.ranks[rank] = { lv = svc.level or 0, cost = svc.cost, id = svc.id }
                entry.icon = entry.icon or svc.icon
                if svc.kind == "used" and rank > (used[key] or 0) then used[key] = rank end
                found = found + 1
            end
            data[key] = entry
        end
        local previous = FDJ.char.spellsUsed or {}
        for key, rank in pairs(used) do
            if rank > (previous[key] or 0) then previous[key] = rank end
        end
        FDJ.char.spellsUsed = previous
        local base, pets = baseline() or {}, 0
        for _, svc in ipairs(services) do
            local b = base[keyOf(svc.name, svc.sub)]
            if (svc.id and FDJ.PetSpellIDs and FDJ.PetSpellIDs[svc.id]) or (b and b.pet) then pets = pets + 1 end
        end
        rememberTrainer(pets * 2 > #services)
    end
    if canFilter then
        for kind, value in pairs(saved) do
            if not value then pcall(SetTrainerServiceTypeFilter, kind, 0) end
        end
    end
    scanning = false
    if found > 0 then
        FDJ.db.spellsScanned = FDJ.db.spellsScanned or {}
        FDJ.db.spellsScanned[classKey()] = time()
        SpellRanks.Refresh()
    end
end

local function isKnownID(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and (IsSpellKnown(id) or IsSpellKnown(id, true)) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known then return true end
    end
    return false
end

local PASSIVE = SPELL_PASSIVE or "Passive"
local passiveCache = setmetatable({}, { __mode = "k" })
local function isPassive(entry)
    local hit = passiveCache[entry]
    if hit ~= nil then return hit end
    local result = false
    if entry.sub and (entry.sub == PASSIVE or entry.sub == "Passive") then result = true end
    if not result then
        for _, info in pairs(entry.ranks or {}) do
            if info.id then
                local ok, passive
                if C_Spell and C_Spell.IsSpellPassive then
                    ok, passive = pcall(C_Spell.IsSpellPassive, info.id)
                elseif IsPassiveSpell then
                    ok, passive = pcall(IsPassiveSpell, info.id)
                end
                if ok and passive then result = true break end
            end
        end
    end
    passiveCache[entry] = result
    return result
end

local function haveRank(key, entry, known)
    local have = known[key] and known[key].rank or 0
    local learned = FDJ.char and FDJ.char.spellsUsed and FDJ.char.spellsUsed[key]
    if learned and learned > have then have = learned end
    for rank, info in pairs(entry.ranks or {}) do
        if rank > have and info.id and isKnownID(info.id) then have = rank end
    end
    return have
end

local function wanted(isPet)
    if kind == "pet" then return isPet end
    if kind == "class" then return not isPet end
    return true
end

local function collect(level)
    local data = merged()
    local known = knownRanks()
    local list = {}
    local seen = {}
    local playerLevel = FDJ.Level()
    local sums = { now = 0, upto = 0, nowCount = 0, uptoCount = 0, pets = false }
    for key, entry in pairs(data) do
        seen[key] = true
        local isPet = entry.pet or (known[key] and known[key].pet) or false
        if isPet then sums.pets = true end
        if wanted(isPet) and not (entry.talent and not known[key]) and (isPet or not isPassive(entry)) then
            local have = haveRank(key, entry, known)
            for rank, info in pairs(entry.ranks or {}) do
                if rank > have then
                    local lv, cost = info.lv or 0, info.cost or 0
                    if lv <= playerLevel then
                        sums.now = sums.now + cost
                        sums.nowCount = sums.nowCount + 1
                    end
                    if lv <= level then
                        sums.upto = sums.upto + cost
                        sums.uptoCount = sums.uptoCount + 1
                    end
                end
            end
            local pick, pickLevel
            if mode == "next" then
                for rank, info in pairs(entry.ranks or {}) do
                    if rank > have and (not pick or rank < pick) then pick, pickLevel = rank, info.lv end
                end
            else
                for rank, info in pairs(entry.ranks or {}) do
                    if (info.lv or 0) <= level and (not pick or rank > pick) then pick, pickLevel = rank, info.lv end
                end
            end
            if pick then
                local maxRank = 0
                for rank in pairs(entry.ranks) do if rank > maxRank then maxRank = rank end end
                local state
                if have >= pick then
                    state = "known"
                elseif (pickLevel or 0) <= playerLevel then
                    state = "train"
                else
                    state = "later"
                end
                local ids = known[key] and known[key].ids or {}
                list[#list + 1] = {
                    name = entry.name, sub = entry.sub, icon = entry.icon or (known[key] and known[key].icon),
                    rank = pick, maxRank = maxRank, lv = pickLevel or 0, state = state,
                    cost = entry.ranks[pick] and entry.ranks[pick].cost,
                    id = (entry.ranks[pick] and entry.ranks[pick].id) or ids[pick],
                    ranks = entry.ranks, ids = ids, have = have, pet = isPet,
                }
            end
        end
    end
    if mode ~= "next" then
        for key, entry in pairs(known) do
            if not seen[key] and wanted(entry.pet or false) then
                list[#list + 1] = { name = entry.name, sub = entry.sub, icon = entry.icon, rank = entry.rank, lv = nil, state = "known", id = entry.ids[entry.rank], ids = entry.ids, have = entry.rank }
            end
        end
    end
    local order = { train = 1, later = 2, known = 3 }
    table.sort(list, function(a, b)
        if mode == "next" and a.state ~= b.state then return order[a.state] < order[b.state] end
        local la, lb = a.lv or 999, b.lv or 999
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return list, next(data) ~= nil, sums
end

function SpellRanks.NewAt(level)
    local data = merged()
    local known = knownRanks()
    local out, cost = {}, 0
    for key, entry in pairs(data) do
        local isPet = entry.pet or (known[key] and known[key].pet) or false
        if not (entry.talent and not known[key]) and (isPet or not isPassive(entry)) then
            local have = haveRank(key, entry, known)
            for rank, info in pairs(entry.ranks or {}) do
                if rank > have and info.lv == level then
                    out[#out + 1] = { name = entry.name, rank = rank, id = info.id, icon = entry.icon or (info.id and spellIcon(info.id)), pet = isPet }
                    cost = cost + (info.cost or 0)
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.pet ~= b.pet then return not a.pet end
        return a.name < b.name
    end)
    return out, cost
end

local function hiddenSlot(slot)
    return slot <= 12 and classKey() == "WARRIOR" and GetBonusBarOffset and (GetBonusBarOffset() or 0) > 0
end
SpellRanks.HiddenSlot = hiddenSlot

local AUTO_RANK = 1000
local macroCache = {}
local function macroSpells(macroID)
    local body = GetMacroBody and GetMacroBody(macroID)
    if type(body) ~= "string" or (issecretvalue and issecretvalue(body)) then return nil end
    local hit = macroCache[body]
    if hit then return hit end
    hit = {}
    for line in body:gmatch("[^\r\n]+") do
        local cmd, rest = line:match("^%s*/(%a+)%s+(.+)$")
        cmd = cmd and cmd:lower()
        if cmd == "cast" or cmd == "use" or cmd == "castsequence" or cmd == "castrandom" then
            rest = rest:gsub("%b[]", ""):gsub("reset=%S+", "")
            for part in rest:gmatch("[^;,]+") do
                local name = part:gsub("^%s*!?", ""):gsub("%s+$", "")
                local rank = name:match("%(%s*[Rr]ank%s*(%d+)%s*%)")
                name = name:gsub("%s*%(.-%)%s*$", "")
                if name ~= "" and not tonumber(name) then
                    local proper
                    if C_Spell and C_Spell.GetSpellInfo then
                        local info = C_Spell.GetSpellInfo(name)
                        proper = info and info.name
                    elseif GetSpellInfo then
                        proper = GetSpellInfo(name)
                    end
                    if proper and not (issecretvalue and issecretvalue(proper)) then name = proper end
                    hit[#hit + 1] = { name = name, rank = tonumber(rank) or AUTO_RANK }
                end
            end
        end
    end
    if #hit == 0 and GetMacroSpell then
        local id = GetMacroSpell(macroID)
        if type(id) == "number" and not (issecretvalue and issecretvalue(id)) then
            local name = spellName(id)
            if name then hit[1] = { name = name, rank = rankOf(spellSub(id)) or AUTO_RANK } end
        end
    end
    macroCache[body] = hit
    return hit
end

local function rankFromID(id, key, known, data)
    local k = known[key]
    if k then
        for r, rid in pairs(k.ids) do if rid == id then return r end end
    end
    local e = data[key]
    if e then
        for r, info in pairs(e.ranks or {}) do if info.id == id then return r end end
        local n = 0
        for _ in pairs(e.ranks or {}) do n = n + 1 end
        if n > 1 then return nil end
    end
    return 1
end

function SpellRanks.Outdated()
    if not GetActionInfo then return {}, {} end
    local data = merged()
    local known = knownRanks()
    local onBars = {}
    local byName
    local function keyFor(name)
        if data[name] or known[name] then return name end
        if not byName then
            byName = {}
            for key, entry in pairs(data) do byName[(entry.name or key):lower()] = byName[(entry.name or key):lower()] or key end
            for key in pairs(known) do local base = (key:match("^([^|]+)")) or key; byName[base:lower()] = byName[base:lower()] or key end
        end
        return byName[name:lower()] or name
    end
    for slot = 1, 180 do
        local what, id, sub
        if not hiddenSlot(slot) then what, id, sub = GetActionInfo(slot) end
        local macroIndex
        if what == "macro" then
            local text = GetActionText and GetActionText(slot)
            macroIndex = type(text) == "string" and not (issecretvalue and issecretvalue(text)) and GetMacroIndexByName and GetMacroIndexByName(text)
            if not macroIndex or macroIndex == 0 then macroIndex = sub ~= "spell" and id or nil end
            if sub == "spell" and type(id) == "number" then
                local name = spellName(id)
                if name then
                    local b = onBars[keyOf(name, spellSub(id))]
                    if not b then onBars[keyOf(name, spellSub(id))] = { rank = AUTO_RANK, slot = slot, macro = true } end
                end
            end
        end
        if what == "spell" and type(id) == "number" then
            local name = spellName(id)
            if name then
                local sub = spellSub(id)
                local key = keyOf(name, sub)
                local rank = rankOf(sub) or rankFromID(id, key, known, data)
                if rank then
                    local b = onBars[key]
                    if not b then
                        b = { rank = 0, slot = slot }
                        onBars[key] = b
                    end
                    if rank > b.rank then b.rank, b.slot = rank, slot end
                end
            end
        elseif macroIndex then
            for _, m in ipairs(macroSpells(macroIndex) or {}) do
                local key = keyFor(m.name)
                local b = onBars[key]
                if not b then
                    b = { rank = 0, slot = slot, macro = true }
                    onBars[key] = b
                end
                if m.rank > b.rank then b.rank, b.slot = m.rank, slot end
            end
        end
    end
    if not next(onBars) then return {}, onBars, data, known end
    local out = {}
    for key, bar in pairs(onBars) do
        local entry = data[key]
        if entry and not entry.pet and not (known[key] and known[key].pet) then
            local have = haveRank(key, entry, known)
            if have > bar.rank and have > 1 then
                local ids = known[key] and known[key].ids or {}
                local id = ids[have] or (entry.ranks[have] and entry.ranks[have].id)
                out[#out + 1] = { name = entry.name, onBar = bar.rank, have = have, id = id, icon = entry.icon or (id and spellIcon(id)) }
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out, onBars, data, known
end

local function freshList()
    return FDJ.char and FDJ.char.freshSpells
end

function SpellRanks.NoteLearned(id)
    bump()
    id = tonumber(id)
    if not id or not FDJ.char then return end
    local name = spellName(id)
    if not name then return end
    local passive = C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id)
    if passive or (FDJ.PetSpellIDs and FDJ.PetSpellIDs[id]) or isProfession(name, id) then return end
    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
        local slot, bank = C_SpellBook.FindSpellBookSlotForSpell(id)
        local player = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        if not slot or (player and bank and bank ~= player) then return end
    end
    FDJ.char.freshSpells = FDJ.char.freshSpells or {}
    FDJ.char.freshSpells[name] = id
end

function SpellRanks.Ignore(name, id, quiet)
    bump()
    if not (FDJ.char and name) then return end
    FDJ.char.barsIgnore = FDJ.char.barsIgnore or {}
    FDJ.char.barsIgnore[name] = id or true
    if not quiet then say(L.SPELL_IGNORED:format(FDJ.Hi(name))) end
    FDJ:Emit("FDJ_OPTION", "barsIgnore")
    if SpellRanks.SyncBars then pcall(SpellRanks.SyncBars) end
end

function SpellRanks.Unignore(name)
    bump()
    if not (FDJ.char and FDJ.char.barsIgnore and name) then return end
    FDJ.char.barsIgnore[name] = nil
    FDJ:Emit("FDJ_OPTION", "barsIgnore")
    if SpellRanks.SyncBars then pcall(SpellRanks.SyncBars) end
end

function SpellRanks.ClassSpells()
    local data, known = merged(), knownRanks()
    local ignore = FDJ.char and FDJ.char.barsIgnore or {}
    local byName, out = {}, {}
    for key, entry in pairs(data) do
        local isPet = entry.pet or (known[key] and known[key].pet)
        if entry.name and not isPet and not isPassive(entry) then
            local item = byName[entry.name]
            if not item then
                local first = entry.ranks and entry.ranks[1]
                item = { name = entry.name, icon = entry.icon or (first and first.id and spellIcon(first.id)) }
                byName[entry.name] = item
                out[#out + 1] = item
            end
            if haveRank(key, entry, known) > 0 then item.known = true end
        end
    end
    for name, id in pairs(ignore) do
        if not byName[name] then
            out[#out + 1] = { name = name, icon = type(id) == "number" and spellIcon(id) or nil, known = true }
        end
    end
    for _, item in ipairs(out) do item.ignored = ignore[item.name] and true or false end
    table.sort(out, function(a, b)
        if a.known ~= b.known then return a.known end
        return a.name < b.name
    end)
    return out
end

function SpellRanks.IgnoredList()
    local out = {}
    for name, id in pairs(FDJ.char and FDJ.char.barsIgnore or {}) do
        out[#out + 1] = { name = name, icon = type(id) == "number" and spellIcon(id) or nil }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function SpellRanks.Missing()
    local out, onBars, data, known = SpellRanks.Outdated()
    onBars = onBars or {}
    data = data or merged()
    known = known or knownRanks()
    local barred = {}
    for key in pairs(onBars) do barred[(key:match("^([^|]+)")) or key] = true end
    local ignore = FDJ.char and FDJ.char.barsIgnore or {}
    for i = #out, 1, -1 do
        if ignore[out[i].name] then table.remove(out, i) end
    end
    local seen = {}
    for _, item in ipairs(out) do seen[item.name] = true end
    local function add(name, id, rank, icon)
        if seen[name] or barred[name] or ignore[name] then return end
        seen[name] = true
        out[#out + 1] = { name = name, onBar = 0, have = rank or 1, id = id, icon = icon or (id and spellIcon(id)), fresh = true }
    end
    for key, entry in pairs(data) do
        local isPet = entry.pet or (known[key] and known[key].pet)
        if not isPet and not isPassive(entry) then
            local have = haveRank(key, entry, known)
            if have > 0 then
                local ids = known[key] and known[key].ids or {}
                local id = ids[have] or (entry.ranks[have] and entry.ranks[have].id)
                add(entry.name, id, have, entry.icon)
            end
        end
    end
    local fresh = freshList()
    if fresh then
        for name, id in pairs(fresh) do
            if barred[name] then fresh[name] = nil else add(name, id, rankOf(spellSub(id)) or 1) end
        end
    end
    for i = #out, 1, -1 do
        if isProfession(out[i].name, out[i].id) then table.remove(out, i) end
    end
    table.sort(out, function(a, b)
        if (a.fresh or false) ~= (b.fresh or false) then return not a.fresh end
        return a.name < b.name
    end)
    return out
end

local NEW_SPELLS = { "Frost Blast", "Salvation", "Mass Salvation", "Revoke", "Mana Tide Totem", "Seal of Fury", "Shred" }
function SpellRanks.FindSpells(text)
    local want, order = {}, {}
    local names = {}
    for n in ((text and text ~= "") and text or table.concat(NEW_SPELLS, ",")):gmatch("[^,]+") do
        n = n:gsub("^%s+", ""):gsub("%s+$", "")
        if n ~= "" then want[n:lower()] = n names[#names + 1] = n end
    end
    say(("Looking for %s ..."):format(table.concat(names, ", ")))
    local found, id, LAST, STEP = {}, 1, 2000000, 40000
    local ticker
    ticker = C_Timer.NewTicker(0.01, function()
        local stop = math.min(LAST, id + STEP)
        for i = id, stop do
            local n = spellName(i)
            if n and want[n:lower()] then
                found[#found + 1] = i
                if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, i) end
            end
        end
        id = stop + 1
        if id > LAST then
            ticker:Cancel()
            C_Timer.After(3, function()
                local lines = {}
                for _, i in ipairs(found) do
                    local sub = spellSub(i) or ""
                    local lvl = GetSpellLevelLearned and GetSpellLevelLearned(i)
                    local desc = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(i) or ""
                    lines[#lines + 1] = ("%d  %s  [%s]  %s  %s"):format(i, spellName(i) or "?", sub, (lvl and lvl > 0) and ("level " .. lvl) or "", desc:gsub("\n", " "):sub(1, 70))
                end
                local text = #lines > 0 and table.concat(lines, "\n") or "nothing found"
                if FDJ.Kit and FDJ.Kit.TextWindow then FDJ.Kit.TextWindow("Spell ids", text) else say(text) end
            end)
        end
    end)
end

function SpellRanks.Explain(query)
    query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local data, known = merged(), knownRanks()
    local _, onBars = SpellRanks.Outdated()
    local hit = false
    for key, entry in pairs(data) do
        if entry.name and entry.name:lower() == query then
            hit = true
            local have = haveRank(key, entry, known)
            local barred = false
            for k, b in pairs(onBars or {}) do
                if ((k:match("^([^|]+)")) or k) == entry.name then barred = "slot " .. tostring(b.slot) end
            end
            local hiddenAt = {}
            for slot = 1, 12 do
                local what, id = GetActionInfo(slot)
                if what == "spell" and spellName(id) == entry.name and hiddenSlot(slot) then hiddenAt[#hiddenAt + 1] = slot end
            end
            if #hiddenAt > 0 then say(("%s sits in hidden no-stance slot %s (ignored)"):format(entry.name, table.concat(hiddenAt, ", "))) end
            say(("%s: key '%s', you have rank %d, spellbook %s, passive %s, pet %s, on bars %s, closed with X %s"):format(entry.name, key, have,
                known[key] and ("rank " .. known[key].rank) or "no", tostring(isPassive(entry)), tostring(entry.pet or false), tostring(barred),
                tostring(FDJ.char and FDJ.char.barsIgnore and FDJ.char.barsIgnore[entry.name] or false)))
        end
    end
    for key, k in pairs(known) do
        if k.name and k.name:lower() == query and not data[key] then
            hit = true
            say(("%s: in your spellbook (key '%s', rank %d) but not in the trainer list"):format(k.name, key, k.rank))
        end
    end
    if not hit then say(("'%s' isn't in the trainer list or your spellbook (check the spelling)."):format(query)) end
    local list = SpellRanks.Missing()
    local names = {}
    for _, item in ipairs(list) do names[#names + 1] = item.name end
    say(("Card would show %d: %s"):format(#list, table.concat(names, ", ")))
end

local MICRO = {
    book = { "SpellbookMicroButton", "PlayerSpellsMicroButton" },
    talents = { "TalentMicroButton", "PlayerSpellsMicroButton" },
}
local function microButton(kind)
    for _, name in ipairs(MICRO[kind] or {}) do
        local b = _G[name]
        if b and b.Click then return b end
    end
end

local opener
local function getOpener()
    if opener ~= nil then return opener or nil end
    local ok, b = pcall(CreateFrame, "Button", "FojjiCoreSpellsOpener", UIParent, "SecureActionButtonTemplate")
    if not ok or not b then opener = false return nil end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("type1", "click")
    b:Hide()
    function b:Detach()
        if InCombatLockdown() then return end
        self.dragging = nil
        self.visual = nil
        self:Hide()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -200, -200)
    end
    local function call(v, script, ...)
        local fn = v and v.openerScripts and v.openerScripts[script]
        if fn then fn(v, ...) end
    end
    b:SetScript("OnEnter", function(self) call(self.visual, "OnEnter") end)
    b:SetScript("OnLeave", function(self)
        if self.dragging then return end
        local v = self.visual
        self:Detach()
        call(v, "OnLeave")
    end)
    b:HookScript("OnClick", function(self, button)
        local v = self.visual
        if v and v.openerClick then v.openerClick(v, button) end
    end)
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        call(self.visual, "OnDragStart")
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = nil
        call(self.visual, "OnDragStop")
    end)
    FDJ:On("PLAYER_REGEN_DISABLED", function() b:Detach() end)
    opener = b
    return b
end

function SpellRanks.SecureOpen(visual, kind, onClick)
    visual.openerScripts = {
        OnEnter = visual:GetScript("OnEnter"),
        OnLeave = visual:GetScript("OnLeave"),
        OnDragStart = visual:GetScript("OnDragStart"),
        OnDragStop = visual:GetScript("OnDragStop"),
    }
    visual.openerClick = onClick
    visual:HookScript("OnEnter", function(self)
        if InCombatLockdown() or not self:IsVisible() then return end
        local micro = microButton(kind)
        local b = micro and getOpener()
        if not b then return end
        b.visual = self
        b:SetAttribute("clickbutton", micro)
        b:ClearAllPoints()
        b:SetAllPoints(self)
        b:SetFrameStrata(self:GetFrameStrata())
        b:SetFrameLevel(self:GetFrameLevel() + 5)
        b:Show()
    end)
    visual:HookScript("OnHide", function(self)
        local b = opener
        if b and b.visual == self then b:Detach() end
    end)
end

function SpellRanks.HasOpener(kind)
    return microButton(kind) ~= nil
end

local function playerSpot()
    local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return nil end
    local x, y = FDJ.XY(pos)
    if x and y then return m, x, y end
end

rememberTrainer = function(isPet)
    if not FDJ.db then return end
    local m, x, y = playerSpot()
    if not m then return end
    FDJ.db.trainers = FDJ.db.trainers or {}
    local list = FDJ.db.trainers[classKey()] or {}
    FDJ.db.trainers[classKey()] = list
    local pet = isPet and true or nil
    for _, t in ipairs(list) do
        if t.m == m and t.pet == pet and math.abs(t.x - x) < 0.03 and math.abs(t.y - y) < 0.03 then
            t.x, t.y = x, y
            return
        end
    end
    list[#list + 1] = { m = m, x = x, y = y, pet = pet, f = (FDJ.Faction() or ""):sub(1, 1) }
end

local function trainerSpots(pet)
    local out = {}
    local faction = (FDJ.Faction() or ""):sub(1, 1)
    local built = FDJ.ClassTrainers and FDJ.ClassTrainers[classKey()] or {}
    if pet then built = FDJ.ClassTrainers and FDJ.ClassTrainers.PET or {} end
    for _, t in ipairs(built) do
        if (not t[4] or t[4] == faction) then
            out[#out + 1] = { m = t[1], x = t[2] / 100, y = t[3] / 100 }
        end
    end
    local learned = FDJ.db and FDJ.db.trainers and FDJ.db.trainers[classKey()]
    for _, t in ipairs(learned or {}) do
        if (t.pet == true) == pet and (not t.f or t.f == faction) then out[#out + 1] = t end
    end
    return out
end

local function worldPos(m, x, y)
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if not ok or not continent or not pos then return nil end
    local wx, wy = FDJ.XY(pos)
    return continent, wx, wy
end

function SpellRanks.NearestTrainer(pet)
    local spots = trainerSpots(pet and true or false)
    if #spots == 0 and pet then spots = trainerSpots(false) end
    if #spots == 0 then return nil end
    local m, x, y = playerSpot()
    local pc, px, py
    if m then pc, px, py = worldPos(m, x, y) end
    local best, bestD
    for _, spot in ipairs(spots) do
        local c, wx, wy = worldPos(spot.m, spot.x, spot.y)
        local d = (pc and c == pc and wx) and math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2) or math.huge
        if not bestD or d < bestD then best, bestD = spot, d end
    end
    return best, bestD ~= math.huge and bestD or nil
end

local trainerPin

function SpellRanks.TrainerPinned()
    if not (trainerPin and FDJ.Pins and FDJ.Pins.Native) then return false end
    local m, x, y = FDJ.Pins.Native()
    return m == trainerPin.m and x and math.abs(x - trainerPin.x) < 0.002 and math.abs(y - trainerPin.y) < 0.002 or false
end

function SpellRanks.ClearTrainer()
    if SpellRanks.TrainerPinned() and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
    trainerPin = nil
    if FDJ.Pins then FDJ.Pins.active = nil end
    FDJ:Emit("FDJ_PINS")
end

function SpellRanks.ToggleTrainer(pet)
    if SpellRanks.TrainerPinned() then
        SpellRanks.ClearTrainer()
    else
        SpellRanks.GoToTrainer(pet)
    end
end

function SpellRanks.GoToTrainer(pet)
    local spot = SpellRanks.NearestTrainer(pet)
    if not spot then
        say(L.SPELL_TRAINER_NONE)
        return
    end
    if FDJ.Pins and FDJ.Pins.WaypointAt and FDJ.Pins.WaypointAt(spot.m, spot.x, spot.y, pet and L.SPELL_PET_TRAINER or L.SPELL_TRAINER) then
        trainerPin = { m = spot.m, x = spot.x, y = spot.y }
        FDJ:Emit("FDJ_PINS")
    end
end

local function masterName(wm) return Addon.Tr and Addon.Tr(wm[2]) or wm[2] end

local CLASS_BITS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local bitand = (bit and bit.band) or function(a, b)
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
    end
    return r
end

local function knowsSpell(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function distanceTo(m, x, y)
    local pm, px, py = playerSpot()
    if not pm then return nil end
    local pc, wx, wy = worldPos(pm, px, py)
    local c, tx, ty = worldPos(m, x, y)
    if not (pc and c and pc == c and wx and tx) then return nil end
    return math.sqrt((tx - wx) ^ 2 + (ty - wy) ^ 2)
end

function SpellRanks.WeaponMaster(id)
    local faction = (FDJ.Faction() or ""):sub(1, 1)
    local best, bestD
    for _, wm in ipairs(FDJ.WeaponMasters or {}) do
        if wm[6] == faction then
            for _, sid in ipairs(wm[7]) do
                if sid == id then
                    local d = distanceTo(wm[3], wm[4] / 100, wm[5] / 100) or math.huge
                    if not best or d < bestD then best, bestD = wm, d end
                end
            end
        end
    end
    return best, bestD ~= math.huge and bestD or nil
end

function SpellRanks.Weapons()
    local bitv = CLASS_BITS[classKey()] or 0
    local out = {}
    for _, w in ipairs(FDJ.WeaponSkills or {}) do
        local id, mask = w[1], w[2]
        if bitand(mask, bitv) ~= 0 then
            local name = spellName(id)
            if name then
                local wm, yards = SpellRanks.WeaponMaster(id)
                out[#out + 1] = { id = id, name = name, icon = spellIcon(id), known = knowsSpell(id), master = wm, yards = yards }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.known ~= b.known then return not a.known end
        return a.name < b.name
    end)
    return out
end

local weaponPin

function SpellRanks.WeaponPinned(id)
    if not (weaponPin and weaponPin.id == id and FDJ.Pins and FDJ.Pins.Native) then return false end
    local m, x, y = FDJ.Pins.Native()
    return m == weaponPin.m and x and math.abs(x - weaponPin.x) < 0.002 and math.abs(y - weaponPin.y) < 0.002 or false
end

function SpellRanks.ToggleWeapon(id)
    if SpellRanks.WeaponPinned(id) then
        if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
        weaponPin = nil
        if FDJ.Pins then FDJ.Pins.active = nil end
        FDJ:Emit("FDJ_PINS")
        return
    end
    local wm = SpellRanks.WeaponMaster(id)
    if not wm then
        say(L.WEAPON_NO_MASTER)
        return
    end
    local x, y = wm[4] / 100, wm[5] / 100
    if FDJ.Pins and FDJ.Pins.WaypointAt and FDJ.Pins.WaypointAt(wm[3], x, y, masterName(wm)) then
        weaponPin = { id = id, m = wm[3], x = x, y = y }
        FDJ:Emit("FDJ_PINS")
    end
end

function SpellRanks.ShareWeapon(w, toChatBox)
    if not (w and w.master) then return end
    if not toChatBox and not FDJ.GroupChannel() then return FDJ.ShareToGroup(nil, false) end
    if not SpellRanks.WeaponPinned(w.id) then SpellRanks.ToggleWeapon(w.id) end
    local line = FDJ.Pins and FDJ.Pins.ShareLine and FDJ.Pins.ShareLine()
    if not line then return end
    line = line .. "  " .. L.WEAPON_SHARE_FOR:format(w.name, masterName(w.master))
    FDJ.ShareToGroup(line, toChatBox)
end

local function trainerTip(owner, pet)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(pet and L.SPELL_PET_TRAINER or L.SPELL_TRAINER, 1, 1, 1)
    local spot, yards = SpellRanks.NearestTrainer(pet)
    if spot then
        local where = FDJ.MapName(spot.m)
        if yards then where = where .. "  |cff9a9ea6" .. L.SPELL_YARDS:format(math.floor(yards + 0.5)) .. "|r" end
        GameTooltip:AddLine(where, RGB(C.text))
        GameTooltip:AddLine(SpellRanks.TrainerPinned() and L.SPELL_TRAINER_PINNED or L.SPELL_TRAINER_CLICK, C.muted[1], C.muted[2], C.muted[3])
    else
        GameTooltip:AddLine(L.SPELL_TRAINER_NONE, C.muted[1], C.muted[2], C.muted[3], true)
    end
    GameTooltip:Show()
end

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:11:11:1:0|t"
coins = function(amount)
    amount = math.floor(tonumber(amount) or 0)
    local gold, silver, copper = math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. COIN:format("Gold") end
    if silver > 0 then parts[#parts + 1] = silver .. COIN:format("Silver") end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = copper .. COIN:format("Copper") end
    return table.concat(parts, " ")
end

local function rankLabel(item)
    if item.sub then return item.sub end
    if (item.maxRank or item.rank or 1) <= 1 and item.rank <= 1 then return "" end
    return L.SPELL_RANK:format(item.rank)
end

local function makeRow()
    local row = Kit.Row(scroll.content, ROW)
    row.rule:SetAlpha(0.35)
    row.level = Kit.Text(row, "small", C.muted, "RIGHT")
    row.level:SetPoint("LEFT", 2, 0)
    row.level:SetWidth(22)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 30, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.mark = Kit.Text(row, "tiny", C.good, "RIGHT")
    row.mark:SetPoint("RIGHT", -6, 0)
    row.name = Kit.Text(row, "normal", GOLD)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.rank = Kit.Text(row, "tiny", C.muted)
    row.rank:SetPoint("LEFT", row.name, "RIGHT", 6, -1)
    row.rank:SetPoint("RIGHT", row.mark, "LEFT", -4, -1)
    row:SetScript("OnEnter", function(self)
        self:Hover(true)
        local w = self.weapon
        if w then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(w.name, 1, 1, 1)
            if w.known then
                GameTooltip:AddLine(L.WEAPON_KNOWN, RGB(C.good))
            elseif w.master then
                local wm = w.master
                GameTooltip:AddLine(L.WEAPON_MASTER, RGB(C.accent))
                GameTooltip:AddLine(masterName(wm), 1, 1, 1)
                local where = FDJ.MapName(wm[3]) .. ("  %.1f, %.1f"):format(wm[4], wm[5])
                if w.yards then where = where .. "  |cff9a9ea6" .. L.SPELL_YARDS:format(math.floor(w.yards + 0.5)) .. "|r" end
                GameTooltip:AddLine(where, RGB(C.text))
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(SpellRanks.WeaponPinned(w.id) and L.WEAPON_TIP_UNPIN or L.WEAPON_TIP_PIN, RGB(C.muted))
                GameTooltip:AddLine(L.WEAPON_TIP_SHARE, RGB(C.muted))
            else
                GameTooltip:AddLine(L.WEAPON_NO_MASTER, RGB(C.muted))
            end
            GameTooltip:Show()
            return
        end
        local item = self.item
        if not item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local shown = false
        if item.id and GameTooltip.SetSpellByID then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, item.id) end
        if not shown or (GameTooltip.NumLines and GameTooltip:NumLines() == 0) then
            GameTooltip:SetText(item.name, 1, 1, 1)
            local rank = rankLabel(item)
            if rank ~= "" then GameTooltip:AddLine(rank, RGB(C.muted)) end
        end
        GameTooltip:AddLine(" ")
        if item.lv then GameTooltip:AddLine(L.SPELL_TRAIN_AT:format(item.lv), RGB(C.text)) end
        if item.cost and item.cost > 0 then GameTooltip:AddLine(coins(item.cost), 1, 1, 1) end
        GameTooltip:AddLine(L["SPELL_STATE_" .. item.state:upper()], RGB(C.muted))
        GameTooltip:AddDoubleLine(L.SPELL_ID, item.id and tostring(item.id) or L.SPELL_ID_UNKNOWN, C.muted[1], C.muted[2], C.muted[3], 1, 0.82, 0.3)
        local ranks, maxRank = item.ranks or {}, 0
        for r in pairs(ranks) do if r > maxRank then maxRank = r end end
        for r in pairs(item.ids or {}) do if r > maxRank then maxRank = r end end
        if maxRank > 1 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.SPELL_ALL_RANKS, RGB(C.accent))
            for r = 1, maxRank do
                local info = ranks[r] or {}
                local id = info.id or (item.ids and item.ids[r])
                local left = L.SPELL_RANK:format(r) .. (info.lv and ("   " .. L.LEVEL .. " " .. info.lv) or "")
                local tone = r <= (item.have or 0) and C.dim or (r == item.rank and C.white or C.text)
                GameTooltip:AddDoubleLine(left, id and ("ID " .. id) or "-", tone[1], tone[2], tone[3], 0.6, 0.62, 0.66)
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self:Hover(false)
        Kit.HideTip()
    end)
    row:SetScript("OnClick", function(self, button)
        local w = self.weapon
        if not (w and not w.known and w.master) then return end
        if button == "RightButton" or IsShiftKeyDown() then
            SpellRanks.ShareWeapon(w, IsShiftKeyDown())
        else
            SpellRanks.ToggleWeapon(w.id)
        end
        SpellRanks.Refresh()
    end)
    return row
end

local weaponView

local CITY_ICON = {
    [1453] = "Spell_Arcane_TeleportStormWind", [1455] = "Spell_Arcane_TeleportIronForge",
    [1457] = "Spell_Arcane_TeleportDarnassus", [1454] = "Spell_Arcane_TeleportOrgrimmar",
    [1456] = "Spell_Arcane_TeleportThunderBluff", [1458] = "Spell_Arcane_TeleportUnderCity",
}
local function cityIcon(m) return "Interface\\Icons\\" .. (CITY_ICON[m] or "INV_Misc_Map_01") end

local function masterPinned(wm)
    if not (FDJ.Pins and FDJ.Pins.Native) then return false end
    local m, x, y = FDJ.Pins.Native()
    return m == wm[3] and x and math.abs(x - wm[4] / 100) < 0.002 and math.abs(y - wm[5] / 100) < 0.002 or false
end

function SpellRanks.PinMaster(wm, id)
    if masterPinned(wm) then
        if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
        weaponPin = nil
        if FDJ.Pins then FDJ.Pins.active, FDJ.Pins.label = nil, nil end
        FDJ:Emit("FDJ_PINS")
        return
    end
    local x, y = wm[4] / 100, wm[5] / 100
    if FDJ.Pins and FDJ.Pins.WaypointAt and FDJ.Pins.WaypointAt(wm[3], x, y, masterName(wm)) then
        weaponPin = { id = id, m = wm[3], x = x, y = y }
        FDJ:Emit("FDJ_PINS")
    end
end

function SpellRanks.ShareMaster(wm, what, toChatBox)
    if not toChatBox and not FDJ.GroupChannel() then return FDJ.ShareToGroup(nil, false) end
    if not masterPinned(wm) then SpellRanks.PinMaster(wm) end
    local line = FDJ.Pins and FDJ.Pins.ShareLine and FDJ.Pins.ShareLine()
    if not line then return end
    line = line .. "  " .. (what and L.WEAPON_SHARE_FOR:format(what, masterName(wm)) or masterName(wm))
    FDJ.ShareToGroup(line, toChatBox)
end

local function yardText(yards)
    if not yards then return "" end
    if yards >= 1000 then return ("%.1fk yd"):format(yards / 1000) end
    return L.SPELL_YARDS:format(math.floor(yards + 0.5))
end

local ITEM_H, CARD_TOP = 20, 42

local function trainerTipFor(f)
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
    GameTooltip:SetText(masterName(f.wm), 1, 1, 1)
    GameTooltip:AddLine(L.WEAPON_MASTER, RGB(C.accent))
    GameTooltip:AddDoubleLine(FDJ.MapName(f.wm[3]), ("%.1f, %.1f"):format(f.wm[4], f.wm[5]), 1, 0.82, 0.3, RGB(C.muted))
    if f.yards then GameTooltip:AddLine(L.SPELL_YARDS:format(math.floor(f.yards + 0.5)), RGB(C.text)) end
    GameTooltip:AddLine(" ")
    for _, it in ipairs(f.items) do
        if it:IsShown() and it.wname then
            if it.known then GameTooltip:AddDoubleLine(it.wname, L.WEAPON_KNOWN, 0.5, 0.5, 0.5, RGB(C.dim))
            else GameTooltip:AddDoubleLine(it.wname, L.WEAPON_LEARN, 1, 1, 1, RGB(C.good)) end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(masterPinned(f.wm) and L.WEAPON_TIP_UNPIN or L.WEAPON_TIP_PIN, RGB(C.muted))
    GameTooltip:AddLine(L.WEAPON_TIP_SHARE, RGB(C.muted))
    GameTooltip:Show()
end

local function paintCard(f, hover)
    f.bg:SetColorTexture(RGB(f.pinned and C.amber or C.field, f.pinned and 0.20 or 0.55))
    Kit.EdgeColor(f, hover and C.accent or (f.pinned and C.amber or C.borderDim))
    f.stripe:SetColorTexture(RGB(C.amber, f.pinned and 1 or 0))
    f.pin:SetAlpha((f.pinned or hover) and 1 or 0.4)
    f.pin:SetDesaturated(not (f.pinned or hover))
end

local function makeTrainerCard(parent)
    local f = CreateFrame("Button", nil, parent)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.bg = Kit.Fill(f, C.field, 0.55)
    Kit.Edge(f, C.borderDim)
    f.stripe = f:CreateTexture(nil, "ARTWORK")
    f.stripe:SetPoint("TOPLEFT", 1, -1)
    f.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    f.stripe:SetWidth(2)
    f.tp = f:CreateTexture(nil, "ARTWORK")
    f.tp:SetSize(26, 26)
    f.tp:SetPoint("TOPLEFT", 9, -8)
    f.tp:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.pin = Kit.PinIcon(f, 24)
    f.pin:SetPoint("TOPRIGHT", -6, -8)
    f.dist = Kit.Text(f, "small", C.muted, "RIGHT")
    f.dist:SetPoint("RIGHT", f.pin, "LEFT", -4, 0)
    f.near = Kit.Text(f, "tiny", C.good, "RIGHT")
    f.near:SetPoint("TOPRIGHT", f.dist, "BOTTOMRIGHT", 0, -2)
    f.name = Kit.Text(f, "normal", C.white)
    f.name:SetPoint("TOPLEFT", f.tp, "TOPRIGHT", 8, 1)
    f.name:SetPoint("RIGHT", f.dist, "LEFT", -6, 0)
    f.name:SetWordWrap(false)
    f.where = Kit.Text(f, "tiny", C.muted)
    f.where:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -2)
    f.rule = Kit.Line(f, "TOP", C.borderDim, 0.5, 8)
    f.rule:ClearAllPoints()
    f.rule:SetPoint("TOPLEFT", 9, -(CARD_TOP - 2))
    f.rule:SetPoint("TOPRIGHT", -9, -(CARD_TOP - 2))
    f.items = {}
    f:SetScript("OnEnter", function(self) paintCard(self, true) trainerTipFor(self) end)
    f:SetScript("OnLeave", function(self) paintCard(self, false) Kit.HideTip() end)
    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            SpellRanks.ShareMaster(self.wm, self.what, IsShiftKeyDown())
        else
            SpellRanks.PinMaster(self.wm)
        end
    end)
    return f
end

local function cardItem(f, i)
    local it = f.items[i]
    if it then return it end
    it = CreateFrame("Frame", nil, f)
    it:SetHeight(ITEM_H)
    it.icon = it:CreateTexture(nil, "ARTWORK")
    it.icon:SetSize(16, 16)
    it.icon:SetPoint("LEFT")
    it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    it.tag = Kit.Text(it, "tiny", C.good, "RIGHT")
    it.tag:SetPoint("RIGHT", -2, 0)
    it.tick = it:CreateTexture(nil, "ARTWORK")
    it.tick:SetSize(13, 13)
    it.tick:SetPoint("RIGHT", -2, 0)
    it.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    it.name = Kit.Text(it, "small", GOLD)
    it.name:SetPoint("LEFT", it.icon, "RIGHT", 5, 0)
    it.name:SetPoint("RIGHT", it.tag, "LEFT", -4, 0)
    it.name:SetWordWrap(false)
    f.items[i] = it
    return it
end

local function sectionLabel(parent, text)
    local t = Kit.Text(parent, "tiny", C.accent)
    t:SetText(text)
    return t
end

local function refreshWeapons()
    kindSeg:Hide()
    stepper:Hide()
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -8, 26)
    local content = scroll.content
    if not weaponView then
        weaponView = CreateFrame("Frame", nil, content)
        weaponView.cards, weaponView.loose = {}, {}
        weaponView.nowhereLabel = sectionLabel(weaponView, L.WEAPON_SEC_NOWHERE)
    end
    weaponView:ClearAllPoints()
    weaponView:SetPoint("TOPLEFT")
    weaponView:SetPoint("RIGHT", content, "RIGHT")
    weaponView:Show()
    local V = weaponView
    local width = content:GetWidth() or 0
    if width < 120 then width = WIDTH - 30 end

    local list = SpellRanks.Weapons()
    local learn, byId = {}, {}
    for _, w in ipairs(list) do
        byId[w.id] = w
        if not w.known then learn[#learn + 1] = w end
    end
    foot.cost, foot.count = 0, 0
    costLabel:SetText(L.SPELL_MODE_WEAPONS)
    costText:SetText(#learn == 1 and L.WEAPON_OPEN_ONE or (#learn > 0 and L.WEAPON_OPEN:format(#learn) or L.WEAPON_ALL_KNOWN))
    costText:SetPoint("RIGHT", foot, "RIGHT", -1, 0)
    costText:SetTone(#learn > 0 and C.text or C.dim)
    trainerButton:Hide()
    trainerButton.share:Hide()
    hint:SetText(L.WEAPON_HINT)
    hint:SetTone(C.dim)
    empty:SetShown(#learn == 0)
    empty:SetText(#list == 0 and L.WEAPON_NONE or L.WEAPON_ALL_KNOWN)

    for _, f in ipairs(V.cards) do f:Hide() end
    for _, it in ipairs(V.loose) do it:Hide() end
    V.nowhereLabel:Hide()

    local faction = (FDJ.Faction() or ""):sub(1, 1)
    local masters, taught = {}, {}
    for _, wm in ipairs(FDJ.WeaponMasters or {}) do
        if wm[6] == faction then
            local teaches, needed = {}, 0
            for _, sid in ipairs(wm[7]) do
                local w = byId[sid]
                if w then
                    teaches[#teaches + 1] = w
                    taught[sid] = true
                    if not w.known then needed = needed + 1 end
                end
            end
            if needed > 0 then
                table.sort(teaches, function(a, b)
                    if (a.known or false) ~= (b.known or false) then return not a.known end
                    return a.name < b.name
                end)
                masters[#masters + 1] = { wm = wm, teaches = teaches, yards = distanceTo(wm[3], wm[4] / 100, wm[5] / 100) }
            end
        end
    end
    table.sort(masters, function(a, b)
        if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
        if a.yards and b.yards and a.yards ~= b.yards then return a.yards < b.yards end
        return masterName(a.wm) < masterName(b.wm)
    end)

    local y = 2
    for i, m in ipairs(masters) do
        local f = V.cards[i] or makeTrainerCard(V)
        V.cards[i] = f
        f.wm, f.yards = m.wm, m.yards
        f.nearest = i == 1 and m.yards ~= nil
        f.pinned = masterPinned(m.wm)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -y)
        f:SetWidth(width)
        f.tp:SetTexture(cityIcon(m.wm[3]))
        f.name:SetText(masterName(m.wm))
        f.where:SetText(FDJ.MapName(m.wm[3]))
        f.dist:SetText(m.yards and yardText(m.yards) or "")
        f.near:SetText(f.nearest and L.WEAPON_NEAREST or "")
        local names = {}
        local cols = 1
        for n, w in ipairs(m.teaches) do
            local it = cardItem(f, n)
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 9, -(CARD_TOP + 4 + (n - 1) * ITEM_H))
            it:SetWidth(width - 18)
            it.icon:SetTexture(w.icon or 134400)
            it.name:SetText(w.name)
            it.wname, it.known = w.name, w.known
            if w.known then
                it.icon:SetDesaturated(true)
                it.icon:SetAlpha(0.45)
                it.name:SetTone(C.dim)
                it.tag:SetText("")
                it.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                it.tick:Show()
            else
                it.icon:SetDesaturated(false)
                it.icon:SetAlpha(1)
                it.name:SetTone(GOLD)
                it.tag:SetText("")
                it.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
                it.tick:Show()
                names[#names + 1] = w.name
            end
            it:Show()
        end
        for k = #m.teaches + 1, #f.items do f.items[k]:Hide() f.items[k].wname = nil end
        f.what = table.concat(names, ", ")
        local h = CARD_TOP + 4 + math.ceil(#m.teaches / cols) * ITEM_H + 6
        f:SetHeight(h)
        paintCard(f, false)
        f:Show()
        y = y + h + 6
    end

    local nowhere = {}
    for _, w in ipairs(learn) do if not taught[w.id] then nowhere[#nowhere + 1] = w end end
    if #nowhere > 0 then
        y = y + 4
        V.nowhereLabel:ClearAllPoints()
        V.nowhereLabel:SetPoint("TOPLEFT", 4, -y)
        V.nowhereLabel:Show()
        y = y + 16
        for n, w in ipairs(nowhere) do
            local it = V.loose[n]
            if not it then
                it = CreateFrame("Frame", nil, V)
                it:SetHeight(ITEM_H)
                it.icon = it:CreateTexture(nil, "ARTWORK")
                it.icon:SetSize(16, 16)
                it.icon:SetPoint("LEFT", 4, 0)
                it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                it.icon:SetDesaturated(true)
                it.name = Kit.Text(it, "small", C.muted)
                it.name:SetPoint("LEFT", it.icon, "RIGHT", 5, 0)
                V.loose[n] = it
            end
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 0, -y)
            it:SetWidth(width)
            it.icon:SetTexture(w.icon or 134400)
            it.name:SetText(w.name)
            it:Show()
            y = y + ITEM_H
        end
    end
    V:SetHeight(y)
    scroll:SetContentHeight(y + 4)
end

local stale, shownWith, shownAt = true, nil, 0
local function showKey() return table.concat({ mode or "", kind or "", viewLevel or 0, FDJ.Level(), gen }, ":") end

function SpellRanks.Refresh()
    if not panel or not panel:IsShown() then return end
    stale, shownWith, shownAt = false, showKey(), GetTime()
    rows:Reset()
    if mode == "weapons" then return refreshWeapons() end
    if weaponView then weaponView:Hide() end
    costText:SetPoint("RIGHT", trainerButton, "LEFT", -26, 0)
    trainerButton:Show()
    trainerButton:Paint()
    local playerLevel = FDJ.Level()
    viewLevel = math.max(1, math.min(viewLevel or playerLevel, 60))
    levelText:SetText(L.SPELL_AT_LEVEL:format(viewLevel))
    local list, scanned, sums = collect(viewLevel)
    if not sums.pets and kind ~= "class" then
        kind = "class"
        list, scanned, sums = collect(viewLevel)
    end

    local anchor = foot
    local function stack(frame, shown, gap)
        frame:SetShown(shown)
        if not shown then return end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 6))
        frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -(gap or 6))
        anchor = frame
    end
    stack(kindSeg, sums.pets, 4)
    if sums.pets then kindSeg:Select(kind, true) end
    stack(stepper, mode == "all")
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -8, 26)

    local cost, count, label
    if mode == "all" then
        cost, count = sums.upto, sums.uptoCount
        label = L.SPELL_COST_UPTO:format(viewLevel)
    else
        cost, count = sums.now, sums.nowCount
        label = L.SPELL_COST_NOW
    end
    foot.cost, foot.count = cost, count
    costLabel:SetText(label)
    if count > 0 then
        local short = GetMoney and cost > GetMoney()
        costText:SetText(coins(cost))
        costText:SetTone(short and C.bad or C.text)
    else
        costText:SetText(mode == "all" and L.SPELL_COST_NONE_UPTO or L.SPELL_COST_NONE)
        costText:SetTone(C.dim)
    end

    hint:SetText(scanned and (mode == "all" and L.SPELL_HINT_SCANNED or L.SPELL_HINT_NEXT) or L.SPELL_HINT_TRAINER)
    hint:SetTone(scanned and C.dim or C.warn)
    empty:SetShown(#list == 0)
    empty:SetText(mode == "next" and scanned and L.SPELL_ALL_TRAINED or L.SPELL_NONE)
    local y = 0
    for _, item in ipairs(list) do
        local row = rows:Get()
        row.item = item
        row.weapon = nil
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", scroll.content, "RIGHT")
        row.level:SetText(item.lv and item.lv > 0 and item.lv or (item.lv == 0 and "1" or "-"))
        row.level:SetTone(item.state == "train" and C.good or (item.state == "known" and C.dim or C.muted))
        row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetDesaturated(item.state == "later")
        row.icon:SetAlpha(item.state == "known" and 0.7 or 1)
        row.name:SetText(item.name)
        row.name:SetTone(item.state == "known" and C.muted or (item.state == "later" and C.text or GOLD))
        row.rank:SetText(rankLabel(item))
        if item.state == "train" then
            row.mark:SetText(L.SPELL_TRAIN)
            row.mark:SetTone(C.good)
        elseif item.state == "known" then
            row.mark:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t")
        else
            row.mark:SetText("")
        end
        y = y + ROW
    end
    scroll:SetContentHeight(y)
end

local function build()
    FDJ.SyncTheme()
    panel = CreateFrame("Frame", "FojjiCoreSpellRanks", UIParent)
    panel:SetWidth(WIDTH)
    panel:SetFrameStrata("HIGH")
    panel:EnableMouse(true)
    Kit.Fill(panel, C.frame, 0.97)
    Kit.Edge(panel, C.border)
    if Addon.Native and Addon.Skin then Addon.Skin.Panel(panel) end

    local head = CreateFrame("Frame", nil, panel)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(34)
    Kit.Fill(head, C.header)
    Kit.Line(head, "BOTTOM", C.borderDim)
    local icon = head:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 8, 0)
    Kit.Logo(icon)
    local title = Kit.Text(head, "title", C.white)
    title:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    title:SetText(L.SPELL_TITLE)
    local shrink = Kit.IconButton(head, "fc:icon-minus", 24, L.SPELL_MINIMIZE, function() SpellRanks.SetCollapsed(true) end)
    shrink:SetPoint("RIGHT", -3, 0)

    tab = CreateFrame("Button", "FojjiCoreSpellRanksTab", UIParent)
    tab:SetSize(36, 36)
    Kit.Fill(tab, C.header)
    Kit.Edge(tab, C.border)
    if Addon.Native and Addon.Skin then Addon.Skin.Panel(tab) end
    local tabIcon = tab:CreateTexture(nil, "ARTWORK")
    tabIcon:SetSize(24, 24)
    tabIcon:SetPoint("CENTER")
    Kit.Logo(tabIcon)
    tab:SetScript("OnClick", function() SpellRanks.SetCollapsed(false) end)
    tab:SetScript("OnEnter", function(self)
        Kit.EdgeColor(self, C.accent)
        Kit.Tip(self, L.SPELL_TITLE, L.SPELL_EXPAND, "ANCHOR_RIGHT")
    end)
    tab:SetScript("OnLeave", function(self)
        Kit.EdgeColor(self, C.border)
        Kit.HideTip()
    end)
    tab:Hide()

    seg = Kit.Segmented(panel, { { "next", L.SPELL_MODE_NEXT }, { "all", L.SPELL_MODE_ALL }, { "weapons", L.SPELL_MODE_WEAPONS } }, function(key)
        mode = key
        saved().mode = key
        saved().picked = true
        SpellRanks.Refresh()
    end)
    seg:SetHeight(24)
    seg:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 8, -8)
    seg:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -8, -8)

    kindSeg = Kit.Segmented(panel, { { "class", L.SPELL_KIND_CLASS }, { "pet", PET or "Pet" } }, function(key)
        kind = key
        saved().kind = key
        SpellRanks.Refresh()
    end)
    kindSeg:SetHeight(20)
    kindSeg:Hide()

    stepper = CreateFrame("Frame", nil, panel)
    stepper:SetHeight(26)
    local minus = Kit.IconButton(stepper, "fc:icon-minus", 24, nil, function()
        setLevel((viewLevel or 60) - (IsShiftKeyDown() and 10 or 1))
    end)
    minus:SetPoint("LEFT")
    local plus = Kit.IconButton(stepper, "fc:icon-plus", 24, nil, function()
        setLevel((viewLevel or 60) + (IsShiftKeyDown() and 10 or 1))
    end)
    plus:SetPoint("RIGHT")
    levelText = Kit.Text(stepper, "normal", C.white, "CENTER")
    levelText:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    levelText:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    stepper:EnableMouseWheel(true)
    stepper:SetScript("OnMouseWheel", function(_, delta)
        setLevel((viewLevel or 60) + delta)
    end)

    scroll = Kit.Scroller(panel)
    rows = Kit.Pool(makeRow)
    empty = Kit.Text(scroll, "small", C.muted, "CENTER")
    empty:SetPoint("TOPLEFT", 10, -30)
    empty:SetPoint("TOPRIGHT", -10, -30)
    empty:SetWordWrap(true)

    hint = Kit.Text(panel, "tiny", C.dim)
    hint:SetPoint("BOTTOMLEFT", 9, 8)
    hint:SetPoint("BOTTOMRIGHT", -9, 8)

    foot = CreateFrame("Frame", nil, panel)
    foot:SetHeight(36)
    foot:SetPoint("TOPLEFT", seg, "BOTTOMLEFT", 0, -4)
    foot:SetPoint("TOPRIGHT", seg, "BOTTOMRIGHT", 0, -4)
    Kit.Line(foot, "BOTTOM", C.borderDim)
    foot:EnableMouse(true)
    trainerButton = CreateFrame("Button", nil, foot)
    trainerButton:SetSize(120, 22)
    trainerButton:SetPoint("RIGHT", 0, -1)
    trainerButton.pin = Kit.PinIcon(trainerButton, 20)
    trainerButton.pin:SetPoint("RIGHT", -3, 0)
    trainerButton.pin:SetAlpha(0.85)
    trainerButton.label = Kit.Text(trainerButton, "small", C.muted, "RIGHT")
    trainerButton.label:SetPoint("RIGHT", trainerButton.pin, "LEFT", -3, 0)
    trainerButton:SetScript("OnEnter", function(self)
        self.pin:SetAlpha(1)
        self.label:SetTextColor(RGB(C.white))
        trainerTip(self, kind == "pet")
    end)
    trainerButton:SetScript("OnLeave", function(self)
        self:Paint()
        Kit.HideTip()
    end)
    trainerButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    trainerButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            SpellRanks.ClearTrainer()
        else
            SpellRanks.ToggleTrainer(kind == "pet")
        end
    end)
    trainerButton.on = Kit.Fill(trainerButton, C.amber, 0, "BACKGROUND", 1)
    trainerButton.share = Kit.IconButton(foot, "fc:icon-gossip", 20, L.SHARE_PIN, function()
        if FDJ.Pins and FDJ.Pins.Share then FDJ.Pins.Share(nil, IsShiftKeyDown()) end
    end)
    trainerButton.share.tipBody = L.SHARE_PIN_TIP
    trainerButton.share:SetPoint("RIGHT", trainerButton, "LEFT", -2, 0)
    function trainerButton:Paint()
        local on = SpellRanks.TrainerPinned()
        self.on:SetColorTexture(RGB(C.amber, on and 0.28 or 0))
        self.pin:SetAlpha(on and 1 or 0.85)
        self.label:SetText(kind == "pet" and L.SPELL_PET_TRAINER or L.SPELL_TRAINER)
        self.label:SetTextColor(RGB(on and C.amber or C.muted))
        self:SetWidth(math.ceil(self.label:GetStringWidth() or 90) + 20 + 12)
        self.share:SetShown(on)
    end
    FDJ:On("FDJ_PINS", function() if trainerButton:IsVisible() then trainerButton:Paint() end end)
    FDJ:On("FDJ_PINS", function() if panel:IsShown() and mode == "weapons" then SpellRanks.Refresh() end end)
    FDJ:On("USER_WAYPOINT_UPDATED", function() if trainerButton:IsVisible() then trainerButton:Paint() end end)
    trainerButton:HookScript("OnShow", function(self) self:Paint() end)
    costLabel = Kit.Text(foot, "tiny", C.dim)
    costLabel:SetPoint("TOPLEFT", 1, -3)
    costLabel:SetPoint("RIGHT", trainerButton, "LEFT", -26, 0)
    costText = Kit.Text(foot, "small", C.text)
    costText:SetPoint("BOTTOMLEFT", 1, 5)
    costText:SetPoint("RIGHT", trainerButton, "LEFT", -26, 0)
    foot:SetScript("OnEnter", function(self)
        if not self.count or self.count == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(mode == "all" and L.SPELL_COST_UPTO:format(viewLevel) or L.SPELL_COST_NOW, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.SPELL_COST_RANKS, tostring(self.count), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
        GameTooltip:AddDoubleLine(L.SPELL_COST_TOTAL, coins(self.cost), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
        if GetMoney then
            local money = GetMoney()
            GameTooltip:AddDoubleLine(L.SPELL_COST_HAVE, coins(money), C.muted[1], C.muted[2], C.muted[3], 1, 1, 1)
            if self.cost > money then GameTooltip:AddLine(L.SPELL_COST_SHORT:format(coins(self.cost - money)), RGB(C.bad)) end
        end
        GameTooltip:Show()
    end)
    foot:SetScript("OnLeave", Kit.HideTip)

    panel:SetScript("OnShow", function()
        local view = saved()
        if not view.picked then
            view.mode = "next"
            view.picked = true
        end
        mode = (view.mode == "all" or view.mode == "weapons") and view.mode or "next"
        kind = view.kind == "pet" and "pet" or "class"
        viewLevel = view.level or 60
        seg:Select(mode, true)
        if stale or showKey() ~= shownWith or GetTime() - shownAt > 30 then SpellRanks.Refresh() end
    end)
    panel:Hide()
end

local function attach(frame)
    if not SpellRanks.Enabled() then return end
    if not panel then build() end
    host = frame
    panel:SetParent(UIParent)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(40)
    panel:SetToplevel(true)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    panel:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 4, 0)
    tab:SetParent(UIParent)
    tab:SetFrameStrata("HIGH")
    tab:SetFrameLevel(50)
    tab:SetToplevel(true)
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, -60)
    local small = saved().collapsed
    local wasShown = panel:IsShown()
    panel:SetShown(not small)
    tab:SetShown(small and true or false)
    if small then SpellRanks.Refresh() end
    if wasShown then stale = true; SpellRanks.Refresh() end
end

function SpellRanks.SetCollapsed(on)
    saved().collapsed = on and true or nil
    if host and host:IsVisible() then attach(host) end
end

local function hookFrame(frame)
    if not frame or hooked[frame] or not frame.HookScript then return end
    hooked[frame] = true
    FDJ.WatchFrame(frame, function(self) attach(self) end, function(self)
        if panel and host == self then panel:Hide() tab:Hide() end
    end)
    if frame:IsShown() then attach(frame) end
end

local function hookTab(page, outer)
    if not page or hooked[page] or not page.HookScript then return end
    hooked[page] = true
    FDJ.WatchFrame(page, function() if page:IsVisible() then attach(outer) end end, function()
        if panel and host == outer then panel:Hide() tab:Hide() end
    end)
    FDJ.WatchFrame(outer, nil, function()
        if tab and host == outer then tab:Hide() end
    end)
    if page:IsVisible() then attach(outer) end
end

local function findFrames()
    for _, name in ipairs(BOOK_FRAMES) do
        local frame = _G[name]
        if frame then hookFrame(frame) end
    end
    local combined = _G.PlayerSpellsFrame
    if combined and combined.SpellBookFrame then hookTab(combined.SpellBookFrame, combined) end
end

function SpellRanks.HideAll()
    if panel then
        panel:Hide()
        tab:Hide()
    end
end

function SpellRanks.SetEnabled(on, quiet)
    if FDJ.opt then FDJ.opt.spellRanks = on and true or false end
    if not on then
        if panel then panel:Hide() tab:Hide() end
        if not quiet then say(L.SPELL_HIDDEN) end
    elseif host and host:IsShown() then
        attach(host)
    end
    FDJ:Emit("FDJ_OPTION", "spellRanks", on)
end

local toast
local hideLater
local function hideToast()
    if not toast then return end
    if InCombatLockdown() and toast.IsProtected and toast:IsProtected() then
        toast:SetAlpha(0)
        toast.left = 1e9
        if not hideLater then
            hideLater = CreateFrame("Frame")
            hideLater:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                if toast and toast:GetAlpha() == 0 then toast:Hide() toast:SetAlpha(1) end
            end)
        end
        hideLater:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    toast:Hide()
end
local TOAST_ICON = 38
local TOAST_LIFE = 20

local function saveToastSpot()
    local point, _, rel, x, y = toast:GetPoint(1)
    if FDJ.db then FDJ.db.window.spellToast = { point, rel, x, y } end
end

local function placeToast()
    toast:ClearAllPoints()
    if FDJ.db and FDJ.db.window.spellToastV ~= 8 then
        FDJ.db.window.spellToast = nil
        FDJ.db.window.spellToastV = 8
    end
    local spot = FDJ.db and FDJ.db.window.spellToast
    if spot then
        toast:SetPoint(spot[1], UIParent, spot[2], spot[3], spot[4])
    else
        toast:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end
end

local function makeToastIcon(i)
    local b = CreateFrame("Button", nil, toast)
    b:SetSize(TOAST_ICON, TOAST_ICON)
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(TOAST_ICON * 1.9, TOAST_ICON * 1.9)
    b.glow:SetTexture(FDJ.Glyph("fc:badge-glow"))
    b.glow:SetBlendMode("ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    if b.CreateMaskTexture then
        local mask = b:CreateMaskTexture()
        mask:SetAllPoints(b.icon)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        b.icon:AddMaskTexture(mask)
    else
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetAllPoints()
    b.ring:SetTexture(FDJ.Glyph("fc:badge-ring"))
    b.pop = b:CreateAnimationGroup()
    local fade = b.pop:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.25)
    local grow = b.pop:CreateAnimation("Scale")
    if grow.SetScaleFrom then
        grow:SetScaleFrom(0.4, 0.4)
        grow:SetScaleTo(1, 1)
    else
        grow:SetFromScale(0.4, 0.4)
        grow:SetToScale(1, 1)
    end
    grow:SetDuration(0.3)
    grow:SetSmoothing("OUT")
    b.pop.fade, b.pop.grow = fade, grow
    b:SetScript("OnEnter", function(self)
        toast.hold = true
        local item = self.item
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not (item.id and pcall(GameTooltip.SetSpellByID, GameTooltip, item.id)) then
            GameTooltip:SetText(item.name, 1, 1, 1)
        end
        if item.hint then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(item.hint, C.good[1], C.good[2], C.good[3])
        end
        if item.pickup then GameTooltip:AddLine(L.SPELL_IGNORE_HINT, C.muted[1], C.muted[2], C.muted[3]) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        toast.hold = false
        Kit.HideTip()
    end)
    local function ignore(self, button)
        if button == "RightButton" and self.item and self.item.pickup then
            Kit.HideTip()
            SpellRanks.Ignore(self.item.name, self.item.id)
        end
    end
    b:SetScript("OnMouseUp", ignore)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        self.moving = true
        toast:StartMoving()
    end)
    b:SetScript("OnDragStop", function(self)
        if not self.moving then return end
        self.moving = nil
        toast:StopMovingOrSizing()
        saveToastSpot()
    end)
    SpellRanks.SecureOpen(b, "book", ignore)
    return b
end

local function buildToast()
    toast = CreateFrame("Button", "FojjiCoreSpellToast", UIParent)
    toast:SetFrameStrata("MEDIUM")
    toast:SetClampedToScreen(true)
    toast:SetMovable(true)
    toast:RegisterForDrag("LeftButton")
    toast:RegisterForClicks("RightButtonUp")
    FDJ.SyncTheme()
    Kit.Fill(toast, C.frame, 0.94)
    Kit.Edge(toast, C.border)
    local shine = Kit.Gradient(toast, "VERTICAL", C.accent, 0, 0.14, "BORDER")
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", -1, 1)
    local stripe = toast:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    stripe:SetHeight(2)
    Kit.Paint(stripe, C.accent)
    toast.title = Kit.Text(toast, "small", C.white, "CENTER")
    toast.title:SetPoint("TOP", 0, -8)
    toast.sub = Kit.Text(toast, "tiny", C.muted, "CENTER")
    toast.sub:SetPoint("BOTTOM", 0, 7)
    toast.pin = CreateFrame("Button", nil, toast)
    toast.pin:SetSize(16, 16)
    toast.pin:SetPoint("TOPLEFT", 4, -4)
    local pin = Kit.PinIcon(toast.pin, 14)
    pin:SetPoint("CENTER")
    pin:SetAlpha(0.55)
    toast.pin:SetScript("OnEnter", function(self)
        toast.hold = true
        pin:SetAlpha(1)
        trainerTip(self, false)
    end)
    toast.pin:SetScript("OnLeave", function()
        toast.hold = false
        pin:SetAlpha(0.55)
        Kit.HideTip()
    end)
    toast.pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    toast.pin:SetScript("OnClick", function(_, button)
        if button == "RightButton" then SpellRanks.ClearTrainer() else SpellRanks.ToggleTrainer(false) end
    end)
    local close = CreateFrame("Button", nil, toast)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -4, -5)
    close:SetFrameLevel(toast:GetFrameLevel() + 10)
    close:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    close:SetHighlightTexture("Interface\\Buttons\\UI-StopButton", "ADD")
    close:GetNormalTexture():SetVertexColor(1, 0.25, 0.25)
    close:SetScript("OnClick", function()
        if toast.kind == "bars" then SpellRanks.DismissBars() end
        hideToast()
    end)
    close:SetScript("OnEnter", function(self)
        toast.hold = true
        self:GetNormalTexture():SetVertexColor(1, 0.45, 0.45)
    end)
    close:SetScript("OnLeave", function(self)
        toast.hold = false
        self:GetNormalTexture():SetVertexColor(1, 0.25, 0.25)
    end)
    toast.close = close
    toast.icons = {}
    toast:SetScript("OnDragStart", toast.StartMoving)
    toast:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveToastSpot()
    end)
    toast:SetScript("OnClick", function(self)
        if self.kind == "bars" then SpellRanks.DismissBars() end
        hideToast()
    end)
    toast:SetScript("OnHide", function(self)
        local was = self.kind
        self.kind = nil
        if was ~= "bars" then C_Timer.After(0.3, function() if SpellRanks.SyncBars then pcall(SpellRanks.SyncBars) end end) end
    end)
    toast:SetScript("OnEnter", function(self) self.hold = true end)
    toast:SetScript("OnLeave", function(self) self.hold = false end)
    toast.out = toast:CreateAnimationGroup()
    local fade = toast.out:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.8)
    toast.out:SetScript("OnFinished", hideToast)
    local tick = 0
    toast:SetScript("OnUpdate", function(self, elapsed)
        tick = tick + elapsed
        if tick < 0.1 then return end
        elapsed, tick = tick, 0
        if self.sticky or self.hold or self:IsMouseOver() then
            self.left = math.max(self.left, 2)
            if self.out:IsPlaying() then self.out:Stop() self:SetAlpha(1) end
            return
        end
        self.left = self.left - elapsed
        if self.left <= 0 and not self.out:IsPlaying() then self.out:Play() end
    end)
    toast:Hide()
end

local function showToast(title, sub, items, pinned, opts)
    opts = opts or {}
    if #items == 0 then return end
    if not toast then buildToast() end
    if FDJ.SyncTheme() then Kit.Repaint() end
    local count = math.min(#items, 8)
    for i = 1, count do
        local b = toast.icons[i] or makeToastIcon(i)
        toast.icons[i] = b
        local item = items[i]
        b.item = item
        b.icon:SetTexture(item.icon or 134400)
        local tone = item.pet and C.good or C.accent
        b.ring:SetVertexColor(tone[1], tone[2], tone[3])
        b.glow:SetVertexColor(tone[1], tone[2], tone[3], 0.35)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 14 + (i - 1) * (TOAST_ICON + 8), -28)
        b:Show()
        if opts.quiet then
            b.pop:Stop()
            b:SetAlpha(1)
        else
            b.pop.fade:SetStartDelay(0.15 + i * 0.07)
            b.pop.grow:SetStartDelay(0.15 + i * 0.07)
            b:SetAlpha(0)
            b.pop:SetScript("OnFinished", function() b:SetAlpha(1) end)
            b.pop:Play()
        end
    end
    for i = count + 1, #toast.icons do toast.icons[i]:Hide() end
    if #items > count then sub = sub .. "  ·  " .. L.SPELL_TOAST_MORE:format(#items - count) end
    toast.title:SetText(title)
    toast.sub:SetText(sub)
    toast.pin:SetShown(pinned and true or false)
    local width = math.max(170, 28 + count * TOAST_ICON + (count - 1) * 8, toast.title:GetUnboundedStringWidth() + 48, toast.sub:GetUnboundedStringWidth() + 24)
    toast:SetSize(width, 28 + TOAST_ICON + 26)
    local rowWidth = count * TOAST_ICON + (count - 1) * 8
    for i = 1, count do
        toast.icons[i]:ClearAllPoints()
        toast.icons[i]:SetPoint("TOPLEFT", (width - rowWidth) / 2 + (i - 1) * (TOAST_ICON + 8), -28)
    end
    placeToast()
    toast.out:Stop()
    toast:SetAlpha(1)
    toast.left = TOAST_LIFE
    toast.sticky = opts.sticky
    toast.kind = opts.kind
    toast.hold = false
    toast:Show()
end
SpellRanks.ShowToast = showToast

local function levelToast(level)
    if not (FDJ.opt and FDJ.opt.spellToast ~= false) or FDJ.off or SpellRanks.Off() then return end
    local list, cost = SpellRanks.NewAt(level)
    if #list == 0 then return end
    local items = {}
    for _, item in ipairs(list) do
        items[#items + 1] = { name = item.name, id = item.id, icon = item.icon, pet = item.pet }
    end
    local sub = L.LEVEL .. " " .. level
    if cost > 0 then sub = sub .. "  ·  " .. coins(cost) end
    showToast(#items == 1 and L.SPELL_TOAST_ONE or L.SPELL_TOAST_MANY, sub, items, true)
end

local function barItems(list)
    local items = {}
    for _, item in ipairs(list) do
        items[#items + 1] = { name = item.name, id = item.id, icon = item.icon, pickup = true,
            hint = item.fresh and L.SPELL_BARS_PICK_NEW or L.SPELL_BARS_PICK:format(item.have) }
    end
    return items
end

local dismissed
local announced = {}

local function barsSig(list)
    local sig = {}
    for _, item in ipairs(list) do sig[#sig + 1] = item.name .. item.have end
    return table.concat(sig, ",")
end

local function hideBars()
    if toast and toast:IsShown() and toast.kind == "bars" then hideToast() end
end

local slotBuf = {}
local function slotsSig()
    wipe(slotBuf)
    slotBuf[1] = GetBonusBarOffset and GetBonusBarOffset() or 0
    slotBuf[2] = gen
    slotBuf[3] = FDJ.char and FDJ.char.freshSpells and next(FDJ.char.freshSpells) and 1 or 0
    for slot = 1, 180 do
        local what, id = GetActionInfo(slot)
        if what then
            slotBuf[#slotBuf + 1] = slot
            slotBuf[#slotBuf + 1] = what
            slotBuf[#slotBuf + 1] = id or 0
        end
    end
    return table.concat(slotBuf, ":")
end
local lastSig, lastList

local missingSince, retryPending = {}, false
local BAR_GRACE = 5

local function settled(list, force)
    local now, ready, wait, seen = GetTime(), {}, nil, {}
    for _, item in ipairs(list) do
        local key = item.name .. item.have
        seen[key] = true
        local since = missingSince[key]
        if not since then
            since = now
            missingSince[key] = now
        end
        if force or now - since >= BAR_GRACE then
            ready[#ready + 1] = item
        else
            local left = BAR_GRACE - (now - since)
            wait = wait and math.min(wait, left) or left
        end
    end
    for key in pairs(missingSince) do
        if not seen[key] then missingSince[key] = nil end
    end
    if wait and not retryPending then
        retryPending = true
        C_Timer.After(wait + 0.1, function()
            retryPending = false
            if SpellRanks.SafeSync then SpellRanks.SafeSync() end
        end)
    end
    return ready
end

local function syncBars(force)
    if SpellRanks.Off() or (not force and (not (FDJ.opt and FDJ.opt.spellBars ~= false) or FDJ.off)) then
        hideBars()
        return false
    end
    local sig = GetActionInfo and slotsSig()
    local list
    if sig and sig == lastSig and lastList and not force then
        list = lastList
    else
        list = SpellRanks.Missing()
        lastSig, lastList = sig, list
    end
    if #list == 0 then
        wipe(missingSince)
        dismissed = nil
        hideBars()
        return false
    end
    list = settled(list, force)
    if #list == 0 then
        hideBars()
        return false
    end
    if barsSig(list) == dismissed then return true end
    if toast and toast:IsShown() and toast.kind ~= "bars" then return true end
    local refresh = toast and toast:IsShown() and toast.kind == "bars"
    showToast(L.SPELL_BARS_TITLE, L.SPELL_TOAST_DRAG, barItems(list), false, { sticky = true, kind = "bars", quiet = refresh })
    local newOnes = {}
    for _, item in ipairs(list) do
        local key = item.name .. item.have
        if not announced[key] then
            announced[key] = true
            local link = item.id and C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(item.id)
            if item.fresh then
                newOnes[#newOnes + 1] = link or FDJ.Hi(item.name)
            else
                say(L.SPELL_BARS_CHAT:format(link or FDJ.Hi(item.name), item.have))
            end
        end
    end
    if #newOnes == 1 then
        say(L.SPELL_BARS_CHAT_NEW:format(newOnes[1]))
    elseif #newOnes > 1 then
        local shown = {}
        for i = 1, math.min(#newOnes, 4) do shown[i] = newOnes[i] end
        local more = #newOnes > 4 and (" " .. L.SPELL_TOAST_MORE:format(#newOnes - 4)) or ""
        say(L.SPELL_BARS_CHAT_MANY:format(table.concat(shown, ", ") .. more))
    end
    return true
end
SpellRanks.SyncBars = syncBars

function SpellRanks.DismissBars()
    local list = SpellRanks.Missing()
    dismissed = #list > 0 and barsSig(list) or nil
end

local waitCombat
local function inCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local function safeSync()
    if inCombat() then
        waitCombat = true
        return
    end
    local ok, err = pcall(syncBars)
    if not ok then say("|cffff5555bar check failed:|r " .. tostring(err)) end
end
SpellRanks.SafeSync = safeSync

FDJ:On("PLAYER_REGEN_ENABLED", function()
    if waitCombat then
        waitCombat = nil
        FDJ.Debounce("spellbars", 3, safeSync)
    end
end)

function SpellRanks.CheckBars()
    if inCombat() then
        waitCombat = true
        return
    end
    dismissed = nil
    wipe(announced)
    local ok, shown = pcall(syncBars, true)
    if not ok then
        say("|cffff5555bar check failed:|r " .. tostring(shown))
    elseif not shown then
        say(L.SPELL_BARS_OK)
    end
end

FDJ:On("ADDON_LOADED", function(name)
    if BOOK_ADDONS[name] then findFrames() end
end)
FDJ:On("PLAYER_LOGIN", function()
    findFrames()
    if ToggleSpellBook and not FDJ.GamepadUI() then hooksecurefunc("ToggleSpellBook", findFrames) end
end)
FDJ:On("TRAINER_SHOW", function() C_Timer.After(0.1, scanTrainer) end)
FDJ:On("TRAINER_UPDATE", function()
    if not scanning then FDJ.Debounce("spellscan", 0.3, scanTrainer) end
end)
FDJ:On("SPELLS_CHANGED", function()
    if panel and panel:IsShown() and not inCombat() then FDJ.Debounce("spellranks", 0.3, SpellRanks.Refresh) end
end)
FDJ:On("PET_BAR_UPDATE", function() FDJ.Debounce("spellranks", 0.3, SpellRanks.Refresh) end)
FDJ:On("UNIT_PET", function(unit)
    if unit == "player" then FDJ.Debounce("spellranks", 0.5, SpellRanks.Refresh) end
end)
local function learned(id)
    C_Timer.After(0.5, function() pcall(SpellRanks.NoteLearned, id) end)
end

FDJ:On("LEARNED_SPELL_IN_TAB", function(id)
    learned(id)
    FDJ.Debounce("spellranks", 0.3, SpellRanks.Refresh)
    FDJ.Debounce("spellbars", 1.5, safeSync)
end)
FDJ:On("PLAYER_LEVEL_UP", function(level)
    FDJ.Debounce("spellranks", 0.5, SpellRanks.Refresh)
    level = tonumber(level)
    if level then C_Timer.After(2.5, function() levelToast(level) end) end
end)
FDJ:On("LEARNED_SPELL_IN_SKILL_LINE", function(id)
    learned(id)
    FDJ.Debounce("spellbars", 1.5, safeSync)
end)
FDJ:On("SPELLS_CHANGED", function()
    if inCombat() then return end
    bump()
    FDJ.Debounce("spellbars", 1.5, safeSync)
end)
FDJ:On("SPELL_TEXT_UPDATE", function()
    if not inCombat() then FDJ.Debounce("spelltext", 2, bump) end
end)
for _, event in ipairs({ "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "UNIT_PET", "PET_BAR_UPDATE" }) do
    FDJ:On(event, bump)
end
FDJ:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(4, safeSync) end)
FDJ:On("UPDATE_MACROS", function()
    wipe(macroCache)
    bump()
    if not inCombat() then FDJ.Debounce("spellbars", 0.5, safeSync) end
end)
FDJ:On("ACTIONBAR_SLOT_CHANGED", function(slot)
    if inCombat() then return end
    if panel and panel:IsShown() then FDJ.Debounce("spellranks", 0.4, SpellRanks.Refresh) end
    FDJ.Debounce("spellbars", 0.3, safeSync)
end)
for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_LEVEL_UP",
    "PET_BAR_UPDATE", "UNIT_PET", "ACTIONBAR_SLOT_CHANGED", "PLAYER_MONEY", "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED" }) do
    FDJ:On(event, function() stale = true end)
end
FDJ:On("PLAYER_MONEY", function()
    if panel and panel:IsShown() then FDJ.Debounce("spellranks", 0.4, SpellRanks.Refresh) end
end)

local talentCard, talentHidden
local lastLevelUp, lastUnspent = 0, nil

local function unspentTalents()
    if C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints then
        local ok, has, a, b = pcall(C_ClassTalents.HasUnspentTalentPoints)
        if ok and has ~= nil then
            if not has then return 0 end
            local n = (tonumber(a) or 0) + (tonumber(b) or 0)
            return n > 0 and n or 1
        end
    end
    if UnitCharacterPoints then
        local n = UnitCharacterPoints("player")
        return tonumber(n) or 0
    end
    return 0
end

local function maxLevel()
    local cap = GetMaxPlayerLevel and GetMaxPlayerLevel()
    return (type(cap) == "number" and cap > 0) and cap or 60
end

local function openTalents()
    if InCombatLockdown() then return end
    if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentOrSpecFrame then
        PlayerSpellsUtil.ToggleClassTalentOrSpecFrame()
    elseif ToggleTalentFrame then
        ToggleTalentFrame()
    end
end

local function talentIcon()
    if GetTalentTabInfo then
        local spec = FojjiCore and ((FojjiCore.GetCachedSpec and FojjiCore.GetCachedSpec()) or (FojjiCore.GetSpec and FojjiCore.GetSpec()))
        local markers = FojjiCore and FojjiCore.SpecMarkers and FojjiCore.SpecMarkers[classKey()] or {}
        for i, m in ipairs(markers) do
            if spec and m[1] == spec.key then
                local r = { pcall(GetTalentTabInfo, i) }
                local tex = r[1] and (type(r[2]) == "number" and r[5] or r[3])
                if tex then return tex end
            end
        end
    end
    return 132222
end

local function buildCard(spec)
    local f = CreateFrame("Button", spec.name, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:RegisterForClicks("LeftButtonUp")
    FDJ.SyncTheme()
    Kit.Fill(f, C.frame, 0.94)
    Kit.Edge(f, C.border)
    local shine = Kit.Gradient(f, "VERTICAL", C.accent, 0, 0.14, "BORDER")
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", -1, 1)
    local stripe = f:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    stripe:SetHeight(2)
    Kit.Paint(stripe, C.accent)
    f.title = Kit.Text(f, "small", C.white, "CENTER")
    f.title:SetPoint("TOP", 0, -8)
    f.sub = Kit.Text(f, "tiny", C.muted, "CENTER")
    f.sub:SetPoint("BOTTOM", 0, 7)
    f.sub:SetText(spec.sub)

    local b = CreateFrame("Frame", nil, f)
    b:SetSize(TOAST_ICON, TOAST_ICON)
    b:SetPoint("TOP", 0, -28)
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(TOAST_ICON * 1.9, TOAST_ICON * 1.9)
    b.glow:SetTexture(FDJ.Glyph("fc:badge-glow"))
    b.glow:SetBlendMode("ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    if b.CreateMaskTexture then
        local mask = b:CreateMaskTexture()
        mask:SetAllPoints(b.icon)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        b.icon:AddMaskTexture(mask)
    else
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetAllPoints()
    b.ring:SetTexture(FDJ.Glyph("fc:badge-ring"))
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(18, 18)
    b.badge:SetPoint("BOTTOMRIGHT", 5, -3)
    Kit.Fill(b.badge, C.accent, 1)
    Kit.Edge(b.badge, C.frame)
    b.count = Kit.Text(b.badge, "tiny", C.white, "CENTER")
    b.count:SetPoint("CENTER", 0, 0)
    f.badge = b

    local close = CreateFrame("Button", nil, f)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -4, -5)
    close:SetFrameLevel(f:GetFrameLevel() + 10)
    close:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    close:SetHighlightTexture("Interface\\Buttons\\UI-StopButton", "ADD")
    close:GetNormalTexture():SetVertexColor(1, 0.25, 0.25)
    close:SetScript("OnClick", function()
        spec.onClose()
        f:Hide()
    end)
    f:SetScript("OnClick", spec.onClick)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint(1)
        if FDJ.db then FDJ.db.window[spec.posKey] = { point, rel, x, y } end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(spec.tip, 1, 1, 1)
        GameTooltip:AddLine(spec.hint, C.muted[1], C.muted[2], C.muted[3], true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", Kit.HideTip)
    if spec.secure then SpellRanks.SecureOpen(f, spec.secure) end
    f.pop = b:CreateAnimationGroup()
    local fade = f.pop:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.25)
    f.pop:SetScript("OnFinished", function() b:SetAlpha(1) end)
    f:Hide()
    return f
end

local function buildTalentCard()
    return buildCard({
        name = "FojjiCoreTalentReminder", posKey = "talentCard", secure = "talents",
        sub = L.TALENT_CARD_SUB, tip = L.TALENT_CARD_TIP, hint = L.TALENT_CARD_HINT,
        onClose = function() talentHidden = unspentTalents() end,
        onClick = function() if not SpellRanks.HasOpener("talents") then openTalents() end end,
    })
end

local function placeTalentCard(f)
    f:ClearAllPoints()
    if FDJ.db and FDJ.db.window.talentCardV ~= 2 then
        FDJ.db.window.talentCard = nil
        FDJ.db.window.talentCardV = 2
    end
    local spot = FDJ.db and FDJ.db.window.talentCard
    if spot then
        f:SetPoint(spot[1], UIParent, spot[2], spot[3], spot[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 200, -110)
    end
end

local function trackRespec(n)
    if not FDJ.char then return end
    if n == 0 then
        FDJ.char.talentQuiet = nil
    elseif lastUnspent and n > lastUnspent and GetTime() - lastLevelUp > 5 then
        FDJ.char.talentQuiet = true
    end
    lastUnspent = n
end

function SpellRanks.UpdateTalents(preview)
    if InCombatLockdown() and not preview then return end
    local on = FDJ.opt and FDJ.opt.talentReminder ~= false and not FDJ.off and not SpellRanks.Off()
    local n = preview and 2 or unspentTalents()
    if not preview then trackRespec(n) end
    if talentHidden and n > talentHidden then talentHidden = nil end
    if n == 0 then talentHidden = nil end
    local quiet = FDJ.char and FDJ.char.talentQuiet
    local show = preview or (on and n > 0 and not talentHidden and not quiet and not InCombatLockdown()
        and (UnitLevel("player") or 1) < maxLevel())
    if not show then
        if talentCard then talentCard:Hide() end
        return
    end
    local fresh = not (talentCard and talentCard:IsShown())
    if not talentCard then talentCard = buildTalentCard() end
    FDJ.SyncTheme()
    talentCard.title:SetText(n == 1 and L.TALENT_CARD_ONE or L.TALENT_CARD_MANY:format(n))
    talentCard.badge.icon:SetTexture(talentIcon())
    talentCard.badge.count:SetText(tostring(n))
    local width = math.max(170, talentCard.title:GetUnboundedStringWidth() + 48, talentCard.sub:GetUnboundedStringWidth() + 24)
    talentCard:SetSize(width, 28 + TOAST_ICON + 26)
    placeTalentCard(talentCard)
    talentCard:Show()
    if fresh then
        talentCard.badge:SetAlpha(0)
        talentCard.pop:Play()
    end
end

local talentsWaiting
local function talentsChanged()
    if InCombatLockdown() then
        talentsWaiting = true
        return
    end
    FDJ.Debounce("talentcard", 0.5, function() SpellRanks.UpdateTalents() end)
end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "CHARACTER_POINTS_CHANGED",
    "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_TALENT_UPDATE" }) do
    FDJ:On(event, talentsChanged)
end
FDJ:On("PLAYER_REGEN_ENABLED", function()
    if talentsWaiting then
        talentsWaiting = nil
        talentsChanged()
    end
end)
FDJ:On("PLAYER_LEVEL_UP", function()
    lastLevelUp = GetTime()
    talentsChanged()
end)
FDJ:On("PLAYER_REGEN_DISABLED", function()
    if talentCard and talentCard:IsShown() then
        talentCard:Hide()
        talentsWaiting = true
    end
end)

Addon.SpellQoL = {
    BarsOn = function() return not FDJ.opt or FDJ.opt.spellBars ~= false end,
    SetBars = function(on)
        if FDJ.opt then FDJ.opt.spellBars = on and true or false end
        if SpellRanks.SyncBars then pcall(SpellRanks.SyncBars) end
    end,
    CheckBars = function() SpellRanks.CheckBars() end,
    TalentsOn = function() return not FDJ.opt or FDJ.opt.talentReminder ~= false end,
    SetTalents = function(on)
        if FDJ.opt then FDJ.opt.talentReminder = on and true or false end
        SpellRanks.UpdateTalents()
    end,
    PreviewTalents = function() SpellRanks.UpdateTalents(true) end,
}

function Addon.CreateSpellRanksPage(page, UI)
    FDJ.SyncTheme()
    local COLW = 300
    local scroll = UI.Scroll(page)
    scroll:SetPoint("TOPLEFT", 0, -50)
    scroll:SetPoint("BOTTOMRIGHT", -18, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(640, 600)
    scroll:SetScrollChild(body)
    scroll:SetScript("OnSizeChanged", function(_, width) body:SetWidth(width) end)

    local y = 0
    local function Section(title)
        y = y + 12
        local label = UI.Text(body, title, 12, "accent")
        label:SetPoint("TOPLEFT", 0, -y)
        local line = UI.Texture(body, "ARTWORK", "borderDim")
        line:SetPoint("TOPLEFT", 0, -(y + 17))
        line:SetPoint("TOPRIGHT", 0, -(y + 17))
        line:SetHeight(1)
        y = y + 26
    end
    local function Note(text, height)
        local t = UI.Text(body, text, 10, "dim")
        t:SetPoint("TOPLEFT", 0, -y)
        t:SetWidth(COLW * 2)
        t:SetJustifyH("LEFT")
        t:SetWordWrap(true)
        t:SetHeight(height or 28)
        y = y + (height or 28) + 8
        return t
    end

    local function option(key, text)
        local b = UI.Checkbox(body, text, function(value)
            if FDJ.opt then FDJ.opt[key] = value and true or false end
            if key == "spellBars" and SpellRanks.SyncBars then pcall(SpellRanks.SyncBars) end
            if key == "talentReminder" then SpellRanks.UpdateTalents() end
            if key == "talentTemplates" and SpellRanks.Talents and SpellRanks.Talents.Panel then SpellRanks.Talents.Panel.Apply() end
        end)
        b:SetWidth(COLW * 2)
        b:SetPoint("TOPLEFT", 0, -y)
        y = y + 30
        return b
    end
    local function buttons(...)
        local x = 0
        for _, def in ipairs({ ... }) do
            local btn = UI.Button(body, def[1], 200)
            btn:SetPoint("TOPLEFT", x, -y)
            btn:SetScript("OnClick", def[2])
            if def.secure then SpellRanks.SecureOpen(btn, def.secure, def.after) end
            x = x + 210
        end
        y = y + 40
    end

    Section(L.SR_TITLE)
    local offBox = UI.Checkbox(body, L.SR_OPT_DISABLE, function(value)
        if FDJ.opt then FDJ.opt.spellsOff = value and true or nil end
        if value then
            if panel then panel:Hide() tab:Hide() end
            if talentCard then talentCard:Hide() end
            hideToast()
        elseif host and host:IsShown() then
            attach(host)
        end
        pcall(SpellRanks.SyncBars)
        SpellRanks.UpdateTalents()
        FDJ:Emit("FDJ_OPTION", "spellRanks")
    end)
    offBox:SetWidth(COLW * 2)
    offBox:SetPoint("TOPLEFT", 0, -y)
    y = y + 34

    Section(L.SR_SEC_RANKS)
    local box = UI.Checkbox(body, L.OPT_SPELL_RANKS, function(value) SpellRanks.SetEnabled(value, true) end)
    box:SetWidth(COLW * 2)
    box:SetPoint("TOPLEFT", 0, -y)
    y = y + 30
    local toastBox = option("spellToast", L.OPT_SPELL_TOAST)
    local function closeCore()
        local core = _G.FojjiCoreOptionsFrame
        if core and core:IsShown() then core:Hide() end
    end
    buttons({ L.SPELL_OPEN_BOOK, secure = "book", after = closeCore, function()
        if InCombatLockdown() or SpellRanks.HasOpener("book") then return end
        closeCore()
        if FDJ.GamepadUI() then return end
        local util = _G.PlayerSpellsUtil
        if util and util.OpenToSpellBookTab then util.OpenToSpellBookTab()
        elseif util and util.ToggleSpellBookFrame then util.ToggleSpellBookFrame()
        elseif ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell")
        elseif TogglePlayerSpellsFrame then TogglePlayerSpellsFrame() end
    end }, { L.SPELL_TOAST_PREVIEW, function()
        local level = FDJ.Level()
        local list, cost = SpellRanks.NewAt(level)
        if #list == 0 then list, cost = SpellRanks.NewAt(level + (level % 2 == 0 and 2 or 1)) end
        local items = {}
        for _, item in ipairs(list) do items[#items + 1] = item end
        if #items == 0 then
            for _, id in ipairs({ 133, 116, 6673, 1126, 172 }) do
                local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
                if name then items[#items + 1] = { name = name, id = id, icon = C_Spell.GetSpellTexture(id) } end
            end
        end
        SpellRanks.ShowToast(#items == 1 and L.SPELL_TOAST_ONE or L.SPELL_TOAST_MANY, L.LEVEL .. " " .. level .. (cost > 0 and ("  ·  " .. coins(cost)) or ""), items, true)
    end })

    Section(L.SR_SEC_TALENTS)
    local talentBox = option("talentReminder", L.OPT_TALENT_REMINDER)
    local templatesBox = option("talentTemplates", L.OPT_TALENT_TEMPLATES)
    local talentPanel = SpellRanks.Talents and SpellRanks.Talents.Panel
    if talentPanel then
        buttons({ L.TALENT_PREVIEW, function() SpellRanks.UpdateTalents(true) end },
            { L.TAL_SECTION, function() talentPanel.Toggle() end })
    else
        buttons({ L.TALENT_PREVIEW, function() SpellRanks.UpdateTalents(true) end })
    end

    Section(L.SR_SEC_BARS)
    local barsBox = option("spellBars", L.OPT_SPELL_BARS)
    buttons({ L.SPELL_BARS_CHECK, function() SpellRanks.CheckBars() end })
    Note(L.SPELL_REMIND_NOTE, 14)
    local listTop = y
    local emptyNote = UI.Text(body, L.SPELL_REMIND_EMPTY, 10, "dim")
    emptyNote:SetPoint("TOPLEFT", 0, -listTop)
    local spellRows = {}
    local function spellRow(i)
        local row = spellRows[i]
        if row then return row end
        row = UI.Checkbox(body, "", function(value)
            if not row.spell then return end
            if value then SpellRanks.Unignore(row.spell) else SpellRanks.Ignore(row.spell, nil, true) end
        end)
        row:SetWidth(COLW - 10)
        spellRows[i] = row
        return row
    end
    local function layoutIgnored()
        local list = SpellRanks.ClassSpells()
        emptyNote:SetShown(#list == 0)
        local half = math.ceil(#list / 2)
        for i, item in ipairs(list) do
            local row = spellRow(i)
            row.spell = item.name
            local icon = item.icon and ("|T" .. item.icon .. ":16:16:0:0:64:64:5:59:5:59|t  ") or ""
            row.label:SetText(icon .. (item.known and item.name or ("|cff808080" .. item.name .. "|r")))
            row:SetChecked(not item.ignored)
            local col, line = (i <= half) and 0 or 1, (i <= half) and (i - 1) or (i - half - 1)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", col * COLW, -(listTop + line * 26))
            row:Show()
        end
        for i = #list + 1, #spellRows do spellRows[i]:Hide() end
        body:SetHeight(listTop + math.max(half, 1) * 26 + 30)
    end

    local function refresh()
        offBox:SetChecked(SpellRanks.Off())
        box:SetChecked(not FDJ.opt or FDJ.opt.spellRanks ~= false)
        toastBox:SetChecked(not FDJ.opt or FDJ.opt.spellToast ~= false)
        barsBox:SetChecked(not FDJ.opt or FDJ.opt.spellBars ~= false)
        talentBox:SetChecked(not FDJ.opt or FDJ.opt.talentReminder ~= false)
        templatesBox:SetChecked(not FDJ.opt or FDJ.opt.talentTemplates ~= false)
        layoutIgnored()
    end
    page:HookScript("OnShow", refresh)
    FDJ:On("FDJ_OPTION", function(key)
        if (key == "spellRanks" or key == "barsIgnore") and page:IsVisible() then refresh() end
    end)
    refresh()
end
