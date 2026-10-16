local _, Addon = ...

FojjiCore = FojjiCore or {}

local MARKERS = {
    WARRIOR = {
        { "arms", "Arms", { [12294] = 30, [12289] = 25, [12862] = 25, [12292] = 20, [1289682] = 20, [1290261] = 20 } },
        { "fury", "Fury", { [23881] = 30, [12319] = 25, [20500] = 25, [12328] = 20, [20504] = 20, [1225295] = 20 } },
        { "protection", "Protection", { [23922] = 30, [29787] = 25, [12311] = 20, [12312] = 20, [12809] = 20, [16538] = 20 } },
    },
    PALADIN = {
        { "holy", "Holy", { [1310911] = 30, [5923] = 25, [1310904] = 20, [1310905] = 20, [1311606] = 20 } },
        { "protection", "Protection", { [20925] = 30, [1311034] = 25, [20177] = 20, [1311015] = 20 } },
        { "retribution", "Retribution", { [1310735] = 30, [1311084] = 25, [1311085] = 25, [20049] = 20, [20066] = 20, [20111] = 20 } },
    },
    HUNTER = {
        { "beastmastery", "Beast Mastery", { [19574] = 30, [19621] = 25, [19577] = 20, [19578] = 20, [19590] = 20 } },
        { "marksmanship", "Marksmanship", { [1310687] = 30, [19507] = 25, [19461] = 20, [19503] = 20, [1223987] = 20 } },
        { "survival", "Survival", { [1310533] = 30, [19168] = 25, [440529] = 20, [1310496] = 20, [1310532] = 20, [1317257] = 20 } },
    },
    ROGUE = {
        { "assassination", "Assassination", { [1310703] = 30, [14186] = 25, [14174] = 20, [14983] = 20, [1310707] = 20 } },
        { "combat", "Combat", { [13750] = 30, [18427] = 25, [30919] = 25, [13877] = 20, [13960] = 20 } },
        { "subtlety", "Subtlety", { [1310721] = 30, [462708] = 25, [1310728] = 25, [14082] = 20, [14185] = 20, [16511] = 20 } },
    },
    PRIEST = {
        { "discipline", "Discipline", { [10060] = 30, [431622] = 25, [402174] = 20, [425280] = 20 } },
        { "holy", "Holy", { [401859] = 30, [14898] = 25, [14901] = 20, [20711] = 20, [1317006] = 20 } },
        { "shadow", "Shadow", { [15473] = 30, [15259] = 25, [1310076] = 25, [15487] = 20, [1309950] = 20 } },
    },
    SHAMAN = {
        { "elemental", "Elemental", { [408490] = 30, [16578] = 25, [28999] = 20, [408438] = 20, [1222988] = 20 } },
        { "enhancement", "Enhancement", { [425336] = 30, [408498] = 25, [16268] = 20, [30812] = 20, [1223031] = 20 } },
        { "restoration", "Restoration", { [408521] = 30, [16178] = 25, [16188] = 20, [29206] = 20 } },
    },
    MAGE = {
        { "arcane", "Arcane", { [12042] = 30, [15058] = 25, [11232] = 20, [12043] = 20 } },
        { "fire", "Fire", { [11129] = 30, [11124] = 25, [11113] = 20, [11115] = 20 } },
        { "frost", "Frost", { [11426] = 30, [11180] = 25, [11190] = 20, [12472] = 20, [400647] = 20 } },
    },
    WARLOCK = {
        { "affliction", "Affliction", { [1316697] = 30, [18271] = 25, [17804] = 20, [18265] = 20 } },
        { "demonology", "Demonology", { [425464] = 30, [23785] = 25, [19028] = 20, [412732] = 20, [1225217] = 20 } },
        { "destruction", "Destruction", { [412758] = 30, [426316] = 25, [18073] = 20, [412751] = 20, [1225228] = 20 } },
    },
    DRUID = {
        { "balance", "Balance", { [24858] = 30, [16896] = 25, [16880] = 20, [17245] = 20, [408248] = 20 } },
        { "feralcombat", "Feral Combat", { [417141] = 30, [417051] = 25, [1223246] = 25, [17007] = 20, [417046] = 20, [1223242] = 20 } },
        { "restoration", "Restoration", { [408120] = 30, [17074] = 25, [17116] = 20, [17123] = 20, [1309631] = 20 } },
    },
}
local MIN_DEPTH = 20
FojjiCore.SpecMarkers = MARKERS

local function secret(v) return issecretvalue and issecretvalue(v) end

local function specName(class, key)
    for _, s in ipairs(MARKERS[class] or {}) do
        if s[1] == key then return s[2] end
    end
end

local callbacks = {}
function FojjiCore.RegisterCallback(event, func)
    if type(event) ~= "string" or type(func) ~= "function" then return end
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], func)
end
function FojjiCore.UnregisterCallback(event, func)
    for i, f in ipairs(callbacks[event] or {}) do
        if f == func then table.remove(callbacks[event], i) return end
    end
end
local function fire(event, auraEvent, ...)
    for _, f in ipairs(callbacks[event] or {}) do pcall(f, ...) end
    local api = Addon.AuraAPI
    if api and api.ScanEvents then pcall(api.ScanEvents, auraEvent, ...) end
end

local function learnedFromTraits()
    if not (C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
        and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo
        and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then return nil end
    local ok, group = pcall(C_SpecializationInfo.GetActiveSpecGroup)
    if not ok or not group or secret(group) then return nil end
    local ok2, configID = pcall(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group)
    if not ok2 or not configID or secret(configID) then return nil end
    local ok3, config = pcall(C_Traits.GetConfigInfo, configID)
    if not ok3 or type(config) ~= "table" or type(config.treeIDs) ~= "table" then return nil end
    local learned, any = {}, false
    for _, treeID in ipairs(config.treeIDs) do
        local okT, nodes = pcall(C_Traits.GetTreeNodes, treeID)
        for _, nodeID in ipairs(okT and type(nodes) == "table" and nodes or {}) do
            local okN, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            local rank = okN and type(node) == "table" and (node.ranksPurchased or node.activeRank)
            if rank and not secret(rank) and rank > 0 then
                local entries = {}
                if type(node.entryIDs) == "table" then
                    for _, id in ipairs(node.entryIDs) do entries[#entries + 1] = id end
                end
                if node.activeEntry and node.activeEntry.entryID then entries[#entries + 1] = node.activeEntry.entryID end
                for _, entryID in ipairs(entries) do
                    local okE, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
                    local defID = okE and type(entry) == "table" and entry.definitionID
                    if defID and not secret(defID) then
                        local okD, def = pcall(C_Traits.GetDefinitionInfo, defID)
                        local spellID = okD and type(def) == "table" and def.spellID
                        if spellID and not secret(spellID) then
                            learned[spellID] = true
                            any = true
                        end
                    end
                end
            end
        end
    end
    return any and learned or nil
end

local function knownSpell(spellID)
    local api = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell or IsSpellKnown
    if not api then return false end
    local ok, known = pcall(api, spellID)
    return ok and not secret(known) and known == true
end

local function resolve(class, learned)
    local list = MARKERS[class]
    if not list then return nil end
    local best, keys = 0, {}
    for _, s in ipairs(list) do
        local depth = 0
        for spellID, value in pairs(s[3]) do
            if value >= MIN_DEPTH and value > depth and ((learned and learned[spellID]) or knownSpell(spellID)) then
                depth = value
            end
        end
        if depth > 0 then
            if depth > best then
                best, keys = depth, { s[1] }
            elseif depth == best then
                keys[#keys + 1] = s[1]
            end
        end
    end
    if best == 0 then return nil end
    return { class = class, key = keys[1], name = specName(class, keys[1]), keys = keys, depth = best }
end

local function columnPoints()
    if not (C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
        and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then return nil end
    local ok, group = pcall(C_SpecializationInfo.GetActiveSpecGroup)
    if not ok or not group or secret(group) then return nil end
    local ok2, configID = pcall(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group)
    if not ok2 or not configID or secret(configID) then return nil end
    local ok3, config = pcall(C_Traits.GetConfigInfo, configID)
    if not ok3 or type(config) ~= "table" or type(config.treeIDs) ~= "table" then return nil end
    local nodes = {}
    for _, treeID in ipairs(config.treeIDs) do
        local okT, ids = pcall(C_Traits.GetTreeNodes, treeID)
        for _, nodeID in ipairs(okT and type(ids) == "table" and ids or {}) do
            local okN, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            if okN and type(node) == "table" and node.ID and node.ID ~= 0 then
                local x, rank = node.posX, node.activeRank or 0
                if type(x) == "number" and not secret(x) and not secret(rank) then
                    nodes[#nodes + 1] = { x = x, rank = rank }
                end
            end
        end
    end
    if #nodes < 3 then return nil end
    local xs, seen = {}, {}
    for _, n in ipairs(nodes) do
        if not seen[n.x] then seen[n.x] = true; xs[#xs + 1] = n.x end
    end
    table.sort(xs)
    if #xs < 3 then return nil end
    local gaps = {}
    for i = 2, #xs do gaps[#gaps + 1] = { at = (xs[i - 1] + xs[i]) / 2, size = xs[i] - xs[i - 1] } end
    table.sort(gaps, function(a, b) return a.size > b.size end)
    local cut1, cut2 = math.min(gaps[1].at, gaps[2].at), math.max(gaps[1].at, gaps[2].at)
    local points = { 0, 0, 0 }
    for _, n in ipairs(nodes) do
        local i = n.x < cut1 and 1 or (n.x < cut2 and 2 or 3)
        points[i] = points[i] + n.rank
    end
    if points[1] + points[2] + points[3] == 0 then return nil end
    return points
end

local function tabPoints()
    if not (GetNumTalentTabs and GetTalentTabInfo) then return columnPoints() end
    local okN, n = pcall(GetNumTalentTabs)
    if not okN or type(n) ~= "number" or secret(n) or n < 1 then return nil end
    local points, any = {}, false
    for i = 1, n do
        local r = { pcall(GetTalentTabInfo, i) }
        if r[1] then
            local spent = type(r[2]) == "number" and r[6] or r[4]
            if type(spent) == "number" and not secret(spent) then
                points[i] = spent
                if spent > 0 then any = true end
            end
        end
    end
    if any then return points end
    return columnPoints()
end

local SPEC_POINTS = 21
function FojjiCore.SpecFromPoints(class, points)
    local list = MARKERS[class]
    if not list or type(points) ~= "table" then return nil end
    local best, keys = 0, {}
    for i, s in ipairs(list) do
        local p = points[i] or 0
        if p >= SPEC_POINTS then
            if p > best then best, keys = p, { s[1] } elseif p == best then keys[#keys + 1] = s[1] end
        end
    end
    if best == 0 then return nil end
    return { class = class, key = keys[1], name = specName(class, keys[1]), keys = keys, depth = best, points = best }
end

local function guess(class)
    local list, points = MARKERS[class], tabPoints()
    if not list or not points then return nil end
    local best, keys = 0, {}
    for i, s in ipairs(list) do
        local p = points[i] or 0
        if p > best then best, keys = p, { s[1] } elseif p == best and p > 0 then keys[#keys + 1] = s[1] end
    end
    if best == 0 then return nil end
    return { class = class, key = keys[1], name = specName(class, keys[1]), keys = keys, depth = 0, points = best, guess = true }
end

local mine
local dirty = true
local talentsMoved = false

local function copy(spec)
    if not spec then return nil end
    local keys = {}
    for i, k in ipairs(spec.keys) do keys[i] = k end
    return { class = spec.class, key = spec.key, name = spec.name, keys = keys, depth = spec.depth, points = spec.points, guess = spec.guess }
end

local function refresh()
    if InCombatLockdown and InCombatLockdown() then return false end
    local _, class = UnitClass("player")
    if not class or secret(class) then return false end
    dirty = false
    local spec
    if Addon.IsRetail then
        local api = C_SpecializationInfo
        local idx = api and api.GetSpecialization and api.GetSpecialization()
        local name
        if idx and api.GetSpecializationInfo then name = select(2, api.GetSpecializationInfo(idx)) end
        if type(name) == "string" and not secret(name) then
            local key = name:lower():gsub("[^%a]", "")
            spec = { class = class, key = key, name = name, keys = { key }, depth = 0 }
        end
    else
        spec = FojjiCore.SpecFromPoints(class, tabPoints()) or guess(class)
    end
    local before = mine and mine.key
    mine = spec
    if (spec and spec.key) ~= before then
        fire("SpecChanged", "FOJJICORE_SPEC_CHANGED", spec and spec.key)
        if FojjiCore.ShareSpec then FojjiCore.ShareSpec() end
    end
    return true
end

local others = {}
FojjiCore.GroupSpecs = others

local function myRealm()
    local r = GetNormalizedRealmName and GetNormalizedRealmName()
    return (r and not secret(r)) and r or nil
end

local function fullName(name, realm)
    if not name or secret(name) then return nil end
    if name:find("-", 1, true) then return name end
    realm = realm and realm ~= "" and realm or myRealm()
    return realm and (name .. "-" .. realm) or name
end

local function nameOf(who)
    if type(who) ~= "string" or who == "" then return nil end
    if UnitExists and UnitExists(who) then
        local name, realm = UnitFullName(who)
        return fullName(name, realm)
    end
    return fullName(who)
end

local function isMe(who)
    if who == nil or who == "player" then return true end
    if type(who) ~= "string" then return false end
    if UnitIsUnit and UnitExists and UnitExists(who) then
        local ok, same = pcall(UnitIsUnit, who, "player")
        if ok and same == true then return true end
    end
    return nameOf(who) == fullName(UnitName("player"))
end

function FojjiCore.GetSpec(a, b)
    local who = a
    if a == FojjiCore then who = b end
    if isMe(who) then
        if dirty then refresh() end
        return copy(mine)
    end
    local name = nameOf(who)
    return name and copy(others[name]) or nil
end

function FojjiCore.GetCachedSpec()
    return copy(mine)
end

function FojjiCore.GetSpecKey(a, b)
    local spec = FojjiCore.GetSpec(a, b)
    return spec and spec.key or nil
end

FojjiCore.Spec = FojjiCore.GetSpecKey

local PREFIX = "FJSPEC"
local send = C_ChatInfo and (C_ChatInfo.SendAddonMessage or C_ChatInfo.SendAddonMessageLogged)
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local function groupChannel()
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

local function sendMsg(msg, channel, target)
    if not send or not channel then return end
    pcall(send, PREFIX, msg, channel, target)
end

local function myMessage()
    if dirty then refresh() end
    local _, class = UnitClass("player")
    if not mine then return "S\t" .. (class or "") .. "\t\t0\t" end
    return "S\t" .. mine.class .. "\t" .. mine.key .. "\t" .. mine.depth .. "\t" .. table.concat(mine.keys, ",")
end

function FojjiCore.ShareSpec()
    local channel = groupChannel()
    if channel then sendMsg(myMessage(), channel) end
end

function FojjiCore.RequestSpec(a, b)
    local who = a
    if a == FojjiCore then who = b end
    if who == nil or who == "group" then
        local channel = groupChannel()
        if channel then sendMsg("Q", channel) end
        return channel ~= nil
    end
    local name = nameOf(who)
    if not name or isMe(who) then return false end
    sendMsg("Q", "WHISPER", name)
    return true
end

local lastAnswer = 0
local comm = CreateFrame("Frame")
comm:RegisterEvent("CHAT_MSG_ADDON")
comm:SetScript("OnEvent", function(_, _, prefix, msg, channel, sender)
    if (issecretvalue and issecretvalue(prefix)) or prefix ~= PREFIX or type(msg) ~= "string" or secret(sender) then return end
    local name = fullName(sender)
    if not name or name == fullName(UnitName("player")) then return end
    if msg == "Q" then
        if channel == "WHISPER" then
            sendMsg(myMessage(), "WHISPER", name)
        elseif GetTime() - lastAnswer > 3 then
            lastAnswer = GetTime()
            sendMsg(myMessage(), groupChannel() or channel)
        end
        return
    end
    local kind, class, key, depth, keys = strsplit("\t", msg)
    if kind ~= "S" then return end
    local entry = nil
    if key and key ~= "" then
        local list = {}
        for k in (keys or key):gmatch("[^,]+") do list[#list + 1] = k end
        entry = { class = class, key = key, name = specName(class, key) or key, keys = list, depth = tonumber(depth) or 0, guess = (tonumber(depth) or 0) == 0 or nil, t = time() }
    end
    others[name] = entry
    fire("SpecReceived", "FOJJICORE_SPEC_RECEIVED", name, entry and entry.key)
end)

local watcher = CreateFrame("Frame")
local wasGrouped = false
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "CHARACTER_POINTS_CHANGED" }) do
    pcall(watcher.RegisterEvent, watcher, event)
end
local pending = false
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        refresh()
    end)
end
watcher:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        local grouped = IsInGroup and IsInGroup() or false
        if grouped and not wasGrouped then
            C_Timer.After(3, function()
                FojjiCore.ShareSpec()
                FojjiCore.RequestSpec()
            end)
        end
        if not grouped then wipe(others) end
        wasGrouped = grouped
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if talentsMoved then
            talentsMoved = false
            soon()
        end
        return
    end
    if event == "SPELLS_CHANGED" then
        if not (InCombatLockdown and InCombatLockdown()) then dirty = true end
        return
    end
    dirty = true
    if InCombatLockdown and InCombatLockdown() then talentsMoved = true else soon() end
    if event == "PLAYER_LOGIN" then
        wasGrouped = IsInGroup and IsInGroup() or false
        if wasGrouped then C_Timer.After(5, FojjiCore.ShareSpec) end
    end
end)

function FojjiCore.SpecReport()
    local say = function(t) print("|cff66b3ffFojjiCore|r " .. t) end
    local _, class = UnitClass("player")
    local learned = learnedFromTraits()
    local n = 0
    for _ in pairs(learned or {}) do n = n + 1 end
    say("class " .. tostring(class) .. ", talents read: " .. (learned and (n .. " learned (talent tree)") or "talent tree unavailable, checking marker spells"))
    local pts = tabPoints()
    if pts then
        local spec = FojjiCore.SpecFromPoints(class, pts)
        say(("points %d / %d / %d: %s"):format(pts[1] or 0, pts[2] or 0, pts[3] or 0, spec and spec.name or "no tree at 21 yet"))
    end
    if learned then
        local names = {}
        for spellID in pairs(learned) do
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
            names[#names + 1] = (name and not secret(name) and name or "?") .. " " .. spellID
        end
        table.sort(names)
        say("  learned: " .. table.concat(names, ", "))
    end
    for _, sp in ipairs(MARKERS[class] or {}) do
        local hits = {}
        for spellID, value in pairs(sp[3]) do
            if (learned and learned[spellID]) or (not learned and knownSpell(spellID)) then
                local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or spellID
                hits[#hits + 1] = tostring(name) .. " (" .. value .. ")"
            end
        end
        say("  " .. sp[2] .. ": " .. (#hits > 0 and table.concat(hits, ", ") or "no marker talents"))
    end
    local points = tabPoints()
    if points then
        local parts = {}
        for i, sp in ipairs(MARKERS[class] or {}) do parts[#parts + 1] = sp[2] .. " " .. (points[i] or 0) end
        say("  points spent: " .. table.concat(parts, " / "))
    else
        say("  points spent: not available")
    end
    dirty = true
    refresh()
    local spec = mine
    if spec then
        say("result: |cffffffff" .. spec.name .. "|r (" .. spec.key .. ")" .. (spec.guess and (" - guessed from " .. spec.points .. " points, no marker talent yet") or (" - depth " .. spec.depth)) .. (#spec.keys > 1 and (", tied with " .. table.concat(spec.keys, ", ")) or ""))
    else
        say("result: none (no marker talent learned and no talent points to go by)")
    end
end
