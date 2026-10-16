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
local Book = FDJ.QuestBook

local WorldLayer = {}
FDJ.WorldLayer = WorldLayer

WorldLayer.tool = "stops"
WorldLayer.markKind = "flag"
WorldLayer.brush = 2

local child, layer, catcher
local questPins, handles, marks, entrancePins
local pen, livePen
local seenScale, seenMap, seenW
local project

function WorldLayer.MapID()
    return WorldMapFrame and WorldMapFrame:GetMapID()
end

local function editableMap(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    if not info or not Enum or not Enum.UIMapType then return info ~= nil end
    return info.mapType >= Enum.UIMapType.Continent
end
WorldLayer.Editable = editableMap

local projCache = setmetatable({}, { __mode = "k" })
local function strokeOn(st, mapID)
    if st.m == mapID then return { st.p } end
    local cache = projCache[st]
    local key = mapID .. ":" .. #st.p
    if cache and cache[key] then return cache[key] end
    local pieces, cur = {}, nil
    for i = 1, #st.p - 1, 2 do
        local x, y = project(st.m, st.p[i], st.p[i + 1], mapID)
        if x then
            if not cur then
                cur = {}
                pieces[#pieces + 1] = cur
            end
            cur[#cur + 1] = x
            cur[#cur + 1] = y
        else
            cur = nil
        end
    end
    for i = #pieces, 1, -1 do
        if #pieces[i] < 4 then table.remove(pieces, i) end
    end
    projCache[st] = { [key] = pieces }
    return pieces
end

project = function(m, x, y, target)
    if m == target then return x, y end
    if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, continent, worldPos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if not ok or not continent or not worldPos then return nil end
    local ok2, mapID, pos = pcall(C_Map.GetMapPosFromWorldPos, continent, worldPos, target)
    if not ok2 or mapID ~= target or not pos then return nil end
    local px, py = FDJ.XY(pos)
    if not px or px < 0 or px > 1 or py < 0 or py > 1 then return nil end
    return px, py
end
WorldLayer.Project = project

local function cursorNormalized()
    local x, y = GetCursorPosition()
    local s = child:GetEffectiveScale()
    local left, top = child:GetLeft(), child:GetTop()
    if not left then return nil end
    return (x / s - left) / child:GetWidth(), (top - y / s) / child:GetHeight()
end

local placed = setmetatable({}, { __mode = "k" })
local function place(frame, x, y)
    local a = frame.wlAnchor
    if not a then
        a = FDJ.NewFrame("Frame", nil, child)
        a:SetSize(1, 1)
        frame.wlAnchor = a
    end
    a:ClearAllPoints()
    a:SetPoint("CENTER", child, "TOPLEFT", x * child:GetWidth(), -y * child:GetHeight())
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", a, "CENTER")
    frame:SetScale(1 / child:GetScale())
    placed[frame] = true
end

local function editing()
    return WorldLayer.editing and WorldLayer.route ~= nil
end

local function makeQuestPin()
    local pin = FDJ.NewFrame("Button", nil, layer)
    pin:SetSize(22, 22)
    pin:SetFrameLevel(layer:GetFrameLevel() + 5)
    pin.glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glow:SetPoint("CENTER")
    pin.glow:SetSize(34, 34)
    pin.glow:SetTexture(FDJ.Glyph("fc:glow-soft"))
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetScript("OnEnter", function(self)
        local qid = self.qid
        local q = Book[qid]
        local body = {}
        local home = FDJ.QuestHome[qid]
        if home then body[#body + 1] = { L.DUNGEON, FDJ.DungeonTitle(home[1]) } end
        local step = Quests.Step(qid)
        if step then
            body[#body + 1] = { L.CHAIN_NEXT:format(step.index, step.count), Quests.StepTitle(step) }
            body[#body + 1] = { L.GIVER, Quests.StepWhere(step) }
        elseif q.by then body[#body + 1] = { L.GIVER, q.by } end
        body[#body + 1] = { L.STATUS, Quests.StatusText(Quests.Status(qid), qid) }
        local has, lacks = FDJ.Party.Holders(qid)
        if #has > 0 then body[#body + 1] = { L.REPORT_HAVE, table.concat(has, ", "), C.info } end
        if #lacks > 0 then body[#body + 1] = { L.REPORT_NEED, table.concat(lacks, ", "), C.dim } end
        body[#body + 1] = " "
        body[#body + 1] = L.GHOST_HINT
        Kit.Tip(self, Quests.Title(qid), body)
        self.glow:SetVertexColor(Kit.RGB(C.quest, 0.6))
    end)
    pin:SetScript("OnLeave", function(self)
        Kit.HideTip()
        self.glow:SetVertexColor(Kit.RGB(C.quest, 0.25))
    end)
    pin:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Pins.BeginPlacing(self.qid)
        else
            Pins.Pin(self.qid, true)
        end
    end)
    return pin
end

local function dungeonIcon(tex)
    if tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Dungeon") then
        tex:SetAtlas("Dungeon")
    else
        tex:SetTexture("Interface\\Minimap\\Dungeon")
    end
end

local function makeEntrance()
    local pin = FDJ.NewFrame("Button", nil, layer)
    pin:SetSize(26, 26)
    pin:SetFrameLevel(layer:GetFrameLevel() + 4)
    pin.glow = pin:CreateTexture(nil, "BACKGROUND")
    pin.glow:SetPoint("CENTER")
    pin.glow:SetSize(40, 40)
    pin.glow:SetTexture(FDJ.Glyph("fc:glow-soft"))
    pin.glow:SetVertexColor(1, 1, 1, 0)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    dungeonIcon(pin.icon)
    pin:RegisterForClicks("LeftButtonUp")
    pin:SetScript("OnEnter", function(self)
        self.glow:SetVertexColor(1, 0.85, 0.5, 0.5)
        local list = self.dungeons
        if not list then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local first = list[1]
        GameTooltip:SetText(#list > 1 and (first.family or FDJ.DungeonTitle(first)) or FDJ.DungeonTitle(first), 1, 1, 1)
        for _, d in ipairs(list) do
            local c = FDJ.RangeColor(d)
            c = type(c) == "string" and FDJ.Colors[c] or c
            local label = #list > 1 and d.name or L.LEVELS
            GameTooltip:AddDoubleLine(label, d.range[1] .. "-" .. d.range[2], 0.85, 0.86, 0.9, c[1], c[2], c[3])
        end
        local side = FDJ.FactionTag and FDJ.FactionTag(first)
        if side then GameTooltip:AddLine(side) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(#list > 1 and L.ENTRANCE_PICK or L.ENTRANCE_HINT, Kit.RGB(C.muted))
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function(self)
        self.glow:SetVertexColor(1, 1, 1, 0)
        Kit.HideTip()
    end)
    pin:SetScript("OnClick", function(self)
        local list = self.dungeons
        if not list then return end
        if #list == 1 then
            FDJ.InstanceMap.ShowDungeon(list[1])
            return
        end
        local items = { { text = list[1].family or L.CHOOSE_DUNGEON, title = true } }
        for _, d in ipairs(list) do
            items[#items + 1] = {
                text = d.name .. "  " .. FDJ.Paint(FDJ.RangeColor(d), d.range[1] .. "-" .. d.range[2]),
                onClick = function() FDJ.InstanceMap.ShowDungeon(d) end,
            }
        end
        Kit.Menu(self, items, 200)
    end)
    return pin
end

local function makeHandle()
    local h = FDJ.NewFrame("Button", nil, layer)
    h:SetSize(18, 18)
    h:SetFrameLevel(layer:GetFrameLevel() + 10)
    h.ring = h:CreateTexture(nil, "BACKGROUND")
    h.ring:SetAllPoints()
    h.ring:SetTexture(FDJ.Glyph("ui-dot"))
    h.dot = h:CreateTexture(nil, "ARTWORK")
    h.dot:SetPoint("TOPLEFT", 2, -2)
    h.dot:SetPoint("BOTTOMRIGHT", -2, 2)
    h.dot:SetTexture(FDJ.Glyph("ui-dot"))
    h.num = Kit.Text(h, "tiny", C.shadow, "CENTER")
    h.num:SetShadowOffset(0, 0)
    h.num:SetPoint("CENTER", 0, 0)
    h.label = Kit.Pill(h)
    h.label:SetPoint("LEFT", h, "RIGHT", 4, 0)
    h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnEnter", function(self)
        local route = WorldLayer.route
        local p = route and route.points[self.index]
        if not p then return end
        local body = {}
        if p.label then body[#body + 1] = p.label end
        body[#body + 1] = ("%s %.1f, %.1f"):format(FDJ.MapName(p.m), p.x * 100, p.y * 100)
        body[#body + 1] = editing() and L.HANDLE_HINT or L.WORLD_HANDLE_HINT
        Kit.Tip(self, L.STOP_N:format(self.index), body)
    end)
    h:SetScript("OnLeave", Kit.HideTip)
    h:SetScript("OnClick", function(self, button)
        local route = WorldLayer.route
        if not route then return end
        local p = route.points[self.index]
        if editing() and self.native then
            if button == "RightButton" or WorldLayer.tool == "erase" then
                Routes.Remove(route, self.index)
                WorldLayer.selected = nil
            elseif IsShiftKeyDown() then
                Kit.Prompt(L.LABEL_STOP:format(self.index), p and p.label or "", function(text) Routes.Label(route, self.index, text) end)
            else
                WorldLayer.selected = WorldLayer.selected ~= self.index and self.index or nil
                WorldLayer.Refresh()
            end
        elseif p then
            if button == "RightButton" then
                Pins.OpenMap(p.m)
            else
                Routes.Follow(route, self.index)
            end
        end
    end)
    h:SetScript("OnDragStart", function(self)
        if not (editing() and self.native) or WorldLayer.tool == "erase" then return end
        self.dragging = true
        self:SetScript("OnUpdate", function(me)
            local x, y = cursorNormalized()
            if x then place(me, FDJ.Clamp(x, 0, 1), FDJ.Clamp(y, 0, 1)) end
        end)
    end)
    h:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        local x, y = cursorNormalized()
        if x then Routes.Move(WorldLayer.route, self.index, x, y) end
    end)
    return h
end

local function makeMark()
    local b = FDJ.NewFrame("Button", nil, layer)
    b:SetSize(24, 24)
    b:SetFrameLevel(layer:GetFrameLevel() + 8)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.label = Kit.Pill(b)
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
    Kit.MarkText(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnEnter", function(self)
        local mk = WorldLayer.route and WorldLayer.route.marks[self.index]
        if mk then Kit.Tip(self, mk.label or L["MARK_" .. mk.k:upper()] or L.MARKER, editing() and (mk.k == "text" and L.TEXT_HANDLE_HINT or L.MARK_HANDLE_HINT) or nil) end
    end)
    b:SetScript("OnLeave", Kit.HideTip)
    b:SetScript("OnClick", function(self, button)
        local route = WorldLayer.route
        if not route or not editing() then return end
        if WorldLayer.tool == "erase" or button == "RightButton" then
            Routes.RemoveMark(route, self.index)
        elseif IsShiftKeyDown() or WorldLayer.tool == "stops" or WorldLayer.tool == "text" then
            local mk = route.marks[self.index]
            local index = self.index
            if mk and mk.k == "text" then
                Kit.TextEditor({ label = mk.label, c = mk.c, s = mk.s }, function(text, color, size)
                    if not text or text:match("^%s*$") then
                        Routes.RemoveMark(route, index)
                    else
                        Routes.StyleMark(route, index, text, color, size)
                    end
                end, function() Routes.RemoveMark(route, index) end)
                return
            end
            Kit.Prompt(L.LABEL_MARK, mk and mk.label or "", function(text)
                Routes.LabelMark(route, index, text)
            end)
        end
    end)
    b:SetScript("OnDragStart", function(self)
        if not editing() or WorldLayer.tool == "erase" then return end
        self.dragging = true
        self:SetScript("OnUpdate", function(me)
            local x, y = cursorNormalized()
            if x then place(me, FDJ.Clamp(x, 0, 1), FDJ.Clamp(y, 0, 1)) end
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        local x, y = cursorNormalized()
        if x then Routes.MoveMark(WorldLayer.route, self.index, x, y) end
    end)
    return b
end

local function drawRoute(mapID)
    handles:Reset()
    marks:Reset()
    pen:Begin()
    local route = WorldLayer.route
    if route and not FDJ.db.routes[route.id] then
        WorldLayer.route = nil
        WorldLayer.editing = false
        route = nil
    end
    if route and mapID then
        Routes.Normalize(route)
        local w, h, s = child:GetWidth(), child:GetHeight(), child:GetScale()
        local color = Routes.Color(route)
        pen.k = 1 / s
        for _, st in ipairs(route.strokes) do
            for _, piece in ipairs(strokeOn(st, mapID)) do
                pen:Path(piece, w, h, Routes.StrokeColor(route, st), (st.w or 2) / s)
            end
        end
        local spots = {}
        for i, p in ipairs(route.points) do
            local x, y = project(p.m, p.x, p.y, mapID)
            if x then spots[i] = { x = x, y = y, native = p.m == mapID } end
        end
        for i = 2, #route.points do
            local a, b = spots[i - 1], spots[i]
            if a and b then pen:Seg(a.x * w, a.y * h, b.x * w, b.y * h, color, 3.5 / s) end
        end
        for i, p in ipairs(route.points) do
            local spot = spots[i]
            if spot then
                local hd = handles:Get()
                hd.index = i
                hd.native = spot.native
                hd.num:SetText(i)
                hd.label:Set(p.label, color)
                hd.ring:SetVertexColor(RGB(i == WorldLayer.selected and C.text or C.shadow))
                hd.dot:SetVertexColor(RGB(color))
                hd:SetAlpha(spot.native and 1 or 0.7)
                place(hd, spot.x, spot.y)
                hd:EnableMouse(not (editing() and WorldLayer.tool == "draw"))
            end
        end
        for i, mk in ipairs(route.marks) do
            local x, y = project(mk.m, mk.x, mk.y, mapID)
            if x then
                local b = marks:Get()
                b.index = i
                Kit.ShowMark(b, mk, Routes.MarkColor(route, mk))
                place(b, x, y)
                b:EnableMouse(not (editing() and WorldLayer.tool == "draw"))
            end
        end
    end
    pen:End()
end

local function drawLive()
    local stroke = WorldLayer.stroke
    livePen:Begin()
    if stroke and WorldLayer.route then
        local w, h, s = child:GetWidth(), child:GetHeight(), child:GetScale()
        livePen.k = 1 / s
        livePen:Path(stroke.p, w, h, Routes.Color(WorldLayer.route, WorldLayer.brushColor), (Routes.Widths[WorldLayer.brush] or 4) / s)
    end
    livePen:End()
end

local function drawPins(mapID)
    questPins:Reset()
    if not mapID then return end
    local d = FDJ.Dock and FDJ.Dock.Dungeon()
    if not (d and FDJ.Dock.IsOpen()) then return end
    local active = Pins.ActiveQuest()
    for _, qid in ipairs(d.quests) do
        local code = Quests.Status(qid)
        if qid ~= active and (code == "open" or code == "low" or code == "chain") and Quests.Visible(qid) then
            local spot = Quests.Spot(qid)
            local x, y
            if spot then x, y = project(spot.m, spot.x, spot.y, mapID) end
            if x then
                local f = questPins:Get()
                f.qid = qid
                f.icon:SetTexture(Quests.Style.open.icon)
                f.icon:SetDesaturated(code == "low")
                f.glow:SetVertexColor(Kit.RGB(C.quest, 0.25))
                f:SetAlpha(code == "low" and 0.6 or 1)
                place(f, x, y)
            end
        end
    end
end

local function drawEntrances(mapID)
    entrancePins:Reset()
    if not mapID or not FDJ:Option("entrances") then return end
    local info = C_Map.GetMapInfo(mapID)
    if info and Enum and Enum.UIMapType and info.mapType < Enum.UIMapType.Continent then return end
    local seen = {}
    for _, e in ipairs(FDJ.Entrances(mapID)) do
        local x, y = project(e.m, e.x, e.y, mapID)
        local id = x and (math.floor(x * 200) .. ":" .. math.floor(y * 200))
        if x and not seen[id] then
            seen[id] = true
            local list = {}
            for _, k in ipairs(e.keys) do
                local d = FDJ.ByKey[k]
                if d then list[#list + 1] = d end
            end
            if #list > 0 then
                local pin = entrancePins:Get()
                pin.dungeons = list
                local zoneView = info and Enum and Enum.UIMapType and info.mapType >= Enum.UIMapType.Zone
                pin:SetSize(zoneView and 26 or 18, zoneView and 26 or 18)
                place(pin, x, y)
            end
        end
    end
end

local function lift(base)
    if layer.base == base then return end
    layer.base = base
    layer:SetFrameLevel(base)
    catcher:SetFrameLevel(base - 1)
    for _, kids in ipairs({ { entrancePins, 4 }, { questPins, 5 }, { handles, 10 }, { marks, 8 } }) do
        for _, list in ipairs({ kids[1].used, kids[1].spare }) do
            for _, f in ipairs(list) do f:SetFrameLevel(base + kids[2]) end
        end
    end
end

local function syncCatcher(mapID)
    local placing = Pins.placing ~= nil
    local active = (placing or editing()) and editableMap(mapID)
    lift(9800)
    local cover = _G.FojjiCoreDungeonInstanceMap
    layer:SetShown(not (cover and cover:IsShown()))
    catcher:SetShown(active and true or false)
    if active and not FDJ.InCombat() and catcher.SetPropagateMouseClicks then
        local passive = placing or WorldLayer.tool == "stops"
        if catcher.passive ~= passive then
            catcher.passive = passive
            catcher:SetPropagateMouseClicks(passive)
        end
    end
end

function WorldLayer.Refresh()
    if FDJ.off then
        if layer then
            layer:Hide()
            catcher:Hide()
        end
        return
    end
    if not layer or not WorldMapFrame:IsShown() then return end
    local mapID = WorldLayer.MapID()
    seenMap, seenScale, seenW = mapID, child:GetScale(), child:GetWidth()
    drawEntrances(mapID)
    drawPins(mapID)
    drawRoute(mapID)
    drawLive()
    syncCatcher(mapID)
    FDJ:Emit("FDJ_WORLD_REFRESH", mapID)
end

function WorldLayer.ShowRoute(route, edit)
    WorldLayer.route = route and Routes.Normalize(route) or nil
    WorldLayer.editing = edit and route ~= nil or false
    WorldLayer.selected = nil
    WorldLayer.Refresh()
end

function WorldLayer.SetTool(tool)
    WorldLayer.tool = tool
    WorldLayer.selected = nil
    WorldLayer.Refresh()
end

function WorldLayer.StopEditing()
    WorldLayer.editing = false
    WorldLayer.selected = nil
    WorldLayer.stroke = nil
    WorldLayer.Refresh()
end

local function onCatcherDown(_, button)
    local x, y = GetCursorPosition()
    catcher.press = { x, y, button }
    local route = WorldLayer.route
    if button ~= "LeftButton" or Pins.placing or not editing() then return end
    local mapID = WorldLayer.MapID()
    if WorldLayer.tool == "draw" then
        local nx, ny = cursorNormalized()
        if not nx then return end
        WorldLayer.stroke = { m = mapID, p = { FDJ.Clamp(nx, 0, 1), FDJ.Clamp(ny, 0, 1) }, lx = x, ly = y }
    end
    local lastErase = 0
    catcher:SetScript("OnUpdate", function()
        local cx, cy = GetCursorPosition()
        local stroke = WorldLayer.stroke
        if stroke then
            if math.abs(cx - stroke.lx) + math.abs(cy - stroke.ly) >= 3 * catcher:GetEffectiveScale() then
                stroke.lx, stroke.ly = cx, cy
                local nx, ny = cursorNormalized()
                if nx then
                    stroke.p[#stroke.p + 1] = FDJ.Clamp(nx, 0, 1)
                    stroke.p[#stroke.p + 1] = FDJ.Clamp(ny, 0, 1)
                    drawLive()
                end
            end
        elseif WorldLayer.tool == "erase" and GetTime() - lastErase > 0.05 then
            lastErase = GetTime()
            local nx, ny = cursorNormalized()
            if nx and route then
                Routes.Erase(route, mapID, nx, ny, 12 / (child:GetHeight() * child:GetScale()), child:GetWidth() / child:GetHeight())
            end
        end
    end)
end

local function onCatcherUp(_, button)
    catcher:SetScript("OnUpdate", nil)
    local press = catcher.press
    catcher.press = nil
    local stroke = WorldLayer.stroke
    WorldLayer.stroke = nil
    if stroke then
        drawLive()
        if #stroke.p >= 6 and WorldLayer.route then
            Routes.AddStroke(WorldLayer.route, stroke.m, stroke.p, Routes.Widths[WorldLayer.brush] or 4, WorldLayer.brushColor)
            return
        end
    end
    if not press then return end
    local cx, cy = GetCursorPosition()
    if math.abs(cx - press[1]) > 4 or math.abs(cy - press[2]) > 4 then return end
    local mapID = WorldLayer.MapID()
    local x, y = cursorNormalized()
    if not x or x < 0 or x > 1 or y < 0 or y > 1 then return end
    if Pins.placing then
        if button == "LeftButton" then
            Pins.Place(mapID, x, y)
        else
            Pins.StopPlacing()
        end
        return
    end
    if button == "RightButton" then
        local info = C_Map.GetMapInfo(mapID)
        local parent = info and info.parentMapID
        if parent and parent > 0 then
            if WorldMapFrame.NavigateToParentMap then WorldMapFrame:NavigateToParentMap() else WorldMapFrame:SetMapID(parent) end
        end
        return
    end
    local route = WorldLayer.route
    if not (editing() and route and button == "LeftButton") then return end
    local tool = WorldLayer.tool
    local info = C_Map.GetMapInfo(mapID)
    local zoneLevel = info and Enum and Enum.UIMapType and info.mapType >= Enum.UIMapType.Zone
    if tool == "draw" or tool == "erase" or not zoneLevel then
        local under = C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(mapID, x, y)
        if under and under.mapID and under.mapID ~= mapID then
            WorldMapFrame:SetMapID(under.mapID)
            return
        end
        if tool == "draw" then return end
    end
    if tool == "stops" then
        local index = Routes.Add(route, mapID, x, y, WorldLayer.selected)
        if index and WorldLayer.selected then WorldLayer.selected = index end
    elseif tool == "mark" then
        Routes.AddMark(route, mapID, x, y, WorldLayer.markKind, WorldLayer.brushColor)
    elseif tool == "text" then
        Kit.TextEditor({ c = WorldLayer.brushColor }, function(text, color, size)
            if text and not text:match("^%s*$") then Routes.AddMark(route, mapID, x, y, "text", color, text, size) end
        end)
    elseif tool == "erase" then
        Routes.Erase(route, mapID, x, y, 14 / (child:GetHeight() * child:GetScale()), child:GetWidth() / child:GetHeight())
    end
end

WorldLayer.Place = function(frame, x, y) place(frame, x, y) end
WorldLayer.Cursor = function() return cursorNormalized() end
WorldLayer.Layer = function() return layer end

function WorldLayer.Init()
    if layer or not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    child = WorldMapFrame.ScrollContainer.Child
    if not child then return end
    layer = FDJ.NewFrame("Frame", nil, child)
    layer:SetAllPoints(child)
    layer:SetFrameLevel(math.min(child:GetFrameLevel() + 1200, 9000))

    catcher = FDJ.NewFrame("Frame", nil, child)
    catcher:SetAllPoints(child)
    catcher:SetFrameLevel(layer:GetFrameLevel() - 1)
    catcher:EnableMouse(true)
    if catcher.SetPropagateMouseClicks then
        catcher:SetPropagateMouseClicks(true)
        catcher.passive = true
    end
    if catcher.SetPropagateMouseMotion then catcher:SetPropagateMouseMotion(true) end
    catcher:SetScript("OnMouseDown", onCatcherDown)
    catcher:SetScript("OnMouseUp", onCatcherUp)
    catcher:Hide()

    pen = Kit.Ink(layer)
    livePen = Kit.Ink(layer)
    questPins = Kit.Pool(makeQuestPin)
    entrancePins = Kit.Pool(makeEntrance)
    handles = Kit.Pool(makeHandle)
    marks = Kit.Pool(makeMark)

    local watch, lastScale = 0, nil
    layer:SetScript("OnUpdate", function(_, dt)
        local sc = child:GetScale()
        if sc ~= lastScale then
            lastScale = sc
            local inv = 1 / sc
            for f in pairs(placed) do
                if f:IsShown() then f:SetScale(inv) end
            end
        end
        watch = watch + dt
        if watch < 0.1 then return end
        watch = 0
        if child:GetScale() ~= seenScale or WorldLayer.MapID() ~= seenMap or child:GetWidth() ~= seenW then
            WorldLayer.Refresh()
        end
    end)
    FDJ.WatchFrame(WorldMapFrame, function() WorldLayer.Refresh() end, function()
        if Pins.placing then Pins.StopPlacing() end
        WorldLayer.stroke = nil
    end)
    FDJ:On("FDJ_OPTION", function(key) if key == "entrances" then WorldLayer.Refresh() end end)
    for _, event in ipairs({ "FDJ_PINS", "FDJ_WAYPOINTS", "FDJ_ROUTES", "FDJ_QUESTS", "FDJ_SPOTS", "FDJ_PLACING", "FDJ_PARTY", "FDJ_DOCK" }) do
        FDJ:On(event, function() FDJ.Debounce("worldlayer", 0.05, WorldLayer.Refresh) end)
    end
end
