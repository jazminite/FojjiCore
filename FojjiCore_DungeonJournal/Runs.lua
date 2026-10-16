local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Runs = {}
FDJ.Runs = Runs

local L = FDJ.L
local STALE = 3 * 3600
local lastAlert = {}

local function run()
    return FDJ.char.run
end

function Runs.Killed(boss)
    local kills = run().kills[boss.dungeon.key]
    return kills and kills[boss.index] ~= nil
end

function Runs.Count(d)
    local kills, n = run().kills[d.key], 0
    if kills then
        for _ in pairs(kills) do n = n + 1 end
    end
    return n
end

function Runs.Reset(silent)
    local r = run()
    r.kills = {}
    r.last = 0
    FDJ:Emit("FDJ_KILLS")
    if not silent then FDJ.Print(L.RUN_RESET) end
end

function Runs.Mark(boss)
    if not boss or Runs.Killed(boss) then return end
    local r = run()
    local key = boss.dungeon.key
    r.kills[key] = r.kills[key] or {}
    r.kills[key][boss.index] = time()
    r.last = time()
    FDJ.char.lastDungeon = key
    FDJ:Emit("FDJ_KILLS")
end

local function bossByName(name)
    if type(name) ~= "string" or FDJ.Secret(name) then return nil end
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    for _, d in ipairs(FDJ.ByInstance[instanceID] or {}) do
        for _, boss in ipairs(d.bosses) do
            if boss.n == name then return boss end
        end
    end
    return nil
end

FDJ:On("ENCOUNTER_END", function(_, name, _, _, success)
    if success == 1 or success == true then Runs.Mark(bossByName(name)) end
end)

FDJ:On("BOSS_KILL", function(_, name)
    Runs.Mark(bossByName(name))
end)

FDJ:On("PLAYER_ENTERING_WORLD", function()
    local _, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return end
    local r = run()
    local stale = r.last > 0 and time() - r.last > STALE
    local here = FDJ.CurrentDungeon()
    local cleared = here and #here.bosses > 0 and Runs.Count(here) >= #here.bosses
    if r.instance ~= instanceID or stale or cleared then
        r.instance = instanceID
        if next(r.kills) then Runs.Reset(true) end
    end
    if here then
        FDJ:Emit("FDJ_ENTERED", here)
        local today = date("%Y-%m-%d")
        if FDJ.db and FDJ.db.enterHint ~= today then
            FDJ.db.enterHint = today
            C_Timer.After(3, function()
                FDJ.Print(("Type %s to open the Dungeon Journal for %s."):format(FDJ.Paint("white", "/fc dj"), FDJ.Hi(FDJ.DungeonTitle(here))))
            end)
        end
    end
end)

local resetPattern
FDJ:On("CHAT_MSG_SYSTEM", function(text)
    if type(text) ~= "string" or FDJ.Secret(text) or type(INSTANCE_RESET_SUCCESS) ~= "string" then return end
    resetPattern = resetPattern or ("^" .. INSTANCE_RESET_SUCCESS:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$")
    if text:match(resetPattern) then
        Runs.Reset(true)
        if FDJ.GroupChannel() then FDJ.Comm.Send("IR", "") end
    end
end)

FDJ:On("FDJ_COMM", function(kind)
    if kind == "IR" and next(run().kills) then Runs.Reset(true) end
end)

function FDJ.WishHint(itemID)
    local gear = FDJ.Gear and FDJ.Gear.Accepts(itemID) and not FDJ.char.wishes[itemID]
    if gear then return Runs.IsWished(itemID) and L.PLAN_HINT_REMOVE or L.PLAN_HINT_ADD end
    return Runs.IsWished(itemID) and L.WISH_HINT_REMOVE or L.WISH_HINT_ADD
end

function Runs.PaintMark(tex, itemID)
    local plan = FDJ.Gear and FDJ.Gear.HasItem(itemID)
    if plan then
        tex:SetTexture(FDJ.Glyph("fc:mark-plan"))
        tex:SetVertexColor(FDJ.Kit.RGB(FDJ.Colors.accent))
    else
        tex:SetTexture(FDJ.Glyph("mark-star"))
        tex:SetVertexColor(FDJ.Kit.RGB(FDJ.Colors.amber))
    end
    tex:SetShown(plan or FDJ.char.wishes[itemID] ~= nil)
end

function Runs.IsWished(itemID)
    if FDJ.char.wishes[itemID] ~= nil then return true end
    return FDJ.Gear and FDJ.Gear.HasItem(itemID) or false
end

local function owns(itemID)
    if C_Item.GetItemCount and C_Item.GetItemCount(itemID, true) > 0 then return true end
    if GetItemCount and GetItemCount(itemID, true) > 0 then return true end
    if C_Item.IsEquippedItem and C_Item.IsEquippedItem(itemID) then return true end
    if IsEquippedItem and IsEquippedItem(itemID) then return true end
    return false
end

Runs.Owns = owns

function Runs.ToggleWish(itemID, charKey)
    local mine = not charKey or charKey == FDJ.charKey
    if FDJ.Gear and FDJ.Gear.Accepts(itemID) and mine and not FDJ.char.wishes[itemID] then
        FDJ.Gear.ToggleItem(itemID)
        return
    end
    local owner = charKey and FDJ.db.chars[charKey] or FDJ.char
    owner.wishes = owner.wishes or {}
    if owner.wishes[itemID] then
        owner.wishes[itemID] = nil
    else
        local ok, have = pcall(owns, itemID)
        if owner == FDJ.char and ok and have then
            FDJ.Print(L.WISH_OWNED)
            return
        end
        owner.wishes[itemID] = time()
    end
    FDJ:Emit("FDJ_WISHES")
end

function Runs.WishCharacters()
    local list = {}
    for key, data in pairs(FDJ.db.chars) do
        if type(data) == "table" and type(data.wishes) == "table" and next(data.wishes) then
            list[#list + 1] = {
                key = key, wishes = data.wishes, class = data.class,
                name = data.name or key:match("^([^%-]+)") or key, me = key == FDJ.charKey,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.me ~= b.me then return a.me end
        return a.name < b.name
    end)
    return list
end

function Runs.ClearOwned()
    local wishes = FDJ.char and FDJ.char.wishes
    if not wishes then return end
    local removed = false
    for itemID in pairs(wishes) do
        local ok, have = pcall(owns, itemID)
        if ok and have then
            wishes[itemID] = nil
            removed = true
            local _, link = C_Item.GetItemInfo(itemID)
            FDJ.Print(L.WISH_GOT:format(link or ("item:" .. itemID)))
        end
    end
    if removed then FDJ:Emit("FDJ_WISHES") end
end

FDJ:On("BAG_UPDATE_DELAYED", function() FDJ.Debounce("wishowned", 1, Runs.ClearOwned) end)
FDJ:On("PLAYER_EQUIPMENT_CHANGED", function() FDJ.Debounce("wishowned", 1, Runs.ClearOwned) end)

function Runs.WishSummary()
    local items, dungeons = 0, 0
    for _, d in ipairs(FDJ.Dungeons) do
        local n = Runs.WishCount(d)
        if n > 0 then
            items = items + n
            dungeons = dungeons + 1
        end
    end
    return items, dungeons
end

function Runs.WishCount(d)
    local n = 0
    for _, boss in ipairs(d.bosses) do
        for _, item in ipairs(boss.loot) do
            if Runs.IsWished(item) then n = n + 1 end
        end
    end
    return n
end

local function alert(link, itemID)
    local bis = FDJ.Gear and FDJ.Gear.HasItem(itemID)
    if bis and not FDJ.char.wishes[itemID] then
        if not FDJ.Gear.AlertFor(itemID) then return end
    elseif not FDJ:Option("alerts") then
        return
    end
    if lastAlert[itemID] and GetTime() - lastAlert[itemID] < 30 then return end
    lastAlert[itemID] = GetTime()
    local text = (FDJ.Gear and FDJ.Gear.HasItem(itemID) and L.PLAN_DROPPED or L.WISH_DROPPED):format(link)
    FDJ.Print(text)
    local planOpts = bis and FDJ.Gear.Options and FDJ.Gear.Options()
    if planOpts then
        if planOpts.alertBig and RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, text, { r = 0.31, g = 0.82, b = 0.78 })
        end
        if FDJ.Gear.PlayAlertSound then FDJ.Gear.PlayAlertSound(planOpts.alertSound or "ping") end
        return
    end
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, { r = 0.31, g = 0.82, b = 0.78 })
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
end

FDJ:On("LOOT_OPENED", function()
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = FDJ.ItemFromLink(link)
        if itemID and Runs.IsWished(itemID) then alert(link, itemID) end
        if GetLootSourceInfo then
            local sources = { pcall(GetLootSourceInfo, slot) }
            if sources[1] then
                for i = 2, #sources, 2 do
                    local npc = FDJ.NpcFromGUID(sources[i])
                    if npc and FDJ.NpcBoss[npc] then Runs.Mark(FDJ.NpcBoss[npc]) end
                end
            end
        end
    end
end)

FDJ:On("START_LOOT_ROLL", function(rollID)
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
    local itemID = FDJ.ItemFromLink(link)
    if itemID and Runs.IsWished(itemID) then alert(link, itemID) end
end)
