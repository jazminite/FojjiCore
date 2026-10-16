local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Quests = {}
FDJ.Quests = Quests

local L = FDJ.L
local Book = FDJ.QuestBook

Quests.Style = {
    done = { color = "muted", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    ready = { color = "warn", icon = "Interface\\GossipFrame\\ActiveQuestIcon" },
    active = { color = "info", icon = "Interface\\GossipFrame\\IncompleteQuestIcon" },
    open = { color = "good", icon = "Interface\\GossipFrame\\AvailableQuestIcon" },
    chain = { color = "good", icon = "Interface\\GossipFrame\\AvailableQuestIcon" },
    low = { color = "dim", icon = "Interface\\GossipFrame\\AvailableQuestIcon", grey = true },
    faction = { color = "dim", icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    missing = { color = "dim", icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    unknown = { color = "dim", icon = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
}

local requested = {}

function Quests.Title(qid)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)
    if type(title) == "string" and title ~= "" then return title end
    if not requested[qid] and C_QuestLog.RequestLoadQuestByID then
        requested[qid] = true
        C_QuestLog.RequestLoadQuestByID(qid)
    end
    local q = Book[qid]
    return q and q.t or ("#" .. qid)
end

function Quests.InLog(qid)
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid)
    return index ~= nil and index > 0
end

local Chains, Steps = FDJ.QuestChains or {}, FDJ.QuestSteps or {}
function Quests.Step(qid)
    local chain = Chains[qid]
    if not chain or C_QuestLog.IsQuestFlaggedCompleted(qid) or Quests.InLog(qid) then return nil end
    local last = 0
    for i = #chain, 1, -1 do
        if C_QuestLog.IsQuestFlaggedCompleted(chain[i]) then last = i break end
    end
    local sid = chain[last + 1]
    if not sid then return nil end
    local s = Steps[sid] or {}
    return {
        qid = sid, index = last + 1, count = #chain + 1, inLog = Quests.InLog(sid),
        title = s[1], by = s[2], m = s[3], x = s[4], y = s[5], at = s[6],
    }
end

function Quests.StepTitle(step)
    if not step then return "" end
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(step.qid)
    return title or step.title or ("#" .. step.qid)
end

function Quests.StepWhere(step)
    if not step then return nil end
    if step.inLog then return L.CHAIN_IN_LOG:format(Quests.StepTitle(step)) end
    local who = step.by or L.CHAIN_NO_GIVER
    return step.at and (who .. "  ·  " .. step.at) or who
end

function Quests.Status(qid)
    local q = Book[qid]
    if not q then return "unknown" end
    if C_QuestLog.IsQuestFlaggedCompleted(qid) then return "done" end
    if Quests.InLog(qid) then
        if C_QuestLog.IsComplete and C_QuestLog.IsComplete(qid) then return "ready" end
        return "active"
    end
    if q.side and q.side ~= FDJ.Faction() then return "faction" end
    if Quests.Step(qid) then return "chain" end
    if FDJ.Level() < (q.req or 1) then return "low" end
    return "open"
end

function Quests.StatusText(code, qid)
    if code == "low" then return L.STATUS_LOW:format(Book[qid] and Book[qid].req or 0) end
    if code == "chain" then
        local step = Quests.Step(qid)
        if step then return L.STATUS_CHAIN:format(step.index, step.count) end
    end
    return L["STATUS_" .. code:upper()] or code
end

function Quests.Visible(qid)
    local q = Book[qid]
    if not q then return false end
    if q.side and q.side ~= FDJ.Faction() then return false end
    if FDJ:Option("hideDone") and C_QuestLog.IsQuestFlaggedCompleted(qid) then return false end
    return true
end

function Quests.ForDungeon(d, all)
    local out = {}
    for _, qid in ipairs(d.quests) do
        if all or Quests.Visible(qid) then out[#out + 1] = qid end
    end
    return out
end

function Quests.Summary(d)
    local counts = { open = 0, active = 0, ready = 0, done = 0, low = 0 }
    for _, qid in ipairs(d.quests) do
        local code = Quests.Status(qid)
        if code == "chain" then code = "open" end
        if counts[code] then counts[code] = counts[code] + 1 end
    end
    return counts
end

function Quests.Objectives(qid)
    if not Quests.InLog(qid) or not C_QuestLog.GetQuestObjectives then return nil end
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, qid)
    if ok and type(list) == "table" and #list > 0 then return list end
    return nil
end

function Quests.ChatName(qid)
    if Quests.InLog(qid) and GetQuestLink then
        local ok, link = pcall(GetQuestLink, qid)
        if ok and type(link) == "string" and link:find("|Hquest:", 1, true) then return link end
    end
    return "[" .. Quests.Title(qid):gsub("|", "") .. "]"
end

function Quests.Link(qid)
    if GetQuestLink then
        local ok, link = pcall(GetQuestLink, qid)
        if ok and type(link) == "string" then return link end
    end
    return "[" .. Quests.Title(qid) .. "]"
end

local INSIDE = {
    ["Ragefire Chasm"] = "ragefire", ["Wailing Caverns"] = "wailing", ["Blackfathom Deeps"] = "blackfathom",
    ["Gnomeregan"] = "gnomeregan", ["Razorfen Kraul"] = "kraul", ["Scarlet Monastery"] = "sm_graveyard",
    ["Razorfen Downs"] = "downs", ["Uldaman"] = "uldaman", ["Maraudon"] = "maraudon", ["Sunken Temple"] = "sunken",
    ["Blackrock Mountain"] = "brd", ["Blackrock Depths"] = "brd", ["Lower Blackrock Spire"] = "lbrs",
    ["Upper Blackrock Spire"] = "ubrs", ["Dire Maul"] = "dm_east", ["Stratholme"] = "stratholme",
    ["Scholomance"] = "scholomance", ["Ruins of Lordaeron"] = "lordaeron", ["Hall of Thanes"] = "hallofthanes",
    ["Excavation Site: Wetlands"] = "excavation",
    ["City of Dalaran"] = "dalaran",
}

function Quests.Spot(qid)
    local db = FDJ.db
    local step = Quests.Step(qid)
    if step then
        if step.inLog then return Quests.NextStep(step.qid), "step" end
        local spot = db.spots[step.qid]
        if spot then return spot, spot.how or "met" end
        if step.by and db.spots["@" .. step.by] then return db.spots["@" .. step.by], db.spots["@" .. step.by].how or "seen" end
        if step.m and step.x then return { m = step.m, x = step.x / 100, y = step.y / 100, how = "known" }, "known" end
        return nil
    end
    local spot = db.spots[qid]
    if spot then return spot, spot.how or "met" end
    local q = Book[qid]
    if q and q.by then
        spot = db.spots["@" .. q.by]
        if spot then return spot, spot.how or "seen" end
        spot = FDJ.GiverSpot(q.by)
        if spot then return spot, "known" end
    end
    local door = q and q.at and INSIDE[q.at] and FDJ.EntranceSpot and FDJ.EntranceSpot(INSIDE[q.at])
    if door then return { m = door.m, x = door.x, y = door.y, how = "known" }, "known" end
    return nil
end

function Quests.NextStep(qid)
    if not Quests.InLog(qid) or not C_QuestLog.GetNextWaypoint then return nil end
    local ok, mapID, x, y = pcall(C_QuestLog.GetNextWaypoint, qid)
    if ok and mapID and x and y then return { m = mapID, x = x, y = y, how = "step" } end
    return nil
end

local RANK = { pin = 5, met = 4, shared = 3, seen = 2, known = 1 }

local function playerSpot()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = FDJ.XY(pos)
    if not x or not y or FDJ.Secret(x) or (x == 0 and y == 0) then return nil end
    return mapID, x, y
end

function Quests.Remember(key, mapID, x, y, how, quiet)
    local db = FDJ.db
    local old = db.spots[key]
    if old and (RANK[old.how] or 0) > (RANK[how] or 0) then return false end
    if old and old.how == how and old.m == mapID and math.abs(old.x - x) < 0.004 and math.abs(old.y - y) < 0.004 then
        old.t = time()
        return false
    end
    db.spots[key] = { m = mapID, x = x, y = y, how = how, t = time() }
    if not quiet then FDJ:Emit("FDJ_SPOTS") end
    return true
end

local function learn(qid, how)
    local q = Book[qid]
    if not q or not UnitExists("npc") or UnitIsPlayer("npc") then return end
    local mapID, x, y = playerSpot()
    if not mapID then return end
    local changed = Quests.Remember(qid, mapID, x, y, how)
    local npc = UnitName("npc")
    if q.by and npc == q.by then changed = Quests.Remember("@" .. q.by, mapID, x, y, how) or changed end
    if changed and how == "met" and FDJ.Party then FDJ.Party.ShareSpot(qid) end
end

FDJ:On("QUEST_DETAIL", function()
    local qid = GetQuestID and GetQuestID()
    if qid and Book[qid] then
        learn(qid, "met")
        local xp = GetRewardXP and GetRewardXP()
        if type(xp) == "number" and not FDJ.Secret(xp) and xp > 0 then
            FDJ.db.xp = FDJ.db.xp or {}
            FDJ.db.xp[qid] = xp
        end
    end
end)

function Quests.XP(qid)
    if Quests.InLog(qid) and GetQuestLogRewardXP then
        local ok, xp = pcall(GetQuestLogRewardXP, qid)
        if ok and type(xp) == "number" and xp > 0 then
            FDJ.db.xp = FDJ.db.xp or {}
            FDJ.db.xp[qid] = xp
            return xp
        end
    end
    return FDJ.db.xp and FDJ.db.xp[qid] or nil
end

FDJ:On("GOSSIP_SHOW", function()
    if not (C_GossipInfo and C_GossipInfo.GetAvailableQuests) then return end
    for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
        if info.questID and Book[info.questID] then learn(info.questID, "met") end
    end
end)

FDJ:On("QUEST_GREETING", function()
    if not (GetNumAvailableQuests and GetAvailableQuestInfo) then return end
    for i = 1, GetNumAvailableQuests() do
        local qid = select(5, GetAvailableQuestInfo(i))
        if qid and Book[qid] then learn(qid, "met") end
    end
end)

FDJ:On("PLAYER_TARGET_CHANGED", function()
    if not UnitExists("target") or UnitIsPlayer("target") then return end
    local name = UnitName("target")
    if FDJ.Secret(name) then return end
    local list = name and FDJ.GiverQuests[name]
    if not list then return end
    local mapID, x, y = playerSpot()
    if mapID then Quests.Remember("@" .. name, mapID, x, y, "seen") end
end)

local function cacheLogXP()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and GetQuestLogRewardXP) then return end
    FDJ.db.xp = FDJ.db.xp or {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        local qid = info and not info.isHeader and info.questID
        if qid and Book[qid] then
            local ok, xp = pcall(GetQuestLogRewardXP, qid)
            if ok and type(xp) == "number" and not FDJ.Secret(xp) and xp > 0 then FDJ.db.xp[qid] = xp end
        end
    end
end

local function changed()
    FDJ.Debounce("questlog", 0.6, function()
        cacheLogXP()
        FDJ:Emit("FDJ_QUESTS")
    end)
end

FDJ:On("QUEST_COMPLETE", function()
    local qid = GetQuestID and GetQuestID()
    local xp = GetRewardXP and GetRewardXP()
    if qid and Book[qid] and type(xp) == "number" and not FDJ.Secret(xp) and xp > 0 then
        FDJ.db.xp = FDJ.db.xp or {}
        FDJ.db.xp[qid] = xp
    end
end)

FDJ:On("QUEST_LOG_UPDATE", changed)
FDJ:On("QUEST_ACCEPTED", changed)
FDJ:On("QUEST_REMOVED", changed)
FDJ:On("QUEST_TURNED_IN", changed)
FDJ:On("PLAYER_LEVEL_UP", changed)
FDJ:On("QUEST_DATA_LOAD_RESULT", function(qid)
    if Book[qid] then FDJ.Debounce("questdata", 1, function() FDJ:Emit("FDJ_QUESTS") end) end
end)

function Quests.Share(qid)
    if not Quests.InLog(qid) then
        FDJ.Print(L.SHARE_NOT_IN_LOG)
        return false
    end
    if C_QuestLog.IsPushableQuest and not C_QuestLog.IsPushableQuest(qid) then
        FDJ.Print(L.NOT_SHAREABLE)
        return false
    end
    if not FDJ.GroupChannel() then
        FDJ.Print(L.NOT_IN_GROUP)
        return false
    end
    C_QuestLog.SetSelectedQuest(qid)
    QuestLogPushQuest()
    return true
end
