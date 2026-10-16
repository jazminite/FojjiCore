local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end

local RD = {}
Addon.RaidData = RD
FojjiCore = FojjiCore or {}
FojjiCore.RaidData = RD

local PREFIX = "FJRD"
local NOTE = "NOTE"

local function say(msg) if Addon.Print then Addon.Print(msg) else print("FojjiCore: " .. msg) end end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function readable(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local function me() return (UnitName("player")) end
local function shortName(n) return ((strsplit("-", n or ""))) end

local function db()
    FojjiCoreDB = FojjiCoreDB or {}
    local d = FojjiCoreDB.raidData
    if type(d) ~= "table" then d = {}; FojjiCoreDB.raidData = d end
    return d
end

local function packData(pack, create)
    local d = db()
    local p = d[pack]
    if not p and create then
        p = { values = {}, rev = 0 }
        d[pack] = p
    end
    if p then p.values = p.values or {} end
    return p
end

local callbacks = {}
function RD:OnChange(fn) callbacks[#callbacks + 1] = fn end

local function fire(pack, key)
    for i = 1, #callbacks do pcall(callbacks[i], pack, key) end
    local api = Addon.AuraAPI or _G.WeakAuras
    if api and api.ScanEvents then pcall(api.ScanEvents, "FOJJI_RAID_DATA", pack, key or "ALL") end
end
RD.Fire = fire

RD.slots = {}

local function slotList(pack)
    local s = RD.slots[pack]
    if not s then
        s = { list = {}, byKey = {} }
        RD.slots[pack] = s
    end
    return s
end

function RD:RegisterSlot(pack, slot)
    if type(pack) ~= "string" or type(slot) ~= "table" or type(slot.key) ~= "string" or slot.key == "" then return false end
    local key = slot.key:gsub("[%s=~%^%[%]]", "_")
    local s = slotList(pack)
    local entry = s.byKey[key]
    if not entry then
        entry = { key = key }
        s.byKey[key] = entry
        s.list[#s.list + 1] = entry
    end
    entry.boss = slot.boss or entry.boss
    entry.name = slot.name or entry.name or key
    entry.help = slot.help or entry.help
    entry.example = slot.example or entry.example
    entry.lines = slot.lines or entry.lines
    return true
end

function RD:GetSlots(pack)
    local RP = FojjiCore.RaidPacks
    local p = RP and RP.packs and RP.packs[pack]
    local order = {}
    for i, bk in ipairs(p and p.bossOrder or {}) do order[bk] = i end
    local out = {}
    for i, e in ipairs(slotList(pack).list) do
        if e.key ~= NOTE then out[#out + 1] = { e = e, i = i } end
    end
    table.sort(out, function(a, b)
        local oa, ob = order[a.e.boss or ""] or 999, order[b.e.boss or ""] or 999
        if oa ~= ob then return oa < ob end
        return a.i < b.i
    end)
    local list = {}
    for _, x in ipairs(out) do
        local e = x.e
        local boss = e.boss and p and p.bosses[e.boss]
        list[#list + 1] = { key = e.key, boss = e.boss, bossName = boss and boss.name or e.boss, name = e.name, help = e.help, example = e.example, lines = e.lines }
    end
    local note = slotList(pack).byKey[NOTE]
    list[#list + 1] = {
        key = NOTE, name = note and note.name or "Raid note",
        help = note and note.help or "Anything for the raid. Lines with someone's name show up as their assignment.",
        example = note and note.example or "Kaz'rogal: Fojji soaks Mark\nArchimonde: Healers dispel Doomfire",
        lines = 5,
    }
    return list
end

function RD:Get(pack, key)
    local p = packData(pack)
    local v = p and p.values[key]
    if v == nil or v == "" then return nil end
    return v
end

function RD:Set(pack, key, text, quiet)
    text = text or ""
    local p = packData(pack, true)
    if (p.values[key] or "") == text then return end
    p.values[key] = text ~= "" and text or nil
    p.rev = (p.rev or 0) + 1
    p.by = me()
    p.t = time()
    p.mine = true
    if not quiet then fire(pack, key) end
end

function RD:Info(pack)
    local p = packData(pack)
    if not p then return nil end
    local n = 0
    for _, v in pairs(p.values) do if v ~= "" then n = n + 1 end end
    return { by = p.by, t = p.t, rev = p.rev or 0, mine = p.mine, sent = p.sent, count = n }
end

function RD:Clear(pack)
    local p = packData(pack)
    if not p then return end
    p.values = {}
    p.rev = (p.rev or 0) + 1
    p.by, p.t, p.mine = me(), time(), true
    fire(pack, "ALL")
end

function RD.ParseRows(text)
    local rows = {}
    text = trim(text)
    if text == "" then return rows end
    local lines = {}
    if not text:find("\n") and text:find("^[^:]+:[^:]") and text:find("%-[^%-:]+:") then
        for part in (text .. "-"):gmatch("([^%-]*)%-") do lines[#lines + 1] = part end
    else
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
    end
    for _, line in ipairs(lines) do
        line = trim(line)
        if line ~= "" and not line:find("^#") and not line:find("^%-%-") then
            local label, rest = line:match("^(.*):(.-)$")
            if not label then label, rest = "", line end
            local names = {}
            for n in rest:gmatch("[^,%s]+") do names[#names + 1] = n end
            rows[#rows + 1] = { label = trim(label), names = names, line = line }
        end
    end
    return rows
end

function RD:Rows(pack, key)
    return RD.ParseRows(self:Get(pack, key))
end

function RD:Mine(pack, key, name)
    name = (shortName(name or me()) or ""):lower()
    if name == "" then return nil end
    for i, row in ipairs(self:Rows(pack, key)) do
        for _, n in ipairs(row.names) do
            if shortName(n):lower() == name then return i, row end
        end
    end
    return nil
end

function RD:Export(pack)
    local p = packData(pack)
    local out = { "# Fojji raid data: " .. pack }
    local seen = {}
    for _, slot in ipairs(self:GetSlots(pack)) do
        seen[slot.key] = true
        local v = p and p.values[slot.key]
        if v and v ~= "" then
            out[#out + 1] = "[" .. slot.key .. "]"
            out[#out + 1] = v
        end
    end
    for key, v in pairs(p and p.values or {}) do
        if not seen[key] and v ~= "" then
            out[#out + 1] = "[" .. key .. "]"
            out[#out + 1] = v
        end
    end
    return table.concat(out, "\n")
end

function RD:Import(text, pack)
    text = (text or ""):gsub("\r", "")
    local named = text:match("^%s*#%s*Fojji raid data:%s*([%w_]+)")
    pack = named or pack
    if not pack then say("Pick a raid pack first.") return end
    local values, key, buf = {}, nil, {}
    local function flush()
        if key then values[key] = trim(table.concat(buf, "\n")) end
        buf = {}
    end
    local found = false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local k = line:match("^%s*%[([%w_]+)%]%s*$")
        if k then
            flush()
            key = k
            found = true
        elseif key then
            buf[#buf + 1] = line
        end
    end
    flush()
    if not found then say("That isn't raid data (it needs [KEY] lines, as Export makes).") return end
    local p = packData(pack, true)
    p.values = {}
    for k, v in pairs(values) do if v ~= "" then p.values[k] = v end end
    p.rev = (p.rev or 0) + 1
    p.by, p.t, p.mine = me(), time(), true
    local RP = FojjiCore.RaidPacks
    local info = RP and RP.packs and RP.packs[pack]
    say(("Imported raid data for %s."):format(info and info.name or pack))
    fire(pack, "ALL")
    return pack
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local function clean(s) return (tostring(s or ""):gsub("[~%^]", ""):gsub("\n", "{nl}")) end
local function unclean(s) return (tostring(s or ""):gsub("{nl}", "\n")) end

local function serialize(pack)
    local p = packData(pack, true)
    local parts = { table.concat({ "1", pack, tostring(p.rev or 0) }, "~") }
    for k, v in pairs(p.values) do
        if v ~= "" then parts[#parts + 1] = k .. "=" .. clean(v) end
    end
    return table.concat(parts, "^")
end

local function deserialize(body)
    local first, pack, values = true, nil, {}
    local rev
    for chunk in (body .. "^"):gmatch("([^%^]*)%^") do
        if first then
            first = false
            local v, pk, r = strsplit("~", chunk)
            if v ~= "1" or not pk or pk == "" then return nil end
            pack, rev = pk, tonumber(r) or 0
        elseif chunk ~= "" then
            local k, v = chunk:match("^([^=]+)=(.*)$")
            if k then values[k] = unclean(v) end
        end
    end
    return pack, values, rev
end

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

function RD.CanSend()
    if not channel() then return false end
    if IsInRaid() then return (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) or false end
    return true
end

function RD:Send(pack, quiet)
    local ch = channel()
    if not ch then if not quiet then say("Join a group to send raid data.") end return false end
    if not RD.CanSend() then if not quiet then say("Only the raid leader or an assistant can send raid data.") end return false end
    local body = serialize(pack)
    local id = tostring(math.random(1000, 9999))
    local size = 220
    local n = math.max(1, math.ceil(#body / size))
    for i = 1, n do
        queue(("D%s:%d:%d:%s"):format(id, i, n, body:sub((i - 1) * size + 1, i * size)), ch)
    end
    local p = packData(pack, true)
    p.sent = time()
    if not quiet then
        local RP = FojjiCore.RaidPacks
        local info = RP and RP.packs and RP.packs[pack]
        say(("Sent %s raid data to the %s."):format(info and info.name or pack, ch == "PARTY" and "party" or "raid"))
    end
    for i = 1, #callbacks do pcall(callbacks[i], pack, "SENT") end
    return true
end

function RD:Request()
    local ch = channel()
    if ch then queue("R", ch) end
end

local function senderAllowed(sender)
    if not IsInRaid() then
        return UnitIsGroupLeader and UnitIsGroupLeader(sender) or false
    end
    local short = shortName(sender)
    for i = 1, GetNumGroupMembers() do
        local name, rank = GetRaidRosterInfo(i)
        name = readable(name)
        if name and shortName(name) == short then return (rank or 0) >= 1 end
    end
    return false
end

local inbox = {}
local function receive(sender, body)
    local pack, values = deserialize(body)
    if not pack then return end
    local p = packData(pack, true)
    p.values = values
    p.rev = (p.rev or 0) + 1
    p.by, p.t, p.mine, p.sent = sender, time(), nil, nil
    local RP = FojjiCore.RaidPacks
    local info = RP and RP.packs and RP.packs[pack]
    say(("Raid data for %s from %s."):format(info and info.name or pack, sender))
    fire(pack, "ALL")
end

local lastAnswer = 0
local comm = CreateFrame("Frame")
comm:RegisterEvent("CHAT_MSG_ADDON")
comm:RegisterEvent("GROUP_JOINED")
comm:SetScript("OnEvent", function(_, event, prefix, msg, _, sender)
    if event == "GROUP_JOINED" then
        C_Timer.After(6, function() if IsInRaid() then RD:Request() end end)
        return
    end
    if (issecretvalue and issecretvalue(prefix)) or prefix ~= PREFIX then return end
    msg, sender = readable(msg), readable(sender)
    if not (msg and sender) then return end
    local short = shortName(sender)
    if short == me() then return end
    if msg == "R" then
        if not (UnitIsGroupLeader and UnitIsGroupLeader("player")) or GetTime() - lastAnswer < 10 then return end
        lastAnswer = GetTime()
        for pack, p in pairs(db()) do
            if p.mine and next(p.values or {}) then RD:Send(pack, true) end
        end
        return
    end
    local id, i, n, rest = msg:match("^D(%d+):(%d+):(%d+):(.*)$")
    if not id or not senderAllowed(sender) then return end
    i, n = tonumber(i), tonumber(n)
    local box = inbox[sender .. id]
    if not box then box = { parts = {}, got = 0 }; inbox[sender .. id] = box end
    if not box.parts[i] then box.parts[i] = rest; box.got = box.got + 1 end
    if box.got >= n then
        inbox[sender .. id] = nil
        receive(short, table.concat(box.parts))
    end
end)

local RP = FojjiCore.RaidPacks
if RP then
    function RP:RegisterRaidSlot(pack, slot) return RD:RegisterSlot(pack, slot) end
    function RP:GetRaidData(pack, key) return RD:Get(pack, key) end
    function RP:GetRaidRows(pack, key) return RD:Rows(pack, key) end
    function RP:GetMyRaidRow(pack, key, name) return RD:Mine(pack, key, name) end
end
