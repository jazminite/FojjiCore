local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end

local CD = {}
Addon.CDAssign = CD
FojjiCore = FojjiCore or {}
FojjiCore.CDAssign = CD

local function say(msg) if Addon.Print then Addon.Print(msg) else print("FojjiCore: " .. msg) end end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function readable(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local PREFIX = "FJCD"

local function db()
    FojjiCoreDB = FojjiCoreDB or {}
    local d = FojjiCoreDB.cdAssign
    if type(d) ~= "table" then d = {}; FojjiCoreDB.cdAssign = d end
    d.plans = d.plans or {}
    if d.autoSend == nil then d.autoSend = true end
    d.accept = d.accept or "lead"
    return d
end
CD.DB = db

local callbacks = {}
function CD:OnChange(fn) callbacks[#callbacks + 1] = fn end

local function api() return Addon.AuraAPI or _G.WeakAuras end
local function fire(event, ...)
    local a = api()
    if a and a.ScanEvents then pcall(a.ScanEvents, event, ...) end
end

local function clean(v) v = trim(v); return (v ~= "" and v ~= "nil") and v or nil end
local function spellID(v) v = tonumber(v); return (v and v > 0) and v or nil end
local function counts(s)
    local out = {}
    for n in (s or ""):gmatch("[^,%s]+") do out[#out + 1] = tonumber(n) end
    if #out == 0 then out[1] = 1 end
    return out
end
local function players(s)
    local out = {}
    for p in (s or ""):gmatch("[^,]+") do p = trim(p); if p ~= "" then out[#out + 1] = p end end
    return out
end

function CD:Parse(text)
    local list, bad = {}, 0
    text = (text or ""):gsub("\r", "")
    for raw in (text .. "*"):gmatch("([^%*\n]*)[%*\n]") do
        raw = trim(raw)
        if raw ~= "" then
            local f = {}
            for part in (raw .. "/"):gmatch("([^/]*)/") do f[#f + 1] = part end
            local key = trim(f[1]):upper()
            local e
            if key == "INTERRUPT" or key == "INT" then
                e = { kind = "interrupt", k = trim(f[2]), counts = counts(f[3]), who = players(f[4]), spell = spellID(f[5]), text = clean(f[6]) }
            elseif key == "NOTE" then
                e = { kind = "note", k = trim(f[2]), who = players(f[3]), text = clean(table.concat(f, "/", 4)) }
            elseif key:find("HEALTH") or key:find("POWER") then
                e = { kind = key:find("HEALTH") and "health" or "power", k = key, pct = tonumber(f[2]), who = players(f[3]), time = tonumber(f[4]) or 0,
                    spell = spellID(f[5]), npc = clean(f[6]), text = clean(f[7]), tts = clean(f[8]), name = clean(f[9]), icon = clean(f[10]) }
                if not e.pct then e = nil end
            elseif #f >= 3 then
                e = { kind = "time", k = key, counts = counts(f[2]), who = players(f[3]), time = tonumber(f[4]) or 0,
                    spell = spellID(f[5]), text = clean(f[6]), tts = clean(f[7]), name = clean(f[8]), icon = clean(f[9]) }
            end
            if e and e.k ~= "" and #e.who > 0 then list[#list + 1] = e else bad = bad + 1 end
        end
    end
    return list, bad
end

local function cnt(c) local t = {} for i, v in ipairs(c or {}) do t[i] = tostring(v) end return table.concat(t, ",") end
local function s(v) return v and tostring(v):gsub("[/%*\n]", " ") or "" end
function CD:Serialize(list)
    local out = {}
    for _, e in ipairs(list) do
        local who = table.concat(e.who, ",")
        if e.kind == "interrupt" then out[#out + 1] = table.concat({ "INTERRUPT", s(e.k), cnt(e.counts), who, s(e.spell), s(e.text) }, "/")
        elseif e.kind == "note" then out[#out + 1] = table.concat({ "NOTE", s(e.k), who, s(e.text) }, "/")
        elseif e.kind == "health" or e.kind == "power" then
            out[#out + 1] = table.concat({ s(e.k), s(e.pct), who, s(e.time), s(e.spell), s(e.npc), s(e.text), s(e.tts), s(e.name), s(e.icon) }, "/")
        else
            out[#out + 1] = table.concat({ s(e.k), cnt(e.counts), who, s(e.time), s(e.spell), s(e.text), s(e.tts), s(e.name), s(e.icon) }, "/")
        end
    end
    return table.concat(out, "*")
end

local function resolve(list)
    local GS = Addon.GroupSetups
    for _, e in ipairs(list) do
        e.keys = {}
        for i, p in ipairs(e.who) do
            local name = GS and GS.KeyName and GS:KeyName(p)
            if name then e.keys[i] = p:upper(); e.who[i] = name end
        end
    end
    return list
end

local MELEE = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, MONK = true, DEMONHUNTER = true, PALADIN = true }
local RANGED_SPEC = { [102] = true, [253] = true, [254] = true, [255] = true, [62] = true, [63] = true, [64] = true, [258] = true, [262] = true,
    [265] = true, [266] = true, [267] = true, [1467] = true, [1473] = true }
local MELEE_SPEC = { [71] = true, [72] = true, [70] = true, [259] = true, [260] = true, [261] = true, [103] = true, [251] = true, [252] = true,
    [263] = true, [269] = true, [577] = true }

local function myRole()
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if role == "TANK" then return "TANKS" end
    if role == "HEALER" then return "HEALERS" end
    local _, class = UnitClass("player")
    local spec
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecializationInfo then
        local idx = C_SpecializationInfo.GetSpecialization()
        spec = idx and C_SpecializationInfo.GetSpecializationInfo(idx)
    elseif GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        spec = idx and GetSpecializationInfo(idx)
    end
    if spec and RANGED_SPEC[spec] then return "RANGEDDPS" end
    if spec and MELEE_SPEC[spec] then return "MELEEDPS" end
    return MELEE[class or ""] and "MELEEDPS" or "RANGEDDPS"
end

local ROLE_WORDS = { TANK = "TANKS", TANKS = "TANKS", HEALER = "HEALERS", HEALERS = "HEALERS", MELEE = "MELEEDPS", MELEEDPS = "MELEEDPS",
    RANGED = "RANGEDDPS", RANGEDDPS = "RANGEDDPS", DPS = "DPS" }

local meCache
local function me()
    if meCache and GetTime() - meCache.t < 5 then return meCache end
    local name = UnitName("player") or ""
    local GS = Addon.GroupSetups
    local full = GS and GS.KnownFull and GS.KnownFull(name) or name
    local _, class = UnitClass("player")
    local keys = {}
    local r = GS and GS.Roster_Keys and GS:Roster_Keys()
    for k, n in pairs(r and r.keys or {}) do
        local nl = n:lower()
        if nl == full:lower() or (nl:match("^(%S+)") == name:lower() and not (nl:find("%s") and full:find("%s") and nl ~= full:lower())) then keys[k:upper()] = true end
    end
    meCache = { t = GetTime(), first = name:lower(), full = full:lower(), class = class, role = myRole(), keys = keys }
    return meCache
end

function CD:IsMe(token, key)
    local m = me()
    token = trim(token or "")
    local up = token:upper()
    if up == "ALL" or up == "EVERYONE" or up == "RAID" then return true end
    if key and m.keys[key:upper()] then return true end
    if m.keys[up] then return true end
    if m.class and (up == m.class or up:gsub("%s", "") == m.class) then return true end
    local role = ROLE_WORDS[up]
    if role then return role == m.role or (role == "DPS" and (m.role == "MELEEDPS" or m.role == "RANGEDDPS")) end
    local low = (strsplit("-", token)):lower()
    if low == m.full or low == m.first then return true end
    local f = low:match("^(%S+)")
    if f == m.first then
        if low:find("%s") and m.full:find("%s") then return false end
        return true
    end
    return false
end

CD.active = nil
CD.all, CD.mine = {}, {}

local function rebuild()
    local all, mine = {}, {}
    local plan = CD.active
    for _, e in ipairs(plan and plan.list or {}) do
        if e.kind == "time" or e.kind == "health" or e.kind == "power" then
            all[e.k] = all[e.k] or {}
            table.insert(all[e.k], e)
            for i, p in ipairs(e.who) do
                if CD:IsMe(p, e.keys and e.keys[i]) then
                    mine[e.k] = mine[e.k] or {}
                    table.insert(mine[e.k], e)
                    break
                end
            end
        end
    end
    CD.all, CD.mine = all, mine
    for i = 1, #callbacks do pcall(callbacks[i]) end
    fire("FOJJI_ASSIGNMENTS_UPDATE")
end
CD.Rebuild = rebuild

function CD:GetAll() return self.all end
function CD:GetMine() return self.mine end
function CD:GetPlan() return self.active end
function CD:GetTyped(kind, key)
    local out = {}
    for _, e in ipairs(self.active and self.active.list or {}) do
        if e.kind == kind and (not key or e.k:upper() == key:upper()) then
            local copy = {}
            for k, v in pairs(e) do copy[k] = v end
            copy.mine = false
            for i, p in ipairs(e.who) do if self:IsMe(p, e.keys and e.keys[i]) then copy.mine = true end end
            out[#out + 1] = copy
        end
    end
    return out
end

local function setActive(plan, keep)
    CD.active = plan
    if not keep then db().received = plan end
    rebuild()
end

function CD:Import(text, title)
    local list, bad = self:Parse(text)
    if #list == 0 then say("Nothing to import - expected KEY/count/players/time/spellID lines.") return end
    title = trim(title or "")
    if title == "" then title = date("Assignments %d/%m %H:%M") end
    local plans = db().plans
    local plan = { title = title, text = text, t = time() }
    local at
    for i, p in ipairs(plans) do if p.title == title then at = i end end
    if at then plans[at] = plan else plans[#plans + 1] = plan; at = #plans end
    db().selected = at
    say(("Imported %d assignments%s as \"%s\"."):format(#list, bad > 0 and (" (" .. bad .. " lines skipped)") or "", title))
    self:Use(at)
    return at
end

function CD:Use(i, noSend)
    local p = db().plans[i]
    if not p then return end
    db().selected = i
    local list = resolve((self:Parse(p.text)))
    setActive({ title = p.title, by = UnitName("player"), t = time(), list = list, own = true })
    if not noSend and IsInGroup() then self:Send() end
end

function CD:DeletePlan(i)
    table.remove(db().plans, i)
    if db().selected == i then db().selected = nil end
    rebuild()
end

local function channel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local outbox, pumping = {}, false
local function pump()
    local m = table.remove(outbox, 1)
    if not m then pumping = false return end
    local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if send then pcall(send, PREFIX, m[1], m[2], m[3]) end
    C_Timer.After(0.12, pump)
end
local function queue(text, ch, target)
    outbox[#outbox + 1] = { text, ch, target }
    if not pumping then pumping = true; pump() end
end

local function isLead() return UnitIsGroupLeader and UnitIsGroupLeader("player") end
local function isAssist() return isLead() or (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) end

CD.lastSent = 0
function CD:Send(target, quiet)
    local plan = self.active
    if not (plan and plan.own) then if not quiet then say("Import or pick a plan first.") end return end
    local ch = channel()
    if not ch then if not quiet then say("Join a group to send assignments.") end return end
    if InCombatLockdown() then if not quiet then say("Can't send assignments in combat.") end return end
    local body = (plan.title or ""):gsub("[~]", "") .. "~" .. self:Serialize(plan.list)
    local id = tostring(math.random(1000, 9999))
    local size = 220
    local n = math.ceil(#body / size)
    for i = 1, n do
        local part = ("D%s:%d:%d:%s"):format(id, i, n, body:sub((i - 1) * size + 1, i * size))
        if target then queue(part, "WHISPER", target) else queue(part, ch) end
    end
    self.lastSent = GetTime()
    self.lastHash = body
    if not quiet then say(("Sent \"%s\" (%d assignments) to the %s."):format(plan.title or "assignments", #plan.list, target and target or (ch == "PARTY" and "party" or "raid"))) end
end

local function autoSend()
    if not (db().autoSend and isLead() and CD.active and CD.active.own) then return end
    local body = (CD.active.title or "") .. "~" .. CD:Serialize(CD.active.list)
    if body ~= CD.lastHash or GetTime() - CD.lastSent > 300 then CD:Send(nil, true) end
end

local function senderAllowed(sender)
    local mode = db().accept
    if mode == "all" then return true end
    local short = (strsplit("-", sender))
    local first = short:match("^(%S+)") or short
    if not IsInRaid() then return UnitIsGroupLeader and (UnitIsGroupLeader(short) or UnitIsGroupLeader(first)) end
    for i = 1, GetNumGroupMembers() do
        local name, rank = GetRaidRosterInfo(i)
        if name and readable(name) then
            local n = (strsplit("-", name))
            if n == short or (n:match("^(%S+)") or n) == first then return (rank or 0) >= (mode == "leader" and 2 or 1) end
        end
    end
    return false
end

local inbox, lastAsk = {}, 0
local function ask()
    if isLead() or not IsInGroup() or GetTime() - lastAsk < 60 then return end
    lastAsk = GetTime()
    local ch = channel()
    if ch then queue("Q", ch) end
end
CD.Request = ask

local comm = CreateFrame("Frame")
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
comm:RegisterEvent("CHAT_MSG_ADDON")
comm:RegisterEvent("READY_CHECK")
comm:RegisterEvent("PARTY_LEADER_CHANGED")
comm:RegisterEvent("GROUP_ROSTER_UPDATE")
comm:RegisterEvent("PLAYER_ENTERING_WORLD")
comm:RegisterEvent("PLAYER_LOGIN")
pcall(comm.RegisterEvent, comm, "START_PLAYER_COUNTDOWN")
pcall(comm.RegisterEvent, comm, "PLAYER_SPECIALIZATION_CHANGED")
pcall(comm.RegisterEvent, comm, "PLAYER_ROLES_ASSIGNED")
comm:SetScript("OnEvent", function(_, event, prefix, msg, _, sender)
    if event == "PLAYER_LOGIN" then
        local d = db()
        if d.selected and d.plans[d.selected] then CD:Use(d.selected, true)
        elseif d.received then setActive(d.received, true) end
        return
    end
    if event == "READY_CHECK" or event == "START_PLAYER_COUNTDOWN" or event == "PARTY_LEADER_CHANGED" then
        meCache = nil
        autoSend()
        if event ~= "PARTY_LEADER_CHANGED" then ask() end
        return
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ROLES_ASSIGNED" then
        meCache = nil
        if CD.active then rebuild() end
        if event ~= "PLAYER_SPECIALIZATION_CHANGED" then C_Timer.After(3, ask) end
        return
    end
    if (issecretvalue and issecretvalue(prefix)) or prefix ~= PREFIX then return end
    msg, sender = readable(msg), readable(sender)
    if not (msg and sender) then return end
    local short = (strsplit("-", sender))
    local myName = UnitName("player")
    if short == myName or short:match("^(%S+)") == myName then return end
    if msg == "Q" then
        if isLead() and CD.active and CD.active.own then
            if GetTime() - (CD.lastAnswer or 0) > 10 then CD.lastAnswer = GetTime(); CD:Send(nil, true) end
        end
        return
    end
    local id, i, n, rest = msg:match("^D(%d+):(%d+):(%d+):(.*)$")
    if not id or not senderAllowed(sender) then return end
    i, n = tonumber(i), tonumber(n)
    local box = inbox[sender .. id]
    if not box then box = { parts = {}, got = 0 }; inbox[sender .. id] = box end
    if not box.parts[i] then box.parts[i] = rest; box.got = box.got + 1 end
    if box.got < n then return end
    inbox[sender .. id] = nil
    local body = table.concat(box.parts)
    local title, text = body:match("^([^~]*)~(.*)$")
    local list = CD:Parse(text or "")
    if CD.active and CD.active.own and isLead() then return end
    setActive({ title = title, by = short, t = time(), list = list })
    say(("Assignments \"%s\" received from %s (%d entries)."):format(title or "?", short, #list))
end)

function CD:BossKeys(encounterID)
    local out = {}
    local RP = FojjiCore.RaidPacks
    for _, p in pairs(RP and RP.packs or {}) do
        for bk, b in pairs(p.bosses or {}) do if b.encounterID == encounterID then out[#out + 1] = bk end end
    end
    out[#out + 1] = "E" .. tostring(encounterID)
    return out
end

function CD:ForBoss(bossKey, everyone)
    local rows = {}
    if not bossKey then return rows end
    local prefix = bossKey:upper() .. "_"
    for _, e in ipairs(self.active and self.active.list or {}) do
        if (e.kind == "time" or e.kind == "health" or e.kind == "power") and e.k:upper():sub(1, #prefix) == prefix then
            local mine = false
            for i, p in ipairs(e.who) do if self:IsMe(p, e.keys and e.keys[i]) then mine = true end end
            if everyone or mine then
                local base = { key = e.k, time = e.time or 0, kind = e.kind, pct = e.pct, npc = e.npc, spellId = e.spell, name = e.name,
                    icon = e.icon, text = e.text, tts = e.tts, players = e.who, mine = mine, start = e.k:upper() == prefix .. "ENC_START" }
                if e.kind == "time" then
                    for _, c in ipairs(e.counts) do
                        local r = {}
                        for k, v in pairs(base) do r[k] = v end
                        r.count = c
                        rows[#rows + 1] = r
                    end
                else
                    rows[#rows + 1] = base
                end
            end
        end
    end
    return rows
end

function CD:Test()
    local row
    for _, list in pairs(self.mine) do row = row or list[1] end
    fire("FOJJI_ASSIGNMENTS_TEST", row and { key = row.k, spellId = row.spell, name = row.name, icon = row.icon, text = row.text, tts = row.tts }
        or { key = "TEST", spellId = 2825, text = "Test assignment" })
end
