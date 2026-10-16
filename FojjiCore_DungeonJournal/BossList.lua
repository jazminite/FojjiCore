local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Runs = FDJ.Runs

local BossList = {}
BossList.__index = BossList
FDJ.BossList = BossList

local ICON = 26
local GAP = 4
local DOT = "   ·   "

function BossList.New(parent, wide)
    local self = setmetatable({}, BossList)
    self.open = {}
    self.wide = wide
    self.filter = ""
    local frame = CreateFrame("Frame", nil, parent)
    self.frame = frame
    local scroll = Kit.Scroller(frame)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT")
    self.scroll = scroll
    self.rows = Kit.Pool(function() return self:MakeRow() end)
    self.heads = Kit.Pool(function()
        local h = CreateFrame("Frame", nil, self.scroll.content)
        h:SetHeight(26)
        h.text = Kit.Text(h, "tiny", C.muted)
        h.text:SetPoint("BOTTOMLEFT", 2, 6)
        h.line = h:CreateTexture(nil, "ARTWORK")
        h.line:SetHeight(1)
        h.line:SetPoint("LEFT", h.text, "RIGHT", 10, 0)
        h.line:SetPoint("RIGHT", h, "RIGHT", 0, 0)
        Kit.Paint(h.line, C.borderDim)
        return h
    end)
    local function refresh()
        if frame:IsVisible() then self:Refresh() end
    end
    FDJ:On("FDJ_KILLS", refresh)
    FDJ:On("FDJ_WISHES", refresh)
    FDJ:On("GET_ITEM_INFO_RECEIVED", function()
        if frame:IsVisible() then FDJ.Debounce("bosslist" .. tostring(self), 0.1, refresh) end
    end)
    FDJ:On("ITEM_DATA_LOAD_RESULT", function()
        if frame:IsVisible() then FDJ.Debounce("bosslist" .. tostring(self), 0.1, refresh) end
    end)
    FDJ:On("SPELL_DATA_LOAD_RESULT", function()
        if frame:IsVisible() then FDJ.Debounce("bossspell" .. tostring(self), 0.2, refresh) end
    end)
    frame:SetScript("OnShow", function() self:Refresh() end)
    return self
end

function BossList:SetDungeon(d)
    if self.dungeon ~= d then
        self.dungeon = d
        self.open = {}
        self.scroll:To(0)
    end
    self:Refresh()
end

function BossList:SetFilter(text)
    self.filter = (text or ""):lower()
    self:Refresh()
end

function BossList:Expand(boss, only)
    if only then self.open = {} end
    self.open[boss] = true
    self:Refresh()
    if self.offsets and self.offsets[boss] then self.scroll:To(self.offsets[boss]) end
end

function BossList:ExpandAll(on)
    self.open = {}
    if on and self.dungeon then
        for _, boss in ipairs(self.dungeon.bosses) do self.open[boss] = true end
    end
    self:Refresh()
end

function BossList:AllOpen()
    if not self.dungeon then return false end
    for _, boss in ipairs(self.dungeon.bosses) do
        if not self.open[boss] then return false end
    end
    return true
end

local function itemMatches(itemID, needle)
    if needle == "" then return true end
    local name = C_Item.GetItemInfo(itemID)
    return name ~= nil and name:lower():find(needle, 1, true) ~= nil
end

local function spellRow(parent, wide)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(wide and 40 or 24)
    b.icon = Kit.SpellIcon(b, wide and 26 or 20)
    b.icon:SetPoint("TOPLEFT", 0, wide and -2 or -1)
    b.name = Kit.Text(b, "small", C.white)
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, wide and -1 or -3)
    b.name:SetPoint("RIGHT")
    if wide then
        b.desc = Kit.Text(b, "small", C.muted)
        b.desc:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
        b.desc:SetWordWrap(true)
        b.desc:SetJustifyV("TOP")
        b.desc:SetSpacing(2)
    end
    return b
end

local function lootIcon(parent)
    local b = Kit.ItemIcon(parent, ICON)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.star = b:CreateTexture(nil, "OVERLAY", nil, 7)
    b.star:SetSize(12, 12)
    b.star:SetPoint("TOPRIGHT", 3, 3)
    b.star:SetTexture(FDJ.Glyph("mark-star"))
    b.star:SetVertexColor(RGB(C.amber))
    b.oddsBack = b:CreateTexture(nil, "OVERLAY", nil, 5)
    b.oddsBack:SetPoint("BOTTOMLEFT", 1, 1)
    b.oddsBack:SetPoint("BOTTOMRIGHT", -1, 1)
    b.oddsBack:SetHeight(10)
    b.oddsBack:SetColorTexture(0, 0, 0, 0.72)
    b.oddsBack:Hide()
    b.odds = Kit.Text(b, "tiny", C.quest, "RIGHT", "OVERLAY")
    b.odds:SetDrawLayer("OVERLAY", 7)
    b.odds:SetShadowColor(0, 0, 0, 1)
    b.odds:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetScript("OnClick", function(self, button)
        if not self.itemID then return end
        if button == "RightButton" then
            Runs.ToggleWish(self.itemID)
            return
        end
        local _, link = C_Item.GetItemInfo(self.itemID)
        if link and IsModifiedClick() then HandleModifiedItemClick(link) end
    end)
    return b
end

local function lootRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(36)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hl = Kit.Fill(row, C.white, 0, "BACKGROUND", 1)
    row.icon = Kit.ItemIcon(row, 28)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:EnableMouse(false)
    row.star = row.icon:CreateTexture(nil, "OVERLAY", nil, 7)
    row.star:SetSize(13, 13)
    row.star:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -4, 4)
    row.star:SetTexture(FDJ.Glyph("mark-star"))
    row.star:SetVertexColor(RGB(C.amber))
    row.odds = Kit.Text(row, "small", C.white, "RIGHT")
    row.odds:SetPoint("RIGHT", -6, 0)
    row.odds:SetWidth(44)
    row.name = Kit.Text(row, "small", C.text)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -1)
    row.name:SetPoint("RIGHT", row.odds, "LEFT", -6, 0)
    row.kind = Kit.Text(row, "tiny", C.muted)
    row.kind:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.kind:SetPoint("RIGHT", row.odds, "LEFT", -6, 0)
    row:SetScript("OnEnter", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0.04)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:AddLine(FDJ.WishHint(self.itemID), 1, 0.72, 0.3)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0)
        Kit.HideTip()
    end)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Runs.ToggleWish(self.itemID)
            return
        end
        local _, link = C_Item.GetItemInfo(self.itemID)
        if link and IsModifiedClick() then HandleModifiedItemClick(link) end
    end)
    function row:SetItem(itemID, odds)
        self.itemID = itemID
        self.icon:SetItem(itemID)
        local name, _, quality, _, _, kind, subKind, _, slot = C_Item.GetItemInfo(itemID)
        if not name then FDJ.RequestItem(itemID, true) end
        local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        self.name:SetText(name or L.LOADING)
        if qc then self.name:SetTextColor(qc.r, qc.g, qc.b) else self.name:SetTextColor(RGB(C.text)) end
        local bits = {}
        local slotName = slot and slot ~= "" and _G[slot]
        if slotName then bits[#bits + 1] = slotName end
        if subKind and subKind ~= "" then bits[#bits + 1] = subKind elseif kind then bits[#bits + 1] = kind end
        local tag = FDJ.TagOf[itemID]
        if tag then bits[#bits + 1] = FDJ.Paint(tag == "added" and "good" or "amber", tag == "added" and L.TAG_ADDED or L.TAG_REWORKED) end
        if FDJ.QuestNeeds[itemID] then bits[#bits + 1] = FDJ.Paint("quest", L.QUEST_ITEM) end
        self.kind:SetText(table.concat(bits, FDJ.Paint("dim", "  ·  ")))
        self.odds:SetText(odds and (odds .. "%") or "")
        Runs.PaintMark(self.star, itemID)
    end
    return row
end

function BossList:MakeRow()
    local wide = self.wide
    local row = CreateFrame("Frame", nil, self.scroll.content)
    local head = Kit.Row(row, wide and 56 or 40)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    row.head = head
    if wide then
        head.bg = Kit.Fill(head, C.panel, 0.55, "BACKGROUND", 0)
        head.rule:Hide()
        head.strip = head:CreateTexture(nil, "ARTWORK")
        head.strip:SetPoint("TOPLEFT")
        head.strip:SetPoint("BOTTOMLEFT")
        head.strip:SetWidth(2)
        head.glow = Kit.Gradient(head, "HORIZONTAL", C.accent, 0.16, 0, "BACKGROUND", 1)
        head.glow:SetPoint("TOPLEFT")
        head.glow:SetPoint("BOTTOMLEFT")
        head.glow:SetWidth(260)
        head.glow:Hide()
    end
    row.portrait = Kit.Portrait(head, wide and 40 or 28)
    row.portrait:SetPoint("LEFT", wide and 12 or 6, 0)
    row.portrait:EnableMouse(false)
    row.check = head:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(14, 14)
    row.check:SetPoint("BOTTOMRIGHT", row.portrait, "BOTTOMRIGHT", 3, -2)
    row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    row.chev = Kit.Glyph(head, "fc:icon-chevron-down", 12, C.dim)
    row.chev:SetPoint("RIGHT", -10, 0)
    row.spells = {}
    if wide then
        for i = 1, 6 do
            local s = Kit.SpellIcon(head, 24)
            if i == 1 then s:SetPoint("RIGHT", row.chev, "LEFT", -16, 0) else s:SetPoint("RIGHT", row.spells[i - 1], "LEFT", -4, 0) end
            row.spells[i] = s
        end
    end
    row.lootIcons = {}
    if wide then
        for i = 1, 8 do
            local b = Kit.ItemIcon(head, 24)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b.star = b:CreateTexture(nil, "OVERLAY", nil, 7)
            b.star:SetSize(10, 10)
            b.star:SetPoint("TOPRIGHT", 3, 3)
            b.star:SetTexture(FDJ.Glyph("mark-star"))
            b.star:SetVertexColor(RGB(C.amber))
            b:HookScript("OnEnter", function(self)
                if not self.itemID then return end
                GameTooltip:AddLine(FDJ.WishHint(self.itemID), 1, 0.72, 0.3)
                GameTooltip:Show()
            end)
            b:SetScript("OnClick", function(self, button)
                if not self.itemID then return end
                if button == "RightButton" then
                    Runs.ToggleWish(self.itemID)
                    return
                end
                local _, link = C_Item.GetItemInfo(self.itemID)
                if link and IsModifiedClick() then HandleModifiedItemClick(link) end
            end)
            b:Hide()
            row.lootIcons[i] = b
        end
    end
    if wide then
        row.div = head:CreateTexture(nil, "ARTWORK")
        row.div:SetSize(1, 24)
        row.div:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.9)
    end
    local right = wide and row.spells[6] or row.chev
    row.name = Kit.Text(head, wide and "normal" or "small", C.white)
    row.name:SetPoint("TOPLEFT", row.portrait, "TOPRIGHT", wide and 12 or 9, wide and -3 or -1)
    row.name:SetPoint("RIGHT", right, "LEFT", -10, 0)
    row.tags = {}
    for i = 1, 2 do
        local t = CreateFrame("Frame", nil, head)
        t:SetHeight(14)
        t.bg = t:CreateTexture(nil, "BACKGROUND")
        t.bg:SetAllPoints()
        t.text = Kit.Text(t, "tiny", C.white, "CENTER")
        t.text:SetPoint("CENTER", 0, 0)
        function t:Set(label, c)
            self.text:SetText(label)
            self.text:SetTextColor(c[1], c[2], c[3])
            self.bg:SetColorTexture(c[1], c[2], c[3], 0.18)
            self:SetWidth(self.text:GetStringWidth() + 10)
            self:Show()
        end
        t:Hide()
        row.tags[i] = t
    end
    row.meta = Kit.Text(head, "tiny", C.dim)
    row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.meta:SetPoint("RIGHT", right, "LEFT", -10, 0)
    head:SetScript("OnClick", function(_, button)
        local boss = row.boss
        if button == "RightButton" then
            Kit.Menu(head, {
                { text = boss.n, title = true },
                { text = L.SHOW_BOSS_MAP, onClick = function() FDJ.Journal.Open(boss.dungeon, "map", boss) end },
                { text = Runs.Killed(boss) and L.UNMARK_KILL or L.MARK_KILL, onClick = function()
                    if Runs.Killed(boss) then
                        FDJ.char.run.kills[boss.dungeon.key][boss.index] = nil
                        FDJ:Emit("FDJ_KILLS")
                    else
                        Runs.Mark(boss)
                    end
                end },
                { text = L.POST_ABILITIES, disabled = not boss.spells, onClick = function() FDJ.Journal.PostAbilities(boss) end },
            })
            return
        end
        self.open[boss] = not self.open[boss] or nil
        self:Refresh()
        if self.onToggle then self.onToggle() end
    end)
    local body = CreateFrame("Frame", nil, row)
    body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)
    body.bg = Kit.Fill(body, C.field, 0.55)
    Kit.Line(body, "BOTTOM", C.borderDim, 0.6)
    row.body = body
    row.abilityTitle = Kit.Section(body, "")
    row.abilityTitle:SetText(L.ABILITIES:upper())
    row.lootTitle = Kit.Section(body, "")
    row.lootTitle:SetText(L.LOOT:upper())
    row.spellRows = {}
    row.loot = {}
    return row
end

function BossList:Body(row, boss)
    local body = row.body
    local wide = self.wide
    local inset = wide and 56 or 14
    local width = math.max(160, self.scroll.content:GetWidth() - inset - 14)
    local y = 12
    for _, s in ipairs(row.spellRows) do s:Hide() end
    for _, l in ipairs(row.loot) do l:Hide() end
    if boss.spells and #boss.spells > 0 and self.filter == "" then
        row.abilityTitle:ClearAllPoints()
        row.abilityTitle:SetPoint("TOPLEFT", inset, -y)
        row.abilityTitle:Show()
        y = y + 18
        for i, spell in ipairs(boss.spells) do
            local s = row.spellRows[i]
            if not s then
                s = spellRow(body, wide)
                row.spellRows[i] = s
            end
            s.icon:SetSpell(spell)
            s.name:SetText(C_Spell.GetSpellName(spell) or ("#" .. spell))
            local h = 24
            if wide then
                local desc = C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spell) or ""
                if type(desc) ~= "string" then desc = "" end
                s.desc:SetWidth(width - 40)
                s.desc:SetText(desc)
                h = math.max(32, 20 + (desc ~= "" and s.desc:GetStringHeight() or 0)) + 8
            end
            s:SetHeight(h)
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", inset, -y)
            s:SetPoint("RIGHT", body, "RIGHT", -14, 0)
            s:Show()
            y = y + h
        end
        y = y + 6
    else
        row.abilityTitle:Hide()
    end
    row.lootTitle:ClearAllPoints()
    row.lootTitle:SetPoint("TOPLEFT", inset, -y)
    row.lootTitle:SetText(#boss.loot == 0 and (L.LOOT:upper() .. "  ·  NOT KNOWN YET") or L.LOOT:upper())
    y = y + 18
    local items = {}
    for i, itemID in ipairs(boss.loot) do
        if itemMatches(itemID, self.filter) then items[#items + 1] = { itemID, boss.odds and boss.odds[i] } end
    end
    if wide then
        local cols = width > 560 and 2 or 1
        local colW = (width - (cols - 1) * 16) / cols
        for i, entry in ipairs(items) do
            local r = row.loot[i]
            if not r then
                r = lootRow(body)
                row.loot[i] = r
            end
            local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", inset + col * (colW + 16), -(y + line * 38))
            r:SetWidth(colW)
            r:SetItem(entry[1], entry[2])
            r:Show()
        end
        y = y + math.ceil(#items / cols) * 38 + 10
    else
        local perRow = math.max(1, math.floor((width + GAP) / (ICON + GAP)))
        for i, entry in ipairs(items) do
            local b = row.loot[i]
            if not b then
                b = lootIcon(body)
                row.loot[i] = b
            end
            local col, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", inset + col * (ICON + GAP), -(y + line * (ICON + GAP)))
            b:SetItem(entry[1])
            Runs.PaintMark(b.star, entry[1])
            b.odds:SetText(entry[2] and (math.floor(entry[2] + 0.5) .. "%") or "")
            b.oddsBack:SetShown(entry[2] ~= nil)
            b:Show()
        end
        y = y + math.ceil(#items / perRow) * (ICON + GAP) + 10
    end
    body:SetHeight(y)
    return y
end

function BossList:Refresh()
    self.rows:Reset()
    local d = self.dungeon
    if not d then return end
    self.offsets = {}
    self.heads:Reset()
    local y = 0
    local nextBoss = nil
    local lastFloor
    local floorHeads = self.wide and #d.floors > 1 and self.filter == ""
    for _, boss in ipairs(d.bosses) do
        local matches = self.filter == ""
        if not matches then
            for _, itemID in ipairs(boss.loot) do
                if itemMatches(itemID, self.filter) then matches = true break end
            end
        end
        if matches and floorHeads and boss.f ~= lastFloor then
            lastFloor = boss.f
            local h = self.heads:Get()
            h:SetPoint("TOPLEFT", 0, -y)
            h:SetPoint("RIGHT", self.scroll.content, "RIGHT")
            h.text:SetText(FDJ.FloorLabel(d, boss.f):upper())
            y = y + 26
        end
        if matches then
            local row = self.rows:Get()
            row.boss = boss
            self.offsets[boss] = y
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", self.scroll.content, "RIGHT")
            row.portrait:SetCreature(boss.face, boss.icon)
            local dead = Runs.Killed(boss)
            row.portrait.face:SetDesaturated(dead)
            row.portrait.ring:SetVertexColor(RGB(boss.rare and C.info or C.border))
            row.check:SetShown(dead)
            local isNext = boss == nextBoss
            if row.head.strip then
                local c = isNext and C.accent or (dead and C.good or C.border)
                row.head.strip:SetColorTexture(c[1], c[2], c[3], (isNext or dead) and 1 or 0.7)
                row.head.glow:SetShown(isNext)
                row.head.strip:SetWidth(isNext and 3 or 2)
            end
            row.head:SetAlpha(dead and 0.6 or 1)
            row.name:SetText(FDJ.Paint("dim", boss.index .. ".") .. "  " .. boss.n)
            row.name:SetTone(dead and C.muted or C.white)
            local bits = {}
            if boss.lv then
                local c = GetQuestDifficultyColor and GetQuestDifficultyColor(boss.lv)
                local lvText = L.LEVEL .. " " .. boss.lv
                if c and not dead then lvText = ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, lvText) end
                bits[#bits + 1] = lvText
            end
            if boss.rare and not self.wide then bits[#bits + 1] = FDJ.Paint("info", L.RARE) end
            if self.wide and #d.floors > 1 and not floorHeads then bits[#bits + 1] = FDJ.FloorLabel(d, boss.f) end
            if not self.wide or #boss.loot > 8 then bits[#bits + 1] = L.ITEMS_N:format(#boss.loot) end
            local wished = 0
            for _, item in ipairs(boss.loot) do if Runs.IsWished(item) then wished = wished + 1 end end
            if wished > 0 then bits[#bits + 1] = FDJ.Paint("amber", L.WISHED_N:format(wished)) end
            row.meta:SetText(table.concat(bits, FDJ.Paint("dim", DOT)))
            local tagN = 0
            local function tag(label, c)
                tagN = tagN + 1
                local t = row.tags[tagN]
                t:ClearAllPoints()
                if tagN == 1 then
                    t:SetPoint("LEFT", row.name, "LEFT", row.name:GetStringWidth() + 8, 0)
                else
                    t:SetPoint("LEFT", row.tags[tagN - 1], "RIGHT", 4, 0)
                end
                t:Set(label, c)
            end
            for _, t in ipairs(row.tags) do t:Hide() end
            if self.wide then
                if isNext then tag("NEXT", C.accent) end
                if boss.rare then tag("RARE", C.info) end
            end
            local edge = row.chev
            for i, s in ipairs(row.spells) do
                local spell = boss.spells and boss.spells[i]
                if spell then
                    s:SetSpell(spell)
                    s:Show()
                    edge = s
                else
                    s:Hide()
                end
            end
            local spellEdge = edge ~= row.chev and edge or nil
            local shownLoot = 0
            for i, b in ipairs(row.lootIcons) do
                local itemID = boss.loot[i]
                if itemID then
                    b:SetItem(itemID)
                    Runs.PaintMark(b.star, itemID)
                    b:ClearAllPoints()
                    b:SetPoint("RIGHT", edge, "LEFT", (i == 1) and (edge == row.chev and -14 or -18) or -4, 0)
                    b:Show()
                    edge = b
                    shownLoot = shownLoot + 1
                else
                    b:Hide()
                end
            end
            if row.div then
                row.div:ClearAllPoints()
                if spellEdge and shownLoot > 0 then
                    row.div:SetPoint("RIGHT", spellEdge, "LEFT", -9, 0)
                    row.div:Show()
                else
                    row.div:Hide()
                end
            end
            if self.wide then
                row.name:ClearAllPoints()
                row.name:SetPoint("TOPLEFT", row.portrait, "TOPRIGHT", 12, -3)
                row.name:SetPoint("RIGHT", edge, "LEFT", -10, 0)
                row.meta:ClearAllPoints()
                row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
                row.meta:SetPoint("RIGHT", edge, "LEFT", -10, 0)
            end
            local open = self.open[boss] or self.filter ~= ""
            local height = row.head:GetHeight()
            if open then
                row.body:Show()
                row.chev:SetTexture(FDJ.Glyph("fc:icon-chevron-up"))
                height = height + self:Body(row, boss)
            else
                row.body:Hide()
                row.chev:SetTexture(FDJ.Glyph("fc:icon-chevron-down"))
            end
            row:SetHeight(height)
            y = y + height + (self.wide and 3 or 0)
        end
    end
    self.scroll:SetContentHeight(y)
    local missing = false
    for _, boss in ipairs(d.bosses) do
        for _, itemID in ipairs(boss.loot) do
            if C_Item.GetItemInfo(itemID) == nil then
                missing = true
                FDJ.RequestItem(itemID, true)
            end
        end
    end
    if missing and not self.retrying then
        self.retrying = true
        C_Timer.After(3, function()
            self.retrying = nil
            if self.frame:IsVisible() then self:Refresh() end
        end)
    end
end
