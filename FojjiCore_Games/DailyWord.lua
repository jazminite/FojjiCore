local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever and Addon.DJ and Addon.Games) then return end
local FDJ = Addon.DJ
local Games = Addon.Games
local Kit, C = FDJ.Kit, FDJ.Colors

local Word = {}
Games.DailyWord = Word

local TILE, GAP = 56, 6
local ROWS, LEN = 6, 5
local GREEN = { 0.33, 0.62, 0.32 }
local YELLOW = { 0.78, 0.65, 0.22 }
local GREY = { 0.23, 0.24, 0.27 }
local CHEERS = { "Incredible!", "Brilliant!", "Great!", "Nice one!", "Good!", "Phew!" }

local win

local function data() return Games.WordData end
local function today()
    local d = data()
    local now = (GetServerTime and GetServerTime()) or time()
    return math.max(0, math.floor((now - d.EPOCH) / 86400))
end
local function answerFor(day)
    local d = data()
    local i = day % d.COUNT
    return d.ANSWERS:sub(i * LEN + 1, i * LEN + LEN)
end
local function valid(w)
    return data().VALID:find("|" .. w .. "|", 1, true) ~= nil
end

local function score(guess, answer)
    local res, left = {}, {}
    for i = 1, LEN do
        local a, g = answer:sub(i, i), guess:sub(i, i)
        if a == g then res[i] = "g" else left[a] = (left[a] or 0) + 1 end
    end
    for i = 1, LEN do
        if not res[i] then
            local g = guess:sub(i, i)
            if (left[g] or 0) > 0 then res[i] = "y" left[g] = left[g] - 1 else res[i] = "x" end
        end
    end
    return res
end
Word.Score = score

local function store()
    FojjiCoreDB.dailyWord = FojjiCoreDB.dailyWord or {}
    local s = FojjiCoreDB.dailyWord
    s.stats = s.stats or { played = 0, won = 0, streak = 0, best = 0, dist = { 0, 0, 0, 0, 0, 0 } }
    local day = today()
    if s.day ~= day then s.day, s.guesses, s.over, s.won = day, {}, nil, nil end
    if s.stats.lastWin and s.stats.lastWin < day - 1 then s.stats.streak = 0 end
    return s
end

local function finish(won)
    local s = store()
    s.over, s.won = true, won
    local st = s.stats
    st.played = st.played + 1
    if won then
        st.won = st.won + 1
        st.streak = (st.lastWin == s.day - 1 and st.streak or 0) + 1
        st.best = math.max(st.best, st.streak)
        st.lastWin = s.day
        st.dist[#s.guesses] = (st.dist[#s.guesses] or 0) + 1
    else
        st.streak = 0
    end
end

local function paintTile(t, letter, state)
    t.letter:SetText(letter or "")
    local c = state == "g" and GREEN or state == "y" and YELLOW or state == "x" and GREY
    if c then
        t.fill:SetColorTexture(c[1], c[2], c[3], 1)
        Kit.EdgeColor(t, c, 1)
    else
        t.fill:SetColorTexture(C.field[1], C.field[2], C.field[3], 0.95)
        Kit.EdgeColor(t, letter and letter ~= "" and C.border or C.borderDim, 1)
    end
end

local function keyState(k, state)
    local rank = { x = 1, y = 2, g = 3 }
    if k.state and rank[k.state] >= rank[state] then return end
    k.state = state
    local c = state == "g" and GREEN or state == "y" and YELLOW or GREY
    k.fill:SetColorTexture(c[1], c[2], c[3], 1)
    k.label:SetTextColor(1, 1, 1)
end

local function say(text, hold)
    win.msg:SetText(text or "")
    win.msgAt = GetTime()
    if not hold and text then
        local at = win.msgAt
        C_Timer.After(2, function() if win and win.msgAt == at then win.msg:SetText("") end end)
    end
end

local function shake(row)
    if row.shake then row.shake:Stop() row.shake:Play() end
end

local refresh, showStats

local function reveal(r, guess, res, done)
    local row = win.rows[r]
    for i = 1, LEN do
        C_Timer.After((i - 1) * 0.16, function()
            local t = row.tiles[i]
            if t.flip then t.flip:Stop() t.flip:Play() end
            C_Timer.After(0.08, function() paintTile(t, guess:sub(i, i), res[i]) end)
            if i == LEN and done then C_Timer.After(0.3, done) end
        end)
    end
end

local function submit()
    local s = store()
    if s.over or win.busy then return end
    local guess = win.typed
    local row = win.rows[#s.guesses + 1]
    if #guess < LEN then say("Not enough letters") shake(row) return end
    if not valid(guess) then say("Not in the word list") shake(row) return end
    local answer = answerFor(s.day)
    local res = score(guess, answer)
    s.guesses[#s.guesses + 1] = guess
    win.typed = ""
    win.box:SetText("")
    win.busy = true
    local won = guess == answer
    if won or #s.guesses >= ROWS then finish(won) end
    reveal(#s.guesses, guess, res, function()
        win.busy = nil
        for i = 1, LEN do keyState(win.keys[guess:sub(i, i)], res[i]) end
        if s.over then
            say(s.won and CHEERS[#s.guesses] or answer, true)
            C_Timer.After(1.2, function() if win and win:IsShown() then showStats() end end)
        end
    end)
end

local function typeLetter(ch)
    local s = store()
    if win.day ~= s.day then win.typed = "" win.box:SetText("") refresh() return end
    if s.over or win.busy then return end
    if ch == "ENTER" then submit() return end
    if ch == "BACK" then win.typed = win.typed:sub(1, -2)
    elseif #win.typed < LEN then win.typed = win.typed .. ch end
    win.box:SetText(win.typed)
    refresh(true)
end

local function nextIn()
    local d = data()
    local now = (GetServerTime and GetServerTime()) or time()
    local left = d.EPOCH + (today() + 1) * 86400 - now
    return ("%d:%02d:%02d"):format(math.floor(left / 3600), math.floor(left / 60) % 60, left % 60)
end

local function shareText()
    local s = store()
    local st = s.stats
    return ("Daily Word #%d: %s/6  -  streak %d  -  %d played, %d solved"):format(s.day + 1,
        s.won and tostring(#s.guesses) or "X", st.streak, st.played, st.won)
end

function showStats()
    local s = store()
    local p = win.stats
    local st = s.stats
    p.nums[1]:SetText(tostring(st.played))
    p.nums[2]:SetText(st.played > 0 and tostring(math.floor(st.won / st.played * 100 + 0.5)) or "0")
    p.nums[3]:SetText(tostring(st.streak))
    p.nums[4]:SetText(tostring(st.best))
    local most = 1
    for i = 1, ROWS do most = math.max(most, st.dist[i] or 0) end
    for i = 1, ROWS do
        local b = p.bars[i]
        local n = st.dist[i] or 0
        b.fill:SetWidth(math.max(18, 230 * n / most))
        b.count:SetText(tostring(n))
        local mine = s.won and #s.guesses == i
        local c = mine and GREEN or GREY
        b.fill:SetColorTexture(c[1], c[2], c[3], 1)
    end
    p.share:SetShown((s.over and IsInGuild and IsInGuild()) and true or false)
    p:Show()
    win.keyboard:Hide()
    if not p.tick then
        p.tick = C_Timer.NewTicker(1, function() if p:IsVisible() then p.next:SetText("Next word in " .. nextIn()) end end)
    end
    p.next:SetText("Next word in " .. nextIn())
end

function refresh(typingOnly)
    local s = store()
    local r = #s.guesses + 1
    if typingOnly then
        local row = win.rows[r]
        if row then for i = 1, LEN do paintTile(row.tiles[i], win.typed:sub(i, i)) end end
        return
    end
    win.day = s.day
    win.sub:SetText(("#%d"):format(s.day + 1))
    for _, k in pairs(win.keys) do
        k.state = nil
        k.fill:SetColorTexture(C.button[1], C.button[2], C.button[3], 1)
        k.label:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
    local answer = answerFor(s.day)
    for i = 1, ROWS do
        local g = s.guesses[i]
        local res = g and score(g, answer)
        for j = 1, LEN do
            if g then
                paintTile(win.rows[i].tiles[j], g:sub(j, j), res[j])
                keyState(win.keys[g:sub(j, j)], res[j])
            else
                paintTile(win.rows[i].tiles[j], i == r and win.typed:sub(j, j) or "")
            end
        end
    end
    if s.over then
        say(s.won and CHEERS[#s.guesses] or answer, true)
        showStats()
    else
        win.stats:Hide()
        win.keyboard:Show()
        say(nil)
    end
end

local function makeKey(parent, label, w, value)
    local k = CreateFrame("Button", nil, parent)
    k:SetSize(w, 42)
    k.fill = k:CreateTexture(nil, "BACKGROUND")
    k.fill:SetAllPoints()
    k.edges = Kit.Edge(k, C.borderDim)
    k.label = Kit.Text(k, value == "BACK" and "large" or "normal", C.text, "CENTER")
    k.label:SetPoint("CENTER", 0, 1)
    k.label:SetText(label)
    k:SetScript("OnEnter", function(self) Kit.EdgeColor(self, C.accent, 1) end)
    k:SetScript("OnLeave", function(self) Kit.EdgeColor(self, C.borderDim, 1) end)
    k:SetScript("OnClick", function() typeLetter(value) win.box:SetFocus() end)
    return k
end

local function build()
    local W = 372
    local f = Kit.Window("FojjiCoreDailyWord", "Daily Word", W, 640)
    f:SetFrameStrata("DIALOG")
    win = f
    f.typed = ""
    f.sub = Kit.Text(f, "small", C.muted, "RIGHT")
    f.sub:SetPoint("TOPRIGHT", -40, -16)

    local gridW = LEN * TILE + (LEN - 1) * GAP
    local x0 = (W - gridW) / 2
    f.rows = {}
    for r = 1, ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(gridW, TILE)
        row:SetPoint("TOPLEFT", x0, -54 - (r - 1) * (TILE + GAP))
        row.tiles = {}
        for i = 1, LEN do
            local t = CreateFrame("Frame", nil, row)
            t:SetSize(TILE, TILE)
            t:SetPoint("LEFT", (i - 1) * (TILE + GAP), 0)
            t.fill = t:CreateTexture(nil, "BACKGROUND")
            t.fill:SetAllPoints()
            t.edges = Kit.Edge(t, C.borderDim)
            t.letter = t:CreateFontString(nil, "OVERLAY")
            t.letter:SetFont(FDJ.Font and FDJ.Font() or STANDARD_TEXT_FONT, 28, "")
            t.letter:SetPoint("CENTER", 0, 1)
            t.letter:SetTextColor(1, 1, 1)
            local ag = t:CreateAnimationGroup()
            local a1 = ag:CreateAnimation("Scale")
            local a2 = ag:CreateAnimation("Scale")
            if a1.SetScaleFrom then
                a1:SetScaleFrom(1, 1) a1:SetScaleTo(1, 0.05)
                a2:SetScaleFrom(1, 0.05) a2:SetScaleTo(1, 1)
            else
                a1:SetScale(1, 0.05) a2:SetScale(1, 20)
            end
            a1:SetDuration(0.08) a1:SetOrder(1)
            a2:SetDuration(0.08) a2:SetOrder(2)
            t.flip = ag
            row.tiles[i] = t
        end
        local sh = row:CreateAnimationGroup()
        for n, dx in ipairs({ 8, -16, 16, -16, 8 }) do
            local m = sh:CreateAnimation("Translation")
            m:SetOffset(dx, 0)
            m:SetDuration(0.045)
            m:SetOrder(n)
        end
        row.shake = sh
        f.rows[r] = row
    end

    f.msg = Kit.Text(f, "normal", C.white, "CENTER")
    f.msg:SetPoint("TOP", 0, -54 - ROWS * (TILE + GAP) - 4)

    local kb = CreateFrame("Frame", nil, f)
    kb:SetPoint("BOTTOMLEFT", 12, 14)
    kb:SetPoint("BOTTOMRIGHT", -12, 14)
    kb:SetHeight(3 * 42 + 2 * 6)
    f.keyboard = kb
    f.keys = {}
    local rowsK = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
    local kw = 30
    for r, letters in ipairs(rowsK) do
        local n = #letters
        local width = n * kw + (n - 1) * 4 + (r == 3 and 2 * (50 + 4) or 0)
        local x = (W - 24 - width) / 2
        local y = -(r - 1) * 48
        if r == 3 then
            local e = makeKey(kb, "Enter", 50, "ENTER")
            e:SetPoint("TOPLEFT", x, y)
            x = x + 54
        end
        for i = 1, n do
            local ch = letters:sub(i, i)
            local k = makeKey(kb, ch, kw, ch)
            k:SetPoint("TOPLEFT", x, y)
            f.keys[ch] = k
            x = x + kw + 4
        end
        if r == 3 then
            local b = makeKey(kb, "", 50, "BACK")
            b:SetPoint("TOPLEFT", x, y)
            local arrow = b:CreateTexture(nil, "OVERLAY")
            arrow:SetSize(14, 14)
            arrow:SetPoint("CENTER")
            arrow:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\icon-chevron-left")
            arrow:SetVertexColor(C.text[1], C.text[2], C.text[3])
        end
    end

    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 12, -54 - ROWS * (TILE + GAP) - 26)
    p:SetPoint("BOTTOMRIGHT", -12, 12)
    Kit.Fill(p, C.field, 0.95)
    Kit.Edge(p, C.borderDim)
    p.nums = {}
    local labels = { "Played", "Win %", "Streak", "Best" }
    local cw = (W - 24) / 4
    for i, l in ipairs(labels) do
        local n = Kit.Text(p, 22, C.white, "CENTER")
        n:SetPoint("TOP", p, "TOPLEFT", cw * (i - 0.5), -8)
        local t = Kit.Text(p, "tiny", C.muted, "CENTER")
        t:SetPoint("TOP", n, "BOTTOM", 0, -2)
        t:SetText(l)
        p.nums[i] = n
    end
    p.bars = {}
    for i = 1, ROWS do
        local b = CreateFrame("Frame", nil, p)
        b:SetSize(260, 10)
        b:SetPoint("TOPLEFT", 34, -54 - (i - 1) * 12)
        local lab = Kit.Text(b, "tiny", C.muted, "RIGHT")
        lab:SetPoint("RIGHT", b, "LEFT", -6, 0)
        lab:SetText(tostring(i))
        b.fill = b:CreateTexture(nil, "ARTWORK")
        b.fill:SetPoint("LEFT")
        b.fill:SetHeight(10)
        b.count = Kit.Text(b, "tiny", C.white, "RIGHT")
        b.count:SetPoint("RIGHT", b.fill, "RIGHT", -4, 0)
        p.bars[i] = b
    end
    p.next = Kit.Text(p, "small", C.muted, "LEFT")
    p.next:SetPoint("BOTTOMLEFT", 12, 13)
    p.share = Kit.Button(p, "Share to guild", 116, 24, function()
        if IsInGuild and IsInGuild() and SendChatMessage then SendChatMessage(shareText(), "GUILD") end
    end, "primary")
    p.share:SetPoint("BOTTOMRIGHT", -8, 8)
    p:Hide()
    f.stats = p

    local box = CreateFrame("EditBox", nil, f)
    box:SetSize(1, 1)
    box:SetPoint("TOPLEFT")
    box:SetAlpha(0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(LEN)
    box:SetScript("OnTextChanged", function(self, user)
        if not user then return end
        local t = (self:GetText() or ""):upper():gsub("[^A-Z]", ""):sub(1, LEN)
        local s = store()
        if s.over or f.busy then t = "" end
        f.typed = t
        if self:GetText() ~= t then self:SetText(t) end
        refresh(true)
    end)
    box:SetScript("OnEnterPressed", function() typeLetter("ENTER") end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() f:Hide() end)
    f.box = box
    f:EnableMouse(true)
    f:HookScript("OnMouseDown", function() box:SetFocus() end)
    f:HookScript("OnShow", function() box:SetFocus() refresh() end)
    f:HookScript("OnHide", function()
        box:ClearFocus()
        if p.tick then p.tick:Cancel() p.tick = nil end
    end)
    if Games.Window then Games.Window(f) end
    return f
end

function Word.Toggle()
    if not win then build() end
    if win:IsShown() then win:Hide() else win:Show() end
end

local function drawTile(t)
    if t.wordArt then return end
    local sq = t:CreateTexture(nil, "ARTWORK")
    sq:SetSize(28, 28)
    sq:SetPoint("CENTER")
    sq:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 1)
    local w = t:CreateFontString(nil, "OVERLAY")
    w:SetFont(FDJ.Font and FDJ.Font() or STANDARD_TEXT_FONT, 17, "")
    w:SetPoint("CENTER", sq, "CENTER", 0, 1)
    w:SetTextColor(1, 1, 1)
    w:SetText("W")
    t.wordArt = true
end
Games.list = Games.list or {}
Games.list[#Games.list + 1] = { name = "Daily Word", draw = drawTile, open = function() Word.Toggle() end }
