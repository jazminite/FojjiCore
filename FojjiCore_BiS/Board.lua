local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Plan = FDJ.Gear
FDJ.Plan = Plan
local Measure = Plan.Measure
local Advisor = Plan.Advisor

local TILE_H, TILE_GAP, HEAD_H, DRAWER_H = 46, 6, 24, 232
local MARK = "fc:plan-mark"

local DOLL = {
    L = { { "head", 1 }, { "neck", 1 }, { "shoulder", 1 }, { "back", 1 }, { "chest", 1 }, { "tabard", 1 }, { "wrist", 1 } },
    R = { { "hands", 1 }, { "waist", 1 }, { "legs", 1 }, { "feet", 1 }, { "rings", 1 }, { "rings", 2 }, { "trinkets", 1 }, { "trinkets", 2 } },
    B = { { "mainhand", 1 }, { "offhand", 1 }, { "ranged", 1 } },
}

local TONE = { equipped = "good", owned = "amber", missing = "dim", none = "borderDim" }

local SLOT_ART_NAME = {
    [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot", [5] = "ChestSlot", [19] = "TabardSlot",
    [9] = "WristSlot", [10] = "HandsSlot", [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot", [11] = "Finger0Slot",
    [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
}
local slotArt = {}
local function emptyArt(slot)
    if slotArt[slot] == nil then
        local ok, _, tex = pcall(GetInventorySlotInfo, SLOT_ART_NAME[slot] or "")
        slotArt[slot] = ok and tex or false
    end
    return slotArt[slot] or nil
end

local function groupByKey(key)
    for _, g in ipairs(Plan.GROUPS) do
        if g.key == key then return g end
    end
end

local requested = {}
local function itemName(itemID)
    local name, _, q = C_Item.GetItemInfo(itemID)
    if not name and (not requested[itemID] or GetTime() - requested[itemID] > 15) then
        requested[itemID] = GetTime()
        C_Item.RequestLoadItemDataByID(itemID)
    end
    local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if not name and Plan.ItemNames then name = Plan.ItemNames[itemID] end
    return name, qc and { qc.r, qc.g, qc.b } or nil
end

local function shortFrom(itemID)
    local boss, odds = Plan.Source(itemID)
    if boss then return FDJ.DungeonTitle(boss.dungeon) .. (odds and ("  ·  " .. ("%.1f%%"):format(odds)) or "") end
    local q = Plan.QuestFor(itemID)
    if q then return L.PLAN_QUEST_SHORT:format(q.t) end
    local src = Plan.ItemSource and Plan.ItemSource[itemID]
    if src then
        local short = L["PLAN_SRC_SHORT_" .. src[1]]
        if short then return short:format(src[2] or "") end
    end
    return nil
end

local function slotLabel(g, index)
    local label = Plan.SlotName(g)
    if #g.slots > 1 then label = label .. " " .. index end
    return tostring(label):upper()
end

local function wornScore(g, weights)
    local low
    for _, slot in ipairs(g.slots) do
        local id = GetInventoryItemID("player", slot)
        local s = id and Measure.ItemValue(id, weights) or 0
        if not low or s < low then low = s end
    end
    return low or 0
end

local function upgradeText(from, to)
    if not to or to <= 0 then return nil end
    if from < 4 then
        local pts = math.floor(to - from + 0.5)
        if pts == 0 then return nil end
        return ("%+d"):format(pts), pts > 0 and "good" or "bad"
    end
    local pct = (to - from) / from * 100
    if math.abs(pct) < 0.5 then return nil end
    pct = math.max(-99, math.min(999, pct))
    return ("%+.0f%%"):format(pct), pct > 0 and "good" or "bad"
end

local function itemTip(owner, itemID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if C_Item.GetItemInfo(itemID) then
        GameTooltip:SetItemByID(itemID)
    else
        C_Item.RequestLoadItemDataByID(itemID)
        GameTooltip:SetText(Plan.ItemNames and Plan.ItemNames[itemID] or ("Item " .. itemID), 1, 1, 1)
        local g = Plan.SlotFor and Plan.SlotFor(itemID)
        if g then GameTooltip:AddLine(Plan.SlotName(g), C.muted[1], C.muted[2], C.muted[3]) end
        local from = shortFrom(itemID)
        if from then GameTooltip:AddLine(from, C.text[1], C.text[2], C.text[3]) end
        GameTooltip:AddLine(L.PLAN_NOT_SENT, C.dim[1], C.dim[2], C.dim[3], true)
    end
    GameTooltip:Show()
end

local function linkItem(itemID)
    local _, link = C_Item.GetItemInfo(itemID)
    if link then HandleModifiedItemClick(link) end
end

local function pinnedAt(p)
    if not (p and FDJ.WP and FDJ.WP.List) then return nil end
    for _, wp in ipairs(FDJ.WP.List()) do
        if wp.m == p.m and math.abs(wp.x - p.x) < 0.001 and math.abs(wp.y - p.y) < 0.001 then return wp end
    end
end
local function togglePin(p)
    if not (p and FDJ.WP) then return end
    local wp = pinnedAt(p)
    if wp then FDJ.WP.Remove(wp) else FDJ.WP.Add(p.m, p.x, p.y, p.label, { focus = true }) end
end

local function prompt(title, default, done)
    Kit.Prompt(title, default or "", function(text)
        text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text ~= "" then done(text) end
    end)
end

local buildSettings

local function buildPlanner(host, top, pad)
    FDJ.SyncTheme()
    pad = pad or 0
    local root = CreateFrame("Frame", nil, host)
    root:SetPoint("TOPLEFT", pad, top)
    root:SetPoint("BOTTOMRIGHT", -pad, pad)

    local state = { view = nil, open = nil, page = 1, any = false, query = "" }
    local function mine() return state.view == nil or state.view == FDJ.charKey end
    local function target()
        local t = FDJ.char and FDJ.char.planTarget
        return (type(t) == "number" and t > 0) and t or FDJ.Level()
    end

    local board, settingsFrame, offFrame
    local tabs = Kit.Tabs(root, { { "board", L.PLAN_TAB_BOARD }, { "settings", L.PLAN_TAB_SETTINGS } }, function(key)
        local on = Plan.Enabled()
        board:SetShown(key == "board" and on)
        offFrame:SetShown(key == "board" and not on)
        settingsFrame:SetShown(key == "settings")
    end)
    if Addon.Native then tabs.first:SetPoint("TOPLEFT", 0, -7) else tabs.first:SetPoint("TOPLEFT", -6, 0) end
    local rule = root:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", 0, -33)
    rule:SetPoint("TOPRIGHT", 0, -33)
    rule:SetHeight(1)
    Kit.Paint(rule, C.borderDim)
    if Addon.Native and Addon.Skin then Addon.Skin.Rule(rule) end

    board = CreateFrame("Frame", nil, root)
    board:SetPoint("TOPLEFT", 0, -42)
    board:SetPoint("BOTTOMRIGHT")
    offFrame = CreateFrame("Frame", nil, root)
    offFrame:SetAllPoints(board)
    local offText = Kit.Text(offFrame, "normal", C.muted, "CENTER")
    offText:SetPoint("CENTER", 0, 20)
    offText:SetText(L.PLAN_OFF)
    Kit.Button(offFrame, L.PLAN_TURN_ON, nil, 28, function() Plan.SetOption("enabled", true) end, "primary")
        :SetPoint("TOP", offText, "BOTTOM", 0, -12)
    settingsFrame = buildSettings(root)
    settingsFrame:SetAllPoints(board)

    local refresh

    local head = CreateFrame("Frame", nil, board)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(30)

    local listBtn = Kit.Button(head, "", 210, 28, nil, "dropdown")
    if Addon.Native then
        listBtn:SetPoint("LEFT", 6, 0)
    else
        local mark = Kit.Glyph(head, MARK, 16, C.accent)
        mark:SetPoint("LEFT", 2, 0)
        listBtn:SetPoint("LEFT", mark, "RIGHT", 8, 0)
    end
    listBtn.label:ClearAllPoints()
    listBtn.label:SetPoint("LEFT", 10, 0)
    listBtn.label:SetPoint("RIGHT", -24, 0)
    listBtn.label:SetJustifyH("LEFT")
    if not listBtn.nativeDropdown then Kit.Glyph(listBtn, "fc:icon-chevron-down", 11, C.muted):SetPoint("RIGHT", -9, 0) end

    local suggestBtn = Kit.Button(head, L.BIS_SUGGEST, nil, 28, nil, "primary", "fc:icon-spark")
    suggestBtn:SetPoint("LEFT", listBtn, "RIGHT", 6, 0)
    suggestBtn.tip = L.BIS_SUGGEST_TIP

    local popout = Kit.IconButton(head, "fc:icon-export", 28, L.PLAN_POPOUT, function()
        if host.isPopout then host:Hide() else Plan.ToggleWindow() end
    end)
    popout:SetPoint("RIGHT")
    popout:SetShown(not host.isPopout)
    local weightsBtn = Kit.Button(head, L.PLAN_WEIGHTS, nil, 28)
    if host.isPopout then weightsBtn:SetPoint("RIGHT") else weightsBtn:SetPoint("RIGHT", popout, "LEFT", -6, 0) end
    local shareBtn = Kit.Button(head, L.PLAN_SHARE, nil, 28)
    shareBtn:SetPoint("RIGHT", weightsBtn, "LEFT", -6, 0)
    local showBtn = Addon.Native and Kit.Button(head, L.PLAN_STATS, nil, 28)
        or Kit.IconButton(head, "fc:icon-stats", 28, L.PLAN_STATS, nil)
    showBtn:SetPoint("RIGHT", shareBtn, "LEFT", -6, 0)

    listBtn:SetScript("OnClick", function(self)
        local items = {}
        if mine() then
            items[#items + 1] = { text = L.PLAN_NEW, color = C.accent, onClick = function()
                prompt(L.PLAN_NAME_Q, Plan.UnusedName(L.PLAN_NEW), function(n) Plan.NewList(n, false) end)
            end }
            items[#items + 1] = { text = L.PLAN_COPY, color = C.accent, onClick = function()
                prompt(L.PLAN_NAME_Q, Plan.UnusedName(Plan.ActiveName()), function(n) Plan.NewList(n, true) end)
            end }
            items[#items + 1] = { text = L.PLAN_RENAME, color = C.accent, onClick = function()
                prompt(L.PLAN_NAME_Q, (Plan.ActiveName()), function(n) Plan.RenameList(n) end)
            end }
            items[#items + 1] = { text = L.PLAN_DELETE, color = C.bad, onClick = function()
                Kit.Confirm(L.PLAN_DELETE_Q:format((Plan.ActiveName())), function() Plan.DeleteList() end)
            end }
        end
        local others = {}
        for _, w in ipairs(Plan.Characters()) do
            if not w.me and not w.old and w.n > 0 then others[#others + 1] = w end
        end
        if #others > 0 or not mine() then
            items[#items + 1] = { text = L.PLAN_OTHER_CHARS, title = true }
            if not mine() then
                items[#items + 1] = { text = L.PLAN_BACK_TO_MINE, color = C.accent, onClick = function()
                    state.view, state.open = nil, nil
                    refresh()
                end }
            end
            for _, w in ipairs(others) do
                items[#items + 1] = { text = FDJ.Paint(FDJ.Party.ClassColor(w.class), w.name) .. FDJ.Paint("dim", "  " .. L.ITEMS_N:format(w.n)),
                    checked = state.view == w.key,
                    onClick = function()
                        state.view, state.open = w.key, nil
                        refresh()
                    end }
            end
        end
        Kit.Menu(self, items, 240)
    end)

    local suggesting = false
    local function busy(finished, waiting)
        suggestBtn:SetLabel(finished and L.BIS_SUGGEST or L.BIS_SUGGEST_WAIT:format(waiting or 0))
        if finished then suggesting = false end
    end
    local function start(level)
        if suggesting or not mine() then return false end
        suggesting = true
        state.view = nil
        if FDJ.char then FDJ.char.planTarget = level end
        suggestBtn:SetLabel(L.BIS_SUGGEST_LOADING)
        return true
    end
    local function autoPlan(replace, level)
        if start(level) then Advisor.Assemble(replace, busy, { level = level }) end
    end
    local function newPlanFor(level, name)
        if start(level) then Advisor.Assemble(true, busy, { level = level, list = name }) end
    end
    suggestBtn:SetScript("OnClick", function(self)
        if not mine() then return end
        local me = FDJ.Level()
        local planName = Plan.ActiveName()
        local items = {}
        items[#items + 1] = { text = L.PLAN_FILL_EMPTY, onClick = function()
            Kit.Confirm(L.PLAN_AUTO_FILL_Q:format(planName, me), function() autoPlan(false, me) end)
        end }
        items[#items + 1] = { text = L.BIS_PRESETS_HEAD, title = true }
        items[#items + 1] = { text = L.BIS_PRESET_CURRENT:format(me), onClick = function()
            newPlanFor(me, L.BIS_PRESET_LEVEL:format(me))
        end }
        for _, p in ipairs(Advisor.PRESETS) do
            if p.level > me and not p.raid then
                local name = Advisor.PresetName(p)
                items[#items + 1] = { text = name, onClick = function() newPlanFor(p.level, name) end }
            end
        end
        items[#items + 1] = { text = L.BIS_PRESET_CUSTOM, color = C.accent, onClick = function()
            prompt(L.BIS_PRESET_CUSTOM_Q, tostring(target()), function(text)
                local lv = tonumber((text or ""):match("%d+"))
                if not lv then return end
                lv = math.max(1, math.min(60, math.floor(lv)))
                newPlanFor(lv, L.BIS_PRESET_LEVEL:format(lv))
            end)
        end }
        Kit.Menu(self, items, 260)
    end)

    shareBtn:SetScript("OnClick", function(self)
        Kit.Menu(self, {
            { text = L.PLAN_SHARE_EXPORT, onClick = function()
                Kit.TextWindow(L.PLAN_EXPORT_TITLE, Plan.ToText(state.view), nil, L.BIS_EXPORT_HINT)
            end },
            { text = L.PLAN_SHARE_IMPORT, onClick = function()
                Kit.TextWindow(L.PLAN_IMPORT_TITLE, "", function(text)
                    state.view = nil
                    return Plan.FromText(text)
                end, L.PLAN_IMPORT_HINT)
            end },
        }, 170)
    end)

    local viewing = CreateFrame("Frame", nil, board)
    viewing:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    viewing:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -6)
    viewing:SetHeight(24)
    Kit.Fill(viewing, C.accent, 0.12)
    viewing.text = Kit.Text(viewing, "small", C.text)
    viewing.text:SetPoint("LEFT", 10, 0)
    viewing.back = Kit.Button(viewing, L.PLAN_BACK_TO_MINE, nil, 20, function()
        state.view, state.open = nil, nil
        refresh()
    end)
    viewing.back:SetPoint("RIGHT", -4, 0)
    viewing:Hide()

    local track = CreateFrame("Frame", nil, board)
    track:SetHeight(32)
    Kit.Fill(track, C.panel, 0.6)
    Kit.Edge(track, C.borderDim, 0.7)
    track.line = track:CreateTexture(nil, "BORDER")
    track.line:SetHeight(2)
    local phases = CreateFrame("Frame", nil, track)
    phases:SetHeight(24)
    phases:SetPoint("RIGHT", -8, 0)
    phases.label = Kit.Text(phases, "tiny", C.muted)
    phases.label:SetPoint("LEFT")
    phases.label:SetText(L.PLAN_PHASE:upper())
    phases.dots = {}
    local DOT = 22
    for n = 1, Plan.PHASES do
        local b = CreateFrame("Button", nil, phases)
        b:SetSize(DOT, DOT)
        b:SetPoint("LEFT", phases.label, "RIGHT", 8 + (n - 1) * (DOT + 5), 0)
        b.disc = b:CreateTexture(nil, "BACKGROUND")
        b.disc:SetAllPoints()
        b.disc:SetTexture(FDJ.Glyph("fc:ui-disc"))
        b.ring = b:CreateTexture(nil, "BORDER")
        b.ring:SetAllPoints()
        b.ring:SetTexture(FDJ.Glyph("fc:ui-ring"))
        b.num = Kit.Text(b, "tiny", C.muted, "CENTER")
        b.num:SetPoint("CENTER", 0, 0)
        b.num:SetText(n)
        b.n = n
        b:SetScript("OnClick", function(self)
            if not mine() then return end
            Plan.SetPhase(self.n)
        end)
        b:SetScript("OnEnter", function(self)
            Kit.Tip(self, L.PLAN_PHASE_N:format(self.n), L.PLAN_PHASE_TIP)
            if self.n ~= phases.current then self.ring:SetVertexColor(RGB(C.text)) end
        end)
        b:SetScript("OnLeave", function(self)
            Kit.HideTip()
            if self.n ~= phases.current then self.ring:SetVertexColor(RGB(C.borderDim)) end
        end)
        phases.dots[n] = b
    end
    phases:SetWidth(phases.label:GetStringWidth() + 8 + Plan.PHASES * (DOT + 5))
    local function paintPhases()
        local cur = Plan.PhaseOf(state.view)
        phases.current = cur
        phases:SetWidth(phases.label:GetStringWidth() + 8 + Plan.PHASES * (DOT + 5))
        for n, b in ipairs(phases.dots) do
            local on = n == cur
            b.disc:SetVertexColor(RGB(on and C.accent or C.field))
            b.disc:SetAlpha(on and 0.28 or 1)
            b.ring:SetVertexColor(RGB(on and C.accent or C.borderDim))
            b.num:SetTextColor(RGB(on and C.white or C.muted))
            b:SetEnabled(mine())
        end
    end
    track.line:SetPoint("LEFT", 14, 0)
    track.line:SetPoint("RIGHT", phases, "LEFT", -14, 0)
    Kit.Paint(track.line, C.borderDim, 0.9)
    local stopsOnTrack, dragging = {}, nil

    local function lineUp()
        local x = 10
        for _, b in ipairs(stopsOnTrack) do
            if b:IsShown() and b ~= dragging then
                b:ClearAllPoints()
                b:SetPoint("LEFT", x, 0)
                x = x + b:GetWidth() + 14
            end
        end
        return x
    end

    local function listMenu(anchor, l)
        Kit.Menu(anchor, {
            { text = l.name, title = true },
            { text = L.PLAN_RENAME, onClick = function()
                Plan.SetActive(l.index)
                prompt(L.PLAN_NAME_Q, l.name, function(n) Plan.RenameList(n) end)
            end },
            { text = L.PLAN_COPY, onClick = function()
                Plan.SetActive(l.index)
                prompt(L.PLAN_NAME_Q, Plan.UnusedName(l.name), function(n) Plan.NewList(n, true) end)
            end },
            { text = L.PLAN_DELETE, color = C.bad, onClick = function()
                Kit.Confirm(L.PLAN_DELETE_Q:format(l.name), function() Plan.DeleteListAt(l.index) end)
            end },
        }, 180)
    end

    local function trackStop(i)
        local b = stopsOnTrack[i]
        if b then return b end
        b = CreateFrame("Button", nil, track)
        b:SetHeight(24)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        Kit.Edge(b, C.borderDim)
        if Addon.Native and Addon.Skin and Addon.Skin.Button(b) then
            for _, e in ipairs(b.edges or {}) do e:Hide() end
        end
        b.fill = b:CreateTexture(nil, "BORDER")
        b.fill:SetPoint("BOTTOMLEFT", 1, 1)
        b.fill:SetHeight(2)
        b.text = Kit.Text(b, "small", C.text)
        b.text:SetPoint("LEFT", 10, 0)
        b.count = Kit.Text(b, "tiny", C.muted)
        b.count:SetPoint("LEFT", b.text, "RIGHT", 6, 0)
        b:SetScript("OnEnter", function(self)
            if not self.on then Kit.EdgeColor(self, C.accent, 0.6) end
            if self.list and not dragging then Kit.Tip(self, self.list.name, mine() and L.BIS_TRACK_TIP or L.BIS_TRACK_TIP_ALT) end
        end)
        b:SetScript("OnLeave", function(self)
            if not self.on then Kit.EdgeColor(self, C.borderDim) end
            Kit.HideTip()
        end)
        b:SetScript("OnClick", function(self, button)
            if self.dragged then self.dragged = nil return end
            if not self.list then return end
            if button == "RightButton" then
                if mine() then listMenu(self, self.list) end
                return
            end
            Plan.SetActive(self.list.index, state.view)
        end)
        local function others(self)
            local out = {}
            for _, o in ipairs(stopsOnTrack) do
                if o ~= self and o:IsShown() and o.list then out[#out + 1] = o end
            end
            return out
        end
        local function slotFor(self, list)
            local mid = self.x + self:GetWidth() / 2
            local k = 0
            for i, o in ipairs(list) do
                if mid > (o.tx or 0) + o:GetWidth() / 2 then k = i end
            end
            return k
        end
        local function slide(self, elapsed)
            local list = others(self)
            local k = slotFor(self, list)
            local x = 10
            for i, o in ipairs(list) do
                if i == k + 1 then x = x + self:GetWidth() + 14 end
                o.tx = x
                o.cx = (o.cx or x) + (x - (o.cx or x)) * math.min(1, elapsed * 18)
                o:ClearAllPoints()
                o:SetPoint("LEFT", track, "LEFT", o.cx, 0)
                x = x + o:GetWidth() + 14
            end
            return list, k
        end
        local function finishDrag(self)
            self:SetScript("OnUpdate", nil)
            if dragging ~= self then return end
            self:SetAlpha(1)
            self:SetFrameLevel(track:GetFrameLevel() + 1)
            local list = others(self)
            local k = slotFor(self, list)
            dragging = nil
            for _, o in ipairs(list) do o.cx, o.tx = nil, nil end
            local from, to = self.list.index, nil
            if list[k + 1] then
                local e = list[k + 1].list.index
                to = from < e and e - 1 or e
            elseif list[k] then
                local e = list[k].list.index
                to = from < e and e or e + 1
            end
            if to and to ~= from then Plan.MoveList(from, to) else lineUp() end
        end
        b:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" or not (mine() and self.list) then return end
            local scale = track:GetEffectiveScale()
            local press = GetCursorPosition() / scale
            self.grab = press - (self:GetLeft() or 0)
            self:SetScript("OnUpdate", function(me, elapsed)
                local cx = GetCursorPosition() / scale
                if dragging ~= me then
                    if math.abs(cx - press) < 4 then return end
                    dragging = me
                    me.dragged = true
                    Kit.HideTip()
                    me:SetFrameLevel(track:GetFrameLevel() + 10)
                    me:SetAlpha(0.85)
                    for _, o in ipairs(others(me)) do o.cx = (o:GetLeft() or 0) - (track:GetLeft() or 0) end
                end
                local maxX = (track.line:GetRight() or track:GetRight() or 0) - (track:GetLeft() or 0) - me:GetWidth()
                me.x = math.max(4, math.min(maxX, cx - me.grab - (track:GetLeft() or 0)))
                me:ClearAllPoints()
                me:SetPoint("LEFT", track, "LEFT", me.x, 0)
                slide(me, elapsed)
            end)
        end)
        b:SetScript("OnMouseUp", function(self)
            finishDrag(self)
            self:SetScript("OnUpdate", nil)
        end)
        b:SetScript("OnHide", function(self) if dragging == self then finishDrag(self) end end)
        stopsOnTrack[i] = b
        return b
    end

    local addList = Kit.Button(track, L.PLAN_NEW, nil, 24, function(self)
        Kit.Menu(self, {
            { text = L.PLAN_NEW, onClick = function()
                prompt(L.PLAN_NAME_Q, Plan.UnusedName(L.PLAN_NEW), function(n) Plan.NewList(n, false) end)
            end },
            { text = L.PLAN_COPY, onClick = function()
                prompt(L.PLAN_NAME_Q, Plan.UnusedName(Plan.ActiveName()), function(n) Plan.NewList(n, true) end)
            end },
        }, 180)
    end, nil, "fc:icon-plus")

    local function paintTrack()
        if dragging then return end
        local lists = Plan.SpecLists(state.view)
        local total = 0
        for _, g in ipairs(Plan.GROUPS) do if not g.optional then total = total + Plan.SlotCount(g) end end
        for i, l in ipairs(lists) do
            local b = trackStop(i)
            local picked = 0
            for _, g in ipairs(Plan.GROUPS) do
                local p = l.picks and l.picks[g.key]
                if p and not g.optional then picked = picked + math.min(#p, Plan.SlotCount(g)) end
            end
            b.list, b.on = l, l.active
            b.text:SetText(l.name)
            b.text:SetTextColor(RGB(b.on and C.white or C.text))
            b.count:SetText(picked .. "/" .. total)
            b.bg:SetColorTexture(RGB(b.on and C.accent or C.frame, b.on and 0.30 or 0.95))
            Kit.EdgeColor(b, b.on and C.accent or C.borderDim, b.on and 0.9 or 1)
            if b.nativeArt then
                b.bg:SetColorTexture(0, 0, 0, 0)
                b.active = b.on
                b:NativeState(false)
                Addon.Skin.ButtonText(b.text, true, b.on)
            end
            local w = b.text:GetUnboundedStringWidth() + b.count:GetUnboundedStringWidth() + 26
            b:SetWidth(w)
            b.fill:SetWidth(math.max(1, (w - 2) * math.min(1, total > 0 and picked / total or 0)))
            b.fill:SetColorTexture(RGB(C.accent, b.on and 1 or 0.6))
            b:Show()
        end
        for i = #lists + 1, #stopsOnTrack do stopsOnTrack[i]:Hide() end
        local x = lineUp()
        addList:ClearAllPoints()
        addList:SetPoint("LEFT", x, 0)
        addList:SetShown(mine())
    end

    local body = CreateFrame("Frame", nil, board)
    body:SetPoint("BOTTOMRIGHT")
    local function anchorBody()
        local above = viewing:IsShown() and viewing or head
        track:ClearAllPoints()
        track:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
        track:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -8)
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -10)
        body:SetPoint("BOTTOMRIGHT")
    end

    local colL = CreateFrame("Frame", nil, body)
    local colR = CreateFrame("Frame", nil, body)
    local centre = CreateFrame("Frame", nil, body)
    local bottom = CreateFrame("Frame", nil, body)
    body:SetScript("OnSizeChanged", function() if refresh then refresh() end end)
    local stage = Plan.BuildStage and Plan.BuildStage(centre, { view = function() return state.view end, mine = mine })
    if stage then stage:SetAllPoints(centre) end

    local tiles = {}
    local function placeOn(g, index, itemID)
        if not mine() then return end
        if Plan.SlotFor(itemID) ~= g then
            FDJ.Print(L.PLAN_WRONG_SLOT:format(Plan.SlotName(g)))
            return
        end
        Plan.PutInSlot(g, index, itemID)
    end

    local function makeTile()
        local t = CreateFrame("Button", nil, body)
        t:SetHeight(TILE_H)
        Kit.Fill(t, C.panel, 0.9)
        t.edge = Kit.Edge(t, C.borderDim)
        t.bar = t:CreateTexture(nil, "ARTWORK")
        t.bar:SetPoint("TOPLEFT", 1, -1)
        t.bar:SetPoint("BOTTOMLEFT", 1, 1)
        t.bar:SetWidth(3)
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(32, 32)
        t.icon:SetPoint("LEFT", 10, 0)
        t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t.empty = t:CreateTexture(nil, "ARTWORK", nil, 1)
        t.empty:SetAllPoints(t.icon)
        t.empty:SetColorTexture(RGB(C.field, 1))
        t.name = Kit.Text(t, "small", C.white)
        t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 9, -1)
        t.name:SetPoint("RIGHT", -70, 0)
        t.src = Kit.Text(t, "tiny", C.muted)
        t.src:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 9, 1)
        t.src:SetPoint("RIGHT", -60, 0)
        t.slot = Kit.Text(t, "tiny", C.dim, "RIGHT")
        t.slot:SetPoint("TOPRIGHT", -8, -6)
        t.gain = Kit.Text(t, "small", C.good, "RIGHT")
        t.gain:SetPoint("BOTTOMRIGHT", -8, 6)
        t.hl = t:CreateTexture(nil, "HIGHLIGHT")
        t.hl:SetAllPoints()
        t.hl:SetColorTexture(RGB(C.accent, 0.06))
        if Addon.Native then
            local sheen = t:CreateTexture(nil, "BACKGROUND", nil, 1)
            sheen:SetPoint("TOPLEFT", 1, -1)
            sheen:SetPoint("BOTTOMRIGHT", -1, 1)
            sheen:SetColorTexture(1, 1, 1, 1)
            if not (CreateColor and pcall(sheen.SetGradient, sheen, "VERTICAL",
                CreateColor(1, 0.85, 0.6, 0), CreateColor(1, 0.85, 0.6, 0.07))) then sheen:Hide() end
            t.slotFrame = t:CreateTexture(nil, "OVERLAY")
            t.slotFrame:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            t.slotFrame:SetSize(56, 56)
            t.slotFrame:SetPoint("CENTER", t.icon, "CENTER")
            t.quality = t:CreateTexture(nil, "OVERLAY", nil, 1)
            t.quality:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            t.quality:SetBlendMode("ADD")
            t.quality:SetSize(60, 60)
            t.quality:SetPoint("CENTER", t.icon, "CENTER")
            t.quality:Hide()
            t.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            t.hl:SetBlendMode("ADD")
            t.hl:SetAlpha(0.5)
        end
        function t:SetSide(side)
            if self.side == side then return end
            self.side = side
            local right = side == "R"
            self.bar:ClearAllPoints()
            self.bar:SetPoint(right and "TOPRIGHT" or "TOPLEFT", right and -1 or 1, -1)
            self.bar:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", right and -1 or 1, 1)
            self.icon:ClearAllPoints()
            self.icon:SetPoint(right and "RIGHT" or "LEFT", right and -10 or 10, 0)
            self.name:ClearAllPoints()
            self.src:ClearAllPoints()
            self.slot:ClearAllPoints()
            self.gain:ClearAllPoints()
            if right then
                self.name:SetPoint("TOPRIGHT", self.icon, "TOPLEFT", -9, -1)
                self.name:SetPoint("LEFT", 8, 0)
                self.name:SetJustifyH("RIGHT")
                self.src:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMLEFT", -9, 1)
                self.src:SetPoint("LEFT", 52, 0)
                self.src:SetJustifyH("RIGHT")
                self.gain:SetPoint("BOTTOMLEFT", 8, 5)
                self.gain:SetJustifyH("LEFT")
            else
                self.name:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 9, -1)
                self.name:SetPoint("RIGHT", -8, 0)
                self.name:SetJustifyH("LEFT")
                self.src:SetPoint("BOTTOMLEFT", self.icon, "BOTTOMRIGHT", 9, 1)
                self.src:SetPoint("RIGHT", -52, 0)
                self.src:SetJustifyH("LEFT")
                self.gain:SetPoint("BOTTOMRIGHT", -8, 5)
                self.gain:SetJustifyH("RIGHT")
            end
            self.slot:Hide()
        end
        t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        t:SetScript("OnEnter", function(self)
            if self.itemID then itemTip(self, self.itemID) elseif mine() then self.src:SetText(L.PLAN_CHOOSE) end
        end)
        t:SetScript("OnLeave", function(self)
            Kit.HideTip()
            if not self.itemID then self.src:SetText("") end
        end)
        local function dropped(self)
            local kind, id = GetCursorInfo()
            if kind == "item" and id then
                ClearCursor()
                placeOn(self.group, self.index, id)
                return true
            end
        end
        t:SetScript("OnReceiveDrag", dropped)
        t:SetScript("OnClick", function(self, button)
            if dropped(self) then return end
            if button == "RightButton" then
                if mine() and self.itemID then Plan.ClearSlot(self.group, self.index) end
                return
            end
            if IsModifiedClick() and self.itemID then linkItem(self.itemID) return end
            local same = state.open and state.open.group == self.group and state.open.index == self.index
            state.open = (not same) and { group = self.group, index = self.index } or nil
            state.page, state.query, state.peek = 1, "", nil
            refresh()
        end)
        return t
    end

    for side, keys in pairs(DOLL) do
        for row, entry in ipairs(keys) do
            local g = groupByKey(entry[1])
            if g then
                local t = makeTile()
                t.group, t.index, t.row = g, entry[2], row
                t:SetSide(side)
                tiles[#tiles + 1] = t
            end
        end
    end

    local function paintTile(t, weights, worn)
        local picks = Plan.ItemsIn(t.group, state.view)
        local id = picks[t.index]
        t.itemID = id
        t.slot:SetText(slotLabel(t.group, t.index))
        local status = "none"
        if id then
            status = mine() and Plan.State(t.group, id) or "missing"
            local name, qc = itemName(id)
            t.icon:SetTexture(C_Item.GetItemIconByID(id) or 134400)
            t.icon:SetDesaturated(false)
            t.icon:SetAlpha(1)
            t.icon:Show()
            t.empty:Hide()
            t.name:SetText(name or L.LOADING)
            t.name:SetTextColor(RGB(qc or C.text))
            if t.quality then
                local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
                local qcol = q and q >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
                if qcol then
                    t.quality:SetVertexColor(qcol.r, qcol.g, qcol.b, 0.85)
                    t.quality:Show()
                else
                    t.quality:Hide()
                end
            end
            local where = status == "equipped" and L.PLAN_EQUIPPED or shortFrom(id)
            if status == "owned" then where = L.PLAN_IN_BAGS .. (where and ("  ·  " .. where) or "") end
            t.src:SetText(where or "")
            local txt, tone
            if mine() and status ~= "equipped" then
                txt, tone = upgradeText(worn[t.group] or 0, Measure.ItemValue(id, weights))
            end
            t.gain:SetText(txt or "")
            if tone then t.gain:SetTextColor(RGB(C[tone])) end
        else
            local art = emptyArt(t.group.slots[t.index])
            t.icon:SetTexture(art)
            t.icon:SetShown(art ~= nil)
            t.icon:SetDesaturated(true)
            t.icon:SetAlpha(0.35)
            t.empty:SetShown(art == nil)
            local label = Plan.SlotName(t.group)
            if #t.group.slots > 1 then label = label .. " " .. t.index end
            t.name:SetText(label)
            t.name:SetTextColor(RGB(C.dim))
            if t.quality then t.quality:Hide() end
            t.src:SetText("")
            t.gain:SetText("")
        end
        t.slot:Hide()
        t.bar:SetColorTexture(RGB(C[TONE[status]] or C.dim))
        local open = state.open and state.open.group == t.group and state.open.index == t.index
        Kit.EdgeColor(t, open and C.accent or C.borderDim)
        if t.nativeChrome and t.nativeChrome.SetBackdropBorderColor then
            if open then t.nativeChrome:SetBackdropBorderColor(1, 0.82, 0, 1) else t.nativeChrome:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end
        end
        return status
    end

    local drawer = CreateFrame("Frame", nil, body)
    drawer:SetFrameLevel(body:GetFrameLevel() + 20)
    drawer:EnableMouse(true)
    drawer:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            state.open = nil
            refresh()
        end
    end)
    Kit.Fill(drawer, C.field, 1)
    Kit.Edge(drawer, C.borderDim)
    if Addon.Native and Addon.Skin then Addon.Skin.Panel(drawer) end
    local drawerTop = drawer:CreateTexture(nil, "ARTWORK")
    drawerTop:SetPoint("TOPLEFT", 1, -1)
    drawerTop:SetPoint("TOPRIGHT", -1, -1)
    drawerTop:SetHeight(2)
    Kit.Paint(drawerTop, C.accent, 0.9)
    drawer.close = Kit.CloseButton(drawer, function()
        state.open = nil
        refresh()
    end)
    drawer.close:SetPoint("TOPRIGHT", -4, -6)

    local card = CreateFrame("Frame", nil, drawer)
    card:SetPoint("TOPLEFT", 12, -12)
    card:SetPoint("BOTTOMLEFT", 12, 12)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT")
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.iconEdge = CreateFrame("Frame", nil, card)
    card.iconEdge:SetPoint("TOPLEFT", card.icon, -1, 1)
    card.iconEdge:SetPoint("BOTTOMRIGHT", card.icon, 1, -1)
    Kit.Edge(card.iconEdge, C.borderDim)
    card.name = Kit.Text(card, "normal", C.white)
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -2)
    card.name:SetPoint("RIGHT", -64, 0)
    card.sub = Kit.Text(card, "tiny", C.muted)
    card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
    card.sub:SetPoint("RIGHT", -64, 0)
    card.gain = Kit.Text(card, "large", C.good, "RIGHT")
    card.gain:SetPoint("TOPRIGHT", 0, -2)
    card.gainNote = Kit.Text(card, "tiny", C.dim, "RIGHT")
    card.gainNote:SetPoint("TOPRIGHT", card.gain, "BOTTOMRIGHT", 0, -2)
    card.none = Kit.Text(card, "small", C.dim)
    card.none:SetPoint("TOPLEFT", card.icon, "BOTTOMLEFT", 0, -16)
    card.none:SetPoint("RIGHT")
    card.none:SetJustifyH("LEFT")
    card.none:SetWordWrap(true)

    local STEP_H = 38
    card.spine = card:CreateTexture(nil, "BORDER")
    card.spine:SetWidth(2)
    Kit.Paint(card.spine, C.borderDim, 1)
    card.steps = {}
    local function routeStep(i)
        local st = card.steps[i]
        if st then return st end
        st = CreateFrame("Frame", nil, card)
        st:SetHeight(STEP_H)
        st.dot = st:CreateTexture(nil, "ARTWORK")
        st.dot:SetSize(10, 10)
        st.dot:SetPoint("TOPLEFT", 13, -3)
        st.dot:SetTexture(FDJ.Glyph("fc:ui-dot"))
        st.num = Kit.Text(st, "tiny", C.dim, "RIGHT")
        st.num:SetPoint("RIGHT", st.dot, "LEFT", -5, 0)
        st.title = Kit.Text(st, "small", C.white)
        st.title:SetPoint("TOPLEFT", 34, 0)
        st.title:SetPoint("RIGHT")
        st.detail = Kit.Text(st, "tiny", C.muted)
        st.detail:SetPoint("TOPLEFT", st.title, "BOTTOMLEFT", 0, -3)
        st.detail:SetPoint("RIGHT")
        for _, fs in ipairs({ st.title, st.detail }) do
            fs:SetJustifyH("LEFT")
            if fs.SetWordWrap then fs:SetWordWrap(true) end
            if fs.SetMaxLines then fs:SetMaxLines(3) end
        end
        st.track = st:CreateTexture(nil, "ARTWORK")
        st.track:SetPoint("TOPLEFT", st.detail, "BOTTOMLEFT", 0, -4)
        st.track:SetSize(120, 3)
        Kit.Paint(st.track, C.borderDim, 1)
        st.fill = st:CreateTexture(nil, "OVERLAY")
        st.fill:SetPoint("LEFT", st.track, "LEFT")
        st.fill:SetHeight(3)
        Kit.Paint(st.fill, C.accent, 1)
        card.steps[i] = st
        return st
    end

    card.pin = Kit.Button(card, L.PLAN_ROUTE_PIN, nil, 24, nil, "primary", "fc:icon-pin")
    card.pin:SetPoint("BOTTOMLEFT")
    card.pin.tip = L.PLAN_PIN_TIP
    card.journal = Kit.Button(card, L.PLAN_ROUTE_JOURNAL, nil, 24, nil, nil, "fc:icon-journal")
    card.journal:SetPoint("LEFT", card.pin, "RIGHT", 6, 0)

    local optsBox = CreateFrame("Frame", nil, drawer)
    optsBox:SetPoint("TOPRIGHT", -36, -12)
    optsBox:SetPoint("BOTTOMRIGHT", -12, 12)
    optsBox:SetPoint("LEFT", card, "RIGHT", 18, 0)
    local divider = drawer:CreateTexture(nil, "BORDER")
    divider:SetWidth(1)
    divider:SetPoint("TOP", optsBox, "TOPLEFT", -9, 0)
    divider:SetPoint("BOTTOM", optsBox, "BOTTOMLEFT", -9, 0)
    Kit.Paint(divider, C.borderDim, 1)

    drawer.any = Kit.Button(optsBox, L.PLAN_ANY_LEVEL, nil, 20, function()
        state.any = not state.any
        state.page = 1
        refresh()
    end)
    drawer.any:SetPoint("TOPRIGHT")
    drawer.any:HookScript("OnEnter", function(self)
        Kit.Tip(self, L.PLAN_ANY_LEVEL, L.PLAN_ANY_LEVEL_TIP:format(target()))
        GameTooltip:Show()
    end)
    drawer.any:HookScript("OnLeave", function() GameTooltip:Hide() end)
    drawer.search = Kit.Input(optsBox, 140, 20, L.PLAN_SEARCH, function(_, text, user)
        if not user then return end
        state.query = text or ""
        state.page = 1
        FDJ.Debounce("plansearch", 0.25, function() refresh() end)
    end, nil, "fc:icon-search")
    drawer.search:SetPoint("TOPLEFT")
    drawer.none = Kit.Text(optsBox, "small", C.dim)
    drawer.none:SetPoint("TOPLEFT", 0, -36)
    drawer.none:SetText(L.PLAN_NO_OPTIONS)
    drawer.pageText = Kit.Text(optsBox, "tiny", C.dim, "RIGHT")
    drawer.pageText:SetPoint("BOTTOMRIGHT", -52, 4)
    drawer.prev = Kit.IconButton(optsBox, "fc:icon-chevron-up", 20, nil, function()
        state.page = math.max(1, state.page - 1)
        refresh()
    end)
    drawer.prev:SetPoint("BOTTOMRIGHT", -24, 0)
    drawer.next = Kit.IconButton(optsBox, "fc:icon-chevron-down", 20, nil, function()
        state.page = state.page + 1
        refresh()
    end)
    drawer.next:SetPoint("BOTTOMRIGHT")
    optsBox:EnableMouseWheel(true)
    optsBox:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 and drawer.prev:IsShown() then drawer.prev:Click()
        elseif delta < 0 and drawer.next:IsShown() then drawer.next:Click() end
    end)

    local OPT_H = 26
    local paintCard
    drawer.options = {}
    local function optionButton(i)
        local b = drawer.options[i]
        if b then return b end
        b = CreateFrame("Button", nil, optsBox)
        b:SetHeight(OPT_H)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetPoint("TOPLEFT")
        b.mark:SetPoint("BOTTOMLEFT")
        b.mark:SetWidth(2)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 8, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.name = Kit.Text(b, "small", C.white)
        b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
        b.name:SetWidth(150)
        b.from = Kit.Text(b, "tiny", C.muted)
        b.from:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
        b.from:SetPoint("RIGHT", -48, 0)
        b.gain = Kit.Text(b, "small", C.good, "RIGHT")
        b.gain:SetPoint("RIGHT", -6, 0)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(RGB(C.accent, 0.08))
        if Addon.Native then
            b.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            b.hl:SetBlendMode("ADD")
            b.hl:SetVertexColor(1, 0.82, 0.4, 0.6)
            b.quality = b:CreateTexture(nil, "OVERLAY")
            b.quality:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            b.quality:SetBlendMode("ADD")
            b.quality:SetSize(38, 38)
            b.quality:SetPoint("CENTER", b.icon, "CENTER")
            b.quality:Hide()
        end
        b:SetScript("OnEnter", function(self)
            state.peek = self.itemID
            paintCard()
            itemTip(self, self.itemID)
        end)
        b:SetScript("OnLeave", function()
            Kit.HideTip()
            state.peek = nil
            paintCard()
        end)
        b:SetScript("OnClick", function(self)
            if IsModifiedClick() then linkItem(self.itemID) return end
            if state.open then placeOn(state.open.group, state.open.index, self.itemID) end
        end)
        drawer.options[i] = b
        return b
    end
    drawer:Hide()

    local function candidates(g)
        local query = (state.query or ""):lower()
        local wanted = tonumber(query:match("^%s*(%d+)%s*$"))
        if wanted then
            return { wanted }
        end
        local weights = Measure.StatValues(nil, Plan.SpecOf(state.view))
        local owner = state.view and FDJ.db and FDJ.db.chars[state.view]
        local list = Advisor.Contenders(g, { level = target(), any = state.any, weights = weights, class = owner and owner.class })
        if target() >= 60 and Advisor.Curated and (not owner or not owner.class or owner.class == select(2, UnitClass("player"))) then
            local curated = Advisor.Curated(g, { level = 60, weights = weights, spec = Plan.SpecOf(state.view) })
            if curated and curated[1] then
                local merged, seen = {}, {}
                for _, e in ipairs(curated) do if not seen[e.id] then seen[e.id] = true; merged[#merged + 1] = e end end
                for _, e in ipairs(list) do if not seen[e.id] then seen[e.id] = true; merged[#merged + 1] = e end end
                list = merged
            end
        end
        local out = {}
        for _, e in ipairs(list) do
            if query == "" then
                out[#out + 1] = e.id
            else
                local name = C_Item.GetItemInfo(e.id)
                if name and name:lower():find(query, 1, true) then out[#out + 1] = e.id end
            end
        end
        return out
    end

    local function routeFor(itemID)
        local boss, odds = Plan.Source(itemID)
        if boss and boss.dungeon then
            local d = boss.dungeon
            local title = FDJ.DungeonTitle(d)
            local door = FDJ.EntranceSpot and FDJ.EntranceSpot(d.key)
            local lv = FDJ.Level()
            local range = d.range and L.PLAN_LEVELS:format(d.range[1], d.range[2]) or ""
            local inRange = d.range and lv >= d.range[1] - 2 and lv <= d.range[2]
            return {
                steps = {
                    { L.PLAN_ROUTE_TRAVEL:format(door and door.zone or d.zone or "?"),
                      door and L.PLAN_ROUTE_DOOR:format(door.x * 100, door.y * 100) or "" },
                    { L.PLAN_ROUTE_ENTER:format(title), range .. (inRange and ("  ·  " .. FDJ.Paint("good", L.PLAN_IN_RANGE)) or "") },
                    { L.PLAN_ROUTE_DEFEAT:format(boss.n), odds and L.PLAN_ROUTE_ODDS:format(("%.1f"):format(odds)) or L.PLAN_ROUTE_NO_ODDS, odds = odds },
                },
                pin = door and { m = door.m, x = door.x, y = door.y, label = title },
                dungeon = d,
            }
        end
        local q, qid = Plan.QuestFor(itemID)
        if q then
            local Quests = FDJ.Quests
            local step = Quests and Quests.Step and Quests.Step(qid)
            local spot = Quests and Quests.Spot and Quests.Spot(qid)
            local steps = {}
            if step then
                steps[#steps + 1] = { L.PLAN_ROUTE_START:format(step.title or Quests.Title(step.qid)),
                    step.by and L.PLAN_ROUTE_FROM:format(step.by, step.at or q.at or "?") or "" }
                steps[#steps + 1] = { L.PLAN_ROUTE_CHAIN:format(step.index, step.count), q.at or "" }
            else
                steps[#steps + 1] = { L.PLAN_ROUTE_START:format(q.t), q.by and L.PLAN_ROUTE_FROM:format(q.by, q.at or "?") or (q.at or "") }
            end
            steps[#steps + 1] = { L.PLAN_ROUTE_REWARD:format(q.t), L.PLAN_ROUTE_REWARD_SUB:format(q.req or q.lv or 1) }
            return { steps = steps, pin = spot and { m = spot.m, x = spot.x, y = spot.y, label = q.t } }
        end
        local src = Plan.ItemSource and Plan.ItemSource[itemID]
        if src then
            local kind, what, where = src[1], src[2] or "", src[3] or ""
            local steps = {}
            if kind == "craft" then
                steps[1] = { L.PLAN_SRC_CRAFT:format(what), L.PLAN_SRC_CRAFT_SUB }
                if where ~= "" then steps[2] = { L.PLAN_SRC_RECIPE, where } end
            elseif kind == "world" then
                steps[1] = { L.PLAN_SRC_WORLD, where ~= "" and where or L.PLAN_SRC_WORLD_SUB }
            else
                local title = L["PLAN_SRC_" .. kind]
                steps[1] = { title and title:format(what) or what, where }
            end
            return { steps = steps }
        end
        return nil
    end

    paintCard = function()
        local open = state.open
        if not open then return end
        local picks = Plan.ItemsIn(open.group, state.view)
        local id = state.peek or picks[open.index] or state.firstOption
        card.itemID = id
        for _, st in ipairs(card.steps) do st:Hide() end
        card.spine:Hide()
        card.pin:Hide()
        card.journal:Hide()
        if not id then
            card.icon:SetTexture(nil)
            card.name:SetText(L.PLAN_NOTHING)
            card.name:SetTextColor(RGB(C.dim))
            card.sub:SetText(slotLabel(open.group, open.index))
            card.gain:SetText("")
            card.gainNote:SetText("")
            card.none:SetText(L.PLAN_ROUTE_EMPTY)
            card.none:Show()
            return
        end
        local name, qc = itemName(id)
        card.icon:SetTexture(C_Item.GetItemIconByID(id) or 134400)
        Kit.EdgeColor(card.iconEdge, qc or C.borderDim, qc and 0.9 or 1)
        card.name:SetText(name or L.LOADING)
        card.name:SetTextColor(RGB(qc or C.text))
        local status = mine() and Plan.State(open.group, id) or "missing"
        local statusText = status == "equipped" and FDJ.Paint("good", L.PLAN_EQUIPPED)
            or status == "owned" and FDJ.Paint("amber", L.PLAN_IN_BAGS) or FDJ.Paint("muted", L.PLAN_TO_GET)
        local planned = picks[open.index] == id
        card.sub:SetText(slotLabel(open.group, open.index) .. "  ·  " .. statusText
            .. (planned and "" or ("  ·  " .. FDJ.Paint("accent", L.PLAN_ROUTE_PREVIEW))))
        local weights = Measure.StatValues(nil, Plan.SpecOf(state.view))
        local txt, tone
        if mine() and status ~= "equipped" then txt, tone = upgradeText(wornScore(open.group, weights), Measure.ItemValue(id, weights)) end
        card.gain:SetText(txt or "")
        if tone then card.gain:SetTextColor(RGB(C[tone])) end
        card.gainNote:SetText(txt and L.PLAN_ROUTE_GAIN or "")

        local route = routeFor(id)
        card.none:SetShown(route == nil)
        if not route then
            card.none:SetText(L.PLAN_ROUTE_UNKNOWN)
            return
        end
        local y = 36 + 16
        for i, s in ipairs(route.steps) do
            local st = routeStep(i)
            st:ClearAllPoints()
            st:SetPoint("TOPLEFT", 0, -y)
            st:SetPoint("RIGHT")
            st.num:SetText(i)
            st.title:SetText(s[1])
            st.detail:SetText(s[2] or "")
            local last = i == #route.steps
            st.dot:SetVertexColor(RGB(last and C.accent or C.muted))
            st.track:SetShown(s.odds ~= nil)
            st.fill:SetShown(s.odds ~= nil)
            if s.odds then
                st.fill:SetWidth(math.max(2, 120 * math.min(1, s.odds / 100)))
            end
            st:Show()
            local used = (st.title:GetStringHeight() or 12) + 3 + (st.detail:GetStringHeight() or 10)
                + (s.odds and 9 or 0) + 10
            local h = math.max(STEP_H, math.ceil(used))
            st:SetHeight(h)
            y = y + h
        end
        card.spine:ClearAllPoints()
        card.spine:SetPoint("TOP", card.steps[1].dot, "CENTER", 0, -2)
        card.spine:SetPoint("BOTTOM", card.steps[#route.steps].dot, "CENTER", 0, 2)
        card.spine:Show()
        card.pin:SetShown(route.pin ~= nil)
        local pinned = pinnedAt(route.pin) ~= nil
        card.pin:SetLabel(pinned and L.PLAN_ROUTE_UNPIN or L.PLAN_ROUTE_PIN)
        card.pin:SetKind(pinned and nil or "primary")
        card.pin:SetScript("OnClick", function()
            togglePin(route.pin)
            refresh()
        end)
        card.journal:SetShown(route.dungeon ~= nil)
        if route.dungeon then
            card.journal:ClearAllPoints()
            if route.pin then card.journal:SetPoint("LEFT", card.pin, "RIGHT", 6, 0) else card.journal:SetPoint("BOTTOMLEFT") end
            card.journal:SetScript("OnClick", function()
                if FDJ.Journal and FDJ.Journal.Open then FDJ.Journal.Open(route.dungeon, "overview") end
            end)
        end
    end

    local function paintDrawer(width)
        local open = state.open
        if not open then
            drawer:Hide()
            return
        end
        drawer:Show()
        card:SetWidth(math.floor((width - 24) * 0.46))
        local capped = target() < (GetMaxPlayerLevel and GetMaxPlayerLevel() or 60)
        if not capped then state.any = false end
        drawer.any:SetShown(capped)
        drawer.search:ClearAllPoints()
        drawer.search:SetPoint("TOPLEFT")
        if capped then
            drawer.search:SetPoint("RIGHT", drawer.any, "LEFT", -6, 0)
        else
            drawer.search:SetPoint("RIGHT")
        end
        Kit.EdgeColor(drawer.any, state.any and C.accent or C.borderDim)
        drawer.any.label:SetTextColor(RGB(state.any and C.white or C.muted))
        local list = candidates(open.group)
        state.firstOption = list[1]
        local per = math.max(3, math.floor(((drawer:GetHeight() or DRAWER_H) - 24 - 30 - 24) / (OPT_H + 2)))
        local pages = math.max(1, math.ceil(#list / per))
        state.page = math.min(state.page, pages)
        local picks = Plan.ItemsIn(open.group, state.view)
        local weights = Measure.StatValues(nil, Plan.SpecOf(state.view))
        local worn = mine() and wornScore(open.group, weights) or 0
        local first = (state.page - 1) * per
        local shown = 0
        for i = 1, per do
            local id = list[first + i]
            if id then
                shown = shown + 1
                local b = optionButton(i)
                b.itemID = id
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 0, -(30 + (i - 1) * (OPT_H + 2)))
                b:SetPoint("RIGHT")
                local name, qc = itemName(id)
                b.icon:SetTexture(C_Item.GetItemIconByID(id) or 134400)
                b.name:SetText(name or L.LOADING)
                b.name:SetTextColor(RGB(qc or C.text))
                if b.quality then
                    local qn = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
                    local qcol = qn and qn >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qn]
                    if qcol then b.quality:SetVertexColor(qcol.r, qcol.g, qcol.b, 0.85) end
                    b.quality:SetShown(qcol and true or false)
                end
                b.name:SetWidth(math.max(90, math.floor(optsBox:GetWidth() * 0.45)))
                local boss, odds = Plan.Source(id)
                local q = not boss and Plan.QuestFor(id)
                b.from:SetText(boss and (FDJ.DungeonTitle(boss.dungeon) .. (odds and ("  ·  " .. ("%.1f%%"):format(odds)) or ""))
                    or (q and L.PLAN_QUESTS) or "")
                local txt, tone
                if mine() then txt, tone = upgradeText(worn, Measure.ItemValue(id, weights)) end
                b.gain:SetText(txt or "")
                if tone then b.gain:SetTextColor(RGB(C[tone])) end
                local here = picks[open.index] == id
                b.bg:SetColorTexture(RGB(here and C.accent or C.panel, here and 0.14 or (i % 2 == 0 and 0.35 or 0.6)))
                b.mark:SetColorTexture(RGB(C.accent, here and 1 or 0))
                b:Show()
            end
        end
        for i = shown + 1, #drawer.options do drawer.options[i]:Hide() end
        drawer.none:SetShown(shown == 0)
        drawer.prev:SetShown(state.page > 1)
        drawer.next:SetShown(state.page < pages)
        drawer.pageText:SetText(pages > 1 and (state.page .. " / " .. pages) or "")
        paintCard()
    end

    local weightsPanel
    local function buildWeights()
        local f = CreateFrame("Frame", nil, board)
        f:SetPoint("TOPLEFT", body, "TOPLEFT")
        f:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT")
        f:SetFrameLevel(body:GetFrameLevel() + 30)
        f:EnableMouse(true)
        Kit.Fill(f, C.frame, 0.98)
        Kit.Edge(f, C.accent, 0.4)
        f.back = Kit.Button(f, L.PLAN_BACK, nil, 24, function() f:Hide() end, nil, "fc:icon-chevron-left")
        f.back:SetPoint("TOPLEFT", 12, -12)
        f.title = Kit.Text(f, "large", C.white)
        f.title:SetPoint("LEFT", f.back, "RIGHT", 12, 0)
        f.title:SetText(L.PLAN_WEIGHTS_TITLE)
        f.close = Kit.CloseButton(f, function() f:Hide() end)
        f.close:SetPoint("TOPRIGHT", -6, -6)
        f.sub = Kit.Text(f, "small", C.muted)
        f.sub:SetPoint("TOPLEFT", f.back, "BOTTOMLEFT", 2, -10)
        f.hint = Kit.Text(f, "tiny", C.dim)
        f.hint:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -4)
        f.hint:SetText(L.PLAN_WEIGHTS_HINT)
        f.reset = Kit.Button(f, L.PLAN_RESET, nil, 24, function() Measure.ResetStatValues(nil, f.spec) end, nil, "fc:icon-reset")
        f.reset:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
        f.export = Kit.Button(f, L.EXPORT, nil, 24, function()
            Kit.TextWindow(L.PLAN_WEIGHTS_TITLE, Measure.ToText(nil, f.spec), nil, L.BIS_WEIGHTS_EXPORT_HINT)
        end)
        f.export:SetPoint("RIGHT", f.reset, "LEFT", -6, 0)
        f.import = Kit.Button(f, L.IMPORT, nil, 24, function()
            Kit.TextWindow(L.PLAN_WEIGHTS_TITLE, "", function(text) return Measure.FromText(text, nil, f.spec) end, L.BIS_WEIGHTS_IMPORT_HINT)
        end)
        f.import:SetPoint("RIGHT", f.export, "LEFT", -6, 0)
        local specs = Plan.Specs()
        local defs = {}
        for _, sp in ipairs(specs) do defs[#defs + 1] = { sp.key, sp.name } end
        if #defs > 0 then
            f.seg = Kit.Segmented(f, defs, function(key)
                f.spec = key
                f:Refill()
            end)
            f.seg:SetPoint("TOPLEFT", 16, -82)
            f.seg:SetWidth(math.min(420, #defs * 130))
        end
        f.cells = {}
        local shown = {}
        for _, st in ipairs(Measure.LIST) do
            if st.group ~= "res" then shown[#shown + 1] = st end
        end
        for i, st in ipairs(shown) do
            local cell = CreateFrame("Frame", nil, f)
            cell:SetSize(200, 26)
            cell.st = st
            cell.name = Kit.Text(cell, "small", C.text)
            cell.name:SetPoint("LEFT")
            cell.name:SetText(st.label .. (st.pct and FDJ.Paint("dim", "  %") or ""))
            cell.input = Kit.Input(cell, 58, 22, "0", nil, function(self, text)
                Measure.SetStatValue(st.id, tonumber(text) or 0, nil, f.spec)
            end)
            cell.input:SetPoint("RIGHT")
            cell.input:SetJustifyH("CENTER")
            cell.input:HookScript("OnEditFocusLost", function(self)
                local v = tonumber(self:GetText()) or 0
                if v ~= (Measure.StatValues(nil, f.spec)[st.id] or 0) then Measure.SetStatValue(st.id, v, nil, f.spec) end
            end)
            f.cells[i] = cell
        end
        function f:Arrange()
            local w = self:GetWidth() - 32
            local cols = math.max(1, math.floor((w + 24) / 224))
            local rows = math.ceil(#self.cells / cols)
            for i, cell in ipairs(self.cells) do
                local col, row = math.floor((i - 1) / rows), (i - 1) % rows
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", 16 + col * 224, -120 - row * 30)
            end
        end
        function f:Refill()
            self.spec = self.spec or Plan.SpecOf()
            if self.seg then self.seg:Select(self.spec, true) end
            local name = self.spec
            for _, sp in ipairs(Plan.Specs()) do if sp.key == self.spec then name = sp.name end end
            local w, custom = Measure.StatValues(nil, self.spec)
            self.sub:SetText((custom and L.PLAN_WEIGHTS_CUSTOM or L.PLAN_WEIGHTS_DEFAULT):format(name))
            for _, cell in ipairs(self.cells) do
                local v = w[cell.st.id] or 0
                if not cell.input:HasFocus() then cell.input:SetText(v ~= 0 and tostring(v) or "") end
                cell.name:SetTextColor(RGB(v ~= 0 and C.text or C.dim))
            end
        end
        f:SetScript("OnSizeChanged", function(self) self:Arrange() end)
        f:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then self:Hide() end end)
        for _, cell in ipairs(f.cells) do
            cell:EnableMouse(true)
            cell:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then f:Hide() end end)
        end
        f:SetScript("OnShow", function() weightsBtn:SetActive(true) end)
        f:SetScript("OnHide", function() weightsBtn:SetActive(false) end)
        FDJ:On("FDJ_GEAR_WEIGHTS", function() if f:IsVisible() then f:Refill() end end)
        f:Hide()
        return f
    end
    weightsBtn:SetScript("OnClick", function()
        weightsPanel = weightsPanel or buildWeights()
        if weightsPanel:IsShown() then
            weightsPanel:Hide()
            return
        end
        weightsPanel.spec = Plan.SpecOf()
        weightsPanel:Show()
        weightsPanel:Arrange()
        weightsPanel:Refill()
    end)

    local showcase = Plan.AttachStats and Plan.AttachStats(host, {
        view = function() return state.view end,
        mine = mine,
        focus = function(g, index)
            state.open = { group = g, index = index }
            state.page, state.query, state.peek = 1, "", nil
            refresh()
        end,
    })
    local function paintShowBtn()
        local on = showcase and showcase.IsOpen()
        showBtn:SetActive(on and true or false)
    end
    showBtn:SetShown(showcase ~= nil)
    showBtn:SetScript("OnClick", function()
        if showcase then showcase.Switch() end
        paintShowBtn()
    end)

    refresh = function()
        if not board:IsVisible() then return end
        local isMine = mine()
        viewing:SetShown(not isMine)
        if not isMine then
            local who = state.view
            local data = FDJ.db and FDJ.db.chars[who]
            viewing.text:SetText(L.PLAN_VIEWING:format(data and data.name or who))
        end
        anchorBody()
        paintTrack()
        paintPhases()
        local specName, specIcon = "", nil
        local cur = Plan.SpecOf(state.view)
        for _, sp in ipairs(Plan.Specs(state.view)) do
            if sp.key == cur then specName, specIcon = sp.name, sp.icon end
        end
        local listName = Plan.ActiveName(state.view)
        listBtn:SetLabel(specIcon and ("|T%s:14:14:0:0:64:64:5:59:5:59|t  %s  %s"):format(tostring(specIcon), specName, FDJ.Paint("dim", "·  " .. listName))
            or L.PLAN_LIST:format(listName))
        suggestBtn:SetEnabled(isMine)

        local weights = Measure.StatValues(nil, Plan.SpecOf(state.view))
        local worn = {}
        if isMine then
            for _, g in ipairs(Plan.GROUPS) do worn[g] = wornScore(g, weights) end
        end
        local W, H = body:GetWidth() or 0, body:GetHeight() or 0
        if W < 10 or H < 10 then return end
        local SPACING = 10
        local centreW = math.floor(math.max(220, math.min(380, W * 0.30)))
        local colW = math.floor((W - centreW - SPACING * 2) / 2)
        local rowsH = H - TILE_H - SPACING
        local tileH = math.max(34, math.min(TILE_H + 6, math.floor((rowsH - 7 * TILE_GAP) / 8)))
        colL:ClearAllPoints()
        colL:SetPoint("TOPLEFT")
        colL:SetSize(colW, rowsH)
        colR:ClearAllPoints()
        colR:SetPoint("TOPRIGHT")
        colR:SetSize(colW, rowsH)
        centre:ClearAllPoints()
        centre:SetPoint("TOPLEFT", colL, "TOPRIGHT", SPACING, 0)
        centre:SetPoint("BOTTOMRIGHT", colR, "BOTTOMLEFT", -SPACING, 0)
        bottom:ClearAllPoints()
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(TILE_H)
        local weaponW = math.floor((W - TILE_GAP * 2) / 3)

        local openTile
        for _, t in ipairs(tiles) do
            paintTile(t, weights, worn)
            t:ClearAllPoints()
            if t.side == "B" then
                t:SetPoint("TOPLEFT", bottom, "TOPLEFT", (t.row - 1) * (weaponW + TILE_GAP), 0)
                t:SetSize(weaponW, TILE_H)
            else
                local col = t.side == "L" and colL or colR
                t:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -((t.row - 1) * (tileH + TILE_GAP)))
                t:SetSize(colW, tileH)
            end
            if state.open and state.open.group == t.group and state.open.index == t.index then openTile = t end
        end

        if openTile then
            drawer:ClearAllPoints()
            if openTile.side == "L" then
                drawer:SetPoint("TOPLEFT", centre, "TOPLEFT", -SPACING + 4, 0)
                drawer:SetPoint("BOTTOMRIGHT", colR, "BOTTOMRIGHT")
            elseif openTile.side == "R" then
                drawer:SetPoint("TOPLEFT", colL, "TOPLEFT")
                drawer:SetPoint("BOTTOMRIGHT", centre, "BOTTOMRIGHT", SPACING - 4, 0)
            else
                drawer:SetPoint("TOPLEFT", colL, "TOPLEFT")
                drawer:SetPoint("BOTTOMRIGHT", colR, "BOTTOMRIGHT")
            end
            local dw = openTile.side == "B" and W or (W - colW - 4)
            paintDrawer(dw)
        else
            state.open = nil
            drawer:Hide()
        end
        if stage then stage.Update() end
        if showcase then showcase.Update() end
        paintShowBtn()
    end

    local function soon() FDJ.Debounce("planner" .. (host.isPopout and "pop" or "page"), 0.15, refresh) end
    FDJ:On("FDJ_WISHES", function() if board:IsVisible() then soon() end end)
    FDJ:On("FDJ_GEAR_ITEMS", function() if board:IsVisible() then soon() end end)
    FDJ:On("FDJ_WAYPOINTS", function() if board:IsVisible() and state.open then soon() end end)
    FDJ:On("FDJ_GEAR_WEIGHTS", function() if board:IsVisible() then soon() end end)
    FDJ:On("BAG_UPDATE_DELAYED", function() if board:IsVisible() then soon() end end)
    FDJ:On("GET_ITEM_INFO_RECEIVED", function(itemID)
        if requested[itemID] and board:IsVisible() then soon() end
    end)
    FDJ:On("FDJ_GEAR_OPTIONS", function() if root:IsVisible() then tabs:Select(tabs.current or "board") end end)
    board:SetScript("OnShow", function()
        refresh()
        if Plan.AutoFill then Plan.AutoFill() end
    end)
    root:SetScript("OnShow", function() tabs:Select(tabs.current or "board") end)
    tabs:Select("board")
end

buildSettings = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    local y = 6
    local checks = {}
    local function head(text)
        local t = Kit.Text(f, "tiny", C.accent)
        t:SetPoint("TOPLEFT", 0, -y)
        t:SetText(text:upper())
        y = y + 22
    end
    local function check(key, text, tip, getter, setter)
        local b = Kit.Check(f, text, getter or function() return Plan.Options()[key] end, setter or function(v) Plan.SetOption(key, v) end, tip)
        b:SetPoint("TOPLEFT", 0, -y)
        checks[#checks + 1] = b
        y = y + 28
    end
    head(L.PLAN_TITLE)
    check("enabled", L.PLAN_OPT_DISABLE, L.PLAN_OPT_DISABLE_TIP,
        function() return Plan.Options().enabled == false end,
        function(v) Plan.SetOption("enabled", not v) end)
    y = y + 8
    head(L.BIS_OPT_FEATURES)
    check("tooltip", L.PLAN_OPT_TOOLTIP, L.PLAN_OPT_TOOLTIP_TIP)
    check("alerts", L.PLAN_OPT_ALERTS, L.PLAN_OPT_ALERTS_TIP)
    do
        local label = Kit.Text(f, "small", C.text)
        label:SetPoint("TOPLEFT", 26, -(y + 6))
        label:SetText(L.PLAN_OPT_SOUND)
        local pick = Kit.Button(f, "", 170, 26, nil, "dropdown")
        pick:SetPoint("LEFT", label, "RIGHT", 12, 0)
        local function nameOf(key)
            for _, s in ipairs(FDJ.Gear.ALERT_SOUNDS) do if s[1] == key then return s[2] end end
            return key
        end
        local function show() pick:SetLabel(nameOf(Plan.Options().alertSound or "ping")) end
        pick:SetScript("OnClick", function(self)
            local items = {}
            for _, s in ipairs(FDJ.Gear.ALERT_SOUNDS) do
                local key = s[1]
                items[#items + 1] = { text = s[2], checked = (Plan.Options().alertSound or "ping") == key, onClick = function()
                    Plan.SetOption("alertSound", key)
                    FDJ.Gear.PlayAlertSound(key)
                    show()
                end }
            end
            Kit.Menu(self, items, 170)
        end)
        f:HookScript("OnShow", show)
        show()
        y = y + 34
    end
    check("alertBig", L.PLAN_OPT_BIG, L.PLAN_OPT_BIG_TIP)
    check("altClick", L.PLAN_OPT_CLICK, L.PLAN_OPT_CLICK_TIP)
    check("gearScore", L.BIS_OPT_GS, L.BIS_OPT_GS_TIP)
    check("autoSuggest", L.PLAN_OPT_AUTOFILL, L.PLAN_OPT_AUTOFILL_TIP)
    y = y + 8
    head(L.BIS_OPT_SHORTCUT)
    local label = Kit.Text(f, "small", C.text)
    label:SetPoint("TOPLEFT", 0, -(y + 6))
    label:SetText(L.PLAN_OPT_KEY)
    local key = Kit.Button(f, "", 150, 26)
    key:SetPoint("LEFT", label, "RIGHT", 12, 0)
    local hint = Kit.Text(f, "tiny", C.dim)
    hint:SetPoint("LEFT", key, "RIGHT", 10, 0)
    local function showKey()
        local k = Plan.Options().key or ""
        key:SetLabel(key.waiting and L.BIS_KEY_PRESS or (k ~= "" and (GetBindingText and GetBindingText(k) or k) or L.BIS_KEY_NONE))
        hint:SetText(key.waiting and L.BIS_KEY_WAIT or L.BIS_KEY_CHANGE)
    end
    key:SetScript("OnClick", function(self)
        self.waiting = true
        self:EnableKeyboard(true)
        showKey()
    end)
    key:SetScript("OnKeyDown", function(self, k)
        if not self.waiting then return end
        if k:match("SHIFT$") or k:match("CTRL$") or k:match("ALT$") then return end
        self.waiting = nil
        self:EnableKeyboard(false)
        if k ~= "ESCAPE" then
            if k == "BACKSPACE" or k == "DELETE" then
                k = ""
            else
                k = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. k
            end
            Plan.SetOption("key", k)
        end
        showKey()
    end)
    key:EnableKeyboard(false)
    y = y + 40
    Kit.Button(f, L.PLAN_POPOUT, nil, 26, function() Plan.ToggleWindow() end, nil, "fc:icon-export"):SetPoint("TOPLEFT", 0, -y)
    y = y + 40
    head(L.BIS_OPT_DATA)
    Kit.Button(f, L.PLAN_CLEAR, nil, 26, function()
        Kit.Confirm(L.PLAN_CLEAR_Q, function()
            wipe(Plan.ActivePicks())
            FDJ:Emit("FDJ_WISHES")
        end)
    end):SetPoint("TOPLEFT", 0, -y)
    f:SetScript("OnShow", function()
        for _, b in ipairs(checks) do b:Sync() end
        showKey()
    end)
    return f
end

function Addon.CreateGearPage(page)
    buildPlanner(page, -54, 0)
end

local window
function Plan.ToggleWindow()
    if not window then
        window = Kit.Window("FojjiCorePlanWindow", L.PLAN_TITLE, 1040, 700)
        window.isPopout = true
        window:SetFrameStrata("MEDIUM")
        local top = -46
        if Addon.Native and window.nativeChrome then
            window.head:SetAlpha(0)
            window.head:EnableMouse(false)
            top = -8
        else
            local icon = Kit.Glyph(window.head, MARK, 16, C.accent)
            icon:SetPoint("LEFT", 14, 0)
            window.title:ClearAllPoints()
            window.title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        end
        local pos = FDJ.db and FDJ.db.window
        if pos and pos.planW then window:SetSize(math.max(pos.planW, 900), math.max(pos.planH, 620)) end
        if pos and pos.planX then
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.planX, pos.planY)
        end
        function window:OnMoved()
            if pos then pos.planX, pos.planY = self:GetLeft(), self:GetTop() end
        end
        Kit.Resizable(window, 900, 620, function(self)
            if pos then
                pos.planW, pos.planH = self:GetWidth(), self:GetHeight()
                pos.planX, pos.planY = self:GetLeft(), self:GetTop()
            end
        end)
        buildPlanner(window, top, 12)
    end
    window:SetShown(not window:IsShown())
    if window:IsShown() then window:Raise() end
end
