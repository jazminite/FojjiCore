local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Quests = FDJ.Quests
local Routes = FDJ.Routes

local Pocket = {}
FDJ.Pocket = Pocket

local HEAD = 30
local WIDTH, HEIGHT = 270, 290
local frame, head, body, seg, toggle, grip, count, countIcon
local views = {}
local dungeon
local manual = false

local function state()
    FDJ.db.pocket = FDJ.db.pocket or {}
    return FDJ.db.pocket
end

local function upwards()
    return (FDJ:Option("pocketDir") or "up") ~= "down"
end

local function speedrun()
    local ui = Addon.SRUI
    if not (ui and ui.Spot) then return nil end
    local store = Addon.GetSpeedrunStore and Addon.GetSpeedrunStore()
    if store and store.disabled then return nil end
    return ui
end

local function anchored()
    return FDJ:Option("pocketAnchor") ~= false and speedrun() or nil
end

local function timerWidth()
    local ui = anchored()
    if ui then
        local _, _, w = ui.Spot()
        return w
    end
end

local function savePosition()
    local s = state()
    local left, right, top = frame:GetLeft(), frame:GetRight(), frame:GetTop()
    if not (left and right and top) then return end
    local mid = (UIParent:GetWidth() or 0) / 2
    if (left + right) / 2 > mid then
        s.side, s.x = "RIGHT", right
    else
        s.side, s.x = "LEFT", left
    end
    s.y, s.yb = top, frame:GetBottom()
end

local function placeFrame()
    local s = state()
    local up = upwards()
    local lift = up and 4 or (HEAD + 6)
    local point = up and "BOTTOMLEFT" or "TOPLEFT"
    frame:ClearAllPoints()
    local ui = anchored()
    if ui then
        local left, top, _, live = ui.Spot()
        if live then
            frame:SetPoint(point, live, "TOPLEFT", 0, lift)
        else
            frame:SetPoint(point, UIParent, "BOTTOMLEFT", left, top + lift)
        end
        return
    end
    if s.x and (up and s.yb or not up and s.y) then
        local v = up and "BOTTOM" or "TOP"
        frame:SetPoint(v .. (s.side == "RIGHT" and "RIGHT" or "LEFT"), UIParent, "BOTTOMLEFT", s.x, up and s.yb or s.y)
        return
    end
    local w, h = UIParent:GetWidth() or 1000, UIParent:GetHeight() or 700
    frame:SetPoint(up and "BOTTOMRIGHT" or "TOPRIGHT", UIParent, "BOTTOMLEFT", w - w * 0.03, h - h * 0.48 + lift)
end

local function available(d)
    local n = 0
    for _, qid in ipairs(Quests.ForDungeon(d)) do
        local code = Quests.Status(qid)
        if code == "open" or code == "ready" or code == "chain" then n = n + 1 end
    end
    return n
end

local function compactWidth()
    local text = head.name.GetUnboundedStringWidth and head.name:GetUnboundedStringWidth()
    if not text then
        head.measure = head.measure or head:CreateFontString(nil, "BACKGROUND")
        local font, size, flags = head.name:GetFont()
        if font then head.measure:SetFont(font, size, flags) end
        head.measure:SetText(head.name:GetText() or "")
        text = head.measure:GetStringWidth()
    end
    local counted = countIcon:IsShown() and math.ceil(count:GetStringWidth() or 0) or 0
    local w = 1 + 6 + 20 + 7 + math.ceil(text or 0) + 6 + 13 + 2 + counted + 4 + 22 + 1 + 22 + 1 + 24 + 2 + 1 + 10
    return timerWidth() or math.max(150, w)
end

local function paint()
    if not frame or not dungeon then return end
    head.name:SetText(FDJ.DungeonTitle(dungeon) .. "  " .. FDJ.Paint(FDJ.RangeColor(dungeon), dungeon.range[1] .. "-" .. dungeon.range[2]))
    local n = available(dungeon)
    count:SetText(n > 0 and n or "")
    countIcon:SetShown(n > 0)
    if not state().open then
        frame:SetWidth(compactWidth())
        C_Timer.After(0, function() if not state().open then frame:SetWidth(compactWidth()) end end)
    end
end

local function layout()
    local s = state()
    local open = s.open and true or false
    local up = upwards()
    placeFrame()
    frame:SetWidth(open and (s.w or timerWidth() or WIDTH) or compactWidth())
    frame:SetHeight(open and (s.h or HEIGHT) or HEAD + 2)
    head:ClearAllPoints()
    body:ClearAllPoints()
    grip:ClearAllPoints()
    if up then
        head:SetPoint("BOTTOMLEFT", 1, 1)
        head:SetPoint("BOTTOMRIGHT", -1, 1)
        body:SetPoint("TOPLEFT", 7, -8)
        body:SetPoint("BOTTOMRIGHT", head, "TOPRIGHT", -7, 7)
        grip:SetPoint("TOPRIGHT", -2, -2)
        grip.corner = "TOPRIGHT"
        grip.tex:SetTexCoord(0, 1, 1, 0)
    else
        head:SetPoint("TOPLEFT", 1, -1)
        head:SetPoint("TOPRIGHT", -1, -1)
        body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 7, -7)
        body:SetPoint("BOTTOMRIGHT", -7, 8)
        grip:SetPoint("BOTTOMRIGHT", -2, 2)
        grip.corner = nil
        grip.tex:SetTexCoord(0, 1, 0, 1)
    end
    if seg then seg:SetPoint("TOPRIGHT", up and -14 or 0, 0) end
    body:SetShown(open)
    grip:SetShown(open)
    head.rule:SetShown(open and not up)
    head.ruleTop:SetShown(open and up)
    local opens, closes = up and "fc:icon-chevron-up" or "fc:icon-chevron-down", up and "fc:icon-chevron-down" or "fc:icon-chevron-up"
    toggle:SetIcon(open and closes or opens)
    toggle.tip = open and L.POCKET_COLLAPSE or L.POCKET_EXPAND
end

function Pocket.SetDungeon(d, byHand)
    if not d then return end
    if byHand then manual = true end
    dungeon = d
    FDJ.Prefetch(d)
    if not frame then return end
    paint()
    views.quests.list:SetDungeon(d)
    views.bosses.list:SetDungeon(d)
end

local function chooseMenu(anchor)
    local items = { { text = L.POCKET_FOLLOW, checked = not manual, onClick = function()
        manual = false
        Pocket.SetDungeon(FDJ.SuggestedDungeon())
    end } }
    local family
    for _, d in ipairs(FDJ.Dungeons) do
        if d.family ~= family and d.family then items[#items + 1] = { text = d.family, title = true } end
        family = d.family
        items[#items + 1] = {
            text = (d.family and "  " or "") .. FDJ.FactionIcon(d, 13) .. (FDJ.IsEnemyDungeon(d) and FDJ.Paint("dim", d.name) or d.name) .. "  " .. FDJ.Paint(FDJ.RangeColor(d), d.range[1] .. "-" .. d.range[2]),
            checked = d == dungeon,
            onClick = function() Pocket.SetDungeon(d, true) end,
        }
    end
    Kit.Menu(anchor, items, 240)
end

local function buildViews()
    local function view()
        local f = CreateFrame("Frame", nil, body)
        f:SetPoint("TOPLEFT", seg, "BOTTOMLEFT", 0, -8)
        f:SetPoint("BOTTOMRIGHT", 0, 0)
        f:Hide()
        return f
    end

    local q = view()
    q.list = FDJ.QuestList.New(q, true)
    q.list.frame:SetAllPoints(q)
    views.quests = q

    local b = view()
    b.list = FDJ.BossList.New(b)
    b.list.frame:SetAllPoints(b)
    views.bosses = b

end

local function build()
    FDJ.SyncTheme()
    frame = CreateFrame("Frame", "FojjiCoreDungeonPocket", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    Kit.Fill(frame, C.frame, 0.97)
    Kit.Edge(frame, C.border)
    if Addon.Native and Addon.Skin then Addon.Skin.Panel(frame) end

    head = CreateFrame("Button", nil, frame)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(HEAD)
    Kit.Fill(head, C.header)
    head.rule = Kit.Line(head, "BOTTOM", C.borderDim)
    head.ruleTop = Kit.Line(head, "TOP", C.borderDim)
    head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function()
        Kit.HideTip()
        head.dragged = true
        local ui = anchored()
        if ui and ui.DragStart() then head.withTimer = true return end
        frame:StartMoving()
    end)
    head:SetScript("OnDragStop", function()
        local ui = anchored()
        if head.withTimer then
            head.withTimer = nil
            if ui then ui.DragStop() end
        else
            frame:StopMovingOrSizing()
            if ui then
                local left, bottom = frame:GetLeft(), upwards() and frame:GetBottom() or (frame:GetTop() and frame:GetTop() - HEAD - 6)
                if left and bottom then ui.SetSpot(left, bottom - 4) end
            else
                savePosition()
            end
        end
        placeFrame()
        C_Timer.After(0, function() head.dragged = nil end)
    end)
    head:SetScript("OnClick", function(self, button)
        if head.dragged then
            head.dragged = nil
            return
        end
        if button == "RightButton" then
            chooseMenu(self)
        else
            Pocket.Toggle()
        end
    end)
    head.hl = Kit.Fill(head, C.white, 0, "BORDER")
    head:SetScript("OnEnter", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0.035)
    end)
    head:SetScript("OnLeave", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0)
    end)

    local icon = head:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 6, 0)
    Kit.Logo(icon)

    local gear = Kit.IconButton(head, "Interface\\AddOns\\FojjiCore\\textures\\Speedrun\\gear", 18, L.SETTINGS, function() FDJ.Journal.Settings() end)
    gear:SetPoint("RIGHT", -3, 0)
    gear.glyph:SetSize(13, 13)
    local close = Kit.CloseButton(head, function()
        FDJ:SetOption("pocketWhen", "never")
        FDJ.Print(L.POCKET_HIDDEN)
    end)
    close:SetSize(18, 18)
    close:SetPoint("RIGHT", gear, "LEFT", -1, 0)
    if not Addon.Native then
        close:SetScript("OnSizeChanged", nil)
        close.glyph:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\close-cross")
        close.glyph:SetSize(11, 11)
    end
    toggle = Kit.IconButton(head, "fc:icon-chevron-down", 22, L.POCKET_EXPAND, function() Pocket.Toggle() end)
    toggle:SetPoint("RIGHT", close, "LEFT", -1, 0)
    toggle:SetAlpha(0)
    toggle:EnableMouse(false)
    local book = Kit.IconButton(head, "ui-book", 22, L.OPEN_JOURNAL, function() FDJ.Journal.Open(dungeon) end)
    book:SetPoint("RIGHT", close, "LEFT", -1, 0)

    count = Kit.Text(head, "small", C.good, "RIGHT")
    count:SetPoint("RIGHT", book, "LEFT", -4, 0)
    countIcon = head:CreateTexture(nil, "ARTWORK")
    countIcon:SetSize(13, 13)
    countIcon:SetPoint("RIGHT", count, "LEFT", -2, 0)
    countIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")

    head.name = Kit.Text(head, "normal", C.white)
    head.name:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    head.name:SetPoint("RIGHT", countIcon, "LEFT", -6, 0)

    if not Addon.Native then
        Kit.EdgeColor(frame, C.accent, 0.22)
        Kit.Paint(head.rule, C.accent, 0.3)
        Kit.Paint(head.ruleTop, C.accent, 0.3)
    end

    body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 7, -7)
    body:SetPoint("BOTTOMRIGHT", -7, 8)

    seg = Kit.Segmented(body, {
        { "bosses", L.TAB_BOSSES },
        { "quests", L.TAB_QUESTS },
    }, function(key)
        for k, v in pairs(views) do v:SetShown(k == key) end
        state().tab = key
    end)
    seg:SetHeight(22)
    seg:SetPoint("TOPLEFT")
    seg:SetPoint("TOPRIGHT")

    buildViews()

    grip = Kit.Resizable(frame, 240, 200, function(self)
        local s = state()
        s.w, s.h = self:GetWidth(), self:GetHeight()
        savePosition()
        placeFrame()
    end)
    Pocket.Placed()

    placeFrame()
    local saved = state().tab
    seg:Select(views[saved or ""] and saved or "bosses")

    local function refresh()
        if frame:IsShown() then paint() end
    end
    FDJ:On("FDJ_QUESTS", refresh)
    FDJ:On("FDJ_SPOTS", refresh)
    FDJ:On("PLAYER_LEVEL_UP", function()
        if not manual and not FDJ.CurrentDungeon() then C_Timer.After(0.5, function() Pocket.SetDungeon(FDJ.SuggestedDungeon()) end) end
    end)
    FDJ:On("FDJ_ENTERED", function(d)
        manual = false
        Pocket.SetDungeon(d)
    end)

    Pocket.SetDungeon(FDJ.SuggestedDungeon())
    layout()
end

function Pocket.Toggle()
    if not frame then return end
    local s = state()
    s.open = not s.open
    layout()
end

local function wanted()
    local when = FDJ:Option("pocketWhen") or "always"
    if when == "never" then return false end
    if when == "group" then return IsInGroup and IsInGroup() or false end
    if when == "dungeon" then
        local _, kind = IsInInstance()
        return kind == "party" or (FDJ.CurrentDungeon and FDJ.CurrentDungeon() ~= nil) or false
    end
    return true
end

function Pocket.Apply()
    if FDJ.db and not FDJ.db.pocketDungeonDefault then
        FDJ.db.pocketDungeonDefault = true
        FDJ.db.pocketWhenSet = true
        FDJ.opt.pocketWhen = "dungeon"
        FDJ.opt.pocket = true
    end
    if FDJ.db and not FDJ.db.pocketUpDefault then
        FDJ.db.pocketUpDefault = true
        FDJ.opt.pocketDir = "up"
        local s = state()
        s.x, s.y, s.yb, s.side, s.w, s.h = nil, nil, nil, nil, nil, nil
    end
    if FDJ.db and not FDJ.db.pocketShorter2 then
        FDJ.db.pocketShorter2 = true
        state().h = nil
        if frame then layout() end
    end
    if not wanted() then
        if frame then frame:Hide() end
        return
    end
    if not frame then build() end
    Pocket.Placed()
    layout()
    frame:Show()
    frame:Raise()
    paint()
end

FDJ:On("FDJ_OPTION", function(key)
    if key == "pocket" or key == "pocketWhen" then Pocket.Apply() end
    if (key == "pocketDir" or key == "pocketAnchor") and frame then layout() end
end)

local hooked
function Pocket.Placed()
    local t = Addon.SRUI and Addon.SRUI.frame
    if hooked or not t then return end
    hooked = true
    local function follow()
        C_Timer.After(0, function() if frame and frame:IsShown() then layout() end end)
    end
    t:HookScript("OnSizeChanged", follow)
    t:HookScript("OnShow", follow)
    t:HookScript("OnHide", follow)
end
FDJ:On("GROUP_ROSTER_UPDATE", function()
    if FDJ:Option("pocketWhen") == "group" then Pocket.Apply() end
end)
FDJ:On("PLAYER_ENTERING_WORLD", function()
    if FDJ:Option("pocketWhen") == "dungeon" then C_Timer.After(0.5, Pocket.Apply) end
end)
FDJ:On("ZONE_CHANGED_NEW_AREA", function()
    if FDJ:Option("pocketWhen") == "dungeon" then Pocket.Apply() end
end)

function Pocket.ToggleShown()
    FDJ:SetOption("pocketWhen", wanted() and "never" or "always")
end
