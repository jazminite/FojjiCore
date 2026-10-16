local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end

Addon.DJ = Addon.DJ or {}
local FDJ = Addon.DJ

FDJ.core = Addon
FDJ.addon = "FojjiCore_DungeonJournal"
FDJ.title = "Dungeon Journal"
FDJ.media = "Interface\\AddOns\\FojjiCore\\textures\\DungeonJournal\\"
FDJ.coreMedia = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
FDJ.icon = "Interface\\AddOns\\FojjiCore\\textures\\F_icon_teal.png"

FDJ.Colors = {
    frame = { 0.071, 0.075, 0.082 },
    header = { 0.090, 0.094, 0.104 },
    sidebar = { 0.073, 0.077, 0.084 },
    content = { 0.113, 0.117, 0.125 },
    panel = { 0.142, 0.146, 0.154 },
    field = { 0.079, 0.083, 0.090 },
    fieldHover = { 0.102, 0.108, 0.120 },
    border = { 0.240, 0.248, 0.264 },
    borderDim = { 0.183, 0.188, 0.199 },
    button = { 0.167, 0.172, 0.182 },
    buttonHover = { 0.210, 0.222, 0.245 },
    scroll = { 0.182, 0.187, 0.197 },
    title = { 0.90, 0.94, 1.00 },
    white = { 1, 1, 1 },
    text = { 0.90, 0.91, 0.93 },
    tab = { 0.80, 0.82, 0.85 },
    muted = { 0.64, 0.66, 0.70 },
    dim = { 0.46, 0.48, 0.52 },
    accent = { 0.40, 0.70, 1.00 },
    accent2 = { 0.55, 0.40, 1.00 },
    amber = { 1.0, 0.72, 0.30 },
    good = { 0.40, 0.86, 0.46 },
    warn = { 1.0, 0.82, 0.25 },
    bad = { 0.95, 0.40, 0.40 },
    info = { 0.45, 0.70, 1.0 },
    quest = { 1.0, 0.82, 0.0 },
    xp = { 1.0, 0.52, 0.80 },
    alliance = { 0.25, 0.55, 1.0 },
    horde = { 0.90, 0.22, 0.19 },
    shadow = { 0, 0, 0 },
}
FDJ.Colors.ink = FDJ.Colors.frame
FDJ.Colors.slab = FDJ.Colors.panel
FDJ.Colors.raised = FDJ.Colors.button
FDJ.Colors.hover = FDJ.Colors.buttonHover
FDJ.Colors.edge = FDJ.Colors.borderDim

local THEME = {
    frame = "frame", header = "header", sidebar = "sidebar", content = "content", panel = "panel",
    field = "field", fieldHover = "fieldHover", border = "border", borderDim = "borderDim",
    button = "button", buttonHover = "buttonHover", scroll = "scroll", title = "title",
    text = "text", tab = "tab", muted = "dim", accent = "accent", accent2 = "accent2",
}

function FDJ.SyncTheme()
    if not Addon.GetColor then return false end
    local changed = false
    for key, name in pairs(THEME) do
        local ok, r, g, b = pcall(Addon.GetColor, name)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            local c = FDJ.Colors[key]
            if c[1] ~= r or c[2] ~= g or c[3] ~= b then
                c[1], c[2], c[3] = r, g, b
                changed = true
            end
        end
    end
    local m, d = FDJ.Colors.muted, FDJ.Colors.dim
    d[1], d[2], d[3] = m[1] * 0.72, m[2] * 0.72, m[3] * 0.72
    return changed
end

FDJ.RouteColors = {
    { 0.40, 0.70, 1.00 },
    { 1.0, 0.72, 0.30 },
    { 0.95, 0.40, 0.55 },
    { 0.50, 0.90, 0.40 },
    { 0.75, 0.55, 1.0 },
    { 0.95, 0.95, 0.95 },
    { 0.98, 0.30, 0.25 },
    { 0.30, 0.90, 0.85 },
}

local function hex(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
FDJ.Hex = hex

function FDJ.Paint(color, text)
    if type(color) == "string" then color = FDJ.Colors[color] end
    return "|cff" .. hex(color) .. tostring(text) .. "|r"
end

function FDJ.Font()
    return Addon.UIFont or (Addon.UIKit and Addon.UIKit.FONT) or STANDARD_TEXT_FONT
end

function FDJ.Glyph(name)
    if not name or type(name) == "number" then return name end
    if name:find("\\", 1, true) then return name end
    if name:sub(1, 3) == "fc:" then return FDJ.coreMedia .. name:sub(4) end
    return FDJ.media .. name
end

function FDJ.Q(text)
    return FDJ.Paint("quest", text)
end

function FDJ.Hi(text)
    return FDJ.Paint("text", text)
end

local PRINT_TEXT = { 0.62, 0.86, 0.82 }
local PRINT_OPEN = "|cff9edbd1"
function FDJ.PrintAs(label, text)
    local c = FDJ.Colors
    local line = ("|T%s:14:14:0:0|t %s %s %s"):format(FDJ.icon, FDJ.Paint(c.accent, label), FDJ.Paint(c.dim, "||"), FDJ.Paint(PRINT_TEXT, (tostring(text):gsub("|r", "|r" .. PRINT_OPEN))))
    DEFAULT_CHAT_FRAME:AddMessage(line)
end

function FDJ.Print(text)
    FDJ.PrintAs("Dungeon Journal", text)
end

local listeners = {}
local hub = CreateFrame("Frame")
FDJ.hub = hub

FDJ.off = false

local PLAYER_ONLY = { UNIT_PET = true }
function FDJ.Listen(event)
    if PLAYER_ONLY[event] and hub.RegisterUnitEvent then
        pcall(hub.RegisterUnitEvent, hub, event, "player")
    else
        pcall(hub.RegisterEvent, hub, event)
    end
end

function FDJ:On(event, fn)
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
        if not FDJ.off and not event:find("^FDJ_") then FDJ.Listen(event) end
    end
    list[#list + 1] = fn
end

function FDJ:Emit(event, ...)
    if FDJ.off then return end
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then Addon.Report(err) end
    end
end

local function offSlash(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "on" or cmd == "enable" then
        FDJ:SetEnabled(true)
    else
        FDJ.Print("The Dungeon Journal is turned off. |cffffffff/fc dj on|r turns it back on (or /fc -> Journal Settings).")
    end
end

hub:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == FDJ.addon and FDJ.LoadStore then
        FDJ:LoadStore()
        if FDJ.db.options.enabled == false then
            FDJ.off = true
            hub:UnregisterAllEvents()
            SLASH_FOJJICOREDJ1 = "/fdj"
            SlashCmdList.FOJJICOREDJ = offSlash
            return
        end
    end
    FDJ:Emit(event, ...)
end)

local pending = {}

function FDJ.Debounce(key, delay, fn)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(delay, function()
        pending[key] = nil
        fn()
    end)
end

local function gamepadUI() return Addon.GamepadUI and Addon.GamepadUI() or false end
FDJ.GamepadUI = gamepadUI

function FDJ.NewFrame(kind, name, parent, template, id)
    if not parent or not gamepadUI() then return CreateFrame(kind, name, parent, template, id) end
    local f = CreateFrame(kind, name, nil, template, id)
    if parent then
        f:SetParent(parent)
        f:SetFrameStrata(parent:GetFrameStrata())
        f:SetFrameLevel(parent:GetFrameLevel() + 1)
    end
    return f
end

function FDJ.InInstance()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    return inside and kind ~= "none" and true or false
end

function FDJ.EscapeCloses(name)
    if name and UISpecialFrames and not gamepadUI() then table.insert(UISpecialFrames, name) end
end

local watched, watcher = {}, nil
local function look()
    local any = false
    for frame, entry in pairs(watched) do
        local now = frame:IsVisible() and true or false
        if now then any = true end
        if now ~= entry.shown then
            entry.shown = now
            for _, f in ipairs(now and entry.show or entry.hide) do f(frame) end
        end
    end
    return any
end

local mapFns, layoutFns, seenMap, seenW = {}, {}, nil, nil
local function lookMap()
    local map = WorldMapFrame
    if not (map and map:IsVisible()) then seenMap, seenW = nil, nil return end
    local id, w = map:GetMapID(), map:GetWidth()
    if seenMap and id ~= seenMap then for _, f in ipairs(mapFns) do f() end end
    if seenW and w ~= seenW then for _, f in ipairs(layoutFns) do f() end end
    seenMap, seenW = id, w
end

local function startGamepadWatch()
    if watcher then return end
    watcher = CreateFrame("Frame", nil, UIParent)
    local wait, every = 0, 0.5
    watcher:SetScript("OnUpdate", Addon.Guard(function(_, elapsed)
        wait = wait + elapsed
        if wait < every then return end
        wait = 0
        local open = look()
        if #mapFns > 0 or #layoutFns > 0 then lookMap() end
        every = open and 0.1 or 0.5
    end))
end

function FDJ.OnMapChanged(fn)
    if not WorldMapFrame then return end
    if not gamepadUI() and WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", fn) return end
    mapFns[#mapFns + 1] = fn
    FDJ.WatchFrame(WorldMapFrame)
end

function FDJ.OnMapLayout(fn)
    if not WorldMapFrame then return end
    if not gamepadUI() and WorldMapFrame.SynchronizeDisplayState then hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", fn) return end
    layoutFns[#layoutFns + 1] = fn
    FDJ.WatchFrame(WorldMapFrame)
end

function FDJ.WatchFrame(target, onShow, onHide)
    if not target then return end
    local w = watched[target]
    if not w then
        w = { shown = target:IsVisible() and true or false, show = {}, hide = {} }
        watched[target] = w
        if not gamepadUI() and target.HookScript then
            target:HookScript("OnShow", look)
            target:HookScript("OnHide", look)
            w.hooked = true
        end
    end
    if onShow then w.show[#w.show + 1] = onShow end
    if onHide then w.hide[#w.hide + 1] = onHide end
    if not w.hooked then startGamepadWatch() end
end

function FDJ.Faction()
    return UnitFactionGroup("player")
end

function FDJ.Level()
    return UnitLevel("player") or 1
end

function FDJ.PlayerName()
    return UnitName("player")
end

function FDJ.RouteTitle(pattern, place)
    return pattern:format(place, FDJ.PlayerName() or "?")
end

function FDJ.Short(name)
    if not name then return nil end
    if Ambiguate then return Ambiguate(name, "none") end
    return (name:gsub("%-.*$", ""))
end

function FDJ.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = FDJ.Copy(v) end
    return out
end

function FDJ.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function FDJ.Ago(stamp)
    if not stamp then return "" end
    local secs = time() - stamp
    if secs < 90 then return "just now" end
    if secs < 5400 then return ("%d min ago"):format(math.floor(secs / 60)) end
    if secs < 129600 then return ("%d h ago"):format(math.floor(secs / 3600)) end
    return ("%d days ago"):format(math.floor(secs / 86400))
end

function FDJ.Secret(value)
    return issecretvalue ~= nil and issecretvalue(value) or false
end

function FDJ.ChatLocked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

function FDJ.InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function FDJ.GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

local function splitPlain(text, out)
    while #text > 250 do
        local cut = text:sub(1, 250):match("^.*()[ ,;]") or 250
        out[#out + 1] = text:sub(1, cut)
        text = text:sub(cut + 1):gsub("^%s+", "")
    end
    if #text > 0 then out[#out + 1] = text end
end

function FDJ.Say(lines)
    if type(lines) == "string" then lines = { lines } end
    local channel = FDJ.GroupChannel()
    if not channel then
        for _, line in ipairs(lines) do FDJ.Print(line) end
        return
    end
    if FDJ.ChatLocked() then
        FDJ.Print(FDJ.L.CHAT_LOCKED)
        return
    end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    local out = {}
    for _, line in ipairs(lines) do
        if line:find("|H") or #line <= 250 then out[#out + 1] = line else splitPlain(line, out) end
    end
    for _, line in ipairs(out) do send(line, channel) end
end

function FDJ.Clip(text, limit)
    if type(text) ~= "string" or #text <= limit then return text end
    local cut = limit
    while cut > 0 do
        local b = text:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return text:sub(1, cut)
end

function FDJ.ShareToGroup(line, toChatBox, printer)
    printer = printer or FDJ.Print
    if toChatBox then
        if not FDJ.OpenChat(line) then printer(line) end
        return true
    end
    if not FDJ.GroupChannel() then
        printer(FDJ.L.SHARE_SOLO)
        return false
    end
    FDJ.Say(line)
    return true
end

function FDJ.OpenChat(text)
    if ChatFrameUtil and ChatFrameUtil.OpenChat then
        ChatFrameUtil.OpenChat(text)
        return true
    end
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
        return true
    end
    return false
end

function FDJ.InsertLink(link)
    if not link then return false end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then return ChatFrameUtil.InsertLink(link) and true or false end
    if ChatEdit_InsertLink then return ChatEdit_InsertLink(link) and true or false end
    return false
end

function FDJ.XY(vec)
    if type(vec) ~= "table" then return nil end
    local x, y = vec.x, vec.y
    if FDJ.Secret(x) or FDJ.Secret(y) then return nil end
    if (x == nil or y == nil) and vec.GetXY then x, y = vec:GetXY() end
    if FDJ.Secret(x) or FDJ.Secret(y) or x == nil or y == nil then return nil end
    return x, y
end
