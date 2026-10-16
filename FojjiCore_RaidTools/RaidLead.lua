local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end

local RL = {}
Addon.RaidLead = RL
FojjiCore = FojjiCore or {}
FojjiCore.RaidLead = RL

local PREFIX = "FJRL"
local K
local function kit() K = K or Addon.UIKit; return K end
local function say(msg) if Addon.Print then Addon.Print(msg) else print("FojjiCore: " .. msg) end end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function short(n) return (strsplit("-", n or "")) end
local function charKey(n) return (short(n):match("^(%S+)")) or short(n) end
local function readable(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end

local function db()
    FojjiCoreDB = FojjiCoreDB or {}
    local d = FojjiCoreDB.raidLead
    if type(d) ~= "table" then d = {}; FojjiCoreDB.raidLead = d end
    d.invite = d.invite or { keywords = "inv", keywordOn = false, guildOnly = true, autoAccept = false, autoRaid = false, maxRank = 3 }
    if not d.invite.v2 then d.invite.autoAccept, d.invite.autoRaid, d.invite.v2 = false, false, true end
    d.roles = d.roles or { promote = "", promoteOn = false, tanks = "", tanksOn = false, ml = "", mlOn = false, threshold = 4 }
    d.log = d.log or { raids = false, dungeons = false }
    if not d.log.v2 then d.log.raids, d.log.dungeons, d.log.v2 = false, false, true end
    d.attendance = d.attendance or { sessions = {} }
    d.loot = d.loot or { list = {}, minQuality = 4 }
    if not d.loot.where then d.loot.where = d.loot.raidsOnly == false and "always" or "raid"; d.loot.raidsOnly = nil end
    return d
end
RL.DB = db

local callbacks = {}
function RL:OnChange(fn) callbacks[#callbacks + 1] = fn end
local function changed(what) for i = 1, #callbacks do pcall(callbacks[i], what) end end

local function isLeader() return UnitIsGroupLeader and UnitIsGroupLeader("player") end
local function canLead() return isLeader() or (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) end

local function unitList()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do list[#list + 1] = "raid" .. i end
    else
        list[1] = "player"
        for i = 1, GetNumSubgroupMembers() do list[#list + 1] = "party" .. i end
    end
    return list
end

local function groupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function resolveList(text)
    local out = {}
    local GS = Addon.GroupSetups
    for token in (text or ""):gmatch("[^,]+") do
        token = trim(token)
        if token ~= "" then
            local name = GS and GS.KeyName and GS:KeyName(token)
            out[#out + 1] = name or token
        end
    end
    return out
end
RL.ResolveList = resolveList

local function fullName(unit)
    local n = UnitName(unit) or ""
    local i = tonumber(unit:match("^raid(%d+)$"))
    local rn = i and GetRaidRosterInfo(i)
    rn = rn and short(rn) or ""
    return #rn > #n and rn or n
end

local function rosterUnitByName(name)
    local want = charKey(name):lower()
    for _, u in ipairs(unitList()) do
        local n = UnitName(u)
        if n and charKey(n):lower() == want then return u, n end
    end
    if Addon.GroupSetups and Addon.GroupSetups.Roster then
        local r = Addon.GroupSetups:Roster()
        local hit = Addon.GroupSetups:Resolve(r, name)
        if hit then return "raid" .. hit.index, short(hit.name) end
    end
end

local send = C_ChatInfo and (C_ChatInfo.SendAddonMessage or C_ChatInfo.SendAddonMessageLogged)
local function sendMsg(msg, channel, target)
    channel = channel or groupChannel()
    if not channel or not send then return end
    pcall(send, PREFIX, msg, channel, target)
end

RL.versions = {}

local function myPacks()
    local parts = {}
    local RP = FojjiCore.RaidPacks
    if RP and RP.GetPacks then
        for _, p in ipairs(RP:GetPacks()) do parts[#parts + 1] = p.key .. "=" .. tostring(p.version or "?") end
    end
    return table.concat(parts, ";")
end

local commFrame = CreateFrame("Frame")
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(_, _, prefix, msg, channel, sender)
    if (issecretvalue and issecretvalue(prefix)) or prefix ~= PREFIX or type(msg) ~= "string" then return end
    local full = short(sender)
    sender = charKey(full)
    local kind = msg:sub(1, 2)
    if kind == "VQ" then
        sendMsg("VR\t" .. tostring(FojjiCore_Version or "?") .. "\t" .. myPacks() .. "\t" .. (select(2, UnitClass("player")) or ""), channel == "WHISPER" and "WHISPER" or nil, channel == "WHISPER" and full or nil)
    elseif kind == "VR" then
        local _, ver, packs, class = strsplit("\t", msg)
        local p = {}
        for pair in (packs or ""):gmatch("[^;]+") do
            local k, v = pair:match("^([^=]+)=(.*)$")
            if k then p[k] = v end
        end
        RL.versions[sender] = { fc = ver, packs = p, t = GetTime(), full = full, class = class ~= "" and class or nil }
        changed("versions")
    end
end)

function RL:CheckVersions()
    wipe(self.versions)
    local me = charKey(UnitName("player"))
    self.versions[me] = { fc = tostring(FojjiCore_Version or "?"), packs = {}, t = GetTime(), class = select(2, UnitClass("player")) }
    for pair in myPacks():gmatch("[^;]+") do
        local k, v = pair:match("^([^=]+)=(.*)$")
        if k then self.versions[me].packs[k] = v end
    end
    if not groupChannel() then say("Not in a group - showing your own versions only.") end
    sendMsg("VQ")
    self.versionAsked = GetTime()
    changed("versions")
end

local inviteUnit = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
local convertToRaid = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid

local function invite(name)
    if not name or name == "" or not inviteUnit then return end
    if UnitInRaid(name) or UnitInParty(name) then return end
    if db().invite.autoRaid and IsInGroup() and not IsInRaid() and isLeader() and GetNumGroupMembers() >= 4 and convertToRaid then convertToRaid() end
    pcall(inviteUnit, name)
end

local queue, queueTimer = {}, nil
local function pump()
    queueTimer = nil
    local n = 0
    while #queue > 0 and n < 4 do
        invite(table.remove(queue, 1))
        n = n + 1
    end
    if #queue > 0 then queueTimer = C_Timer.NewTimer(1.2, pump) end
end
function RL:InviteNames(names)
    local me = UnitName("player")
    local added = 0
    for _, n in ipairs(names) do
        n = short(n):match("^(%S+)") or ""
        if n ~= "" and n ~= me then queue[#queue + 1] = n; added = added + 1 end
    end
    if added == 0 then say("Nobody to invite.") return end
    say("Inviting " .. added .. " player" .. (added == 1 and "" or "s") .. "...")
    if not queueTimer then pump() end
end

function RL:GuildRanks()
    local ranks = {}
    if GuildControlGetNumRanks then
        for i = 1, GuildControlGetNumRanks() do ranks[i] = GuildControlGetRankName(i) end
    end
    return ranks
end

function RL:InviteGuild(maxRank)
    if not IsInGuild() then say("You are not in a guild.") return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
    local names = {}
    for i = 1, GetNumGuildMembers() do
        local name, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online and rankIndex and rankIndex + 1 <= maxRank then names[#names + 1] = name end
    end
    self:InviteNames(names)
end

function RL:InviteRoster()
    local GS = Addon.GroupSetups
    local names = GS and GS.RosterNames and GS:RosterNames() or {}
    if #names == 0 then say("No roster imported - import a roster under Raid Data > Roster first.") return end
    self:InviteNames(names)
end

local function isGuildMate(name)
    if not IsInGuild() then return false end
    name = short(name):lower()
    for i = 1, GetNumGuildMembers() do
        local n = GetGuildRosterInfo(i)
        if n and short(n):lower() == name then return true end
    end
    return false
end

local function isFriend(name)
    name = short(name):lower()
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name and short(info.name):lower() == name then return true end
        end
    end
    return false
end

local inviteFrame = CreateFrame("Frame")
inviteFrame:RegisterEvent("CHAT_MSG_WHISPER")
inviteFrame:RegisterEvent("PARTY_INVITE_REQUEST")
inviteFrame:SetScript("OnEvent", function(_, event, a1, a2)
    local c = db().invite
    if event == "CHAT_MSG_WHISPER" then
        if not c.keywordOn then return end
        local text, sender = readable(a1), readable(a2)
        if not text or not sender then return end
        if IsInGroup() and not canLead() then return end
        text = trim(text):lower()
        for word in (c.keywords or ""):gmatch("[^,]+") do
            if text == trim(word):lower() then
                if c.guildOnly and not isGuildMate(sender) then return end
                invite(short(sender))
                return
            end
        end
    elseif event == "PARTY_INVITE_REQUEST" then
        local from = readable(a1)
        if c.autoAccept and from and (isGuildMate(from) or isFriend(from)) then
            if Addon.Vendor and Addon.Vendor.AcceptInvite then
                Addon.Vendor.AcceptInvite()
            else
                AcceptGroup()
                if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
            end
        end
    end
end)

local THRESHOLDS = { [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }
RL.THRESHOLDS = THRESHOLDS

local P = C_PartyInfo
local ML_ENUM = Enum and Enum.LootMethod and (Enum.LootMethod.Masterlooter or Enum.LootMethod.MasterLooter or Enum.LootMethod.Master)

local function getLootMethod()
    if GetLootMethod then return GetLootMethod() end
    if P and P.GetLootMethod then return P.GetLootMethod() end
end

function RL.IsMasterLooter(name)
    local method, partyIndex, raidIndex = getLootMethod()
    if not (method == "master" or (ML_ENUM and method == ML_ENUM)) then return false end
    local current = raidIndex and GetRaidRosterInfo(raidIndex)
    return current ~= nil and charKey(current):lower() == charKey(name):lower()
end

if SetLootMethod or (P and P.SetLootMethod) then
    function RL.SetMasterLooter(name)
        local ok
        if SetLootMethod then ok = pcall(SetLootMethod, "master", name) end
        if not ok and P and P.SetLootMethod then
            ok = pcall(P.SetLootMethod, ML_ENUM or 2, name)
            if not ok then ok = pcall(P.SetLootMethod, "master", name) end
        end
        return ok
    end
end

function RL.SetThreshold(q)
    local get = GetLootThreshold or (P and P.GetLootThreshold)
    local set = SetLootThreshold or (P and P.SetLootThreshold)
    if set and (not get or get() ~= q) then pcall(set, q) end
end

function RL:ApplyRoles(manual)
    if not IsInRaid() then if manual then say("You need to be in a raid.") end return end
    if not isLeader() then if manual then say("You need to be raid leader.") end return end
    local r = db().roles
    local did = {}
    if r.promoteOn or manual then
        for _, n in ipairs(resolveList(r.promote)) do
            local u, name = rosterUnitByName(n)
            if u and not UnitIsGroupAssistant(u) and not UnitIsGroupLeader(u) then PromoteToAssistant(u); did[#did + 1] = name .. " assist" end
        end
    end
    if (r.tanksOn or manual) and SetPartyAssignment then
        for _, n in ipairs(resolveList(r.tanks)) do
            local u, name = rosterUnitByName(n)
            if u and not (GetPartyAssignment and GetPartyAssignment("MAINTANK", u)) then
                pcall(SetPartyAssignment, "MAINTANK", u)
                did[#did + 1] = name .. " main tank"
            end
        end
    end
    if r.mlOn or manual then
        local master
        for _, n in ipairs(resolveList(r.ml)) do
            local u, name = rosterUnitByName(n)
            if u and UnitIsConnected(u) then master = name break end
        end
        if not master then
            if manual and trim(r.ml or "") ~= "" then say("Master looter: nobody on that list is in the raid.") end
        elseif not RL.SetMasterLooter then
            if manual then say("Master looter: this game client has no way to set the loot method.") end
        elseif RL.IsMasterLooter(master) then
        elseif RL.SetMasterLooter(master) then
            did[#did + 1] = master .. " master looter"
            C_Timer.After(1, function() RL.SetThreshold(r.threshold) end)
        elseif manual then
            say("Master looter: the game refused to set " .. master .. ".")
        end
    end
    if #did > 0 then say("Raid roles: " .. table.concat(did, ", ") .. ".") elseif manual then say("Raid roles already set.") end
end

local rolesFrame = CreateFrame("Frame")
rolesFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rolesFrame:SetScript("OnEvent", function()
    local r = db().roles
    if not (r.promoteOn or r.tanksOn or r.mlOn) or InCombatLockdown() then return end
    if rolesFrame.t then rolesFrame.t:Cancel() end
    rolesFrame.t = C_Timer.NewTimer(1.5, function() rolesFrame.t = nil; RL:ApplyRoles(false) end)
end)

local logFrame = CreateFrame("Frame")
logFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
logFrame:SetScript("OnEvent", function()
    if not LoggingCombat then return end
    C_Timer.After(1, function()
        local c = db().log
        local _, kind = IsInInstance()
        local want = (kind == "raid" and c.raids) or (kind == "party" and c.dungeons)
        if want and not LoggingCombat() then
            LoggingCombat(true)
            RL.startedLog = true
            say("Combat logging |cff44ff88on|r (" .. (GetInstanceInfo() or kind) .. ").")
        elseif not want and RL.startedLog and LoggingCombat() then
            LoggingCombat(false)
            RL.startedLog = nil
            say("Combat logging |cffff8866off|r.")
        end
    end)
end)

local function currentSession()
    local name, kind = GetInstanceInfo()
    if kind ~= "raid" or not IsInRaid() then return nil end
    local sessions = db().attendance.sessions
    local today = date("%Y-%m-%d")
    local last = sessions[#sessions]
    if last and last.date == today and last.instance == name then return last end
    local s = { date = today, instance = name, start = time(), members = {}, bosses = {} }
    sessions[#sessions + 1] = s
    return s
end

local function rosterSnapshot()
    local m = {}
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, class, _, online = GetRaidRosterInfo(i)
        if name and online then m[short(name)] = class end
    end
    return m
end

RL.lastBoss = nil
local attFrame = CreateFrame("Frame")
attFrame:RegisterEvent("ENCOUNTER_START")
attFrame:RegisterEvent("ENCOUNTER_END")
attFrame:SetScript("OnEvent", function(_, event, encounterID, encounterName, _, _, success)
    local s = currentSession()
    if not s then return end
    local snap = rosterSnapshot()
    for n, c in pairs(snap) do s.members[n] = c end
    if event == "ENCOUNTER_END" then
        local list = {}
        for n in pairs(snap) do list[#list + 1] = n end
        table.sort(list)
        s.bosses[#s.bosses + 1] = { name = readable(encounterName) or ("Encounter " .. tostring(encounterID)), kill = success == 1, t = time(), members = list }
        if success == 1 then RL.lastBoss = { name = readable(encounterName), t = GetTime() } end
        changed("attendance")
    end
end)

function RL:Sessions() return db().attendance.sessions end

function RL:AttendanceTable(days)
    local cutoff = days and (time() - days * 86400) or 0
    local total, seen, class = 0, {}, {}
    for _, s in ipairs(self:Sessions()) do
        if (s.start or 0) >= cutoff then
            total = total + 1
            for n, c in pairs(s.members) do seen[n] = (seen[n] or 0) + 1; class[n] = c end
        end
    end
    local rows = {}
    for n, c in pairs(seen) do rows[#rows + 1] = { name = n, class = class[n], count = c, pct = total > 0 and math.floor(c / total * 100 + 0.5) or 0 } end
    table.sort(rows, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.name < b.name end)
    return rows, total
end

function RL:AttendanceCSV(days)
    local rows, total = self:AttendanceTable(days)
    local out = { "name,class,raids,of,percent" }
    for _, r in ipairs(rows) do out[#out + 1] = ("%s,%s,%d,%d,%d"):format(r.name, r.class or "", r.count, total, r.pct) end
    return table.concat(out, "\n")
end

function RL:DeleteSession(i) table.remove(db().attendance.sessions, i); changed("attendance") end

local function patternFrom(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local LOOT_PATTERNS = {
    { patternFrom(LOOT_ITEM_MULTIPLE), "other", true },
    { patternFrom(LOOT_ITEM), "other" },
    { patternFrom(LOOT_ITEM_SELF_MULTIPLE), "self", true },
    { patternFrom(LOOT_ITEM_SELF), "self" },
}

local QUALITY_HEX = { ffa335ee = 4, ff0070dd = 3, ff1eff00 = 2, ffff8000 = 5, ffffffff = 1, ff9d9d9d = 0 }
local function linkQuality(link)
    local q = C_Item and C_Item.GetItemQualityByID and select(2, pcall(C_Item.GetItemQualityByID, link))
    if type(q) == "number" then return q end
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local quality
    if info then quality = select(3, info(link)) end
    if quality then return quality end
    local hex = link:match("|c(%x%x%x%x%x%x%x%x)")
    return hex and QUALITY_HEX[hex:lower()] or 1
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("CHAT_MSG_LOOT")
lootFrame:SetScript("OnEvent", function(_, _, msg)
    msg = readable(msg)
    if not msg then return end
    local c = db().loot
    local instName, kind = GetInstanceInfo()
    if c.where == "raid" and kind ~= "raid" then return end
    if c.where == "instance" and kind ~= "raid" and kind ~= "party" then return end
    for _, p in ipairs(LOOT_PATTERNS) do
        if p[1] then
            local a, b = msg:match(p[1])
            if a then
                local who, link
                if p[2] == "self" then who, link = UnitName("player"), a else who, link = a, b end
                if link and link:find("|Hitem:") then
                    if linkQuality(link) >= (c.minQuality or 4) then
                        local boss = RL.lastBoss and (GetTime() - RL.lastBoss.t) < 600 and RL.lastBoss.name or nil
                        table.insert(c.list, 1, { who = short(who), link = link, t = time(), instance = instName, boss = boss })
                        while #c.list > 1000 do table.remove(c.list) end
                        changed("loot")
                    end
                end
                return
            end
        end
    end
end)

function RL:Loot() return db().loot.list end
function RL:LootCSV()
    local out = { "date,player,item,boss,instance" }
    for _, e in ipairs(self:Loot()) do
        local item = e.link:match("%[(.-)%]") or e.link
        out[#out + 1] = ('%s,%s,"%s",%s,%s'):format(date("%Y-%m-%d %H:%M", e.t), e.who, item, e.boss or "", e.instance or "")
    end
    return table.concat(out, "\n")
end
function RL:ClearLoot() wipe(db().loot.list); changed("loot") end

function RL.Slash(cmd, rest)
    if cmd == "versions" then RL:CheckVersions(); FojjiCore:ToggleOptions("raidlead"); if Addon.RaidLeadPage then Addon.RaidLeadPage.SelectView("versions") end return true end
    if cmd == "raiddata" and Addon.RaidData then FojjiCore:ToggleOptions("assignments"); if Addon.AssignmentsPage then Addon.AssignmentsPage.SelectView("raiddata") end return true end
    if cmd == "roles" then RL:ApplyRoles(true) return true end
    if cmd == "invite" then
        if rest == "guild" then RL:InviteGuild(db().invite.maxRank) else RL:InviteRoster() end
        return true
    end
    return false
end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) end
    return "|cffd8dbe0"
end

local function Table(card, columns)
    local t = CreateFrame("Frame")
    t.cols, t.rows = columns, {}
    t.head = {}
    local function cell(parent, i, size, color)
        local fs = K.T(parent, size, color)
        fs:SetJustifyH(columns[i].align or "LEFT")
        return fs
    end
    for i in ipairs(columns) do t.head[i] = cell(t, i, 11, "dim"); t.head[i]:SetText(columns[i].title) end
    function t:Layout()
        local w = self:GetWidth() or 500
        local x = 0
        for i, c in ipairs(self.cols) do
            local cw = c.w <= 1 and w * c.w or c.w
            c.x, c.cw = x, cw
            x = x + cw
        end
        local function place(fs, i, y)
            local c = self.cols[i]
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", c.x, y)
            fs:SetWidth(c.cw - 6)
        end
        for i, fs in ipairs(self.head) do place(fs, i, 0) end
        for r, row in ipairs(self.rows) do
            for i, fs in ipairs(row) do place(fs, i, -20 - (r - 1) * 20) end
            if row.span then row[1]:SetWidth(w - 6) end
            row.bg:ClearAllPoints()
            row.bg:SetPoint("TOPLEFT", -4, -17 - (r - 1) * 20)
            row.bg:SetPoint("RIGHT", 0, 0)
            row.bg:SetHeight(20)
        end
    end
    function t:Set(data)
        for r, values in ipairs(data) do
            local row = self.rows[r]
            if not row then
                row = {}
                row.bg = self:CreateTexture(nil, "BACKGROUND")
                row.bg:SetTexture(K.WHITE)
                for i in ipairs(self.cols) do row[i] = cell(self, i, 12, "text") end
                self.rows[r] = row
            end
            row.bg:SetVertexColor(1, 1, 1, r % 2 == 0 and 0.03 or 0)
            row.bg:Show()
            for i = 1, #self.cols do row[i]:SetText(values[i] or ""); row[i]:Show() end
            row.span = #values == 1
        end
        for r = #data + 1, #self.rows do
            self.rows[r].bg:Hide()
            for i = 1, #self.cols do self.rows[r][i]:Hide() end
        end
        self.h = 22 + #data * 20
        self:SetHeight(self.h)
        for _, it in ipairs(card.items) do if it.w == self then it.h = self.h end end
        self:Layout()
    end
    t:SetScript("OnSizeChanged", function(self) self:Layout() end)
    return t
end

local function wide(card) card.wide = true; return card end

local function inputRow(label, value, onCommit, width)
    local f = CreateFrame("Frame")
    f.cap = K.Caption(f, label)
    f.cap:SetPoint("TOPLEFT", 0, 0)
    f.w = K.Input(f, onCommit)
    f.w.box:SetMaxLetters(0)
    f.w:SetPoint("TOPLEFT", 0, -19)
    if width then f.w:SetWidth(width) else f.w:SetPoint("RIGHT", 0, 0) end
    f.w:SetValue(value or "")
    return f
end

local function buttonRow(buttons, note)
    local f = CreateFrame("Frame")
    local prev
    for _, b in ipairs(buttons) do
        b:SetParent(f)
        b:ClearAllPoints()
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("LEFT", 0, 0) end
        prev = b
    end
    if note then
        f.note = K.T(f, 12, "dim")
        f.note:SetPoint("LEFT", prev, "RIGHT", 12, 0)
        f.note:SetPoint("RIGHT", 0, 0)
        f.note:SetText(note)
    end
    return f
end

function Addon.BuildRaidDataView(frame, UI)
    kit()
    local RD = Addon.RaidData
    if RD then
        local v = { frame = frame, stack = K.CardStack(frame, -44, UI) }
        local RP = FojjiCore.RaidPacks
        local pack
        local function packs()
            local list = {}
            for key, p in pairs(RP and RP.packs or {}) do
                if not p.dynamic or (p.bossOrder and #p.bossOrder > 0) then list[#list + 1] = { key = key, name = p.name or key } end
            end
            table.sort(list, function(a, b) return a.name < b.name end)
            return list
        end
        local function packName(key)
            local p = key and RP and RP.packs[key]
            return p and (p.name or key) or "No raid packs"
        end

        local top = v.stack:Add(wide(K.Card(v.frame, "Raid data")))
        local packDD = K.Dropdown(UIParent, 210, function(self)
            local entries = {}
            for _, e in ipairs(packs()) do
                entries[#entries + 1] = { text = e.name, checked = pack == e.key, onClick = function() pack = e.key; v.refresh() end }
            end
            K.openMenu(self, entries)
        end)
        local sendBtn = K.Button(UIParent, "Send to raid", 130, 26, "primary", "icon-raid")
        sendBtn:SetScript("OnClick", function()
            if not pack then return end
            if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then GetCurrentKeyBoardFocus():ClearFocus() end
            RD:Send(pack)
        end)
        K.Tip(sendBtn, "Send to raid", "Raid leader or assistant. Raiders who join later ask for it, and the raid leader's FojjiCore answers.")
        local expBtn = K.Button(UIParent, "Export", 90, 26, nil, "icon-export")
        expBtn:SetScript("OnClick", function() if pack then K.CopyBox("Raid data: " .. packName(pack), RD:Export(pack), "Paste into Import on another FojjiCore, or keep it in a text file.", true) end end)
        local impBtn = K.Button(UIParent, "Import", 90, 26)
        local clrBtn = K.Button(UIParent, "Clear", 80, 26, "danger")
        local armed
        clrBtn:SetScript("OnClick", function()
            if not pack then return end
            if armed then
                armed = nil
                clrBtn.label:SetText("Clear")
                RD:Clear(pack)
            else
                armed = true
                clrBtn.label:SetText("Sure?")
                C_Timer.After(3, function() armed = nil; clrBtn.label:SetText("Clear") end)
            end
        end)
        top:Add(buttonRow({ packDD, sendBtn, expBtn, impBtn, clrBtn }), 28, 8)
        local status = K.T(UIParent, 12, "dim")
        local statusRow = CreateFrame("Frame")
        status:SetParent(statusRow); status:SetPoint("LEFT", 0, 0); status:SetPoint("RIGHT", 0, 0); status:SetJustifyH("LEFT")
        top:Add(statusRow, 18, 6)

        local importDlg
        impBtn:SetScript("OnClick", function()
            if not importDlg then
                local f = CreateFrame("Frame", "FojjiCoreRaidDataImport", UIParent)
                f:SetSize(560, 340); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
                K.Surface(f, "frame", 0.98, "accent", 0.85)
                if UISpecialFrames then table.insert(UISpecialFrames, "FojjiCoreRaidDataImport") end
                local t = K.T(f, 15, "white"); t:SetPoint("TOPLEFT", 16, -14); t:SetText("Import raid data")
                local hint = K.T(f, 12, "dim"); hint:SetPoint("TOPLEFT", 16, -36); hint:SetPoint("RIGHT", -16, 0); hint:SetJustifyH("LEFT")
                hint:SetText("Paste an Export. It replaces this pack's raid data (send it to the raid afterwards).")
                local field = CreateFrame("Frame", nil, f)
                K.Surface(field, "field", 1, "border", 1)
                field:SetPoint("TOPLEFT", 16, -58); field:SetPoint("BOTTOMRIGHT", -16, 50)
                local sc = CreateFrame("ScrollFrame", nil, field); sc:SetPoint("TOPLEFT", 6, -6); sc:SetPoint("BOTTOMRIGHT", -6, 6)
                local eb = CreateFrame("EditBox", nil, sc)
                eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(0); eb:SetFont(K.FONT, 12, ""); eb:SetWidth(510)
                eb:SetTextColor(0.95, 0.96, 0.98)
                sc:SetScrollChild(eb)
                field:EnableMouse(true); field:SetScript("OnMouseDown", function() eb:SetFocus() end)
                eb:SetScript("OnEscapePressed", function() f:Hide() end)
                local ok = K.Button(f, "Import", 110, 28, "primary"); ok:SetPoint("BOTTOMRIGHT", -14, 12)
                local cancel = K.Button(f, "Cancel", 90, 28); cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
                cancel:SetScript("OnClick", function() f:Hide() end)
                ok:SetScript("OnClick", function()
                    local got = RD:Import(eb:GetText(), pack)
                    if got then f:Hide(); pack = got; v.refresh() end
                end)
                f.eb = eb
                importDlg = f
            end
            importDlg:ClearAllPoints(); importDlg:SetPoint("CENTER", 0, 80)
            importDlg.eb:SetText("")
            importDlg:Show(); importDlg:Raise(); importDlg.eb:SetFocus()
        end)

        local slotsCard = v.stack:Add(wide(K.Card(v.frame, "Assignments")))
        local boxes = {}
        local function slotBox(i)
            local b = boxes[i]
            if b then return b end
            b = CreateFrame("Frame")
            b.fill = nil
            b.title = K.T(b, 13, "white"); b.title:SetPoint("TOPLEFT", 0, 0); b.title:SetPoint("RIGHT", 0, 0); b.title:SetJustifyH("LEFT")
            b.help = K.T(b, 11, "dim"); b.help:SetPoint("TOPLEFT", 0, -18); b.help:SetPoint("RIGHT", 0, 0); b.help:SetJustifyH("LEFT"); b.help:Hide()
            b.field = CreateFrame("Frame", nil, b)
            K.Surface(b.field, "field", 1, "border", 1)
            b.field:SetPoint("TOPLEFT", 0, -22); b.field:SetPoint("BOTTOMRIGHT", 0, 0)
            local sc = CreateFrame("ScrollFrame", nil, b.field)
            sc:SetPoint("TOPLEFT", 8, -6); sc:SetPoint("BOTTOMRIGHT", -8, 6)
            local eb = CreateFrame("EditBox", nil, sc)
            eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(0)
            eb:SetFont(K.FONT, 12, ""); eb:SetTextColor(0.95, 0.96, 0.98); eb:SetWidth(500)
            sc:SetScrollChild(eb)
            sc:SetScript("OnSizeChanged", function(_, w) eb:SetWidth(math.max(100, w)) end)
            b.field:EnableMouse(true); b.field:SetScript("OnMouseDown", function() eb:SetFocus() end)
            b.ph = K.T(b.field, 12, "dim"); b.ph:SetPoint("TOPLEFT", 9, -7); b.ph:SetPoint("RIGHT", -9, 0); b.ph:SetJustifyH("LEFT"); b.ph:SetJustifyV("TOP")
            b.ph:SetAlpha(0.6)
            eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            eb:SetScript("OnTextChanged", function(self, user)
                b.ph:SetShown(self:GetText() == "")
                if user and b.pack and b.key then RD:Set(b.pack, b.key, self:GetText(), true) end
            end)
            eb:SetScript("OnEditFocusLost", function() if b.pack and b.key then RD.Fire(b.pack, b.key) end end)
            b.eb = eb
            slotsCard:Add(b, 100, 14)
            boxes[i] = b
            return b
        end

        local function stamp(t) return t and date("%d/%m %H:%M", t) or "" end
        v.refresh = function()
            local list = packs()
            if not (pack and RP and RP.packs[pack]) then
                local here = RP and RP.PackForInstance and RP:PackForInstance(select(8, GetInstanceInfo()))
                pack = here or (list[1] and list[1].key)
            end
            packDD:SetText(packName(pack))
            local info = pack and RD:Info(pack)
            if not pack then
                status:SetText("Install a Fojji raid pack to use raid data.")
            elseif not info or (info.count == 0 and not info.by) then
                status:SetText("Nothing set for this raid yet.")
            elseif info.mine then
                status:SetText(("%d filled in - edited by you %s%s"):format(info.count, stamp(info.t),
                    info.sent and ("  |  |cff44ff88sent " .. stamp(info.sent) .. "|r") or "  |  |cffffcc44not sent yet|r"))
            else
                status:SetText(("%d filled in - |cff44ff88from %s|r %s"):format(info.count, info.by or "?", stamp(info.t)))
            end
            local canSend = pack ~= nil and RD.CanSend()
            sendBtn:SetEnabled(canSend); sendBtn:SetAlpha(canSend and 1 or 0.45)
            local slots = pack and RD:GetSlots(pack) or {}
            for i, slot in ipairs(slots) do
                local b = slotBox(i)
                b.pack, b.key = pack, slot.key
                b.title:SetText((slot.bossName and ("|cff8a8f98" .. slot.bossName .. "  /|r  ") or "") .. (slot.name or slot.key) .. "   |cff5c6370" .. slot.key .. "|r")
                b.help:SetText(slot.help or "")
                b.ph:SetText(slot.example or "")
                local lines = slot.lines or 4
                local h = 22 + 12 + lines * 14
                b:SetHeight(h)
                for _, it in ipairs(slotsCard.items) do if it.w == b then it.h = h end end
                if not b.eb:HasFocus() then b.eb:SetText(RD:Get(pack, slot.key) or "") end
                b.ph:SetShown(b.eb:GetText() == "")
                b:Show()
            end
            for i = #slots + 1, #boxes do boxes[i]:Hide() end
            slotsCard:SetShown(#slots > 0)
            v.stack:Layout()
        end
        RD:OnChange(function() if frame:IsVisible() then v.refresh() end end)
        frame:HookScript("OnShow", function() v.refresh() end)
    end
end

function Addon.CreateRaidLeadPage(page, UI)
    kit()
    local d = db()
    local views = {}
    local tabs
    local tabList = { { "general", "General" } }
    if Addon.BuildGroupsView then tabList[#tabList + 1] = { "groups", "Groups" } end
    tabList[#tabList + 1] = { "versions", "Versions" }
    tabList[#tabList + 1] = { "invites", "Invites" }
    tabList[#tabList + 1] = { "roles", "Roles" }
    tabList[#tabList + 1] = { "attendance", "Attendance" }
    tabList[#tabList + 1] = { "loot", "Loot" }
    tabs = K.SubTabs(page, tabList, function(key) if views[key] and views[key].refresh then views[key].refresh() end end)

    local function view(key)
        local stack = K.CardStack(tabs.views[key], -44, UI)
        views[key] = { frame = tabs.views[key], stack = stack }
        return views[key]
    end
    local function dropdownText(dd, text) dd:SetText(text) end

    if Addon.BuildGroupsView then Addon.BuildGroupsView(tabs.views.groups) end

    do
        local v = view("versions")
        local ver = v.stack:Add(wide(K.Card(v.frame, "Versions")))
        local vt = Table(ver, { { title = "Player", w = 0.30 }, { title = "FojjiCore", w = 0.16 }, { title = "Raid packs", w = 0.54 } })
        local vbtn = K.Button(UIParent, "Check versions", 140, 26, "primary", "icon-check")
        vbtn:SetScript("OnClick", function() RL:CheckVersions() end)
        ver:Add(buttonRow({ vbtn }), 26, 10)
        ver:Add(vt, 22, 4)

        v.refresh = function()
            local vrows = {}
            local names = {}
            for n in pairs(RL.versions) do names[#names + 1] = n end
            for _, u in ipairs(unitList()) do local n = UnitName(u); if n and not RL.versions[charKey(n)] then names[#names + 1] = charKey(n) end end
            table.sort(names)
            local best = "0"
            for _, e in pairs(RL.versions) do if (e.fc or "0") > best then best = e.fc end end
            for _, n in ipairs(names) do
                local e = RL.versions[n]
                local u = rosterUnitByName(n)
                local class = (e and e.class) or (u and select(2, UnitClass(u)))
                local shown = (e and e.full) or (u and fullName(u)) or n
                if e then
                    local packs = {}
                    for k2, v2 in pairs(e.packs) do packs[#packs + 1] = k2 .. " " .. v2 end
                    table.sort(packs)
                    vrows[#vrows + 1] = { classColor(class) .. shown .. "|r", (e.fc == best and "|cff44ff88" or "|cffffaa33") .. e.fc .. "|r", #packs > 0 and table.concat(packs, ",  ") or "|cff8a8f98none|r" }
                else
                    vrows[#vrows + 1] = { classColor(class) .. shown .. "|r", RL.versionAsked and "|cffff5555no FojjiCore|r" or "|cff8a8f98-|r", "" }
                end
            end
            vt:Set(vrows)
            v.stack:Layout()
        end
    end

    do
        local v = view("invites")
        local inv = v.stack:Add(K.Card(v.frame, "Invite"))
        local ib1 = K.Button(UIParent, "Invite roster", 130, 26, "primary")
        ib1:SetScript("OnClick", function() RL:InviteRoster() end)
        K.Tip(ib1, "Invite roster", "Everyone on the roster from Raid Data > Roster.")
        local rankDD = K.Dropdown(UIParent, 170, function(self)
            local entries = {}
            for i, rn in ipairs(RL:GuildRanks()) do
                entries[#entries + 1] = { text = "Up to " .. rn, checked = d.invite.maxRank == i, onClick = function() d.invite.maxRank = i; v.refresh() end }
            end
            K.openMenu(self, entries)
        end)
        local ib2 = K.Button(UIParent, "Invite guild", 120, 26)
        ib2:SetScript("OnClick", function() RL:InviteGuild(d.invite.maxRank) end)
        inv:Add(buttonRow({ ib1, ib2, rankDD }), 26, 12)

        local kwc = v.stack:Add(K.Card(v.frame, "Keyword invites"))
        local kwSw = K.SwitchRow(UIParent, "Invite people who whisper a keyword", function(val) d.invite.keywordOn = val end)
        kwc:Add(kwSw, 24, 6)
        local kw = inputRow("Keywords (comma separated)", d.invite.keywords, function(val) d.invite.keywords = val end, 260)
        kwc:Add(kw, 47, 6)
        local goSw = K.SwitchRow(UIParent, "Guild members only", function(val) d.invite.guildOnly = val end)
        kwc:Add(goSw, 24, 6)

        v.refresh = function()
            local ranks = RL:GuildRanks()
            dropdownText(rankDD, #ranks > 0 and ("Up to " .. (ranks[d.invite.maxRank] or ranks[#ranks])) or "No guild")
            kwSw:SetValue(d.invite.keywordOn); goSw:SetValue(d.invite.guildOnly)
            kw.w:SetValue(d.invite.keywords)
            v.stack:Layout()
        end
    end

    do
        local v = view("roles")
        local roles = v.stack:Add(wide(K.Card(v.frame, "Raid roles", "Set while you're raid leader. Names or roster keys, comma separated.")))
        local tanksSw = K.SwitchRow(UIParent, "Main tanks, in order", function(val) d.roles.tanksOn = val end)
        roles:Add(tanksSw, 24, 4)
        local tanks = inputRow("", d.roles.tanks, function(val) d.roles.tanks = val end)
        tanks.w:ClearAllPoints(); tanks.w:SetPoint("TOPLEFT", 0, 0); tanks.w:SetPoint("RIGHT", 0, 0)
        roles:Add(tanks, 28, 12)
        local promSw = K.SwitchRow(UIParent, "Assistants", function(val) d.roles.promoteOn = val end)
        roles:Add(promSw, 24, 4)
        local prom = inputRow("", d.roles.promote, function(val) d.roles.promote = val end)
        prom.w:ClearAllPoints(); prom.w:SetPoint("TOPLEFT", 0, 0); prom.w:SetPoint("RIGHT", 0, 0)
        roles:Add(prom, 28, 12)
        local mlSw = K.SwitchRow(UIParent, "Master looter - first one in the raid gets it", function(val) d.roles.mlOn = val end)
        roles:Add(mlSw, 24, 4)
        local ml = inputRow("", d.roles.ml, function(val) d.roles.ml = val end)
        ml.w:ClearAllPoints(); ml.w:SetPoint("TOPLEFT", 0, 0); ml.w:SetPoint("RIGHT", 0, 0)
        roles:Add(ml, 28, 12)
        local thDD = K.Dropdown(UIParent, 160, function(self)
            local entries = {}
            for q = 2, 4 do entries[#entries + 1] = { text = THRESHOLDS[q] .. " and better", checked = d.roles.threshold == q, onClick = function() d.roles.threshold = q; v.refresh() end } end
            K.openMenu(self, entries)
        end)
        local now = K.Button(UIParent, "Set roles now", 130, 26, "primary", "icon-check")
        now:SetScript("OnClick", function() RL:ApplyRoles(true) end)
        local thCap = K.Caption(UIParent, "Loot threshold")
        local row = buttonRow({ now, thDD })
        thCap:SetParent(row); thCap:ClearAllPoints(); thCap:SetPoint("RIGHT", thDD, "LEFT", -8, 0)
        thDD:ClearAllPoints(); thDD:SetPoint("LEFT", now, "RIGHT", 120, 0)
        roles:Add(row, 28, 8)

        v.refresh = function()
            dropdownText(thDD, THRESHOLDS[d.roles.threshold] .. " and better")
            tanksSw:SetValue(d.roles.tanksOn); promSw:SetValue(d.roles.promoteOn); mlSw:SetValue(d.roles.mlOn)
            tanks.w:SetValue(d.roles.tanks); prom.w:SetValue(d.roles.promote); ml.w:SetValue(d.roles.ml)
            v.stack:Layout()
        end
    end

    do
        local v = view("attendance")
        local days = 30
        local sum = v.stack:Add(wide(K.Card(v.frame, "Attendance", "Recorded on every boss pull in a raid.")))
        local rangeDD = K.Dropdown(UIParent, 140, function(self)
            local entries = {}
            for _, dd in ipairs({ 7, 14, 30, 90, 0 }) do
                entries[#entries + 1] = { text = dd == 0 and "All time" or ("Last " .. dd .. " days"), checked = days == dd, onClick = function() days = dd; v.refresh() end }
            end
            K.openMenu(self, entries)
        end)
        local exp = K.Button(UIParent, "Export CSV", 120, 26, nil, "icon-export")
        exp:SetScript("OnClick", function() K.CopyBox("Attendance", RL:AttendanceCSV(days > 0 and days or nil), "Paste into a spreadsheet.", true) end)
        sum:Add(buttonRow({ rangeDD, exp }), 28, 10)
        local at = Table(sum, { { title = "Player", w = 0.40 }, { title = "Raids", w = 0.30 }, { title = "Attendance", w = 0.30 } })
        sum:Add(at, 22, 4)

        local nightsCap = CreateFrame("Frame")
        nightsCap.t = K.T(nightsCap, 11, "accent")
        nightsCap.t:SetPoint("BOTTOMLEFT", 0, 0)
        nightsCap.t:SetText("RECENT RAID NIGHTS")
        sum:Add(nightsCap, 22, 6)
        local st = Table(sum, { { title = "Date", w = 0.22 }, { title = "Raid", w = 0.38 }, { title = "Bosses", w = 0.22 }, { title = "Players", w = 0.18 } })
        sum:Add(st, 22, 4)

        v.refresh = function()
            dropdownText(rangeDD, days == 0 and "All time" or ("Last " .. days .. " days"))
            local rows, total = RL:AttendanceTable(days > 0 and days or nil)
            local data = {}
            for _, r in ipairs(rows) do
                data[#data + 1] = { classColor(r.class) .. r.name .. "|r", r.count .. " / " .. total, (r.pct >= 75 and "|cff44ff88" or (r.pct >= 50 and "|cffffcc44" or "|cffff5555")) .. r.pct .. "%|r" }
            end
            if #data == 0 then data[1] = { "|cff8a8f98Nothing recorded yet.|r" } end
            at:Set(data)
            local sdata = {}
            local list = RL:Sessions()
            for i = #list, math.max(1, #list - 7), -1 do
                local s = list[i]
                local kills, n = 0, 0
                for _, b in ipairs(s.bosses) do if b.kill then kills = kills + 1 end end
                for _ in pairs(s.members) do n = n + 1 end
                sdata[#sdata + 1] = { s.date, s.instance or "?", kills .. " killed / " .. #s.bosses .. " pulls", tostring(n) }
            end
            if #sdata == 0 then sdata[1] = { "|cff8a8f98Nothing recorded yet.|r" } end
            st:Set(sdata)
            v.stack:Layout()
        end
    end

    do
        local v = view("loot")
        local query = ""
        local WHERE = { { "raid", "In raids" }, { "instance", "In raids and dungeons" }, { "always", "Always" } }
        local function whereText() for _, w in ipairs(WHERE) do if w[1] == d.loot.where then return w[2] end end return "In raids" end
        local rec = v.stack:Add(wide(K.Card(v.frame, "Record loot")))
        local whereDD = K.Dropdown(UIParent, 190, function(self)
            local e = {}
            for _, w in ipairs(WHERE) do e[#e + 1] = { text = w[2], checked = d.loot.where == w[1], onClick = function() d.loot.where = w[1]; v.refresh() end } end
            K.openMenu(self, e)
        end)
        rec:Add(buttonRow({ whereDD }), 28, 6)
        local card = v.stack:Add(wide(K.Card(v.frame, "Loot history", "The last 60 items - search or export for more.")))
        local search = K.Search(UIParent, 200, function(text) query = (text or ""):lower(); v.refresh() end)
        local qDD = K.Dropdown(UIParent, 150, function(self)
            local entries = {}
            for q = 2, 4 do entries[#entries + 1] = { text = THRESHOLDS[q] .. " and better", checked = d.loot.minQuality == q, onClick = function() d.loot.minQuality = q; v.refresh() end } end
            K.openMenu(self, entries)
        end)
        local exp = K.Button(UIParent, "Export CSV", 120, 26, nil, "icon-export")
        exp:SetScript("OnClick", function() K.CopyBox("Loot history", RL:LootCSV(), "Paste into a spreadsheet.", true) end)
        local clear = K.Button(UIParent, "Clear", 80, 26, "danger")
        local armed
        clear:SetScript("OnClick", function()
            if armed then armed = nil; clear.label:SetText("Clear"); RL:ClearLoot()
            else armed = true; clear.label:SetText("Sure?"); C_Timer.After(3, function() armed = nil; clear.label:SetText("Clear") end) end
        end)
        card:Add(buttonRow({ search, qDD, exp, clear }), 28, 8)
        local lt = Table(card, { { title = "When", w = 0.16 }, { title = "Player", w = 0.18 }, { title = "Item", w = 0.40 }, { title = "Boss", w = 0.26 } })
        card:Add(lt, 22, 4)
        v.refresh = function()
            dropdownText(qDD, THRESHOLDS[d.loot.minQuality] .. " and better")
            whereDD:SetText(whereText())
            local data = {}
            for _, e in ipairs(RL:Loot()) do
                local hay = (e.who .. " " .. (e.link:match("%[(.-)%]") or "") .. " " .. (e.boss or "")):lower()
                if query == "" or hay:find(query, 1, true) then
                    data[#data + 1] = { date("%d/%m %H:%M", e.t), e.who, e.link, e.boss or (e.instance or "") }
                    if #data >= 60 then break end
                end
            end
            if #data == 0 then data[1] = { "|cff8a8f98Nothing yet.|r" } end
            lt:Set(data)
            v.stack:Layout()
        end
    end

    do
        local v = view("general")
        local GS = Addon.GroupSetups
        local ui = v.stack:Add(K.Card(v.frame, "Raid button"))
        local btnSw = K.SwitchRow(UIParent, "Show the FojjiCore raid button", function(val) if GS then GS:SetShowButton(val) end end)
        ui:Add(btnSw, 24, 6)
        local leadSw = K.SwitchRow(UIParent, "Only when you're raid leader or assistant", function(val) if GS then GS:SetButtonLeadOnly(val) end end)
        ui:Add(leadSw, 24, 8)
        local function dirLabel()
            local cur = GS and GS:GetDirection() or "auto"
            for _, dd in ipairs(GS and GS.DIRECTIONS or {}) do if dd[1] == cur then return dd[2] end end
            return "Auto"
        end
        local dirDD = K.Dropdown(UIParent, 140, function(self)
            local e = {}
            for _, dd in ipairs(GS.DIRECTIONS) do
                e[#e + 1] = { text = dd[1] == "auto" and "Auto (away from the edge)" or dd[2], checked = GS:GetDirection() == dd[1], onClick = function() GS:SetDirection(dd[1]); v.refresh() end }
            end
            K.openMenu(self, e)
        end)
        local reset = K.Button(UIParent, "Reset position", 130, 28)
        reset:SetScript("OnClick", function() GS:ResetButton() end)
        local dirCap = K.Caption(UIParent, "Menu opens")
        local dirRow = buttonRow({ dirDD, reset })
        dirCap:SetParent(dirRow); dirCap:ClearAllPoints(); dirCap:SetPoint("LEFT", 0, 0)
        dirDD:ClearAllPoints(); dirDD:SetPoint("LEFT", 90, 0)
        ui:Add(dirRow, 28, 8)
        local log = v.stack:Add(K.Card(v.frame, "Combat logging"))
        local lr = K.SwitchRow(UIParent, "Log in raids", function(val) d.log.raids = val end)
        log:Add(lr, 24, 6)
        local ld = K.SwitchRow(UIParent, "Log in dungeons", function(val) d.log.dungeons = val end)
        log:Add(ld, 24, 6)
        local grp = v.stack:Add(K.Card(v.frame, "Group"))
        local accSw = K.SwitchRow(UIParent, "Accept invites from guild members and friends", function(val) d.invite.autoAccept = val end)
        grp:Add(accSw, 24, 6)
        local raidSw = K.SwitchRow(UIParent, "Convert to a raid when the party fills", function(val) d.invite.autoRaid = val end)
        grp:Add(raidSw, 24, 6)
        v.refresh = function()
            btnSw:SetValue(GS and GS:GetShowButton())
            leadSw:SetValue(GS and GS:GetButtonLeadOnly())
            dirDD:SetText(dirLabel())
            lr:SetValue(d.log.raids); ld:SetValue(d.log.dungeons)
            accSw:SetValue(d.invite.autoAccept); raidSw:SetValue(d.invite.autoRaid)
            v.stack:Layout()
        end
    end

    RL:OnChange(function(what)
        if not page:IsVisible() then return end
        local m = (what == "versions" or what == "check") and "versions" or what
        if views[m] and m == tabs.current then views[m].refresh() end
    end)
    local ticker
    page:HookScript("OnShow", function()
        K.repaint()
        tabs:Select(tabs.current)
        if not ticker then ticker = C_Timer.NewTicker(2, function() if page:IsVisible() and tabs.current == "versions" and views.versions then views.versions.refresh() end end) end
    end)
    page.SelectView = function(key) if key == "check" then key = "versions" end tabs:Select(key) end
    Addon.RaidLeadPage = page
    tabs:Select("general")
end
