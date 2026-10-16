local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ
local Pins = FDJ.Pins
local L = FDJ.L
local function say(text) FDJ.PrintAs("FojjiCore", text) end
local Guard = Addon.Guard or function(fn) return fn end

local WP = {}
FDJ.WP = WP

local COLOR = FDJ.WaypointColor
local MAX = 100

function WP.List()
    if not FDJ.db then return {} end
    FDJ.db.waypoints = FDJ.db.waypoints or {}
    return FDJ.db.waypoints
end

local function worldPos(m, x, y)
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if ok and cont and pos then return cont, pos end
    return nil
end

function WP.CanPlace(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    if not info then return false end
    if Enum and Enum.UIMapType and (info.mapType == Enum.UIMapType.Dungeon or info.mapType < Enum.UIMapType.Continent) then return false end
    return worldPos(mapID, 0.5, 0.5) ~= nil
end

local function changed()
    FDJ:Emit("FDJ_WAYPOINTS")
end

function WP.Add(m, x, y, title, opts)
    opts = opts or {}
    if not WP.CanPlace(m) then
        if not opts.quiet then say(L.WP_NO_DUNGEON) end
        return nil
    end
    local list = WP.List()
    for _, old in ipairs(list) do
        if old.m == m and math.abs(old.x - x) < 0.0005 and math.abs(old.y - y) < 0.0005 then
            if opts.route then old.route = opts.route end
            if opts.stop then old.stop = opts.stop end
            if opts.pickup then old.pickup = opts.pickup end
            if title and not old.title then old.title = FDJ.Clip(title, 80) end
            if opts.focus then WP.focus = old end
            if not opts.quiet then say(L.WP_EXISTS:format(FDJ.Hi(FDJ.MapName(m)), FDJ.Paint("accent", ("%.1f, %.1f"):format(x * 100, y * 100)))) end
            changed()
            return old
        end
    end
    if #list >= MAX then table.remove(list, 1) end
    local wp = { m = m, x = x, y = y, title = title and FDJ.Clip(title, 80) or nil, route = opts.route, stop = opts.stop, pickup = opts.pickup }
    list[#list + 1] = wp
    if opts.focus then WP.focus = wp end
    if not opts.quiet then
        say(L.WP_ADDED:format(FDJ.Hi(FDJ.MapName(m)), FDJ.Paint("accent", ("%.1f, %.1f"):format(x * 100, y * 100))))
    end
    changed()
    return wp
end

function WP.Remove(wp, arrived)
    local list = WP.List()
    for i = #list, 1, -1 do
        if list[i] == wp then table.remove(list, i) end
    end
    if WP.focus == wp then WP.focus = nil end
    if WP.target == wp then WP.target = nil end
    if wp.route and arrived and FDJ.Routes then
        local route = FDJ.Routes.Get(wp.route)
        if route and route.points[(wp.stop or 0) + 1] then
            FDJ.Routes.Follow(route, wp.stop + 1)
            return
        elseif route then
            say(L.ROUTE_DONE:format(FDJ.Hi(route.name)))
        end
    end
    changed()
end

function WP.RemoveWhere(fn)
    local list = WP.List()
    local hit = false
    for i = #list, 1, -1 do
        if fn(list[i]) then
            if WP.focus == list[i] then WP.focus = nil end
            if WP.target == list[i] then WP.target = nil end
            table.remove(list, i)
            hit = true
        end
    end
    return hit
end

function WP.Clear(quiet)
    local list = WP.List()
    local n = #list
    wipe(list)
    WP.focus, WP.target = nil, nil
    changed()
    if not quiet then say(n > 0 and L.WP_CLEARED or L.WP_NONE) end
end

function WP.Move(wp, m, x, y)
    if not WP.CanPlace(m) then return end
    wp.m, wp.x, wp.y = m, x, y
    changed()
end

local cache, cacheMap = setmetatable({}, { __mode = "k" }), nil
local tick, mineX, mineY = -1, {}, {}

local function playerOn(mapID)
    local now = GetTime()
    if now ~= tick then
        tick = now
        wipe(mineX)
        wipe(mineY)
    end
    local x = mineX[mapID]
    if x == nil then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        local px, py
        if pos then px, py = FDJ.XY(pos) end
        mineX[mapID] = px or false
        mineY[mapID] = py or false
        x = px or false
    end
    if not x then return nil end
    return x, mineY[mapID]
end

local function locate(wp, start)
    local mapID, guard = start, 0
    while mapID and guard < 6 do
        guard = guard + 1
        local tx, ty
        if wp.m == mapID then
            tx, ty = wp.x, wp.y
        else
            local cont, pos = worldPos(wp.m, wp.x, wp.y)
            if cont and C_Map.GetMapPosFromWorldPos then
                local ok, got, p = pcall(C_Map.GetMapPosFromWorldPos, cont, pos, mapID)
                if ok and got == mapID and p then tx, ty = FDJ.XY(p) end
            end
        end
        if tx then
            local w, h = 0, 0
            if C_Map.GetMapWorldSize then w, h = C_Map.GetMapWorldSize(mapID) end
            if w and w > 0 then return { map = mapID, x = tx, y = ty, w = w, h = h } end
        end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        if mapID == 0 then mapID = nil end
    end
    return false
end

function WP.Offset(wp)
    local pm = C_Map.GetBestMapForUnit("player")
    if not pm then return nil end
    if pm ~= cacheMap then
        cacheMap = pm
        wipe(cache)
    end
    local spot = cache[wp]
    if spot == nil or (spot and (spot.m ~= wp.m or spot.sx ~= wp.x or spot.sy ~= wp.y)) then
        spot = locate(wp, pm)
        if spot then spot.m, spot.sx, spot.sy = wp.m, wp.x, wp.y end
        cache[wp] = spot
    end
    if not spot then return nil end
    local mx, my = playerOn(spot.map)
    if not mx then return nil end
    return (spot.x - mx) * spot.w, (spot.y - my) * spot.h
end

function WP.Following()
    for _, wp in ipairs(WP.List()) do
        if wp.route then return wp end
    end
    return nil
end

local function pick()
    local follow = WP.Following()
    if follow then return follow, WP.Offset(follow) end
    local focus = WP.focus
    if focus then return focus, WP.Offset(focus) end
    local best, bx, by, bd
    for _, wp in ipairs(WP.List()) do
        local dx, dy = WP.Offset(wp)
        if dx then
            local d = dx * dx + dy * dy
            if not bd or d < bd then best, bx, by, bd = wp, dx, dy, d end
        end
    end
    if best then return best, bx, by end
    return WP.List()[1], nil, nil
end

WP.Pick = pick

local tracker

local function describe(wp)
    if not wp then return L.WP_TITLE, "" end
    local where = ("%.1f, %.1f  %s"):format(wp.x * 100, wp.y * 100, FDJ.MapName(wp.m) or "")
    local route = wp.route and FDJ.Routes and FDJ.Routes.Get(wp.route)
    if route then
        return route.name, L.ROUTE_STOP:format(wp.stop or 1, #route.points) .. "  " .. (wp.title or where)
    end
    local n = #WP.List()
    local label = wp.title or L.WP_TITLE
    if n > 1 then label = label .. FDJ.Paint("dim", "  +" .. (n - 1)) end
    return label, where
end

local function retarget(wp)
    if not tracker then return end
    WP.target = wp
    local label, sub = describe(wp)
    Pins.SetTarget(tracker, label, sub)
    tracker.route = wp and wp.route and true or nil
    tracker:SyncSteps()
end

local KIND = {
    name = "FojjiCoreOwnWaypointArrow",
    posKey = "wparrow",
    home = { 475, 276 },
    color = COLOR,
    title = L.WP_TITLE,
    closeTip = L.WP_CLOSE,
    offset = function()
        local wp, dx, dy = pick()
        if wp ~= WP.target then retarget(wp) end
        return dx, dy
    end,
    refresh = function() WP.UpdateArrow() end,
    onClose = function()
        local wp = WP.target
        if not wp then return end
        if wp.route and FDJ.Routes then FDJ.Routes.Unfollow() else WP.Remove(wp) end
    end,
    onStep = function(delta) if FDJ.Routes then FDJ.Routes.Step(delta) end end,
    onArrive = function()
        local wp = WP.target
        if not wp then return false end
        WP.Remove(wp, true)
        return true
    end,
}

WP.Describe = describe

function WP.UpdateArrow()
    if tracker and tracker.preview then return end
    local want = FDJ:Option("wpArrow") and #WP.List() > 0
    if not want then
        if tracker then tracker:Hide() end
        return
    end
    tracker = tracker or Pins.NewTracker(KIND)
    retarget((pick()))
    tracker:Show()
end

function WP.Preview()
    if not FDJ:Option("wpArrow") then return end
    tracker = tracker or Pins.NewTracker(KIND)
    Pins.Preview(tracker, L.WP_TITLE, L.ARROW_PREVIEW_SUB)
end

local pins
local function makePin()
    local layer = FDJ.WorldLayer.Layer()
    local pin = FDJ.NewFrame("Button", nil, layer)
    pin:SetSize(24, 24)
    pin:SetFrameLevel(layer:GetFrameLevel() + 9)
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetPoint("CENTER")
    pin.ring:SetSize(30, 30)
    pin.ring:SetTexture(FDJ.Glyph("fc:glow-soft"))
    pin.ring:SetVertexColor(COLOR[1], COLOR[2], COLOR[3], 0.55)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    FDJ.WaypointIcon(pin.icon)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:RegisterForDrag("LeftButton")
    pin:SetScript("OnEnter", function(self)
        local wp = self.wp
        if not wp then return end
        local label, sub = describe(wp)
        FDJ.Kit.Tip(self, wp.title or label, { sub, " ", L.WP_PIN_HINT })
    end)
    pin:SetScript("OnLeave", function() FDJ.Kit.HideTip() end)
    pin:SetScript("OnClick", function(self, button)
        local wp = self.wp
        if not wp then return end
        if button == "RightButton" then
            if wp.route and FDJ.Routes then FDJ.Routes.Unfollow() else WP.Remove(wp) end
        else
            WP.focus = wp
            changed()
        end
    end)
    pin:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function(me)
            local x, y = FDJ.WorldLayer.Cursor()
            if x then FDJ.WorldLayer.Place(me, FDJ.Clamp(x, 0, 1), FDJ.Clamp(y, 0, 1)) end
        end)
    end)
    pin:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
        local x, y = FDJ.WorldLayer.Cursor()
        local m = FDJ.WorldLayer.MapID()
        if self.wp and x and m and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            WP.Move(self.wp, m, x, y)
        else
            changed()
        end
    end)
    return pin
end

local function drawMap(mapID)
    if not FDJ.WorldLayer.Layer() then return end
    pins = pins or FDJ.Kit.Pool(makePin)
    pins:Reset()
    if not mapID then return end
    local project = FDJ.WorldLayer.Project
    for _, wp in ipairs(WP.List()) do
        local x, y = project(wp.m, wp.x, wp.y, mapID)
        if x then
            local pin = pins:Get()
            pin.wp = wp
            local on = wp == WP.target
            local sz = on and 26 or 22
            pin:SetSize(sz, sz)
            pin.ring:SetSize(sz * 1.5, sz * 1.5)
            pin.ring:SetShown(on)
            pin:SetAlpha(on and 1 or 0.9)
            FDJ.WorldLayer.Place(pin, x, y)
        end
    end
end

FDJ:On("FDJ_WORLD_REFRESH", function(mapID) Guard(drawMap)(mapID) end)
FDJ:On("FDJ_WAYPOINTS", function()
    WP.UpdateArrow()
    if FDJ.Way and FDJ.Way.UpdateMinimap then FDJ.Way.UpdateMinimap() end
end)
FDJ:On("FDJ_OPTION", function(key)
    if key == "wpArrow" then WP.UpdateArrow() end
end)
FDJ:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(2, function()
        WP.UpdateArrow()
        if FDJ.Way and FDJ.Way.UpdateMinimap then FDJ.Way.UpdateMinimap() end
    end)
end)

local clearButton

local function findBlizzardPinButton(host)
    local hl, ht = host:GetLeft(), host:GetTop()
    if not hl then return nil end
    for _, f in ipairs(WorldMapFrame.overlayFrames or {}) do
        if f ~= clearButton and f.IsShown and f:IsShown() and f.GetLeft then
            local l, t, w = f:GetLeft(), f:GetTop(), f:GetWidth()
            if l and t and w and w < 60 and math.abs(l - hl) < 40 and math.abs(t - ht) < 40 then return f end
        end
    end
    return nil
end

local function placeClear()
    local host = WorldMapFrame.ScrollContainer
    clearButton:ClearAllPoints()
    local blizz = findBlizzardPinButton(host)
    if blizz then
        clearButton:SetPoint("LEFT", blizz, "RIGHT", 2, 0)
    else
        clearButton:SetPoint("TOPLEFT", host, "TOPLEFT", 40, -4)
    end
end

local function syncClear()
    if not clearButton then return end
    local n = #WP.List()
    local show = n > 0 and WorldMapFrame and WorldMapFrame:IsShown()
    if show then placeClear() end
    clearButton:SetShown(show and true or false)
end

local function buildClear()
    if clearButton or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    local host = WorldMapFrame.ScrollContainer
    local b = FDJ.NewFrame("Button", nil, WorldMapFrame)
    b:SetSize(31, 31)
    b:SetFrameStrata(WorldMapFrame:GetFrameStrata())
    b:SetFrameLevel(host:GetFrameLevel() + 600)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetSize(22, 22)
    b.bg:SetPoint("CENTER")
    b.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    b.bg:SetVertexColor(0, 0, 0, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("CENTER")
    FDJ.WaypointIcon(b.icon)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetSize(53, 53)
    b.border:SetPoint("TOPLEFT")
    b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.x = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.x:SetSize(12, 12)
    b.x:SetPoint("TOPRIGHT", 1, 1)
    b.x:SetTexture("Interface\\Buttons\\UI-StopButton")
    b.x:SetVertexColor(1, 0.25, 0.25)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    b:RegisterForClicks("RightButtonUp")
    b:SetScript("OnClick", function() WP.Clear() end)
    b:SetScript("OnEnter", function(self)
        FDJ.Kit.Tip(self, L.WP_BUTTON:format(#WP.List()), L.WP_BUTTON_TIP, "ANCHOR_BOTTOM")
    end)
    b:SetScript("OnLeave", function() FDJ.Kit.HideTip() end)
    FDJ.WatchFrame(WorldMapFrame, function() C_Timer.After(0, syncClear) end)
    clearButton = b
    syncClear()
end

FDJ:On("FDJ_WAYPOINTS", syncClear)
FDJ:On("PLAYER_LOGIN", function() C_Timer.After(1, function() Guard(buildClear)() end) end)
FDJ:On("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" then C_Timer.After(0, function() Guard(buildClear)() end) end
end)
