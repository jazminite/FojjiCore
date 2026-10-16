local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Pins = {}
FDJ.Pins = Pins

local L = FDJ.L
local function say(text) FDJ.PrintAs("FojjiCore", text) end
local Book = FDJ.QuestBook
local Quests = FDJ.Quests

Pins.placing = nil
Pins.active = nil

local function same(a, b)
    return a and b and math.abs(a - b) < 0.0005
end

function Pins.RawNative()
    if not (C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return nil end
    local point = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if not point or not point.position then return nil end
    local pos = point.position
    local x, y = pos.x, pos.y
    if (not x or not y) and pos.GetXY then x, y = pos:GetXY() end
    if not x or not y then return nil end
    return point.uiMapID, x, y
end

local function worldOf(m, x, y)
    if not (m and x and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
    if not (ok and cont and pos) then return nil end
    local wx, wy = FDJ.XY(pos)
    return cont, wx, wy
end
local lastQ = {}
local function matches(b, m, x, y)
    if not (b and m) then return false end
    if m == b.m and same(x, b.x) and same(y, b.y) then return true end
    if lastQ.b == b and lastQ.m == m and lastQ.x == x and lastQ.y == y then return lastQ.r end
    if not b.cont then b.cont, b.wx, b.wy = worldOf(b.sm or b.m, b.sx or b.x, b.sy or b.y) end
    local c, wx, wy = worldOf(m, x, y)
    local r = (c and b.cont == c and wx and b.wx and (wx - b.wx) ^ 2 + (wy - b.wy) ^ 2 < 1) or false
    lastQ.b, lastQ.m, lastQ.x, lastQ.y, lastQ.r = b, m, x, y, r
    return r
end
function Pins.IsBorrowed(m, x, y)
    return matches(Pins.borrowed, m, x, y) or matches(Pins.prevBorrowed, m, x, y)
end

function Pins.Native()
    local st = Pins.stashed
    if st then return st.m, st.x, st.y end
    local m, x, y = Pins.RawNative()
    if not m or Pins.IsBorrowed(m, x, y) then return nil end
    return m, x, y
end

function Pins.ClearOwn()
    if Pins.stashed then
        Pins.stashed = nil
        if FDJ.char then FDJ.char.beamStash = nil end
        return
    end
    if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
end

function Pins.HasOwn()
    return Pins.Native() ~= nil
end

function Pins.Has(qid)
    local active = Pins.active
    if not active or active.qid ~= qid then return false end
    local m, x, y = Pins.Native()
    return m == active.m and same(x, active.x) and same(y, active.y)
end

function Pins.ActiveQuest()
    local active = Pins.active
    if active and Pins.Has(active.qid) then return active.qid end
    return nil
end

function Pins.OpenMap(mapID)
    if FDJ.InCombat() then
        say(L.MAP_IN_COMBAT)
        return false
    end
    if FDJ.GamepadUI() then
        if not (WorldMapFrame and WorldMapFrame:IsShown()) then
            say(L.MAP_OPEN_YOURSELF)
            return false
        end
        if mapID and FDJ.InstanceMap and FDJ.InstanceMap.ShowWorld then FDJ.InstanceMap.ShowWorld() end
        if mapID and WorldMapFrame:GetMapID() ~= mapID then WorldMapFrame:SetMapID(mapID) end
        return true
    end
    if mapID and FDJ.InstanceMap and FDJ.InstanceMap.ShowWorld then FDJ.InstanceMap.ShowWorld() end
    if C_Map.OpenWorldMap then
        C_Map.OpenWorldMap(mapID)
    elseif OpenWorldMap then
        OpenWorldMap(mapID)
    else
        if not WorldMapFrame:IsShown() then ToggleWorldMap() end
        if mapID then WorldMapFrame:SetMapID(mapID) end
    end
    if mapID and WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() ~= mapID then
        WorldMapFrame:SetMapID(mapID)
    end
    return true
end

function Pins.SetNative(mapID, x, y, quiet)
    if not (C_Map.SetUserWaypoint and UiMapPoint) then return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        if not quiet then say(L.NO_WAYPOINT) end
        return false
    end
    Pins.stashed, Pins.borrowed, Pins.prevBorrowed = nil, nil, nil
    if FDJ.char then FDJ.char.beamStash, FDJ.char.beamBorrow = nil, nil end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    Pins.ShowInWorld()
    return true
end

function Pins.ShowInWorld()
    if not FDJ:Option("worldPin") or FDJ.InInstance() then return end
    local st = C_SuperTrack
    if not (st and st.SetSuperTrackedUserWaypoint and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return end
    st.SetSuperTrackedUserWaypoint(true)
    C_Timer.After(0.2, function()
        if C_Map.HasUserWaypoint() and st.IsSuperTrackingUserWaypoint and not st.IsSuperTrackingUserWaypoint() then
            st.SetSuperTrackedUserWaypoint(true)
        end
    end)
end

local function pinAt(qid, mapID, x, y, quiet)
    if not Pins.SetNative(mapID, x, y) then return false end
    Pins.active = { qid = qid, m = mapID, x = x, y = y }
    Pins.label = nil
    FDJ:Emit("FDJ_PINS")
    if not quiet then
        say(L.PIN_SET:format(FDJ.Q(Quests.Title(qid)), FDJ.Hi(FDJ.MapName(mapID)),
            FDJ.Paint("accent", ("%.1f, %.1f"):format(x * 100, y * 100))))
    end
    return true
end

function Pins.BeginPlacing(qid)
    local q = Book[qid]
    if not q then return end
    Pins.placing = qid
    FDJ:Emit("FDJ_PLACING", qid)
    local zone = FDJ.ZoneMap(q.at)
    if not zone and q.by and FDJ.Givers[q.by] then zone = FDJ.ZoneMap(FDJ.Givers[q.by][1]) end
    Pins.OpenMap(zone or C_Map.GetBestMapForUnit("player"))
end

function Pins.StopPlacing()
    if Pins.placing then
        Pins.placing = nil
        FDJ:Emit("FDJ_PLACING", nil)
    end
end

function Pins.Place(mapID, x, y)
    local qid = Pins.placing
    if not qid then return false end
    Pins.StopPlacing()
    Quests.Remember(qid, mapID, x, y, "pin")
    pinAt(qid, mapID, x, y)
    return true
end

function Pins.Pin(qid, stay)
    local spot = Quests.NextStep(qid) or Quests.Spot(qid)
    if spot then
        pinAt(qid, spot.m, spot.x, spot.y)
        return true
    end
    Pins.BeginPlacing(qid)
    return false
end

function Pins.Remove(qid)
    if Pins.Has(qid) then Pins.ClearOwn() end
    Pins.active = nil
    FDJ:Emit("FDJ_PINS")
end

function Pins.Toggle(qid)
    if Pins.Has(qid) then
        Pins.Remove(qid)
    else
        Pins.Pin(qid)
    end
end

function Pins.Hyperlink()
    if not C_Map.GetUserWaypointHyperlink then return nil end
    local ok, link = pcall(C_Map.GetUserWaypointHyperlink)
    if ok and type(link) == "string" and link ~= "" then return link end
    return nil
end

function Pins.ShareLine(qid)
    local m, x, y = Pins.Native()
    if not m then return nil end
    qid = qid or Pins.ActiveQuest()
    local where = ("%s %.1f, %.1f"):format(FDJ.MapName(m), x * 100, y * 100)
    local link = Pins.Hyperlink()
    local line = link and (link .. "  (" .. where .. ")") or (L.PIN_SHARE_PREFIX .. " " .. where)
    if qid and Pins.Has(qid) then line = line .. "  " .. L.PIN_SHARE_FOR:format(Quests.Title(qid)) end
    return line
end

function Pins.Share(qid, toChatBox)
    local line = Pins.ShareLine(qid)
    if not line then
        say(L.NO_PIN_TO_SHARE)
        return false
    end
    return FDJ.ShareToGroup(line, toChatBox, say)
end

function Pins.WaypointAt(mapID, x, y, label, quiet)
    if not Pins.SetNative(mapID, x, y, quiet) then return false end
    Pins.active = nil
    Pins.label = label
    FDJ:Emit("FDJ_PINS")
    if quiet then return true end
    say(L.WAYPOINT_SET:format(FDJ.Hi(FDJ.MapName(mapID)), FDJ.Paint("accent", ("%.1f, %.1f"):format(x * 100, y * 100))))
    return true
end

local lastWaypoint
FDJ:On("USER_WAYPOINT_UPDATED", function()
    FDJ.Debounce("nativepin", 0.1, function()
        local m, x, y = Pins.Native()
        local key = m and ("%d:%.4f:%.4f"):format(m, x, y)
        if key and key ~= lastWaypoint then Pins.ShowInWorld() end
        lastWaypoint = key
        FDJ:Emit("FDJ_PINS")
    end)
end)

FDJ:On("PLAYER_LOGIN", function()
    local old = FDJ.db and FDJ.db.pins
    if type(old) ~= "table" or next(old) == nil then return end
    for qid, pin in pairs(old) do
        if type(pin) == "table" and pin.m and pin.x and pin.y then Quests.Remember(qid, pin.m, pin.x, pin.y, "pin", true) end
    end
    wipe(old)
end)

local function playerAt()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = FDJ.XY(pos)
    if FDJ.Secret(x) then return nil end
    return mapID, x, y
end

function Pins.PlanPickup(d)
    local ready, later, missing, left = {}, {}, 0, 0
    local lowest
    for _, qid in ipairs(Quests.ForDungeon(d)) do
        local code = Quests.Status(qid)
        if code == "open" or code == "chain" or code == "low" then
            left = left + 1
            local spot = Quests.Spot(qid)
            if not spot then
                missing = missing + 1
            elseif code == "low" then
                local req = Book[qid] and Book[qid].req or 0
                if not lowest or req < lowest then lowest = req end
                later[#later + 1] = { m = spot.m, x = spot.x, y = spot.y, label = Quests.Title(qid) .. " (" .. L.LEVEL .. " " .. req .. ")" }
            else
                ready[#ready + 1] = { m = spot.m, x = spot.x, y = spot.y, label = Quests.Title(qid) }
            end
        end
    end
    local stops = ready
    if #stops == 0 and #later > 0 then
        stops = later
        say(L.PLAN_LOW:format(lowest or 0))
    end
    if #stops == 0 then
        say(left == 0 and L.PLAN_NONE_LEFT or L.PLAN_EMPTY)
        return nil
    end
    local merged = {}
    for _, stop in ipairs(stops) do
        local hit
        for _, m in ipairs(merged) do
            if m.m == stop.m and math.abs(m.x - stop.x) < 0.01 and math.abs(m.y - stop.y) < 0.01 then hit = m end
        end
        if hit then
            hit.label = hit.label .. " + " .. stop.label
        else
            merged[#merged + 1] = stop
        end
    end
    local mapID, px, py = playerAt()
    local ordered, cm, cx, cy = {}, mapID, px or 0.5, py or 0.5
    while #merged > 0 do
        local best, bestCost
        for i, stop in ipairs(merged) do
            local cost = (stop.m == cm and 0 or 10) + math.sqrt((stop.x - cx) ^ 2 + (stop.y - cy) ^ 2)
            if not bestCost or cost < bestCost then best, bestCost = i, cost end
        end
        local stop = table.remove(merged, best)
        ordered[#ordered + 1] = stop
        cm, cx, cy = stop.m, stop.x, stop.y
    end
    local WP = FDJ.WP
    WP.RemoveWhere(function(wp) return wp.pickup == d.key end)
    local added = 0
    for i, stop in ipairs(ordered) do
        if WP.Add(stop.m, stop.x, stop.y, FDJ.Clip(stop.label, 80), { quiet = true, pickup = d.key, stop = i }) then added = added + 1 end
    end
    if added == 0 then
        FDJ:Emit("FDJ_WAYPOINTS")
        say(L.PLAN_EMPTY)
        return nil
    end
    say(L.PLAN_MADE:format(added) .. (missing > 0 and ("  " .. L.PLAN_MISSING:format(missing)) or ""))
    return added
end

local arrow
local CARD_W, CARD_H, DIAL = 240, 96, 78

local function waypointOffset()
    if Pins.stashed then
        if FDJ.WP and FDJ.WP.Offset then return FDJ.WP.Offset(Pins.stashed) end
        return nil
    end
    if not Pins.HasOwn() then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and guard < 6 do
        guard = guard + 1
        local me = C_Map.GetPlayerMapPosition(mapID, "player")
        local wp = C_Map.GetUserWaypointPositionForMap and C_Map.GetUserWaypointPositionForMap(mapID)
        if me and wp then
            local w, h = 0, 0
            if C_Map.GetMapWorldSize then w, h = C_Map.GetMapWorldSize(mapID) end
            local mx, my = FDJ.XY(me)
            local wx, wy = FDJ.XY(wp)
            if w and w > 0 and mx and wx then
                return (wx - mx) * w, (wy - my) * h
            end
        end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        if mapID == 0 then mapID = nil end
    end
    return nil
end

Pins.Offset = waypointOffset

FDJ.WaypointColor = { 0.55, 0.86, 1.00 }

local PIN_ATLAS = { "Waypoint-MapPin-Untracked", "Waypoint-MapPin-Tracked" }
function FDJ.WaypointIcon(tex)
    if tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo then
        for _, atlas in ipairs(PIN_ATLAS) do
            if C_Texture.GetAtlasInfo(atlas) then
                tex:SetAtlas(atlas)
                tex:SetDesaturated(true)
                tex:SetVertexColor(0.70, 0.93, 1.00)
                if not tex.lift then
                    local layer, sub = tex:GetDrawLayer()
                    tex.lift = tex:GetParent():CreateTexture(nil, layer, nil, math.min((sub or 0) + 1, 7))
                    tex.lift:SetAllPoints(tex)
                    tex.lift:SetBlendMode("ADD")
                end
                tex.lift:SetAtlas(atlas)
                tex.lift:SetDesaturated(true)
                tex.lift:SetVertexColor(0.30, 0.55, 0.75)
                tex.lift:Show()
                return true
            end
        end
    end
    if tex.lift then tex.lift:Hide() end
    tex:SetTexture(FDJ.Glyph("fc:wp-marker"))
    local c = FDJ.WaypointColor
    tex:SetVertexColor(c[1], c[2], c[3])
    return false
end

local function placeArrow(f, key, home)
    f:ClearAllPoints()
    local p = FDJ.db and FDJ.db.window and FDJ.db.window[key]
    if p and p[1] then
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", home and home[1] or 475, home and home[2] or 180)
    end
end

local yardsFmt
local function put(fs, text)
    if fs.shownText ~= text then
        fs.shownText = text
        fs:SetText(text)
    end
end

local function tone(fs, c)
    if fs.shownTone ~= c then
        fs.shownTone = c
        fs:SetTone(c)
    end
end

local function yardsText(y)
    if not yardsFmt then yardsFmt = (L.ARROW_YARDS or "%d yd"):gsub("%%d", "%%s") end
    local n
    if y >= 9950 then n = ("%dk"):format(math.floor(y / 1000 + 0.5))
    elseif y >= 1000 then n = ("%.1fk"):format(y / 1000)
    else n = tostring(math.floor(y + 0.5)) end
    return yardsFmt:format(n)
end

local function timeText(sec)
    if sec >= 3600 then return ("%dh %02dm"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60)) end
    if sec >= 600 then return ("%dm"):format(math.floor(sec / 60 + 0.5)) end
    if sec >= 60 then return ("%dm %02ds"):format(math.floor(sec / 60), math.floor(sec % 60)) end
    return ("%ds"):format(math.floor(sec))
end

function Pins.NewTracker(kind)
    local Kit, C = FDJ.Kit, FDJ.Colors
    local RGB = Kit.RGB
    FDJ.SyncTheme()
    local TINT = kind.color or C.accent
    local f = CreateFrame("Button", kind.name, UIParent)
    f.kind = kind
    f:SetSize(CARD_W, CARD_H)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    local bg = Kit.Fill(f, C.frame, 0.94)
    local edges = Kit.Edge(f, C.border)
    local shine = Kit.Gradient(f, "VERTICAL", TINT, 0, 0.14, "BORDER")
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", -1, 1)
    local stripe = f:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    stripe:SetHeight(2)
    Kit.Paint(stripe, TINT)

    local dial = CreateFrame("Frame", nil, f)
    dial:SetSize(DIAL, DIAL)
    dial:SetPoint("LEFT", 8, 0)
    f.disc = dial:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.disc:SetAllPoints()
    f.disc:SetTexture(FDJ.Glyph("fc:nav-disc"))
    f.ring = dial:CreateTexture(nil, "BORDER")
    f.ring:SetAllPoints()
    f.ring:SetTexture(FDJ.Glyph("fc:nav-ring"))
    f.arrow = dial:CreateTexture(nil, "ARTWORK")
    f.arrow:SetSize(DIAL * 0.58, DIAL * 0.58)
    f.arrow:SetPoint("CENTER")
    f.arrow:SetTexture(FDJ.Glyph("fc:nav-arrow"))
    f.check = dial:CreateTexture(nil, "OVERLAY")
    f.check:SetSize(DIAL * 0.4, DIAL * 0.4)
    f.check:SetPoint("CENTER")
    f.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    f.check:Hide()
    f.dial = dial
    local function paint()
        f.disc:SetVertexColor(RGB(C.field, 0.95))
        f.ring:SetVertexColor(RGB(kind.color or C.accent))
    end
    paint()
    if Kit.OnRepaint then Kit.OnRepaint(paint) end

    f.label = Kit.Text(f, "small", C.white)
    f.label:SetPoint("TOPLEFT", dial, "TOPRIGHT", 10, -2)
    f.label:SetPoint("RIGHT", -22, 0)
    f.label:SetWordWrap(false)
    f.dist = Kit.Text(f, "huge", C.white)
    f.dist:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -3)
    f.eta = Kit.Text(f, "tiny", C.muted)
    f.dist:SetShadowColor(0, 0, 0, 1)
    f.eta:SetShadowColor(0, 0, 0, 1)
    f.eta:SetPoint("BOTTOMLEFT", f.dist, "BOTTOMRIGHT", 6, 3)
    f.sub = Kit.Text(f, "tiny", C.muted)
    f.sub:SetPoint("TOPLEFT", f.dist, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("RIGHT", -10, 0)
    f.sub:SetWordWrap(false)
    f.me = Kit.Text(f, "tiny", C.dim)
    f.me:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -2)
    f.me:SetPoint("RIGHT", -10, 0)
    f.me:SetWordWrap(false)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -4, -5)
    close:SetFrameLevel(f:GetFrameLevel() + 10)
    close:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    close:SetHighlightTexture("Interface\\Buttons\\UI-StopButton", "ADD")
    close:GetNormalTexture():SetVertexColor(1, 0.25, 0.25)
    close:SetScript("OnClick", function()
        if f.preview then
            f.preview = nil
            kind.refresh()
            return
        end
        kind.onClose(f)
    end)
    close:SetScript("OnEnter", function(self) Kit.Tip(self, kind.title, kind.closeTip, "ANCHOR_TOP") end)
    close:SetScript("OnLeave", function() Kit.HideTip() end)

    local size = CreateFrame("Button", nil, f)
    size:SetSize(14, 14)
    size:SetPoint("RIGHT", close, "LEFT", -3, 0)
    size:SetFrameLevel(f:GetFrameLevel() + 10)
    size.icon = size:CreateTexture(nil, "ARTWORK")
    size.icon:SetAllPoints()
    size:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        Kit.Tip(self, kind.title, f.compact and L.ARROW_EXPAND or L.ARROW_COMPACT, "ANCHOR_TOP")
    end)
    size:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(RGB(C.muted))
        Kit.HideTip()
    end)
    size.icon:SetVertexColor(RGB(C.muted))

    local function stepButton(glyph, delta, tip)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(14, 14)
        b:SetFrameLevel(f:GetFrameLevel() + 10)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(FDJ.Glyph(glyph))
        b.icon:SetVertexColor(RGB(C.muted))
        b:SetScript("OnClick", function() if kind.onStep then kind.onStep(delta) end end)
        b:SetScript("OnEnter", function(self)
            self.icon:SetVertexColor(1, 1, 1)
            Kit.Tip(self, tip, nil, "ANCHOR_TOP")
        end)
        b:SetScript("OnLeave", function(self)
            self.icon:SetVertexColor(RGB(C.muted))
            Kit.HideTip()
        end)
        b:Hide()
        return b
    end
    f.nextStop = stepButton("fc:chevron-right", 1, L.ROUTE_NEXT)
    f.nextStop:SetPoint("BOTTOMRIGHT", -6, 6)
    f.prevStop = stepButton("fc:chevron-left", -1, L.ROUTE_PREV)
    f.prevStop:SetPoint("RIGHT", f.nextStop, "LEFT", -4, 0)
    function f:SyncSteps()
        local on = self.route and not self.compact and not self.preview
        self.prevStop:SetShown(on and true or false)
        self.nextStop:SetShown(on and true or false)
    end

    local chrome = { bg, shine, stripe, f.label, f.sub, f.me }
    for _, t in ipairs(edges) do chrome[#chrome + 1] = t end
    local function showButtons(on)
        local a = (not f.compact or on) and 1 or 0
        close:SetAlpha(a)
        size:SetAlpha(a)
    end
    f.showButtons = showButtons
    local function layout()
        local c = f.compact
        for _, t in ipairs(chrome) do t:SetShown(not c) end
        dial:ClearAllPoints()
        f.dist:ClearAllPoints()
        f.eta:ClearAllPoints()
        if c then
            f:SetSize(196, 72)
            dial:SetScale(0.86)
            dial:SetPoint("LEFT", f, "LEFT", 4, 0)
            f.dist:SetPoint("BOTTOMLEFT", dial, "RIGHT", 6, -4)
            f.eta:SetPoint("TOPLEFT", f.dist, "BOTTOMLEFT", 1, -1)
            size.icon:SetTexture(FDJ.Glyph("fc:chevron-down"))
        else
            f:SetSize(CARD_W, CARD_H)
            dial:SetScale(1)
            dial:SetPoint("LEFT", 8, 0)
            f.dist:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -3)
            f.eta:SetPoint("BOTTOMLEFT", f.dist, "BOTTOMRIGHT", 6, 3)
            size.icon:SetTexture(FDJ.Glyph("fc:chevron-up"))
        end
        showButtons(f:IsMouseOver())
        f:SyncSteps()
    end
    size:SetScript("OnClick", function(self)
        f.compact = not f.compact or nil
        if FDJ.db then FDJ.db.window[kind.posKey .. "Compact"] = f.compact and true or false end
        layout()
        if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
    end)
    local saved = FDJ.db and FDJ.db.window and FDJ.db.window[kind.posKey .. "Compact"]
    f.compact = saved ~= false or nil

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint(1)
        if FDJ.db then FDJ.db.window[kind.posKey] = { point, rel, x, y } end
    end)
    f:SetScript("OnEnter", function() showButtons(true) end)

    local spin, slow = 0, 1
    local dx, dy, lastFacing
    f:SetScript("OnUpdate", Addon.Guard(function(self, dt)
        spin = spin + dt
        slow = slow + dt
        if slow >= 0.1 then
            slow = 0
            if self.compact then showButtons(self:IsMouseOver()) end
            if self.preview then
                local t = GetTime() - self.preview
                if t > 10 then
                    self.preview = nil
                    kind.refresh()
                    return
                end
                local yards = math.max(0, 260 - t * 30)
                dx, dy = math.sin(t * 0.9) * yards, -math.cos(t * 0.9) * yards
            else
                dx, dy = kind.offset(self)
            end
            local m = C_Map.GetBestMapForUnit("player")
            local pos = m and C_Map.GetPlayerMapPosition(m, "player")
            local px, py
            if pos then px, py = FDJ.XY(pos) end
            put(self.me, px and L.ARROW_YOU:format(px * 100, py * 100) or "")
            if not dx then
                self.arrow:Show()
                self.arrow:SetAlpha(0.25)
                self.check:Hide()
                put(self.dist, "--")
                tone(self.dist, C.muted)
                put(self.eta, "")
                put(self.sub, L.ARROW_ELSEWHERE)
                self.subShown = nil
            else
                if not self.subShown then
                    put(self.sub, self.subText or "")
                    self.subShown = true
                end
                local yards = math.sqrt(dx * dx + dy * dy)
                if kind.onArrive and not self.preview and yards < 10 and kind.onArrive(self) then return end
                if yards < 6 then
                    self.arrow:Hide()
                    self.check:Show()
                    put(self.dist, L.ARROW_ARRIVED)
                    tone(self.dist, C.good)
                    put(self.eta, "")
                else
                    self.check:Hide()
                    self.arrow:Show()
                    self.arrow:SetAlpha(1)
                    put(self.dist, yardsText(yards))
                    tone(self.dist, C.white)
                    local speed, run = 0, 7
                    if GetUnitSpeed then speed, run = GetUnitSpeed("player") end
                    if FDJ.Secret(speed) or type(speed) ~= "number" then speed = 0 end
                    if FDJ.Secret(run) or type(run) ~= "number" then run = 7 end
                    speed = math.max(speed or 0, run or 7, 7)
                    local eta = yards / speed
                    if self.etaShown and math.abs(eta - self.etaShown) < self.etaShown * 0.5 then
                        eta = self.etaShown + (eta - self.etaShown) * 0.35
                    end
                    self.etaShown = eta
                    if yards > 10 and eta < 6000 then
                        put(self.eta, timeText(eta))
                    else
                        put(self.eta, "")
                    end
                end
            end
        end
        if spin < 0.05 then return end
        spin = 0
        local facing = GetPlayerFacing and GetPlayerFacing()
        if FDJ.Secret(facing) or not facing then return end
        if facing ~= lastFacing then
            lastFacing = facing
            self.ring:SetRotation(-facing)
        end
        if dx and self.arrow:IsShown() then
            local rel = -math.atan2(dx, -dy) - facing
            self.arrow:SetRotation(rel)
            local off = math.abs(((rel + math.pi) % (2 * math.pi)) - math.pi)
            local col = off < 0.26 and C.good or kind.color or C.accent
            if col ~= self.arrowCol then
                self.arrowCol = col
                self.arrow:SetVertexColor(RGB(col))
            end
        end
    end))
    f:SetScript("OnShow", function(self) slow = 1 self.etaShown = nil end)
    layout()
    placeArrow(f, kind.posKey, kind.home)
    f:Hide()
    return f
end

local MAP = {
    name = "FojjiCoreWaypointArrow",
    posKey = "arrow",
    home = { 475, 180 },
    title = L.ARROW_TITLE,
    closeTip = L.ARROW_CLOSE,
    offset = function() return waypointOffset() end,
    refresh = function() Pins.UpdateArrow() end,
    onClose = function()
        Pins.ClearOwn()
        Pins.active, Pins.label = nil, nil
        FDJ:Emit("FDJ_PINS")
    end,
    onArrive = function(self)
        local now = GetTime()
        if not self.nearSince or now - (self.lastNear or 0) > 1 then self.nearSince = now end
        self.lastNear = now
        if now - self.nearSince < 5 then return false end
        self.nearSince = nil
        Pins.ClearOwn()
        Pins.active, Pins.label = nil, nil
        FDJ:Emit("FDJ_PINS")
        return true
    end,
}

local function buildArrow()
    return Pins.NewTracker(MAP)
end

function Pins.Preview(f, label, sub)
    f.preview = GetTime()
    f:SyncSteps()
    f.label:SetText(label)
    f.subText = sub
    f.subShown = nil
    f.etaShown = nil
    f:Show()
end

function Pins.SetTarget(f, label, sub)
    f.label:SetText(label)
    f.subText = sub
    f.subShown = nil
    f.etaShown = nil
end

function Pins.PreviewArrow()
    arrow = arrow or buildArrow()
    Pins.Preview(arrow, L.ARROW_PREVIEW, L.ARROW_PREVIEW_SUB)
    if FDJ.WP then FDJ.WP.Preview() end
end

function Pins.UpdateArrow()
    if arrow and arrow.preview then return end
    local want = FDJ:Option("pinArrow") and Pins.HasOwn() and not FDJ.InInstance()
    if not want then
        if arrow then arrow:Hide() end
        return
    end
    arrow = arrow or buildArrow()
    local m, x, y = Pins.Native()
    Pins.SetTarget(arrow, Pins.label or (Pins.active and Pins.active.qid and Quests.Title(Pins.active.qid)) or L.ARROW_TITLE,
        m and ("%.1f, %.1f  %s"):format(x * 100, y * 100, FDJ.MapName(m) or "") or "")
    arrow:SyncSteps()
    arrow:Show()
end

FDJ:On("FDJ_PINS", function() Pins.UpdateArrow() end)
FDJ:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, Pins.UpdateArrow) end)
FDJ:On("FDJ_OPTION", function(key)
    if key == "pinArrow" then Pins.UpdateArrow() end
    if key == "worldPin" and FDJ:Option("worldPin") then Pins.ShowInWorld() end
end)
