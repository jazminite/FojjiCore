local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end
local AM = Addon.Assignments
if not AM then return end

local K
local function kit() K = K or Addon.UIKit; return K end
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local TEX = "Interface\\AddOns\\FojjiCore\\textures\\DungeonJournal\\"
local MAX_ZOOM = 8

local function classHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
end

local Board = {}
Board.__index = Board
AM.Board = Board

function AM.NewBoard(parent)
    kit()
    local self = setmetatable({}, Board)
    local vp = CreateFrame("Frame", nil, parent)
    vp:SetClipsChildren(true)
    vp:EnableMouse(true)
    vp:EnableMouseWheel(true)
    K.Surface(vp, "field", 1, "borderDim")
    local canvas = CreateFrame("Frame", nil, vp)
    canvas:SetSize(1002, 668)
    canvas:SetPoint("TOPLEFT")
    local art = CreateFrame("Frame", nil, canvas); art:SetAllPoints()
    local ink = CreateFrame("Frame", nil, canvas); ink:SetAllPoints(); ink:SetFrameLevel(art:GetFrameLevel() + 2)
    local pins = CreateFrame("Frame", nil, canvas); pins:SetAllPoints(); pins:SetFrameLevel(art:GetFrameLevel() + 4)
    self.vp, self.canvas, self.art, self.ink, self.pins = vp, canvas, art, ink, pins
    self.W, self.H = 1002, 668
    self.zoom, self.ox, self.oy = 1, 0, 0
    self.tiles, self.lines, self.pinPool, self.used = {}, {}, {}, {}
    self.tool, self.color, self.width, self.stamp = "view", 1, 3, 8
    self.undo = {}
    self.empty = K.T(vp, 13, "dim", "CENTER")
    self.empty:SetPoint("CENTER")
    self.empty:SetText("No map art here - you can still draw.")
    self.empty:Hide()

    vp:SetScript("OnSizeChanged", function()
        local pv = self.pendingView
        if pv and (vp:GetWidth() or 0) > 2 then self.pendingView = nil; self:SetView(pv[1], pv[2], pv[3]) else self:Layout() end
    end)
    vp:SetScript("OnMouseWheel", function(_, d) self:ZoomAtCursor(d > 0 and 1.25 or 0.8) end)
    vp:SetScript("OnMouseDown", function(_, button) self:Press(button) end)
    vp:SetScript("OnMouseUp", function(_, button) self:Release(button) end)
    vp:SetScript("OnHide", function() self:Release() end)
    return self
end

function Board:SetMap(mapID)
    self.mapID = mapID
    for _, t in ipairs(self.tiles) do t:Hide() end
    local W, H, list, cols, tw, th = 1002, 668
    if mapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures then
        local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
        local layer = ok and type(layers) == "table" and layers[1]
        local ok2, tiles = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
        if layer and ok2 and type(tiles) == "table" and #tiles > 0 then
            W, H = layer.layerWidth or W, layer.layerHeight or H
            tw, th = layer.tileWidth or 256, layer.tileHeight or 256
            cols = math.max(1, math.ceil(W / tw))
            list = tiles
        end
    end
    self.W, self.H = W, H
    self.canvas:SetSize(W, H)
    if list then
        for i, file in ipairs(list) do
            local t = self.tiles[i]
            if not t then t = self.art:CreateTexture(nil, "ARTWORK"); self.tiles[i] = t end
            t:SetTexture(file)
            t:SetSize(tw, th)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self.art, "TOPLEFT", ((i - 1) % cols) * tw, -math.floor((i - 1) / cols) * th)
            t:Show()
        end
    end
    self.empty:SetShown(not list)
    self.hasArt = list ~= nil
end

function Board:Base()
    local vw, vh = self.vp:GetWidth() or 1, self.vp:GetHeight() or 1
    if vw < 2 or vh < 2 then return 1 end
    return math.min(vw / self.W, vh / self.H)
end

function Board:Clamp()
    local vw, vh = self.vp:GetWidth() or 1, self.vp:GetHeight() or 1
    local s = self:Base() * self.zoom
    local cw, ch = self.W * s, self.H * s
    if cw <= vw then self.ox = (vw - cw) / 2 else self.ox = math.max(vw - cw, math.min(0, self.ox)) end
    if ch <= vh then self.oy = (vh - ch) / 2 else self.oy = math.max(vh - ch, math.min(0, self.oy)) end
end

function Board:Place()
    self:Clamp()
    local s = self:Base() * self.zoom
    self.canvas:SetScale(math.max(0.01, s))
    self.canvas:ClearAllPoints()
    self.canvas:SetPoint("TOPLEFT", self.vp, "TOPLEFT", self.ox / s, -self.oy / s)
end

function Board:Layout()
    self:Place()
    self:Draw()
end

function Board:SetView(z, cx, cy)
    self.zoom = math.max(1, math.min(MAX_ZOOM, z or 1))
    local vw, vh = self.vp:GetWidth() or 1, self.vp:GetHeight() or 1
    if vw < 2 or vh < 2 then self.pendingView = { z, cx, cy } return end
    local s = self:Base() * self.zoom
    self.ox = vw / 2 - (cx or 0.5) * self.W * s
    self.oy = vh / 2 - (cy or 0.5) * self.H * s
    self:Layout()
end

function Board:View()
    local vw, vh = self.vp:GetWidth() or 1, self.vp:GetHeight() or 1
    local s = self:Base() * self.zoom
    return self.zoom, (vw / 2 - self.ox) / (self.W * s), (vh / 2 - self.oy) / (self.H * s)
end

local function cursorIn(frame)
    local x, y = GetCursorPosition()
    local es = frame:GetEffectiveScale()
    return x / es, y / es
end

function Board:Cursor()
    local x, y = cursorIn(self.canvas)
    local l, t = self.canvas:GetLeft(), self.canvas:GetTop()
    if not l then return 0.5, 0.5 end
    return (x - l) / self.W, (t - y) / self.H
end

function Board:ZoomAtCursor(f)
    local nx, ny = self:Cursor()
    local z = math.max(1, math.min(MAX_ZOOM, self.zoom * f))
    if z == self.zoom then return end
    local x, y = cursorIn(self.vp)
    local cx, cy = x - self.vp:GetLeft(), self.vp:GetTop() - y
    self.zoom = z
    local s = self:Base() * z
    self.ox, self.oy = cx - nx * self.W * s, cy - ny * self.H * s
    self:Layout()
    if self.onView then self.onView() end
end

function Board:SetPlan(plan)
    self.plan = plan
    self.undo = {}
    self:Draw()
end

local function color(i) local c = AM.COLORS[i or 1] or AM.COLORS[1]; return c[1], c[2], c[3] end

function Board:Line(x1, y1, x2, y2, r, g, b, a, w)
    local n = self.lineN + 1
    self.lineN = n
    local l = self.lines[n]
    if not l then l = self.ink:CreateLine(nil, "ARTWORK"); self.lines[n] = l end
    l:SetColorTexture(r, g, b, a or 1)
    l:SetThickness(math.max(1, (w or 3) / self.zoom / math.max(0.2, self:Base())))
    l:SetStartPoint("TOPLEFT", self.ink, x1 * self.W, -y1 * self.H)
    l:SetEndPoint("TOPLEFT", self.ink, x2 * self.W, -y2 * self.H)
    l:Show()
    return l
end

function Board:Pin()
    local n = self.pinN + 1
    self.pinN = n
    local p = self.pinPool[n]
    if not p then
        p = CreateFrame("Frame", nil, self.pins)
        p.tex = p:CreateTexture(nil, "ARTWORK")
        p.tex:SetPoint("CENTER")
        p.ring = p:CreateTexture(nil, "BORDER")
        p.ring:SetPoint("CENTER")
        p.text = K.T(p, 12, "white", "CENTER", true)
        p.sub = K.T(p, 10, "dim", "CENTER", true)
        self.pinPool[n] = p
    end
    p:SetScale(1 / (self.zoom * math.max(0.2, self:Base())))
    p.tex:Show(); p.ring:Hide(); p.text:SetText(""); p.sub:SetText("")
    p.tex:SetVertexColor(1, 1, 1, 1); p.tex:SetTexCoord(0, 1, 0, 1)
    p:Show()
    return p
end

function Board:PlacePin(p, x, y, size)
    local k = self.zoom * math.max(0.2, self:Base())
    p:SetSize(size, size)
    p:ClearAllPoints()
    p:SetPoint("CENTER", self.pins, "TOPLEFT", x * self.W * k, -y * self.H * k)
end

function Board:DrawItem(it)
    if it.t == "L" then
        local r, g, b = color(it.c)
        for i = 1, #it.p - 3, 2 do self:Line(it.p[i], it.p[i + 1], it.p[i + 2], it.p[i + 3], r, g, b, 0.95, (it.w or 3) * 1.4) end
    elseif it.t == "A" then
        local r, g, b = color(it.c)
        local x1, y1, x2, y2 = it.p[1], it.p[2], it.p[3], it.p[4]
        self:Line(x1, y1, x2, y2, r, g, b, 0.95, 4)
        local dx, dy = (x2 - x1) * self.W, (y2 - y1) * self.H
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 1 then
            local head = 16 / self.zoom / math.max(0.2, self:Base())
            local ux, uy = dx / len, dy / len
            for _, side in ipairs({ 1, -1 }) do
                local hx = x2 * self.W - head * (ux * 0.85 - uy * 0.5 * side)
                local hy = y2 * self.H - head * (uy * 0.85 + ux * 0.5 * side)
                self:Line(x2, y2, hx / self.W, hy / self.H, r, g, b, 0.95, 4)
            end
        end
    elseif it.t == "C" then
        local r, g, b = color(it.c)
        local seg = 36
        local rx = it.r
        local ry = it.r * self.W / self.H
        local px, py
        for i = 0, seg do
            local a = i / seg * math.pi * 2
            local x, y = it.x + math.cos(a) * rx, it.y + math.sin(a) * ry
            if px then self:Line(px, py, x, y, r, g, b, 0.9, 3) end
            px, py = x, y
        end
    elseif it.t == "M" then
        local p = self:Pin()
        p.tex:SetTexture(AM.StampTexture(it.i))
        p.tex:SetSize(24, 24)
        self:PlacePin(p, it.x, it.y, 26)
    elseif it.t == "T" then
        local p = self:Pin()
        p.tex:Hide()
        p.text:ClearAllPoints(); p.text:SetPoint("CENTER")
        p.text:SetText(it.s or "")
        p.text:SetTextColor(color(it.c))
        self:PlacePin(p, it.x, it.y, 20)
    elseif it.t == "P" then
        local p = self:Pin()
        p.tex:SetTexture(TEX .. "ui-dot")
        p.tex:SetSize(16, 16)
        local label, r, g, b = AM.TokenLook(it.s)
        p.tex:SetVertexColor(r, g, b, 1)
        p.ring:SetTexture(TEX .. "ui-ring"); p.ring:SetSize(20, 20); p.ring:SetVertexColor(0, 0, 0, 0.8); p.ring:Show()
        p.text:ClearAllPoints(); p.text:SetPoint("TOP", p, "BOTTOM", 0, 2)
        p.text:SetText(label)
        p.text:SetTextColor(r, g, b)
        if it.l and it.l ~= "" then
            p.sub:ClearAllPoints(); p.sub:SetPoint("TOP", p.text, "BOTTOM", 0, -1)
            p.sub:SetText(it.l)
        end
        self:PlacePin(p, it.x, it.y, 20)
    end
end

function Board:Draw()
    if not K then return end
    self.lineN, self.pinN = 0, 0
    local plan = self.plan
    if plan then for _, it in ipairs(plan.items) do self:DrawItem(it) end end
    if self.live then self:DrawItem(self.live) end
    for _, b in ipairs(self.bosses or {}) do
        if b.mapID == self.mapID and b.x then
            local p = self:Pin()
            p.tex:SetTexture(TEX .. "mark-skull")
            p.tex:SetSize(18, 18)
            p.tex:SetVertexColor(1, 0.85, 0.4, b == self.boss and 1 or 0.55)
            p.text:ClearAllPoints(); p.text:SetPoint("TOP", p, "BOTTOM", 0, 1)
            p.text:SetText(b == self.boss and b.name or "")
            p.text:SetTextColor(1, 0.85, 0.4)
            self:PlacePin(p, b.x, b.y, 18)
        end
    end
    for i = self.lineN + 1, #self.lines do self.lines[i]:Hide() end
    for i = self.pinN + 1, #self.pinPool do self.pinPool[i]:Hide() end
end

function AM.TokenLook(s)
    s = s or ""
    local role = AM.ROLE_TOKENS[s]
    if role then return s, role[1], role[2], role[3] end
    local GS = Addon.GroupSetups
    local cls = GS and GS.ClassOf and GS.ClassOf(s)
    if cls then
        local r, g, b = classHex(cls)
        return s, r or 1, g or 1, b or 1
    end
    local name = (GS and GS.KeyName and GS:KeyName(s)) or s
    local label = name ~= s and (s .. " " .. name) or s
    if GS and GS.Roster and IsInRaid() then
        local u = GS:Resolve(GS:Roster(), name)
        if u then
            local r, g, b = classHex(u.class)
            if r then return label, r, g, b end
        end
    end
    return label, 0.92, 0.92, 0.95
end

local function dist2(ax, ay, bx, by) return (ax - bx) ^ 2 + (ay - by) ^ 2 end
local function segDist2(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l = dx * dx + dy * dy
    local t = l > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l)) or 0
    return dist2(px, py, ax + t * dx, ay + t * dy)
end

function Board:Hit()
    local plan = self.plan
    if not plan then return end
    local x, y = self:Cursor()
    local px, py = x * self.W, y * self.H
    local tol = (12 / self.zoom / math.max(0.2, self:Base())) ^ 2
    for i = #plan.items, 1, -1 do
        local it = plan.items[i]
        if it.t == "M" or it.t == "T" or it.t == "P" then
            if dist2(px, py, it.x * self.W, it.y * self.H) <= tol * 1.6 then return it, i end
        elseif it.t == "C" then
            local d = math.sqrt(dist2(px, py, it.x * self.W, it.y * self.H))
            if math.abs(d - it.r * self.W) <= math.sqrt(tol) or d <= it.r * self.W * 0.3 then return it, i end
        elseif it.t == "L" or it.t == "A" then
            for k = 1, #it.p - 3, 2 do
                if segDist2(px, py, it.p[k] * self.W, it.p[k + 1] * self.H, it.p[k + 2] * self.W, it.p[k + 3] * self.H) <= tol then return it, i end
            end
        end
    end
end

function Board:Commit(op)
    local plan = self.plan
    if not plan then return end
    if op then
        self.undo[#self.undo + 1] = op
        if #self.undo > 60 then table.remove(self.undo, 1) end
    end
    plan.rev = (plan.rev or 0) + 1
    plan.t = time()
    plan.by = UnitName("player")
    AM.Changed(plan)
end

function Board:Add(it)
    if not self.plan then return end
    local items = self.plan.items
    items[#items + 1] = it
    self:Commit({ "add", it })
    self:Draw()
end

function Board:Remove(it, i)
    table.remove(self.plan.items, i)
    self:Commit({ "del", it, i })
    self:Draw()
end

function Board:Undo()
    local op = table.remove(self.undo)
    if not op or not self.plan then return end
    local items = self.plan.items
    if op[1] == "add" then
        for i = #items, 1, -1 do if items[i] == op[2] then table.remove(items, i) break end end
    elseif op[1] == "del" then
        table.insert(items, math.min(op[3], #items + 1), op[2])
    elseif op[1] == "move" then
        local it = op[2]
        if it.p then it.p = op[3] else it.x, it.y = op[3][1], op[3][2] end
    elseif op[1] == "clear" then
        self.plan.items = op[2]
    end
    self:Commit()
    self:Draw()
end

function Board:Clear()
    if not self.plan or #self.plan.items == 0 then return end
    local old = self.plan.items
    self.plan.items = {}
    self:Commit({ "clear", old })
    self:Draw()
end

local function copyPts(p) local c = {} for i = 1, #p do c[i] = p[i] end return c end

function Board:Press(button)
    if not self.plan then return end
    local x, y = self:Cursor()
    local cx, cy = cursorIn(self.vp)
    self.press = { button = button, sx = cx, sy = cy, ox = self.ox, oy = self.oy, x = x, y = y }
    local press = self.press
    if button ~= "LeftButton" then press.mode = "pan"
    else
        local tool = self.tool
        if tool == "view" then
            local it = self:Hit()
            if it then
                press.mode, press.item = "move", it
                press.before = it.p and copyPts(it.p) or { it.x, it.y }
            else
                press.mode = "pan"
            end
        elseif tool == "pen" then
            press.mode = "pen"
            self.live = { t = "L", c = self.color, w = self.width, p = { x, y } }
        elseif tool == "arrow" then
            press.mode = "arrow"
            self.live = { t = "A", c = self.color, p = { x, y, x, y } }
        elseif tool == "circle" then
            press.mode = "circle"
            self.live = { t = "C", c = self.color, x = x, y = y, r = 0 }
        elseif tool == "stamp" then
            self:Add({ t = "M", i = self.stamp, x = x, y = y })
        elseif tool == "text" then
            if self.onText then self.onText(x, y) end
        elseif tool == "player" then
            if self.player then self:Add({ t = "P", s = self.player, x = x, y = y })
            elseif self.onHint then self.onHint("Pick a player, key, class or role on the right first.") end
        elseif tool == "erase" then
            press.mode = "erase"
            local it, i = self:Hit()
            if it then self:Remove(it, i) end
        end
    end
    self.vp:SetScript("OnUpdate", function() self:Drag() end)
end

function Board:Drag()
    local press = self.press
    if not press then self.vp:SetScript("OnUpdate", nil) return end
    local x, y = self:Cursor()
    if press.mode == "pan" then
        local cx, cy = cursorIn(self.vp)
        self.ox, self.oy = press.ox + (cx - press.sx), press.oy - (cy - press.sy)
        self:Place()
    elseif press.mode == "move" then
        local it, dx, dy = press.item, x - press.x, y - press.y
        if it.p then
            for i = 1, #it.p, 2 do it.p[i], it.p[i + 1] = press.before[i] + dx, press.before[i + 1] + dy end
        else
            it.x, it.y = press.before[1] + dx, press.before[2] + dy
        end
        self:Draw()
    elseif press.mode == "pen" then
        local p = self.live.p
        local lx, ly = p[#p - 1], p[#p]
        local step = 5 / self.zoom / math.max(0.2, self:Base())
        if dist2(x * self.W, y * self.H, lx * self.W, ly * self.H) >= step * step then
            p[#p + 1], p[#p + 2] = x, y
            self:Draw()
        end
    elseif press.mode == "arrow" then
        self.live.p[3], self.live.p[4] = x, y
        self:Draw()
    elseif press.mode == "circle" then
        self.live.r = math.sqrt(((x - self.live.x) * self.W) ^ 2 + ((y - self.live.y) * self.H) ^ 2) / self.W
        self:Draw()
    elseif press.mode == "erase" then
        local it, i = self:Hit()
        if it then self:Remove(it, i) end
    end
end

function Board:Release()
    local press = self.press
    self.press = nil
    self.vp:SetScript("OnUpdate", nil)
    if not press then return end
    local live = self.live
    self.live = nil
    if press.mode == "pan" then
        if self.onView then self.onView() end
    elseif press.mode == "move" then
        self:Commit({ "move", press.item, press.before })
    elseif live then
        local keep = (live.t == "L" and #live.p >= 4) or (live.t == "A" and (live.p[1] ~= live.p[3] or live.p[2] ~= live.p[4])) or (live.t == "C" and live.r > 0.004)
        if keep then self:Add(live) else self:Draw() end
    end
end

local win

local function toolButton(parent, tex, tip, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(30, 28)
    K.Surface(b, "button", 1, "border", 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16); b.icon:SetPoint("CENTER")
    if tex then b.icon:SetTexture(tex) end
    if text then
        b.t = K.T(b, 13, "text", "CENTER"); b.t:SetPoint("CENTER"); b.t:SetText(text)
        b.icon:Hide()
    end
    function b:Paint()
        local on = self.on
        local r, g, bl = K.C("accent")
        if on then self.bg:SetVertexColor(r, g, bl, 0.35) else self.bg:SetVertexColor(K.C(self.hover and "buttonHover" or "button")) end
        self.bd:Set((on or self.hover) and "accent" or "border", 1)
        self.icon:SetVertexColor(1, 1, 1, 1)
    end
    b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    if tip then K.Tip(b, tip[1], tip[2]) end
    K.paint(function() b:Paint() end)
    return b
end

local TOOLS = {
    { "view", TEX .. "ui-cursor", { "Move", "Drag things to move them. Drag the map to pan, wheel to zoom." } },
    { "pen", TEX .. "ui-brush", { "Draw", "Freehand lines." } },
    { "arrow", TEX .. "mark-arrow", { "Arrow", "Drag from start to end." } },
    { "circle", TEX .. "ui-ring", { "Circle", "Drag out from the centre." } },
    { "stamp", nil, { "Marker", "Click to place. Click the tool again to pick another marker." } },
    { "text", nil, { "Text", "Click where the text goes." } },
    { "player", TEX .. "ui-party", { "Player", "Pick a name, key, class or role on the right, then click the map." } },
    { "erase", TEX .. "ui-eraser", { "Erase", "Click or drag over things to remove them." } },
}

local function buildWindow()
    kit()
    local d = AM.DB()
    local f = CreateFrame("Frame", "FojjiCoreAssignments", UIParent)
    f:SetSize(d.win.w or 1120, d.win.h or 700)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(300)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(860, 520) elseif f.SetMinResize then f:SetMinResize(860, 520) end
    K.Surface(f, "frame", 0.98, "accent", 0.6); K.Sheen(f, 60, 0.08)
    if Addon.Native and Addon.Skin then Addon.Skin.Dialog(f) end
    if Addon.EscapeCloses then Addon.EscapeCloses("FojjiCoreAssignments") end
    if d.win.p then f:SetPoint(d.win.p[1], UIParent, d.win.p[2], d.win.p[3], d.win.p[4]) else f:SetPoint("CENTER") end

    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(46)
    head:EnableMouse(true); head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() f:StartMoving() end)
    head:SetScript("OnDragStop", function() f:StopMovingOrSizing(); local p, _, rp, x, y = f:GetPoint(); d.win.p = { p, rp, x, y } end)
    local title = K.T(head, 16, "white"); title:SetPoint("LEFT", 16, 0); title:SetText("Position Assignments")
    local close = K.Button(head, "X", 26, 26); close:SetPoint("RIGHT", -10, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    local raidDD = K.Dropdown(head, 230, nil); raidDD:SetPoint("LEFT", title, "RIGHT", 18, 0)
    local status = K.T(head, 12, "dim"); status:SetPoint("LEFT", raidDD, "RIGHT", 14, 0); status:SetPoint("RIGHT", close, "LEFT", -12, 0)

    local left = CreateFrame("Frame", nil, f)
    left:SetPoint("TOPLEFT", 12, -50); left:SetPoint("BOTTOMLEFT", 12, 50); left:SetWidth(190)
    K.Surface(left, "field", 0.8, "borderDim")
    local bossRows = {}

    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPRIGHT", -12, -50); right:SetPoint("BOTTOMRIGHT", -12, 50); right:SetWidth(210)

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0); bar:SetPoint("RIGHT", right, "LEFT", -10, 0); bar:SetHeight(30)
    local board = AM.NewBoard(f)
    board.vp:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
    board.vp:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -10, 0)
    f.board = board

    local share = K.Button(f, "Share to raid", 130, 28, "primary", "icon-raid"); share:SetPoint("BOTTOMLEFT", 12, 12)
    local show = K.Button(f, "Share and show", 130, 28); show:SetPoint("LEFT", share, "RIGHT", 8, 0)
    local export = K.Button(f, "Export", 80, 28, nil, "icon-export"); export:SetPoint("LEFT", show, "RIGHT", 8, 0)
    local import = K.Button(f, "Import", 80, 28); import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    local hereMap = K.Button(f, "Use this zone's map", 160, 28); hereMap:SetPoint("LEFT", import, "RIGHT", 8, 0)
    K.Tip(show, "Share and show", "Shares, and opens the plan for everyone who allows it.")
    K.Tip(hereMap, "Use this zone's map", "Draws this boss on the map you're standing on - for raids without journal maps.")
    local floorPrev = K.Button(f, "<", 28, 28); local floorNext = K.Button(f, ">", 28, 28)
    local floorText = K.T(f, 12, "text", "CENTER")
    floorNext:SetPoint("BOTTOMRIGHT", -232, 12)
    floorText:SetPoint("RIGHT", floorNext, "LEFT", -6, 0); floorText:SetWidth(170)
    floorPrev:SetPoint("RIGHT", floorText, "LEFT", -6, 0)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip.t = grip:CreateTexture(nil, "OVERLAY"); grip.t:SetAllPoints(); grip.t:SetTexture(TEX .. "ui-grip"); grip.t:SetAlpha(0.6)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); d.win.w, d.win.h = f:GetWidth(), f:GetHeight(); local p, _, rp, x, y = f:GetPoint(); d.win.p = { p, rp, x, y } end)

    local state = { raid = nil, boss = nil, plan = nil }
    f.state = state

    local tools = {}
    local px = 0
    local function setTool(key)
        board.tool = key
        for k, b in pairs(tools) do b.on = k == key; b:Paint() end
    end
    local function stampMenu(owner)
        local e = {}
        for _, s in ipairs(AM.STAMPS) do
            e[#e + 1] = { text = s[2], checked = board.stamp == s[1], onClick = function() board.stamp = s[1]; tools.stamp.icon:SetTexture(AM.StampTexture(s[1])); setTool("stamp") end }
        end
        K.openMenu(owner, e)
    end
    for _, t in ipairs(TOOLS) do
        local b = toolButton(bar, t[2], t[3], t[1] == "text" and "T" or nil)
        if t[1] == "stamp" then b.icon:SetTexture(AM.StampTexture(8)) end
        b:SetPoint("LEFT", px, 0)
        px = px + 32
        b:SetScript("OnClick", function(self)
            if t[1] == "stamp" and board.tool == "stamp" then stampMenu(self) return end
            setTool(t[1])
        end)
        tools[t[1]] = b
    end
    px = px + 10
    local swatches = {}
    for i, c in ipairs(AM.COLORS) do
        local s = CreateFrame("Button", nil, bar)
        s:SetSize(18, 18); s:SetPoint("LEFT", px, 0); px = px + 21
        s.bg = s:CreateTexture(nil, "ARTWORK"); s.bg:SetAllPoints(); s.bg:SetColorTexture(c[1], c[2], c[3], 1)
        s.bd = K.Border(s, "border")
        s:SetScript("OnClick", function()
            board.color = i
            for j, o in ipairs(swatches) do o.bd:Set(j == i and "white" or "border", 1) end
        end)
        swatches[i] = s
    end
    swatches[1].bd:Set("white", 1)
    px = px + 10
    local undo = toolButton(bar, TEX .. "ui-undo", { "Undo", "Ctrl+Z also works while the map has focus." })
    undo:SetPoint("LEFT", px, 0); px = px + 32
    undo:SetScript("OnClick", function() board:Undo() end)
    local clear = toolButton(bar, TEX .. "ui-trash", { "Clear", "Removes everything on this boss's map. Undo brings it back." })
    clear:SetPoint("LEFT", px, 0)
    clear:SetScript("OnClick", function() board:Clear() end)
    setTool("view")

    local prompt = K.Input(board.vp, nil)
    prompt:SetSize(200, 24); prompt:Hide()
    prompt:SetFrameLevel(board.vp:GetFrameLevel() + 30)
    prompt.box:SetScript("OnEnterPressed", function(self)
        local s = trim(self:GetText())
        if s ~= "" and prompt.at then board:Add({ t = "T", c = board.color, x = prompt.at[1], y = prompt.at[2], s = s }) end
        prompt:Hide()
    end)
    prompt.box:SetScript("OnEscapePressed", function() prompt:Hide() end)
    prompt.box:SetScript("OnEditFocusLost", function() prompt:Hide() end)
    board.onText = function(x, y)
        local cx, cy = cursorIn(board.vp)
        prompt.at = { x, y }
        prompt:ClearAllPoints()
        prompt:SetPoint("LEFT", board.vp, "BOTTOMLEFT", cx - board.vp:GetLeft() - 4, cy - board.vp:GetBottom())
        prompt:Show(); prompt.box:SetText(""); prompt.box:SetFocus()
    end
    board.onHint = function(msg) status:SetText("|cffffcc66" .. msg .. "|r") end
    board.onView = function()
        if state.plan then local z, cx, cy = board:View(); state.plan.view = { z, cx, cy } end
    end

    local pHead = K.T(right, 13, "white"); pHead:SetPoint("TOPLEFT", 2, -2); pHead:SetText("Players")
    local source = "raid"
    local seg = K.Segmented(right, { "Raid", "Roster", "Roles" }, function(i) source = ({ "raid", "roster", "roles" })[i]; f:RefreshPlayers() end)
    seg:SetPoint("TOPLEFT", 0, -22); seg:SetPoint("RIGHT", 0, 0); seg:SetValue(1)
    local plist = CreateFrame("Frame", nil, right)
    plist:SetPoint("TOPLEFT", 0, -56); plist:SetPoint("RIGHT", 0, 0); plist:SetHeight(220)
    K.Surface(plist, "field", 0.8, "borderDim")
    local psc = CreateFrame("ScrollFrame", nil, plist)
    psc:SetPoint("TOPLEFT", 4, -4); psc:SetPoint("BOTTOMRIGHT", -4, 4)
    psc:EnableMouseWheel(true)
    psc:SetScript("OnMouseWheel", function(self, dd) self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - dd * 40))) end)
    local pbody = CreateFrame("Frame", nil, psc); pbody:SetSize(200, 10); psc:SetScrollChild(pbody)
    psc:SetScript("OnSizeChanged", function(_, w) pbody:SetWidth(w) end)
    local prow = {}

    local nHead = K.T(right, 13, "white"); nHead:SetPoint("TOPLEFT", plist, "BOTTOMLEFT", 2, -12); nHead:SetText("Note")
    local nField = CreateFrame("Frame", nil, right)
    nField:SetPoint("TOPLEFT", nHead, "BOTTOMLEFT", -2, -6); nField:SetPoint("BOTTOMRIGHT", 0, 0)
    K.Surface(nField, "field", 1, "border", 1)
    local nsc = CreateFrame("ScrollFrame", nil, nField)
    nsc:SetPoint("TOPLEFT", 6, -6); nsc:SetPoint("BOTTOMRIGHT", -6, 6)
    local note = CreateFrame("EditBox", nil, nsc)
    note:SetMultiLine(true); note:SetAutoFocus(false); note:SetMaxLetters(1500)
    note:SetFont(K.FONT, 12, ""); note:SetTextColor(0.95, 0.96, 0.98); note:SetWidth(190)
    nsc:SetScrollChild(note)
    nsc:SetScript("OnSizeChanged", function(_, w) note:SetWidth(math.max(60, w)) end)
    nField:EnableMouse(true); nField:SetScript("OnMouseDown", function() note:SetFocus() end)
    note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    note:SetScript("OnTextChanged", function(self, user)
        if user and state.plan then state.plan.note = self:GetText(); state.plan.rev = (state.plan.rev or 0) + 1 end
    end)
    note:SetScript("OnEditFocusLost", function() if state.plan then AM.Changed(state.plan) end end)
    K.Tip(nField, "Note", "Lines with someone's name, roster key, class or role show up as their assignment in Fojji raid packs.")

    local function playerSource()
        local out, seen = {}, {}
        local function add(v, class)
            if not v or v == "" or seen[v:lower()] then return end
            seen[v:lower()] = true
            out[#out + 1] = { v = v, class = class }
        end
        if source == "roles" then
            for _, r in ipairs({ "Tank", "Healer", "Melee", "Ranged" }) do add(r) end
            for _, c in ipairs({ "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid", "Death Knight", "Monk", "Demon Hunter", "Evoker" }) do
                local GS = Addon.GroupSetups
                local cls = GS and GS.ClassOf and GS.ClassOf(c)
                if cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then add(c, cls) end
            end
        elseif source == "roster" then
            local GS = Addon.GroupSetups
            local r = GS and GS.Roster_Keys and GS:Roster_Keys()
            for _, k in ipairs(r and r.order or {}) do add(k) end
        else
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    local n, _, _, _, _, c = GetRaidRosterInfo(i)
                    if n then local GS = Addon.GroupSetups; add(GS and GS.KnownFull and GS.KnownFull((strsplit("-", n))) or (strsplit("-", n)), c) end
                end
            else
                for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
                    if UnitExists(u) then add(UnitName(u), select(2, UnitClass(u))) end
                end
            end
            table.sort(out, function(a, b) return a.v < b.v end)
        end
        return out
    end

    function f:RefreshPlayers()
        local list = playerSource()
        for i, e in ipairs(list) do
            local r = prow[i]
            if not r then
                r = CreateFrame("Button", nil, pbody)
                r:SetHeight(18); r:SetPoint("TOPLEFT", 0, -(i - 1) * 19); r:SetPoint("RIGHT", 0, 0)
                r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture(K.WHITE)
                r.t = K.T(r, 12, "text"); r.t:SetPoint("LEFT", 4, 0); r.t:SetPoint("RIGHT", -4, 0)
                r:RegisterForDrag("LeftButton")
                r:SetScript("OnClick", function(self) board.player = self.v; setTool("player"); f:RefreshPlayers() end)
                r:SetScript("OnDragStart", function(self) board.dragPlayer = self.v; SetCursor("Interface\\Cursor\\Point") end)
                r:SetScript("OnDragStop", function(self)
                    ResetCursor()
                    if board.dragPlayer and board.vp:IsMouseOver() and state.plan then
                        local x, y = board:Cursor()
                        board:Add({ t = "P", s = board.dragPlayer, x = x, y = y })
                    end
                    board.dragPlayer = nil
                end)
                prow[i] = r
            end
            r.v = e.v
            local label, cr, cg, cb = AM.TokenLook(e.v)
            if e.class then local a, b2, c2 = classHex(e.class); if a then cr, cg, cb = a, b2, c2 end end
            r.t:SetText(label)
            r.t:SetTextColor(cr, cg, cb)
            local sel = board.player == e.v
            local ar, ag, ab = K.C("accent")
            r.bg:SetVertexColor(ar, ag, ab, sel and 0.3 or 0)
            r:Show()
        end
        for i = #list + 1, #prow do prow[i]:Hide() end
        pbody:SetHeight(math.max(10, #list * 19))
    end

    local function selectBoss(b)
        state.boss = b
        local plan = AM:Plan(state.raid, b, true)
        state.plan = plan
        board.bosses = state.raid.bosses
        board.boss = b
        board:SetMap(plan.mapID)
        board:SetPlan(plan)
        local v = plan.view
        if v then board:SetView(v[1], v[2], v[3])
        elseif b.x and plan.mapID == b.mapID then board:SetView(2.2, b.x, b.y)
        else board:SetView(1, 0.5, 0.5) end
        note:SetText(plan.note or "")
        AM.DB().last = { raid = state.raid.key, boss = b.name }
        f:Refresh()
    end
    f.SelectBoss = selectBoss

    function f:RefreshBosses()
        local raid = state.raid
        local list = raid and raid.bosses or {}
        for i, b in ipairs(list) do
            local r = bossRows[i]
            if not r then
                r = CreateFrame("Button", nil, left)
                r:SetHeight(26); r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 27); r:SetPoint("RIGHT", -4, 0)
                r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture(K.WHITE)
                r.t = K.T(r, 12, "text"); r.t:SetPoint("LEFT", 8, 0); r.t:SetPoint("RIGHT", -18, 0)
                r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(8, 8); r.dot:SetPoint("RIGHT", -6, 0); r.dot:SetTexture(TEX .. "ui-dot")
                r:SetScript("OnClick", function(self) selectBoss(self.b) end)
                r:SetScript("OnEnter", function(self) if state.boss ~= self.b then self.bg:SetVertexColor(1, 1, 1, 0.06) end end)
                r:SetScript("OnLeave", function() f:RefreshBosses() end)
                bossRows[i] = r
            end
            r.b = b
            r.t:SetText(b.name)
            local plan = AM:Plan(raid, b, false)
            local has = plan and (#plan.items > 0 or (plan.note or "") ~= "")
            local ar, ag, ab = K.C("accent")
            r.dot:SetVertexColor(ar, ag, ab, 1); r.dot:SetShown(has and true or false)
            if state.boss == b then r.bg:SetVertexColor(ar, ag, ab, 0.3); r.t:SetTextColor(1, 1, 1)
            else r.bg:SetVertexColor(0, 0, 0, 0); r.t:SetTextColor(K.C("text")) end
            r:Show()
        end
        for i = #list + 1, #bossRows do bossRows[i]:Hide() end
    end

    local function selectRaid(key, bossName)
        local raid = AM:Raid(key)
        if not raid then return end
        state.raid = raid
        raidDD:SetText(raid.name)
        f:RefreshBosses()
        local pick = raid.bosses[1]
        for _, b in ipairs(raid.bosses) do if bossName and b.name == bossName then pick = b end end
        if pick then selectBoss(pick) end
    end
    f.SelectRaid = selectRaid

    raidDD:SetScript("OnClick", function(self)
        local e, group = {}, nil
        for _, r in ipairs(AM:Raids()) do
            if r.group ~= group then group = r.group; e[#e + 1] = { text = group, header = true } end
            e[#e + 1] = { text = r.name, checked = state.raid and state.raid.key == r.key, onClick = function() selectRaid(r.key) end }
        end
        if Addon.OptionsMenu then Addon.OptionsMenu.Open(self, e, { width = 260, maxRows = 16 }) end
    end)

    function f:Refresh()
        local plan = state.plan
        local floors = (plan and AM.FloorsOf(plan.mapID)) or {}
        local idx = 1
        for i, fl in ipairs(floors) do if plan and fl.mapID == plan.mapID then idx = i end end
        floorText:SetText(floors[idx] and floors[idx].name or "")
        floorPrev:SetShown(#floors > 1); floorNext:SetShown(#floors > 1)
        floorPrev:SetEnabled(idx > 1); floorNext:SetEnabled(idx < #floors)
        local grouped = AM.CanShare()
        share:SetEnabled(grouped and plan ~= nil); share:SetAlpha(share:IsEnabled() and 1 or 0.45)
        show:SetEnabled(grouped and plan ~= nil); show:SetAlpha(show:IsEnabled() and 1 or 0.45)
        if plan then
            status:SetText(plan.by and plan.by ~= UnitName("player") and ("|cff8a8f98from " .. plan.by .. (plan.t and date("  %d/%m %H:%M", plan.t) or "") .. "|r") or "")
        end
        f:RefreshBosses()
        f:RefreshPlayers()
    end

    local function stepFloor(dir)
        local plan = state.plan
        if not plan then return end
        local floors = AM.FloorsOf(plan.mapID)
        for i, fl in ipairs(floors) do
            if fl.mapID == plan.mapID and floors[i + dir] then
                plan.mapID = floors[i + dir].mapID
                plan.view = nil
                board:SetMap(plan.mapID)
                board:SetView(1, 0.5, 0.5)
                AM.Changed(plan)
                f:Refresh()
                return
            end
        end
    end
    floorPrev:SetScript("OnClick", function() stepFloor(-1) end)
    floorNext:SetScript("OnClick", function() stepFloor(1) end)
    hereMap:SetScript("OnClick", function()
        local plan = state.plan
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if not (plan and mapID) then return end
        plan.mapID = mapID; plan.view = nil
        board:SetMap(mapID); board:SetView(1, 0.5, 0.5)
        AM.Changed(plan); f:Refresh()
    end)
    share:SetScript("OnClick", function() if state.plan then AM:Share(state.plan, false) end end)
    show:SetScript("OnClick", function() if state.plan then AM:Share(state.plan, true) end end)
    export:SetScript("OnClick", function() if state.plan then K.CopyBox("Assignments: " .. (state.plan.name or ""), AM:Export(state.plan), "Paste into Import on another FojjiCore.") end end)
    import:SetScript("OnClick", function() AM.OpenImport() end)

    f:EnableKeyboard(false)
    f:SetScript("OnShow", function() K.repaint(); f:Refresh() end)
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:SetScript("OnEvent", function() if f:IsShown() then f:RefreshPlayers() end end)
    AM:OnChange(function(plan)
        if not f:IsShown() then return end
        if plan and state.plan and plan.key == state.plan.key and plan ~= state.plan then
            state.plan = plan
            board:SetPlan(plan)
            note:SetText(plan.note or "")
        end
        f:RefreshBosses()
    end)
    f:Hide()
    return f
end

function AM:Open(key)
    if InCombatLockdown() and not (win and win:IsShown()) then return end
    if not win then win = buildWindow() end
    win:Show(); win:Raise()
    local plan = key and self.DB().plans[key]
    if plan then
        for _, r in ipairs(self:Raids()) do
            local raid = self:Raid(r.key)
            for _, b in ipairs(raid and raid.bosses or {}) do
                if self:PlanKey(raid, b) == key then win.SelectRaid(raid.key, b.name) return end
            end
        end
        local raid = { key = "shared", name = plan.raid or "Shared", bosses = { { name = plan.name or "Boss", custom = key, mapID = plan.mapID } }, floors = {} }
        win.state.raid = raid
        win.SelectBoss(raid.bosses[1])
        return
    end
    local here = self:CurrentRaid()
    local last = self.DB().last
    if here then win.SelectRaid(here)
    elseif last and last.raid and self:Raid(last.raid) then win.SelectRaid(last.raid, last.boss)
    elseif not win.state.raid then
        local first = self:Raids()[1]
        if first then win.SelectRaid(first.key) end
    end
end

function AM:Toggle()
    if win and win:IsShown() then win:Hide() else self:Open() end
end

local importDlg
function AM.OpenImport()
    kit()
    if not importDlg then
        local f = CreateFrame("Frame", "FojjiCoreAssignImport", UIParent)
        f:SetSize(520, 260); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
        K.Surface(f, "frame", 0.98, "accent", 0.85)
        if Addon.EscapeCloses then Addon.EscapeCloses("FojjiCoreAssignImport") end
        local t = K.T(f, 15, "white"); t:SetPoint("TOPLEFT", 16, -14); t:SetText("Import assignments")
        local field = CreateFrame("Frame", nil, f)
        K.Surface(field, "field", 1, "border", 1)
        field:SetPoint("TOPLEFT", 16, -42); field:SetPoint("BOTTOMRIGHT", -16, 50)
        local sc = CreateFrame("ScrollFrame", nil, field); sc:SetPoint("TOPLEFT", 6, -6); sc:SetPoint("BOTTOMRIGHT", -6, 6)
        local eb = CreateFrame("EditBox", nil, sc)
        eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(0); eb:SetFont(K.FONT, 12, ""); eb:SetWidth(470)
        sc:SetScrollChild(eb)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        local ok = K.Button(f, "Import", 110, 28, "primary"); ok:SetPoint("BOTTOMRIGHT", -14, 12)
        local cancel = K.Button(f, "Cancel", 90, 28); cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
        cancel:SetScript("OnClick", function() f:Hide() end)
        ok:SetScript("OnClick", function()
            local plan = AM:Import(eb:GetText())
            if plan then f:Hide(); AM:Open(plan.key) end
        end)
        f.eb = eb
        importDlg = f
    end
    importDlg:ClearAllPoints(); importDlg:SetPoint("CENTER", 0, 80)
    importDlg.eb:SetText("")
    importDlg:Show(); importDlg:Raise(); importDlg.eb:SetFocus()
end

function AM.BuildPositionsView(page, UI)
    kit()
    local d = AM.DB()
    local stack = K.CardStack(page, -44, UI)

    local top = stack:Add(K.Card(page, "Position maps", "Draw where people stand for each boss, then share it with the raid."))
    local open = K.Button(UIParent, "Open maps", 130, 28, "primary", "icon-raid")
    open:SetScript("OnClick", function() AM:Open() end)
    local imp = K.Button(UIParent, "Import", 90, 28)
    imp:SetScript("OnClick", function() AM.OpenImport() end)
    local custom = K.Button(UIParent, "New map here", 130, 28)
    custom:SetScript("OnClick", function() local p = AM:NewCustom(); if p then AM:Open(p.key) end end)
    K.Tip(custom, "New map here", "A free board on the map you're standing on.")
    local row = CreateFrame("Frame")
    open:SetParent(row); open:SetPoint("LEFT", 0, 0)
    imp:SetParent(row); imp:SetPoint("LEFT", open, "RIGHT", 8, 0)
    custom:SetParent(row); custom:SetPoint("LEFT", imp, "RIGHT", 8, 0)
    top:Add(row, 28, 8)

    local shareCard = stack:Add(K.Card(page, "Shared plans"))
    local ACCEPT = { { "lead", "From raid leader and assistants" }, { "all", "From anyone in the group" }, { "none", "Never" } }
    local function acceptText() for _, a in ipairs(ACCEPT) do if a[1] == d.accept then return a[2] end end return ACCEPT[1][2] end
    local acc = K.Dropdown(UIParent, 260, function(self)
        local e = {}
        for _, a in ipairs(ACCEPT) do e[#e + 1] = { text = a[2], checked = d.accept == a[1], onClick = function() d.accept = a[1]; self:SetText(acceptText()) end } end
        K.openMenu(self, e)
    end)
    local cap = K.Caption(UIParent, "Accept")
    local arow = CreateFrame("Frame")
    cap:SetParent(arow); cap:SetPoint("LEFT", 0, 0)
    acc:SetParent(arow); acc:SetPoint("LEFT", 70, 0)
    shareCard:Add(arow, 28, 8)
    local auto = K.SwitchRow(UIParent, "Open plans the leader shows to the raid", function(v) d.autoShow = v end)
    shareCard:Add(auto, 24, 6)

    local saved = stack:Add(K.Card(page, "Saved plans"))
    local holder = CreateFrame("Frame"); saved:Add(holder, 10, 6)
    local lines = {}
    local function refresh()
        acc:SetText(acceptText())
        auto:SetValue(d.autoShow)
        local list = {}
        for key, p in pairs(d.plans) do
            if #(p.items or {}) > 0 or (p.note or "") ~= "" then list[#list + 1] = p end
        end
        table.sort(list, function(a, b) if (a.raid or "") ~= (b.raid or "") then return (a.raid or "") < (b.raid or "") end return (a.name or "") < (b.name or "") end)
        for i, p in ipairs(list) do
            local l = lines[i]
            if not l then
                l = CreateFrame("Frame", nil, holder); l:SetHeight(30)
                l:SetPoint("TOPLEFT", 0, -(i - 1) * 34); l:SetPoint("RIGHT", 0, 0)
                K.Surface(l, "field", 0.7, "borderDim")
                l.label = K.T(l, 13, "text"); l.label:SetPoint("LEFT", 10, 0); l.label:SetPoint("RIGHT", -250, 0)
                l.del = K.Button(l, "", 26, 22, "danger", "icon-minus"); l.del:SetPoint("RIGHT", -4, 0)
                l.exp = K.Button(l, "Export", 70, 22); l.exp:SetPoint("RIGHT", l.del, "LEFT", -6, 0)
                l.share = K.Button(l, "Share", 64, 22); l.share:SetPoint("RIGHT", l.exp, "LEFT", -6, 0)
                l.open = K.Button(l, "Open", 64, 22, "primary"); l.open:SetPoint("RIGHT", l.share, "LEFT", -6, 0)
                l.open:SetScript("OnClick", function() AM:Open(l.key) end)
                l.share:SetScript("OnClick", function() local p2 = d.plans[l.key]; if p2 then AM:Share(p2, false) end end)
                l.exp:SetScript("OnClick", function() local p2 = d.plans[l.key]; if p2 then K.CopyBox("Assignments: " .. (p2.name or ""), AM:Export(p2), "Paste into Import on another FojjiCore.") end end)
                l.del:SetScript("OnClick", function()
                    if l.armed then AM:Delete(l.key) else
                        l.armed = true; l.del.label:SetText("?")
                        C_Timer.After(3, function() l.armed = nil; l.del.label:SetText("") end)
                    end
                end)
                lines[i] = l
            end
            l.key = p.key
            l.label:SetText((p.name or "?") .. "  |cff8a8f98" .. (p.raid or "") .. (p.by and p.by ~= UnitName("player") and ("  -  from " .. p.by) or "") .. "|r")
            l:Show()
        end
        for i = #list + 1, #lines do lines[i]:Hide() end
        local h = math.max(1, #list) * 34
        if #list == 0 then
            holder.empty = holder.empty or K.T(holder, 12, "dim")
            holder.empty:SetPoint("TOPLEFT", 0, -4); holder.empty:SetText("No plans yet."); holder.empty:Show()
            h = 24
        elseif holder.empty then holder.empty:Hide() end
        holder:SetHeight(h)
        for _, it in ipairs(saved.items) do if it.w == holder then it.h = h end end
        stack:Layout()
    end
    AM:OnChange(function() if page:IsVisible() then refresh() end end)
    page:HookScript("OnShow", function() K.repaint(); refresh() end)
end
