local _, Addon = ...
local K = {}
Addon.UIKit = K

local FONT = Addon.LocalFont("Interface\\AddOns\\FojjiCore\\font\\Numen.ttf")
local WHITE = "Interface\\Buttons\\WHITE8x8"
local QUESTION = 134400
K.FONT, K.WHITE, K.QUESTION = FONT, WHITE, QUESTION
function K.SetFontPath(path) if path then FONT = path; K.FONT = path end end
local UI_TEX = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
K.TEX = UI_TEX
local painters = {}
local function C(name)
    if Addon.GetColor then return Addon.GetColor(name) end
    return 0.8, 0.8, 0.8
end
local function paint(fn) painters[#painters + 1] = fn; fn() end
local function repaint() for i = 1, #painters do painters[i]() end end

local function solid(tex, name, alpha)
    tex:SetTexture(WHITE)
    paint(function() local r, g, b = C(name); tex:SetVertexColor(r, g, b, alpha or 1) end)
    return tex
end

K.SCALE = 0.93
local function setFont(fs, size)
    if not fs.exact then size = math.max(10, math.floor(size * K.SCALE + 0.5)) end
    fs:SetFont(FONT, size, "")
    if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, "") end
end

local function T(parent, size, colorName, justify, exact)
    local fs = Addon.Localize(parent:CreateFontString(nil, "OVERLAY"))
    fs.exact = exact
    setFont(fs, size or 12)
    fs:SetShadowColor(0, 0, 0, 0.7)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    fs.colorName = colorName or "text"
    paint(function() fs:SetTextColor(C(fs.colorName)) end)
    function fs:SetColorName(n) self.colorName = n; self:SetTextColor(C(n)) end
    return fs
end

local function Border(f, name, alpha)
    local b = { name = name or "borderDim", alpha = alpha or 1 }
    for i = 1, 4 do
        b[i] = f:CreateTexture(nil, "BORDER")
        b[i]:SetTexture(WHITE)
    end
    b[1]:SetPoint("TOPLEFT"); b[1]:SetPoint("TOPRIGHT"); b[1]:SetHeight(1)
    b[2]:SetPoint("BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT"); b[2]:SetHeight(1)
    b[3]:SetPoint("TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT"); b[3]:SetWidth(1)
    b[4]:SetPoint("TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT"); b[4]:SetWidth(1)
    function b:Set(n, a)
        self.name, self.alpha = n or self.name, a or self.alpha
        local r, g, bl = C(self.name)
        for i = 1, 4 do self[i]:SetVertexColor(r, g, bl, self.alpha) end
    end
    paint(function() b:Set() end)
    return b
end

local function Surface(f, colorName, alpha, borderName, borderAlpha)
    f.bg = solid(f:CreateTexture(nil, "BACKGROUND"), colorName or "field", alpha or 1)
    f.bg:SetAllPoints()
    if borderName ~= false then f.bd = Border(f, borderName or "borderDim", borderAlpha or 1) end
    return f
end

local function Tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(Addon.Tr(title), 1, 1, 1)
        if text then GameTooltip:AddLine(Addon.Tr(text), 0.75, 0.78, 0.82, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function Icon(parent, size)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    Surface(holder, "frame", 1, "border", 0.9)
    holder.tex = holder:CreateTexture(nil, "ARTWORK")
    holder.tex:SetPoint("TOPLEFT", 1, -1)
    holder.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    holder.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    function holder:SetIcon(icon) self.tex:SetTexture(icon or QUESTION) end
    return holder
end

local function Glyph(parent, name, size, colorName, alpha, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(UI_TEX .. name)
    t:SetSize(size, size)
    t.colorName, t.alphaV = colorName or "text", alpha or 1
    paint(function() local r, g, b = C(t.colorName); t:SetVertexColor(r, g, b, t.alphaV) end)
    function t:SetColorName(n, a) self.colorName = n; self.alphaV = a or self.alphaV; local r, g, b = C(n); self:SetVertexColor(r, g, b, self.alphaV) end
    return t
end

local function Sheen(f, height, alpha)
    local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    t:SetTexture(UI_TEX .. "grad-v")
    t:SetPoint("TOPLEFT", 1, -1)
    t:SetPoint("TOPRIGHT", -1, -1)
    t:SetHeight(height or 40)
    paint(function() local r, g, b = C("accent"); t:SetVertexColor(r, g, b, alpha or 0.07) end)
    return t
end

local W = {}
local function native() return Addon.Native and Addon.Skin ~= nil end

function W.Button(parent, text, width, height, kind, icon)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height or 26)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(WHITE)
    b.bg:SetAllPoints()
    b.bd = Border(b, "border")
    b.label = T(b, 13, "text", "CENTER")
    b.label:SetPoint("LEFT", icon and 24 or 6, 0)
    b.label:SetPoint("RIGHT", -6, 0)
    b.label:SetText(text)
    if icon then
        b.icon = Glyph(b, icon, 14, "text")
        b.icon:SetPoint("LEFT", 9, 0)
        if text == "" then b.icon:ClearAllPoints(); b.icon:SetPoint("CENTER") end
    end
    b.kind = kind or "ghost"
    local list = kind == "dropdown"
    if native() and (list and Addon.Skin.Dropdown(b) or (not list and Addon.Skin.Button(b))) then
        b.bg:Hide()
        for i = 1, 4 do b.bd[i]:Hide() end
    end
    function b:Paint(hover)
        if self.nativeDropdown then
            self.label:SetTextColor(1, 1, 1)
            return
        end
        if self.nativeArt then
            self:NativeState(false)
            Addon.Skin.ButtonText(self.label, self:IsEnabled(), hover)
            if self.icon then self.icon:SetVertexColor(1, hover and 1 or 0.82, hover and 1 or 0, 1) end
            return
        end
        if self.kind == "primary" then
            local r, g, bl = C("accent")
            self.bg:SetVertexColor(r, g, bl, hover and 0.42 or 0.26)
            self.bd:Set("accent", hover and 1 or 0.75)
            self.label:SetTextColor(1, 1, 1)
            if self.icon then self.icon:SetVertexColor(1, 1, 1, 1) end
        elseif self.kind == "danger" then
            local r, g, bl = C("warning")
            self.bg:SetVertexColor(r, g, bl, hover and 0.22 or 0.08)
            self.bd:Set("warning", hover and 0.9 or 0.45)
            self.label:SetTextColor(1, 0.82, 0.8)
            if self.icon then self.icon:SetVertexColor(1, 0.82, 0.8, 1) end
        else
            local r, g, bl = C(hover and "buttonHover" or "button")
            self.bg:SetVertexColor(r, g, bl, 1)
            self.bd:Set(hover and "accent" or "border", hover and 0.8 or 1)
            self.label:SetTextColor(C(hover and "white" or "text"))
            if self.icon then self.icon:SetColorName(hover and "accent" or "text") end
        end
    end
    paint(function() b:Paint(false) end)
    b:SetScript("OnEnter", function(self) self:Paint(true) end)
    b:SetScript("OnLeave", function(self) self:Paint(false) end)
    function b:SetKind(k) self.kind = k; self:Paint(self:IsMouseOver()) end
    return b
end

function W.Switch(parent, onChange)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(30, 16)
    s.track = s:CreateTexture(nil, "BACKGROUND")
    s.track:SetTexture(WHITE)
    s.track:SetAllPoints()
    s.bd = Border(s, "border")
    s.knob = s:CreateTexture(nil, "ARTWORK")
    s.knob:SetTexture(WHITE)
    s.knob:SetSize(10, 10)
    local box = native() and Addon.Skin.Check(s, 24)
    if box then
        s:SetSize(24, 24)
        s.track:Hide()
        s.knob:Hide()
        for i = 1, 4 do s.bd[i]:Hide() end
        box:SetPoint("CENTER")
    end
    function s:Paint()
        if box then box:Set(self.value, self.hover) return end
        self.knob:ClearAllPoints()
        if self.value then
            local r, g, b = C("accent")
            self.track:SetVertexColor(r, g, b, 0.85)
            self.bd:Set("accent", 1)
            self.knob:SetVertexColor(1, 1, 1, 1)
            self.knob:SetPoint("RIGHT", -3, 0)
        else
            local r, g, b = C("frame")
            self.track:SetVertexColor(r, g, b, 1)
            self.bd:Set(self.hover and "accent" or "border", self.hover and 0.8 or 1)
            local dr, dg, db = C("dim")
            self.knob:SetVertexColor(dr, dg, db, 1)
            self.knob:SetPoint("LEFT", 3, 0)
        end
    end
    function s:SetValue(v) self.value = v and true or false; self:Paint() end
    s:SetScript("OnClick", function(self)
        self:SetValue(not self.value)
        if onChange then onChange(self.value) end
    end)
    s:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    s:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    paint(function() s:Paint() end)
    return s
end

function W.SwitchRow(parent, label, onChange, size)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(24)
    row.switch = W.Switch(row, onChange)
    row.switch:SetPoint("LEFT", 0, 0)
    row.label = T(row, size or 13, "text")
    row.label:SetPoint("LEFT", row.switch, "RIGHT", 10, 0)
    row.label:SetPoint("RIGHT", -22, 0)
    row.label:SetText(label)
    row.reset = W.ResetMark(row, function() if row.onReset then row.onReset() end end)
    row.reset:SetPoint("RIGHT", 0, 0)
    row.reset:Hide()
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.onReset then self.onReset() end
            return
        end
        self.switch:Click()
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(self) self.label:SetTextColor(C("white")); self.switch.hover = true; self.switch:Paint() end)
    row:SetScript("OnLeave", function(self) self.label:SetTextColor(C(self.label.colorName)); self.switch.hover = false; self.switch:Paint() end)
    function row:SetValue(v) self.switch:SetValue(v) end
    function row:SetCustom(v) self.reset:SetShown(v and true or false) end
    row.h = 24
    return row
end

local function Caption(parent, text)
    local c = T(parent, 12, "tab")
    c:SetText(text)
    return c
end

function W.Input(parent, onCommit)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(28)
    Surface(h, "frame", 1, "border", 1)
    if native() and Addon.Skin.Input(h) then
        h.bg:SetAlpha(0.6)
        for i = 1, 4 do h.bd[i]:Hide() end
        h.bd.Set = function() end
    end
    local eb = CreateFrame("EditBox", nil, h)
    eb:SetPoint("TOPLEFT", 9, -2)
    eb:SetPoint("BOTTOMRIGHT", -9, 2)
    eb:SetAutoFocus(false)
    eb:SetFont(FONT, 12, "")
    eb:SetTextColor(0.93, 0.95, 0.98)
    eb:SetMaxLetters(80)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(h.value or ""); self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function() h.bd:Set("accent", 1) end)
    eb:SetScript("OnEditFocusLost", function(self)
        h.bd:Set("border", 1)
        local v = self:GetText()
        if v ~= (h.value or "") and onCommit then onCommit(v) end
    end)
    h.box = eb
    function h:SetValue(v)
        self.value = v and tostring(v) or ""
        if not eb:HasFocus() then eb:SetText(self.value) end
    end
    return h
end

function W.Stepper(parent, minV, maxV, step, onChange, suffix)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(112, 28)
    Surface(s, "frame", 1, "border", 1)
    local function btn(text, point, delta)
        local b = CreateFrame("Button", nil, s)
        b:SetSize(28, 26)
        b:SetPoint(point, point == "LEFT" and 1 or -1, 0)
        b.bg = solid(b:CreateTexture(nil, "ARTWORK"), "button", 1)
        b.bg:SetAllPoints()
        b.t = T(b, 15, "text", "CENTER")
        b.t:SetPoint("CENTER", 0, 1)
        b.t:SetText(text)
        b:SetScript("OnEnter", function(self) local r, g, bl = C("accent"); self.bg:SetVertexColor(r, g, bl, 0.35) end)
        b:SetScript("OnLeave", function(self) local r, g, bl = C("button"); self.bg:SetVertexColor(r, g, bl, 1) end)
        b:SetScript("OnClick", function()
            local v = math.max(minV, math.min(maxV, (s.value or minV) + delta))
            if v ~= s.value then s:SetValue(v); if onChange then onChange(v) end end
        end)
        return b
    end
    s.minus = btn("-", "LEFT", -step)
    s.plus = btn("+", "RIGHT", step)
    s.text = T(s, 13, "white", "CENTER")
    s.text:SetPoint("LEFT", s.minus, "RIGHT", 0, 0)
    s.text:SetPoint("RIGHT", s.plus, "LEFT", 0, 0)
    function s:SetValue(v)
        self.value = tonumber(v) or minV
        local txt = (self.value % 1 == 0) and tostring(self.value) or string.format("%.1f", self.value)
        self.text:SetText(txt .. (suffix or "s"))
    end
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(_, d)
        local v = math.max(minV, math.min(maxV, (s.value or minV) + d * step))
        if v ~= s.value then s:SetValue(v); if onChange then onChange(v) end end
    end)
    s.h = 28
    return s
end

function W.Segmented(parent, labels, onChange)
    local g = CreateFrame("Frame", nil, parent)
    g:SetHeight(28)
    Surface(g, "frame", 1, "border", 1)
    local skinned = native()
    if skinned then
        g.bg:Hide()
        for i = 1, 4 do g.bd[i]:Hide() end
    end
    g.buttons = {}
    for i, text in ipairs(labels) do
        local b = CreateFrame("Button", nil, g)
        b.bg = b:CreateTexture(nil, "ARTWORK")
        b.bg:SetTexture(WHITE)
        b.bg:SetAllPoints()
        if skinned then Addon.Skin.Button(b) b:HookScript("OnMouseUp", function() g:Paint() end) end
        b.t = T(b, 13, "text", "CENTER")
        b.t:SetAllPoints()
        b.t:SetText(text)
        b:SetScript("OnClick", function()
            if g.value ~= i then g:SetValue(i); if onChange then onChange(i) end end
        end)
        b:SetScript("OnEnter", function(self) if g.value ~= i then self.t:SetTextColor(C("white")) end end)
        b:SetScript("OnLeave", function() g:Paint() end)
        g.buttons[i] = b
    end
    function g:Layout()
        local w = (self:GetWidth() - 2) / #self.buttons
        for i, b in ipairs(self.buttons) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 1 + (i - 1) * w, -1)
            b:SetSize(w, 26)
        end
    end
    function g:Paint()
        for i, b in ipairs(self.buttons) do
            if b.nativeArt then
                b.active = i == self.value
                b:NativeState(false)
                b.bg:SetVertexColor(0, 0, 0, 0)
                Addon.Skin.ButtonText(b.t, true, b.active)
            elseif i == self.value then
                local r, gg, bl = C("accent")
                b.bg:SetVertexColor(r, gg, bl, 0.30)
                b.t:SetTextColor(1, 1, 1)
            else
                b.bg:SetVertexColor(0, 0, 0, 0)
                b.t:SetTextColor(C("dim"))
            end
        end
    end
    function g:SetValue(v) self.value = v; self:Paint() end
    g:SetScript("OnSizeChanged", function(self) self:Layout() end)
    paint(function() g:Paint() end)
    g.h = 28
    return g
end

function W.Dropdown(parent, width, onOpen)
    local b = W.Button(parent, "", width, 28, "dropdown")
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", 10, 0)
    b.label:SetPoint("RIGHT", -22, 0)
    b.label:SetJustifyH("LEFT")
    b.arrow = Glyph(b, "icon-chevron-down", 14, "dim")
    b.arrow:SetPoint("RIGHT", -8, 0)
    if b.nativeDropdown then b.arrow:SetAlpha(0) end
    b:HookScript("OnEnter", function(self) self.arrow:SetColorName("accent") end)
    b:HookScript("OnLeave", function(self) self.arrow:SetColorName("dim") end)
    b:SetScript("OnClick", function(self) if onOpen then onOpen(self) end end)
    function b:SetText(t) self.label:SetText(t) end
    return b
end

local function openMenu(owner, entries)
    if Addon.OptionsMenu and Addon.OptionsMenu.Open then
        Addon.OptionsMenu.Open(owner, entries, { width = math.max(200, owner:GetWidth()), maxRows = 10 })
    end
end

function W.Search(parent, width, onChange)
    local s = W.Input(parent, nil)
    s:SetWidth(width)
    s.icon = Glyph(s, "icon-search", 14, "dim")
    s.icon:SetPoint("LEFT", 9, 0)
    s.box:ClearAllPoints()
    s.box:SetPoint("TOPLEFT", 28, -2)
    s.box:SetPoint("BOTTOMRIGHT", -9, 2)
    s.hint = T(s, 12, "dim")
    s.hint:SetPoint("LEFT", 28, 0)
    s.hint:SetText("Search...")
    s.box:SetScript("OnTextChanged", function(self)
        s.hint:SetShown(self:GetText() == "")
        if onChange then onChange(self:GetText()) end
    end)
    return s
end

function W.Slider(parent, label, minV, maxV, step, onChange, fmt)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(46)
    c.label = T(c, 13, "text")
    c.label:SetPoint("TOPLEFT", 0, 0)
    c.label:SetText(label)
    c.value = T(c, 12, "white", "RIGHT")
    c.value:SetPoint("TOPRIGHT", 0, 0)
    local s = CreateFrame("Slider", nil, c)
    s:SetPoint("TOPLEFT", 0, -22)
    s:SetPoint("TOPRIGHT", 0, -22)
    s:SetHeight(16)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    local track = solid(s:CreateTexture(nil, "BACKGROUND"), "frame", 1)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
    local tb = CreateFrame("Frame", nil, c)
    tb:SetPoint("LEFT", s, "LEFT"); tb:SetPoint("RIGHT", s, "RIGHT"); tb:SetHeight(6)
    tb:SetFrameLevel(c:GetFrameLevel() + 1)
    s:SetFrameLevel(c:GetFrameLevel() + 3)
    Border(tb, "border")
    local fill = solid(s:CreateTexture(nil, "ARTWORK"), "accent", 0.85)
    fill:SetPoint("LEFT")
    fill:SetHeight(6)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    if native() then
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        thumb:SetSize(32, 32)
    else
        thumb:SetTexture(WHITE)
        thumb:SetVertexColor(1, 1, 1, 1)
        thumb:SetSize(10, 16)
    end
    s:SetThumbTexture(thumb)
    local function show(v)
        c.value:SetText(fmt and fmt(v) or tostring(v))
        local w = s:GetWidth() or 0
        local pct = (maxV > minV) and (v - minV) / (maxV - minV) or 0
        fill:SetWidth(math.max(1, w * pct))
    end
    s:SetScript("OnValueChanged", function(_, v, user)
        v = math.floor(v / step + 0.5) * step
        show(v)
        if onChange then onChange(v, user) end
    end)
    s:SetScript("OnMouseWheel", function(self, d)
        self:SetValue(math.max(minV, math.min(maxV, (self:GetValue() or minV) + d * step)))
    end)
    s:SetScript("OnSizeChanged", function() show(s:GetValue() or minV) end)
    c.slider = s
    function c:SetValue(v) s:SetValue(v); show(v) end
    function c:GetValue() return s:GetValue() end
    c.h = 46
    return c
end

function W.Card(parent, title, desc, icon)
    local card = CreateFrame("Frame", nil, parent)
    Surface(card, "panel", 0.92, "borderDim")
    if not native() then Sheen(card, 46, 0.06) end
    card.accent = solid(card:CreateTexture(nil, "ARTWORK"), "accent", 0.9)
    card.accent:SetSize(3, 16)
    card.accent:SetPoint("TOPLEFT", 0, -16)
    if native() or icon then card.accent:Hide() end
    local textX = 18
    if icon then
        card.icon = Icon(card, 34)
        card.icon:SetPoint("TOPLEFT", 16, -14)
        card.icon:SetIcon(icon)
        textX = 60
    end
    card.title = T(card, 15, native() and "title" or "white")
    card.title:SetPoint("TOPLEFT", textX, (icon and not desc) and -23 or -14)
    card.title:SetText(title or "")
    card.y = (icon and not desc) and 58 or 42
    if desc then
        card.desc = T(card, 12, "dim")
        card.desc:SetPoint("TOPLEFT", textX, -37)
        card.desc:SetPoint("RIGHT", -18, 0)
        card.desc:SetWordWrap(true)
        card.desc:SetJustifyV("TOP")
        card.desc:SetText(desc)
        card.y = 62
    end
    card.items = {}
    function card:Add(widget, height, gap, indent)
        widget:SetParent(self)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", 18 + (indent or 0), -self.y)
        if widget.fill ~= false then widget:SetPoint("RIGHT", -18, 0) end
        if height then widget:SetHeight(height) end
        self.items[#self.items + 1] = { w = widget, h = height or widget.h or 24, gap = gap or 10, indent = indent }
        self.y = self.y + (height or widget.h or 24) + (gap or 10)
        self:SetHeight(self.y + 8)
        return widget
    end
    function card:Restack()
        local y = (icon and not desc) and 58 or 42
        if self.desc then
            local dh = self.desc.GetStringHeight and self.desc:GetStringHeight()
            y = 46 + math.max(16, tonumber(dh) or 16)
        end
        for _, it in ipairs(self.items) do
            if it.w:IsShown() then
                it.w:ClearAllPoints()
                it.w:SetPoint("TOPLEFT", 18 + (it.indent or 0), -y)
                if it.w.fill ~= false then it.w:SetPoint("RIGHT", -18, 0) end
                y = y + it.h + it.gap
            end
        end
        self:SetHeight(y + 8)
    end
    return card
end

function W.CardStack(page, top, UI)
    local scroll = UI.Scroll(page)
    scroll:SetPoint("TOPLEFT", 0, top or -54)
    scroll:SetPoint("BOTTOMRIGHT", -18, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(600, 10)
    scroll:SetScrollChild(body)
    local stack = { scroll = scroll, body = body, cards = {} }
    function stack:Add(card)
        card:SetParent(body)
        self.cards[#self.cards + 1] = card
        return card
    end
    function stack:Layout()
        local w = scroll:GetWidth() or 600
        body:SetWidth(w)
        local cols = w >= 900 and 2 or 1
        local colW = cols == 2 and math.floor((w - 16) / 2) or math.min(w, 760)
        local y = { 0, 0 }
        for _, card in ipairs(self.cards) do
            if card:IsShown() and card.wide then
                local top = math.max(y[1], y[2])
                card:SetWidth(cols == 2 and w or colW)
                if card.Restack then card:Restack() end
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", 0, -top)
                y[1] = top + (card:GetHeight() or 0) + 14
                y[2] = y[1]
            elseif card:IsShown() then
                card:SetWidth(colW)
                if card.Restack then card:Restack() end
                local col = (cols == 2 and y[2] < y[1]) and 2 or 1
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", (col - 1) * (colW + 16), -y[col])
                y[col] = y[col] + (card:GetHeight() or 0) + 14
            end
        end
        body:SetHeight(math.max(y[1], y[2]) + 4)
    end
    scroll:SetScript("OnSizeChanged", function() stack:Layout() end)
    return stack
end

function W.ResetMark(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    b.t = Glyph(b, "icon-reset", 12, "dim")
    b.t:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self)
        self.t:SetColorName("accent")
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Changed - click to reset", 1, 1, 1)
            GameTooltip:AddLine("Goes back to the pack's default.", 0.75, 0.78, 0.82)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self.t:SetColorName("dim"); if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick", function() if onClick then onClick() end end)
    return b
end

local function openColorPicker(rgb, onChange)
    if not ColorPickerFrame then return end
    local r, g, b = rgb and rgb[1] or 1, rgb and rgb[2] or 1, rgb and rgb[3] or 1
    local function current()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        return { math.floor(nr * 1000 + 0.5) / 1000, math.floor(ng * 1000 + 0.5) / 1000, math.floor(nb * 1000 + 0.5) / 1000 }
    end
    local pending
    local function push(c)
        pending = c
        C_Timer.After(0, function() if pending then local p = pending; pending = nil; onChange(p) end end)
    end
    if ColorPickerFrame.SetFrameStrata then ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG") end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() push(current()) end,
            cancelFunc = function() onChange({ r, g, b }) end,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = r, g = g, b = b }
        ColorPickerFrame.func = function() push(current()) end
        ColorPickerFrame.cancelFunc = function() onChange({ r, g, b }) end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

function W.ColorSwatch(parent, onChange, clearable, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(label and 150 or 40, 26)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(40, 22)
    b.box:SetPoint("LEFT", 0, 0)
    Surface(b.box, "frame", 1, "border")
    b.col = b.box:CreateTexture(nil, "ARTWORK")
    b.col:SetTexture(WHITE)
    b.col:SetPoint("TOPLEFT", 3, -3)
    b.col:SetPoint("BOTTOMRIGHT", -3, 3)
    b.none = T(b.box, 9, "dim", "CENTER")
    b.none:SetAllPoints()
    b.none:SetText("AUTO")
    if label then
        b.label = T(b, 13, "text")
        b.label:SetPoint("LEFT", b.box, "RIGHT", 10, 0)
        b.label:SetPoint("RIGHT", 0, 0)
        b.label:SetText(label)
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    function b:SetValue(rgb)
        self.value = type(rgb) == "table" and rgb or nil
        if self.value then
            self.col:SetVertexColor(self.value[1], self.value[2], self.value[3], 1)
            self.col:Show(); self.none:Hide()
        else
            self.col:Hide(); self.none:Show()
        end
    end
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if clearable and onChange then onChange(false) end
            return
        end
        openColorPicker(self.value or self.fallback, function(c) if onChange then onChange(c) end end)
    end)
    b:SetScript("OnEnter", function(self) self.box.bd:Set("accent", 1) end)
    b:SetScript("OnLeave", function(self) self.box.bd:Set("border", 1) end)
    return b
end

local copyBox
function W.CopyBox(title, text, note, multiline)
    if not copyBox then
        local f = CreateFrame("Frame", "FojjiCoreCopyBox", UIParent)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        Surface(f, "frame", 0.98, "accent", 0.85)
        Sheen(f, 60, 0.12)
        Addon.EscapeCloses("FojjiCoreCopyBox")
        f.title = T(f, 16, "white")
        f.title:SetPoint("TOPLEFT", 18, -16)
        f.note = T(f, 12, "dim")
        f.note:SetPoint("TOPLEFT", 18, -40)
        f.note:SetPoint("RIGHT", -18, 0)
        f.note:SetWordWrap(true)
        f.field = CreateFrame("Frame", nil, f)
        Surface(f.field, "field", 1, "border", 1)
        f.scroll = CreateFrame("ScrollFrame", nil, f.field)
        f.scroll:SetPoint("TOPLEFT", 8, -6)
        f.scroll:SetPoint("BOTTOMRIGHT", -8, 6)
        f.eb = CreateFrame("EditBox", nil, f.scroll)
        f.eb:SetAutoFocus(false)
        f.eb:SetFont(FONT, 13, "")
        f.eb:SetTextColor(0.95, 0.96, 0.98)
        f.eb:SetWidth(400)
        f.scroll:SetScrollChild(f.eb)
        f.eb:SetScript("OnEscapePressed", function() f:Hide() end)
        f.eb:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(f.value or ""); self:HighlightText() end
        end)
        f.eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        f.eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        f.eb:SetScript("OnKeyUp", function(self, key)
            if (key == "C" or key == "X") and IsControlKeyDown and IsControlKeyDown() then
                f.hint:SetText("Copied!")
                C_Timer.After(0.6, function() if f:IsShown() then f:Hide() end end)
            end
        end)
        f.hint = T(f, 12, "accent")
        f.hint:SetPoint("BOTTOMLEFT", 18, 20)
        f.close = W.Button(f, "Close", 100, 28)
        f.close:SetPoint("BOTTOMRIGHT", -16, 14)
        f.close:SetScript("OnClick", function() f:Hide() end)
        copyBox = f
    end
    local f = copyBox
    multiline = multiline or (text or ""):find("\n") ~= nil
    f.value = text or ""
    f.title:SetText(title or "Copy")
    f.note:SetText(note or "")
    f:SetSize(multiline and 620 or 480, multiline and 460 or 150 + (note and 16 or 0))
    f.field:ClearAllPoints()
    f.field:SetPoint("TOPLEFT", 18, note and -64 or -46)
    f.field:SetPoint("RIGHT", -18, 0)
    f.field:SetPoint("BOTTOM", 0, 56)
    f.eb:SetMultiLine(multiline)
    f.eb:SetMaxLetters(0)
    f.eb:SetWidth(multiline and 570 or 428)
    f.eb:SetHeight(multiline and 380 or 30)
    f.eb:SetTextInsets(4, 4, 0, 0)
    f.eb:SetText(f.value)
    if f.eb.SetCursorPosition then f.eb:SetCursorPosition(0) end
    f.hint:SetText("Press Ctrl+C to copy")
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:Show()
    f:Raise()
    f.eb:SetFocus()
    f.eb:HighlightText()
    repaint()
end

function W.SubTabs(page, items, onSelect, top)
    top = top or -54
    local st = { views = {}, tabs = {}, current = items[1] and items[1][1] }
    local strip = CreateFrame("Frame", nil, page)
    strip:SetPoint("TOPLEFT", 0, top)
    strip:SetPoint("TOPRIGHT", -18, top)
    strip:SetHeight(30)
    local line = solid(strip:CreateTexture(nil, "BACKGROUND"), "borderDim", 1)
    line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    if native() then Addon.Skin.Rule(line) end
    st.strip = strip
    function st:Select(key)
        if not self.views[key] then return end
        self.current = key
        for k, v in pairs(self.views) do v:SetShown(k == key) end
        for _, b in pairs(self.tabs) do b:Paint() end
        if onSelect then onSelect(key) end
    end
    local prev
    for _, it in ipairs(items) do
        local key = it[1]
        local b = CreateFrame("Button", nil, strip)
        b:SetHeight(30)
        b.t = T(b, 13, "dim")
        b.t:SetPoint("LEFT", 4, 0)
        b.t:SetText(it[2])
        b:SetWidth(b.t:GetStringWidth() + 24)
        b.line = solid(b:CreateTexture(nil, "ARTWORK"), "accent", 1)
        b.line:SetHeight(2); b.line:SetPoint("BOTTOMLEFT"); b.line:SetPoint("BOTTOMRIGHT")
        function b:Paint()
            local on = st.current == key
            self.line:SetShown(on)
            self.t:SetTextColor(C(on and "white" or (self.hover and "text" or "dim")))
        end
        b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
        b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
        b:SetScript("OnClick", function() st:Select(key) end)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 10, 0) else b:SetPoint("LEFT", 0, 0) end
        prev = b
        st.tabs[key] = b
        local v = CreateFrame("Frame", nil, page)
        v:SetPoint("TOPLEFT", 0, top + 4)
        v:SetPoint("BOTTOMRIGHT", 0, 0)
        v:Hide()
        st.views[key] = v
    end
    paint(function() for _, b in pairs(st.tabs) do b:Paint() end end)
    return st
end

K.C, K.paint, K.repaint, K.solid, K.setFont, K.T, K.Border, K.Surface, K.Tip, K.Icon = C, paint, repaint, solid, setFont, T, Border, Surface, Tip, Icon
K.Caption, K.openMenu, K.Glyph, K.Sheen = Caption, openMenu, Glyph, Sheen
for name, fn in pairs(W) do K[name] = fn end
