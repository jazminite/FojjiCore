local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L
local RGB = Kit.RGB
local Quests = FDJ.Quests
local Routes = FDJ.Routes
local Runs = FDJ.Runs

local Journal = {}
FDJ.Journal = Journal

local W, H = 1080, 720
local SIDE = 250
local HEAD = 39
local top = 0
local shell
local host
local BANNER = 106
local bannerH = BANNER
local PAD = 22

local window, sidebar, content, banner, tabs, tabRule
local pages = {}
local current
local home
local filter = "all"
local search = ""

local function matches(d)
    if filter == "level" and not FDJ.FitsLevel(d) then return false end
    if filter == "quests" then
        local s = Quests.Summary(d)
        if s.open + s.active + s.ready == 0 then return false end
    end
    if search == "" then return true end
    local needle = search:lower()
    if FDJ.DungeonTitle(d):lower():find(needle, 1, true) or d.zone:lower():find(needle, 1, true) then return true end
    for _, boss in ipairs(d.bosses) do
        if boss.n:lower():find(needle, 1, true) then return true end
        for _, item in ipairs(boss.loot) do
            local name = C_Item.GetItemInfo(item)
            if name and name:lower():find(needle, 1, true) then return true end
        end
    end
    for _, qid in ipairs(d.quests) do
        if Quests.Title(qid):lower():find(needle, 1, true) then return true end
    end
    return false
end

local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local READY_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"

local function buildSidebar()
    sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 1, -top)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDE)
    Kit.Fill(sidebar, C.sidebar)
    Kit.Line(sidebar, "RIGHT", C.borderDim)

    local box = Kit.Input(sidebar, SIDE - 66, 30, L.SEARCH_HINT, function(_, text)
        search = text or ""
        Journal.RefreshList()
    end, nil, "fc:icon-search")
    box:SetPoint("TOPLEFT", 16, -16)
    do
        local where = Kit.IconButton(sidebar, "ui-waypoint", 30, L.WHERE_AM_I, function()
            Journal.Select(FDJ.SuggestedDungeon())
        end, "ghost")
        where.tipBody = L.WHERE_AM_I_TIP
        where:SetPoint("LEFT", box, "RIGHT", 4, 0)
    end

    local seg = Kit.Segmented(sidebar, { { "all", L.FILTER_ALL }, { "level", L.FILTER_LEVEL }, { "quests", L.FILTER_QUESTS } }, function(key)
        filter = key
        Journal.RefreshList()
    end)
    seg:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -10)
    seg:SetPoint("RIGHT", sidebar, "RIGHT", -16, 0)
    seg:Select("all", true)

    local scroll = Kit.Scroller(sidebar)
    scroll:SetPoint("TOPLEFT", 8, -100)
    scroll:SetPoint("BOTTOMRIGHT", -6, 10)
    sidebar.scroll = scroll

    sidebar.rows = Kit.Pool(function()
        local row = CreateFrame("Button", nil, scroll.content)
        row:SetHeight(30)
        row.glow = Kit.Gradient(row, "HORIZONTAL", C.accent, 0.26, 0, "BACKGROUND", 1)
        row.glow:SetAllPoints()
        row.hl = Kit.Fill(row, C.white, 0, "BACKGROUND", 2)
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetPoint("TOPLEFT")
        row.mark:SetPoint("BOTTOMLEFT")
        row.mark:SetWidth(3)
        Kit.Paint(row.mark, C.accent)
        row.name = Kit.Text(row, "small", C.text)
        row.side = row:CreateTexture(nil, "ARTWORK")
        row.side:SetTexture(FDJ.media .. "ui-dot")
        row.side:SetSize(6, 6)
        row.side:SetPoint("RIGHT", row.name, "LEFT", -5, 0)
        row.range = Kit.Text(row, "tiny", C.muted, "RIGHT")
        row.range:SetPoint("RIGHT", -10, 0)
        row.badge = Kit.Badge(row, C.quest)
        row.badge:SetPoint("RIGHT", row.range, "LEFT", -10, 0)
        row.name:SetPoint("RIGHT", row.badge, "LEFT", -6, 0)
        row:SetScript("OnEnter", function(self)
            if not self.dungeon then return end
            if self.dungeon ~= current then self.hl:SetColorTexture(1, 1, 1, 0.04) end
            local s = Quests.Summary(self.dungeon)
            Kit.Tip(self, FDJ.DungeonTitle(self.dungeon), {
                { L.ZONE, self.dungeon.zone },
                { L.LEVELS, self.dungeon.range[1] .. "-" .. self.dungeon.range[2] },
                { L.BOSSES, tostring(#self.dungeon.bosses) },
                { L.QUESTS, L.QUEST_SUMMARY:format(s.open, s.active + s.ready, s.done) },
            })
        end)
        row:SetScript("OnLeave", function(self)
            self.hl:SetColorTexture(1, 1, 1, 0)
            Kit.HideTip()
        end)
        row:SetScript("OnClick", function(self)
            if self.dungeon then Journal.Select(self.dungeon) end
        end)
        return row
    end)
end

function Journal.RefreshList()
    if not sidebar then return end
    sidebar.rows:Reset()
    local y, lastFamily = 0, nil
    local list = sidebar.scroll.content
    for _, d in ipairs(FDJ.Dungeons) do
        if matches(d) then
            if d.family and d.family ~= lastFamily then
                local head = sidebar.rows:Get()
                head.dungeon = nil
                head:SetHeight(24)
                head:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
                head:SetPoint("RIGHT", list, "RIGHT")
                head.name:ClearAllPoints()
                head.name:SetPoint("BOTTOMLEFT", 12, 6)
                head.name:SetPoint("RIGHT", -10, 0)
                Kit.SetFont(head.name, "tiny")
                head.name:SetTone(C.muted)
                head.name:SetText(d.family:upper())
                head.range:SetText("")
                head.badge:Hide()
                head.side:Hide()
                head.mark:Hide()
                head.glow:Hide()
                y = y + 24
            end
            lastFamily = d.family
            local row = sidebar.rows:Get()
            row.dungeon = d
            row:SetHeight(25)
            row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", list, "RIGHT")
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", d.family and 26 or 14, 0)
            row.name:SetPoint("RIGHT", row.badge, "LEFT", -6, 0)
            Kit.SetFont(row.name, 11)
            row.name:SetText(d.family and d.name or FDJ.DungeonTitle(d))
            local side = FDJ.DungeonSide(d)
            row.side:SetShown(side ~= nil)
            if side then
                local c = side == "Alliance" and C.alliance or C.horde
                row.side:SetVertexColor(c[1], c[2], c[3], FDJ.IsEnemyDungeon(d) and 0.45 or 0.9)
            end
            local selected = d == current and not (home and home:IsShown())
            row.name:SetTone(selected and C.white or C.text)
            row.range:SetText(d.range[1] .. "-" .. d.range[2])
            row.range:SetTone(FDJ.ListRangeColor(d, C.dim))
            local s = Quests.Summary(d)
            if s.ready > 0 then
                row.badge:Set(s.ready, C.quest, READY_ICON)
            else
                row.badge:Set(s.open + s.active, C.quest, QUEST_ICON)
            end
            row.mark:SetShown(selected)
            row.glow:SetShown(selected)
            y = y + 25
        end
    end
    sidebar.scroll:SetContentHeight(y + 8)
    if home and home:IsShown() then Journal.RefreshHome() end
end

local function buildBanner()
    banner = CreateFrame("Frame", nil, content)
    banner:SetPoint("TOPLEFT")
    banner:SetPoint("TOPRIGHT")
    banner:SetHeight(BANNER)
    banner:SetClipsChildren(true)
    banner.art = banner:CreateTexture(nil, "BACKGROUND", nil, 1)
    banner.art:SetAllPoints()
    banner.fade = Kit.Gradient(banner, "HORIZONTAL", C.content, 1, 0.15, "BACKGROUND", 2)
    banner.fade:SetPoint("TOPLEFT")
    banner.fade:SetPoint("BOTTOMLEFT")
    banner.fade:SetPoint("RIGHT", banner, "CENTER", 120, 0)
    banner.fade2 = Kit.Gradient(banner, "HORIZONTAL", C.content, 0.15, 0, "BACKGROUND", 2)
    banner.fade2:SetPoint("TOPLEFT", banner.fade, "TOPRIGHT")
    banner.fade2:SetPoint("BOTTOMRIGHT")
    banner.under = Kit.Gradient(banner, "VERTICAL", C.content, 1, 0, "BACKGROUND", 3)
    banner.under:SetPoint("BOTTOMLEFT")
    banner.under:SetPoint("BOTTOMRIGHT")
    banner.under:SetHeight(64)
    banner.over = Kit.Gradient(banner, "VERTICAL", C.content, 0, 0.55, "BACKGROUND", 3)
    banner.over:SetPoint("TOPLEFT")
    banner.over:SetPoint("TOPRIGHT")
    banner.over:SetHeight(34)

    local back = CreateFrame("Button", nil, banner)
    back.glyph = Kit.Glyph(back, "fc:icon-chevron-right", 10, C.muted)
    back.glyph:SetTexCoord(1, 0, 0, 1)
    back.glyph:SetPoint("LEFT")
    back.text = Kit.Text(back, "small", C.muted)
    back.text:SetPoint("LEFT", back.glyph, "RIGHT", 5, 0)
    back.text:SetText(L.ALL_DUNGEONS or "All dungeons")
    back:SetSize(back.text:GetStringWidth() + 22, 18)
    back:SetPoint("TOPLEFT", PAD - 2, -12)
    back:SetScript("OnEnter", function(self) self.text:SetTone(C.white); self.glyph:SetVertexColor(1, 1, 1) end)
    back:SetScript("OnLeave", function(self) self.text:SetTone(C.muted); self.glyph:SetVertexColor(C.muted[1], C.muted[2], C.muted[3]) end)
    back:SetScript("OnClick", function() Journal.Home() end)
    banner.back = back

    banner.name = Addon.Localize(banner:CreateFontString(nil, "OVERLAY"))
    banner.name:SetFont(FDJ.Font(), 24, "")
    banner.name:SetTextColor(1, 0.82, 0)
    banner.name:SetShadowColor(0, 0, 0, 1)
    banner.name:SetShadowOffset(1, -1)
    banner.name:SetPoint("TOPLEFT", PAD, -36)
    banner.badge = Journal.MakeBadge(banner, 30)
    banner.badge:SetPoint("RIGHT", banner.name, "LEFT", -10, -1)
    banner.meta = Kit.Text(banner, "small", C.text)
    banner.meta:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 1, -8)

    local world = Kit.Button(banner, L.ENTRANCE_WP, nil, 26, function()
        if not current then return end
        local spot = FDJ.EntranceSpot(current.key)
        if spot then
            FDJ.Pins.WaypointAt(spot.m, spot.x, spot.y, FDJ.DungeonTitle(current))
        else
            FDJ:Emit("FDJ_DOCK_DUNGEON", current)
            FDJ.Pins.OpenMap(FDJ.ZoneMap(current.zone))
        end
    end, nil, "ui-waypoint")
    world:SetPoint("TOPRIGHT", -PAD, -14)
    world.tip = L.ENTRANCE_WP_TIP
    function world.Refresh()
        local here = FDJ.CurrentDungeon()
        world:SetShown(current ~= nil and not (here and here.key == current.key))
    end
    FDJ:On("FDJ_ENTERED", world.Refresh)
    FDJ:On("PLAYER_ENTERING_WORLD", world.Refresh)
    banner.world = world
    banner:SetScript("OnSizeChanged", function() if current then Journal.PaintBannerArt() end end)
end

function Journal.PaintBannerArt()
    local d = current
    local w, h = banner:GetWidth(), bannerH
    if not d or w < 10 then return end
    local tex, u1, u2, vMid, vPerPx
    local cover = Journal.CoverFor(d)
    local screen = FDJ.LoadScreens and FDJ.LoadScreens[d.key]
    if screen then
        banner.art:SetTexture(screen, nil, nil, "TRILINEAR")
        local id = banner.art.GetTextureFileID and banner.art:GetTextureFileID()
        if not id or id == 0 then screen = nil end
    end
    if screen then
        tex, u1, u2, vMid = screen, 0.02, 0.98, 0.50
        vPerPx = 0.96 / w
    elseif d.art then
        tex, u1, u2, vMid = d.art[2], 0, 0.70, 0.34
        vPerPx = (0.70 * 1024 / w) / 512
    elseif cover then
        tex, u1, u2, vMid = cover, 0, 1, 0.5
        vPerPx = (256 / 140) / w
    end
    if not tex then
        banner.art:Hide()
        return
    end
    local span = math.min(0.6, h * vPerPx)
    banner.art:SetTexture(tex, nil, nil, "TRILINEAR")
    banner.art:SetTexCoord(u1, u2, vMid - span / 2, vMid + span / 2)
    banner.art:SetAlpha(0.85)
    banner.art:Show()
end

function Journal.LayoutBanner()
    if not banner then return end
    local small = bannerH ~= BANNER
    local side = current and FDJ.DungeonSide(current)
    banner:SetHeight(bannerH)
    banner.back:ClearAllPoints()
    banner.back:SetPoint("TOPLEFT", PAD - 2, small and -8 or -12)
    banner.back:Show()
    banner.world:ClearAllPoints()
    banner.world:SetPoint("TOPRIGHT", -PAD, small and -28 or -14)
    banner.name:SetFont(FDJ.Font(), small and 20 or 24, "")
    banner.name:ClearAllPoints()
    banner.name:SetPoint("TOPLEFT", side and (PAD + 40) or PAD, small and -32 or -36)
    banner.meta:ClearAllPoints()
    if small then
        banner.meta:SetPoint("LEFT", banner.name, "RIGHT", 16, -1)
    else
        banner.meta:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 1, -8)
    end
    banner.under:SetHeight(small and 30 or 64)
end

local function paintBanner()
    local d = current
    if not d then return end
    banner.name:SetText(FDJ.DungeonTitle(d))
    local side = FDJ.DungeonSide(d)
    banner.badge:SetSide(side, FDJ.IsEnemyDungeon(d))
    Journal.LayoutBanner()
    local dot = FDJ.Paint("dim", "   ·   ")
    local tag = FDJ.FactionTag(d)
    local key = FDJ.KeyBadge(d)
    banner.meta:SetText(d.zone .. (tag and (dot .. tag) or "") .. dot .. L.LEVELS .. " " .. FDJ.Paint(FDJ.RangeColor(d), d.range[1] .. "-" .. d.range[2]) .. dot .. L.BOSSES_N:format(#d.bosses) .. (key and (dot .. key) or ""))
    if tabs and tabs.buttons.access then tabs.buttons.access:SetShown(FDJ.AccessList(d) ~= nil) end
    Journal.PaintBannerArt()
end

local focused = false

local function anchorPage(f)
    f:ClearAllPoints()
    local top = focused and -14 or (f.tall and -(bannerH + 4)) or (f.snug and -(bannerH + 34)) or -(bannerH + 44)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, top)
    f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -PAD, f.snug and 8 or 16)
end

function Journal.AnchorPages()
    for _, page in pairs(pages) do anchorPage(page) end
end

local function pageFrame()
    local f = CreateFrame("Frame", nil, content)
    anchorPage(f)
    f:Hide()
    return f
end

local function buildOverview()
    local f = pageFrame()
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(30)
    f.progress = Kit.Text(bar, "small", C.muted)
    f.progress:SetPoint("LEFT", 2, 0)
    local reset = Kit.Button(bar, L.RESET_RUN, nil, 26, function() Runs.Reset() end, nil, "fc:icon-reset")
    reset:SetPoint("RIGHT")
    reset.tip = L.RESET_RUN_TIP
    local expand
    expand = Kit.Button(bar, L.EXPAND_ALL, nil, 26, function()
        f.list:ExpandAll(not f.list:AllOpen())
        f:SyncExpand()
    end, nil, "fc:icon-chevron-down")
    expand:SetPoint("RIGHT", reset, "LEFT", -8, 0)
    local search = Kit.Input(bar, 190, 26, L.SEARCH_LOOT, function(_, text) f.list:SetFilter(text) end, nil, "fc:icon-search")
    search:SetPoint("RIGHT", expand, "LEFT", -8, 0)
    f.track = bar:CreateTexture(nil, "ARTWORK")
    f.track:SetSize(140, 4)
    f.track:SetPoint("LEFT", f.progress, "RIGHT", 12, 0)
    Kit.Paint(f.track, C.field)
    f.fill = bar:CreateTexture(nil, "OVERLAY")
    f.fill:SetHeight(4)
    f.fill:SetPoint("LEFT", f.track, "LEFT")
    Kit.Paint(f.fill, C.accent)
    Kit.Line(bar, "BOTTOM", C.borderDim, 0.8)
    local holder = CreateFrame("Frame", nil, f)
    holder:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
    holder:SetPoint("BOTTOMRIGHT", 0, 0)
    f.list = FDJ.BossList.New(holder, true)
    f.list.frame:SetAllPoints()
    function f:SyncExpand()
        local all = self.list:AllOpen()
        expand:SetLabel(all and L.COLLAPSE_ALL or L.EXPAND_ALL)
        expand.glyph:SetTexture(FDJ.Glyph(all and "fc:icon-chevron-up" or "fc:icon-chevron-down"))
    end
    f.list.onToggle = function() f:SyncExpand() end
    FDJ:On("FDJ_KILLS", function() if f:IsVisible() and current then f:Refresh() end end)
    function f:Refresh()
        local d = current
        local kills = Runs.Count(d)
        self.progress:SetText(L.RUN_PROGRESS:format(FDJ.Paint("white", kills), FDJ.Paint("white", #d.bosses)))
        local share = #d.bosses > 0 and math.min(1, kills / #d.bosses) or 0
        self.fill:SetWidth(math.max(0.01, 140 * share))
        self.fill:SetShown(share > 0)
        self.list:SetDungeon(d)
        self:SyncExpand()
    end
    FDJ:On("FDJ_KILLS", function() if f:IsVisible() then f:Refresh() end end)
    pages.overview = f
end

local function classMarkup(class, size)
    local def = class and Routes.MarkByKey["c_" .. class:lower()]
    if not def then return "" end
    return Routes.MarkIcon(def, size) .. " "
end

local function buildWishlist()
    local f = pageFrame()
    local scroll = Kit.Scroller(f)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT")
    f.empty = Kit.Text(scroll, "normal", C.muted, "CENTER")
    f.empty:SetPoint("TOPLEFT", 10, -40)
    f.empty:SetPoint("TOPRIGHT", -10, -40)
    f.empty:SetWordWrap(true)
    f.empty:SetText(L.WISHLIST_EMPTY)
    f.heads = Kit.Pool(function()
        local h = CreateFrame("Frame", nil, scroll.content)
        h:SetHeight(38)
        h.bg = Kit.Fill(h, C.panel, 0.7)
        Kit.Line(h, "BOTTOM", C.borderDim)
        h.name = Kit.Text(h, "normal", C.white)
        h.name:SetPoint("LEFT", 8, 0)
        h.meta = Kit.Text(h, "small", C.muted, "RIGHT")
        h.meta:SetPoint("RIGHT", -10, 0)
        return h
    end)
    f.rows = Kit.Pool(function()
        local row = Kit.Row(scroll.content, 40)
        row.rule:SetAlpha(0.3)
        row.icon = Kit.ItemIcon(row, 28)
        row.icon:SetPoint("LEFT", 14, 0)
        row.icon:EnableMouse(false)
        row.name = Kit.Text(row, "small", C.text)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
        row.name:SetPoint("RIGHT", -70, 0)
        row.from = Kit.Text(row, "tiny", C.muted)
        row.from:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.from:SetPoint("RIGHT", -70, 0)
        row.odds = Kit.Text(row, "small", C.white, "RIGHT")
        row.odds:SetPoint("RIGHT", -10, 0)
        row:SetScript("OnEnter", function(self)
            self:Hover(true)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.bis and L.WISHLIST_BIS_HINT or L.WISHLIST_ROW_HINT, 0.6, 0.6, 0.65)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self:Hover(false)
            Kit.HideTip()
        end)
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if self.bis then
                    if FDJ.Plan and FDJ.Plan.ToggleWindow then FDJ.Plan.ToggleWindow() end
                else
                    Runs.ToggleWish(self.itemID, self.charKey)
                end
                return
            end
            local _, link = C_Item.GetItemInfo(self.itemID)
            if link and IsModifiedClick() then
                HandleModifiedItemClick(link)
                return
            end
            if self.boss then Journal.Open(self.boss.dungeon, "overview", self.boss) end
        end)
        return row
    end)
    function f:Refresh()
        self.heads:Reset()
        self.rows:Reset()
        local y = 0
        local any = false
        local chars = Runs.WishCharacters()
        local bis = {}
        if FDJ.Gear and FDJ.Gear.Wanted then
            for itemID, plan in pairs(FDJ.Gear.Wanted()) do
                local ok, have = pcall(Runs.Owns, itemID)
                if not (ok and have) then bis[itemID] = plan end
            end
        end
        if next(bis) and not (chars[1] and chars[1].me) then
            table.insert(chars, 1, { key = FDJ.charKey, wishes = {}, class = select(2, UnitClass("player")), name = FDJ.PlayerName(), me = true })
        end
        for _, who in ipairs(chars) do
            local items, seen = {}, {}
            local function add(itemID, plan)
                if seen[itemID] then return end
                seen[itemID] = true
                local source = FDJ.LootSources[itemID] and FDJ.LootSources[itemID][1]
                items[#items + 1] = { itemID = itemID, boss = source and source.boss, odds = source and source.odds, plan = plan }
            end
            for itemID in pairs(who.wishes) do add(itemID) end
            if who.me then for itemID, plan in pairs(bis) do add(itemID, plan) end end
            table.sort(items, function(a, b)
                local da = a.boss and a.boss.dungeon.index or 999
                local db = b.boss and b.boss.dungeon.index or 999
                if da ~= db then return da < db end
                return a.itemID < b.itemID
            end)
            if #items > 0 then
                any = true
                local h = self.heads:Get()
                h:SetPoint("TOPLEFT", 0, -y)
                h:SetPoint("RIGHT", scroll.content, "RIGHT")
                local c = FDJ.Party.ClassColor(who.class)
                h.name:SetText(classMarkup(who.class, 18) .. FDJ.Paint(c, who.name) .. (who.me and FDJ.Paint("dim", "  " .. L.WISHLIST_YOU) or ""))
                h.meta:SetText(L.ITEMS_N:format(#items))
                y = y + 42
                for _, w in ipairs(items) do
                    local row = self.rows:Get()
                    row.itemID, row.boss, row.charKey, row.bis = w.itemID, w.boss, who.key, w.plan ~= nil
                    row:SetPoint("TOPLEFT", 0, -y)
                    row:SetPoint("RIGHT", scroll.content, "RIGHT")
                    row.icon:SetItem(w.itemID)
                    local name, _, quality = C_Item.GetItemInfo(w.itemID)
                    if not name then C_Item.RequestLoadItemDataByID(w.itemID) end
                    row.name:SetText(name or L.LOADING)
                    local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                    if qc then row.name:SetTextColor(qc.r, qc.g, qc.b) else row.name:SetTextColor(RGB(C.text)) end
                    local from = ""
                    if w.boss then
                        local d = w.boss.dungeon
                        from = FDJ.DungeonTitle(d) .. "  " .. FDJ.Paint(FDJ.RangeColor(d), d.range[1] .. "-" .. d.range[2]) .. FDJ.Paint("dim", "   ·   ") .. w.boss.n
                    elseif w.plan and FDJ.Gear.QuestFor then
                        local q, qid = FDJ.Gear.QuestFor(w.itemID)
                        if q then from = L.WISHLIST_QUEST:format(FDJ.Quests.Title(qid)) end
                    end
                    if w.plan then
                        from = from .. (from ~= "" and FDJ.Paint("dim", "   ·   ") or "") .. FDJ.Paint("accent", L.WISHLIST_BIS:format(w.plan))
                    end
                    row.from:SetText(from)
                    row.odds:SetText(w.odds and (w.odds .. "%") or "")
                    y = y + 40
                end
                y = y + 12
            end
        end
        self.empty:SetShown(not any)
        scroll:SetContentHeight(y)
    end
    FDJ:On("FDJ_WISHES", function() if f:IsVisible() then f:Refresh() end end)
    FDJ:On("BAG_UPDATE_DELAYED", function() if f:IsVisible() then FDJ.Debounce("wishpage", 0.5, function() f:Refresh() end) end end)
    FDJ:On("PLAYER_EQUIPMENT_CHANGED", function() if f:IsVisible() then FDJ.Debounce("wishpage", 0.5, function() f:Refresh() end) end end)
    FDJ:On("GET_ITEM_INFO_RECEIVED", function()
        if f:IsVisible() then FDJ.Debounce("wishpage", 0.2, function() f:Refresh() end) end
    end)
    pages.wishlist = f
end

local function sideValue(v)
    if type(v) == "table" then return v[FDJ.Faction() or ""] end
    return v
end

function FDJ.AccessList(d)
    return d and FDJ.Access and FDJ.Access[d.key]
end

function FDJ.AccessHas(entry)
    local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(entry.item, true)) or (GetItemCount and GetItemCount(entry.item, true)) or 0
    if count > 0 then return true end
    for _, q in ipairs(entry.have or {}) do
        if C_QuestLog.IsQuestFlaggedCompleted(q) or FDJ.Quests.InLog(q) then return true end
    end
    return false
end

function FDJ.AccessRequired(d)
    for _, entry in ipairs(FDJ.AccessList(d) or {}) do
        if entry.need == "required" then return entry end
    end
end

local KEY_ICON = "Interface\\AddOns\\FojjiCore\\textures\\UI\\icon-key"
function FDJ.KeyBadge(d, size)
    local entry = FDJ.AccessRequired(d)
    if not entry then return nil end
    size = size or 14
    if FDJ.AccessHas(entry) then
        return ("|T%s:%d:%d:0:0:64:64:0:64:0:64:255:209:76|t "):format(KEY_ICON, size, size) .. FDJ.Paint("good", L.ACCESS_KEY)
    end
    return ("|T%s:%d:%d:0:0:64:64:0:64:0:64:140:140:150|t "):format(KEY_ICON, size, size) .. FDJ.Paint("bad", L.ACCESS_NO_KEY)
end

local function stepState(step)
    local q = sideValue(step.q)
    if q then
        if C_QuestLog.IsQuestFlaggedCompleted(q) then return "done" end
        if FDJ.Quests.InLog(q) then return "active" end
        return "todo"
    end
    if step.item then
        local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(step.item, true)) or 0
        if count > 0 then return "done" end
    end
    return "todo"
end

local function buildAccess()
    local f = pageFrame()
    local scroll = Kit.Scroller(f)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT")
    f.cards = {}
    f.steps = Kit.Pool(function()
        local r = CreateFrame("Button", nil, scroll.content)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.num = CreateFrame("Frame", nil, r)
        r.num:SetSize(22, 22)
        r.num:SetPoint("TOPLEFT", 0, -2)
        r.num.bg = Kit.Fill(r.num, C.field, 1)
        Kit.Edge(r.num, C.borderDim)
        r.num.t = Kit.Text(r.num, "small", C.white, "CENTER")
        r.num.t:SetPoint("CENTER", 0, 0)
        r.num.check = r.num:CreateTexture(nil, "OVERLAY")
        r.num.check:SetSize(16, 16)
        r.num.check:SetPoint("CENTER")
        r.num.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        r.title = Kit.Text(r, "normal", C.white)
        r.title:SetPoint("TOPLEFT", r.num, "TOPRIGHT", 10, -1)
        r.state = Kit.Text(r, "tiny", C.muted)
        r.state:SetPoint("LEFT", r.title, "RIGHT", 8, 0)
        r.note = Kit.Text(r, "small", C.muted)
        r.note:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
        r.note:SetPoint("RIGHT", -40, 0)
        r.note:SetWordWrap(true)
        r.note:SetJustifyH("LEFT")
        r.pin = Kit.IconButton(r, "ui-waypoint", 24, L.ACCESS_PIN, function()
            local st = r.step
            local m, x, y = st and sideValue(st.m), st and sideValue(st.x), st and sideValue(st.y)
            if m and x and y then FDJ.Pins.WaypointAt(m, x / 100, y / 100, Addon.Tr(sideValue(st.npc) or sideValue(st.t))) end
        end)
        r.pin:SetPoint("TOPRIGHT", -4, -2)
        return r
    end)
    local function card(i)
        local c = f.cards[i]
        if c then return c end
        c = CreateFrame("Frame", nil, scroll.content)
        c.bg = Kit.Fill(c, C.panel, 0.7)
        Kit.Edge(c, C.borderDim)
        c.stripe = c:CreateTexture(nil, "ARTWORK")
        c.stripe:SetPoint("TOPLEFT", 1, -1)
        c.stripe:SetPoint("BOTTOMLEFT", 1, 1)
        c.stripe:SetWidth(3)
        c.icon = Kit.ItemIcon(c, 44)
        c.icon:SetPoint("TOPLEFT", 14, -14)
        c.name = Kit.Text(c, "large", C.white)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, -2)
        c.need = Kit.Text(c, "tiny", C.muted)
        c.need:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
        c.why = Kit.Text(c, "small", C.text)
        c.why:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -6)
        c.why:SetPoint("RIGHT", -150, 0)
        c.why:SetWordWrap(true)
        c.why:SetJustifyH("LEFT")
        c.status = CreateFrame("Frame", nil, c)
        c.status:SetSize(128, 26)
        c.status:SetPoint("TOPRIGHT", -14, -16)
        c.status.bg = Kit.Fill(c.status, C.field, 1)
        Kit.Edge(c.status, C.borderDim)
        c.status.key = c.status:CreateTexture(nil, "ARTWORK")
        c.status.key:SetSize(16, 16)
        c.status.key:SetPoint("LEFT", 8, 0)
        c.status.key:SetTexture(KEY_ICON)
        c.status.t = Kit.Text(c.status, "small", C.white)
        c.status.t:SetPoint("LEFT", c.status.key, "RIGHT", 6, 0)
        c.steps = Kit.Text(c, "tiny", C.accent)
        c.steps:SetText(L.ACCESS_HOW)
        f.cards[i] = c
        return c
    end
    function f:Refresh()
        self.steps:Reset()
        for _, c in ipairs(self.cards) do c:Hide() end
        local list = FDJ.AccessList(current) or {}
        local width = scroll.content:GetWidth()
        if not width or width < 200 then width = 600 end
        local y = 6
        for i, entry in ipairs(list) do
            local c = card(i)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 0, -y)
            c:SetPoint("RIGHT", scroll.content, "RIGHT", -2, 0)
            c.icon:SetItem(entry.item)
            local name, _, quality = C_Item.GetItemInfo(entry.item)
            if not name then C_Item.RequestLoadItemDataByID(entry.item) end
            c.name:SetText(name or Addon.Tr(entry.name or "") )
            local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if qc then c.name:SetTextColor(qc.r, qc.g, qc.b) else c.name:SetTextColor(RGB(C.white)) end
            c.need:SetText(entry.need == "required" and L.ACCESS_REQUIRED or L.ACCESS_OPTIONAL)
            c.need:SetTone(entry.need == "required" and C.amber or C.muted)
            c.why:SetText(entry.why or "")
            local has = FDJ.AccessHas(entry)
            c.status.t:SetText(has and L.ACCESS_HAVE or (entry.need == "required" and L.ACCESS_NO_KEY or L.ACCESS_MISSING))
            c.status.t:SetTone(has and C.good or (entry.need == "required" and C.bad or C.muted))
            c.status.key:SetVertexColor(RGB(has and C.amber or C.dim))
            c.status:SetWidth(math.floor(c.status.t:GetUnboundedStringWidth() + 40))
            c.stripe:SetColorTexture(RGB(has and C.good or (entry.need == "required" and C.amber or C.borderDim)))
            local inner = 14 + 44 + 12
            c.why:SetWidth(width - inner - 160)
            local top = math.max(14 + 44, 14 + 20 + 6 + (c.why:GetStringHeight() or 14)) + 16
            c.steps:ClearAllPoints()
            c.steps:SetPoint("TOPLEFT", c, "TOPLEFT", inner, -top)
            local sy = top + 18
            local steps = entry.steps or {}
            if steps[1] == nil then steps = steps[FDJ.Faction() or ""] or {} end
            local firstOpen
            for n, st in ipairs(steps) do
                local r = self.steps:Get()
                r.step = st
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", c, "TOPLEFT", inner, -sy)
                r:SetPoint("RIGHT", c, "RIGHT", -12, 0)
                local state = stepState(st)
                if state ~= "done" and not firstOpen then firstOpen = n end
                r.num.t:SetText(state == "done" and "" or tostring(n))
                r.num.check:SetShown(state == "done")
                r.num.bg:SetColorTexture(RGB(state == "active" and C.accent or (firstOpen == n and C.amber or C.field), (state == "active" or firstOpen == n) and 0.35 or 1))
                local npc = sideValue(st.npc)
                npc = npc and Addon.Tr(npc)
                local q = sideValue(st.q)
                local title = q and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)
                if not title and st.item then title = C_Item.GetItemInfo(st.item) end
                if title == "" then title = nil end
                title = title or Addon.Tr(sideValue(st.t))
                r.title:SetText(title .. (npc and FDJ.Paint("dim", "   ·   ") .. FDJ.Paint("muted", npc) or ""))
                r.title:SetTone(state == "done" and C.muted or C.white)
                r.state:SetText(state == "active" and L.ACCESS_IN_LOG or (state == "done" and L.ACCESS_DONE or ""))
                r.state:SetTone(state == "active" and C.accent or C.good)
                r.note:SetText(st.note or "")
                r.note:SetWidth(width - inner - 60)
                r.pin:SetShown(sideValue(st.m) ~= nil)
                local h = 22 + (st.note and (r.note:GetStringHeight() or 12) + 6 or 0)
                h = math.max(h, 28)
                r:SetHeight(h)
                sy = sy + h + 10
            end
            local ch = sy + 6
            c:SetHeight(ch)
            c:Show()
            y = y + ch + 12
        end
        scroll:SetContentHeight(y + 10)
    end
    FDJ:On("BAG_UPDATE_DELAYED", function() if f:IsVisible() then FDJ.Debounce("accesspage", 0.5, function() f:Refresh() end) end end)
    FDJ:On("GET_ITEM_INFO_RECEIVED", function() if f:IsVisible() then FDJ.Debounce("accesspage", 0.3, function() f:Refresh() end) end end)
    FDJ:On("QUEST_LOG_UPDATE", function() if f:IsVisible() then FDJ.Debounce("accesspage", 1, function() f:Refresh() end) end end)
    pages.access = f
end

function Journal.PostAbilities(boss)
    local parts = {}
    for _, spell in ipairs(boss.spells or {}) do
        local link = C_Spell.GetSpellLink and C_Spell.GetSpellLink(spell)
        parts[#parts + 1] = link or C_Spell.GetSpellName(spell) or tostring(spell)
    end
    local lines, line = {}, boss.n .. ":"
    for _, part in ipairs(parts) do
        if #line + #part + 1 > 240 then
            lines[#lines + 1] = line
            line = part
        else
            line = line .. " " .. part
        end
    end
    lines[#lines + 1] = line
    FDJ.Say(lines)
end

local palette

local function buildPalette(chart, onPick, parent)
    local f = CreateFrame("Frame", nil, parent or window)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetSize(6 * 32 + 12, 10)
    f:EnableMouse(true)
    Kit.Fill(f, C.slab, 0.98)
    Kit.Edge(f, C.accent, 0.6)
    f:Hide()
    local title = Kit.Text(f, "small", C.muted)
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText(L.MARKERS)
    local y = -26
    for i, def in ipairs(Routes.Stamps) do
        local col, row = (i - 1) % 6, math.floor((i - 1) / 6)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(28, 28)
        b:SetPoint("TOPLEFT", 6 + col * 32, y - row * 32)
        b.bg = Kit.Fill(b, C.raised)
        Kit.Edge(b, C.edge)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 3, -3)
        b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        Routes.ApplyIcon(b.icon, def)
        b:SetScript("OnEnter", function(self)
            Kit.EdgeColor(self, C.accent)
            Kit.Tip(self, L["MARK_" .. def.key:upper()] or L.MARKER)
        end)
        b:SetScript("OnLeave", function(self)
            Kit.EdgeColor(self, chart.markKind == def.key and C.accent or C.edge)
            Kit.HideTip()
        end)
        b:SetScript("OnClick", function()
            f:Hide()
            onPick(def.key)
        end)
        b.key = def.key
        f[#f + 1] = b
    end
    local rows = math.ceil(#Routes.Stamps / 6)
    f:SetHeight(26 + rows * 32 + 6)
    function f:Sync()
        for _, b in ipairs(self) do Kit.EdgeColor(b, chart.markKind == b.key and C.accent or C.edge) end
    end
    return f
end

FDJ.MarkPalette = buildPalette

local function buildMap()
    local f = pageFrame()
    f.snug = true
    anchorPage(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(30)
    local holder = CreateFrame("Frame", nil, f)
    holder:SetPoint("BOTTOMRIGHT")
    function f:ShowTools(on)
        FDJ.db.window.mapTools = on and true or nil
        bar:SetShown(on)
        holder:ClearAllPoints()
        holder:SetPoint("BOTTOMRIGHT")
        if on then holder:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6) else holder:SetPoint("TOPLEFT") end
        if self.routesToggle then self.routesToggle:SetActive(on) end
    end
    local chart = FDJ.Chart.New(holder, 760)
    chart.view:SetPoint("TOP", holder, "TOP", 0, 0)
    chart.onBossClick = function(boss) Journal.Open(current, "overview", boss) end
    holder:SetScript("OnSizeChanged", function(_, w, h) chart:Resize(w, h) end)
    f.chart = chart

    local pick = Kit.Button(bar, L.NO_ROUTE, 200, 28)
    pick:SetPoint("LEFT")
    pick.label:ClearAllPoints()
    pick.label:SetPoint("LEFT", 22, 0)
    pick.label:SetPoint("RIGHT", -8, 0)
    pick.label:SetJustifyH("LEFT")
    pick.swatch = pick:CreateTexture(nil, "ARTWORK")
    pick.swatch:SetSize(8, 8)
    pick.swatch:SetPoint("LEFT", 8, 0)
    pick.tip = L.ROUTE_PICK_TIP
    f.pick = pick

    local function ensureRoute()
        if chart.route then return chart.route end
        local route = Routes.Create("chart", current.key, FDJ.RouteTitle(L.ROUTE_DEFAULT, FDJ.DungeonTitle(current)))
        chart:SetRoute(route)
        return route
    end

    local tools = {}
    local function toolButton(key, glyph, tip)
        local b = Kit.IconButton(bar, glyph, 28, tip, function()
            if key ~= "view" then ensureRoute() end
            if key == "mark" then
                palette = palette or buildPalette(chart, function(kind)
                    chart.markKind = kind
                    chart:SetTool("mark")
                end)
                palette:ClearAllPoints()
                palette:SetPoint("TOPLEFT", tools.mark, "BOTTOMLEFT", 0, -4)
                palette:Sync()
                palette:SetShown(not palette:IsShown())
                if chart.tool ~= "mark" then chart:SetTool("mark") end
                return
            end
            if palette then palette:Hide() end
            chart:SetTool(chart.tool == key and "view" or key)
        end)
        tools[key] = b
        return b
    end
    toolButton("view", "ui-cursor", L.TOOL_VIEW):SetPoint("LEFT", pick, "RIGHT", 10, 0)
    toolButton("draw", "ui-brush", L.TOOL_DRAW):SetPoint("LEFT", tools.view, "RIGHT", 3, 0)
    toolButton("stops", "ui-route", L.TOOL_STOPS):SetPoint("LEFT", tools.draw, "RIGHT", 3, 0)
    toolButton("mark", "ui-stamp", L.TOOL_MARK):SetPoint("LEFT", tools.stops, "RIGHT", 3, 0)
    toolButton("text", "fc:icon-font", L.TOOL_TEXT):SetPoint("LEFT", tools.mark, "RIGHT", 3, 0)
    toolButton("erase", "ui-eraser", L.TOOL_ERASE):SetPoint("LEFT", tools.text, "RIGHT", 3, 0)

    local width = Kit.IconButton(bar, "ui-dot", 28, L.BRUSH_SIZE, function()
        chart.brush = chart.brush % #Routes.Widths + 1
        FDJ.opt.brush = chart.brush
        f:Tools()
    end)
    width:SetPoint("LEFT", tools.erase, "RIGHT", 10, 0)
    local ink = CreateFrame("Button", nil, bar)
    ink:SetSize(28, 28)
    ink:SetPoint("LEFT", width, "RIGHT", 3, 0)
    Kit.Fill(ink, C.raised)
    Kit.Edge(ink, C.edge)
    ink.swatch = ink:CreateTexture(nil, "ARTWORK")
    ink.swatch:SetPoint("TOPLEFT", 6, -6)
    ink.swatch:SetPoint("BOTTOMRIGHT", -6, 6)
    ink:SetScript("OnEnter", function(self) Kit.Tip(self, L.INK_COLOR, L.INK_COLOR_TIP) end)
    ink:SetScript("OnLeave", Kit.HideTip)
    ink:SetScript("OnClick", function(self)
        local items = { { text = L.INK_ROUTE, checked = chart.brushColor == nil, onClick = function()
            chart.brushColor, chart.markColor = nil, nil
            f:Tools()
        end } }
        for i, c in ipairs(FDJ.RouteColors) do
            items[#items + 1] = { text = FDJ.Paint(c, L.INK_N:format(i)), checked = chart.brushColor == i, onClick = function()
                chart.brushColor, chart.markColor = i, i
                f:Tools()
            end }
        end
        Kit.Menu(self, items, 150)
    end)
    f.ink = ink
    f.width = width

    local function action(glyph, tip, fn)
        local b = Kit.IconButton(bar, glyph, 28, tip, fn)
        return b
    end
    f.bFocus = action("ui-expand", L.FOCUS_TIP, function() Journal.SetFocus(not focused) end)
    f.bFocus:SetPoint("RIGHT")
    f.bShare = action("ui-party", L.SHARE_ROUTE_TIP, function() if chart.route then Routes.Share(chart.route) end end)
    f.bShare:SetPoint("RIGHT", f.bFocus, "LEFT", -10, 0)
    f.bExport = action("fc:icon-export", L.EXPORT_TIP, function() if chart.route then FDJ.RouteList.Export(chart.route) end end)
    f.bExport:SetPoint("RIGHT", f.bShare, "LEFT", -3, 0)
    f.bMore = action("fc:icon-gear", L.MORE_TIP, function(b)
        if chart.route then FDJ.RouteList.Menu(b, chart.route, function(route, edit) Journal.ShowRoute(route, edit) end) end
    end)
    f.bMore:SetPoint("RIGHT", f.bExport, "LEFT", -3, 0)
    f.bClear = action("ui-trash", L.CLEAR_TIP, function()
        local route = chart.route
        if route then Kit.Confirm(L.CLEAR_ROUTE:format(route.name), function() Routes.Clear(route) end) end
    end)
    f.bClear:SetPoint("RIGHT", f.bMore, "LEFT", -3, 0)
    f.bUndo = action("ui-undo", L.UNDO_TIP, function() Routes.Undo(chart.route) end)
    f.bUndo:SetPoint("RIGHT", f.bClear, "LEFT", -3, 0)

    pick:SetScript("OnClick", function(_, button)
        if button == "RightButton" and chart.route then
            FDJ.RouteList.Rename(chart.route)
            return
        end
        local items = { { text = L.ROUTES, title = true } }
        items[#items + 1] = { text = L.NO_ROUTE, checked = chart.route == nil, onClick = function()
            chart:SetRoute(nil)
            f:Tools()
        end }
        for _, route in ipairs(Routes.ForChart(current)) do
            items[#items + 1] = { text = route.name, checked = chart.route == route, color = Routes.Color(route), onClick = function()
                chart:SetRoute(route)
                f:Tools()
            end }
        end
        if chart.route then
            items[#items + 1] = { text = L.RENAME_DOTS, color = C.accent, onClick = function() FDJ.RouteList.Rename(chart.route) end }
        end
        items[#items + 1] = { text = L.NEW_ROUTE_DOTS, color = C.accent, onClick = function() Journal.NewChartRoute() end }
        items[#items + 1] = { text = L.IMPORT_DOTS, color = C.accent, onClick = function()
            FDJ.RouteList.ImportDialog(function(route) Journal.ShowRoute(route, false) end)
        end }
        Kit.Menu(pick, items, 220)
    end)

    chart.brush = FDJ.opt.brush or 2
    chart.onTool = function() f:Tools() end

    function f:Tools()
        local route = chart.route
        pick:SetLabel(route and route.name or L.NO_ROUTE)
        pick.label:SetTextColor(RGB(route and C.text or C.muted))
        pick.swatch:SetColorTexture(RGB(route and Routes.Color(route) or C.dim))
        for key, b in pairs(tools) do b:SetActive(chart.tool == key or (key == "view" and not chart:Editing())) end
        for _, b in ipairs({ self.bClear, self.bMore, self.bExport, self.bShare }) do b:SetEnabled(route ~= nil) end
        self.bUndo:SetEnabled(Routes.CanUndo(route))
        local size = 8 + (chart.brush - 1) * 4
        self.width.glyph:ClearAllPoints()
        self.width.glyph:SetPoint("CENTER")
        self.width.glyph:SetSize(size, size)
        self.width.tip = L.BRUSH_SIZE .. ": " .. L["BRUSH_" .. chart.brush]
        self.ink.swatch:SetColorTexture(RGB(chart.brushColor and FDJ.RouteColors[chart.brushColor] or (route and Routes.Color(route)) or C.accent))
        self.bFocus:SetActive(focused)
    end

    function f:Refresh()
        if chart.dungeon ~= current then
            chart:SetRoute(nil)
            chart:SetDungeon(current, 1)
            local list = Routes.ForChart(current)
            if #list > 0 then chart:SetRoute(list[1]) end
        else
            chart:Draw()
        end
        self:Tools()
    end
    f:SetScript("OnHide", function() if palette then palette:Hide() end end)
    FDJ:On("FDJ_ROUTES", function() if f:IsVisible() then f:Tools() end end)
    local toggle = Kit.Button(holder, L.ROUTES or "Routes", nil, 26, function()
        f:ShowTools(not bar:IsShown())
        if not bar:IsShown() and chart:Editing() then chart:SetTool("view") end
    end, nil, "ui-route")
    toggle:SetFrameLevel(chart.view:GetFrameLevel() + 20)
    toggle:SetPoint("TOPRIGHT", chart.view, "TOPRIGHT", -8, -8)
    Kit.Fill(toggle, C.header, 0.92, "BACKGROUND", -8)
    f.routesToggle = toggle
    f:ShowTools(FDJ.db.window.mapTools)
    pages.map = f
end

function Journal.NewChartRoute()
    if not current then return end
    Kit.Prompt(L.NAME_ROUTE, FDJ.RouteTitle(L.ROUTE_DEFAULT, FDJ.DungeonTitle(current)), function(text)
        local route = Routes.Create("chart", current.key, text ~= "" and text or nil)
        Journal.ShowRoute(route, true)
    end)
end

function Journal.ShowRoute(route, edit)
    if route.scope == "world" then
        FDJ:Emit("FDJ_SHOW_WORLD_ROUTE", route, edit)
        return
    end
    local d = FDJ.ByKey[route.key]
    if not d then return end
    Journal.Open(d, "map")
    local map = pages.map
    local chart = map.chart
    chart:SetRoute(route)
    local first = route.points[1] or route.strokes[1] or route.marks[1]
    local floor = first and chart:FloorOfChart(first.m)
    if floor and floor ~= chart.floor then chart:SetFloor(floor) end
    chart:SetTool(edit and "draw" or "view")
    map:ShowTools(true)
    map:Tools()
end

local function buildQuests()
    local f = pageFrame()
    f.list = FDJ.QuestList.New(f, false)
    f.list.frame:SetAllPoints(f)
    function f:Refresh() self.list:SetDungeon(current) end
    pages.quests = f
end

local function buildParty()
    local f = pageFrame()
    f.grid = FDJ.PartyGrid.New(f, false)
    f.grid.frame:SetAllPoints(f)
    function f:Refresh() self.grid:SetDungeon(current) end
    pages.party = f
end

local function buildRoutes()
    local f = pageFrame()
    f.list = FDJ.RouteList.New(f, false, { "chart" })
    f.list.frame:SetAllPoints(f)
    f.list.onOpen = Journal.ShowRoute
    f.list.onCreate = function(scope)
        if scope == "chart" then
            Journal.NewChartRoute()
        else
            FDJ.NewWorldRoute(FDJ.ZoneMap(current.zone))
        end
    end
    function f:Refresh()
        self.list:SetSource(function() return Routes.ForChart(current) end)
    end
    pages.routes = f
end

function Journal.Settings()
    if FojjiCore and FojjiCore.ToggleOptions then
        if shell then shell:Hide() end
        FojjiCore:ToggleOptions("djsettings")
    end
end

function Journal.SetFocus(on)
    focused = on and true or false
    if not window then return end
    banner:SetShown(not focused)
    sidebar:Hide()
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", 1, -top)
    content:SetPoint("BOTTOMRIGHT", -1, 1)
    tabRule:SetShown(not focused)
    for _, b in pairs(tabs.buttons) do b:SetShown(not focused) end
    for _, page in pairs(pages) do anchorPage(page) end
    if focused and tabs.current ~= "map" then tabs:Select("map") end
    pages.map:Tools()
end

local function frameWindow()
    window = CreateFrame("Frame", "FojjiCoreDungeonJournal", host or UIParent)
    window:SetAllPoints(host or UIParent)
    Kit.Fill(window, C.frame, 1)
    Kit.Edge(window, C.borderDim)
end

local function makeShell()
    if shell then return shell end
    shell = Kit.Window("FojjiCoreDungeonJournalWindow", FDJ.title, W, H)
    shell:SetFrameStrata("MEDIUM")
    local icon = shell.head:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 14, 0)
    Kit.Logo(icon)
    shell.title:ClearAllPoints()
    shell.title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    shell.title:SetText("Dungeon Journal")
    local CORE = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
    local metal = shell.head:CreateTexture(nil, "BACKGROUND", nil, 2)
    metal:SetAllPoints()
    metal:SetTexture(CORE .. "header-metal")
    metal:SetAlpha(0.35)
    local wash = Kit.Gradient(shell.head, "HORIZONTAL", C.accent, 0.22, 0, "BACKGROUND", 3)
    wash:SetPoint("TOPLEFT")
    wash:SetPoint("BOTTOMLEFT")
    wash:SetWidth(320)
    local topRule = shell:CreateTexture(nil, "OVERLAY")
    topRule:SetPoint("TOPLEFT", 1, -1)
    topRule:SetPoint("TOPRIGHT", -1, -1)
    topRule:SetHeight(2)
    Kit.Paint(topRule, C.accent, 0.9)
    local headRule = shell.head:CreateTexture(nil, "OVERLAY")
    headRule:SetPoint("BOTTOMLEFT")
    headRule:SetPoint("BOTTOMRIGHT")
    headRule:SetHeight(1)
    Kit.Paint(headRule, C.accent, 0.35)
    Kit.EdgeColor(shell, C.accent, 0.45)
    icon:SetSize(20, 20)
    local gear = Kit.IconButton(shell.head, "fc:icon-gear", 28, L.SETTINGS, function() Journal.Settings() end)
    gear:SetPoint("RIGHT", shell.close, "LEFT", -4, 0)
    shell.body = CreateFrame("Frame", nil, shell)
    shell.body:SetPoint("TOPLEFT", 0, -HEAD)
    shell.body:SetPoint("BOTTOMRIGHT", 0, 0)
    local pos = FDJ.db.window
    if pos.w and pos.h then shell:SetSize(math.max(pos.w, 940), math.max(pos.h, 620)) end
    if pos.x and pos.y then
        shell:ClearAllPoints()
        shell:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    end
    function shell:OnMoved()
        pos.x, pos.y = self:GetLeft(), self:GetTop()
    end
    Kit.Resizable(shell, 940, 620, function(self)
        pos.w, pos.h = self:GetWidth(), self:GetHeight()
        pos.x, pos.y = self:GetLeft(), self:GetTop()
    end)
    FDJ.EscapeCloses("FojjiCoreDungeonJournalWindow")
    return shell
end

local function attach(target)
    window:SetParent(target)
    window:ClearAllPoints()
    window:SetAllPoints(target)
    window:SetFrameLevel(target:GetFrameLevel() + 1)
    window:Show()
end

local CARD_COORDS = { 0, 0.68359375, 0, 0.7421875 }
local CARD_W, CARD_GAP = 214, 10
local COVERS = {
    hallofthanes = 7963781,
    lordaeron = 7963782,
    excavation = 7963777,
    dalaran = 7963775,
}
local COVER_COORDS = { 0.16, 0.84, 0.17, 0.83 }
local CRESTS = {
    Horde = {
        { "Interface\\Timer\\Horde-Logo", 0.12, 0.88, 0.12, 0.88 },
        { "Interface\\TargetingFrame\\UI-PVP-Horde", 0.09, 0.55, 0.04, 0.50 },
        { "Interface\\FriendsFrame\\PlusManz-Horde" },
    },
    Alliance = {
        { "Interface\\Timer\\Alliance-Logo", 0.12, 0.88, 0.12, 0.88 },
        { "Interface\\TargetingFrame\\UI-PVP-Alliance", 0.09, 0.55, 0.04, 0.50 },
        { "Interface\\FriendsFrame\\PlusManz-Alliance" },
    },
}
local GLOW = { Horde = { 1.0, 0.16, 0.08 }, Alliance = { 0.22, 0.55, 1.0 } }
local crestPick = {}

local function setCrest(tex, side)
    local pick = crestPick[side]
    if pick then
        tex:SetTexture(pick[1])
        tex:SetTexCoord(pick[2] or 0, pick[3] or 1, pick[4] or 0, pick[5] or 1)
        return
    end
    for _, c in ipairs(CRESTS[side]) do
        tex:SetTexture(c[1])
        local id = tex.GetTextureFileID and tex:GetTextureFileID()
        if id and id ~= 0 then
            crestPick[side] = c
            tex:SetTexCoord(c[2] or 0, c[3] or 1, c[4] or 0, c[5] or 1)
            return
        end
    end
    crestPick[side] = CRESTS[side][#CRESTS[side]]
    setCrest(tex, side)
end

function Journal.MakeBadge(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.glow = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.glow:SetSize(size * 2.3, size * 2.3)
    f.glow:SetPoint("CENTER")
    f.glow:SetTexture(FDJ.Glyph("fc:badge-glow"))
    f.glow:SetBlendMode("ADD")
    f.disc = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.disc:SetAllPoints()
    f.disc:SetTexture(FDJ.Glyph("fc:badge-disc"))
    f.disc:SetVertexColor(0.03, 0.03, 0.04, 0.88)
    f.crest = f:CreateTexture(nil, "OVERLAY", nil, 3)
    f.crest:SetPoint("CENTER")
    f.crest:SetSize(size * 0.9, size * 0.9)
    f.ring = f:CreateTexture(nil, "OVERLAY", nil, 4)
    f.ring:SetAllPoints()
    f.ring:SetTexture(FDJ.Glyph("fc:badge-ring"))
    function f:SetSide(side, faded)
        if not GLOW[side] then self:Hide() return end
        local c = GLOW[side]
        setCrest(self.crest, side)
        self.ring:SetVertexColor(c[1], c[2], c[3], faded and 0.55 or 1)
        self.glow:SetVertexColor(c[1], c[2], c[3], faded and 0.35 or 0.85)
        self.crest:SetDesaturated(faded and true or false)
        self.crest:SetAlpha(faded and 0.7 or 1)
        self:Show()
    end
    f:Hide()
    return f
end

function Journal.CoverFor(d) return d and COVERS[d.key] end

local function cardArt(b, d, zoom)
    for _, t in ipairs(b.tiles) do t:Hide() end
    local cover = not d.art and COVERS[d.key]
    if d.art or cover then
        b.art:SetTexture(cover or d.art[1])
        local c = cover and COVER_COORDS or CARD_COORDS
        local x1, x2, y1, y2 = c[1], c[2], c[3], c[4]
        if zoom then
            local dx, dy = (x2 - x1) * 0.04, (y2 - y1) * 0.04
            x1, x2, y1, y2 = x1 + dx, x2 - dx, y1 + dy, y2 - dy
        end
        b.art:SetTexCoord(x1, x2, y1, y2)
        b.art:Show()
        return
    end
    b.art:Hide()
    local mapID = FDJ.ZoneMap(d.zone)
    local list, info = FDJ.ChartTiles(mapID or 0)
    if not list then return end
    local cols = (info and info.wide) or 4
    local rows = math.ceil(#list / cols)
    local w, h = b:GetWidth(), b:GetHeight()
    local t = w / (cols * 1002 / 1024)
    local mapH = rows * t * (668 / 768)
    local oy = math.max(0, (mapH - h) / 2)
    for i, fid in ipairs(list) do
        local tex = b.tiles[i]
        if not tex then
            tex = b:CreateTexture(nil, "BACKGROUND", nil, 1)
            b.tiles[i] = tex
        end
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        tex:SetTexture(fid)
        tex:SetSize(t, t)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", b, "TOPLEFT", c * t, -r * t + oy)
        tex:SetVertexColor(0.85, 0.8, 0.7)
        tex:Show()
    end
end

local function makeCard()
    local b = CreateFrame("Button", nil, home.scroll.content)
    b:SetClipsChildren(true)
    Kit.Fill(b, C.field)
    b.tiles = {}
    b.art = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.art:SetAllPoints()
    b.shade = Kit.Gradient(b, "VERTICAL", C.shadow, 0.92, 0, "BACKGROUND", 3)
    b.shade:SetPoint("BOTTOMLEFT"); b.shade:SetPoint("BOTTOMRIGHT"); b.shade:SetHeight(62)
    b.topShade = Kit.Gradient(b, "VERTICAL", C.shadow, 0, 0.55, "BACKGROUND", 3)
    b.topShade:SetPoint("TOPLEFT"); b.topShade:SetPoint("TOPRIGHT"); b.topShade:SetHeight(28)
    b.hl = Kit.Fill(b, C.white, 0, "ARTWORK")
    Kit.Edge(b, C.borderDim)
    b.family = Kit.Text(b, 9, C.muted)
    b.family:SetPoint("BOTTOMLEFT", 9, 46)
    b.name = Addon.Localize(b:CreateFontString(nil, "OVERLAY"))
    b.name:SetFont(FDJ.Font(), 14, "OUTLINE")
    b.name:SetTextColor(1, 0.82, 0)
    b.name:SetShadowColor(0, 0, 0, 1)
    b.name:SetShadowOffset(1, -1)
    b.name:SetPoint("BOTTOMLEFT", 9, 29)
    b.name:SetPoint("RIGHT", -9, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.range = Kit.Text(b, 10, C.white)
    b.range:SetPoint("BOTTOMLEFT", 9, 8)
    b.kills = Kit.Text(b, 10, C.text, "RIGHT")
    b.kills:SetPoint("BOTTOMRIGHT", -9, 8)
    b.pill = CreateFrame("Frame", nil, b)
    b.pill:SetSize(40, 22)
    b.pill:SetPoint("BOTTOMRIGHT", -6, 5)
    Kit.Fill(b.pill, C.shadow, 0.8)
    Kit.Edge(b.pill, C.quest, 0.7)
    b.pill.icon = b.pill:CreateTexture(nil, "ARTWORK")
    b.pill.icon:SetSize(14, 14)
    b.pill.icon:SetPoint("LEFT", 5, 0)
    b.pill.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    b.pill.text = Kit.Text(b.pill, 12, C.quest, "LEFT")
    b.pill.text:SetPoint("LEFT", b.pill.icon, "RIGHT", 3, 0)
    b.access = {}
    for k = 1, 2 do
        local f = CreateFrame("Frame", nil, b)
        f:SetSize(22, 22)
        f:EnableMouse(true)
        f.bg = Kit.Fill(f, C.shadow, 0.8)
        f.edge = Kit.Edge(f, C.borderDim)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", 2, -2)
        f.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f:SetScript("OnEnter", function(self)
            local e = self.entry
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(C_Item.GetItemInfo(e.item) or Addon.Tr(e.name or ""), 1, 0.82, 0.3)
            GameTooltip:AddLine(Addon.Tr(e.why or ""), 0.8, 0.8, 0.8, true)
            local has = FDJ.AccessHas(e)
            GameTooltip:AddLine(has and L.ACCESS_HAVE or (e.need == "required" and L.ACCESS_NO_KEY or L.ACCESS_MISSING), RGB(has and C.good or C.bad))
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() Kit.HideTip() end)
        f:SetScript("OnMouseUp", function(self)
            if self:GetParent().dungeon then Journal.Select(self:GetParent().dungeon, "access") end
        end)
        f:Hide()
        b.access[k] = f
    end
    b.side = Journal.MakeBadge(b, 28)
    b.side:SetPoint("TOPLEFT", 7, -7)
    b.here = Kit.Text(b, 9, C.accent)
    b.here:SetPoint("TOPLEFT", 20, -7)
    b:SetScript("OnEnter", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0.06)
        Kit.EdgeColor(self, C.accent)
        if self.dungeon then cardArt(self, self.dungeon, true) end
        local d = self.dungeon
        if d then
            local body = { { L.LEVELS, d.range[1] .. "-" .. d.range[2] }, { L.BOSSES, tostring(#d.bosses) }, { d.zone } }
            Kit.Tip(self, FDJ.DungeonTitle(d), body)
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.hl:SetColorTexture(1, 1, 1, 0)
        Kit.EdgeColor(self, self.isHere and C.accent or C.borderDim)
        if self.dungeon then cardArt(self, self.dungeon, false) end
        Kit.HideTip()
    end)
    b:SetScript("OnClick", function(self)
        if self.dungeon then Journal.Select(self.dungeon, "overview") end
    end)
    return b
end

local function buildHome()
    home = CreateFrame("Frame", nil, window)
    home:SetPoint("TOPLEFT", content, "TOPLEFT")
    home:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
    home:SetFrameLevel(content:GetFrameLevel() + 40)
    home:EnableMouse(true)
    Kit.Fill(home, C.content)
    home.title = Kit.Text(home, "huge", C.white)
    home.title:SetPoint("TOPLEFT", PAD + 2, -20)
    home.title:SetText(L.BROWSE_DUNGEONS or "Dungeons")
    local where = Kit.IconButton(home, "ui-waypoint", 30, L.WHERE_AM_I, function()
        Journal.Select(FDJ.SuggestedDungeon(), "overview")
    end, "ghost")
    where.tipBody = L.WHERE_AM_I_TIP
    where:SetPoint("TOPRIGHT", -PAD, -16)
    local seg = Kit.Segmented(home, { { "all", L.FILTER_ALL }, { "level", L.FILTER_LEVEL }, { "quests", L.FILTER_QUESTS } }, function(key)
        filter = key
        Journal.RefreshList()
    end)
    seg:SetSize(230, 28)
    seg:SetPoint("RIGHT", where, "LEFT", -8, 0)
    home.seg = seg
    local box = Kit.Input(home, 220, 28, L.SEARCH_HINT, function(_, text)
        search = text or ""
        Journal.RefreshList()
    end, nil, "fc:icon-search")
    box:SetPoint("RIGHT", seg, "LEFT", -8, 0)
    home.scroll = Kit.Scroller(home)
    home.scroll:SetPoint("TOPLEFT", PAD, -62)
    home.scroll:SetPoint("BOTTOMRIGHT", -PAD + 8, 14)
    home.empty = Kit.Text(home, "normal", C.muted, "CENTER")
    home.empty:SetPoint("TOP", home.scroll, "TOP", 0, -40)
    home.empty:SetText(L.NO_MATCH or "No dungeons match.")
    home.cards = Kit.Pool(makeCard)
    home:SetScript("OnSizeChanged", function() if home:IsShown() then FDJ.Debounce("djhome", 0.05, Journal.RefreshHome) end end)
    home:Hide()
end

function Journal.RefreshHome()
    if not (home and home:IsShown()) then return end
    home.cards:Reset()
    if home.seg and home.seg.Select then home.seg:Select(filter, true) end
    local width = math.max(300, home.scroll:GetWidth() - 10)
    home.scroll.content:SetWidth(width)
    local cols = math.max(2, math.floor((width + CARD_GAP) / (CARD_W + CARD_GAP)))
    local cw = math.floor((width - CARD_GAP * (cols - 1)) / cols)
    local ch = math.floor(cw * 95 / 175)
    local here = FDJ.CurrentDungeon()
    local level = FDJ.Level()
    local i = 0
    for _, d in ipairs(FDJ.Dungeons) do
        if matches(d) then
            local b = home.cards:Get()
            b.dungeon = d
            local col, row = i % cols, math.floor(i / cols)
            b:SetSize(cw, ch)
            b:SetPoint("TOPLEFT", home.scroll.content, "TOPLEFT", col * (cw + CARD_GAP), -row * (ch + CARD_GAP))
            cardArt(b, d, false)
            local far = level < d.range[1] - 6 or level > d.range[2] + 8
            b.art:SetDesaturated(far)
            b.art:SetAlpha(far and 0.55 or 1)
            b.family:SetText(d.family and d.family:upper() or "")
            b.name:SetText(d.family and d.name or FDJ.DungeonTitle(d))
            b.range:SetText(FDJ.Paint(FDJ.ListRangeColor(d, C.muted), d.range[1] .. "-" .. d.range[2]))
            local qs = Quests.Summary(d)
            local n = qs.open + qs.active + qs.ready
            b.pill:SetShown(n > 0)
            local list = FDJ.AccessList(d) or {}
            local prevIcon
            for k, f in ipairs(b.access) do
                local e = list[k]
                f.entry = e
                if e then
                    local has = FDJ.AccessHas(e)
                    f.icon:SetTexture(C_Item.GetItemIconByID(e.item) or 134400)
                    f.icon:SetDesaturated(not has)
                    f.icon:SetAlpha(1)
                    if has then f.icon:SetVertexColor(1, 1, 1) else f.icon:SetVertexColor(0.9, 0.9, 0.9) end
                    for _, t in ipairs(f.edge or {}) do t:SetColorTexture(RGB(has and C.amber or C.muted, has and 1 or 0.7)) end
                    f:ClearAllPoints()
                    if prevIcon then f:SetPoint("RIGHT", prevIcon, "LEFT", -3, 0) else f:SetPoint("TOPRIGHT", -6, -6) end
                    prevIcon = f
                    f:Show()
                else
                    f:Hide()
                end
            end
            b.pill.text:SetText(tostring(n))
            b.pill:SetWidth(b.pill.text:GetStringWidth() + 30)
            b.kills:ClearAllPoints()
            if n > 0 then b.kills:SetPoint("RIGHT", b.pill, "LEFT", -6, 0) else b.kills:SetPoint("BOTTOMRIGHT", -9, 8) end
            local kills = Runs.Count(d)
            b.kills:SetText(kills > 0 and (kills .. "/" .. #d.bosses) or "")
            local side = FDJ.DungeonSide(d)
            b.side:SetSide(side, FDJ.IsEnemyDungeon(d))
            b.here:ClearAllPoints()
            b.here:SetPoint("TOPLEFT", side and 40 or 9, side and -16 or -8)
            b.isHere = d == here
            b.here:SetText(b.isHere and (L.YOU_ARE_HERE or "YOU ARE HERE") or "")
            Kit.EdgeColor(b, b.isHere and C.accent or C.borderDim)
            i = i + 1
        end
    end
    home.empty:SetShown(i == 0)
    home.scroll:SetContentHeight(math.ceil(i / cols) * (ch + CARD_GAP))
end

local function arrive()
    local here = not (host and window:GetParent() == host) and FDJ.CurrentDungeon()
    if here then
        Journal.Select(here)
    else
        if not current then Journal.Select(FDJ.ByKey[FDJ.db.window.dungeon or ""] or FDJ.SuggestedDungeon()) end
        Journal.Home()
    end
end

function Journal.Home()
    if not window then return end
    home:Show()
    Journal.RefreshHome()
    Journal.RefreshList()
end

local function build()
    FDJ.SyncTheme()
    frameWindow()

    content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", 1, -top)
    content:SetPoint("BOTTOMRIGHT", -1, 1)
    Kit.Fill(content, C.content)

    buildSidebar()
    buildBanner()
    buildOverview()
    buildMap()
    buildQuests()
    buildParty()
    buildRoutes()
    buildWishlist()
    buildAccess()

    tabs = Kit.Tabs(content, {
        { "overview", L.TAB_OVERVIEW },
        { "map", L.TAB_MAP },
        { "quests", L.TAB_QUESTS },
        { "party", L.TAB_PARTY },
        { "routes", L.TAB_ROUTES },
        { "wishlist", L.WISHLIST },
        { "access", L.TAB_ACCESS },
    }, function(key)
        for k, page in pairs(pages) do page:SetShown(k == key) end
        FDJ.db.window.tab = key
        if current and pages[key] then pages[key]:Refresh() end
    end)
    tabs.first:SetPoint("TOPLEFT", content, "TOPLEFT", PAD - 8, Addon.Native and -(bannerH + 2) or -(bannerH - 4))
    tabRule = content:CreateTexture(nil, "BORDER")
    tabRule:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -(bannerH + 28))
    tabRule:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -(bannerH + 28))
    tabRule:SetHeight(1)
    Kit.Paint(tabRule, C.borderDim)
    if Addon.Native and Addon.Skin then Addon.Skin.Rule(tabRule) end

    buildHome()
    sidebar:Hide()

    window:SetScript("OnShow", function()
        Journal.RefreshList()
        if Journal.opening then return end
        arrive()
    end)

    local function refreshAll()
        if not window:IsVisible() then return end
        Journal.RefreshList()
        paintBanner()
    end
    FDJ:On("FDJ_QUESTS", refreshAll)
end

function Journal.Embed(frame)
    if window then return end
    host = frame
    frame:HookScript("OnShow", function()
        local fresh = not window
        if fresh then build() end
        if shell then shell:Hide() end
        attach(frame)
        arrive()
    end)
end

local function reveal()
    if not window then build() end
    if host and window:GetParent() == host and window:IsVisible() then return end
    makeShell()
    attach(shell.body)
    local over = FojjiCoreOptionsFrame and FojjiCoreOptionsFrame:IsShown() and FojjiCoreOptionsFrame
    if over then
        shell:SetFrameStrata(over:GetFrameStrata())
        shell:SetFrameLevel(over:GetFrameLevel() + 40)
    elseif shell:GetFrameStrata() ~= "MEDIUM" then
        shell:SetFrameStrata("MEDIUM")
    end
    shell:Show()
    shell:Raise()
end

function Journal.Select(d, tab)
    if not window then build() end
    if not d then return end
    current = d
    banner.world.Refresh()
    FDJ.Prefetch(d)
    FDJ.db.window.dungeon = d.key
    if home then home:Hide() end
    paintBanner()
    Journal.RefreshList()
    tab = tab or tabs.current or FDJ.db.window.tab
    if tab == "loot" or not pages[tab] then tab = "overview" end
    if tab == "access" and not FDJ.AccessList(d) then tab = "overview" end
    tabs:Select(tab)
end

function Journal.Open(d, tab, boss)
    Journal.opening = true
    reveal()
    Journal.opening = nil
    if not d and not tab then
        arrive()
        return
    end
    if tab == "loot" then tab = "overview" end
    Journal.Select(d or current or FDJ.ByKey[FDJ.db.window.dungeon or ""] or FDJ.SuggestedDungeon(), tab)
    if boss then
        if tab == "overview" then
            pages.overview.list:Expand(boss, true)
            pages.overview:SyncExpand()
        elseif tab == "map" then
            pages.map.chart:FocusBoss(boss)
        end
    end
end

function Journal.Toggle()
    if shell and shell:IsShown() then
        shell:Hide()
    else
        Journal.Open()
    end
end

function Journal.HideWindow()
    if shell and shell:IsShown() then shell:Hide() end
end

function Journal.IsShown()
    return window ~= nil and window:IsVisible()
end

function Journal.Current()
    return current
end

FDJ:On("FDJ_ENTERED", function(d)
    if window and window:IsVisible() then Journal.Select(d) end
end)
