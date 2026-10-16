local _, Addon = ...

local Skin = {}
Addon.Skin = Skin

function Addon.IsNative() return Addon.Native == true end

local BTN = "Interface\\Buttons\\UI-Panel-Button-"
local BTN_COORD = { 0, 0.09375, 0.53125, 0.625, 0.6875 }

function Skin.Button(b)
    if not Addon.Native or b.nativeArt then return false end
    local art = {}
    local function slice(l, r)
        local t = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetTexCoord(l, r, 0, BTN_COORD[5])
        art[#art + 1] = t
        return t
    end
    art.left = slice(BTN_COORD[1], BTN_COORD[2])
    art.left:SetPoint("TOPLEFT")
    art.left:SetPoint("BOTTOMLEFT")
    art.left:SetWidth(12)
    art.right = slice(BTN_COORD[3], BTN_COORD[4])
    art.right:SetPoint("TOPRIGHT")
    art.right:SetPoint("BOTTOMRIGHT")
    art.right:SetWidth(12)
    art.mid = slice(BTN_COORD[2], BTN_COORD[3])
    art.mid:SetPoint("TOPLEFT", art.left, "TOPRIGHT")
    art.mid:SetPoint("BOTTOMRIGHT", art.right, "BOTTOMLEFT")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(BTN .. "Highlight")
    hl:SetTexCoord(0, BTN_COORD[4], 0, BTN_COORD[5])
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    b.nativeArt = art
    function b:NativeState(pushed)
        local file = not self:IsEnabled() and "Disabled" or ((pushed or self.active) and "Down" or "Up")
        for _, t in ipairs(art) do t:SetTexture(BTN .. file) end
    end
    b:HookScript("OnMouseDown", function(self) if self:IsEnabled() then self:NativeState(true) end end)
    b:HookScript("OnMouseUp", function(self) self:NativeState(false) end)
    b:NativeState(false)
    return true
end

local TAB = "Interface\\OptionsFrame\\UI-OptionsFrame-"
function Skin.Tab(b)
    if not Addon.Native or b.nativeArt then return false end
    local art = {}
    local function slice(l, r)
        local t = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetTexCoord(l, r, 0, 1)
        art[#art + 1] = t
        return t
    end
    local left = slice(0, 0.15625)
    left:SetPoint("TOPLEFT", 0, 2)
    left:SetPoint("BOTTOMLEFT", 0, -3)
    left:SetWidth(16)
    local right = slice(0.84375, 1)
    right:SetPoint("TOPRIGHT", 0, 2)
    right:SetPoint("BOTTOMRIGHT", 0, -3)
    right:SetWidth(16)
    local mid = slice(0.15625, 0.84375)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetPoint("TOPLEFT", 6, 2)
    hl:SetPoint("BOTTOMRIGHT", -6, -6)
    b.nativeArt = art
    function b:NativeState()
        local file = TAB .. (self.active and "ActiveTab" or "InActiveTab")
        for _, t in ipairs(art) do t:SetTexture(file) end
        hl:SetShown(not self.active)
    end
    b:NativeState()
    return true
end

function Skin.ButtonText(fs, enabled, hot)
    if not enabled then fs:SetTextColor(0.5, 0.5, 0.5)
    elseif hot then fs:SetTextColor(1, 1, 1)
    else fs:SetTextColor(1, 0.82, 0) end
end

local CHECK = "Interface\\Buttons\\UI-CheckBox-"
function Skin.Check(frame, size)
    if not Addon.Native then return nil end
    local box = CreateFrame("Frame", nil, frame)
    box:SetSize(size or 24, size or 24)
    box.up = box:CreateTexture(nil, "ARTWORK")
    box.up:SetAllPoints()
    box.up:SetTexture(CHECK .. "Up")
    box.tick = box:CreateTexture(nil, "OVERLAY")
    box.tick:SetAllPoints()
    box.tick:SetTexture(CHECK .. "Check")
    box.hl = box:CreateTexture(nil, "HIGHLIGHT")
    box.hl:SetAllPoints()
    box.hl:SetTexture(CHECK .. "Highlight")
    box.hl:SetBlendMode("ADD")
    box.hl:Hide()
    function box:Set(on, hot, enabled)
        self.tick:SetShown(on and true or false)
        self.tick:SetTexture(CHECK .. ((enabled == false) and "Check-Disabled" or "Check"))
        self.hl:SetShown(hot and true or false)
    end
    return box
end

local LABEL = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"
function Skin.Dropdown(b)
    if not Addon.Native or b.nativeArt then return false end
    local function piece(l, r)
        local t = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetTexture(LABEL)
        t:SetTexCoord(l, r, 0, 1)
        t:SetHeight(64)
        return t
    end
    local left = piece(0, 0.1953125)
    left:SetWidth(25)
    left:SetPoint("LEFT", -16, -2)
    local right = piece(0.8046875, 1)
    right:SetWidth(25)
    right:SetPoint("RIGHT", 16, -2)
    local mid = piece(0.1953125, 0.8046875)
    mid:SetPoint("LEFT", left, "RIGHT")
    mid:SetPoint("RIGHT", right, "LEFT")
    local arrow = b:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(24, 24)
    arrow:SetPoint("RIGHT", 0, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(arrow)
    b:HookScript("OnMouseDown", function() arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down") end)
    b:HookScript("OnMouseUp", function() arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up") end)
    b.nativeArt = { left, mid, right }
    b.nativeDropdown = arrow
    function b:NativeState() end
    return true
end

local function redButton(b, name, fallback)
    if not Addon.Native then return false end
    local atlas = b.SetNormalAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("RedButton-" .. name)
    if atlas then
        b:SetNormalAtlas("RedButton-" .. name)
        b:SetPushedAtlas(name == "Exit" and "RedButton-exit-pressed" or ("RedButton-" .. name .. "-pressed"))
        b:SetHighlightAtlas("RedButton-Highlight", "ADD")
    else
        b:SetNormalTexture(fallback .. "Up")
        b:SetPushedTexture(fallback .. "Down")
        b:SetHighlightTexture(fallback .. "Highlight", "ADD")
    end
    return true
end
function Skin.CloseButton(b) return redButton(b, "Exit", "Interface\\Buttons\\UI-Panel-MinimizeButton-") end
function Skin.MinimizeButton(b) return redButton(b, "MiniCondense", "Interface\\Buttons\\UI-Panel-SmallerButton-") end

local ARROWS = {
    ["fc:icon-chevron-down"] = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-",
    ["fc:icon-chevron-up"] = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-",
    ["fc:icon-chevron-left"] = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-",
    ["fc:icon-chevron-right"] = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-",
}
function Skin.ArrowButton(b, icon)
    if not Addon.Native or not ARROWS[icon] then return false end
    function b:NativeArrow(path)
        local base = ARROWS[path] or ARROWS["fc:icon-chevron-down"]
        self:SetNormalTexture(base .. "Up")
        self:SetPushedTexture(base .. "Down")
        self:SetDisabledTexture(base .. "Disabled")
        self:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    end
    b.nativeArrow = true
    b:NativeArrow(icon)
    return true
end

local INPUT = "Interface\\Common\\Common-Input-Border"
function Skin.Input(e)
    if not Addon.Native or e.nativeArt then return false end
    local function piece(l, r)
        local t = e:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetTexture(INPUT)
        t:SetTexCoord(l, r, 0, 0.625)
        return t
    end
    local left = piece(0, 0.0625)
    left:SetPoint("TOPLEFT", -2, 0)
    left:SetPoint("BOTTOMLEFT", -2, 0)
    left:SetWidth(8)
    local right = piece(0.9375, 1)
    right:SetPoint("TOPRIGHT", 2, 0)
    right:SetPoint("BOTTOMRIGHT", 2, 0)
    right:SetWidth(8)
    local mid = piece(0.0625, 0.9375)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    e.nativeArt = { left, mid, right }
    return true
end

function Skin.Strip(f)
    if f.edges then for _, t in ipairs(f.edges) do t:Hide() t:SetAlpha(0) end end
    if f.bd then for i = 1, 4 do if f.bd[i] then f.bd[i]:Hide() end end end
end

local RULE = { 1.00, 0.82, 0.22 }
function Skin.Rule(line, peak)
    if not Addon.Native or not line or line.nativeRule or not (CreateColor and line.SetGradient) then return false end
    local layer, sub = line:GetDrawLayer()
    local parent = line:GetParent()
    local function half(fromA, toA)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetColorTexture(1, 1, 1, 1)
        t:SetHeight(1)
        pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(RULE[1], RULE[2], RULE[3], fromA), CreateColor(RULE[1], RULE[2], RULE[3], toA))
        return t
    end
    peak = peak or 0.8
    local l, r = half(0, peak), half(peak, 0)
    l:SetPoint("LEFT", line, "LEFT")
    l:SetPoint("RIGHT", line, "CENTER")
    r:SetPoint("LEFT", line, "CENTER")
    r:SetPoint("RIGHT", line, "RIGHT")
    line:SetAlpha(0)
    line.nativeRule = { l, r }
    local function follow(on) l:SetShown(on) r:SetShown(on) end
    hooksecurefunc(line, "Show", function() follow(true) end)
    hooksecurefunc(line, "Hide", function() follow(false) end)
    hooksecurefunc(line, "SetShown", function(_, on) follow(on and true or false) end)
    follow(line:IsShown())
    return true
end

local TOOLTIP_EDGE = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 }
local DIALOG_EDGE = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32 }

local function edgeOver(f, backdrop, out)
    local c = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    c:SetPoint("TOPLEFT", -out, out)
    c:SetPoint("BOTTOMRIGHT", out, -out)
    c:SetFrameLevel(math.min(f:GetFrameLevel() + 30, 9000))
    c:EnableMouse(false)
    if c.SetBackdrop then
        c:SetBackdrop(backdrop)
        c:SetBackdropBorderColor(1, 1, 1, 1)
    end
    return c
end

function Skin.Panel(f)
    if not Addon.Native or f.nativeChrome then return false end
    f.nativeChrome = edgeOver(f, TOOLTIP_EDGE, 3)
    Skin.Strip(f)
    return true
end

function Skin.Dialog(f)
    if not Addon.Native or f.nativeChrome then return false end
    f.nativeChrome = edgeOver(f, DIALOG_EDGE, 6)
    Skin.Strip(f)
    return true
end

function Skin.Window(f, title, onClose)
    if not Addon.Native or f.nativeChrome then return false end
    local ok, c = pcall(CreateFrame, "Frame", nil, f, "ButtonFrameTemplate")
    if not (ok and c) then return Skin.Dialog(f) end
    c:SetPoint("TOPLEFT", -6, 24)
    c:SetPoint("BOTTOMRIGHT", 6, -6)
    c:SetFrameLevel(math.min(f:GetFrameLevel() + 30, 9000))
    c:EnableMouse(false)
    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, c) end
    if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, c) end
    for _, key in ipairs({ "Inset", "Bg" }) do if type(c[key]) == "table" and c[key].Hide then c[key]:Hide() end end
    if c.SetTitle then pcall(c.SetTitle, c, title or "")
    elseif type(c.TitleText) == "table" then c.TitleText:SetText(title or "") end
    if type(c.CloseButton) == "table" then
        c.CloseButton:SetScript("OnClick", function() if onClose then onClose() else f:Hide() end end)
    end
    local grab = CreateFrame("Frame", nil, c)
    grab:SetPoint("TOPLEFT", 6, 0)
    grab:SetPoint("TOPRIGHT", -28, 0)
    grab:SetHeight(24)
    grab:EnableMouse(true)
    grab:RegisterForDrag("LeftButton")
    grab:SetScript("OnDragStart", function() local s = f:GetScript("OnDragStart") if s then s(f) end end)
    grab:SetScript("OnDragStop", function() local s = f:GetScript("OnDragStop") if s then s(f) end end)
    f.nativeChrome = c
    Skin.Strip(f)
    return true
end

function Skin.SetTitle(f, title)
    local c = f and f.nativeChrome
    if not c then return end
    if c.SetTitle then pcall(c.SetTitle, c, title or "") elseif type(c.TitleText) == "table" then c.TitleText:SetText(title or "") end
end
