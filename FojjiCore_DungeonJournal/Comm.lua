local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

local Comm = {}
FDJ.Comm = Comm

local PREFIX = "FojjiDJ"
local SLICE = 200
local GAP = 0.35

local queue, inbox = {}, {}
local serial = 0
local ticking = false

local function send(item)
    local api = C_ChatInfo
    if not api or not api.SendAddonMessage then return true end
    local ok, result = pcall(api.SendAddonMessage, PREFIX, item.text, item.channel, item.target)
    if not ok then return true end
    if result == false then return false end
    if type(result) == "number" and Enum and Enum.SendAddonMessageResult then
        local r = Enum.SendAddonMessageResult
        if result == r.AddonMessageThrottle or result == r.ChannelThrottle or result == r.GeneralError then return false end
    end
    return true
end

local function pump()
    if #queue == 0 then
        ticking = false
        return
    end
    if not FDJ.ChatLocked() then
        local item = queue[1]
        if send(item) then table.remove(queue, 1) end
    end
    C_Timer.After(GAP, pump)
end

function Comm.Send(kind, payload, channel, target)
    channel = channel or FDJ.GroupChannel()
    if not channel then return false end
    payload = payload or ""
    serial = (serial % 4095) + 1
    local total = math.max(1, math.ceil(#payload / SLICE))
    for i = 1, total do
        local slice = payload:sub((i - 1) * SLICE + 1, i * SLICE)
        queue[#queue + 1] = {
            text = ("%s~%x~%x~%x~%s"):format(kind, serial, i, total, slice),
            channel = channel,
            target = target,
        }
    end
    if not ticking then
        ticking = true
        pump()
    end
    return true
end

function Comm.Busy()
    return #queue
end

local function receive(prefix, text, channel, sender)
    if FDJ.Secret(prefix) or prefix ~= PREFIX or FDJ.Secret(text) or FDJ.Secret(sender) then return end
    if type(text) ~= "string" or type(sender) ~= "string" then return end
    local who = FDJ.Short(sender)
    local me = FDJ.PlayerName()
    if me and (who == me or sender == me or sender:gsub("%-.*$", "") == me) then return end
    if UnitIsUnit and UnitExists and UnitExists(sender) and UnitIsUnit(sender, "player") then return end
    local full = GetUnitName and GetUnitName("player", true)
    if full and (sender == full or who == full or sender:gsub("%-.*$", "") == full:gsub("%-.*$", "")) then return end
    local kind, id, index, total, slice = text:match("^(%w+)~(%x+)~(%x+)~(%x+)~(.*)$")
    if not kind then return end
    index, total = tonumber(index, 16), tonumber(total, 16)
    if not index or not total or total < 1 or total > 400 or index > total then return end
    if total == 1 then
        FDJ:Emit("FDJ_COMM", kind, slice, who, channel)
        return
    end
    local key = who .. ":" .. id
    local box = inbox[key]
    if not box or box.total ~= total then
        box = { total = total, got = 0, parts = {}, born = GetTime() }
        inbox[key] = box
    end
    if not box.parts[index] then
        box.parts[index] = slice
        box.got = box.got + 1
    end
    if box.got == box.total then
        inbox[key] = nil
        FDJ:Emit("FDJ_COMM", kind, table.concat(box.parts), who, channel)
    end
    for k, other in pairs(inbox) do
        if GetTime() - other.born > 120 then inbox[k] = nil end
    end
end

FDJ:On("PLAYER_LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
end)

FDJ:On("CHAT_MSG_ADDON", receive)
