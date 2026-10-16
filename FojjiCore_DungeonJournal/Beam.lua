local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ
local L = FDJ.L

-- Credit: idea from Questline's world marker (anchoring to C_Navigation.GetFrame); our own art.
local Beam = {}
FDJ.Beam = Beam

local NEAR, FAR, GONE = 100, 110, 3
local CLOSE = 25
local FADE = 0.35
local TICK = 0.03
local GOLD = { 1.00, 0.80, 0.26 }
local BLUE = { 0.45, 0.78, 1.00 }

local Pins = FDJ.Pins
local beam, driver
local shown = 0
local want = false

local blizz, blizzBase, guard = nil, 1, false
local function blizzFactor()
    if Pins.borrowed then return 0 end
    return 1 - shown
end
local function blizzAlpha()
    if Addon.GamepadUI and Addon.GamepadUI() then return end
    if not blizz then
        blizz = _G.SuperTrackedFrame
        if not blizz then return end
        blizzBase = blizz:GetAlpha() or 1
        hooksecurefunc(blizz, "SetAlpha", function(fr, a)
            if guard then return end
            blizzBase = a or 1
            local k = blizzFactor()
            if k < 1 then
                guard = true
                fr:SetAlpha(blizzBase * k)
                guard = false
            end
        end)
    end
    guard = true
    blizz:SetAlpha(blizzBase * blizzFactor())
    guard = false
end

local function build()
    local Kit, C = FDJ.Kit, FDJ.Colors
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(1, 1)
    f:SetFrameStrata("BACKGROUND")
    f:EnableMouse(false)
    local tex = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
    local glows = {}
    local function layer(w, h, a, file, sub)
        local t = f:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetTexture(tex .. file)
        t:SetSize(w, h)
        t:SetBlendMode("ADD")
        t.a = a
        glows[#glows + 1] = t
        return t
    end
    f.glow = layer(70, 190, 0.5, "wp-beam", 1)
    f.glow:SetPoint("BOTTOM", f, "CENTER", 0, -4)
    f.core = layer(22, 190, 1, "wp-beam", 2)
    f.core:SetPoint("BOTTOM", f, "CENTER", 0, -4)
    f.pool = layer(96, 30, 0.55, "glow-soft", 0)
    f.pool:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.ring = layer(64, 24, 0.9, "wp-ground", 3)
    f.ring:SetPoint("CENTER", f, "CENTER", 0, 0)
    local ag = f.ring:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local sc = ag:CreateAnimation("Scale")
    if sc.SetScaleFrom then sc:SetScaleFrom(0.85, 0.85); sc:SetScaleTo(1.15, 1.15) else sc:SetScale(1.35, 1.35) end
    sc:SetDuration(1.2)
    sc:SetSmoothing("IN_OUT")
    ag:Play()
    for n = 1, 3 do
        local m = layer(9, 9, 1, "wp-spark", 4)
        m:SetPoint("BOTTOM", f, "CENTER", 0, 0)
        m:SetAlpha(0)
        local g = m:CreateAnimationGroup()
        g:SetLooping("REPEAT")
        local up = g:CreateAnimation("Translation")
        up:SetOffset(0, 160)
        up:SetDuration(1.8)
        up:SetSmoothing("OUT")
        up:SetStartDelay((n - 1) * 0.6)
        local fin = g:CreateAnimation("Alpha")
        fin:SetFromAlpha(0)
        fin:SetToAlpha(1)
        fin:SetDuration(0.3)
        fin:SetStartDelay((n - 1) * 0.6)
        local fout = g:CreateAnimation("Alpha")
        fout:SetFromAlpha(1)
        fout:SetToAlpha(0)
        fout:SetDuration(1.2)
        fout:SetStartDelay((n - 1) * 0.6 + 0.6)
        g:Play()
    end
    local card = CreateFrame("Frame", nil, f)
    card:SetSize(120, 36)
    card:SetPoint("BOTTOM", f.core, "TOP", 0, 2)
    Kit.Fill(card, C.frame, 0.86)
    Kit.Edge(card, C.borderDim)
    card.stripe = card:CreateTexture(nil, "ARTWORK")
    card.stripe:SetPoint("TOPLEFT", 1, -1)
    card.stripe:SetPoint("TOPRIGHT", -1, -1)
    card.stripe:SetHeight(2)
    card.stripe:SetTexture("Interface\\Buttons\\WHITE8x8")
    local font = FDJ.Font and FDJ.Font() or STANDARD_TEXT_FONT
    f.title = card:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(font, 12, "")
    f.title:SetTextColor(1, 1, 1)
    f.title:SetShadowOffset(1, -1)
    f.title:SetPoint("TOP", 0, -6)
    f.dist = card:CreateFontString(nil, "OVERLAY")
    f.dist:SetFont(font, 11, "")
    f.dist:SetShadowOffset(1, -1)
    f.dist:SetPoint("TOP", f.title, "BOTTOM", 0, -2)
    f.card = card
    function f:Fit()
        local w = math.max(self.title:GetStringWidth() or 0, self.dist:GetStringWidth() or 0)
        self.card:SetWidth(math.ceil(w) + 24)
    end
    function f:Tint(c)
        if self.tint == c then return end
        self.tint = c
        for _, t in ipairs(glows) do t:SetVertexColor(c[1], c[2], c[3], t.a) end
        self.dist:SetTextColor(c[1], c[2], c[3])
        self.card.stripe:SetVertexColor(c[1], c[2], c[3], 0.9)
    end
    f:Tint(GOLD)
    f:SetAlpha(0)
    f:Hide()
    return f
end

local function setText(fs, text)
    if fs.shownText ~= text then
        fs.shownText = text
        fs:SetText(text)
    end
end

local yardsFmt
local function yards(d)
    if not yardsFmt then yardsFmt = L.ARROW_YARDS or "%d yd" end
    return yardsFmt:format(math.floor(d + 0.5))
end

local function title()
    local b = Pins.borrowed
    if b and b.wp and FDJ.WP and FDJ.WP.Describe then
        local label = FDJ.WP.Describe(b.wp)
        return (label or ""):gsub("|c%x%x%x%x%x%x%x%x.-|r", "")
    end
    if Pins.label then return Pins.label end
    local qid = Pins.ActiveQuest and Pins.ActiveQuest()
    if qid and FDJ.Quests then return FDJ.Quests.Title(qid) end
    return L.ARROW_TITLE or ""
end

local function setNative(m, x, y)
    if not (C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(m) then return false end
    if not pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(m, x, y)) then return false end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    return true
end

local function remember()
    if not FDJ.char then return end
    local b, st = Pins.borrowed, Pins.stashed
    FDJ.char.beamBorrow = b and { m = b.m, x = b.x, y = b.y } or nil
    FDJ.char.beamStash = st and { m = st.m, x = st.x, y = st.y } or nil
end

local function release()
    local b, st = Pins.borrowed, Pins.stashed
    if not b and not st then return end
    Pins.borrowed, Pins.stashed = nil, nil
    if b then Pins.prevBorrowed = b end
    remember()
    if st then
        setNative(st.m, st.x, st.y)
    elseif b then
        local m, x, y = Pins.RawNative()
        Pins.borrowed = b
        local mine = m and Pins.IsBorrowed(m, x, y)
        Pins.borrowed = nil
        if mine and C_Map.ClearUserWaypoint then
            C_Map.ClearUserWaypoint()
        end
    end
    FDJ:Emit("FDJ_PINS")
end
Beam.Release = release

local function zoneSpot(m, x, y)
    if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return m, x, y end
    local zone = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while zone and guard < 6 do
        local info = C_Map.GetMapInfo(zone)
        if not info or not Enum or not Enum.UIMapType or info.mapType <= Enum.UIMapType.Zone then break end
        zone = info.parentMapID
        guard = guard + 1
    end
    if not zone or zone == m then return m, x, y end
    local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if not (ok and cont and world) then return m, x, y end
    local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, world, zone)
    if not (ok2 and pos) then return m, x, y end
    local zx, zy = FDJ.XY(pos)
    if not zx or zx < 0 or zx > 1 or zy < 0 or zy > 1 then return m, x, y end
    return zone, zx, zy
end

local function borrow(wp)
    local b = Pins.borrowed
    if b and b.wp == wp and b.sm == wp.m and b.sx == wp.x and b.sy == wp.y then return true end
    if not Pins.stashed then
        local m, x, y = Pins.RawNative()
        if m and not Pins.IsBorrowed(m, x, y) then Pins.stashed = { m = m, x = x, y = y } end
    end
    local m, x, y = zoneSpot(wp.m, wp.x, wp.y)
    if b then Pins.prevBorrowed = b end
    Pins.borrowed = { m = m, x = x, y = y, wp = wp, sm = wp.m, sx = wp.x, sy = wp.y }
    if not setNative(m, x, y) then
        Pins.borrowed = nil
        release()
        return false
    end
    remember()
    blizzAlpha()
    FDJ:Emit("FDJ_PINS")
    return true
end

local function distOf(dx, dy) return dx and math.sqrt(dx * dx + dy * dy) or nil end

local wpWait = 0
local function ownWaypoints(dt)
    local b = Pins.borrowed
    if b then
        local m, x, y = Pins.RawNative()
        if not (m and Pins.IsBorrowed(m, x, y)) then
            Pins.borrowed, Pins.stashed = nil, nil
            remember()
            b = nil
        end
    end
    local WP = FDJ.WP
    if not (WP and WP.Pick and #WP.List() > 0) then
        release()
        return
    end
    wpWait = wpWait - dt
    if wpWait > 0 then return end
    wpWait = b and 0.1 or 0.25
    local wp, dx, dy = WP.Pick()
    local wd = distOf(dx, dy)
    local pd = Pins.HasOwn() and distOf(Pins.Offset()) or nil
    local reach = (b and b.wp == wp) and FAR or NEAR
    local ok = wp and wd and wd <= reach and wd > GONE
    if ok and pd then
        if b and b.wp == wp then ok = wd <= pd + 5 else ok = wd + 5 < pd end
    end
    if ok then borrow(wp) else release() end
end

local function tick(dt)
    if FDJ:Option("worldBeam") then ownWaypoints(dt) else release() end
    local tracking = C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()
    local nav = tracking and C_Navigation.GetFrame()
    local dist = nav and C_Navigation.GetDistance and C_Navigation.GetDistance()
    if FDJ.Secret and FDJ.Secret(dist) then dist = nil end
    local clamped = nav and C_Navigation.WasClampedToScreen and C_Navigation.WasClampedToScreen()
    if type(dist) == "number" and nav and not clamped and dist > GONE and FDJ:Option("worldBeam") then
        want = dist <= (want and FAR or NEAR) and dist > (want and CLOSE or CLOSE + 3)
    else
        want = false
    end
    local before = shown
    local step = (dt or TICK) / FADE
    if want then shown = math.min(1, shown + step) else shown = math.max(0, shown - step) end
    if shown > 0 then
        beam = beam or build()
        if beam.anchor ~= nav and nav then
            beam:ClearAllPoints()
            beam:SetPoint("CENTER", nav, "CENTER", 0, 0)
            beam.anchor = nav
        end
        beam:Tint(Pins.borrowed and BLUE or GOLD)
        local a1, a2 = beam.title.shownText, beam.dist.shownText
        setText(beam.title, title())
        if type(dist) == "number" then setText(beam.dist, yards(dist)) end
        if beam.title.shownText ~= a1 or beam.dist.shownText ~= a2 then beam:Fit() end
        beam:SetAlpha(shown)
        if not beam:IsShown() then beam:Show() end
    elseif beam and beam:IsShown() then
        beam:Hide()
    end
    if shown ~= before then blizzAlpha() end
    if shown == 0 and not want and not (type(dist) == "number" and dist < NEAR * 2) then return 0.5 end
    return TICK
end

local function needed()
    if not FDJ:Option("worldBeam") or FDJ.InInstance() then return false end
    if Pins.borrowed then return true end
    if FDJ.WP and #FDJ.WP.List() > 0 then return true end
    local st = C_SuperTrack
    return st and st.IsSuperTrackingUserWaypoint and st.IsSuperTrackingUserWaypoint() and Pins.HasOwn() and true or false
end

function Beam.Refresh()
    if not (C_Navigation and C_Navigation.GetFrame) then return end
    driver = driver or CreateFrame("Frame")
    if needed() then
        local acc, wait = 0, TICK
        driver:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < wait then return end
            wait = tick(acc) or TICK
            acc = 0
        end)
    else
        driver:SetScript("OnUpdate", nil)
        release()
        if shown > 0 then
            shown = 0
            if beam then beam:Hide() end
            blizzAlpha()
        end
    end
end

FDJ:On("SUPER_TRACKING_CHANGED", function() Beam.Refresh() end)
FDJ:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, Beam.Refresh) end)
FDJ:On("USER_WAYPOINT_UPDATED", function() C_Timer.After(0.3, Beam.Refresh) end)
FDJ:On("FDJ_WAYPOINTS", function() C_Timer.After(0.1, Beam.Refresh) end)
FDJ:On("FDJ_OPTION", function(key) if key == "worldBeam" then Beam.Refresh() end end)
FDJ:On("PLAYER_ENTERING_WORLD", function()
    local old, kept = FDJ.char and FDJ.char.beamBorrow, FDJ.char and FDJ.char.beamStash
    if FDJ.char then FDJ.char.beamBorrow, FDJ.char.beamStash = nil, nil end
    if old then
        local m, x, y = Pins.RawNative()
        if m and m == old.m and math.abs(x - old.x) < 0.0005 and math.abs(y - old.y) < 0.0005 then
            if kept then setNative(kept.m, kept.x, kept.y) elseif C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
        end
    end
    C_Timer.After(1, Beam.Refresh)
end)
FDJ:On("PLAYER_LOGOUT", function() release() end)
