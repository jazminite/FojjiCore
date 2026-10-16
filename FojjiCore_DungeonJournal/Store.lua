local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local ACCOUNT_DEFAULTS = {
    schema = 2,
    routes = {},
    pins = {},
    spots = {},
    wishes = {},
    chars = {},
    options = {
        enabled = true,
        dock = false,
        dockOpen = false,
        dockFollow = false,
        tooltips = true,
        alerts = true,
        partySync = true,
        worldPin = true,
        worldBeam = true,
        pinArrow = true,
        wpArrow = true,
        minimapPin = true,
        minimapNodes = true,
        mapClick = true,
        instanceMap = true,
        entrances = true,
        mapButton = true,
        routesButton = false,
        pocket = true,
        pocketWhen = "dungeon",
        pocketAnchor = true,
        pocketDir = "up",
        spellRanks = true,
        spellToast = true,
        spellBars = true,
        talentReminder = true,
        autoTrack = false,
        otherFaction = false,
        hideDone = false,
        brush = 2,
        journalKey = "SHIFT-J",
    },
    window = {},
}

local CHARACTER_DEFAULTS = {
    run = { instance = 0, last = 0, kills = {} },
    wishes = {},
    lastDungeon = nil,
}

local function fill(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = FDJ.Copy(v)
        elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
            fill(target[k], v)
        end
    end
    return target
end

local function fullName()
    local first, second = UnitFullName("player")
    first = first or UnitName("player")
    if not first or (issecretvalue and (issecretvalue(first) or issecretvalue(second))) then return UnitName("player") end
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(second) == "string" and second ~= "" and second ~= realm then return first .. " " .. second end
    return first
end
FDJ.FullName = fullName

local function legacyKey()
    local realm = GetRealmName and GetRealmName() or ""
    return (UnitName("player") or "?") .. "-" .. realm
end

local function charKey()
    local guid = UnitGUID and UnitGUID("player")
    local id = guid and not (issecretvalue and issecretvalue(guid)) and guid:match("([^%-]+)$")
    if not id then return legacyKey() end
    return legacyKey() .. "-" .. id
end

local function claimLegacy(db, key, class)
    local old = legacyKey()
    if old == key then return end
    local legacy = db.chars[old]
    if type(legacy) ~= "table" or type(db.chars[key]) == "table" then return end
    local mine = {}
    local specs, anyClass = {}, {}
    for c, list in pairs(FojjiCore and FojjiCore.SpecMarkers or {}) do
        for _, m in ipairs(list) do
            anyClass[m[1]] = true
            if c == class then specs[m[1]] = true end
        end
    end
    if type(legacy.bisLists) == "table" then
        local keep, take = {}, {}
        for _, l in ipairs(legacy.bisLists) do
            if (l.spec and specs[l.spec]) or not (l.spec and anyClass[l.spec]) or not next(specs) then
                take[#take + 1] = l
            else
                keep[#keep + 1] = l
            end
        end
        legacy.bisLists = keep
        legacy.bisActive, legacy.bisSpec, legacy.bisBySpec = nil, nil, nil
        if #take > 0 then mine.bisLists = take end
    end
    if not legacy.claimed then
        for k, v in pairs(legacy) do
            if k ~= "bisLists" and k ~= "bisActive" and k ~= "bisSpec" and k ~= "bisBySpec" and k ~= "class" and k ~= "bis" then
                mine[k] = v
            end
        end
        if not mine.bisLists and type(legacy.bis) == "table" and legacy.class == class then mine.bis = legacy.bis end
        for k in pairs(mine) do if k ~= "bisLists" then legacy[k] = nil end end
        if mine.bis then legacy.bis = nil end
        legacy.claimed = true
    end
    if not legacy.bisLists or #legacy.bisLists == 0 then
        db.chars[old] = nil
    end
    db.chars[key] = mine
end

function FDJ:LoadStore()
    if self.db then return end
    if type(FojjiCoreDB) ~= "table" then FojjiCoreDB = {} end
    if type(FojjiCoreDB.dungeonJournal) ~= "table" then FojjiCoreDB.dungeonJournal = {} end
    self.db = fill(FojjiCoreDB.dungeonJournal, ACCOUNT_DEFAULTS)
    local key = charKey()
    local _, myClass = UnitClass("player")
    pcall(claimLegacy, self.db, key, myClass)
    if type(self.db.chars[key]) ~= "table" then self.db.chars[key] = {} end
    self.char = fill(self.db.chars[key], CHARACTER_DEFAULTS)
    self.charKey = key
    local _, class = UnitClass("player")
    self.char.class = class or self.char.class
    self.char.name = fullName() or self.char.name
    self.opt = self.db.options
    if not self.db.dockDefaultOff then
        self.opt.dock, self.opt.dockOpen, self.opt.dockFollow = false, false, false
        self.opt.routesButton = false
        self.db.dockDefaultOff = true
    end
    if not self.db.wishesMoved then
        for itemID, stamp in pairs(self.db.wishes or {}) do self.char.wishes[itemID] = stamp end
        self.db.wishes = {}
        self.db.wishesMoved = true
    end
end

local OFF_VALUES = { pocketWhen = "never" }

function FDJ:Option(key)
    if self.off and key ~= "enabled" then return OFF_VALUES[key] or false end
    return self.opt and self.opt[key]
end

function FDJ:SetOption(key, value)
    self.opt[key] = value
    self:Emit("FDJ_OPTION", key, value)
end

function FDJ:BuildBackup()
    return FDJ.Codec.Pack("backup", {
        routes = self.db.routes,
        spots = self.db.spots,
        wishes = self.char.wishes,
        options = self.db.options,
        stamp = time(),
    })
end

function FDJ:RestoreBackup(text)
    local data, err = FDJ.Codec.Unpack(text, "backup")
    if not data then return false, err end
    local count = 0
    if type(data.pins) == "table" then
        for qid, pin in pairs(data.pins) do
            if type(pin) == "table" and pin.m and pin.x and pin.y and FDJ.QuestBook[qid] then
                self.db.spots[qid] = { m = pin.m, x = pin.x, y = pin.y, how = "pin", t = pin.t or time() }
            end
        end
    end
    for _, key in ipairs({ "routes", "spots", "wishes" }) do
        if type(data[key]) == "table" then
            local target = key == "wishes" and self.char.wishes or self.db[key]
            for k, v in pairs(data[key]) do
                if target[k] == nil then count = count + 1 end
                target[k] = v
            end
        end
    end
    if type(data.options) == "table" then
        for k, v in pairs(data.options) do
            if ACCOUNT_DEFAULTS.options[k] ~= nil and type(v) == type(ACCOUNT_DEFAULTS.options[k]) then self.opt[k] = v end
        end
    end
    self:Emit("FDJ_ROUTES")
    self:Emit("FDJ_PINS")
    self:Emit("FDJ_SPOTS")
    self:Emit("FDJ_WISHES")
    return true, count
end

FDJ:On("PLAYER_LOGIN", function()
    if FDJ.char and FDJ.FullName then FDJ.char.name = FDJ.FullName() or FDJ.char.name end
end)
