local Addon = FojjiCoreNS
if not Addon then return end
local SR = FojjiCore.Speedrun
local SharedMedia = LibStub("LibSharedMedia-3.0")

local UI = {}
Addon.SRUI = UI

local TEX = "Interface\\AddOns\\FojjiCore\\textures\\Speedrun\\"
local BASE_FONT = "Interface\\AddOns\\FojjiCore\\font\\Numen.ttf"
local WIDE = Addon.WideFont
local STATUS_H, FOOT_H = 14, 14

UI.ACCENTS = {
    blue = { 0.40, 0.70, 1.00 }, red = { 1.00, 0.30, 0.26 }, jade = { 0.20, 0.88, 0.66 },
    violet = { 0.70, 0.48, 1.00 }, gold = { 1.00, 0.82, 0.26 }, white = { 0.90, 0.92, 0.96 },
}
UI.PALETTES = {
    classic = { good = { 0.30, 0.92, 0.46 }, bad = { 1.00, 0.36, 0.32 } },
    cool = { good = { 0.40, 0.75, 1.00 }, bad = { 1.00, 0.62, 0.20 } },
    mono = { good = { 0.95, 0.95, 0.98 }, bad = { 0.58, 0.60, 0.65 } },
}
local C = {
    bg = { 0.030, 0.035, 0.045 }, header = { 0.045, 0.052, 0.068 }, row = { 0.065, 0.075, 0.095 },
    text = { 0.90, 0.92, 0.95 }, dim = { 0.50, 0.54, 0.60 }, gold = { 1.00, 0.82, 0.26 },
}

function UI.Accent(db)
    db = db or SR:GetStore()
    local preset = UI.ACCENTS[db.accent]
    if preset then return preset[1], preset[2], preset[3] end
    if Addon.GetAccent then return Addon.GetAccent() end
    return 0.40, 0.70, 1.00
end

function UI.EngagedColor(db)
    db = db or SR:GetStore()
    local preset = UI.ACCENTS[db.engagedColor]
    if preset then return preset[1], preset[2], preset[3] end
    return UI.Accent(db)
end
local function Palette(db)
    return UI.PALETTES[db.colors] or UI.PALETTES.classic
end

local function FontPath(name)
    if WIDE then return STANDARD_TEXT_FONT end
    return (name and SharedMedia:Fetch("font", name, true)) or BASE_FONT
end

local function SetFont(fontString, path, size, flags)
    if fontString:SetFont(path, size, flags or "") == false then fontString:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
end

local Tip = {}

local function Tex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end
local function BuildTip()
    local t = CreateFrame("Frame", "FojjiSpeedrunTooltip", UIParent)
    t:SetFrameStrata("TOOLTIP")
    t:SetClampedToScreen(true)
    t.bg = Tex(t, "BACKGROUND", C.header[1], C.header[2], C.header[3], 0.97)
    t.bg:SetAllPoints()
    t.edges = {}
    for _, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = Tex(t, "BORDER", 1, 1, 1, 0.5)
        edge:SetPoint(spec[1]); edge:SetPoint(spec[2])
        if spec[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        t.edges[#t.edges + 1] = edge
    end
    t.title = Addon.Localize(t:CreateFontString(nil, "OVERLAY"))
    t.title:SetPoint("TOPLEFT", 10, -8)
    t.lines = {}
    t:Hide()
    Tip.frame = t
end
local function TipLine(index)
    local t = Tip.frame
    local line = t.lines[index]
    if line then return line end
    line = { left = Addon.Localize(t:CreateFontString(nil, "OVERLAY")), right = Addon.Localize(t:CreateFontString(nil, "OVERLAY")) }
    line.left:SetPoint("TOPLEFT", 10, -(24 + (index - 1) * 15))
    line.right:SetPoint("TOPRIGHT", -10, -(24 + (index - 1) * 15))
    t.lines[index] = line
    return line
end

function Tip.Show(owner, title, entries, anchor)
    if not Tip.frame then BuildTip() end
    local t = Tip.frame
    local db = SR:GetStore()
    local path = FontPath(db.font)
    local ar, ag, ab = UI.Accent(db)
    for _, edge in ipairs(t.edges) do edge:SetColorTexture(ar, ag, ab, 0.6) end
    SetFont(t.title, path, 12, "OUTLINE")
    t.title:SetTextColor(ar, ag, ab)
    t.title:SetText(title or "")
    local width = math.max(120, (t.title:GetStringWidth() or 100) + 20)
    local count = entries and #entries or 0
    for index = 1, count do
        local entry = entries[index]
        local line = TipLine(index)
        if type(entry) == "table" then
            SetFont(line.left, path, 11, ""); SetFont(line.right, path, 11, "")
            line.left:ClearAllPoints()
            line.left:SetPoint("TOPLEFT", 10, -(24 + (index - 1) * 15))
            line.left:SetText(entry[1] or "")
            line.left:SetTextColor(0.6, 0.64, 0.7)
            line.right:SetText(entry[2] or "")
            local c = { entry[3] or 0.9, entry[4] or 0.92, entry[5] or 0.96 }
            line.right:SetTextColor(c[1], c[2], c[3])
            width = math.max(width, (line.left:GetStringWidth() or 0) + (line.right:GetStringWidth() or 0) + 40)
        else
            SetFont(line.left, path, 11, ""); SetFont(line.right, path, 11, "")
            line.left:ClearAllPoints()
            line.left:SetPoint("TOPLEFT", 10, -(24 + (index - 1) * 15))
            line.left:SetText(tostring(entry))
            line.left:SetTextColor(0.85, 0.87, 0.92)
            line.right:SetText("")
            width = math.max(width, (line.left:GetStringWidth() or 0) + 20)
        end
        line.left:Show(); line.right:Show()
    end
    for index = count + 1, #t.lines do t.lines[index].left:Hide(); t.lines[index].right:Hide() end
    t:SetSize(width, 24 + count * 15 + 8)
    t:ClearAllPoints()
    t:SetPoint(anchor or "BOTTOM", owner, "TOP", 0, 6)
    t:Show()
end
function Tip.Hide() if Tip.frame then Tip.frame:Hide() end end

local frame, rows = nil, {}
local accentTextures = {}
local confirmReset = false
local scrollOffset = 0
local engagedRow, appliedScale, appliedGrow

local function AccentTex(parent, layer, alpha)
    local t = Tex(parent, layer, 1, 1, 1, alpha)
    accentTextures[#accentTextures + 1] = { tex = t, alpha = alpha or 1 }
    return t
end

local function GlyphButton(parent, glyph)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(13, 13)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(TEX .. glyph)
    b.rest = { 0.70, 0.74, 0.80 }
    b.icon:SetVertexColor(0.70, 0.74, 0.80)

    b:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(UI.Accent())
        if self.tipText then Tip.Show(self, self.tipText, nil, "BOTTOM") end
    end)
    b:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(self.rest[1], self.rest[2], self.rest[3])
        Tip.Hide()
    end)
    return b
end

local DEF_RIGHT, DEF_TOP = 0.03, 0.48

local function SavePosition()
    local db = SR:GetStore()
    local left = frame:GetLeft()
    local edge = db.growUp and frame:GetBottom() or frame:GetTop()
    if not left or not edge then return end
    local ps, fs = UIParent:GetEffectiveScale() or 1, frame:GetEffectiveScale() or 1
    db.pos = { x = left * fs / ps, y = edge * fs / ps, anchor = db.growUp and "BOTTOMLEFT" or "TOPLEFT" }
end

local function ApplyPosition()
    local db = SR:GetStore()
    local ps, fs = UIParent:GetEffectiveScale() or 1, frame:GetEffectiveScale() or 1
    frame:ClearAllPoints()
    local pos = db.pos
    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        local anchor = db.growUp and "BOTTOMLEFT" or "TOPLEFT"
        frame:SetPoint(anchor, UIParent, "BOTTOMLEFT", pos.x * ps / fs, pos.y * ps / fs)
    else
        local w, h = UIParent:GetWidth() or 1000, UIParent:GetHeight() or 700
        local k = ps / fs
        if db.growUp then
            frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -w * DEF_RIGHT * k, h * (1 - DEF_TOP) * k - 40)
        else
            frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -w * DEF_RIGHT * k, -h * DEF_TOP * k)
        end
    end
end
function UI.Spot()
    local db = SR:GetStore()
    local ps = UIParent:GetEffectiveScale() or 1
    if frame and frame:IsShown() and frame:GetLeft() and frame:GetTop() then
        local k = (frame:GetEffectiveScale() or 1) / ps
        return frame:GetLeft() * k, frame:GetTop() * k, frame:GetWidth() * k, frame
    end
    local sc = db.scale or 1
    local w = (db.width or 240) * sc
    local pos = db.pos
    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        local top = pos.y
        if db.growUp then top = top + ((frame and frame:GetHeight()) or 40) * sc end
        return pos.x, top, w
    end
    local W, H = UIParent:GetWidth() or 1000, UIParent:GetHeight() or 700
    return W - W * DEF_RIGHT - w, H - H * DEF_TOP, w
end

function UI.SetSpot(left, top)
    local db = SR:GetStore()
    if db.locked then return end
    local y = top
    if db.growUp then y = top - ((frame and frame:GetHeight()) or 40) * (db.scale or 1) end
    db.pos = { x = left, y = y, anchor = db.growUp and "BOTTOMLEFT" or "TOPLEFT" }
    if frame and frame:IsShown() then ApplyPosition() end
end

function UI.DragStart()
    if frame and frame:IsShown() and not SR:GetStore().locked then frame:StartMoving(); return true end
end
function UI.DragStop()
    if not frame then return end
    frame:StopMovingOrSizing(); SavePosition(); ApplyPosition()
end

function UI.ResetPosition()
    if not frame then return end
    SR:GetStore().pos = nil
    ApplyPosition()
end

local function ShowTooltip(row)
    local info = row.info
    if not info then return end
    local entries = {}
    if info.killed then
        entries[#entries + 1] = { "Killed", SR.FormatTime(info.time, 1) }
        if info.pull then entries[#entries + 1] = { "Pulled", SR.FormatTime(info.pull, 1) } end
        if info.fight then entries[#entries + 1] = { "Fight length", SR.FormatTime(info.fight, 1) } end
        if info.delta then
            local pal = Palette(SR:GetStore())
            local c = info.delta <= 0 and pal.good or pal.bad
            entries[#entries + 1] = { "Versus comparison", SR.FormatDelta(info.delta, 1), c[1], c[2], c[3] }
        end
    elseif info.engaged then
        entries[#entries + 1] = ("Pull %d, %s in"):format(info.attempt or 1, SR.FormatTime(info.fightTime, 0))
    else
        entries[#entries + 1] = "Not killed yet"
    end
    if info.attempts and info.attempts > 0 then entries[#entries + 1] = { "Pulls", tostring(info.attempts) } end
    if info.refTime then entries[#entries + 1] = { "Comparison kill", SR.FormatTime(info.refTime, 1), 0.7, 0.72, 0.76 } end
    if info.refPull then entries[#entries + 1] = { "Comparison pull", SR.FormatTime(info.refPull, 1), 0.7, 0.72, 0.76 } end
    Tip.Show(row, info.name, entries, "RIGHT")
end

local function Wheel(delta)
    scrollOffset = scrollOffset - delta
    UI.Update()
end

local function GetRow(index)
    local row = rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, frame.body)
    row:EnableMouse(true)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() Tip.Hide() end)
    row.bg = Tex(row, "BACKGROUND", C.row[1], C.row[2], C.row[3], 0.85)
    row.bg:SetAllPoints()
    row.stripe = Tex(row, "ARTWORK", 1, 1, 1, 1)
    row.stripe:SetPoint("TOPLEFT"); row.stripe:SetPoint("BOTTOMLEFT"); row.stripe:SetWidth(2)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.delta = row:CreateFontString(nil, "OVERLAY")
    row.delta:SetPoint("RIGHT", -5, 0)
    row.delta:SetJustifyH("RIGHT")
    row.time = row:CreateFontString(nil, "OVERLAY")
    row.time:SetJustifyH("RIGHT")
    row.att = row:CreateFontString(nil, "OVERLAY")
    row.att:SetJustifyH("RIGHT")
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    rows[index] = row
    return row
end

local function StyleRow(row, db, rowHeight)
    local path = FontPath(db.font)
    local size = db.textSize
    SetFont(row.name, path, size); SetFont(row.time, path, size); SetFont(row.delta, path, size); SetFont(row.att, path, size - 1)
    local icon = math.max(8, rowHeight - 4)
    row.icon:SetSize(icon, icon)
    row.icon:SetShown(db.icons)
    local charW = size * 0.62
    row.delta:SetWidth(db.deltas and math.floor(charW * 5.4) or 1)
    row.delta:SetShown(db.deltas)
    row.time:SetWidth(math.floor(charW * 5.2))
    row.time:ClearAllPoints()
    if db.deltas then row.time:SetPoint("RIGHT", row.delta, "LEFT", -3, 0) else row.time:SetPoint("RIGHT", -5, 0) end
    row.att:ClearAllPoints()
    row.att:SetPoint("RIGHT", row.time, "LEFT", -3, 0)
    row.att:SetWidth(math.floor(charW * 2.6))
    row.name:ClearAllPoints()
    if db.icons then row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0) else row.name:SetPoint("LEFT", 8, 0) end
    row.name:SetPoint("RIGHT", row.att, "LEFT", -2, 0)
end

local function Set(fontString, color, text)
    fontString:SetTextColor(color[1], color[2], color[3])
    fontString:SetText(text)
end

local function Stack(element, db, offset, height, inset)
    element:ClearAllPoints()
    if db.growUp then
        element:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, offset)
        element:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, offset)
    else
        element:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -offset)
        element:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -offset)
    end
    element:SetHeight(height)
end

local function LastDelta()
    local run = SR.run
    if not run then return end
    local last
    for _, id in ipairs(run.order) do last = id end
    return last and SR:GetDelta(last)
end

function UI.GetEngagedRow() return engagedRow end

function UI.UpdateLive()
    if not frame or not frame:IsShown() then return end
    local still = (SR.state == "idle" or SR.state == "stopped" or SR.state == "finished") and not SR.engaged
    if still and frame.drawnStill == SR.state then return end
    frame.drawnStill = still and SR.state or nil
    local db = SR:GetStore()
    local pal = Palette(db)
    local color = C.text
    if SR.state == "idle" or SR.state == "stopped" then color = C.dim
    elseif SR.state == "finished" then color = SR.run and SR.run.isPB and C.gold or pal.good
    else
        local d = LastDelta()
        if d then color = d <= 0 and pal.good or pal.bad end
    end
    Set(frame.timer, color, SR.FormatTime(SR:GetElapsed(), db.decimals))

    local engaged = SR.engaged
    if engagedRow and engaged then
        engagedRow.time:SetText(SR.FormatTime(GetTime() - engaged.startTime, 0))
    end
end

function UI.Update()
    if not frame then return end
    frame.drawnStill = nil
    local db = SR:GetStore()
    local show = SR:ShouldShow()
    frame:SetShown(show)
    if not show then return end
    local ar, ag, ab = UI.Accent(db)
    local pal = Palette(db)

    if appliedScale ~= db.scale or appliedGrow ~= db.growUp then
        if appliedScale ~= nil then
            local growWas = appliedGrow
            local growNow = db.growUp
            db.growUp = growWas
            SavePosition()
            db.growUp = growNow
        end
        appliedScale, appliedGrow = db.scale, db.growUp
        frame:SetScale(db.scale)
        ApplyPosition()
    end
    frame:SetAlpha(db.alpha)
    frame:SetWidth(db.width)
    frame.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], db.bgAlpha)
    for _, edge in ipairs(frame.edges) do edge:SetShown(db.border and not frame.nativeChrome) end
    for _, entry in ipairs(accentTextures) do entry.tex:SetColorTexture(ar, ag, ab, entry.alpha) end

    local textPath = FontPath(db.font)
    local barHeight = math.max(22, db.timerSize + 8)
    SetFont(frame.timer, FontPath(db.timerFont), db.timerSize, "OUTLINE")
    local headerSize = db.headerSize or db.textSize
    SetFont(frame.status, textPath, headerSize, "")
    SetFont(frame.statusRight, textPath, headerSize, "")
    SetFont(frame.foot, textPath, db.textSize - 1, "")
    SetFont(frame.footRight, textPath, db.textSize - 1, "")

    local snap = SR:GetSnapshot()
    local state = SR.state
    local engaged = SR.engaged

    local button = math.min(18, barHeight - 4)
    for _, b in ipairs({ frame.bStart, frame.bReset, frame.bList, frame.bGear, frame.bClose }) do
        b:SetSize(button, button)
        b:SetShown(db.buttons)
    end
    local running = state == "running"
    frame.bStart.icon:SetTexture(TEX .. (running and "stop" or "play"))
    frame.bStart.tipText = running and "Stop run" or (state == "idle" and "Start run" or "Start a new run")
    local done = state == "finished" or state == "stopped"
    frame.bReset.rest = confirmReset and { pal.bad[1], pal.bad[2], pal.bad[3] } or { 0.70, 0.74, 0.80 }
    frame.bReset.icon:SetVertexColor(frame.bReset.rest[1], frame.bReset.rest[2], frame.bReset.rest[3])
    frame.bReset.tipText = confirmReset and "Click again to reset" or "Reset run"
    frame.bDone:SetSize(button, button)
    frame.bDone:SetShown(db.buttons and done)
    frame.bDone.rest = { pal.good[1], pal.good[2], pal.good[3] }
    frame.bDone.icon:SetVertexColor(pal.good[1], pal.good[2], pal.good[3])
    frame.bClose.tipText = done and "End run and hide" or "Hide"
    frame.bList.icon:SetTexCoord(0, 1, db.collapsed and 0 or 1, db.collapsed and 1 or 0)
    frame.bList.tipText = db.collapsed and "Show bosses" or "Hide bosses"
    frame.bGear.tipText = "Settings"
    frame.timer:ClearAllPoints()
    if db.buttons then frame.timer:SetPoint("LEFT", frame.bReset, "RIGHT", 7, 0) else frame.timer:SetPoint("LEFT", frame.bar, "LEFT", 8, 0) end

    if db.statusLine then
        if engaged then
            Set(frame.status, { ar, ag, ab }, ("%s  -  pull %d"):format(engaged.name, engaged.attempt or 1))
            local ref = SR:GetActiveReference()
            local refPull = ref and ref.pulls and ref.pulls[engaged.id]
            local pullDelta = refPull and engaged.pull and (engaged.pull - refPull)
            if pullDelta then Set(frame.statusRight, pullDelta <= 0 and pal.good or pal.bad, SR.FormatDelta(pullDelta, db.decimals))
            else Set(frame.statusRight, C.dim, "") end
        elseif state == "idle" then
            local hints = { manual = "press play", instance = "starts on entry", combat = "starts on combat", pull = "starts on pull", boss = "starts on boss" }
            Set(frame.status, C.dim, snap.name and ("Ready - " .. (hints[db.startMode] or "")) or "No raid detected")
            Set(frame.statusRight, C.dim, snap.refFinal and SR.FormatTime(snap.refFinal, 0) or "")
        elseif state == "running" then
            Set(frame.status, C.dim, snap.name or "")
            local d = LastDelta()
            if d then Set(frame.statusRight, d <= 0 and pal.good or pal.bad, SR.FormatDelta(d, db.decimals)) else Set(frame.statusRight, C.dim, "") end
        elseif state == "finished" then
            Set(frame.status, snap.isPB and C.gold or pal.good, (snap.isPB and "Finished - new best!" or "Finished") .. (db.buttons and "  |cff8a8f98(tick to close)|r" or ""))
            local d = snap.refFinal and (SR:GetElapsed() - snap.refFinal)
            if d and not snap.isPB then Set(frame.statusRight, d <= 0 and pal.good or pal.bad, SR.FormatDelta(d, db.decimals)) else Set(frame.statusRight, C.dim, "") end
        else
            Set(frame.status, C.dim, "Stopped"); Set(frame.statusRight, C.dim, "")
        end
    end

    local list = SR:GetRows(db.order, db.showUnkilled)
    local total = #list
    local maxRows = db.maxRows > 0 and db.maxRows or total
    local visible = math.min(total, maxRows)
    local showList = not db.collapsed and total > 0

    local engagedIndex, followIndex
    for index, row in ipairs(list) do
        if row.engaged then engagedIndex = index end
        if UI.followBoss and row.id == UI.followBoss then followIndex = index end
    end
    local focus
    if engagedIndex and UI.lastEngaged ~= list[engagedIndex].id then UI.lastEngaged = list[engagedIndex].id; focus = engagedIndex end
    if not engagedIndex then UI.lastEngaged = nil end
    if followIndex then focus = focus or followIndex; UI.followBoss = nil end
    if focus then
        if focus <= scrollOffset then scrollOffset = focus - 1
        elseif focus > scrollOffset + visible then scrollOffset = focus - visible end
    end
    scrollOffset = math.max(0, math.min(scrollOffset, math.max(0, total - visible)))

    local rowHeight = db.rowHeight
    frame.body:SetShown(showList)
    for _, row in ipairs(rows) do row:Hide() end
    engagedRow = nil
    if showList then
        for slot = 1, visible do
            local info = list[scrollOffset + slot]
            local row = GetRow(slot)
            StyleRow(row, db, rowHeight)
            row.info = info
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, -(slot - 1) * rowHeight)
            row:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", db.growUp and 0 or 0, -(slot - 1) * rowHeight)
            row:SetHeight(rowHeight - 1)
            local face = db.icons and Addon.BossPortrait and Addon.BossPortrait(info.id, info.name)
            if face and SetPortraitTextureFromCreatureDisplayID and pcall(SetPortraitTextureFromCreatureDisplayID, row.icon, face) then
                row.icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
            else
                row.icon:SetTexture(info.icon)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            row.name:SetText(info.name .. (info.optional and " (opt)" or ""))
            Set(row.att, C.dim, (db.attempts and (info.attempts or 0) > 1) and ("x" .. info.attempts) or "")
            local minimal = db.rowStyle == "minimal"
            if info.killed then
                local behind = info.delta and info.delta > 0
                local tint = info.delta == nil and { ar, ag, ab } or (behind and pal.bad or pal.good)
                row.bg:SetColorTexture(tint[1] * 0.28, tint[2] * 0.28, tint[3] * 0.28, minimal and 0 or 0.85)
                row.stripe:SetColorTexture(tint[1], tint[2], tint[3], 1)
                Set(row.name, C.text, row.name:GetText())
                Set(row.time, C.text, SR.FormatTime(info.time, 0))
                if info.delta then Set(row.delta, tint, SR.FormatDelta(info.delta)) else row.delta:SetText("") end
                row.icon:SetDesaturated(false)
            elseif info.engaged then
                if db.colorEngaged then
                    local er, eg, eb = UI.EngagedColor(db)
                    row.bg:SetColorTexture(er * 0.3, eg * 0.3, eb * 0.3, minimal and 0 or 0.95)
                    row.stripe:SetColorTexture(er, eg, eb, 1)
                    Set(row.time, { er, eg, eb }, SR.FormatTime(info.fightTime, 0))
                else
                    row.bg:SetColorTexture(C.row[1], C.row[2], C.row[3], minimal and 0 or 0.85)
                    row.stripe:SetColorTexture(0.16, 0.18, 0.22, 1)
                    Set(row.time, C.text, SR.FormatTime(info.fightTime, 0))
                end
                Set(row.name, C.text, row.name:GetText())
                row.delta:SetText("")
                row.icon:SetDesaturated(false)
                engagedRow = row
            else
                row.bg:SetColorTexture(C.row[1], C.row[2], C.row[3], minimal and 0 or 0.85)
                row.stripe:SetColorTexture(0.16, 0.18, 0.22, 1)
                Set(row.name, C.dim, row.name:GetText())
                Set(row.time, C.dim, info.refTime and SR.FormatTime(info.refTime, 0) or "")
                row.delta:SetText("")
                row.icon:SetDesaturated(true)
            end
            row:Show()
        end
    end

    local scrolling = showList and total > visible
    frame.scrollTrack:SetShown(scrolling)
    frame.scrollThumb:SetShown(scrolling)
    if scrolling then
        local trackHeight = visible * rowHeight
        local size = math.max(10, trackHeight * visible / total)
        local room = trackHeight - size
        frame.scrollThumb:SetHeight(size)
        frame.scrollThumb:ClearAllPoints()
        frame.scrollThumb:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", 0, -(room * scrollOffset / math.max(1, total - visible)))
        frame.scrollThumb:SetColorTexture(ar, ag, ab, 0.8)
    end

    local showFooter = db.footer and not db.collapsed and snap.name ~= nil
    frame.footer:SetShown(showFooter)
    if showFooter then
        local text = "No comparison"
        if snap.refFinal or snap.refLabel then
            local label = snap.refKind == "best" and "Best" or (snap.refLabel and ("<" .. snap.refLabel .. ">") or "Import")
            text = ("%s  %s"):format(SR.FormatTime(snap.refFinal, 0), label)
        end
        Set(frame.foot, C.dim, text)
        Set(frame.footRight, C.dim, snap.wipes > 0 and ("Wipes: " .. snap.wipes) or "")
    end

    local pct = snap.bossCount > 0 and snap.killed / snap.bossCount or 0
    frame.progress:SetWidth(math.max(0.001, (db.width - 2) * pct))
    frame.progress:SetShown(pct > 0)

    local offset = 1
    Stack(frame.bar, db, offset, barHeight, 1); offset = offset + barHeight
    frame.statusFrame:SetShown(db.statusLine)
    if db.statusLine then
        local statusH = math.max(STATUS_H, (db.headerSize or db.textSize or 12) + 4)
        Stack(frame.statusFrame, db, offset, statusH, 1)
        offset = offset + statusH
    end
    if showList then
        Stack(frame.body, db, offset + 1, visible * rowHeight, 3)
        frame.body:SetPoint(db.growUp and "BOTTOMRIGHT" or "TOPRIGHT", frame, db.growUp and "BOTTOMRIGHT" or "TOPRIGHT", scrolling and -6 or -3, db.growUp and offset + 1 or -(offset + 1))
        offset = offset + 1 + visible * rowHeight + 2
    end
    if showFooter then Stack(frame.footer, db, offset, FOOT_H, 1); offset = offset + FOOT_H end
    frame:SetHeight(offset + 1)
    if frame.grip then
        frame.grip:ClearAllPoints()
        if db.growUp then
            frame.grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            frame.grip.tex:SetTexCoord(0, 1, 1, 0)
        else
            frame.grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            frame.grip.tex:SetTexCoord(0, 1, 0, 1)
        end
        frame.grip:SetShown(not db.locked)
    end
    UI.UpdateLive()
end

local function ContextEntries()
    local db = SR:GetStore()
    local running = SR.state == "running"
    return {
        { text = running and "Stop run" or "Start run", onClick = function() if running then SR:Stop() else SR:Start("manual") end end },
        { text = "Reset run", disabled = SR.state == "idle", onClick = function() SR:Reset() end },
        { text = db.collapsed and "Show bosses" or "Hide bosses", onClick = function() db.collapsed = not db.collapsed; SR:Notify() end },
        { text = db.locked and "Unlock position" or "Lock position", onClick = function() db.locked = not db.locked; SR:Notify() end },
        { text = "Disable Speedrun Timer", checked = db.disabled, onClick = function() SR:SetDisabled(true) end },
        { text = "Settings...", onClick = function() if FojjiCore.ToggleOptions then FojjiCore:ToggleOptions("speedrun") end end },
        { text = "Hide tracker", onClick = function()
            if db.visibility ~= "never" then db.lastVisibility = db.visibility end
            db.visibility = "never"; SR.preview = false; SR:Notify()
            Addon.Print("Tracker hidden. /fc speedrun brings it back, or use the Speedrun Timer settings.")
        end },
    }
end

function UI.SetEnabled(enabled)
    if UI.driver then UI.driver:Cancel() UI.driver = nil end
    if enabled and frame then UI.StartDriver() end
    if not enabled then
        Tip.Hide()
        if frame then frame:Hide() end
    else UI.Update() end
end

function UI.Create()
    if not SR:IsEnabled() then return end
    if frame then return end
    local db = SR:GetStore()
    frame = CreateFrame("Frame", "FojjiSpeedrunFrame", UIParent)
    UI.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetSize(db.width, 40)
    frame:Hide()
    if Addon.Native and Addon.Skin then Addon.Skin.Panel(frame) end
    if Addon.DJ and Addon.DJ.Pocket and Addon.DJ.Pocket.Placed then Addon.DJ.Pocket.Placed() end

    frame.bg = Tex(frame, "BACKGROUND", C.bg[1], C.bg[2], C.bg[3], db.bgAlpha)
    frame.bg:SetAllPoints()
    frame.edges = {}
    for _, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = AccentTex(frame, "BORDER", 0.5)
        edge:SetPoint(spec[1]); edge:SetPoint(spec[2])
        if spec[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        frame.edges[#frame.edges + 1] = edge
    end

    frame.bar = CreateFrame("Frame", nil, frame)
    frame.barBG = Tex(frame.bar, "BACKGROUND", C.header[1], C.header[2], C.header[3], 1)
    frame.barBG:SetAllPoints()
    local line = AccentTex(frame.bar, "ARTWORK", 0.8)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    frame.progress = AccentTex(frame.bar, "OVERLAY", 1)
    frame.progress:SetPoint("BOTTOMLEFT"); frame.progress:SetHeight(2)

    local hit = CreateFrame("Button", nil, frame.bar)
    hit:SetAllPoints()
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnDragStart", function() if not SR:GetStore().locked then frame:StartMoving() end end)
    hit:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition(); ApplyPosition() end)
    hit:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            if Addon.OptionsMenu then Addon.OptionsMenu.Open(hit, ContextEntries, { width = 150 }) end
        else
            local d = SR:GetStore(); d.collapsed = not d.collapsed; UI.Update()
        end
    end)
    frame.hit = hit

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(14, 14)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints()
    grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip.tex:SetAlpha(0.45)
    grip:SetScript("OnEnter", function(self)
        self.tex:SetAlpha(1)
        Tip.Show(self, "Resize", { "Drag sideways: width", "Drag up / down: bosses shown" }, "BOTTOM")
    end)
    grip:SetScript("OnLeave", function(self) if not self.sizing then self.tex:SetAlpha(0.45) end Tip.Hide() end)
    grip:SetScript("OnMouseDown", function(self, mouse)
        if mouse ~= "LeftButton" then return end
        local d = SR:GetStore()
        if d.locked then return end
        Tip.Hide()
        self.sizing = true
        local scale = frame:GetEffectiveScale()
        local startX, startY = GetCursorPosition()
        local startW = d.width
        local listH = frame.body and frame.body:IsShown() and frame.body:GetHeight() or 0
        local fixedH = frame:GetHeight() - listH
        local startRows = math.floor(listH / math.max(1, d.rowHeight) + 0.5)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local dx, dy = (x - startX) / scale, (y - startY) / scale
            if d.growUp then dy = -dy end
            local width = math.floor(math.max(150, math.min(420, startW + dx)) / 5 + 0.5) * 5
            local changed = width ~= d.width
            d.width = width
            if startRows > 0 then
                local rows = math.max(1, math.min(20, math.floor((startRows * d.rowHeight - dy) / d.rowHeight + 0.5)))
                if rows ~= d.maxRows then d.maxRows = rows; changed = true end
            end
            if changed then UI.Update() end
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        if not self.sizing then return end
        self.sizing = nil
        self:SetScript("OnUpdate", nil)
        if not self:IsMouseOver() then self.tex:SetAlpha(0.45) end
        SR:Notify()
    end)
    frame.grip = grip

    frame.timer = frame.bar:CreateFontString(nil, "OVERLAY")

    frame.bStart = GlyphButton(frame.bar, "play")
    frame.bStart:SetPoint("LEFT", 4, 0)
    frame.bStart:SetScript("OnClick", function()
        if SR.state == "running" then SR:Stop() else SR:Start("manual") end
    end)
    frame.bReset = GlyphButton(frame.bar, "reset")
    frame.bReset:SetPoint("LEFT", frame.bStart, "RIGHT", 1, 0)
    frame.bReset:SetScript("OnClick", function()
        if SR.state == "running" and not confirmReset then
            confirmReset = true
            UI.Update()
            C_Timer.After(3, function() confirmReset = false; UI.Update() end)
            return
        end
        confirmReset = false
        SR:Reset()
    end)
    frame.bGear = GlyphButton(frame.bar, "gear")
    frame.bGear:SetPoint("RIGHT", -4, 0)
    frame.bGear:SetScript("OnClick", function() if FojjiCore.ToggleOptions then FojjiCore:ToggleOptions("speedrun") end end)

    frame.bClose = GlyphButton(frame.bar, "play")
    frame.bClose:SetPoint("RIGHT", frame.bGear, "LEFT", -1, 0)
    frame.bClose.icon:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\close-cross")
    frame.bClose.icon:SetSize(11, 11)
    frame.bClose:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 0.45, 0.45)
        Tip.Show(self, self.tipText or "Hide", nil, "BOTTOM")
    end)
    frame.bClose:SetScript("OnClick", function()
        SR.preview = false
        if SR.state == "finished" or SR.state == "stopped" then SR:EndRun() end
        SR.manuallyHidden = true
        UI.Update()
    end)
    frame.bList = GlyphButton(frame.bar, "chevron")
    frame.bList:SetPoint("RIGHT", frame.bClose, "LEFT", -1, 0)
    frame.bList:SetScript("OnClick", function() local d = SR:GetStore(); d.collapsed = not d.collapsed; UI.Update() end)
    frame.bDone = GlyphButton(frame.bar, "check")
    frame.bDone:SetPoint("RIGHT", frame.bList, "LEFT", -1, 0)
    frame.bDone.tipText = "End run (result is saved) and hide"
    frame.bDone:SetScript("OnClick", function() SR:EndRun() end)
    frame.bDone:Hide()
    for _, b in ipairs({ frame.bStart, frame.bReset, frame.bGear, frame.bClose, frame.bList, frame.bDone }) do b:SetFrameLevel(hit:GetFrameLevel() + 2) end

    frame.statusFrame = CreateFrame("Frame", nil, frame)
    frame.status = Addon.Localize(frame.statusFrame:CreateFontString(nil, "OVERLAY"))
    frame.status:SetPoint("LEFT", 8, 0)
    frame.status:SetPoint("RIGHT", frame.statusFrame, "CENTER", 40, 0)
    frame.status:SetJustifyH("LEFT")
    frame.status:SetWordWrap(false)
    frame.statusRight = frame.statusFrame:CreateFontString(nil, "OVERLAY")
    frame.statusRight:SetPoint("RIGHT", -8, 0)

    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:EnableMouseWheel(true)
    frame.body:SetScript("OnMouseWheel", function(_, delta) Wheel(delta) end)
    frame.scrollTrack = Tex(frame.body, "ARTWORK", 0.12, 0.13, 0.16, 0.9)
    frame.scrollTrack:SetWidth(2)
    frame.scrollTrack:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", 3, 0)
    frame.scrollTrack:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 3, 0)
    frame.scrollThumb = Tex(frame.body, "OVERLAY", 1, 1, 1, 0.8)
    frame.scrollThumb:SetWidth(2)
    frame.scrollThumb:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", 3, 0)

    frame.footer = CreateFrame("Frame", nil, frame)
    frame.foot = Addon.Localize(frame.footer:CreateFontString(nil, "OVERLAY"))
    frame.foot:SetPoint("LEFT", 8, 0)
    frame.footRight = frame.footer:CreateFontString(nil, "OVERLAY")
    frame.footRight:SetPoint("RIGHT", -8, 0)

    local acc = 0
    frame:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0
        UI.UpdateLive()
    end)

    function UI.StartDriver()
        if UI.driver then return end
        UI.driver = C_Timer.NewTicker(1, function()
            if frame:IsShown() ~= SR:ShouldShow() then UI.Update() end
        end)
    end
    UI.StartDriver()

    SR:Subscribe(function(event, id)
        if event == "FOJJI_CORE_SPEEDRUN_SPLIT" then UI.followBoss = id end
        if event == "FOJJI_CORE_SPEEDRUN_RESET" or event == "FOJJI_CORE_SPEEDRUN_START" then scrollOffset = 0; UI.followBoss = nil end
    end)
    SR.OnChanged = UI.Update
    UI.Update()
end

Addon.SpeedrunRefreshTheme = function() UI.Update() end
