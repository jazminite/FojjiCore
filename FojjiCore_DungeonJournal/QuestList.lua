local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Book = FDJ.QuestBook
local Quests = FDJ.Quests
local Party = FDJ.Party
local Pins = FDJ.Pins

local QuestList = {}
QuestList.__index = QuestList
FDJ.QuestList = QuestList

local ORDER = { ready = 1, active = 2, open = 3, chain = 3, low = 4, done = 5, faction = 6, unknown = 7 }
local CHIP = { done = C.good, ready = C.warn, active = { 0.45, 0.78, 1 }, missing = C.bad, unknown = C.dim }

local function levelColor(q)
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(q.lv)
        if c then return { c.r, c.g, c.b } end
    end
    return C.text
end

function QuestList.New(parent, compact)
    local self = setmetatable({}, QuestList)
    self.compact = compact
    self.open = {}
    local frame = CreateFrame("Frame", nil, parent)
    self.frame = frame

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(28)
    self.bar = bar

    local function plan()
        if self.dungeon then Pins.PlanPickup(self.dungeon) end
    end
    local sync = Kit.IconButton(bar, "fc:icon-reset", 26, L.SYNC_TIP, function() Party.Request() end)
    sync:SetPoint("RIGHT", 0, 0)
    sync:SetShown(compact and true or false)
    local pick
    if compact then
        pick = Kit.IconButton(bar, "ui-route", 26, L.PLAN_TIP, plan)
    else
        pick = Kit.Button(bar, L.PLAN_BUTTON, nil, 24, plan, "primary", "ui-route")
        pick.tip = L.PLAN_TIP
    end
    if compact then pick:SetPoint("RIGHT", sync, "LEFT", -8, 0) else pick:SetPoint("RIGHT", 0, 0) end
    self.sync, self.pick = sync, pick

    local done = Kit.Check(bar, L.HIDE_DONE, function() return FDJ:Option("hideDone") end,
        function(v) FDJ:SetOption("hideDone", v) self:Refresh() end)
    done:SetPoint("LEFT", 0, 0)
    self.checks = { done }

    local scroll = Kit.Scroller(frame)
    scroll:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    self.scroll = scroll
    Kit.Line(bar, "BOTTOM", C.borderDim, 0.8)

    self.empty = Kit.Text(scroll, "normal", C.muted, "CENTER")
    self.empty:SetPoint("TOP", 0, -40)
    self.empty:SetText(L.NO_QUESTS)

    self.rows = Kit.Pool(function() return self:MakeRow() end)

    local function refresh()
        if frame:IsVisible() then self:Refresh() end
    end
    for _, event in ipairs({ "FDJ_QUESTS", "FDJ_PARTY", "FDJ_PINS", "FDJ_SPOTS", "FDJ_OPTION" }) do FDJ:On(event, refresh) end
    FDJ:On("GET_ITEM_INFO_RECEIVED", function()
        if frame:IsVisible() then FDJ.Debounce("questlist-items", 0.4, refresh) end
    end)
    frame:SetScript("OnShow", function() self:Refresh() end)
    return self
end

function QuestList:SetDungeon(d)
    if self.dungeon ~= d then
        self.dungeon = d
        self.open = {}
        self.scroll:To(0)
    end
    self:Refresh()
end

local function tileList(parent)
    local list = CreateFrame("Frame", nil, parent)
    list.title = Kit.Section(list, "")
    list.title:SetPoint("TOPLEFT", 0, 0)
    list.tiles = {}
    function list:Set(label, items)
        if not items or #items == 0 then
            self:Hide()
            return 0
        end
        self.title:SetText(label:upper())
        for i, itemID in ipairs(items) do
            local b = self.tiles[i]
            if not b then
                b = Kit.ItemIcon(self, 30)
                self.tiles[i] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", (i - 1) * 34, -16)
            b:SetItem(itemID)
            b:Show()
        end
        for i = #items + 1, #self.tiles do self.tiles[i]:Hide() end
        self:SetSize(math.max(60, #items * 34), 48)
        self:Show()
        return 48
    end
    return list
end

local function fact(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(32)
    f.label = Kit.Section(f, "")
    f.label:SetPoint("TOPLEFT", 0, 0)
    f.value = Kit.Text(f, "small", C.text)
    f.value:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -4)
    f.value:SetPoint("RIGHT", -4, 0)
    return f
end

local function objective(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(20)
    f.text = Kit.Text(f, "small", C.text)
    f.text:SetPoint("TOPLEFT", 0, 0)
    f.count = Kit.Text(f, "small", C.muted, "RIGHT")
    f.count:SetPoint("TOPRIGHT", 0, 0)
    f.text:SetPoint("RIGHT", f.count, "LEFT", -8, 0)
    f.track = f:CreateTexture(nil, "ARTWORK")
    f.track:SetPoint("BOTTOMLEFT", 0, 0)
    f.track:SetPoint("BOTTOMRIGHT", 0, 0)
    f.track:SetHeight(3)
    f.track:SetColorTexture(1, 1, 1, 0.08)
    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetPoint("BOTTOMLEFT", 0, 0)
    f.fill:SetHeight(3)
    return f
end

function QuestList:MakeRow()
    local content = self.scroll.content
    local row = CreateFrame("Frame", nil, content)
    local head = Kit.Row(row, self.compact and 50 or 64)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    row.head = head

    row.accent = head:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", 0, -8)
    row.accent:SetPoint("BOTTOMLEFT", 0, 8)
    row.accent:SetWidth(2)

    row.icon = head:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("TOPLEFT", 12, -9)

    row.pin = CreateFrame("Button", nil, head)
    row.pin:SetSize(28, 22)
    row.pin:SetPoint("BOTTOMRIGHT", -6, self.compact and 4 or 5)
    row.pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.pin.on = Kit.Fill(row.pin, C.amber, 0, "BACKGROUND", 1)
    row.pin.edge = Kit.Edge(row.pin, C.amber, 0)
    row.pin.hl = Kit.Fill(row.pin, C.buttonHover, 0, "BACKGROUND", 2)
    row.pin.icon = Kit.PinIcon(row.pin, 22)
    row.pin.icon:SetPoint("CENTER")
    row.pin:SetScript("OnEnter", function(self)
        self.hl:SetColorTexture(RGB(C.buttonHover, 1))
        local pinned = Pins.Has(row.qid)
        Kit.Tip(self, pinned and L.PINNED or L.PIN, pinned and L.PINNED_TIP or (Quests.Spot(row.qid) and L.PIN_TIP or L.PIN_PLACE_TIP))
    end)
    row.pin:SetScript("OnLeave", function(self)
        self.hl:SetColorTexture(RGB(C.buttonHover, 0))
        Kit.HideTip()
    end)
    row.pin:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            Pins.BeginPlacing(row.qid)
        else
            Pins.Toggle(row.qid)
        end
    end)

    row.sharePin = Kit.IconButton(head, "fc:icon-gossip", 22, L.SHARE_PIN, function()
        Pins.Share(row.qid, IsShiftKeyDown())
    end)
    row.sharePin.tipBody = L.SHARE_PIN_TIP
    row.sharePin:SetPoint("RIGHT", row.pin, "LEFT", -1, 0)
    row.sharePin:Hide()

    row.share = Kit.Button(head, L.SHARE, nil, 20, function() Quests.Share(row.qid) end)
    row.share.tip = L.SHARE
    row.share.tipBody = L.SHARE_TIP
    row.share:Hide()

    row.party = CreateFrame("Button", nil, head)
    row.party:SetSize(42, 22)
    row.party:SetPoint("RIGHT", row.pin, "LEFT", -2, 0)
    row.party.hl = Kit.Fill(row.party, C.buttonHover, 0, "BACKGROUND", 2)
    row.party.icon = Kit.Glyph(row.party, "ui-party", 17, C.info)
    row.party.icon:SetPoint("LEFT", 5, 0)
    row.party.count = Kit.Text(row.party, "normal", C.dim)
    row.party.count:SetPoint("LEFT", row.party.icon, "RIGHT", 5, 0)
    row.party:SetScript("OnEnter", function(self)
        self.hl:SetColorTexture(RGB(C.buttonHover, 1))
        local lines = {}
        for _, member in ipairs(Party.Roster()) do
            local code = Party.MemberStatus(member, row.qid)
            lines[#lines + 1] = { FDJ.Paint(Party.ClassColor(member.class), member.name), L["PARTY_" .. code:upper()], CHIP[code] or C.dim }
        end
        if #lines < 2 then lines = { L.PARTY_SOLO } else lines[#lines + 1] = " "; lines[#lines + 1] = L.PARTY_ASK_HINT end
        Kit.Tip(self, L.PARTY_HAS, lines)
    end)
    row.party:SetScript("OnLeave", function(self)
        self.hl:SetColorTexture(RGB(C.buttonHover, 0))
        Kit.HideTip()
    end)
    row.party:SetScript("OnClick", function() Party.Ask(row.qid) end)

    row.title = Kit.Text(head, self.compact and "small" or "normal", C.white)
    row.title:SetPoint("TOPLEFT", 36, -8)
    row.title:SetPoint("RIGHT", head, "RIGHT", -10, 0)
    row.sub = Kit.Text(head, self.compact and "tiny" or "small", C.muted)
    if self.compact then
        row.sub:SetPoint("LEFT", head, "BOTTOMLEFT", 36, 15)
    else
        row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
    end
    row.sub:SetPoint("RIGHT", head, "RIGHT", -10, 0)
    row.xp = Kit.Text(head, "small", C.xp, "RIGHT")
    row.xp:SetPoint("RIGHT", row.party, "LEFT", -6, 0)

    head:SetScript("OnEnter", function()
        head:Hover(true)
        self:RowTip(row)
    end)
    head:SetScript("OnLeave", function()
        head:Hover(false)
        Kit.HideTip()
    end)
    head:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            self:RowMenu(row)
            return
        end
        if IsModifiedClick("CHATLINK") and FDJ.InsertLink(Quests.Link(row.qid)) then return end
        self.open[row.qid] = not self.open[row.qid] or nil
        self:Refresh()
    end)

    local body = CreateFrame("Frame", nil, row)
    body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)
    body.bg = Kit.Fill(body, C.field, 0.55)
    Kit.Line(body, "BOTTOM", C.borderDim, 0.6)
    row.body = body
    row.facts = { fact(body), fact(body), fact(body), fact(body) }
    row.objectives = {}
    row.needs = tileList(body)
    row.gives = tileList(body)
    row.pinFlag = CreateFrame("Frame", nil, body)
    row.pinFlag:SetHeight(24)
    row.pinFlag.bg = Kit.Fill(row.pinFlag, C.amber, 0.12)
    row.pinFlag.edge = row.pinFlag:CreateTexture(nil, "ARTWORK")
    row.pinFlag.edge:SetPoint("TOPLEFT")
    row.pinFlag.edge:SetPoint("BOTTOMLEFT")
    row.pinFlag.edge:SetWidth(2)
    row.pinFlag.edge:SetColorTexture(RGB(C.amber))
    row.pinFlag.icon = Kit.PinIcon(row.pinFlag, 15)
    row.pinFlag.icon:SetPoint("LEFT", 8, 0)
    row.pinFlag.text = Kit.Text(row.pinFlag, "small", C.amber)
    row.pinFlag.text:SetPoint("LEFT", row.pinFlag.icon, "RIGHT", 6, 0)
    row.pinFlag.text:SetPoint("RIGHT", -8, 0)

    return row
end

function QuestList:RowTip(row)
    local qid = row.qid
    local q = Book[qid]
    local lines = {}
    local step = Quests.Step(qid)
    if step then
        lines[#lines + 1] = { L.CHAIN_NEXT:format(step.index, step.count), Quests.StepTitle(step) }
        lines[#lines + 1] = { L.GIVER, Quests.StepWhere(step) }
        lines[#lines + 1] = { L.CHAIN_ENDS, (q.by or "?") .. (q.at and ("  ·  " .. q.at) or "") }
    else
        if q.by then lines[#lines + 1] = { L.GIVER, q.by } end
        if q.at then lines[#lines + 1] = { L.ZONE, q.at } end
    end
    lines[#lines + 1] = { L.LEVEL, ("%d  (%s %d)"):format(q.lv, L.REQ, q.req) }
    Kit.Tip(row.head, Quests.Title(qid), lines)
end

function QuestList:RowMenu(row)
    local qid = row.qid
    local inLog = Quests.InLog(qid)
    Kit.Menu(row.head, {
        { text = Quests.Title(qid), title = true },
        { text = Pins.Has(qid) and L.UNPIN or L.PIN_ON_MAP, onClick = function() Pins.Toggle(qid) end },
        { text = L.PLACE, onClick = function() Pins.BeginPlacing(qid) end },
        { text = L.SHARE_PIN, disabled = not Pins.Has(qid), onClick = function() Pins.Share(qid) end },
        { text = L.SHARE, disabled = not inLog, onClick = function() Quests.Share(qid) end },
        { text = L.LINK, onClick = function() Party.Ask(qid) end },
        { text = L.FORGET_SPOT, disabled = FDJ.db.spots[qid] == nil, onClick = function()
            FDJ.db.spots[qid] = nil
            FDJ:Emit("FDJ_SPOTS")
        end },
    })
end

function QuestList:Details(row, q)
    local qid = row.qid
    local width = math.max(180, self.scroll.content:GetWidth() - 52)
    local pinned = Pins.Has(qid)
    local y = 12

    if pinned then
        local spot = Pins.active
        row.pinFlag.text:SetText(L.PIN_ACTIVE:format(("%s  %.1f, %.1f"):format(FDJ.MapName(spot.m), spot.x * 100, spot.y * 100)))
        row.pinFlag:ClearAllPoints()
        row.pinFlag:SetPoint("TOPLEFT", 36, -y)
        row.pinFlag:SetWidth(width)
        row.pinFlag:Show()
        y = y + 32
    else
        row.pinFlag:Hide()
    end

    local xp = Quests.XP(qid)
    local level = q.lv .. FDJ.Paint("muted", "   " .. L.REQ .. " " .. q.req) .. (q.side and FDJ.Paint("muted", "   ·   " .. q.side) or "")
    local spot, how = Quests.Spot(qid)
    local where = spot and ("%s  %.1f, %.1f"):format(FDJ.MapName(spot.m), spot.x * 100, spot.y * 100) or FDJ.Paint("dim", L.LOC_NONE)
    local cells = {
        { L.LEVEL, level },
        { L.XP_LABEL, xp and FDJ.Paint(C.xp, (BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp) .. " XP") or FDJ.Paint("dim", L.XP_UNKNOWN) },
        (function()
            local step = Quests.Step(qid)
            if step then return { L.CHAIN_NEXT:format(step.index, step.count), Quests.StepTitle(step) .. FDJ.Paint("muted", "  ·  " .. Quests.StepWhere(step)) } end
            return { L.GIVER, (q.by or "?") .. (q.at and FDJ.Paint("muted", "  ·  " .. q.at) or "") }
        end)(),
        { spot and (L["LOC_" .. (how or "met"):upper()] or L.LOC_KNOWN):gsub(":$", "") or L.LOC_KNOWN:gsub(":$", ""), where },
    }
    local cols = width >= 300 and 2 or 1
    local colW = (width - (cols - 1) * 14) / cols
    for i, cell in ipairs(cells) do
        local f = row.facts[i]
        f.label:SetText(cell[1]:upper())
        f.value:SetText(cell[2])
        local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 36 + col * (colW + 14), -(y + line * 38))
        f:SetWidth(colW)
        f:Show()
    end
    y = y + math.ceil(#cells / cols) * 38 + 2

    for _, o in ipairs(row.objectives) do o:Hide() end
    local objectives = Quests.Objectives(qid)
    if objectives then
        local n = 0
        for _, o in ipairs(objectives) do
            if o.text and o.text ~= "" then
                n = n + 1
                local f = row.objectives[n]
                if not f then
                    f = objective(row.body)
                    row.objectives[n] = f
                end
                local have, need = tonumber(o.numFulfilled), tonumber(o.numRequired)
                if not need then
                    local a, b = o.text:match("(%d+)%s*/%s*(%d+)")
                    have, need = tonumber(a), tonumber(b)
                end
                local label = o.text:gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub(":%s*%d+%s*/%s*%d+%s*$", "")
                f.text:SetText(label)
                f.text:SetTone(o.finished and C.good or C.text)
                f.count:SetText(need and need > 0 and (have or 0) .. " / " .. need or (o.finished and L.DONE or ""))
                f.count:SetTone(o.finished and C.good or C.muted)
                local ratio = need and need > 0 and math.min(1, (have or 0) / need) or (o.finished and 1 or 0)
                f.fill:SetWidth(math.max(1, width * ratio))
                f.fill:SetColorTexture(RGB(o.finished and C.good or C.info))
                f.fill:SetShown(ratio > 0)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", 36, -y)
                f:SetWidth(width)
                f:Show()
                y = y + 26
            end
        end
        y = y + 4
    end

    local nh = row.needs:Set(L.COLLECT, q.need)
    local gh = row.gives:Set(L.REWARDS, q.gives)
    row.needs:ClearAllPoints()
    row.gives:ClearAllPoints()
    if nh > 0 then row.needs:SetPoint("TOPLEFT", 36, -y) end
    if gh > 0 then
        if nh > 0 and cols == 2 then
            row.gives:SetPoint("TOPLEFT", 36 + colW + 14, -y)
        else
            row.gives:SetPoint("TOPLEFT", 36, -(y + nh))
        end
    end
    if cols == 2 then y = y + math.max(nh, gh) else y = y + nh + gh end
    y = y + 6

    y = y + 4
    row.body:SetHeight(y)
    return y
end

function QuestList:Refresh()
    self.rows:Reset()
    for _, check in ipairs(self.checks) do check:Sync() end
    local d = self.dungeon
    if not d then
        self.scroll:SetContentHeight(1)
        return
    end
    local list = Quests.ForDungeon(d)
    local status = {}
    for _, qid in ipairs(list) do status[qid] = Quests.Status(qid) end
    table.sort(list, function(a, b)
        local oa, ob = ORDER[status[a]] or 9, ORDER[status[b]] or 9
        if oa ~= ob then return oa < ob end
        if Book[a].lv ~= Book[b].lv then return Book[a].lv < Book[b].lv end
        return a < b
    end)
    self.empty:SetShown(#list == 0)

    local roster = Party.Roster()
    local grouped = #roster > 1
    if self.compact then
        self.sync:SetShown(grouped)
        self.pick:ClearAllPoints()
        if grouped then self.pick:SetPoint("RIGHT", self.sync, "LEFT", -8, 0) else self.pick:SetPoint("RIGHT", self.bar, "RIGHT", 0, 0) end
    end
    local active = Pins.ActiveQuest()
    local y = 0
    for _, qid in ipairs(list) do
        local q, code = Book[qid], status[qid]
        local row = self.rows:Get()
        row.qid = qid
        row:SetPoint("TOPLEFT", self.scroll.content, "TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", self.scroll.content, "RIGHT", 0, 0)
        local style = Quests.Style[code] or Quests.Style.unknown
        row.icon:SetTexture(style.icon)
        row.icon:SetDesaturated(style.grey or false)
        row.accent:SetColorTexture(RGB(FDJ.Colors[style.color] or C.dim, (code == "ready" or code == "active") and 1 or 0))
        local faded = code == "done" or code == "faction" or code == "low"
        row.title:SetText(FDJ.Paint(faded and C.dim or levelColor(q), q.lv) .. "  " .. FDJ.Paint(faded and "muted" or "white", Quests.Title(qid)))
        local sub = FDJ.Paint(style.color, Quests.StatusText(code, qid))
        local xp = code ~= "done" and Quests.XP(qid)
        row.xp:SetText(xp and ((BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp) .. " XP") or "")
        local step = code == "chain" and Quests.Step(qid)
        if step then
            sub = sub .. FDJ.Paint("dim", "   ·   " .. (step.inLog and Quests.StepWhere(step) or ((step.by or Quests.StepTitle(step)) .. ((step.at and not self.compact) and ("  ·  " .. step.at) or ""))))
        elseif q.by then sub = sub .. FDJ.Paint("dim", "   ·   " .. q.by .. ((q.at and not self.compact) and ("  ·  " .. q.at) or "")) end
        row.sub:SetText(sub)
        local pinned = qid == active
        local known = Quests.Spot(qid) ~= nil
        row.pin.icon:SetDesaturated(not pinned)
        row.pin.icon:SetAlpha(pinned and 1 or (known and 0.55 or 0.3))
        row.pin.on:SetColorTexture(RGB(C.amber, pinned and 0.2 or 0))
        Kit.EdgeColor(row.pin, C.amber, pinned and 0.9 or 0)
        row.sharePin:SetShown(pinned)
        local last = pinned and row.sharePin or row.pin
        row.party:ClearAllPoints()
        row.party:SetPoint("RIGHT", last, "LEFT", -2, 0)
        local holders = 0
        for _, member in ipairs(roster) do
            local mc = Party.MemberStatus(member, qid)
            if mc == "active" or mc == "ready" then holders = holders + 1 end
        end
        row.party.count:SetText(holders)
        row.party.icon:SetVertexColor(RGB(C.info, holders > 0 and 1 or 0.6))
        row.party.count:SetTone(holders > 0 and C.white or C.muted)
        row.party:SetShown(grouped or holders > 0)
        if self.compact and grouped then
            local have = 0
            for _, member in ipairs(roster) do
                local mc = Party.MemberStatus(member, qid)
                if mc == "done" or mc == "active" or mc == "ready" then have = have + 1 end
            end
            row.party.count:SetText(have .. "/" .. #roster)
            row.party.count:SetTone(have == #roster and C.good or (have > 0 and C.white or C.muted))
            row.party.icon:SetVertexColor(RGB(C.info, have > 0 and 1 or 0.6))
        end
        if self.compact then
            row.party:SetWidth(math.ceil(row.party.count:GetStringWidth() or 8) + 30)
        end
        if row.party:IsShown() then last = row.party end
        local canShare = grouped and Quests.InLog(qid)
        row.share:SetKind(canShare and "primary" or nil)
        row.share:SetAlpha(canShare and 1 or 0.4)
        row.share:Show()
        row.share:ClearAllPoints()
        row.share:SetPoint("RIGHT", last, "LEFT", -4, 0)
        last = row.share
        row.xp:ClearAllPoints()
        row.xp:SetPoint("RIGHT", last, "LEFT", -6, 0)
        if self.compact then
            local edge = (row.xp:GetText() or "") ~= "" and row.xp or last
            row.sub:SetPoint("RIGHT", edge, "LEFT", -6, 0)
        end
        local height = row.head:GetHeight()
        if self.open[qid] then
            row.body:Show()
            height = height + self:Details(row, q)
        else
            row.body:Hide()
        end
        row:SetHeight(height)
        y = y + height
    end
    self.scroll:SetContentHeight(y)
end
