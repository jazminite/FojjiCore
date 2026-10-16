local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Routes = FDJ.Routes

local RouteList = {}
RouteList.__index = RouteList
FDJ.RouteList = RouteList

function RouteList.Export(route)
    Kit.TextWindow(L.EXPORT_TITLE:format(route.name), Routes.Encode(route), nil, L.EXPORT_HINT)
end

function RouteList.ImportDialog(onDone)
    Kit.TextWindow(L.IMPORT_TITLE, "", function(text)
        local route, err = Routes.Import(text)
        if not route then
            FDJ.Print(Routes.ErrorText(err))
            return false
        end
        FDJ.Print(L.IMPORTED:format(FDJ.Hi(route.name)))
        if onDone then onDone(route) end
        return true
    end, L.IMPORT_HINT)
end

function RouteList.Rename(route)
    if not route then return end
    Kit.Prompt(L.RENAME_ROUTE, route.name, function(text) Routes.Rename(route, text) end)
end

function RouteList.Menu(anchor, route, onOpen)
    local items = {
        { text = route.name, title = true },
        { text = L.VIEW, onClick = function() onOpen(route, false) end },
        { text = L.EDIT, onClick = function() onOpen(route, true) end },
        { text = L.RENAME, onClick = function() RouteList.Rename(route) end },
        { text = L.RECOLOR, onClick = function() Routes.CycleColor(route) end },
        { text = L.REVERSE, onClick = function() Routes.Reverse(route) end },
        { text = L.EXPORT, onClick = function() RouteList.Export(route) end },
        { text = L.SHARE_PARTY, onClick = function() Routes.Share(route) end },
        { text = L.DELETE, color = C.bad, onClick = function()
            Kit.Confirm(L.DELETE_ROUTE:format(route.name), function() Routes.Delete(route) end)
        end },
    }
    if route.scope ~= "chart" and #route.points > 0 then
        table.insert(items, #items, { text = L.FOLLOW_ROUTE, onClick = function() Routes.Follow(route, 1) end })
    end
    Kit.Menu(anchor, items)
end

function RouteList.New(parent, compact, scopes)
    local self = setmetatable({}, RouteList)
    self.compact = compact
    self.scopes = scopes or { "chart", "world" }
    local frame = CreateFrame("Frame", nil, parent)
    self.frame = frame

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(30)
    self.bar = bar
    self.single = #self.scopes == 1
    if self.single then
        bar:SetHeight(1)
    else
        local import = Kit.Button(bar, L.IMPORT, nil, 26, function()
            RouteList.ImportDialog(function(route) if self.onOpen then self.onOpen(route, false) end end)
        end)
        import:SetPoint("RIGHT")
        import.tip = L.IMPORT_TIP
    end

    local scroll = Kit.Scroller(frame)
    scroll:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, self.single and 0 or -6)
    scroll:SetPoint("BOTTOMRIGHT")
    self.scroll = scroll
    self.rows = Kit.Pool(function() return self:MakeRow() end)
    self.sections = {}
    for _, scope in ipairs(self.scopes) do
        self.sections[scope] = self:MakeSection(scope)
    end

    FDJ:On("FDJ_ROUTES", function()
        if frame:IsVisible() then self:Refresh() end
    end)
    FDJ:On("FDJ_WAYPOINTS", function()
        if frame:IsVisible() then self:Refresh() end
    end)
    frame:SetScript("OnShow", function() self:Refresh() end)
    return self
end

function RouteList:SetSource(fn)
    self.source = fn
    self:Refresh()
end

function RouteList:MakeSection(scope)
    local head = CreateFrame("Frame", nil, self.scroll.content)
    head:SetHeight(36)
    local isChart = scope == "chart"
    head.title = Kit.Text(head, "tiny", C.accent)
    head.title:SetPoint("LEFT", 4, 2)
    head.title:SetText((isChart and L.ROUTES_DUNGEON or L.ROUTES_WORLD):upper())
    head.add = Kit.Button(head, isChart and L.NEW_DUNGEON_ROUTE or L.NEW_WORLD_ROUTE, nil, 24, function()
        if self.onCreate then self.onCreate(scope) end
    end, nil, isChart and "ui-layers" or "ui-waypoint")
    head.add:SetPoint("RIGHT", 0, 2)
    head.add.tip = isChart and L.NEW_DUNGEON_TIP or L.NEW_WORLD_TIP
    if self.single then
        head.import = Kit.Button(head, L.IMPORT, nil, 24, function()
            RouteList.ImportDialog(function(route) if self.onOpen then self.onOpen(route, false) end end)
        end)
        head.import:SetPoint("RIGHT", head.add, "LEFT", -6, 0)
        head.import.tip = L.IMPORT_TIP
    end
    head.rule = head:CreateTexture(nil, "ARTWORK")
    head.rule:SetPoint("BOTTOMLEFT", 0, 0)
    head.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    head.rule:SetHeight(1)
    head.rule:SetColorTexture(RGB(C.borderDim))
    head.none = Kit.Text(head, "small", C.muted)
    head.none:SetText(isChart and L.ROUTES_DUNGEON_NONE or L.ROUTES_WORLD_NONE)
    return head
end

local ROW_H = 88

function RouteList:MakeRow()
    local row = Kit.Row(self.scroll.content, ROW_H)
    row.swatch = CreateFrame("Button", nil, row)
    row.swatch:SetSize(4, ROW_H - 18)
    row.swatch:SetPoint("LEFT", 8, 0)
    row.swatch.tex = Kit.Fill(row.swatch, C.accent, 1, "ARTWORK")
    row.swatch:SetScript("OnClick", function() Routes.CycleColor(row.route) end)
    row.swatch:SetScript("OnEnter", function(b) Kit.Tip(b, L.RECOLOR) end)
    row.swatch:SetScript("OnLeave", Kit.HideTip)
    row.name = Kit.Text(row, "normal", C.white)
    row.name:SetPoint("TOPLEFT", 24, -9)
    row.name:SetPoint("RIGHT", -8, 0)
    row.name:SetWordWrap(false)
    row.sub = Kit.Text(row, "small", C.muted)
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -7)

    local function icon(path, tip, fn)
        local b = Kit.IconButton(row, path, 28, tip, function() fn(row.route) end)
        return b
    end
    row.sub:SetPoint("RIGHT", -8, 0)
    row.sub:SetWordWrap(false)
    row.bRename = icon("fc:icon-font", L.RENAME, RouteList.Rename)
    row.bRename:SetPoint("BOTTOMLEFT", 18, 6)
    row.bEdit = icon("ui-brush", L.EDIT, function(r) if self.onOpen then self.onOpen(r, true) end end)
    row.bEdit:SetPoint("LEFT", row.bRename, "RIGHT", 4, 0)
    row.bExport = icon("fc:icon-export", L.EXPORT, RouteList.Export)
    row.bExport:SetPoint("LEFT", row.bEdit, "RIGHT", 4, 0)
    row.bShare = icon("ui-party", L.SHARE_PARTY, function(r) Routes.Share(r) end)
    row.bShare:SetPoint("LEFT", row.bExport, "RIGHT", 4, 0)
    row.bFollow = icon("ui-waypoint", L.FOLLOW_ROUTE_TIP, function(r)
        local current = Routes.Following()
        if current == r then Routes.Unfollow() else Routes.Follow(r, 1) end
    end)
    row.bFollow:SetPoint("LEFT", row.bShare, "RIGHT", 4, 0)
    row:SetScript("OnDoubleClick", function() RouteList.Rename(row.route) end)

    row:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            RouteList.Menu(row, row.route, self.onOpen)
        elseif self.onOpen then
            self.onOpen(row.route, false)
        end
    end)
    return row
end

function FDJ.OpenWorldRoutes()
    if FojjiCore and FojjiCore.ToggleOptions then FojjiCore:ToggleOptions("worldroutes") end
end

function FDJ.NewWorldRoute(mapID)
    if not mapID and WorldMapFrame and WorldMapFrame:IsShown() then mapID = WorldMapFrame:GetMapID() end
    mapID = mapID or (C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
    Kit.Prompt(L.NAME_ROUTE, FDJ.RouteTitle(L.WORLD_ROUTE_DEFAULT, mapID and FDJ.MapName(mapID) or L.WORLD_MAP), function(text)
        local route = Routes.Create("world", nil, text ~= "" and text or nil)
        local core = _G.FojjiCoreOptionsFrame
        if core and core:IsShown() then core:Hide() end
        FDJ.WorldLayer.tool = "draw"
        FDJ.Dock.ShowWorldRoute(route, true, mapID)
        FDJ.Print(L.WORLD_DRAW)
    end)
end

function RouteList:Refresh()
    self.rows:Reset()
    local list = self.source and self.source() or {}
    local groups = { chart = {}, world = {} }
    for _, route in ipairs(list) do
        local g = groups[route.scope == "chart" and "chart" or "world"]
        g[#g + 1] = route
    end
    local y = 0
    for _, scope in ipairs(self.scopes) do
        local head = self.sections[scope]
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", self.scroll.content, "TOPLEFT", 0, -y)
        head:SetPoint("RIGHT", self.scroll.content, "RIGHT")
        head:Show()
        y = y + 40
        local routes = groups[scope]
        head.none:ClearAllPoints()
        head.none:SetShown(#routes == 0)
        if #routes == 0 then
            head.none:SetPoint("TOPLEFT", self.scroll.content, "TOPLEFT", 6, -y - 4)
            y = y + 26
        end
        for _, route in ipairs(routes) do
            local row = self.rows:Get()
            row.route = route
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", self.scroll.content, "RIGHT")
            row.swatch.tex:SetColorTexture(RGB(Routes.Color(route)))
            local picked = self.selected == route
            row.pick = row.pick or Kit.Fill(row, C.accent, 0, "BACKGROUND", 2)
            Kit.Paint(row.pick, C.accent, picked and 0.14 or 0)
            row.name:SetTextColor(RGB(picked and C.accent or C.white))
            row.name:SetText(route.name)
            local bits = { Routes.Where(route), Routes.Summary(route) }
            local yards = Routes.Yards(route)
            if yards and yards > 0 then bits[#bits + 1] = L.YARDS_N:format(math.floor(yards + 0.5)) end
            if route.author and route.author ~= FDJ.PlayerName() then bits[#bits + 1] = L.BY_AUTHOR:format(route.author) end
            row.sub:SetText(table.concat(bits, FDJ.Paint("dim", "   ·   ")))
            row.bFollow:SetShown(route.scope ~= "chart" and #route.points > 0)
            if row.bFollow.SetActive then row.bFollow:SetActive(Routes.Following() == route) end
            y = y + ROW_H
        end
        y = y + 8
    end
    self.scroll:SetContentHeight(y)
end

local function firstMap(route)
    local first = route and (route.points[1] or route.strokes[1] or route.marks[1])
    if not first then return nil end
    local seen, count = {}, 0
    for _, list in ipairs({ route.points, route.strokes, route.marks }) do
        for _, e in ipairs(list) do
            if not seen[e.m] then seen[e.m] = true count = count + 1 end
        end
    end
    if count <= 1 then return first.m end
    local info = C_Map.GetMapInfo(first.m)
    while info and Enum and Enum.UIMapType and info.mapType > Enum.UIMapType.Continent and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    local continents = {}
    for m in pairs(seen) do
        local i = C_Map.GetMapInfo(m)
        while i and Enum and Enum.UIMapType and i.mapType > Enum.UIMapType.Continent and i.parentMapID and i.parentMapID > 0 do
            i = C_Map.GetMapInfo(i.parentMapID)
        end
        if i then continents[i.mapID] = true end
    end
    local n = 0
    for _ in pairs(continents) do n = n + 1 end
    if n > 1 and info and info.parentMapID and info.parentMapID > 0 then return info.parentMapID end
    return info and info.mapID or first.m
end

local function buildPinPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetHeight(204)
    local checks = {}
    local head = CreateFrame("Frame", nil, p)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(36)
    local title = Kit.Text(head, "tiny", C.accent)
    title:SetPoint("LEFT", 4, 2)
    title:SetText(L.PAGE_PINS:upper())
    local info = Kit.IconButton(head, "fc:icon-info", 24, L.WAY_HELP .. "\n\n" .. L.PINS_FOLLOW_HELP)
    info:SetPoint("RIGHT", 0, 2)
    local rule = head:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetHeight(1)
    rule:SetColorTexture(RGB(C.borderDim))

    local grid = {
        { "wpArrow", L.PINS_WP, L.PINS_WP_TIP },
        { "pinArrow", L.PINS_TRACKER, L.PINS_TRACKER_TIP },
        { "minimapPin", L.PINS_MINIMAP, L.PINS_MINIMAP_TIP },
        { "worldPin", L.PINS_WORLD, L.PINS_WORLD_TIP },
        { "worldBeam", L.PINS_BEAM, L.PINS_BEAM_TIP },
        { "mapClick", L.PINS_MAPCLICK_SHORT, L.PINS_MAPCLICK_TIP },
        { "minimapNodes", L.PINS_NODES, L.PINS_NODES_TIP },
    }
    for i, def in ipairs(grid) do
        local key = def[1]
        local c = Kit.Check(p, def[2], function() return FDJ.opt and FDJ.opt[key] end, function(v) FDJ:SetOption(key, v) end, def[3])
        c.col, c.row = (i - 1) % 2, math.floor((i - 1) / 2)
        checks[#checks + 1] = c
    end
    local defs = {
        { L.PINS_PREVIEW_SHORT, function() FDJ.Pins.PreviewArrow() end },
        { L.WP_CLEAR_SHORT, function() if FDJ.WP then FDJ.WP.Clear() end end },
        { L.WAY_PASTE_SHORT, function() if FDJ.Way then FDJ.Way.Paste() end end },
    }
    local btns = {}
    for i, def in ipairs(defs) do btns[i] = Kit.Button(p, def[1], 90, 24, def[2]) end
    local function lay(w)
        local half = math.floor((w - 8) / 2)
        for _, c in ipairs(checks) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 4 + c.col * half, -(48 + c.row * 28))
        end
        local bw = math.floor((w - 12) / 3)
        for i, b in ipairs(btns) do
            b:ClearAllPoints()
            b:SetWidth(bw)
            b:SetPoint("TOPLEFT", (i - 1) * (bw + 6), -168)
        end
    end
    p:SetScript("OnSizeChanged", function(_, w) lay(w) end)
    lay(300)
    p:SetScript("OnShow", function() for _, c in ipairs(checks) do c:Sync() end end)
    for _, c in ipairs(checks) do c:Sync() end
    return p
end

function Addon.CreateWorldRoutesPage(page)
    FDJ.SyncTheme()
    local view = CreateFrame("Frame", nil, page)
    view:SetPoint("TOPLEFT", 0, -54)
    view:SetPoint("BOTTOMRIGHT", 0, 0)

    local side = CreateFrame("Frame", nil, view)
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(300)
    local pinPanel = buildPinPanel(side)
    pinPanel:SetPoint("TOPLEFT")
    pinPanel:SetPoint("TOPRIGHT")
    local list = RouteList.New(side, true, { "world" })
    list.frame:SetPoint("TOPLEFT", pinPanel, "BOTTOMLEFT", 0, -4)
    list.frame:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT")

    local right = CreateFrame("Frame", nil, view)
    right:SetPoint("TOPLEFT", side, "TOPRIGHT", 14, 0)
    right:SetPoint("BOTTOMRIGHT")

    local bar = CreateFrame("Frame", nil, right)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(30)
    local holder = CreateFrame("Frame", nil, right)
    holder:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -8)
    holder:SetPoint("BOTTOMRIGHT")
    local chart = FDJ.Chart.New(holder, 700)
    chart.view:SetPoint("TOP", holder, "TOP", 0, 0)
    chart.brush = FDJ.opt.brush or 2
    chart.viewHint = L.ROUTES_MAP_HINT
    holder:SetScript("OnSizeChanged", function(_, w, h) chart:Resize(w, h) end)

    local zone = Kit.Button(bar, L.WORLD_MAP, 170, 28)
    zone:SetPoint("LEFT")
    zone.label:ClearAllPoints()
    zone.label:SetPoint("LEFT", 10, 0)
    zone.label:SetPoint("RIGHT", -22, 0)
    zone.label:SetJustifyH("LEFT")
    local caret = Kit.Glyph(zone, "fc:icon-chevron-down", 12, C.muted)
    caret:SetPoint("RIGHT", -8, 0)
    zone.tip = L.PICK_ZONE

    local palette
    local tools = {}
    local function sync() end
    local function tool(key, glyph, tip)
        local b = Kit.IconButton(bar, glyph, 28, tip, function()
            if not chart.route then
                FDJ.Print(L.ROUTES_PICK_FIRST)
                return
            end
            if key == "mark" then
                palette = palette or FDJ.MarkPalette(chart, function(kind)
                    chart.markKind = kind
                    chart:SetTool("mark")
                end, view)
                palette:ClearAllPoints()
                palette:SetPoint("TOPLEFT", tools.mark, "BOTTOMLEFT", 0, -4)
                palette:Sync()
                palette:SetShown(not palette:IsShown())
                if chart.tool ~= "mark" then chart:SetTool("mark") end
                return
            end
            if palette then palette:Hide() end
            chart:SetTool(chart.tool == key and "view" or key)
        end)
        tools[key] = b
        return b
    end
    tool("view", "ui-cursor", L.TOOL_VIEW):SetPoint("LEFT", zone, "RIGHT", 10, 0)
    tool("draw", "ui-brush", L.TOOL_DRAW):SetPoint("LEFT", tools.view, "RIGHT", 3, 0)
    tool("stops", "ui-route", L.TOOL_STOPS):SetPoint("LEFT", tools.draw, "RIGHT", 3, 0)
    tool("mark", "ui-stamp", L.TOOL_MARK):SetPoint("LEFT", tools.stops, "RIGHT", 3, 0)
    tool("text", "fc:icon-font", L.TOOL_TEXT):SetPoint("LEFT", tools.mark, "RIGHT", 3, 0)
    tool("erase", "ui-eraser", L.TOOL_ERASE):SetPoint("LEFT", tools.text, "RIGHT", 3, 0)
    local undo = Kit.IconButton(bar, "ui-undo", 28, L.UNDO_TIP, function() if chart.route then Routes.Undo(chart.route) end end)
    undo:SetPoint("LEFT", tools.erase, "RIGHT", 10, 0)
    local ink = CreateFrame("Button", nil, bar)
    ink:SetSize(28, 28)
    ink:SetPoint("LEFT", undo, "RIGHT", 3, 0)
    Kit.Fill(ink, C.raised)
    Kit.Edge(ink, C.edge)
    ink.swatch = ink:CreateTexture(nil, "ARTWORK")
    ink.swatch:SetPoint("TOPLEFT", 6, -6)
    ink.swatch:SetPoint("BOTTOMRIGHT", -6, 6)
    ink:SetScript("OnEnter", function(self) Kit.Tip(self, L.INK_COLOR, L.INK_COLOR_TIP) end)
    ink:SetScript("OnLeave", Kit.HideTip)
    ink:SetScript("OnClick", function(self)
        local items = { { text = L.INK_ROUTE, checked = chart.brushColor == nil, onClick = function()
            chart.brushColor, chart.markColor = nil, nil
            sync()
        end } }
        for i, c in ipairs(FDJ.RouteColors) do
            items[#items + 1] = { text = FDJ.Paint(c, L.INK_N:format(i)), checked = chart.brushColor == i, onClick = function()
                chart.brushColor, chart.markColor = i, i
                sync()
            end }
        end
        Kit.Menu(self, items, 150)
    end)
    local onMap = Kit.Button(bar, L.SHOW_ON_MAP, nil, 28, function()
        if not chart.route then return end
        local core = _G.FojjiCoreOptionsFrame
        if core and core:IsShown() then core:Hide() end
        FDJ.Dock.ShowWorldRoute(chart.route, false, chart:ChartID())
    end, nil, "ui-waypoint")
    onMap:SetPoint("RIGHT")
    onMap.tip = L.SHOW_ON_MAP_TIP

    sync = function()
        local route = chart.route
        for key, b in pairs(tools) do
            b:SetActive(chart.tool == key or (key == "view" and not chart:Editing()))
            b:SetEnabled(route ~= nil)
        end
        undo:SetEnabled(Routes.CanUndo(route))
        onMap:SetEnabled(route ~= nil)
        zone:SetLabel(FDJ.MapName(chart:ChartID()))
        ink.swatch:SetColorTexture(RGB(chart.brushColor and FDJ.RouteColors[chart.brushColor] or (route and Routes.Color(route)) or C.accent))
    end
    chart.onTool = sync

    local function showZone(mapID)
        if not mapID then return end
        chart:SetWorldMap(mapID)
        FDJ.db.worldRoutesZone = mapID
        sync()
    end

    zone:SetScript("OnClick", function(self)
        local items = {}
        local worldID
        for _, group in ipairs(FDJ.ZoneList()) do
            local ci = group.id and C_Map.GetMapInfo(group.id)
            if ci and ci.parentMapID and ci.parentMapID > 0 then worldID = ci.parentMapID break end
        end
        if worldID and FDJ.ChartTiles(worldID) then
            items[#items + 1] = { text = FDJ.MapName(worldID), checked = chart:ChartID() == worldID, color = C.accent, onClick = function() showZone(worldID) end }
        end
        for _, group in ipairs(FDJ.ZoneList()) do
            items[#items + 1] = { text = group.name, title = true }
            if group.id then
                items[#items + 1] = { text = L.WHOLE_CONTINENT:format(group.name), checked = chart:ChartID() == group.id, color = C.accent, onClick = function() showZone(group.id) end }
            end
            for _, z in ipairs(group.zones) do
                items[#items + 1] = { text = z.name, checked = chart:ChartID() == z.id, onClick = function() showZone(z.id) end }
            end
        end
        Kit.Menu(self, items, 200)
    end)

    local MAPTYPE = Enum and Enum.UIMapType or {}
    local function canShow(id)
        local info = id and C_Map.GetMapInfo(id)
        if not info then return false end
        if MAPTYPE.World and info.mapType < MAPTYPE.World then return false end
        return FDJ.ChartTiles(id) ~= nil
    end
    local function childAt(fx, fy)
        local current = chart:ChartID()
        if not (current and C_Map.GetMapInfoAtPosition) then return nil end
        local ok, info = pcall(C_Map.GetMapInfoAtPosition, current, fx, fy)
        if not ok or not info or info.mapID == current then return nil end
        if MAPTYPE.Zone and info.mapType ~= MAPTYPE.Zone and info.mapType ~= MAPTYPE.Continent then return nil end
        if not canShow(info.mapID) then return nil end
        return info
    end
    chart.onMapClick = function(button, fx, fy, editing)
        if button == "RightButton" then
            if chart.zoom > 1 then return false end
            local info = C_Map.GetMapInfo(chart:ChartID() or 0)
            local parent = info and info.parentMapID
            if parent and parent > 0 and canShow(parent) then
                showZone(parent)
                return true
            end
            return false
        end
        if editing or button ~= "LeftButton" then return false end
        local child = childAt(fx, fy)
        if child then
            showZone(child.mapID)
            return true
        end
        return false
    end

    local where = CreateFrame("Frame", nil, holder)
    where:SetHeight(22)
    where:SetFrameLevel(chart.view:GetFrameLevel() + 60)
    Kit.Fill(where, C.shadow, 0.7)
    where.text = Kit.Text(where, "small", C.white)
    where.text:SetPoint("LEFT", 8, 0)
    where:SetPoint("TOPLEFT", chart.view, "TOPLEFT", 6, -6)
    where:Hide()
    local coords = CreateFrame("Frame", nil, holder)
    coords:SetSize(96, 22)
    coords:SetFrameLevel(chart.view:GetFrameLevel() + 60)
    coords:SetPoint("BOTTOMRIGHT", chart.view, "BOTTOMRIGHT", -6, 32)
    Kit.Fill(coords, C.shadow, 0.7)
    coords.text = Kit.Text(coords, "small", C.white, "CENTER")
    coords.text:SetPoint("CENTER")
    coords:Hide()
    local lastHover = 0
    holder:SetScript("OnUpdate", function()
        if GetTime() - lastHover < 0.05 then return end
        lastHover = GetTime()
        if not chart.view:IsMouseOver() then
            where:Hide()
            coords:Hide()
            return
        end
        local x, y = GetCursorPosition()
        local c = chart.canvas
        local sc = c:GetEffectiveScale()
        local l, t = c:GetLeft(), c:GetTop()
        if not l then return end
        local fx, fy = (x / sc - l) / c:GetWidth(), (t - y / sc) / c:GetHeight()
        if fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1 then
            coords.text:SetText(("%.1f, %.1f"):format(fx * 100, fy * 100))
            coords:Show()
        else
            coords:Hide()
        end
        local child = not chart:Editing() and childAt(fx, fy)
        if child then
            where.text:SetText(child.name .. FDJ.Paint("dim", "   " .. L.CLICK_TO_OPEN))
            where:SetWidth(where.text:GetStringWidth() + 16)
            where:Show()
        else
            where:Hide()
        end
    end)

    local function select(route, edit)
        if route and route == chart.route and not edit then route = nil end
        list.selected = route
        list:Refresh()
        chart:SetRoute(route)
        if not route then
            chart:SetTool("view")
            sync()
            return
        end
        local m = firstMap(route)
        if m and m ~= chart:ChartID() then showZone(m) end
        if edit then chart:SetTool("draw") end
        sync()
    end
    list.onOpen = select
    list.onCreate = function()
        local mapID = chart:ChartID()
        Kit.Prompt(L.NAME_ROUTE, FDJ.RouteTitle(L.WORLD_ROUTE_DEFAULT, FDJ.MapName(mapID)), function(text)
            local route = Routes.Create("world", nil, text ~= "" and text or nil)
            select(route, true)
        end)
    end
    list:SetSource(Routes.World)

    view:SetScript("OnShow", function()
        list:Refresh()
        if not chart:ChartID() then
            local start = FDJ.db.worldRoutesZone
            if not (start and C_Map.GetMapInfo(start)) then
                start = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
                while start and FDJ.WorldLayer.Editable and not FDJ.WorldLayer.Editable(start) do
                    local info = C_Map.GetMapInfo(start)
                    start = info and info.parentMapID ~= 0 and info.parentMapID or nil
                end
            end
            showZone(start or 1413)
        else
            chart:Draw()
            sync()
        end
    end)
    view:SetScript("OnHide", function() if palette then palette:Hide() end end)
    FDJ:On("FDJ_ROUTES", function() if view:IsVisible() then sync() end end)
    return view
end
