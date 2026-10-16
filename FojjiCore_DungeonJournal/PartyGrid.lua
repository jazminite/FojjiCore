local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Quests = FDJ.Quests
local Party = FDJ.Party

local PartyGrid = {}
PartyGrid.__index = PartyGrid
FDJ.PartyGrid = PartyGrid

local STATUS = {
    done = { tex = "Interface\\RaidFrame\\ReadyCheck-Ready", size = 16 },
    ready = { tex = "Interface\\GossipFrame\\ActiveQuestIcon", size = 16 },
    active = { glyph = "ui-questlog", size = 15, tint = { 0.45, 0.78, 1 } },
    missing = { tex = "Interface\\RaidFrame\\ReadyCheck-NotReady", size = 14, alpha = 0.75 },
    unknown = { glyph = "ui-dot", size = 7, tint = { 0.5, 0.52, 0.56 }, alpha = 0.8 },
}
local LEGEND = { "done", "ready", "active", "missing", "unknown" }

local function paintStatus(tex, code)
    local s = STATUS[code] or STATUS.unknown
    tex:SetTexture(s.glyph and FDJ.Glyph(s.glyph) or s.tex)
    tex:SetSize(s.size, s.size)
    tex:SetDesaturated(s.tint ~= nil and s.glyph == nil)
    if s.tint then tex:SetVertexColor(s.tint[1], s.tint[2], s.tint[3]) else tex:SetVertexColor(1, 1, 1) end
    tex:SetAlpha(s.alpha or 1)
end

function PartyGrid.PaintStatus(tex, code, max)
    paintStatus(tex, code)
    local size = (STATUS[code] or STATUS.unknown).size
    if code == "unknown" or not STATUS[code] then tex:SetSize(6, 6) else tex:SetSize(math.min(size, max or size), math.min(size, max or size)) end
end

local CELL = 34
local ROW = 30

function PartyGrid.New(parent, compact)
    local self = setmetatable({}, PartyGrid)
    self.compact = compact
    self.cell = compact and 28 or CELL
    local frame = CreateFrame("Frame", nil, parent)
    self.frame = frame

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(26)
    local sync = Kit.Button(bar, L.SYNC, nil, 26, function() Party.Request() end)
    local report = Kit.Button(bar, L.REPORT, nil, 26, function()
        if self.dungeon then Party.Report(self.dungeon) end
    end)
    report:SetPoint("RIGHT")
    report.tip = L.REPORT_TIP
    sync:SetPoint("RIGHT", report, "LEFT", -6, 0)
    sync.tip = L.SYNC_TIP
    self.note = Kit.Text(bar, "small", C.muted)
    self.note:SetPoint("LEFT", 2, 0)
    self.note:SetPoint("RIGHT", sync, "LEFT", -6, 0)

    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
    head:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -6)
    head:SetHeight(30)
    Kit.Fill(head, C.field, 0.8)
    Kit.Line(head, "BOTTOM", C.borderDim)
    self.head = head
    self.names = {}

    local scroll = Kit.Scroller(frame)
    scroll:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", 0, 22)
    self.scroll = scroll

    local legend = CreateFrame("Frame", nil, frame)
    legend:SetPoint("BOTTOMLEFT", 2, 3)
    legend:SetPoint("BOTTOMRIGHT", -2, 3)
    legend:SetHeight(14)
    local prev
    for _, code in ipairs(LEGEND) do
        local icon = legend:CreateTexture(nil, "ARTWORK")
        paintStatus(icon, code)
        local s = STATUS[code]
        icon:SetSize(math.min(s.size, 12), math.min(s.size, 12))
        if code == "unknown" then icon:SetSize(6, 6) end
        if prev then icon:SetPoint("LEFT", prev, "RIGHT", 9, 0) else icon:SetPoint("LEFT", 0, 0) end
        local text = Kit.Text(legend, "tiny", C.muted)
        text:SetPoint("LEFT", icon, "RIGHT", 3, 0)
        text:SetText(L["PARTY_" .. code:upper()])
        prev = text
    end

    self.empty = Kit.Text(scroll, "normal", C.muted, "CENTER")
    self.empty:SetPoint("TOP", 0, -30)

    self.rows = Kit.Pool(function() return self:MakeRow() end)

    local function refresh()
        if frame:IsVisible() then self:Refresh() end
    end
    FDJ:On("FDJ_PARTY", refresh)
    FDJ:On("FDJ_QUESTS", refresh)
    FDJ:On("FDJ_OPTION", refresh)
    frame:SetScript("OnShow", function() self:Refresh() end)
    frame:SetScript("OnSizeChanged", function()
        if frame:IsVisible() then FDJ.Debounce("partygrid" .. tostring(self), 0.1, function() self:Refresh() end) end
    end)
    return self
end

function PartyGrid:SetDungeon(d)
    self.dungeon = d
    self:Refresh()
end

local function cellEnter(cell)
    if not cell.member then return end
    Kit.Tip(cell, cell.member.name, { Quests.Title(cell.qid), L["PARTY_" .. cell.code:upper()] })
end

function PartyGrid:MakeRow()
    local row = CreateFrame("Frame", nil, self.scroll.content)
    row:SetHeight(ROW)
    row.bg = Kit.Fill(row, C.white, 0)
    Kit.Line(row, "BOTTOM", C.borderDim, 0.6)
    row.title = Kit.Text(row, "small", C.text)
    row.title:SetPoint("LEFT", 10, 0)
    row.cells = {}
    for i = 1, 5 do
        local cell = CreateFrame("Button", nil, row)
        cell:SetSize(self.cell, ROW)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetSize(16, 16)
        cell.icon:SetPoint("CENTER")
        cell:SetScript("OnEnter", cellEnter)
        cell:SetScript("OnLeave", Kit.HideTip)
        row.cells[i] = cell
    end
    return row
end

local function headEnter(self)
    local member = self.member
    if not member then return end
    local c = Party.ClassColor(member.class)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(member.name or "?", c[1], c[2], c[3])
    if member.me then
        GameTooltip:AddLine(L.PARTY_YOU, C.muted[1], C.muted[2], C.muted[3])
    elseif Party.HasAddon(member.name) then
        GameTooltip:AddLine(L.PARTY_HAS_ADDON, C.accent[1], C.accent[2], C.accent[3])
    else
        GameTooltip:AddLine(L.PARTY_NO_ADDON, C.muted[1], C.muted[2], C.muted[3], true)
    end
    GameTooltip:Show()
end

local function firstName(name)
    name = name or "?"
    return name:match("^(%S+)") or name
end

function PartyGrid:Layout(count)
    local width = self.frame:GetWidth()
    if not width or width < 50 then width = self.compact and 300 or 700 end
    local room = width - (self.compact and 130 or 260)
    self.cell = math.max(30, math.min(self.compact and 58 or 80, math.floor(room / math.max(count, 1))))
    self.head:SetHeight(26)
end

function PartyGrid:Header(roster)
    for _, h in ipairs(self.names) do h:Hide() end
    local count = math.min(#roster, 5)
    self:Layout(count)
    local cell = self.cell
    local size = cell < 40 and 10 or 11
    for i = 1, count do
        local member = roster[i]
        local h = self.names[i]
        if not h then
            h = CreateFrame("Button", nil, self.head)
            h.text = Addon.Localize(h:CreateFontString(nil, "OVERLAY"))
            h.text:SetShadowColor(0, 0, 0, 0.8)
            h.text:SetShadowOffset(1, -1)
            h.text:SetPoint("CENTER")
            h.text:SetJustifyH("CENTER")
            h.text:SetWordWrap(false)
            h:SetScript("OnEnter", headEnter)
            h:SetScript("OnLeave", Kit.HideTip)
            self.names[i] = h
        end
        h.member = member
        local c = Party.ClassColor(member.class)
        local live = member.me or Party.HasAddon(member.name)
        h.text:SetFont(STANDARD_TEXT_FONT, size, "")
        h.text:SetWidth(cell - 2)
        h.text:SetText(firstName(member.name))
        h.text:SetTextColor(c[1], c[2], c[3], live and 1 or 0.75)
        h:SetSize(cell, 22)
        h:ClearAllPoints()
        h:SetPoint("RIGHT", self.head, "RIGHT", -6 - (count - i) * cell, 0)
        h:Show()
    end
    return count
end

function PartyGrid:Refresh()
    self.rows:Reset()
    local d = self.dungeon
    if not d then return end
    local roster = Party.Roster()
    local count = self:Header(roster)
    local withAddon = 0
    for _, member in ipairs(roster) do
        if not member.me and Party.HasAddon(member.name) then withAddon = withAddon + 1 end
    end
    if #roster < 2 then
        self.note:SetText(L.PARTY_SOLO)
    else
        self.note:SetText(L.PARTY_NOTE:format(withAddon, #roster - 1))
    end
    local list = Quests.ForDungeon(d)
    self.empty:SetText(#list == 0 and L.NO_QUESTS or "")
    local y = 0
    for _, qid in ipairs(list) do
        local row = self.rows:Get()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", self.scroll.content, "RIGHT", 0, 0)
        row.title:SetPoint("RIGHT", row, "RIGHT", -10 - count * self.cell, 0)
        local code = Quests.Status(qid)
        local style = Quests.Style[code] or Quests.Style.unknown
        row.title:SetText(FDJ.Paint(style.color, Quests.Title(qid)))
        for i = 1, 5 do
            local cell = row.cells[i]
            local member = roster[i]
            if member and i <= count then
                local mc = Party.MemberStatus(member, qid)
                cell.member, cell.qid, cell.code = member, qid, mc
                paintStatus(cell.icon, mc)
                cell:SetWidth(self.cell)
                cell:ClearAllPoints()
                cell:SetPoint("RIGHT", row, "RIGHT", -6 - (count - i) * self.cell, 0)
                cell:Show()
            else
                cell:Hide()
            end
        end
        row.bg:SetColorTexture(1, 1, 1, (#self.rows.used % 2 == 0) and 0.02 or 0)
        y = y + ROW
    end
    self.scroll:SetContentHeight(y)
end
