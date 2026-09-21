local _, Addon = ...

function Addon.CreateSpeedrunPage(page, UI)
    local SR = FojjiCore.Speedrun
    local D = Addon.SRData
    local Menu = Addon.OptionsMenu
    local SharedMedia = LibStub("LibSharedMedia-3.0")
    local db = SR:GetStore()
    local COLW = 300
    local refreshers, syncing = {}, false

    local scroll = UI.Scroll(page)
    scroll:SetPoint("TOPLEFT", 0, -50)
    scroll:SetPoint("BOTTOMRIGHT", -18, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(640, 1600)
    scroll:SetScrollChild(body)
    scroll:SetScript("OnSizeChanged", function(_, width) body:SetWidth(width) end)

    local activeParent = body
    local y, cy = 0, { 0, 0 }

    local containerY, containerCy = 0, { 0, 0 }
    local function Begin(title, container)
        if container then
            activeParent = container
            containerY, containerCy = 0, { 0, 0 }
        else
            activeParent = body
        end
        local yy, cyy = container and containerY or y, container and containerCy or cy
        yy = yy + 12
        local label = UI.Text(activeParent, title, 12, "accent")
        label:SetPoint("TOPLEFT", 0, -yy)
        local line = UI.Texture(activeParent, "ARTWORK", "borderDim")
        line:SetPoint("TOPLEFT", 0, -(yy + 17))
        line:SetPoint("TOPRIGHT", 0, -(yy + 17))
        line:SetHeight(1)
        yy = yy + 26
        cyy[1], cyy[2] = yy, yy
        if container then containerY, containerCy = yy, cyy else y, cy = yy, cyy end
    end
    local function Put(col, widget, height, gap)
        local cyy = (activeParent == body) and cy or containerCy
        widget:SetPoint("TOPLEFT", activeParent, "TOPLEFT", (col - 1) * (COLW + 24), -cyy[col])
        cyy[col] = cyy[col] + height + (gap or 6)
    end
    local function End()
        if activeParent == body then y = math.max(cy[1], cy[2]) + 4
        else containerY = math.max(containerCy[1], containerCy[2]) + 4 end
    end

    local function Refresh()
        local was = syncing
        syncing = true
        for _, fn in ipairs(refreshers) do fn() end
        syncing = was
    end
    local function Changed() if not syncing then SR:Notify() end end

    local function Note(col, text)
        local t = UI.Text(activeParent, text, 10, "dim")
        t:SetWidth(COLW)
        t:SetJustifyH("LEFT")
        t:SetHeight(28)
        Put(col, t, 28, 4)
        return t
    end

    local function Check(col, text, key, opts)
        opts = opts or {}
        local function get()
            if opts.get then return opts.get() end
            local value = db[key]
            if opts.invert then value = not value end
            return value and true or false
        end
        local function set(value)
            if opts.set then opts.set(value)
            elseif opts.invert then db[key] = not value
            else db[key] = value end
        end
        local box = UI.Checkbox(activeParent, text, function(value)
            if syncing then return end
            set(value)
            if opts.after then opts.after(value) end
            Changed()
        end)
        box:SetWidth(COLW)
        refreshers[#refreshers + 1] = function() box:SetChecked(get()) end
        Put(col, box, 22, 4)
        return box
    end

    local function Choice(col, label, key, options, after, width)
        local title = UI.Text(activeParent, label, 11, "text")
        title:SetHeight(14)
        Put(col, title, 14, 3)
        local button = Menu.Button(UI, activeParent, width or COLW, 24)
        local function Text()
            for _, option in ipairs(options) do if option.value == db[key] then return option.text end end
            return tostring(db[key])
        end
        button:SetLabel(Text())
        button:SetScript("OnClick", function(self)
            Menu.Open(self, function()
                local list = {}
                for _, option in ipairs(options) do
                    list[#list + 1] = { text = option.text, checked = db[key] == option.value, onClick = function()
                        db[key] = option.value
                        button:SetLabel(option.text)
                        if after then after(option.value) end
                        Changed()
                        Refresh()
                    end }
                end
                return list
            end)
        end)
        refreshers[#refreshers + 1] = function() button:SetLabel(Text()) end
        Put(col, button, 24, 8)
        return button
    end

    local function Slider(col, label, key, minValue, maxValue, step, format, after)
        local holder = CreateFrame("Frame", nil, activeParent)
        holder:SetSize(COLW, 34)
        local text = UI.Text(holder, label, 11, "text")
        text:SetPoint("TOPLEFT")
        local value = UI.Text(holder, "", 11, "white")
        value:SetPoint("TOPRIGHT")
        local slider = CreateFrame("Slider", nil, holder)
        slider:SetPoint("TOPLEFT", 0, -19)
        slider:SetPoint("TOPRIGHT", 0, -19)
        slider:SetHeight(12)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(minValue, maxValue)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        local track = UI.Texture(slider, "BACKGROUND", "scroll")
        track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(3)
        local thumb = UI.Texture(slider, "ARTWORK", "accent")
        thumb:SetSize(8, 14)
        slider:SetThumbTexture(thumb)
        local function Show(v) value:SetText(format and format(v) or tostring(v)) end
        refreshers[#refreshers + 1] = function() slider:SetValue(db[key]); Show(db[key]) end
        slider:SetValue(db[key])
        Show(db[key])
        slider:SetScript("OnValueChanged", function(_, raw)
            if syncing then Show(raw); return end
            local v = math.floor(raw / step + 0.5) * step
            v = math.floor(v * 1000 + 0.5) / 1000
            db[key] = v
            Show(v)
            if after then after(v) end
            Changed()
        end)
        Put(col, holder, 34, 6)
        return slider
    end

    local function Action(col, text, width, onClick)
        local button = UI.Button(activeParent, text, width)
        button:SetHeight(24)
        button:SetScript("OnClick", onClick)
        return button
    end

    local function Field(width)
        local holder = CreateFrame("Frame", nil, activeParent)
        holder:SetSize(width, 24)
        UI.Panel(holder)
        local box = CreateFrame("EditBox", nil, holder)
        box:SetPoint("TOPLEFT", 8, -3)
        box:SetPoint("BOTTOMRIGHT", -8, 3)
        box:SetAutoFocus(false)
        box:SetFont(UI.Font, 11, "")
        box:SetTextColor(0.9, 0.92, 0.96)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        return box, holder
    end

    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 0, -118)
    scroll:SetPoint("BOTTOMRIGHT", -18, 0)

    local demo = UI.Button(page, "Demo run", 84)
    demo:SetPoint("TOPLEFT", 0, -50)
    demo:SetHeight(26)
    demo:SetScript("OnClick", function() SR:Demo() end)
    local preview = UI.Button(page, "Preview", 84)
    preview:SetPoint("LEFT", demo, "RIGHT", 6, 0)
    preview:SetHeight(26)
    preview:SetScript("OnClick", function()
        SR.preview = not SR.preview
        if SR.preview then SR.manuallyHidden = nil end
        SR:Notify()
    end)
    local recenter = UI.Button(page, "Reset position", 104)
    recenter:SetPoint("LEFT", preview, "RIGHT", 6, 0)
    recenter:SetHeight(26)
    recenter:SetScript("OnClick", function() if Addon.SRUI then Addon.SRUI.ResetPosition() end end)
    local hint = UI.Text(page, "Demo plays a short sample run. Preview forces the tracker on screen (even outside a raid) so you can see your settings; click it again to let the normal show/hide rules take over.", 10, "dim")
    hint:SetPoint("TOPLEFT", 0, -80)
    hint:SetPoint("TOPRIGHT", 0, -80)
    hint:SetHeight(34)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)

    Begin("WHEN TO SHOW THE TRACKER")
    Choice(1, "Show the tracker", "visibility", {
        { value = "instance", text = "In raids and dungeons" },
        { value = "raid", text = "Only inside raid instances" },
        { value = "group", text = "Whenever I am in a raid group" },
        { value = "run", text = "Only while a run is active" },
        { value = "always", text = "Always" },
        { value = "never", text = "Never (timer still works)" },
    })
    Slider(2, "Hide this long after a run ends (0 = stay)", "hideAfterFinish", 0, 120, 5, function(v) return v == 0 and "stay" or (v .. "s") end)
    Note(2, "A running or finished run always keeps the tracker visible until you reset it.")
    End()

    Begin("TIMER RULES")
    Choice(1, "Start the timer", "startMode", {
        { value = "combat", text = "On the first combat inside the instance" },
        { value = "pull", text = "On the first boss pull" },
        { value = "instance", text = "When I enter the instance" },
        { value = "manual", text = "Only when I press Start" },
    })
    Choice(2, "Finish the run", "finishMode", {
        { value = "final", text = "When the final boss dies" },
        { value = "all", text = "When every listed boss is dead" },
        { value = "manual", text = "Only when I press Stop" },
    })
    Check(1, "Reset when I leave the group", "resetOnLeave")
    Check(1, "Reset when I enter a different instance", "resetOnZone")
    Check(2, "Follow the leader's / assistants' start and reset", "follow")
    Note(2, "Dying and running back never resets the timer.")
    End()

    Begin("LAYOUT")
    Check(1, "Show the boss list", "collapsed", { invert = true })
    Check(1, "Show the status line under the timer", "statusLine")
    Check(1, "Show the control buttons", "buttons")
    Check(1, "Show a comparison footer", "footer")
    Check(1, "Show border", "border")
    Check(1, "Lock position", "locked")
    Check(1, "Expand upwards", "growUp")
    Check(1, "Show tenths of a second", "decimals", {
        get = function() return (db.decimals or 0) > 0 end,
        set = function(value) db.decimals = value and 1 or 0 end,
    })
    Slider(2, "Scale", "scale", 0.5, 1.8, 0.05, function(v) return ("%.2f"):format(v) end)
    Slider(2, "Width", "width", 150, 420, 5)
    Slider(2, "Timer size", "timerSize", 10, 40, 1)
    Slider(2, "Text size", "textSize", 8, 16, 1)
    Slider(2, "Window opacity", "alpha", 0.3, 1, 0.05, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
    Slider(2, "Background opacity", "bgAlpha", 0, 1, 0.05, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
    End()

    Begin("APPEARANCE")
    local fontOptions = {}
    for _, name in ipairs(SharedMedia:List("font") or {}) do fontOptions[#fontOptions + 1] = { value = name, text = name } end
    table.sort(fontOptions, function(a, b) return a.text:lower() < b.text:lower() end)
    if #fontOptions == 0 then fontOptions[1] = { value = "Numen", text = "Numen" } end
    local function FontChoice(col, label, key)
        local title = UI.Text(body, label, 11, "text")
        title:SetHeight(14)
        Put(col, title, 14, 3)
        local button = Menu.Button(UI, body, COLW, 24)
        button:SetLabel(tostring(db[key]))
        button:SetScript("OnClick", function(self)
            Menu.Open(self, function()
                local list = {}
                for _, option in ipairs(fontOptions) do
                    list[#list + 1] = { text = option.text, checked = db[key] == option.value, onClick = function()
                        db[key] = option.value
                        button:SetLabel(option.text)
                        Changed()
                    end }
                end
                return list
            end, { maxRows = 12 })
        end)
        refreshers[#refreshers + 1] = function() button:SetLabel(tostring(db[key])) end
        Put(col, button, 24, 8)
    end
    FontChoice(1, "Timer font", "timerFont")
    FontChoice(1, "Text font", "font")
    Choice(2, "Accent color", "accent", {
        { value = "theme", text = "Follow the FojjiCore window theme" },
        { value = "blue", text = "Blue" }, { value = "red", text = "Red" }, { value = "jade", text = "Jade" },
        { value = "violet", text = "Violet" }, { value = "gold", text = "Gold" }, { value = "white", text = "White" },
    })
    Choice(2, "Ahead / behind colors", "colors", {
        { value = "classic", text = "Green / red" },
        { value = "cool", text = "Blue / orange (colorblind friendly)" },
        { value = "mono", text = "White / grey" },
    })
    Check(2, "Color the boss I am currently fighting", "colorEngaged")
    Choice(2, "Color for the current fight", "engagedColor", {
        { value = "theme", text = "Follow the FojjiCore window theme" },
        { value = "blue", text = "Blue" }, { value = "red", text = "Red" }, { value = "jade", text = "Jade" },
        { value = "violet", text = "Violet" }, { value = "gold", text = "Gold" }, { value = "white", text = "White" },
    })
    End()

    Begin("BOSS LIST")
    Choice(1, "Order", "order", {
        { value = "route", text = "Raid order (rows stay in place)" },
        { value = "kills", text = "Order killed (kills first)" },
    })
    Check(1, "Show bosses I have not killed yet", "showUnkilled")
    Check(1, "Show boss icons", "icons")
    Check(1, "Show time versus the comparison run", "deltas")
    Check(1, "Show pull count (x2, x3...) on retried bosses", "attempts")
    Slider(2, "Row height", "rowHeight", 12, 30, 1)
    Slider(2, "Rows shown before scrolling (0 = all)", "maxRows", 0, 20, 1, function(v) return v == 0 and "all" or tostring(v) end)
    Choice(2, "Row style", "rowStyle", {
        { value = "tint", text = "Tinted rows (green / red)" },
        { value = "minimal", text = "Minimal (colored text only)" },
    })
    Note(2, "Scroll the list with the mouse wheel. It follows the boss you pull.")
    End()

    Begin("BOSS ORDER")
    Note(1, "Set the order bosses are shown in for a raid. Dungeons and unlisted raids always show bosses in the order you actually kill them.")
    local orderKey
    for _, key in ipairs(D.order) do if not D.raids[key].dynamic then orderKey = key; break end end
    local orderRows, orderReset, orderRowsTop, RepositionAfterBossOrder
    local orderButton = Menu.Button(UI, body, COLW, 24)
    local function OrderRaidText() local raid = D.raids[orderKey]; return raid and raid.name or "No raids available" end
    local function RenderOrder()
        local raid = D.raids[orderKey]
        local bosses = raid and D.OrderedBosses(raid, db.bossOrder[orderKey]) or {}
        for index, boss in ipairs(bosses) do
            local row = orderRows[index]
            if not row then
                row = CreateFrame("Frame", nil, body)
                row:SetSize(COLW, 22)
                row.bg = UI.Texture(row, "BACKGROUND", "field")
                row.bg:SetAllPoints()
                row.name = UI.Text(row, "", 11, "text")
                row.name:SetPoint("LEFT", 6, 0)
                row.name:SetPoint("RIGHT", -50, 0)
                row.name:SetJustifyH("LEFT")
                row.up = UI.Button(row, "^", 22)
                row.up:SetPoint("RIGHT", -24, 0)
                row.up:SetHeight(20)
                row.down = UI.Button(row, "v", 22)
                row.down:SetPoint("RIGHT", 0, 0)
                row.down:SetHeight(20)
                orderRows[index] = row
            end
            row.name:SetText(boss.name)
            row.up:SetScript("OnClick", function() SR:MoveBoss(orderKey, boss.id, -1); RenderOrder() end)
            row.down:SetScript("OnClick", function() SR:MoveBoss(orderKey, boss.id, 1); RenderOrder() end)
            row.up:SetShown(index > 1)
            row.down:SetShown(index < #bosses)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(orderRowsTop + (index - 1) * 24))
            row:Show()
        end
        for index = #bosses + 1, #orderRows do orderRows[index]:Hide() end
        orderReset:SetShown(db.bossOrder[orderKey] ~= nil)
        if RepositionAfterBossOrder then RepositionAfterBossOrder() end
    end
    orderButton:SetLabel(OrderRaidText())
    orderButton:SetScript("OnClick", function(self)
        Menu.Open(self, function()
            local list = {}
            for _, key in ipairs(D.order) do
                local raid = D.raids[key]
                if not raid.dynamic then
                    list[#list + 1] = { text = raid.name, tag = raid.expansion, checked = key == orderKey, onClick = function()
                        orderKey = key
                        orderButton:SetLabel(OrderRaidText())
                        RenderOrder()
                    end }
                end
            end
            return list
        end, { maxRows = 12 })
    end)
    Put(1, orderButton, 24, 8)
    orderRowsTop = cy[1]
    orderRows = {}
    local comparisonContainer = CreateFrame("Frame", nil, body)
    comparisonContainer:SetSize(640, 400)
    orderReset = Action(1, "Reset to default order", 160, function()
        SR:SetBossOrder(orderKey, nil)
        RenderOrder()
    end)

    function RepositionAfterBossOrder()
        local raid = D.raids[orderKey]
        local count = raid and #D.OrderedBosses(raid, db.bossOrder[orderKey]) or 0
        local resetY = orderRowsTop + count * 24 + 6
        orderReset:ClearAllPoints()
        orderReset:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -resetY)
        local containerTop = resetY + 24 + 16
        comparisonContainer:ClearAllPoints()
        comparisonContainer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -containerTop)
        y = math.max(y, containerTop + containerY)
        body:SetHeight(y + 20)
    end
    RenderOrder()
    refreshers[#refreshers + 1] = function() orderButton:SetLabel(OrderRaidText()); RenderOrder() end
    Begin("COMPARISON AND RUN HISTORY", comparisonContainer)
    Choice(1, "Compare my run against", "compare", {
        { value = "best", text = "My personal best" },
        { value = "pinned", text = "A run I picked from history" },
        { value = "import", text = "An imported run" },
        { value = "none", text = "Nothing" },
    })

    local historyTitle = UI.Text(activeParent, "Run history (click to compare against, x to delete)", 11, "text")
    historyTitle:SetHeight(14)
    Put(2, historyTitle, 14, 3)
    local historyButton = Menu.Button(UI, activeParent, COLW, 24)
    local function HistoryEntries()
        local list = {}
        local pinned = db.pinned
        for _, entry in ipairs(SR:GetHistory()) do
            local raid = D.raids[entry.key]
            local isBest = db.bests[entry.key] and db.bests[entry.key].id == entry.id
            list[#list + 1] = {
                text = ("%s  %s"):format(SR.FormatTime(entry.final, 1), date("%d %b %H:%M", entry.date or 0)),
                tag = (isBest and "BEST " or "") .. (pinned[entry.key] == entry.id and "PINNED " or "") .. (raid and raid.short or "?"),
                checked = pinned[entry.key] == entry.id,
                onClick = function() SR:PinRun(entry.key, entry.id); Refresh() end,
                onRemove = function() SR:RemoveHistory(entry.id); Refresh() end,
            }
        end
        if #list == 0 then list[1] = { text = "No finished runs yet", disabled = true } end
        return list
    end
    historyButton:SetLabel("Choose a run...")
    historyButton:SetScript("OnClick", function(self) Menu.Open(self, HistoryEntries, { maxRows = 10 }) end)
    Put(2, historyButton, 24, 8)

    local labelTitle = UI.Text(activeParent, "Run label (used when you export or import)", 11, "text")
    labelTitle:SetHeight(14)
    Put(2, labelTitle, 14, 3)
    local labelBox, labelHolder = Field(COLW)
    labelBox:SetMaxLetters(40)
    labelBox:SetText(db.label or "")
    labelBox:SetScript("OnTextChanged", function(self, user) if user then db.label = self:GetText() end end)
    Put(2, labelHolder, 24, 8)

    local stringTitle = UI.Text(activeParent, "Run string (paste to import, copy after export)", 11, "text")
    stringTitle:SetHeight(14)
    Put(1, stringTitle, 14, 3)
    local stringBox, stringHolder = Field(COLW)
    stringBox:SetMaxLetters(4200)
    Put(1, stringHolder, 24, 6)

    local message = UI.Text(activeParent, "", 10, "dim")
    message:SetWidth(COLW * 2 + 24)
    message:SetJustifyH("LEFT")
    message:SetHeight(28)

    local function Export(which)
        local text, err = SR:Export(which)
        if not text then message:SetText(err); return end
        stringBox:SetText(text)
        stringBox:SetFocus()
        stringBox:HighlightText()
        message:SetText("Press Ctrl+C to copy this run string and share it.")
    end
    local exportBest = Action(1, "Export best", 92, function() Export("best") end)
    Put(1, exportBest, 24, 0)
    local exportLast = Action(1, "Export last", 92, function() Export("last") end)
    exportLast:ClearAllPoints()
    exportLast:SetPoint("LEFT", exportBest, "RIGHT", 6, 0)
    local import = Action(1, "Import", 92, function()
        local ok, info = SR:Import(stringBox:GetText())
        if ok then
            db.compare = "import"
            message:SetText("Imported a run for " .. info .. ". Now comparing against it.")
            stringBox:SetText(""); stringBox:ClearFocus()
            Refresh(); Changed()
        else
            message:SetText(info)
        end
    end)
    import:ClearAllPoints()
    import:SetPoint("LEFT", exportLast, "RIGHT", 6, 0)
    containerCy[1] = containerCy[1] + 6

    local confirmBest, confirmClear = false, false
    local resetBest = Action(2, "Reset best time", 120, function(self)
        local route = SR.route
        if not route then message:SetText("Pick a raid first."); return end
        if not confirmBest then
            confirmBest = true
            self.label:SetText("Sure?")
            C_Timer.After(3, function() confirmBest = false; self.label:SetText("Reset best time") end)
            return
        end
        confirmBest = false
        self.label:SetText("Reset best time")
        db.bests[route.key] = nil
        Changed(); message:SetText("Personal best cleared for " .. (route.name or "this raid") .. ".")
    end)
    Put(2, resetBest, 24, 0)
    local clearHistory = Action(2, "Clear all history", 130, function(self)
        if not confirmClear then
            confirmClear = true
            self.label:SetText("Sure?")
            C_Timer.After(3, function() confirmClear = false; self.label:SetText("Clear all history") end)
            return
        end
        confirmClear = false
        self.label:SetText("Clear all history")
        SR:ClearHistory()
        message:SetText("Run history and personal bests cleared.")
        Refresh()
    end)
    clearHistory:ClearAllPoints()
    clearHistory:SetPoint("LEFT", resetBest, "RIGHT", 6, 0)
    containerCy[2] = containerCy[2] + 6
    End()
    message:SetPoint("TOPLEFT", comparisonContainer, "TOPLEFT", 0, -containerY)
    containerY = containerY + 34
    comparisonContainer:SetHeight(containerY + 10)
    RepositionAfterBossOrder()

    local function UpdateStatus()
        preview.label:SetText(SR.preview and "Preview: on" or "Preview")
    end
    local acc = 0
    page:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc > 0.25 then acc = 0; UpdateStatus() end
    end)
    page:SetScript("OnShow", function() Refresh(); UpdateStatus() end)
    page:SetScript("OnHide", function() Menu.Close() end)
    Refresh()
    UpdateStatus()
end
