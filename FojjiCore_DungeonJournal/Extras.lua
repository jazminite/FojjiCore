local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Kit = FDJ.Kit
local C = FDJ.Colors
local L = FDJ.L

local function addSources(tooltip, itemID)
    local sources = FDJ.LootSources[itemID]
    local needs = FDJ.QuestNeeds[itemID]
    local reward = FDJ.Gear and FDJ.Gear.QuestFor and FDJ.Gear.QuestFor(itemID)
    local g, rank
    if FDJ.Gear then g, rank = FDJ.Gear.ForTooltip(itemID) end
    local wished = FDJ.char and FDJ.char.wishes[itemID]
    if not sources and not needs and not reward and not g and not wished then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(("|T%s:12:12:0:0|t %s"):format(FDJ.icon, FDJ.Paint("accent", "Dungeon Journal")))
    if reward and not sources then
        tooltip:AddLine(L.PLAN_QUEST_SHORT:format(FDJ.Q(reward.t)), C.text[1], C.text[2], C.text[3])
    end
    for i, src in ipairs(sources or {}) do
        if i > 3 then
            tooltip:AddLine(FDJ.Paint("dim", L.MORE_SOURCES:format(#sources - 3)))
            break
        end
        local boss = src.boss
        tooltip:AddDoubleLine(boss.n .. FDJ.Paint("dim", "  " .. FDJ.DungeonTitle(boss.dungeon)),
            src.odds and (src.odds .. "%") or "", C.text[1], C.text[2], C.text[3], C.muted[1], C.muted[2], C.muted[3])
    end
    for i, qid in ipairs(needs or {}) do
        if i > 2 then break end
        tooltip:AddLine(L.NEEDED_FOR:format(FDJ.Q(FDJ.Quests.Title(qid))), C.muted[1], C.muted[2], C.muted[3])
    end
    if g then
        local a = C.accent
        local mark = ("|T%s:13:13:0:0:64:64:0:64:0:64:%d:%d:%d|t "):format(FDJ.Glyph("fc:mark-plan"), math.floor(a[1] * 255), math.floor(a[2] * 255), math.floor(a[3] * 255))
        local label = FDJ.Gear.SlotName(g)
        if rank > #g.slots then label = label .. "  (" .. L.PLAN_BACKUP .. ")" end
        local sets = FDJ.Gear.SetsWith and FDJ.Gear.SetsWith(itemID) or {}
        local names = #sets > 0 and table.concat(sets, ", ") or L.PLAN_MARK
        tooltip:AddLine(mark .. FDJ.Paint("accent", L.ON_BIS:format(names, label)))
    elseif wished then
        tooltip:AddLine(FDJ.Paint("amber", L.ON_WISHLIST))
    end
end

local function reload()
    if ReloadUI then ReloadUI() elseif C_UI and C_UI.Reload then C_UI.Reload() end
end

function FDJ:Shutdown()
    if self.WorldLayer and self.WorldLayer.route and self.WorldLayer.ShowRoute then pcall(self.WorldLayer.ShowRoute, nil) end
    self.off = true
    self.hub:UnregisterAllEvents()
    for _, fn in ipairs({
        self.Dock and self.Dock.Apply,
        self.InstanceMap and self.InstanceMap.Update,
        self.WorldLayer and self.WorldLayer.Refresh,
        self.Pocket and self.Pocket.Apply,
        self.SpellRanks and self.SpellRanks.HideAll,
        self.Journal and self.Journal.HideWindow,
    }) do
        pcall(fn)
    end
    SLASH_FOJJICOREDJ1 = "/fdj"
    SlashCmdList.FOJJICOREDJ = function(msg)
        local cmd = (msg or ""):lower():match("^%s*(%S*)")
        if cmd == "on" or cmd == "enable" then FDJ:SetEnabled(true) else FDJ.Print("The Dungeon Journal is turned off. |cffffffff/fc dj on|r turns it back on.") end
    end
end

function FDJ:SetEnabled(on)
    if not self.db then self:LoadStore() end
    on = on and true or false
    self.db.options.enabled = on
    if on and self.off then
        self.reloadPending = true
        FDJ.Print("Dungeon Journal turned on - reload to load it.")
    elseif not on and not self.off then
        self:Shutdown()
        self.reloadPending = true
        FDJ.Print("Dungeon Journal turned off. Reload to unload it completely (/fc dj on turns it back on).")
    end
    if self.settingsRefresh then self.settingsRefresh() end
end

function FDJ:Enabled()
    return not self.off and not (self.db and self.db.options.enabled == false)
end

local MAP_KEYS = { "entrances", "instanceMap", "mapButton", "routesButton", "dock" }
function FDJ:MapOff()
    for _, key in ipairs(MAP_KEYS) do self:SetOption(key, false) end
    if self.Dock and self.Dock.Close then pcall(self.Dock.Close) end
end
function FDJ:MapAnyOn()
    for _, key in ipairs(MAP_KEYS) do if self.opt and self.opt[key] ~= false then return true end end
    return false
end

local function hookTooltips()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not FDJ:Option("tooltips") or tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local itemID = data and data.id
        if type(itemID) ~= "number" or FDJ.Secret(itemID) then return end
        addSources(tooltip, itemID)
    end)
end

local function offer(o)
    local route = o.route
    Kit.Toast(L.ROUTE_OFFER:format(FDJ.Paint("accent", o.sender), FDJ.Hi(route.name), FDJ.Routes.Summary(route)), {
        { L.SAVE, function()
            local saved = FDJ.Routes.Adopt(route)
            FDJ.Print(L.IMPORTED:format(FDJ.Hi(saved.name)))
        end },
        { L.SAVE_VIEW, function()
            local saved = FDJ.Routes.Adopt(route)
            FDJ.Journal.ShowRoute(saved, false)
        end },
    })
end

local function restore()
    Kit.TextWindow(L.RESTORE, "", function(text)
        local ok, result = FDJ:RestoreBackup(text)
        if not ok then
            FDJ.Print(FDJ.Routes.ErrorText(result))
            return false
        end
        FDJ.Print(L.RESTORED:format(FDJ.Hi(result)))
        return true
    end, L.RESTORE_HINT)
end
FDJ.RestoreDialog = restore

local function findMaps(query)
    query = (query or ""):lower()
    if query == "" or not (C_Map and C_Map.GetMapInfo) then
        FDJ.Print("Usage: |cffffffff/fc dj findmap <name>|r, e.g. /fc dj findmap hyjal")
        return
    end
    local function describe(mapID, info)
        local parent = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
        local line = ("%d  %s  type=%s  parent=%s (%s)"):format(mapID, tostring(info.name), tostring(info.mapType),
            tostring(info.parentMapID), parent and parent.name or "?")
        local group = C_Map.GetMapGroupID and C_Map.GetMapGroupID(mapID)
        if group and C_Map.GetMapGroupMembersInfo then
            local floors = {}
            for _, m in ipairs(C_Map.GetMapGroupMembersInfo(group) or {}) do
                floors[#floors + 1] = m.mapID .. "=" .. tostring(m.name)
            end
            line = line .. "  floors: " .. table.concat(floors, ", ")
        end
        return line
    end
    local root = tonumber(query)
    if root then
        local out = {}
        for _, c in ipairs(C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(root, nil, true) or {}) do
            out[#out + 1] = describe(c.mapID, c)
        end
        if #out == 0 then FDJ.Print("No maps inside " .. root .. ".") return end
        Kit.TextWindow("Maps inside " .. root, table.concat(out, "\n"), nil, "Copy this and send it over")
        return
    end
    local instances = query == "instances"
    FDJ.Print("Searching maps for \"" .. query .. "\"...")
    local found, id, last = {}, 1, 12000
    local function step()
        local stop = math.min(id + 400, last)
        for mapID = id, stop do
            local info = C_Map.GetMapInfo(mapID)
            local name = info and info.name
            local hit
            if name and not FDJ.Secret(name) then
                if instances then
                    hit = mapID >= 2400 and (info.mapType == 4 or info.mapType == 5 or info.mapType == 6)
                else
                    hit = name:lower():find(query, 1, true)
                end
            end
            if hit then found[#found + 1] = describe(mapID, info) end
        end
        id = stop + 1
        if id <= last then
            C_Timer.After(0, step)
        elseif #found == 0 then
            FDJ.Print("No maps found for \"" .. query .. "\".")
        else
            Kit.TextWindow("Maps: " .. query, table.concat(found, "\n"), nil, "Copy this and send it over")
        end
    end
    step()
end

local function slash(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "" then
        FDJ.Journal.Toggle()
    elseif cmd == "map" then
        FDJ.db.options.dockOpen = true
        local d = FDJ.SuggestedDungeon()
        FDJ:Emit("FDJ_DOCK_DUNGEON", d)
        FDJ.Pins.OpenMap(FDJ.ZoneMap(d.zone))
    elseif cmd == "quests" then
        FDJ.Journal.Open(FDJ.SuggestedDungeon(), "quests")
    elseif cmd == "import" then
        FDJ.RouteList.ImportDialog(function(route) FDJ.Journal.ShowRoute(route, false) end)
    elseif cmd == "backup" then
        Kit.TextWindow(L.BACKUP, FDJ:BuildBackup(), nil, L.BACKUP_HINT)
    elseif cmd == "restore" then
        restore()
    elseif cmd == "sync" then
        FDJ.Party.Request()
    elseif (cmd == "spells" or cmd == "ranks") and FDJ.SpellRanks then
        FDJ.SpellRanks.SetEnabled(not FDJ.SpellRanks.Enabled())
    elseif cmd == "bars" and FDJ.SpellRanks then
        local spell = (msg or ""):match("^%s*%S+%s+(.+)$")
        if spell then FDJ.SpellRanks.Explain(spell) else FDJ.SpellRanks.CheckBars() end
    elseif cmd == "findspell" and FDJ.SpellRanks and FDJ.SpellRanks.FindSpells then
        FDJ.SpellRanks.FindSpells((msg or ""):match("^%s*%S+%s+(.+)$"))
    elseif cmd == "bar" then
        FDJ.Pocket.ToggleShown()
    elseif cmd == "findmap" then
        findMaps((msg or ""):match("^%s*%S+%s+(.+)$"))
    elseif cmd == "sharepin" or cmd == "pin" then
        FDJ.Pins.Share()
    elseif cmd == "reset" then
        FDJ.Runs.Reset()
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        FDJ.Journal.Settings()
    elseif cmd == "off" or cmd == "disable" then
        FDJ:SetEnabled(false)
    elseif cmd == "on" or cmd == "enable" then
        FDJ.Print("The Dungeon Journal is already on.")
    else
        FDJ.Print(L.COMMANDS)
        for _, line in ipairs(L.HELP_LINES) do
            DEFAULT_CHAT_FRAME:AddMessage("    " .. FDJ.Paint("accent", line[1]) .. FDJ.Paint("dim", "  " .. line[2]))
        end
    end
end

function Addon.EmbedDungeonJournal(page)
    local frame = CreateFrame("Frame", nil, page)
    frame:SetPoint("TOPLEFT", 0, -54)
    frame:SetPoint("BOTTOMRIGHT", 0, 0)
    FDJ.Journal.Embed(frame)
    return frame
end

function Addon.CreateDungeonJournalPage(page, UI)
    FDJ.SyncTheme()
    local COLW = 300
    local scroll = UI.Scroll(page)
    scroll:SetPoint("TOPLEFT", 0, -50)
    scroll:SetPoint("BOTTOMRIGHT", -18, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(640, 900)
    scroll:SetScrollChild(body)
    scroll:SetScript("OnSizeChanged", function(_, width) body:SetWidth(width) end)

    local refreshers = {}
    local y, cy = 0, { 0, 0 }
    local function Section(title)
        y = y + 12
        local label = UI.Text(body, title, 12, "accent")
        label:SetPoint("TOPLEFT", 0, -y)
        local line = UI.Texture(body, "ARTWORK", "borderDim")
        line:SetPoint("TOPLEFT", 0, -(y + 17))
        line:SetPoint("TOPRIGHT", 0, -(y + 17))
        line:SetHeight(1)
        y = y + 26
        cy[1], cy[2] = y, y
    end
    local function Put(col, widget, height, gap)
        widget:SetPoint("TOPLEFT", body, "TOPLEFT", (col - 1) * (COLW + 24), -cy[col])
        cy[col] = cy[col] + height + (gap or 6)
    end
    local function Done()
        y = math.max(cy[1], cy[2]) + 6
    end
    local function Note(col, text)
        local t = UI.Text(body, text, 10, "dim")
        t:SetWidth(COLW)
        t:SetJustifyH("LEFT")
        t:SetWordWrap(true)
        t:SetHeight(28)
        Put(col, t, 28, 10)
    end
    local function Toggle(col, text, note, get, set)
        local box = UI.Checkbox(body, text, function(value) set(value) end)
        box:SetWidth(COLW)
        refreshers[#refreshers + 1] = function() box:SetChecked(get() and true or false) end
        Put(col, box, 22, note and 2 or 8)
        if note then Note(col, note) end
    end
    local function Option(col, text, note, key)
        Toggle(col, text, note, function() return FDJ.opt and FDJ.opt[key] end, function(value) FDJ:SetOption(key, value) end)
    end
    local function Action(col, text, note, fn)
        local b = UI.Button(body, text, 200)
        b:SetScript("OnClick", fn)
        Put(col, b, 26, note and 2 or 8)
        if note then Note(col, note) end
    end

    local rest = {}
    Section("Dungeon Journal")
    Toggle(1, "Disable Dungeon Journal and all features.", nil,
        function() return FDJ.db and FDJ.db.options.enabled == false end,
        function(value) FDJ:SetEnabled(not value) end)
    local reloadBtn = UI.Button(body, "Reload UI", 140)
    reloadBtn:SetScript("OnClick", function() ReloadUI() end)
    Put(2, reloadBtn, 26, 2)
    Done()
    local function collectRest()
        local all = { body:GetChildren() }
        for _, r in ipairs({ body:GetRegions() }) do all[#all + 1] = r end
        return all
    end
    local before = {}
    for _, w in ipairs(collectRest()) do before[w] = true end

    Section("World map")
    Option(1, "Dungeon entrances", nil, "entrances")
    Option(1, "Dungeon map inside dungeons", nil, "instanceMap")
    Option(1, "Dungeon map button", nil, "mapButton")
    Option(2, "World map dock", nil, "dock")
    Option(2, "Dock follows the map zone", nil, "dockFollow")
    Option(2, "Routes button", nil, "routesButton")
    Done()
    cy[1], cy[2] = y, y
    local mapOff = UI.Button(body, "Hide all on the map", 200)
    mapOff:SetScript("OnClick", function() FDJ:MapOff() end)
    Put(1, mapOff, 26, 2)
    Done()

    Section("Popout bar")
    do
        local seg = Kit.Segmented(body, { { "always", L.POCKET_ALWAYS }, { "group", L.POCKET_GROUP }, { "dungeon", L.POCKET_DUNGEON }, { "never", L.POCKET_NEVER } }, function(key)
            FDJ:SetOption("pocketWhen", key)
        end)
        seg:SetSize(COLW + 80, 24)
        Put(1, seg, 24, 4)
        refreshers[#refreshers + 1] = function() seg:Select(FDJ.opt and FDJ.opt.pocketWhen or "dungeon", true) end
    end
    Done()
    cy[1], cy[2] = y, y
    do
        local row = CreateFrame("Frame", nil, body)
        row:SetSize(COLW * 2, 24)
        local label = UI.Text(row, L.POCKET_DIR, 12, "text")
        label:SetPoint("LEFT")
        local dir = Kit.Segmented(row, { { "up", L.POCKET_UP }, { "down", L.POCKET_DOWN } }, function(key)
            FDJ:SetOption("pocketDir", key)
        end)
        dir:SetSize(200, 24)
        dir:SetPoint("LEFT", label, "RIGHT", 12, 0)
        Put(1, row, 24, 4)
        refreshers[#refreshers + 1] = function() dir:Select(FDJ.opt and FDJ.opt.pocketDir or "up", true) end
    end
    Option(1, L.POCKET_ANCHOR, nil, "pocketAnchor")
    Done()

    Section("Shortcut")
    do
        local row = CreateFrame("Frame", nil, body)
        row:SetSize(COLW * 2, 26)
        local label = UI.Text(row, "Open the journal", 12, "text")
        label:SetPoint("LEFT")
        local b = UI.Button(row, "", 150)
        b:SetPoint("LEFT", label, "RIGHT", 12, 0)
        local hint = UI.Text(row, "", 10, "dim")
        hint:SetPoint("LEFT", b, "RIGHT", 10, 0)
        local function show()
            local key = FDJ.db and FDJ.db.options.journalKey or ""
            b.label:SetText(key ~= "" and (GetBindingText and GetBindingText(key) or key) or "Not set")
            hint:SetText(b.waiting and "Press a key (Esc cancels, Backspace clears)" or "Click to change")
        end
        b:SetScript("OnClick", function(self)
            self.waiting = true
            self.label:SetText("...")
            show()
            self.label:SetText("Press a key")
            self:EnableKeyboard(true)
        end)
        b:SetScript("OnKeyDown", function(self, key)
            if not self.waiting then return end
            if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
            self.waiting = nil
            self:EnableKeyboard(false)
            if key ~= "ESCAPE" then
                if key == "BACKSPACE" or key == "DELETE" then
                    key = ""
                else
                    key = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
                end
                FDJ:SetOption("journalKey", key)
                FDJ.ApplyJournalKey()
            end
            show()
        end)
        b:EnableKeyboard(false)
        refreshers[#refreshers + 1] = show
        Put(1, row, 26, 8)
    end
    Done()

    Section("Loot")
    Option(1, "Item tooltip sources", nil, "tooltips")
    Option(2, "Wishlist drop alerts", nil, "alerts")
    Done()

    Section("Party")
    Option(1, "Share quest progress with party", nil, "partySync")
    Done()

    Section(L.OPT_CARD_DATA)
    Action(1, L.BACKUP, nil, function() Kit.TextWindow(L.BACKUP, FDJ:BuildBackup(), nil, L.BACKUP_HINT) end)
    Action(1, L.RESTORE, nil, restore)
    Action(2, L.FORGET_ALL_SPOTS, nil, function()
        Kit.Confirm(L.FORGET_ALL_SPOTS_Q, function()
            wipe(FDJ.db.spots)
            FDJ:Emit("FDJ_SPOTS")
        end)
    end)
    Done()
    local fullHeight = y + 20
    for _, w in ipairs(collectRest()) do
        if not before[w] then rest[#rest + 1] = w end
    end
    body:SetHeight(fullHeight)

    local function refresh()
        for _, fn in ipairs(refreshers) do fn() end
        local on = FDJ.db and FDJ.db.options.enabled ~= false
        local live = not FDJ.off
        for _, w in ipairs(rest) do w:SetAlpha((on and live) and 1 or 0.4) end
        local pending = (on and FDJ.off) or (not on and not FDJ.off) or FDJ.reloadPending
        reloadBtn:SetShown(pending and true or false)
    end
    FDJ.settingsRefresh = function() if page:IsVisible() then refresh() end end
    page:HookScript("OnShow", refresh)
    FDJ:On("FDJ_OPTION", function() if page:IsVisible() then refresh() end end)
    refresh()
end

local function initDock()
    if WorldMapFrame then
        FDJ.Dock.Init()
        return true
    end
    return false
end

FDJ:On("ADDON_LOADED", function(name)
    if name == FDJ.addon then
        FDJ:LoadStore()
    elseif name == "Blizzard_WorldMap" and FDJ.db then
        initDock()
    end
end)

FDJ:On("PLAYER_LOGIN", function()
    FDJ:LoadStore()
    FDJ.SyncTheme()
    hookTooltips()
    initDock()
    FDJ.Pocket.Apply()
    SLASH_FOJJICOREDJ1 = "/fdj"
    SlashCmdList.FOJJICOREDJ = slash
end)

FDJ:On("FDJ_ROUTE_OFFER", offer)

local keyButton = CreateFrame("Button", "FojjiCoreJournalKey", UIParent)
keyButton:SetScript("OnClick", function()
    if FDJ.off then return end
    if FDJ.Journal and FDJ.Journal.Toggle then FDJ.Journal.Toggle() end
end)
local keyPending = false
function FDJ.ApplyJournalKey()
    if InCombatLockdown and InCombatLockdown() then keyPending = true return end
    keyPending = false
    ClearOverrideBindings(keyButton)
    local key = not FDJ.off and FDJ.db and FDJ.db.options.journalKey
    if key and key ~= "" then SetOverrideBindingClick(keyButton, false, key, "FojjiCoreJournalKey") end
end
FDJ:On("PLAYER_LOGIN", function() FDJ.ApplyJournalKey() end)
FDJ:On("PLAYER_REGEN_ENABLED", function() if keyPending then FDJ.ApplyJournalKey() end end)
