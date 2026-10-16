local Addon = FojjiCoreNS
if not (Addon and (Addon.IsForever or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)) then return end
if not Addon.ForeverClient then return end
local K = Addon.UIKit
local W = K
local FONT, WHITE, QUESTION = K.FONT, K.WHITE, K.QUESTION
local C, paint, repaint, solid, setFont, T, Border, Surface, Tip, Icon = K.C, K.paint, K.repaint, K.solid, K.setFont, K.T, K.Border, K.Surface, K.Tip, K.Icon
local Caption, openMenu, Glyph, Sheen = K.Caption, K.openMenu, K.Glyph, K.Sheen
local DEMO_LENGTHS = { 30, 60, 90, 120, 180 }
local CHANNELS = { "Master", "SFX", "Dialog", "Music", "Ambience" }

local Picker
local function buildPicker()
    local ROWS, ROW_H, W_ = 13, 24, 340
    local p = CreateFrame("Frame", "FojjiCoreSoundPicker", UIParent)
    p:SetSize(W_, 420)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    Surface(p, "frame", 0.98, "accent", 0.8)
    Sheen(p, 60, 0.10)
    p:Hide()
    if Addon.EscapeCloses then Addon.EscapeCloses("FojjiCoreSoundPicker") end

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:Hide()
    catcher:SetScript("OnClick", function() p:Hide() end)
    p:SetScript("OnHide", function() catcher:Hide() end)

    p.title = T(p, 14, "white")
    p.title:SetPoint("TOPLEFT", 14, -12)
    p.title:SetText("Choose a sound")
    p.sub = T(p, 11, "dim")
    p.sub:SetPoint("TOPLEFT", 14, -30)
    p.sub:SetPoint("RIGHT", -14, 0)
    p.search = W.Search(p, W_ - 28, function() p.offset = 0; p:Filter() end)
    p.search:SetPoint("TOPLEFT", 14, -50)

    p.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, p)
        r:SetSize(W_ - 44, ROW_H)
        r:SetPoint("TOPLEFT", 14, -86 - (i - 1) * ROW_H)
        r.hl = solid(r:CreateTexture(nil, "BACKGROUND"), "accent", 0.16)
        r.hl:SetAllPoints()
        r.hl:Hide()
        r.sel = solid(r:CreateTexture(nil, "ARTWORK"), "accent", 1)
        r.sel:SetWidth(2)
        r.sel:SetPoint("TOPLEFT"); r.sel:SetPoint("BOTTOMLEFT")
        r.t = T(r, 12, "text")
        r.t:SetPoint("LEFT", 10, 0)
        r.t:SetPoint("RIGHT", -34, 0)
        r.play = W.Button(r, "", 26, 20, nil, "icon-play")
        r.play:SetPoint("RIGHT", -2, 0)
        Tip(r.play, "Preview")
        r.play:SetScript("OnClick", function()
            local e = r.entry
            if not e or not e.value or e.value == "none" then return end
            FojjiCore.RaidPacks:PlaySoundValue(e.value, (p.text and p.text ~= "") and p.text or "Debuff", p.channel)
        end)
        r:SetScript("OnEnter", function(self) if self.entry and not self.entry.header then self.hl:Show() end end)
        r:SetScript("OnLeave", function(self) self.hl:Hide() end)
        r:SetScript("OnClick", function(self)
            local e = self.entry
            if not e or e.header then return end
            p:Hide()
            if p.onPick then p.onPick(e.value) end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, d) p:Scroll(d) end)
        p.rows[i] = r
    end
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, d) p:Scroll(d) end)

    local bar = CreateFrame("Slider", nil, p)
    bar:SetPoint("TOPRIGHT", -12, -86)
    bar:SetSize(8, ROWS * ROW_H)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    local track = solid(bar:CreateTexture(nil, "BACKGROUND"), "borderDim", 1)
    track:SetAllPoints()
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetSize(8, 40)
    paint(function() local r, g, b = C("accent"); thumb:SetVertexColor(r, g, b, 0.85) end)
    bar:SetThumbTexture(thumb)
    bar:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if v ~= p.offset then p.offset = v; p:Render(true) end
    end)
    p.bar = bar

    function p:Scroll(d)
        local maxOff = math.max(0, #self.view - ROWS)
        self.offset = math.max(0, math.min(maxOff, (self.offset or 0) - d * 3))
        self:Render()
    end

    function p:BuildAll()
        local all = {}
        if self.withTTS then
            all[#all + 1] = { header = true, text = "VOICE" }
            all[#all + 1] = { value = "tts", text = "TTS (voice pack line or text-to-speech)" }
        end
        all[#all + 1] = { value = "none", text = "No sound" }
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            all[#all + 1] = { header = true, text = "SOUNDS" }
            for _, name in ipairs(LSM:List("sound")) do
                if name ~= "None" then all[#all + 1] = { value = "lsm:" .. name, text = name } end
            end
        end
        self.all = all
    end

    function p:Filter()
        local q = (self.search.box:GetText() or ""):lower()
        local view, lastHeader = {}, nil
        for _, e in ipairs(self.all) do
            if e.header then
                lastHeader = e
            elseif q == "" or e.text:lower():find(q, 1, true) then
                if lastHeader then view[#view + 1] = lastHeader; lastHeader = nil end
                view[#view + 1] = e
            end
        end
        self.view = view
        self:Render()
    end

    function p:Render(fromBar)
        local off = self.offset or 0
        for i, r in ipairs(self.rows) do
            local e = self.view[off + i]
            r.entry = e
            if e then
                r:Show()
                r.t:SetText(e.text)
                if e.header then
                    setFont(r.t, 10)
                    r.t:SetColorName("accent")
                    r.play:Hide()
                    r.sel:Hide()
                else
                    setFont(r.t, 12)
                    r.t:SetColorName(e.value == self.current and "white" or "text")
                    r.play:SetShown(e.value ~= "none")
                    r.sel:SetShown(e.value == self.current)
                end
            else
                r:Hide()
            end
        end
        local maxOff = math.max(0, #self.view - ROWS)
        self.bar:SetShown(maxOff > 0)
        self.bar:SetMinMaxValues(0, maxOff)
        if not fromBar then self.bar:SetValue(off) end
        thumb:SetHeight(math.max(24, ROWS * ROW_H * ROWS / math.max(ROWS, #self.view)))
    end

    function p:Open(owner, o)
        self.current, self.text, self.channel, self.onPick = o.current, o.text or "", o.channel, o.onPick
        self.sub:SetText(o.name and ("for " .. o.name) or "")
        if self.withTTS ~= (o.withTTS and true or false) or not self.all then
            self.withTTS = o.withTTS and true or false
            self:BuildAll()
        end
        self.search.box:SetText("")
        self.offset = 0
        self:Filter()
        for i, e in ipairs(self.view) do
            if e.value == self.current then self.offset = math.max(0, math.min(#self.view - ROWS, i - 4)) break end
        end
        self:Render()
        self:ClearAllPoints()
        local bottom = owner.GetBottom and owner:GetBottom()
        local scale = owner.GetEffectiveScale and owner:GetEffectiveScale() or 1
        if bottom and bottom * scale < 440 then
            self:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
        else
            self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
        end
        catcher:Show()
        self:Show()
        self:Raise()
    end
    return p
end

local function openPicker(owner, o)
    Picker = Picker or buildPicker()
    Picker:Open(owner, o)
end

local RAIL_W = 224
local ROW_HEAD = 56
local CARD_HEAD = 34

local AUDIO_LABELS = { "TTS", "Sound" }
local SEP = "  |cFF4a4f58/|r  "

local function audioSummary(RP, pack, key, onField, modeField)
    if not RP:Get(pack, key, onField) then return nil end
    return tonumber(RP:Get(pack, key, modeField)) == 2 and "Sound" or "TTS"
end

local SECTIONS = {
    { key = "timer", title = "Boss timer", icon = "icon-timeline",
      summary = function(RP, pack, key, ab)
          local parts = {}
          if RP:Get(pack, key, "timer") then
              parts[#parts + 1] = RP:Get(pack, key, "emphasize") and ("Timer, emphasize " .. (RP:Get(pack, key, "emphasizeAt") or 10) .. "s") or "Timer"
          end
          if RP:Get(pack, key, "ttsCountdown") then parts[#parts + 1] = "Countdown " .. (RP:Get(pack, key, "countdownFrom") or 5) end
          if ab.allowActive and RP:Get(pack, key, "active") then parts[#parts + 1] = "Effect bar" end
          if #parts == 0 then return nil end
          return table.concat(parts, SEP)
      end,
      controls = {
        { col = "screen", t = "map", f = "mapTo", label = "This timer is",
          tip = "Learned timer: pick which ability it is. From then on this duration uses that ability's name, timer, pre-warning, cast bar and alerts." },
        { col = "screen", t = "input", f = "label", label = "Name (optional)",
          tip = "Your own name for this ability, used on its timer, pre-warning and alerts. Leave empty for the pack's name." },
        { col = "screen", t = "switch", f = "timer", label = "Show boss timer" },
        { col = "screen", t = "color", f = "barColor", label = "Timer colour", dep = "timer",
          tip = "Own colour for this timer. Right-click to go back to the pack colour (Pack settings)." },
        { col = "screen", t = "switch", f = "emphasize", label = "Emphasize near the end", dep = "timer",
          tip = "Moves the timer to the emphasized (big) bars for its last seconds." },
        { col = "screen", t = "stepper", f = "emphasizeAt", label = "Emphasize at", dep = "emphasize", min = 3, max = 30, step = 1 },
        { col = "screen", t = "color", f = "emphColor", label = "Emphasized colour", dep = "emphasize",
          tip = "Own colour for the emphasized bar. Right-click to go back to the pack colour." },
        { col = "screen", t = "switch", f = "active", label = "Effect duration bar",
          tip = "After the cast, a bar for how long the effect lasts (e.g. how long a Death & Decay stays on the ground)." },
        { col = "sound", t = "switch", f = "ttsCountdown", label = "Countdown (TTS)", dep = "emphasize",
          tip = "Counts down out loud on the emphasized bar, using your voice pack or text-to-speech." },
        { col = "sound", t = "stepper", f = "countdownFrom", label = "Count down from", dep = "ttsCountdown", min = 3, max = 10, step = 1, suffix = "" },
    } },
    { key = "prewarn", title = "Pre-warning", icon = "icon-info",
      summary = function(RP, pack, key)
          local parts = {}
          if RP:Get(pack, key, "prewarn") then
              parts[#parts + 1] = RP:LookName("prewarn", RP:Get(pack, key, "pwStyle")) .. " " .. (RP:Get(pack, key, "pwt") or 4) .. "s"
          end
          local audio = audioSummary(RP, pack, key, "ttsPrewarn", "pwAudio")
          if audio then parts[#parts + 1] = audio .. " " .. (RP:Get(pack, key, "pwAudioAt") or 4) .. "s" end
          if #parts == 0 then return nil end
          return table.concat(parts, " + ") .. " before"
      end,
      controls = {
        { col = "screen", t = "switch", f = "prewarn", label = "Pre-warning on screen" },
        { col = "screen", t = "looks", f = "pwStyle", moment = "prewarn", label = "Look", dep = "prewarn",
          tip = "How the pre-warning shows - pick one or more. Each look is one of the raid pack's display auras (move and style them in /wa)." },
        { col = "screen", t = "stepper", f = "pwt", label = "Seconds before cast", dep = "prewarn", min = 1, max = 30, step = 0.5 },
        { col = "screen", t = "input", f = "pwText", label = "Warning text", dep = "prewarn" },
        { col = "sound", t = "switch", f = "ttsPrewarn", label = "Before the cast",
          tip = "A sound or TTS before the cast - with or without the on-screen pre-warning, at its own time." },
        { col = "sound", t = "stepper", f = "pwAudioAt", label = "Seconds before cast", dep = "ttsPrewarn", min = 0.5, max = 30, step = 0.5 },
        { col = "sound", t = "segment", f = "pwAudio", label = "Play", dep = "ttsPrewarn", labels = AUDIO_LABELS },
        { col = "sound", t = "input", f = "ttsPrewarnText", label = "TTS text", dep = "ttsPrewarn", depEq = { "pwAudio", 1 }, speak = true },
        { col = "sound", t = "sound", f = "pwSoundFile", label = "Sound", dep = "ttsPrewarn", depEq = { "pwAudio", 2 } },
    } },
    { key = "cast", title = "Cast bar", icon = "icon-stopwatch", needsCast = true,
      summary = function(RP, pack, key)
          local parts = {}
          if RP:Get(pack, key, "cast") then parts[#parts + 1] = RP:LookName("cast", RP:Get(pack, key, "castStyle")) end
          local audio = audioSummary(RP, pack, key, "endAudio", "endAudioMode")
          if audio then parts[#parts + 1] = audio .. " at the end" end
          if #parts == 0 then return nil end
          return table.concat(parts, SEP)
      end,
      controls = {
        { col = "screen", t = "info", f = "castInfo" },
        { col = "screen", t = "switch", f = "cast", label = "Show cast bar" },
        { col = "screen", t = "looks", f = "castStyle", moment = "cast", label = "Look", dep = "cast",
          tip = "How the cast shows - pick one or more. Cast bar: the cast bar group.  Big bar: the special alert bar.  Icon: the icon alerts." },
        { col = "screen", t = "input", f = "castText", label = "Cast bar text", dep = "cast" },
        { col = "sound", t = "switch", f = "endAudio", label = "When the cast ends",
          tip = "Plays when the boss finishes casting it - e.g. \"Safe\" or \"Go back in\"." },
        { col = "sound", t = "segment", f = "endAudioMode", label = "Play", dep = "endAudio", labels = AUDIO_LABELS },
        { col = "sound", t = "input", f = "endTtsText", label = "TTS text", dep = "endAudio", depEq = { "endAudioMode", 1 }, speak = true,
          tip = "Empty = \"<name> done\"." },
        { col = "sound", t = "sound", f = "endSoundFile", label = "Sound", dep = "endAudio", depEq = { "endAudioMode", 2 } },
    } },
    { key = "oncast", title = "On cast", icon = "icon-raid",
      summary = function(RP, pack, key)
          local parts = {}
          if RP:Get(pack, key, "alert") then parts[#parts + 1] = RP:LookName("alert", RP:Get(pack, key, "style")) end
          local audio = audioSummary(RP, pack, key, "tts", "castAudio")
          if audio then parts[#parts + 1] = audio end
          if #parts == 0 then return nil end
          return table.concat(parts, " + ")
      end,
      controls = {
        { col = "screen", t = "switch", f = "alert", label = "Alert on screen" },
        { col = "screen", t = "looks", f = "style", moment = "alert", label = "Alert look", dep = "alert",
          tip = "How the alert shows - pick one or more. Each look is one of the raid pack's display auras (move and style them in /wa)." },
        { col = "screen", t = "input", f = "alertText", label = "Alert text", dep = "alert" },
        { col = "screen", t = "input", f = "tauntText", label = "Off-tank alert text", dep = "alert" },
        { col = "screen", t = "switch", f = "roleOnly", label = "Only my role / active tank",
          tip = "The alert and the cast-start audio only play for the role this ability is for (tank abilities: the tank who has to act)." },
        { col = "sound", t = "switch", f = "tts", label = "When the cast starts",
          tip = "Plays the moment the boss starts it - with or without the on-screen alert." },
        { col = "sound", t = "segment", f = "castAudio", label = "Play", dep = "tts", labels = AUDIO_LABELS },
        { col = "sound", t = "input", f = "ttsText", label = "TTS text", dep = "tts", depEq = { "castAudio", 1 }, speak = true },
        { col = "sound", t = "sound", f = "castSoundFile", label = "Sound", dep = "tts", depEq = { "castAudio", 2 } },
    } },
}

local function allowed(ab, field)
    if field == "castInfo" then return true end
    if field == "mapTo" then return ab.duration ~= nil end
    if not ab.fields then return true end
    for _, f in ipairs(ab.fields) do if f == field then return true end end
    return false
end

function Addon.CreateRaidPackPage(page, UI)
    local RP = FojjiCore.RaidPacks
    page.UI = UI
    local st = { pack = nil, boss = nil, query = "", mode = "abilities", view = "boss" }
    local expanded = {}
    local abilityRows, debuffRows = {}, {}
    page.expanded, page.state = expanded, st
    local refresh

    local function castTime(ab) return ab.castTime or RP:GetCastTime(st.pack, ab.key) end
    local function soundLabel(v)
        if type(v) ~= "string" or v == "" or v == "none" then return "Choose a sound..." end
        return RP:SoundLabel(v)
    end

    local packDD = W.Dropdown(page, 260, function(self)
        local entries = {}
        for _, p in ipairs(RP:GetPacks()) do
            local key = p.key
            entries[#entries + 1] = { text = p.name or key, tag = p.version and ("v" .. p.version) or nil, selected = st.pack == key,
                onClick = function() st.pack = key; st.boss = nil; refresh() end }
        end
        openMenu(self, entries)
    end)
    packDD:SetPoint("TOPLEFT", 0, -54)
    local search = W.Search(page, 220, function(text) st.query = (text or ""):lower(); refresh() end)
    search:SetPoint("TOPRIGHT", -18, -54)

    local none = T(page, 13, "text")
    none:SetPoint("TOPLEFT", 0, -110)
    none:SetWordWrap(true)
    none:SetText("No Fojji raid pack found in your ForeverAuras.\n\nImport a Fojji raid pack string - it shows up here automatically (no need to be in the raid).\nUntil you change something, the pack simply runs on its defaults.")

    local rail = CreateFrame("Frame", nil, page)
    rail:SetPoint("TOPLEFT", 0, -94)
    rail:SetPoint("BOTTOMLEFT", 0, 0)
    rail:SetWidth(RAIL_W)
    Surface(rail, "sidebar", 0.6, "borderDim")
    Sheen(rail, 60, 0.05)

    local function railButton(parent)
        local b = CreateFrame("Button", nil, parent)
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetTexture(K.TEX .. "grad-h")
        b.hl:SetAllPoints()
        b.stripe = solid(b:CreateTexture(nil, "ARTWORK"), "accent", 1)
        b.stripe:SetWidth(3)
        b.stripe:SetPoint("TOPLEFT"); b.stripe:SetPoint("BOTTOMLEFT")
        b.name = T(b, 13, "text")
        b.badge = T(b, 11, "accent", "RIGHT")
        b.badge:SetPoint("RIGHT", -10, 0)
        function b:Paint()
            local sel = self.isSelected and self.isSelected()
            local r, g, bl = C("accent")
            if sel then self.hl:SetVertexColor(r, g, bl, 0.30)
            elseif self.hover then self.hl:SetVertexColor(1, 1, 1, 0.07)
            else self.hl:SetVertexColor(0, 0, 0, 0) end
            self.stripe:SetShown(sel and true or false)
            self.name:SetTextColor(C((sel or self.hover) and "white" or "text"))
            if self.glyph then self.glyph:SetColorName((sel or self.hover) and "accent" or "dim") end
        end
        b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
        b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
        return b
    end

    local packBtn = railButton(rail)
    packBtn:SetPoint("TOPLEFT", 1, -8)
    packBtn:SetPoint("RIGHT", -1, 0)
    packBtn:SetHeight(36)
    packBtn.glyph = Glyph(packBtn, "icon-gear", 18, "dim")
    packBtn.glyph:SetPoint("LEFT", 16, 0)
    packBtn.name:SetPoint("LEFT", packBtn.glyph, "RIGHT", 12, 0)
    packBtn.name:SetText("Pack settings")
    packBtn.isSelected = function() return st.view == "pack" end
    packBtn:SetScript("OnClick", function() st.view = "pack"; refresh() end)

    local railTitle = T(rail, 12, "tab")
    railTitle:SetPoint("TOPLEFT", 14, -56)
    railTitle:SetText("Encounters")
    local railLine = solid(rail:CreateTexture(nil, "ARTWORK"), "borderDim", 1)
    railLine:SetHeight(1)
    railLine:SetPoint("TOPLEFT", 12, -48)
    railLine:SetPoint("TOPRIGHT", -12, -48)

    local bossButtons = {}
    local railScroll = UI.Scroll(rail)
    railScroll:SetPoint("TOPLEFT", 1, -70)
    railScroll:SetPoint("BOTTOMRIGHT", -12, 50)
    local railBody = CreateFrame("Frame", nil, railScroll)
    railBody:SetSize(RAIL_W - 14, 10)
    railScroll:SetScrollChild(railBody)
    railScroll:HookScript("OnSizeChanged", function(_, w) railBody:SetWidth(w) end)
    local function bossButton(i)
        local b = bossButtons[i]
        if b then return b end
        b = railButton(railBody)
        b.icon = Icon(b, 22)
        b.icon:SetPoint("LEFT", 12, 0)
        b.name:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
        b.name:SetPoint("RIGHT", -26, 0)
        b:HookScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.name:GetText() or "", 1, 1, 1)
            if self.changed and self.changed > 0 then
                GameTooltip:AddLine(self.changed .. " setting" .. (self.changed == 1 and "" or "s") .. " changed from the pack defaults", 1, 0.9, 0.4)
            end
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b.isSelected = function() return st.view == "boss" and b.key == st.boss end
        b:SetScript("OnClick", function(self) st.view = "boss"; st.boss = self.key; page.scroll:SetVerticalScroll(0); refresh() end)
        bossButtons[i] = b
        return b
    end

    local function bossIcon(boss)
        if boss.icon then return boss.icon end
        for _, ab in ipairs(RP:GetAbilities(st.pack, boss.key)) do
            if ab.icon and ab.icon ~= QUESTION then return ab.icon end
        end
        return QUESTION
    end

    local demoRaid = W.Button(rail, "Demo whole raid", 100, 28, nil, "icon-play")
    demoRaid:SetPoint("BOTTOMLEFT", 12, 12)
    demoRaid:SetPoint("BOTTOMRIGHT", -12, 12)
    demoRaid:SetScript("OnClick", function() if st.pack then RP:StartDemo(st.pack, "ALL") end end)
    Tip(demoRaid, "Demo the whole raid", "Every boss, one after another. Stop it from any boss or with /fc demo stop.")

    local function refreshRail()
        local bosses = RP:GetBosses(st.pack)
        local avail = (rail:GetHeight() or 400) - 70 - 52
        local bh = math.max(30, math.min(40, math.floor(avail / math.max(1, #bosses))))
        railBody:SetHeight(math.max(10, #bosses * bh))
        for i, boss in ipairs(bosses) do
            local b = bossButton(i)
            b.key = boss.key
            b:SetHeight(bh)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -(i - 1) * bh)
            b:SetPoint("RIGHT", railBody, "RIGHT", 0, 0)
            b.name:SetText(boss.name or boss.key)
            b.icon:SetIcon(bossIcon(boss))
            local n = RP:CountCustomized(st.pack, boss.key) + RP:CountCustomizedDebuffs(st.pack, boss.key)
            b.badge:SetText(n > 0 and tostring(n) or "")
            b.changed = n
            b:Show()
            b:Paint()
        end
        for i = #bosses + 1, #bossButtons do bossButtons[i]:Hide() end
        for i, boss in ipairs(bosses) do
            if boss.key == st.boss and st.view == "boss" then
                local top, viewH = (i - 1) * bh, railScroll:GetHeight() or 300
                local cur = railScroll:GetVerticalScroll() or 0
                if top < cur then railScroll:SetVerticalScroll(top)
                elseif top + bh > cur + viewH then railScroll:SetVerticalScroll(math.max(0, top + bh - viewH)) end
            end
        end
        packBtn:Paint()
        return bosses
    end
    rail:SetScript("OnSizeChanged", function() if st.pack then refreshRail() end end)

    local main = CreateFrame("Frame", nil, page)
    main:SetPoint("TOPLEFT", rail, "TOPRIGHT", 16, 0)
    main:SetPoint("BOTTOMRIGHT", 0, 0)

    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT", -18, 0)
    head:SetHeight(60)
    Surface(head, "panel", 0.95, "borderDim")
    local headGlow = head:CreateTexture(nil, "BACKGROUND", nil, 2)
    headGlow:SetTexture(K.TEX .. "grad-h")
    headGlow:SetPoint("TOPLEFT", 1, -1); headGlow:SetPoint("BOTTOMLEFT", 1, 1)
    headGlow:SetWidth(260)
    paint(function() local r, g, b = C("accent"); headGlow:SetVertexColor(r, g, b, 0.12) end)
    head.icon = Icon(head, 40)
    head.icon:SetPoint("LEFT", 12, 0)
    head.name = T(head, 18, "white")
    head.name:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", 12, -2)
    head.sub = T(head, 12, "dim")
    head.sub:SetPoint("BOTTOMLEFT", head.icon, "BOTTOMRIGHT", 12, 2)
    local right = CreateFrame("Frame", nil, head)
    right:SetPoint("RIGHT", -10, 0)
    right:SetSize(210, 30)
    head.name:SetPoint("RIGHT", right, "LEFT", -10, 0)
    head.sub:SetPoint("RIGHT", right, "LEFT", -10, 0)
    local demoBtn = W.Button(right, "Demo", 84, 28, "primary", "icon-play")
    demoBtn:SetPoint("LEFT", 0, 0)
    demoBtn:SetScript("OnClick", function() if st.pack then RP:StartDemo(st.pack, st.boss or "ALL") end end)
    Tip(demoBtn, "Demo this boss", "Plays the fight's timers with the Fojji - Raid Demo [Forever] aura, anywhere. Inside the raid the pack's own auras play it. Pulling a boss stops it.")
    local stopBtn = W.Button(right, "Stop", 64, 28, nil, "icon-stop")
    stopBtn:SetPoint("LEFT", demoBtn, "RIGHT", 6, 0)
    stopBtn:SetScript("OnClick", function() if st.pack then RP:StopDemo(st.pack) end end)
    local lenDD = W.Dropdown(right, 62, function(self)
        if not st.pack then return end
        local cur = RP:GetGlobal(st.pack, "demoLength") or 90
        local entries = {}
        for _, s in ipairs(DEMO_LENGTHS) do
            entries[#entries + 1] = { text = s .. " seconds", selected = cur == s, onClick = function() RP:SetGlobal(st.pack, "demoLength", s) end }
        end
        openMenu(self, entries)
    end)
    lenDD:SetPoint("LEFT", stopBtn, "RIGHT", 6, 0)
    Tip(lenDD, "Demo length")

    local tabBar = CreateFrame("Frame", nil, main)
    tabBar:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
    tabBar:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -10)
    tabBar:SetHeight(32)
    local tabLine = solid(tabBar:CreateTexture(nil, "BACKGROUND"), "borderDim", 1)
    tabLine:SetHeight(1)
    tabLine:SetPoint("BOTTOMLEFT"); tabLine:SetPoint("BOTTOMRIGHT")
    local tabs = {}
    local function tab(mode, glyph)
        local b = CreateFrame("Button", nil, tabBar)
        b:SetHeight(32)
        b.glyph = Glyph(b, glyph, 14, "dim")
        b.glyph:SetPoint("LEFT", 4, 1)
        b.t = T(b, 13, "dim")
        b.t:SetPoint("LEFT", b.glyph, "RIGHT", 7, 0)
        b.line = solid(b:CreateTexture(nil, "ARTWORK"), "accent", 1)
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT"); b.line:SetPoint("BOTTOMRIGHT")
        function b:Paint()
            local on = st.mode == mode
            self.line:SetShown(on)
            self.t:SetTextColor(C(on and "white" or (self.hover and "text" or "dim")))
            self.glyph:SetColorName(on and "accent" or "dim")
        end
        b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
        b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
        b:SetScript("OnClick", function() page.SetMode(mode) end)
        tabs[mode] = b
        return b
    end
    local tabA = tab("abilities", "icon-timeline")
    tabA:SetPoint("BOTTOMLEFT", 0, 0)
    local tabD = tab("debuffs", "icon-speaker")

    local ctx = CreateFrame("Frame", nil, tabBar)
    ctx:SetPoint("TOPRIGHT", 0, -3)
    ctx:SetSize(400, 24)
    local resetBoss = W.Button(ctx, "Reset boss", 104, 24, nil, "icon-reset")
    resetBoss:SetScript("OnClick", function()
        if st.pack and st.boss then RP:ResetBoss(st.pack, st.boss, st.mode == "debuffs") end
    end)
    Tip(resetBoss, "Reset boss", "Everything on this tab for this boss goes back to the pack's defaults.")
    local expandAll = W.Button(ctx, "", 28, 24, nil, "icon-chevron-down")
    Tip(expandAll, "Expand / collapse all")
    expandAll:SetScript("OnClick", function()
        if next(expanded) then
            for k in pairs(expanded) do expanded[k] = nil end
        else
            for _, ab in ipairs(RP:GetAbilities(st.pack, st.boss)) do expanded[ab.key] = true end
        end
        refresh()
    end)
    local forgetBoss = W.Button(ctx, "", 28, 24, nil, "icon-minus")
    forgetBoss:SetScript("OnClick", function()
        if not (st.pack and st.boss) then return end
        if IsShiftKeyDown() then RP:ForgetBoss(st.pack, st.boss); st.boss = nil
        elseif Addon.Print then Addon.Print("Hold SHIFT and click Forget boss to remove this learned boss and everything set up for it.") end
    end)
    Tip(forgetBoss, "Forget boss", "Hold SHIFT: removes this learned boss, its timers and your names for them. It comes back the next time you pull it.")
    local forget = W.Button(ctx, "", 28, 24, nil, "icon-minus")
    forget:SetScript("OnClick", function() if st.pack and st.boss then RP:ForgetDiscovered(st.pack, st.boss) end end)
    Tip(forget, "Forget discovered", "Removes the timers this boss auto-discovered (Forever mode), including your names for them. They come back if seen again.")
    local playAll = W.Button(ctx, "Play all", 86, 24, nil, "icon-play")
    playAll:SetScript("OnClick", function()
        if not st.pack or not st.boss then return end
        local i = 0
        for _, d in ipairs(RP:GetDebuffs(st.pack, st.boss)) do
            if RP:Get(st.pack, d.key, "enabled") then
                local key = d.key
                C_Timer.After(i * 1.4, function() RP:PreviewDebuffSound(st.pack, key) end)
                i = i + 1
            end
        end
    end)
    Tip(playAll, "Play all", "Plays every enabled debuff sound of this boss, one after another.")
    local function placeCtx(list)
        local x = 0
        for _, w in ipairs(list) do
            w:ClearAllPoints()
            w:SetPoint("RIGHT", -x, 0)
            w:Show()
            x = x + w:GetWidth() + 6
        end
    end

    local scroll = UI.Scroll(main)
    scroll:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", -18, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(500, 10)
    scroll:SetScrollChild(body)
    page.scroll = scroll
    local layoutList
    scroll:SetScript("OnSizeChanged", function(_, w) body:SetWidth(w); if layoutList then layoutList() end end)
    local empty = T(main, 13, "text")
    empty:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 2, -18)
    empty:SetPoint("RIGHT", -18, 0)
    empty:SetWordWrap(true)

    local function cardOpen(key, hasSomething)
        local saved = FojjiCoreDB and FojjiCoreDB.raidPackCards and FojjiCoreDB.raidPackCards[key]
        if saved ~= nil then return saved end
        return hasSomething
    end
    local function setCardOpen(key, open)
        FojjiCoreDB = FojjiCoreDB or {}
        FojjiCoreDB.raidPackCards = FojjiCoreDB.raidPackCards or {}
        FojjiCoreDB.raidPackCards[key] = open and true or false
    end

    st.variant = st.variant or {}
    local function layer(ab)
        local vi = st.variant[ab.key]
        if vi and not RP:GetVariants(st.pack, ab.key)[vi] then
            st.variant[ab.key] = nil
            vi = nil
        end
        return vi
    end
    local function get(ab, field)
        local vi = layer(ab)
        if vi then return RP:GetVariantValue(st.pack, ab.key, vi, field) end
        return RP:Get(st.pack, ab.key, field)
    end
    local function isCustom(ab, field)
        local vi = layer(ab)
        if vi then return RP:IsVariantSet(st.pack, ab.key, vi, field) end
        return RP:IsCustomized(st.pack, ab.key, field)
    end
    local function set(ab, field, value)
        local vi = layer(ab)
        if vi then RP:SetVariantField(st.pack, ab.key, vi, field, value) return end
        RP:Set(st.pack, ab.key, field, value)
    end
    local function reset(ab, field)
        local vi = layer(ab)
        if vi then RP:SetVariantField(st.pack, ab.key, vi, field, nil) return end
        RP:Set(st.pack, ab.key, field, RP:GetDefault(st.pack, ab.key, field))
    end
    local function baseValue(ab, field)
        if layer(ab) then return RP:Get(st.pack, ab.key, field) end
        return RP:GetDefault(st.pack, ab.key, field)
    end
    local function layerRP(ab)
        return setmetatable({ Get = function(_, _, _, field) return get(ab, field) end }, { __index = RP })
    end

    local function buildDetail(row)
        local d = CreateFrame("Frame", nil, row)
        d:SetPoint("TOPLEFT", 0, -ROW_HEAD)
        d:SetPoint("RIGHT", 0, 0)
        d.line = solid(d:CreateTexture(nil, "ARTWORK"), "borderDim", 1)
        d.line:SetHeight(1)
        d.line:SetPoint("TOPLEFT", 14, 0)
        d.line:SetPoint("TOPRIGHT", -14, 0)
        d.tabBtns = {}
        d.addRule = W.Button(d, "Cast rule", 104, 24, nil, "icon-plus")
        Tip(d.addRule, "Add a cast rule", "Make particular casts different: change any setting for e.g. cast 3 only - another alert text, another look, another sound, or switch something off. Everything you don't change follows Every cast.")
        d.addRule:SetScript("OnClick", function()
            local ab = row.ab
            if not ab then return end
            st.addingRule = st.addingRule or {}
            st.addingRule[ab.key] = not st.addingRule[ab.key] or nil
            refresh()
        end)
        local function addRule(spec)
            local ab = row.ab
            if not ab then return end
            spec = RP:CleanCasts(spec)
            if not spec then
                d.ruleError:Show()
                return
            end
            st.variant[ab.key] = RP:AddVariant(st.pack, ab.key, spec)
            st.addingRule[ab.key] = nil
            d.ruleInput:SetValue("")
            refresh()
        end
        d.ruleInput = W.Input(d, function(v) if v and v ~= "" then addRule(v) end end)
        d.ruleInput:SetSize(250, 26)
        d.ruleInput.box:SetScript("OnTextChanged", function(self)
            d.ruleHint2:SetShown(self:GetText() == "")
            d.ruleError:Hide()
        end)
        d.ruleHint2 = T(d.ruleInput, 12, "dim")
        d.ruleHint2:SetPoint("LEFT", 9, 0)
        d.ruleHint2:SetText("Which casts?  3   1, 3   2-4   3+")
        d.ruleAdd = W.Button(d, "Add", 64, 26, "primary")
        d.ruleAdd:SetScript("OnClick", function() addRule(d.ruleInput.box:GetText()) end)
        d.ruleOdd = W.Button(d, "Odd casts", 92, 26)
        d.ruleOdd:SetScript("OnClick", function() addRule("odd") end)
        d.ruleEven = W.Button(d, "Even casts", 96, 26)
        d.ruleEven:SetScript("OnClick", function() addRule("even") end)
        d.ruleError = T(d, 12, "warning")
        d.ruleError:SetText("Use cast numbers: 3   or   1, 3   or   2-4   or   3+")
        d.ruleError:Hide()
        d.removeRule = W.Button(d, "Remove rule", 112, 24, "danger", "icon-minus")
        d.removeRule:SetScript("OnClick", function()
            local ab = row.ab
            local vi = ab and st.variant[ab.key]
            if not vi then return end
            RP:RemoveVariant(st.pack, ab.key, vi)
            st.variant[ab.key] = nil
            refresh()
        end)
        d.ruleHint = T(d, 12, "dim")
        d.ruleHint:SetWordWrap(true)
        d.sections = {}
        for si, sec in ipairs(SECTIONS) do
            local sf = CreateFrame("Frame", nil, d)
            sf.def = sec
            sf.panel = CreateFrame("Frame", nil, sf)
            sf.panel:SetAllPoints()
            sf.panel:SetFrameLevel(math.max(0, sf:GetFrameLevel() - 1))
            Surface(sf.panel, "frame", 0.45, "borderDim", 0.7)
            sf.head = CreateFrame("Button", nil, sf)
            sf.head:SetPoint("TOPLEFT", 0, 0)
            sf.head:SetPoint("TOPRIGHT", 0, 0)
            sf.head:SetHeight(CARD_HEAD)
            sf.head.hl = sf.head:CreateTexture(nil, "BACKGROUND", nil, 1)
            sf.head.hl:SetTexture(K.TEX .. "grad-h")
            sf.head.hl:SetAllPoints()
            sf.head.hl:Hide()
            paint(function() local r, g, b = C("accent"); sf.head.hl:SetVertexColor(r, g, b, 0.08) end)
            sf.chev = Glyph(sf.head, "icon-chevron-right", 12, "dim")
            sf.chev:SetPoint("LEFT", 10, 0)
            sf.glyph = Glyph(sf.head, sec.icon or "icon-info", 14, "accent")
            sf.glyph:SetPoint("LEFT", sf.chev, "RIGHT", 8, 0)
            sf.title = T(sf.head, 14, "white")
            sf.title:SetPoint("LEFT", sf.glyph, "RIGHT", 8, 0)
            sf.title:SetText(sec.title)
            sf.sum = T(sf.head, 12, "accent", "RIGHT")
            sf.sum:SetPoint("RIGHT", -12, 0)
            sf.sum:SetPoint("LEFT", sf.title, "RIGHT", 16, 0)
            sf.capScreen = Caption(sf, "Display")
            sf.capSound = Caption(sf, "Audio")
            sf.head:SetScript("OnEnter", function() sf.head.hl:Show(); sf.chev:SetColorName("accent") end)
            sf.head:SetScript("OnLeave", function() sf.head.hl:Hide(); sf.chev:SetColorName("dim") end)
            sf.head:SetScript("OnClick", function()
                if not row.ab then return end
                setCardOpen(sec.key, not sf.open)
                refresh()
            end)
            if sec.tip then Tip(sf.head, sec.title, sec.tip) end
            sf.controls = {}
            for ci, def in ipairs(sec.controls) do
                local c
                local onChange = function(v) if row.ab then set(row.ab, def.f, v) end end
                if def.t == "switch" then
                    c = W.SwitchRow(sf, def.label, onChange)
                    c.onReset = function() if row.ab then reset(row.ab, def.f) end end
                elseif def.t == "map" then
                    c = CreateFrame("Frame", nil, sf)
                    c.cap = Caption(c, def.label)
                    c.cap:SetPoint("TOPLEFT", 0, 0)
                    c.w = W.Dropdown(c, 200, function(self)
                        local ab = row.ab
                        if not ab then return end
                        local cur = RP:GetDurationMap(st.pack, ab.boss, ab.duration)
                        local entries = { { text = "Unknown - set it up here", selected = cur == nil,
                            onClick = function() RP:SetDurationMap(st.pack, ab.boss, ab.duration, nil) end } }
                        for _, other in ipairs(RP:GetAbilities(st.pack, ab.boss)) do
                            if not other.duration then
                                local k = other.key
                                entries[#entries + 1] = { text = RP:GetName(st.pack, k), selected = cur == k,
                                    onClick = function() RP:SetDurationMap(st.pack, ab.boss, ab.duration, k) end }
                            end
                        end
                        openMenu(self, entries)
                    end)
                    c.w:SetPoint("TOPLEFT", 0, -19)
                    c.w:SetPoint("RIGHT", 0, 0)
                    c.h = 47
                    c.reset = W.ResetMark(c, function() if row.ab then RP:SetDurationMap(st.pack, row.ab.boss, row.ab.duration, nil) end end)
                    c.reset:SetPoint("LEFT", c.cap, "RIGHT", 4, 0)
                elseif def.t == "info" then
                    c = CreateFrame("Frame", nil, sf)
                    c.text = T(c, 12, "dim")
                    c.text:SetPoint("TOPLEFT")
                    c.text:SetPoint("RIGHT")
                    c.text:SetWordWrap(true)
                    c.h = 20
                elseif def.t == "color" then
                    c = CreateFrame("Frame", nil, sf)
                    c.w = W.ColorSwatch(c, onChange, true, def.label)
                    c.w:SetPoint("LEFT", 0, 0)
                    c.w:SetPoint("RIGHT", -22, 0)
                    c.reset = W.ResetMark(c, function() if row.ab then reset(row.ab, def.f) end end)
                    c.reset:SetPoint("RIGHT", 0, 0)
                    c.h = 26
                else
                    c = CreateFrame("Frame", nil, sf)
                    c.cap = Caption(c, def.label)
                    c.cap:SetPoint("TOPLEFT", 0, 0)
                    if def.t == "stepper" then
                        c.w = W.Stepper(c, def.min, def.max, def.step, onChange, def.suffix)
                    elseif def.t == "input" then
                        c.w = W.Input(c, onChange)
                        c.w:SetPoint("RIGHT", def.speak and -34 or 0, 0)
                        if def.speak then
                            c.play = W.Button(c, "", 28, 28, nil, "icon-play")
                            c.play:SetPoint("TOPRIGHT", 0, -19)
                            Tip(c.play, "Listen", "Speaks it with your voice pack or text-to-speech.")
                            c.play:SetScript("OnClick", function()
                                if not row.ab then return end
                                local txt = c.w.box:GetText()
                                if not txt or txt == "" then
                                    txt = RP:GetName(st.pack, row.ab.key) .. (def.f == "ttsPrewarnText" and " soon" or (def.f == "endTtsText" and " done" or ""))
                                end
                                if FojjiCore.Speak then FojjiCore:Speak(txt) end
                            end)
                        end
                    elseif def.t == "segment" then
                        c.w = W.Segmented(c, def.labels, onChange)
                        c.w:SetPoint("RIGHT", 0, 0)
                    elseif def.t == "looks" then
                        c.w = W.Dropdown(c, 200, function(self)
                            local ab = row.ab
                            if not ab then return end
                            local key, field, moment = ab.key, def.f, def.moment
                            local entries = {}
                            local function current()
                                local have = {}
                                for part in (get(ab, field) or ""):gmatch("[^,]+") do have[part] = true end
                                return have
                            end
                            local function refresh()
                                local have = current()
                                entries[1].checked = not isCustom(ab, field)
                                for i, look in ipairs(RP:GetLooks(moment)) do entries[i + 1].checked = have[look.key] or false end
                            end
                            entries[1] = {
                                text = (layer(ab) and "Same as every cast (" or "Pack default (") .. RP:LookName(moment, baseValue(ab, field)) .. ")",
                                keepOpen = true,
                                onClick = function() reset(ab, field); refresh() end,
                            }
                            for _, look in ipairs(RP:GetLooks(moment)) do
                                entries[#entries + 1] = {
                                    text = look.name,
                                    keepOpen = true,
                                    onClick = function()
                                        local have = current()
                                        if have[look.key] then
                                            have[look.key] = nil
                                            if not next(have) then return end
                                        else
                                            have[look.key] = true
                                        end
                                        local list = {}
                                        for k in pairs(have) do list[#list + 1] = k end
                                        set(ab, field, table.concat(list, ","))
                                        refresh()
                                    end,
                                }
                            end
                            refresh()
                            openMenu(self, entries)
                        end)
                        c.w:SetPoint("RIGHT", 0, 0)
                    elseif def.t == "sound" then
                        c.w = W.Dropdown(c, 200, function(self)
                            if not row.ab then return end
                            openPicker(self, { current = get(row.ab, def.f), name = row.ab.name,
                                channel = RP:GetGlobal(st.pack, "soundChannel"), onPick = onChange })
                        end)
                        c.w:SetPoint("RIGHT", -34, 0)
                        c.play = W.Button(c, "", 28, 28, nil, "icon-play")
                        c.play:SetPoint("TOPRIGHT", 0, -19)
                        c.play:SetScript("OnClick", function()
                            if row.ab then RP:PlaySoundValue(get(row.ab, def.f), nil, RP:GetGlobal(st.pack, "soundChannel")) end
                        end)
                    end
                    c.w:SetPoint("TOPLEFT", 0, -19)
                    c.h = 47
                    c.reset = W.ResetMark(c, function() if row.ab then reset(row.ab, def.f) end end)
                    c.reset:SetPoint("LEFT", c.cap, "RIGHT", 4, 0)
                end
                if def.tip then Tip(c, def.label, def.tip) end
                c.def = def
                sf.controls[ci] = c
            end
            d.sections[si] = sf
        end
        d.foot = T(d, 12, "dim")
        d.foot:SetText("The reset icon next to a setting puts it back to the pack default.")
        d.reset = W.Button(d, "Reset ability", 116, 24, nil, "icon-reset")
        d.reset:SetScript("OnClick", function() if row.ab then RP:ResetAbility(st.pack, row.ab.key) end end)
        row.detail = d
    end

    local function visible(ab, def)
        if not allowed(ab, def.f) then return false end
        if ab.duration and def.f ~= "mapTo" and RP:GetDurationMap(st.pack, ab.boss, ab.duration) then return false end
        if def.dep and not get(ab, def.dep) then return false end
        if def.depOff and get(ab, def.depOff) then return false end
        if def.depEq and (tonumber(get(ab, def.depEq[1])) or 1) ~= def.depEq[2] then return false end
        return true
    end

    local function layoutDetail(row, width)
        local d, ab = row.detail, row.ab
        local pack = st.pack
        local pad, gap = 26, 36
        local inner = width - pad * 2
        local cast = castTime(ab)
        local vi = layer(ab)
        local secs = {}
        local mapped = ab.duration and RP:GetDurationMap(pack, ab.boss, ab.duration)
        for si, sf in ipairs(d.sections) do
            local hide = (sf.def.needsCast and not cast) or (mapped and si > 1)
                or (sf.def.needsField and not allowed(ab, sf.def.needsField))
                or (sf.def.key == "timer" and layer(ab) ~= nil)
            if hide then sf:Hide() else secs[#secs + 1] = sf end
        end
        local function bind(c, def)
            local custom = isCustom(ab, def.f)
            if def.t == "switch" then
                c:SetValue(get(ab, def.f))
                c:SetCustom(custom)
            elseif def.t == "info" then
                c.text:SetText(("Cast time |cFFffffff%.1fs|r%s"):format(cast, ab.castTime and "" or " (seen in combat)"))
            elseif def.t == "map" then
                local m = RP:GetDurationMap(pack, ab.boss, ab.duration)
                c.w:SetText(m and RP:GetName(pack, m) or "Unknown - set it up here")
                c.reset:SetShown(m ~= nil)
            elseif def.t == "color" then
                c.w.fallback = RP:GetBarColor(pack, ab.key, def.f == "emphColor") or { 1, 1, 1 }
                c.w:SetValue(get(ab, def.f))
                c.reset:SetShown(custom)
            else
                local v = get(ab, def.f)
                if def.t == "sound" then
                    c.w:SetText(soundLabel(v))
                elseif def.t == "looks" then
                    c.w:SetText(RP:LookName(def.moment, v) .. (custom and "" or (vi and "  |cFF8a8f98(every cast)|r" or "  |cFF8a8f98(default)|r")))
                else
                    c.w:SetValue(v)
                end
                c.reset:SetShown(custom)
                if def.t == "segment" then c.w:Layout() end
            end
        end
        local function shown(c)
            local def = c.def
            local show = visible(ab, def)
            if def.f == "castInfo" then show = cast ~= nil end
            c:SetShown(show and true or false)
            return show
        end
        local twoCols = inner >= 520
        local colGap = 32
        local colW = twoCols and math.floor((inner - 24 - colGap) / 2) or (inner - 24)
        local variants = RP:GetVariants(pack, ab.key)
        local tabs = { { label = "Every cast" } }
        for i, v in ipairs(variants) do tabs[#tabs + 1] = { label = RP:CastsLabel(v.casts), index = i, set = RP:IsVariantSet(pack, ab.key, i) } end
        local tx = pad
        for i, tab in ipairs(tabs) do
            local b = d.tabBtns[i]
            if not b then
                b = W.Button(d, "", 90, 24)
                d.tabBtns[i] = b
            end
            b.label:SetText(tab.label .. ((tab.index and not tab.set) and "  |cFF8a8f98(empty)|r" or ""))
            b:SetWidth(math.max(84, math.floor((b.label:GetStringWidth() or (#tab.label * 7)) + 26)))
            b:SetKind(tab.index == vi and "primary" or "ghost")
            b:SetScript("OnClick", function()
                st.variant[ab.key] = tab.index
                refresh()
            end)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", tx, -14)
            b:Show()
            tx = tx + b:GetWidth() + 6
        end
        for i = #tabs + 1, #d.tabBtns do d.tabBtns[i]:Hide() end
        d.addRule:ClearAllPoints()
        d.addRule:SetPoint("TOPLEFT", tx + 4, -14)
        d.removeRule:ClearAllPoints()
        d.removeRule:SetPoint("TOPRIGHT", -pad, -14)
        d.removeRule:SetShown(vi ~= nil)
        local y = 14 + 24 + 10
        local adding = st.addingRule and st.addingRule[ab.key]
        for _, w in ipairs({ d.ruleInput, d.ruleAdd, d.ruleOdd, d.ruleEven }) do w:SetShown(adding and true or false) end
        if not adding then d.ruleError:Hide() end
        if adding then
            d.ruleInput:ClearAllPoints()
            d.ruleInput:SetPoint("TOPLEFT", pad, -y)
            d.ruleAdd:ClearAllPoints()
            d.ruleAdd:SetPoint("LEFT", d.ruleInput, "RIGHT", 6, 0)
            d.ruleOdd:ClearAllPoints()
            d.ruleOdd:SetPoint("LEFT", d.ruleAdd, "RIGHT", 14, 0)
            d.ruleEven:ClearAllPoints()
            d.ruleEven:SetPoint("LEFT", d.ruleOdd, "RIGHT", 6, 0)
            d.ruleHint2:SetShown(d.ruleInput.box:GetText() == "")
            y = y + 26 + 8
            d.ruleError:ClearAllPoints()
            d.ruleError:SetPoint("TOPLEFT", pad, -y)
            if d.ruleError:IsShown() then y = y + 20 end
        end
        if vi then
            local label = RP:CastsLabel(variants[vi].casts)
            d.ruleHint:SetText(("Changes here only apply to |cFFffffff%s|r. Anything you don't change follows |cFFffffffEvery cast|r - the boss timer always does."):format(label:lower()))
            d.ruleHint:ClearAllPoints()
            d.ruleHint:SetPoint("TOPLEFT", pad, -y)
            d.ruleHint:SetPoint("RIGHT", -pad, 0)
            d.ruleHint:Show()
            y = y + 24
        else
            d.ruleHint:Hide()
        end
        for _, sf in ipairs(secs) do
            ab.allowActive = allowed(ab, "active")
            local sum = sf.def.summary and sf.def.summary(layerRP(ab), pack, ab.key, ab)
            sf.sum:SetText(sum or "|cFF8a8f98Off|r")
            local open = cardOpen(sf.def.key, sum ~= nil)
            sf.open = open
            sf.chev:SetTexture(K.TEX .. (open and "icon-chevron-down" or "icon-chevron-right"))
            local hgt = CARD_HEAD
            local hasScreen, hasSound = false, false
            for _, c in ipairs(sf.controls) do
                local def = c.def
                local show = visible(ab, def)
                if def.f == "castInfo" then show = cast ~= nil end
                if show then
                    if def.col == "sound" then hasSound = true else hasScreen = true end
                end
            end
            sf.capScreen:SetShown(open and hasScreen and hasSound)
            sf.capSound:SetShown(open and hasScreen and hasSound)
            if open then
                local top = CARD_HEAD + 6
                if hasScreen and hasSound then top = top + 20 end
                local yScreen, ySound = top, top
                local soundX = twoCols and (12 + colW + colGap) or 12
                sf.capScreen:ClearAllPoints()
                sf.capScreen:SetPoint("TOPLEFT", 12, -(CARD_HEAD + 6))
                for _, c in ipairs(sf.controls) do
                    if shown(c) then
                        local soundCol = c.def.col == "sound" and hasScreen
                        c:ClearAllPoints()
                        if soundCol and twoCols then
                            c:SetPoint("TOPLEFT", soundX, -ySound)
                            ySound = ySound + c.h + 8
                        elseif soundCol then
                            ySound = math.max(ySound, yScreen)
                            c:SetPoint("TOPLEFT", 12, -ySound)
                            ySound = ySound + c.h + 8
                            yScreen = ySound
                        else
                            c:SetPoint("TOPLEFT", 12, -yScreen)
                            yScreen = yScreen + c.h + 8
                        end
                        c:SetWidth(colW)
                        c:SetHeight(c.h)
                        bind(c, c.def)
                    end
                end
                sf.capSound:ClearAllPoints()
                if twoCols then
                    sf.capSound:SetPoint("TOPLEFT", soundX, -(CARD_HEAD + 6))
                else
                    sf.capSound:SetPoint("TOPLEFT", 12, -(CARD_HEAD + 6))
                    sf.capSound:Hide()
                end
                hgt = math.max(yScreen, ySound) + 4
            else
                for _, c in ipairs(sf.controls) do c:Hide() end
            end
            sf:Show()
            sf:ClearAllPoints()
            sf:SetPoint("TOPLEFT", pad, -y)
            sf:SetSize(inner, hgt)
            y = y + hgt + 8
        end
        local rowH = 0
        y = y + 2
        d.foot:ClearAllPoints()
        d.foot:SetPoint("TOPLEFT", pad, -y - 5)
        d.reset:ClearAllPoints()
        d.reset:SetPoint("TOPRIGHT", -pad, -y)
        local customised = RP:IsCustomized(pack, ab.key)
        d.foot:SetText(vi and "The reset icon next to a setting puts it back to Every cast."
            or "The reset icon next to a setting puts it back to the pack default.")
        d.reset:SetShown(customised and not vi)
        d.foot:SetShown(customised)
        local h = y + 36
        d:SetHeight(h)
        return h
    end

    local function summary(ab)
        local pack, key = st.pack, ab.key
        local m = ab.duration and RP:GetDurationMap(pack, ab.boss, ab.duration)
        if m then return "|cFF8a8f98is|r " .. RP:GetName(pack, m) end
        local on = {}
        local function add(txt) on[#on + 1] = txt end
        if RP:Get(pack, key, "timer") then
            add(RP:Get(pack, key, "emphasize") and ("Timer |cFF8a8f98" .. (RP:Get(pack, key, "emphasizeAt") or 10) .. "s|r") or "Timer")
        end
        if RP:Get(pack, key, "prewarn") then add("Pre |cFF8a8f98" .. (RP:Get(pack, key, "pwt") or 4) .. "s|r") end
        if castTime(ab) and RP:Get(pack, key, "cast") then add("Cast") end
        if RP:Get(pack, key, "alert") then add("Alert") end
        if RP:Get(pack, key, "tts") or RP:Get(pack, key, "ttsPrewarn") or RP:Get(pack, key, "ttsCountdown")
            or (castTime(ab) and RP:Get(pack, key, "endAudio")) then add("Audio") end
        if #on == 0 then return "|cFF8a8f98Nothing shown|r" end
        return table.concat(on, "  |cFF4a4f58/|r  ")
    end

    local function getAbilityRow(i)
        if abilityRows[i] then return abilityRows[i] end
        local row = CreateFrame("Frame", nil, body)
        Surface(row, "panel", 0.95, "borderDim")
        row.stripe = solid(row:CreateTexture(nil, "ARTWORK"), "accent", 1)
        row.stripe:SetWidth(3)
        row.stripe:SetPoint("TOPLEFT", 0, 0)
        row.stripe:SetPoint("BOTTOMLEFT", 0, 0)
        local hdr = CreateFrame("Button", nil, row)
        hdr:SetPoint("TOPLEFT")
        hdr:SetPoint("TOPRIGHT")
        hdr:SetHeight(ROW_HEAD)
        hdr.hl = hdr:CreateTexture(nil, "BACKGROUND", nil, 1)
        hdr.hl:SetTexture(K.TEX .. "grad-h")
        hdr.hl:SetAllPoints()
        hdr.hl:Hide()
        paint(function() local r, g, b = C("accent"); hdr.hl:SetVertexColor(r, g, b, 0.10) end)
        row.icon = Icon(hdr, 36)
        row.icon:SetPoint("LEFT", 14, 0)
        row.chev = Glyph(hdr, "icon-chevron-right", 16, "dim")
        row.chev:SetPoint("RIGHT", -14, 0)
        row.preview = W.Button(hdr, "", 28, 26, nil, "icon-play")
        row.preview:SetPoint("RIGHT", row.chev, "LEFT", -10, 0)
        row.preview:SetScript("OnClick", function()
            if not row.ab then return end
            local vi = st.variant[row.ab.key]
            local v = vi and RP:GetVariants(st.pack, row.ab.key)[vi]
            RP:PreviewAbility(st.pack, row.ab.key, v and RP:CastsExample(v.casts) or nil)
        end)
        Tip(row.preview, "Preview", "Plays just this ability once, with your settings: its timer, pre-warning, cast bar, alert and audio.")
        row.state = T(hdr, 13, "accent", "RIGHT")
        row.state:SetPoint("RIGHT", row.preview, "LEFT", -12, 0)
        row.name = T(hdr, 15, "white")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -1)
        row.name:SetPoint("RIGHT", row.state, "LEFT", -12, 0)
        row.sub = T(hdr, 12, "dim")
        row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 12, 1)
        row.sub:SetPoint("RIGHT", row.state, "LEFT", -12, 0)
        hdr:SetScript("OnEnter", function() hdr.hl:Show(); row.chev:SetColorName("accent") end)
        hdr:SetScript("OnLeave", function() hdr.hl:Hide(); row.chev:SetColorName("dim") end)
        hdr:SetScript("OnClick", function()
            if not row.ab then return end
            expanded[row.ab.key] = not expanded[row.ab.key] or nil
            refresh()
        end)
        abilityRows[i] = row
        return row
    end

    local TYPE_NAMES = {}
    for _, t in ipairs(RP.TYPES) do TYPE_NAMES[t.key] = t.name:upper() end

    local function bindAbility(row, ab)
        row.ab = ab
        local pack = st.pack
        row.icon:SetIcon(ab.icon)
        row.name:SetText(RP:GetName(pack, ab.key))
        local tags = {}
        local kind = RP:GetKind(pack, ab.key)
        local tc = RP:GetTypeColor(pack, kind)
        if not (ab.discovered and kind == "UNKNOWN") then tags[#tags + 1] = ("|cFF%02x%02x%02x%s|r"):format(math.floor(tc[1] * 255), math.floor(tc[2] * 255), math.floor(tc[3] * 255), TYPE_NAMES[kind] or kind) end
        if ab.mythic then tags[#tags + 1] = "|cFFff9a3dMYTHIC|r" end
        if ab.discovered then tags[#tags + 1] = ab.duration and ("|cFF4fc3f7AUTO " .. ab.duration .. "s|r") or "|cFF4fc3f7AUTO-DISCOVERED|r" end
        if castTime(ab) then tags[#tags + 1] = ("CAST %.1fs"):format(castTime(ab)) end
        local rules = {}
        for _, v in ipairs(RP:GetVariants(pack, ab.key)) do rules[#rules + 1] = RP:CastsLabel(v.casts):upper() end
        if #rules > 0 then tags[#tags + 1] = "|cFF4fc3f7" .. table.concat(rules, ", ") .. "|r" end
        local custom = RP:IsCustomized(pack, ab.key)
        if custom then tags[#tags + 1] = "|cFFffe066CHANGED|r" end
        row.sub:SetText(table.concat(tags, "   "))
        row.stripe:SetShown(custom)
        local roomy = (body:GetWidth() or 600) >= 620
        row.state:SetText(roomy and summary(ab) or "")
        row.state:SetShown(roomy)
        row.chev:SetTexture(K.TEX .. (expanded[ab.key] and "icon-chevron-down" or "icon-chevron-right"))
    end

    local function getDebuffRow(i)
        if debuffRows[i] then return debuffRows[i] end
        local row = CreateFrame("Frame", nil, body)
        Surface(row, "panel", 0.95, "borderDim")
        row.stripe = solid(row:CreateTexture(nil, "ARTWORK"), "accent", 1)
        row.stripe:SetWidth(3)
        row.stripe:SetPoint("TOPLEFT"); row.stripe:SetPoint("BOTTOMLEFT")
        row.toggle = W.Switch(row, function(v) if row.d then RP:Set(st.pack, row.d.key, "enabled", v) end end)
        row.toggle:SetPoint("TOPLEFT", 14, -19)
        Tip(row.toggle, "Enable", "Play a sound when this debuff lands on you.")
        row.icon = Icon(row, 32)
        row.icon:SetPoint("TOPLEFT", 58, -11)
        row.name = T(row, 14, "white")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -1)
        row.sub = T(row, 11, "dim")
        row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 12, 1)
        row.reset = W.Button(row, "", 28, 26, nil, "icon-reset")
        row.reset:SetPoint("TOPRIGHT", -14, -14)
        row.reset:SetScript("OnClick", function() if row.d then RP:ResetAbility(st.pack, row.d.key) end end)
        Tip(row.reset, "Reset", "Back to the pack's default.")
        row.play = W.Button(row, "Play", 70, 26, nil, "icon-play")
        row.play:SetPoint("TOPRIGHT", -48, -14)
        row.play:SetScript("OnClick", function() if row.d then RP:PreviewDebuffSound(st.pack, row.d.key) end end)
        row.name:SetPoint("RIGHT", row.play, "LEFT", -12, 0)
        row.sub:SetPoint("RIGHT", row.play, "LEFT", -12, 0)
        row.soundCap = Caption(row, "Play")
        row.soundCap:SetPoint("TOPLEFT", 58, -54)
        row.pick = W.Dropdown(row, 220, function(self)
            if not row.d then return end
            local d = row.d
            openPicker(self, { current = RP:Get(st.pack, d.key, "sound"), text = RP:Get(st.pack, d.key, "text"), withTTS = true,
                channel = RP:GetGlobal(st.pack, "soundChannel"), name = d.name,
                onPick = function(value) RP:Set(st.pack, d.key, "sound", value) end })
        end)
        row.pick:SetPoint("TOPLEFT", 58, -69)
        row.textCap = Caption(row, "TTS text")
        row.textCap:SetPoint("TOPLEFT", row.pick, "TOPRIGHT", 14, 15)
        row.text = W.Input(row, function(v) if row.d then RP:Set(st.pack, row.d.key, "text", v) end end)
        row.text:SetPoint("TOPLEFT", row.pick, "TOPRIGHT", 14, 0)
        row.text:SetPoint("RIGHT", -14, 0)
        Tip(row.text, "TTS text", "Uses your voice pack's recording of this line when it has one (Audio & Voices), otherwise text-to-speech.")
        debuffRows[i] = row
        return row
    end

    local function bindDebuff(row, d)
        row.d = d
        local pack = st.pack
        local sound = RP:Get(pack, d.key, "sound")
        local text = RP:Get(pack, d.key, "text")
        local enabled = RP:Get(pack, d.key, "enabled")
        local custom = RP:IsCustomized(pack, d.key)
        row.icon:SetIcon(d.icon)
        row.name:SetText(d.name)
        local sub = { "ID " .. d.spellID }
        if d.mythic then sub[#sub + 1] = "|cFFff9a3dMYTHIC|r" end
        if custom then sub[#sub + 1] = "|cFFffe066CHANGED|r" end
        if d.note then sub[#sub + 1] = d.note end
        row.sub:SetText(table.concat(sub, "   "))
        row.stripe:SetShown(custom)
        row.reset:SetShown(custom)
        row.toggle:SetValue(enabled)
        local tts = sound == "tts"
        row.pick:SetText(tts and "TTS" or soundLabel(sound))
        row.textCap:SetShown(tts)
        row.text:SetShown(tts)
        if tts then row.text:SetValue(text) end
        row.icon:SetAlpha(enabled and 1 or 0.4)
        row.name:SetColorName(enabled and "white" or "dim")
        row.pick:SetAlpha(enabled and 1 or 0.5)
        row.text:SetAlpha(enabled and 1 or 0.5)
        local w = body:GetWidth() or 600
        row.pick:SetWidth(math.max(140, math.min(240, math.floor((w - 58 - 28 - 14) / 2))))
    end

    local function matches(item)
        local q = st.query
        if not q or q == "" then return true end
        return (item.name or ""):lower():find(q, 1, true) ~= nil or tostring(item.spellID or ""):find(q, 1, true) ~= nil
    end

    function layoutList()
        local width = body:GetWidth()
        if not width or width < 50 then width = 500 end
        local y = 0
        local rows = st.mode == "debuffs" and debuffRows or abilityRows
        for _, row in ipairs(rows) do
            if row:IsShown() then
                local h
                if st.mode == "debuffs" then
                    h = 110
                else
                    h = ROW_HEAD
                    if expanded[row.ab.key] then
                        if not row.detail then buildDetail(row) end
                        row.detail:Show()
                        h = h + layoutDetail(row, width)
                    elseif row.detail then
                        row.detail:Hide()
                    end
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", body, "RIGHT", 0, 0)
                row:SetHeight(h)
                y = y + h + 6
            end
        end
        body:SetHeight(math.max(10, y))
    end

    function page.SetMode(mode)
        st.mode = mode
        st.view = "boss"
        page.scroll:SetVerticalScroll(0)
        refresh()
    end

    function page.RefreshList()
        local p = RP.packs[st.pack]
        local boss = st.boss and p.bosses[st.boss]
        local abilities = boss and RP:GetAbilities(st.pack, st.boss) or {}
        local debuffs = boss and RP:GetDebuffs(st.pack, st.boss) or {}
        local changedA = boss and RP:CountCustomized(st.pack, st.boss) or 0
        local changedD = boss and RP:CountCustomizedDebuffs(st.pack, st.boss) or 0
        local running = RP:IsDemoRunning(st.pack)

        local sub = { #abilities .. (#abilities == 1 and " ability" or " abilities") }
        if #debuffs > 0 then sub[#sub + 1] = #debuffs .. (#debuffs == 1 and " debuff sound" or " debuff sounds") end
        local changed = changedA + changedD
        sub[#sub + 1] = changed > 0 and ("|cFFffe066" .. changed .. " changed|r") or "pack defaults"
        if running then sub[#sub + 1] = "|cFF5cff8aDemo running|r" end
        head.sub:SetText(table.concat(sub, "   /   "))
        demoBtn.label:SetText(running and "Restart" or "Demo")
        lenDD:SetText((RP:GetGlobal(st.pack, "demoLength") or 90) .. "s")
        local narrow = (head:GetWidth() or 600) < 470
        lenDD:SetShown(not narrow)
        stopBtn:SetShown(not narrow or running)
        right:SetWidth(84 + (stopBtn:IsShown() and 70 or 0) + (lenDD:IsShown() and 68 or 0))

        tabA.t:SetText(("Abilities  |cFF8a8f98%d|r"):format(#abilities))
        tabA:SetWidth(tabA.t:GetStringWidth() + 32)
        tabD.t:SetText(("Debuff sounds  |cFF8a8f98%d|r"):format(#debuffs))
        tabD:SetWidth(tabD.t:GetStringWidth() + 32)
        tabD:ClearAllPoints()
        tabD:SetPoint("BOTTOMLEFT", tabA, "BOTTOMRIGHT", 16, 0)
        tabA:Paint(); tabD:Paint()
        tabD:SetShown(#debuffs > 0 or st.mode == "debuffs")

        for _, w in ipairs({ resetBoss, expandAll, forget, playAll, forgetBoss }) do w:Hide() end
        local list = {}
        if st.mode == "debuffs" then
            for _, d in ipairs(debuffs) do if matches(d) then list[#list + 1] = d end end
            local on = RP:GetGlobal(st.pack, "debuffSounds")
            local ctxList = {}
            if changedD > 0 then ctxList[#ctxList + 1] = resetBoss end
            ctxList[#ctxList + 1] = playAll
            placeCtx(ctxList)
            for _, r in ipairs(abilityRows) do r:Hide() end
            for i, d in ipairs(list) do
                local row = getDebuffRow(i)
                row:Show()
                bindDebuff(row, d)
            end
            for i = #list + 1, #debuffRows do debuffRows[i]:Hide(); debuffRows[i].d = nil end
            for _, r in ipairs(debuffRows) do r:SetAlpha(on and 1 or 0.5) end
            if #debuffs == 0 then
                empty:SetText(boss and "No debuff sounds for this boss in this pack version." or "")
            elseif #list == 0 then
                empty:SetText("Nothing matches your search.")
            else
                empty:SetText("")
            end
        else
            local discovered = false
            for _, ab in ipairs(abilities) do
                if matches(ab) then list[#list + 1] = ab end
                if ab.discovered then discovered = true end
            end
            expandAll.icon:SetTexture(K.TEX .. (next(expanded) and "icon-chevron-up" or "icon-chevron-down"))
            local ctxList = {}
            if changedA > 0 then ctxList[#ctxList + 1] = resetBoss end
            ctxList[#ctxList + 1] = expandAll
            if p.dynamic and boss then ctxList[#ctxList + 1] = forgetBoss
            elseif discovered then ctxList[#ctxList + 1] = forget end
            placeCtx(ctxList)
            for _, r in ipairs(debuffRows) do r:Hide() end
            for i, ab in ipairs(list) do
                local row = getAbilityRow(i)
                row:Show()
                bindAbility(row, ab)
            end
            for i = #list + 1, #abilityRows do abilityRows[i]:Hide(); abilityRows[i].ab = nil end
            if not boss and p.dynamic then
                empty:SetText("No bosses learned yet.\n\nPull any raid boss with this pack loaded: it appears on the left, and every boss timer shows up here as \"Unknown (30s)\" for you to name and set up.")
            elseif #abilities == 0 then
                empty:SetText(boss and "No abilities yet. In Forever mode every boss timer the pack can't name appears here after a pull as \"Unknown (30s)\" - give it a name and set it up like any other ability." or "")
            elseif #list == 0 then
                empty:SetText("Nothing matches your search.")
            else
                empty:SetText("")
            end
        end
        layoutList()
    end

    local packView = CreateFrame("Frame", nil, page)
    packView:SetPoint("TOPLEFT", rail, "TOPRIGHT", 16, 0)
    packView:SetPoint("BOTTOMRIGHT", 0, 0)
    local pstack = K.CardStack(packView, 0, UI)
    local pv = {}

    local colCard = pstack:Add(K.Card(packView, "Boss timer colours",
        "The only look setting outside the auras. Per-ability colours are on each ability (Boss timer section) and always win."))
    local function capRow(caption, widget, h)
        local f = CreateFrame("Frame")
        f.cap = Caption(f, caption)
        f.cap:SetPoint("TOPLEFT", 0, 0)
        widget:SetParent(f)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", 0, -19)
        if widget.fill ~= false then widget:SetPoint("RIGHT", 0, 0) end
        f.h = (h or 28) + 19
        return f
    end
    pv.mode = W.Segmented(UIParent, { "Pack auras", "One colour", "By type" }, function(v) RP:SetGlobal(st.pack, "barColorMode", v) end)
    colCard:Add(capRow("Timer colours", pv.mode), 47, 12)
    pv.single = W.ColorSwatch(UIParent, function(c) if c then RP:SetGlobal(st.pack, "barColor", c) end end, false, "Timer colour")
    pv.single.fill = false
    colCard:Add(pv.single, 26, 10)
    pv.types = CreateFrame("Frame")
    pv.typeSw = {}
    for i, t in ipairs(RP.TYPES) do
        local kind = t.key
        local sw = W.ColorSwatch(pv.types, function(c)
            if c then RP:SetTypeColor(st.pack, kind, c) end
        end, false, t.name)
        sw:SetWidth(170)
        pv.typeSw[i] = sw
    end
    function pv.types:Layout()
        local w = self:GetWidth() or 400
        local per = math.max(1, math.floor(w / 180))
        for i, sw in ipairs(pv.typeSw) do
            sw:ClearAllPoints()
            sw:SetPoint("TOPLEFT", ((i - 1) % per) * 180, -math.floor((i - 1) / per) * 32)
        end
        local h = math.ceil(#pv.typeSw / per) * 32
        if self.h ~= h then
            self.h = h
            for _, it in ipairs(colCard.items) do if it.w == self then it.h = h end end
            pstack:Layout()
        end
    end
    pv.types:SetScript("OnSizeChanged", function(self) self:Layout() end)
    pv.types.h = 128
    colCard:Add(pv.types, 128, 12)
    pv.emode = W.Segmented(UIParent, { "Same as timer", "Own colour" }, function(v) RP:SetGlobal(st.pack, "emphColorMode", v) end)
    colCard:Add(capRow("Emphasized bars", pv.emode), 47, 10)
    pv.emph = W.ColorSwatch(UIParent, function(c) if c then RP:SetGlobal(st.pack, "emphColor", c) end end, false, "Emphasized colour")
    pv.emph.fill = false
    colCard:Add(pv.emph, 26, 6)

    local behCard = pstack:Add(K.Card(packView, "Timers"))
    local function gswitch(card, field, label, tip)
        local r = W.SwitchRow(UIParent, label, function(v) if st.pack then RP:SetGlobal(st.pack, field, v) end end)
        card:Add(r, 24, 8)
        if tip then Tip(r, label, tip) end
        pv[field] = r
    end
    gswitch(behCard, "emphasizeAll", "Emphasize every boss timer", "Every timer moves to the emphasized bars near the end (each ability's Emphasize at).")
    gswitch(behCard, "showUnknown", "Show unknown boss timers", "Timers the pack can't name yet still show, as \"Boss Ability (Xs)\".")
    gswitch(behCard, "autoDiscover", "Auto-discover spells", "Forever mode: spells the pack doesn't know get their own timer and appear in the boss list.")

    local sndCard = pstack:Add(K.Card(packView, "Debuff sounds"))
    gswitch(sndCard, "debuffSounds", "Play debuff sounds", "Master switch for this pack's debuff sounds.")
    pv.channel = W.Dropdown(UIParent, 180, function(self)
        if not st.pack then return end
        local cur = RP:GetGlobal(st.pack, "soundChannel") or "Master"
        local entries = {}
        for _, c in ipairs(CHANNELS) do
            entries[#entries + 1] = { text = c, selected = cur == c, onClick = function() RP:SetGlobal(st.pack, "soundChannel", c) end }
        end
        openMenu(self, entries)
    end)
    pv.channel.fill = false
    sndCard:Add(capRow("Sound channel", pv.channel), 47, 6)

    local gosCard = pstack:Add(K.Card(packView, "Inside this raid",
        "Auto gossip answers NPC dialogue for you: the option you picked last time for that NPC, else the first one. Hold SHIFT to skip. Boss teleports the pack marks are never picked."))
    pv.gosCard = gosCard
    gswitch(gosCard, "autoGossip", "Auto-select gossip in this raid", "Hold SHIFT while talking to an NPC to answer yourself. What you pick yourself is remembered for that NPC.")
    local grow = CreateFrame("Frame")
    pv.gosInfo = T(grow, 12, "dim")
    pv.gosForget = W.Button(grow, "Forget my choices", 150, 26, nil, "icon-reset")
    pv.gosForget:SetPoint("LEFT", 0, 0)
    pv.gosForget:SetScript("OnClick", function() if st.pack then RP:ForgetGossip(st.pack) end end)
    Tip(pv.gosForget, "Forget my choices", "Auto gossip goes back to the first option for every NPC in this raid.")
    pv.gosInfo:SetPoint("LEFT", pv.gosForget, "RIGHT", 12, 0)
    gosCard:Add(grow, 26, 6)
    gswitch(gosCard, "skipCinematics", "Skip cinematics", "Cinematics and movies that play inside this raid are skipped straight away.")

    local expCard = pstack:Add(K.Card(packView, "Export"))
    local erow = CreateFrame("Frame")
    local expBtn = W.Button(erow, "Export settings", 140, 26, nil, "icon-export")
    expBtn:SetPoint("LEFT", 0, 0)
    expBtn:SetScript("OnClick", function()
        if not st.pack then return end
        local text = RP:ExportDefaults(st.pack)
        if text then
            K.CopyBox("Export: " .. (RP.packs[st.pack].name or st.pack), text,
                "Copy it and send it to the pack author.", false)
        end
    end)
    Tip(expBtn, "Export settings", "Everything set up for this pack as one line of text. Shipped with the pack, it becomes everyone's default.")
    pv.expInfo = T(erow, 12, "dim")
    pv.expInfo:SetPoint("LEFT", expBtn, "RIGHT", 12, 0)
    expCard:Add(erow, 28, 6)

    local resetCard = pstack:Add(K.Card(packView, "Reset", "Hold SHIFT and click: every ability, debuff sound, colour and option of this pack goes back to the pack defaults."))
    local rrow = CreateFrame("Frame")
    local resetPack = W.Button(rrow, "Reset pack", 130, 28, "danger", "icon-reset")
    resetPack:SetPoint("LEFT", 0, 0)
    resetPack:SetScript("OnClick", function()
        if not st.pack then return end
        if IsShiftKeyDown() then RP:ResetPack(st.pack)
        elseif Addon.Print then Addon.Print("Hold SHIFT and click Reset pack to reset every setting of this pack.") end
    end)
    resetCard:Add(rrow, 28, 6)

    local function refreshPackView()
        local pack = st.pack
        local mode = RP:GetGlobal(pack, "barColorMode") or 1
        pv.mode:SetValue(mode); pv.mode:Layout()
        pv.single:SetValue(RP:GetGlobal(pack, "barColor"))
        pv.single:SetShown(mode == 2)
        pv.types:SetShown(mode == 3)
        for i, t in ipairs(RP.TYPES) do pv.typeSw[i]:SetValue(RP:GetTypeColor(pack, t.key)) end
        local emode = RP:GetGlobal(pack, "emphColorMode") or 1
        pv.emode:SetValue(emode); pv.emode:Layout()
        pv.emph:SetValue(RP:GetGlobal(pack, "emphColor"))
        pv.emph:SetShown(emode == 2)
        for _, f in ipairs({ "emphasizeAll", "showUnknown", "autoDiscover", "debuffSounds", "autoGossip", "skipCinematics" }) do pv[f]:SetValue(RP:GetGlobal(pack, f)) end
        local p = RP.packs[pack]
        pv.gosCard:SetShown(p and p.instance ~= nil)
        local learned = RP:CountLearnedGossip(pack)
        pv.gosInfo:SetText(learned > 0 and (learned .. " NPC choice" .. (learned == 1 and "" or "s") .. " remembered") or "No choices remembered yet")
        pv.gosForget:SetShown(learned > 0)
        pv.gosInfo:ClearAllPoints()
        if learned > 0 then pv.gosInfo:SetPoint("LEFT", pv.gosForget, "RIGHT", 12, 0) else pv.gosInfo:SetPoint("LEFT", 0, 0) end
        local nA, nD = RP:CountCustomized(pack), RP:CountCustomizedDebuffs(pack)
        pv.expInfo:SetText((nA + nD) .. " changed setting" .. ((nA + nD) == 1 and "" or "s") .. " in this pack")
        pv.channel:SetText(RP:GetGlobal(pack, "soundChannel") or "Master")
        pstack:Layout()
        if pv.types:IsShown() then pv.types:Layout() end
    end

    function refresh()
        if not page:IsVisible() then return end
        local packs = RP:GetPacks()
        if not st.pack or not RP.packs[st.pack] then st.pack = packs[1] and packs[1].key end
        local has = st.pack ~= nil
        none:SetShown(not has)
        rail:SetShown(has)
        search:SetShown(has and st.view == "boss")
        if not has then
            main:Hide(); packView:Hide()
            packDD:SetText("No packs detected")
            return
        end
        local p = RP.packs[st.pack]
        packDD:SetText((p.name or p.key) .. (p.version and ("   |cFF8a8f98v" .. p.version .. "|r") or ""))
        local bosses = refreshRail()
        if st.boss and not p.bosses[st.boss] then st.boss = nil end
        if not st.boss then st.boss = bosses[1] and bosses[1].key end
        for _, b in ipairs(bossButtons) do if b:IsShown() then b:Paint() end end
        if st.view == "pack" then
            main:Hide()
            packView:Show()
            refreshPackView()
            return
        end
        packView:Hide()
        main:Show()
        local boss = st.boss and p.bosses[st.boss]
        head.icon:SetIcon(boss and bossIcon(boss))
        head.name:SetText(boss and boss.name or (p.dynamic and "Waiting for the first pull" or ""))
        page.RefreshList()
    end
    page.Refresh = refresh
    Addon.RaidPackPage = page

    page:HookScript("OnSizeChanged", function(_, w)
        if not w or w <= 0 then return end
        rail:SetWidth(w < 640 and 172 or RAIL_W)
    end)
    RP:RegisterCallback(function() if page:IsVisible() then refresh() end end)
    page:HookScript("OnShow", function()
        local now = GetTime()
        if RP.ScanInstalledPacks and (not page.lastScan or now - page.lastScan > 5) then
            page.lastScan = now
            RP:ScanInstalledPacks()
        end
        repaint(); refresh()
    end)
end

function Addon.CreateTimelinePage(page, UI)
    local RP = FojjiCore.RaidPacks
    page.UI = UI
    FONT = UI.Font or FONT
    local selected = 1

    local intro = T(page, 12, "dim")
    intro:SetPoint("TOPLEFT", 0, -54)
    intro:SetPoint("RIGHT", -18, 0)
    intro:SetWordWrap(true)
    intro:SetText("Every boss pull is recorded (last 15). The duration summary maps a new boss (duration -> ability); the full log below can be copied.")

    local pick = W.Dropdown(page, 380, nil)
    pick:SetPoint("TOPLEFT", 0, -84)

    local panel = CreateFrame("Frame", nil, page)
    panel:SetPoint("TOPLEFT", 0, -124)
    panel:SetPoint("BOTTOMRIGHT", 0, 0)
    Surface(panel, "frame", 0.6, "borderDim")

    local scroll = UI.Scroll(panel)
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -24, 10)
    local holder = CreateFrame("Frame", nil, scroll)
    holder:SetSize(640, 400)
    scroll:SetScrollChild(holder)
    local box = CreateFrame("EditBox", nil, holder)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFont(FONT, 12, "")
    box:SetTextColor(0.9, 0.92, 0.96)
    box:SetPoint("TOPLEFT", 4, -4)
    box:SetWidth(620)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScript("OnSizeChanged", function(_, width) holder:SetWidth(width); box:SetWidth(width - 8) end)

    local function logName(log)
        return ("%s   %s   (%s, %s)"):format(log.date or "?", log.name or tostring(log.encounterID), tostring(log.difficultyID),
            log.success and "kill" or "wipe")
    end

    local function refresh()
        if not page:IsVisible() then return end
        local logs = RP:GetTimelineLogs()
        local log = logs[selected] or logs[1]
        if not log then
            pick:SetText("No pulls recorded yet")
            box:SetText("")
            return
        end
        pick:SetText(logName(log))
        local lines = { ("-- %s | encounter %s | difficulty %s | %.0fs"):format(log.name or "?", tostring(log.encounterID), tostring(log.difficultyID), log.length or 0),
            "-- Durations seen (rounded):" }
        for _, l in ipairs(RP:SummarizeLog(log)) do lines[#lines + 1] = "--   " .. l end
        lines[#lines + 1] = ""
        for _, l in ipairs(log.lines or {}) do lines[#lines + 1] = l end
        box:SetText(table.concat(lines, "\n"))
        holder:SetHeight(math.max(400, #lines * 15 + 20))
    end

    pick:SetScript("OnClick", function(self)
        local entries = {}
        for i, log in ipairs(RP:GetTimelineLogs()) do
            local idx = i
            entries[#entries + 1] = { text = logName(log), selected = idx == selected, onClick = function() selected = idx; refresh() end }
        end
        openMenu(self, entries)
    end)

    RP:RegisterCallback(function(reason) if reason == "timeline" then selected = 1; refresh() end end)
    page:HookScript("OnShow", function() repaint(); refresh() end)
end

function Addon.RaidPackSlash(msg)
    local RP = FojjiCore.RaidPacks
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "packs" then FojjiCore:ToggleOptions("raidpacks") return true end
    if cmd == "sounds" then
        FojjiCore:ToggleOptions("raidpacks")
        if Addon.RaidPackPage and Addon.RaidPackPage.SetMode then Addon.RaidPackPage.SetMode("debuffs") end
        return true
    end
    if cmd == "timeline" then FojjiCore:ToggleOptions("timeline") return true end
    if cmd ~= "demo" then return false end
    local packs = RP:GetPacks()
    if #packs == 0 then Addon.Print("No Fojji raid pack detected.") return true end
    local arg1, arg2 = rest:match("^(%S*)%s*(%S*)$")
    arg1 = (arg1 or ""):lower()
    if arg1 == "stop" then
        for _, p in ipairs(packs) do RP:StopDemo(p.key) end
        Addon.Print("Demo stopped.")
        return true
    end
    local length = tonumber(arg2) or tonumber(arg1)
    for _, p in ipairs(packs) do
        if arg1 == "" or arg1 == "all" or tonumber(arg1) then
            RP:StartDemo(p.key, "ALL", length)
            return true
        end
        for _, b in ipairs(RP:GetBosses(p.key)) do
            if b.key:lower():find(arg1, 1, true) or (b.name or ""):lower():find(arg1, 1, true) then
                RP:StartDemo(p.key, b.key, length)
                return true
            end
        end
    end
    Addon.Print("Unknown boss '" .. arg1 .. "'. Usage: /fc demo [boss|all] [seconds], /fc demo stop")
    return true
end
