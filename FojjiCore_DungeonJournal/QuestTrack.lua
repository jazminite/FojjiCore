local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Track = {}
FDJ.QuestTrack = Track

local Quests = FDJ.Quests

function Track.On() return FDJ.opt and FDJ.opt.autoTrack == true end

local function logIndex(qid)
    local i = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid)
    if (not i or i == 0) and GetQuestLogIndexByID then i = GetQuestLogIndexByID(qid) end
    return (type(i) == "number" and i > 0) and i or nil
end

local function watched()
    local list = {}
    if C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        for i = 1, C_QuestLog.GetNumQuestWatches() or 0 do
            local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if id then list[#list + 1] = id end
        end
        return list
    end
    local count = (C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries()) or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
    for i = 1, count do
        local id
        if C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(i)
            id = info and not info.isHeader and info.questID
        elseif GetQuestLogTitle then
            local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
            id = not isHeader and questID
        end
        if id and IsQuestWatched and IsQuestWatched(i) then list[#list + 1] = id end
    end
    return list
end

local function setWatch(qid, on)
    if C_QuestLog.AddQuestWatch and C_QuestLog.RemoveQuestWatch then
        if on then C_QuestLog.AddQuestWatch(qid) else C_QuestLog.RemoveQuestWatch(qid) end
        return
    end
    local i = logIndex(qid)
    if not i then return end
    if on and AddQuestWatch then AddQuestWatch(i) elseif not on and RemoveQuestWatch then RemoveQuestWatch(i) end
end

local function enter(d)
    if not (Track.On() and FDJ.char and d) then return end
    local wanted = {}
    for _, qid in ipairs(Quests.ForDungeon(d) or {}) do
        if logIndex(qid) then wanted[qid] = true end
    end
    if not next(wanted) then return end
    local now = watched()
    if not FDJ.char.trackSaved then FDJ.char.trackSaved = now end
    for _, qid in ipairs(now) do
        if not wanted[qid] then setWatch(qid, false) end
    end
    local room = tonumber(MAX_WATCHABLE_QUESTS) or 25
    local n = 0
    for qid in pairs(wanted) do
        n = n + 1
        if n <= room then setWatch(qid, true) end
    end
end

local function leave()
    local saved = FDJ.char and FDJ.char.trackSaved
    if not saved then return end
    FDJ.char.trackSaved = nil
    local keep = {}
    for _, qid in ipairs(saved) do keep[qid] = true end
    for _, qid in ipairs(watched()) do
        if not keep[qid] then setWatch(qid, false) end
    end
    for _, qid in ipairs(saved) do
        if logIndex(qid) then setWatch(qid, true) end
    end
end

FDJ:On("FDJ_ENTERED", enter)
FDJ:On("PLAYER_ENTERING_WORLD", function()
    local _, kind = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then leave() end
end)

function Track.Set(on)
    if FDJ.opt then FDJ.opt.autoTrack = on and true or false end
    if on then
        local d = FDJ.CurrentDungeon()
        if d then enter(d) end
    else
        leave()
    end
end
