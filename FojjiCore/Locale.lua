local _, Addon = ...
local loc = GetLocale and GetLocale() or "enUS"
if loc == "enGB" then loc = "enUS" end
Addon.Locale = loc
Addon.TR = {}
Addon.Translated = false
Addon.WideFont = loc == "zhCN" or loc == "zhTW" or loc == "koKR" or loc == "ruRU"

local TR = Addon.TR

function Addon.Tr(text)
    if type(text) ~= "string" then return text end
    return TR[text] or text
end

local function setText(self, text, ...)
    if type(text) == "string" then text = TR[text] or text end
    return self.trSetText(self, text, ...)
end

function Addon.Localize(fs)
    if not Addon.Translated or not fs or fs.trSetText then return fs end
    fs.trSetText = fs.SetText
    fs.SetText = setText
    return fs
end

function Addon.LocalFont(path)
    if Addon.WideFont then return STANDARD_TEXT_FONT end
    return path
end

function Addon.GamepadUIAuto()
    if C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and Enum and Enum.InputDeviceInterfaceType then
        local ok, style = pcall(C_InputInterfaceStyle.GetCurrentStyle)
        if ok then return style == Enum.InputDeviceInterfaceType.Gamepad end
    end
    if InputUtil and InputUtil.IsGamepadUIEnabled then
        local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
        if ok then return on and true or false end
    end
    return false
end
function Addon.GamepadUI()
    local set = FojjiCoreDB and FojjiCoreDB.gamepadUI
    if set == "on" then return true elseif set == "off" then return false end
    return Addon.GamepadUIAuto()
end

function Addon.EscapeCloses(name)
    if name and UISpecialFrames and not Addon.GamepadUI() then table.insert(UISpecialFrames, name) end
end

do
    local f, atLogin = CreateFrame("Frame"), nil
    f:RegisterEvent("PLAYER_LOGIN")
    if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid("INPUT_DEVICE_INTERFACE_TRANSITION") then
        pcall(f.RegisterEvent, f, "INPUT_DEVICE_INTERFACE_TRANSITION")
    end
    f:SetScript("OnEvent", function(_, event)
        local now = Addon.GamepadUIAuto()
        if event == "PLAYER_LOGIN" then atLogin = now return end
        if atLogin == nil or now == atLogin or (FojjiCoreDB and FojjiCoreDB.gamepadUI) then return end
        atLogin = now
        if Addon.Print then Addon.Print("Gamepad UI switched. Type |cffffd100/reload|r so FojjiCore can adjust to it.") end
    end)
end
