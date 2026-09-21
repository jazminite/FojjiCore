if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    return
end

local ADDON_MESSAGE_PREFIX = "FojjiTimerAddon"

C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
C_ChatInfo.RegisterAddonMessagePrefix("D5WCWC")
C_ChatInfo.RegisterAddonMessagePrefix("D5WCC")
C_ChatInfo.RegisterAddonMessagePrefix("D5WC")
C_ChatInfo.RegisterAddonMessagePrefix("D5C")
C_ChatInfo.RegisterAddonMessagePrefix("D5")

local function printTimerMessage(cmd,playerName,duration)
    if cmd == "BREAK" and duration ~= 0 then
        print(string.format("%s started a break timer for %d minutes!", playerName, duration / 60))
    elseif cmd == "BREAK_CANCEL" then
        print(string.format("%s cancelled the break timer!", playerName))
    end
end

local function sendBreakMessage(cmd,duration)
    local message = cmd .. ":" .. (duration or "") .. ":" .. UnitName("player")

    if IsInRaid() then
        C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, message, "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, message, "PARTY")
    else
        C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, message, "WHISPER", UnitName("player"))
    end

    if IsInRaid() then
        local name = UnitName("player")
        local realm = GetRealmName():gsub("[%s-]+", "")

        if cmd == "BREAK" then
            local _,_,_,_,_,_,_,instanceID = GetInstanceInfo()
            instanceID = tonumber(instanceID) or 0

            local dbmMessage = ("%s-%s\t1\tBT\t%s\t%d"):format(name, realm, duration, instanceID)
            C_ChatInfo.SendAddonMessage("D5", dbmMessage, "RAID")
        elseif cmd == "BREAK_CANCEL" then
            local dbmMessage = name .. "\tD5WC\t0\tBT"
            C_ChatInfo.SendAddonMessage("D5", dbmMessage, "RAID")
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(self,event,...)
    local prefix,content = ...

    if prefix ~= ADDON_MESSAGE_PREFIX then
        return
    end

    local cmd,timeValue,playerName = strsplit(":", content)
    local duration = tonumber(timeValue or "0")

    if cmd == "BREAK" or cmd == "BREAK_CANCEL" then
        printTimerMessage(cmd,playerName,duration)
    end
end)

SLASH_FOJJIPULL1 = "/pull"

SlashCmdList["FOJJIPULL"] = function(msg)
    if IsInGroup() and not (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player")) then
        print("You do not have permission.")
        return
    end

    if msg == "cancel" then
        SlashCmdList.COUNTDOWN("0")
        return
    end

    local duration = tonumber(msg)

    if duration and duration > 0 then
        SlashCmdList.COUNTDOWN(tostring(duration))
    else
        print("Invalid pull time specified.")
    end
end

SLASH_FOJJIBREAK1 = "/break"

SlashCmdList["FOJJIBREAK"] = function(msg)
    if IsInGroup() and not (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player")) then
        print("You do not have permission.")
        return
    end

    if msg == "cancel" then
        sendBreakMessage("BREAK_CANCEL")
        return
    end

    local duration = tonumber(msg)

    if duration and duration > 0 then
        sendBreakMessage("BREAK",duration * 60)
    else
        print("Invalid break time specified.")
    end
end
