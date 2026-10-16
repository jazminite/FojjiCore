local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Party = {}
FDJ.Party = Party

local L = FDJ.L
local Book = FDJ.QuestBook
local Quests = FDJ.Quests

Party.members = {}

local CODE_OUT = { done = "d", ready = "r", active = "a" }
local CODE_IN = { d = "done", r = "ready", a = "active" }

local function syncing()
    return FDJ:Option("partySync") and FDJ.GroupChannel() ~= nil
end

function Party.Roster()
    local list = {}
    local _, myClass = UnitClass("player")
    list[1] = { unit = "player", name = FDJ.PlayerName(), class = myClass, me = true }
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local _, class = UnitClass(unit)
                list[#list + 1] = { unit = unit, name = FDJ.Short(GetUnitName(unit, true)), class = class }
            end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local _, class = UnitClass(unit)
                list[#list + 1] = { unit = unit, name = FDJ.Short(GetUnitName(unit, true)), class = class }
            end
        end
    end
    return list
end

function Party.ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b } end
    return FDJ.Colors.text
end

function Party.HasAddon(name)
    return Party.members[name] ~= nil
end

function Party.MemberStatus(member, qid)
    if member.me then
        local code = Quests.Status(qid)
        if code == "done" or code == "ready" or code == "active" then return code end
        return "missing"
    end
    local data = Party.members[member.name]
    if data then
        local code = CODE_IN[data.states[qid] or ""]
        if code then return code end
    end
    if C_QuestLog.IsUnitOnQuest then
        local ok, on = pcall(C_QuestLog.IsUnitOnQuest, member.unit, qid)
        if ok and on and not FDJ.Secret(on) then return "active" end
    end
    if data then return "missing" end
    return "unknown"
end

function Party.Holders(qid)
    local has, lacks = {}, {}
    for _, member in ipairs(Party.Roster()) do
        local code = Party.MemberStatus(member, qid)
        if code == "active" or code == "ready" then
            has[#has + 1] = member.name
        elseif code == "missing" then
            lacks[#lacks + 1] = member.name
        end
    end
    return has, lacks
end

local function toBase36(n)
    local digits, out = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    repeat
        local r = n % 36
        out = digits:sub(r + 1, r + 1) .. out
        n = math.floor(n / 36)
    until n == 0
    return out
end

function Party.BuildState()
    local parts = {}
    for qid in pairs(Book) do
        local code = CODE_OUT[Quests.Status(qid)]
        if code then parts[#parts + 1] = code .. toBase36(qid) end
    end
    table.sort(parts)
    return ("1;%d;%s"):format(FDJ.Level(), table.concat(parts, ","))
end

function Party.ReadState(payload)
    local version, level, body = payload:match("^(%d+);(%d+);(.*)$")
    if version ~= "1" then return nil end
    local states = {}
    for code, id in body:gmatch("(%a)(%w+)") do
        local qid = tonumber(id, 36)
        if qid and CODE_IN[code] then states[qid] = code end
    end
    return states, tonumber(level)
end

local lastSent, forceNext
function Party.Broadcast(force)
    if not syncing() then return end
    if force == true then forceNext = true end
    FDJ.Debounce("partystate", force == true and 0.5 or 3, function()
        if not syncing() then return end
        local state = Party.BuildState()
        if state == lastSent and not forceNext then return end
        lastSent, forceNext = state, nil
        FDJ.Comm.Send("QS", state)
    end)
end

local pending

function Party.Request()
    if not syncing() then
        FDJ.Print(FDJ.GroupChannel() and L.SYNC_OFF or L.NOT_IN_GROUP)
        return
    end
    FDJ.Comm.Send("QR", "")
    Party.Broadcast(true)
    local asked = GetTime()
    FDJ.Print(L.SYNC_ASKING)
    pending = { at = asked, got = {} }
    local mine = pending
    C_Timer.After(6, function()
        if pending ~= mine then return end
        pending = nil
        local none = {}
        for _, member in ipairs(Party.Roster()) do
            if not member.me and not mine.got[member.name] then
                none[#none + 1] = FDJ.Paint(Party.ClassColor(member.class), member.name)
            end
        end
        if #none > 0 then FDJ.Print(L.SYNC_NONE:format(table.concat(none, ", "))) end
    end)
end

function Party.ShareSpot(qid)
    if not syncing() then return end
    local spot = FDJ.db.spots[qid]
    if not spot then return end
    FDJ.Comm.Send("SP", ("%d,%d,%.4f,%.4f"):format(qid, spot.m, spot.x, spot.y))
end

function Party.AskLine(qid)
    local has, lacks = Party.Holders(qid)
    if #has == 0 then return nil end
    local line = Quests.ChatName(qid) .. " - " .. L.REPORT_HAVE .. " " .. table.concat(has, ", ")
    if #lacks > 0 then line = line .. " - " .. L.REPORT_NEED .. " " .. table.concat(lacks, ", ") end
    return line
end

function Party.Ask(qid)
    if not FDJ.GroupChannel() then
        FDJ.Print(L.NOT_IN_GROUP)
        return
    end
    local line = Party.AskLine(qid)
    if not line then
        FDJ.Print(L.ASK_NOBODY:format(FDJ.Q(Quests.Title(qid))))
        return
    end
    FDJ.Say(line)
end

function Party.Report(d)
    local lines = { L.REPORT_HEAD:format(FDJ.DungeonTitle(d)) }
    local roster = Party.Roster()
    if #roster < 2 then
        FDJ.Print(L.NOT_IN_GROUP)
        return
    end
    for _, qid in ipairs(Quests.ForDungeon(d)) do
        local q = Book[qid]
        if not q.side or q.side == FDJ.Faction() then
            local line = Party.AskLine(qid)
            if line then lines[#lines + 1] = line end
        end
    end
    if #lines == 1 then lines[2] = L.REPORT_NONE end
    FDJ.Say(lines)
end

FDJ:On("FDJ_COMM", function(kind, payload, sender)
    if kind == "QS" then
        local states, level = Party.ReadState(payload)
        if states then
            Party.members[sender] = { states = states, level = level, seen = GetTime() }
            if pending and not pending.got[sender] then
                pending.got[sender] = true
                local class
                for _, member in ipairs(Party.Roster()) do
                    if member.name == sender then class = member.class end
                end
                FDJ.Print(L.SYNC_GOT:format(FDJ.Paint(Party.ClassColor(class), sender)))
            end
            FDJ.Debounce("partyview", 0.5, function() FDJ:Emit("FDJ_PARTY") end)
        end
    elseif kind == "QR" then
        Party.Broadcast(true)
    elseif kind == "SP" then
        local qid, m, x, y = payload:match("^(%d+),(%d+),([%d%.]+),([%d%.]+)$")
        qid, m, x, y = tonumber(qid), tonumber(m), tonumber(x), tonumber(y)
        if qid and Book[qid] and m and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            Quests.Remember(qid, m, x, y, "shared")
        end
    end
end)

local known = {}
local function rosterChanged()
    local present, joined = {}, false
    for _, member in ipairs(Party.Roster()) do
        present[member.name] = true
        if not member.me and not known[member.name] then joined = true end
    end
    known = present
    for name in pairs(Party.members) do
        if not present[name] then Party.members[name] = nil end
    end
    if joined and syncing() then
        FDJ.Debounce("partyask", 2, function() if syncing() then FDJ.Comm.Send("QR", "") end end)
    end
    Party.Broadcast(true)
    FDJ.Debounce("partyview", 0.5, function() FDJ:Emit("FDJ_PARTY") end)
end

FDJ:On("GROUP_ROSTER_UPDATE", rosterChanged)
FDJ:On("PLAYER_ENTERING_WORLD", rosterChanged)
FDJ:On("FDJ_QUESTS", function() Party.Broadcast() end)
FDJ:On("UNIT_QUEST_LOG_CHANGED", function(unit)
    if unit ~= "player" then FDJ.Debounce("partyview", 1, function() FDJ:Emit("FDJ_PARTY") end) end
end)
