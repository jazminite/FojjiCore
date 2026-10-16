local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Quests = FDJ.Quests
local Routes = FDJ.Routes
local Pins = FDJ.Pins
local WorldLayer = FDJ.WorldLayer

local Dock = {}
FDJ.Dock = Dock

local WIDTH = 340
local panel, tab, banner, tabs
local views = {}
local dungeon
local pinned = false

function Dock.Dungeon()
    return dungeon
end

function Dock.IsOpen()
    return panel ~= nil and panel:IsVisible()
end

local function fits()
    local right = WorldMapFrame:GetRight()
    local screen = UIParent:GetRight()
    if not right or not screen then return true end
    local scale = WorldMapFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return right * scale + WIDTH * panel:GetEffectiveScale() / UIParent:GetEffectiveScale() <= screen + 1
end

local function anchor()
    if not panel then return end
    panel:ClearAllPoints()
    tab:ClearAllPoints()
    local inside = (WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized()) or not fits()
    if inside then
        panel:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -4, -26)
        panel:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -4, 4)
        tab:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -6, -66)
    else
        panel:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 2, 0)
        panel:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMRIGHT", 2, 0)
        tab:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 1, -66)
    end
    tab:SetShown(FDJ:Option("dock") and not panel:IsShown())
end

local function paint()
    if not panel or not dungeon then return end
    banner.name:SetText(FDJ.DungeonTitle(dungeon))
    local tag = FDJ.FactionTag(dungeon)
    banner.meta:SetText(("%s   ·   %s%s %s"):format(dungeon.zone, tag and (tag .. "   ·   ") or "", L.LEVELS,
        FDJ.Paint(FDJ.RangeColor(dungeon), dungeon.range[1] .. "-" .. dungeon.range[2])))
    banner.follow:SetActive(not pinned and FDJ:Option("dockFollow"))
end

function Dock.SetDungeon(d, manual)
    if not d then return end
    if manual then pinned = true end
    dungeon = d
    FDJ.Prefetch(d)
    if not panel then return end
    paint()
    views.quests.list:SetDungeon(d)
    views.bosses.list:SetDungeon(d)
    views.routes.list:Refresh()
    FDJ:Emit("FDJ_DOCK")
end

local function follow(mapID)
    if pinned or not FDJ:Option("dockFollow") or not mapID then return end
    local here = FDJ.CurrentDungeon()
    local list = FDJ.DungeonsInZone(mapID)
    local pick
    for _, d in ipairs(list) do
        if FDJ.FitsLevel(d) and (not pick or d.range[1] > pick.range[1]) then pick = d end
    end
    pick = pick or list[1] or here
    if pick and pick ~= dungeon then Dock.SetDungeon(pick) end
end

function Dock.SyncBar()
    if not panel then return end
    panel.body:ClearAllPoints()
    panel.body:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -134)
    panel.body:SetPoint("BOTTOMRIGHT", -12, 12)
end

local function buildViews(body)
    local function view()
        local f = FDJ.NewFrame("Frame", nil, body)
        f:SetPoint("TOPLEFT", 0, 0)
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

    local r = view()
    r.list = FDJ.RouteList.New(r, true, { "chart" })
    r.list.frame:SetPoint("TOPLEFT")
    r.list.frame:SetPoint("BOTTOMRIGHT", 0, 0)
    r.list.onOpen = function(route, edit)
        if route.scope == "chart" then
            FDJ.Journal.ShowRoute(route, edit)
        else
            Dock.ShowWorldRoute(route, edit)
        end
    end
    r.list.onCreate = function(scope)
        if scope == "chart" then
            FDJ.Journal.Open(dungeon, "map")
            FDJ.Journal.NewChartRoute()
        else
            local mapID = WorldLayer.MapID()
            if not WorldLayer.Editable(mapID) then
                FDJ.Print(L.PICK_ZONE_FIRST)
                return
            end
            FDJ.NewWorldRoute(mapID)
        end
    end
    r.list:SetSource(function() return dungeon and Routes.ForChart(dungeon) or {} end)
    views.routes = r
end

function Dock.ShowWorldRoute(route, edit, mapID)
    if not WorldMapFrame:IsShown() then
        local first = route and (route.points[1] or route.strokes[1] or route.marks[1])
        local target = mapID or (first and first.m) or (dungeon and FDJ.ZoneMap(dungeon.zone))
        Pins.OpenMap(target)
    elseif mapID then
        WorldMapFrame:SetMapID(mapID)
    end
    if FDJ.InstanceMap and FDJ.InstanceMap.RouteMode then FDJ.InstanceMap.RouteMode(true) end
    WorldLayer.ShowRoute(route, edit)
    if edit and WorldLayer.tool == "view" then WorldLayer.SetTool("draw") end
end

local function build()
    FDJ.SyncTheme()
    panel = FDJ.NewFrame("Frame", "FojjiCoreDungeonDock", WorldMapFrame)
    panel:SetWidth(WIDTH)
    panel:SetFrameStrata(WorldMapFrame:GetFrameStrata())
    panel:SetFrameLevel(9950)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function() end)
    Kit.Fill(panel, C.frame, 1)
    if panel.SetIgnoreParentAlpha then panel:SetIgnoreParentAlpha(true) end
    Kit.Edge(panel, C.edge)

    local head = FDJ.NewFrame("Frame", nil, panel)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(32)
    Kit.Fill(head, C.header)
    Kit.Line(head, "BOTTOM", C.borderDim)
    local icon = head:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 7, 0)
    Kit.Logo(icon)
    local title = Kit.Text(head, "normal", C.white)
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("Dungeon Journal")
    local close = Kit.CloseButton(head, function() Dock.Close() end)
    close:SetPoint("RIGHT", -2, 0)
    local full = Kit.IconButton(head, "ui-book", 26, L.OPEN_JOURNAL, function()
        FDJ.Journal.Open(dungeon)
    end)
    full:SetPoint("RIGHT", close, "LEFT", -4, 0)

    banner = FDJ.NewFrame("Button", nil, panel)
    banner:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 11, -10)
    banner:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -11, -10)
    banner:SetHeight(44)
    banner.name = Kit.Text(banner, "large", C.white)
    banner.name:SetPoint("TOPLEFT", 2, -4)
    banner.name:SetPoint("RIGHT", -60, 0)
    banner.meta = Kit.Text(banner, "small", C.muted)
    banner.meta:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 0, -6)
    banner.meta:SetPoint("RIGHT", -60, 0)
    banner.follow = Kit.IconButton(banner, "ui-waypoint", 26, L.FOLLOW_TIP, function()
        if pinned then
            pinned = false
            FDJ:SetOption("dockFollow", true)
            follow(WorldLayer.MapID())
        else
            FDJ:SetOption("dockFollow", not FDJ:Option("dockFollow"))
        end
        paint()
    end)
    banner.follow:SetPoint("RIGHT", 0, 0)
    local choose = Kit.IconButton(banner, "fc:icon-chevron-down", 26, L.CHOOSE_DUNGEON, function(b)
        local items = {}
        local family
        for _, d in ipairs(FDJ.Dungeons) do
            if d.family ~= family and d.family then items[#items + 1] = { text = d.family, title = true } end
            family = d.family
            items[#items + 1] = {
                text = (d.family and "  " or "") .. FDJ.FactionIcon(d, 13) .. (FDJ.IsEnemyDungeon(d) and FDJ.Paint("dim", d.name) or d.name) .. "  " .. FDJ.Paint(FDJ.RangeColor(d), d.range[1] .. "-" .. d.range[2]),
                checked = d == dungeon,
                onClick = function() Dock.SetDungeon(d, true) end,
            }
        end
        Kit.Menu(b, items, 240)
    end)
    choose:SetPoint("RIGHT", banner.follow, "LEFT", -4, 0)
    banner:SetScript("OnClick", function() choose:Click() end)
    banner.hl = Kit.Fill(banner, C.white, 0, "BACKGROUND")
    banner.hl:ClearAllPoints()
    banner.hl:SetPoint("TOPLEFT", -6, 0)
    banner.hl:SetPoint("BOTTOMRIGHT", banner.follow, "BOTTOMLEFT", -4, -6)
    local function hover(on)
        banner.hl:SetColorTexture(1, 1, 1, on and 0.04 or 0)
        banner.name:SetTone(on and C.accent or C.white)
        choose.hot = on
        choose:Paint()
    end
    banner:SetScript("OnEnter", function() hover(true) end)
    banner:SetScript("OnLeave", function() hover(false) end)
    choose.tip = nil
    choose:HookScript("OnEnter", function()
        banner.hl:SetColorTexture(1, 1, 1, 0.04)
        banner.name:SetTone(C.accent)
    end)
    choose:HookScript("OnLeave", function()
        banner.hl:SetColorTexture(1, 1, 1, 0)
        banner.name:SetTone(C.white)
    end)

    tabs = Kit.Tabs(panel, {
        { "quests", L.TAB_QUESTS },
        { "bosses", L.TAB_BOSSES },
        { "routes", L.TAB_ROUTES },
    }, function(key)
        for k, v in pairs(views) do v:SetShown(k == key) end
        FDJ.db.window.dockTab = key
    end)
    tabs.first:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", Addon.Native and 0 or -6, Addon.Native and -10 or -4)
    for _, b in pairs(tabs.buttons) do b:SetWidth(78) end
    local rule = panel:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -36)
    rule:SetPoint("TOPRIGHT", banner, "BOTTOMRIGHT", 0, -36)
    rule:SetHeight(1)
    Kit.Paint(rule, C.borderDim)
    if Addon.Native and Addon.Skin then Addon.Skin.Rule(rule) end

    local body = FDJ.NewFrame("Frame", nil, panel)
    panel.body = body
    buildViews(body)

    tab = FDJ.NewFrame("Button", "FojjiCoreDungeonDockTab", WorldMapFrame)
    tab:SetSize(36, 36)
    tab:SetFrameStrata(WorldMapFrame:GetFrameStrata())
    tab:SetFrameLevel(9960)
    if tab.SetIgnoreParentAlpha then tab:SetIgnoreParentAlpha(true) end
    Kit.Fill(tab, C.header)
    Kit.Edge(tab, C.border)
    local glyph = Kit.Glyph(tab, "ui-book", 20, C.accent)
    glyph:SetPoint("CENTER")
    tab:SetScript("OnClick", function()
        if panel:IsShown() then Dock.Close() else Dock.Open() end
    end)
    tab:SetScript("OnEnter", function(self)
        glyph:SetVertexColor(RGB(C.text))
        Kit.Tip(self, FDJ.title, L.DOCK_SHOW, "ANCHOR_LEFT")
    end)
    tab:SetScript("OnLeave", function()
        glyph:SetVertexColor(RGB(C.accent))
        Kit.HideTip()
    end)

    panel:SetScript("OnShow", function()
        anchor()
        Dock.SyncBar()
    end)
    panel:SetScript("OnHide", anchor)
    panel:Hide()

    FDJ.WatchFrame(WorldMapFrame, function() Dock.Apply() end)
    FDJ.OnMapLayout(function() C_Timer.After(0, anchor) end)
    do
        FDJ.OnMapChanged(function()
            follow(WorldLayer.MapID())
            if panel:IsShown() and views.routes:IsShown() then views.routes.list:Refresh() end
        end)
    end
    FDJ:On("FDJ_PLACING", function()
        if Pins.placing then Dock.Open() end
        Dock.SyncBar()
    end)
    FDJ:On("FDJ_WORLD_REFRESH", Dock.SyncBar)
    FDJ:On("FDJ_ROUTES", Dock.SyncBar)
    FDJ:On("FDJ_OPTION", function(key)
        if key == "dock" then Dock.Apply() end
        if key == "dockFollow" then paint() end
    end)
    FDJ:On("FDJ_DOCK_DUNGEON", function(d)
        Dock.SetDungeon(d, true)
        FDJ.db.options.dockOpen = true
    end)
    FDJ:On("FDJ_SHOW_WORLD_ROUTE", function(route, edit, mapID) Dock.ShowWorldRoute(route, edit, mapID) end)
    FDJ:On("FDJ_ENTERED", function(d)
        if not pinned then Dock.SetDungeon(d) end
    end)

    Dock.SetDungeon(dungeon or FDJ.SuggestedDungeon())
    local saved = FDJ.db.window.dockTab
    tabs:Select(views[saved or ""] and saved or "quests")
end

function Dock.Apply()
    if not panel then return end
    if not FDJ:Option("dock") and not Pins.placing then
        panel:Hide()
        tab:Hide()
        return
    end
    if FDJ.db.options.dockOpen or Pins.placing then
        panel:Show()
        follow(WorldLayer.MapID())
    else
        panel:Hide()
    end
    anchor()
end

function Dock.Open()
    if not panel then return end
    FDJ.db.options.dockOpen = true
    panel:Show()
    anchor()
    FDJ:Emit("FDJ_DOCK")
end

function Dock.Close()
    if not panel then return end
    FDJ.db.options.dockOpen = false
    panel:Hide()
    anchor()
    FDJ:Emit("FDJ_DOCK")
end

function Dock.Init()
    if panel or not WorldMapFrame then return end
    WorldLayer.Init()
    FDJ.InstanceMap.Init()
    build()
    Dock.Apply()
end
