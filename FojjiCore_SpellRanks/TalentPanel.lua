local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever and Addon.DJ and Addon.DJ.SpellRanks and Addon.DJ.SpellRanks.Talents) then return end
local FDJ = Addon.DJ
local Talents = FDJ.SpellRanks.Talents
local Kit, C, L = FDJ.Kit, FDJ.Colors, FDJ.L

local Panel = {}
Talents.Panel = Panel

local CELL, GAP = 38, 10
local COLS = 4
local PAD = 14
local win, entry
local data
local plan = { ranks = {} }
local ov
local treeArt

local unspent
local function maxPoints()
    local cap = GetMaxPlayerLevel and GetMaxPlayerLevel()
    cap = (type(cap) == "number" and cap > 0) and cap or 60
    return math.max(1, cap - 9)
end

local function totals()
    local tree, total = { 0, 0, 0 }, 0
    for id, n in pairs(plan.ranks) do
        local tal = data and data.byID[id]
        if tal and n > 0 then
            tree[tal.tab] = tree[tal.tab] + n
            total = total + n
        end
    end
    return tree, total
end

local function above(tab, tier)
    local n = 0
    for id, r in pairs(plan.ranks) do
        local tal = data.byID[id]
        if tal and tal.tab == tab and tal.tier < tier then n = n + r end
    end
    return n
end

local function prereqMet(id)
    local need = data.needs[id]
    if not need then return true end
    local req = data.byID[need]
    return (plan.ranks[need] or 0) >= (req and req.max or 1)
end

local function canAdd(id)
    local tal = data.byID[id]
    if not tal or (plan.ranks[id] or 0) >= tal.max then return false end
    local _, total = totals()
    if total >= maxPoints() then return false end
    if above(tal.tab, tal.tier) < (tal.tier - 1) * 5 then return false end
    return prereqMet(id)
end

local function canRemove(id)
    local have = plan.ranks[id] or 0
    if have <= 0 then return false end
    local tal = data.byID[id]
    if not tal then return false end
    plan.ranks[id] = have - 1
    local ok = true
    for other, n in pairs(plan.ranks) do
        if n > 0 and other ~= id then
            local o = data.byID[other]
            if o and o.tab == tal.tab and o.tier > tal.tier and above(o.tab, o.tier) < (o.tier - 1) * 5 then ok = false break end
            if data.needs[other] == id then ok = false break end
        end
    end
    plan.ranks[id] = have
    return ok
end

local function needed()
    local need = 0
    for id, n in pairs(plan.ranks) do
        local tal = data and data.byID[id]
        if tal and n > tal.rank then need = need + (n - tal.rank) end
    end
    return need, unspent()
end

local function picks()
    local out = {}
    for id, n in pairs(plan.ranks) do
        local tal = data.byID[id]
        if tal and n > 0 then out[#out + 1] = { id = id, rank = n, tab = tal.tab, tier = tal.tier } end
    end
    table.sort(out, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.tab ~= b.tab then return a.tab < b.tab end
        return a.id < b.id
    end)
    return out
end

function unspent()
    if C_Traits and C_Traits.GetTreeCurrencyInfo and data then
        local ok, config = pcall(C_Traits.GetConfigInfo, data.cfg)
        local treeID = ok and type(config) == "table" and type(config.treeIDs) == "table" and config.treeIDs[1]
        if treeID then
            local okC, list = pcall(C_Traits.GetTreeCurrencyInfo, data.cfg, treeID, false)
            local c = okC and type(list) == "table" and list[1]
            if c and type(c.quantity) == "number" then return c.quantity end
        end
    end
    local n = UnitCharacterPoints and UnitCharacterPoints("player")
    return type(n) == "number" and n or 0
end

local paint

local function load(tpl)
    plan = { ranks = {}, tpl = tpl, loaded = true }
    if tpl then
        for _, p in ipairs(tpl.picks) do if data.byID[p.id] then plan.ranks[p.id] = p.rank end end
    else
        for id, tal in pairs(data.byID) do if tal.rank > 0 then plan.ranks[id] = tal.rank end end
    end
    paint()
end

function Panel.Click(id, remove, all)
    local did = false
    repeat
        local ok = remove and canRemove(id) or (not remove and canAdd(id))
        if not ok then break end
        plan.ranks[id] = (plan.ranks[id] or 0) + (remove and -1 or 1)
        did = true
    until not all
    if did then
        plan.dirty = true
        paint()
    end
    return did
end
function Panel.Plan() return plan end

local function nodeTip(btn)
    local tal = btn.tal
    if not tal then return end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    local n = plan.ranks[tal.id] or 0
    local lines = {}
    local ok = tal.entry and GameTooltip.SetTraitEntry and pcall(GameTooltip.SetTraitEntry, GameTooltip, tal.entry, math.max(1, n))
    if ok then
        for i = 1, GameTooltip:NumLines() do
            local l, r = _G["GameTooltipTextLeft" .. i], _G["GameTooltipTextRight" .. i]
            local lt = l and l:GetText()
            if lt and lt ~= "" then
                local lr, lg, lb = l:GetTextColor()
                local rt = r and r:IsShown() and r:GetText() or nil
                local rr, rg, rb = 1, 1, 1
                if rt then rr, rg, rb = r:GetTextColor() end
                lines[#lines + 1] = { lt, lr, lg, lb, rt, rr, rg, rb }
            end
        end
    end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if #lines > 0 then
        GameTooltip:SetText(tal.name, 1, 1, 1)
        for i, ln in ipairs(lines) do
            if not (i == 1 and ln[1] == tal.name) then
                if ln[5] then GameTooltip:AddDoubleLine(ln[1], ln[5], ln[2], ln[3], ln[4], ln[6], ln[7], ln[8])
                else GameTooltip:AddLine(ln[1], ln[2], ln[3], ln[4], true) end
            end
        end
    elseif not (tal.spell and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, tal.spell)) then
        GameTooltip:SetText(tal.name, 1, 1, 1)
    end
    local have = Talents.LiveRank and Talents.LiveRank(tal.id) or tal.rank
    GameTooltip:AddLine(" ")
    if have == n then
        GameTooltip:AddLine(L.TAL_RANK:format(n, tal.max), C.accent[1], C.accent[2], C.accent[3])
    else
        GameTooltip:AddLine(L.TAL_PLANNED:format(n, tal.max), C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:AddLine(L.TAL_LEARNED:format(have, tal.max), C.muted[1], C.muted[2], C.muted[3])
    end
    local need = (tal.tier - 1) * 5
    if above(tal.tab, tal.tier) < need then
        GameTooltip:AddLine(L.TAL_NEEDS_POINTS:format(need, data.trees[tal.tab].name), C.bad[1], C.bad[2], C.bad[3])
    end
    if not prereqMet(tal.id) then
        local req = data.byID[data.needs[tal.id]]
        GameTooltip:AddLine(L.TAL_NEEDS_TALENT:format(req and req.max or 1, req and req.name or "?"), C.bad[1], C.bad[2], C.bad[3])
    end
    GameTooltip:Show()
end

local GOLD, GREY = { 1.0, 0.82, 0.18 }, { 0.30, 0.31, 0.33 }
local function newNode(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CELL, CELL)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.back = b:CreateTexture(nil, "BACKGROUND")
    b.back:SetAllPoints()
    b.back:SetColorTexture(0, 0, 0, 0.85)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 4, -4)
    b.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    b.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    b.ring = {}
    for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetPoint(spec[1], spec[1]:find("LEFT") and 2 or -2, spec[1]:find("TOP") and -2 or 2)
        t:SetPoint(spec[2], spec[2]:find("LEFT") and 2 or -2, spec[2]:find("TOP") and -2 or 2)
        if spec[3] then t:SetHeight(2) else t:SetWidth(2) end
        b.ring[i] = t
    end
    b.halo = {}
    for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetPoint(spec[1], spec[1]:find("LEFT") and -1 or 1, spec[1]:find("TOP") and 1 or -1)
        t:SetPoint(spec[2], spec[2]:find("LEFT") and -1 or 1, spec[2]:find("TOP") and 1 or -1)
        if spec[3] then t:SetHeight(2) else t:SetWidth(2) end
        t:Hide()
        b.halo[i] = t
    end
    b.pill = CreateFrame("Frame", nil, b)
    b.pill:SetFrameLevel(b:GetFrameLevel() + 3)
    b.pill:SetSize(16, 15)
    b.pill:SetPoint("BOTTOMRIGHT", 3, -3)
    local pb = b.pill:CreateTexture(nil, "BACKGROUND")
    pb:SetAllPoints()
    pb:SetColorTexture(0.03, 0.03, 0.04, 0.95)
    b.rank = b.pill:CreateFontString(nil, "OVERLAY")
    b.rank:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    b.rank:SetShadowOffset(0, 0)
    b.rank:SetPoint("CENTER", 0, 0)
    b.pill:Hide()
    b.chip = b.rank
    b:SetScript("OnClick", function(self, mouse)
        if self.tal then Panel.Click(self.tal.id, mouse == "RightButton", IsShiftKeyDown()) end
        nodeTip(self)
    end)
    b:SetScript("OnEnter", nodeTip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function line(parent)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(1, 1, 1, 1)
    return t
end

local WIN_W = 860
local function treeWidth() return math.floor((WIN_W - PAD * 2 - 20) / 3) end
local function cellPos(tal)
    local inset = math.floor((treeWidth() - (COLS * CELL + (COLS - 1) * GAP)) / 2)
    return inset + (tal.col - 1) * (CELL + GAP), -(48 + (tal.tier - 1) * (CELL + GAP))
end

local TREE_ART = {
    WARRIOR = { "WarriorArms", "WarriorFury", "WarriorProtection" },
    PALADIN = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
    HUNTER = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
    ROGUE = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
    PRIEST = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
    SHAMAN = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
    MAGE = { "MageArcane", "MageFire", "MageFrost" },
    WARLOCK = { "WarlockCurses", "WarlockSummoning", "WarlockDestruction" },
    DRUID = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
}
function treeArt(t)
    local bg
    if GetTalentTabInfo then
        local ok, a, b, c, d, e = pcall(GetTalentTabInfo, t)
        for _, v in ipairs(ok and { a, b, c, d, e } or {}) do
            if type(v) == "string" and v:match("^%u%l+%u") and not v:find(" ") then bg = v break end
        end
    end
    if not bg then
        local _, class = UnitClass("player")
        bg = TREE_ART[class or ""] and TREE_ART[class][t]
    end
    return bg and ("Interface\\TalentFrame\\" .. bg) or nil
end

local function buildTrees()
    local tiers = data.tiers or 7
    local w, h = treeWidth(), 48 + tiers * (CELL + GAP) + 6
    win.trees = win.trees or {}
    for t = 1, 3 do
        local tr = win.trees[t]
        if not tr then
            tr = CreateFrame("Frame", nil, win)
            Kit.Fill(tr, C.panel, 0.55)
            tr.artTop = tr:CreateTexture(nil, "BACKGROUND", nil, 1)
            tr.artTop:SetPoint("TOPLEFT", 1, -1)
            tr.artTop:SetPoint("BOTTOMRIGHT", -1, 1)
            tr.shade = tr:CreateTexture(nil, "BACKGROUND", nil, 2)
            tr.shade:SetAllPoints()
            tr.shade:SetColorTexture(0, 0, 0, 0.45)
            Kit.Edge(tr, C.borderDim)
            tr.head = Kit.Text(tr, "large", C.white, "LEFT")
            tr.head:SetPoint("TOPLEFT", PAD, -14)
            tr.points = Kit.Text(tr, "large", C.accent, "RIGHT")
            tr.points:SetPoint("TOPRIGHT", -PAD, -14)
            tr.rule = Kit.Line(tr, "TOP", C.borderDim)
            tr.rule:ClearAllPoints()
            tr.rule:SetPoint("TOPLEFT", PAD, -38)
            tr.rule:SetPoint("TOPRIGHT", -PAD, -38)
            tr.nodes, tr.lines = {}, {}
            win.trees[t] = tr
        end
        tr:SetSize(w, h)
        tr:ClearAllPoints()
        tr:SetPoint("TOPLEFT", PAD + (t - 1) * (w + 10), -88)
        local art = treeArt(t)
        local ok = art and tr.artTop:SetTexture(art .. "-TopLeft") ~= false
        tr.artTop:SetShown(ok and true or false)
        tr.shade:SetShown(ok and true or false)
        tr.head:SetText(data.trees[t].name)
        for _, b in ipairs(tr.nodes) do b:Hide() end
        for _, l in ipairs(tr.lines) do l:Hide() end
        local n, ln = 0, 0
        tr.byID = {}
        for id, tal in pairs(data.trees[t].list) do
            n = n + 1
            local b = tr.nodes[n] or newNode(tr)
            tr.nodes[n] = b
            b.tal = tal
            b.icon:SetTexture(tal.icon or 134400)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", cellPos(tal))
            b:Show()
            tr.byID[id] = b
        end
        for id, tal in pairs(data.trees[t].list) do
            local from = data.needs[id] and data.byID[data.needs[id]]
            if from and from.tab == t then
                local fx, fy = cellPos(from)
                local tx, ty = cellPos(tal)
                local function seg(x1, y1, x2, y2)
                    ln = ln + 1
                    local l = tr.lines[ln] or line(tr)
                    tr.lines[ln] = l
                    l:ClearAllPoints()
                    l:SetPoint("TOPLEFT", math.min(x1, x2) - 1, math.max(y1, y2) + 1)
                    l:SetSize(math.max(2, math.abs(x2 - x1) + 2), math.max(2, math.abs(y2 - y1) + 2))
                    l.to = id
                    l:Show()
                end
                local half = CELL / 2
                if from.col == tal.col then
                    seg(fx + half, fy - CELL, tx + half, ty)
                elseif from.tier == tal.tier then
                    local x1, x2 = from.col < tal.col and fx + CELL or fx, from.col < tal.col and tx or tx + CELL
                    seg(x1, fy - half, x2, ty - half)
                else
                    seg(fx + (from.col < tal.col and CELL or 0), fy - half, tx + half, fy - half)
                    seg(tx + half, fy - half, tx + half, ty)
                end
            end
        end
    end
    win:SetSize(PAD * 2 + 3 * w + 20, 88 + h + 64)
end

local SEL = { 0.40, 0.86, 0.46 }
local function paintNode(b)
    local tal = b.tal
    if not tal then return end
    local id = tal.id
    local n = plan.ranks[id] or 0
    local open = n == 0 and canAdd(id)
    local full = n >= tal.max
    b.icon:SetDesaturated(n == 0 and not open)
    b.icon:SetAlpha((n > 0 or open) and 1 or 0.4)
    local c, a, thick
    if full then c, a, thick = GOLD, 1, 1
    elseif n > 0 or open then c, a, thick = SEL, 0.85, 1
    else c, a, thick = GREY, 0.6, 1 end
    for i, t in ipairs(b.ring) do
        t:SetColorTexture(c[1], c[2], c[3], a)
        if i <= 2 then t:SetHeight(thick) else t:SetWidth(thick) end
        t:Show()
    end
    for _, t in ipairs(b.halo or {}) do
        t:SetColorTexture(c[1], c[2], c[3], 0.22)
        t:SetShown(full)
    end
    if n > 0 or open then
        b.rank:SetText(tostring(n))
        b.rank:SetTextColor(full and GOLD[1] or SEL[1], full and GOLD[2] or SEL[2], full and GOLD[3] or SEL[3])
        b.pill:SetWidth(math.max(16, (b.rank:GetStringWidth() or 8) + 7))
        b.pill:Show()
    else
        b.rank:SetText("")
        b.pill:Hide()
    end
end

local bars = {}
local function templateMenu(anchor)
    local items = {
        { text = L.TAL_MINE, checked = not plan.tpl and not plan.dirty, onClick = function() Panel.Load(nil) end },
    }
    local list = Talents.List()
    if #list > 0 then items[#items + 1] = { text = L.TAL_SAVED, title = true } end
    for _, tpl in ipairs(list) do
        local sum = Talents.Summary(tpl)
        items[#items + 1] = {
            text = tpl.name .. "  " .. FDJ.Paint("dim", sum),
            checked = plan.tpl == tpl,
            onClick = function() Panel.Load(tpl) end,
            onDelete = function()
                Kit.Confirm(L.TAL_DELETE_ASK:format(tpl.name), function()
                    if plan.tpl == tpl then plan.tpl = nil end
                    Talents.Delete(tpl)
                    paint()
                end)
            end,
        }
    end
    Kit.Menu(anchor, items, 240)
end

local function save()
    local list = picks()
    if #list == 0 then FDJ.Print(L.TAL_NOTHING) return end
    Kit.Prompt(L.TAL_PLAN_NAME, plan.tpl and plan.tpl.name or "", function(name)
        name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        for _, tpl in ipairs(Talents.List()) do
            if tpl.name == name then
                tpl.picks = list
                plan.tpl, plan.dirty = tpl, nil
                FDJ:Emit("FDJ_TALENTS")
                paint()
                return
            end
        end
        plan.tpl, plan.dirty = Talents.Add(name, list), nil
        paint()
    end)
end

local function makeBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(34)
    bar.pick = Kit.Button(bar, L.TAL_MINE, 190, 26, function(self) templateMenu(self) end)
    bar.pick:SetPoint("LEFT", 6, 0)
    bar.save = Kit.Button(bar, L.TAL_PLAN_SAVE, 64, 26, save)
    bar.save:SetPoint("LEFT", bar.pick, "RIGHT", 6, 0)
    bar.export = Kit.Button(bar, L.TAL_EXPORT, 64, 26, function()
        local list = picks()
        if #list == 0 then return end
        Kit.TextWindow(L.TAL_EXPORT, Talents.Export({ name = plan.tpl and plan.tpl.name or L.TAL_UNSAVED, class = select(2, UnitClass("player")), picks = list }), nil, L.TAL_EXPORT_HINT)
    end)
    bar.export:SetPoint("LEFT", bar.save, "RIGHT", 6, 0)
    bar.import = Kit.Button(bar, L.TAL_IMPORT, 64, 26, function()
        Kit.TextWindow(L.TAL_IMPORT, "", function(text)
            local tpl = Talents.Import(text)
            if tpl then Panel.Load(tpl) end
        end, L.TAL_IMPORT_HINT, L.TAL_IMPORT)
    end)
    bar.import:SetPoint("LEFT", bar.export, "RIGHT", 6, 0)
    bar.clear = Kit.Button(bar, L.TAL_PLAN_CLEAR, 60, 26, function()
        plan.ranks, plan.dirty, plan.tpl = {}, true, nil
        paint()
    end)
    bar.clear:SetPoint("LEFT", bar.import, "RIGHT", 6, 0)
    bar.apply = Kit.Button(bar, L.TAL_APPLY_NOW, 150, 26, function(self)
        local list = picks()
        local need, left = needed()
        if #list == 0 or need == 0 or need > left then return end
        Talents.Apply({ name = plan.tpl and plan.tpl.name or L.TAL_UNSAVED, picks = list })
    end, "primary")
    bar.apply:SetPoint("RIGHT", -6, 0)
    bar.points = Kit.Text(bar, "small", C.text, "LEFT")
    bar.points:SetPoint("LEFT", bar.clear, "RIGHT", 14, 0)
    bars[#bars + 1] = bar
    return bar
end

local treeIcons = {}
local TREE_ICONS = {
    WARRIOR = { "Ability_Rogue_Eviscerate", "Ability_Warrior_InnerRage", "Ability_Warrior_DefensiveStance" },
    PALADIN = { "Spell_Holy_HolyBolt", "Spell_Holy_DevotionAura", "Spell_Holy_AuraOfLight" },
    HUNTER = { "Ability_Hunter_BeastTaming", "Ability_Marksmanship", "Ability_Hunter_SwiftStrike" },
    ROGUE = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
    PRIEST = { "Spell_Holy_WordFortitude", "Spell_Holy_HolyBolt", "Spell_Shadow_ShadowWordPain" },
    SHAMAN = { "Spell_Nature_Lightning", "Spell_Nature_LightningShield", "Spell_Nature_MagicImmunity" },
    MAGE = { "Spell_Holy_MagicalSentry", "Spell_Fire_FireBolt02", "Spell_Frost_FrostBolt02" },
    WARLOCK = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
    DRUID = { "Spell_Nature_StarFall", "Ability_Racial_BearForm", "Spell_Nature_HealingTouch" },
    DEATHKNIGHT = { "Spell_Deathknight_BloodPresence", "Spell_Deathknight_FrostPresence", "Spell_Deathknight_UnholyPresence" },
}
local function treeIcon(t)
    if treeIcons[t] then return treeIcons[t] end
    local _, classKey = UnitClass("player")
    local set = TREE_ICONS[classKey or ""]
    if set and set[t] then
        treeIcons[t] = "Interface\\Icons\\" .. set[t]
        return treeIcons[t]
    end
    local icon
    if not icon then
        local _, class = UnitClass("player")
        local m = FojjiCore and FojjiCore.SpecMarkers and FojjiCore.SpecMarkers[class] and FojjiCore.SpecMarkers[class][t]
        local best, weight
        for spell, w in pairs(m and m[3] or {}) do if not weight or w > weight then best, weight = spell, w end end
        icon = best and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(best)
    end
    if not icon and data then
        local deep
        for _, tal in pairs(data.trees[t].list) do if not deep or tal.tier > deep.tier then deep = tal end end
        icon = deep and deep.icon
    end
    treeIcons[t] = icon or 134400
    return treeIcons[t]
end

local function paintBar(bar)
    local tree, total = totals()
    local specText = ""
    local spec = FojjiCore and FojjiCore.SpecFromPoints and FojjiCore.SpecFromPoints(select(2, UnitClass("player")), tree)
    if spec then
        local idx
        for t = 1, 3 do if tree[t] == spec.points then idx = idx or t end end
        specText = "   " .. (idx and ("|T" .. treeIcon(idx) .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. FDJ.Paint("quest", spec.name)
    end
    bar.points:SetText(FDJ.Paint("dim", L.TAL_LEVEL:format(total > 0 and total + 9 or 10)) .. specText)
    local cap = maxPoints()
    local countText = FDJ.Paint(total >= cap and "quest" or "accent", tostring(total)) .. " |cffd8d8d8/ " .. cap .. "|r"
    if win and bar == win.bar and win.count then win.count:SetText(countText) end
    if ov and bar == ov.bar then
        for t = 1, 3 do
            local tc = ov.trees and ov.trees[t]
            if tc then tc:SetText(FDJ.Paint(tree[t] > 0 and "accent" or "dim", tostring(tree[t]))) end
        end
        ov.count:SetText(countText)
    end
    bar.pick:SetLabel(plan.tpl and plan.tpl.name or (plan.dirty and L.TAL_UNSAVED or L.TAL_MINE))
    local need, left = needed()
    bar.apply.short = need > left or need == 0
    if need == 0 then bar.apply:SetLabel(L.TAL_APPLY_NOW)
    elseif need > left then bar.apply:SetLabel(L.TAL_APPLY_SHORT:format(need - left))
    else bar.apply:SetLabel(L.TAL_APPLY_N:format(need)) end
    bar.apply:SetAlpha(bar.apply.short and 0.5 or 1)
end

local outerWin, treeFrame

local function nodeButtons(tf)
    local map = {}
    if tf.EnumerateAllTalentButtons then
        local ok, f, t, k = pcall(tf.EnumerateAllTalentButtons, tf)
        if ok and type(f) == "function" then
            for a, b in f, t, k do
                local btn = type(a) == "table" and a.GetNodeID and a or b
                local okI, id = pcall(function() return btn:GetNodeID() end)
                if okI and id then map[id] = btn end
            end
        end
    end
    if not next(map) then
        local function walk(f, depth)
            if depth > 7 then return end
            for _, child in ipairs({ f:GetChildren() }) do
                local okI, id = pcall(function() return child.GetNodeID and child:GetNodeID() end)
                if okI and id then map[id] = child else walk(child, depth + 1) end
            end
        end
        walk(tf, 0)
    end
    return map
end

local function overlayOn() return ov and ov:IsShown() end

local function buildOverlay()
    ov = CreateFrame("Frame", nil, UIParent)
    ov:SetFrameStrata("FULLSCREEN_DIALOG")
    ov:SetAllPoints(outerWin)
    ov.cells = {}
    ov.bar = makeBar(ov)
    ov.bar:SetPoint("BOTTOMLEFT", outerWin, "BOTTOMLEFT", 8, 6)
    ov.bar:SetPoint("BOTTOMRIGHT", outerWin, "BOTTOMRIGHT", -8, 6)
    Kit.Fill(ov.bar, C.frame, 0.97)
    Kit.Edge(ov.bar, C.accent)
    ov.top = CreateFrame("Frame", nil, ov)
    ov.top:SetAllPoints(ov)
    ov.top:SetFrameLevel(ov:GetFrameLevel() + 30)
    ov.count = Kit.Text(ov.top, 30, C.text, "CENTER")
    ov.count:SetFont(FDJ.Font(), 30, "OUTLINE")
    ov.count:SetPoint("TOP", outerWin, "TOP", 0, -88)
    ov.count:Show()
    ov:Hide()
end

local heads = {}
local function headerText(name)
    if heads[name] ~= nil then return heads[name] or nil end
    local found
    local function look(f, depth)
        if found or depth > 6 then return end
        for _, r in ipairs({ f:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" and r:GetText() == name then found = r return end
        end
        for _, c in ipairs({ f:GetChildren() }) do look(c, depth + 1) end
    end
    pcall(look, treeFrame, 0)
    heads[name] = found or false
    return found
end

local function layoutOverlay()
    local map = nodeButtons(treeFrame)
    for _, cell in pairs(ov.cells) do cell:Hide() end
    ov.trees = ov.trees or {}
    for t = 1, 3 do
        local fs = data.trees[t] and headerText(data.trees[t].name)
        local tc = ov.trees[t]
        if fs and not tc then
            tc = Kit.Text(ov.top, 20, C.accent, "LEFT")
            tc:SetFont(FDJ.Font(), 20, "OUTLINE")
            ov.trees[t] = tc
        end
        if tc then
            tc:ClearAllPoints()
            if fs then tc:SetPoint("LEFT", fs, "RIGHT", 10, 0) end
            tc:SetShown(fs and true or false)
        end
    end
    local left, width = treeFrame:GetLeft(), treeFrame:GetWidth()
    if left and width and width > 0 then
        local rows = { {}, {}, {} }
        local place = {}
        for id, btn in pairs(map) do
            local x, y = btn:GetCenter()
            if x and y and data.byID[id] then
                local tab = math.min(3, math.max(1, math.floor((x - left) / (width / 3)) + 1))
                place[id] = { tab = tab, y = math.floor(y / 4 + 0.5) }
                rows[tab][#rows[tab] + 1] = place[id].y
            end
        end
        for t = 1, 3 do
            table.sort(rows[t], function(a, b) return a > b end)
            local tier, last, of = 0, nil, {}
            for _, y in ipairs(rows[t]) do
                if not last or last - y > 3 then tier = tier + 1 end
                of[y], last = tier, y
            end
            rows[t] = of
        end
        for id, p in pairs(place) do
            local tal = data.byID[id]
            if tal.tab ~= p.tab then
                data.trees[tal.tab].list[id] = nil
                data.trees[p.tab].list[id] = tal
                tal.tab = p.tab
            end
            tal.tier = rows[p.tab][p.y] or tal.tier
        end
    end
    local n = 0
    for id, btn in pairs(map) do
        local tal = data.byID[id]
        if tal then
            local cell = ov.cells[id] or newNode(ov)
            ov.cells[id] = cell
            cell.tal = tal
            cell:ClearAllPoints()
            cell:SetAllPoints(btn)
            local gameIcon = btn.Icon or btn.icon
            local tex = gameIcon and gameIcon.GetTexture and gameIcon:GetTexture()
            cell.icon:SetTexture(tex or tal.icon or 134400)
            cell.back:Show()
            cell:Show()
            n = n + 1
        end
    end
    return n
end

function paint()
    if not data then return end
    if overlayOn() then
        for _, cell in pairs(ov.cells) do if cell:IsShown() then paintNode(cell) end end
        paintBar(ov.bar)
    end
    if win and win:IsShown() then
        local tree = totals()
        for t = 1, 3 do
            local tr = win.trees[t]
            tr.points:SetText(tostring(tree[t]))
            for _, b in pairs(tr.byID) do paintNode(b) end
            for _, l in ipairs(tr.lines) do
                if l:IsShown() then
                    local lit = prereqMet(l.to)
                    local c = lit and C.quest or C.borderDim
                    l:SetColorTexture(c[1], c[2], c[3], lit and 0.9 or 0.7)
                end
            end
        end
        paintBar(win.bar)
    end
    if entry then
        entry.active = overlayOn() or nil
        if Kit.ButtonPaint then Kit.ButtonPaint(entry) end
    end
end

function Panel.Load(tpl) load(tpl) end

local function build()
    win = Kit.Window("FojjiCoreTalentPlanner", L.TAL_SECTION, WIN_W, 600)
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    local logo = win.head:CreateTexture(nil, "ARTWORK")
    logo:SetSize(18, 18)
    logo:SetPoint("LEFT", 12, 0)
    Kit.Logo(logo)
    win.title:ClearAllPoints()
    win.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    win.count = Kit.Text(win, 30, C.text, "CENTER")
    win.count:SetFont(FDJ.Font(), 30, "OUTLINE")
    win.count:SetPoint("TOP", 0, -46)
    win.bar = makeBar(win)
    win.bar:SetPoint("BOTTOMLEFT", PAD - 6, 10)
    win.bar:SetPoint("BOTTOMRIGHT", -(PAD - 6), 10)
    win:SetScript("OnShow", function()
        data = Talents.Read()
        if not data then win:Hide() FDJ.Print(L.TAL_NO_API) return end
        buildTrees()
        if not plan.loaded then plan.loaded = true load(nil) else paint() end
    end)
    win:SetScript("OnHide", function() GameTooltip:Hide() paint() end)
    table.insert(UISpecialFrames, "FojjiCoreTalentPlanner")
end

local function openWindow(over)
    if not win then build() end
    win:ClearAllPoints()
    if over and over:IsVisible() then win:SetPoint("CENTER", over, "CENTER", 0, 0) else win:SetPoint("CENTER") end
    win:Show()
end

function Panel.Exit()
    if ov then ov:Hide() end
    GameTooltip:Hide()
    if entry then
        entry.active = nil
        if Kit.ButtonPaint then Kit.ButtonPaint(entry) end
    end
end

local function enter()
    data = Talents.Read()
    if not data then FDJ.Print(L.TAL_NO_API) return end
    if not ov then buildOverlay() end
    if layoutOverlay() == 0 then
        openWindow(outerWin)
        return
    end
    ov:Show()
    if not plan.loaded then plan.loaded = true load(nil) else paint() end
end

local function toggle()
    if outerWin and outerWin:IsVisible() then
        if overlayOn() then Panel.Exit() else enter() end
    else
        if win and win:IsShown() then win:Hide() else openWindow(nil) end
    end
end

function Panel.On() return not (FDJ.opt and FDJ.opt.talentTemplates == false) end
function Panel.Apply()
    if not Panel.On() then Panel.Exit() end
    if Panel.Place then Panel.Place() end
end

function Panel.Toggle()
    local ok, err = pcall(toggle)
    if not ok then FDJ.Print("Talent templates: " .. tostring(err)) end
end

local function refresh()
    if not (overlayOn() or (win and win:IsShown())) then return end
    data = Talents.Read()
    if not data then return end
    if overlayOn() then layoutOverlay() end
    paint()
end
local function later()
    if overlayOn() or (win and win:IsShown()) then FDJ.Debounce("talentpanel", 0.2, refresh) end
end
FDJ:On("TRAIT_CONFIG_UPDATED", later)
FDJ:On("CHARACTER_POINTS_CHANGED", later)
FDJ:On("FDJ_TALENTS", refresh)

local function talentWindow()
    local ps = _G.PlayerSpellsFrame
    if ps then return ps, ps.TalentsFrame end
    local ct = _G.ClassTalentFrame
    if ct then return ct, ct.TalentsTab end
end

local function findByText(root, words)
    local found
    local function clean(t) return (t:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    local function look(f, depth)
        if found or depth > 8 then return end
        if f.GetRegions then
            for _, r in ipairs({ f:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "FontString" then
                    local t = r:GetText()
                    if type(t) == "string" and words[clean(t)] then found = f return end
                end
            end
        end
        for _, child in ipairs({ f:GetChildren() }) do look(child, depth + 1) end
    end
    look(root, 0)
    return found
end
function Panel.SecondaryTab(root)
    return findByText(root, { [_G.TALENT_SPEC_SECONDARY or "Secondary"] = true, Secondary = true })
end
local function primaryTab(root)
    return findByText(root, { [_G.TALENT_SPEC_PRIMARY or "Primary"] = true, Primary = true })
end

local function attach()
    local outer, tf = talentWindow()
    if not outer or entry then return end
    outerWin, treeFrame = outer, tf or outer
    entry = Kit.Button(UIParent, L.TAL_TAB, 150, 28, function() Panel.Toggle() end)
    entry:SetParent(outer)
    entry:Hide()
    entry.label:ClearAllPoints()
    entry.label:SetPoint("CENTER", 11, 0)
    local logo = entry:CreateTexture(nil, "OVERLAY")
    logo:SetSize(18, 18)
    logo:SetPoint("RIGHT", entry.label, "LEFT", -7, 0)
    logo:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\logo-mid-base")
    local arc = entry:CreateTexture(nil, "OVERLAY", nil, 1)
    arc:SetAllPoints(logo)
    arc:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\logo-mid-arc")
    local function tint() arc:SetVertexColor(C.accent[1], C.accent[2], C.accent[3]) end
    tint()
    if Kit.OnRepaint then Kit.OnRepaint(tint) end
    local hooked = {}
    local secTab, primTab, pending
    local function place()
        pending = nil
        local over = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG" }
        entry:SetFrameStrata(over[outer:GetFrameStrata()] or "DIALOG")
        entry:ClearAllPoints()
        if not (secTab and secTab:GetWidth() > 20) then secTab = Panel.SecondaryTab(outer) end
        if not primTab then primTab = primaryTab(outer) end
        local tab = secTab
        if tab and tab:GetWidth() > 20 then
            entry:SetSize(tab:GetWidth(), tab:GetHeight())
            entry:SetPoint("LEFT", tab, "RIGHT", 2, 0)
        elseif tf and tf.SearchBox then
            entry:SetSize(150, 24)
            entry:SetPoint("RIGHT", tf.SearchBox, "LEFT", -12, 0)
        else
            entry:SetSize(150, 24)
            entry:SetPoint("TOPRIGHT", outer, "TOPRIGHT", -260, -34)
        end
        local onTalents = (tf and tf ~= outer) and tf:IsVisible() or (not tf and outer:IsVisible())
        entry:SetShown(onTalents and Panel.On() and Talents.Available() and true or false)
        for _, t in ipairs({ tab, primTab }) do
            if t and not hooked[t] and t.HookScript then
                hooked[t] = true
                t:HookScript("OnMouseUp", function() Panel.Exit() end)
                if t:HasScript("OnClick") then t:HookScript("OnClick", function() Panel.Exit() end) end
            end
        end
    end
    place()
    Panel.Place = place
    local function soon() if not pending then pending = true C_Timer.After(0, place) end end
    outer:HookScript("OnShow", soon)
    if tf and tf ~= outer then
        tf:HookScript("OnShow", soon)
        tf:HookScript("OnHide", function()
            entry:Hide()
            Panel.Exit()
        end)
    end
    outer:HookScript("OnHide", function()
        entry:Hide()
        Panel.Exit()
        if win and win:IsShown() then win:Hide() end
    end)
end

FDJ:On("ADDON_LOADED", function(name)
    if name == "Blizzard_PlayerSpells" or name == "Blizzard_ClassTalentUI" then C_Timer.After(0, attach) end
end)
FDJ:On("PLAYER_LOGIN", function() C_Timer.After(1, attach) end)

local keyPending
local function talentKey()
    if keyPending or not Panel.On() or (UnitLevel("player") or 0) >= 10 then return end
    keyPending = true
    C_Timer.After(0, function()
        keyPending = nil
        if outerWin and outerWin:IsVisible() then return end
        Panel.Toggle()
    end)
end
FDJ:On("PLAYER_LOGIN", function()
    local util = _G.PlayerSpellsUtil
    if util then
        for _, fn in ipairs({ "ToggleClassTalentOrSpecFrame", "ToggleClassTalentFrame" }) do
            if type(util[fn]) == "function" then hooksecurefunc(util, fn, talentKey) end
        end
    end
    if type(_G.ToggleTalentFrame) == "function" then hooksecurefunc("ToggleTalentFrame", talentKey) end
end)

function Panel.Debug()
    local outer, tf = talentWindow()
    local function nm(f) return type(f) == "table" and f.GetName and (f:GetName() or "yes") or tostring(f) end
    FDJ.Print("window: " .. nm(outer) .. ", tree frame: " .. nm(tf) .. ", api: " .. tostring(Talents.Available()))
    local tab = outer and type(outer) == "table" and Panel.SecondaryTab(outer)
    FDJ.Print("secondary tab: " .. (tab and ((tab:GetName() or tab:GetObjectType()) .. " " .. math.floor(tab:GetWidth()) .. "x" .. math.floor(tab:GetHeight())) or "not found")
        .. ", entry: " .. tostring(entry and entry:IsShown()))
    local d = Talents.Read()
    if d then
        local n, b = 0, 0
        for _ in pairs(d.byID) do n = n + 1 end
        if type(tf) == "table" and tf.GetChildren then for _ in pairs(nodeButtons(tf)) do b = b + 1 end end
        FDJ.Print(("talents: %d, game buttons: %d, rows: %d, trees: %s / %s / %s"):format(n, b, d.tiers or 0, d.trees[1].name, d.trees[2].name, d.trees[3].name))
        if data then
            local deep, count = { 0, 0, 0 }, { 0, 0, 0 }
            for _, tal in pairs(data.byID) do
                deep[tal.tab] = math.max(deep[tal.tab], tal.tier or 0)
                count[tal.tab] = count[tal.tab] + 1
            end
            FDJ.Print(("in use: rows %d / %d / %d, talents %d / %d / %d"):format(deep[1], deep[2], deep[3], count[1], count[2], count[3]))
        end
        if ov and ov.count then
            local l, b, w, h = ov.count:GetRect()
            local ol, ob, ow, oh = outerWin:GetRect()
            FDJ.Print(("count: shown %s, text %s, at %s,%s %sx%s; window %s,%s %sx%s; overlay %s"):format(tostring(ov.count:IsVisible()), tostring(ov.count:GetText()),
                tostring(l and math.floor(l)), tostring(b and math.floor(b)), tostring(w and math.floor(w)), tostring(h and math.floor(h)),
                tostring(ol and math.floor(ol)), tostring(ob and math.floor(ob)), tostring(ow and math.floor(ow)), tostring(oh and math.floor(oh)), tostring(ov:IsShown())))
        end
    end
end
