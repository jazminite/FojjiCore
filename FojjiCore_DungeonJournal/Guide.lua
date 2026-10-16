local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Routes = FDJ.Routes
local Pins = FDJ.Pins

local Guide = {}
FDJ.Guide = Guide

function Guide.Steps(g)
    local list = {}
    for i, step in ipairs(g.steps) do list[i] = { index = i, step = step } end
    if FDJ.Faction() == "Horde" and list[1] and list[2] and list[1].step.side == "Alliance" and list[2].step.side == "Horde" then
        list[1], list[2] = list[2], list[1]
    end
    return list
end

function Guide.Done(g)
    FDJ.char.guides = FDJ.char.guides or {}
    if not FDJ.char.guides[g.key] then
        local old = FDJ.db.guides and FDJ.db.guides[g.key]
        FDJ.char.guides[g.key] = old and FDJ.Copy(old) or {}
    end
    return FDJ.char.guides[g.key]
end

function Guide.Progress(g)
    local done, n = Guide.Done(g), 0
    for i in ipairs(g.steps) do if done[i] then n = n + 1 end end
    return n, #g.steps
end

function Guide.Next(g)
    local done = Guide.Done(g)
    for n, entry in ipairs(Guide.Steps(g)) do
        if not done[entry.index] then return entry, n end
    end
    return nil
end

local function spotOf(step)
    local m = FDJ.ZoneMap(step.zone)
    if not m then return nil end
    return m, step.x / 100, step.y / 100
end

function Guide.Route(g)
    FDJ.db.guideRoutes = FDJ.db.guideRoutes or {}
    local route = Routes.Get(FDJ.db.guideRoutes[g.key])
    if not route then
        route = Routes.Create("world", nil, L.GUIDE_ROUTE:format(g.name))
        FDJ.db.guideRoutes[g.key] = route.id
    end
    route.points = {}
    local done = Guide.Done(g)
    for n, entry in ipairs(Guide.Steps(g)) do
        local m, x, y = spotOf(entry.step)
        if m and not done[entry.index] then
            route.points[#route.points + 1] = { m = m, x = x, y = y, label = n .. ". " .. entry.step.title }
        end
    end
    FDJ:Emit("FDJ_ROUTES")
    return route
end

function Guide.IsShown(g)
    local id = FDJ.db.guideRoutes and FDJ.db.guideRoutes[g.key]
    local shown = FDJ.WorldLayer and FDJ.WorldLayer.route
    return id ~= nil and shown ~= nil and shown.id == id
end

local function continentOf(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    while info and Enum and Enum.UIMapType and info.mapType and info.mapType > Enum.UIMapType.Continent and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info and info.mapID or mapID
end

function Guide.Show(g)
    local route = Guide.Route(g)
    local entry = Guide.Next(g)
    local m = entry and spotOf(entry.step)
    local core = _G.FojjiCoreOptionsFrame
    if core and core:IsShown() then core:Hide() end
    FDJ:Emit("FDJ_SHOW_WORLD_ROUTE", route, false, continentOf(m) or m)
    FDJ:Emit("FDJ_GUIDE")
end

function Guide.Hide(g)
    if Guide.IsShown(g) then FDJ.WorldLayer.ShowRoute(nil, false) end
    FDJ:Emit("FDJ_GUIDE")
end

function Guide.SetDone(g, index, on)
    Guide.Done(g)[index] = on and true or nil
    if Guide.IsShown(g) then
        FDJ.WorldLayer.ShowRoute(Guide.Route(g), false)
    else
        Guide.Route(g)
    end
    FDJ:Emit("FDJ_GUIDE")
end

local function pinnedAt(step)
    local m, x, y = spotOf(step)
    local pm, px, py = Pins.Native()
    return m and pm == m and math.abs(px - x) < 0.0005 and math.abs(py - y) < 0.0005
end

function Guide.PinStep(step)
    local m, x, y = spotOf(step)
    if m then Pins.WaypointAt(m, x, y) end
    FDJ:Emit("FDJ_GUIDE")
end

function Guide.PinNext(g)
    local entry = Guide.Next(g)
    if entry then Guide.PinStep(entry.step) else FDJ.Print(L.GUIDE_ALL_DONE) end
end

local function stepRow(parent, g, view)
    local row = CreateFrame("Frame", nil, parent)
    row.bg = Kit.Fill(row, C.white, 0)
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    row.edge:SetWidth(2)
    row.rule = Kit.Line(row, "BOTTOM", C.borderDim, 0.6)
    row.num = CreateFrame("Frame", nil, row)
    row.num:SetSize(28, 28)
    row.num:SetPoint("TOPLEFT", 12, -12)
    row.num.dot = row.num:CreateTexture(nil, "ARTWORK")
    row.num.dot:SetAllPoints()
    row.num.dot:SetTexture(FDJ.Glyph("ui-dot"))
    row.num.text = Kit.Text(row.num, "small", C.shadow, "CENTER")
    row.num.text:SetShadowOffset(0, 0)
    row.num.text:SetPoint("CENTER")
    row.num.check = row.num:CreateTexture(nil, "OVERLAY")
    row.num.check:SetSize(16, 16)
    row.num.check:SetPoint("CENTER")
    row.num.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    row.pin = CreateFrame("Button", nil, row)
    row.pin:SetSize(30, 28)
    row.pin:SetPoint("TOPRIGHT", -8, -10)
    row.pin.hl = Kit.Fill(row.pin, C.buttonHover, 0, "BACKGROUND", 2)
    row.pin.icon = Kit.PinIcon(row.pin, 20)
    row.pin.icon:SetPoint("CENTER")
    row.pin:SetScript("OnEnter", function(self)
        self.hl:SetColorTexture(RGB(C.buttonHover, 1))
        Kit.Tip(self, pinnedAt(row.step) and L.PINNED or L.PIN_ON_MAP, L.GUIDE_PIN_TIP)
    end)
    row.pin:SetScript("OnLeave", function(self)
        self.hl:SetColorTexture(RGB(C.buttonHover, 0))
        Kit.HideTip()
    end)
    row.pin:SetScript("OnClick", function()
        if pinnedAt(row.step) then
            Pins.ClearOwn()
            FDJ:Emit("FDJ_GUIDE")
        else
            Guide.PinStep(row.step)
        end
    end)
    row.share = Kit.IconButton(row, "fc:icon-gossip", 28, L.SHARE_PIN, function() Pins.Share(nil, IsShiftKeyDown()) end)
    row.share.tipBody = L.SHARE_PIN_TIP
    row.share:SetPoint("RIGHT", row.pin, "LEFT", -2, 0)

    row.check = Kit.Check(row, L.GUIDE_DONE, function() return Guide.Done(g)[row.index] end, function(v)
        Guide.SetDone(g, row.index, v)
    end)
    row.check:SetPoint("RIGHT", row.share, "LEFT", -12, 0)

    row.title = Kit.Text(row, 13, C.white)
    row.title:SetPoint("TOPLEFT", row.num, "TOPRIGHT", 12, 0)
    row.title:SetPoint("RIGHT", row.check, "LEFT", -12, 0)
    row.where = Kit.Text(row, 11, C.accent)
    row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.flag = Kit.Text(row, 10, C.amber)
    row.flag:SetPoint("LEFT", row.where, "RIGHT", 10, 0)
    row.text = Kit.Text(row, 12, C.muted)
    row.text:SetPoint("TOPLEFT", row.where, "BOTTOMLEFT", 0, -6)
    row.text:SetWordWrap(true)
    row.text:SetJustifyV("TOP")
    row.text:SetSpacing(2)
    return row
end

function Addon.CreateGuidePage(page, g)
    g = g or FDJ.Guides[1]
    if not g then return end
    FDJ.SyncTheme()
    local view = CreateFrame("Frame", nil, page)
    view:SetPoint("TOPLEFT", 0, -54)
    view:SetPoint("BOTTOMRIGHT", 0, 0)

    local top = CreateFrame("Frame", nil, view)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(204)
    Kit.Fill(top, C.panel, 0.9)
    Kit.Edge(top, C.borderDim)
    local wash = Kit.Gradient(top, "HORIZONTAL", C.accent, 0.10, 0, "BACKGROUND", 2)
    wash:SetPoint("TOPLEFT", 1, -1)
    wash:SetPoint("BOTTOMLEFT", top, "TOPLEFT", 1, -92)
    wash:SetWidth(420)

    local tiles = {}
    local main = g.rewards and g.rewards[1]
    local card = CreateFrame("Frame", nil, top)
    card:SetPoint("TOPLEFT", 16, -16)
    card:SetSize(340, 60)
    local big = Kit.ItemIcon(card, 56)
    big:SetPoint("LEFT")
    tiles[#tiles + 1] = big
    local rewardLabel = Kit.Text(card, "tiny", C.muted)
    rewardLabel:SetPoint("TOPLEFT", big, "TOPRIGHT", 12, -4)
    rewardLabel:SetText(L.GUIDE_REWARD:upper())
    local rewardName = Kit.Text(card, "large", C.white)
    rewardName:SetPoint("TOPLEFT", rewardLabel, "BOTTOMLEFT", 0, -4)
    rewardName:SetPoint("RIGHT", card, "RIGHT")
    rewardName:SetWordWrap(false)
    local facts = Kit.Text(card, "small", C.muted)
    facts:SetPoint("TOPLEFT", rewardName, "BOTTOMLEFT", 0, -5)
    local _, stepTotal = Guide.Progress(g)
    local dot = FDJ.Paint("dim", "   ·   ")
    facts:SetText(L.LEVEL .. " " .. FDJ.Paint("good", g.level .. "+") .. dot .. L.GUIDE_STEP_COUNT:format(stepTotal) .. dot .. L.GUIDE_BOTH_SIDES)

    local function paintReward()
        if not main then return end
        big:SetItem(main)
        local name, _, quality = C_Item.GetItemInfo(main)
        local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        rewardName:SetText(name or g.reward or "")
        if qc then rewardName:SetTextColor(qc.r, qc.g, qc.b) end
    end
    if main and C_Item.GetItemInfo(main) == nil then C_Item.RequestLoadItemDataByID(main) end
    paintReward()

    if g.extras and #g.extras > 0 then
        local divider = top:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", card, "TOPRIGHT", 14, 2)
        divider:SetSize(1, 64)
        divider:SetColorTexture(RGB(C.borderDim))
        local along = Kit.Text(top, "tiny", C.muted)
        along:SetPoint("TOPLEFT", divider, "TOPRIGHT", 18, -2)
        along:SetText(L.GUIDE_ALONG:upper())
        local alongSub = Kit.Text(top, "tiny", C.dim)
        alongSub:SetPoint("LEFT", along, "RIGHT", 8, 0)
        alongSub:SetText(L.GUIDE_ALONG_SUB)
        local last
        for i, itemID in ipairs(g.extras) do
            local b = Kit.ItemIcon(top, 36)
            if last then b:SetPoint("LEFT", last, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", along, "BOTTOMLEFT", 0, -8) end
            if C_Item.GetItemInfo(itemID) == nil then C_Item.RequestLoadItemDataByID(itemID) end
            b:SetItem(itemID)
            tiles[#tiles + 1] = b
            last = b
        end
    end
    FDJ:On("GET_ITEM_INFO_RECEIVED", function()
        if not view:IsVisible() then return end
        for _, b in ipairs(tiles) do b:SetItem(b.itemID) end
        paintReward()
    end)

    local rule = top:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", 16, -92)
    rule:SetPoint("TOPRIGHT", -16, -92)
    rule:SetHeight(1)
    rule:SetColorTexture(RGB(C.borderDim))
    local intro = Kit.Text(top, "small", C.muted)
    intro:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -10)
    intro:SetPoint("RIGHT", -16, 0)
    intro:SetWordWrap(true)
    intro:SetText(g.summary)

    local progress = Kit.Text(top, "small", C.white)
    progress:SetPoint("BOTTOMLEFT", 16, 48)
    local percent = Kit.Text(top, "small", C.muted, "RIGHT")
    percent:SetPoint("BOTTOMRIGHT", -16, 48)
    local track = top:CreateTexture(nil, "ARTWORK")
    track:SetPoint("BOTTOMLEFT", 16, 40)
    track:SetPoint("BOTTOMRIGHT", -16, 40)
    track:SetHeight(4)
    track:SetColorTexture(1, 1, 1, 0.08)
    local fill = top:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
    fill:SetHeight(4)

    local buttons = {}
    local function button(text, kind, glyph, fn, tip)
        local b = Kit.Button(top, text, nil, 26, fn, kind, glyph)
        b.tipBody = tip
        b.tip = tip and text
        buttons[#buttons + 1] = b
        return b
    end
    local show = button(L.GUIDE_SHOW_ROUTE, "primary", "ui-route", function()
        if Guide.IsShown(g) then Guide.Hide(g) else Guide.Show(g) end
    end, L.GUIDE_SHOW_TIP)
    local pinNext = button(L.GUIDE_PIN_NEXT, nil, "ui-waypoint", function() Guide.PinNext(g) end, L.GUIDE_PIN_NEXT_TIP)
    local share = button(L.GUIDE_SHARE, nil, "ui-party", function() Routes.Share(Guide.Route(g)) end, L.GUIDE_SHARE_TIP)
    local reset = button(L.GUIDE_RESET, nil, "fc:icon-reset", function()
        Kit.Confirm(L.GUIDE_RESET_Q, function()
            wipe(Guide.Done(g))
            Guide.SetDone(g, 0, false)
        end)
    end)
    show:SetPoint("BOTTOMLEFT", 16, 8)
    pinNext:SetPoint("LEFT", show, "RIGHT", 6, 0)
    share:SetPoint("LEFT", pinNext, "RIGHT", 6, 0)
    reset:SetPoint("BOTTOMRIGHT", -16, 8)

    local scroll = Kit.Scroller(view)
    scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT")
    local rows = Kit.Pool(function() return stepRow(scroll.content, g, view) end)

    local function refresh()
        if not view:IsVisible() then return end
        local n, total = Guide.Progress(g)
        progress:SetText(L.GUIDE_STEPS:format(n, total))
        percent:SetText(math.floor(100 * n / math.max(1, total) + 0.5) .. "%")
        top:SetHeight(92 + 10 + intro:GetStringHeight() + 14 + 64)
        local w = track:GetWidth()
        fill:SetWidth(math.max(1, (w > 0 and w or 400) * n / math.max(1, total)))
        fill:SetColorTexture(RGB(n == total and C.good or C.accent))
        fill:SetShown(n > 0)
        local shown = Guide.IsShown(g)
        show:SetLabel(shown and L.GUIDE_HIDE_ROUTE or L.GUIDE_SHOW_ROUTE)
        show:SetKind(shown and "danger" or "primary")
        pinNext:SetEnabled(n < total)
        rows:Reset()
        local done = Guide.Done(g)
        local nextEntry = Guide.Next(g)
        local y = 0
        local width = math.max(240, scroll.content:GetWidth())
        for idx, entry in ipairs(Guide.Steps(g)) do
            local row = rows:Get()
            local step = entry.step
            row.step, row.index = step, entry.index
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", scroll.content, "RIGHT")
            local finished = done[entry.index]
            local isNext = nextEntry == entry or (nextEntry and nextEntry.index == entry.index)
            row.num.dot:SetVertexColor(RGB(finished and C.good or (isNext and C.accent or C.edge)))
            row.num.text:SetText(finished and "" or idx)
            row.num.check:SetShown(finished and true or false)
            row.title:SetText(step.title)
            row.title:SetTone(finished and C.muted or C.white)
            row.where:SetText(("%s   %.1f, %.1f"):format(step.zone, step.x, step.y))
            row.where:SetTone(finished and C.dim or C.accent)
            local pinned = pinnedAt(step)
            row.flag:SetText(pinned and L.GUIDE_PINNED or (isNext and L.GUIDE_NEXT or ""))
            row.pin.icon:SetDesaturated(not pinned)
            row.pin.icon:SetAlpha(pinned and 1 or 0.6)
            row.share:SetShown(pinned and true or false)
            row.edge:SetColorTexture(RGB(C.accent, isNext and 1 or 0))
            row.bg:SetColorTexture(1, 1, 1, isNext and 0.03 or 0)
            row.check:Sync()
            row.text:SetWidth(math.min(width - 220, 660))
            row.text:SetText(step.text)
            row.text:SetTextColor(RGB(finished and C.dim or C.muted))
            local height = math.max(64, 50 + row.text:GetStringHeight() + 12)
            row:SetHeight(height)
            y = y + height
        end
        scroll:SetContentHeight(y)
    end
    view:SetScript("OnShow", refresh)
    view:SetScript("OnSizeChanged", function() FDJ.Debounce("guideview", 0.05, refresh) end)
    FDJ:On("FDJ_GUIDE", refresh)
    FDJ:On("FDJ_PINS", function() FDJ.Debounce("guidepins", 0.1, refresh) end)
    FDJ:On("FDJ_ROUTES", function() FDJ.Debounce("guideroutes", 0.1, refresh) end)
    return view
end
