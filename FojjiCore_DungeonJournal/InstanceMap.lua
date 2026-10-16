local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Routes = FDJ.Routes
local Pins = FDJ.Pins

local InstanceMap = {}
FDJ.InstanceMap = InstanceMap

local frame, chart, pick, toggle, chooser, title, cover, routesBtn, rbar, hintStrip
local routeMode = false
local chartMode = false
local editWidgets = {}
local tools = {}
local hidden = false
local dungeon
local chosen
local openMap
local openedAt = 0
local worldOnce = false

local function dungeonMenu(anchor, current, onPick)
    local items = {}
    local here = FDJ.CurrentDungeon()
    if here then
        items[#items + 1] = { text = L.DUNGEON_HERE:format(FDJ.DungeonTitle(here)), onClick = function() onPick(here) end }
    end
    local family
    for _, d in ipairs(FDJ.Dungeons) do
        if d.family ~= family and d.family then items[#items + 1] = { text = d.family, title = true } end
        family = d.family
        items[#items + 1] = {
            text = (d.family and "  " or "") .. (FDJ.IsEnemyDungeon(d) and FDJ.Paint("dim", d.name) or d.name) .. "  " .. FDJ.Paint(FDJ.RangeColor(d), d.range[1] .. "-" .. d.range[2]),
            checked = d == current,
            onClick = function() onPick(d) end,
        }
    end
    Kit.Menu(anchor, items, 240)
end
InstanceMap.Menu = dungeonMenu

local function guessFloor(d)
    for _, boss in ipairs(d.bosses) do
        if not boss.rare and not FDJ.Runs.Killed(boss) then return boss.f end
    end
    return 1
end

local function syncTools()
    if not frame then return end
    local route = chart.route
    pick:SetLabel(route and route.name or L.NO_ROUTE)
    pick.label:SetTone(route and C.text or C.muted)
    for key, b in pairs(tools) do b:SetActive(chart.tool == key or (key == "view" and not chart:Editing())) end
    tools.undo:SetEnabled(Routes.CanUndo(route))
    local c = chart.brushColor and FDJ.RouteColors[chart.brushColor] or (route and Routes.Color(route)) or C.accent
    frame.ink.glyph:SetVertexColor(c[1], c[2], c[3], 1)
    for _, w in ipairs(editWidgets) do w:SetShown(chartMode) end
    if not frame.float then return end
    frame.bar:SetShown(chartMode)
    frame.float:SetShown(not chartMode)
    frame.holder:ClearAllPoints()
    if chartMode then
        frame.holder:SetPoint("TOPLEFT", frame.bar, "BOTTOMLEFT", 10, -10)
    else
        frame.holder:SetPoint("TOPLEFT", 10, -10)
    end
    frame.holder:SetPoint("BOTTOMRIGHT", -10, 10)
    if frame.routesToggle then
        frame.routesToggle:SetLabel(chartMode and L.DONE or L.ROUTES)
        frame.routesToggle:SetActive(chartMode)
    end
    if frame.routeName then
        frame.routeName:SetShown(not chartMode and route ~= nil)
        frame.routeName:SetText(route and (FDJ.Paint("dim", L.SHOWING .. "  ") .. route.name) or "")
    end
end

local function ensureRoute()
    if chart.route then return chart.route end
    local route = Routes.Create("chart", dungeon.key, FDJ.RouteTitle(L.ROUTE_DEFAULT, FDJ.DungeonTitle(dungeon)))
    chart:SetRoute(route)
    return route
end

local function build()
    local scroll = WorldMapFrame.ScrollContainer
    frame = FDJ.NewFrame("Frame", "FojjiCoreDungeonInstanceMap", WorldMapFrame)
    frame:SetAllPoints(scroll)
    frame:SetFrameLevel(9900)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function() end)
    Kit.Fill(frame, C.frame, 0.98)

    local bar = FDJ.NewFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(40)
    Kit.Fill(bar, C.header, 0.96)
    Kit.Line(bar, "BOTTOM", C.borderDim)
    frame.bar = bar

    local nav = WorldMapFrame.NavBar
    cover = FDJ.NewFrame("Frame", nil, WorldMapFrame)
    if nav then
        cover:SetAllPoints(nav)
        cover:SetFrameLevel(nav:GetFrameLevel() + 20)
    else
        cover:SetPoint("BOTTOMLEFT", scroll, "TOPLEFT", 0, 2)
        cover:SetPoint("BOTTOMRIGHT", scroll, "TOPRIGHT", -60, 2)
        cover:SetHeight(30)
        cover:SetFrameLevel(scroll:GetFrameLevel() + 400)
    end
    cover:EnableMouse(true)
    Kit.Fill(cover, C.header, 1)
    local icon = cover:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 10, 0)
    Kit.Logo(icon)
    local titleBtn = FDJ.NewFrame("Button", nil, cover)
    titleBtn:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    titleBtn:SetHeight(26)
    titleBtn.hl = Kit.Fill(titleBtn, C.white, 0, "BACKGROUND")
    title = Kit.Text(titleBtn, "large", C.white)
    title:SetPoint("LEFT", 4, 0)
    local caret = Kit.Glyph(titleBtn, "fc:icon-chevron-down", 14, C.muted)
    caret:SetPoint("LEFT", title, "RIGHT", 6, -1)
    titleBtn:SetScript("OnEnter", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0.05)
        caret:SetVertexColor(RGB(C.accent))
        Kit.Tip(self, L.CHOOSE_DUNGEON, nil, "ANCHOR_BOTTOM")
    end)
    titleBtn:SetScript("OnLeave", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0)
        caret:SetVertexColor(RGB(C.muted))
        Kit.HideTip()
    end)
    titleBtn:SetScript("OnClick", function(self)
        dungeonMenu(self, dungeon, function(d) InstanceMap.ShowDungeon(d) end)
    end)
    cover.titleBtn = titleBtn
    cover:Hide()

    local hide = Kit.Button(bar, L.GAME_MAP, nil, 26, function()
        hidden = true
        InstanceMap.Update()
    end, nil, "fc:icon-chevron-down")
    hide:SetPoint("RIGHT", -10, 0)
    hide.tip = L.GAME_MAP_TIP
    local journal = Kit.IconButton(bar, "ui-book", 28, L.OPEN_JOURNAL, function() FDJ.Journal.Open(dungeon or nil, "map") end)
    journal:SetPoint("RIGHT", hide, "LEFT", -8, 0)

    local function tool(key, glyph, tip)
        local b = Kit.IconButton(bar, glyph, 28, tip, function(self)
            if not dungeon then return end
            if key == "undo" then
                Routes.Undo(chart.route)
                return
            end
            if key ~= "view" then ensureRoute() end
            if key == "mark" then
                local items = {}
                for _, m in ipairs(Routes.Stamps) do
                    items[#items + 1] = {
                        text = Routes.MarkIcon(m, 14) .. "  " .. (L["MARK_" .. m.key:upper()] or m.key),
                        checked = chart.markKind == m.key,
                        onClick = function()
                            chart.markKind = m.key
                            chart:SetTool("mark")
                        end,
                    }
                end
                Kit.Menu(self, items, 180)
                return
            end
            chart:SetTool(chart.tool == key and "view" or key)
        end)
        tools[key] = b
        return b
    end
    local share = Kit.IconButton(bar, "ui-party", 28, L.SHARE_ROUTE_TIP, function()
        if chart.route then Routes.Share(chart.route) else FDJ.Print(L.NO_ROUTE_TO_SHARE) end
    end)
    local routesToggle = Kit.Button(bar, L.ROUTES, nil, 26, function()
        chartMode = not chartMode
        if not chartMode then chart:SetTool("view") end
        syncTools()
    end, nil, "ui-route")
    routesToggle:SetPoint("RIGHT", journal, "LEFT", -8, 0)
    routesToggle.tip = L.DUNGEON_ROUTES_TIP
    frame.routesToggle = routesToggle
    share:SetPoint("RIGHT", routesToggle, "LEFT", -14, 0)
    local export = Kit.IconButton(bar, "fc:icon-export", 28, L.EXPORT_TIP, function()
        if chart.route then FDJ.RouteList.Export(chart.route) end
    end)
    export:SetPoint("RIGHT", share, "LEFT", -2, 0)
    tools.share, tools.export = nil, nil
    local width = Kit.IconButton(bar, "ui-dot", 28, L.BRUSH_SIZE, function(self)
        chart.brush = chart.brush % #Routes.Widths + 1
        local size = 8 + (chart.brush - 1) * 4
        self.glyph:SetSize(size, size)
    end)
    width:SetPoint("RIGHT", export, "LEFT", -14, 0)
    local inkBtn = Kit.IconButton(bar, "ui-dot", 28, L.INK_COLOR, function(self)
        local items = { { text = L.INK_ROUTE, checked = chart.brushColor == nil, onClick = function()
            chart.brushColor, chart.markColor = nil, nil
            syncTools()
        end } }
        for i, c in ipairs(FDJ.RouteColors) do
            items[#items + 1] = { text = FDJ.Paint(c, L.INK_N:format(i)), checked = chart.brushColor == i, onClick = function()
                chart.brushColor, chart.markColor = i, i
                syncTools()
            end }
        end
        Kit.Menu(self, items, 150)
    end)
    inkBtn:SetPoint("RIGHT", width, "LEFT", -2, 0)
    inkBtn.keepColor = true
    frame.ink = inkBtn
    tool("undo", "ui-undo", L.UNDO_TIP):SetPoint("RIGHT", inkBtn, "LEFT", -10, 0)
    tool("erase", "ui-eraser", L.TOOL_ERASE):SetPoint("RIGHT", tools.undo, "LEFT", -8, 0)
    tool("text", "fc:icon-font", L.TOOL_TEXT):SetPoint("RIGHT", tools.erase, "LEFT", -2, 0)
    tool("mark", "ui-stamp", L.TOOL_MARK):SetPoint("RIGHT", tools.text, "LEFT", -2, 0)
    tool("stops", "ui-route", L.TOOL_STOPS):SetPoint("RIGHT", tools.mark, "LEFT", -2, 0)
    tool("draw", "ui-brush", L.TOOL_DRAW):SetPoint("RIGHT", tools.stops, "LEFT", -2, 0)
    tool("view", "ui-cursor", L.TOOL_VIEW):SetPoint("RIGHT", tools.draw, "LEFT", -2, 0)

    pick = Kit.Button(bar, L.NO_ROUTE, nil, 28, nil, nil, "fc:icon-chevron-down")
    pick:SetPoint("LEFT", bar, "LEFT", 46, 0)
    pick:SetPoint("RIGHT", tools.view, "LEFT", -10, 0)
    for _, w in ipairs({ pick, share, export, width, inkBtn }) do editWidgets[#editWidgets + 1] = w end
    for _, b in pairs(tools) do editWidgets[#editWidgets + 1] = b end
    frame.routeName = Kit.Text(bar, "small", C.text)
    frame.routeName:SetPoint("LEFT", 46, 0)
    frame.routeName:SetPoint("RIGHT", routesToggle, "LEFT", -10, 0)
    frame.routeName:SetWordWrap(false)
    pick.label:SetJustifyH("LEFT")
    pick:SetScript("OnClick", function(_, button)
        if not dungeon then return end
        if button == "RightButton" and chart.route then
            FDJ.RouteList.Rename(chart.route)
            return
        end
        local items = { { text = L.ROUTES, title = true }, { text = L.NO_ROUTE, checked = chart.route == nil, onClick = function()
            chart:SetRoute(nil)
            syncTools()
        end } }
        for _, route in ipairs(Routes.ForChart(dungeon)) do
            items[#items + 1] = { text = route.name, checked = chart.route == route, color = Routes.Color(route), onClick = function()
                chart:SetRoute(route)
                syncTools()
            end }
        end
        if chart.route then
            items[#items + 1] = { text = L.RENAME_DOTS, color = C.accent, onClick = function() FDJ.RouteList.Rename(chart.route) end }
        end
        items[#items + 1] = { text = L.NEW_ROUTE_DOTS, color = C.accent, onClick = function()
            Kit.Prompt(L.NAME_ROUTE, FDJ.RouteTitle(L.ROUTE_DEFAULT, FDJ.DungeonTitle(dungeon)), function(text)
                local route = Routes.Create("chart", dungeon.key, text ~= "" and text or nil)
                chart:SetRoute(route)
                chart:SetTool("draw")
                syncTools()
            end)
        end }
        Kit.Menu(pick, items, 220)
    end)
    pick.tip = L.ROUTE_PICK_TIP

    local holder = FDJ.NewFrame("Frame", nil, frame)
    frame.holder = holder
    holder:SetPoint("TOPLEFT", 10, -10)
    holder:SetPoint("BOTTOMRIGHT", -10, 10)
    chart = FDJ.Chart.New(holder, 800)
    chart.brush = FDJ.opt.brush or 2
    chart.view:SetPoint("CENTER")
    chart.onTool = syncTools
    chart.onBossClick = function(boss) FDJ.Journal.Open(boss.dungeon, "overview", boss) end
    holder:SetScript("OnSizeChanged", function(_, w, h) chart:Resize(w, h) end)

    local float = FDJ.NewFrame("Frame", nil, frame)
    float:SetPoint("TOPRIGHT", -10, -10)
    float:SetSize(260, 30)
    float:SetFrameLevel(frame:GetFrameLevel() + 30)
    local worldBtn = Kit.Button(float, L.GAME_MAP, nil, 30, function()
        hidden = true
        InstanceMap.Update()
    end, "primary", "ui-waypoint")
    chart.onRightClick = function()
        hidden = true
        InstanceMap.Update()
    end
    worldBtn:SetPoint("RIGHT", 0, 0)
    worldBtn.tip = L.GAME_MAP_TIP
    Kit.Fill(worldBtn, C.header, 0.96, "BACKGROUND", -8)
    local editBtn = Kit.IconButton(float, "ui-route", 30, L.ROUTES, function()
        chartMode = true
        syncTools()
    end)
    editBtn.tipBody = L.DUNGEON_ROUTES_TIP
    editBtn:SetPoint("RIGHT", worldBtn, "LEFT", -6, 0)
    Kit.Fill(editBtn, C.header, 0.96, "BACKGROUND", -8)
    frame.float = float

    chooser = Kit.IconButton(WorldMapFrame, "fc:icon-chevron-down", 30, L.CHOOSE_DUNGEON, function(self)
        dungeonMenu(self, dungeon or chosen, function(d) InstanceMap.ShowDungeon(d) end)
    end)
    local nativeDrop = Addon.Native and chooser.nativeArrow
    chooser:SetFrameLevel(nativeDrop and 9952 or 9950)
    if nativeDrop then
        chooser:SetSize(28, 28)
        chooser:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -10, -9)
    else
        chooser:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -10, -5)
        Kit.Fill(chooser, C.header, 0.96)
        Kit.Edge(chooser, C.border)
    end
    chooser:Hide()
    toggle = Kit.Button(WorldMapFrame, L.DUNGEON_MAP, nil, nativeDrop and 26 or 30, function(self)
        local d = FDJ.CurrentDungeon() or chosen or (FDJ.Dock and FDJ.Dock.Dungeon and FDJ.Dock.Dungeon())
        if d then
            InstanceMap.ShowDungeon(d)
        else
            dungeonMenu(self, nil, function(pickd) InstanceMap.ShowDungeon(pickd) end)
        end
    end, "primary", "ui-layers")
    toggle:SetFrameLevel(9950)
    toggle.tip = L.DUNGEON_MAP_TIP
    if nativeDrop then
        toggle:SetPoint("RIGHT", chooser, "LEFT", -3, 0)
    else
        toggle:SetPoint("RIGHT", chooser, "LEFT", -2, 0)
        Kit.Fill(toggle, C.header, 0.96, "BACKGROUND", -8)
    end
    toggle:Hide()
    routesBtn = Kit.Button(WorldMapFrame, L.ROUTES, nil, 30, function() InstanceMap.RouteMode(true) end, nil, "ui-route")
    routesBtn:SetFrameLevel(9950)
    routesBtn:SetPoint("RIGHT", toggle, "LEFT", -6, 0)
    routesBtn.tip = L.ROUTES_WORLD_BTN_TIP
    Kit.Fill(routesBtn, C.header, 0.96, "BACKGROUND", -8)
    routesBtn:Hide()
    InstanceMap.BuildRouteBar(scroll)

    FDJ:On("FDJ_ROUTES", function() if frame:IsVisible() then syncTools() end end)
end

local BAR_TOOLS = {
    { "view", "ui-cursor", "TOOL_VIEW" },
    { "draw", "ui-brush", "TOOL_DRAW" },
    { "stops", "ui-route", "TOOL_STOPS" },
    { "mark", "ui-stamp", "TOOL_MARK" },
    { "text", "fc:icon-font", "TOOL_TEXT" },
    { "erase", "ui-eraser", "TOOL_ERASE" },
}

local function layerTool()
    local Layer = FDJ.WorldLayer
    if not (Layer.editing and Layer.route) then return "view" end
    return Layer.tool
end

local function ensureWorldRoute()
    local Layer = FDJ.WorldLayer
    if Layer.route and Layer.route.scope == "world" then return Layer.route end
    local mapID = Layer.MapID()
    local route = Routes.Create("world", nil, FDJ.RouteTitle(L.WORLD_ROUTE_DEFAULT, FDJ.MapName(mapID)))
    Layer.ShowRoute(route, false)
    return route
end

local function useTool(key)
    local Layer = FDJ.WorldLayer
    if key == "view" then
        Layer.StopEditing()
        return
    end
    local route = ensureWorldRoute()
    Layer.route = route
    Layer.editing = true
    Layer.SetTool(key)
end

local function routePicker(anchor)
    local Layer = FDJ.WorldLayer
    local shown = Layer.route
    local items = { { text = L.ROUTES_WORLD, title = true } }
    items[#items + 1] = { text = L.NO_ROUTE, checked = shown == nil, onClick = function() Layer.ShowRoute(nil) end }
    for _, route in ipairs(Routes.World()) do
        items[#items + 1] = {
            text = route.name .. FDJ.Paint("dim", "  " .. Routes.Where(route)),
            checked = shown == route,
            color = Routes.Color(route),
            onClick = function() Layer.ShowRoute(route, false) end,
        }
    end
    items[#items + 1] = { text = L.NEW_ROUTE_DOTS, color = C.accent, onClick = function()
        local mapID = Layer.MapID()
        Kit.Prompt(L.NAME_ROUTE, FDJ.RouteTitle(L.WORLD_ROUTE_DEFAULT, FDJ.MapName(mapID)), function(text)
            local route = Routes.Create("world", nil, text ~= "" and text or nil)
            Layer.ShowRoute(route, true)
            Layer.SetTool("draw")
        end)
    end }
    if shown then
        items[#items + 1] = { text = L.RENAME_DOTS, color = C.accent, onClick = function() FDJ.RouteList.Rename(shown) end }
    end
    items[#items + 1] = { text = L.IMPORT_DOTS, color = C.accent, onClick = function()
        FDJ.RouteList.ImportDialog(function(route)
            if route.scope == "world" then Layer.ShowRoute(route, false) end
        end)
    end }
    items[#items + 1] = { text = L.ROUTES_MANAGE, color = C.accent, onClick = function() FDJ.OpenWorldRoutes() end }
    Kit.Menu(anchor, items, 240)
end

function InstanceMap.BuildRouteBar(scroll)
    local Layer = FDJ.WorldLayer
    rbar = FDJ.NewFrame("Frame", "FojjiCoreWorldRouteBar", WorldMapFrame)
    rbar:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    rbar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    rbar:SetHeight(40)
    rbar:SetFrameLevel(9950)
    rbar:EnableMouse(true)
    Kit.Fill(rbar, C.header, 0.96)
    Kit.Line(rbar, "BOTTOM", C.borderDim)

    local pickBtn = Kit.Button(rbar, L.NO_ROUTE, 180, 28)
    pickBtn:SetPoint("LEFT", 46, 0)
    pickBtn.label:ClearAllPoints()
    pickBtn.label:SetPoint("LEFT", 22, 0)
    pickBtn.label:SetPoint("RIGHT", -22, 0)
    pickBtn.label:SetJustifyH("LEFT")
    pickBtn.swatch = pickBtn:CreateTexture(nil, "ARTWORK")
    pickBtn.swatch:SetSize(8, 8)
    pickBtn.swatch:SetPoint("LEFT", 8, 0)
    local caret = Kit.Glyph(pickBtn, "fc:icon-chevron-down", 12, C.muted)
    caret:SetPoint("RIGHT", -8, 0)
    pickBtn:SetScript("OnClick", function(self) routePicker(self) end)
    pickBtn.tip = L.ROUTE_PICK_TIP
    rbar.pick = pickBtn

    rbar.tools = {}
    local prev = pickBtn
    for _, def in ipairs(BAR_TOOLS) do
        local key = def[1]
        local b = Kit.IconButton(rbar, def[2], 28, L[def[3]], function(self)
            if key == "mark" then
                local items = {}
                for _, m in ipairs(Routes.Stamps) do
                    items[#items + 1] = {
                        text = Routes.MarkIcon(m, 14) .. "  " .. (L["MARK_" .. m.key:upper()] or m.key),
                        checked = Layer.markKind == m.key,
                        onClick = function()
                            Layer.markKind = m.key
                            useTool("mark")
                        end,
                    }
                end
                Kit.Menu(self, items, 170)
                return
            end
            useTool(key)
        end)
        b:SetPoint("LEFT", prev, "RIGHT", prev == pickBtn and 10 or 3, 0)
        rbar.tools[key] = b
        prev = b
    end
    rbar.width = Kit.IconButton(rbar, "ui-dot", 28, L.BRUSH_SIZE, function()
        Layer.brush = Layer.brush % #Routes.Widths + 1
        InstanceMap.SyncRouteBar()
    end)
    rbar.width:SetPoint("LEFT", prev, "RIGHT", 10, 0)
    rbar.ink = FDJ.NewFrame("Button", nil, rbar)
    rbar.ink:SetSize(28, 28)
    rbar.ink:SetPoint("LEFT", rbar.width, "RIGHT", 3, 0)
    Kit.Fill(rbar.ink, C.raised)
    Kit.Edge(rbar.ink, C.edge)
    rbar.ink.swatch = rbar.ink:CreateTexture(nil, "ARTWORK")
    rbar.ink.swatch:SetPoint("TOPLEFT", 6, -6)
    rbar.ink.swatch:SetPoint("BOTTOMRIGHT", -6, 6)
    rbar.ink:SetScript("OnEnter", function(self) Kit.Tip(self, L.INK_COLOR, L.INK_COLOR_TIP) end)
    rbar.ink:SetScript("OnLeave", Kit.HideTip)
    rbar.ink:SetScript("OnClick", function(self)
        local items = { { text = L.INK_ROUTE, checked = Layer.brushColor == nil, onClick = function()
            Layer.brushColor = nil
            InstanceMap.SyncRouteBar()
        end } }
        for i, c in ipairs(FDJ.RouteColors) do
            items[#items + 1] = { text = FDJ.Paint(c, L.INK_N:format(i)), checked = Layer.brushColor == i, onClick = function()
                Layer.brushColor = i
                InstanceMap.SyncRouteBar()
            end }
        end
        Kit.Menu(self, items, 150)
    end)
    rbar.undo = Kit.IconButton(rbar, "ui-undo", 28, L.UNDO_TIP, function() Routes.Undo(Layer.route) end)
    rbar.undo:SetPoint("LEFT", rbar.ink, "RIGHT", 10, 0)

    rbar.close = Kit.Button(rbar, L.DONE, 70, 28, function()
        if Pins.placing then Pins.StopPlacing() return end
        InstanceMap.RouteMode(false)
    end)
    rbar.close:SetPoint("RIGHT", -10, 0)
    rbar.share = Kit.IconButton(rbar, "ui-party", 28, L.SHARE_ROUTE_TIP, function() if Layer.route then Routes.Share(Layer.route) end end)
    rbar.share:SetPoint("RIGHT", rbar.close, "LEFT", -8, 0)
    rbar.export = Kit.IconButton(rbar, "fc:icon-export", 28, L.EXPORT_TIP, function() if Layer.route then FDJ.RouteList.Export(Layer.route) end end)
    rbar.export:SetPoint("RIGHT", rbar.share, "LEFT", -3, 0)

    rbar.note = Kit.Text(rbar, "small", C.text)
    rbar.note:SetPoint("LEFT", 46, 0)
    rbar.note:SetPoint("RIGHT", rbar.close, "LEFT", -10, 0)
    rbar.note:SetWordWrap(false)
    rbar:Hide()

    hintStrip = FDJ.NewFrame("Frame", nil, WorldMapFrame)
    hintStrip:SetPoint("BOTTOMLEFT", scroll, "BOTTOMLEFT", 8, 8)
    hintStrip:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -8, 8)
    hintStrip:SetHeight(22)
    hintStrip:SetFrameLevel(9950)
    Kit.Fill(hintStrip, C.shadow, 0.65)
    hintStrip.text = Kit.Text(hintStrip, "tiny", C.text, "CENTER")
    hintStrip.text:SetPoint("LEFT", 8, 0)
    hintStrip.text:SetPoint("RIGHT", -8, 0)
    hintStrip:Hide()

    for _, event in ipairs({ "FDJ_WORLD_REFRESH", "FDJ_ROUTES", "FDJ_PLACING" }) do
        FDJ:On(event, function() InstanceMap.SyncRouteBar() end)
    end
    FDJ.WatchFrame(WorldMapFrame, nil, function()
        if routeMode then
            routeMode = false
            Layer.StopEditing()
        end
    end)
end

function InstanceMap.SyncRouteBar()
    if not rbar then return end
    local Layer = FDJ.WorldLayer
    local dungeonOpen = frame and frame:IsShown()
    local placing = Pins.placing
    local show = not dungeonOpen and (routeMode or placing ~= nil)
    rbar:SetShown(show and true or false)
    if not show then
        hintStrip:Hide()
        return
    end
    local route = Layer.route
    local tool = layerTool()
    local building = not placing
    rbar.pick:SetShown(building)
    for key, b in pairs(rbar.tools) do
        b:SetShown(building)
        b:SetActive(tool == key)
    end
    rbar.width:SetShown(building)
    rbar.ink:SetShown(building)
    rbar.undo:SetShown(building)
    rbar.share:SetShown(building)
    rbar.export:SetShown(building)
    rbar.note:SetShown(not building)
    if placing then
        rbar.note:SetText(L.PLACING_BAR:format(FDJ.Q(FDJ.Quests.Title(placing))))
        rbar.close:SetLabel(L.CANCEL)
        hintStrip:Hide()
        return
    end
    rbar.close:SetLabel(L.DONE)
    rbar.pick:SetLabel(route and route.name or L.NO_ROUTE)
    rbar.pick.label:SetTextColor(RGB(route and C.text or C.muted))
    rbar.pick.swatch:SetColorTexture(RGB(route and Routes.Color(route) or C.dim))
    rbar.undo:SetEnabled(Routes.CanUndo(route))
    rbar.share:SetEnabled(route ~= nil)
    rbar.export:SetEnabled(route ~= nil)
    local size = 8 + (Layer.brush - 1) * 4
    rbar.width.glyph:ClearAllPoints()
    rbar.width.glyph:SetPoint("CENTER")
    rbar.width.glyph:SetSize(size, size)
    rbar.ink.swatch:SetColorTexture(RGB(Layer.brushColor and FDJ.RouteColors[Layer.brushColor] or (route and Routes.Color(route)) or C.accent))
    local hint
    if tool ~= "view" then
        hint = L["WORLD_" .. tool:upper()]
        if not Layer.Editable(Layer.MapID()) then hint = FDJ.Paint("warn", L.ZOOM_TO_ZONE) end
    elseif not route then
        hint = L.ROUTE_MODE_HINT
    end
    hintStrip.text:SetText(hint or "")
    hintStrip:SetShown(hint ~= nil)
end

function InstanceMap.RouteMode(on)
    if not frame then build() end
    routeMode = on and true or false
    if not routeMode then FDJ.WorldLayer.StopEditing() end
    InstanceMap.Update()
end

function InstanceMap.InRouteMode()
    return routeMode
end

function InstanceMap.ShowDungeon(d)
    if not d then return end
    chosen = d
    hidden = false
    openMap = WorldMapFrame:GetMapID()
    openedAt = GetTime()
    if FDJ.Dock and FDJ.Dock.SetDungeon then
        FDJ.Dock.SetDungeon(d, true)
        if FDJ:Option("dock") and FDJ.Dock.Open then FDJ.Dock.Open() end
    end
    InstanceMap.Update()
end

function InstanceMap.Update()
    if FDJ.off then
        if frame then
            frame:Hide()
            toggle:Hide()
            chooser:Hide()
            routesBtn:Hide()
            if rbar then rbar:Hide() end
            if hintStrip then hintStrip:Hide() end
            InstanceMap.Cover(false)
        end
        return
    end
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    if not frame then build() end
    local here = FDJ:Option("instanceMap") and FDJ.CurrentDungeon() or nil
    local d = chosen or here
    if not d then
        frame:Hide()
        toggle:SetShown(not routeMode and FDJ:Option("mapButton") ~= false)
        chooser:SetShown(not routeMode and FDJ:Option("mapButton") ~= false)
        routesBtn:SetShown(not routeMode and FDJ:Option("routesButton") ~= false)
        InstanceMap.SyncRouteBar()
        InstanceMap.Cover(false)
        if FDJ.WorldLayer and FDJ.WorldLayer.Refresh then FDJ.WorldLayer.Refresh() end
        dungeon = nil
        return
    end
    if dungeon ~= d then
        dungeon = d
        hidden = false
        chart:SetRoute(nil)
        chart:SetDungeon(d, guessFloor(d))
        local list = Routes.ForChart(d)
        if #list > 0 then chart:SetRoute(list[1]) end
    end
    title:SetText(FDJ.DungeonTitle(d))
    if cover.titleBtn then cover.titleBtn:SetWidth(title:GetStringWidth() + 30) end
    frame:SetShown(not hidden)
    if not hidden and routeMode then routeMode = false end
    toggle:SetShown(hidden and not routeMode and FDJ:Option("mapButton") ~= false)
    chooser:SetShown(hidden and not routeMode and FDJ:Option("mapButton") ~= false)
    routesBtn:SetShown(hidden and not routeMode and FDJ:Option("routesButton") ~= false)
    InstanceMap.SyncRouteBar()
    if FDJ.WorldLayer and FDJ.WorldLayer.Refresh then FDJ.WorldLayer.Refresh() end
    InstanceMap.Cover(not hidden)
    if not hidden then
        chart:Draw()
        syncTools()
    end
end

function InstanceMap.ShowWorld()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if frame and frame:IsShown() then
            hidden = true
            InstanceMap.Update()
        end
    else
        worldOnce = true
    end
end

local function raiseCover()
    local top = cover:GetFrameLevel()
    local function consider(f)
        if f and f.GetFrameLevel and f ~= cover and f ~= frame and f ~= toggle then
            local lv = f:GetFrameLevel()
            if lv >= top then top = lv + 1 end
        end
    end
    for _, f in ipairs(WorldMapFrame.overlayFrames or {}) do consider(f) end
    for _, f in ipairs({ WorldMapFrame:GetChildren() }) do
        local name = f.GetName and f:GetName()
        if not (name and name:find("^FojjiCore")) and f ~= WorldMapFrame.ScrollContainer and f ~= WorldMapFrame.BorderFrame then consider(f) end
    end
    if top > cover:GetFrameLevel() then cover:SetFrameLevel(math.min(top + 5, 9000)) end
end

function InstanceMap.Cover(on)
    if not cover then return end
    if on then raiseCover() end
    cover:SetShown(on)
    local nav = WorldMapFrame.NavBar
    if nav then nav:SetAlpha(on and 0 or 1) end
end

function InstanceMap.Init()
    if not WorldMapFrame then return end
    FDJ.WatchFrame(WorldMapFrame, function()
        hidden = worldOnce
        worldOnce = false
        local here = FDJ:Option("instanceMap") and FDJ.CurrentDungeon() or nil
        if here then
            chosen = nil
        elseif chosen then
            hidden = true
        end
        openMap = WorldMapFrame:GetMapID()
        openedAt = GetTime()
        InstanceMap.Update()
    end)
    do
        FDJ.OnMapChanged(function()
            if not frame or not frame:IsShown() or not dungeon then return end
            local mapID = WorldMapFrame:GetMapID()
            if GetTime() - openedAt < 0.6 then
                openMap = mapID
                return
            end
            if openMap and mapID ~= openMap then
                hidden = true
                InstanceMap.Update()
            end
        end)
    end
    local function refresh()
        if WorldMapFrame:IsShown() then InstanceMap.Update() end
    end
    FDJ:On("FDJ_ENTERED", refresh)
    FDJ:On("ZONE_CHANGED_NEW_AREA", refresh)
    FDJ:On("FDJ_OPTION", function(key) if key == "instanceMap" or key == "mapButton" or key == "routesButton" then refresh() end end)
end
