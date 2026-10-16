local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ
local Pins = FDJ.Pins
local L = FDJ.L
local Guard = Addon.Guard or function(fn) return fn end
local function say(text) FDJ.PrintAs("FojjiCore", text) end

local Way = {}
FDJ.Way = Way

local zoneIndex, zoneNames
local KEEP = { [2] = 3, [3] = 1, [5] = 2 }

local function squash(s)
    return (s:lower():gsub("[%s'%-]", ""))
end

local function buildIndex()
    zoneIndex, zoneNames = {}, {}
    local rank = {}
    for id = 1, 3000 do
        local info = C_Map.GetMapInfo(id)
        local r = info and info.name and info.name ~= "" and KEEP[info.mapType]
        if r then
            local key = squash(info.name)
            if not zoneIndex[key] or r < rank[key] then
                zoneIndex[key] = id
                zoneNames[key] = info.name
                rank[key] = r
            end
        end
    end
end

function Way.ResolveZone(text)
    local forced = text:match("^#(%d+)$")
    if forced then
        local id = tonumber(forced)
        if C_Map.GetMapInfo(id) then return id end
        return nil, L.WAY_ZONE_NONE:format(text)
    end
    if not zoneIndex then buildIndex() end
    local q = squash(text)
    if q == "" then return nil, L.WAY_USAGE end
    if zoneIndex[q] then return zoneIndex[q] end
    local hits = {}
    for key, id in pairs(zoneIndex) do
        if key:find(q, 1, true) then hits[#hits + 1] = key end
    end
    if #hits == 1 then return zoneIndex[hits[1]] end
    if #hits == 0 then return nil, L.WAY_ZONE_NONE:format(text) end
    local names = {}
    for i, key in ipairs(hits) do names[i] = zoneNames[key] end
    table.sort(names)
    if #names > 7 then
        for i = #names, 8, -1 do names[i] = nil end
        names[8] = "..."
    end
    return nil, L.WAY_ZONE_MANY:format(text, table.concat(names, ", "))
end

function Way.Parse(msg)
    msg = (msg or ""):gsub("(%d)[%.,] (%d)", "%1 %2"):gsub("(%d),(%d)", "%1.%2")
    local tokens = {}
    for token in msg:gmatch("%S+") do tokens[#tokens + 1] = token end
    if #tokens == 0 then return nil, L.WAY_USAGE end
    local first = tokens[1]:lower()
    if first == "clear" or first == "reset" or first == "remove" then return "clear" end
    local at
    for i, token in ipairs(tokens) do
        if tonumber(token) then
            at = i
            break
        end
    end
    local x, y = at and tonumber(tokens[at]), at and tonumber(tokens[at + 1] or "")
    if not (x and y) or x < 0 or x > 100 or y < 0 or y > 100 then return nil, L.WAY_USAGE end
    local mapID, err
    if at > 1 then
        mapID, err = Way.ResolveZone(table.concat(tokens, " ", 1, at - 1))
        if not mapID then return nil, err end
    else
        mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return nil, L.NO_WAYPOINT end
    end
    local title = tokens[at + 2] and table.concat(tokens, " ", at + 2) or nil
    return mapID, x / 100, y / 100, title
end

function Way.Clear(quiet)
    FDJ.WP.Clear(quiet)
end

function Way.RunMany(text)
    local Routes = FDJ.Routes
    local stops, bad = {}, 0
    for line in (text or ""):gmatch("[^\r\n]+") do
        line = line:gsub("^%s*/%S+", "")
        if line:match("%S") then
            local m, x, y, title = Way.Parse(line)
            if m and m ~= "clear" then
                stops[#stops + 1] = { m = m, x = x, y = y, label = title }
            else
                bad = bad + 1
            end
        end
    end
    if #stops == 0 then
        say(L.WAY_PASTE_NONE)
        return false
    end
    if #stops == 1 then
        local s = stops[1]
        FDJ.WP.Add(s.m, s.x, s.y, s.label, { focus = true })
    else
        local route = Routes.Create("world", nil, L.WAY_PASTE_ROUTE)
        for _, s in ipairs(stops) do
            local i = Routes.Add(route, s.m, s.x, s.y)
            if i and s.label then Routes.Label(route, i, s.label) end
        end
        Routes.Follow(route, 1)
        say(L.WAY_PASTE_MADE:format(#route.points))
    end
    if bad > 0 then say(L.WAY_PASTE_SKIPPED:format(bad)) end
    return true
end

function Way.Paste()
    FDJ.Kit.TextWindow(L.WAY_PASTE_TITLE, "", Way.RunMany, L.WAY_PASTE_HINT, L.WAY_PASTE_GO)
end

function Way.Run(msg, quiet)
    if not quiet and (msg or ""):match("^%s*[Pp][Aa][Ss][Tt][Ee]%s*$") then return Way.Paste() end
    local m, x, y, title = Way.Parse(msg)
    if m == "clear" then return Way.Clear(quiet) end
    if not m then
        if not quiet and x then say(x) end
        return
    end
    FDJ.WP.Add(m, x, y, title, { quiet = quiet, focus = true })
end

local SIZE = {
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
    outdoor = { [0] = 466.667, 400, 333.333, 266.667, 200, 133.333 },
}

local driver, pool
local rotate, square, recheck, dirty = false, false, 0, true

-- Credit: HereBeDragons-Pins (the minimapZoom / minimapInsideZoom check).
local indoors, checking = false, false
local minimapIndoors
local function checkIndoors()
    if checking or not (Minimap and Minimap.GetZoom and GetCVar) then return end
    checking = true
    local zoom = Minimap:GetZoom()
    if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
        Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
        indoors = tonumber(GetCVar("minimapZoom")) ~= Minimap:GetZoom()
        Minimap:SetZoom(zoom)
    else
        indoors = tonumber(GetCVar("minimapZoom")) ~= zoom
    end
    checking = false
end
minimapIndoors = function() return indoors end

local function newPin()
    local Kit = FDJ.Kit
    local pin = CreateFrame("Frame", nil, Minimap)
    pin:SetSize(16, 16)
    pin:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin:EnableMouse(true)
    if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(false) end
    pin:SetScript("OnEnter", function(self)
        local t = self.target
        if not t then return end
        Kit.Tip(self, t.title or L.WP_TITLE, ("%s  %.1f, %.1f"):format(FDJ.MapName(t.m), t.x * 100, t.y * 100), "ANCHOR_LEFT")
    end)
    pin:SetScript("OnLeave", function() Kit.HideTip() end)
    pin:Hide()
    return pin
end

local function placeOne(pin, dx, dy, radius, facing)
    local ex, ny = dx, -dy
    if facing then
        local c, s = math.cos(facing), math.sin(facing)
        ex, ny = ex * c + ny * s, ny * c - ex * s
    end
    local px, py = ex / radius, ny / radius
    local edge
    if square then
        local big = math.max(math.abs(px), math.abs(py))
        if big > 0.95 then
            px, py = px / big * 0.95, py / big * 0.95
            edge = true
        end
    else
        local d = math.sqrt(px * px + py * py)
        if d > 0.9 then
            px, py = px / d * 0.9, py / d * 0.9
            edge = true
        end
    end
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", Minimap, "CENTER", px * Minimap:GetWidth() / 2, py * Minimap:GetHeight() / 2)
    pin:SetAlpha(edge and 0.7 or 1)
    pin:SetScale(edge and 0.85 or 1)
    pin:Show()
end

local nativeTarget = {}

local function place()
    local zoom = Minimap:GetZoom() or 0
    local list = (minimapIndoors() and SIZE.indoor or SIZE.outdoor)
    local radius = (list[zoom] or list[0]) / 2
    local facing
    if rotate and GetPlayerFacing then
        facing = GetPlayerFacing()
        if FDJ.Secret(facing) then facing = nil end
    end
    local n = 0
    local C = FDJ.Colors
    if Pins.HasOwn() then
        local dx, dy = Pins.Offset()
        if dx then
            n = n + 1
            local pin = pool[n] or newPin()
            pool[n] = pin
            local m, x, y = Pins.Native()
            nativeTarget.m, nativeTarget.x, nativeTarget.y, nativeTarget.title = m, x, y, Pins.label or L.ARROW_TITLE
            pin.target = m and nativeTarget or nil
            if pin.kind ~= "native" then
                pin.kind = "native"
                if not (pin.icon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Waypoint-MapPin-Untracked") and pin.icon:SetAtlas("Waypoint-MapPin-Untracked") ~= false) then
                    pin.icon:SetTexture(FDJ.Glyph("fc:pin"))
                    pin.icon:SetVertexColor(FDJ.Kit.RGB(C.accent))
                else
                    pin.icon:SetDesaturated(false)
                    pin.icon:SetVertexColor(1, 1, 1)
                    if pin.icon.lift then pin.icon.lift:Hide() end
                end
            end
            placeOne(pin, dx, dy, radius, facing)
        end
    end
    local WP = FDJ.WP
    for _, wp in ipairs(WP and WP.List() or {}) do
        local dx, dy = WP.Offset(wp)
        if dx then
            n = n + 1
            local pin = pool[n] or newPin()
            pool[n] = pin
            pin.target = wp
            if pin.kind ~= "wp" then
                pin.kind = "wp"
                FDJ.WaypointIcon(pin.icon)
            end
            placeOne(pin, dx, dy, radius, facing)
        end
    end
    for i = n + 1, #pool do pool[i]:Hide() end
end

local function refreshShape()
    rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local shape = GetMinimapShape and GetMinimapShape()
    square = shape ~= nil and shape ~= "ROUND"
end

local function minimapSpot()
    local zoom = Minimap:GetZoom() or 0
    local list = (minimapIndoors() and SIZE.indoor or SIZE.outdoor)
    local radius = (list[zoom] or list[0]) / 2
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local mx, my = Minimap:GetCenter()
    if not (cx and mx) then return nil end
    local ex = (cx / scale - mx) / (Minimap:GetWidth() / 2) * radius
    local ny = (cy / scale - my) / (Minimap:GetHeight() / 2) * radius
    refreshShape()
    if rotate and GetPlayerFacing then
        local facing = GetPlayerFacing()
        if facing and not FDJ.Secret(facing) then
            local c, sn = math.cos(facing), math.sin(facing)
            ex, ny = ex * c - ny * sn, ny * c + ex * sn
        end
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and guard < 6 do
        guard = guard + 1
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        local w, h = 0, 0
        if C_Map.GetMapWorldSize then w, h = C_Map.GetMapWorldSize(mapID) end
        if pos and w and w > 0 and h and h > 0 then
            local px, py = FDJ.XY(pos)
            if px then
                local x, y = px + ex / w, py - ny / h
                if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return mapID, x, y end
            end
        end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        if mapID == 0 then mapID = nil end
    end
    return nil
end

local minimapHooked
local function hookMinimap()
    if minimapHooked or not (Minimap and Minimap.HookScript) then return end
    minimapHooked = true
    Minimap:HookScript("OnMouseUp", Guard(function(_, button)
        if button ~= "RightButton" or not FDJ:Option("mapClick") then return end
        if not IsControlKeyDown() or IsAltKeyDown() or IsShiftKeyDown() then return end
        local m, x, y = minimapSpot()
        if m then FDJ.WP.Add(m, x, y, nil, { focus = true }) end
    end))
end

function Way.UpdateMinimap()
    if not Minimap then return end
    local any = Pins.HasOwn() or (FDJ.WP and #FDJ.WP.List() > 0)
    local want = FDJ:Option("minimapPin") and any and not FDJ.InInstance()
    pool = pool or {}
    if not want then
        if driver then driver:Hide() end
        for _, p in ipairs(pool) do p:Hide() end
        return
    end
    if not driver then
        driver = CreateFrame("Frame")
        local acc = 1
        local lx, ly, lf, lz, li, lw
        driver:SetScript("OnUpdate", Guard(function(_, dt)
            acc = acc + dt
            if acc < 0.05 then return end
            recheck = recheck + acc
            acc = 0
            if recheck > 2 then
                recheck = 0
                refreshShape()
                dirty = true
            end
            local y, x = UnitPosition("player")
            if FDJ.Secret(x) or FDJ.Secret(y) then x, y = nil, nil end
            local f = 0
            if rotate and GetPlayerFacing then
                f = GetPlayerFacing()
                if FDJ.Secret(f) or not f then f = 0 end
            end
            local z = Minimap:GetZoom() or 0
            local i = minimapIndoors()
            local w = Minimap:GetWidth()
            if not dirty and x == lx and y == ly and f == lf and z == lz and i == li and w == lw then return end
            dirty = false
            lx, ly, lf, lz, li, lw = x, y, f, z, i, w
            place()
        end))
    end
    if not driver:IsShown() then checkIndoors() end
    refreshShape()
    dirty = true
    driver:Show()
end

FDJ:On("FDJ_PINS", function() Way.UpdateMinimap() end)
FDJ:On("FDJ_WAYPOINTS", function() dirty = true end)
FDJ:On("FDJ_OPTION", function(key)
    if key == "minimapPin" then Way.UpdateMinimap() end
end)

local clicker
local function syncClicker()
    if not clicker then return end
    local want = FDJ:Option("mapClick") and IsControlKeyDown() and not IsAltKeyDown() and not IsShiftKeyDown()
        and WorldMapFrame:IsShown()
    clicker:SetShown(want and true or false)
end

local function setupClicker()
    if clicker or not (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.GetNormalizedCursorPosition) then return end
    if InCombatLockdown() then return end
    local host = WorldMapFrame.ScrollContainer
    clicker = CreateFrame("Frame", nil, host)
    clicker:SetAllPoints(host)
    clicker:SetFrameLevel(math.min(host:GetFrameLevel() + 500, 9000))
    clicker:EnableMouse(true)
    clicker.passLeft = clicker.SetPassThroughButtons and pcall(clicker.SetPassThroughButtons, clicker, "LeftButton", "MiddleButton", "Button4", "Button5")
    if clicker.SetPropagateMouseMotion then pcall(clicker.SetPropagateMouseMotion, clicker, true) end
    clicker:Hide()
    clicker:SetScript("OnMouseUp", Guard(function(self, button)
        if button ~= "RightButton" and not (button == "LeftButton" and not self.passLeft) then return end
        local m = WorldMapFrame:GetMapID()
        local x, y = WorldMapFrame:GetNormalizedCursorPosition()
        if not (m and x and y) or x < 0 or x > 1 or y < 0 or y > 1 then return end
        if button == "RightButton" then
            FDJ.WP.Add(m, x, y, nil, { focus = true })
        else
            Pins.WaypointAt(m, x, y)
        end
    end))
    clicker:SetScript("OnEvent", syncClicker)
    FDJ.WatchFrame(WorldMapFrame, function()
        clicker:RegisterEvent("MODIFIER_STATE_CHANGED")
        syncClicker()
    end, function()
        clicker:UnregisterEvent("MODIFIER_STATE_CHANGED")
        clicker:Hide()
    end)
    if WorldMapFrame:IsShown() then clicker:RegisterEvent("MODIFIER_STATE_CHANGED") end
end

FDJ:On("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" then C_Timer.After(0, setupClicker) end
end)
FDJ:On("PLAYER_REGEN_ENABLED", function() if not clicker then setupClicker() end end)

FDJ:On("PLAYER_LOGIN", function()
    C_Timer.After(1, setupClicker)
    local tomtom = SlashCmdList and SlashCmdList.TOMTOM_WAY
    if type(tomtom) == "function" then
        SlashCmdList.TOMTOM_WAY = function(msg, ...)
            tomtom(msg, ...)
            Guard(Way.Run)(msg, true)
        end
    else
        SLASH_FOJJICOREWAY1 = "/way"
        SLASH_FOJJICOREWAY2 = "/fway"
        SlashCmdList.FOJJICOREWAY = function(msg) Guard(Way.Run)(msg) end
    end
    SLASH_FOJJICOREWAYPASTE1 = "/waypaste"
    SlashCmdList.FOJJICOREWAYPASTE = function() Way.Paste() end
    if not SLASH_FOJJICOREWAY2 then
        SLASH_FOJJICOREFWAY1 = "/fway"
        SlashCmdList.FOJJICOREFWAY = function(msg) Guard(Way.Run)(msg) end
    end
    C_Timer.After(2, Way.UpdateMinimap)
    hookMinimap()
end)

local function rescale()
    if FDJ.InInstance() or not (driver and driver:IsShown()) then return end
    checkIndoors()
    dirty = true
end
FDJ:On("MINIMAP_UPDATE_ZOOM", function() dirty = true end)
FDJ:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(0.5, function() Way.UpdateMinimap() rescale() end) end)
FDJ:On("ZONE_CHANGED_INDOORS", function() C_Timer.After(0.2, rescale) end)
FDJ:On("ZONE_CHANGED", function() C_Timer.After(0.2, rescale) end)
