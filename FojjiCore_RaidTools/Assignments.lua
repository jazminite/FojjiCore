local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end

local AM = {}
Addon.Assignments = AM
FojjiCore = FojjiCore or {}
FojjiCore.Assignments = AM

local K
local function kit() K = K or Addon.UIKit; return K end
local function say(msg) if Addon.Print then Addon.Print(msg) else print("FojjiCore: " .. msg) end end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function readable(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end

local TEX = "Interface\\AddOns\\FojjiCore\\textures\\DungeonJournal\\"
local MARK = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local PREFIX = "FJAM"

local function db()
    FojjiCoreDB = FojjiCoreDB or {}
    local d = FojjiCoreDB.assignments
    if type(d) ~= "table" then d = {}; FojjiCoreDB.assignments = d end
    d.plans = d.plans or {}
    d.accept = d.accept or "lead"
    if d.autoShow == nil then d.autoShow = true end
    d.win = d.win or {}
    return d
end
AM.DB = db

local callbacks = {}
function AM:OnChange(fn) callbacks[#callbacks + 1] = fn end

local function fireAuras(event, encounterID, key)
    local api = Addon.AuraAPI or _G.WeakAuras
    if api and api.ScanEvents then pcall(api.ScanEvents, event, encounterID, key) end
end

local function changed(plan)
    for i = 1, #callbacks do pcall(callbacks[i], plan) end
    if plan then fireAuras("FOJJI_ASSIGNMENTS", plan.encounterID, plan.key) end
end
AM.Changed = changed

local function me() return (UnitName("player")) end

AM.COLORS = {
    { 1.00, 0.30, 0.30 }, { 1.00, 0.62, 0.20 }, { 1.00, 0.90, 0.25 }, { 0.35, 0.90, 0.40 },
    { 0.30, 0.75, 1.00 }, { 0.70, 0.45, 1.00 }, { 1.00, 0.45, 0.80 }, { 0.95, 0.95, 0.95 },
}
AM.STAMPS = {
    { 1, "Star" }, { 2, "Circle" }, { 3, "Diamond" }, { 4, "Triangle" }, { 5, "Moon" }, { 6, "Square" }, { 7, "Cross" }, { 8, "Skull" },
    { "aoe", "Area" }, { "warn", "Warning" }, { "heal", "Healer" }, { "shield", "Tank" }, { "swords", "Melee" },
    { "eye", "Watch" }, { "flag", "Flag" }, { "arrow", "Arrow" }, { "question", "Question" },
}
local function stampTexture(i)
    if type(i) == "number" then return MARK .. i end
    return TEX .. "mark-" .. tostring(i)
end
AM.StampTexture = stampTexture

local ROLE_TOKENS = { Tank = { 0.45, 0.65, 1 }, Healer = { 0.35, 0.95, 0.45 }, Melee = { 1, 0.45, 0.35 }, Ranged = { 1, 0.8, 0.3 } }
AM.ROLE_TOKENS = ROLE_TOKENS

local raidCache

local function mapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name
end

local function floorsOf(mapID)
    local floors = {}
    if not mapID or not C_Map then return floors end
    local gid = C_Map.GetMapGroupID and C_Map.GetMapGroupID(mapID)
    local members = gid and C_Map.GetMapGroupMembersInfo and C_Map.GetMapGroupMembersInfo(gid)
    if type(members) == "table" and #members > 0 then
        for _, m in ipairs(members) do floors[#floors + 1] = { mapID = m.mapID, name = m.name } end
    else
        floors[1] = { mapID = mapID, name = mapName(mapID) }
    end
    return floors
end
AM.FloorsOf = floorsOf

local function hasEJ() return EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex end

local function ejRaids(out)
    if not hasEJ() then return end
    local prev = EJ_GetCurrentTier and EJ_GetCurrentTier()
    local ok = pcall(function()
        for tier = EJ_GetNumTiers(), 1, -1 do
            EJ_SelectTier(tier)
            local tierName = EJ_GetTierInfo and EJ_GetTierInfo(tier) or ("Tier " .. tier)
            local i = 1
            while i < 60 do
                local jid, name, _, _, _, _, _, areaMap = EJ_GetInstanceByIndex(i, true)
                if not jid then break end
                out[#out + 1] = { key = "ej" .. jid, name = name, group = tierName, ej = jid, areaMap = areaMap }
                i = i + 1
            end
        end
    end)
    if prev then pcall(EJ_SelectTier, prev) end
    return ok
end

local function ejBosses(raid)
    raid.bosses, raid.floors = {}, floorsOf(raid.areaMap)
    local i = 1
    while i < 40 do
        local name, _, jEnc, _, _, _, dungeonEncID = EJ_GetEncounterInfoByIndex(i, raid.ej)
        if not name then break end
        raid.bosses[#raid.bosses + 1] = { name = name, jid = jEnc, encounterID = dungeonEncID }
        i = i + 1
    end
    if C_EncounterJournal and C_EncounterJournal.GetEncountersOnMap then
        for _, f in ipairs(raid.floors) do
            local ok, list = pcall(C_EncounterJournal.GetEncountersOnMap, f.mapID)
            for _, e in ipairs(ok and list or {}) do
                for _, b in ipairs(raid.bosses) do
                    if b.jid == e.encounterID and not b.mapID then b.mapID, b.x, b.y = f.mapID, e.mapX, e.mapY end
                end
            end
        end
    end
    for _, b in ipairs(raid.bosses) do b.mapID = b.mapID or (raid.floors[1] and raid.floors[1].mapID) end
end

local ejByEncounter
local function ejPlace(encounterID)
    if not encounterID or not hasEJ() then return end
    if not ejByEncounter then
        ejByEncounter = {}
        local list = {}
        ejRaids(list)
        for _, r in ipairs(list) do
            pcall(ejBosses, r)
            for _, b in ipairs(r.bosses or {}) do if b.encounterID then ejByEncounter[b.encounterID] = b end end
        end
    end
    return ejByEncounter[encounterID]
end

local function packRaids(out)
    local RP = FojjiCore.RaidPacks
    if not (RP and RP.packs) then return end
    local keys = {}
    for k in pairs(RP.packs) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, pk in ipairs(keys) do
        local p = RP.packs[pk]
        local raid = { key = "pack:" .. pk, name = p.name or pk, group = "Fojji raid packs", pack = pk, bosses = {} }
        for _, bk in ipairs(p.bossOrder or {}) do
            local b = p.bosses[bk]
            if b then
                local e = { name = b.name or bk, encounterID = b.encounterID, packBoss = bk, mapID = b.mapID, x = b.mapX, y = b.mapY }
                if not e.mapID then
                    local hit = ejPlace(b.encounterID)
                    if hit then e.mapID, e.x, e.y = hit.mapID, hit.x, hit.y end
                end
                raid.bosses[#raid.bosses + 1] = e
            end
        end
        local first = raid.bosses[1] and raid.bosses[1].mapID
        raid.floors = floorsOf(first)
        if #raid.bosses > 0 then out[#out + 1] = raid end
    end
end

function AM:Raids(refresh)
    if raidCache and not refresh then return raidCache end
    local out = {}
    packRaids(out)
    ejRaids(out)
    local custom = { key = "custom", name = "My maps", group = "Other", bosses = {}, floors = {} }
    for key, plan in pairs(db().plans) do
        if plan.custom then custom.bosses[#custom.bosses + 1] = { name = plan.name or "Map", custom = key, mapID = plan.mapID } end
    end
    table.sort(custom.bosses, function(a, b) return a.name < b.name end)
    if #custom.bosses > 0 then out[#out + 1] = custom end
    raidCache = out
    return out
end

function AM:Raid(key)
    for _, r in ipairs(self:Raids()) do
        if r.key == key then
            if r.ej and not r.bosses then pcall(ejBosses, r) end
            return r
        end
    end
end

function AM:PlanKey(raid, boss)
    if boss.custom then return boss.custom end
    if boss.encounterID and boss.encounterID > 0 then return "e" .. boss.encounterID end
    return "b" .. raid.key .. ":" .. (boss.packBoss or boss.name)
end

function AM:Plan(raid, boss, create)
    local key = self:PlanKey(raid, boss)
    local plans = db().plans
    local p = plans[key]
    if not p and create then
        p = { key = key, name = boss.name, raid = raid.name, encounterID = boss.encounterID, mapID = boss.mapID, items = {}, note = "", rev = 0 }
        plans[key] = p
    end
    if p and not p.mapID then p.mapID = boss.mapID end
    return p, key
end

function AM:GetPlan(encounterID)
    return encounterID and db().plans["e" .. encounterID]
end

function AM:CurrentRaid()
    if not (IsInInstance and select(2, IsInInstance()) == "raid") then return end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if EJ_GetInstanceForMap and mapID then
        local jid = EJ_GetInstanceForMap(mapID)
        if jid and jid > 0 then return "ej" .. jid end
    end
    local instName = GetInstanceInfo()
    for _, r in ipairs(self:Raids()) do
        if r.pack then
            local RP = FojjiCore.RaidPacks
            local p = RP and RP.packs[r.pack]
            if p and (p.instance == instName or r.name == instName) then return r.key end
        end
    end
end

local function myTokens(name)
    name = name or me()
    local t = { [(name or ""):lower()] = true }
    local GS = Addon.GroupSetups
    if GS and GS.KnownFull then
        local full = GS.KnownFull(name)
        t[full:lower()] = true
    end
    local _, class = UnitClass("player")
    if class then t[class:lower()] = true; t[(class:sub(1, 1) .. class:sub(2):lower()):lower()] = true end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if role == "TANK" then t.tank = true elseif role == "HEALER" then t.healer = true end
    local r = GS and GS.Roster_Keys and GS:Roster_Keys()
    for key, n in pairs(r and r.keys or {}) do
        local nl = n:lower()
        if nl == (name or ""):lower() or nl:match("^(%S+)") == (name or ""):lower() then t[key:lower()] = true end
    end
    return t
end

function AM:GetMine(encounterID, name)
    local plan = type(encounterID) == "table" and encounterID or self:GetPlan(encounterID)
    local res = { lines = {}, tokens = {} }
    if not plan then return res end
    local mine = myTokens(name)
    for line in ((plan.note or "") .. "\n"):gmatch("([^\n]*)\n") do
        local l = line:lower()
        for word in l:gmatch("[%w_]+") do
            if mine[word] then res.lines[#res.lines + 1] = trim(line) break end
        end
    end
    for _, it in ipairs(plan.items or {}) do
        if it.t == "P" and mine[(it.s or ""):lower()] then
            res.tokens[#res.tokens + 1] = { value = it.s, label = it.l, x = it.x, y = it.y }
        end
    end
    return res
end

local pullFrame = CreateFrame("Frame")
pullFrame:RegisterEvent("ENCOUNTER_START")
pullFrame:SetScript("OnEvent", function(_, _, encounterID)
    encounterID = readable(encounterID)
    local plan = encounterID and AM:GetPlan(encounterID)
    if plan then fireAuras("FOJJI_ASSIGNMENTS_PULL", encounterID, plan.key) end
end)

local function n3(v) return tostring(math.floor((v or 0) * 1000 + 0.5)) end
local function d3(s) return (tonumber(s) or 0) / 1000 end
local function clean(s) return (tostring(s or ""):gsub("[~%^]", ""):gsub("\n", "{nl}")) end
local function unclean(s) return (tostring(s or ""):gsub("{nl}", "\n")) end

function AM:Serialize(plan)
    local parts = { table.concat({ "1", clean(plan.key), tostring(plan.mapID or 0), tostring(plan.encounterID or 0), tostring(plan.rev or 0),
        clean(plan.name), clean(plan.raid), clean(plan.note), plan.custom and "1" or "0" }, "~") }
    for _, it in ipairs(plan.items or {}) do
        local s
        if it.t == "L" then
            local pts = {}
            for i = 1, #it.p do pts[i] = n3(it.p[i]) end
            s = "L," .. (it.c or 1) .. "," .. (it.w or 3) .. "," .. table.concat(pts, ",")
        elseif it.t == "A" then
            s = "A," .. (it.c or 1) .. "," .. n3(it.p[1]) .. "," .. n3(it.p[2]) .. "," .. n3(it.p[3]) .. "," .. n3(it.p[4])
        elseif it.t == "C" then
            s = "C," .. (it.c or 1) .. "," .. n3(it.x) .. "," .. n3(it.y) .. "," .. n3(it.r)
        elseif it.t == "M" then
            s = "M," .. tostring(it.i) .. "," .. n3(it.x) .. "," .. n3(it.y)
        elseif it.t == "T" then
            s = "T," .. (it.c or 8) .. "," .. n3(it.x) .. "," .. n3(it.y) .. "," .. clean(it.s)
        elseif it.t == "P" then
            s = "P," .. n3(it.x) .. "," .. n3(it.y) .. "," .. clean((it.s or ""):gsub(",", "")) .. "," .. clean(it.l)
        end
        if s then parts[#parts + 1] = s end
    end
    return table.concat(parts, "^")
end

function AM:Deserialize(text)
    text = trim(text or ""):gsub("^FJAM1:", "")
    local first = true
    local plan
    for chunk in (text .. "^"):gmatch("([^%^]*)%^") do
        if first then
            first = false
            local v, key, mapID, enc, rev, name, raid, note, custom = strsplit("~", chunk)
            if v ~= "1" or not key or key == "" then return nil end
            plan = { key = key, mapID = tonumber(mapID) ~= 0 and tonumber(mapID) or nil, encounterID = tonumber(enc) ~= 0 and tonumber(enc) or nil,
                rev = tonumber(rev) or 0, name = unclean(name), raid = unclean(raid), note = unclean(note), custom = custom == "1" or nil, items = {} }
        elseif chunk ~= "" then
            local t = chunk:sub(1, 1)
            local it
            if t == "L" then
                local nums = {}
                for n in chunk:sub(3):gmatch("[^,]+") do nums[#nums + 1] = tonumber(n) or 0 end
                it = { t = "L", c = nums[1], w = nums[2], p = {} }
                for i = 3, #nums do it.p[#it.p + 1] = nums[i] / 1000 end
                if #it.p < 4 then it = nil end
            elseif t == "A" then
                local c, a, b, x, y = chunk:match("^A,(%d+),(%d+),(%d+),(%d+),(%d+)$")
                if c then it = { t = "A", c = tonumber(c), p = { d3(a), d3(b), d3(x), d3(y) } } end
            elseif t == "C" then
                local c, x, y, r = chunk:match("^C,(%d+),(%d+),(%d+),(%d+)$")
                if c then it = { t = "C", c = tonumber(c), x = d3(x), y = d3(y), r = d3(r) } end
            elseif t == "M" then
                local i, x, y = chunk:match("^M,([%w]+),(%d+),(%d+)$")
                if i then it = { t = "M", i = tonumber(i) or i, x = d3(x), y = d3(y) } end
            elseif t == "T" then
                local c, x, y, s = chunk:match("^T,(%d+),(%d+),(%d+),(.*)$")
                if c then it = { t = "T", c = tonumber(c), x = d3(x), y = d3(y), s = unclean(s) } end
            elseif t == "P" then
                local x, y, s, l = chunk:match("^P,(%d+),(%d+),([^,]*),?(.*)$")
                if x then it = { t = "P", x = d3(x), y = d3(y), s = unclean(s), l = l ~= "" and unclean(l) or nil } end
            end
            if it then plan.items[#plan.items + 1] = it end
        end
    end
    return plan
end

function AM:Export(plan) return "FJAM1:" .. self:Serialize(plan) end

function AM:Import(text)
    local plan = self:Deserialize(text)
    if not plan then say("That isn't an assignments export.") return end
    plan.by = me()
    db().plans[plan.key] = plan
    raidCache = nil
    say(("Imported assignments for %s."):format(plan.name or "a boss"))
    changed(plan)
    return plan
end

function AM:Delete(key)
    db().plans[key] = nil
    raidCache = nil
    changed()
end

function AM:NewCustom(mapID, name)
    mapID = mapID or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
    if not mapID then say("No map here.") return end
    local key = "m" .. mapID .. "-" .. time()
    local plan = { key = key, name = name or mapName(mapID) or ("Map " .. mapID), raid = "My maps", mapID = mapID, items = {}, note = "", rev = 0, custom = true }
    db().plans[key] = plan
    raidCache = nil
    changed(plan)
    return plan
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local function channel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local outbox, pumping = {}, false
local function pump()
    local msg = table.remove(outbox, 1)
    if not msg then pumping = false return end
    local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if send then pcall(send, PREFIX, msg[1], msg[2]) end
    C_Timer.After(0.12, pump)
end
local function queue(text, ch)
    outbox[#outbox + 1] = { text, ch }
    if not pumping then pumping = true; pump() end
end

local function canLead()
    if IsInRaid() then return (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) end
    return UnitIsGroupLeader and UnitIsGroupLeader("player")
end
AM.CanShare = function() return channel() ~= nil end

function AM:Share(plan, show)
    local ch = channel()
    if not ch then say("Join a group to share assignments.") return end
    local body = self:Serialize(plan)
    local id = tostring(math.random(1000, 9999))
    local size = 220
    local n = math.ceil(#body / size)
    for i = 1, n do
        queue(("D%s:%d:%d:%s%s"):format(id, i, n, (i == n and show) and "!" or "", body:sub((i - 1) * size + 1, i * size)), ch)
    end
    say(("Shared assignments for %s with the %s."):format(plan.name or "boss", ch == "PARTY" and "party" or "raid"))
end

local function senderAllowed(sender)
    local mode = db().accept
    if mode == "all" then return true end
    if mode == "none" then return false end
    if not IsInRaid() then
        return UnitIsGroupLeader and UnitIsGroupLeader(sender) or false
    end
    local short = (strsplit("-", sender))
    local first = short:match("^(%S+)") or short
    for i = 1, GetNumGroupMembers() do
        local name, rank = GetRaidRosterInfo(i)
        if name and readable(name) then
            local n = (strsplit("-", name))
            if n == short or (n:match("^(%S+)") or n) == first then return (rank or 0) >= 1 end
        end
    end
    return false
end

local inbox = {}
local toast
local function showToast(plan, sender)
    kit()
    if not toast then
        toast = CreateFrame("Frame", "FojjiCoreAssignToast", UIParent)
        toast:SetSize(300, 64)
        toast:SetPoint("TOP", 0, -120)
        toast:SetFrameStrata("DIALOG")
        toast:SetFrameLevel(300)
        K.Surface(toast, "frame", 0.96, "accent", 0.8)
        toast.t = K.T(toast, 13, "white"); toast.t:SetPoint("TOPLEFT", 12, -10); toast.t:SetPoint("RIGHT", -12, 0)
        toast.open = K.Button(toast, "Open", 80, 22, "primary"); toast.open:SetPoint("BOTTOMRIGHT", -10, 8)
        toast.close = K.Button(toast, "Later", 70, 22); toast.close:SetPoint("RIGHT", toast.open, "LEFT", -6, 0)
        toast.close:SetScript("OnClick", function() toast:Hide() end)
    end
    toast.t:SetText(("%s shared assignments:\n|cffffcc66%s|r"):format(sender, plan.name or "boss"))
    toast.open:SetScript("OnClick", function() toast:Hide(); AM:Open(plan.key) end)
    toast:Show()
    if toast.timer then toast.timer:Cancel() end
    toast.timer = C_Timer.NewTimer(20, function() toast:Hide() end)
end

local pendingShow
local function receive(sender, body, show)
    local plan = AM:Deserialize(body)
    if not plan then return end
    plan.by = sender
    plan.t = time()
    db().plans[plan.key] = plan
    raidCache = nil
    changed(plan)
    if show and db().autoShow then
        if InCombatLockdown() then pendingShow = plan.key else AM:Open(plan.key) end
    else
        showToast(plan, sender)
    end
end

local comm = CreateFrame("Frame")
comm:RegisterEvent("CHAT_MSG_ADDON")
comm:RegisterEvent("PLAYER_REGEN_ENABLED")
comm:SetScript("OnEvent", function(_, event, prefix, msg, _, sender)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingShow then local k = pendingShow; pendingShow = nil; AM:Open(k) end
        return
    end
    if (issecretvalue and issecretvalue(prefix)) or prefix ~= PREFIX then return end
    msg, sender = readable(msg), readable(sender)
    if not (msg and sender) then return end
    local short = (strsplit("-", sender))
    if short == me() or (short:match("^(%S+)")) == me() then return end
    local id, i, n, rest = msg:match("^D(%d+):(%d+):(%d+):(.*)$")
    if not id then return end
    if not senderAllowed(sender) then return end
    i, n = tonumber(i), tonumber(n)
    local show = false
    if rest:sub(1, 1) == "!" and i == n then show = true; rest = rest:sub(2) end
    local box = inbox[sender .. id]
    if not box then box = { parts = {}, got = 0, t = GetTime() }; inbox[sender .. id] = box end
    if not box.parts[i] then box.parts[i] = rest; box.got = box.got + 1 end
    if show then box.show = true end
    if box.got >= n then
        inbox[sender .. id] = nil
        receive(short, table.concat(box.parts), box.show)
    end
end)
