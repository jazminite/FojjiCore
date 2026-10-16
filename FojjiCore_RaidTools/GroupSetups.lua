local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end

local GS = {}
Addon.GroupSetups = GS
FojjiCore = FojjiCore or {}
FojjiCore.GroupSetups = GS

local K
local function kit() K = K or Addon.UIKit; return K end
local function say(msg) if Addon.Print then Addon.Print(msg) else print("FojjiCore: " .. msg) end end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function db()
    FojjiCoreDB = FojjiCoreDB or {}
    local d = FojjiCoreDB.groupSetups
    if type(d) ~= "table" then d = {}; FojjiCoreDB.groupSetups = d end
    d.list = d.list or {}
    d.roster = d.roster or {}
    if d.showButton == nil then d.showButton = true end
    if d.buttonLeadOnly == nil then d.buttonLeadOnly = true end
    return d
end
function GS:List() return db().list end
function GS:Get(i) return db().list[i] end

local callbacks = {}
function GS:OnChange(fn) callbacks[#callbacks + 1] = fn end
local function changed() for i = 1, #callbacks do pcall(callbacks[i]) end end

local function newSetup(name)
    local s = { name = name, groups = {} }
    for g = 1, 8 do s.groups[g] = {} end
    return s
end

function GS:Count(setup)
    local n = 0
    for g = 1, 8 do n = n + #(setup.groups[g] or {}) end
    return n
end

local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" }
local classByWord
local function classOf(token)
    if not classByWord then
        classByWord = {}
        for _, c in ipairs(CLASS_TOKENS) do
            classByWord[c:lower()] = c
            classByWord[c:lower() .. "s"] = c
            local male = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]
            local female = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[c]
            if male then classByWord[male:lower()] = c end
            if female then classByWord[female:lower()] = c end
        end
        classByWord["death knight"], classByWord["demon hunter"] = "DEATHKNIGHT", "DEMONHUNTER"
    end
    return classByWord[trim(token):lower()]
end
GS.ClassOf = classOf

function GS:Roster_Keys() return db().roster end
function GS:KeyName(key)
    local r = db().roster.keys
    return r and r[trim(key):upper()]
end
function GS:RosterNames()
    local out, seen = {}, {}
    for _, name in pairs(db().roster.keys or {}) do
        if not seen[name] then seen[name] = true; out[#out + 1] = name end
    end
    table.sort(out)
    return out
end
function GS:SetRoster(pairs_, title)
    local r = db().roster
    r.keys, r.order, r.title, r.t = {}, {}, title, time()
    for _, p in ipairs(pairs_) do
        if not r.keys[p[1]] then r.order[#r.order + 1] = p[1] end
        r.keys[p[1]] = p[2]
    end
    changed()
end
function GS:ClearRoster() db().roster = {}; changed() end

function GS:Token(t)
    local class = classOf(t)
    if class then return "class", class end
    return "name", t
end

function GS:Parse(text, defaultName)
    text = (text or ""):gsub("\r", ""):gsub("[\n;|]", ",")
    local out, warn = {}, {}
    local cur, g = nil, 1
    local function ensure(title)
        cur = newSetup(title)
        out[#out + 1] = cur
        g = 1
    end
    for token in (text .. ","):gmatch("([^,]*),") do
        local t = trim(token)
        if t:sub(1, 1) == "#" then
            ensure(trim(t:sub(2)) ~= "" and trim(t:sub(2)) or nil)
        elseif t ~= "" then
            if not cur then ensure(nil) end
            local num, rest = t:match("^[Gg]?(%d+)%s*[%-%.:%)]%s*(.*)$")
            if num then
                num = tonumber(num)
                if num >= 1 and num <= 8 then g = num else warn[#warn + 1] = "group " .. num .. " ignored (1-8 only)" end
                t = trim(rest)
            end
            if t ~= "" then
                local grp = cur.groups[g]
                if #grp < 5 then grp[#grp + 1] = t
                else warn[#warn + 1] = t .. " skipped (group " .. g .. " already has 5)" end
            end
        end
    end
    local n = 0
    for i, s in ipairs(out) do
        if not s.name then n = n + 1; s.name = (defaultName and defaultName ~= "" and defaultName .. (n > 1 and (" " .. n) or "")) or ("Setup " .. (#db().list + i)) end
    end
    return out, warn
end

function GS:Export(setup, withTitle)
    local parts = {}
    if withTitle and setup.name then parts[1] = "#" .. setup.name end
    for g = 1, 8 do
        local grp = setup.groups[g] or {}
        for i, name in ipairs(grp) do parts[#parts + 1] = (i == 1 and (g .. "-") or "") .. name end
    end
    return table.concat(parts, ",")
end

function GS:Import(text, name)
    local setups, warn = self:Parse(text, name)
    local added = 0
    for _, s in ipairs(setups) do
        if self:Count(s) > 0 then
            local list, done = db().list, false
            for i, old in ipairs(list) do if old.name == s.name then list[i] = s; done = true break end end
            if not done then list[#list + 1] = s end
            added = added + 1
        end
    end
    for _, w in ipairs(warn) do say("|cffffaa00" .. w .. "|r") end
    if added > 0 then say(("Imported %d group setup%s."):format(added, added == 1 and "" or "s"))
    else say("Nothing to import - expected 1-Name,Name,2-Name,...") end
    changed()
    return added
end

function GS:ParseRoster(text)
    text = (text or ""):gsub("\r", "")
    local pairs_, skipped = {}, {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local tokens = {}
        if line:find("\t") and not line:find(",") then
            tokens[1] = line
        else
            for token in (line .. ","):gmatch("([^,;|]*)[,;|]") do tokens[#tokens + 1] = token end
        end
        for _, token in ipairs(tokens) do
            local t = trim(token)
            if t ~= "" then
                local key, name = t:match("^([%w_]+)%s*[%-:=\t]%s*(.-)%s*$")
                if not key then key, name = t:match("^([%w_]+)\t+(.-)%s*$") end
                if key and name and name ~= "" then pairs_[#pairs_ + 1] = { key:upper(), name }
                else skipped[#skipped + 1] = t end
            end
        end
    end
    return pairs_, skipped
end

function GS:ImportRoster(text, title)
    local pairs_, skipped = self:ParseRoster(text)
    if #pairs_ == 0 then
        say("Nothing to import - expected KEY-Name pairs, e.g. PROTWARR1-Midori One,HPALA1-Happyjoe.")
        return 0
    end
    title = trim(title)
    self:SetRoster(pairs_, title ~= "" and title or nil)
    say(("Roster imported: %d players%s."):format(#pairs_, title ~= "" and (" (" .. title .. ")") or ""))
    if #skipped > 0 then say(("|cffffaa00Skipped %d without a key: %s|r"):format(#skipped, table.concat(skipped, ", ", 1, math.min(5, #skipped)) .. (#skipped > 5 and ", ..." or ""))) end
    return #pairs_
end

function GS:Delete(i) table.remove(db().list, i); changed() end
function GS:Rename(i, name) local s = db().list[i]; if s and name and trim(name) ~= "" then s.name = trim(name); changed() end end

function GS:CaptureRaid()
    if not IsInRaid() then say("You are not in a raid.") return end
    local s = newSetup(date("Raid %d/%m %H:%M"))
    for i = 1, GetNumGroupMembers() do
        local name, _, sub = GetRaidRosterInfo(i)
        if name and sub and #s.groups[sub] < 5 then s.groups[sub][#s.groups[sub] + 1] = GS.KnownFull(trim((strsplit("-", name)))) end
    end
    local list = db().list
    list[#list + 1] = s
    say("Saved the current raid as \"" .. s.name .. "\".")
    changed()
    return #list
end

local function norm(n) return trim((strsplit("-", n or ""))):lower() end
local function first(n) return (n:match("^(%S+)")) or n end

local function hasSurname(n) return n:find("%s") ~= nil end

local function knownFull(name)
    if hasSurname(name) then return name end
    local RL = Addon.RaidLead
    local e = RL and RL.versions and RL.versions[name:match("^(%S+)") or name]
    if e and e.full and hasSurname(e.full) then return e.full end
    return name
end
GS.KnownFull = knownFull

function GS:Roster()
    local r, byFirst = {}, {}
    r.__first = byFirst
    if not IsInRaid() then return r end
    for i = 1, GetNumGroupMembers() do
        local name, rank, sub, _, _, classFile, _, online = GetRaidRosterInfo(i)
        if name then
            local full = knownFull(trim((strsplit("-", name))))
            local u = { name = name, full = full, index = i, subgroup = sub, class = classFile, online = online, rank = rank }
            local k = norm(full)
            r[k] = u
            local f = first(k)
            if byFirst[f] == nil then byFirst[f] = u else byFirst[f] = false end
        end
    end
    return r
end

function GS:Resolve(roster, sheetName)
    local k = norm(sheetName)
    if k == "" then return end
    if roster[k] then return roster[k] end
    local u = roster.__first and roster.__first[first(k)]
    if not u then return end
    if hasSurname(k) and hasSurname(u.full) then return end
    return u
end

local need, busy, passes
local driver = CreateFrame("Frame")

local function canMove()
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then return true end
    if UnitIsGroupAssistant and UnitIsGroupAssistant("player") then return true end
    if IsRaidLeader and IsRaidLeader() then return true end
    if IsRaidOfficer and IsRaidOfficer() then return true end
    return false
end

local function inCombat()
    local list
    for i = 1, GetNumGroupMembers() do
        local u = "raid" .. i
        if UnitAffectingCombat(u) then list = (list and list .. ", " or "") .. (UnitName(u) or "?") end
    end
    return list
end

local function finish(msg)
    need, busy = nil, nil
    driver:UnregisterEvent("GROUP_ROSTER_UPDATE")
    if msg then say(msg) end
    changed()
end

local function step()
    if not need then return end
    passes = passes + 1
    if passes > 40 then return finish("|cffff4444Group sort stopped|r - the raid did not settle.") end
    local fighting = inCombat()
    if fighting then return finish("|cffff4444Group sort stopped|r - in combat: " .. fighting) end

    local cur, id, size = {}, {}, {}
    for g = 1, 8 do size[g] = 0 end
    for i = 1, GetNumGroupMembers() do
        local name, _, sub = GetRaidRosterInfo(i)
        if name then cur[name] = sub; id[name] = i; size[sub] = size[sub] + 1 end
    end

    local moved = false
    for name, want in pairs(need) do
        local have = cur[name]
        if have and have ~= want and size[want] < 5 then
            SetRaidSubgroup(id[name], want)
            size[have], size[want] = size[have] - 1, size[want] + 1
            cur[name] = want
            moved = true
        end
    end
    if moved then return driver:Fallback() end

    local used = {}
    for name, want in pairs(need) do
        local have = cur[name]
        if have and have ~= want and not used[name] then
            for other, og in pairs(cur) do
                if og == want and not used[other] and need[other] ~= og then
                    SwapRaidSubgroup(id[name], id[other])
                    used[name], used[other] = true, true
                    moved = true
                    break
                end
            end
        end
    end
    if moved then return driver:Fallback() end

    finish("|cff44ff88Groups sorted.|r")
end

function driver:Fallback()
    if self.fb then self.fb:Cancel() end
    self.fb = C_Timer.NewTimer(2, function() self.fb = nil; if need then step() end end)
end
driver:SetScript("OnEvent", function()
    if driver.t then driver.t:Cancel() end
    driver.t = C_Timer.NewTimer(0.4, function() driver.t = nil; step() end)
end)

function GS:Apply(setup)
    if not setup then return end
    if not IsInRaid() then say("You need to be in a raid.") return end
    if not canMove() then say("You need to be raid leader or assistant to move players.") return end
    local fighting = inCombat()
    if fighting then say("|cffff4444Can't sort in combat|r: " .. fighting) return end
    local roster, missing = self:Roster(), {}
    need = {}
    local classSlots = {}
    for g = 1, 8 do
        for _, n in ipairs(setup.groups[g] or {}) do
            local kind, value = self:Token(n)
            if kind == "class" then
                classSlots[#classSlots + 1] = { g = g, class = value }
            else
                local u = self:Resolve(roster, value)
                if u and not need[u.name] then need[u.name] = g else missing[#missing + 1] = n end
            end
        end
    end
    local spare = {}
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, class = GetRaidRosterInfo(i)
        if name and not need[name] then spare[#spare + 1] = { name = name, class = class } end
    end
    for _, slot in ipairs(classSlots) do
        local hit
        for i, p in ipairs(spare) do if p.class == slot.class then hit = i break end end
        if hit then need[spare[hit].name] = slot.g; table.remove(spare, hit)
        else missing[#missing + 1] = slot.class:sub(1, 1) .. slot.class:sub(2):lower() end
    end
    if #missing > 0 then say("|cffffaa00Not in raid:|r " .. table.concat(missing, ", ")) end
    if not next(need) then return finish("Nobody from \"" .. (setup.name or "?") .. "\" is in the raid.") end
    busy, passes = setup.name, 0
    setup.used = time()
    driver:RegisterEvent("GROUP_ROSTER_UPDATE")
    say("Applying \"" .. (setup.name or "?") .. "\"...")
    changed()
    step()
end
function GS:IsBusy() return busy end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.85, 0.87, 0.9
end

local function GroupGrid(parent)
    kit()
    local grid = { boxes = {} }
    for g = 1, 8 do
        local b = CreateFrame("Frame", nil, parent)
        K.Surface(b, "field", 1, "borderDim")
        b.title = K.T(b, 11, "accent")
        b.title:SetPoint("TOPLEFT", 8, -6)
        b.title:SetText("Group " .. g)
        b.rows = {}
        for s = 1, 5 do
            local fs = K.T(b, 12, "text")
            fs:SetPoint("TOPLEFT", 8, -8 - s * 16)
            fs:SetPoint("RIGHT", -6, 0)
            b.rows[s] = fs
        end
        grid.boxes[g] = b
    end
    function grid:Layout(w, h)
        local cw, ch = (w - 3 * 8) / 4, (h - 8) / 2
        for g = 1, 8 do
            local b = self.boxes[g]
            b:ClearAllPoints()
            b:SetSize(cw, ch)
            b:SetPoint("TOPLEFT", parent, "TOPLEFT", ((g - 1) % 4) * (cw + 8), -math.floor((g - 1) / 4) * (ch + 8))
        end
    end
    function grid:Show(setup)
        local roster = GS:Roster()
        local inRaid = IsInRaid()
        for g = 1, 8 do
            local names = setup and setup.groups[g] or {}
            for s = 1, 5 do
                local fs, n = self.boxes[g].rows[s], names[s]
                local kind, value
                if n then kind, value = GS:Token(n) end
                if kind == "class" then
                    fs:SetText("Any " .. value:sub(1, 1) .. value:sub(2):lower())
                    fs:SetTextColor(classColor(value))
                elseif n then
                    local label = n
                    local u = inRaid and GS:Resolve(roster, value)
                    if u then
                        fs:SetText(n .. (u.subgroup == g and "" or "  |cff888888(G" .. u.subgroup .. ")|r"))
                        fs:SetTextColor(classColor(u.class))
                    else
                        fs:SetText(label .. (inRaid and "  |cffff5555missing|r" or ""))
                        fs:SetTextColor(0.6, 0.62, 0.66)
                    end
                else
                    fs:SetText("")
                end
            end
        end
    end
    return grid
end

local renameDlg
function GS:OpenRename(i)
    kit()
    local s = self:Get(i)
    if not s then return end
    if not renameDlg then
        local f = CreateFrame("Frame", "FojjiCoreGroupRename", UIParent)
        f:SetSize(360, 128)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        K.Surface(f, "frame", 0.98, "accent", 0.85); K.Sheen(f, 50, 0.12)
        if Addon.EscapeCloses then Addon.EscapeCloses("FojjiCoreGroupRename") end
        local t = K.T(f, 15, "white"); t:SetPoint("TOPLEFT", 16, -14); t:SetText("Rename setup")
        f.input = K.Input(f, nil)
        f.input.box:SetMaxLetters(60)
        f.input:SetPoint("TOPLEFT", 16, -44); f.input:SetPoint("RIGHT", -16, 0)
        local ok = K.Button(f, "Save", 100, 26, "primary"); ok:SetPoint("BOTTOMRIGHT", -14, 14)
        local cancel = K.Button(f, "Cancel", 90, 26); cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
        local function save() GS:Rename(f.index, f.input.box:GetText()); f:Hide() end
        ok:SetScript("OnClick", save)
        cancel:SetScript("OnClick", function() f:Hide() end)
        f.input.box:SetScript("OnEnterPressed", save)
        f.input.box:SetScript("OnEscapePressed", function() f:Hide() end)
        renameDlg = f
    end
    renameDlg.index = i
    renameDlg.input.box:SetText(s.name or "")
    renameDlg:ClearAllPoints(); renameDlg:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    renameDlg:Show(); renameDlg:Raise()
    renameDlg.input.box:SetFocus(); renameDlg.input.box:HighlightText()
    K.repaint()
end

local pasteDlg
function GS:OpenPaste()
    kit()
    if not pasteDlg then
        local f = CreateFrame("Frame", "FojjiCoreGroupPaste", UIParent)
        f:SetSize(560, 330)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetClampedToScreen(true)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        K.Surface(f, "frame", 0.98, "accent", 0.85); K.Sheen(f, 60, 0.12)
        if Addon.EscapeCloses then Addon.EscapeCloses("FojjiCoreGroupPaste") end
        local t = K.T(f, 16, "white"); t:SetPoint("TOPLEFT", 18, -16); t:SetText("Import group setup")
        local n = K.T(f, 12, "dim"); n:SetPoint("TOPLEFT", 18, -40); n:SetPoint("RIGHT", -18, 0); n:SetWordWrap(true)
        n:SetText("1-Name,Name,2-Name,Name  -  a class (1-Warrior) takes anyone of that class")
        f.name = K.Input(f); f.name:SetPoint("TOPLEFT", 18, -66); f.name:SetPoint("RIGHT", -18, 0)
        f.nameHint = K.T(f.name, 12, "dim"); f.nameHint:SetPoint("LEFT", 9, 0); f.nameHint:SetText("Title (optional)")
        f.name.box:HookScript("OnTextChanged", function(self) f.nameHint:SetShown(self:GetText() == "") end)
        local field = CreateFrame("Frame", nil, f)
        K.Surface(field, "field", 1, "border", 1)
        field:SetPoint("TOPLEFT", 18, -102); field:SetPoint("RIGHT", -18, 0); field:SetPoint("BOTTOM", 0, 56)
        local sc = CreateFrame("ScrollFrame", nil, field)
        sc:SetPoint("TOPLEFT", 8, -6); sc:SetPoint("BOTTOMRIGHT", -8, 6)
        local eb = CreateFrame("EditBox", nil, sc)
        eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(0)
        eb:SetFont(K.FONT, 12, ""); eb:SetTextColor(0.95, 0.96, 0.98)
        eb:SetWidth(500)
        sc:SetScrollChild(eb)
        field:EnableMouse(true); field:SetScript("OnMouseDown", function() eb:SetFocus() end)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        f.eb = eb
        local ok = K.Button(f, "Import", 120, 28, "primary"); ok:SetPoint("BOTTOMRIGHT", -16, 14)
        local cancel = K.Button(f, "Cancel", 100, 28); cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
        cancel:SetScript("OnClick", function() f:Hide() end)
        ok:SetScript("OnClick", function()
            if GS:Import(eb:GetText(), trim(f.name.box:GetText())) > 0 then f:Hide(); if GS.popup and GS.popup:IsShown() then GS.popup:Select(#GS:List()) end end
        end)
        pasteDlg = f
    end
    pasteDlg.eb:SetText(""); pasteDlg.name.box:SetText("")
    pasteDlg:ClearAllPoints(); pasteDlg:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    pasteDlg:Show(); pasteDlg:Raise(); pasteDlg.eb:SetFocus()
    K.repaint()
end

local function buildPopup()
    kit()
    local f = CreateFrame("Frame", "FojjiCoreGroupPopup", UIParent)
    f:SetSize(860, 420)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(300)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint(); db().popupPos = { p, rp, x, y } end)
    K.Surface(f, "frame", 0.97, "accent", 0.7); K.Sheen(f, 60, 0.10)
    if Addon.EscapeCloses then Addon.EscapeCloses("FojjiCoreGroupPopup") end
    local title = K.T(f, 16, "white"); title:SetPoint("TOPLEFT", 18, -14); title:SetText("Group Setups")
    f.status = K.T(f, 12, "dim"); f.status:SetPoint("LEFT", title, "RIGHT", 14, 0)
    local close = K.Button(f, "X", 26, 26); close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() f:Hide() end)

    local left = CreateFrame("Frame", nil, f)
    left:SetPoint("TOPLEFT", 14, -48); left:SetPoint("BOTTOMLEFT", 14, 52); left:SetWidth(210)
    K.Surface(left, "field", 0.8, "borderDim")
    local sc = CreateFrame("ScrollFrame", nil, left)
    sc:SetPoint("TOPLEFT", 4, -4); sc:SetPoint("BOTTOMRIGHT", -4, 4)
    sc:EnableMouseWheel(true)
    sc:SetScript("OnMouseWheel", function(self, d) self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * 26))) end)
    local body = CreateFrame("Frame", nil, sc); body:SetSize(200, 10); sc:SetScrollChild(body)
    f.rows = {}

    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0); right:SetPoint("BOTTOMRIGHT", -14, 52)
    local grid = GroupGrid(right)
    right:SetScript("OnSizeChanged", function(_, w, h) grid:Layout(w, h) end)
    grid:Layout(860 - 14 - 210 - 12 - 14, 420 - 48 - 52)

    local apply = K.Button(f, "Apply groups", 140, 30, "primary", "icon-play"); apply:SetPoint("BOTTOMRIGHT", -14, 12)
    local export = K.Button(f, "Export", 90, 30); export:SetPoint("RIGHT", apply, "LEFT", -8, 0)
    local ren = K.Button(f, "Rename", 90, 30); ren:SetPoint("RIGHT", export, "LEFT", -8, 0)
    local del = K.Button(f, "Delete", 90, 30, "danger"); del:SetPoint("RIGHT", ren, "LEFT", -8, 0)
    local imp = K.Button(f, "Import...", 110, 30); imp:SetPoint("BOTTOMLEFT", 14, 12)
    local cap = K.Button(f, "Save current raid", 150, 30); cap:SetPoint("LEFT", imp, "RIGHT", 8, 0)
    K.Tip(apply, "Apply groups", "Moves everyone into their group. Needs raid lead or assist, out of combat.")
    K.Tip(cap, "Save current raid", "Stores the raid's current groups as a new setup.")

    f.sel = 1
    function f:Select(i) self.sel = i; self:Refresh() end
    function f:Refresh()
        local list = GS:List()
        if self.sel > #list then self.sel = #list end
        if self.sel < 1 then self.sel = 1 end
        for i, s in ipairs(list) do
            local r = self.rows[i]
            if not r then
                r = CreateFrame("Button", nil, body)
                r:SetSize(200, 24)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
                r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture(K.WHITE)
                r.label = K.T(r, 12, "text"); r.label:SetPoint("LEFT", 8, 0); r.label:SetPoint("RIGHT", -34, 0)
                r.count = K.T(r, 11, "dim", "RIGHT"); r.count:SetPoint("RIGHT", -6, 0)
                r:SetScript("OnClick", function(btn) f:Select(btn.i) end)
                r:SetScript("OnDoubleClick", function(btn) GS:Apply(GS:Get(btn.i)) end)
                r:SetScript("OnEnter", function(btn) if btn.i ~= f.sel then btn.bg:SetVertexColor(1, 1, 1, 0.06) end end)
                r:SetScript("OnLeave", function() f:Refresh() end)
                self.rows[i] = r
            end
            r.i = i
            r.label:SetText(s.name or ("Setup " .. i))
            r.count:SetText(GS:Count(s))
            if i == self.sel then local cr, cg, cb = K.C("accent"); r.bg:SetVertexColor(cr, cg, cb, 0.30); r.label:SetTextColor(1, 1, 1)
            else r.bg:SetVertexColor(0, 0, 0, 0); r.label:SetTextColor(K.C("text")) end
            r:Show()
        end
        for i = #list + 1, #self.rows do self.rows[i]:Hide() end
        body:SetHeight(math.max(10, #list * 26))
        local s = list[self.sel]
        grid:Show(s)
        local has = s ~= nil
        apply:SetEnabled(has and IsInRaid() and not GS:IsBusy()); export:SetEnabled(has); del:SetEnabled(has); ren:SetEnabled(has); ren:SetAlpha(has and 1 or 0.45)
        apply:SetAlpha(apply:IsEnabled() and 1 or 0.45); export:SetAlpha(has and 1 or 0.45); del:SetAlpha(has and 1 or 0.45)
        cap:SetEnabled(IsInRaid()); cap:SetAlpha(IsInRaid() and 1 or 0.45)
        if GS:IsBusy() then self.status:SetText("|cffffcc44applying " .. GS:IsBusy() .. "...|r")
        elseif #list == 0 then self.status:SetText("no setups yet - Import... or Save current raid")
        elseif not IsInRaid() then self.status:SetText("not in a raid - preview only")
        elseif not canMove() then self.status:SetText("|cffff8866need lead or assist to apply|r")
        else self.status:SetText("double-click a setup to apply it") end
    end
    apply:SetScript("OnClick", function() GS:Apply(GS:Get(f.sel)) end)
    export:SetScript("OnClick", function()
        local s = GS:Get(f.sel)
        if s and K.CopyBox then K.CopyBox("Export: " .. (s.name or ""), GS:Export(s), "Paste into another FojjiCore (Import...) or the sheet.") end
    end)
    del:SetScript("OnClick", function() GS:Delete(f.sel) end)
    ren:SetScript("OnClick", function() GS:OpenRename(f.sel) end)
    imp:SetScript("OnClick", function() GS:OpenPaste() end)
    cap:SetScript("OnClick", function() local i = GS:CaptureRaid(); if i then f:Select(i) end end)

    f:SetScript("OnShow", function(self) K.repaint(); self:Refresh() end)
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:SetScript("OnEvent", function(self) if self:IsShown() then self:Refresh() end end)
    GS:OnChange(function() if f:IsShown() then f:Refresh() end end)
    local pos = db().popupPos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", 0, 60) end
    f:Hide()
    return f
end

function GS:TogglePopup()
    if not self.popup then self.popup = buildPopup() end
    self.popup:SetShown(not self.popup:IsShown())
    if self.popup:IsShown() then self.popup:Raise() end
end

local raidBtn
local function updateButton()
    if not raidBtn then return end
    local d = db()
    local show = IsInRaid() and (not d.buttonLeadOnly or canMove())
    raidBtn:SetShown(d.showButton and show and true or false)
    if not raidBtn:IsShown() and GS.flyout then GS.flyout:Hide() end
end
function GS:SetShowButton(v) db().showButton = v and true or false; updateButton() end
function GS:GetShowButton() return db().showButton end
function GS:SetButtonLeadOnly(v) db().buttonLeadOnly = v and true or false; updateButton() end
function GS:GetButtonLeadOnly() return db().buttonLeadOnly end

local LOGO = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"

local function menuEntries()
    local RL = Addon.RaidLead
    local e = {}
    e[#e + 1] = { text = "Group setups", onClick = function() GS:TogglePopup() end }
    local CDA = Addon.CDAssign
    if CDA and CDA.active and CDA.active.own then e[#e + 1] = { text = "Send assignments", tag = CDA.active.title, onClick = function() CDA:Send() end } end
    if Addon.Assignments and Addon.Assignments.Open then e[#e + 1] = { text = "Position maps", onClick = function() Addon.Assignments:Open() end } end
    local list = GS:List()
    if #list > 0 then
        local last, lastI
        for i, s in ipairs(list) do if s.used and (not last or s.used > last.used) then last, lastI = s, i end end
        if last then
            e[#e + 1] = { text = "Apply " .. (last.name or "setup"), tag = "last", disabled = not canMove(), onClick = function() GS:Apply(GS:Get(lastI)) end }
        end
        e[#e + 1] = { text = "Apply groups", tag = #list .. "  >", page = function()
            local p = { { text = "< Back", back = true } }
            local order = {}
            for i in ipairs(list) do order[#order + 1] = i end
            table.sort(order, function(a, b) return (list[a].used or 0) > (list[b].used or 0) or ((list[a].used or 0) == (list[b].used or 0) and a > b) end)
            for n, i in ipairs(order) do
                if n > 12 then
                    p[#p + 1] = { text = "All " .. #list .. " setups...", onClick = function() GS:TogglePopup() end }
                    break
                end
                local s = list[i]
                p[#p + 1] = { text = s.name or ("Setup " .. i), tag = tostring(GS:Count(s)), disabled = not canMove(), onClick = function() GS:Apply(GS:Get(i)) end }
            end
            return p
        end }
    end
    local ready = (C_PartyInfo and C_PartyInfo.DoReadyCheck) or DoReadyCheck
    if ready then e[#e + 1] = { text = "Ready check", disabled = not canMove(), onClick = function() ready() end } end
    if RL then
        e[#e + 1] = { text = "Check versions", onClick = function() RL:CheckVersions(); if FojjiCore.ToggleOptions then FojjiCore:ToggleOptions("raidlead") end; if Addon.RaidLeadPage then Addon.RaidLeadPage.SelectView("versions") end end }
        e[#e + 1] = { text = "Set raid roles", disabled = not (UnitIsGroupLeader and UnitIsGroupLeader("player")), onClick = function() RL:ApplyRoles(true) end }
        e[#e + 1] = { text = "Invite roster", onClick = function() RL:InviteRoster() end }
    end
    return e
end

GS.DIRECTIONS = { { "auto", "Auto" }, { "down", "Down" }, { "up", "Up" }, { "left", "Left" }, { "right", "Right" } }
function GS:GetDirection() return db().buttonDir or "auto" end
function GS:SetDirection(v) db().buttonDir = v; if self.flyout then self.flyout:Hide() end end
function GS:ResetButton()
    db().buttonPos = nil
    if raidBtn then raidBtn:ClearAllPoints(); raidBtn:SetPoint("TOP", UIParent, "TOP", 0, -14) end
end

local flyout
local function closeFlyout() if flyout then flyout:Hide() end end

local function placeFlyout(f, b)
    local dir = GS:GetDirection()
    local cx, cy = b:GetCenter()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = b:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cx, cy = (cx or 0) * scale, (cy or 0) * scale
    local onRight, onTop = cx > sw / 2, cy > sh / 2
    if dir == "auto" then
        local edgeX = math.min(cx, sw - cx) / sw
        local edgeY = math.min(cy, sh - cy) / sh
        if edgeX < 0.12 and edgeY > 0.12 then dir = onRight and "left" or "right"
        else dir = onTop and "down" or "up" end
    end
    f:ClearAllPoints()
    if dir == "down" then
        if onRight then f:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -4) else f:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4) end
    elseif dir == "up" then
        if onRight then f:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, 4) else f:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 4) end
    elseif dir == "left" then
        if onTop then f:SetPoint("TOPRIGHT", b, "TOPLEFT", -4, 0) else f:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -4, 0) end
    else
        if onTop then f:SetPoint("TOPLEFT", b, "TOPRIGHT", 4, 0) else f:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 4, 0) end
    end
end

local function buildFlyout()
    local f = CreateFrame("Frame", "FojjiCoreRaidFlyout", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetWidth(196)
    f:SetFrameLevel(50)
    K.Surface(f, "frame", 0.97, "border", 1)
    if Addon.EscapeCloses then Addon.EscapeCloses("FojjiCoreRaidFlyout") end
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(1)
    catcher:RegisterForClicks("AnyDown")
    catcher:SetScript("OnClick", closeFlyout)
    catcher:Hide()
    f.rows = {}
    function f:Fill(entries)
        local y = 6
        for i, e in ipairs(entries) do
            local r = self.rows[i]
            if not r then
                r = CreateFrame("Button", nil, self)
                r:SetPoint("LEFT", 4, 0); r:SetPoint("RIGHT", -4, 0)
                r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture(K.WHITE); r.bg:SetVertexColor(1, 1, 1, 0)
                r.t = K.T(r, 12, "text"); r.t:SetPoint("LEFT", 8, 0); r.t:SetPoint("RIGHT", -34, 0)
                r.tag = K.T(r, 11, "dim", "RIGHT"); r.tag:SetPoint("RIGHT", -8, 0)
                r:SetScript("OnEnter", function(self) if self.e and not self.e.header and not self.e.disabled then local cr, cg, cb = K.C("accent"); self.bg:SetVertexColor(cr, cg, cb, 0.25) end end)
                r:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0) end)
                r:SetScript("OnClick", function(self)
                    local e = self.e
                    if not e or e.header or e.disabled then return end
                    if e.back then flyout:Fill(menuEntries()); return end
                    if e.page then flyout:Fill(e.page()); return end
                    closeFlyout()
                    if e.onClick then e.onClick() end
                end)
                self.rows[i] = r
            end
            r.e = e
            local h = e.header and 20 or 24
            r:SetHeight(h)
            r:SetPoint("TOP", 0, -y)
            y = y + h
            r.t:SetText(e.header and e.text:upper() or e.text)
            r.t:SetTextColor(K.C(e.header and "accent" or (e.disabled and "dim" or "text")))
            r.tag:SetText(e.tag or "")
            r.bg:SetVertexColor(1, 1, 1, 0)
            r:Show()
        end
        for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
        self:SetHeight(y + 6)
    end
    f:SetScript("OnShow", function() catcher:Show() end)
    f:SetScript("OnHide", function() catcher:Hide(); if raidBtn then raidBtn:Paint() end end)
    f:Hide()
    return f
end

local function toggleFlyout(b)
    if not flyout then flyout = buildFlyout(); GS.flyout = flyout end
    if flyout:IsShown() then flyout:Hide() return end
    flyout:Fill(menuEntries())
    placeFlyout(flyout, b)
    flyout:Show(); flyout:Raise()
    b:Paint()
end

local function buildButton()
    kit()
    local b = CreateFrame("Button", "FojjiCoreRaidButton", UIParent)
    b:SetSize(34, 34)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:SetMovable(true); b:EnableMouse(true); b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    K.Surface(b, "frame", 0.94, "border", 1)
    b.sheen = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.sheen:SetPoint("TOPLEFT", 1, -1); b.sheen:SetPoint("TOPRIGHT", -1, -1); b.sheen:SetHeight(16)
    b.sheen:SetTexture(K.WHITE)
    if b.sheen.SetGradient and CreateColor then b.sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.06)) else b.sheen:SetVertexColor(1, 1, 1, 0.03) end
    b.logo = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.logo:SetSize(24, 24); b.logo:SetPoint("CENTER")
    b.logo:SetTexture(LOGO .. "logo-small-base")
    b.arc = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.arc:SetAllPoints(b.logo)
    b.arc:SetTexture(LOGO .. "logo-small-arc")
    b.grip = b:CreateTexture(nil, "OVERLAY")
    b.grip:SetSize(6, 6); b.grip:SetPoint("BOTTOMRIGHT", -3, 3); b.grip:SetTexture(K.WHITE)
    function b:Paint()
        local open = flyout and flyout:IsShown()
        local r, g, bl = K.C("accent")
        self.arc:SetVertexColor(r, g, bl)
        self.bd:Set((self.hover or open) and "accent" or "border", (self.hover or open) and 0.9 or 1)
        self.bg:SetVertexColor(K.C(open and "buttonHover" or "frame"))
        self.grip:SetVertexColor(r, g, bl, self.hover and 0.6 or 0)
    end
    K.paint(function() b:Paint() end)
    b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    b:SetScript("OnDragStart", function(self) closeFlyout(); self.dragging = true; self:StartMoving() end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing(); self.dragging = false
        local p, _, rp, x, y = self:GetPoint(); db().buttonPos = { p, rp, x, y }
    end)
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then closeFlyout(); if FojjiCore.ToggleOptions then FojjiCore:ToggleOptions() end return end
        toggleFlyout(self)
    end)
    K.Tip(b, "FojjiCore", "Click: raid tools\nRight-click: open FojjiCore\nDrag: move")
    local pos = db().buttonPos
    if pos then b:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else b:SetPoint("TOP", UIParent, "TOP", 0, -14) end
    return b
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PARTY_LEADER_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        db()
        if not raidBtn then raidBtn = buildButton() end
    end
    updateButton()
end)

function GS.Slash(rest)
    rest = trim(rest or ""):lower()
    if rest == "import" or rest == "paste" then GS:OpenPaste()
    elseif rest == "button" then GS:SetShowButton(not GS:GetShowButton()); say("Raid button " .. (GS:GetShowButton() and "shown" or "hidden") .. ".")
    elseif rest == "edit" or rest == "builder" then
        FojjiCore:ToggleOptions("raidlead")
        if Addon.RaidLeadPage then Addon.RaidLeadPage.SelectView("groups") end
    else GS:TogglePopup() end
    return true
end

local function pasteField(card, height)
    local name = K.Input(card); card:Add(name, 28, 8)
    name.box:SetMaxLetters(80)
    local hint = K.T(name, 12, "dim"); hint:SetPoint("LEFT", 9, 0); hint:SetText("Title (optional)")
    name.box:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    local field = CreateFrame("Frame", nil, card)
    K.Surface(field, "field", 1, "border", 1)
    card:Add(field, height or 120, 10)
    local sc = CreateFrame("ScrollFrame", nil, field)
    sc:SetPoint("TOPLEFT", 8, -6); sc:SetPoint("BOTTOMRIGHT", -8, 6)
    local eb = CreateFrame("EditBox", nil, sc)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(0)
    eb:SetFont(K.FONT, 12, ""); eb:SetTextColor(0.95, 0.96, 0.98); eb:SetWidth(500)
    sc:SetScrollChild(eb)
    sc:SetScript("OnSizeChanged", function(_, w) eb:SetWidth(math.max(100, w)) end)
    field:EnableMouse(true); field:SetScript("OnMouseDown", function() eb:SetFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function clear() eb:SetText(""); name.box:SetText(""); eb:ClearFocus() end
    return name, eb, clear
end

local function classHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) end
    return "|cffd8dbe0"
end

local function className(c) return c:sub(1, 1) .. c:sub(2):lower() end

local function buildSetupsView(view, UI, openBuilder)
    local stack = K.CardStack(view, -44, UI)

    local imp = stack:Add(K.Card(view, "Import setups",
        "1-Fojji,Farsan,2-Midori,Shoop - the number starts a group. A class (1-Warrior,Priest) takes anyone of that class. #Title names a setup; one setup per line."))
    local name, eb, clearField = pasteField(imp, 120)
    local row = CreateFrame("Frame", nil, imp); row.fill = false; row:SetSize(400, 28)
    local go = K.Button(row, "Import", 120, 28, "primary"); go:SetPoint("LEFT", 0, 0)
    local open = K.Button(row, "Group popup", 140, 28, nil, "icon-raid"); open:SetPoint("LEFT", go, "RIGHT", 8, 0)
    imp:Add(row, 28, 8)
    go:SetScript("OnClick", function()
        if GS:Import(eb:GetText(), trim(name.box:GetText())) > 0 then clearField() end
    end)
    open:SetScript("OnClick", function() GS:TogglePopup() end)

    local saved = stack:Add(K.Card(view, "Saved setups"))
    local holder = CreateFrame("Frame", nil, saved); holder:SetHeight(10)
    saved:Add(holder, 10, 6)
    local lines = {}
    local function refresh()
        local list = GS:List()
        for i, s in ipairs(list) do
            local l = lines[i]
            if not l then
                l = CreateFrame("Frame", nil, holder); l:SetHeight(30)
                l:SetPoint("TOPLEFT", 0, -(i - 1) * 34); l:SetPoint("RIGHT", 0, 0)
                K.Surface(l, "field", 0.7, "borderDim")
                l.label = K.T(l, 13, "text"); l.label:SetPoint("LEFT", 10, 0); l.label:SetPoint("RIGHT", -330, 0)
                l.del = K.Button(l, "", 26, 22, "danger", "icon-minus"); l.del:SetPoint("RIGHT", -4, 0)
                l.exp = K.Button(l, "Export", 70, 22); l.exp:SetPoint("RIGHT", l.del, "LEFT", -6, 0)
                l.app = K.Button(l, "Apply", 70, 22, "primary"); l.app:SetPoint("RIGHT", l.exp, "LEFT", -6, 0)
                l.edit = K.Button(l, "Edit", 60, 22); l.edit:SetPoint("RIGHT", l.app, "LEFT", -6, 0)
                l.ren = K.Button(l, "Rename", 70, 22); l.ren:SetPoint("RIGHT", l.edit, "LEFT", -6, 0)
                l.ren:SetScript("OnClick", function() GS:OpenRename(l.i) end)
                l.del:SetScript("OnClick", function() GS:Delete(l.i) end)
                l.app:SetScript("OnClick", function() GS:Apply(GS:Get(l.i)) end)
                l.exp:SetScript("OnClick", function() local s2 = GS:Get(l.i); if s2 then K.CopyBox("Export: " .. (s2.name or ""), GS:Export(s2), "Paste into another FojjiCore or the sheet.") end end)
                l.edit:SetScript("OnClick", function() openBuilder(l.i) end)
                lines[i] = l
            end
            l.i = i
            l.label:SetText((s.name or ("Setup " .. i)) .. "  |cff8a8f98" .. GS:Count(s) .. "|r")
            l:Show()
        end
        for i = #list + 1, #lines do lines[i]:Hide() end
        local h = math.max(1, #list) * 34
        if #list == 0 then
            holder.empty = holder.empty or K.T(holder, 12, "dim")
            holder.empty:SetPoint("TOPLEFT", 0, -4); holder.empty:SetText("No setups yet."); holder.empty:Show()
            h = 24
        elseif holder.empty then holder.empty:Hide() end
        holder:SetHeight(h)
        for _, it in ipairs(saved.items) do if it.w == holder then it.h = h end end
        stack:Layout()
    end
    GS:OnChange(function() if view:IsVisible() then refresh() end end)
    view:HookScript("OnShow", refresh)
end

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function emptyDraft()
    local d = { name = "", groups = {} }
    for g = 1, 8 do d.groups[g] = { "", "", "", "", "" } end
    return d
end

function GS:LoadDraft(i)
    local d = emptyDraft()
    local s = i and self:Get(i)
    if s then
        d.name, d.src = s.name or "", i
        for g = 1, 8 do for k, n in ipairs(s.groups[g] or {}) do if k <= 5 then d.groups[g][k] = n end end end
    end
    self.draft = d
    changed()
end

function GS:DraftFromRaid()
    local d = emptyDraft()
    d.name = date("Raid %d/%m %H:%M")
    if IsInRaid() then
        local fill = {}
        for i = 1, GetNumGroupMembers() do
            local name, _, sub = GetRaidRosterInfo(i)
            if name and sub then
                fill[sub] = (fill[sub] or 0) + 1
                if fill[sub] <= 5 then d.groups[sub][fill[sub]] = knownFull(trim((strsplit("-", name)))) end
            end
        end
    end
    self.draft = d
    changed()
end

local function draftToSetup(d)
    local s = newSetup(trim(d.name) ~= "" and trim(d.name) or nil)
    for g = 1, 8 do for k = 1, 5 do local n = trim(d.groups[g][k]); if n ~= "" then s.groups[g][#s.groups[g] + 1] = n end end end
    return s
end

function GS:SaveDraft()
    local d = self.draft
    if not d then return end
    local s = draftToSetup(d)
    if self:Count(s) == 0 then say("Nothing to save - the groups are empty.") return end
    local list = db().list
    if not s.name then s.name = "Setup " .. (#list + 1) end
    local at
    if d.src and list[d.src] and (list[d.src].name == s.name or trim(d.name) == "") then at = d.src end
    if not at then for i, old in ipairs(list) do if old.name == s.name then at = i break end end end
    if at then list[at] = s else list[#list + 1] = s; at = #list end
    d.src, d.name = at, s.name
    say(("Saved \"%s\"."):format(s.name))
    changed()
end

local function buildBuilderView(view)
    if not GS.draft then GS.draft = emptyDraft() end
    local slots, pool = {}, {}
    local selected
    local source = "raid"

    local bar = CreateFrame("Frame", nil, view)
    bar:SetPoint("TOPLEFT", 0, -44); bar:SetPoint("RIGHT", -18, 0); bar:SetHeight(28)
    local loadDD = K.Dropdown(bar, 180, function(self)
        local e = { { text = "New (empty)", onClick = function() GS:LoadDraft(nil) end } }
        for i, s in ipairs(GS:List()) do e[#e + 1] = { text = s.name or ("Setup " .. i), tag = tostring(GS:Count(s)), checked = GS.draft.src == i, onClick = function() GS:LoadDraft(i) end } end
        K.openMenu(self, e)
    end)
    loadDD:SetPoint("LEFT", 0, 0)
    local nameIn = K.Input(bar, function(val) GS.draft.name = val or "" end)
    nameIn.box:SetMaxLetters(60)
    nameIn:SetWidth(180); nameIn:SetPoint("LEFT", loadDD, "RIGHT", 8, 0)
    nameIn.box:HookScript("OnTextChanged", function(self) GS.draft.name = self:GetText() end)
    local nameHint = K.T(nameIn, 12, "dim"); nameHint:SetPoint("LEFT", 9, 0); nameHint:SetText("Title")
    nameIn.box:HookScript("OnTextChanged", function(self) nameHint:SetShown(self:GetText() == "") end)
    local fromRaid = K.Button(bar, "From raid", 96, 28); fromRaid:SetPoint("LEFT", nameIn, "RIGHT", 8, 0)
    local clearB = K.Button(bar, "Clear", 70, 28); clearB:SetPoint("LEFT", fromRaid, "RIGHT", 8, 0)
    local apply = K.Button(bar, "Apply", 80, 28, "primary", "icon-play"); apply:SetPoint("RIGHT", 0, 0)
    local save = K.Button(bar, "Save", 80, 28); save:SetPoint("RIGHT", apply, "LEFT", -8, 0)
    fromRaid:SetScript("OnClick", function() GS:DraftFromRaid() end)
    clearB:SetScript("OnClick", function() local n, src = GS.draft.name, GS.draft.src; GS.draft = emptyDraft(); GS.draft.name, GS.draft.src = n, src; changed() end)
    save:SetScript("OnClick", function() GS:SaveDraft() end)
    apply:SetScript("OnClick", function() GS:Apply(draftToSetup(GS.draft)) end)
    K.Tip(fromRaid, "From raid", "Copies the raid's current groups.")

    local gridArea = CreateFrame("Frame", nil, view)
    gridArea:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -10); gridArea:SetPoint("BOTTOMRIGHT", -236, 30)
    local poolArea = CreateFrame("Frame", nil, view)
    poolArea:SetPoint("TOPLEFT", gridArea, "TOPRIGHT", 12, 0); poolArea:SetPoint("BOTTOMRIGHT", -18, 30)
    K.Surface(poolArea, "field", 0.8, "borderDim")

    local leftBtns, rightBtns = { loadDD, nameIn, fromRaid, clearB }, { save, apply }
    local function layout()
        local W = (view:GetWidth() or 0) - 18
        local H = view:GetHeight() or 0
        if W < 200 or H < 120 then return end
        local GAP = 8
        local fixedL = fromRaid:GetWidth() + clearB:GetWidth() + GAP * 3
        local rightW = 0
        for i, b in ipairs(rightBtns) do rightW = rightW + b:GetWidth() + (i > 1 and GAP or 0) end
        local flex = math.floor((W - rightW - 16 - fixedL) / 2)
        local rows = 1
        if flex >= 120 then
            flex = math.min(flex, 180)
        else
            rows = 2
            flex = math.max(100, math.min(180, math.floor((W - fixedL) / 2)))
        end
        loadDD:SetWidth(flex)
        nameIn:SetWidth(flex)
        local x = 0
        for _, b in ipairs(leftBtns) do
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "TOPLEFT", x, -14)
            x = x + b:GetWidth() + GAP
        end
        local rx, cy = W, rows == 1 and -14 or -50
        for i = #rightBtns, 1, -1 do
            local b = rightBtns[i]
            b:ClearAllPoints()
            b:SetPoint("RIGHT", bar, "TOPLEFT", rx, cy)
            rx = rx - b:GetWidth() - GAP
        end
        local barH = rows == 1 and 28 or 64
        bar:SetHeight(barH)
        local poolW = math.max(160, math.min(236, W - 12 - 4 * 80 - 24))
        local top = 44 + barH + 10
        local gridW = math.max(120, W - poolW - 12)
        local h = math.max(80, H - top - 30)
        gridArea:ClearAllPoints()
        gridArea:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -top)
        gridArea:SetSize(gridW, h)
        poolArea:ClearAllPoints()
        poolArea:SetPoint("TOPLEFT", view, "TOPLEFT", gridW + 12, -top)
        poolArea:SetSize(poolW, h)
    end
    view:HookScript("OnSizeChanged", layout)
    view:HookScript("OnShow", layout)
    C_Timer.After(0, layout)
    local hint = K.T(view, 11, "dim")
    hint:SetPoint("BOTTOMLEFT", 2, 8)
    hint:SetText("Drag names into groups. Double-click a slot to type, right-click to clear.")

    local ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP"); ghost:SetSize(140, 20); ghost:Hide()
    K.Surface(ghost, "frame", 0.95, "accent", 0.8)
    ghost.t = K.T(ghost, 12, "white"); ghost.t:SetPoint("LEFT", 6, 0)
    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition(); local s = UIParent:GetEffectiveScale()
        self:ClearAllPoints(); self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 10, y / s - 10)
    end)
    local drag

    local function label(n)
        if not n or n == "" then return "" end
        local cls = classOf(n)
        if cls then return classHex(cls) .. "Any " .. className(cls) .. "|r" end
        local u = GS:Resolve(GS:Roster(), n)
        return u and (classHex(u.class) .. n .. "|r") or n
    end

    local function slotUnderMouse()
        for _, sl in ipairs(slots) do if sl:IsVisible() and sl:IsMouseOver() then return sl end end
    end

    local function place(sl, n)
        GS.draft.groups[sl.g][sl.s] = n or ""
        changed()
    end

    local function finishDrag()
        ghost:Hide()
        local d = drag; drag = nil
        if not d then return end
        local target = slotUnderMouse()
        if target then
            if d.slot then
                local gs = GS.draft.groups
                gs[d.slot.g][d.slot.s], gs[target.g][target.s] = gs[target.g][target.s], gs[d.slot.g][d.slot.s]
                changed()
            else
                place(target, d.name)
            end
        elseif d.slot and poolArea:IsMouseOver() then
            place(d.slot, "")
        end
    end

    local editor = K.Input(gridArea, nil)
    editor:SetHeight(20); editor:Hide()
    editor.box:SetScript("OnEnterPressed", function(self) if editor.slot then place(editor.slot, trim(self:GetText())) end; editor:Hide() end)
    editor.box:SetScript("OnEscapePressed", function() editor:Hide() end)
    editor.box:SetScript("OnEditFocusLost", function() editor:Hide() end)

    local boxes = {}
    for g = 1, 8 do
        local b = CreateFrame("Frame", nil, gridArea)
        K.Surface(b, "field", 1, "borderDim")
        b.title = K.T(b, 11, "accent"); b.title:SetPoint("TOPLEFT", 8, -6); b.title:SetText("Group " .. g)
        for s = 1, 5 do
            local sl = CreateFrame("Button", nil, b)
            sl.g, sl.s = g, s
            sl:SetHeight(20)
            sl:SetPoint("TOPLEFT", 4, -4 - s * 22); sl:SetPoint("RIGHT", -4, 0)
            sl.bg = sl:CreateTexture(nil, "BACKGROUND"); sl.bg:SetAllPoints(); sl.bg:SetTexture(K.WHITE)
            sl.t = K.T(sl, 12, "text"); sl.t:SetPoint("LEFT", 6, 0); sl.t:SetPoint("RIGHT", -4, 0)
            sl:RegisterForDrag("LeftButton")
            sl:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            sl:SetScript("OnDragStart", function(self)
                local n = GS.draft.groups[self.g][self.s]
                if n == "" then return end
                drag = { slot = self }; ghost.t:SetText(label(n)); ghost:Show()
            end)
            sl:SetScript("OnDragStop", finishDrag)
            sl:SetScript("OnClick", function(self, button)
                if button == "RightButton" then place(self, "") return end
                selected = (selected == self) and nil or self
                changed()
            end)
            sl:SetScript("OnDoubleClick", function(self)
                editor.slot = self
                editor:ClearAllPoints(); editor:SetAllPoints(self); editor:SetFrameLevel(self:GetFrameLevel() + 5)
                editor:Show(); editor.box:SetText(GS.draft.groups[self.g][self.s]); editor.box:SetFocus(); editor.box:HighlightText()
            end)
            sl:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
            sl:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
            function sl:Paint()
                local n = GS.draft.groups[self.g][self.s]
                self.t:SetText(n ~= "" and label(n) or "|cff5a5f68-|r")
                if selected == self then local r, gg, bl = K.C("accent"); self.bg:SetVertexColor(r, gg, bl, 0.30)
                else self.bg:SetVertexColor(1, 1, 1, self.hover and 0.07 or 0.025) end
            end
            slots[#slots + 1] = sl
        end
        boxes[g] = b
    end
    gridArea:SetScript("OnSizeChanged", function(_, w, h)
        local cw, ch = (w - 3 * 8) / 4, math.min(140, (h - 8) / 2)
        for g = 1, 8 do
            local b = boxes[g]
            b:ClearAllPoints(); b:SetSize(cw, ch)
            b:SetPoint("TOPLEFT", ((g - 1) % 4) * (cw + 8), -math.floor((g - 1) / 4) * (ch + 8))
        end
    end)

    local seg = K.Segmented(poolArea, { "Raid", "Roster", "Guild" }, function(i) source = ({ "raid", "roster", "guild" })[i]; changed() end)
    seg:SetPoint("TOPLEFT", 6, -6); seg:SetPoint("RIGHT", -6, 0); seg:SetValue(1)
    local chips = CreateFrame("Frame", nil, poolArea)
    chips:SetPoint("TOPLEFT", 6, -40); chips:SetPoint("RIGHT", -6, 0); chips:SetHeight(3 * 20)
    for i, c in ipairs(CLASSES) do
        local ch = CreateFrame("Button", nil, chips)
        ch:SetSize(70, 18)
        ch:SetPoint("TOPLEFT", ((i - 1) % 3) * 72, -math.floor((i - 1) / 3) * 20)
        ch.t = K.T(ch, 11, "text"); ch.t:SetPoint("LEFT", 2, 0); ch.t:SetText(classHex(c) .. className(c) .. "|r")
        ch:RegisterForDrag("LeftButton")
        ch:SetScript("OnDragStart", function() drag = { name = className(c) }; ghost.t:SetText(label(className(c))); ghost:Show() end)
        ch:SetScript("OnDragStop", finishDrag)
        ch:SetScript("OnClick", function()
            local target = selected
            if not target then for _, sl in ipairs(slots) do if GS.draft.groups[sl.g][sl.s] == "" then target = sl break end end end
            if target then place(target, className(c)) end
        end)
        K.Tip(ch, "Any " .. className(c), "Takes any " .. className(c):lower() .. " not placed by name.")
    end
    local listSc = CreateFrame("ScrollFrame", nil, poolArea)
    listSc:SetPoint("TOPLEFT", 6, -106); listSc:SetPoint("BOTTOMRIGHT", -6, 6)
    listSc:EnableMouseWheel(true)
    listSc:SetScript("OnMouseWheel", function(self, d) self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * 40))) end)
    local listBody = CreateFrame("Frame", nil, listSc); listBody:SetSize(200, 10); listSc:SetScrollChild(listBody)
    listSc:SetScript("OnSizeChanged", function(_, w) listBody:SetWidth(w) end)
    local empty = K.T(listBody, 12, "dim"); empty:SetPoint("TOPLEFT", 4, -4)

    local function poolNames()
        local out, seen = {}, {}
        for g = 1, 8 do for s = 1, 5 do local n = GS.draft.groups[g][s]; if n ~= "" then seen[norm(n)] = true end end end
        local function add(n, class)
            n = trim((strsplit("-", n or "")))
            if n == "" then return end
            local k = norm(n)
            if seen[k] then return end
            seen[k] = true
            out[#out + 1] = { name = n, class = class }
        end
        if source == "raid" then
            if IsInRaid() then for i = 1, GetNumGroupMembers() do local n, _, _, _, _, c = GetRaidRosterInfo(i); if n then add(knownFull(trim((strsplit("-", n)))), c) end end
            else for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do if UnitExists(u) then add(UnitName(u), select(2, UnitClass(u))) end end end
        elseif source == "roster" then
            for _, n in ipairs(GS:RosterNames()) do add(n) end
        else
            if GetNumGuildMembers then
                for i = 1, GetNumGuildMembers() do
                    local n, _, _, _, _, _, _, _, online, _, c = GetGuildRosterInfo(i)
                    if online then add(n, c) end
                end
            end
        end
        table.sort(out, function(a, b) return a.name < b.name end)
        return out
    end

    local function refreshPool()
        local names = poolNames()
        for i, p in ipairs(names) do
            local r = pool[i]
            if not r then
                r = CreateFrame("Button", nil, listBody)
                r:SetHeight(18)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * 19); r:SetPoint("RIGHT", 0, 0)
                r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture(K.WHITE); r.bg:SetVertexColor(1, 1, 1, 0)
                r.t = K.T(r, 12, "text"); r.t:SetPoint("LEFT", 4, 0); r.t:SetPoint("RIGHT", -4, 0)
                r:RegisterForDrag("LeftButton")
                r:SetScript("OnDragStart", function(self) drag = { name = self.name }; ghost.t:SetText(self.t:GetText()); ghost:Show() end)
                r:SetScript("OnDragStop", finishDrag)
                r:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.07) end)
                r:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0) end)
                r:SetScript("OnClick", function(self)
                    local target = selected
                    if not target then for _, sl in ipairs(slots) do if GS.draft.groups[sl.g][sl.s] == "" then target = sl break end end end
                    if target then selected = nil; place(target, self.name) end
                end)
                pool[i] = r
            end
            r.name = p.name
            r.t:SetText(p.class and (classHex(p.class) .. p.name .. "|r") or p.name)
            r:Show()
        end
        for i = #names + 1, #pool do pool[i]:Hide() end
        listBody:SetHeight(math.max(10, #names * 19))
        empty:SetShown(#names == 0)
        empty:SetText(source == "roster" and "No roster names left." or (source == "guild" and "Nobody online left." or "Nobody left to place."))
    end

    local function refresh()
        if not view:IsVisible() then return end
        local d = GS.draft
        if not nameIn.box:HasFocus() then nameIn.box:SetText(d.name or "") end
        loadDD:SetText(d.src and GS:Get(d.src) and (GS:Get(d.src).name or "Setup") or "Load setup...")
        for _, sl in ipairs(slots) do sl:Paint() end
        local inRaid = IsInRaid()
        apply:SetEnabled(inRaid and canMove()); apply:SetAlpha(apply:IsEnabled() and 1 or 0.45)
        fromRaid:SetEnabled(inRaid); fromRaid:SetAlpha(inRaid and 1 or 0.45)
        refreshPool()
    end
    GS:OnChange(refresh)
    view:RegisterEvent("GROUP_ROSTER_UPDATE")
    view:SetScript("OnEvent", refresh)
    view:HookScript("OnShow", function() if GetNumGuildMembers and C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end; refresh() end)
    view:HookScript("OnHide", function() ghost:Hide(); drag = nil; editor:Hide() end)
    return bar, save, clearB, { load = loadDD, name = nameIn, fromRaid = fromRaid, clear = clearB, apply = apply,
        setRight = function(list) rightBtns = list; layout() end }
end

local function buildRosterView(view, UI)
    local stack = K.CardStack(view, -44, UI)

    local imp = stack:Add(K.Card(view, "Import roster",
        "KEY-Name pairs, by comma or line: PROTWARR1-Midori One,HPALA1-Happyjoe. Raid roles and invites can use the keys. Replaces the current roster."))
    local name, eb, clearField = pasteField(imp, 140)
    local row = CreateFrame("Frame", nil, imp); row.fill = false; row:SetSize(400, 28)
    local go = K.Button(row, "Import roster", 140, 28, "primary"); go:SetPoint("LEFT", 0, 0)
    imp:Add(row, 28, 8)
    go:SetScript("OnClick", function()
        if GS:ImportRoster(eb:GetText(), name.box:GetText()) > 0 then clearField() end
    end)

    local card = stack:Add(K.Card(view, "Current roster"))
    local info = K.T(UIParent, 12, "text")
    local infoHolder = CreateFrame("Frame")
    info:SetParent(infoHolder); info:SetPoint("TOPLEFT"); info:SetPoint("RIGHT"); info:SetJustifyV("TOP"); info:SetWordWrap(true)
    card:Add(infoHolder, 18, 8)
    local copy = K.Button(UIParent, "Copy roster", 120, 26, nil, "icon-export")
    local clear = K.Button(UIParent, "Clear", 80, 26, "danger")
    local bRow = CreateFrame("Frame")
    copy:SetParent(bRow); copy:SetPoint("LEFT", 0, 0)
    clear:SetParent(bRow); clear:SetPoint("LEFT", copy, "RIGHT", 8, 0)
    card:Add(bRow, 26, 10)
    local list = CreateFrame("Frame")
    card:Add(list, 20, 4)
    local cols = { { "Key", 0 }, { "Name", 0.34 }, { "In raid", 0.78 } }
    local head, rows = {}, {}
    for i, c in ipairs(cols) do head[i] = K.T(list, 11, "dim"); head[i]:SetText(c[1]) end

    copy:SetScript("OnClick", function()
        local r = db().roster
        local parts = {}
        for _, k in ipairs(r.order or {}) do parts[#parts + 1] = k .. "-" .. (r.keys[k] or "") end
        K.CopyBox("Roster" .. (r.title and (": " .. r.title) or ""), table.concat(parts, ","), "Paste into another FojjiCore or back into the sheet.")
    end)
    local armed
    clear:SetScript("OnClick", function()
        if armed then
            armed = nil; clear.label:SetText("Clear"); GS:ClearRoster()
        else
            armed = true; clear.label:SetText("Sure?")
            C_Timer.After(3, function() armed = nil; clear.label:SetText("Clear") end)
        end
    end)

    local function place()
        local w = list:GetWidth() or 500
        for i, c in ipairs(cols) do
            head[i]:ClearAllPoints(); head[i]:SetPoint("TOPLEFT", w * c[2], 0)
            for _, r in ipairs(rows) do
                r[i]:ClearAllPoints(); r[i]:SetPoint("TOPLEFT", w * c[2], -r.y)
                r[i]:SetWidth(w * ((cols[i + 1] and cols[i + 1][2] or 1) - c[2]) - 6)
            end
        end
    end
    list:SetScript("OnSizeChanged", place)

    local function refresh()
        local r = db().roster
        local order = r.order or {}
        local n = #order
        if n > 0 then
            info:SetText(("|cffffffff%s|r  |cff8a8f98%d players%s|r"):format(r.title or "Roster", n,
                r.t and ("  -  imported " .. date("%d/%m %H:%M", r.t)) or ""))
        else
            info:SetText("|cff8a8f98No roster yet.|r")
        end
        copy:SetEnabled(n > 0); copy:SetAlpha(n > 0 and 1 or 0.45)
        clear:SetEnabled(n > 0); clear:SetAlpha(n > 0 and 1 or 0.45)
        local raid = GS:Roster()
        local inRaid = IsInRaid and IsInRaid()
        for i, key in ipairs(order) do
            local row = rows[i]
            if not row then
                row = { y = 20 + (i - 1) * 20 }
                row.bg = list:CreateTexture(nil, "BACKGROUND"); row.bg:SetTexture(K.WHITE)
                row.bg:SetPoint("TOPLEFT", -4, -row.y + 3); row.bg:SetPoint("RIGHT", 0, 0); row.bg:SetHeight(20)
                row.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.03 or 0)
                for c = 1, #cols do row[c] = K.T(list, 12, "text") end
                rows[i] = row
            end
            local nm = r.keys[key] or ""
            local u = GS:Resolve(raid, nm)
            row[1]:SetText("|cffffcc66" .. key .. "|r")
            row[2]:SetText(u and (classHex(u.class) .. nm .. "|r") or nm)
            row[3]:SetText(not inRaid and "|cff8a8f98-|r" or (u and (u.online and "|cff44ff88yes|r" or "|cffffaa33offline|r") or "|cffff5555no|r"))
            row.bg:Show(); for c = 1, #cols do row[c]:Show() end
        end
        for i = n + 1, #rows do rows[i].bg:Hide(); for c = 1, #cols do rows[i][c]:Hide() end end
        for _, h in ipairs(head) do h:SetShown(n > 0) end
        local h = n > 0 and (20 + n * 20) or 1
        list:SetHeight(h)
        for _, it in ipairs(card.items) do if it.w == list then it.h = h end end
        place()
        stack:Layout()
    end
    GS:OnChange(function() if view:IsVisible() then refresh() end end)
    view:RegisterEvent("GROUP_ROSTER_UPDATE")
    view:SetScript("OnEvent", function() if view:IsVisible() then refresh() end end)
    view:HookScript("OnShow", refresh)
end

function Addon.BuildGroupsView(view)
    kit()
    local bar, save, clearB, parts = buildBuilderView(view)
    local del = K.Button(bar, "", 28, 28, "danger", "icon-minus")
    del:SetPoint("RIGHT", save, "LEFT", -8, 0)
    K.Tip(del, "Delete setup", "Deletes the saved setup you loaded.")
    local exp = K.Button(bar, "Export", 80, 28, nil, "icon-export")
    exp:SetPoint("RIGHT", del, "LEFT", -8, 0)
    local imp = K.Button(bar, "Import", 80, 28)
    imp:SetPoint("RIGHT", exp, "LEFT", -8, 0)
    K.Tip(imp, "Import setups", "1-Fojji,Farsan,2-Midori,Shoop - the number starts a group. A class (1-Warrior) takes anyone of that class. #Title names a setup; one setup per line.")
    imp:SetScript("OnClick", function() GS:OpenPaste() end)
    parts.setRight({ imp, exp, del, save, parts.apply })
    exp:SetScript("OnClick", function()
        local s = draftToSetup(GS.draft)
        K.CopyBox("Export: " .. (GS.draft.name ~= "" and GS.draft.name or "setup"), GS:Export(s), "Paste into another FojjiCore or the sheet.")
    end)
    local armed
    del:SetScript("OnClick", function()
        local i = GS.draft.src
        if not (i and GS:Get(i)) then return end
        if not armed then
            armed = true
            K.Tip(del, "Click again to delete", GS:Get(i).name or "")
            C_Timer.After(3, function() armed = nil end)
            return
        end
        armed = nil
        GS:Delete(i)
        GS:LoadDraft(nil)
    end)
    local function sync()
        local has = GS.draft.src and GS:Get(GS.draft.src) ~= nil
        del:SetEnabled(has and true or false); del:SetAlpha(has and 1 or 0.4)
    end
    GS:OnChange(function() if view:IsVisible() then sync() end end)
    view:HookScript("OnShow", sync)
end

function Addon.BuildRosterView(view, UI)
    kit()
    buildRosterView(view, UI)
end

function Addon.CreateGroupSetupPage(page, UI)
    kit()
    local tabs = K.SubTabs(page, { { "setups", "Setups" }, { "builder", "Builder" } })
    local function openBuilder(i) GS:LoadDraft(i); tabs:Select("builder") end
    buildSetupsView(tabs.views.setups, UI, openBuilder)
    buildBuilderView(tabs.views.builder)
    page:HookScript("OnShow", function() K.repaint(); tabs:Select(tabs.current) end)
    page.SelectView = function(key) tabs:Select(key) end
    Addon.GroupSetupPage = page
    tabs:Select("setups")
end
