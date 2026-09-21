-- /pull <seconds>, /pull cancel
-- /break <minutes>, /break <minutes:seconds>, /break cancel
-- ForeverAuras event: FOJJI_CORE_BREAK_TIMER(prefix, message, channel, sender)
-- Chat prefix: FojjiTimerAddon

local _, Addon = ...
local MESSAGE_PREFIX = "FojjiTimerAddon"

C_ChatInfo.RegisterAddonMessagePrefix(MESSAGE_PREFIX)

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
frame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if hasanysecretvalues(prefix, message, channel, sender) then return end
    if prefix ~= MESSAGE_PREFIX or channel ~= "RAID" then return end

    local command, value = strsplit(":", message)
    if command == "BREAK_CANCEL" then
        Addon.AuraAPI.ScanEvents("FOJJI_CORE_BREAK_TIMER", prefix, message, channel, sender)
        Addon.Print(sender .. " cancelled the break timer.")
    elseif command == "BREAK" then
        local duration = tonumber(value)
        if duration and duration >= 1 and duration <= 3600 and duration % 1 == 0 then
            Addon.AuraAPI.ScanEvents("FOJJI_CORE_BREAK_TIMER", prefix, message, channel, sender)
            Addon.Print(("%s started a break timer for %d:%02d."):format(sender, math.floor(duration / 60), duration % 60))
        end
    end
end)

SLASH_FOJJIPULL1 = "/pull"

SlashCmdList["FOJJIPULL"] = function(msg)
    if IsInGroup() and not (UnitIsGroupAssistant("player") or UnitIsGroupLeader("player")) then
        Addon.Print("You do not have permission.")
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
        Addon.Print("Invalid pull time specified.")
    end
end

SLASH_FOJJIBREAK1 = "/break"

SlashCmdList["FOJJIBREAK"] = function(msg)
    if not IsInRaid() or not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        Addon.Print("Only the raid leader or assistants can send a break timer.")
        return
    end

    msg = msg:match("^%s*(.-)%s*$"):lower()
    local message
    if msg == "cancel" then
        message = "BREAK_CANCEL::" .. UnitName("player")
    else
        local minutes, seconds = msg:match("^(%d+):(%d%d)$")
        minutes = tonumber(minutes or msg)
        seconds = tonumber(seconds) or 0
        if not minutes or minutes < 0 or minutes > 60 or minutes % 1 ~= 0 or seconds > 59 or minutes * 60 + seconds < 1 or minutes * 60 + seconds > 3600 then
            Addon.Print("Use /break 5, /break 3:30, or /break cancel. Maximum: 60 minutes.")
            return
        end
        message = ("BREAK:%d:%s"):format(minutes * 60 + seconds, UnitName("player"))
    end

    local ok, result = pcall(C_ChatInfo.SendAddonMessageLogged, MESSAGE_PREFIX, message, "RAID")
    if not ok then
        Addon.Print("The client could not send the logged break timer message.")
    elseif result ~= nil and result ~= true and result ~= Enum.SendAddonMessageResult.Success then
        local reason = tostring(result)
        for name, value in pairs(Enum.SendAddonMessageResult) do
            if value == result then reason = name; break end
        end
        Addon.Print("Break timer message was not sent: " .. reason .. ".")
    end
end
