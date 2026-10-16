local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end
if not Addon.ForeverClient then return end
local AuraAPI = Addon.AuraAPI or ForeverAuras or WeakAuras

FojjiCore = FojjiCore or {}
local RP = FojjiCore.RaidPacks or {}
FojjiCore.RaidPacks = RP

RP.API_VERSION = 1
RP.packs = RP.packs or {}
RP.callbacks = RP.callbacks or {}
RP.demo = RP.demo or {}

RP.FIELDS = {
    label = "",
    timer = true,
    emphasize = false,
    emphasizeAt = 10,
    ttsCountdown = false,
    countdownFrom = 5,
    barColor = false,
    emphColor = false,
    prewarn = false,
    pwStyle = "text",
    pwt = 4,
    pwAudioAt = 4,
    pwText = "",
    ttsPrewarn = false,
    pwAudio = 1,
    pwSoundFile = "",
    ttsPrewarnText = "",
    alert = false,
    style = "bar",
    alertText = "",
    tts = false,
    castAudio = 1,
    castSoundFile = "",
    ttsText = "",
    roleOnly = true,
    tauntText = "",
    circle = false,
    active = false,
    cast = false,
    castStyle = "castbar",
    castText = "",
    endAudio = false,
    endAudioMode = 1,
    endSoundFile = "",
    endTtsText = "",
}

RP.LOOKS = {
    alert = {
        { key = "bar", name = "Bar" },
        { key = "text", name = "Text" },
        { key = "icon", name = "Icon" },
        { key = "largeicon", name = "Large icon" },
    },
    prewarn = {
        { key = "text", name = "Text" },
        { key = "circle", name = "Circle" },
        { key = "bar", name = "Bar" },
        { key = "icon", name = "Icon" },
        { key = "largeicon", name = "Large icon" },
    },
    cast = {
        { key = "castbar", name = "Cast bar" },
        { key = "bar", name = "Bar" },
        { key = "icon", name = "Icon" },
        { key = "largeicon", name = "Large icon" },
    },
}

RP.LOOK_FIELDS = {
    style = "alert",
    pwStyle = "prewarn",
    castStyle = "cast",
}

RP.OLD_LOOKS = {
    alert = { "bar", "text", "bar,text" },
    prewarn = { "text", "circle", "text,circle", "bar" },
    cast = { "bar", "castbar" },
}

RP.GLOBAL_FIELDS = {
    emphasizeAll = false,
    showUnknown = true,
    autoDiscover = true,
    demoLength = 90,
    debuffSounds = true,
    soundChannel = "Master",
    barColorMode = 2,
    barColor = { 0.247, 0.565, 1.00 },
    typeColors = false,
    emphColorMode = 2,
    emphColor = { 1.00, 0.275, 0.333 },
    autoGossip = true,
    skipCinematics = true,
}

RP.TYPES = {
    { key = "TANK", name = "Tank", color = { 0.30, 0.52, 0.95 } },
    { key = "DAMAGE", name = "Raid damage", color = { 0.92, 0.30, 0.30 } },
    { key = "MOVEMENT", name = "Movement", color = { 0.92, 0.72, 0.22 } },
    { key = "SOAK", name = "Soak", color = { 0.45, 0.88, 0.45 } },
    { key = "ADDS", name = "Adds", color = { 0.72, 0.42, 0.95 } },
    { key = "PHASE", name = "Phase", color = { 0.30, 0.85, 0.90 } },
    { key = "MECHANIC", name = "Mechanic", color = { 0.95, 0.52, 0.22 } },
    { key = "UNKNOWN", name = "Unknown", color = { 0.62, 0.64, 0.68 } },
}

RP.DEBUFF_FIELDS = {
    enabled = true,
    sound = "cue:Debuff",
    text = "",
}

local function store(pack)
    FojjiCoreDB = FojjiCoreDB or {}
    FojjiCoreDB.raidPacks = FojjiCoreDB.raidPacks or {}
    local s = FojjiCoreDB.raidPacks[pack]
    if not s then
        s = {}
        FojjiCoreDB.raidPacks[pack] = s
    end
    s.overrides = s.overrides or {}
    s.global = s.global or {}
    s.discovered = s.discovered or {}
    if (s.looks or 0) < 2 then
        local function parts(v)
            local t = {}
            if type(v) == "string" then for part in v:gmatch("[^,%s]+") do t[#t + 1] = part end end
            return t
        end
        for _, o in pairs(s.overrides) do
            if type(o) == "table" then
                for field, moment in pairs(RP.LOOK_FIELDS) do
                    if type(o[field]) == "number" then o[field] = RP:NormalizeLook(moment, o[field]) end
                end
                if (s.looks or 0) >= 1 then
                    for field in pairs(RP.LOOK_FIELDS) do
                        if type(o[field]) == "string" then
                            local t = parts(o[field])
                            for i, part in ipairs(t) do if part == "icon" then t[i] = "largeicon" end end
                            o[field] = table.concat(t, ",")
                        end
                    end
                end
                if o.pwt ~= nil and o.pwAudioAt == nil then o.pwAudioAt = o.pwt end
            end
        end
        s.looks = 2
    end
    return s
end

local function notify(reason, pack)
    for _, fn in ipairs(RP.callbacks) do
        local ok, err = pcall(fn, reason, pack)
        if not ok and Addon.Print then Addon.Print("Raid pack callback error: " .. tostring(err)) end
    end
end

function RP:RegisterCallback(fn)
    self.callbacks[#self.callbacks + 1] = fn
end

local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function ensurePack(pack, info)
    local p = RP.packs[pack]
    if not p then
        p = { key = pack, bosses = {}, bossOrder = {}, abilities = {}, debuffs = {} }
        RP.packs[pack] = p
    end
    if info then
        p.name = info.packName or p.name or pack
        p.version = info.packVersion or p.version
        p.root = info.root or p.root
        p.eventPrefix = info.eventPrefix or p.eventPrefix or "WA_FJI"
        p.instance = info.instance or p.instance
        if info.globals then p.globalDefaults = info.globals end
        if info.gossip then p.gossip = info.gossip end
    end
    return p
end

function RP:GetLooks(moment)
    return self.LOOKS[moment] or {}
end

function RP:RegisterLook(moment, key, name)
    local list = self.LOOKS[moment]
    if not list or type(key) ~= "string" or key == "" or key:find("[,%s]") then return false end
    for _, look in ipairs(list) do
        if look.key == key then
            look.name = name or look.name
            return true
        end
    end
    list[#list + 1] = { key = key, name = name or key, custom = true }
    return true
end

function RP:NormalizeLook(moment, value)
    if type(value) == "number" then
        value = self.OLD_LOOKS[moment] and self.OLD_LOOKS[moment][value]
    end
    if type(value) ~= "string" or value == "" then
        return self.FIELDS[(moment == "alert" and "style") or (moment == "prewarn" and "pwStyle") or "castStyle"]
    end
    local wanted, order = {}, {}
    for part in value:gmatch("[^,%s]+") do
        if not wanted[part] then
            wanted[part] = true
            order[#order + 1] = part
        end
    end
    local out = {}
    for _, look in ipairs(self.LOOKS[moment] or {}) do
        if wanted[look.key] then
            out[#out + 1] = look.key
            wanted[look.key] = nil
        end
    end
    for _, part in ipairs(order) do
        if wanted[part] then out[#out + 1] = part end
    end
    return table.concat(out, ",")
end

function RP:LookName(moment, value)
    local names = {}
    for part in self:NormalizeLook(moment, value):gmatch("[^,]+") do
        local name = part
        for _, look in ipairs(self.LOOKS[moment] or {}) do
            if look.key == part then name = look.name end
        end
        names[#names + 1] = name
    end
    return table.concat(names, " + ")
end

local function normalizeDefaults(defaults)
    local d = {}
    for field, fallback in pairs(RP.FIELDS) do
        local v = defaults and defaults[field]
        if v == nil then v = fallback end
        d[field] = copy(v)
    end
    for field, moment in pairs(RP.LOOK_FIELDS) do
        d[field] = RP:NormalizeLook(moment, d[field])
    end
    return d
end

function RP:RegisterPack(pack, info)
    local p = ensurePack(pack, info)
    p.dynamic = true
    local s = store(pack)
    s.knownBosses = s.knownBosses or {}
    local list = {}
    for key, b in pairs(s.knownBosses) do list[#list + 1] = { key = key, b = b } end
    table.sort(list, function(a, b) return (a.b.order or 99) < (b.b.order or 99) end)
    for _, e in ipairs(list) do
        if not p.bosses[e.key] then
            self:RegisterBoss(pack, { boss = e.key, bossName = e.b.name, encounterID = e.b.encounterID, order = e.b.order,
                abilities = {}, dynamic = true, restoring = true })
        end
    end
    notify("register", pack)
end

function RP:IsEncounterClaimed(encounterID, exceptPack, encounterName)
    for key, p in pairs(self.packs) do
        for _, b in pairs(p.bosses) do
            if not b.dynamic and (key ~= exceptPack or b.matchName) then
                if b.encounterID == encounterID and encounterID and encounterID > 0 then return true end
                if encounterName and b.matchName and b.matchName == encounterName then return true end
            end
        end
    end
    return false
end

local function bakedMap(pack, bossKey)
    local p = RP.packs[pack]
    local b = p and p.bosses[bossKey]
    return b and b.durationMap
end

function RP:SetDurationMap(pack, bossKey, seconds, abilityKey)
    if not bossKey or not seconds then return end
    local s = store(pack)
    s.durationMap = s.durationMap or {}
    s.durationMap[bossKey] = s.durationMap[bossKey] or {}
    local baked = bakedMap(pack, bossKey)
    baked = baked and baked[seconds]
    if abilityKey == baked then
        s.durationMap[bossKey][seconds] = nil
    elseif abilityKey == nil and baked then
        s.durationMap[bossKey][seconds] = false
    else
        s.durationMap[bossKey][seconds] = abilityKey
    end
    notify("set", pack)
end

function RP:GetDurationMap(pack, bossKey, seconds)
    local s = FojjiCoreDB and FojjiCoreDB.raidPacks and FojjiCoreDB.raidPacks[pack]
    local m = s and s.durationMap and s.durationMap[bossKey]
    local v = m and m[seconds]
    if v ~= nil then return v or nil end
    local baked = bakedMap(pack, bossKey)
    return baked and baked[seconds]
end

function RP:RegisterBoss(pack, info)
    if type(pack) ~= "string" or type(info) ~= "table" or not info.boss then return false end
    local p = ensurePack(pack, info)
    local s = store(pack)
    local boss = p.bosses[info.boss]
    if not boss then
        boss = { key = info.boss }
        p.bosses[info.boss] = boss
        p.bossOrder[#p.bossOrder + 1] = info.boss
    end
    if info.dynamic then
        s.knownBosses = s.knownBosses or {}
        local known = s.knownBosses[info.boss]
        if not known then
            local n = 0
            for _ in pairs(s.knownBosses) do n = n + 1 end
            known = { order = 100 + n }
            s.knownBosses[info.boss] = known
        end
        known.name = info.bossName or known.name
        known.encounterID = info.encounterID or known.encounterID
        info.order = known.order
        p.dynamic = true
    end
    boss.name = info.bossName or info.boss
    boss.encounterID = info.encounterID
    boss.order = info.order or 99
    boss.icon = info.bossIcon or boss.icon
    boss.matchName = info.matchName
    boss.dynamic = info.dynamic
    boss.durationMap = info.durationMap
    boss.mapID = info.mapID or boss.mapID
    boss.mapX, boss.mapY = info.mapX or boss.mapX, info.mapY or boss.mapY
    boss.debuffs = boss.debuffs or {}
    boss.abilities = {}
    for _, slot in ipairs(info.assignments or {}) do
        if RP.RegisterRaidSlot and type(slot) == "table" then
            local s = copy(slot)
            s.boss = s.boss or info.boss
            RP:RegisterRaidSlot(pack, s)
        end
    end
    table.sort(p.bossOrder, function(a, b)
        return (p.bosses[a].order or 99) < (p.bosses[b].order or 99)
    end)

    local reset = 0
    for _, ab in ipairs(info.abilities or {}) do
        local entry = {
            key = ab.key, boss = info.boss, name = ab.name, spellID = ab.spellID, icon = ab.icon,
            rev = ab.rev or 1, mythic = ab.mythic, role = ab.role,
            fields = ab.fields,
            castTime = ab.castTime or (s.castTimes and s.castTimes[ab.key]),
            kind = ab.kind, discovered = ab.discovered, duration = ab.duration,
            defaults = normalizeDefaults(ab.defaults),
        }
        p.abilities[ab.key] = entry
        boss.abilities[#boss.abilities + 1] = ab.key
        local o = s.overrides[ab.key]
        if o and (o.rev or 1) < entry.rev then
            s.overrides[ab.key] = nil
            reset = reset + 1
        elseif o then
            for field, v in pairs(o) do
                if field ~= "rev" and deepEqual(entry.defaults[field], v) then o[field] = nil end
            end
            local left = false
            for field in pairs(o) do if field ~= "rev" then left = true break end end
            if not left then s.overrides[ab.key] = nil end
        end
    end

    local disc = s.discovered[info.boss]
    if disc then
        for key, d in pairs(disc) do
            if not p.abilities[key] then
                p.abilities[key] = {
                    key = key, boss = info.boss, name = d.name, spellID = d.spellID, icon = d.icon, rev = 1,
                    discovered = true, duration = d.duration, defaults = normalizeDefaults(d.defaults),
                }
                boss.abilities[#boss.abilities + 1] = key
            end
        end
    end

    if reset > 0 and Addon.Print then
        Addon.Print(("%s updated: %d ability setting%s reset to the new defaults."):format(p.name or pack, reset, reset == 1 and "" or "s"))
    end
    if not info.restoring then notify("register", pack) end
    return true
end

function RP:Discover(pack, bossKey, key, info)
    local p = ensurePack(pack)
    local boss = p.bosses[bossKey]
    if not boss or p.abilities[key] then return end
    local defaults = normalizeDefaults(info and info.defaults)
    p.abilities[key] = {
        key = key, boss = bossKey, name = info and info.name or key, spellID = info and info.spellID,
        icon = info and info.icon, rev = 1, discovered = true, duration = info and info.duration, defaults = defaults,
    }
    boss.abilities[#boss.abilities + 1] = key
    local s = store(pack)
    s.discovered[bossKey] = s.discovered[bossKey] or {}
    s.discovered[bossKey][key] = {
        name = info and info.name, spellID = info and info.spellID, icon = info and info.icon, duration = info and info.duration,
        defaults = info and info.defaults, first = date and date("%Y-%m-%d") or nil,
    }
    notify("discover", pack)
end

local function entryOf(p, key)
    if not p then return nil end
    return p.abilities[key] or (p.debuffs and p.debuffs[key])
end

function RP:Get(pack, key, field)
    local s = FojjiCoreDB and FojjiCoreDB.raidPacks and FojjiCoreDB.raidPacks[pack]
    local o = s and s.overrides and s.overrides[key]
    if o and o[field] ~= nil then
        local moment = RP.LOOK_FIELDS[field]
        if moment and type(o[field]) == "number" then return RP:NormalizeLook(moment, o[field]) end
        return o[field]
    end
    local ab = entryOf(self.packs[pack], key)
    if ab then return ab.defaults[field] end
    return nil
end

function RP:SetCastTime(pack, key, seconds)
    if not seconds or seconds <= 0 then return end
    local s = store(pack)
    s.castTimes = s.castTimes or {}
    seconds = math.floor(seconds * 10 + 0.5) / 10
    local ab = entryOf(self.packs[pack], key)
    if s.castTimes[key] == seconds and (not ab or ab.castTime) then return end
    s.castTimes[key] = seconds
    if ab then ab.castTime = ab.castTime or seconds end
    notify("cast", pack)
end

function RP:GetCastTime(pack, key)
    local ab = entryOf(self.packs[pack], key)
    if ab and ab.castTime then return ab.castTime end
    local s = FojjiCoreDB and FojjiCoreDB.raidPacks and FojjiCoreDB.raidPacks[pack]
    return s and s.castTimes and s.castTimes[key]
end

function RP:SetIcon(pack, key, icon)
    local ab = entryOf(self.packs[pack], key)
    if ab and icon and ab.icon ~= icon then
        ab.icon = icon
        notify("icon", pack)
    end
end

function RP:GetGlobalDefault(pack, field)
    local p = self.packs[pack]
    local d = p and p.globalDefaults
    if d and d[field] ~= nil then return d[field] end
    return RP.GLOBAL_FIELDS[field]
end

function RP:GetGlobal(pack, field)
    local s = FojjiCoreDB and FojjiCoreDB.raidPacks and FojjiCoreDB.raidPacks[pack]
    local v = s and s.global and s.global[field]
    if v ~= nil then return v end
    return self:GetGlobalDefault(pack, field)
end

function RP:GetName(pack, key)
    local l = self:Get(pack, key, "label")
    if type(l) == "string" and l ~= "" then return l end
    local ab = entryOf(self.packs[pack], key)
    return ab and ab.name or key
end

function RP:GetKind(pack, key)
    local ab = entryOf(self.packs[pack], key)
    if ab and ab.kind then return ab.kind end
    if ab and ab.discovered then return "UNKNOWN" end
    return ab and "MECHANIC" or "UNKNOWN"
end

function RP:GetTypeColor(pack, kind)
    local t = self:GetGlobal(pack, "typeColors")
    if type(t) == "table" and t[kind] then return t[kind] end
    for _, d in ipairs(RP.TYPES) do if d.key == kind then return d.color end end
    return RP.TYPES[#RP.TYPES].color
end

function RP:SetTypeColor(pack, kind, rgb)
    local cur = self:GetGlobal(pack, "typeColors")
    local t = {}
    if type(cur) == "table" then for k, v in pairs(cur) do t[k] = v end end
    t[kind] = rgb
    self:SetGlobal(pack, "typeColors", t)
end

function RP:GetBarColor(pack, key, emphasized)
    local own = self:Get(pack, key, emphasized and "emphColor" or "barColor")
    if type(own) == "table" then return own end
    if emphasized and self:GetGlobal(pack, "emphColorMode") == 2 then return self:GetGlobal(pack, "emphColor") end
    if emphasized then
        local base = self:Get(pack, key, "barColor")
        if type(base) == "table" then return base end
    end
    local mode = self:GetGlobal(pack, "barColorMode")
    if mode == 2 then return self:GetGlobal(pack, "barColor") end
    if mode == 3 then return self:GetTypeColor(pack, self:GetKind(pack, key)) end
    return nil
end

function RP:GetDefault(pack, key, field)
    local ab = entryOf(self.packs[pack], key)
    return ab and ab.defaults[field]
end

function RP:Set(pack, key, field, value)
    if RP.LOOK_FIELDS[field] then value = RP:NormalizeLook(RP.LOOK_FIELDS[field], value) end
    local s = store(pack)
    local ab = entryOf(self.packs[pack], key)
    local o = s.overrides[key]
    if ab and deepEqual(ab.defaults[field], value) then
        if o then
            o[field] = nil
            local empty = true
            for k in pairs(o) do if k ~= "rev" then empty = false break end end
            if empty then s.overrides[key] = nil end
        end
    else
        if not o then
            o = { rev = ab and ab.rev or 1 }
            s.overrides[key] = o
        end
        o[field] = copy(value)
    end
    notify(ab and ab.isDebuff and "debuff" or "set", pack)
end

function RP:CastsMatch(spec, count)
    if type(spec) ~= "string" or not count then return false end
    for part in spec:gmatch("[^,%s]+") do
        part = part:lower()
        local a, b = part:match("^(%d+)%-(%d+)$")
        local from = part:match("^(%d+)%+$")
        if part == "odd" and count % 2 == 1 then return true end
        if part == "even" and count % 2 == 0 then return true end
        if a and count >= tonumber(a) and count <= tonumber(b) then return true end
        if from and count >= tonumber(from) then return true end
        if tonumber(part) == count then return true end
    end
    return false
end

function RP:CleanCasts(text)
    local parts = {}
    for part in tostring(text or ""):lower():gmatch("[^,%s]+") do
        local ok = part:match("^%d+$") or part:match("^%d+%-%d+$") or part:match("^%d+%+$") or part == "odd" or part == "even"
        if not ok then return nil end
        parts[#parts + 1] = part
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ",")
end

function RP:CastsLabel(spec)
    spec = tostring(spec or ""):gsub("%s+", "")
    if spec == "odd" then return "Odd casts" end
    if spec == "even" then return "Even casts" end
    if spec:match("^%d+$") then return "Cast " .. spec end
    return "Casts " .. spec:gsub(",", ", ")
end

function RP:CastsExample(spec)
    spec = tostring(spec or "")
    if spec:find("even") then return 2 end
    if spec:find("odd") then return 1 end
    return tonumber(spec:match("%d+")) or 1
end

function RP:GetVariants(pack, key)
    local s = FojjiCoreDB and FojjiCoreDB.raidPacks and FojjiCoreDB.raidPacks[pack]
    local o = s and s.overrides and s.overrides[key]
    return o and o.variants or {}
end

function RP:AddVariant(pack, key, casts)
    local s = store(pack)
    local ab = entryOf(self.packs[pack], key)
    local o = s.overrides[key]
    if not o then
        o = { rev = ab and ab.rev or 1 }
        s.overrides[key] = o
    end
    o.variants = o.variants or {}
    for i, v in ipairs(o.variants) do
        if v.casts == casts then return i end
    end
    o.variants[#o.variants + 1] = { casts = casts, set = {} }
    notify("set", pack)
    return #o.variants
end

function RP:RemoveVariant(pack, key, index)
    local list = self:GetVariants(pack, key)
    if not list[index] then return end
    table.remove(list, index)
    local o = store(pack).overrides[key]
    if o and #list == 0 then o.variants = nil end
    if o then
        local empty = true
        for k in pairs(o) do if k ~= "rev" then empty = false break end end
        if empty then store(pack).overrides[key] = nil end
    end
    notify("set", pack)
end

function RP:GetVariantValue(pack, key, index, field)
    local v = self:GetVariants(pack, key)[index]
    if v and v.set[field] ~= nil then
        local moment = RP.LOOK_FIELDS[field]
        if moment then return RP:NormalizeLook(moment, v.set[field]) end
        return v.set[field]
    end
    return self:Get(pack, key, field)
end

function RP:IsVariantSet(pack, key, index, field)
    local v = self:GetVariants(pack, key)[index]
    if not v then return false end
    if field then return v.set[field] ~= nil end
    return next(v.set) ~= nil
end

function RP:SetVariantField(pack, key, index, field, value)
    local v = self:GetVariants(pack, key)[index]
    if not v then return end
    if RP.LOOK_FIELDS[field] then value = RP:NormalizeLook(RP.LOOK_FIELDS[field], value) end
    if value == nil or deepEqual(value, self:Get(pack, key, field)) then
        v.set[field] = nil
    else
        v.set[field] = copy(value)
    end
    notify("set", pack)
end

function RP:GetFor(pack, key, field, count)
    if not count then return nil end
    for _, v in ipairs(self:GetVariants(pack, key)) do
        if v.set[field] ~= nil and self:CastsMatch(v.casts, count) then
            local moment = RP.LOOK_FIELDS[field]
            if moment then return RP:NormalizeLook(moment, v.set[field]) end
            return v.set[field]
        end
    end
    return nil
end

function RP:SetGlobal(pack, field, value)
    local s = store(pack)
    if deepEqual(self:GetGlobalDefault(pack, field), value) then s.global[field] = nil else s.global[field] = copy(value) end
    notify("set", pack)
end

function RP:IsCustomized(pack, key, field)
    local s = FojjiCoreDB and FojjiCoreDB.raidPacks and FojjiCoreDB.raidPacks[pack]
    local o = s and s.overrides and s.overrides[key]
    if not o then return false end
    if field then return o[field] ~= nil end
    for k in pairs(o) do if k ~= "rev" then return true end end
    return false
end

function RP:CountCustomized(pack, bossKey)
    local p = self.packs[pack]
    local n = 0
    if not p then return 0 end
    for key, ab in pairs(p.abilities) do
        if (not bossKey or ab.boss == bossKey) and self:IsCustomized(pack, key) then n = n + 1 end
    end
    return n
end

function RP:ResetAbility(pack, key)
    store(pack).overrides[key] = nil
    notify("reset", pack)
end

function RP:ResetBoss(pack, bossKey, debuffs)
    local p = self.packs[pack]
    if not p then return end
    local s = store(pack)
    for key, ab in pairs(debuffs and p.debuffs or p.abilities) do
        if ab.boss == bossKey then s.overrides[key] = nil end
    end
    notify(debuffs and "debuff" or "reset", pack)
end

function RP:ResetPack(pack)
    local s = store(pack)
    s.overrides = {}
    s.global = {}
    notify("reset", pack)
    notify("debuff", pack)
end

function RP:ForgetDiscovered(pack, bossKey)
    local s = store(pack)
    local p = self.packs[pack]
    for key in pairs(s.discovered[bossKey] or {}) do
        s.overrides[key] = nil
        if p and p.abilities[key] then p.abilities[key] = nil end
    end
    s.discovered[bossKey] = nil
    if p and p.bosses[bossKey] then
        local keep = {}
        for _, key in ipairs(p.bosses[bossKey].abilities) do
            if p.abilities[key] then keep[#keep + 1] = key end
        end
        p.bosses[bossKey].abilities = keep
    end
    notify("reset", pack)
end

function RP:ForgetBoss(pack, bossKey)
    local p = self.packs[pack]
    if not p or not p.dynamic then return end
    self:ForgetDiscovered(pack, bossKey)
    local s = store(pack)
    if s.knownBosses then s.knownBosses[bossKey] = nil end
    p.bosses[bossKey] = nil
    for i, k in ipairs(p.bossOrder) do if k == bossKey then table.remove(p.bossOrder, i) break end end
    notify("reset", pack)
end

function RP:GetPacks()
    local list = {}
    for key, p in pairs(self.packs) do list[#list + 1] = p end
    table.sort(list, function(a, b) return (a.name or a.key) < (b.name or b.key) end)
    return list
end

function RP:GetBosses(pack)
    local p = self.packs[pack]
    local list = {}
    if not p then return list end
    for _, key in ipairs(p.bossOrder) do list[#list + 1] = p.bosses[key] end
    return list
end

function RP:GetAbilities(pack, bossKey)
    local p = self.packs[pack]
    local list = {}
    local boss = p and p.bosses[bossKey]
    if not boss then return list end
    for _, key in ipairs(boss.abilities) do
        if p.abilities[key] then list[#list + 1] = p.abilities[key] end
    end
    return list
end

local MARKER = "rp:RegisterBoss(PACK"

local function sandboxEnv(id, data)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.aura_env = { id = id, config = data.config or {}, cloneId = nil }
    env.WeakAuras = setmetatable({ ScanEvents = function() end, IsOptionsOpen = function() return false end },
        { __index = AuraAPI })
    env.print = function() end
    return env
end

local function repairStrayInterrupt(displays)
    local fixed = 0
    for id, data in pairs(displays) do
        local st = type(id) == "string" and type(data) == "table" and data.actions and data.actions.start
        if st and st.do_custom and type(st.custom) == "string"
            and (id:find("%[All%] Cast Bars$") or id:find("%[All%] Active Abilities$"))
            and st.custom:find("SpeakText") and st.custom:find('"Interrupt"', 1, true) then
            st.do_custom = false
            st.custom = ""
            fixed = fixed + 1
            if AuraAPI.Add and AuraAPI.IsAuraLoaded and AuraAPI.IsAuraLoaded(id) then pcall(AuraAPI.Add, data) end
        end
    end
    if fixed > 0 and Addon.Print then
        Addon.Print(("Fixed %d raid pack bar%s that said \"Interrupt\" on every cast."):format(fixed, fixed == 1 and "" or "s"))
    end
    return fixed
end

function RP:ScanInstalledPacks()
    local saved = Addon.AuraSaved or ForeverAurasSaved
    local displays = saved and saved.displays
    if not displays then return 0 end
    pcall(repairStrayInterrupt, displays)
    local n = 0
    for id, data in pairs(displays) do
        local init = type(data) == "table" and data.actions and data.actions.init
        local code = init and init.do_custom and init.custom
        if type(code) == "string" and code:find(MARKER, 1, true) then
            local fn = loadstring and loadstring(code, "FojjiCore scan: " .. tostring(id)) or load(code, "FojjiCore scan: " .. tostring(id))
            if fn then
                if setfenv then setfenv(fn, sandboxEnv(id, data)) end
                local ok = pcall(fn)
                if ok then n = n + 1 end
            end
        end
    end
    self.scanned = true
    return n
end

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("PLAYER_LOGIN")
scanFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function() RP:ScanInstalledPacks() end)
end)

local SOUND_DIR = "Interface\\AddOns\\FojjiCore\\sound\\"
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local function debuffKey(spellID) return "DEBUFF_" .. tostring(spellID) end

local function normalizeSound(v)
    if type(v) ~= "string" or v == "" then return "none" end
    if v == "tts" or v == "none" or v:find("^cue:") or v:find("^lsm:") then return v end
    return "cue:" .. v
end

local function normalizeDebuffDefaults(d)
    local out = {}
    for field, fallback in pairs(RP.DEBUFF_FIELDS) do
        local v = d and d[field]
        if v == nil then v = fallback end
        out[field] = copy(v)
    end
    out.sound = normalizeSound(out.sound)
    return out
end

function RP:RegisterDebuffs(pack, bossKey, list)
    local p = ensurePack(pack)
    local boss = p.bosses[bossKey]
    if not boss or type(list) ~= "table" then return end
    local s = store(pack)
    boss.debuffs = {}
    local reset = 0
    for _, d in ipairs(list) do
        if d.spellID then
            local key = debuffKey(d.spellID)
            p.debuffs[key] = {
                key = key, boss = bossKey, name = d.name or ("Spell " .. d.spellID), spellID = d.spellID,
                icon = d.icon, rev = d.rev or 1, note = d.note, mythic = d.mythic, role = d.role,
                isDebuff = true, defaults = normalizeDebuffDefaults(d.defaults),
            }
            boss.debuffs[#boss.debuffs + 1] = key
            local o = s.overrides[key]
            if o and (o.rev or 1) < (d.rev or 1) then s.overrides[key] = nil; reset = reset + 1 end
        end
    end
    if reset > 0 and Addon.Print then
        Addon.Print(("%s updated: %d debuff sound%s reset to the new defaults."):format(p.name or pack, reset, reset == 1 and "" or "s"))
    end
    RP:QueueAuraSoundRebuild()
    notify("debuffs", pack)
end

function RP:GetDebuffs(pack, bossKey)
    local p = self.packs[pack]
    local list = {}
    local boss = p and p.bosses[bossKey]
    if not boss or not boss.debuffs then return list end
    for _, key in ipairs(boss.debuffs) do
        if p.debuffs[key] then list[#list + 1] = p.debuffs[key] end
    end
    return list
end

function RP:HasDebuff(pack, spellID)
    local p = self.packs[pack]
    return p and p.debuffs[debuffKey(spellID)] ~= nil or false
end

function RP:CountCustomizedDebuffs(pack, bossKey)
    local p = self.packs[pack]
    local n = 0
    if not p then return 0 end
    for key, d in pairs(p.debuffs) do
        if (not bossKey or d.boss == bossKey) and self:IsCustomized(pack, key) then n = n + 1 end
    end
    return n
end

function RP:SoundPath(value)
    value = normalizeSound(value)
    local cue = value:match("^cue:(.+)$")
    if cue then return SOUND_DIR .. cue .. ".ogg" end
    local name = value:match("^lsm:(.+)$")
    if name and LSM then return LSM:Fetch("sound", name, true) end
    return nil
end

function RP:SoundLabel(value, text)
    value = normalizeSound(value)
    if value == "none" then return "No sound" end
    if value == "tts" then return "Speak: " .. ((text and text ~= "") and text or "...") end
    return value:match("^cue:(.+)$") or value:match("^lsm:(.+)$") or value
end

function RP:PlaySoundValue(value, text, channel)
    value = normalizeSound(value)
    if value == "none" then return false end
    if value == "tts" then
        if text and text ~= "" and FojjiCore.Speak then return FojjiCore:Speak(text) end
        return false
    end
    local path = self:SoundPath(value)
    if path then return PlaySoundFile(path, channel or "Master") end
    return false
end

local lastPlayed = {}
function RP:PlayDebuffSound(pack, spellID)
    if not self:GetGlobal(pack, "debuffSounds") then return end
    local key = debuffKey(spellID)
    if not self:Get(pack, key, "enabled") then return end
    if self.auraSoundHandled and self.auraSoundHandled[key] then return end
    local now = GetTime()
    if lastPlayed[key] and now - lastPlayed[key] < 1.5 then return end
    lastPlayed[key] = now
    return self:PlaySoundValue(self:Get(pack, key, "sound"), self:Get(pack, key, "text"), self:GetGlobal(pack, "soundChannel"))
end

function RP:PreviewDebuffSound(pack, key)
    return self:PlaySoundValue(self:Get(pack, key, "sound"), self:Get(pack, key, "text"), self:GetGlobal(pack, "soundChannel"))
end

local AddAuraSound = C_UnitAuras and C_UnitAuras.AddAuraSound
local RemoveAuraSound = C_UnitAuras and (C_UnitAuras.RemoveAuraSound or C_UnitAuras.RemovePrivateAuraAppliedSound)
local AddPrivateSound = C_UnitAuras and C_UnitAuras.AddPrivateAuraAppliedSound
RP.auraSoundIDs = RP.auraSoundIDs or {}
RP.auraSoundHandled = RP.auraSoundHandled or {}

local function restricted()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return true end
    if InCombatLockdown and InCombatLockdown() then return true end
    return false
end

function RP:RebuildAuraSounds()
    if not (AddAuraSound or AddPrivateSound) then return end
    if restricted() then self.auraSoundDirty = true return end
    self.auraSoundDirty = nil
    for key, id in pairs(self.auraSoundIDs) do
        if RemoveAuraSound then pcall(RemoveAuraSound, id) end
        self.auraSoundIDs[key] = nil
    end
    wipe(self.auraSoundHandled)
    for packKey, p in pairs(self.packs) do
        if self:GetGlobal(packKey, "debuffSounds") then
            local channel = self:GetGlobal(packKey, "soundChannel") or "Master"
            for key, d in pairs(p.debuffs) do
                if self:Get(packKey, key, "enabled") then
                    local path = self:SoundPath(self:Get(packKey, key, "sound"))
                    if not path and self:Get(packKey, key, "sound") == "tts" and FojjiCore.GetVoiceLineFile then
                        path = FojjiCore:GetVoiceLineFile(self:Get(packKey, key, "text"))
                    end
                    if path then
                        local info = { spellID = d.spellID, unitToken = "player", soundFileName = path, outputChannel = channel }
                        local ok, id
                        if AddAuraSound then
                            ok, id = pcall(AddAuraSound, 0, info)
                            if ok and id then self.auraSoundHandled[key] = true end
                        else
                            ok, id = pcall(AddPrivateSound, info)
                        end
                        if ok and id then self.auraSoundIDs[key] = id end
                    end
                end
            end
        end
    end
end

function RP:QueueAuraSoundRebuild()
    if self.auraSoundTimer then return end
    self.auraSoundTimer = C_Timer.NewTimer(0.5, function()
        self.auraSoundTimer = nil
        self:RebuildAuraSounds()
    end)
end

RP:RegisterCallback(function(reason)
    if reason == "debuff" or reason == "reset" or reason == "set" then RP:QueueAuraSoundRebuild() end
end)

local soundFrame = CreateFrame("Frame")
soundFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
soundFrame:RegisterEvent("ENCOUNTER_END")
soundFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
soundFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or RP.auraSoundDirty then RP:QueueAuraSoundRebuild() end
end)

local function updateLoad(d)
    if AuraAPI.UpdateLoadConditions then
        AuraAPI.UpdateLoadConditions(d)
    elseif AuraAPI.Add then
        AuraAPI.Add(d)
    end
end

function RP:RestoreDemoLoads()
    if self.restoreTimer then self.restoreTimer:Cancel(); self.restoreTimer = nil end
    local bk = FojjiCoreDB and FojjiCoreDB.demoLoadBackup
    if not bk or not next(bk) then return end
    for id, load in pairs(bk) do
        local d = AuraAPI.GetData and AuraAPI.GetData(id)
        if d then
            d.load = load
            pcall(updateLoad, d)
        end
        bk[id] = nil
    end
    self.forcedPack = nil
end

function RP:SetDemoState(pack, bossKey, running, source)
    self.demo[pack] = self.demo[pack] or {}
    self.demo[pack][bossKey] = running and (source or "pack") or nil
    if running then
        if self.restoreTimer then self.restoreTimer:Cancel(); self.restoreTimer = nil end
    end
    notify("demo", pack)
end

function RP:IsDemoRunning(pack, bossKey)
    local d = self.demo[pack]
    if not d then return false end
    if bossKey then return d[bossKey] and true or false end
    return next(d) ~= nil or (self.demoQueue and self.demoQueue[pack] ~= nil)
end

function RP:IsControllerDemo(pack, bossKey)
    local d = self.demo[pack]
    return d and d[bossKey] == "pack" or false
end

RP.DEMO_AURA = "Fojji - Raid Demo [Forever]"

function RP:DemoAura()
    local demo = FojjiCore.RaidDemo
    if type(demo) ~= "table" or type(demo.raids) ~= "table" then return nil end
    if AuraAPI and AuraAPI.IsAuraLoaded and not AuraAPI.IsAuraLoaded(demo.id or RP.DEMO_AURA) then return nil end
    return demo
end

function RP:DemoBosses(pack, includePreviewOnly)
    local demo = self:DemoAura()
    local keys = {}
    for _, raid in ipairs(demo and demo.raids or {}) do
        if raid.pack == pack then
            for _, boss in ipairs(raid.bosses or {}) do
                if includePreviewOnly or boss.demo ~= false then keys[#keys + 1] = boss.key end
            end
        end
    end
    return keys
end

function RP:PreviewAbility(pack, key, count)
    local p = self.packs[pack]
    local ab = p and p.abilities[key]
    if not ab or not AuraAPI or not AuraAPI.ScanEvents then return false end
    local say = Addon.Print or print
    if (IsEncounterInProgress and IsEncounterInProgress()) or (InCombatLockdown and InCombatLockdown()) then
        say("Preview is not available in combat.")
        return false
    end
    if not self:DemoAura() then
        say("Previews are played by the |cFFfbff6d" .. RP.DEMO_AURA .. "|r aura. Import it (or enable it) and try again - it can stay loaded everywhere.")
        return false
    end
    local found = false
    for _, bossKey in ipairs(self:DemoBosses(pack, true)) do
        if bossKey == ab.boss then found = true end
    end
    if not found then
        say(((p.bosses[ab.boss] and p.bosses[ab.boss].name) or ab.boss) .. " isn't in your " .. RP.DEMO_AURA .. " aura - import its latest version.")
        return false
    end
    local mapped = ab.duration and self:GetDurationMap(pack, ab.boss, ab.duration)
    if mapped then key = mapped end
    self:StopDemo(pack)
    self.demoQueue = self.demoQueue or {}
    self.demoQueue[pack] = {
        C_Timer.NewTimer(0.2, function()
            if self.demoQueue then self.demoQueue[pack] = nil end
            AuraAPI.ScanEvents("WA_FJI_DEMO", ab.boss, 0, key, count or 1)
        end),
    }
    notify("demo", pack)
    return true
end

function RP:StopDemo(pack)
    if self.demoQueue and self.demoQueue[pack] then
        for _, t in ipairs(self.demoQueue[pack]) do t:Cancel() end
        self.demoQueue[pack] = nil
    end
    if AuraAPI and AuraAPI.ScanEvents then
        AuraAPI.ScanEvents("WA_FJI_DEMO_STOP")
    end
    notify("demo", pack)
end

function RP:StartDemo(pack, bossKey, length)
    local p = self.packs[pack]
    if not p or not AuraAPI or not AuraAPI.ScanEvents then return false end
    local say = Addon.Print or print
    if IsEncounterInProgress and IsEncounterInProgress() then
        say("Demo is not available during an encounter.")
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        say("Demo is not available in combat.")
        return false
    end
    if not self:DemoAura() then
        say("Demos are played by the |cFFfbff6d" .. RP.DEMO_AURA .. "|r aura. Import it (or enable it) and try again - it can stay loaded everywhere.")
        return false
    end
    local keys = self:DemoBosses(pack)
    if #keys == 0 then
        say((p.name or pack) .. " has no demo timings in your " .. RP.DEMO_AURA .. " aura - import its latest version.")
        return false
    end
    if bossKey and bossKey ~= "ALL" then
        local found = false
        for _, key in ipairs(keys) do if key == bossKey then found = true end end
        if not found then
            local b = p.bosses and p.bosses[bossKey]
            say(((b and b.name) or bossKey) .. " has no demo timings yet.")
            return false
        end
        keys = { bossKey }
    end
    self:StopDemo(pack)
    length = length or self:GetGlobal(pack, "demoLength") or 90
    self.demoQueue = self.demoQueue or {}
    local queue = {}
    self.demoQueue[pack] = queue
    for i, key in ipairs(keys) do
        queue[#queue + 1] = C_Timer.NewTimer((i - 1) * (length + 3) + 0.2, function()
            AuraAPI.ScanEvents("WA_FJI_DEMO", key, length)
        end)
    end
    queue[#queue + 1] = C_Timer.NewTimer((#keys - 1) * (length + 3) + 0.5, function()
        if self.demoQueue then self.demoQueue[pack] = nil end
        notify("demo", pack)
    end)
    notify("demo", pack)
    return true
end

local restoreFrame = CreateFrame("Frame")
restoreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
restoreFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
restoreFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(3, function() RP:RestoreDemoLoads() end)
    elseif RP.forcedPack and not RP:IsDemoRunning(RP.forcedPack) then
        RP:RestoreDemoLoads()
    end
end)

RP.HandlesGossip = true

local function instanceID()
    local id = select(8, GetInstanceInfo())
    if issecretvalue and issecretvalue(id) then return nil end
    return id
end

function RP:PackForInstance(id)
    if not id then return nil end
    for key, p in pairs(self.packs) do
        if p.instance and p.instance == id then return key, p end
    end
end

local function npcID()
    local guid = UnitGUID and UnitGUID("npc")
    if not guid or (issecretvalue and issecretvalue(guid)) then return nil end
    local id = select(6, strsplit("-", guid))
    return tonumber(id)
end

function RP:CountLearnedGossip(pack)
    local s = FojjiCoreDB and FojjiCoreDB.raidPacks and FojjiCoreDB.raidPacks[pack]
    local n = 0
    for _ in pairs(s and s.gossipLearned or {}) do n = n + 1 end
    return n
end

function RP:ForgetGossip(pack)
    store(pack).gossipLearned = nil
    notify("set", pack)
end

local gossipFrame = CreateFrame("Frame")
gossipFrame:RegisterEvent("GOSSIP_SHOW")
gossipFrame:SetScript("OnEvent", function()
    if not C_GossipInfo or not C_GossipInfo.GetOptions then return end
    if IsShiftKeyDown() then return end
    local pack, p = RP:PackForInstance(instanceID())
    if not pack or not RP:GetGlobal(pack, "autoGossip") then return end
    if C_GossipInfo.GetNumAvailableQuests and (C_GossipInfo.GetNumAvailableQuests() or 0) > 0 then return end
    if C_GossipInfo.GetNumActiveQuests and (C_GossipInfo.GetNumActiveQuests() or 0) > 0 then return end
    local options = C_GossipInfo.GetOptions()
    if not options or #options == 0 then return end
    local blocked = {}
    for _, id in ipairs(p.gossip and p.gossip.blocked or {}) do blocked[id] = true end
    for _, o in ipairs(options) do
        if blocked[o.gossipOptionID] then return end
    end
    local s = store(pack)
    local npc = npcID()
    local pick = options[1].gossipOptionID
    local learned = npc and s.gossipLearned and s.gossipLearned[npc]
    if learned then
        for _, o in ipairs(options) do if o.gossipOptionID == learned then pick = learned end end
    end
    RP.autoPicking = true
    C_GossipInfo.SelectOption(pick)
    RP.autoPicking = false
    if Addon.Print and not RP.gossipHinted then
        RP.gossipHinted = true
        Addon.Print("Auto gossip picked an option for you (hold SHIFT to skip it, /fc -> Raid Packs -> Pack settings).")
    end
end)

if C_GossipInfo and C_GossipInfo.SelectOption and hooksecurefunc and not (Addon.GamepadUI and Addon.GamepadUI()) then
    hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
        if RP.autoPicking then return end
        local pack = RP:PackForInstance(instanceID())
        local npc = npcID()
        if not pack or not npc or type(optionID) ~= "number" then return end
        local s = store(pack)
        s.gossipLearned = s.gossipLearned or {}
        s.gossipLearned[npc] = optionID
    end)
end

RP.HandlesCinematics = true

local cinematicFrame = CreateFrame("Frame")
cinematicFrame:RegisterEvent("CINEMATIC_START")
cinematicFrame:RegisterEvent("PLAY_MOVIE")
cinematicFrame:SetScript("OnEvent", function(_, event)
    local pack = RP:PackForInstance(instanceID())
    if not pack or not RP:GetGlobal(pack, "skipCinematics") then return end
    if event == "CINEMATIC_START" then
        if CinematicFrame_CancelCinematic then CinematicFrame_CancelCinematic() end
    elseif MovieFrame then
        if MovieFrame_StopMovie then MovieFrame_StopMovie(MovieFrame) else MovieFrame:Hide() end
    end
end)

local function serialize(v)
    local t = type(v)
    if t == "string" then return (string.format("%q", v):gsub("\\\n", "\\n")) end
    if t == "number" then
        if v == math.floor(v) then return tostring(v) end
        return (string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", ""))
    end
    if t ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    local out = {}
    if #v == #keys then
        for i = 1, #v do out[i] = serialize(v[i]) end
    else
        for _, k in ipairs(keys) do
            local ks = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. serialize(k) .. "]")
            out[#out + 1] = ks .. "=" .. serialize(v[k])
        end
    end
    return "{" .. table.concat(out, ",") .. "}"
end

function RP:ExportDefaults(pack)
    local p = self.packs[pack]
    if not p then return nil end
    local s = store(pack)
    local overrides = {}
    for key, o in pairs(s.overrides) do
        local t = {}
        for field, v in pairs(o) do if field ~= "rev" then t[field] = copy(v) end end
        if next(t) then overrides[key] = t end
    end
    local discovered = {}
    for bossKey, list in pairs(s.discovered or {}) do
        for key, d in pairs(list) do
            discovered[bossKey] = discovered[bossKey] or {}
            discovered[bossKey][key] = { duration = d.duration, spellID = d.spellID }
        end
    end
    local data = {
        pack = pack, packVersion = p.version,
        exported = date and date("%Y-%m-%d %H:%M") or nil,
        global = copy(s.global), overrides = overrides, durationMap = copy(s.durationMap or {}),
        castTimes = copy(s.castTimes or {}), discovered = discovered,
    }
    local text = "return" .. serialize(data)
    FojjiCoreDB.exports = FojjiCoreDB.exports or {}
    FojjiCoreDB.exports[pack] = text
    return text
end

local MAX_LOGS = 15
local recorder = CreateFrame("Frame")
local current

local function readable(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function logLine(fmt, ...)
    if not current then return end
    current.lines[#current.lines + 1] = ("[%7.2f] "):format(GetTime() - current.start) .. fmt:format(...)
end

recorder:RegisterEvent("ENCOUNTER_START")
recorder:RegisterEvent("ENCOUNTER_END")
for _, e in ipairs({ "ENCOUNTER_TIMELINE_EVENT_ADDED", "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", "ENCOUNTER_TIMELINE_EVENT_REMOVED" }) do
    pcall(recorder.RegisterEvent, recorder, e)
end

recorder:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, name, difficultyID, size = ...
        current = {
            encounterID = encounterID, name = name, difficultyID = difficultyID, size = size,
            date = date("%Y-%m-%d %H:%M"), start = GetTime(), lines = {},
        }
    elseif event == "ENCOUNTER_END" then
        if current then
            local _, _, _, _, success = ...
            current.success = success == 1
            current.length = GetTime() - current.start
            FojjiCoreDB = FojjiCoreDB or {}
            FojjiCoreDB.timelineLogs = FojjiCoreDB.timelineLogs or {}
            table.insert(FojjiCoreDB.timelineLogs, 1, current)
            while #FojjiCoreDB.timelineLogs > MAX_LOGS do table.remove(FojjiCoreDB.timelineLogs) end
            current.start = nil
            current = nil
            notify("timeline")
        end
    elseif not current then
        return
    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        local info = ...
        if type(info) ~= "table" then return end
        local spellID = readable(info.spellID)
        local spellName = readable(info.spellName)
        logLine("ADD    id %-6s dur %-9.3f src %s%s", tostring(info.id), info.duration or -1, tostring(info.source),
            spellID and ("  spell %d %s"):format(spellID, spellName or "") or "")
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        local id = ...
        local st = C_EncounterTimeline and C_EncounterTimeline.GetEventState(id)
        local names = { [0] = "Active", [1] = "Paused", [2] = "Finished", [3] = "Canceled" }
        logLine("STATE  id %-6s %s", tostring(id), names[st] or tostring(st))
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
        logLine("REMOVE id %s", tostring((...)))
    end
end)

function RP:GetTimelineLogs()
    return (FojjiCoreDB and FojjiCoreDB.timelineLogs) or {}
end

function RP:SummarizeLog(log)
    local counts, order, spells = {}, {}, {}
    for _, line in ipairs(log.lines or {}) do
        local dur = line:match("ADD%s+id%s+%S+%s+dur%s+([%d%.]+)")
        if dur then
            local r = math.floor(tonumber(dur) + 0.5)
            if not counts[r] then counts[r] = 0; order[#order + 1] = r end
            counts[r] = counts[r] + 1
            local sid, sname = line:match("spell (%d+) ?(.*)$")
            if sid then spells[r] = spells[r] or {}; spells[r][sid .. " " .. (sname or "")] = true end
        end
    end
    table.sort(order)
    local out = {}
    for _, r in ipairs(order) do
        local s = ""
        if spells[r] then
            local names = {}
            for k in pairs(spells[r]) do names[#names + 1] = k end
            table.sort(names)
            s = "  <- " .. table.concat(names, ", ")
        end
        out[#out + 1] = ("%4ds  x%d%s"):format(r, counts[r], s)
    end
    return out
end
