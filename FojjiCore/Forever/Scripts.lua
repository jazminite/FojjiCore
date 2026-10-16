local _, Addon = ...
local ForeverAuras = Addon.AuraAPI
local ForeverAurasSaved = Addon.AuraSaved
local SharedMedia = LibStub("LibSharedMedia-3.0")

FojjiCore = FojjiCore or {}
FojjiCore_Version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("FojjiCore", "Version")) or (GetAddOnMetadata and GetAddOnMetadata("FojjiCore", "Version")) or "3.5.4"

FojjiCore.fontPatchGroups = {

    "Fojji - Class Pack Anchors [Forever]",
    "Fojji - Class Pack Anchors [Forever] 1440p",
    "Fojji - Class Pack Anchors [Forever] 1080p",
    "Fojji - Druid UI [Forever]",
    "Fojji - Hunter UI [Forever]",
    "Fojji - Mage UI [Forever]",
    "Fojji - Paladin UI [Forever]",
    "Fojji - Priest UI [Forever]",
    "Fojji - Rogue UI [Forever]",
    "Fojji - Shaman UI [Forever]",
    "Fojji - Warlock UI [Forever]",
    "Fojji - Warrior UI [Forever]",

    "Fojji - Item & Trinket Tracker",
    "Fojji - Pull & Break Timers",
    "Fojji - Buff Tracker [Forever]",
    "Fojji - Debuff Tracker [Forever]",
    "Fojji - Campfire Guild Helper [Forever]",
    "Fojji - Cooldown Pulse [Forever]",
    "Fojji - Equipment Manager [Forever]",
    "Fojji - Item Manager [Forever]",
    "Fojji - Consume Bar [Forever]",
    "Fojji - Consumables [Forever]",
    "Fojji - Consume CDs [Forever]",
    "Fojji - Experience Bar [Forever]",
    "Fojji - Friendly XP Tracker [Forever]",
    "Fojji - Incoming Combat Text [Forever]",
    "Fojji - Mage Vending Machine [Forever]",
    "Fojji - Object Highlight [Forever]",
    "Fojji - Sunder Armor on Nameplates",
    "Fojji - Sunder Armor on Nameplates [Forever]",
    "Fojji - Target Name on Nameplate",
    "Fojji - Target Name on Nameplate [Forever]",
    "Fojji - Threat on Nameplates [Forever]",
    "Fojji - Scrolling Combat Text [Forever]",
    "Fojji - Consumable Reminders [Forever]",
    "Fojji - Town Consumes Helper [Forever]",
    "Fojji - Raid Watch [Forever]",
    "Fojji - Cast Times [Forever]",
    "Fojji - Character Stats [Forever]",
    "NCT - Multi-Column Template",
    "Numen - Cooldown Tracker [Forever]",

    "Fojji - Hyjal Raiding Pack [Forever]",
    "Fojji - The Venomous Abyss [Forever]",
    "Fojji - Raid Demo [Forever]",
    "Fojji - Raid Pack Anchors [Forever]",
    "Fojji - [Forever] Hyjal Summit",
    "Fojji - [Forever] Hyjal",

    "Fojji - Druid UI [TBC]",
    "Fojji - Hunter UI [TBC]",
    "Fojji - Mage UI [TBC]",
    "Fojji - Paladin UI [TBC]",
    "Fojji - Priest UI [TBC]",
    "Fojji - Rogue UI [TBC]",
    "Fojji - Shaman UI [TBC]",
    "Fojji - Warlock UI [TBC]",
    "Fojji - Warrior UI [TBC]",

    "Fojji - [T4] Raiding Pack [TBC]",
    "Fojji - [T5] Raid Frames",
    "Fojji - [T5] Raiding Pack",
    "Fojji - [T6] Black Temple [Part 1]",
    "Fojji - [T6] Black Temple [Part 2]",
    "Fojji - [T6] Mount Hyjal",
    "Fojji - [Forever] Mount Hyjal",
    "Fojji - [Midnight S2] The Venomous Abyss",
    "Fojji - Raid Demo",
    "Fojji - Raid Assignments [Forever]",
    "Fojji - [T6] Raid Frames",
    "Fojji - [T6] Raid Leader",
    "Fojji - Karazhan [TBC]",
    "Fojji - Karazhan [TBC][Raid Frames]",
    "Fojji - Raid Pack Anchors [Classic]",

    "Fojji - Dungeon Pack [TBC][P1]",
    "Fojji - Dungeon Pack [TBC][P2]",
    "Fojji - Dungeon Pack [TBC][Party Frames]",

    "Fojji - API Role [TBC]",
    "Fojji - Essentials [TBC]",
    "Numen - Core [TBC]",
    "Numen - Cooldown Tracker [TBC]",

    "Fojji - Arcane Bomb Suite [TBC]",
    "Fojji - AutoMarker [TBC]",
    "Fojji - Boss Kill Times [TBC]",
    "Fojji - Buff Tracker [TBC]",
    "Fojji - Consumables [TBC]",
    "Fojji - Cooldown Pulse [TBC]",
    "Fojji - Debuff Tracker [TBC]",
    "Fojji - External Aura Range [TBC]",
    "Fojji - Fatal Attraction GPS",
    "Fojji - Gear Checker [TBC]",
    "Fojji - Healer Mana Pot Carry [TBC]",
    "Fojji - Healer Tracker [TBC]",
    "Fojji - Incoming Heal Casts [TBC]",
    "Fojji - Item & Trinket Tracker [TBC]",
    "Fojji - JC Neck Tracker [TBC]",
    "Fojji - Pyromaniac [TBC]",
    "Fojji - Raid Leader Tools [TBC]",
    "Fojji - Raid Notes [TBC]",
    "Fojji - Raid Watch [TBC] [Zippy's Edit]",
    "Fojji - Reminder Pop-ups [TBC]",
    "Fojji - Target Swing Timer [TBC]",
    "Fojji - Taunt Alerter [TBC]",
    "Fojji - TBC Boss Frames [Jeyp's Edit]",
    "Fojji - Threat Assist",
    "Fojji - Town Consumes Helper [TBC]",
    "Fojji - WF_STATUS [TBC]",
    "Fojji - Who Pulled [TBC]",
    "Fojji - Pull & Break Timers",
}

local SOUND_CHANNELS = {
    Master = true,
    SFX = true,
    Music = true,
    Ambience = true,
    Dialog = true,
}

local function getFirstVoiceID()
    local voices = C_VoiceChat.GetTtsVoices() or {}
    return voices[1] and voices[1].voiceID
end

local function getSoundChannel()
    local DB = FojjiCoreDB
    local channel = DB and DB.ttsSoundChannel or "Master"

    if channel == "Sound Effects" then
        channel = "SFX"
    end

    if not SOUND_CHANNELS[channel] then
        channel = "Master"
    end

    return channel
end

local function getVoicePackFile(text)
    local DB = FojjiCoreDB

    if not DB or DB.ttsVoiceType ~= "custom" then
        return
    end

    if DB.ttsRandomFavorites then
        local favorites = {}

        for _,name in ipairs(FojjiCore.voicePackOrder or {}) do
            local pack = FojjiCore.voicePacks and FojjiCore.voicePacks[name]

            if DB.ttsVoiceFavorites and DB.ttsVoiceFavorites[name] and pack and pack[text] then
                favorites[#favorites+1] = name
            end
        end

        if #favorites == 0 then
            return
        end

        local name = favorites[math.random(#favorites)]
        return FojjiCore.voicePacks[name][text]
    end

    local pack = FojjiCore.voicePacks and FojjiCore.voicePacks[DB.ttsVoicePack]
    return pack and pack[text]
end

function FojjiCore:GetVoiceLineFile(text)
    if not text or text == "" then return nil end
    return getVoicePackFile(text)
end

function FojjiCore:ApplyTTSSettings()
    local DB = FojjiCoreDB

    if not DB then
        return
    end

    _G.FJITTS_SFX_VOLUME = DB.ttsVolume
    _G.FJITTS_SFX_RATE = DB.ttsRate
    _G.FJITTS_SFX_VOICEID = DB.ttsVoiceID
end

function FojjiCore:Speak(text)
    local DB = FojjiCoreDB

    if not DB or DB.disableTTS or not text or text == "" then
        return false
    end

    if DB.ttsVoiceType == "custom" then
        local file = getVoicePackFile(text)

        if file then
            local willPlay = PlaySoundFile(file,getSoundChannel())

            if willPlay then
                return true
            end
        end

        local voiceID = DB.ttsVoiceID or getFirstVoiceID()

        if not voiceID then
            return false
        end

        C_VoiceChat.SpeakText(voiceID,text,DB.ttsRate,DB.ttsVolume,true)
        return true
    end

    local voiceID = DB.ttsVoiceID or getFirstVoiceID()

    if not voiceID then
        return false
    end

    C_VoiceChat.SpeakText(voiceID,text,DB.ttsRate,DB.ttsVolume,true)
    return true
end

function FojjiCore:GetFontFromAura(auraName)
    local data = ForeverAuras.GetData(auraName)

    if data and data.config and data.config.option and data.config.option.font then
        return SharedMedia:Fetch("font",data.config.option.font)
    end
end

function FojjiCore:ApplyFontToRegion(region,fontPath)
    if not region or not fontPath then
        return
    end

    for _,subRegion in ipairs(region.subRegions or {}) do
        if subRegion.type == "subtext" then
            local _,size,flags = subRegion.text:GetFont()
            subRegion.text:SetFont(fontPath,size,flags)
        end
    end
end

function FojjiCore:ApplyFontToGroup(activeRegions,fontPath)
    if not fontPath then
        return
    end

    for _,regionData in ipairs(activeRegions or {}) do
        local region = regionData.region
        self:ApplyFontToRegion(region,fontPath)
    end
end

local function auraKey(name)
    local key = name:lower():gsub("%s+", "")
    return key, (key:gsub("%[forever%]$", ""))
end

function FojjiCore:FindAuraName(name)
    if ForeverAuras.GetData(name) then return name end
    local want, base = auraKey(name)
    local displays = ForeverAurasSaved and ForeverAurasSaved.displays
    if not displays then return nil end
    local loose
    for id in pairs(displays) do
        if type(id) == "string" then
            local key, idBase = auraKey(id)
            if key == want then return id end
            if not loose and idBase == base then loose = id end
        end
    end
    return loose
end

local function patchOne(id, fontName)
    local saved = ForeverAurasSaved and ForeverAurasSaved.displays and ForeverAurasSaved.displays[id]
    if not saved then return end
    if saved.regionType == "text" then saved.font = fontName end
    if saved.subRegions then
        for _,sub in ipairs(saved.subRegions) do
            if sub.type == "subtext" then sub.text_font = fontName end
        end
    end
end

function FojjiCore:PatchFontForGroup(groupName,fontName,isRecursive)
    groupName = self:FindAuraName(groupName) or groupName
    local groupData = ForeverAuras.GetData(groupName)

    if not groupData then
        return
    end
    if not groupData.controlledChildren then
        patchOne(groupName, fontName)
        return
    end

    for _,childName in ipairs(groupData.controlledChildren) do
        local childData = ForeverAuras.GetData(childName)

        if childData and (childData.regionType == "group" or childData.regionType == "dynamicgroup") and childData.controlledChildren then
            self:PatchFontForGroup(childName,fontName,true)
        else
            local saved = ForeverAurasSaved and ForeverAurasSaved.displays and ForeverAurasSaved.displays[childName]

            if saved then
                if saved.regionType == "text" then
                    saved.font = fontName
                end

                if saved.subRegions then
                    for _,sub in ipairs(saved.subRegions) do
                        if sub.type == "subtext" then
                            sub.text_font = fontName
                        end
                    end
                end
            end
        end
    end

    if not isRecursive then
        Addon.Print(string.format("Fonts patched for group: |cff66b3ff%s|r",groupName))
        Addon.Print("Type |cff66b3ff/reload|r to apply font changes.")
    end
end

function FojjiCore:GetGroupFont(groupName, depth)
    depth = depth or 0
    if depth > 6 then return nil end
    groupName = self:FindAuraName(groupName) or groupName
    local displays = ForeverAurasSaved and ForeverAurasSaved.displays
    local saved = displays and displays[groupName]
    if not saved then return nil end
    if saved.regionType == "text" and saved.font then return saved.font end
    for _, sub in ipairs(saved.subRegions or {}) do
        if sub.type == "subtext" and sub.text_font then return sub.text_font end
    end
    for _, child in ipairs(saved.controlledChildren or {}) do
        local font = self:GetGroupFont(child, depth + 1)
        if font then return font end
    end
    return nil
end

function FojjiCore:PatchFontForAll(fontName)
    if not fontName or not ForeverAuras then
        return
    end

    local patched, done = 0, {}

    for _,groupName in ipairs(self.fontPatchGroups or {}) do
        local found = self:FindAuraName(groupName)

        if found and not done[found] then
            done[found] = true
            self:PatchFontForGroup(found,fontName,true)
            patched = patched+1
        end
    end

    if patched > 0 then
        Addon.Print(string.format("Applied |cff66b3ff%s|r to %d Fojji ForeverAura pack%s.",fontName,patched,patched == 1 and "" or "s"))
        Addon.Print("Type |cff66b3ff/reload|r to apply font changes.")
    else
        Addon.Print("No supported Fojji ForeverAura packs were found.")
    end
end

FojjiCore.SCALE_MIN, FojjiCore.SCALE_MAX = 0.5, 2

function FojjiCore:GetInstalledPackGroups()
    local list, seen = {}, {}

    for _,groupName in ipairs(self.fontPatchGroups or {}) do
        local found = self:FindAuraName(groupName)
        local data = found and ForeverAuras.GetData(found)

        if data and not data.parent and not seen[found] and not found:find(" UI %[") then
            seen[found] = true
            list[#list+1] = found
        end
    end

    local function isAnchors(name) return name:find("Anchors") ~= nil end
    table.sort(list, function(a, b)
        local ca, cb = isAnchors(a), isAnchors(b)
        if ca ~= cb then return ca end
        return a:lower() < b:lower()
    end)

    return list
end

function FojjiCore:GetGroupScale(groupName)
    local found = self:FindAuraName(groupName)
    local data = found and ForeverAuras.GetData(found)

    if not data then
        return nil
    end

    return tonumber(data.scale) or 1
end

function FojjiCore:SetGroupScale(groupName,scale,quiet)
    local found = self:FindAuraName(groupName)
    local data = found and ForeverAuras.GetData(found)

    if not data or data.parent then
        return false
    end

    scale = math.floor(math.max(self.SCALE_MIN,math.min(self.SCALE_MAX,tonumber(scale) or 1))*100+0.5)/100
    data.scale = scale

    local saved = ForeverAurasSaved and ForeverAurasSaved.displays and ForeverAurasSaved.displays[found]

    if saved then
        saved.scale = scale
    end

    local region = ForeverAuras.GetRegion and ForeverAuras.GetRegion(found)

    if region and region.SetScale then
        region:SetScale(scale)
    end

    if self.QueueAnchorSync then self.QueueAnchorSync() end

    if not quiet then
        Addon.Print(string.format("Scale |cff66b3ff%d%%|r applied to |cff66b3ff%s|r.",math.floor(scale*100+0.5),found))
    end

    return true
end

function FojjiCore:SetScaleForAll(scale)
    local count = 0

    for _,groupName in ipairs(self:GetInstalledPackGroups()) do
        if self:SetGroupScale(groupName,scale,true) then
            count = count+1
        end
    end

    if count > 0 then
        Addon.Print(string.format("Scale |cff66b3ff%d%%|r applied to %d Fojji ForeverAuras pack%s.",math.floor((tonumber(scale) or 1)*100+0.5),count,count == 1 and "" or "s"))
    else
        Addon.Print("No supported Fojji ForeverAuras packs were found.")
    end

    return count
end

local ANCHOR_BASE = {
    ["Fojji Anchors - Core [Class]"] = { 34, 32 },
    ["Fojji Anchors - Cooldown Bar [Class]"] = { 32, 30 },
    ["Fojji Anchors - Base Cooldowns [Class]"] = { 30, 26 },
    ["Fojji Anchors - Base CDs [Healer] [Class]"] = { 30, 26 },
    ["Fojji Anchors - Buffs [Class]"] = { 29, 25 },
    ["Fojji Anchors - Debuffs [Class]"] = { 30, 26 },
    ["Fojji Anchors - Defensive CDs [Class]"] = { 30, 28 },
    ["Fojji Anchors - Defensive [Class]"] = { 30, 26 },
    ["Fojji Anchors - Extra Icons [Class]"] = { 32, 32 },
    ["Fojji Anchors - Pop-up Group [Class]"] = { 30, 30 },
    ["Fojji Anchors - Popup Icons"] = { 30, 30 },
    ["Fojji Anchors - Reminders [Class]"] = { 36, 36 },
    ["Fojji Anchors - Combat Reminders [Class]"] = { 36, 36 },
    ["Fojji Anchors - Power Bars [Class]"] = { 238, 12 },
    ["Fojji Anchors - Player Cast Bar [Class]"] = { 205, 21 },
    ["Fojji Anchors - Target Cast Bar [Class]"] = { 238, 15 },
}
local SIZED = { icon = true, aurabar = true }
local warned = {}

local function isAnchorId(id)
    return type(id) == "string" and id:find("^Fojji Anchor") ~= nil
end

local function isClassAnchor(id)
    return ANCHOR_BASE[id] ~= nil or id:find("%[Class%]") ~= nil
end

local function frameTarget(data)
    return data.anchorFrameType == "SELECTFRAME" and type(data.anchorFrameFrame) == "string"
        and data.anchorFrameFrame:match("^WeakAuras:(.+)$") or nil
end

local function anchorTarget(data)
    local target = frameTarget(data)
    return target and isAnchorId(target) and target or nil
end

local function followFlag(data)
    local init = data.actions and data.actions.init
    local code = init and init.do_custom and init.custom
    if type(code) ~= "string" or not code:find("followAnchor", 1, true) then return nil end
    for line in code:gmatch("[^\n]+") do
        local value = line:gsub("%-%-.*$", ""):match("aura_env%.followAnchor%s*=%s*(%a+)")
        if value == "true" then return true elseif value == "false" then return false end
    end
end

local function anchorFor(data)
    local node, hops = data, 0
    while node and hops < 10 do
        hops = hops + 1
        local target = frameTarget(node)
        if target and isAnchorId(target) then return target end
        if target and ForeverAuras.GetData(target) then
            node = ForeverAuras.GetData(target)
        else
            node = node.parent and ForeverAuras.GetData(node.parent)
        end
    end
end

local function anchorPieces(id, out, depth)
    local data = ForeverAuras.GetData(id)
    if not data or depth > 4 then return out end
    if SIZED[data.regionType] and tonumber(data.width) and tonumber(data.height) then
        out[#out + 1] = data
    elseif data.regionType == "text" and tonumber(data.fontSize) then
        out[#out + 1] = data
    end
    for _, child in ipairs(data.controlledChildren or {}) do anchorPieces(child, out, depth + 1) end
    return out
end

local function sameSize(a, b)
    if a.regionType ~= b.regionType then return false end
    if a.regionType == "text" then return math.abs(tonumber(a.fontSize) - tonumber(b.fontSize)) < 0.05 end
    return math.abs(tonumber(a.width) - tonumber(b.width)) <= 0.05 and math.abs(tonumber(a.height) - tonumber(b.height)) <= 0.05
end

local function anchorSample(id)
    local pieces = anchorPieces(id, {}, 0)
    local first = pieces[1]
    if not first then return nil end
    for i = 2, #pieces do
        if not sameSize(pieces[i], first) then return nil, true end
    end
    return first
end

local function anchorLabel(id)
    if id == "Fojji Anchors - Core [Class]" then return "Main Bar" end
    return (id:gsub("^Fojji Anchors %- ", ""):gsub("%s*%[Class%]", ""))
end

local function sizeStore()
    local DB = FojjiCoreDB
    if not DB then return nil end
    DB.anchorSizes = DB.anchorSizes or {}
    return DB.anchorSizes
end

local function resizeOne(data, kind, base, sample, store, changed)
    if data.regionType ~= kind or followFlag(data) == false then return end
    local w, h = tonumber(data.width), tonumber(data.height)
    if not w or not h then return end
    local x, y = tonumber(data.xOffset) or 0, tonumber(data.yOffset) or 0
    local rec = store[data.id]
    local function moved(a, b) return math.abs(a - (b or 1e9)) > 0.05 end
    if not rec or moved(w, rec.sw) or moved(h, rec.sh) or moved(x, rec.sx or x) or moved(y, rec.sy or y) then
        rec = { w = w, h = h, x = x, y = y }
        store[data.id] = rec
    end
    local sw, sh = tonumber(sample.width), tonumber(sample.height)
    local nw, nh = sw, sh
    if kind ~= "icon" then
        if math.abs(rec.w - base[1]) > 0.05 then nw = rec.w end
        if math.abs(rec.h - base[2]) > 0.05 then nh = rec.h end
    end
    local nx, ny = rec.x or x, rec.y or y
    rec.sw, rec.sh, rec.sx, rec.sy = nw, nh, nx, ny
    if moved(nw, w) or moved(nh, h) or moved(nx, x) or moved(ny, y) then
        data.width, data.height, data.xOffset, data.yOffset = nw, nh, nx, ny
        changed[#changed + 1] = data
    end
end

local function resizeUnder(id, kind, base, sample, store, changed, depth)
    local data = ForeverAuras.GetData(id)
    if not data or depth > 6 then return end
    if depth > 0 and anchorTarget(data) then return end
    if data.controlledChildren then
        for _, child in ipairs(data.controlledChildren) do
            resizeUnder(child, kind, base, sample, store, changed, depth + 1)
        end
    else
        resizeOne(data, kind, base, sample, store, changed)
    end
end

local function copyOne(data, sample, changed)
    if data.regionType ~= sample.regionType then return end
    if data.regionType ~= "text" and not SIZED[data.regionType] then return end
    if data.regionType == "text" then
        local size = tonumber(sample.fontSize)
        if size and math.abs((tonumber(data.fontSize) or 0) - size) > 0.05 then
            data.fontSize = size
            changed[#changed + 1] = data
        end
        return
    end
    local w, h = tonumber(sample.width), tonumber(sample.height)
    if math.abs((tonumber(data.width) or 0) - w) > 0.05 or math.abs((tonumber(data.height) or 0) - h) > 0.05 then
        data.width, data.height = w, h
        changed[#changed + 1] = data
    end
end

local TEXT_SKIP = { type = true, text_text = true }

local function ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local t = {}
    for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. ser(x) end
    table.sort(t)
    return "{" .. table.concat(t, ",") .. "}"
end

local function copyValue(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copyValue(x) end
    return t
end

local function textKey(sub)
    return sub.type == "subtext" and type(sub.text_text) == "string" and sub.text_text:match("^%s*(.-)%s*$") or nil
end

local function anchorTexts(target)
    local out, mixed = {}, {}
    for _, piece in ipairs(anchorPieces(target, {}, 0)) do
        for _, sub in ipairs(piece.subRegions or {}) do
            local key = textKey(sub)
            if key then
                local fields = out[key]
                if not fields then
                    fields = {}
                    out[key] = fields
                    for field, value in pairs(sub) do
                        if not TEXT_SKIP[field] then fields[field] = value end
                    end
                else
                    for field, value in pairs(sub) do
                        if not TEXT_SKIP[field] and fields[field] ~= nil and ser(fields[field]) ~= ser(value) then
                            mixed[key .. "\0" .. field] = true
                        end
                    end
                end
            end
        end
    end
    for k in pairs(mixed) do
        local key, field = k:match("^(.-)%z(.*)$")
        out[key][field] = nil
    end
    return out
end

local function textChanges(target, snaps)
    local now = anchorTexts(target)
    local last = snaps[target]
    local changes = {}
    local fresh = {}
    for key, fields in pairs(now) do
        fresh[key] = {}
        for field, value in pairs(fields) do
            local s = ser(value)
            fresh[key][field] = s
            local before = last and last[key] and last[key][field]
            if before ~= nil and before ~= s then
                changes[key] = changes[key] or {}
                changes[key][field] = value
            end
        end
        if last and last[key] then
            for field, s in pairs(last[key]) do
                if fresh[key][field] == nil then fresh[key][field] = s end
            end
        end
    end
    return changes, fresh
end

local function retextUnder(id, changes, changed, depth)
    local data = ForeverAuras.GetData(id)
    if not data or depth > 6 then return end
    if depth > 0 and anchorTarget(data) then return end
    if data.controlledChildren then
        for _, child in ipairs(data.controlledChildren) do retextUnder(child, changes, changed, depth + 1) end
        return
    end
    if followFlag(data) == false or data.regionType == "progresstexture" then return end
    local touched
    for _, sub in ipairs(data.subRegions or {}) do
        local fields = changes[textKey(sub) or ""]
        if fields then
            for field, value in pairs(fields) do
                if ser(sub[field]) ~= ser(value) then
                    sub[field] = copyValue(value)
                    touched = true
                end
            end
        end
    end
    if touched then changed[#changed + 1] = data end
end

function FojjiCore:SyncAnchorSizes(quiet, force)
    if not ForeverAuras or not ForeverAurasSaved or not ForeverAurasSaved.displays then return 0 end
    local DB = FojjiCoreDB
    if DB and DB.anchorSizeSync == false then return 0 end
    if InCombatLockdown() then
        self.anchorSyncAfterCombat = true
        return 0
    end
    local store = sizeStore()
    if not store then return 0 end

    local changed, groups, samples = {}, {}, {}
    DB.anchorTexts = DB.anchorTexts or {}
    local snaps, texts, freshSnaps = DB.anchorTexts, {}, {}
    DB.anchorSeen = DB.anchorSeen or {}
    local seen, freshSeen, always = DB.anchorSeen, {}, force or DB.anchorAutoFit == true
    local function resized(target, sample)
        local now = sample.regionType == "text" and tostring(sample.fontSize)
            or (tostring(sample.width) .. "x" .. tostring(sample.height))
        freshSeen[target] = now
        if always then return true end
        return seen[target] ~= nil and seen[target] ~= now
    end
    local function sampleOf(target)
        local s = samples[target]
        if s == nil then
            local sample, mixed = anchorSample(target)
            if mixed then
                if not quiet and not warned[target] then
                    warned[target] = true
                    Addon.Print(string.format("|cff66b3ff%s|r anchors are different sizes. Set them all to the same size and the auras on it will follow.", anchorLabel(target)))
                end
            elseif sample then
                warned[target] = nil
            end
            s = sample or false
            samples[target] = s
        end
        return s or nil
    end

    for id, data in pairs(ForeverAurasSaved.displays) do
        local target = anchorTarget(data)
        if target and isClassAnchor(target) and not isAnchorId(id) and data.controlledChildren
            and target ~= "Fojji Anchors - Proc Textures [Class]" then
            local sample = sampleOf(target)
            local base = ANCHOR_BASE[target]
            if sample and SIZED[sample.regionType] and not base then
                local key = "@" .. target
                store[key] = store[key] or { w = tonumber(sample.width), h = tonumber(sample.height) }
                base = { store[key].w, store[key].h }
            end
            local before = #changed
            if sample and base and SIZED[sample.regionType] and resized(target, sample) then
                resizeUnder(id, sample.regionType, base, sample, store, changed, 0)
            end
            if not texts[target] then
                texts[target], freshSnaps[target] = textChanges(target, snaps)
            end
            if next(texts[target]) then retextUnder(id, texts[target], changed, 0) end
            if #changed > before then groups[#groups + 1] = data end
        elseif not data.controlledChildren and not isAnchorId(id) and followFlag(data) then
            local on = anchorFor(data)
            local sample = on and not isClassAnchor(on) and sampleOf(on)
            if sample and resized(on, sample) then
                local before = #changed
                copyOne(data, sample, changed)
                local parent = #changed > before and data.parent and ForeverAuras.GetData(data.parent)
                if parent then groups[#groups + 1] = parent end
            end
        end
    end

    for target, snap in pairs(freshSnaps) do snaps[target] = snap end
    for target, now in pairs(freshSeen) do seen[target] = now end

    local added = {}
    self.anchorSyncing = true
    for _, data in ipairs(changed) do
        if not added[data.id] then
            added[data.id] = true
            pcall(ForeverAuras.Add, data, true)
        end
    end
    local done, order = {}, {}
    local function climb(data, depth)
        local id = data and data.parent
        local parent = id and ForeverAuras.GetData(id)
        if not parent or depth > 8 then return end
        if not done[id] or done[id] < depth then
            if not done[id] then order[#order + 1] = parent end
            done[id] = depth
        end
        climb(parent, depth + 1)
    end
    for _, data in ipairs(changed) do climb(data, 1) end
    for _, data in ipairs(groups) do
        if not done[data.id] then done[data.id] = 0; order[#order + 1] = data end
    end
    table.sort(order, function(a, b) return done[a.id] < done[b.id] end)
    for _, data in ipairs(order) do pcall(ForeverAuras.Add, data, true) end
    self.anchorSyncing = nil

    local count = 0
    for _ in pairs(added) do count = count + 1 end
    if not quiet and count > 0 then
        Addon.Print(string.format("Auras matched to your anchors (|cff66b3ff%d|r aura%s).", count, count == 1 and "" or "s"))
    end
    return count
end

do
    local pending
    local function later()
        pending = nil
        FojjiCore:SyncAnchorSizes()
    end
    local function queue()
        if pending then return end
        pending = true
        C_Timer.After(0.4, later)
    end
    FojjiCore.QueueAnchorSync = queue

    if ForeverAuras and ForeverAuras.Add then
        hooksecurefunc(ForeverAuras, "Add", function(data)
            if not data or FojjiCore.anchorSyncing then return end
            if isAnchorId(data.id) and (SIZED[data.regionType] or data.regionType == "text") then
                queue()
            elseif followFlag(data) ~= nil then
                queue()
            elseif not data.parent and data.controlledChildren and data.scale then
                queue()
            end
        end)
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
            C_Timer.After(2, function() FojjiCore:SyncAnchorSizes(true) end)
        elseif FojjiCore.anchorSyncAfterCombat then
            FojjiCore.anchorSyncAfterCombat = nil
            queue()
        end
    end)
end

function FojjiCore:InitForeverAurasOptionsHook()
    if self.waOptionsHooked then
        return
    end

    if not ForeverAuras then
        return
    end

    self.waOptionsHooked = true

    if ForeverAuras.OpenOptions then
        hooksecurefunc(ForeverAuras,"OpenOptions",function()
            ForeverAuras.ScanEvents("WA_FJI_OPTIONS_OPENED")
        end)
    end
end

FojjiCore:InitForeverAurasOptionsHook()

SLASH_FJIARCANEBOMB1 = "/ab"

SlashCmdList["FJIARCANEBOMB"] = function()
    ForeverAuras.ScanEvents("WA_FJI_ABT_TOGGLE")
end
