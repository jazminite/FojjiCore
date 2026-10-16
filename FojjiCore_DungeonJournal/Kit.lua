local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = {}
FDJ.Kit = Kit

local C = FDJ.Colors
local L = FDJ.L

local function rgb(color, alpha)
    return color[1], color[2], color[3], alpha or 1
end
Kit.RGB = rgb

local fills = setmetatable({}, { __mode = "k" })
local texts = setmetatable({}, { __mode = "k" })
local painters = {}

function Kit.Repaint()
    for tex, spec in pairs(fills) do tex:SetColorTexture(rgb(spec[1], spec[2])) end
    for fs, color in pairs(texts) do fs:SetTextColor(rgb(color)) end
    for _, fn in ipairs(painters) do fn() end
end

function Kit.OnRepaint(fn)
    painters[#painters + 1] = fn
end

function Kit.Fill(frame, color, alpha, layer, sub)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    tex:SetAllPoints()
    tex:SetColorTexture(rgb(color, alpha))
    fills[tex] = { color, alpha }
    return tex
end

function Kit.Paint(tex, color, alpha)
    tex:SetColorTexture(rgb(color, alpha))
    fills[tex] = { color, alpha }
end

local EDGES = {
    { "TOPLEFT", "TOPRIGHT", false },
    { "BOTTOMLEFT", "BOTTOMRIGHT", false },
    { "TOPLEFT", "BOTTOMLEFT", true },
    { "TOPRIGHT", "BOTTOMRIGHT", true },
}

function Kit.Edge(frame, color, alpha)
    local list = {}
    for i, spec in ipairs(EDGES) do
        local tex = frame:CreateTexture(nil, "BORDER")
        tex:SetPoint(spec[1])
        tex:SetPoint(spec[2])
        if spec[3] then tex:SetWidth(1) else tex:SetHeight(1) end
        Kit.Paint(tex, color or C.borderDim, alpha)
        list[i] = tex
    end
    frame.edges = list
    return list
end

function Kit.EdgeColor(frame, color, alpha)
    for _, tex in ipairs(frame.edges or {}) do Kit.Paint(tex, color, alpha) end
end

function Kit.Line(frame, side, color, alpha, inset)
    local tex = frame:CreateTexture(nil, "BORDER")
    inset = inset or 0
    if side == "BOTTOM" or side == "TOP" then
        tex:SetPoint(side .. "LEFT", inset, 0)
        tex:SetPoint(side .. "RIGHT", -inset, 0)
        tex:SetHeight(1)
    else
        tex:SetPoint("TOP" .. side, 0, -inset)
        tex:SetPoint("BOTTOM" .. side, 0, inset)
        tex:SetWidth(1)
    end
    Kit.Paint(tex, color or C.borderDim, alpha)
    if Addon.Native and Addon.Skin and (side == "BOTTOM" or side == "TOP") and (alpha == nil or alpha >= 0.8) then Addon.Skin.Rule(tex) end
    return tex
end

function Kit.Gradient(frame, orientation, color, fromAlpha, toAlpha, layer, sub)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    tex:SetColorTexture(1, 1, 1, 1)
    local function apply()
        if tex.SetGradient and CreateColor then
            pcall(tex.SetGradient, tex, orientation, CreateColor(color[1], color[2], color[3], fromAlpha), CreateColor(color[1], color[2], color[3], toAlpha))
        else
            tex:SetColorTexture(rgb(color, (fromAlpha + toAlpha) / 2))
        end
    end
    apply()
    Kit.OnRepaint(apply)
    return tex
end

local SIZES = { tiny = 10, small = 12, normal = 13, large = 16, huge = 22, title = 15 }

function Kit.SetFont(fs, size)
    local px = SIZES[size or "normal"] or tonumber(size) or 13
    if fs:SetFont(FDJ.Font(), px, "") == false then fs:SetFont(STANDARD_TEXT_FONT, px, "") end
end

function Kit.Text(parent, size, color, justify, layer)
    local fs = Addon.Localize(parent:CreateFontString(nil, layer or "OVERLAY"))
    Kit.SetFont(fs, size)
    fs:SetShadowColor(0, 0, 0, 0.6)
    fs:SetShadowOffset(1, -1)
    color = color or C.text
    fs:SetTextColor(rgb(color))
    texts[fs] = color
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    function fs:SetTone(c)
        texts[self] = c
        self:SetTextColor(rgb(c))
    end
    return fs
end

function Kit.Glyph(parent, name, size, color, layer)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK")
    tex:SetTexture(FDJ.Glyph(name))
    tex:SetSize(size, size)
    tex:SetVertexColor(rgb(color or C.text))
    return tex
end

local LOGO = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
function Kit.Logo(tex)
    tex:SetTexture(LOGO .. "logo-small-base")
    tex:SetVertexColor(1, 1, 1)
    if tex.ring then return tex.ring end
    local layer, sub = tex:GetDrawLayer()
    local ring = tex:GetParent():CreateTexture(nil, layer or "ARTWORK", nil, math.min((sub or 0) + 1, 7))
    ring:SetAllPoints(tex)
    ring:SetTexture(LOGO .. "logo-small-arc")
    local function tint() ring:SetVertexColor(rgb(C.accent)) end
    tint()
    Kit.OnRepaint(tint)
    hooksecurefunc(tex, "Hide", function() ring:Hide() end)
    hooksecurefunc(tex, "Show", function() ring:Show() end)
    tex.ring = ring
    return ring
end

function Kit.Atlas(tex, atlases, fallback)
    if C_Texture and C_Texture.GetAtlasInfo and tex.SetAtlas then
        for _, atlas in ipairs(atlases) do
            if C_Texture.GetAtlasInfo(atlas) then
                tex:SetAtlas(atlas)
                return true
            end
        end
    end
    tex:SetTexture(FDJ.Glyph(fallback))
    return false
end

Kit.PIN_ATLAS = { "Waypoint-MapPin-Minimap-Tracked", "Waypoint-MapPin-Tracked", "Waypoint-MapPin-Untracked" }

function Kit.PinIcon(parent, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size, size)
    Kit.Atlas(tex, Kit.PIN_ATLAS, "ui-wowpin")
    return tex
end

function Kit.Pill(parent)
    local f = FDJ.NewFrame("Frame", nil, parent)
    f:SetHeight(18)
    f.bg = Kit.Fill(f, C.shadow, 0.72)
    f.accent = f:CreateTexture(nil, "ARTWORK")
    f.accent:SetPoint("TOPLEFT")
    f.accent:SetPoint("BOTTOMLEFT")
    f.accent:SetWidth(2)
    f.text = Kit.Text(f, "tiny", C.white, "LEFT")
    f.text:SetPoint("LEFT", 7, 0)
    function f:Set(text, color)
        if not text or text == "" then
            self:Hide()
            return
        end
        self.text:SetText(text)
        self.accent:SetColorTexture(rgb(color or C.accent))
        self:SetWidth(self.text:GetStringWidth() + 13)
        self:Show()
    end
    f:EnableMouse(false)
    return f
end

function Kit.Tip(owner, title, body, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(Addon.Tr(title), 1, 1, 1)
    if type(body) == "string" then
        GameTooltip:AddLine(Addon.Tr(body), C.muted[1], C.muted[2], C.muted[3], true)
    elseif type(body) == "table" then
        for _, line in ipairs(body) do
            if type(line) == "table" then
                local tint = line[3] or C.muted
                GameTooltip:AddDoubleLine(line[1], line[2], 0.9, 0.91, 0.93, tint[1], tint[2], tint[3])
            else
                GameTooltip:AddLine(line, C.muted[1], C.muted[2], C.muted[3], true)
            end
        end
    end
    GameTooltip:Show()
end

local function hideTip()
    GameTooltip:Hide()
end
Kit.HideTip = hideTip

local Skin = Addon.Skin
local function native() return Addon.Native and Skin ~= nil end

local function buttonPaint(self)
    local enabled = self:IsEnabled()
    local hot = self.hot and enabled
    local kind = self.kind or "ghost"
    if self.nativeArrow then return end
    if self.nativeDropdown then
        if self.label then self.label:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5) end
        return
    end
    if self.nativeArt then
        self:NativeState(false)
        if self.label then Skin.ButtonText(self.label, enabled, hot or self.active) end
        if self.glyph and not self.game and not self.keepColor then
            if enabled then self.glyph:SetVertexColor(1, (hot or self.active) and 1 or 0.82, (hot or self.active) and 1 or 0) else self.glyph:SetVertexColor(0.5, 0.5, 0.5) end
        end
        return
    end
    if self.active then
        self.bg:SetColorTexture(rgb(C.accent, hot and 0.34 or 0.24))
        Kit.EdgeColor(self, C.accent, 0.85)
    elseif kind == "primary" then
        self.bg:SetColorTexture(rgb(C.accent, hot and 0.42 or 0.26))
        Kit.EdgeColor(self, C.accent, hot and 1 or 0.75)
    elseif kind == "flat" then
        self.bg:SetColorTexture(rgb(C.buttonHover, hot and 1 or 0))
        Kit.EdgeColor(self, C.border, 0)
    else
        self.bg:SetColorTexture(rgb(hot and C.buttonHover or C.button))
        Kit.EdgeColor(self, hot and C.accent or C.border, hot and 0.8 or 1)
    end
    if self.label then
        local tone = not enabled and C.dim or ((self.active or hot or kind == "primary") and C.white) or self.ink or C.text
        self.label:SetTone(tone)
    end
    if self.glyph then
        if self.game then
            self.glyph:SetDesaturated(not enabled)
            self.glyph:SetVertexColor(1, 1, 1, enabled and 1 or 0.5)
        elseif not self.keepColor then
            local tint = not enabled and C.dim or ((self.active or hot) and C.accent) or self.ink or C.tab
            self.glyph:SetVertexColor(rgb(tint, enabled and 1 or 0.55))
        end
    end
end
Kit.ButtonPaint = buttonPaint

local function tipEnter(self)
    self.hot = true
    buttonPaint(self)
    if self.tip then Kit.Tip(self, self.tip, self.tipBody) end
end

local function tipLeave(self)
    self.hot = false
    buttonPaint(self)
    hideTip()
end

local function setActive(self, on)
    self.active = on and true or false
    buttonPaint(self)
end

local function setLabel(self, text)
    self.label:SetText(text)
    if self.autoWidth then self:SetWidth(math.max(self.minWidth or 0, math.ceil(self.label.GetUnboundedStringWidth and self.label:GetUnboundedStringWidth() or self.label:GetStringWidth()) + (self.glyph and 44 or 28))) end
end

local function setKind(self, kind)
    self.kind = kind
    buttonPaint(self)
end

local function wire(b, onClick)
    b.SetActive = setActive
    b.SetKind = setKind
    b.Paint = buttonPaint
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", tipEnter)
    b:SetScript("OnLeave", tipLeave)
    b:SetScript("OnEnable", buttonPaint)
    b:SetScript("OnDisable", buttonPaint)
    if onClick then b:SetScript("OnClick", onClick) end
    Kit.OnRepaint(function() buttonPaint(b) end)
end

function Kit.Button(parent, text, width, height, onClick, kind, glyph)
    local b = FDJ.NewFrame("Button", nil, parent)
    b.kind = kind
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    Kit.Edge(b, C.border)
    if glyph then
        b.glyph = Kit.Glyph(b, glyph, 14, C.tab)
        b.glyph:SetPoint("LEFT", 10, 0)
    end
    b.label = Kit.Text(b, "small", C.text, "CENTER")
    if glyph then
        b.label:SetPoint("LEFT", b.glyph, "RIGHT", 6, 0)
        b.label:SetPoint("RIGHT", -10, 0)
    else
        b.label:SetPoint("CENTER")
    end
    b.autoWidth = width == nil
    b.minWidth = 40
    b:SetHeight(height or 26)
    local list = kind == "dropdown" or glyph == "fc:icon-chevron-down"
    if native() and kind ~= "flat" and (list and Skin.Dropdown(b) or (not list and Skin.Button(b))) then
        b.bg:Hide()
        for _, t in ipairs(b.edges or {}) do t:Hide() end
        if list and b.glyph then
            b.glyph:Hide()
            b.label:ClearAllPoints()
            b.label:SetPoint("LEFT", 10, 0)
            b.label:SetPoint("RIGHT", -24, 0)
            b.label:SetJustifyH("LEFT")
        end
    end
    b.SetLabel = setLabel
    wire(b, onClick)
    b:SetLabel(text or "")
    if width then b:SetWidth(width) end
    if b.autoWidth then
        b:HookScript("OnShow", function(self) self:SetLabel(self.label:GetText() or "") end)
        C_Timer.After(0, function() b:SetLabel(b.label:GetText() or "") end)
    end
    buttonPaint(b)
    return b
end

local function isGameIcon(icon)
    return type(icon) == "number" or (type(icon) == "string" and icon:find("^Interface\\Icons\\") ~= nil)
end

function Kit.IconButton(parent, icon, size, tip, onClick, kind)
    local b = FDJ.NewFrame("Button", nil, parent)
    size = size or 26
    b:SetSize(size, size)
    b.kind = kind or "flat"
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    Kit.Edge(b, C.border, 0)
    b.glyph = b:CreateTexture(nil, "ARTWORK")
    b.game = isGameIcon(icon)
    if b.game then
        b.glyph:SetPoint("TOPLEFT", 2, -2)
        b.glyph:SetPoint("BOTTOMRIGHT", -2, 2)
        b.glyph:SetTexture(icon)
        b.glyph:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        local g = math.floor(size * 0.62 + 0.5)
        b.glyph:SetSize(g, g)
        b.glyph:SetPoint("CENTER")
        b.glyph:SetTexture(FDJ.Glyph(icon))
    end
    b.tip = tip
    function b:SetIcon(path)
        if self.nativeArrow then return self:NativeArrow(path) end
        self.glyph:SetTexture(FDJ.Glyph(path))
    end
    if native() and Skin.ArrowButton(b, icon) then
        b.bg:Hide()
        b.glyph:Hide()
        for _, t in ipairs(b.edges or {}) do t:Hide() end
        b.SetIcon = function(self, path) self:NativeArrow(path) end
    end
    wire(b, onClick)
    buttonPaint(b)
    return b
end

function Kit.Check(parent, text, getter, setter, tip)
    local b = FDJ.NewFrame("Button", nil, parent)
    b:SetHeight(22)
    local track = FDJ.NewFrame("Frame", nil, b)
    track:SetSize(26, 14)
    track:SetPoint("LEFT", 0, 0)
    track.bg = Kit.Fill(track, C.field)
    Kit.Edge(track, C.border)
    local knob = track:CreateTexture(nil, "ARTWORK")
    knob:SetSize(8, 8)
    local label = Kit.Text(b, "small", C.tab)
    label:SetPoint("LEFT", track, "RIGHT", 8, 0)
    label:SetText(text)
    b:SetWidth(label:GetStringWidth() + 36)
    b.tip = tip
    local box = native() and Skin.Check(b, 22)
    if box then
        track:Hide()
        box:SetPoint("LEFT", -3, 0)
        label:ClearAllPoints()
        label:SetPoint("LEFT", box, "RIGHT", 4, 1)
    end
    function b:Sync()
        local on = getter() and true or false
        if box then box:Set(on, self.hot) return end
        knob:ClearAllPoints()
        if on then
            track.bg:SetColorTexture(rgb(C.accent, 0.85))
            Kit.EdgeColor(track, C.accent)
            knob:SetColorTexture(1, 1, 1, 1)
            knob:SetPoint("RIGHT", -3, 0)
        else
            track.bg:SetColorTexture(rgb(C.field))
            Kit.EdgeColor(track, C.border)
            knob:SetColorTexture(rgb(C.muted))
            knob:SetPoint("LEFT", 3, 0)
        end
    end
    b:SetScript("OnClick", function(self)
        setter(not getter())
        self:Sync()
    end)
    b:SetScript("OnEnter", function(self)
        label:SetTone(C.white)
        self.hot = true
        if box then self:Sync() end
        if self.tip then Kit.Tip(self, text, self.tip) end
    end)
    b:SetScript("OnLeave", function(self)
        label:SetTone(C.tab)
        self.hot = false
        if box then self:Sync() end
        hideTip()
    end)
    Kit.OnRepaint(function() b:Sync() end)
    b:Sync()
    return b
end

function Kit.Input(parent, width, height, placeholder, onChange, onEnter, glyph)
    local e = FDJ.NewFrame("EditBox", nil, parent)
    e:SetSize(width or 140, height or 26)
    e:SetAutoFocus(false)
    Kit.SetFont(e, "small")
    e:SetTextColor(0.95, 0.96, 0.98)
    e:SetTextInsets(glyph and 28 or 9, 9, 0, 0)
    e:SetMaxLetters(120)
    local fill = Kit.Fill(e, C.field)
    Kit.Edge(e, C.borderDim)
    if native() and Skin.Input(e) then
        fill:SetAlpha(0.6)
        for _, t in ipairs(e.edges or {}) do t:Hide() end
    end
    if glyph then
        e.icon = Kit.Glyph(e, glyph, 13, C.dim)
        e.icon:SetPoint("LEFT", 9, 0)
    end
    local hint = Kit.Text(e, "small", C.dim)
    hint:SetPoint("LEFT", glyph and 28 or 10, 0)
    hint:SetPoint("RIGHT", -9, 0)
    hint:SetText(placeholder or "")
    local function sync(self)
        hint:SetShown(self:GetText() == "" and not self:HasFocus())
    end
    e:SetScript("OnEditFocusGained", function(self)
        Kit.EdgeColor(self, C.accent)
        sync(self)
    end)
    e:SetScript("OnEditFocusLost", function(self)
        Kit.EdgeColor(self, C.borderDim)
        sync(self)
    end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onEnter then onEnter(self, self:GetText()) end
    end)
    e:SetScript("OnTextChanged", function(self, user)
        sync(self)
        if onChange then onChange(self, self:GetText(), user) end
    end)
    return e
end

function Kit.Scroller(parent)
    local s = FDJ.NewFrame("ScrollFrame", nil, parent)
    local content = FDJ.NewFrame("Frame", nil, s)
    content:SetSize(1, 1)
    s:SetScrollChild(content)
    s.content = content
    s:EnableMouseWheel(true)

    local track = FDJ.NewFrame("Frame", nil, s)
    track:SetPoint("TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", 0, 0)
    track:SetWidth(3)
    local thumb = FDJ.NewFrame("Frame", nil, track)
    thumb:SetWidth(3)
    thumb:EnableMouse(true)
    local paint = Kit.Fill(thumb, C.scroll, 1, "ARTWORK")
    if native() then
        track:SetWidth(8)
        thumb:SetWidth(8)
        Kit.Fill(track, C.shadow, 0.35, "BACKGROUND")
        paint:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
        paint:SetTexCoord(0.2, 0.8, 0.125, 0.875)
        paint:SetVertexColor(1, 1, 1, 1)
        paint.native = true
        fills[paint] = nil
    end

    function s:Range()
        return math.max(0, content:GetHeight() - self:GetHeight())
    end

    function s:Bar()
        local range, height = self:Range(), self:GetHeight()
        if range <= 0 or height <= 0 then
            track:Hide()
            return
        end
        track:Show()
        local size = math.max(24, height * height / content:GetHeight())
        thumb:SetHeight(size)
        local offset = (height - size) * (self:GetVerticalScroll() / range)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -offset)
    end

    function s:To(value)
        self:SetVerticalScroll(FDJ.Clamp(value, 0, self:Range()))
        self:Bar()
    end

    function s:Scroll(delta)
        self:To(self:GetVerticalScroll() + delta)
    end

    function s:SetContentHeight(height)
        content:SetHeight(math.max(1, height))
        self:To(self:GetVerticalScroll())
    end

    s:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-delta * 52) end)
    s:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(math.max(1, w - 10))
        self:To(self:GetVerticalScroll())
    end)
    thumb:SetScript("OnEnter", function() if not paint.native then Kit.Paint(paint, C.accent) end end)
    thumb:SetScript("OnLeave", function() if not paint.native then Kit.Paint(paint, C.scroll) end end)
    thumb:SetScript("OnMouseDown", function()
        local _, startY = GetCursorPosition()
        local startScroll = s:GetVerticalScroll()
        local scale = s:GetEffectiveScale()
        thumb:SetScript("OnUpdate", function()
            local _, y = GetCursorPosition()
            local free = s:GetHeight() - thumb:GetHeight()
            if free > 0 then s:To(startScroll + (startY - y) / scale * s:Range() / free) end
        end)
    end)
    thumb:SetScript("OnMouseUp", function() thumb:SetScript("OnUpdate", nil) end)
    return s
end

function Kit.Pool(make)
    local pool = { used = {}, spare = {} }
    function pool:Get()
        local item = table.remove(self.spare) or make()
        self.used[#self.used + 1] = item
        item:Show()
        return item
    end
    function pool:Reset()
        for i = #self.used, 1, -1 do
            local item = self.used[i]
            item:Hide()
            item:ClearAllPoints()
            self.spare[#self.spare + 1] = item
            self.used[i] = nil
        end
    end
    return pool
end

function Kit.Row(parent, height)
    local row = FDJ.NewFrame("Button", nil, parent)
    row:SetHeight(height or 40)
    row.hl = Kit.Fill(row, C.white, 0, "BACKGROUND", 1)
    row.rule = Kit.Line(row, "BOTTOM", C.borderDim, 0.6)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    function row:Hover(on)
        self.hl:SetColorTexture(1, 1, 1, on and 0.035 or 0)
    end
    row:SetScript("OnEnter", function(self) self:Hover(true) end)
    row:SetScript("OnLeave", function(self) self:Hover(false) end)
    return row
end

function Kit.Section(parent, text)
    local fs = Kit.Text(parent, "tiny", C.muted)
    fs:SetText(text:upper())
    return fs
end

local menu

local function buildMenu()
    local blocker = FDJ.NewFrame("Button", nil, UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:SetAllPoints(UIParent)
    blocker:RegisterForClicks("AnyUp")
    blocker:Hide()
    local box = FDJ.NewFrame("Frame", nil, blocker)
    box:SetFrameStrata("FULLSCREEN_DIALOG")
    box:SetClampedToScreen(true)
    box:EnableMouse(true)
    Kit.Fill(box, C.panel, 0.99)
    Kit.Edge(box, C.border)
    if native() then Skin.Panel(box) end
    menu = { blocker = blocker, box = box, rows = {} }
    blocker:SetScript("OnClick", function() blocker:Hide() end)
    local function scrollTo(offset)
        menu.offset = FDJ.Clamp(math.floor(offset + 0.5), 0, math.max(0, #menu.items - menu.visible))
        menu.Paint()
    end
    box:SetScript("OnMouseWheel", function(_, delta) scrollTo((menu.offset or 0) - delta * 2) end)
    box:EnableMouseWheel(true)
    local track = FDJ.NewFrame("Button", nil, box)
    track:SetWidth(8)
    track:SetPoint("TOPRIGHT", -2, -4)
    track:SetPoint("BOTTOMRIGHT", -2, 4)
    track.bg = Kit.Fill(track, C.white, 0.05)
    local thumb = FDJ.NewFrame("Button", nil, track)
    thumb:SetWidth(8)
    thumb.tex = Kit.Fill(thumb, C.muted, 0.55)
    if native() then
        thumb.tex:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
        thumb.tex:SetTexCoord(0.2, 0.8, 0.125, 0.875)
        thumb.tex:SetVertexColor(1, 1, 1, 1)
        thumb.tex.SetColorTexture = function() end
        fills[thumb.tex] = nil
        track.bg:SetColorTexture(0, 0, 0, 0.4)
    end
    local function fromCursor(grab)
        local _, y = GetCursorPosition()
        y = y / track:GetEffectiveScale()
        local top, h = track:GetTop(), track:GetHeight()
        if not top or not h or h <= 0 then return end
        local room = h - thumb:GetHeight()
        local pos = FDJ.Clamp(top - y - (grab or thumb:GetHeight() / 2), 0, math.max(1, room))
        scrollTo(pos / math.max(1, room) * math.max(0, #menu.items - menu.visible))
    end
    local function stopDrag()
        thumb:SetScript("OnUpdate", nil)
        thumb.tex:SetColorTexture(rgb(C.muted, 0.55))
    end
    thumb:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        local grab = (self:GetTop() or 0) - y / track:GetEffectiveScale()
        self.tex:SetColorTexture(rgb(C.accent, 0.9))
        self:SetScript("OnUpdate", function()
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then stopDrag() return end
            fromCursor(grab)
        end)
    end)
    thumb:SetScript("OnMouseUp", stopDrag)
    thumb:SetScript("OnEnter", function(self) self.tex:SetColorTexture(rgb(C.text, 0.7)) end)
    thumb:SetScript("OnLeave", function(self) if not self:GetScript("OnUpdate") then self.tex:SetColorTexture(rgb(C.muted, 0.55)) end end)
    track:SetScript("OnClick", function() fromCursor() end)
    box.track, box.thumb = track, thumb
end

local ROW = 24

local function menuRow(i)
    local row = menu.rows[i]
    if row then return row end
    row = FDJ.NewFrame("Button", nil, menu.box)
    row:SetHeight(ROW)
    row.hl = Kit.Fill(row, C.accent, 0.16, "BACKGROUND")
    if native() then
        row.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.hl:SetBlendMode("ADD")
        row.hl:SetVertexColor(1, 1, 1, 1)
        row.hl:SetAlpha(1)
        fills[row.hl] = nil
    end
    row.hl:Hide()
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(2)
    row.text = Kit.Text(row, "small", C.text)
    row.text:SetPoint("LEFT", 12, 0)
    row.text:SetPoint("RIGHT", -10, 0)
    row.del = FDJ.NewFrame("Button", nil, row)
    row.del:SetSize(16, 16)
    row.del:SetPoint("RIGHT", -6, 0)
    row.del.glyph = Kit.Glyph(row.del, "ui-close", 10, C.bad)
    row.del.glyph:SetAlpha(0.75)
    row.del.glyph:SetPoint("CENTER")
    row.del:SetScript("OnEnter", function(self)
        self.glyph:SetAlpha(1)
        local item = row.item
        if item and item.deleteTip then Kit.Tip(self, item.deleteTip) end
    end)
    row.del:SetScript("OnLeave", function(self)
        self.glyph:SetAlpha(0.75)
        hideTip()
    end)
    row.del:SetScript("OnClick", function()
        local item = row.item
        if not (item and item.onDelete) then return end
        menu.blocker:Hide()
        item.onDelete()
    end)
    row.del:Hide()
    row:SetScript("OnEnter", function(self)
        if self.item and not self.item.title and not self.item.disabled then self.hl:Show() end
        if self.item and self.item.tip then Kit.Tip(self, self.item.text, self.item.tip) end
    end)
    row:SetScript("OnLeave", function(self)
        self.hl:Hide()
        hideTip()
    end)
    row:SetScript("OnClick", function(self)
        local item = self.item
        if not item or item.title or item.disabled then return end
        menu.blocker:Hide()
        if item.onClick then item.onClick() end
    end)
    menu.rows[i] = row
    return row
end

function Kit.Menu(anchor, items, width)
    if menu and menu.blocker:IsShown() and menu.anchor == anchor then Kit.CloseMenu() return end
    if not menu then buildMenu() end
    menu.items = items
    menu.offset = 0
    menu.visible = math.min(#items, 16)
    local box = menu.box
    local w = width or 200
    for _, item in ipairs(items) do
        menu.measure = menu.measure or Kit.Text(box, "small")
        menu.measure:SetText(item.text or "")
        w = math.max(w, menu.measure:GetStringWidth() + 36 + (item.onDelete and 20 or 0))
    end
    w = math.min(w, 380)
    box:SetSize(w, menu.visible * ROW + 8)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
    local scrolls = #items > menu.visible
    if scrolls then w = w + 10 end
    box:SetWidth(w)
    for i = 1, menu.visible do
        local row = menuRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 1, -4 - (i - 1) * ROW)
        row:SetPoint("TOPRIGHT", scrolls and -12 or -1, -4 - (i - 1) * ROW)
        row:Show()
    end
    for i = menu.visible + 1, #menu.rows do menu.rows[i]:Hide() end
    box.track:SetShown(scrolls)
    if scrolls then
        local th = math.max(18, (box:GetHeight() - 8) * menu.visible / #items)
        box.thumb:SetHeight(th)
    end
    function menu.Paint()
        if scrolls then
            local room = box.track:GetHeight() - box.thumb:GetHeight()
            local most = math.max(1, #items - menu.visible)
            box.thumb:ClearAllPoints()
            box.thumb:SetPoint("TOPLEFT", box.track, "TOPLEFT", 0, -math.floor(room * (menu.offset or 0) / most + 0.5))
        end
        for i = 1, menu.visible do
            local row, item = menu.rows[i], items[i + menu.offset]
            row.item = item
            row.hl:Hide()
            if item then
                row.text:SetText(item.title and (item.text or ""):upper() or item.text or "")
                Kit.SetFont(row.text, item.title and "tiny" or "small")
                local color = item.title and C.muted or (item.disabled and C.dim) or item.color or (item.checked and C.white) or C.text
                if native() and item.title then color = { 1, 0.82, 0 } end
                row.text:SetTextColor(rgb(color))
                if native() then
                    if not row.tick then
                        row.tick = row:CreateTexture(nil, "ARTWORK")
                        row.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                        row.tick:SetSize(18, 18)
                        row.tick:SetPoint("LEFT", 2, 0)
                    end
                    row.mark:Hide()
                    row.tick:SetShown(item.checked and true or false)
                    row.text:SetPoint("LEFT", item.title and 8 or 20, 0)
                else
                    row.mark:SetColorTexture(rgb(C.accent))
                    row.mark:SetShown(item.checked and true or false)
                end
                row.del:SetShown(item.onDelete and true or false)
                row.text:SetPoint("RIGHT", item.onDelete and -26 or -10, 0)
            end
        end
    end
    menu.Paint()
    menu.blocker:Show()
    menu.anchor = anchor
    if anchor.HookScript and not anchor.menuCloses then
        anchor.menuCloses = true
        anchor:HookScript("OnHide", function(self)
            if menu.anchor == self then Kit.CloseMenu() end
        end)
    end
end

function Kit.CloseMenu()
    if menu then
        menu.anchor = nil
        menu.blocker:Hide()
    end
end

local function closeButton(parent, onClick)
    local b = FDJ.NewFrame("Button", nil, parent)
    b:SetSize(26, 26)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetPoint("TOPLEFT", 3, -3)
    b.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    b.bg:SetColorTexture(rgb(C.bad, 0))
    local x = Kit.Glyph(b, "ui-close", 12, C.muted)
    x:SetPoint("CENTER")
    b.glyph = x
    local function fit(self)
        local size = math.floor(math.min(self:GetWidth(), self:GetHeight()) * 0.46 + 0.5)
        x:SetSize(size, size)
    end
    b:SetScript("OnSizeChanged", fit)
    fit(b)
    b:SetScript("OnEnter", function()
        b.bg:SetColorTexture(rgb(C.bad, 0.22))
        x:SetVertexColor(1, 1, 1)
    end)
    b:SetScript("OnLeave", function()
        b.bg:SetColorTexture(rgb(C.bad, 0))
        x:SetVertexColor(rgb(C.muted))
    end)
    b:SetScript("OnClick", onClick)
    if native() then
        b.bg:Hide()
        x:Hide()
        Skin.CloseButton(b)
        b:SetScript("OnEnter", nil)
        b:SetScript("OnLeave", nil)
        b:SetScript("OnSizeChanged", nil)
    end
    return b
end
Kit.CloseButton = closeButton

local dragDriver = FDJ.NewFrame("Frame")
local dragging
local function dragStep()
    local f = dragging
    if not f then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        dragging = nil
        dragDriver:SetScript("OnUpdate", nil)
        if f.OnMoved then f:OnMoved() end
        return
    end
    local scale = f:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local x, y = cx / scale - f.grabX, cy / scale - f.grabY
    local sw = UIParent:GetWidth() * UIParent:GetEffectiveScale() / scale
    local sh = UIParent:GetHeight() * UIParent:GetEffectiveScale() / scale
    local w = f:GetWidth()
    x = math.max(60 - w, math.min(sw - 60, x))
    y = math.max(40, math.min(sh, y))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end
function Kit.BeginDrag(f)
    local left, top = f:GetLeft(), f:GetTop()
    if not left or not f:IsMovable() then return end
    local scale = f:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    f.grabX, f.grabY = cx / scale - left, cy / scale - top
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    dragging = f
    dragDriver:SetScript("OnUpdate", dragStep)
end
function Kit.EndDrag()
    if dragging then dragStep() end
    if dragging then
        local f = dragging
        dragging = nil
        dragDriver:SetScript("OnUpdate", nil)
        if f.OnMoved then f:OnMoved() end
    end
end

function Kit.Window(name, title, width, height, parent)
    local f = FDJ.NewFrame("Frame", name, parent or UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) Kit.BeginDrag(self) end)
    f:SetScript("OnDragStop", function() Kit.EndDrag() end)
    f:Hide()
    Kit.Fill(f, C.frame, 0.98)
    Kit.Edge(f, C.border)
    local head = FDJ.NewFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(38)
    Kit.Fill(head, C.header)
    Kit.Line(head, "BOTTOM", C.borderDim)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() Kit.BeginDrag(f) end)
    head:SetScript("OnDragStop", function() Kit.EndDrag() end)
    f.head = head
    f.title = Kit.Text(head, "title", C.white)
    f.title:SetPoint("LEFT", 14, 0)
    f.title:SetText(title)
    f.close = closeButton(head, function() f:Hide() end)
    f.close:SetPoint("RIGHT", -6, 0)
    if native() and Skin.Window(f, title, function() f:Hide() end) then
        f.close:Hide()
        f.close:SetWidth(1)
        f.title:SetAlpha(0)
        local setText = f.title.SetText
        f.title.SetText = function(fs, text) setText(fs, text) Skin.SetTitle(f, text) end
    end
    FDJ.EscapeCloses(name)
    return f
end

function Kit.Resizable(f, minW, minH, onResized)
    local maxW, maxH = 2400, 1600
    local grip = FDJ.NewFrame("Button", nil, f)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 50)
    grip.tex = Kit.Glyph(grip, "ui-grip", 12, C.dim)
    grip.tex:SetPoint("CENTER")
    grip:SetScript("OnEnter", function() grip.tex:SetVertexColor(rgb(C.accent)) end)
    grip:SetScript("OnLeave", function() if not grip:GetScript("OnUpdate") then grip.tex:SetVertexColor(rgb(C.dim)) end end)
    local function stop()
        if not grip:GetScript("OnUpdate") then return end
        grip:SetScript("OnUpdate", nil)
        f:StopMovingOrSizing()
        grip.tex:SetVertexColor(rgb(C.dim))
        if onResized then onResized(f) end
    end
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(minW, minH, maxW, maxH)
    else
        if f.SetMinResize then f:SetMinResize(minW, minH) end
        if f.SetMaxResize then f:SetMaxResize(maxW, maxH) end
    end
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local left, top, bottom = f:GetLeft(), f:GetTop(), f:GetBottom()
        if not left then return end
        f:ClearAllPoints()
        if grip.corner == "TOPRIGHT" then
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            f:StartSizing("TOPRIGHT")
        else
            f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            f:StartSizing("BOTTOMRIGHT")
        end
        grip:SetScript("OnUpdate", function()
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then stop() end
        end)
    end)
    grip:SetScript("OnMouseUp", stop)
    f:HookScript("OnHide", stop)
    f.grip = grip
    return grip
end

local textWindow

function Kit.TextWindow(title, text, onImport, hint, actionLabel)
    if not textWindow then
        local f = Kit.Window("FojjiCoreDJText", "", 500, 320)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        local note = Kit.Text(f, "small", C.muted)
        note:SetPoint("TOPLEFT", 16, -52)
        note:SetPoint("TOPRIGHT", -16, -52)
        note:SetWordWrap(true)
        f.note = note
        local holder = FDJ.NewFrame("Frame", nil, f)
        holder:SetPoint("TOPLEFT", 16, -80)
        holder:SetPoint("BOTTOMRIGHT", -16, 54)
        Kit.Fill(holder, C.field)
        Kit.Edge(holder, C.borderDim)
        local scroll = Kit.Scroller(holder)
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -4, 8)
        local edit = FDJ.NewFrame("EditBox", nil, scroll.content)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(0)
        Kit.SetFont(edit, "small")
        edit:SetTextColor(0.95, 0.96, 0.98)
        edit:SetPoint("TOPLEFT")
        edit:SetPoint("TOPRIGHT")
        edit:SetHeight(200)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnTextChanged", function(self, user)
            if user and f.readOnly then
                self:SetText(f.value or "")
                self:HighlightText()
                return
            end
            scroll:SetContentHeight(math.max(scroll:GetHeight(), self:GetHeight()))
        end)
        edit:SetScript("OnKeyDown", function(_, key)
            if f.readOnly and (key == "C" or key == "X") and IsControlKeyDown() then
                f.status:SetText(L.COPIED)
                C_Timer.After(0.7, function() if f.readOnly and f:IsShown() then f:Hide() end end)
            end
        end)
        edit:SetScript("OnMouseUp", function(self) if f.readOnly then self:HighlightText() end end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
            local top = scroll:GetVerticalScroll()
            if -y < top then scroll:To(-y) elseif -y + h > top + scroll:GetHeight() then scroll:To(-y + h - scroll:GetHeight()) end
        end)
        holder:EnableMouse(true)
        holder:SetScript("OnMouseDown", function() edit:SetFocus() end)
        f.edit = edit
        f.primary = Kit.Button(f, "", 120, 28, nil, "primary")
        f.primary:SetPoint("BOTTOMRIGHT", -16, 14)
        f.secondary = Kit.Button(f, L.CLOSE, 100, 28, function() f:Hide() end)
        f.secondary:SetPoint("RIGHT", f.primary, "LEFT", -8, 0)
        f.status = Kit.Text(f, "small", C.accent)
        f.status:SetPoint("BOTTOMLEFT", 18, 22)
        textWindow = f
    end
    local f = textWindow
    f.title:SetText(title)
    f.note:SetText(hint or "")
    f.readOnly = not onImport
    f.value = text or ""
    f.status:SetText(onImport and "" or L.PRESS_COPY)
    f.edit:SetText(f.value)
    if onImport then
        f.primary:SetLabel(actionLabel or L.IMPORT)
        f.primary:SetScript("OnClick", function()
            if onImport(f.edit:GetText()) ~= false then f:Hide() end
        end)
    else
        f.primary:SetLabel(L.SELECT_ALL)
        f.primary:SetScript("OnClick", function()
            f.edit:SetFocus()
            f.edit:HighlightText()
        end)
    end
    f:Show()
    f:Raise()
    f.edit:SetFocus()
    if not onImport then f.edit:HighlightText() end
    return f
end

local prompt

function Kit.Prompt(title, default, onAccept)
    if not prompt then
        local f = Kit.Window("FojjiCoreDJPrompt", "", 360, 132)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.input = Kit.Input(f, 328, 28, "", nil, function() f.ok:Click() end)
        f.input:SetPoint("TOP", 0, -52)
        f.input:SetMaxLetters(80)
        f.ok = Kit.Button(f, L.SAVE, 100, 28, nil, "primary")
        f.ok:SetPoint("BOTTOMRIGHT", -16, 14)
        f.cancel = Kit.Button(f, L.CANCEL, 100, 28, function() f:Hide() end)
        f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -8, 0)
        prompt = f
    end
    prompt.title:SetText(title)
    prompt.input:SetText(default or "")
    prompt.ok:SetScript("OnClick", function()
        local text = prompt.input:GetText()
        prompt:Hide()
        onAccept(text)
    end)
    prompt:Show()
    prompt:Raise()
    prompt.input:SetFocus()
    prompt.input:HighlightText()
end

local textEditor
local TEXT_SIZES = { 11, 14, 18, 24 }
Kit.TextSizes = TEXT_SIZES
local lastTextSize = 2

local function setMarkFont(fs, px)
    if fs:SetFont(FDJ.Font(), px, "OUTLINE") == false then fs:SetFont(STANDARD_TEXT_FONT, px, "OUTLINE") end
end

function Kit.TextEditor(spec, onAccept, onDelete)
    if not textEditor then
        local f = Kit.Window("FojjiCoreDJTextEditor", L.TEXT_PROMPT, 380, 262)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.input = Kit.Input(f, 348, 28, "", function() if f.Preview then f:Preview() end end, function() f.ok:Click() end)
        f.input:SetPoint("TOP", 0, -50)
        f.input:SetMaxLetters(80)
        local colorLabel = Kit.Text(f, "tiny", C.muted)
        colorLabel:SetPoint("TOPLEFT", 16, -90)
        colorLabel:SetText(L.TEXT_COLOR)
        f.swatches = {}
        for i, c in ipairs(FDJ.RouteColors) do
            local b = FDJ.NewFrame("Button", nil, f)
            b:SetSize(30, 22)
            b:SetPoint("TOPLEFT", 16 + (i - 1) * 36, -106)
            b.ring = b:CreateTexture(nil, "BACKGROUND")
            b.ring:SetPoint("TOPLEFT", -2, 2)
            b.ring:SetPoint("BOTTOMRIGHT", 2, -2)
            b.chip = b:CreateTexture(nil, "ARTWORK")
            b.chip:SetAllPoints()
            b.chip:SetColorTexture(c[1], c[2], c[3])
            b:SetScript("OnClick", function()
                f.color = i
                f:Preview()
            end)
            f.swatches[i] = b
        end
        local sizeLabel = Kit.Text(f, "tiny", C.muted)
        sizeLabel:SetPoint("TOPLEFT", 16, -140)
        sizeLabel:SetText(L.TEXT_SIZE)
        f.size = Kit.Segmented(f, { { 1, L.TEXT_S }, { 2, L.TEXT_M }, { 3, L.TEXT_L }, { 4, L.TEXT_XL } }, function(key)
            f.sizeIndex = key
            f:Preview()
        end)
        f.size:SetPoint("TOPLEFT", 16, -156)
        f.size:SetSize(348, 24)
        f.stage = FDJ.NewFrame("Frame", nil, f)
        f.stage:SetPoint("TOPLEFT", 16, -188)
        f.stage:SetSize(348, 26)
        Kit.Fill(f.stage, C.field)
        f.sample = f.stage:CreateFontString(nil, "OVERLAY")
        setMarkFont(f.sample, 14)
        f.sample:SetShadowColor(0, 0, 0, 0.9)
        f.sample:SetShadowOffset(1, -1)
        f.sample:SetPoint("CENTER")
        f.ok = Kit.Button(f, L.SAVE, 100, 28, nil, "primary")
        f.ok:SetPoint("BOTTOMRIGHT", -16, 12)
        f.cancel = Kit.Button(f, L.CANCEL, 100, 28, function() f:Hide() end)
        f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -8, 0)
        f.delete = Kit.Button(f, L.DELETE, 90, 28)
        f.delete:SetPoint("BOTTOMLEFT", 16, 12)
        function f:Preview()
            local c = FDJ.RouteColors[self.color] or FDJ.RouteColors[1]
            for i, b in ipairs(self.swatches) do
                if i == self.color then b.ring:SetColorTexture(1, 1, 1, 0.9) else b.ring:SetColorTexture(0, 0, 0, 0.6) end
            end
            local px = TEXT_SIZES[self.sizeIndex] or 14
            setMarkFont(self.sample, px)
            local text = self.input:GetText()
            self.sample:SetText(text ~= "" and text or L.TEXT_PROMPT)
            self.sample:SetTextColor(c[1], c[2], c[3], text ~= "" and 1 or 0.4)
            self.stage:SetHeight(math.max(26, px + 12))
        end
        textEditor = f
    end
    local f = textEditor
    f.color = spec.c or 1
    f.sizeIndex = spec.s or lastTextSize
    f.size:Select(f.sizeIndex, true)
    f.input:SetText(spec.label or "")
    f.delete:SetShown(onDelete ~= nil)
    f.delete:SetScript("OnClick", function()
        f:Hide()
        if onDelete then onDelete() end
    end)
    f.ok:SetScript("OnClick", function()
        local text = f.input:GetText()
        f:Hide()
        lastTextSize = f.sizeIndex
        onAccept(text, f.color, f.sizeIndex)
    end)
    f:Preview()
    f:Show()
    f:Raise()
    f.input:SetFocus()
    f.input:HighlightText()
end

local confirm

function Kit.Confirm(text, onYes)
    if not confirm then
        local f = Kit.Window("FojjiCoreDJConfirm", L.CONFIRM, 360, 140)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.text = Kit.Text(f, "normal", C.text, "CENTER")
        f.text:SetPoint("TOPLEFT", 18, -54)
        f.text:SetPoint("TOPRIGHT", -18, -54)
        f.text:SetWordWrap(true)
        f.yes = Kit.Button(f, L.YES, 100, 28, nil, "primary")
        f.yes:SetPoint("BOTTOMRIGHT", -16, 14)
        f.no = Kit.Button(f, L.CANCEL, 100, 28, function() f:Hide() end)
        f.no:SetPoint("RIGHT", f.yes, "LEFT", -8, 0)
        confirm = f
    end
    confirm.text:SetText(text)
    confirm.yes:SetScript("OnClick", function()
        confirm:Hide()
        onYes()
    end)
    confirm:Show()
    confirm:Raise()
end

local toasts = {}

local function layoutToasts()
    local y = -math.floor((UIParent:GetHeight() or 900) * 0.32)
    for _, t in ipairs(toasts) do
        t:ClearAllPoints()
        t:SetPoint("TOP", UIParent, "TOP", 0, y)
        y = y - t:GetHeight() - 8
    end
end

function Kit.Toast(text, actions, lifetime)
    local t = FDJ.NewFrame("Frame", nil, UIParent)
    t:SetFrameStrata("FULLSCREEN_DIALOG")
    t:SetSize(380, 74)
    Kit.Fill(t, C.panel, 0.98)
    Kit.Edge(t, C.border)
    local bar = t:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(3)
    Kit.Paint(bar, C.accent)
    local icon = t:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("TOPLEFT", 14, -12)
    Kit.Logo(icon)
    local msg = Kit.Text(t, "small", C.text)
    msg:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    msg:SetPoint("RIGHT", -30, 0)
    msg:SetWordWrap(true)
    msg:SetJustifyV("TOP")
    msg:SetText(text)
    local function dismiss()
        t:Hide()
        for i, other in ipairs(toasts) do
            if other == t then table.remove(toasts, i) break end
        end
        layoutToasts()
    end
    local x = closeButton(t, dismiss)
    x:SetPoint("TOPRIGHT", -3, -3)
    local prev
    for i = #(actions or {}), 1, -1 do
        local action = actions[i]
        local b = Kit.Button(t, action[1], nil, 24, function()
            dismiss()
            action[2]()
        end, i == #actions and "primary" or nil)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("BOTTOMRIGHT", -10, 10) end
        prev = b
    end
    table.insert(toasts, 1, t)
    if #toasts > 4 then toasts[#toasts]:Hide() table.remove(toasts) end
    layoutToasts()
    C_Timer.After(lifetime or 40, function()
        if t:IsShown() then dismiss() end
    end)
    return t
end

function Kit.Tabs(parent, defs, onSelect)
    local bar = { buttons = {}, current = nil }
    local prev
    for _, def in ipairs(defs) do
        local b = FDJ.NewFrame("Button", nil, parent)
        b:SetHeight(32)
        b.label = Kit.Text(b, "normal", C.tab, "CENTER")
        b.label:SetPoint("CENTER", 0, 1)
        b.label:SetText(def[2])
        b:SetWidth(b.label:GetStringWidth() + 28)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("BOTTOMLEFT", 8, 0)
        b.bar:SetPoint("BOTTOMRIGHT", -8, 0)
        b.bar:SetHeight(2)
        b.key = def[1]
        local skinned = native() and Skin.Tab(b)
        if skinned then
            b:SetHeight(26)
            b:SetWidth(b.label:GetStringWidth() + 40)
            b.label:SetPoint("CENTER", 0, -1)
        end
        function b:Paint()
            local on = bar.current == self.key
            if skinned then
                self.active = on
                self:NativeState(false)
                self.bar:SetColorTexture(0, 0, 0, 0)
                Skin.ButtonText(self.label, true, on or self.hot)
                return
            end
            self.bar:SetColorTexture(rgb(C.accent, on and 1 or 0))
            self.label:SetTone(on and C.white or (self.hot and C.text or C.muted))
        end
        b:SetScript("OnEnter", function(self) self.hot = true self:Paint() end)
        b:SetScript("OnLeave", function(self) self.hot = false self:Paint() end)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", skinned and -4 or 2, 0) end
        b:SetScript("OnClick", function() bar:Select(def[1]) end)
        bar.buttons[def[1]] = b
        bar.first = bar.first or b
        prev = b
    end
    function bar:Select(key)
        self.current = key
        for _, b in pairs(self.buttons) do b:Paint() end
        onSelect(key)
    end
    Kit.OnRepaint(function() for _, b in pairs(bar.buttons) do b:Paint() end end)
    return bar
end

function Kit.Segmented(parent, defs, onSelect)
    local g = FDJ.NewFrame("Frame", nil, parent)
    g:SetHeight(26)
    local fill = Kit.Fill(g, C.field)
    Kit.Edge(g, C.borderDim)
    local skinned = native()
    if skinned then
        fill:Hide()
        for _, t in ipairs(g.edges or {}) do t:Hide() end
    end
    g.buttons = {}
    for i, def in ipairs(defs) do
        local b = FDJ.NewFrame("Button", nil, g)
        b.bg = b:CreateTexture(nil, "ARTWORK")
        b.bg:SetAllPoints()
        if skinned then Skin.Button(b) end
        b.t = Kit.Text(b, "small", C.muted, "CENTER")
        b.t:SetPoint("CENTER")
        b.t:SetText(def[2])
        b.key = def[1]
        b:SetScript("OnClick", function() g:Select(def[1]) end)
        b:SetScript("OnEnter", function(self) if g.value ~= self.key then self.t:SetTone(C.white) end end)
        b:SetScript("OnLeave", function() g:Paint() end)
        if skinned then b:HookScript("OnMouseUp", function() g:Paint() end) end
        g.buttons[i] = b
    end
    function g:Layout()
        local w = (self:GetWidth() - 2) / #self.buttons
        for i, b in ipairs(self.buttons) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 1 + (i - 1) * w, -1)
            b:SetSize(w, self:GetHeight() - 2)
        end
    end
    function g:Paint()
        for _, b in ipairs(self.buttons) do
            local on = b.key == self.value
            if b.nativeArt then
                b.active = on
                b:NativeState(false)
                b.bg:SetColorTexture(0, 0, 0, 0)
                Skin.ButtonText(b.t, true, on)
            else
                b.bg:SetColorTexture(rgb(C.accent, on and 0.3 or 0))
                b.t:SetTone(on and C.white or C.muted)
            end
        end
    end
    function g:Select(key, quiet)
        self.value = key
        self:Paint()
        if not quiet and onSelect then onSelect(key) end
    end
    g:SetScript("OnSizeChanged", function(self) self:Layout() end)
    Kit.OnRepaint(function() g:Paint() end)
    return g
end

function Kit.Badge(parent, color)
    local f = FDJ.NewFrame("Frame", nil, parent)
    f:SetSize(18, 16)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(12, 12)
    f.icon:SetPoint("LEFT", 0, 0)
    f.icon:Hide()
    f.text = Kit.Text(f, "tiny", color or C.accent, "LEFT")
    f.text:SetPoint("LEFT", 0, 0)
    function f:Set(value, tint, icon)
        if not value or value == 0 or value == "" then
            self:Hide()
            return
        end
        self.text:SetText(value)
        self.text:SetTone(tint or color or C.accent)
        self.text:ClearAllPoints()
        if icon then
            self.icon:SetTexture(icon)
            self.icon:Show()
            self.text:SetPoint("LEFT", self.icon, "RIGHT", 2, 0)
        else
            self.icon:Hide()
            self.text:SetPoint("LEFT", 0, 0)
        end
        self:SetWidth(self.text:GetStringWidth() + (icon and 14 or 0))
        self:Show()
    end
    return f
end

function Kit.Portrait(parent, size)
    local holder = FDJ.NewFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    local ring = holder:CreateTexture(nil, "BACKGROUND")
    ring:SetAllPoints()
    ring:SetTexture(FDJ.Glyph("ui-dot"))
    ring:SetVertexColor(rgb(C.border))
    local face = holder:CreateTexture(nil, "ARTWORK")
    face:SetPoint("TOPLEFT", 2, -2)
    face:SetPoint("BOTTOMRIGHT", -2, 2)
    holder.face = face
    holder.ring = ring
    function holder:SetCreature(display, icon)
        local ok = false
        if display and SetPortraitTextureFromCreatureDisplayID then
            ok = pcall(SetPortraitTextureFromCreatureDisplayID, face, display)
        end
        if ok then
            face:SetTexCoord(0, 1, 0, 1)
            return
        end
        icon = icon or "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
        face:SetTexCoord(0, 1, 0, 1)
        if not (SetPortraitToTexture and pcall(SetPortraitToTexture, face, icon)) then
            face:SetTexture(icon)
            face:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
    return holder
end

function Kit.ItemIcon(parent, size)
    local b = FDJ.NewFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Kit.Edge(b, C.borderDim)
    function b:SetItem(itemID)
        self.itemID = itemID
        self.icon:SetTexture(C_Item.GetItemIconByID(itemID) or 134400)
        local _, _, quality = C_Item.GetItemInfo(itemID)
        local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if qc then Kit.EdgeColor(self, { qc.r, qc.g, qc.b }, 0.9) else Kit.EdgeColor(self, C.borderDim) end
    end
    b:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", hideTip)
    b:SetScript("OnClick", function(self)
        if self.itemID and IsModifiedClick() then
            local _, link = C_Item.GetItemInfo(self.itemID)
            if link then HandleModifiedItemClick(link) end
        end
    end)
    return b
end

function Kit.SpellIcon(parent, size)
    local b = FDJ.NewFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Kit.Edge(b, C.shadow, 0.9)
    function b:SetSpell(spell)
        self.spell = spell
        self.icon:SetTexture(C_Spell.GetSpellTexture(spell) or 134400)
    end
    b:SetScript("OnEnter", function(self)
        Kit.EdgeColor(self, C.accent)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(self.spell)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        Kit.EdgeColor(self, C.shadow, 0.9)
        hideTip()
    end)
    b:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and C_Spell.GetSpellLink then FDJ.InsertLink(C_Spell.GetSpellLink(self.spell)) end
    end)
    return b
end

function Kit.MarkText(b)
    b.text = Addon.Localize(b:CreateFontString(nil, "OVERLAY"))
    if b.text:SetFont(FDJ.Font(), 15, "OUTLINE") == false then b.text:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE") end
    b.text:SetShadowColor(0, 0, 0, 0.9)
    b.text:SetShadowOffset(1, -1)
    b.text:SetPoint("CENTER")
    b.text:Hide()
end

function Kit.ShowMark(b, mk, color)
    local tex, def = FDJ.Routes.MarkTexture(mk.k)
    if def.text then
        b.icon:Hide()
        b.label:Set(nil)
        local px = TEXT_SIZES[mk.s or 2] or 14
        if b.textSize ~= px then
            setMarkFont(b.text, px)
            b.textSize = px
        end
        b.text:SetText(mk.label or "?")
        b.text:SetTextColor(color[1], color[2], color[3])
        b.text:Show()
        b:SetSize(math.max(24, b.text:GetStringWidth() + 10), px + 8)
        return
    end
    b.text:Hide()
    b.icon:Show()
    FDJ.Routes.ApplyIcon(b.icon, def)
    if not def.plain then b.icon:SetVertexColor(color[1], color[2], color[3]) end
    b.label:Set(mk.label, color)
    b:SetSize(24, 24)
end

function Kit.Ink(owner)
    local ink = { owner = owner, shadows = {}, colors = {}, dots = {}, shadowDots = {}, n = 0, d = 0 }
    local function line(pool, i, sub)
        local l = pool[i]
        if not l then
            l = owner:CreateLine(nil, "ARTWORK", nil, sub)
            pool[i] = l
        end
        return l
    end
    local function dot(pool, i, sub)
        local t = pool[i]
        if not t then
            t = owner:CreateTexture(nil, "ARTWORK", nil, sub)
            t:SetTexture(FDJ.Glyph("ui-dot"))
            pool[i] = t
        end
        return t
    end
    local function place(t, x, y, size, color, alpha)
        t:ClearAllPoints()
        t:SetPoint("CENTER", owner, "TOPLEFT", x, -y)
        t:SetSize(size, size)
        t:SetVertexColor(color[1], color[2], color[3], alpha)
        t:Show()
    end
    local function stroke(l, x1, y1, x2, y2, color, width, alpha)
        l:SetThickness(width)
        l:SetColorTexture(color[1], color[2], color[3], alpha)
        l:SetStartPoint("TOPLEFT", owner, x1, -y1)
        l:SetEndPoint("TOPLEFT", owner, x2, -y2)
        l:Show()
    end
    function ink:Begin()
        self.n, self.d = 0, 0
    end
    function ink:Joint(x, y, color, width, alpha, shadow)
        self.d = self.d + 1
        if shadow ~= false then place(dot(self.shadowDots, self.d, 1), x, y, width + 3 * (self.k or 1), C.shadow, 0.55 * (alpha or 1)) end
        place(dot(self.dots, self.d, 4), x, y, width, color, alpha or 1)
        if shadow == false and self.shadowDots[self.d] then self.shadowDots[self.d]:Hide() end
    end
    function ink:Seg(x1, y1, x2, y2, color, width, alpha, shadow)
        self.n = self.n + 1
        if shadow ~= false then
            stroke(line(self.shadows, self.n, 0), x1, y1, x2, y2, C.shadow, width + 3 * (self.k or 1), 0.55 * (alpha or 1))
        elseif self.shadows[self.n] then
            self.shadows[self.n]:Hide()
        end
        stroke(line(self.colors, self.n, 3), x1, y1, x2, y2, color, width, alpha or 1)
    end
    function ink:Path(pts, sx, sy, color, width, alpha, shadow)
        for j = 1, #pts - 2, 2 do
            self:Seg(pts[j] * sx, pts[j + 1] * sy, pts[j + 2] * sx, pts[j + 3] * sy, color, width, alpha, shadow)
        end
        for j = 1, #pts, 2 do self:Joint(pts[j] * sx, pts[j + 1] * sy, color, width, alpha, shadow) end
    end
    function ink:End()
        for i = self.n + 1, #self.colors do
            self.colors[i]:Hide()
            if self.shadows[i] then self.shadows[i]:Hide() end
        end
        for i = self.d + 1, #self.dots do
            self.dots[i]:Hide()
            if self.shadowDots[i] then self.shadowDots[i]:Hide() end
        end
    end
    return ink
end
