-- /speedrun or /fsr: start, stop, reset, demo, show, hide, preview, lock, unlock, ids
-- Speedrun API for ForeverAuras packs:
--   FojjiCore.Speedrun:GetState()       "idle" | "running" | "finished" | "stopped"
--   FojjiCore.Speedrun:GetElapsed()     elapsed seconds; frozen when the run ends
--   FojjiCore.Speedrun:GetSnapshot()    current timer state and boss rows
--   FojjiCore.Speedrun:GetRows()        boss rows with pull, split and comparison data
--   FojjiCore.Speedrun:ShouldShow()     whether the built-in tracker should be visible
--
-- Events sent through ForeverAuras.ScanEvents:
--   FOJJI_CORE_SPEEDRUN_START   (instanceKey, startEpoch)
--   FOJJI_CORE_SPEEDRUN_PULL    (encounterID, bossName, elapsedOrNil, attempt)
--   FOJJI_CORE_SPEEDRUN_WIPE    (encounterID, bossName, elapsed, attempt)
--   FOJJI_CORE_SPEEDRUN_SPLIT   (encounterID, bossName, elapsed, deltaOrNil)
--   FOJJI_CORE_SPEEDRUN_FINISH  (instanceKey, elapsed, isPersonalBest)
--   FOJJI_CORE_SPEEDRUN_STOP    (instanceKey, elapsed)
--   FOJJI_CORE_SPEEDRUN_RESET   ()
--   FOJJI_CORE_SPEEDRUN_UPDATED () -- re-read GetSnapshot()

local _, Addon = ...
local D = Addon.SRData

local SR = { state = "idle" }
FojjiCore.Speedrun = SR

local SYNC_PREFIX = "FojjiRun1"
local MAX_HISTORY = 25
local MAX_RUN_AGE = 6 * 3600
local EXPORT_TAG = "FCSR1:"
local MAX_IMPORT_CHARS = 4000
local MAX_SEEN = 30

local Store = Addon.GetSpeedrunStore

C_ChatInfo.RegisterAddonMessagePrefix(SYNC_PREFIX)

local function Secret(...)
    return hasanysecretvalues ~= nil and hasanysecretvalues(...) or false
end

function SR:GetStore() return Store() end

local subscribers = {}

function SR:Subscribe(fn) subscribers[#subscribers + 1] = fn end

local function Emit(event, ...)
    local api = Addon.AuraAPI
    if api and api.ScanEvents then api.ScanEvents(event, ...) end
    for _, fn in ipairs(subscribers) do fn(event, ...) end
end

local function Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

local function Changed(persist)
    if persist ~= false then SR:Persist() end
    if SR.OnChanged then SR.OnChanged() end
    Emit("FOJJI_CORE_SPEEDRUN_UPDATED")
end

function SR:Notify() Changed(false) end

function SR.FormatTime(seconds, decimals)
    if type(seconds) ~= "number" then return "--:--" end
    if seconds < 0 then seconds = 0 end
    decimals = decimals or 0
    local tenths = math.floor(seconds * 10 + 0.000001)
    local whole = math.floor(tenths / 10)
    local h = math.floor(whole / 3600)
    local m = math.floor((whole % 3600) / 60)
    local s = whole % 60
    local text
    if h > 0 then text = string.format("%d:%02d:%02d", h, m, s)
    else text = string.format("%02d:%02d", m, s) end
    if decimals > 0 then text = text .. "." .. tostring(tenths % 10) end
    return text
end

function SR.FormatDelta(delta, decimals)
    if type(delta) ~= "number" then return "" end
    local sign = delta < 0 and "-" or "+"
    local a = math.abs(delta)
    if a < 60 then
        if decimals and decimals > 0 and a < 10 then return string.format("%s%.1f", sign, a) end
        return string.format("%s%02d", sign, math.floor(a + 0.5))
    end
    a = math.floor(a + 0.5)
    return string.format("%s%02d:%02d", sign, math.floor(a / 60), a % 60)
end

local function InstanceInfo()
    local inInstance, kind = IsInInstance()
    if not inInstance then return nil end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    if Secret(name, id, kind) or type(id) ~= "number" then return nil end
    return id, name, kind
end

local function RouteKeyForInstance()
    local id, name, kind = InstanceInfo()
    if not id then return nil end
    if kind == "raid" then return id, name, kind end
    if kind == "party" and Store().visibility ~= "raid" then return id, name, kind end
end

local function SeenList(key)
    return key and Store().seen[key] or nil
end

local function RememberBoss(key, id, name)
    if not key or type(id) ~= "number" or type(name) ~= "string" then return end
    local db = Store()
    local list = db.seen[key]
    if not list then list = {}; db.seen[key] = list end
    for _, item in ipairs(list) do if item.id == id then return end end
    if #list < MAX_SEEN then list[#list + 1] = { id = id, name = name:gsub("[%c|]", ""):sub(1, 60) } end
end

function SR:GetState() return self.state end
function SR:IsRunning() return self.state == "running" end

function SR:GetElapsed()
    local run = self.run
    if not run then return 0 end
    if self.state == "running" then return math.max(0, GetTime() - run.startTime) end
    return run.elapsed or 0
end

function SR:GetRules(key)
    local rules = Store().rules
    rules[key] = rules[key] or {}
    return rules[key]
end

function SR:GetBossOrder(key) return Store().bossOrder[key] end
function SR:SetBossOrder(key, order)
    local db = Store()
    if order and #order > 0 then db.bossOrder[key] = order else db.bossOrder[key] = nil end
    if self.route and self.route.key == key then self.route = D.NewRoute(key, nil, SeenList(key), order) end
    Changed(false)
end
function SR:MoveBoss(key, id, delta)
    local src = D.raids[key]
    if not src or src.dynamic then return end
    local order = self:GetBossOrder(key)
    local list = {}
    if order then for _, v in ipairs(order) do list[#list + 1] = v end
    else for _, boss in ipairs(src.bosses) do list[#list + 1] = boss.id end end
    local at
    for i, v in ipairs(list) do if v == id then at = i; break end end
    if not at then return end
    local to = at + delta
    if to < 1 or to > #list then return end
    list[at], list[to] = list[to], list[at]
    self:SetBossOrder(key, list)
end

function SR:Persist()
    local db = Store()
    local run = self.run
    if not run or self.state == "idle" or run.demo then db.active = nil; return end
    db.active = {
        state = self.state, key = run.key, routeName = self.route and self.route.name,
        startEpoch = run.startEpoch, elapsed = run.elapsed, splits = run.splits, pulls = run.pulls,
        attempts = run.attempts, order = run.order, extra = run.extra, grouped = run.grouped,
        wipes = run.wipes, isPB = run.isPB,
    }
end

function SR:GetReference(key, demo)
    if demo then return self.demoRef end
    local db = Store()
    local mode = db.compare
    if mode == "none" then return nil end
    if mode == "import" then return db.imports[key] or db.bests[key] end
    if mode == "pinned" then
        local id = db.pinned[key]
        if id then
            for _, entry in ipairs(db.history) do
                if entry.id == id then
                    return { final = entry.final, splits = entry.splits, pulls = entry.pulls, label = date("%d %b %H:%M", entry.date or 0) }
                end
            end
        end
    end
    return db.bests[key]
end

function SR:GetActiveReference()
    if self.run then return self.run.ref end
    if self.route then return self:GetReference(self.route.key) end
end

function SR:GetDelta(encounterID)
    local run, ref = self.run, self:GetActiveReference()
    if run and ref and ref.splits and run.splits[encounterID] and ref.splits[encounterID] then
        return run.splits[encounterID] - ref.splits[encounterID]
    end
end

function SR:RefreshRoute(entering)
    local db = Store()
    local key, name = RouteKeyForInstance()
    if entering then self.arrivalUntil = GetTime() + 10; self.manuallyHidden = nil end
    self.lastInstanceKey = key

    if self.state ~= "idle" and self.run and not self.run.demo and key and key ~= self.run.key and db.resetOnZone then
        self:Reset(true, true)
        Addon.Print("Run timer reset: you entered a different instance.")
    end
    if self.state == "idle" then
        local want = db.routeOverride or key
        if want and (D.raids[want] or want == key) then

            self.route = D.NewRoute(want, want == key and name or nil, SeenList(want), db.bossOrder[want])
        else
            self.route = nil
        end

        if db.startMode == "instance" and key and self.arrivalUntil and GetTime() < self.arrivalUntil and not db.routeOverride then
            self.arrivalUntil = nil
            self:Start("auto")
            return
        end
    end
    Changed(false)
end

function SR:SetRouteOverride(key)
    Store().routeOverride = key
    if self.state == "idle" then self.route = nil end
    self:RefreshRoute()
end

function SR:ShouldShow()
    local db = Store()
    if self.preview then return true end
    if self.manuallyHidden then return false end
    local mode = db.visibility
    if mode == "never" then return false end
    if self.state ~= "idle" then
        local run = self.run
        if self.state ~= "running" and db.hideAfterFinish > 0 and run and run.endedAt and GetTime() - run.endedAt > db.hideAfterFinish then
            return false
        end
        return true
    end
    if mode == "always" then return true end
    if mode == "run" then return false end
    local id, _, kind = InstanceInfo()
    if mode == "group" then return IsInRaid() end
    if not id then return false end
    if mode == "raid" then return kind == "raid" end

    return kind == "raid" or kind == "party"
end

local function MemberUnit(sender)
    if not IsInRaid() or type(sender) ~= "string" then return end
    local short = Ambiguate(sender, "short")
    for index = 1, GetNumGroupMembers() do
        local unit = "raid" .. index
        local name = UnitName(unit)
        if not Secret(name) and name and name == short then return unit end
    end
end

local function SendSync(message)
    if not IsInRaid() or InCombatLockdown() then return end
    if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then return end
    pcall(C_ChatInfo.SendAddonMessageLogged, SYNC_PREFIX, message, "RAID")
end

local function OnSync(prefix, message, channel, sender)
    if Secret(prefix, message, channel, sender) then return end
    if prefix ~= SYNC_PREFIX or channel ~= "RAID" or type(message) ~= "string" or #message > 24 then return end
    if not Store().follow then return end
    local unit = MemberUnit(sender)
    if not unit or UnitIsUnit(unit, "player") then return end
    if not (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)) then return end
    if message == "R" then
        if SR.state ~= "idle" then
            SR:Reset(true, true)
            Addon.Print(Ambiguate(sender, "short") .. " reset the run timer.")
        end
        return
    end
    local offset = tonumber(message:match("^S:(%d+%.?%d*)$"))
    if offset and offset < MAX_RUN_AGE and SR.state ~= "running" then
        SR:Start("sync", offset)
        Addon.Print(Ambiguate(sender, "short") .. " started the run timer.")
    end
end

function SR:Start(source, offset, opts)
    if self.state == "running" then return false end
    if self.state ~= "idle" then self:Reset(true, true) end
    offset = math.max(0, tonumber(offset) or 0)
    local demo = opts and opts.demo
    local db = Store()
    if not demo then

        local key, name = RouteKeyForInstance()
        if not key then key, name = InstanceInfo() end
        key = db.routeOverride or key
        if not self.route or self.route.key ~= key then
            self.route = D.NewRoute(key or 0, name, SeenList(key), db.bossOrder[key])
        end
    elseif not self.route then
        self.route = D.NewRoute(0, "Custom run")
    end
    self.run = {
        key = self.route.key,
        startTime = GetTime() - offset,
        startEpoch = time() - math.floor(offset),
        splits = {}, pulls = {}, attempts = {}, order = {}, extra = {}, wipes = 0,
        grouped = IsInGroup(), source = source or "manual", demo = demo,
    }
    self.run.ref = self:GetReference(self.route.key, demo)
    self.state = "running"
    self.manuallyHidden = nil
    Emit("FOJJI_CORE_SPEEDRUN_START", self.run.key, self.run.startEpoch)
    if source == "manual" then SendSync(string.format("S:%.1f", offset)) end
    Changed()
    return true
end

function SR:Stop()
    if self.state ~= "running" then return end
    self.run.elapsed = self:GetElapsed()
    self.run.endedAt = GetTime()
    self.state = "stopped"

    if self.run.demo then
        local run = self.run
        C_Timer.After(4, function() if SR.run == run then SR:Reset(true, true) end end)
    end
    Emit("FOJJI_CORE_SPEEDRUN_STOP", self.run.key, self.run.elapsed)
    Changed()
end

local function RecomputeBest(key)
    local db = Store()
    local best
    for _, entry in ipairs(db.history) do
        if entry.key == key and (not best or entry.final < best.final) then best = entry end
    end
    if best then
        db.bests[key] = { id = best.id, final = best.final, splits = Copy(best.splits), pulls = Copy(best.pulls), date = best.date, name = best.name }
    else
        db.bests[key] = nil
    end
end

function SR:Finish()
    if self.state ~= "running" then return end
    local run = self.run
    run.elapsed = self:GetElapsed()
    run.endedAt = GetTime()
    self.state = "finished"
    self.engaged = nil
    local isPB = false
    if not run.demo then
        local db = Store()
        local best = db.bests[run.key]
        local id = db.nextRunId
        db.nextRunId = id + 1
        if not best or run.elapsed < best.final then
            isPB = true
            db.bests[run.key] = { id = id, final = run.elapsed, splits = Copy(run.splits), pulls = Copy(run.pulls), date = time(), name = UnitName("player") }
        end
        table.insert(db.history, 1, { id = id, key = run.key, final = run.elapsed, date = time(), pb = isPB, splits = Copy(run.splits), pulls = Copy(run.pulls), name = UnitName("player") })
        local index = #db.history
        while #db.history > MAX_HISTORY and index > 0 do
            local entry = db.history[index]
            if not (db.bests[entry.key] and db.bests[entry.key].id == entry.id) and db.pinned[entry.key] ~= entry.id then
                table.remove(db.history, index)
            end
            index = index - 1
        end
    end
    run.isPB = isPB

    if run.demo then
        C_Timer.After(4, function() if SR.run == run then SR:Reset(true, true) end end)
    end
    Emit("FOJJI_CORE_SPEEDRUN_FINISH", run.key, run.elapsed, isPB)
    Changed()
end

function SR:Reset(silent, fromSync)
    self.run = nil
    self.state = "idle"
    self.engaged = nil
    Store().active = nil
    if not silent and not fromSync then SendSync("R") end
    Emit("FOJJI_CORE_SPEEDRUN_RESET")
    self:RefreshRoute()
end

function SR:GetHistory(key)
    local out = {}
    for _, entry in ipairs(Store().history) do
        if not key or entry.key == key then out[#out + 1] = entry end
    end
    return out
end

function SR:RemoveHistory(id)
    local db = Store()
    for index, entry in ipairs(db.history) do
        if entry.id == id then
            table.remove(db.history, index)
            if db.pinned[entry.key] == id then db.pinned[entry.key] = nil end
            if db.bests[entry.key] and db.bests[entry.key].id == id then RecomputeBest(entry.key) end
            Changed(false)
            return true
        end
    end
end

function SR:ClearHistory(key)
    local db = Store()
    local keep = {}
    for _, entry in ipairs(db.history) do
        if key and entry.key ~= key then keep[#keep + 1] = entry end
    end
    db.history = keep
    for k in pairs(db.bests) do if not key or k == key then db.bests[k] = nil end end
    for k in pairs(db.pinned) do if not key or k == key then db.pinned[k] = nil end end
    Changed(false)
end

function SR:PinRun(key, id)
    local db = Store()
    db.pinned[key] = id
    db.compare = "pinned"
    Changed(false)
end

function SR:CheckFinish(boss)
    local run, route = self.run, self.route
    local mode = Store().finishMode
    if mode == "final" then
        if not route.dynamic and boss.id == route.final then self:Finish() end
    elseif mode == "all" then
        local counted = 0
        for _, b in ipairs(route.bosses) do
            if not b.optional then
                counted = counted + 1
                if not run.splits[b.id] then return end
            end
        end
        if counted > 0 then self:Finish() end
    end
end

function SR:RecordSplit(boss)
    local run = self.run
    if not run or run.splits[boss.id] then return end
    local t = self:GetElapsed()
    run.splits[boss.id] = t
    run.order[#run.order + 1] = boss.id
    local engaged = self.engaged
    if engaged and engaged.id == boss.id and engaged.pull then run.pulls[boss.id] = engaged.pull end
    Emit("FOJJI_CORE_SPEEDRUN_SPLIT", boss.id, boss.name, t, self:GetDelta(boss.id))
    Changed()
    self:CheckFinish(boss)
end

function SR:BossFor(id, name)
    local boss = D.FindBoss(self.route, id, name)
    if boss then return boss end
    boss = D.AddExtra(self.route, id, name)
    if self.run then self.run.extra[#self.run.extra + 1] = { id = id, name = boss.name } end
    Addon.Print(("Unlisted encounter added to this run: %s (ID %s)."):format(boss.name, tostring(id)))
    return boss
end

function SR:OnEncounterStart(id, name)
    if Secret(id, name) or type(id) ~= "number" or type(name) ~= "string" then return end
    local db = Store()
    db.learned[id] = name
    local physKey = RouteKeyForInstance()

    RememberBoss((self.route and self.route.key) or physKey, id, name)

    if self.state == "idle" and self.route and physKey and self.route.key == physKey then
        if db.startMode == "pull" then
            self:Start("auto")
        end
    end
    local attempt = 1
    local boss
    if self.state == "running" and self.route then
        boss = self:BossFor(id, name)
        attempt = (self.run.attempts[boss.id] or 0) + 1
        self.run.attempts[boss.id] = attempt
    end
    self.engaged = {
        id = boss and boss.id or id, name = name, startTime = GetTime(), attempt = attempt,
        pull = self.state == "running" and self:GetElapsed() or nil,
    }
    Emit("FOJJI_CORE_SPEEDRUN_PULL", self.engaged.id, name, self.engaged.pull, attempt)
    Changed(false)
end

function SR:OnEncounterEnd(id, name, _, _, success)
    if Secret(id, name, success) then return end
    local db = Store()
    if type(id) == "number" and type(name) == "string" then db.learned[id] = name end
    local engaged = self.engaged
    local killed = success == 1 or success == true
    if self.state ~= "running" then
        self.engaged = nil
        Changed(false)
        return
    end
    local boss = D.FindBoss(self.route, id, name)
    if not killed then
        self.run.wipes = self.run.wipes + 1
        Emit("FOJJI_CORE_SPEEDRUN_WIPE", boss and boss.id or id, name, self:GetElapsed(), boss and self.run.attempts[boss.id] or 1)
        self.engaged = nil
        Changed()
        return
    end
    boss = boss or self:BossFor(id, name)
    if not engaged or engaged.id ~= boss.id then

        self.engaged = { id = boss.id, name = name, startTime = GetTime(), attempt = self.run.attempts[boss.id] or 1 }
    end
    self:RecordSplit(boss)
    if self.engaged and self.engaged.id == boss.id then self.engaged = nil end
    Changed(false)
end

function SR:GetRows(order, unkilled)
    local rows = {}
    local route, run = self.route, self.run
    if not route then return rows end
    local ref = self:GetActiveReference()
    local now = GetTime()
    for index, boss in ipairs(route.bosses) do
        local t = run and run.splits[boss.id]
        local pull = run and run.pulls[boss.id]
        local refTime = ref and ref.splits and ref.splits[boss.id]
        local engagedNow = self.engaged and self.engaged.id == boss.id and not t
        rows[#rows + 1] = {
            index = index, id = boss.id, name = boss.name, icon = D.IconPath(boss),
            optional = boss.optional and true or false, extra = boss.extra and true or false,
            killed = t ~= nil, time = t, pull = pull, fight = (t and pull) and (t - pull) or nil,
            attempts = run and run.attempts[boss.id] or 0,
            refTime = refTime, refPull = ref and ref.pulls and ref.pulls[boss.id] or nil,
            delta = (t and refTime) and (t - refTime) or nil,
            engaged = engagedNow and true or false,
            attempt = engagedNow and self.engaged.attempt or nil,
            fightTime = engagedNow and (now - self.engaged.startTime) or nil,
        }
    end
    if unkilled == false then
        local kept = {}
        for _, row in ipairs(rows) do if row.killed or row.engaged then kept[#kept + 1] = row end end
        rows = kept
    end
    if order == "kills" then
        table.sort(rows, function(a, b)
            if a.killed ~= b.killed then return a.killed end
            if a.killed then return a.time < b.time end
            if a.engaged ~= b.engaged then return a.engaged end
            return a.index < b.index
        end)
    end
    return rows
end

function SR:GetSnapshot()
    local route, run = self.route, self.run
    local ref = self:GetActiveReference()
    local killed = 0
    if run then for _ in pairs(run.splits) do killed = killed + 1 end end
    local engaged = self.engaged
    return {
        state = self.state, elapsed = self:GetElapsed(), visible = self:ShouldShow(),
        key = route and route.key, name = route and route.name, short = route and route.short,
        bossCount = route and #route.bosses or 0, killed = killed,
        wipes = run and run.wipes or 0, isPB = run and run.isPB or false,
        refFinal = ref and ref.final, refLabel = ref and (ref.label or ref.name),
        refKind = (run and run.demo) and "demo" or Store().compare,
        engaged = engaged and { id = engaged.id, name = engaged.name, attempt = engaged.attempt, fightTime = GetTime() - engaged.startTime } or nil,
        rows = self:GetRows(),
    }
end

function SR:Demo()
    if self.state == "running" then Addon.Print("Stop or reset the current run first."); return end
    if InstanceInfo() then
        Addon.Print("The demo run is a preview and can't be started while you're inside a raid or dungeon. Leave the instance first, or just start a real run instead.")
        return
    end
    self:Reset(true, true)
    self.route = D.NewRoute(550, nil, nil, Store().bossOrder[550])
    self.demoRef = {
        final = 34, name = "Demo pace", label = "Demo pace",
        splits = { [730] = 9, [731] = 16, [732] = 27, [733] = 34 },
        pulls = { [730] = 2, [731] = 10, [732] = 19, [733] = 28 },
    }
    self:Start("demo", 0, { demo = true })
    local script = {
        { 730, "Al'ar", 2, 8 }, { 731, "Void Reaver", 11, 17 },
        { 732, "High Astromancer Solarian", 20, 26 }, { 733, "Kael'thas Sunstrider", 29, 36 },
    }
    local run = self.run
    for _, step in ipairs(script) do
        C_Timer.After(step[3], function()
            if SR.run == run and SR.state == "running" then SR:OnEncounterStart(step[1], step[2], 0, 25) end
        end)
        C_Timer.After(step[4], function()
            if SR.run == run and SR.state == "running" then SR:OnEncounterEnd(step[1], step[2], 0, 25, 1) end
        end)
    end

end

local function Libs()
    local Serialize = LibStub("LibSerialize", true)
    local Deflate = LibStub:GetLibrary("LibDeflate", true)
    return Serialize, Deflate
end

local function Clean(text, limit)
    text = tostring(text or ""):gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return text:sub(1, limit or 40)
end

function SR:Export(which)
    local Serialize, Deflate = Libs()
    if not Serialize or not Deflate then return nil, "Compression libraries are not available." end
    local db = Store()
    local key = self.route and self.route.key
    local source
    if type(which) == "number" then
        for _, entry in ipairs(db.history) do if entry.id == which then source = entry; break end end
    elseif which == "last" then
        for _, entry in ipairs(db.history) do
            if not key or entry.key == key then source = entry; break end
        end
    else
        source = key and db.bests[key]
    end
    if not source then return nil, "No finished run to export for this raid yet." end
    local label = Clean(db.label, 40)
    if label == "" then label = source.name or UnitName("player") or "Run" end
    local payload = { v = 1, key = source.key or key, name = label, final = source.final, splits = source.splits, pulls = source.pulls, date = source.date }
    return EXPORT_TAG .. Deflate:EncodeForPrint(Deflate:CompressDeflate(Serialize:Serialize(payload)))
end

local function CleanTimes(input, limit)
    local out, count = {}, 0
    if type(input) ~= "table" then return out, 0 end
    for id, t in pairs(input) do
        if type(id) == "number" and type(t) == "number" and t > 0 and t < 86400 and count < limit then
            out[id] = t
            count = count + 1
        end
    end
    return out, count
end

function SR:Import(text)
    local Serialize, Deflate = Libs()
    if not Serialize or not Deflate then return false, "Compression libraries are not available." end
    text = tostring(text or ""):gsub("%s+", "")
    local body = text:match("^" .. EXPORT_TAG .. "(.+)$")
    if not body then return false, "That is not a FojjiCore run string (it should start with FCSR1:)." end
    if #body > MAX_IMPORT_CHARS then return false, "That string is too long to be a run." end
    local packed = Deflate:DecodeForPrint(body)
    local serialized = packed and Deflate:DecompressDeflate(packed)
    if not serialized then return false, "The run string is damaged." end
    local ok, data = Serialize:Deserialize(serialized)
    if not ok or type(data) ~= "table" or data.v ~= 1 then return false, "The run string is damaged or from a newer version." end
    local key = data.key
    if type(key) ~= "number" or not D.raids[key] then return false, "This run is for a raid this version does not know." end
    local splits, count = CleanTimes(data.splits, 40)
    if count == 0 then return false, "The run has no valid splits." end
    local pulls = CleanTimes(data.pulls, 40)
    local final = type(data.final) == "number" and data.final > 0 and data.final < 86400 and data.final or nil
    local db = Store()
    local override = Clean(db.label, 40)
    local label = override ~= "" and override or Clean(data.name, 40)
    db.imports[key] = { final = final, splits = splits, pulls = pulls, date = tonumber(data.date), name = label, label = label }
    Changed(false)
    return true, D.raids[key].name, key
end

local frame = CreateFrame("Frame")
local graceUntil = 0

local function CheckGroupLeft()
    local run = SR.run
    if not run or SR.state == "idle" then return end
    if IsInGroup() then run.grouped = true; return end
    if run.grouped and Store().resetOnLeave and GetTime() > graceUntil then
        SR:Reset(true, true)
        Addon.Print("Run timer reset: you left the group.")
    end
end

local function Restore()
    local db = Store()
    local a = db.active
    db.active = nil
    if type(a) ~= "table" or type(a.key) ~= "number" or type(a.startEpoch) ~= "number" then return end
    local elapsed = a.state == "running" and (time() - a.startEpoch) or a.elapsed or 0
    if elapsed < 0 or elapsed > MAX_RUN_AGE then return end
    SR.route = D.NewRoute(a.key, a.routeName, SeenList(a.key), Store().bossOrder[a.key])
    for _, extra in ipairs(a.extra or {}) do
        if type(extra) == "table" and type(extra.id) == "number" then D.AddExtra(SR.route, extra.id, extra.name) end
    end
    SR.state = (a.state == "finished" or a.state == "stopped") and a.state or "running"
    SR.run = {
        key = a.key, startEpoch = a.startEpoch, startTime = GetTime() - elapsed,
        elapsed = SR.state ~= "running" and elapsed or nil, endedAt = SR.state ~= "running" and GetTime() or nil,
        splits = a.splits or {}, pulls = a.pulls or {}, attempts = a.attempts or {}, order = a.order or {},
        extra = a.extra or {}, wipes = a.wipes or 0, grouped = a.grouped, source = "restored", isPB = a.isPB,
    }
    SR.run.ref = SR:GetReference(a.key)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        Store()
        Restore()
        SR:RefreshRoute()
        if Addon.SRUI then
            local ok, err = pcall(Addon.SRUI.Create)
            if not ok then Addon.Print("Speedrun tracker failed to load: " .. tostring(err)) end
        end
        Changed(false)

        C_Timer.After(1.5, function() SR:RefreshRoute() end)
        C_Timer.After(4, function() SR:RefreshRoute() end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local initial, reloading = ...
        graceUntil = GetTime() + 6
        SR:RefreshRoute(not initial and not reloading)
        C_Timer.After(1.5, function() SR:RefreshRoute() end)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "LOADING_SCREEN_DISABLED" then
        SR:RefreshRoute()
    elseif event == "GROUP_ROSTER_UPDATE" then
        CheckGroupLeft()
        if SR.run and SR.state ~= "idle" and not IsInGroup() then C_Timer.After(2, CheckGroupLeft) end
        Changed(false)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if SR.state == "idle" and Store().startMode == "combat" and SR.route and SR.route.key == RouteKeyForInstance() then
            SR:Start("auto")
        end
    elseif event == "ENCOUNTER_START" then
        SR:OnEncounterStart(...)
    elseif event == "ENCOUNTER_END" then
        SR:OnEncounterEnd(...)
    elseif event == "CHAT_MSG_ADDON_LOGGED" then
        OnSync(...)
    end
end)
for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "LOADING_SCREEN_DISABLED",
    "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "ENCOUNTER_START", "ENCOUNTER_END", "CHAT_MSG_ADDON_LOGGED" }) do
    pcall(frame.RegisterEvent, frame, name)
end

local poll = 0
frame:SetScript("OnUpdate", function(_, dt)
    poll = poll + dt
    if poll < 1 then return end
    poll = 0
    local key = RouteKeyForInstance()
    if key ~= SR.lastInstanceKey then SR:RefreshRoute() end
end)

SLASH_FOJJISPEEDRUN1 = "/speedrun"
SLASH_FOJJISPEEDRUN2 = "/fsr"
SlashCmdList["FOJJISPEEDRUN"] = function(msg)
    local cmd = strtrim(msg or ""):lower()
    local db = Store()
    if cmd == "start" then
        if not SR:Start("manual") then Addon.Print("A run is already in progress.") end
    elseif cmd == "stop" then SR:Stop()
    elseif cmd == "reset" then SR:Reset()
    elseif cmd == "demo" then SR:Demo()
    elseif cmd == "preview" then SR.preview = not SR.preview; Changed(false)
    elseif cmd == "lock" then db.locked = true; Changed(false); Addon.Print("Tracker locked.")
    elseif cmd == "unlock" then db.locked = false; Changed(false); Addon.Print("Tracker unlocked: drag it to move.")
    elseif cmd == "ids" then
        local ids = {}
        for id in pairs(db.learned) do ids[#ids + 1] = id end
        table.sort(ids)
        if #ids == 0 then Addon.Print("No encounters seen yet. Pull a boss first.") end
        for _, id in ipairs(ids) do Addon.Print(("%d = %s"):format(id, db.learned[id])) end
    elseif cmd == "" or cmd == "toggle" then
        SR.manuallyHidden = nil
        if db.visibility == "never" then db.visibility = db.lastVisibility or "instance"
        else db.lastVisibility = db.visibility; db.visibility = "never" end
        Changed(false)
    elseif cmd == "show" then
        if db.visibility == "never" then db.visibility = db.lastVisibility or "instance" end
        SR.manuallyHidden = nil
        SR.preview = true; Changed(false)
        Addon.Print("Showing the tracker. /speedrun preview turns the preview off.")
    elseif cmd == "hide" then
        SR.preview = false
        if db.visibility ~= "never" then db.lastVisibility = db.visibility end
        db.visibility = "never"; Changed(false)
    else
        Addon.Print("/speedrun  [start | stop | reset | demo | show | hide | preview | lock | unlock | ids]")
    end
end
