-- Addon.OptionsMenu.Open(owner, entries, opts), Close(), IsOpen(owner), Refresh()
-- Entries: text, checked, disabled, tag, onClick, onRemove, onFavorite, favorite
-- Options: width, maxRows, openUp

local _, Addon = ...
local Menu = {}
Addon.OptionsMenu = Menu

local FONT = "Interface\\AddOns\\FojjiCore\\font\\Numen.ttf"
local ROW_H, PAD, DEFAULT_ROWS = 22, 3, 10

local function Color(name, alpha)
    local r, g, b = 0.6, 0.6, 0.6
    if Addon.GetColor then r, g, b = Addon.GetColor(name) end
    return r, g, b, alpha or 1
end

local function SetFont(fontString, size)
    if fontString:SetFont(FONT, size, "") == false then fontString:SetFont(STANDARD_TEXT_FONT, size, "") end
end

local popup, catcher, track, thumb
local edges = {}
local rows = {}
local current

local function Render() end

function Menu.IsOpen(owner) return current ~= nil and (owner == nil or current.owner == owner) end

function Menu.Close()
    if popup and popup:IsShown() then popup:Hide() end
    if catcher then catcher:Hide() end
    current = nil
end

local function Scroll(delta)
    if not current then return end
    current.offset = current.offset - delta
    Render()
end

local function GetRow(index)
    local row = rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, popup)
    row:SetHeight(ROW_H)
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetWidth(2)
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.label = row:CreateFontString(nil, "OVERLAY")
    SetFont(row.label, 11)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetPoint("LEFT", 9, 0)
    row.tag = row:CreateFontString(nil, "OVERLAY")
    SetFont(row.tag, 9)
    row.remove = CreateFrame("Button", nil, row)
    row.remove:SetSize(ROW_H, ROW_H)
    row.remove:SetPoint("RIGHT")
    row.remove:SetFrameLevel(row:GetFrameLevel() + 3)
    row.remove.x = row.remove:CreateFontString(nil, "OVERLAY")
    SetFont(row.remove.x, 12)
    row.remove.x:SetPoint("CENTER", 0, 1)
    row.remove.x:SetText("x")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    row:SetScript("OnEnter", function(self)
        if self.entry and not self.entry.disabled and not self.entry.header then
            local r, g, b = Color("accent")
            self.hover:SetColorTexture(r, g, b, 0.16)
            self.hover:Show()
        end
    end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self)
        local entry = self.entry
        if not entry or entry.disabled or entry.header then return end
        if entry.keepOpen then
            if entry.onClick then entry.onClick(entry) end
            Menu.Refresh()
        else
            Menu.Close()
            if entry.onClick then entry.onClick(entry) end
        end
    end)
    row.remove:SetScript("OnEnter", function(self)
        local r, g, b = Color("warning")
        self.x:SetTextColor(r, g, b)
    end)
    row.remove:SetScript("OnLeave", function(self)
        local r, g, b = Color(row.entry and row.entry.favorite and "accent" or "dim")
        self.x:SetTextColor(r, g, b)
    end)
    row.remove:SetScript("OnClick", function()
        local entry = row.entry
        if not entry or entry.disabled or entry.header then return end
        if entry.onFavorite then
            entry.favorite = not entry.favorite
            entry.onFavorite(entry.favorite)
            Render()
        elseif entry.onRemove then
            entry.onRemove(entry)
            Menu.Refresh()
        end
    end)
    rows[index] = row
    return row
end

function Render()
    if not current or not popup then return end
    local entries = current.entries
    local count = #entries
    local visible = math.min(count, current.maxRows)
    current.offset = math.max(0, math.min(current.offset, math.max(0, count - visible)))
    local scrolling = count > visible
    local width = current.width
    local inner = width - 2 - (scrolling and 7 or 0)

    popup:SetSize(width, visible * ROW_H + PAD * 2)
    local bgR, bgG, bgB = Color("header")
    popup.bg:SetColorTexture(bgR, bgG, bgB, 0.98)
    local bR, bG, bB = Color("accent", 0.7)
    for _, edge in ipairs(edges) do edge:SetColorTexture(bR, bG, bB, 0.7) end

    for index = 1, visible do
        local entry = entries[current.offset + index]
        local row = GetRow(index)
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 1, -(PAD + (index - 1) * ROW_H))
        row:SetWidth(inner)
        row:SetHeight(ROW_H)
        row.hover:Hide()
        local textColor = entry.color or (entry.disabled and { Color("dim") }) or (entry.header and { Color("accent") }) or { Color("text") }
        row.label:SetText(entry.text or "")
        row.label:SetTextColor(textColor[1], textColor[2], textColor[3])
        if entry.tag then
            row.tag:SetText(entry.tag)
            row.tag:SetTextColor(Color("dim"))
            row.tag:ClearAllPoints()
            row.tag:SetPoint("RIGHT", row, "RIGHT", (entry.onFavorite and -46) or (entry.onRemove and -(ROW_H + 2)) or -8, 0)
            row.tag:Show()
        else
            row.tag:SetText("")
            row.tag:Hide()
        end
        local reserve = 10 + (entry.onFavorite and 44 or (entry.onRemove and ROW_H or 0)) + (entry.tag and ((row.tag:GetStringWidth() or 30) + 8) or 0)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -reserve, 0)
        if entry.checked then
            local r, g, b = Color("accent")
            row.mark:SetColorTexture(r, g, b, 1)
            row.mark:Show()
        else
            row.mark:Hide()
        end
        row.remove:SetWidth(entry.onFavorite and 40 or ROW_H)
        row.remove.x:SetText(entry.onFavorite and "FAV" or "x")
        row.remove:SetShown(entry.onRemove ~= nil or entry.onFavorite ~= nil)
        row.remove.x:SetTextColor(Color(entry.favorite and "accent" or "dim"))
        row:Show()
    end
    for index = visible + 1, #rows do rows[index]:Hide(); rows[index].entry = nil end

    track:SetShown(scrolling)
    thumb:SetShown(scrolling)
    if scrolling then
        local trackHeight = visible * ROW_H
        local size = math.max(14, trackHeight * visible / count)
        local room = trackHeight - size
        local fraction = current.offset / math.max(1, count - visible)
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -(PAD + room * fraction))
        local r, g, b = Color("accent")
        thumb:SetColorTexture(r, g, b, 0.75)
        local tr, tg, tb = Color("scroll")
        track:SetColorTexture(tr, tg, tb, 0.9)
    end
end

local function Build()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(900)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() Menu.Close() end)
    catcher:Hide()

    popup = CreateFrame("Frame", "FojjiCoreSRMenu", UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(910)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    popup.bg = popup:CreateTexture(nil, "BACKGROUND")
    popup.bg:SetAllPoints()
    for _, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = popup:CreateTexture(nil, "BORDER")
        edge:SetPoint(spec[1]); edge:SetPoint(spec[2])
        if spec[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[#edges + 1] = edge
    end
    track = popup:CreateTexture(nil, "ARTWORK")
    track:SetWidth(3)
    track:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -PAD)
    track:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -2, PAD)
    thumb = popup:CreateTexture(nil, "OVERLAY")
    thumb:SetWidth(3)
    popup:SetScript("OnHide", function() if catcher then catcher:Hide() end; current = nil end)
    popup:SetScript("OnUpdate", function()
        if current and current.owner and not current.owner:IsVisible() then Menu.Close() end
    end)
    popup:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "FojjiCoreSRMenu") end
end

local function Resolve(entriesOrFn)
    local list = type(entriesOrFn) == "function" and entriesOrFn() or entriesOrFn
    return list or {}
end

function Menu.Refresh()
    if not current then return end
    current.entries = Resolve(current.source)
    if #current.entries == 0 then Menu.Close(); return end
    Render()
end

function Menu.Open(owner, entries, opts)
    if not popup then Build() end
    if current and current.owner == owner then Menu.Close(); return end
    Menu.Close()
    opts = opts or {}
    local list = Resolve(entries)
    if #list == 0 then return end
    local width = opts.width or (owner.GetWidth and owner:GetWidth()) or 180
    current = { owner = owner, source = entries, entries = list, width = math.max(140, width), maxRows = opts.maxRows or DEFAULT_ROWS, offset = 0 }
    for index, entry in ipairs(list) do
        if entry.checked then current.offset = math.max(0, index - math.floor(current.maxRows / 2)); break end
    end
    local ownerScale = owner.GetEffectiveScale and owner:GetEffectiveScale() or 1
    popup:SetScale(ownerScale / (UIParent:GetEffectiveScale() or 1))
    popup:ClearAllPoints()
    local height = math.min(#list, current.maxRows) * ROW_H + PAD * 2
    local bottom = owner.GetBottom and owner:GetBottom()
    if opts.openUp or (bottom and bottom * ownerScale < height * ownerScale + 20) then
        popup:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
    else
        popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    end
    Render()
    catcher:Show()
    popup:Show()
end

function Menu.Button(UI, parent, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 200, height or 24)
    UI.Panel(button)
    button.hover = UI.Texture(button, "ARTWORK", "accent", 0.08)
    button.hover:SetAllPoints()
    button.hover:Hide()
    button.text = UI.Text(button, "", 11, "text")
    button.text:SetPoint("LEFT", 8, 0)
    button.text:SetPoint("RIGHT", -20, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    button.arrow = UI.Text(button, "v", 10, "dim")
    button.arrow:SetPoint("RIGHT", -8, 1)
    button:SetScript("OnEnter", function(self) self.hover:Show() end)
    button:SetScript("OnLeave", function(self) self.hover:Hide() end)
    function button:SetLabel(text) self.text:SetText(text or "") end
    return button
end
