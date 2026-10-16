local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local Routes = FDJ.Routes
local RGB = Kit.RGB

local ART_W, ART_H, TILE = 1002, 668, 256
local RATIO = ART_W / ART_H
local MAX_ZOOM = 6
local SAMPLE = 3

local Chart = {}
Chart.__index = Chart
FDJ.Chart = Chart

local function cursorIn(frame)
    local x, y = GetCursorPosition()
    local s = frame:GetEffectiveScale()
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left then return 0.5, 0.5 end
    return (x / s - left) / frame:GetWidth(), (top - y / s) / frame:GetHeight()
end
Chart.CursorIn = cursorIn

local function arrow(parent, texture, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    b:SetNormalTexture(texture .. "-Up")
    b:SetPushedTexture(texture .. "-Down")
    b:SetDisabledTexture(texture .. "-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", onClick)
    return b
end

function Chart.New(parent, width)
    local self = setmetatable({}, Chart)
    self.w = width
    self.h = math.floor(width / RATIO + 0.5)
    self.zoom, self.offX, self.offY = 1, 0, 0
    self.floor = 1
    self.tool = "view"
    self.markKind = "skull"
    self.brush = 2

    local view = CreateFrame("Frame", nil, parent)
    view:SetSize(self.w, self.h)
    view:SetClipsChildren(true)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    Kit.Fill(view, C.shadow)
    self.view = view

    local canvas = CreateFrame("Frame", nil, view)
    canvas:SetPoint("TOPLEFT")
    canvas:SetSize(self.w, self.h)
    self.canvas = canvas

    local art = CreateFrame("Frame", nil, canvas)
    art:SetAllPoints(canvas)
    art:SetClipsChildren(true)
    self.art = art
    self.tiles = {}

    local ink = CreateFrame("Frame", nil, canvas)
    ink:SetAllPoints(canvas)
    ink:SetFrameLevel(art:GetFrameLevel() + 2)
    self.ink = ink
    self.pen = Kit.Ink(ink)
    self.livePen = Kit.Ink(ink)

    self.bossPins = Kit.Pool(function() return self:MakeBossPin() end)
    self.handles = Kit.Pool(function() return self:MakeHandle() end)
    self.markPins = Kit.Pool(function() return self:MakeMark() end)

    local hud = CreateFrame("Frame", nil, view)
    hud:SetAllPoints(view)
    hud:SetFrameLevel(canvas:GetFrameLevel() + 40)
    self.hud = hud

    local plate = CreateFrame("Frame", nil, hud)
    plate:SetPoint("TOPLEFT", 6, -6)
    plate:SetHeight(26)
    Kit.Fill(plate, C.shadow, 0.6)
    Kit.Edge(plate, C.edge)
    self.prev = arrow(plate, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage", function() self:SetFloor(self.floor - 1) end)
    self.prev:SetPoint("LEFT", 2, 0)
    self.floorText = Kit.Text(plate, "small", C.text)
    self.floorText:SetPoint("LEFT", self.prev, "RIGHT", 2, 0)
    self.next = arrow(plate, "Interface\\Buttons\\UI-SpellbookIcon-NextPage", function() self:SetFloor(self.floor + 1) end)
    self.next:SetPoint("LEFT", self.floorText, "RIGHT", 2, 0)
    self.plate = plate

    local zoomIn = Kit.IconButton(hud, "fc:icon-plus", 26, L.ZOOM_IN, function() self:ZoomAt(1.4, 0.5, 0.5) end, "ghost")
    zoomIn:SetPoint("TOPRIGHT", -6, -6)
    local zoomOut = Kit.IconButton(hud, "fc:icon-minus", 26, L.ZOOM_OUT, function() self:ZoomAt(1 / 1.4, 0.5, 0.5) end, "ghost")
    zoomOut:SetPoint("TOP", zoomIn, "BOTTOM", 0, -4)
    local fit = Kit.IconButton(hud, "ui-expand", 26, L.ZOOM_FIT, function() self:ResetView() end, "ghost")
    fit:SetPoint("TOP", zoomOut, "BOTTOM", 0, -4)
    zoomIn:Hide(); zoomOut:Hide(); fit:Hide()

    local hint = CreateFrame("Frame", nil, hud)
    hint:SetPoint("BOTTOMLEFT", 6, 6)
    hint:SetPoint("BOTTOMRIGHT", -6, 6)
    hint:SetHeight(20)
    Kit.Fill(hint, C.shadow, 0.6)
    hint.text = Kit.Text(hint, "tiny", C.muted, "CENTER")
    hint.text:SetPoint("LEFT", 6, 0)
    hint.text:SetPoint("RIGHT", -6, 0)
    hint:Hide()
    self.hint = hint

    local empty = Kit.Text(hud, "normal", C.muted, "CENTER")
    empty:SetPoint("CENTER")
    empty:SetText(L.NO_MAP)
    empty:Hide()
    self.empty = empty

    view:SetScript("OnMouseWheel", function(_, delta)
        local fx, fy = cursorIn(canvas)
        self:ZoomAt(delta > 0 and 1.25 or 0.8, fx, fy)
    end)
    view:SetScript("OnMouseDown", function(_, button) self:PressStart(button) end)
    view:SetScript("OnMouseUp", function(_, button) self:PressEnd(button) end)
    view:SetScript("OnHide", function() self:PressCancel() end)
    local function redraw()
        if view:IsVisible() then self:Draw() end
    end
    FDJ:On("FDJ_ROUTES", redraw)
    FDJ:On("FDJ_KILLS", redraw)
    return self
end

function Chart:Resize(availW, availH)
    local w = math.floor(math.min(availW, availH * RATIO))
    if w < 100 then return end
    local h = math.floor(w / RATIO + 0.5)
    if w == self.w and h == self.h then return end
    local fx = (-self.offX + self.w / 2) / (self.w * self.zoom)
    local fy = (self.offY + self.h / 2) / (self.h * self.zoom)
    self.w, self.h = w, h
    self.view:SetSize(w, h)
    self.offX = self.w / 2 - fx * self.w * self.zoom
    self.offY = fy * self.h * self.zoom - self.h / 2
    self:Layout()
end

function Chart:ChartID()
    if self.worldMap then return self.worldMap end
    local d = self.dungeon
    local f = d and d.floors[self.floor]
    return f and f[1]
end

function Chart:SetWorldMap(mapID)
    self.worldMap = mapID
    self.dungeon = nil
    self.floor = 1
    self.focusBoss = nil
    self.selected = nil
    self:ResetView()
end

function Chart:SetDungeon(d, floor)
    self.worldMap = nil
    if self.dungeon ~= d then
        self.dungeon = d
        self.focusBoss = nil
        self.selected = nil
    end
    self.floor = FDJ.Clamp(floor or self.floor or 1, 1, d and #d.floors or 1)
    self:ResetView()
end

function Chart:SetFloor(index)
    local d = self.dungeon
    if not d then return end
    index = FDJ.Clamp(index, 1, #d.floors)
    if index == self.floor then return end
    self.floor = index
    self.selected = nil
    self:ResetView()
    if self.onFloor then self.onFloor(index) end
end

function Chart:FloorOfChart(chartID)
    for i, f in ipairs(self.dungeon and self.dungeon.floors or {}) do
        if f[1] == chartID then return i end
    end
    return nil
end

function Chart:SetRoute(route)
    if self.route ~= route then self.selected = nil end
    self.route = route and Routes.Normalize(route) or nil
    if not route then self.tool = "view" end
    self:Draw()
end

function Chart:SetTool(tool)
    self.tool = tool or "view"
    self.selected = nil
    self:PressCancel()
    self:Draw()
    if self.onTool then self.onTool(self.tool) end
end

function Chart:Editing()
    return self.route ~= nil and self.tool ~= "view"
end

function Chart:SetEditing(on)
    self:SetTool(on and (self.tool ~= "view" and self.tool or "draw") or "view")
end

function Chart:FocusBoss(boss)
    self.focusBoss = boss
    if boss and boss.f ~= self.floor then
        self.floor = boss.f
        self:ResetView()
    else
        self:Draw()
    end
end

function Chart:ResetView()
    self.zoom, self.offX, self.offY = 1, 0, 0
    self:Layout()
end

function Chart:ClampOffsets()
    local w, h, z = self.w, self.h, self.zoom
    self.offX = FDJ.Clamp(self.offX, w - w * z, 0)
    self.offY = FDJ.Clamp(self.offY, 0, h * z - h)
end

function Chart:ZoomAt(factor, fx, fy)
    local z = self.zoom
    local nz = FDJ.Clamp(z * factor, 1, MAX_ZOOM)
    if nz == z then return end
    local vx = self.offX + fx * self.w * z
    local vy = fy * self.h * z - self.offY
    self.zoom = nz
    self.offX = vx - fx * self.w * nz
    self.offY = fy * self.h * nz - vy
    self:Layout()
end

function Chart:Place()
    self:ClampOffsets()
    self.canvas:ClearAllPoints()
    self.canvas:SetPoint("TOPLEFT", self.view, "TOPLEFT", self.offX, self.offY)
end

function Chart:Layout()
    self:ClampOffsets()
    self.canvas:SetSize(self.w * self.zoom, self.h * self.zoom)
    self:Place()
    self:DrawTiles()
    self:Draw()
end

function Chart:DrawTiles()
    for _, tex in ipairs(self.tiles) do tex:Hide() end
    local chartID = self:ChartID()
    local list, info = FDJ.ChartTiles(chartID or 0)
    self.empty:SetShown(list == nil)
    if not list then return end
    if info.image then
        local tex = self.tiles[1]
        if not tex then
            tex = self.art:CreateTexture(nil, "ARTWORK")
            self.tiles[1] = tex
        end
        tex:SetTexture(info.image, nil, nil, "TRILINEAR")
        tex:SetTexCoord(0, 1, 0, info.bottom or 1)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", self.art, "TOPLEFT", 0, 0)
        tex:SetSize(self.w * self.zoom, self.h * self.zoom)
        tex:Show()
        return
    end
    local cols = info.wide or 4
    local size = TILE * (self.w * self.zoom / ART_W) * (info.zoom or 1)
    local sx, sy = info.shiftX or 0, info.shiftY or 0
    for i, file in ipairs(list) do
        local tex = self.tiles[i]
        if not tex then
            tex = self.art:CreateTexture(nil, "ARTWORK")
            self.tiles[i] = tex
        end
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        tex:SetTexture(file, nil, nil, "TRILINEAR")
        tex:SetSize(size + 0.5, size + 0.5)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", self.art, "TOPLEFT", (col - sx) * size, -(row - sy) * size)
        tex:Show()
    end
end

local HINTS = {
    stops = "EDIT_HINT",
    draw = "DRAW_HINT",
    mark = "MARK_HINT",
    text = "TEXT_HINT",
    erase = "ERASE_HINT",
}

function Chart:Hud()
    local d = self.dungeon
    local count = d and #d.floors or 1
    self.floorText:SetText(d and FDJ.FloorLabel(d, self.floor) or "")
    self.plate:SetWidth(self.floorText:GetStringWidth() + 54)
    self.prev:SetEnabled(self.floor > 1)
    self.next:SetEnabled(self.floor < count)
    self.plate:SetShown(count > 1)
    local hint = self:Editing() and HINTS[self.tool]
    if hint then
        self.hint.text:SetText(L[hint])
        self.hint:Show()
    elseif self.worldMap and self.viewHint then
        self.hint.text:SetText(self.viewHint)
        self.hint:Show()
    else
        self.hint:Hide()
    end
end

local function placeAt(frame, parent, x, y, cw, ch)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "TOPLEFT", x * cw, -y * ch)
end

function Chart:MakeBossPin()
    local pin = CreateFrame("Button", nil, self.canvas)
    pin:SetSize(30, 30)
    pin:SetFrameLevel(self.ink:GetFrameLevel() + 4)
    pin.portrait = Kit.Portrait(pin, 30)
    pin.portrait:SetAllPoints()
    pin.portrait:EnableMouse(false)
    local badge = CreateFrame("Frame", nil, pin)
    badge:SetSize(15, 13)
    badge:SetPoint("BOTTOMRIGHT", 5, -3)
    badge:SetFrameLevel(pin:GetFrameLevel() + 8)
    Kit.Fill(badge, C.shadow, 0.85)
    Kit.Edge(badge, C.amber)
    badge.text = Kit.Text(badge, "tiny", C.amber, "CENTER")
    badge.text:SetPoint("CENTER", 0, 0)
    pin.badge = badge
    pin.level = pin:CreateFontString(nil, "OVERLAY")
    pin.level:SetFont(FDJ.Font(), 10, "OUTLINE")
    pin.level:SetShadowColor(0, 0, 0, 1)
    pin.level:SetShadowOffset(1, -1)
    pin.level:SetPoint("BOTTOM", pin, "TOP", 0, 2)
    pin.check = pin:CreateTexture(nil, "OVERLAY")
    pin.check:SetSize(16, 16)
    pin.check:SetPoint("TOPRIGHT", 5, 4)
    pin.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    pin.name = Kit.Pill(pin)
    pin.name:SetPoint("TOP", pin, "BOTTOM", 0, -4)
    pin.name:Hide()
    pin:RegisterForClicks("LeftButtonUp")
    pin:SetScript("OnEnter", function(p)
        local boss = p.boss
        local body = {}
        if boss.lv then body[#body + 1] = { L.LEVEL, tostring(boss.lv) } end
        body[#body + 1] = { L.LOOT, tostring(#boss.loot) }
        if FDJ.Runs.Killed(boss) then body[#body + 1] = L.KILLED_THIS_RUN end
        body[#body + 1] = L.CLICK_BOSS
        Kit.Tip(p, boss.n, body)
        p.portrait.ring:SetVertexColor(RGB(C.accent))
        p.name:Set(boss.n, C.accent)
    end)
    pin:SetScript("OnLeave", function(p)
        Kit.HideTip()
        p.portrait.ring:SetVertexColor(RGB(p.boss == self.focusBoss and C.amber or C.edge))
        if p.boss ~= self.focusBoss then p.name:Hide() end
    end)
    pin:SetScript("OnClick", function(p)
        if self.onBossClick then self.onBossClick(p.boss) end
    end)
    return pin
end

function Chart:DrawBosses(cw, ch)
    self.bossPins:Reset()
    local d = self.dungeon
    if not d then return end
    local quiet = self:Editing()
    for _, boss in ipairs(d.bosses) do
        if boss.f == self.floor and boss.at then
            local pin = self.bossPins:Get()
            pin.boss = boss
            pin.portrait:SetCreature(boss.face, boss.icon)
            local dead = FDJ.Runs.Killed(boss)
            pin.portrait.face:SetDesaturated(dead)
            pin.check:SetShown(dead)
            pin.badge.text:SetText(boss.index)
            if boss.lv then
                pin.level:SetText("Lv " .. boss.lv)
                local c = GetQuestDifficultyColor and GetQuestDifficultyColor(boss.lv)
                if c then pin.level:SetTextColor(c.r, c.g, c.b) else pin.level:SetTextColor(1, 0.82, 0) end
                if dead then pin.level:SetTextColor(0.6, 0.6, 0.6) end
                pin.level:Show()
            else
                pin.level:Hide()
            end
            pin.badge:SetWidth(math.max(15, pin.badge.text:GetStringWidth() + 6))
            local focus = boss == self.focusBoss
            pin.portrait.ring:SetVertexColor(RGB(focus and C.amber or (boss.rare and C.info or C.edge)))
            if focus then pin.name:Set(boss.n, C.amber) else pin.name:Hide() end
            pin:SetAlpha(quiet and 0.4 or 1)
            pin:EnableMouse(not quiet)
            placeAt(pin, self.canvas, boss.at[1] / 100, boss.at[2] / 100, cw, ch)
        end
    end
end

local function outlined(parent, size, color)
    local fs = Addon.Localize(parent:CreateFontString(nil, "OVERLAY"))
    fs:SetFont(FDJ.Font(), size, "OUTLINE")
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

function Chart:MakeEntrance()
    local e = CreateFrame("Frame", nil, self.canvas)
    e:SetSize(24, 24)
    e:SetFrameLevel(self.ink:GetFrameLevel() + 3)
    e.icon = e:CreateTexture(nil, "OVERLAY")
    e.icon:SetAllPoints()
    if not (e.icon.SetAtlas and pcall(e.icon.SetAtlas, e.icon, "Dungeon", false)) then
        e.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
        e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    e.label = outlined(e, 14, { 1, 0.82, 0 })
    e.label:SetText(L.MAP_ENTRANCE or "Entrance")
    return e
end

function Chart:MakeLink()
    local b = CreateFrame("Button", nil, self.canvas)
    b:SetSize(22, 22)
    b:SetFrameLevel(self.ink:GetFrameLevel() + 3)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetAllPoints()
    b.icon:SetTexture(FDJ.Glyph("fc:icon-chevron-down"))
    b.icon:SetVertexColor(0.45, 1, 0.45)
    b.label = outlined(b, 12, { 0.45, 1, 0.45 })
    b.label:SetPoint("LEFT", b, "RIGHT", 3, 0)
    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetPoint("TOPLEFT", -3, 1)
    b.hl:SetPoint("BOTTOMRIGHT", b.label, "BOTTOMRIGHT", 5, -4)
    b.hl:SetColorTexture(0, 0, 0, 0.6)
    b.hl:Hide()
    b:SetScript("OnClick", function(self2) if self2.to then self:SetFloor(self2.to) end end)
    b:SetScript("OnEnter", function(self2)
        self2.label:SetTextColor(1, 1, 1)
        self2.icon:SetVertexColor(1, 1, 1)
        self2.hl:Show()
    end)
    b:SetScript("OnLeave", function(self2)
        self2.label:SetTextColor(0.45, 1, 0.45)
        self2.icon:SetVertexColor(0.45, 1, 0.45)
        self2.hl:Hide()
    end)
    function b:FitLabel()
        self:SetHitRectInsets(-4, -(self.label:GetStringWidth() + 8), -4, -4)
    end
    return b
end

function Chart:DrawEntrance(cw, ch)
    local d = self.dungeon
    local ent = d and FDJ.Entrance and FDJ.Entrance(d)
    if not self.entrance then self.entrance = self:MakeEntrance() end
    local e = self.entrance
    if ent and (ent.f or 1) == self.floor and ent.at then
        e.label:ClearAllPoints()
        if ent.side == "left" then
            e.label:SetPoint("RIGHT", e, "LEFT", -3, 0)
        elseif ent.side == "top" then
            e.label:SetPoint("BOTTOM", e, "TOP", 0, 1)
        else
            e.label:SetPoint("LEFT", e, "RIGHT", 3, 0)
        end
        placeAt(e, self.canvas, ent.at[1] / 100, ent.at[2] / 100, cw, ch)
        e:SetAlpha(self:Editing() and 0.4 or 1)
        e:Show()
    else
        e:Hide()
    end
    self.linkPins = self.linkPins or Kit.Pool(function() return self:MakeLink() end)
    self.linkPins:Reset()
    for _, link in ipairs(d and d.links or {}) do
        if link.f == self.floor and d.floors[link.to] then
            local b = self.linkPins:Get()
            b.to = link.to
            local where = FDJ.FloorLabel(d, link.to)
            if link.kind == "jump" then
                b.label:SetText((L.MAP_JUMP or "Jump down") .. ": " .. where)
            elseif link.kind == "swim" then
                b.label:SetText((L.MAP_SWIM or "Swim down") .. ": " .. where)
            else
                b.label:SetText(where)
            end
            b:FitLabel()
            b:EnableMouse(not self:Editing())
            placeAt(b, self.canvas, link.at[1] / 100, link.at[2] / 100, cw, ch)
            b:Show()
        end
    end
end

function Chart:MakeHandle()
    local h = CreateFrame("Button", nil, self.canvas)
    h:SetSize(18, 18)
    h:SetFrameLevel(self.ink:GetFrameLevel() + 10)
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
    h:SetScript("OnEnter", function(btn)
        local p = self.route and self.route.points[btn.index]
        if not p then return end
        local body = {}
        if p.label then body[#body + 1] = p.label end
        if btn.leadsTo then body[#body + 1] = L.ROUTE_CONTINUES:format(FDJ.FloorLabel(self.dungeon, btn.leadsTo)) end
        if btn.comesFrom then body[#body + 1] = L.ROUTE_COMES:format(FDJ.FloorLabel(self.dungeon, btn.comesFrom)) end
        if self:Editing() then body[#body + 1] = L.HANDLE_HINT end
        Kit.Tip(btn, L.STOP_N:format(btn.index), body)
    end)
    h:SetScript("OnLeave", Kit.HideTip)
    h:SetScript("OnClick", function(btn, button)
        local route = self.route
        if not route then return end
        if self.tool == "erase" then
            Routes.Remove(route, btn.index)
        elseif self:Editing() then
            if button == "RightButton" then
                Routes.Remove(route, btn.index)
                self.selected = nil
            elseif IsShiftKeyDown() then
                local p = route.points[btn.index]
                Kit.Prompt(L.LABEL_STOP:format(btn.index), p and p.label or "", function(text) Routes.Label(route, btn.index, text) end)
            else
                self.selected = (self.selected == btn.index) and nil or btn.index
                self:Draw()
            end
        elseif btn.leadsTo or btn.comesFrom then
            self:SetFloor(btn.leadsTo or btn.comesFrom)
        end
    end)
    h:SetScript("OnDragStart", function(btn)
        if not self:Editing() or self.tool == "erase" then return end
        btn.dragging = true
        btn:SetScript("OnUpdate", function(me)
            local fx, fy = cursorIn(self.canvas)
            placeAt(me, self.canvas, FDJ.Clamp(fx, 0, 1), FDJ.Clamp(fy, 0, 1), self.canvas:GetWidth(), self.canvas:GetHeight())
        end)
    end)
    h:SetScript("OnDragStop", function(btn)
        if not btn.dragging then return end
        btn.dragging = false
        btn:SetScript("OnUpdate", nil)
        local fx, fy = cursorIn(self.canvas)
        Routes.Move(self.route, btn.index, fx, fy)
    end)
    return h
end

function Chart:MakeMark()
    local b = CreateFrame("Button", nil, self.canvas)
    b:SetSize(24, 24)
    b:SetFrameLevel(self.ink:GetFrameLevel() + 8)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.label = Kit.Pill(b)
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
    Kit.MarkText(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnEnter", function(btn)
        local mk = self.route and self.route.marks[btn.index]
        if not mk then return end
        Kit.Tip(btn, mk.label or L["MARK_" .. mk.k:upper()] or L.MARKER, self:Editing() and (mk.k == "text" and L.TEXT_HANDLE_HINT or L.MARK_HANDLE_HINT) or nil)
    end)
    b:SetScript("OnLeave", Kit.HideTip)
    b:SetScript("OnClick", function(btn, button)
        local route = self.route
        if not route or not self:Editing() then return end
        if self.tool == "erase" or button == "RightButton" then
            Routes.RemoveMark(route, btn.index)
        elseif IsShiftKeyDown() or self.tool == "stops" or self.tool == "text" then
            local mk = route.marks[btn.index]
            local index = btn.index
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
    b:SetScript("OnDragStart", function(btn)
        if not self:Editing() or self.tool == "erase" then return end
        btn.dragging = true
        btn:SetScript("OnUpdate", function(me)
            local fx, fy = cursorIn(self.canvas)
            placeAt(me, self.canvas, FDJ.Clamp(fx, 0, 1), FDJ.Clamp(fy, 0, 1), self.canvas:GetWidth(), self.canvas:GetHeight())
        end)
    end)
    b:SetScript("OnDragStop", function(btn)
        if not btn.dragging then return end
        btn.dragging = false
        btn:SetScript("OnUpdate", nil)
        local fx, fy = cursorIn(self.canvas)
        Routes.MoveMark(self.route, btn.index, fx, fy)
    end)
    return b
end

function Chart:DrawRoute(cw, ch)
    self.handles:Reset()
    self.markPins:Reset()
    local pen = self.pen
    pen:Begin()
    local route, chartID = self.route, self:ChartID()
    if route and chartID then
        local color = Routes.Color(route)
        for _, s in ipairs(route.strokes) do
            if s.m == chartID then pen:Path(s.p, cw, ch, Routes.StrokeColor(route, s), s.w or 2) end
        end
        local pts = route.points
        local spots = {}
        local project = self.worldMap and FDJ.WorldLayer and FDJ.WorldLayer.Project
        for i, p in ipairs(pts) do
            if p.m == chartID then
                spots[i] = { x = p.x, y = p.y, native = true }
            elseif project then
                local x, y = project(p.m, p.x, p.y, chartID)
                if x then spots[i] = { x = x, y = y } end
            end
        end
        for i = 2, #pts do
            local a, b = spots[i - 1], spots[i]
            if a and b then pen:Seg(a.x * cw, a.y * ch, b.x * cw, b.y * ch, color, 3) end
        end
        for i, p in ipairs(pts) do
            local spot = spots[i]
            if spot and not spot.native then
                local h = self.handles:Get()
                h.index = i
                h.leadsTo, h.comesFrom = nil, nil
                h.ring:SetVertexColor(RGB(C.shadow))
                h.dot:SetVertexColor(RGB(color))
                h.num:SetText(i)
                h.label:Set(p.label, color)
                h:SetSize(16, 16)
                placeAt(h, self.canvas, spot.x, spot.y, cw, ch)
                h:EnableMouse(false)
            elseif p.m == chartID then
                local h = self.handles:Get()
                h.index = i
                local nextP, prevP = pts[i + 1], pts[i - 1]
                h.leadsTo = nextP and nextP.m ~= chartID and self:FloorOfChart(nextP.m) or nil
                h.comesFrom = prevP and prevP.m ~= chartID and self:FloorOfChart(prevP.m) or nil
                local portal = h.leadsTo or h.comesFrom
                h.ring:SetVertexColor(RGB(i == self.selected and C.text or C.shadow))
                h.dot:SetVertexColor(RGB(portal and C.amber or color))
                h.num:SetText(i)
                h.label:Set(p.label, color)
                h:SetSize(portal and 20 or 18, portal and 20 or 18)
                placeAt(h, self.canvas, p.x, p.y, cw, ch)
                h:EnableMouse(self.tool ~= "draw")
            end
        end
        for i, mk in ipairs(route.marks) do
            local mx, my = mk.x, mk.y
            local native = mk.m == chartID
            if not native and project then mx, my = project(mk.m, mk.x, mk.y, chartID) else if not native then mx = nil end end
            if mx then
                local b = self.markPins:Get()
                b.index = i
                Kit.ShowMark(b, mk, Routes.MarkColor(route, mk))
                placeAt(b, self.canvas, mx, my, cw, ch)
                b:EnableMouse(native and self.tool ~= "draw")
            end
        end
    end
    pen:End()
end

function Chart:DrawLive()
    local pts = self.stroke and self.stroke.p
    local pen = self.livePen
    pen:Begin()
    if pts and self.route then
        local cw, ch = self.canvas:GetWidth(), self.canvas:GetHeight()
        pen:Path(pts, cw, ch, Routes.Color(self.route, self.brushColor), Routes.Widths[self.brush] or 4)
    end
    pen:End()
end

function Chart:Draw()
    if self.route and not FDJ.db.routes[self.route.id] then
        self.route = nil
        self.selected = nil
        self.tool = "view"
    end
    local cw, ch = self.w * self.zoom, self.h * self.zoom
    self:Hud()
    self:DrawBosses(cw, ch)
    self:DrawEntrance(cw, ch)
    self:DrawRoute(cw, ch)
    self:DrawLive()
end

function Chart:PressStart(button)
    local x, y = GetCursorPosition()
    local scale = self.view:GetEffectiveScale()
    local press = { button = button, x = x, y = y, offX = self.offX, offY = self.offY, moved = false }
    self.press = press
    local chartID = self:ChartID()
    local drawing = button == "LeftButton" and self:Editing() and chartID ~= nil
    if drawing and self.tool == "draw" then
        local fx, fy = cursorIn(self.canvas)
        self.stroke = { m = chartID, p = { FDJ.Clamp(fx, 0, 1), FDJ.Clamp(fy, 0, 1) }, lastX = x, lastY = y }
    end
    local lastErase = 0
    self.view:SetScript("OnUpdate", function()
        local p = self.press
        if not p then return end
        local cx, cy = GetCursorPosition()
        local dx, dy = (cx - p.x) / scale, (cy - p.y) / scale
        if not p.moved and (math.abs(dx) > 3 or math.abs(dy) > 3) then p.moved = true end
        local stroke = self.stroke
        if stroke then
            if math.abs(cx - stroke.lastX) + math.abs(cy - stroke.lastY) >= SAMPLE * scale then
                stroke.lastX, stroke.lastY = cx, cy
                local fx, fy = cursorIn(self.canvas)
                stroke.p[#stroke.p + 1] = FDJ.Clamp(fx, 0, 1)
                stroke.p[#stroke.p + 1] = FDJ.Clamp(fy, 0, 1)
                self:DrawLive()
            end
            return
        end
        if drawing and self.tool == "erase" and p.moved and GetTime() - lastErase > 0.05 then
            lastErase = GetTime()
            local fx, fy = cursorIn(self.canvas)
            Routes.Erase(self.route, chartID, fx, fy, 10 / self.canvas:GetHeight(), RATIO)
            return
        end
        if p.moved and self.zoom > 1 and not drawing then
            self.offX = p.offX + dx
            self.offY = p.offY + dy
            self:Place()
        end
    end)
end

function Chart:PressCancel()
    self.press = nil
    if self.stroke then
        self.stroke = nil
        self:DrawLive()
    end
    self.view:SetScript("OnUpdate", nil)
end

function Chart:PressEnd(button)
    local press = self.press
    local stroke = self.stroke
    self.stroke = nil
    self.press = nil
    self.view:SetScript("OnUpdate", nil)
    if stroke then
        if #stroke.p >= 4 then
            Routes.AddStroke(self.route, stroke.m, stroke.p, Routes.Widths[self.brush] or 4, self.brushColor)
        else
            self:DrawLive()
        end
        self:DrawLive()
        return
    end
    if not press or press.moved or press.button ~= button then return end
    if self.worldMap and self.onMapClick then
        local mx, my = cursorIn(self.canvas)
        if self.onMapClick(button, mx, my, self:Editing()) then return end
    end
    if not self:Editing() then
        if button == "RightButton" then
            if self.onRightClick then
                if self.zoom > 1 then self:ResetView() end
                self.onRightClick()
            elseif self.zoom > 1 then self:ResetView() end
        end
        return
    end
    local chartID = self:ChartID()
    if not chartID then return end
    local fx, fy = cursorIn(self.canvas)
    if fx < 0 or fx > 1 or fy < 0 or fy > 1 then return end
    if button == "RightButton" then
        if self.selected then
            self.selected = nil
            self:Draw()
        end
        return
    end
    if self.tool == "stops" then
        local index = Routes.Add(self.route, chartID, fx, fy, self.selected)
        if index and self.selected then self.selected = index end
    elseif self.tool == "mark" then
        Routes.AddMark(self.route, chartID, fx, fy, self.markKind, self.markColor)
    elseif self.tool == "text" then
        local route = self.route
        Kit.TextEditor({ c = self.markColor }, function(text, color, size)
            if text and not text:match("^%s*$") then Routes.AddMark(route, chartID, fx, fy, "text", color, text, size) end
        end)
    elseif self.tool == "erase" then
        Routes.Erase(self.route, chartID, fx, fy, 12 / self.canvas:GetHeight(), RATIO)
    end
end
