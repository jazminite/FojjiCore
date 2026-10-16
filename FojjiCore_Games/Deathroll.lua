local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever and Addon.DJ and Addon.Games) then return end
local FDJ = Addon.DJ
local Games = Addon.Games
local Kit, C = FDJ.Kit, FDJ.Colors

local DR = {}
Games.Deathroll = DR

local CHALLENGE_TIME = 60
local IDLE_TIME = 300
local game, invite, setup, view
local seen = {}

local function me() return FDJ.PlayerName() end
local function short(n) return n and FDJ.Short(n) or n end
local function key(n)
    if type(n) ~= "string" then return "" end
    n = n:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%-.*$", "")
    return (n:match("^%s*(%S+)") or n):lower()
end
local function same(a, b) return key(a) ~= "" and key(a) == key(b) end
local function paint(name) return "|cff" .. Games.ClassHex(short(name)) .. (short(name) or "?") .. "|r" end
local function other(s, who) return same(who, s.a) and s.b or s.a end
local function amIn(s) return s and (same(s.a, me()) or same(s.b, me())) end
local function wagerText(s) return s.wager and (" for " .. s.wager) or "" end
local COIN = { g = "GoldIcon", s = "SilverIcon", c = "CopperIcon" }
local function wagerShow(w)
    if not w then return nil end
    local plain = w:match("^%s*([%d%.,]+)%s*$")
    if plain then return plain .. " |TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t" end
    local parts, rest = {}, w
    for n, unit in w:gmatch("([%d%.,]+)%s*([gGsScC])") do
        parts[#parts + 1] = n .. " |TInterface\\MoneyFrame\\UI-" .. COIN[unit:lower()] .. ":14:14:2:0|t"
    end
    rest = w:gsub("[%d%.,]+%s*[gGsScC]", ""):gsub("%s", "")
    if #parts > 0 and rest == "" then return table.concat(parts, "  ") end
    return w
end

local function say(text)
    local channel = FDJ.GroupChannel()
    if channel then pcall(SendChatMessage, text, channel) else FDJ.Print(text) end
end

local ROLL
do
    local fmt = type(RANDOM_ROLL_RESULT) == "string" and RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
    fmt = fmt:gsub("%%%d%$", "%%")
    ROLL = "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
end
local function parseRoll(text)
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local who, roll, lo, hi = text:match(ROLL)
    if not who then who, roll, lo, hi = text:match("^(.-)%s+%S+%s+(%d+)%s*%((%d+)%s*%-%s*(%d+)%)") end
    return who, tonumber(roll), tonumber(lo), tonumber(hi)
end

local function column(parent, side)
    local col = CreateFrame("Frame", nil, parent)
    col:SetSize(150, 150)
    Kit.Fill(col, C.field, 0.9)
    col.edges = Kit.Edge(col, C.borderDim)
    col.name = Kit.Text(col, "normal", C.white, "CENTER")
    col.name:SetPoint("TOP", 0, -10)
    col.name:SetPoint("LEFT", 6, 0)
    col.name:SetPoint("RIGHT", -6, 0)
    col.big = Kit.Text(col, "huge", C.white, "CENTER")
    col.big:SetPoint("TOP", col.name, "BOTTOM", 0, -10)
    col.list = Kit.Text(col, "tiny", C.muted, "CENTER")
    col.list:SetPoint("TOP", col.big, "BOTTOM", 0, -6)
    col.list:SetPoint("LEFT", 6, 0)
    col.list:SetPoint("RIGHT", -6, 0)
    col.list:SetWordWrap(true)
    col.roll = Kit.Button(col, "", 130, 26, function()
        local s = game
        if not s or s.done or not RandomRoll then return end
        if s.phase == "rolloff" then
            if s.off[key(me())] == nil then RandomRoll(1, 100) end
        elseif same(s.turn, me()) then
            RandomRoll(1, s.max)
        end
    end, "primary")
    col.roll:SetPoint("BOTTOM", 0, 8)
    col.roll:Hide()
    return col
end

local function build()
    view = Kit.Window("FojjiCoreDeathroll", "Deathroll", 360, 292)
    view:SetFrameStrata("DIALOG")
    Games.Window(view)
    view.wager = Kit.Text(view, "title", C.quest, "CENTER")
    view.wager:SetPoint("TOP", 0, -48)
    view.left = column(view)
    view.left:SetPoint("TOPLEFT", 14, -72)
    view.right = column(view)
    view.right:SetPoint("TOPRIGHT", -14, -72)
    view.vs = Kit.Text(view, "title", C.dim, "CENTER")
    view.vs:SetPoint("CENTER", view, "TOP", 0, -140)
    view.vs:SetText("VS")
    view.status = Kit.Text(view, "small", C.text, "CENTER")
    view.status:SetPoint("BOTTOM", 0, 44)
    view.status:SetPoint("LEFT", 14, 0)
    view.status:SetPoint("RIGHT", -14, 0)
    view.endBtn = Kit.Button(view, "End game", 110, 24, function() DR.End() end)
    view.endBtn:SetPoint("BOTTOMLEFT", 14, 12)
    view.newBtn = Kit.Button(view, "New challenge", 120, 24, function()
        view:Hide()
        DR.Setup(true)
    end, "primary")
    view.newBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    view.shake = view:CreateAnimationGroup()
    for i, dx in ipairs({ 6, -12, 10, -6, 2 }) do
        local a = view.shake:CreateAnimation("Translation")
        a:SetOffset(dx, 0)
        a:SetDuration(0.05)
        a:SetOrder(i)
    end
end

local function paintColumn(col, s, who)
    if s.phase == "rolloff" then
        local r = s.off[key(who)]
        col.name:SetText(paint(who))
        col.big:SetText(r and tostring(r) or "-")
        col.big:SetTextColor(1, 1, 1)
        col.list:SetText(FDJ.Paint("dim", "for who goes first"))
        Kit.EdgeColor(col, r == nil and C.accent or C.borderDim)
        local mine = same(who, me()) and r == nil
        col.roll:SetShown(mine)
        if mine then col.roll:SetLabel("Roll 1-100") end
        return
    end
    local rolls = s.rolls[key(who)] or {}
    col.name:SetText(paint(who))
    local last = rolls[#rolls]
    col.big:SetText(last and tostring(last) or "-")
    local list = {}
    for i = #rolls - 1, math.max(1, #rolls - 5), -1 do list[#list + 1] = tostring(rolls[i]) end
    col.list:SetText(table.concat(list, "  "))
    local active = not s.done and same(s.turn, who)
    Kit.EdgeColor(col, active and C.accent or C.borderDim)
    if s.done then
        local lost = same(s.loser, who)
        col.big:SetTextColor(lost and 1 or 1, lost and 0.25 or 0.82, lost and 0.25 or 0.1)
    else
        col.big:SetTextColor(1, 1, 1)
    end
    local mine = same(who, me()) and active
    col.roll:SetShown(mine)
    if mine then col.roll:SetLabel(("Roll 1-%d"):format(s.max)) end
end

local function paintView()
    local s = view and view.session
    if not s then return end
    view.wager:SetText(wagerShow(s.wager) or FDJ.Paint("dim", "no wager"))
    paintColumn(view.left, s, s.a)
    paintColumn(view.right, s, s.b)
    view.endBtn:SetShown(not (s.done or s.ended))
    view.endBtn:SetLabel("End game")
    view.newBtn:SetShown(s.done or s.ended)
    if s.ended then
        view.status:SetText(FDJ.Paint("dim", "Game ended."))
        return
    end
    if s.phase == "rolloff" then
        view.status:SetText(s.tie and "A tie! Roll again for who goes first." or "Roll for who goes first.")
        return
    end
    if s.done then
        local winner = other(s, s.loser)
        view.status:SetText(paint(winner) .. " wins" .. (s.wager and (" " .. wagerShow(s.wager)) or "") .. "!")
    else
        view.status:SetText((same(s.turn, me()) and "Your turn" or (paint(s.turn) .. " to roll")) .. ("  ·  1-%d"):format(s.max))
    end
end

local function open(s)
    if not view then build() end
    view.session = s
    paintView()
    view:Show()
end

local listener = CreateFrame("Frame")

local function stop()
    game = nil
    listener:UnregisterEvent("CHAT_MSG_SYSTEM")
end

local function finish(s, loser)
    s.done, s.loser = true, loser
    local winner = other(s, loser)
    if same(s.a, me()) then
        say(("Deathroll: %s wins%s! %s rolled a 1."):format(short(winner), s.wager and (" " .. s.wager) or "", short(loser)))
    end
    if view and view.session == s then
        paintView()
        view.shake:Play()
        if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960, "Master") end
        C_Timer.After(10, function() if view.session == s and not view:IsMouseOver() then view:Hide() end end)
    end
    stop()
end

listener:SetScript("OnEvent", function(_, _, text)
    local s = game
    if not s or s.done or type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    local who, roll, lo, hi = parseRoll(text)
    if DR.debug then FDJ.Print("deathroll saw: " .. text .. " -> " .. tostring(who) .. " " .. tostring(roll) .. " (" .. tostring(lo) .. "-" .. tostring(hi) .. "), waiting for " .. tostring(s.turn) .. " 1-" .. s.max) end
    if not who then return end
    if s.phase == "rolloff" then
        if lo ~= 1 or hi ~= 100 or not (same(who, s.a) or same(who, s.b)) or s.off[key(who)] ~= nil then return end
        s.off[key(who)] = roll
        s.t = GetTime()
        local ra, rb = s.off[key(s.a)], s.off[key(s.b)]
        if ra and rb then
            if ra == rb then
                s.off, s.tie = {}, true
            else
                s.tie = nil
                s.turn = ra > rb and s.a or s.b
                s.phase = "play"
            end
        end
        if view and view.session == s then paintView() end
        return
    end
    if not same(who, s.turn) or lo ~= 1 or hi ~= s.max then return end
    local list = s.rolls[key(who)]
    list[#list + 1] = roll
    s.max, s.t = roll, GetTime()
    if roll == 1 then return finish(s, who) end
    s.turn = other(s, who)
    if view and view.session == s then paintView() end
end)

local function begin(s)
    game = s
    s.t = GetTime()
    s.rolls = { [key(s.a)] = {}, [key(s.b)] = {} }
    s.phase = s.turn == "*" and "rolloff" or "play"
    s.off = {}
    listener:RegisterEvent("CHAT_MSG_SYSTEM")
    if amIn(s) then open(s) end
    local function idle()
        if game ~= s or s.done then return end
        if GetTime() - s.t > IDLE_TIME then
            if view and view.session == s then view:Hide() end
            stop()
        else
            C_Timer.After(30, idle)
        end
    end
    C_Timer.After(30, idle)
end

local function send(kind, payload, channel, target)
    FDJ.Comm.Send("DR", kind .. "~" .. payload, channel, target)
end

function DR.Challenge(target, max, wager, rollFirst)
    target = target and target:gsub("^%s+", ""):gsub("%s+$", "") or ""
    max = math.floor(tonumber(max) or 0)
    if target == "" or same(target, me()) then FDJ.Print("Deathroll: pick someone to challenge.") return end
    if max < 2 then FDJ.Print("Deathroll: pick a number above 1.") return end
    if game then FDJ.Print("Deathroll: finish the one you're in first.") return end
    if invite then FDJ.Print(("Deathroll: still waiting on %s."):format(short(invite.b))) return end
    wager = wager and wager:gsub("~", ""):sub(1, 40) or nil
    if wager == "" then wager = nil end
    invite = { id = tostring(math.random(100000, 999999)), a = me(), b = target, max = max, start = max, wager = wager, t = GetTime(), rollFirst = rollFirst }
    send("C", ("%s~%d~%s"):format(invite.id, max, wager or ""), "WHISPER", target)
    FDJ.Print(("Deathroll challenge sent to %s%s. Waiting for an answer."):format(short(target), wagerText(invite)))
    local mine = invite
    C_Timer.After(CHALLENGE_TIME, function()
        if invite == mine then
            invite = nil
            FDJ.Print(("Deathroll: %s didn't answer."):format(short(target)))
        end
    end)
end

local accepted = {}
local function askAccept(from, id, max, wager)
    local text = ("%s challenges you to a deathroll from %d%s."):format(paint(from), max, wager and (" for " .. FDJ.Paint("quest", wager)) or "")
    Kit.Toast(text, {
        { "Decline", function() send("D", id, "WHISPER", from) end },
        { "Accept", function()
            if game then send("D", id, "WHISPER", from) FDJ.Print("Deathroll: you're already in one.") return end
            accepted[id] = from
            send("A", id, "WHISPER", from)
        end },
    }, CHALLENGE_TIME)
end

FDJ:On("FDJ_COMM", function(kind, payload, who)
    if kind ~= "DR" or type(payload) ~= "string" then return end
    local op, rest = payload:match("^(%a)~(.*)$")
    if op == "C" then
        local id, max, wager = rest:match("^(%d+)~(%d+)~(.*)$")
        if id then askAccept(who, id, tonumber(max), wager ~= "" and wager or nil) end
    elseif (op == "A" or op == "D") and invite and rest == invite.id and same(who, invite.b) then
        local s = invite
        invite = nil
        if op == "D" then
            FDJ.Print(("Deathroll: %s declined."):format(short(who)))
            return
        end
        if game then send("E", s.id, "WHISPER", who) return end
        s.b = who
        if s.rollFirst then
            s.turn = "*"
            say(("Deathroll: %s vs %s%s, starting at %d. Rolling 1-100 for who goes first!"):format(short(s.a), short(s.b), wagerText(s), s.max))
        else
            s.turn = math.random(2) == 1 and s.a or s.b
            say(("Deathroll: %s vs %s%s, starting at %d. %s rolls first!"):format(short(s.a), short(s.b), wagerText(s), s.max, short(s.turn)))
        end
        local msg = ("%s~%s~%s~%d~%s~%s"):format(s.id, short(s.a), short(s.b), s.max, short(s.turn), s.wager or "")
        send("S", msg, "WHISPER", s.b)
        begin(s)
    elseif op == "E" then
        if game and game.id == rest and amIn(game) then
            local s = game
            stop()
            s.ended = true
            FDJ.Print(("Deathroll: %s ended the game."):format(short(who)))
            if view and view.session == s then paintView() end
        end
    elseif op == "S" then
        local id, a, b, max, first, wager = rest:match("^(%d+)~([^~]+)~([^~]+)~(%d+)~([^~]+)~(.*)$")
        if not id or (game and game.id == id) or seen[id] then return end
        if not (accepted[id] and same(who, accepted[id])) then return end
        accepted[id] = nil
        seen[id] = true
        if game then send("E", id, "WHISPER", who) return end
        local s = { id = id, a = a, b = b, max = tonumber(max), start = tonumber(max), turn = first, wager = wager ~= "" and wager or nil }
        if same(b, me()) or same(a, me()) then begin(s) end
    end
end)

function DR.End()
    local s = view and view.session
    if not s then return end
    if s == game and not s.done then
        if amIn(s) then
            local foe = other(s, me())
            send("E", s.id, "WHISPER", foe)
            if same(s.a, me()) then say(("Deathroll between %s and %s was called off."):format(short(s.a), short(s.b))) end
        end
        stop()
    end
    s.ended = true
    paintView()
end

function DR.Setup(fresh)
    if not fresh and game and view then view.session = game; view:Show() return end
    if not setup then
        setup = Kit.Window("FojjiCoreDeathrollStart", "Deathroll", 320, 288)
        setup:SetFrameStrata("DIALOG")
        Games.Window(setup)
        local function label(text, x, y)
            local t = Kit.Text(setup, "small", C.muted)
            t:SetPoint("TOPLEFT", x, y)
            t:SetText(text)
        end
        label("Player", 18, -50)
        setup.target = Kit.Input(setup, 284, 26, "Name")
        setup.target:SetPoint("TOPLEFT", 18, -68)
        label("Start at", 18, -104)
        setup.num = Kit.Input(setup, 130, 26, "1000")
        setup.num:SetPoint("TOPLEFT", 18, -122)
        setup.num:SetNumeric(true)
        label("Wager", 160, -104)
        setup.kind = "money"
        setup.mode = Kit.Segmented(setup, { { "money", "Gold" }, { "custom", "Custom" } }, function(k)
            setup.kind = k
            for _, e in ipairs(setup.coins or {}) do e:SetShown(k == "money") end
            if setup.wager then setup.wager:SetShown(k == "custom") end
        end)
        setup.mode:SetSize(142, 24)
        setup.mode:SetPoint("TOPLEFT", 160, -122)
        setup.coins = {}
        for i, unit in ipairs({ "g", "s", "c" }) do
            local e = Kit.Input(setup, 82, 26, "0")
            e:SetNumeric(true)
            e:SetMaxLetters(i == 1 and 6 or 2)
            e:SetPoint("TOPLEFT", 18 + (i - 1) * 96, -176)
            local icon = e:CreateTexture(nil, "OVERLAY")
            icon:SetSize(14, 14)
            icon:SetPoint("RIGHT", -8, 0)
            icon:SetTexture("Interface\\MoneyFrame\\UI-" .. COIN[unit])
            e.unit = unit
            setup.coins[i] = e
        end
        setup.wager = Kit.Input(setup, 284, 26, "A drink at the inn")
        setup.wager:SetPoint("TOPLEFT", 18, -176)
        setup.wager:Hide()
        setup.mode:Select("money")
        setup.rollFirst = Kit.Check(setup, "Roll for who goes first", function() return FojjiCoreDB.drRollFirst ~= false end,
            function(v) FojjiCoreDB.drRollFirst = v and true or false end)
        setup.rollFirst:SetPoint("TOPLEFT", 16, -212)
        local go = Kit.Button(setup, "Challenge", 130, 28, function()
            local n = tonumber(setup.num:GetText()) or 1000
            local wager
            if setup.kind == "money" then
                local bits = {}
                for _, e in ipairs(setup.coins) do
                    local v = tonumber(e:GetText())
                    if v and v > 0 then bits[#bits + 1] = v .. e.unit end
                end
                wager = table.concat(bits, " ")
            else
                wager = setup.wager:GetText()
            end
            DR.Challenge(setup.target:GetText(), n, wager, FojjiCoreDB.drRollFirst ~= false)
            setup:Hide()
        end, "primary")
        go:SetPoint("BOTTOM", 0, 14)
    end
    if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        setup.target:SetText(GetUnitName("target", true) or "")
    end
    setup:Show()
end
