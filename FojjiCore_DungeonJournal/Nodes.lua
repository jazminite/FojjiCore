local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ
local Guard = Addon.Guard or function(fn) return fn end

-- Credit: inspired by NodeSight's discovery (by Krelock) that the minimap's tracking dots can be read this way.
-- Credit: NodeSight's herb and ore icon list helped fill the tables below. The look and the code are our own.

local Nodes = {}
FDJ.Nodes = Nodes

local STEP = 10
local PER_FRAME = 20
local MOVING_WAIT, STILL_WAIT = 1.5, 6
local ICON = 13
local MAX_ICONS = 40
local MERGE = 15
local UNDER_ARROW = 14
local GATHER_WINDOW = 45
local RIDE_MOVE, RIDE_NEAR = 6, 2.5
local RIDE_HISTORY, RIDE_FORGET = 12, 20
local FINDERS = { [2383] = true, [2580] = true }
local ART = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
local MASK, RING, SHADOW = ART .. "node-mask", ART .. "node-ring", ART .. "node-shadow"
local FRAME = ICON + 7
local GENERIC = { herb = "Interface\\Icons\\INV_Misc_Herb_07", ore = "Interface\\Icons\\INV_Ore_Copper_01" }

local HERBS = {
    { "silverleaf", "inv_misc_herb_10" }, { "mageroyal", "inv_jewelry_talisman_03" },
    { "peacebloom", "inv_misc_flower_02" }, { "earthroot", "inv_misc_herb_07" },
    { "briarthorn", "inv_misc_root_01" }, { "swiftthistle", "inv_misc_herb_04" },
    { "bruiseweed", "inv_misc_herb_01" }, { "steelbloom", "inv_misc_flower_01" },
    { "kingsblood", "inv_misc_herb_03" }, { "liferoot", "inv_misc_root_02" },
    { "khadgar's whisker", "inv_misc_herb_08" }, { "grave moss", "inv_misc_dust_02" },
    { "fadeleaf", "inv_misc_herb_12" }, { "wintersbite", "inv_misc_flower_03" },
    { "stranglekelp", "inv_misc_herb_11" }, { "goldthorn", "inv_misc_herb_15" },
    { "firebloom", "inv_misc_herb_19" }, { "purple lotus", "inv_misc_herb_17" },
    { "arthas' tears", "inv_misc_herb_13" }, { "sungrass", "inv_misc_herb_18" },
    { "blindweed", "inv_misc_herb_14" }, { "ghost mushroom", "inv_mushroom_08" },
    { "gromsblood", "inv_misc_herb_16" }, { "dreamfoil", "inv_misc_herb_dreamfoil" },
    { "golden sansam", "inv_misc_herb_sansamroot" }, { "mountain silversage", "inv_misc_herb_mountainsilversage" },
    { "plaguebloom", "inv_misc_herb_plaguebloom" }, { "icecap", "inv_misc_herb_icecap" },
    { "black lotus", "inv_misc_herb_blacklotus" }, { "hive thistle", "inv_misc_spineleaf-_01" },
    { "demonsage", "inv_misc_herb_heartblossom" }, { "death lotus", "inv_nulllotus_void" },
    { "marefoil", "item_herbc" }, { "stranglevine", "inv_herbalism_70_nightmaredreamleaf" },
    { "frilled lichen", "inv_misc_food_109_honeylichen" }, { "rosecap", "inv_misc_herb_talandrasrose" },
}
local ORES = {
    { "copper vein", "inv_ore_copper_01" }, { "tin vein", "inv_ore_tin_01" },
    { "silver vein", "inv_stone_16" }, { "dark iron", "inv_ore_mithril_01" },
    { "iron deposit", "inv_ore_iron_01" }, { "gold vein", "inv_ore_copper_01" },
    { "mithril deposit", "inv_ore_mithril_02" }, { "truesilver deposit", "inv_ore_truesilver_01" },
    { "thorium vein", "inv_ore_thorium_02" }, { "indurium", "inv_ore_mithril_01" },
    { "incendicite", "inv_ore_thorium_01" }, { "bloodstone", "inv_ore_thorium_01" },
}

local known = {}
local function iconFor(name)
    local hit = known[name]
    if hit ~= nil then return hit or nil end
    local low = name:lower():gsub("\226\128\153", "'")
    local file
    if not low:find("[%d:/]") then
        for _, e in ipairs(HERBS) do
            if low:sub(-#e[1]) == e[1] then file = "Interface\\Icons\\" .. e[2] break end
        end
        if not file then
            for _, e in ipairs(ORES) do
                if low:find(e[1], 1, true) then file = "Interface\\Icons\\" .. e[2] break end
            end
        end
        if not file and (low:sub(-5) == " vein" or low:sub(-8) == " deposit") then file = GENERIC.ore end
    end
    known[name] = file or false
    return file
end

local function secret(v) return FDJ.Secret(v) end

local function isSquare()
    return GetMinimapShape and GetMinimapShape() == "SQUARE" or false
end

local finderNames
local function isFinderName(name)
    if not finderNames then
        finderNames = {}
        for id in pairs(FINDERS) do
            local n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
            if n then finderNames[n] = true end
        end
    end
    return name and finderNames[name] or false
end

local function finderOn()
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return true end
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and not secret(info) and not secret(info.active) and info.active then
            local id, name = info.spellID, info.name
            if id and not secret(id) and FINDERS[id] then return true end
            if name and not secret(name) and isFinderName(name) then return true end
        end
    end
    return false
end

local function playerSpot()
    local m = C_Map.GetBestMapForUnit("player")
    if not m or secret(m) then return nil end
    local pos = C_Map.GetPlayerMapPosition(m, "player")
    local x, y = FDJ.XY(pos)
    if not x then return nil end
    local w, h = C_Map.GetMapWorldSize(m)
    if not w or not h or secret(w) or w <= 0 or h <= 0 then return nil end
    return m, x, y, w, h
end

local function facing()
    local f = GetPlayerFacing and GetPlayerFacing()
    if f == nil or secret(f) then return nil end
    return f
end

local function viewRadius()
    local r = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
    if not r or secret(r) or r <= 0 then return nil end
    return r
end

local function clean(text)
    return (text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$"))
end

local layer, icons = nil, {}

local function newIcon()
    local t = layer:CreateTexture(nil, "OVERLAY")
    t:SetSize(ICON, ICON)
    t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    if layer.CreateMaskTexture then
        local m = layer:CreateMaskTexture()
        m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
    end
    local sh = layer:CreateTexture(nil, "OVERLAY", nil, -1)
    sh:SetTexture(SHADOW)
    sh:SetSize(FRAME, FRAME)
    sh:SetPoint("CENTER", t, "CENTER")
    local b = layer:CreateTexture(nil, "OVERLAY", nil, 1)
    b:SetTexture(RING)
    b:SetSize(FRAME, FRAME)
    b:SetPoint("CENTER", t, "CENTER")
    b:SetVertexColor(Addon.GetAccent())
    return { tex = t, border = b, shadow = sh }
end

function Addon.TintNodes()
    local r, g, b = Addon.GetAccent()
    for _, ic in ipairs(icons) do ic.border:SetVertexColor(r, g, b) end
end

local function hideFrom(n)
    for i = n, #icons do
        local ic = icons[i]
        if ic.shown then
            ic.shown = false
            ic.tex:Hide()
            ic.border:Hide()
            ic.shadow:Hide()
        end
    end
end

local markers = {}
local lastKey
local history, riders = {}, {}
local gatheredAt = -1e9
local lm, lx, ly, lr, lf, lh

local function follow(force)
    if not markers[1] then
        hideFrom(1)
        return
    end
    local m, px, py = playerSpot()
    local r = viewRadius()
    local rot = GetCVar("rotateMinimap") == "1"
    local f = rot and facing() or 0
    if not m or not r or (rot and not facing()) then
        hideFrom(1)
        return
    end
    local half = Minimap:GetWidth() / 2
    local sq = isSquare()
    if lastKey and not force and m == lm and px == lx and py == ly and r == lr and f == lf and half == lh then return end
    lastKey = true
    lm, lx, ly, lr, lf, lh = m, px, py, r, f, half
    local n = 0
    for _, mk in ipairs(markers) do
        if mk.map == m and n < MAX_ICONS then
            local east, north = (mk.mx - px) * mk.w, (py - mk.my) * mk.h
            local d = math.sqrt(east * east + north * north) / r * half
            local way = math.atan2(east, north) + (rot and f or 0)
            local ox, oy = d * math.sin(way), d * math.cos(way)
            local inside
            if sq then inside = math.abs(ox) <= half - 3 and math.abs(oy) <= half - 3 else inside = d <= half - 3 end
            if inside then
                n = n + 1
                local ic = icons[n] or newIcon()
                icons[n] = ic
                if ic.file ~= mk.file then
                    ic.file = mk.file
                    ic.tex:SetTexture(mk.file)
                end
                ic.tex:ClearAllPoints()
                ic.tex:SetPoint("CENTER", layer, "BOTTOMLEFT", half + ox, half + oy)
                if not ic.shown then
                    ic.shown = true
                    ic.tex:Show()
                    ic.border:Show()
                    ic.shadow:Show()
                end
            end
        end
    end
    hideFrom(n + 1)
end

local function clear()
    wipe(markers)
    lastKey = nil
    wipe(history)
    wipe(riders)
    hideFrom(1)
end

local grid, gridWidth
local scan
local gridSquare
local function buildGrid(width)
    gridSquare = isSquare()
    gridWidth, grid = width, {}
    local half = width / 2
    for gx = 0, math.floor(width / STEP) do
        for gy = 0, math.floor(width / STEP) do
            local dx, dy = gx * STEP - half, gy * STEP - half
            if gridSquare or dx * dx + dy * dy <= (half - 2) * (half - 2) then grid[#grid + 1] = gx * 1000 + gy end
        end
    end
end

local AROUND = { -1001, -1000, -999, -1, 1, 999, 1000, 1001 }

local function blobs(set)
    local out, seen = {}, {}
    for first in pairs(set) do
        if not seen[first] then
            seen[first] = true
            local stack, keys = { first }, {}
            while #stack > 0 do
                local p = table.remove(stack)
                keys[#keys + 1] = p
                for _, o in ipairs(AROUND) do
                    local q = p + o
                    if set[q] and not seen[q] then
                        seen[q] = true
                        stack[#stack + 1] = q
                    end
                end
            end
            out[#out + 1] = keys
        end
    end
    return out
end

local hitR = 15

local function cover(pts)
    local reach = (hitR + 3) ^ 2
    local cs = {}
    local left = pts
    while #left > 0 and #cs < 6 do
        local sx, sy = 0, 0
        for _, p in ipairs(left) do sx, sy = sx + p[1], sy + p[2] end
        local c = { sx / #left, sy / #left }
        local far = 0
        for _, p in ipairs(left) do far = math.max(far, (p[1] - c[1]) ^ 2 + (p[2] - c[2]) ^ 2) end
        if far > reach then c = { left[1][1], left[1][2] } end
        cs[#cs + 1] = c
        local rest = {}
        for _, p in ipairs(left) do
            local hit = false
            for _, q in ipairs(cs) do
                if (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= reach then hit = true break end
            end
            if not hit then rest[#rest + 1] = p end
        end
        left = rest
    end
    for _ = 1, 4 do
        local sum = {}
        for i = 1, #cs do sum[i] = { 0, 0, 0 } end
        for _, p in ipairs(pts) do
            local bi, bd = 1, math.huge
            for i, c in ipairs(cs) do
                local d = (p[1] - c[1]) ^ 2 + (p[2] - c[2]) ^ 2
                if d < bd then bi, bd = i, d end
            end
            local s = sum[bi]
            s[1], s[2], s[3] = s[1] + p[1], s[2] + p[2], s[3] + 1
        end
        for i, s in ipairs(sum) do
            if s[3] > 0 then cs[i][1], cs[i][2] = s[1] / s[3], s[2] / s[3] end
        end
    end
    return cs
end

local function probe(left, bottom, scale, x, y, hits, point)
    Minimap:UpdateMouseoverAtPoint((left + x) * scale, (bottom + y) * scale)
    local data = C_TooltipInfo.GetMinimapMouseover()
    if not data or secret(data) or not data.lines or secret(data.lines) then return end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not secret(text) then
            for row in text:gmatch("[^\n]+") do
                local name = clean(row)
                if name ~= "" and iconFor(name) then
                    local set = hits[name]
                    if not set then
                        set = {}
                        hits[name] = set
                    end
                    set[point] = true
                end
            end
        end
    end
end

local scratch = {}
local function under(left, bottom, scale, name, x, y)
    wipe(scratch)
    probe(left, bottom, scale, x, y, scratch, 1)
    return scratch[name] ~= nil
end

local function edge(left, bottom, scale, name, x, y, dx, dy, reach)
    local inside, outside = 0, nil
    for d = 3, reach, 3 do
        if under(left, bottom, scale, name, x + dx * d, y + dy * d) then inside = d else outside = d break end
    end
    if not outside then return nil end
    for _ = 1, 3 do
        local mid = (inside + outside) / 2
        if under(left, bottom, scale, name, x + dx * mid, y + dy * mid) then inside = mid else outside = mid end
    end
    return (inside + outside) / 2
end

local REACH, MAX_REFINE = 27, 1
local function refine(ctx, name, x, y)
    local l, b, sc = ctx[1], ctx[2], ctx[3]
    if not under(l, b, sc, name, x, y) then return x, y, false end
    local west = edge(l, b, sc, name, x, y, -1, 0, REACH)
    local east = edge(l, b, sc, name, x, y, 1, 0, REACH)
    if not (west and east) then return x, y, false end
    x = x + (east - west) / 2
    local south = edge(l, b, sc, name, x, y, 0, -1, REACH)
    local north = edge(l, b, sc, name, x, y, 0, 1, REACH)
    if not (south and north) then return x, y, false end
    local wide, tall = (west + east) / 2, (south + north) / 2
    if math.abs(wide - tall) > math.max(wide, tall) * 0.25 or math.max(wide, tall) > hitR * 1.5 then return x, y, false end
    hitR = hitR * 0.8 + (wide + tall) / 2 * 0.2
    return x, y + (north - south) / 2, true
end

local function finish(hits, width)
    local m, px, py, w, h = playerSpot()
    local r = viewRadius()
    local rot = GetCVar("rotateMinimap") == "1"
    local f = facing()
    if not m or not r or (rot and not f) then
        clear()
        return
    end
    local half = width / 2
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    local ctx = left and bottom and { left, bottom, Minimap:GetEffectiveScale() }
    local refines = 0
    local merge = math.max(MERGE, STEP * 1.5 / half * r)
    local function place(name, x, y)
        local dx, dy = x - half, y - half
        local yards = math.sqrt(dx * dx + dy * dy) / half * r
        local world = math.atan2(dx, dy) - (rot and f or 0)
        return px + yards * math.sin(world) / w, py - yards * math.cos(world) / h
    end
    local found = {}
    local function toPx(mk)
        local east, north = (mk.mx - px) * w, (py - mk.my) * h
        local d = math.sqrt(east * east + north * north) / r * half
        local way = math.atan2(east, north) + (rot and f or 0)
        return half + d * math.sin(way), half + d * math.cos(way)
    end
    local function oldNear(name, mx, my)
        local best, bd = nil, merge * merge
        for _, o in ipairs(markers) do
            if o.name == name and o.map == m and not o.used then
                local gx, gy = (o.mx - mx) * w, (o.my - my) * h
                local d = gx * gx + gy * gy
                if d < bd then best, bd = o, d end
            end
        end
        return best
    end
    local function one(name, file, x, y)
        local mx, my = place(name, x, y)
        local mk = { name = name, file = file, map = m, w = w, h = h, mx = mx, my = my }
        local old = oldNear(name, mx, my)
        if old then old.used = true end
        if old and old.exact then
            mk.mx, mk.my, mk.exact = old.mx, old.my, true
        elseif ctx and refines < MAX_REFINE then
            refines = refines + 1
            local rx, ry, exact = refine(ctx, name, x, y)
            if exact then
                mk.mx, mk.my = place(name, rx, ry)
                mk.exact = true
            elseif old then
                mk.mx, mk.my = old.mx, old.my
            end
        elseif old then
            mk.mx, mk.my = old.mx, old.my
        end
        found[#found + 1] = mk
    end
    local function reuse(name, file, pts)
        local kept = {}
        for _, o in ipairs(markers) do
            if o.name == name and o.map == m and o.exact and not o.used then
                local ox, oy = toPx(o)
                for _, p in ipairs(pts) do
                    if (p[1] - ox) ^ 2 + (p[2] - oy) ^ 2 <= (hitR + 2) ^ 2 then
                        kept[#kept + 1] = { o, ox, oy }
                        break
                    end
                end
            end
        end
        if #kept > 0 then
            local all = true
            for _, p in ipairs(pts) do
                local hit = false
                for _, k in ipairs(kept) do
                    if (p[1] - k[2]) ^ 2 + (p[2] - k[3]) ^ 2 <= (hitR + 3) ^ 2 then hit = true break end
                end
                if not hit then all = false break end
            end
            if all then
                for _, k in ipairs(kept) do
                    k[1].used = true
                    found[#found + 1] = { name = name, file = file, map = m, w = w, h = h, mx = k[1].mx, my = k[1].my, exact = true }
                end
                return true
            end
        end
        return false
    end
    local handle
    local function several(name, file, pts, p1, p2, depth)
        local cx, cy = 0, 0
        for _, p in ipairs(pts) do cx, cy = cx + p[1], cy + p[2] end
        cx, cy = cx / #pts, cy / #pts
        local sxx, syy, sxy = 0, 0, 0
        for _, p in ipairs(pts) do
            local dx, dy = p[1] - cx, p[2] - cy
            sxx, syy, sxy = sxx + dx * dx, syy + dy * dy, sxy + dx * dy
        end
        local ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
        local ux, uy = math.cos(ang), math.sin(ang)
        local vx, vy = -uy, ux
        local L, B, S = ctx and ctx[1], ctx and ctx[2], ctx and ctx[3]
        local function centreAcross(x, y)
            local a1 = edge(L, B, S, name, x, y, vx, vy, 2 * hitR)
            local a2 = edge(L, B, S, name, x, y, -vx, -vy, 2 * hitR)
            if not (a1 and a2) then return nil end
            local mid = (a1 - a2) / 2
            return x + vx * mid, y + vy * mid
        end
        if ctx and refines < MAX_REFINE and under(L, B, S, name, cx, cy) then
            refines = refines + 1
            local ax, ay = centreAcross(cx, cy)
            local fwd = ax and edge(L, B, S, name, ax, ay, ux, uy, 4 * hitR)
            local back = ax and edge(L, B, S, name, ax, ay, -ux, -uy, 4 * hitR)
            if fwd and back then
                local list = {}
                if fwd + back <= 2 * hitR * 1.15 then
                    local mid = (fwd - back) / 2
                    list[1] = { ax + ux * mid, ay + uy * mid }
                elseif fwd + back <= 4 * hitR then
                    list[1] = { ax + ux * (fwd - hitR), ay + uy * (fwd - hitR) }
                    list[2] = { ax - ux * (back - hitR), ay - uy * (back - hitR) }
                end
                for _, c in ipairs(list) do
                    local x, y = centreAcross(c[1], c[2])
                    if x then c[1], c[2] = x, y end
                end
                for _, p in ipairs(pts) do
                    local hit = false
                    for _, c in ipairs(list) do
                        if (p[1] - c[1]) ^ 2 + (p[2] - c[2]) ^ 2 <= (hitR + 3) ^ 2 then hit = true break end
                    end
                    if not hit then list = {} break end
                end
                if list[1] then
                    for _, c in ipairs(list) do
                        local mx, my = place(name, c[1], c[2])
                        local old = oldNear(name, mx, my)
                        if old then old.used = true end
                        found[#found + 1] = { name = name, file = file, map = m, w = w, h = h, mx = mx, my = my, exact = true }
                    end
                    return
                end
            end
        end
        if (depth or 0) < 2 and #pts >= 2 then
            local h1, h2 = {}, {}
            for _, p in ipairs(pts) do
                if (p[1] - cx) * ux + (p[2] - cy) * uy < 0 then h1[#h1 + 1] = p else h2[#h2 + 1] = p end
            end
            if #h1 > 0 and #h2 > 0 then
                handle(name, file, h1, (depth or 0) + 1)
                handle(name, file, h2, (depth or 0) + 1)
                return
            end
        end
        for _, c in ipairs(cover(pts)) do
            local mx, my = place(name, c[1], c[2])
            local old = oldNear(name, mx, my)
            if old then
                old.used = true
                mx, my = old.mx, old.my
            end
            found[#found + 1] = { name = name, file = file, map = m, w = w, h = h, mx = mx, my = my }
        end
    end
    function handle(name, file, pts, depth)
        local p1, p2, span = pts[1], pts[1], 0
        for i = 1, #pts do
            for j = i + 1, #pts do
                local d = (pts[i][1] - pts[j][1]) ^ 2 + (pts[i][2] - pts[j][2]) ^ 2
                if d > span then p1, p2, span = pts[i], pts[j], d end
            end
        end
        span = math.sqrt(span)
        if reuse(name, file, pts) then return end
        if span <= 2 * hitR + 4 then
            local sx, sy = 0, 0
            for _, p in ipairs(pts) do sx, sy = sx + p[1], sy + p[2] end
            one(name, file, sx / #pts, sy / #pts)
        else
            several(name, file, pts, p1, p2, depth)
        end
    end
    if ctx then Minimap:SetUsingSoftCursor(true) end
    pcall(function()
        for name, set in pairs(hits) do
            local file = iconFor(name)
            if file then
                for _, keys in ipairs(blobs(set)) do
                    local pts = {}
                    for i, p in ipairs(keys) do pts[i] = { math.floor(p / 1000) * STEP, (p % 1000) * STEP } end
                    handle(name, file, pts)
                end
            end
        end
    end)
    if ctx then Minimap:SetUsingSoftCursor(false) end
    local function movedSince(o)
        if o.map ~= m then return 0 end
        local ex, ny = (px - o.px) * w, (py - o.py) * h
        return math.sqrt(ex * ex + ny * ny) / r * half
    end
    local back
    for i = #history, 1, -1 do
        if movedSince(history[i]) >= RIDE_MOVE then back = history[i] break end
    end
    local unique = {}
    for _, mk in ipairs(found) do
        local x, y = toPx(mk)
        local twin
        for _, u in ipairs(unique) do
            if u.mk.name == mk.name and (u.x - x) ^ 2 + (u.y - y) ^ 2 < (hitR * 0.5) ^ 2 then twin = u break end
        end
        if not twin then
            unique[#unique + 1] = { mk = mk, x = x, y = y }
        elseif mk.exact and not twin.mk.exact then
            twin.mk, twin.x, twin.y = mk, x, y
        end
    end
    found = {}
    for i, u in ipairs(unique) do found[i] = u.mk end

    local now = GetTime()
    local justGathered = now - gatheredAt < GATHER_WINDOW
    local toYardsPx = half / r
    local function stayed(mk)
        if not back then return false end
        for _, o in ipairs(back.seen) do
            if o[1] == mk.name and o[6] and ((o[6] - mk.mx) * w * toYardsPx) ^ 2 + ((o[7] - mk.my) * h * toYardsPx) ^ 2 < RIDE_NEAR * RIDE_NEAR then
                return true
            end
        end
        return false
    end
    local kept, seen = {}, {}
    for _, mk in ipairs(found) do
        local x, y = toPx(mk)
        local dx, dy = x - half, y - half
        local ex, ny = (mk.mx - px) * w / r * half, (py - mk.my) * h / r * half
        seen[#seen + 1] = { mk.name, dx, dy, ex, ny, mk.mx, mk.my }
        local still = stayed(mk)
        local riding = not still and justGathered and dx * dx + dy * dy < UNDER_ARROW * UNDER_ARROW
        if not riding and not still and back then
            for _, o in ipairs(back.seen) do
                if o[1] == mk.name and ((o[2] - dx) ^ 2 + (o[3] - dy) ^ 2 < RIDE_NEAR * RIDE_NEAR
                    or (o[4] - ex) ^ 2 + (o[5] - ny) ^ 2 < RIDE_NEAR * RIDE_NEAR) then
                    riding = true
                    break
                end
            end
        end
        if not riding and not still then
            for _, rd in ipairs(riders) do
                if rd.name == mk.name and now - rd.at < RIDE_FORGET and math.abs(rd.dx - dx) < RIDE_NEAR * 2 and math.abs(rd.dy - dy) < RIDE_NEAR * 2 then
                    riding = true
                    break
                end
            end
        end
        if riding then
            local fresh = true
            for _, rd in ipairs(riders) do
                if rd.name == mk.name and math.abs(rd.dx - dx) < RIDE_NEAR * 2 and math.abs(rd.dy - dy) < RIDE_NEAR * 2 then
                    rd.at, rd.dx, rd.dy, fresh = now, dx, dy, false
                end
            end
            if fresh and dx * dx + dy * dy >= UNDER_ARROW * UNDER_ARROW then
                riders[#riders + 1] = { name = mk.name, dx = dx, dy = dy, at = now }
            end
        else
            kept[#kept + 1] = mk
        end
    end
    for i = #riders, 1, -1 do
        if now - riders[i].at >= RIDE_FORGET then table.remove(riders, i) end
    end
    history[#history + 1] = { map = m, px = px, py = py, seen = seen }
    if #history > RIDE_HISTORY then table.remove(history, 1) end
    markers = kept
    follow(true)
end

local function scanSome()
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    if not (left and bottom) or InCombatLockdown() or not Minimap:IsVisible() then
        scan = nil
        return
    end
    if Minimap:IsMouseOver() then return end
    local scale = Minimap:GetEffectiveScale()
    Minimap:SetUsingSoftCursor(true)
    local ok = pcall(function()
        for i = scan.next, math.min(scan.next + PER_FRAME - 1, #grid) do
            local p = grid[i]
            probe(left, bottom, scale, math.floor(p / 1000) * STEP, (p % 1000) * STEP, scan.hits, p)
        end
    end)
    Minimap:SetUsingSoftCursor(false)
    if not ok then
        scan = nil
        return
    end
    scan.next = scan.next + PER_FRAME
    if scan.next > #grid then
        local s = scan
        scan = nil
        finish(s.hits, s.width)
    end
end

local driver
local wait, tick, spot = 0, 0, nil

local function supported()
    return Minimap and Minimap.UpdateMouseoverAtPoint and Minimap.SetUsingSoftCursor
        and C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover
end

local function openWorld()
    local inside, kind = IsInInstance()
    return not inside and (kind == nil or kind == "none")
end

local function wanted()
    return FDJ:Option("minimapNodes") and supported() and openWorld() and not InCombatLockdown() and finderOn()
end

local function onUpdate(_, dt)
    tick = tick + dt
    if tick >= 0.05 then
        tick = 0
        follow()
    end
    if scan then
        scanSome()
        return
    end
    wait = wait - dt
    if wait > 0 then return end
    local m, x, y = playerSpot()
    local still = m and spot and spot[1] == m and math.abs(spot[2] - x) < 0.0005 and math.abs(spot[3] - y) < 0.0005
    wait = still and STILL_WAIT or MOVING_WAIT
    spot = m and { m, x, y } or nil
    local width = Minimap:GetWidth()
    if not width or width <= 0 then return end
    if width ~= gridWidth or isSquare() ~= gridSquare then buildGrid(width) end
    scan = { next = 1, hits = {}, width = width }
end

function Nodes.Update()
    if not layer and not wanted() then return end
    if not layer then
        layer = CreateFrame("Frame", nil, Minimap)
        layer:SetAllPoints(Minimap)
        layer:SetFrameLevel(Minimap:GetFrameLevel() + 4)
        driver = CreateFrame("Frame")
    end
    if wanted() then
        wait = 0
        driver:SetScript("OnUpdate", Guard(onUpdate))
    else
        driver:SetScript("OnUpdate", nil)
        scan = nil
        if not FDJ:Option("minimapNodes") or not openWorld() or not finderOn() then clear() end
        if InCombatLockdown() then hideFrom(1) end
    end
end

local function soon() FDJ.Debounce("minimapnodes", 0.2, Nodes.Update) end
FDJ:On("PLAYER_ENTERING_WORLD", function()
    clear()
    soon()
end)
FDJ:On("PLAYER_REGEN_DISABLED", function()
    if driver then driver:SetScript("OnUpdate", nil) end
    scan = nil
    hideFrom(1)
end)
FDJ:On("PLAYER_REGEN_ENABLED", function()
    lastKey = nil
    soon()
end)
FDJ:On("LOOT_OPENED", function()
    if not GetLootSourceInfo then
        gatheredAt = GetTime()
        return
    end
    for slot = 1, GetNumLootItems() do
        local ok, guid = pcall(GetLootSourceInfo, slot)
        if ok and type(guid) == "string" and not secret(guid) and guid:find("^GameObject") then
            gatheredAt = GetTime()
            return
        end
    end
end)
FDJ:On("MINIMAP_UPDATE_TRACKING", soon)
FDJ:On("ZONE_CHANGED_NEW_AREA", soon)
FDJ:On("FDJ_OPTION", function(key)
    if key == "minimapNodes" then soon() end
end)
