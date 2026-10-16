local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever and Addon.DJ and Addon.DJ.SpellRanks) then return end
local FDJ = Addon.DJ
local SpellRanks = FDJ.SpellRanks
local L = FDJ.L

local Talents = {}
SpellRanks.Talents = Talents

local function say(text) FDJ.PrintAs("FojjiCore", text) end
local function store()
    if not FDJ.char then return nil end
    FDJ.char.talentTemplates = FDJ.char.talentTemplates or {}
    return FDJ.char.talentTemplates
end
local function classKey()
    local _, class = UnitClass("player")
    return class or "?"
end

local function secret(v) return FDJ.Secret and FDJ.Secret(v) or false end

local function configID()
    if not (C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup) then return nil end
    local ok, group = pcall(C_SpecializationInfo.GetActiveSpecGroup)
    if not ok or not group or secret(group) then return nil end
    local ok2, id = pcall(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group)
    if ok2 and id and not secret(id) then return id end
end

function Talents.Available()
    return C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo
        and C_Traits.PurchaseRank and C_Traits.CommitConfig and configID() ~= nil or false
end

local function tabName(t)
    local markers = FojjiCore and FojjiCore.SpecMarkers and FojjiCore.SpecMarkers[classKey()]
    if markers and markers[t] and markers[t][2] then return markers[t][2] end
    if not GetTalentTabInfo then return "Tree " .. t end
    local r = { pcall(GetTalentTabInfo, t) }
    if not r[1] then return "Tree " .. t end
    if type(r[2]) == "number" then return tostring(r[3] or ("Tree " .. t)) end
    return tostring(r[2] or ("Tree " .. t))
end

local nameCache = {}
local function nodeName(cfg, node)
    local entryID = node.activeEntry and node.activeEntry.entryID or (type(node.entryIDs) == "table" and node.entryIDs[1])
    if not entryID then return nil end
    local hit = nameCache[entryID]
    if hit then return hit[1], hit[2], hit[3], entryID end
    local okE, entry = pcall(C_Traits.GetEntryInfo, cfg, entryID)
    local defID = okE and type(entry) == "table" and entry.definitionID
    if not defID or secret(defID) then return nil end
    local okD, def = pcall(C_Traits.GetDefinitionInfo, defID)
    local spellID = okD and type(def) == "table" and def.spellID
    if not spellID or secret(spellID) then return nil end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if name then nameCache[entryID] = { name, icon, spellID } end
    return name, icon, spellID, entryID
end

local function steps(values)
    local list, seen = {}, {}
    for _, v in ipairs(values) do if not seen[v] then seen[v] = true; list[#list + 1] = v end end
    table.sort(list)
    local gaps = {}
    for i = 2, #list do if list[i] - list[i - 1] > 0 then gaps[#gaps + 1] = list[i] - list[i - 1] end end
    table.sort(gaps)
    local big = {}
    local top = gaps[#gaps] or 0
    for _, g in ipairs(gaps) do if g > top * 0.15 then big[#big + 1] = g end end
    local slack = (big[math.ceil(#big / 2)] or 0) * 0.4
    local map, step, last = {}, 0, nil
    for _, v in ipairs(list) do
        if not last or v - last > slack then step = step + 1 end
        map[v], last = step, v
    end
    return map, step
end

local function readTrees()
    local cfg = configID()
    if not cfg or not Talents.Available() then return nil end
    local ok, config = pcall(C_Traits.GetConfigInfo, cfg)
    if not ok or type(config) ~= "table" or type(config.treeIDs) ~= "table" then return nil end
    local nodes = {}
    for _, treeID in ipairs(config.treeIDs) do
        local okT, ids = pcall(C_Traits.GetTreeNodes, treeID)
        for _, nodeID in ipairs(okT and type(ids) == "table" and ids or {}) do
            local okN, node = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
            if okN and type(node) == "table" and node.ID and node.ID ~= 0 and type(node.posX) == "number" and not secret(node.posX) then
                local rank = math.max(tonumber(node.ranksPurchased) or 0, tonumber(node.activeRank) or 0, tonumber(node.currentRank) or 0)
                if secret(rank) then rank = 0 end
                local name, icon, spellID, entryID = nodeName(cfg, node)
                nodes[#nodes + 1] = { id = nodeID, x = node.posX, y = node.posY or 0, rank = rank, max = node.maxRanks or 1,
                    can = node.canPurchaseRank and true or false, name = name or ("#" .. nodeID), icon = icon, treeID = treeID,
                    spell = spellID, entry = entryID,
                    edges = type(node.visibleEdges) == "table" and node.visibleEdges or nil }
            end
        end
    end
    if #nodes < 3 then return nil end
    local xs, seen = {}, {}
    for _, n in ipairs(nodes) do if not seen[n.x] then seen[n.x] = true; xs[#xs + 1] = n.x end end
    table.sort(xs)
    local cut1, cut2 = math.huge, math.huge
    if #xs >= 3 then
        local gaps = {}
        for i = 2, #xs do gaps[#gaps + 1] = { at = (xs[i - 1] + xs[i]) / 2, size = xs[i] - xs[i - 1] } end
        table.sort(gaps, function(a, b) return a.size > b.size end)
        cut1, cut2 = math.min(gaps[1].at, gaps[2].at), math.max(gaps[1].at, gaps[2].at)
    end
    local out = { cfg = cfg, trees = {}, byID = {} }
    for t = 1, 3 do out.trees[t] = { name = tabName(t), points = 0, list = {} } end
    local ys, xsOf = {}, { {}, {}, {} }
    for _, n in ipairs(nodes) do
        n.tab = n.x < cut1 and 1 or (n.x < cut2 and 2 or 3)
        ys[#ys + 1] = n.y
        table.insert(xsOf[n.tab], n.x)
    end
    local tierOf, tiers = steps(ys)
    local colOf = {}
    for t = 1, 3 do colOf[t] = steps(xsOf[t]) end
    out.tiers = tiers
    for _, n in ipairs(nodes) do
        n.tier = tierOf[n.y] or 1
        n.col = colOf[n.tab][n.x] or 1
        local tree = out.trees[n.tab]
        tree.list[n.id] = n
        tree.points = tree.points + n.rank
        out.byID[n.id] = n
    end
    out.needs = {}
    for _, n in ipairs(nodes) do
        for _, e in ipairs(n.edges or {}) do
            local to = type(e) == "table" and e.targetNode
            if to and out.byID[to] then out.needs[to] = n.id end
        end
    end
    return out
end
Talents.Read = readTrees

local function unspent(data)
    if data and C_Traits.GetTreeCurrencyInfo then
        local ok, config = pcall(C_Traits.GetConfigInfo, data.cfg)
        local treeID = ok and type(config) == "table" and type(config.treeIDs) == "table" and config.treeIDs[1]
        if treeID then
            local okC, list = pcall(C_Traits.GetTreeCurrencyInfo, data.cfg, treeID, false)
            local c = okC and type(list) == "table" and list[1]
            if c and type(c.quantity) == "number" and not secret(c.quantity) then return c.quantity end
        end
    end
    if UnitCharacterPoints then
        local n = UnitCharacterPoints("player")
        if type(n) == "number" then return n end
    end
    return nil
end

local function summary(tpl)
    local counts, total = {}, 0
    for _, p in ipairs(tpl.picks) do
        counts[p.tab] = (counts[p.tab] or 0) + p.rank
        total = total + p.rank
    end
    return ("%d/%d/%d"):format(counts[1] or 0, counts[2] or 0, counts[3] or 0), total
end
Talents.Summary = summary

function Talents.List()
    local s = store()
    if not s then return {} end
    s[classKey()] = s[classKey()] or {}
    return s[classKey()]
end

function Talents.Add(name, picks)
    local list = Talents.List()
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = L.TAL_DEFAULT_NAME:format(#list + 1) end
    local tpl = { name = name:sub(1, 40), class = classKey(), picks = picks }
    list[#list + 1] = tpl
    FDJ:Emit("FDJ_TALENTS")
    return tpl
end

function Talents.SaveCurrent(name)
    local data = readTrees()
    if not data then say(L.TAL_NO_API) return nil end
    local picks = {}
    for _, tal in pairs(data.byID) do
        if tal.rank > 0 then picks[#picks + 1] = { id = tal.id, rank = tal.rank, tab = tal.tab, tier = tal.tier } end
    end
    if #picks == 0 then say(L.TAL_NOTHING) return nil end
    table.sort(picks, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.tab ~= b.tab then return a.tab < b.tab end
        return a.id < b.id
    end)
    return Talents.Add(name, picks)
end

function Talents.Delete(tpl)
    local list = Talents.List()
    for i, t in ipairs(list) do
        if t == tpl then table.remove(list, i) break end
    end
    FDJ:Emit("FDJ_TALENTS")
end

local busy = false
local function spend(tpl, quiet)
    if busy then return end
    if InCombatLockdown() then if not quiet then say(L.TAL_COMBAT) end return end
    if not Talents.Available() then say(L.TAL_NO_API) return end
    local data = readTrees()
    if not data then say(L.TAL_NO_API) return end
    local left = unspent(data)
    if left and left <= 0 then if not quiet then say(L.TAL_NO_POINTS) end return end
    local bought, names, guard = 0, {}, 0
    while guard < 80 do
        guard = guard + 1
        if left and left <= 0 then break end
        local pick
        for _, p in ipairs(tpl.picks) do
            local tal = data.byID[p.id]
            if tal and tal.rank < p.rank and tal.can then pick = tal break end
        end
        if not pick then break end
        local ok, done = pcall(C_Traits.PurchaseRank, data.cfg, pick.id)
        if not ok or done == false then break end
        bought = bought + 1
        names[#names + 1] = ("%s %d/%d"):format(pick.name, pick.rank + 1, pick.max)
        for _, p in ipairs(tpl.picks) do
            local tal = data.byID[p.id]
            local okN, node = pcall(C_Traits.GetNodeInfo, data.cfg, p.id)
            if tal and okN and type(node) == "table" then
                local rank = math.max(tonumber(node.ranksPurchased) or 0, tonumber(node.activeRank) or 0, tonumber(node.currentRank) or 0)
                if not secret(rank) then tal.rank = rank end
                tal.can = node.canPurchaseRank and true or false
            end
        end
        left = unspent(data)
    end
    if bought == 0 then
        if not quiet then say(L.TAL_DONE:format(tpl.name)) end
        return
    end
    busy = true
    local okC, committed = pcall(C_Traits.CommitConfig, data.cfg)
    C_Timer.After(2, function() busy = false end)
    if not okC or committed == false then
        say(L.TAL_STUCK:format(names[#names]))
        return
    end
    say(L.TAL_APPLIED:format(bought, tpl.name) .. "  " .. FDJ.Paint("dim", table.concat(names, ", ")))
    FDJ:Emit("FDJ_TALENTS")
end

function Talents.Apply(tpl, quiet) spend(tpl, quiet) end

function Talents.Export(tpl)
    local parts = {}
    for _, p in ipairs(tpl.picks) do parts[#parts + 1] = ("%d.%d.%d.%d"):format(p.id, p.rank, p.tab or 1, p.tier or 1) end
    return ("FCT2~%s~%s~%s"):format(tpl.class, tpl.name:gsub("~", "-"), table.concat(parts, ","))
end

function Talents.Import(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local class, name, body = text:match("^FCT2~(%u+)~([^~]*)~([%d%.,]+)$")
    if not class then say(L.TAL_BAD_IMPORT) return nil end
    if class ~= classKey() then say(L.TAL_WRONG_CLASS:format(class:sub(1, 1) .. class:sub(2):lower())) return nil end
    local picks = {}
    for a, b, c, d in body:gmatch("(%d+)%.(%d+)%.(%d+)%.(%d+)") do
        picks[#picks + 1] = { id = tonumber(a), rank = tonumber(b), tab = tonumber(c), tier = tonumber(d) }
    end
    if #picks == 0 then say(L.TAL_BAD_IMPORT) return nil end
    return Talents.Add(name, picks)
end

function Talents.LiveRank(nodeID)
    local cfg = configID()
    if not cfg then return nil end
    local ok, node = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
    if not ok or type(node) ~= "table" then return nil end
    local r = math.max(tonumber(node.ranksPurchased) or 0, tonumber(node.activeRank) or 0, tonumber(node.currentRank) or 0)
    if secret(r) then return nil end
    return r
end
