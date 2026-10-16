local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Routes = {}
FDJ.Routes = Routes

local L = FDJ.L
local MAX_POINTS = 300
local MAX_STROKES = 200
local MAX_STROKE_POINTS = 400
local MAX_MARKS = 150
local MAX_LABEL = 80
local history = {}

Routes.offers = {}
Routes.Widths = { 2, 4, 7 }

Routes.Marks = {
    { key = "skull", tex = "mark-skull", tint = { 0.95, 0.95, 0.95 } },
    { key = "swords", tex = "mark-swords", tint = { 1.0, 0.45, 0.35 } },
    { key = "shield", tex = "mark-shield", tint = { 0.45, 0.70, 1.0 } },
    { key = "heal", tex = "mark-heal", tint = { 0.40, 0.90, 0.45 } },
    { key = "aoe", tex = "mark-aoe", tint = { 1.0, 0.55, 0.20 } },
    { key = "warn", tex = "mark-warn", tint = { 1.0, 0.82, 0.25 } },
    { key = "eye", tex = "mark-eye", tint = { 0.80, 0.60, 1.0 } },
    { key = "patrol", tex = "mark-patrol", tint = { 1.0, 0.70, 0.40 } },
    { key = "sleep", tex = "mark-sleep", tint = { 0.55, 0.80, 1.0 } },
    { key = "chest", tex = "mark-chest", tint = { 1.0, 0.82, 0.35 } },
    { key = "stairs", tex = "mark-stairs", tint = { 0.85, 0.85, 0.85 } },
    { key = "door", tex = "mark-door", tint = { 0.85, 0.70, 0.50 } },
    { key = "flag", tex = "mark-flag", tint = { 0.40, 0.90, 0.45 } },
    { key = "finish", tex = "mark-finish", tint = { 0.95, 0.95, 0.95 } },
    { key = "arrow", tex = "mark-arrow", tint = { 0.40, 0.70, 1.0 } },
    { key = "cross", tex = "mark-cross", tint = { 0.95, 0.35, 0.35 } },
    { key = "star", tex = "mark-star", tint = { 1.0, 0.85, 0.30 } },
    { key = "question", tex = "mark-question", tint = { 0.85, 0.85, 0.85 } },
    { key = "text", text = true, tex = "fc:icon-font", tint = { 1, 1, 1 } },
    { key = "rt1", raid = 1 }, { key = "rt2", raid = 2 }, { key = "rt3", raid = 3 }, { key = "rt4", raid = 4 },
    { key = "rt5", raid = 5 }, { key = "rt6", raid = 6 }, { key = "rt7", raid = 7 }, { key = "rt8", raid = 8 },
}
local CLASS_TEX = "Interface\\TargetingFrame\\UI-Classes-Circles"
local CLASS_GRID = {
    WARRIOR = { 0, 0 }, MAGE = { 1, 0 }, ROGUE = { 2, 0 }, DRUID = { 3, 0 },
    HUNTER = { 0, 1 }, SHAMAN = { 1, 1 }, PRIEST = { 2, 1 }, WARLOCK = { 3, 1 }, PALADIN = { 0, 2 },
}
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
for _, class in ipairs(CLASS_ORDER) do
    local g = CLASS_GRID[class]
    Routes.Marks[#Routes.Marks + 1] = {
        key = "c_" .. class:lower(), tex = CLASS_TEX, plain = true, px = 256,
        coords = { g[1] * 0.25, g[1] * 0.25 + 0.2461, g[2] * 0.25, g[2] * 0.25 + 0.25 },
        name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or (class:sub(1, 1) .. class:sub(2):lower()),
    }
end
local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
for _, role in ipairs({ { "tank", 0, 19, 22, 41 }, { "healer", 20, 39, 1, 20 }, { "damage", 20, 39, 22, 41 } }) do
    Routes.Marks[#Routes.Marks + 1] = {
        key = "r_" .. role[1], tex = ROLE_TEX, plain = true, px = 64,
        coords = { role[2] / 64, role[3] / 64, role[4] / 64, role[5] / 64 },
    }
end

Routes.MarkByKey = {}
Routes.Stamps = {}
for _, m in ipairs(Routes.Marks) do
    Routes.MarkByKey[m.key] = m
    if not m.text then Routes.Stamps[#Routes.Stamps + 1] = m end
    if m.raid then
        m.tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. m.raid
        m.plain = true
    end
    if m.name then L["MARK_" .. m.key:upper()] = m.name end
end

function Routes.MarkIcon(def, size)
    if def.coords then
        local c, px = def.coords, def.px or 64
        return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(def.tex, size, size, px, px, math.floor(c[1] * px + 0.5), math.floor(c[2] * px + 0.5), math.floor(c[3] * px + 0.5), math.floor(c[4] * px + 0.5))
    end
    return ("|T%s:%d:%d|t"):format(FDJ.Glyph(def.tex), size, size)
end

function Routes.ApplyIcon(tex, def)
    tex:SetTexture(FDJ.Glyph(def.tex))
    if def.coords then tex:SetTexCoord(def.coords[1], def.coords[2], def.coords[3], def.coords[4]) else tex:SetTexCoord(0, 1, 0, 1) end
    if def.plain then tex:SetVertexColor(1, 1, 1) elseif def.tint then tex:SetVertexColor(def.tint[1], def.tint[2], def.tint[3]) end
end

function Routes.MarkTexture(key)
    local m = Routes.MarkByKey[key] or Routes.MarkByKey.question
    return FDJ.Glyph(m.tex), m
end

local function newID()
    return ("%x%04x"):format(time(), math.random(0, 65535))
end

local function normalize(route)
    route.points = route.points or {}
    route.strokes = route.strokes or {}
    route.marks = route.marks or {}
    return route
end
Routes.Normalize = normalize

function Routes.All()
    return FDJ.db.routes
end

function Routes.Get(id)
    return id and FDJ.db.routes[id]
end

local function sorted(filter)
    local out = {}
    for _, route in pairs(FDJ.db.routes) do
        normalize(route)
        if filter(route) then out[#out + 1] = route end
    end
    table.sort(out, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

function Routes.ForDungeon(d)
    return sorted(function(r) return r.key == d.key end)
end

function Routes.World()
    return sorted(function(r) return r.scope == "world" end)
end

function Routes.ForChart(d)
    return sorted(function(r) return r.scope == "chart" and r.key == d.key end)
end

local function touches(route, mapID)
    for _, p in ipairs(route.points) do if p.m == mapID then return true end end
    for _, s in ipairs(route.strokes) do if s.m == mapID then return true end end
    for _, k in ipairs(route.marks) do if k.m == mapID then return true end end
    return false
end
Routes.Touches = touches

function Routes.ForMap(mapID)
    return sorted(function(r) return r.scope == "world" and touches(r, mapID) end)
end

function Routes.Create(scope, key, name)
    local route = normalize({
        id = newID(),
        name = FDJ.Clip(name, 60) or L.NEW_ROUTE,
        scope = scope,
        key = key,
        color = 1,
        author = FDJ.PlayerName(),
        made = time(),
    })
    FDJ.db.routes[route.id] = route
    FDJ:Emit("FDJ_ROUTES")
    return route
end

function Routes.Delete(route)
    if not route then return end
    FDJ.db.routes[route.id] = nil
    history[route.id] = nil
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.Rename(route, name)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "")
    if not name or name == "" then return end
    route.name = FDJ.Clip(name:gsub("[|\n\r]", ""), 60)
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.Color(route, index)
    return FDJ.RouteColors[index or route.color] or FDJ.RouteColors[1]
end

function Routes.CycleColor(route)
    route.color = (route.color % #FDJ.RouteColors) + 1
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.IsEmpty(route)
    return #route.points == 0 and #route.strokes == 0 and #route.marks == 0
end

local function remember(route)
    local stack = history[route.id]
    if not stack then
        stack = {}
        history[route.id] = stack
    end
    stack[#stack + 1] = { points = FDJ.Copy(route.points), strokes = FDJ.Copy(route.strokes), marks = FDJ.Copy(route.marks) }
    if #stack > 60 then table.remove(stack, 1) end
end

function Routes.CanUndo(route)
    return route ~= nil and history[route.id] ~= nil and #history[route.id] > 0
end

function Routes.Undo(route)
    local stack = route and history[route.id]
    if not stack or #stack == 0 then return end
    local snap = table.remove(stack)
    route.points, route.strokes, route.marks = snap.points, snap.strokes, snap.marks
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.Add(route, m, x, y, after)
    if #route.points >= MAX_POINTS then
        FDJ.Print(L.ROUTE_FULL)
        return nil
    end
    remember(route)
    local index = after and FDJ.Clamp(after + 1, 1, #route.points + 1) or #route.points + 1
    table.insert(route.points, index, { m = m, x = FDJ.Clamp(x, 0, 1), y = FDJ.Clamp(y, 0, 1) })
    FDJ:Emit("FDJ_ROUTES")
    return index
end

function Routes.Move(route, index, x, y)
    local p = route.points[index]
    if not p then return end
    remember(route)
    p.x, p.y = FDJ.Clamp(x, 0, 1), FDJ.Clamp(y, 0, 1)
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.Remove(route, index)
    if not route.points[index] then return end
    remember(route)
    table.remove(route.points, index)
    FDJ:Emit("FDJ_ROUTES")
end

local function cleanLabel(text)
    text = text and text:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, MAX_LABEL)
    if text == "" then return nil end
    return text
end

function Routes.Label(route, index, text)
    local p = route.points[index]
    if not p then return end
    remember(route)
    p.label = cleanLabel(text)
    FDJ:Emit("FDJ_ROUTES")
end

local function perpendicular(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len = dx * dx + dy * dy
    if len == 0 then return math.sqrt((px - ax) ^ 2 + (py - ay) ^ 2) end
    local t = FDJ.Clamp(((px - ax) * dx + (py - ay) * dy) / len, 0, 1)
    return math.sqrt((px - ax - t * dx) ^ 2 + (py - ay - t * dy) ^ 2)
end

function Routes.Simplify(flat, epsilon)
    local n = #flat / 2
    if n <= 2 then return flat end
    local keep = { [1] = true, [n] = true }
    local stack = { { 1, n } }
    while #stack > 0 do
        local seg = table.remove(stack)
        local first, last = seg[1], seg[2]
        local ax, ay = flat[first * 2 - 1], flat[first * 2]
        local bx, by = flat[last * 2 - 1], flat[last * 2]
        local best, index = 0, nil
        for i = first + 1, last - 1 do
            local d = perpendicular(flat[i * 2 - 1], flat[i * 2], ax, ay, bx, by)
            if d > best then best, index = d, i end
        end
        if index and best > epsilon then
            keep[index] = true
            stack[#stack + 1] = { first, index }
            stack[#stack + 1] = { index, last }
        end
    end
    local out = {}
    for i = 1, n do
        if keep[i] then
            out[#out + 1] = flat[i * 2 - 1]
            out[#out + 1] = flat[i * 2]
        end
    end
    return out
end

function Routes.AddStroke(route, m, flat, width, colorIndex)
    if #flat < 4 then return nil end
    if #route.strokes >= MAX_STROKES then
        FDJ.Print(L.ROUTE_FULL)
        return nil
    end
    flat = Routes.Simplify(flat, 0.0012)
    while #flat > MAX_STROKE_POINTS * 2 do flat = Routes.Simplify(flat, 0.003) end
    remember(route)
    local stroke = { m = m, w = width or 2, p = {} }
    if colorIndex and colorIndex ~= route.color then stroke.c = colorIndex end
    for i, v in ipairs(flat) do stroke.p[i] = FDJ.Clamp(v, 0, 1) end
    route.strokes[#route.strokes + 1] = stroke
    FDJ:Emit("FDJ_ROUTES")
    return #route.strokes
end

function Routes.AddMark(route, m, x, y, kind, colorIndex, label, size)
    if #route.marks >= MAX_MARKS then
        FDJ.Print(L.ROUTE_FULL)
        return nil
    end
    remember(route)
    local mark = { m = m, x = FDJ.Clamp(x, 0, 1), y = FDJ.Clamp(y, 0, 1), k = Routes.MarkByKey[kind] and kind or "question" }
    if colorIndex then mark.c = colorIndex end
    if label then mark.label = cleanLabel(label) end
    if size and size ~= 2 then mark.s = size end
    route.marks[#route.marks + 1] = mark
    FDJ:Emit("FDJ_ROUTES")
    return #route.marks
end

function Routes.MoveMark(route, index, x, y)
    local k = route.marks[index]
    if not k then return end
    remember(route)
    k.x, k.y = FDJ.Clamp(x, 0, 1), FDJ.Clamp(y, 0, 1)
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.RemoveMark(route, index)
    if not route.marks[index] then return end
    remember(route)
    table.remove(route.marks, index)
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.LabelMark(route, index, text)
    local k = route.marks[index]
    if not k then return end
    remember(route)
    k.label = cleanLabel(text)
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.StyleMark(route, index, label, colorIndex, size)
    local k = route.marks[index]
    if not k then return end
    remember(route)
    k.label = cleanLabel(label)
    k.c = colorIndex
    k.s = size ~= 2 and size or nil
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.MarkColor(route, mark)
    if mark.c then return Routes.Color(route, mark.c) end
    local def = Routes.MarkByKey[mark.k]
    return def and def.tint or { 1, 1, 1 }
end

function Routes.StrokeColor(route, stroke)
    return Routes.Color(route, stroke.c)
end

function Routes.Erase(route, m, x, y, radius, aspect)
    aspect = aspect or 1
    local function dist(px, py)
        return math.sqrt(((px - x) * aspect) ^ 2 + (py - y) ^ 2)
    end
    local kind, index, best = nil, nil, radius
    for i, mk in ipairs(route.marks) do
        if mk.m == m then
            local d = dist(mk.x, mk.y)
            if d < best then kind, index, best = "mark", i, d end
        end
    end
    for i, p in ipairs(route.points) do
        if p.m == m then
            local d = dist(p.x, p.y)
            if d < best then kind, index, best = "point", i, d end
        end
    end
    for i, s in ipairs(route.strokes) do
        if s.m == m then
            local pts = s.p
            for j = 1, #pts - 2, 2 do
                local d = perpendicular(x * aspect, y, pts[j] * aspect, pts[j + 1], pts[j + 2] * aspect, pts[j + 3])
                if d < best then kind, index, best = "stroke", i, d end
            end
        end
    end
    if not kind then return false end
    remember(route)
    if kind == "mark" then
        table.remove(route.marks, index)
    elseif kind == "point" then
        table.remove(route.points, index)
    else
        table.remove(route.strokes, index)
    end
    FDJ:Emit("FDJ_ROUTES")
    return true
end

function Routes.Reverse(route)
    remember(route)
    local out = {}
    for i = #route.points, 1, -1 do out[#out + 1] = route.points[i] end
    route.points = out
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.Clear(route)
    if Routes.IsEmpty(route) then return end
    remember(route)
    route.points, route.strokes, route.marks = {}, {}, {}
    FDJ:Emit("FDJ_ROUTES")
end

function Routes.Yards(route)
    if route.scope ~= "world" or not C_Map.GetMapWorldSize then return nil end
    local total = 0
    local function add(m, ax, ay, bx, by)
        local w, h = C_Map.GetMapWorldSize(m)
        if w and h and w > 0 then total = total + math.sqrt(((bx - ax) * w) ^ 2 + ((by - ay) * h) ^ 2) end
    end
    for i = 2, #route.points do
        local a, b = route.points[i - 1], route.points[i]
        if a.m == b.m then add(a.m, a.x, a.y, b.x, b.y) end
    end
    for _, s in ipairs(route.strokes) do
        for j = 1, #s.p - 2, 2 do add(s.m, s.p[j], s.p[j + 1], s.p[j + 2], s.p[j + 3]) end
    end
    return total
end

function Routes.Where(route)
    if route.scope == "chart" then
        local d = FDJ.ByKey[route.key]
        return d and FDJ.DungeonTitle(d) or L.UNKNOWN_DUNGEON
    end
    local first = route.points[1] or route.strokes[1] or route.marks[1]
    return first and FDJ.MapName(first.m) or L.WORLD_MAP
end

function Routes.Summary(route)
    local bits = {}
    if #route.points > 0 then bits[#bits + 1] = L.STOPS_N:format(#route.points) end
    if #route.strokes > 0 then bits[#bits + 1] = L.LINES_N:format(#route.strokes) end
    if #route.marks > 0 then bits[#bits + 1] = L.MARKS_N:format(#route.marks) end
    if #bits == 0 then bits[1] = L.EMPTY_ROUTE end
    return table.concat(bits, ", ")
end

local function q(v)
    return math.floor(v * 10000 + 0.5)
end

function Routes.Encode(route)
    local flat, labels = {}, {}
    for i, p in ipairs(route.points) do
        flat[#flat + 1] = p.m
        flat[#flat + 1] = q(p.x)
        flat[#flat + 1] = q(p.y)
        if p.label then labels[i] = p.label end
    end
    local strokes = {}
    for _, s in ipairs(route.strokes) do
        local pts = {}
        for i, v in ipairs(s.p) do pts[i] = q(v) end
        strokes[#strokes + 1] = { s.m, s.w or 2, s.c or 0, pts }
    end
    local marks = {}
    for _, k in ipairs(route.marks) do
        marks[#marks + 1] = { k.m, q(k.x), q(k.y), k.k, k.c or 0, k.label or "", k.s or 2 }
    end
    return FDJ.Codec.Pack("route", {
        v = 2,
        n = route.name,
        s = route.scope,
        k = route.key,
        c = route.color,
        a = route.author,
        p = flat,
        l = labels,
        d = strokes,
        x = marks,
    })
end

local function num(v)
    return type(v) == "number" and v == v
end

function Routes.Decode(text)
    local data, err = FDJ.Codec.Unpack(text, "route")
    if not data then return nil, err end
    if (data.v ~= 1 and data.v ~= 2) or (data.s ~= "chart" and data.s ~= "world") or type(data.p) ~= "table" then return nil, "format" end
    if #data.p % 3 ~= 0 or #data.p / 3 > MAX_POINTS then return nil, "format" end
    local route = normalize({
        name = type(data.n) == "string" and FDJ.Clip(data.n:gsub("[|\n\r]", ""), 60) or L.SHARED_ROUTE,
        scope = data.s,
        key = type(data.k) == "string" and data.k or nil,
        color = (num(data.c) and FDJ.RouteColors[data.c]) and data.c or 1,
        author = type(data.a) == "string" and FDJ.Clip(data.a:gsub("[|\n\r]", ""), 48) or "?",
        made = time(),
    })
    if route.scope == "chart" and not FDJ.ByKey[route.key or ""] then return nil, "dungeon" end
    local labels = type(data.l) == "table" and data.l or {}
    for i = 1, #data.p, 3 do
        local m, x, y = data.p[i], data.p[i + 1], data.p[i + 2]
        if not (num(m) and num(x) and num(y)) then return nil, "format" end
        local label = labels[(i + 2) / 3]
        route.points[#route.points + 1] = {
            m = m,
            x = FDJ.Clamp(x / 10000, 0, 1),
            y = FDJ.Clamp(y / 10000, 0, 1),
            label = type(label) == "string" and cleanLabel(label) or nil,
        }
    end
    if type(data.d) == "table" then
        for i, s in ipairs(data.d) do
            if i > MAX_STROKES then break end
            if type(s) == "table" and num(s[1]) and type(s[4]) == "table" and #s[4] >= 4 and #s[4] % 2 == 0 and #s[4] <= MAX_STROKE_POINTS * 2 then
                local pts, ok = {}, true
                for j, v in ipairs(s[4]) do
                    if not num(v) then ok = false break end
                    pts[j] = FDJ.Clamp(v / 10000, 0, 1)
                end
                if ok then
                    local stroke = { m = s[1], w = num(s[2]) and FDJ.Clamp(s[2], 1, 12) or 2, p = pts }
                    if num(s[3]) and FDJ.RouteColors[s[3]] then stroke.c = s[3] end
                    route.strokes[#route.strokes + 1] = stroke
                end
            end
        end
    end
    if type(data.x) == "table" then
        for i, k in ipairs(data.x) do
            if i > MAX_MARKS then break end
            if type(k) == "table" and num(k[1]) and num(k[2]) and num(k[3]) and type(k[4]) == "string" then
                local mark = {
                    m = k[1],
                    x = FDJ.Clamp(k[2] / 10000, 0, 1),
                    y = FDJ.Clamp(k[3] / 10000, 0, 1),
                    k = Routes.MarkByKey[k[4]] and k[4] or "question",
                }
                if num(k[5]) and FDJ.RouteColors[k[5]] then mark.c = k[5] end
                if type(k[6]) == "string" then mark.label = cleanLabel(k[6]) end
                if num(k[7]) and k[7] >= 1 and k[7] <= 4 and k[7] ~= 2 then mark.s = math.floor(k[7]) end
                route.marks[#route.marks + 1] = mark
            end
        end
    end
    return route
end

function Routes.Adopt(route)
    route.id = newID()
    FDJ.db.routes[route.id] = normalize(route)
    FDJ:Emit("FDJ_ROUTES")
    return route
end

function Routes.Import(text)
    local route, err = Routes.Decode(text)
    if not route then return nil, err end
    return Routes.Adopt(route)
end

function Routes.ErrorText(err)
    return L["IMPORT_" .. tostring(err):upper()] or L.IMPORT_FORMAT
end

function Routes.Share(route)
    if not FDJ.GroupChannel() then
        FDJ.Print(L.NOT_IN_GROUP)
        return
    end
    FDJ.Comm.Send("RT", Routes.Encode(route))
    FDJ.Print(L.ROUTE_SENT:format(FDJ.Hi(route.name)))
end

FDJ:On("FDJ_COMM", function(kind, payload, sender)
    if kind ~= "RT" then return end
    local route = Routes.Decode(payload)
    if not route then return end
    local offer = { sender = sender, route = route }
    table.insert(Routes.offers, offer)
    if #Routes.offers > 5 then table.remove(Routes.offers, 1) end
    FDJ:Emit("FDJ_ROUTE_OFFER", offer)
end)

function Routes.Following()
    local wp = FDJ.WP and FDJ.WP.Following()
    local route = wp and Routes.Get(wp.route)
    if not (route and route.points[wp.stop or 0]) then return nil end
    return route, wp.stop
end

function Routes.Follow(route, index)
    if not (route and route.points and #route.points > 0 and FDJ.WP) then return false end
    index = FDJ.Clamp(index or 1, 1, #route.points)
    local p = route.points[index]
    FDJ.WP.RemoveWhere(function(wp) return wp.route ~= nil end)
    local wp = FDJ.WP.Add(p.m, p.x, p.y, p.label, { route = route.id, stop = index, quiet = true })
    if not wp then
        FDJ.PrintAs("FojjiCore", L.WP_NO_DUNGEON)
        FDJ:Emit("FDJ_WAYPOINTS")
        return false
    end
    return true
end

function Routes.Unfollow()
    if FDJ.WP and FDJ.WP.RemoveWhere(function(wp) return wp.route ~= nil end) then
        FDJ:Emit("FDJ_WAYPOINTS")
    end
end

function Routes.Step(delta)
    local route, i = Routes.Following()
    if not route then return end
    local n = i + delta
    if n < 1 or n > #route.points then return end
    Routes.Follow(route, n)
end
