local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever and Addon.DJ and Addon.DJ.Gear) then return end
local FDJ = Addon.DJ
local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Plan = FDJ.Gear
local Measure = Plan.Measure

local TRY_HAND = { [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT" }
local NO_TRY = { [18] = true }
local STATS_W = 300

local function outermost(f)
    local p = f
    for _ = 1, 20 do
        local up = p:GetParent()
        if not up or up == UIParent then break end
        p = up
    end
    return p
end

function Plan.BuildStage(parent, api)
    local stage = CreateFrame("Frame", nil, parent)
    Kit.Fill(stage, C.field, 0.35)
    local halo = stage:CreateTexture(nil, "BACKGROUND", nil, 1)
    halo:SetTexture(FDJ.Glyph("fc:stage-halo"))
    halo:SetPoint("CENTER", 0, 10)
    halo:SetBlendMode("ADD")
    local floor = stage:CreateTexture(nil, "BACKGROUND", nil, 2)
    floor:SetTexture(FDJ.Glyph("fc:stage-floor"))
    floor:SetPoint("BOTTOM", 0, 22)
    floor:SetBlendMode("ADD")
    stage:SetScript("OnSizeChanged", function(_, w)
        halo:SetSize(w * 1.25, w * 1.25)
        floor:SetSize(w * 0.85, w * 0.85 * 0.32)
    end)

    local specs = {}
    local function specPill(i)
        local b = specs[i]
        if b then return b end
        b = CreateFrame("Button", nil, stage)
        b:SetHeight(24)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.under = b:CreateTexture(nil, "ARTWORK")
        b.under:SetPoint("BOTTOMLEFT")
        b.under:SetPoint("BOTTOMRIGHT")
        b.under:SetHeight(2)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", 5, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.text = Kit.Text(b, "tiny", C.text)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
        b.text:SetPoint("RIGHT", -3, 0)
        if Addon.Native then
            b.native = true
            b:SetSize(64, 50)
            b.icon:ClearAllPoints()
            b.icon:SetSize(28, 28)
            b.icon:SetPoint("TOP", 0, -4)
            b.frameArt = b:CreateTexture(nil, "OVERLAY")
            b.frameArt:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            b.frameArt:SetSize(48, 48)
            b.frameArt:SetPoint("CENTER", b.icon, "CENTER")
            b.glow = b:CreateTexture(nil, "OVERLAY", nil, 1)
            b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            b.glow:SetBlendMode("ADD")
            b.glow:SetAllPoints(b.icon)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
            b.hl:SetBlendMode("ADD")
            b.hl:SetAllPoints(b.icon)
            b.text:ClearAllPoints()
            b.text:SetPoint("TOP", b.icon, "BOTTOM", 0, -3)
            b.text:SetWidth(70)
            b.text:SetJustifyH("CENTER")
            b.text:SetFontObject(GameFontNormalSmall)
        end
        b:SetScript("OnClick", function(self)
            if api.mine() and self.key then Plan.SetSpec(self.key) end
        end)
        specs[i] = b
        return b
    end

    local model = CreateFrame("DressUpModel", nil, stage)
    model:SetPoint("TOPLEFT", 4, Addon.Native and -58 or -34)
    model:SetPoint("BOTTOMRIGHT", -4, 22)
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model.turn, model.zoom = 0, 0

    local look = "set"
    local dress
    local peek = CreateFrame("Button", nil, stage)
    peek:SetSize(24, 24)
    peek:SetPoint("TOPRIGHT", model, "TOPRIGHT", -4, -4)
    peek:SetFrameLevel(model:GetFrameLevel() + 5)
    peek.disc = peek:CreateTexture(nil, "BACKGROUND")
    peek.disc:SetAllPoints()
    peek.disc:SetTexture(FDJ.Glyph("fc:ui-disc"))
    peek.glyph = Kit.Glyph(peek, "fc:icon-eye", 14, C.muted)
    peek.glyph:SetPoint("CENTER")
    local function paintPeek()
        local on = look == "worn"
        peek.disc:SetVertexColor(RGB(on and C.accent or C.field))
        peek.disc:SetAlpha(0.9)
        peek.glyph:SetVertexColor(RGB(on and C.white or C.muted))
    end
    local function setLook(key)
        if key == look then return end
        look = key
        paintPeek()
        if dress then dress() end
    end
    peek:SetScript("OnMouseDown", function() setLook("worn") end)
    peek:SetScript("OnMouseUp", function() setLook("set") end)
    peek:SetScript("OnHide", function() setLook("set") end)
    peek:SetScript("OnEnter", function(self) Kit.Tip(self, L.PLAN_FIT_WORN, L.PLAN_FIT_PEEK) end)
    peek:SetScript("OnLeave", function()
        Kit.HideTip()
        setLook("set")
    end)
    paintPeek()

    local hint = Kit.Text(stage, "tiny", C.dim, "CENTER")
    hint:SetPoint("BOTTOM", 0, 6)
    hint:SetPoint("LEFT", 4, 0)
    hint:SetPoint("RIGHT", -4, 0)
    hint:SetText(L.PLAN_FIT_HINT)

    local function turning(self)
        local x = GetCursorPosition()
        self.turn = self.turn + (x - self.fromX) * 0.011
        self.fromX = x
        pcall(self.SetFacing, self, self.turn)
    end
    local function takeDrop()
        local kind, id = GetCursorInfo()
        if kind == "item" and id and api.mine() then
            ClearCursor()
            Plan.AddItem(id)
            return true
        end
    end
    model:SetScript("OnReceiveDrag", takeDrop)
    model:SetScript("OnMouseDown", function(self, button)
        if takeDrop() then return end
        if button == "LeftButton" then
            self.fromX = GetCursorPosition()
            self:SetScript("OnUpdate", turning)
        else
            self.turn, self.zoom = 0, 0
            pcall(self.SetFacing, self, 0)
            pcall(self.SetPortraitZoom, self, 0)
        end
    end)
    model:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    model:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.max(0, math.min(0.75, self.zoom + delta * 0.08))
        pcall(self.SetPortraitZoom, self, self.zoom)
    end)

    local outfit, solo
    local function planned()
        local out = {}
        if look ~= "set" then return out end
        for _, g in ipairs(Plan.GROUPS) do
            local picks = Plan.ItemsIn(g, api.view())
            for i, slot in ipairs(g.slots) do
                local id = picks[i]
                if id and not NO_TRY[slot] then out[#out + 1] = { slot = slot, id = id } end
            end
        end
        return out
    end
    dress = function(force)
        if not model:IsVisible() then return end
        local wear = solo and { solo } or planned()
        local sig = { look, solo and "solo" or "all" }
        for _, w in ipairs(wear) do sig[#sig + 1] = w.slot .. ":" .. w.id end
        sig = table.concat(sig, ",")
        if sig == outfit and not force then return end
        outfit = sig
        if not model.loaded then
            pcall(model.SetUnit, model, "player")
            model.loaded = true
        end
        pcall(model.Dress, model)
        pcall(model.SetFacing, model, model.turn)
        pcall(model.SetPortraitZoom, model, model.zoom)
        if solo then pcall(model.Undress, model) end
        for _, w in ipairs(wear) do pcall(model.TryOn, model, "item:" .. w.id, TRY_HAND[w.slot]) end
    end
    model:SetScript("OnShow", function() outfit = nil dress() end)
    FDJ:On("PLAYER_EQUIPMENT_CHANGED", function()
        model.loaded = nil
        if model:IsVisible() then outfit = nil dress() end
    end)

    function stage.Solo(slot, itemID)
        if itemID and slot and not NO_TRY[slot] then solo = { slot = slot, id = itemID } else solo = nil end
        dress()
    end

    function stage.Update()
        halo:SetVertexColor(RGB(C.accent))
        halo:SetAlpha(0.3)
        floor:SetVertexColor(RGB(C.accent))
        floor:SetAlpha(0.45)
        local list = Plan.Specs(api.view())
        local cur = Plan.SpecOf(api.view())
        local w = stage:GetWidth() or 0
        local each = (w - 8 - (#list - 1) * 4) / math.max(1, #list)
        local x0 = math.floor((w - (#list * 64 + (#list - 1) * 10)) / 2)
        for i, sp in ipairs(list) do
            local b = specPill(i)
            b.key = sp.key
            b:ClearAllPoints()
            b.icon:SetTexture(sp.icon)
            b.text:SetText(sp.name)
            local on = sp.key == cur
            b:SetEnabled(api.mine())
            if b.native then
                b:SetPoint("TOPLEFT", x0 + (i - 1) * 74, -2)
                b.bg:SetColorTexture(0, 0, 0, 0)
                b.under:SetColorTexture(0, 0, 0, 0)
                b.glow:SetShown(on)
                b.icon:SetDesaturated(not on)
                b.icon:SetAlpha(on and 1 or 0.75)
                if on then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(0.62, 0.60, 0.56) end
            else
                b:SetPoint("TOPLEFT", 4 + (i - 1) * (each + 4), -4)
                b:SetWidth(each)
                b.bg:SetColorTexture(RGB(on and C.accent or C.panel, on and 0.18 or 0.7))
                b.under:SetColorTexture(RGB(C.accent, on and 1 or 0))
                b.text:SetTextColor(RGB(on and C.white or C.muted))
                b.icon:SetDesaturated(not on)
            end
            b:Show()
        end
        for i = #list + 1, #specs do specs[i]:Hide() end
        paintPeek()
        dress()
    end
    Kit.OnRepaint(function() if stage:IsVisible() then stage.Update() end end)
    return stage
end

function Plan.AttachStats(host, api)
    local edge = outermost(host)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetWidth(STATS_W)
    panel:EnableMouse(true)
    panel:Hide()
    Kit.Fill(panel, C.panel, 0.97)
    Kit.Edge(panel, C.borderDim)
    if Addon.Native and Addon.Skin then Addon.Skin.Panel(panel) end
    local seam = panel:CreateTexture(nil, "OVERLAY")
    seam:SetWidth(2)
    Kit.Paint(seam, C.accent, 0.8)

    local function place()
        panel:SetFrameStrata(edge:GetFrameStrata())
        panel:SetFrameLevel(edge:GetFrameLevel() + 20)
        local room = (UIParent:GetRight() or GetScreenWidth()) - (edge:GetRight() or 0)
        panel:ClearAllPoints()
        seam:ClearAllPoints()
        if room >= STATS_W + 8 then
            panel:SetPoint("TOPLEFT", edge, "TOPRIGHT", 2, -8)
            panel:SetPoint("BOTTOMLEFT", edge, "BOTTOMRIGHT", 2, 8)
            seam:SetPoint("TOPLEFT")
            seam:SetPoint("BOTTOMLEFT")
        else
            panel:SetPoint("TOPRIGHT", edge, "TOPLEFT", -2, -8)
            panel:SetPoint("BOTTOMRIGHT", edge, "BOTTOMLEFT", -2, 8)
            seam:SetPoint("TOPRIGHT")
            seam:SetPoint("BOTTOMRIGHT")
        end
    end

    local function label(text, y)
        local t = Kit.Text(panel, "tiny", C.accent)
        t:SetPoint("TOPLEFT", 16, -y)
        t:SetText(text:upper())
        return t
    end

    label(L.PLAN_STATS_SCORE, 16)
    local nowNum = Kit.Text(panel, "huge", C.text)
    nowNum:SetPoint("TOPLEFT", 16, -34)
    local arrow = Kit.Glyph(panel, "fc:icon-chevron-right", 14, C.dim)
    arrow:SetPoint("LEFT", nowNum, "RIGHT", 10, 0)
    local planNum = Kit.Text(panel, "huge", C.white)
    planNum:SetPoint("LEFT", arrow, "RIGHT", 10, 0)
    local gainTag = Kit.Text(panel, "small", C.good, "RIGHT")
    gainTag:SetPoint("TOPRIGHT", -16, -40)
    local nowCap = Kit.Text(panel, "tiny", C.dim)
    nowCap:SetPoint("TOPLEFT", nowNum, "BOTTOMLEFT", 0, -3)
    nowCap:SetText(L.PLAN_STATS_NOW)
    local planCap = Kit.Text(panel, "tiny", C.dim)
    planCap:SetPoint("TOPLEFT", planNum, "BOTTOMLEFT", 0, -3)
    planCap:SetText(L.PLAN_STATS_PLAN)

    local got = Kit.Text(panel, "tiny", C.muted)
    got:SetPoint("TOPLEFT", 16, -94)
    local track = panel:CreateTexture(nil, "ARTWORK")
    track:SetPoint("TOPLEFT", 16, -110)
    track:SetPoint("TOPRIGHT", -16, -110)
    track:SetHeight(3)
    Kit.Paint(track, C.field, 1)
    local fill = panel:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetHeight(3)
    Kit.Paint(fill, C.accent, 1)

    label(L.PLAN_STATS_TABLE, 132)
    local colNow = Kit.Text(panel, "tiny", C.dim, "RIGHT")
    colNow:SetPoint("TOPRIGHT", -112, -132)
    colNow:SetText(L.PLAN_STATS_NOW)
    local colPlan = Kit.Text(panel, "tiny", C.dim, "RIGHT")
    colPlan:SetPoint("TOPRIGHT", -62, -132)
    colPlan:SetText(L.PLAN_STATS_PLAN)
    local rows = {}
    local ROW_H = 20
    local function row(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, panel)
        r:SetHeight(ROW_H)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.name = Kit.Text(r, "small", C.text)
        r.name:SetPoint("LEFT", 8, 0)
        r.now = Kit.Text(r, "small", C.muted, "RIGHT")
        r.now:SetPoint("RIGHT", -96, 0)
        r.plan = Kit.Text(r, "small", C.white, "RIGHT")
        r.plan:SetPoint("RIGHT", -46, 0)
        r.diff = Kit.Text(r, "tiny", C.good, "RIGHT")
        r.diff:SetPoint("RIGHT", -6, 0)
        rows[i] = r
        return r
    end

    local upHead = label(L.PLAN_STATS_UPS, 0)
    local ups = {}
    local UP_H = 30
    local function upRow(i)
        local r = ups[i]
        if r then return r end
        r = CreateFrame("Button", nil, panel)
        r:SetHeight(UP_H)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(RGB(C.field, 0.6))
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(RGB(C.accent, 0.08))
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(22, 22)
        r.icon:SetPoint("LEFT", 6, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Kit.Text(r, "small", C.white)
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1)
        r.name:SetPoint("RIGHT", -52, 0)
        r.slot = Kit.Text(r, "tiny", C.dim)
        r.slot:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, -1)
        r.gain = Kit.Text(r, "small", C.good, "RIGHT")
        r.gain:SetPoint("RIGHT", -8, 0)
        r:SetScript("OnClick", function(self) if self.group and api.focus then api.focus(self.group, self.index) end end)
        r:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ups[i] = r
        return r
    end
    local upsNone = Kit.Text(panel, "small", C.dim)
    upsNone:SetText(L.PLAN_STATS_UPS_NONE)

    local open = false
    function panel.Update()
        if not panel:IsShown() then return end
        local weights = Measure.StatValues(nil, Plan.SpecOf(api.view()))
        local mine = api.mine()
        local worn = mine and Measure.Worn() or {}
        local planSet = Measure.PlannedSet(api.view(), mine)
        local a = Measure.Sum(worn)
        local b = Measure.Sum(planSet)
        local gsA = Measure.GearScore(worn, weights)
        local gsB = Measure.GearScore(planSet, weights)
        nowNum:SetText(mine and gsA or "-")
        planNum:SetText(gsB)
        if mine and gsA > 0 and gsB ~= gsA then
            gainTag:SetText(("%+.0f%%"):format((gsB - gsA) / gsA * 100))
            gainTag:SetTextColor(RGB(gsB > gsA and C.good or C.bad))
        else
            gainTag:SetText("")
        end

        local have, total = 0, 0
        for _, g in ipairs(Plan.GROUPS) do
            if not g.optional then
                local picks = Plan.ItemsIn(g, api.view())
                for i = 1, #g.slots do
                    total = total + 1
                    local id = picks[i]
                    local st = id and mine and Plan.State(g, id)
                    if st == "equipped" or st == "owned" then have = have + 1 end
                end
            end
        end
        got:SetText(L.PLAN_FIT_GOT:format(have, total))
        fill:SetWidth(math.max(0.01, (track:GetWidth() or 0) * (total > 0 and have / total or 0)))
        fill:SetShown(have > 0)

        local list = {}
        for _, st in ipairs(Measure.LIST) do
            local w = weights[st.id] or 0
            local va, vb = a[st.id] or 0, b[st.id] or 0
            if w > 0 or math.abs(va) >= 0.05 or math.abs(vb) >= 0.05 then
                if math.abs(va) >= 0.05 or math.abs(vb) >= 0.05 then list[#list + 1] = { st = st, a = va, b = vb, w = w } end
            end
        end
        table.sort(list, function(x, y)
            if (x.w > 0) ~= (y.w > 0) then return x.w > 0 end
            return x.w > y.w
        end)
        local top = 152
        local room = math.floor(((panel:GetHeight() or 600) - top - 4 * 33 - 50) / ROW_H)
        local shown = 0
        for i, e in ipairs(list) do
            if i > room then break end
            shown = i
            local r = row(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 12, -(top + (i - 1) * ROW_H))
            r:SetPoint("RIGHT", -12, 0)
            r.bg:SetColorTexture(RGB(C.field, i % 2 == 1 and 0.5 or 0.2))
            local pct = e.st.pct or e.st.id == "DPS"
            local function fmt(v) return pct and ("%.1f"):format(v) or tostring(math.floor(v + 0.5)) end
            r.name:SetText(e.st.label)
            r.name:SetTextColor(RGB(e.w > 0 and C.text or C.dim))
            r.now:SetText(mine and fmt(e.a) or "-")
            r.plan:SetText(fmt(e.b))
            local d = e.b - e.a
            if mine and math.abs(d) >= 0.05 then
                r.diff:SetText((d > 0 and "+" or "") .. fmt(d))
                r.diff:SetTextColor(RGB(d > 0 and C.good or C.bad))
            else
                r.diff:SetText("")
            end
            r:Show()
        end
        for i = shown + 1, #rows do rows[i]:Hide() end

        local found = {}
        if mine then
            for _, g in ipairs(Plan.GROUPS) do
                local picks = Plan.ItemsIn(g, api.view())
                local base
                for idx = 1, #g.slots do
                    local id = picks[idx]
                    if id and Plan.State(g, id) == "missing" then
                        if not base then
                            base = math.huge
                            for _, slot in ipairs(g.slots) do
                                local w = GetInventoryItemID("player", slot)
                                local v = w and Measure.ItemValue(w, weights) or 0
                                if v < base then base = v end
                            end
                        end
                        local v = Measure.ItemValue(id, weights) or 0
                        if v > base then found[#found + 1] = { g = g, i = idx, id = id, gain = v - base, base = base } end
                    end
                end
            end
        end
        table.sort(found, function(x, y) return x.gain > y.gain end)
        local count = math.min(4, #found)
        local y0 = (panel:GetHeight() or 600) - 14 - count * (UP_H + 3)
        upHead:ClearAllPoints()
        upHead:SetPoint("TOPLEFT", 16, -(y0 - 22))
        for k = 1, count do
            local e = found[k]
            local r = upRow(k)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 12, -(y0 + (k - 1) * (UP_H + 3)))
            r:SetPoint("RIGHT", -12, 0)
            r.group, r.index, r.itemID = e.g, e.i, e.id
            local name, _, q = C_Item.GetItemInfo(e.id)
            local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            r.icon:SetTexture(C_Item.GetItemIconByID(e.id) or 134400)
            r.name:SetText(name or "...")
            if qc then r.name:SetTextColor(qc.r, qc.g, qc.b) else r.name:SetTextColor(RGB(C.white)) end
            r.slot:SetText(Plan.SlotName(e.g))
            r.gain:SetText(e.base >= 4 and ("+%.0f%%"):format(math.min(999, e.gain / e.base * 100)) or ("+" .. math.floor(e.gain + 0.5)))
            r:Show()
        end
        for k = count + 1, #ups do ups[k]:Hide() end
        upsNone:ClearAllPoints()
        upsNone:SetPoint("BOTTOMLEFT", 16, 16)
        upsNone:SetShown(count == 0)
        if count == 0 then
            upHead:ClearAllPoints()
            upHead:SetPoint("BOTTOMLEFT", upsNone, "TOPLEFT", 0, 8)
        end
    end

    local function show(on)
        open = on
        if on then
            place()
            panel:Show()
            panel.Update()
        else
            panel:Hide()
        end
    end
    local out = {}
    function out.Switch()
        local want = not open
        if FDJ.db and FDJ.db.window then FDJ.db.window.showcase = want end
        show(want)
        return want
    end
    function out.IsOpen() return open end
    function out.Update() panel.Update() end

    local function hidden() show(false) end
    host:HookScript("OnHide", hidden)
    if edge ~= host then edge:HookScript("OnHide", hidden) end
    host:HookScript("OnShow", function()
        if FDJ.db and FDJ.db.window and FDJ.db.window.showcase and edge:IsShown() then show(true) end
    end)
    edge:HookScript("OnDragStop", function() if open then place() end end)
    if edge.head then edge.head:HookScript("OnDragStop", function() if open then place() end end) end
    panel:SetScript("OnSizeChanged", function() if open then panel.Update() end end)
    FDJ:On("PLAYER_EQUIPMENT_CHANGED", function() if open then panel.Update() end end)
        Kit.OnRepaint(function() if open then panel.Update() end end)
    return out
end
