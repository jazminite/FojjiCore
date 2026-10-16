local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever and Addon.DJ and Addon.Games) then return end
local FDJ = Addon.DJ
local Games = Addon.Games
local Kit, C = FDJ.Kit, FDJ.Colors

local Chess = {}
Games.Chess = Chess

local SOUNDS = "Interface\\AddOns\\FojjiCore_Games\\media\\chess-"
function Chess.SoundsOn() return not (FojjiCoreDB and FojjiCoreDB.chessSounds == false) end
function Chess.SetSounds(on) FojjiCoreDB.chessSounds = on and true or false end
local CUSTOM = "Interface\\AddOns\\FojjiCore_Games\\media\\custom\\"
local custom = {}
local function sound(name)
    if not (Chess.SoundsOn() and PlaySoundFile) then return end
    local board = _G.FojjiCoreChess
    if not (board and board:IsVisible()) then return end
    if custom[name] == nil then
        custom[name] = false
        for _, ext in ipairs({ ".ogg", ".mp3" }) do
            local ok, willPlay = pcall(PlaySoundFile, CUSTOM .. name .. ext, "Master")
            if ok and willPlay then custom[name] = CUSTOM .. name .. ext return end
        end
    elseif custom[name] then
        pcall(PlaySoundFile, custom[name], "Master")
        return
    end
    pcall(PlaySoundFile, SOUNDS .. name .. ".ogg", "Master")
end

local CHALLENGE_TIME = 60
local TIME = {
    { "Bullet", { 1, 0 }, { 1, 1 }, { 2, 1 } },
    { "Blitz", { 3, 0 }, { 3, 2 }, { 5, 0 }, { 5, 3 } },
    { "Rapid", { 10, 0 }, { 10, 5 }, { 15, 10 } },
    { "Classical", { 30, 0 }, { 30, 20 } },
}
local function timeKind(mins, inc)
    if not mins or mins <= 0 then return "Unlimited" end
    local est = mins * 60 + (inc or 0) * 40
    if est < 180 then return "Bullet" elseif est < 480 then return "Blitz" elseif est < 1500 then return "Rapid" end
    return "Classical"
end
local function timeText(mins, inc)
    if not mins or mins <= 0 then return "Unlimited" end
    return ("%d+%d %s"):format(mins, inc or 0, timeKind(mins, inc))
end
local SHEET = "Interface\\AddOns\\FojjiCore\\textures\\UI\\chess-pieces"
local COLS = { K = 0, Q = 1, R = 2, B = 3, N = 4, P = 5 }
local SQUARE = 52
local game, invite, setup, view
local fly

local function me() return FDJ.PlayerName() end
local function short(n) return n and FDJ.Short(n) or n end
local function key(n)
    if type(n) ~= "string" then return "" end
    n = n:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%-.*$", "")
    return (n:match("^%s*(%S+)") or n):lower()
end
local function same(a, b) return key(a) ~= "" and key(a) == key(b) end
local function paint(name) return "|cff" .. Games.ClassHex(short(name)) .. (short(name) or "?") .. "|r" end
local function say(text)
    local channel = FDJ.GroupChannel()
    if channel then pcall(SendChatMessage, text, channel) else FDJ.Print(text) end
end

local function sq(f, r) return (r - 1) * 8 + f end
local function fileOf(s) return (s - 1) % 8 + 1 end
local function rankOf(s) return math.floor((s - 1) / 8) + 1 end
local FILES = "abcdefgh"
local function name(s) return FILES:sub(fileOf(s), fileOf(s)) .. rankOf(s) end
local function parse(t)
    local f, r = t:match("^([a-h])([1-8])$")
    if not f then return nil end
    return sq(FILES:find(f, 1, true), tonumber(r))
end

local function newBoard()
    local b = {}
    local back = { "R", "N", "B", "Q", "K", "B", "N", "R" }
    for f = 1, 8 do
        b[sq(f, 1)] = "w" .. back[f]
        b[sq(f, 2)] = "wP"
        b[sq(f, 7)] = "bP"
        b[sq(f, 8)] = "b" .. back[f]
    end
    return b
end

local function newState()
    return { b = newBoard(), turn = "w", cast = { K = true, Q = true, k = true, q = true }, ep = nil, half = 0, ply = 0, moves = {}, keys = {} }
end

local KNIGHT = { { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 }, { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 } }
local KING = { { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
local ROOK = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
local BISHOP = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }

local function step(s, df, dr)
    local f, r = fileOf(s) + df, rankOf(s) + dr
    if f < 1 or f > 8 or r < 1 or r > 8 then return nil end
    return sq(f, r)
end

local function attacked(b, s, by)
    local foe = by
    for _, d in ipairs(KNIGHT) do
        local t = step(s, d[1], d[2])
        if t and b[t] == foe .. "N" then return true end
    end
    for _, d in ipairs(KING) do
        local t = step(s, d[1], d[2])
        if t and b[t] == foe .. "K" then return true end
    end
    local pr = foe == "w" and -1 or 1
    for _, df in ipairs({ -1, 1 }) do
        local t = step(s, df, pr)
        if t and b[t] == foe .. "P" then return true end
    end
    for _, set in ipairs({ { ROOK, "R" }, { BISHOP, "B" } }) do
        for _, d in ipairs(set[1]) do
            local t = step(s, d[1], d[2])
            while t do
                local p = b[t]
                if p then
                    if p == foe .. set[2] or p == foe .. "Q" then return true end
                    break
                end
                t = step(t, d[1], d[2])
            end
        end
    end
    return false
end

local function kingSquare(b, c)
    for s = 1, 64 do if b[s] == c .. "K" then return s end end
end

local function inCheck(st, c)
    local k = kingSquare(st.b, c or st.turn)
    return k and attacked(st.b, k, (c or st.turn) == "w" and "b" or "w") or false
end

local function pseudo(st, s)
    local b, p = st.b, st.b[s]
    if not p or p:sub(1, 1) ~= st.turn then return {} end
    local c, t = p:sub(1, 1), p:sub(2, 2)
    local foe = c == "w" and "b" or "w"
    local out = {}
    local function add(to, extra)
        local m = { from = s, to = to }
        if extra then for k, v in pairs(extra) do m[k] = v end end
        out[#out + 1] = m
    end
    if t == "P" then
        local dir = c == "w" and 1 or -1
        local home, last = c == "w" and 2 or 7, c == "w" and 8 or 1
        local one = step(s, 0, dir)
        local function pawnTo(to, extra)
            if rankOf(to) == last then
                for _, pr in ipairs({ "Q", "R", "B", "N" }) do
                    local e = { promo = pr }
                    if extra then for k, v in pairs(extra) do e[k] = v end end
                    add(to, e)
                end
            else
                add(to, extra)
            end
        end
        if one and not b[one] then
            pawnTo(one)
            local two = step(s, 0, dir * 2)
            if rankOf(s) == home and two and not b[two] then add(two, { double = true }) end
        end
        for _, df in ipairs({ -1, 1 }) do
            local to = step(s, df, dir)
            if to then
                if b[to] and b[to]:sub(1, 1) == foe then pawnTo(to)
                elseif to == st.ep then add(to, { ep = true }) end
            end
        end
    elseif t == "N" or t == "K" then
        for _, d in ipairs(t == "N" and KNIGHT or KING) do
            local to = step(s, d[1], d[2])
            if to and (not b[to] or b[to]:sub(1, 1) == foe) then add(to) end
        end
        if t == "K" then
            local r = c == "w" and 1 or 8
            local kside, qside = c == "w" and "K" or "k", c == "w" and "Q" or "q"
            if s == sq(5, r) and not attacked(b, s, foe) then
                if st.cast[kside] and b[sq(8, r)] == c .. "R" and not b[sq(6, r)] and not b[sq(7, r)]
                    and not attacked(b, sq(6, r), foe) and not attacked(b, sq(7, r), foe) then
                    add(sq(7, r), { castle = "K" })
                end
                if st.cast[qside] and b[sq(1, r)] == c .. "R" and not b[sq(2, r)] and not b[sq(3, r)] and not b[sq(4, r)]
                    and not attacked(b, sq(4, r), foe) and not attacked(b, sq(3, r), foe) then
                    add(sq(3, r), { castle = "Q" })
                end
            end
        end
    else
        local dirs = t == "R" and ROOK or t == "B" and BISHOP or KING
        for _, d in ipairs(dirs) do
            local to = step(s, d[1], d[2])
            while to do
                if b[to] then
                    if b[to]:sub(1, 1) == foe then add(to) end
                    break
                end
                add(to)
                to = step(to, d[1], d[2])
            end
        end
    end
    return out
end

local function posKey(st)
    local parts = {}
    for s = 1, 64 do parts[s] = st.b[s] or "-" end
    return table.concat(parts) .. st.turn .. (st.cast.K and "K" or "") .. (st.cast.Q and "Q" or "")
        .. (st.cast.k and "k" or "") .. (st.cast.q and "q" or "") .. (st.ep or "")
end

local function make(st, m)
    local b = {}
    for s = 1, 64 do b[s] = st.b[s] end
    local p = b[m.from]
    local c = p:sub(1, 1)
    local capture = b[m.to] ~= nil or m.ep
    b[m.to], b[m.from] = p, nil
    if m.ep then b[sq(fileOf(m.to), rankOf(m.from))] = nil end
    if m.promo then b[m.to] = c .. m.promo end
    if m.castle then
        local r = rankOf(m.from)
        if m.castle == "K" then b[sq(6, r)], b[sq(8, r)] = c .. "R", nil
        else b[sq(4, r)], b[sq(1, r)] = c .. "R", nil end
    end
    local cast = { K = st.cast.K, Q = st.cast.Q, k = st.cast.k, q = st.cast.q }
    if p == "wK" then cast.K, cast.Q = false, false end
    if p == "bK" then cast.k, cast.q = false, false end
    for _, x in ipairs({ m.from, m.to }) do
        if x == sq(1, 1) then cast.Q = false elseif x == sq(8, 1) then cast.K = false
        elseif x == sq(1, 8) then cast.q = false elseif x == sq(8, 8) then cast.k = false end
    end
    local n = {
        b = b, turn = c == "w" and "b" or "w", cast = cast,
        ep = m.double and step(m.from, 0, c == "w" and 1 or -1) or nil,
        half = (p:sub(2, 2) == "P" or capture) and 0 or st.half + 1,
        ply = st.ply + 1, moves = st.moves, keys = st.keys,
    }
    n.capture = capture
    return n
end

local function legal(st, s)
    local out = {}
    for _, m in ipairs(pseudo(st, s)) do
        local n = make(st, m)
        if not inCheck(n, st.turn) then out[#out + 1] = m end
    end
    return out
end

local function anyLegal(st)
    for s = 1, 64 do
        local p = st.b[s]
        if p and p:sub(1, 1) == st.turn and #legal(st, s) > 0 then return true end
    end
    return false
end

local function bareMaterial(b)
    local minor, other = 0, 0
    for s = 1, 64 do
        local p = b[s]
        if p and p:sub(2, 2) ~= "K" then
            if p:sub(2, 2) == "N" or p:sub(2, 2) == "B" then minor = minor + 1 else other = other + 1 end
        end
    end
    return other == 0 and minor <= 1
end

local function notate(st, m, after)
    local p = st.b[m.from]
    local t = p:sub(2, 2)
    local text
    if m.castle then
        text = m.castle == "K" and "O-O" or "O-O-O"
    else
        local cap = (st.b[m.to] or m.ep) and "x" or ""
        if t == "P" then
            text = (cap ~= "" and FILES:sub(fileOf(m.from), fileOf(m.from)) or "") .. cap .. name(m.to)
            if m.promo then text = text .. "=" .. m.promo end
        else
            local amb = ""
            for s = 1, 64 do
                if s ~= m.from and st.b[s] == p then
                    for _, o in ipairs(legal(st, s)) do
                        if o.to == m.to then
                            amb = fileOf(s) ~= fileOf(m.from) and FILES:sub(fileOf(m.from), fileOf(m.from)) or tostring(rankOf(m.from))
                            break
                        end
                    end
                    if amb ~= "" then break end
                end
            end
            text = t .. amb .. cap .. name(m.to)
        end
    end
    if inCheck(after) then text = text .. (anyLegal(after) and "+" or "#") end
    return text
end

local function encode(m) return name(m.from) .. name(m.to) .. (m.promo and m.promo:lower() or "") end
local function findMove(st, text)
    local a, b2, pr = text:match("^([a-h][1-8])([a-h][1-8])([qrbn]?)$")
    if not a then return nil end
    local from, to = parse(a), parse(b2)
    for _, m in ipairs(legal(st, from)) do
        if m.to == to and ((pr == "" and not m.promo) or (m.promo and m.promo:lower() == pr)) then return m end
    end
    return nil
end

Chess.Rules = { newState = newState, legal = legal, make = make, inCheck = inCheck, anyLegal = anyLegal, findMove = findMove, notate = notate, encode = encode, parse = parse, name = name }

local function myColour(s)
    if same(s.w, me()) then return "w" elseif same(s.b, me()) then return "b" end
end
local function foeOf(s) return s.foe or (same(s.w, me()) and s.b or s.w) end
local function nameOf(s, c) return c == "w" and s.w or s.b end
local function myTurn(s) return not s.over and myColour(s) == s.st.turn end

local function send(kind, payload, channel, target)
    FDJ.Comm.Send("CH", kind .. "~" .. payload, channel, target)
end
local function tell(s, kind, payload)
    if s.bot then return end
    send(kind, payload, "WHISPER", foeOf(s))
end

local paintView, open
local ticker

local START_ELO = 1000
local refreshBoard
local function plain(n) return n and (tostring(n):gsub("%-.*$", "")) end
local function ratingStore()
    FojjiCoreDB.chessRatings = FojjiCoreDB.chessRatings or {}
    local t = FojjiCoreDB.chessRatings
    t.mine = t.mine or {}
    t.board = t.board or {}
    return t
end
local function myRating()
    local t = ratingStore()
    local key = plain(me()) or "?"
    t.mine[key] = t.mine[key] or { r = START_ELO, g = 0, w = 0, d = 0, l = 0 }
    return t.mine[key]
end
local function guildHas(name)
    if not (IsInGuild and IsInGuild()) then return false end
    local want = plain(name)
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local n = GetGuildRosterInfo(i)
        if n and plain(n) == want then return true end
    end
    return false
end
local function inCircle(name)
    if not name or name == "" then return false end
    if UnitInParty and UnitInParty(name) then return true end
    if UnitInRaid and UnitInRaid(name) then return true end
    return guildHas(name)
end
local function rate(s)
    if s.bot or s.rated or not myColour(s) or (s.st and s.st.ply or 0) < 2 then return end
    s.rated = true
    local m = myRating()
    local mine = myColour(s)
    local score = s.result == mine and 1 or s.result == "d" and 0.5 or 0
    local foe = tonumber(s.foeRating) or START_ELO
    local expect = 1 / (1 + 10 ^ ((foe - m.r) / 400))
    local k = m.g < 20 and 40 or 20
    local new = math.floor(m.r + k * (score - expect) + 0.5)
    s.delta, s.newRating = new - m.r, new
    m.r, m.g = new, m.g + 1
    if score == 1 then m.w = m.w + 1 elseif score == 0 then m.l = m.l + 1 else m.d = m.d + 1 end
    m.peak = math.max(m.peak or START_ELO, new)
    local key = plain(foeOf(s))
    local e = ratingStore().board[key] or { w = 0, d = 0, l = 0 }
    e.r, e.g, e.seen = foe, (tonumber(s.foeGames) or 0) + 1, time()
    if score == 1 then e.w = (e.w or 0) + 1 elseif score == 0 then e.l = (e.l or 0) + 1 else e.d = (e.d or 0) + 1 end
    ratingStore().board[key] = e
    if refreshBoard then refreshBoard() end
end

local function stopClock()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function escapable(on)
    local list = UISpecialFrames
    if type(list) ~= "table" or (FDJ.GamepadUI and FDJ.GamepadUI()) then return end
    for i = #list, 1, -1 do if list[i] == "FojjiCoreChess" then table.remove(list, i) end end
    if on then list[#list + 1] = "FojjiCoreChess" end
end

local function finish(s, result, why)
    s.over, s.result, s.why = true, result, why
    stopClock()
    escapable(true)
    rate(s)
    if myColour(s) then C_Timer.After(0.25, function() sound("end") end) end
    if s.view then
        s.view.premoves, s.view.sel, s.view.moves, s.view.promo = nil, nil, nil, nil
        paintView()
    end
    if same(s.w, me()) and not s.bot then
        local text
        if result == "d" then text = ("Chess: %s vs %s is a draw (%s)."):format(short(s.w), short(s.b), why)
        else text = ("Chess: %s beats %s (%s)."):format(short(nameOf(s, result)), short(nameOf(s, result == "w" and "b" or "w")), why) end
        say(text)
    end
end

local function judge(s)
    local st = s.st
    if not anyLegal(st) then
        if inCheck(st) then finish(s, st.turn == "w" and "b" or "w", "checkmate") else finish(s, "d", "stalemate") end
        return true
    end
    if bareMaterial(st.b) then finish(s, "d", "insufficient material") return true end
    if st.half >= 100 then finish(s, "d", "50-move rule") return true end
    local k = posKey(st)
    st.keys[k] = (st.keys[k] or 0) + 1
    if st.keys[k] >= 3 then finish(s, "d", "threefold repetition") return true end
    return false
end

local function play(s, m)
    local st = s.st
    local text = notate(st, m, make(st, m))
    local after = make(st, m)
    local moved = st.b[m.from]
    local kind = (inCheck(after) and "check") or (m.promo and "promote")
        or (moved and moved:sub(2, 2) == "K" and math.abs(fileOf(m.to) - fileOf(m.from)) == 2 and "castle")
        or ((st.b[m.to] or m.ep) and "capture") or "move"
    sound(kind)
    after.moves = st.moves
    after.keys = st.keys
    st.moves[#st.moves + 1] = text
    s.st, s.last = after, m
    s.drawOffer = nil
    if s.mins > 0 then
        local now = GetTime()
        if s.clockAt then s.clock[st.turn] = math.max(0, s.clock[st.turn] - (now - s.clockAt)) + (s.inc or 0) end
        s.clockAt = now
    end
    if judge(s) then return end
    if s.view then paintView() end
    if myColour(s) and s.st.turn == myColour(s) and Chess.TryPremove then Chess.TryPremove(s) end
    if s.bot and s.st.turn ~= myColour(s) then Chess.BotTurn(s) end
end

local function flag(s, c)
    local b = s.st.b
    local other = c == "w" and "b" or "w"
    local has = false
    for i = 1, 64 do if b[i] and b[i]:sub(1, 1) == other and b[i]:sub(2, 2) ~= "K" then has = true break end end
    if has then finish(s, other, "out of time") else finish(s, "d", "out of time, no mating material") end
end

local function clockLeft(s, c)
    local left = s.clock[c]
    if s.clockAt and s.st.turn == c and not s.over then left = left - (GetTime() - s.clockAt) end
    return math.max(0, left)
end

local function startClock(s)
    stopClock()
    if s.mins <= 0 then return end
    ticker = C_Timer.NewTicker(0.25, function()
        if game ~= s or s.over then stopClock() return end
        local c = s.st.turn
        if c == myColour(s) and not s.lowTick and clockLeft(s, c) < 10 then s.lowTick = true sound("lowtime") end
        if clockLeft(s, c) <= 0 then
            if myColour(s) == c then
                tell(s, "F", s.id)
                flag(s, c)
            elseif GetTime() - s.clockAt > (s.clock[c] + 20) then
                flag(s, c)
            end
        end
        local low = clockLeft(s, c) < 20
        if low ~= s.lowShown and s.view and s.view:IsShown() then s.lowShown = low paintView(true) end
    end)
end

local function begin(s)
    game = s
    s.st = newState()
    s.st.keys[posKey(s.st)] = 1
    s.clock = { w = s.mins * 60, b = s.mins * 60 }
    s.clockAt = s.mins > 0 and GetTime() or nil
    open(s)
    escapable(false)
    startClock(s)
    sound("start")
    if not s.bot then
        local m = myRating()
        tell(s, "I", ("%s~%d~%d"):format(s.id, m.r, m.g))
    end
end

local function stop()
    stopClock()
    game = nil
    escapable(true)
end

-- Credit: the chess pieces are the "cburnett" set by Colin M.L. Burnett (BSD licence), as used by lichess and Wikipedia.
local LIGHT = { 0.84, 0.88, 0.93 }
local DARK = { 0.44, 0.55, 0.68 }
local SELECT = { 0.30, 0.82, 1.00, 0.55 }
local function mix(a, b, t) return a + (b - a) * t end
local function themeBoard()
    if FDJ.SyncTheme and FDJ.SyncTheme() and Kit.Repaint then Kit.Repaint() end
    local a = C.accent
    LIGHT[1], LIGHT[2], LIGHT[3] = mix(0.93, a[1], 0.16), mix(0.93, a[2], 0.16), mix(0.94, a[3], 0.16)
    DARK[1], DARK[2], DARK[3] = mix(0.42, a[1], 0.38), mix(0.44, a[2], 0.38), mix(0.48, a[3], 0.38)
    SELECT[1], SELECT[2], SELECT[3] = a[1], a[2], a[3]
end
local PREMOVE = { 0.90, 0.30, 0.34, 0.50 }

local function pieceCoords(p)
    local col = COLS[p:sub(2, 2)]
    local row = p:sub(1, 1) == "w" and 0 or 1
    return col / 8, (col + 1) / 8, row / 4, (row + 1) / 4
end
local function uiCoords(p)
    local col = COLS[p:sub(2, 2)]
    local row = p:sub(1, 1) == "w" and 2 or 3
    return col / 8, (col + 1) / 8, row / 4, (row + 1) / 4
end

local SIZES = {}
for n = 16, 64, 2 do SIZES[#SIZES + 1] = n end
for n = 68, 128, 4 do SIZES[#SIZES + 1] = n end
local function pixelsPerUnit(frame)
    local _, h = GetPhysicalScreenSize and GetPhysicalScreenSize()
    h = tonumber(h) or 1080
    local scale = frame and frame.GetEffectiveScale and tonumber(frame:GetEffectiveScale()) or 1
    return scale * h / 768
end
local function sheetOf(base, units, frame)
    local ppu = pixelsPerUnit(frame)
    local px = units * ppu
    local best = SIZES[#SIZES]
    for _, n in ipairs(SIZES) do
        if n >= px - 1 then best = n break end
    end
    return base .. "-" .. best, best / ppu
end
local function sheetFor(units, frame) return sheetOf(SHEET, units, frame) end
local function crisp(tex)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(true) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end
local function useSheet(tex, path)
    if tex.sheet ~= path then
        tex.sheet = path
        tex:SetTexture(path)
        crisp(tex)
    end
end
local ICONS = "Interface\\AddOns\\FojjiCore\\textures\\UI\\chess-icons"
local function fitIcon(tex, idx, units, frame)
    local path, size = sheetOf(ICONS, units, frame)
    useSheet(tex, path)
    tex:SetSize(size, size)
    local col, row = idx % 4, math.floor(idx / 4)
    tex:SetTexCoord(col / 4, (col + 1) / 4, row / 2, (row + 1) / 2)
end
local function fitPiece(tex, units, frame)
    local path, size = sheetFor(units, frame)
    useSheet(tex, path)
    tex:SetSize(size, size)
    return size
end

local function cellAt(c, s)
    local f, r = fileOf(s), rankOf(s)
    if c == "b" then f, r = 9 - f, 9 - r end
    return f, r
end

local function squareUnderCursor(v, mine)
    local scale = v.board:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local left, bottom = v.board:GetLeft(), v.board:GetBottom()
    if not (left and bottom) then return nil end
    local x, y = cx / scale - left, cy / scale - bottom
    local f, r = math.floor(x / SQUARE) + 1, math.floor(y / SQUARE) + 1
    if f < 1 or f > 8 or r < 1 or r > 8 then return nil end
    if mine == "b" then f, r = 9 - f, 9 - r end
    return sq(f, r)
end

local function sendMove(g, m)
    local tail = ""
    if g.mins and g.mins > 0 and g.clock and not g.bot then
        local c = g.st.turn
        local left = clockLeft(g, c) + (g.inc or 0)
        tail = "~" .. math.max(0, math.floor(left * 10 + 0.5))
    end
    tell(g, "M", ("%s~%d~%s%s"):format(g.id, g.st.ply, encode(m), tail))
    play(g, m)
end

local function premovesOn() return FojjiCoreDB and FojjiCoreDB.chessPremove == true end

local function castleTarget(st, from, to)
    local p, t = st.b[from], st.b[to]
    if p and t and p:sub(2, 2) == "K" and t == p:sub(1, 1) .. "R" and rankOf(from) == rankOf(to) then
        return sq(fileOf(to) > fileOf(from) and 7 or 3, rankOf(from))
    end
    return to
end

local function queue(v)
    v.premoves = v.premoves or {}
    return v.premoves
end

local function planned(g)
    local v = g.view
    local list = v and v.premoves
    if g.over or not list or #list == 0 then return g.st.b end
    local b = {}
    for i = 1, 64 do b[i] = g.st.b[i] end
    for _, pm in ipairs(list) do
        local p = b[pm.from]
        if p then
            b[pm.to], b[pm.from] = p, nil
            if pm.promo then b[pm.to] = p:sub(1, 1) .. pm.promo end
            if p:sub(2, 2) == "K" and math.abs(fileOf(pm.to) - fileOf(pm.from)) == 2 then
                local r = rankOf(pm.from)
                if fileOf(pm.to) == 7 then b[sq(6, r)], b[sq(8, r)] = b[sq(8, r)], nil
                else b[sq(4, r)], b[sq(1, r)] = b[sq(1, r)], nil end
            end
        end
    end
    return b
end

local function premoveOk(b, from, to)
    local p = b[from]
    if not p or from == to then return false end
    local c, t = p:sub(1, 1), p:sub(2, 2)
    local there = b[to]
    if there and there:sub(2, 2) == "K" then return false end
    local f1, r1, f2, r2 = fileOf(from), rankOf(from), fileOf(to), rankOf(to)
    local df, dr = f2 - f1, r2 - r1
    local adf, adr = math.abs(df), math.abs(dr)
    local function clear()
        local sf = df == 0 and 0 or (df > 0 and 1 or -1)
        local sr = dr == 0 and 0 or (dr > 0 and 1 or -1)
        local f, r = f1 + sf, r1 + sr
        while f ~= f2 or r ~= r2 do
            local q = b[sq(f, r)]
            if q and q:sub(1, 1) == c then return false end
            f, r = f + sf, r + sr
        end
        return true
    end
    local line = (df == 0) ~= (dr == 0)
    local diag = adf == adr and adf > 0
    if t == "P" then
        local fwd = c == "w" and 1 or -1
        if df == 0 and dr == fwd then return not (there and there:sub(1, 1) == c) end
        if df == 0 and dr == 2 * fwd and r1 == (c == "w" and 2 or 7) then return not (there and there:sub(1, 1) == c) and clear() end
        return adf == 1 and dr == fwd
    elseif t == "N" then
        return (adf == 1 and adr == 2) or (adf == 2 and adr == 1)
    elseif t == "B" then
        return diag and clear()
    elseif t == "R" then
        return line and clear()
    elseif t == "Q" then
        return (diag or line) and clear()
    elseif t == "K" then
        if adf <= 1 and adr <= 1 then return true end
        local home = c == "w" and 1 or 8
        if dr == 0 and r1 == home and f1 == 5 and adf == 2 then
            local rf = df > 0 and 8 or 1
            if b[sq(rf, home)] ~= c .. "R" then return false end
            for f = math.min(5, rf) + 1, math.max(5, rf) - 1 do
                local q = b[sq(f, home)]
                if q and q:sub(1, 1) == c then return false end
            end
            return true
        end
    end
    return false
end

local function premoveTargets(b, from)
    local list = {}
    for s = 1, 64 do
        if premoveOk(b, from, s) then list[#list + 1] = { to = s } end
    end
    return list
end

local function lastRank(p, to)
    return p and p:sub(2, 2) == "P" and rankOf(to) == (p:sub(1, 1) == "w" and 8 or 1)
end

local function tryMove(g, from, to)
    local v = g.view
    local st = g.st
    if myTurn(g) and #queue(v) == 0 then
        to = castleTarget(st, from, to)
        for _, m in ipairs(legal(st, from)) do
            if m.to == to then
                v.sel, v.moves = nil, nil
                if m.promo then
                    v.promo = { from = from, to = to }
                    paintView()
                else
                    sendMove(g, m)
                end
                return true
            end
        end
        return false
    end
    if premovesOn() and from ~= to then
        local b = planned(g)
        to = castleTarget({ b = b }, from, to)
        if not premoveOk(b, from, to) then return false end
        v.sel, v.moves = nil, nil
        local takes = b[to] ~= nil
        if lastRank(b[from], to) then
            v.promo = { from = from, to = to, pre = true, takes = takes }
        else
            table.insert(queue(v), { from = from, to = to, takes = takes })
        end
        paintView()
        return true
    end
    return false
end

function Chess.TryPremove(g)
    local v = g.view
    local list = v and v.premoves
    if not list or #list == 0 then return end
    local pm = table.remove(list, 1)
    local there = g.st.b[pm.to]
    local stillThere = there and there:sub(1, 1) ~= myColour(g)
    if pm.takes and not stillThere then
        v.premoves = nil
        paintView()
        return
    end
    for _, m in ipairs(legal(g.st, pm.from)) do
        if m.to == pm.to and (not m.promo or m.promo == (pm.promo or "Q")) then
            C_Timer.After(0.05, function() if game == g and not g.over and myTurn(g) then sendMove(g, m) end end)
            return
        end
    end
    v.premoves = nil
    paintView()
end

local function mineAt(g, s)
    local p = planned(g)[s]
    return p and p:sub(1, 1) == myColour(g)
end

local function onSquare(s, right)
    local g = game
    if not g or g.over or not g.view or not myColour(g) then return end
    local v = g.view
    if right then
        v.sel, v.moves, v.premoves, v.promo = nil, nil, nil, nil
        paintView()
        return
    end
    if not myTurn(g) and not premovesOn() then return end
    local b = planned(g)
    local listed = false
    for _, m in ipairs(v.moves or {}) do if m.to == s then listed = true break end end
    if v.sel and v.sel ~= s and (listed or not mineAt(g, s) or castleTarget({ b = b }, v.sel, s) ~= s) then
        if tryMove(g, v.sel, s) then return end
    end
    if mineAt(g, s) and v.sel ~= s then
        v.sel = s
        v.moves = (myTurn(g) and #queue(v) == 0) and legal(g.st, s) or premoveTargets(b, s)
    else
        v.sel, v.moves = nil, nil
    end
    paintView()
end

local function startDrag(cell)
    local g = game
    if not g or g.over or not g.view or not mineAt(g, cell.sq) then return end
    if not myTurn(g) and not premovesOn() then return end
    local v = g.view
    v.sel = cell.sq
    v.moves = (myTurn(g) and #queue(v) == 0) and legal(g.st, cell.sq) or premoveTargets(planned(g), cell.sq)
    v.drag = cell.sq
    fitPiece(v.ghost, SQUARE + 4, v.ghostFrame)
    v.ghost:SetTexCoord(pieceCoords(planned(g)[cell.sq]))
    v.ghost:Show()
    paintView()
    v.ghostFrame:SetScript("OnUpdate", function()
        local scale = v:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        v.ghost:ClearAllPoints()
        v.ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    end)
end

local function stopDrag()
    local g = game
    local v = view
    if not (v and v.drag) then return end
    local from = v.drag
    v.drag = nil
    v.ghost:Hide()
    v.ghostFrame:SetScript("OnUpdate", nil)
    if not g or g.over then paintView() return end
    local to = squareUnderCursor(v, myColour(g) or "w")
    if to and to ~= from and tryMove(g, from, to) then return end
    paintView()
end

local function clockText(secs)
    secs = math.max(0, secs)
    if secs < 20 then return ("%d:%04.1f"):format(math.floor(secs / 60), secs % 60) end
    secs = math.floor(secs + 0.999)
    return ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
end

local START = { P = 8, N = 2, B = 2, R = 2, Q = 1 }
local WORTH = { P = 1, N = 3, B = 3, R = 5, Q = 9 }
local function captured(b)
    local have = { w = {}, b = {} }
    for i = 1, 64 do
        local p = b[i]
        if p then
            local c, t = p:sub(1, 1), p:sub(2, 2)
            have[c][t] = (have[c][t] or 0) + 1
        end
    end
    local took, score = { w = {}, b = {} }, { w = 0, b = 0 }
    for _, c in ipairs({ "w", "b" }) do
        local foe = c == "w" and "b" or "w"
        for _, t in ipairs({ "Q", "R", "B", "N", "P" }) do
            local gone = START[t] - (have[foe][t] or 0)
            for _ = 1, math.max(0, gone) do took[c][#took[c] + 1] = foe .. t end
            score[c] = score[c] + WORTH[t] * (have[c][t] or 0)
        end
    end
    return took, score
end

local CARD_H = 74
local CARD_W = 252
local CLOCK_W = 84
local function card(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(CARD_W, CARD_H)
    f.fill = f:CreateTexture(nil, "BACKGROUND")
    f.fill:SetAllPoints()
    f.fill:SetColorTexture(C.field[1], C.field[2], C.field[3], 0.95)
    f.glow = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.glow:SetAllPoints()
    f.glow:SetColorTexture(1, 1, 1, 1)
    if f.glow.SetGradient and CreateColor then
        f.gradient = true
    end
    f.glow:Hide()
    f.edges = Kit.Edge(f, C.borderDim)
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetPoint("TOPLEFT", 1, -1)
    f.bar:SetPoint("BOTTOMLEFT", 1, 1)
    f.bar:SetWidth(3)
    f.bar:SetColorTexture(1, 1, 1, 1)
    f.king = f:CreateTexture(nil, "ARTWORK")
    f.king:SetSize(24, 24)
    f.king:SetPoint("TOPLEFT", 12, -9)
    f.king:SetTexture(SHEET)
    f.name = Kit.Text(f, "normal", C.white, "LEFT")
    f.name:SetPoint("LEFT", f.king, "RIGHT", 6, 0)
    f.name:SetPoint("RIGHT", f, "RIGHT", -(CLOCK_W + 16), 0)
    f.name:SetWordWrap(false)
    f.took = {}
    for i = 1, 15 do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetSize(20, 20)
        t:Hide()
        f.took[i] = t
    end
    f.plus = Kit.Text(f, "small", C.muted, "LEFT")
    f.pill = CreateFrame("Frame", nil, f)
    f.pill:SetSize(CLOCK_W, 40)
    f.pill:SetPoint("RIGHT", -10, 0)
    f.pill.fill = f.pill:CreateTexture(nil, "BACKGROUND")
    f.pill.fill:SetAllPoints()
    f.pill.edges = Kit.Edge(f.pill, C.borderDim)
    f.clock = f.pill:CreateFontString(nil, "OVERLAY")
    f.clock:SetFont(FDJ.Font and FDJ.Font() or STANDARD_TEXT_FONT, 23, "")
    f.clock:SetPoint("CENTER", 0, 0)
    return f
end

local function build()
    local boardSize = SQUARE * 8
    local W = 18 + boardSize + 16 + CARD_W + 18
    local v = Kit.Window("FojjiCoreChess", "Chess", W, 52 + boardSize + 46)
    v.menuBtn = Kit.Button(v.head, "Menu", 64, 22, function()
        v:Hide()
        Chess.Setup(true)
    end)
    v.menuBtn:SetPoint("RIGHT", v.close, "LEFT", -8, 0)
    v:SetFrameStrata("DIALOG")
    local board = CreateFrame("Frame", nil, v)
    board:SetSize(boardSize, boardSize)
    board:SetPoint("TOPLEFT", 18, -52)
    v.board = board
    local frameEdge = CreateFrame("Frame", nil, board)
    frameEdge:SetPoint("TOPLEFT", -3, 3)
    frameEdge:SetPoint("BOTTOMRIGHT", 3, -3)
    frameEdge:SetFrameLevel(board:GetFrameLevel())
    Kit.Fill(frameEdge, C.shadow, 0.6, "BACKGROUND")
    local ring = CreateFrame("Frame", nil, board)
    ring:SetPoint("TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", 2, -2)
    ring:SetFrameLevel(board:GetFrameLevel() + 1)
    ring.edges = Kit.Edge(ring, C.borderDim)
    local halo = CreateFrame("Frame", nil, board)
    halo:SetPoint("TOPLEFT", -4, 4)
    halo:SetPoint("BOTTOMRIGHT", 4, -4)
    halo:SetFrameLevel(board:GetFrameLevel() + 1)
    halo.edges = Kit.Edge(halo, C.accent, 0.35)
    halo:Hide()
    v.ring, v.halo = ring, halo
    v.cells = {}
    for s = 1, 64 do
        local cell = CreateFrame("Button", nil, board)
        cell:SetSize(SQUARE, SQUARE)
        cell:SetFrameLevel(board:GetFrameLevel() + 2)
        cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        cell:RegisterForDrag("LeftButton")
        cell.bg = cell:CreateTexture(nil, "BACKGROUND")
        cell.bg:SetAllPoints()
        cell.bg:SetColorTexture(1, 1, 1, 1)
        cell.mark = cell:CreateTexture(nil, "BORDER")
        cell.mark:SetAllPoints()
        cell.mark:SetColorTexture(1, 1, 1, 1)
        cell.mark:Hide()
        cell.dot = cell:CreateTexture(nil, "ARTWORK")
        cell.dot:SetPoint("CENTER")
        cell.dot:Hide()
        cell.piece = cell:CreateTexture(nil, "OVERLAY")
        cell.piece:SetSize(SQUARE, SQUARE)
        cell.piece:SetPoint("CENTER", 0, 0)
        cell.piece:Hide()
        cell.file = cell:CreateFontString(nil, "OVERLAY")
        cell.file:SetFont(FDJ.Font and FDJ.Font() or STANDARD_TEXT_FONT, 10, "")
        cell.file:SetPoint("BOTTOMLEFT", 3, 2)
        cell.rank = cell:CreateFontString(nil, "OVERLAY")
        cell.rank:SetFont(FDJ.Font and FDJ.Font() or STANDARD_TEXT_FONT, 10, "")
        cell.rank:SetPoint("TOPRIGHT", -3, -2)
        cell.sq = s
        cell:SetScript("OnClick", function(self, mouse) onSquare(self.sq, mouse == "RightButton") end)
        cell:SetScript("OnDragStart", startDrag)
        cell:SetScript("OnDragStop", stopDrag)
        cell:SetScript("OnMouseUp", function(_, mouse) if mouse == "LeftButton" and view and view.drag then stopDrag() end end)
        v.cells[s] = cell
    end
    v.ghostFrame = CreateFrame("Frame", nil, UIParent)
    v.ghostFrame:SetFrameStrata("TOOLTIP")
    v.ghostFrame:SetAllPoints(UIParent)
    v.ghost = v.ghostFrame:CreateTexture(nil, "OVERLAY")
    v.ghost:SetSize(SQUARE + 4, SQUARE + 4)
    v.ghost:Hide()

    v.status = Kit.Text(v, "normal", C.text, "LEFT")
    v.status:SetPoint("TOPLEFT", board, "BOTTOMLEFT", 2, -14)
    v.status:SetPoint("RIGHT", board, "RIGHT", -4, 0)
    v.premoveBox = Kit.Check(v, "Premoves", function() return premovesOn() end, function(on)
        FojjiCoreDB.chessPremove = on and true or nil
        if not on and view then view.premoves = nil; paintView() end
    end, "Make your move during the other player's turn; it's played the moment it's legal. Right-click cancels it.")
    v.soundBox = Kit.Check(v, "Sounds", function() return Chess.SoundsOn() end, function(on) Chess.SetSounds(on) end,
        "Move, capture and check sounds. Also in FojjiCore options under Extra Features.")

    v.top = card(v)
    v.top:SetPoint("TOPLEFT", board, "TOPRIGHT", 16, 0)
    v.bottom = card(v)
    v.bottom:SetPoint("BOTTOMLEFT", board, "BOTTOMRIGHT", 16, 0)
    v.soundBox:SetPoint("TOPRIGHT", v.bottom, "BOTTOMRIGHT", 0, -10)
    v.premoveBox:SetPoint("RIGHT", v.soundBox, "LEFT", -18, 0)
    local ask = Kit.Button(v, "Offer draw", 112, 26, function() Chess.OfferDraw() end)
    ask:SetPoint("BOTTOMLEFT", v.bottom, "TOPLEFT", 0, 10)
    v.drawBtn = ask
    v.resignBtn = Kit.Button(v, "Resign", 112, 26, function()
        Kit.Confirm("Resign this game?", function() Chess.Resign() end)
    end)
    v.resignBtn:SetPoint("BOTTOMRIGHT", v.bottom, "TOPRIGHT", 0, 10)
    v.rematchBtn = Kit.Button(v, "Rematch", 112, 26, function() Chess.Rematch() end, "primary")
    v.rematchBtn:SetPoint("BOTTOMLEFT", v.bottom, "TOPLEFT", 0, 10)
    v.newBtn = Kit.Button(v, "New game", 112, 26, function()
        v:Hide()
        Chess.Setup(true)
    end)
    v.newBtn:SetPoint("BOTTOMRIGHT", v.bottom, "TOPRIGHT", 0, 10)
    local mv = CreateFrame("Frame", nil, v)
    mv:SetPoint("TOPLEFT", v.top, "BOTTOMLEFT", 0, -10)
    mv:SetPoint("BOTTOMRIGHT", v.bottom, "TOPRIGHT", 0, 46)
    Kit.Fill(mv, C.field, 0.6)
    Kit.Edge(mv, C.borderDim)
    v.list = Kit.Scroller(mv)
    v.list:SetPoint("TOPLEFT", 1, -1)
    v.list:SetPoint("BOTTOMRIGHT", -1, 1)
    v.rows = {}
    v.empty = Kit.Text(mv, "small", C.dim, "CENTER")
    v.empty:SetPoint("CENTER")
    v.empty:SetText("No moves yet")

    local pk = CreateFrame("Frame", nil, board)
    pk:SetSize(4 * (SQUARE + 4) + 12, SQUARE + 32)
    pk:SetPoint("CENTER")
    pk:SetFrameLevel(board:GetFrameLevel() + 20)
    Kit.Fill(pk, C.frame, 0.97)
    Kit.Edge(pk, C.accent)
    pk.label = Kit.Text(pk, "small", C.muted, "CENTER")
    pk.label:SetPoint("TOP", 0, -6)
    pk.label:SetText("Promote to")
    pk.buttons = {}
    for i, t in ipairs({ "Q", "R", "B", "N" }) do
        local b = CreateFrame("Button", nil, pk)
        b:SetSize(SQUARE, SQUARE)
        b:SetPoint("BOTTOMLEFT", 6 + (i - 1) * (SQUARE + 4), 6)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(LIGHT[1], LIGHT[2], LIGHT[3], 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER")
        b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(DARK[1], DARK[2], DARK[3], 1) end)
        b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(LIGHT[1], LIGHT[2], LIGHT[3], 1) end)
        b.t = t
        b:SetScript("OnClick", function(self)
            local g = game
            local pr = v.promo
            if not (g and pr) then return end
            v.promo = nil
            if pr.pre then
                table.insert(queue(v), { from = pr.from, to = pr.to, promo = self.t, takes = pr.takes })
                paintView()
                return
            end
            for _, m in ipairs(legal(g.st, pr.from)) do
                if m.to == pr.to and m.promo == self.t then sendMove(g, m) return end
            end
            paintView()
        end)
        pk.buttons[i] = b
    end
    pk:Hide()
    v.picker = pk

    local res = CreateFrame("Button", nil, board)
    res:SetAllPoints(board)
    res:SetFrameLevel(board:GetFrameLevel() + 30)
    res.wash = res:CreateTexture(nil, "BACKGROUND")
    res.wash:SetAllPoints()
    res.wash:SetColorTexture(0, 0, 0, 0.5)
    local rc = CreateFrame("Frame", nil, res)
    rc:SetSize(292, 172)
    rc:SetPoint("CENTER")
    Kit.Fill(rc, C.frame, 0.97)
    rc.edges = Kit.Edge(rc, C.border)
    rc.line = rc:CreateTexture(nil, "ARTWORK")
    rc.line:SetPoint("TOPLEFT", 1, -1)
    rc.line:SetPoint("TOPRIGHT", -1, -1)
    rc.line:SetHeight(2)
    rc.icon = rc:CreateTexture(nil, "ARTWORK")
    rc.icon:SetPoint("TOP", 0, -16)
    rc.title = Kit.Text(rc, 24, C.white, "CENTER")
    rc.title:SetPoint("TOP", rc.icon, "BOTTOM", 0, -6)
    rc.sub = Kit.Text(rc, "normal", C.muted, "CENTER")
    rc.sub:SetPoint("TOP", rc.title, "BOTTOM", 0, -6)
    rc.elo = Kit.Text(rc, "small", C.text, "CENTER")
    rc.elo:SetPoint("TOP", rc.sub, "BOTTOM", 0, -6)
    rc.hint = Kit.Text(rc, "tiny", C.dim, "CENTER")
    rc.hint:SetPoint("BOTTOM", 0, 9)
    rc.hint:SetText("Click to see the board")
    res.card = rc
    res.fade = res:CreateAnimationGroup()
    local a = res.fade:CreateAnimation("Alpha")
    a:SetFromAlpha(0)
    a:SetToAlpha(1)
    a:SetDuration(0.3)
    if res.fade.SetToFinalAlpha then res.fade:SetToFinalAlpha(true) end
    res:SetScript("OnClick", function(self) self:Hide() end)
    res:Hide()
    v.result = res
    v:SetScript("OnUpdate", function(self)
        local s = self.session
        if not s or s.over or not s.mins or s.mins <= 0 or not s.clock then return end
        local mine = myColour(s) or "w"
        local c = s.st.turn
        local card = (c == mine) and self.bottom or self.top
        local text = clockText(clockLeft(s, c))
        if card.clockShown ~= text then card.clockShown = text; card.clock:SetText(text) end
    end)
    v:SetScript("OnHide", function()
        v.sel, v.moves = nil, nil
        if v.drag then stopDrag() end
    end)
    return v
end

local WHY = {
    checkmate = "by checkmate", ["out of time"] = "on time", stalemate = "Stalemate",
    ["insufficient material"] = "Insufficient material", ["50-move rule"] = "50-move rule",
    ["threefold repetition"] = "Threefold repetition", agreed = "Draw agreed",
    ["out of time, no mating material"] = "Out of time, but no mating material left",
}
local function showResult(v, s)
    local res, rc = v.result, v.result.card
    local mine = myColour(s)
    local title, tone, icon
    if s.result == "d" then
        title, tone, icon = "Draw", C.accent, 3
    elseif mine then
        local won = s.result == mine
        title, tone = won and "You won" or "You lost", won and C.good or C.bad
        icon = s.result == "w" and 2 or 4
    else
        title, tone = (s.result == "w" and "White" or "Black") .. " wins", C.accent
        icon = s.result == "w" and 2 or 4
    end
    fitIcon(rc.icon, icon, 52, rc)
    rc.title:SetText(title)
    rc.title:SetTextColor(tone[1], tone[2], tone[3])
    rc.sub:SetText(WHY[s.why] or s.why or "")
    rc.line:SetColorTexture(tone[1], tone[2], tone[3], 1)
    if s.delta then
        local d = s.delta
        local sign = d > 0 and FDJ.Paint("good", "+" .. d) or d < 0 and FDJ.Paint("bad", tostring(d)) or FDJ.Paint("dim", "±0")
        rc.elo:SetText(("Rating %d  %s"):format(s.newRating, sign))
    else
        rc.elo:SetText("")
    end
    res:Show()
    res:SetAlpha(0)
    res.fade:Play()
end

local function moveRow(v, i)
    local r = v.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, v.list.content)
    r:SetHeight(22)
    r:SetPoint("LEFT")
    r:SetPoint("RIGHT")
    r.stripe = r:CreateTexture(nil, "BACKGROUND")
    r.stripe:SetAllPoints()
    r.stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.035 or 0)
    r.num = Kit.Text(r, "small", C.dim, "RIGHT")
    r.num:SetPoint("LEFT", 0, 0)
    r.num:SetWidth(30)
    r.w = Kit.Text(r, "small", C.text, "LEFT")
    r.w:SetPoint("LEFT", 44, 0)
    r.w:SetWidth(80)
    r.b = Kit.Text(r, "small", C.text, "LEFT")
    r.b:SetPoint("LEFT", 132, 0)
    r.b:SetWidth(80)
    r:SetPoint("TOP", 0, -(i - 1) * 22)
    v.rows[i] = r
    return r
end

local function paintCard(f, s, c)
    f.name:SetText(paint(nameOf(s, c)))
    fitPiece(f.king, 24, f)
    f.king:SetTexCoord(uiCoords(c .. "K"))
    local took, score = captured(s.st.b)
    local list = took[c]
    local foe = c == "w" and "b" or "w"
    local lead = score[c] - score[foe]
    local same, step = 9, 17
    local room = CARD_W - CLOCK_W - 12 - 10 - 12 - 20 - (lead > 0 and 26 or 0)
    local need = 0
    for i = 2, #list do need = need + (list[i - 1]:sub(2, 2) == list[i]:sub(2, 2) and same or step) end
    if need > room and need > 0 then
        local k = room / need
        same, step = same * k, step * k
    end
    local x = 12
    for i, t in ipairs(f.took) do
        local p = list[i]
        if p then
            if i > 1 then x = x + (list[i - 1]:sub(2, 2) == p:sub(2, 2) and same or step) end
            fitPiece(t, 20, f)
            t:SetTexCoord(uiCoords(p))
            t:ClearAllPoints()
            t:SetPoint("BOTTOMLEFT", math.floor(x + 0.5), 9)
            t:Show()
        else
            t:Hide()
        end
    end
    f.plus:ClearAllPoints()
    f.plus:SetPoint("BOTTOMLEFT", (#list > 0 and math.floor(x + 0.5) + 24 or 12), 14)
    f.plus:SetText(lead > 0 and ("+" .. lead) or "")
    local running = not s.over and s.st.turn == c
    f.bar:SetShown(running)
    f.glow:SetShown(running)
    local a = C.accent
    f.bar:SetVertexColor(a[1], a[2], a[3], 1)
    if f.gradient then
        f.glow:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], 0.16), CreateColor(a[1], a[2], a[3], 0))
    else
        f.glow:SetColorTexture(a[1], a[2], a[3], 0.07)
    end
    Kit.EdgeColor(f, running and C.accent or C.borderDim, running and 0.55 or 1)
    if s.mins > 0 then
        local left = clockLeft(s, c)
        f.clockShown = clockText(left)
        f.clock:SetText(f.clockShown)
        f.pill:Show()
        if running and left < 20 then
            f.pill.fill:SetColorTexture(0.62, 0.12, 0.11, 1)
            Kit.EdgeColor(f.pill, C.bad, 1)
            f.clock:SetTextColor(1, 1, 1)
        elseif running then
            f.pill.fill:SetColorTexture(C.accent[1] * 0.42, C.accent[2] * 0.42, C.accent[3] * 0.42, 1)
            Kit.EdgeColor(f.pill, C.accent, 1)
            f.clock:SetTextColor(1, 1, 1)
        else
            f.pill.fill:SetColorTexture(0.05, 0.05, 0.06, 1)
            Kit.EdgeColor(f.pill, C.borderDim, 1)
            f.clock:SetTextColor(0.55, 0.56, 0.6)
        end
    else
        f.pill:Hide()
    end
end

function paintView(clocksOnly)
    local v = view
    local s = v and v.session
    if not s then return end
    if not clocksOnly then themeBoard() end
    local mine = myColour(s) or "w"
    paintCard(v.top, s, mine == "w" and "b" or "w")
    paintCard(v.bottom, s, mine)
    if clocksOnly then return end
    local st = s.st
    local kingHot = inCheck(st) and kingSquare(st.b, st.turn)
    local pre = {}
    for _, q in ipairs(v.premoves or {}) do pre[q.from], pre[q.to] = true, true end
    local pm = v.premoves and #v.premoves > 0
    local board = planned(s)
    local pieceSheet, pieceSize = sheetFor(SQUARE - 2, v.board)
    for sqi = 1, 64 do
        local cell = v.cells[sqi]
        local f, r = cellAt(mine, sqi)
        cell:ClearAllPoints()
        cell:SetPoint("BOTTOMLEFT", (f - 1) * SQUARE, (r - 1) * SQUARE)
        local light = (fileOf(sqi) + rankOf(sqi)) % 2 == 1
        local col, other = light and LIGHT or DARK, light and DARK or LIGHT
        cell.bg:SetVertexColor(col[1], col[2], col[3], 1)
        cell.file:SetText(r == 1 and FILES:sub(fileOf(sqi), fileOf(sqi)) or "")
        cell.rank:SetText(f == 8 and tostring(rankOf(sqi)) or "")
        cell.file:SetTextColor(other[1], other[2], other[3])
        cell.rank:SetTextColor(other[1], other[2], other[3])
        local p = board[sqi]
        useSheet(cell.piece, pieceSheet)
        cell.piece:SetSize(pieceSize, pieceSize)
        if p and v.drag ~= sqi then
            cell.piece:SetTexCoord(pieceCoords(p))
            cell.piece:Show()
        else
            cell.piece:Hide()
        end
        local mark
        if pre[sqi] then mark = PREMOVE
        elseif v.sel == sqi then mark = SELECT
        elseif kingHot == sqi then mark = { 0.85, 0.15, 0.12, 0.6 } end
        if mark then cell.mark:SetVertexColor(mark[1], mark[2], mark[3], mark[4]); cell.mark:Show() else cell.mark:Hide() end
        cell.dot:Hide()
    end
    for _, m in ipairs(v.moves or {}) do
        local cell = v.cells[m.to]
        local take = board[m.to] ~= nil or m.ep
        if take then
            cell.dot:SetSize(SQUARE, SQUARE)
            cell.dot:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\ui-ring")
            cell.dot:SetVertexColor(0, 0, 0, 0.22)
        else
            cell.dot:SetSize(SQUARE * 0.32, SQUARE * 0.32)
            cell.dot:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\ui-disc")
            cell.dot:SetVertexColor(0, 0, 0, 0.2)
        end
        cell.dot:Show()
    end
    local n = math.ceil(#st.moves / 2)
    for i = 1, n do
        local r = moveRow(v, i)
        r.num:SetText(i .. ".")
        r.w:SetText(st.moves[i * 2 - 1] or "")
        r.b:SetText(st.moves[i * 2] or "")
        r:Show()
    end
    for i = n + 1, #v.rows do v.rows[i]:Hide() end
    v.empty:SetShown(n == 0)
    v.list:SetContentHeight(n * 22 + 4)
    v.list:To(math.max(0, n * 22 + 4 - (v.list:GetHeight() or 0)))
    if v.promo then
        for _, b in ipairs(v.picker.buttons) do
            fitPiece(b.icon, SQUARE - 2, b)
            b.icon:SetTexCoord(pieceCoords(mine .. b.t))
        end
        v.picker:Show()
    else
        v.picker:Hide()
    end
    local text
    if s.over then
        if s.result == "d" then text = FDJ.Paint("quest", "Draw") .. "  ·  " .. s.why
        else text = paint(nameOf(s, s.result)) .. FDJ.Paint("quest", " wins") .. "  ·  " .. s.why end
    elseif s.drawOffer and not same(s.drawOffer, me()) then
        text = paint(s.drawOffer) .. " offers a draw."
    elseif s.drawOffer then
        text = "Draw offered."
    elseif myTurn(s) then
        text = inCheck(st) and FDJ.Paint("bad", "Check!") .. "  " .. FDJ.Paint("accent", "Your move") or FDJ.Paint("accent", "Your move")
    else
        text = (inCheck(st) and FDJ.Paint("bad", "Check.") .. "  " or "") .. paint(nameOf(s, st.turn)) .. " is thinking…"
            .. (pm and ("  " .. FDJ.Paint("dim", #v.premoves == 1 and "(1 premove)" or ("(" .. #v.premoves .. " premoves)"))) or "")
    end
    v.status:SetText(text)
    if s.over then
        if v.resultFor ~= s then v.resultFor = s; showResult(v, s) end
    else
        v.resultFor = nil
        v.result:Hide()
    end
    local yours = not s.over and myTurn(s) and not v.promo
    Kit.EdgeColor(v.ring, yours and C.accent or C.borderDim, 1)
    v.halo:SetShown(yours and true or false)
    local playing = not s.over and myColour(s) ~= nil
    v.drawBtn:SetShown(playing)
    v.resignBtn:SetShown(playing)
    v.premoveBox:SetShown(playing)
    if v.premoveBox.Sync then v.premoveBox:Sync() end
    if v.soundBox.Sync then v.soundBox:Sync() end
    if playing then
        local offered = s.drawOffer and not same(s.drawOffer, me())
        v.drawBtn:SetLabel(offered and "Accept draw" or "Offer draw")
    end
    v.rematchBtn:SetShown(s.over and myColour(s) ~= nil)
    v.newBtn:SetShown(s.over)
end

function open(s)
    if not view then view = build() Games.Window(view) end
    view.session = s
    s.view = view
    view.sel, view.moves, view.promo, view.premoves = nil, nil, nil, nil
    paintView()
    view:Show()
end

local BOT = "Training Dummy"
local VALUE = { P = 1, N = 3, B = 3, R = 5, Q = 9, K = 0 }

local function material(b, c)
    local n = 0
    for i = 1, 64 do
        local p = b[i]
        if p and p:sub(1, 1) == c then n = n + VALUE[p:sub(2, 2)] end
    end
    return n
end

local function botPick(st)
    local moves = {}
    for i = 1, 64 do
        local p = st.b[i]
        if p and p:sub(1, 1) == st.turn then
            for _, m in ipairs(legal(st, i)) do moves[#moves + 1] = m end
        end
    end
    if #moves == 0 then return nil end
    if math.random() < 0.5 then
        for _, m in ipairs(moves) do
            local after = make(st, m)
            if inCheck(after) and not anyLegal(after) then return m end
        end
    end
    if math.random() < 0.35 then
        local best, worth = nil, 0
        for _, m in ipairs(moves) do
            local victim = st.b[m.to]
            local v = victim and VALUE[victim:sub(2, 2)] or 0
            if v > worth then best, worth = m, v end
        end
        if best then return best end
    end
    local m = moves[math.random(#moves)]
    if m.promo then
        for _, o in ipairs(moves) do
            if o.from == m.from and o.to == m.to and o.promo == "Q" then return o end
        end
    end
    return m
end

function Chess.BotTurn(s)
    local delay = 0.5 + math.random() * 0.9
    C_Timer.After(delay, function()
        if game ~= s or s.over or s.st.turn == myColour(s) then return end
        local m = botPick(s.st)
        if m then play(s, m) end
    end)
end

function Chess.PlayComputer(mins, colour, inc)
    if game and not game.over and not game.bot then FDJ.Print("Chess: finish the game you're in first.") return end
    if game then stop() end
    local mine = colour == "r" and (math.random(2) == 1 and "w" or "b") or colour or "w"
    local s = { id = "bot", mins = mins or 0, inc = inc or 0, bot = true, foe = BOT,
        w = mine == "w" and me() or BOT, b = mine == "w" and BOT or me() }
    begin(s)
    if mine == "b" then Chess.BotTurn(s) end
end

function Chess.Rematch()
    local s = game or (view and view.session)
    if not s or not s.over or not myColour(s) then return end
    local swap = myColour(s) == "w" and "b" or "w"
    if s.bot then
        Chess.PlayComputer(s.mins, swap, s.inc)
    else
        Chess.Challenge(foeOf(s), s.mins, swap, s.inc)
    end
end

function Chess.Resign()
    local s = game
    if not s or s.over or not myColour(s) then return end
    tell(s, "R", s.id)
    finish(s, myColour(s) == "w" and "b" or "w", short(me()) .. " resigned")
end

function Chess.OfferDraw()
    local s = game
    if not s or s.over or not myColour(s) then return end
    if s.bot then
        if material(s.st.b, myColour(s) == "w" and "b" or "w") < material(s.st.b, myColour(s)) then
            finish(s, "d", "agreed")
        else
            FDJ.Print(("Chess: %s declines the draw."):format(BOT))
        end
        return
    end
    if s.drawOffer and not same(s.drawOffer, me()) then
        tell(s, "Y", s.id)
        finish(s, "d", "agreed")
        return
    end
    if s.drawOffer then return end
    s.drawOffer = me()
    tell(s, "O", s.id)
    paintView()
end

function Chess.PopupsOn() return FojjiCoreDB and FojjiCoreDB.chessPopups == true end
function Chess.CombatHideOn() return not (FojjiCoreDB and FojjiCoreDB.chessCombatHide == false) end
function Chess.FlightButtonOn() return not (FojjiCoreDB and FojjiCoreDB.chessFlight == false) end

local AGAIN = 45
local lastAsked = {}

function Chess.Challenge(target, mins, colour, inc)
    target = target and target:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if target == "" or same(target, me()) then FDJ.Print("Chess: pick someone to challenge.") return end
    if game and not game.over then FDJ.Print("Chess: finish the game you're in first.") return end
    if invite then FDJ.Print(("Chess: still waiting for %s to answer."):format(short(invite.b))) return end
    if not inCircle(target) then FDJ.Print("Chess: you can challenge people in your guild, party or raid.") return end
    local wait = AGAIN - (GetTime() - (lastAsked[plain(target)] or -AGAIN))
    if wait > 0 then FDJ.Print(("Chess: you can challenge %s again in %d seconds."):format(short(target), math.ceil(wait))) return end
    lastAsked[plain(target)] = GetTime()
    invite = { id = tostring(math.random(100000, 999999)), a = me(), b = target, mins = mins or 0, inc = inc or 0, colour = colour or "r", t = GetTime() }
    send("C", ("%s~%d~%s~%d"):format(invite.id, invite.mins, invite.colour, invite.inc), "WHISPER", target)
    FDJ.Print(("Chess challenge sent to %s. Waiting for an answer."):format(short(target)))
    local mine = invite
    C_Timer.After(CHALLENGE_TIME, function()
        if invite == mine then
            invite = nil
            FDJ.Print(("Chess: %s didn't answer."):format(short(target)))
        end
    end)
end

local function clockName(mins, inc) return timeText(mins, inc) end

local incoming = {}
local accepted = {}
local refreshIncoming
function Chess.Incoming() return incoming end

local function answer(key, yes)
    local c = incoming[key]
    if not c then return end
    incoming[key] = nil
    if yes and game and not game.over then yes = false FDJ.Print("Chess: you're already in a game.") end
    send(yes and "A" or "D", c.id, "WHISPER", c.from)
    if yes then accepted[c.id] = c.from end
    if refreshIncoming then refreshIncoming() end
end
Chess.Answer = answer

local function askAccept(from, id, mins, colour, inc)
    if not inCircle(from) then return end
    local key = plain(from)
    local was = incoming[key]
    if was and GetTime() - was.t < CHALLENGE_TIME then return end
    local c = { from = from, id = id, mins = mins, colour = colour, inc = inc, t = GetTime() }
    incoming[key] = c
    C_Timer.After(CHALLENGE_TIME, function()
        if incoming[key] == c then incoming[key] = nil if refreshIncoming then refreshIncoming() end end
    end)
    local yours = colour == "w" and "black" or colour == "b" and "white" or "a random colour"
    FDJ.Print(("%s challenges you to chess: %s, you'd play %s. |cffffffff/fc chess|r to answer."):format(paint(from), clockName(mins, inc), yours))
    if refreshIncoming then refreshIncoming() end
    local open = (setup and setup:IsShown()) or (view and view:IsShown()) or (fly and fly:IsShown())
    if (Chess.PopupsOn() or open) and Chess.ShowChallenge then Chess.ShowChallenge() end
end

FDJ:On("FDJ_COMM", function(kind, payload, who)
    if kind ~= "CH" or type(payload) ~= "string" then return end
    local op, rest = payload:match("^(%a)~(.*)$")
    if op == "C" then
        local id, mins, colour, inc = rest:match("^(%d+)~(%d+)~([wbr])~?(%d*)$")
        if id then askAccept(who, id, tonumber(mins), colour, tonumber(inc) or 0) end
        return
    elseif (op == "A" or op == "D") and invite and rest == invite.id and same(who, invite.b) then
        local s = invite
        invite = nil
        if op == "A" then lastAsked[plain(who)] = nil end
        if op == "A" and game and not game.over then
            send("E", s.id, "WHISPER", who)
            return
        end
        if op == "D" then
            FDJ.Print(("Chess: %s declined."):format(short(who)))
            return
        end
        local mine = s.colour == "r" and (math.random(2) == 1 and "w" or "b") or s.colour
        local g = { id = s.id, mins = s.mins, inc = s.inc, w = mine == "w" and s.a or who, b = mine == "w" and who or s.a, foe = who }
        send("S", ("%s~%s~%s~%d~%d"):format(g.id, short(g.w), short(g.b), g.mins, g.inc or 0), "WHISPER", who)
        say(("Chess: %s (white) vs %s (black), %s."):format(short(g.w), short(g.b), clockName(g.mins, g.inc)))
        begin(g)
        return
    elseif op == "S" then
        local id, w, b, mins, inc = rest:match("^(%d+)~([^~]+)~([^~]+)~(%d+)~?(%d*)$")
        if not id or (game and game.id == id) then return end
        if not (same(w, me()) or same(b, me())) then return end
        if not (accepted[id] and same(who, accepted[id])) then return end
        accepted[id] = nil
        if game and not game.over then send("E", id, "WHISPER", who) return end
        begin({ id = id, w = w, b = b, mins = tonumber(mins), inc = tonumber(inc) or 0, foe = who })
        return
    end
    local s = game
    if not s or s.over then return end
    local id = rest:match("^(%d+)")
    if id ~= s.id or not same(who, foeOf(s)) then return end
    if op == "I" then
        local r, g = rest:match("^%d+~(%d+)~(%d+)$")
        s.foeRating, s.foeGames = tonumber(r), tonumber(g)
    elseif op == "M" then
        local ply, text, left = rest:match("^%d+~(%d+)~(%w+)~?(%d*)$")
        if tonumber(ply) ~= s.st.ply or s.st.turn == myColour(s) then return end
        local m = findMove(s.st, text)
        if m then
            local mover = s.st.turn
            play(s, m)
            if left ~= "" and s.clock and not s.over then
                s.clock[mover] = tonumber(left) / 10
                if s.view then paintView(true) end
            end
        end
    elseif op == "R" then
        finish(s, myColour(s), short(who) .. " resigned")
    elseif op == "O" then
        s.drawOffer = who
        paintView()
        if PlaySound and view and view:IsVisible() then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master") end
    elseif op == "Y" then
        if s.drawOffer and same(s.drawOffer, me()) then finish(s, "d", "agreed") end
    elseif op == "F" then
        if s.mins > 0 then flag(s, myColour(s) == "w" and "b" or "w") end
    elseif op == "E" then
        if s.st.ply >= 2 then finish(s, myColour(s), short(who) .. " left") stop() return end
        stop()
        s.over, s.result, s.why = true, "d", short(who) .. " left"
        FDJ.Print(("Chess: %s ended the game."):format(short(who)))
        if s.view then paintView() end
    end
end)

function Chess.End()
    local s = game
    if not s then return end
    if not s.over and myColour(s) then
        tell(s, "E", s.id)
        if s.st and s.st.ply >= 2 and not s.bot then
            finish(s, myColour(s) == "w" and "b" or "w", "left")
            stop()
            return
        end
        if same(s.w, me()) then say(("Chess between %s and %s was called off."):format(short(s.w), short(s.b))) end
    end
    stop()
    s.over, s.result, s.why = true, "d", "called off"
    if s.view then paintView() end
end

FDJ:On("PLAYER_LOGOUT", function() if game and not game.over then Chess.End() end end)

local function prefs()
    FojjiCoreDB.chess = FojjiCoreDB.chess or { mode = "player", mins = 5, inc = 0, colour = "r" }
    return FojjiCoreDB.chess
end

local function tile(parent, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.edges = Kit.Edge(b, C.borderDim)
    b.label = Kit.Text(b, "large", C.text, "CENTER")
    b.label:SetPoint("CENTER")
    function b:Paint()
        local on, hot = self.on, self.hot
        if on then
            self.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], hot and 0.36 or 0.26)
            Kit.EdgeColor(self, C.accent, 1)
            self.label:SetTextColor(1, 1, 1)
        else
            local c = hot and C.fieldHover or C.field
            self.fill:SetColorTexture(c[1], c[2], c[3], 0.95)
            Kit.EdgeColor(self, hot and C.border or C.borderDim, 1)
            self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
        if self.sub then self.sub:SetTextColor(on and 1 or C.muted[1], on and 1 or C.muted[2], on and 1 or C.muted[3]) end
    end
    function b:Select(on) self.on = on and true or nil self:Paint() end
    b:SetScript("OnEnter", function(self) self.hot = true self:Paint() end)
    b:SetScript("OnLeave", function(self) self.hot = nil self:Paint() end)
    b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    b:Paint()
    return b
end

local function heading(parent, text, y)
    local t = Kit.Text(parent, "small", C.muted, "LEFT")
    t:SetPoint("TOPLEFT", 18, y)
    t:SetText(text:upper())
    return t
end

local refreshSetup

local BOARD_ROW = 26
local board

local function buildBoard(p)
    board = p
    local me_ = CreateFrame("Frame", nil, p)
    me_:SetPoint("TOPLEFT", 18, -14)
    me_:SetPoint("TOPRIGHT", -18, -14)
    me_:SetHeight(64)
    Kit.Fill(me_, C.field, 0.95)
    Kit.Edge(me_, C.borderDim)
    local bar = me_:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    bar:SetWidth(3)
    Kit.Paint(bar, C.accent)
    p.icon = me_:CreateTexture(nil, "ARTWORK")
    p.icon:SetPoint("LEFT", 14, 0)
    p.label = Kit.Text(me_, "small", C.muted, "LEFT")
    p.label:SetPoint("TOPLEFT", 66, -14)
    p.label:SetText("YOUR RATING")
    p.record = Kit.Text(me_, "small", C.text, "LEFT")
    p.record:SetPoint("TOPLEFT", p.label, "BOTTOMLEFT", 0, -6)
    p.big = Kit.Text(me_, 30, C.white, "RIGHT")
    p.big:SetPoint("RIGHT", -16, 0)
    p.rank = Kit.Text(me_, "small", C.muted, "RIGHT")
    p.rank:SetPoint("RIGHT", p.big, "LEFT", -12, -2)

    local head = CreateFrame("Frame", nil, p)
    head:SetPoint("TOPLEFT", me_, "BOTTOMLEFT", 0, -16)
    head:SetPoint("TOPRIGHT", me_, "BOTTOMRIGHT", 0, -16)
    head:SetHeight(20)
    local function col(parent, x, w, justify, size, color)
        local t = Kit.Text(parent, size or "small", color or C.text, justify)
        t:SetPoint("LEFT", x, 0)
        t:SetWidth(w)
        return t
    end
    local cols = { { 6, 24, "RIGHT", "#" }, { 40, 150, "LEFT", "Player" }, { 192, 60, "RIGHT", "Rating" }, { 258, 46, "RIGHT", "Games" }, { 310, 66, "RIGHT", "Vs you" } }
    for _, c in ipairs(cols) do col(head, c[1], c[2], c[3], "tiny", C.muted):SetText(c[4]:upper()) end
    local box = CreateFrame("Frame", nil, p)
    box:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
    box:SetPoint("BOTTOMRIGHT", -18, 46)
    Kit.Fill(box, C.field, 0.6)
    Kit.Edge(box, C.borderDim)
    p.list = Kit.Scroller(box)
    p.list:SetPoint("TOPLEFT", 1, -1)
    p.list:SetPoint("BOTTOMRIGHT", -1, 1)
    p.rows = {}
    p.make = function(i)
        local r = CreateFrame("Frame", nil, p.list.content)
        r:SetHeight(BOARD_ROW)
        r:SetPoint("LEFT")
        r:SetPoint("RIGHT")
        r:SetPoint("TOP", 0, -(i - 1) * BOARD_ROW)
        r.stripe = r:CreateTexture(nil, "BACKGROUND")
        r.stripe:SetAllPoints()
        r.hl = r:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.hl:SetAllPoints()
        r.cells = {}
        for k, c in ipairs(cols) do r.cells[k] = col(r, c[1] - 1, c[2], c[3], k == 3 and "normal" or "small", k == 1 and C.dim or C.text) end
        return r
    end
    p.empty = Kit.Text(box, "small", C.dim, "CENTER")
    p.empty:SetPoint("CENTER")
    p.empty:SetWidth(320)
    p.empty:SetWordWrap(true)
    p.note = Kit.Text(p, "tiny", C.dim, "LEFT")
    p.note:SetPoint("BOTTOMLEFT", 18, 20)
    p.note:SetWidth(384)
    p.note:SetWordWrap(true)
    p.note:SetText("You and the players you've played, as rated when you last played them. Everyone starts at 1000; games against the computer aren't rated.")
    p:SetScript("OnShow", function() refreshBoard() end)
end

function refreshBoard()
    local p = board
    if not (p and p:IsVisible()) then return end
    local mine = myRating()
    local myName = plain(me()) or "?"
    fitIcon(p.icon, 2, 40, p)
    p.big:SetText(tostring(mine.r))
    p.record:SetText(mine.g > 0 and ("%d games  ·  %s %d  %s %d  %s %d"):format(mine.g, FDJ.Paint("good", "W"), mine.w, FDJ.Paint("dim", "D"), mine.d, FDJ.Paint("bad", "L"), mine.l) or FDJ.Paint("dim", "No rated games yet"))
    local list = { { name = myName, r = mine.r, g = mine.g, w = mine.w, d = mine.d, l = mine.l, me = true } }
    for name, e in pairs(ratingStore().board) do
        if name ~= myName then
            list[#list + 1] = { name = name, r = e.r or START_ELO, g = e.g or 0, w = e.w or 0, d = e.d or 0, l = e.l or 0 }
        end
    end
    table.sort(list, function(a, b)
        if (a.g > 0) ~= (b.g > 0) then return a.g > 0 end
        if a.r ~= b.r then return a.r > b.r end
        return a.name < b.name
    end)
    local myRank
    for i, e in ipairs(list) do
        local r = p.rows[i] or p.make(i)
        p.rows[i] = r
        r.stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.035 or 0)
        r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], e.me and 0.14 or 0)
        local unrated = e.g == 0
        r.cells[1]:SetText(unrated and "–" or tostring(i))
        r.cells[2]:SetText(paint(e.name))
        r.cells[3]:SetText(unrated and FDJ.Paint("dim", tostring(e.r)) or tostring(e.r))
        r.cells[4]:SetText(tostring(e.g))
        r.cells[5]:SetText(("%d / %d / %d"):format(e.w, e.d, e.l))
        r:Show()
        if e.me then myRank = i end
    end
    for i = #list + 1, #p.rows do p.rows[i]:Hide() end
    p.list:SetContentHeight(#list * BOARD_ROW + 2)
    p.rank:SetText(mine.g > 0 and myRank and #list > 1 and ("#%d of %d"):format(myRank, #list) or "")
    p.empty:SetText(#list <= 1 and "Players show up here once you've finished a game against them." or "")
end

local function buildSetup()
    local win = Kit.Window("FojjiCoreChessStart", "Chess", 420, 586 + 32)
    win:SetFrameStrata("DIALOG")
    win.backBtn = Kit.Button(win.head, "Back to game", 104, 22, function()
        if game and view then
            win:Hide()
            view.session = game
            paintView()
            view:Show()
        end
    end, "primary")
    win.backBtn:SetPoint("RIGHT", win.close, "LEFT", -8, 0)
    win.backBtn:Hide()
    local f = CreateFrame("Frame", nil, win)
    f:SetPoint("TOPLEFT", 0, -32)
    f:SetPoint("BOTTOMRIGHT")
    f.fits = {}
    local lb = CreateFrame("Frame", nil, win)
    lb:SetPoint("TOPLEFT", 0, -74)
    lb:SetPoint("BOTTOMRIGHT")
    lb:Hide()
    win.page, win.board = f, lb
    local P = prefs()

    heading(f, "Opponent", -50)
    local who = {}
    local function opponent(mode, x, title, sub, icon)
        local b = tile(f, 188, 58, function() P.mode = mode refreshSetup() end)
        b:SetPoint("TOPLEFT", x, -68)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", 56, -12)
        Kit.SetFont(b.label, "normal")
        b.label:SetText(title)
        b.sub = Kit.Text(b, "tiny", C.muted, "LEFT")
        b.sub:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -4)
        b.sub:SetText(sub)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER", b, "LEFT", 30, 0)
        local tex = b.icon
        f.fits[#f.fits + 1] = function() fitIcon(tex, icon, 44, f) end
        who[mode] = b
    end
    opponent("player", 18, "A player", "Anyone with FojjiCore", 0)
    opponent("bot", 214, "The computer", "Beginner", 1)
    f.who = who

    f.target = Kit.Input(f, 384, 28, "Player name")
    f.target:SetPoint("TOPLEFT", 18, -144)
    f.target:HookScript("OnTextChanged", function() refreshSetup() end)
    f.botNote = Kit.Text(f, "small", C.muted, "LEFT")
    f.botNote:SetPoint("TOPLEFT", 18, -144)
    f.botNote:SetWidth(384)
    f.botNote:SetWordWrap(true)
    f.botNote:SetText("Practice against a very weak opponent: it mostly plays random moves, grabs a piece now and then and only sometimes spots a mate.")

    heading(f, "Time control", -202)
    f.times = {}
    local y = -220
    for _, group in ipairs(TIME) do
        local name = Kit.Text(f, "normal", C.text, "LEFT")
        name:SetPoint("TOPLEFT", 18, y - 9)
        name:SetText(group[1])
        for i = 2, #group do
            local m, inc = group[i][1], group[i][2]
            local b = tile(f, 72, 34, function() P.mins, P.inc = m, inc refreshSetup() end)
            b:SetPoint("TOPLEFT", 102 + (i - 2) * 76, y)
            b.label:SetText(m .. " + " .. inc)
            b.mins, b.inc = m, inc
            f.times[#f.times + 1] = b
        end
        y = y - 40
    end
    local none = tile(f, 300, 34, function() P.mins, P.inc = 0, 0 refreshSetup() end)
    none:SetPoint("TOPLEFT", 102, y)
    none.label:SetText("No clock")
    none.mins, none.inc = 0, 0
    f.times[#f.times + 1] = none
    local noneName = Kit.Text(f, "normal", C.text, "LEFT")
    noneName:SetPoint("TOPLEFT", 18, y - 9)
    noneName:SetText("Casual")

    heading(f, "Your colour", y - 52)
    f.colours = {}
    local cy = y - 70
    for i, def in ipairs({ { "w", "White" }, { "r", "Random" }, { "b", "Black" } }) do
        local b = tile(f, 124, 62, function() P.colour = def[1] refreshSetup() end)
        b:SetPoint("TOPLEFT", 18 + (i - 1) * 130, cy)
        b.label:ClearAllPoints()
        b.label:SetPoint("BOTTOM", 0, 6)
        Kit.SetFont(b.label, "small")
        b.label:SetText(def[2])
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOP", b, "TOP", 0, -2)
        local idx = def[1] == "w" and 2 or def[1] == "r" and 3 or 4
        f.fits[#f.fits + 1] = function() fitIcon(t, idx, 42, f) end
        b.key = def[1]
        f.colours[i] = b
    end

    f.go = Kit.Button(f, "", 384, 36, function()
        if P.mode == "bot" then
            Chess.PlayComputer(P.mins, P.colour, P.inc)
        else
            local name = f.target:GetText()
            if (name or ""):gsub("%s", "") == "" then f.target:SetFocus() return end
            Chess.Challenge(name, P.mins, P.colour, P.inc)
        end
        win:Hide()
    end, "primary")
    f.go:SetPoint("BOTTOM", 0, 16)

    buildBoard(lb)
    win.tabs = Kit.Tabs(win, { { "play", "New game" }, { "board", "Leaderboard" } }, function(key)
        f:SetShown(key == "play")
        lb:SetShown(key == "board")
        if key == "board" then refreshBoard() end
    end)
    win.tabs.first:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -38)
    local rule = win:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", 12, -70)
    rule:SetPoint("TOPRIGHT", -12, -70)
    rule:SetHeight(1)
    Kit.Paint(rule, C.borderDim)
    win.rule = rule
    win.fullHeight = win:GetHeight()
    for _, k in ipairs({ "fits", "who", "target", "botNote", "times", "colours", "go" }) do win[k] = f[k] end

    win.tabs:Select("play")
    return win
end

function refreshSetup()
    local f = setup
    if not f then return end
    local P = prefs()
    f.backBtn:SetShown(game ~= nil and not game.over and view ~= nil)
    for _, fit in ipairs(f.fits) do fit() end
    for mode, b in pairs(f.who) do b:Select(P.mode == mode) end
    local bot = P.mode == "bot"
    f.target:SetShown(not bot)
    f.botNote:SetShown(bot)
    for _, b in ipairs(f.times) do b:Select(b.mins == P.mins and b.inc == (P.inc or 0)) end
    for _, b in ipairs(f.colours) do b:Select(b.key == P.colour) end
    local name = f.target:GetText() or ""
    if bot then
        f.go:SetLabel("Play the Training Dummy")
    else
        f.go:SetLabel(name:gsub("%s", "") ~= "" and ("Challenge " .. name) or "Challenge")
    end
end

local function fillFromTarget()
    if not (setup and setup:IsShown()) or setup.target:HasFocus() then return end
    if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        setup.target:SetText(GetUnitName("target", true) or "")
        refreshSetup()
    end
end

local watch = CreateFrame("Frame")
local watched = {}
local function rewatch()
    local setupUp = setup and setup:IsShown()
    local any = false
    for f in pairs(watched) do if f:IsShown() then any = true end end
    if setupUp then watch:RegisterEvent("PLAYER_TARGET_CHANGED") else watch:UnregisterEvent("PLAYER_TARGET_CHANGED") end
    if any and Chess.CombatHideOn() then watch:RegisterEvent("PLAYER_REGEN_DISABLED") else watch:UnregisterEvent("PLAYER_REGEN_DISABLED") end
end
watch:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        fillFromTarget()
    elseif event == "PLAYER_REGEN_DISABLED" then
        for f in pairs(watched) do f:Hide() end
    end
end)
function Chess.Watch(frame)
    if not frame or frame.chessWatched then return end
    frame.chessWatched = true
    watched[frame] = true
    frame:HookScript("OnShow", rewatch)
    frame:HookScript("OnHide", rewatch)
    rewatch()
end
Chess.Rewatch = rewatch

local pop
local function buildPop()
    local f = CreateFrame("Frame", "FojjiCoreChessChallenge", UIParent)
    f:SetSize(360, 86)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local a, _, b, x, y = self:GetPoint(1)
        FojjiCoreDB.chessPopPos = { a, b, x, y }
    end)
    local p = FojjiCoreDB.chessPopPos
    if p and p[1] then f:ClearAllPoints() f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
    Kit.Fill(f, C.frame, 0.97)
    f.edges = Kit.Edge(f, C.accent, 0.8)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", -1, -1)
    line:SetHeight(2)
    Kit.Paint(line, C.accent)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("LEFT", 14, 2)
    f.who = Kit.Text(f, "normal", C.white, "LEFT")
    f.who:SetPoint("TOPLEFT", 64, -16)
    f.who:SetPoint("RIGHT", f, "RIGHT", -32, 0)
    f.what = Kit.Text(f, "small", C.muted, "LEFT")
    f.what:SetPoint("TOPLEFT", f.who, "BOTTOMLEFT", 0, -5)
    f.what:SetPoint("RIGHT", f, "RIGHT", -32, 0)
    f.yes = Kit.Button(f, "Accept", 90, 24, function() local k = f.key f:Hide() answer(k, true) end, "primary")
    f.yes:SetPoint("BOTTOMRIGHT", -12, 10)
    f.no = Kit.Button(f, "Decline", 90, 24, function() answer(f.key, false) end)
    f.no:SetPoint("RIGHT", f.yes, "LEFT", -6, 0)
    f.timer = f:CreateTexture(nil, "ARTWORK")
    f.timer:SetPoint("BOTTOMLEFT", 1, 1)
    f.timer:SetHeight(2)
    Kit.Paint(f.timer, C.accent)
    local x = CreateFrame("Button", nil, f)
    x:SetSize(20, 20)
    x:SetPoint("TOPRIGHT", -4, -6)
    x.icon = x:CreateTexture(nil, "ARTWORK")
    x.icon:SetSize(12, 12)
    x.icon:SetPoint("CENTER")
    x.icon:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\close-cross")
    x.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    x:SetScript("OnEnter", function(self) self.icon:SetVertexColor(1, 1, 1) end)
    x:SetScript("OnLeave", function(self) self.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3]) end)
    x:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnUpdate", function(self)
        local c = self.key and incoming[self.key]
        if not c then return end
        local left = math.max(0, 1 - (GetTime() - c.t) / CHALLENGE_TIME)
        self.timer:SetWidth(math.max(1, (self:GetWidth() - 2) * left))
    end)
    f:Hide()
    if Games.Window then Games.Window(f) end
    return f
end

local function waiting()
    local key, c
    for k, v in pairs(incoming) do if not c or v.t < c.t then key, c = k, v end end
    return key, c
end

local function showPop()
    if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    local key, c = waiting()
    if not c then return end
    pop = pop or buildPop()
    themeBoard()
    pop.key = key
    fitIcon(pop.icon, 0, 40, pop)
    pop.who:SetText(paint(c.from) .. " challenges you to chess")
    local yours = c.colour == "w" and "you're Black" or c.colour == "b" and "you're White" or "random colours"
    pop.what:SetText(("%s  ·  %s"):format(clockName(c.mins, c.inc), yours))
    pop:Show()
end
Chess.ShowChallenge = showPop

function refreshIncoming()
    if not pop then return end
    local key = waiting()
    if not key then pop:Hide() elseif pop:IsShown() and pop.key ~= key then showPop() end
end

function Chess.Setup(fresh)
    if not fresh and game and not game.over and view then view.session = game; paintView(); view:Show() return end
    themeBoard()
    if not setup then setup = buildSetup() Games.Window(setup) end
    setup:Show()
    fillFromTarget()
    refreshSetup()
    showPop()
end

function Chess.Toggle()
    if view and view:IsShown() then view:Hide() return end
    if setup and setup:IsShown() then setup:Hide() return end
    Chess.Setup()
end

local function flightSpot(b)
    b:ClearAllPoints()
    local p = FojjiCoreDB and FojjiCoreDB.gamesCardPos
    if p and p.point then
        b:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        b:SetPoint("TOP", UIParent, "TOP", 0, -90)
    end
end
Games.list = Games.list or {}
table.insert(Games.list, 1, { name = "Chess", piece = "wN", open = function() themeBoard() Chess.Toggle() end })
if Games.Deathroll then
    table.insert(Games.list, 2, { name = "Deathroll", icon = "Interface\\Icons\\INV_Misc_Dice_02", open = function() Games.Deathroll.Setup() end })
end
local GAMES = Games.list
local TILE_SIZE, TILE_GAP, PADDING = 40, 6, 8
local function headButton(parent, size, tip, body, onClick)
    local x = CreateFrame("Button", nil, parent)
    x:SetSize(size, size)
    x.icon = x:CreateTexture(nil, "ARTWORK")
    x.icon:SetPoint("CENTER")
    x:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        if self.ring then self.ring:SetVertexColor(1, 1, 1) end
        Kit.Tip(self, tip, body)
    end)
    x:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
        if self.ring then self.ring:SetVertexColor(C.muted[1], C.muted[2], C.muted[3]) end
        if GameTooltip then GameTooltip:Hide() end
    end)
    x:SetScript("OnClick", onClick)
    x.icon:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\close-cross")
    x.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    return x
end
local function flyButton()
    if fly then return fly end
    local n = #GAMES
    local b = CreateFrame("Frame", "FojjiCoreGamesFlight", UIParent)
    b:SetSize(PADDING * 2 + n * TILE_SIZE + (n - 1) * TILE_GAP, PADDING + 20 + TILE_SIZE + PADDING)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:SetMovable(true)
    b:EnableMouse(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) self:StartMoving() end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        FojjiCoreDB.gamesCardPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    Kit.Fill(b, C.frame, 0.94)
    b.edges = Kit.Edge(b, C.borderDim)
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", -1, -1)
    line:SetHeight(2)
    Kit.Paint(line, C.accent)
    local title = Kit.Text(b, "tiny", C.muted, "LEFT")
    title:SetPoint("TOPLEFT", PADDING + 1, -9)
    title:SetText("GAMES")
    local x = headButton(b, 20, "Close", nil, function()
        if not b.manual then b.dismissed = true end
        b.manual = nil
        b:Hide()
    end)
    x:SetPoint("TOPRIGHT", -3, -3)
    x.icon:SetSize(13, 13)
    local never = headButton(b, 20, "Don't show on flights", "Turn it back on in FojjiCore options: Extra Features > Games.", function()
        FojjiCoreDB.chessFlight = false
        FDJ.Print("Games won't pop up on flight paths any more. Turn it back on in Extra Features > Games, or type /fc games.")
        b.manual = nil
        b:Hide()
        Chess.ApplyFlight()
    end)
    never:SetPoint("RIGHT", x, "LEFT", -1, 0)
    never.icon:SetSize(8, 8)
    never.ring = never:CreateTexture(nil, "ARTWORK")
    never.ring:SetPoint("CENTER")
    never.ring:SetSize(15, 15)
    never.ring:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\ui-ring")
    never.ring:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
    b.never = never
    b.tiles = {}
    for i, g in ipairs(GAMES) do
        local t = CreateFrame("Button", nil, b)
        t:SetSize(TILE_SIZE, TILE_SIZE)
        t:SetPoint("TOPLEFT", PADDING + (i - 1) * (TILE_SIZE + TILE_GAP), -(PADDING + 20))
        t.fill = Kit.Fill(t, C.field, 0.95)
        t.edges = Kit.Edge(t, C.borderDim)
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetPoint("CENTER")
        t.game = g
        t:RegisterForDrag("LeftButton")
        t:SetScript("OnDragStart", function() b:StartMoving() end)
        t:SetScript("OnDragStop", function() b:GetScript("OnDragStop")(b) end)
        t:SetScript("OnEnter", function(self)
            Kit.EdgeColor(self, C.accent, 1)
            Kit.Tip(self, self.game.name)
        end)
        t:SetScript("OnLeave", function(self)
            Kit.EdgeColor(self, C.borderDim, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
        t:SetScript("OnClick", function(self) self.game.open() end)
        b.tiles[i] = t
    end
    b.fade = b:CreateAnimationGroup()
    local a = b.fade:CreateAnimation("Alpha")
    a:SetFromAlpha(0)
    a:SetToAlpha(1)
    a:SetDuration(0.25)
    if b.fade.SetToFinalAlpha then b.fade:SetToFinalAlpha(true) end
    b:Hide()
    fly = b
    return b
end
local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") end
local flightCheck
local landWatch
local function watchLanding(on)
    if on and not landWatch then
        landWatch = C_Timer.NewTicker(1, function() if not onTaxi() then flightCheck() end end)
    elseif not on and landWatch then
        landWatch:Cancel()
        landWatch = nil
    end
end
local function fillTiles(b)
    for _, t in ipairs(b.tiles) do
        if t.game.piece then
            fitPiece(t.icon, 30, t)
            t.icon:SetTexCoord(uiCoords(t.game.piece))
        elseif t.game.icon then
            t.icon:SetTexture(t.game.icon)
            t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            t.icon:SetSize(30, 30)
        elseif t.game.draw then
            t.game.draw(t)
        end
    end
end
local function showCard(b)
    themeBoard()
    fillTiles(b)
    b:Show()
    b:SetAlpha(0)
    b.fade:Play()
end
function flightCheck()
    local on = Chess.FlightButtonOn() and onTaxi()
    if on then
        local b = flyButton()
        if not b:IsShown() and not b.dismissed then
            b.manual = nil
            flightSpot(b)
            showCard(b)
        end
        watchLanding(true)
    else
        if fly and not fly.manual then fly:Hide() fly.dismissed = nil end
        watchLanding(false)
    end
end

function Chess.ShowGames()
    local b = flyButton()
    if b:IsShown() and b.manual then b:Hide() return end
    b.manual, b.dismissed = true, nil
    flightSpot(b)
    showCard(b)
end
local flightEvents = CreateFrame("Frame")
flightEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_CONTROL_LOST" then
        if UnitOnTaxi("player") then flightCheck() else C_Timer.After(1.5, flightCheck) end
    else
        flightCheck()
    end
end)
function Chess.ApplyFlight()
    if Chess.FlightButtonOn() then
        flightEvents:RegisterEvent("PLAYER_CONTROL_LOST")
        flightEvents:RegisterEvent("PLAYER_CONTROL_GAINED")
        flightEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        flightEvents:UnregisterAllEvents()
    end
    flightCheck()
end
FDJ:On("PLAYER_LOGIN", Chess.ApplyFlight)
