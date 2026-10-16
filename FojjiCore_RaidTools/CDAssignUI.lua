local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end
local CD = Addon.CDAssign
local AM = Addon.Assignments

local K
local function kit() K = K or Addon.UIKit; return K end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function spellLabel(e)
    local name, icon = e.name, e.icon
    if e.spell then
        if not name then
            name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(e.spell)) or (GetSpellInfo and GetSpellInfo(e.spell)) or ("#" .. e.spell)
        end
        if not icon then icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.spell)) or (GetSpellTexture and GetSpellTexture(e.spell)) end
    end
    icon = tonumber(icon) or icon
    return (icon and ("|T" .. icon .. ":14:14:0:0:64:64:5:59:5:59|t ") or "") .. (name or "")
end

local function classColorOf(token)
    local GS = Addon.GroupSetups
    local cls = GS and GS.ClassOf and GS.ClassOf(token)
    if not cls and GS and GS.Roster and IsInRaid() then
        local u = GS:Resolve(GS:Roster(), token)
        cls = u and u.class
    end
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) end
    return "|cffd8dbe0"
end

local function Table(card, columns)
    local t = CreateFrame("Frame")
    t.cols, t.rows, t.head = columns, {}, {}
    for i, c in ipairs(columns) do t.head[i] = K.T(t, 11, "dim"); t.head[i]:SetText(c.title) end
    function t:Layout()
        local w = self:GetWidth() or 500
        local x = 0
        for i, c in ipairs(self.cols) do c.x, c.cw = x, c.w * w; x = x + c.cw end
        for i, fs in ipairs(self.head) do fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", self.cols[i].x, 0); fs:SetWidth(self.cols[i].cw - 6) end
        for r, row in ipairs(self.rows) do
            for i, fs in ipairs(row) do
                fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", self.cols[i].x, -20 - (r - 1) * 20)
                fs:SetWidth(row.span and i == 1 and (w - 6) or (self.cols[i].cw - 6))
            end
            row.bg:ClearAllPoints(); row.bg:SetPoint("TOPLEFT", -4, -17 - (r - 1) * 20); row.bg:SetPoint("RIGHT"); row.bg:SetHeight(20)
        end
    end
    function t:Set(data)
        for r, values in ipairs(data) do
            local row = self.rows[r]
            if not row then
                row = { bg = self:CreateTexture(nil, "BACKGROUND") }
                row.bg:SetTexture(K.WHITE)
                for i in ipairs(self.cols) do row[i] = K.T(self, 12, "text"); row[i]:SetWordWrap(false) end
                self.rows[r] = row
            end
            row.span = #values == 1
            row.bg:SetVertexColor(1, 1, 1, values.header and 0.07 or (r % 2 == 0 and 0.03 or 0)); row.bg:Show()
            for i = 1, #self.cols do row[i]:SetText(values[i] or ""); row[i]:Show() end
        end
        for r = #data + 1, #self.rows do self.rows[r].bg:Hide(); for i = 1, #self.cols do self.rows[r][i]:Hide() end end
        self.h = 22 + #data * 20
        self:SetHeight(self.h)
        for _, it in ipairs(card.items) do if it.w == self then it.h = self.h end end
        self:Layout()
    end
    t:SetScript("OnSizeChanged", function(self) self:Layout() end)
    return t
end

local function pasteField(card, height)
    local name = K.Input(card); card:Add(name, 28, 8)
    name.box:SetMaxLetters(80)
    local hint = K.T(name, 12, "dim"); hint:SetPoint("LEFT", 9, 0); hint:SetText("Title, e.g. Hyjal (optional)")
    name.box:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    local field = CreateFrame("Frame", nil, card)
    K.Surface(field, "field", 1, "border", 1)
    card:Add(field, height or 110, 10)
    local sc = CreateFrame("ScrollFrame", nil, field)
    sc:SetPoint("TOPLEFT", 8, -6); sc:SetPoint("BOTTOMRIGHT", -8, 6)
    local eb = CreateFrame("EditBox", nil, sc)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(0)
    eb:SetFont(K.FONT, 12, ""); eb:SetTextColor(0.95, 0.96, 0.98); eb:SetWidth(500)
    sc:SetScrollChild(eb)
    sc:SetScript("OnSizeChanged", function(_, w) eb:SetWidth(math.max(100, w)) end)
    field:EnableMouse(true); field:SetScript("OnMouseDown", function() eb:SetFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return name, eb, function() eb:SetText(""); name.box:SetText(""); eb:ClearFocus() end
end

local FORMAT_TIP = "One per line (or * between them), fields split by /\n\n" ..
    "|cffffcc66KEY/counts/players/time/spellID/text/tts/name/icon|r\n" ..
    "  KEY: the pack's ability key, or BOSS_ENC_START (time = after the pull)\n" ..
    "  counts: 1,4 = which casts, -1 = every cast\n" ..
    "  time: seconds from the cast (negative = before)\n" ..
    "|cffffcc66BOSS_HEALTH/percent/players/time/spellID/npc/...|r\n" ..
    "|cffffcc66INTERRUPT/target/counts/players/spellID/text|r\n" ..
    "|cffffcc66NOTE/key/players/text|r\n\n" ..
    "players: roster keys, names, classes, TANKS, HEALERS, MELEEDPS, RANGEDDPS or ALL"

local function buildCooldowns(view, UI)
    local d = CD.DB()
    local stack = K.CardStack(view, -44, UI)

    local imp = stack:Add(K.Card(view, "Import Cooldowns"))
    local name, eb, clearField = pasteField(imp, 110)
    local row = CreateFrame("Frame", nil, imp); row.fill = false; row:SetSize(420, 28)
    local go = K.Button(row, "Import", 110, 28, "primary"); go:SetPoint("LEFT", 0, 0)
    local fmt = K.Button(row, "Format", 90, 28, nil, "icon-info"); fmt:SetPoint("LEFT", go, "RIGHT", 8, 0)
    K.Tip(fmt, "Import format", FORMAT_TIP)
    imp:Add(row, 28, 8)
    go:SetScript("OnClick", function() if CD:Import(eb:GetText(), name.box:GetText()) then clearField() end end)

    local plans = stack:Add(K.Card(view, "Imported cooldowns"))
    local status = K.T(UIParent, 12, "text")
    local sh = CreateFrame("Frame"); status:SetParent(sh); status:SetPoint("TOPLEFT"); status:SetPoint("RIGHT")
    plans:Add(sh, 16, 8)
    local send = K.Button(UIParent, "Send to raid", 130, 28, "primary", "icon-raid")
    local test = K.Button(UIParent, "Test warning", 120, 28, nil, "icon-play")
    K.Tip(test, "Test warning", "Shows your first assignment in the Fojji Raid Assignments aura.")
    local brow = CreateFrame("Frame")
    send:SetParent(brow); send:SetPoint("LEFT", 0, 0)
    test:SetParent(brow); test:SetPoint("LEFT", send, "RIGHT", 8, 0)
    plans:Add(brow, 28, 10)
    send:SetScript("OnClick", function() CD:Send() end)
    test:SetScript("OnClick", function() CD:Test() end)
    local holder = CreateFrame("Frame"); plans:Add(holder, 10, 6)
    local lines = {}

    local set = stack:Add(K.Card(view, "Settings"))
    local auto = K.SwitchRow(UIParent, "Send on ready check and pull timer (leader)", function(v) d.autoSend = v end)
    set:Add(auto, 24, 6)

    local prev = K.Card(view, "Assignments"); prev.wide = true; stack:Add(prev)
    local filter = "mine"
    local query = ""
    local seg = K.Segmented(UIParent, { "Mine", "Everyone" }, function(i) filter = i == 1 and "mine" or "all"; view.refresh() end)
    seg:SetWidth(180); seg.fill = false; seg:SetValue(1)
    local search = K.Search(UIParent, 200, function(text) query = (text or ""):lower(); view.refresh() end)
    local frow = CreateFrame("Frame")
    seg:SetParent(frow); seg:SetPoint("LEFT", 0, 0); seg:SetHeight(28)
    search:SetParent(frow); search:SetPoint("LEFT", seg, "RIGHT", 10, 0)
    prev:Add(frow, 28, 10)
    local tbl = Table(prev, { { title = "Key", w = 0.28 }, { title = "#", w = 0.07 }, { title = "Time", w = 0.08 }, { title = "Player", w = 0.20 }, { title = "Spell", w = 0.20 }, { title = "Text", w = 0.17 } })
    prev:Add(tbl, 22, 4)

    local function timeText(e)
        if e.kind == "health" then return e.pct .. "% hp" end
        if e.kind == "power" then return e.pct .. "% pw" end
        if e.kind == "interrupt" or e.kind == "note" then return "" end
        local t = e.time or 0
        return (t > 0 and "+" or "") .. t .. "s"
    end

    view.refresh = function()
        local plan = CD:GetPlan()
        if plan then
            status:SetText(("Active: |cffffffff%s|r  |cff8a8f98%d entries%s|r"):format(plan.title or "?", #plan.list,
                plan.own and "  -  yours" or ("  -  from " .. (plan.by or "?") .. date("  %d/%m %H:%M", plan.t or time()))))
        else
            status:SetText("|cff8a8f98Nothing imported yet.|r")
        end
        local can = plan and plan.own and IsInGroup()
        send:SetEnabled(can and true or false); send:SetAlpha(can and 1 or 0.45)
        local list = d.plans
        for i, p in ipairs(list) do
            local l = lines[i]
            if not l then
                l = CreateFrame("Frame", nil, holder); l:SetHeight(30)
                l:SetPoint("TOPLEFT", 0, -(i - 1) * 34); l:SetPoint("RIGHT", 0, 0)
                K.Surface(l, "field", 0.7, "borderDim")
                l.label = K.T(l, 13, "text"); l.label:SetPoint("LEFT", 10, 0); l.label:SetPoint("RIGHT", -170, 0)
                l.del = K.Button(l, "", 26, 22, "danger", "icon-minus"); l.del:SetPoint("RIGHT", -4, 0)
                l.exp = K.Button(l, "Export", 64, 22); l.exp:SetPoint("RIGHT", l.del, "LEFT", -6, 0)
                l.use = K.Button(l, "Use", 64, 22, "primary"); l.use:SetPoint("RIGHT", l.exp, "LEFT", -6, 0)
                l.use:SetScript("OnClick", function() CD:Use(l.i) end)
                l.exp:SetScript("OnClick", function() local p2 = d.plans[l.i]; if p2 then K.CopyBox("Assignments: " .. p2.title, p2.text, "The text you imported.", true) end end)
                l.del:SetScript("OnClick", function()
                    if l.armed then l.armed = nil; l.del.label:SetText(""); CD:DeletePlan(l.i) else
                        l.armed = true; l.del.label:SetText("?")
                        C_Timer.After(3, function() l.armed = nil; l.del.label:SetText("") end)
                    end
                end)
                lines[i] = l
            end
            l.i = i
            local active = plan and plan.own and d.selected == i
            l.label:SetText(p.title .. "  |cff8a8f98" .. date("%d/%m %H:%M", p.t or time()) .. (active and "  |r|cff44ff88active" or "") .. "|r")
            l.use:SetShown(not active)
            l:Show()
        end
        for i = #list + 1, #lines do lines[i]:Hide() end
        local h = #list > 0 and #list * 34 or 1
        holder:SetHeight(h)
        for _, it in ipairs(plans.items) do if it.w == holder then it.h = h end end
        auto:SetValue(d.autoSend)
        local rows = {}
        if plan then
            local byKey, order = {}, {}
            for _, e in ipairs(plan.list) do
                local mineIdx
                for i, p in ipairs(e.who) do if CD:IsMe(p, e.keys and e.keys[i]) then mineIdx = i end end
                if filter == "all" or mineIdx then
                    local hay = (e.k .. " " .. table.concat(e.who, " ") .. " " .. (e.text or "") .. " " .. (e.name or "")):lower()
                    if query == "" or hay:find(query, 1, true) then
                        if not byKey[e.k] then byKey[e.k] = {}; order[#order + 1] = e.k end
                        table.insert(byKey[e.k], e)
                    end
                end
            end
            for _, k in ipairs(order) do
                for _, e in ipairs(byKey[k]) do
                    local who = {}
                    for i, p in ipairs(e.who) do
                        local label = (e.keys and e.keys[i]) and (p .. " |cff8a8f98" .. e.keys[i] .. "|r") or p
                        who[#who + 1] = classColorOf(p) .. label .. "|r"
                    end
                    local cnt = (e.kind == "time" or e.kind == "interrupt") and table.concat(e.counts or {}, ",") or ""
                    local kind = e.kind == "interrupt" and " |cffff8866interrupt|r" or (e.kind == "note" and " |cff88aaffnote|r" or "")
                    rows[#rows + 1] = { "|cffffcc66" .. e.k .. "|r" .. kind, cnt:gsub("%-1", "all"), timeText(e), table.concat(who, ", "), spellLabel(e), e.text or e.tts or "" }
                end
            end
        end
        if #rows == 0 then rows[1] = { plan and "|cff8a8f98Nothing for you in this plan.|r" or "|cff8a8f98-|r" } end
        tbl:Set(rows)
        stack:Layout()
    end
    CD:OnChange(function() if view:IsVisible() then view.refresh() end end)
    view:HookScript("OnShow", function() view.refresh() end)
end

function Addon.CreateAssignmentsPage(page, UI)
    kit()
    local list = {}
    if Addon.BuildRaidDataView then list[#list + 1] = { "raiddata", "Assignments" } end
    list[#list + 1] = { "cooldowns", "Cooldowns" }
    if AM and AM.BuildPositionsView then list[#list + 1] = { "positions", "Maps" } end
    if Addon.BuildRosterView then list[#list + 1] = { "roster", "Roster" } end
    local tabs = K.SubTabs(page, list)
    if Addon.BuildRaidDataView then Addon.BuildRaidDataView(tabs.views.raiddata, UI) end
    buildCooldowns(tabs.views.cooldowns, UI)
    if AM and AM.BuildPositionsView then AM.BuildPositionsView(tabs.views.positions, UI) end
    if Addon.BuildRosterView then Addon.BuildRosterView(tabs.views.roster, UI) end
    page:HookScript("OnShow", function() K.repaint(); tabs:Select(tabs.current) end)
    page.SelectView = function(key) if tabs.views[key] then tabs:Select(key) end end
    Addon.AssignmentsPage = page
    tabs:Select(list[1][1])
end
