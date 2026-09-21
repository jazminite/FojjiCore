-- WeakAuras hooks: WA_FJI_OPTIONS_OPENED(), WA_FJI_ABT_TOGGLE() via /ab
-- FojjiCore:Speak(text)
-- FojjiCore:PatchFontForGroup(groupName, fontName), FojjiCore:PatchFontForAll(fontName)

local SharedMedia = LibStub("LibSharedMedia-3.0")

FojjiCore = FojjiCore or {}
FojjiCore_Version = "2.0.8"

FojjiCore.fontPatchGroups = {

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
    local data = WeakAuras.GetData(auraName)

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

function FojjiCore:PatchFontForGroup(groupName,fontName,isRecursive)
    local groupData = WeakAuras.GetData(groupName)

    if not groupData or not groupData.controlledChildren then
        return
    end

    for _,childName in ipairs(groupData.controlledChildren) do
        local childData = WeakAuras.GetData(childName)

        if childData and (childData.regionType == "group" or childData.regionType == "dynamicgroup") and childData.controlledChildren then
            self:PatchFontForGroup(childName,fontName,true)
        else
            local saved = WeakAurasSaved and WeakAurasSaved.displays and WeakAurasSaved.displays[childName]

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
        local icon = "|TInterface\\AddOns\\FojjiCore\\textures\\FojjiBlue.tga:12:12|t"
        local prefix = string.format("%s |cff66ccffFojji|cffff4444Core|r",icon)

        print(string.format("%s Fonts patched for group: |cffddeeff%s|r",prefix,groupName))
        print(string.format("%s |cff99ccffType /reload to apply font changes.|r",prefix))
    end
end

function FojjiCore:PatchFontForAll(fontName)
    if not fontName or not WeakAuras then
        return
    end

    local patched = 0

    for _,groupName in ipairs(self.fontPatchGroups or {}) do
        local data = WeakAuras.GetData(groupName)

        if data and data.controlledChildren then
            self:PatchFontForGroup(groupName,fontName,true)
            patched = patched+1
        end
    end

    local icon = "|TInterface\\AddOns\\FojjiCore\\textures\\FojjiBlue.tga:12:12|t"
    local prefix = string.format("%s |cff66ccffFojji|cffff4444Core|r",icon)

    if patched > 0 then
        print(string.format("%s Applied |cffddeeff%s|r to %d Fojji WeakAura pack%s.",prefix,fontName,patched,patched == 1 and "" or "s"))
        print(string.format("%s |cff99ccffType /reload to apply font changes.|r",prefix))
    else
        print(string.format("%s No supported Fojji WeakAura packs were found.",prefix))
    end
end

function FojjiCore:InitWeakAurasOptionsHook()
    if self.waOptionsHooked then
        return
    end

    if not WeakAuras then
        return
    end

    self.waOptionsHooked = true

    if WeakAuras.OpenOptions then
        hooksecurefunc(WeakAuras,"OpenOptions",function()
            WeakAuras.ScanEvents("WA_FJI_OPTIONS_OPENED")
        end)
    end
end

FojjiCore:InitWeakAurasOptionsHook()

SLASH_FJIARCANEBOMB1 = "/ab"

SlashCmdList["FJIARCANEBOMB"] = function()
    WeakAuras.ScanEvents("WA_FJI_ABT_TOGGLE")
end
