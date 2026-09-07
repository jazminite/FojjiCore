local ICON = "Interface\\AddOns\\FojjiCore\\textures\\FojjiIcons\\F_icon_lightblue"
local FONT = "Interface\\AddOns\\FojjiCore\\font\\Numen.ttf"

local DB_VERSION = 2

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")

local COLORS = {
    accent       = {0.17,0.67,0.95},
    title        = {0.40,0.85,1.00},
    frame        = {0.018,0.021,0.026},
    header       = {0.022,0.026,0.032},
    sidebar      = {0.025,0.032,0.040},
    content      = {0.035,0.040,0.048},
    field        = {0.024,0.028,0.034},
    fieldHover   = {0.044,0.052,0.064},
    button       = {0.052,0.058,0.068},
    buttonHover  = {0.075,0.088,0.105},
    border       = {0.16,0.18,0.22},
    borderDim    = {0.13,0.15,0.18},
    text         = {0.88,0.89,0.91},
    dim          = {0.50,0.53,0.57},
    tab          = {0.61,0.64,0.68},
    tabHover     = {0.88,0.90,0.92},
    scroll       = {0.08,0.09,0.11},
    white        = {1,1,1},
    warning      = {1.00,0.25,0.25},
}

local LAYOUT = {
    width = 760,
    height = 570,
    headerHeight = 76,
    sidebarWidth = 180,
    contentPadding = 36,

    fieldWidth = 410,
    fieldHeight = 34,

    sliderWidth = 380,
    sliderHeight = 60,

    checkboxWidth = 240,
    checkboxHeight = 22,

    menuWidth = 410,
    menuContentWidth = 386,
    menuRowHeight = 30,
    menuMaxRows = 7,

    buttonHeight = 32,
}

local DEFAULTS = {
    ttsVolume = 75,
    ttsRate = 1.8,
    ttsVoiceID = 0,
    ttsVoiceType = "custom",
    ttsVoicePack = "Arabella",
    ttsRandomFavorites = false,
    ttsVoiceFavorites = {},
    disableTTS = false,
    fontName = "Numen",
    fontTarget = "ALL",

    minimap = {
        hide = false,
    },
}

local TEST_PHRASES = {
    "Interrupt",
    "Move Out",
    "Fatal Attraction",
    "Fear Soon",
    "Fixate on You",
    "Phase 2",
    "Sapper Now",
    "Shear Soon",
    "Spread Out",
    "Whirlwind",
}

local DB
local frame
local dropdownMenu

local pages = {}
local tabs = {}
local controls = {}

local function color(name,alpha)
local c = COLORS[name]
return c[1],c[2],c[3],alpha or 1
end

local function createTexture(parent,layer,colorName,alpha)
local texture = parent:CreateTexture(nil,layer)
texture:SetColorTexture(color(colorName,alpha))
return texture
end

local function createText(parent,text,size,colorName)
local font = parent:CreateFontString(nil,"OVERLAY")
font:SetFont(FONT,size or 12,"OUTLINE")
font:SetText(text or "")
font:SetTextColor(color(colorName or "text"))
return font
end

local function createBorder(parent,colorName,alpha,inset)
inset = inset or 0
colorName = colorName or "border"

local border = {}

border.top = createTexture(parent,"BORDER",colorName,alpha)
border.top:SetPoint("TOPLEFT",inset,-inset)
border.top:SetPoint("TOPRIGHT",-inset,-inset)
border.top:SetHeight(1)

border.bottom = createTexture(parent,"BORDER",colorName,alpha)
border.bottom:SetPoint("BOTTOMLEFT",inset,inset)
border.bottom:SetPoint("BOTTOMRIGHT",-inset,inset)
border.bottom:SetHeight(1)

border.left = createTexture(parent,"BORDER",colorName,alpha)
border.left:SetPoint("TOPLEFT",inset,-inset)
border.left:SetPoint("BOTTOMLEFT",inset,inset)
border.left:SetWidth(1)

border.right = createTexture(parent,"BORDER",colorName,alpha)
border.right:SetPoint("TOPRIGHT",-inset,-inset)
border.right:SetPoint("BOTTOMRIGHT",-inset,inset)
border.right:SetWidth(1)

return border
end

local function setBorderColor(border,colorName,alpha)
for _,texture in pairs(border) do
    texture:SetColorTexture(color(colorName,alpha))
end
end

local function anchorBelow(object,previous,gap)
object:ClearAllPoints()
object:SetPoint("TOPLEFT",previous,"BOTTOMLEFT",0,-(gap or 8))
end

local function applyDefaults(target,defaults)
for key,value in pairs(defaults) do
    if type(value) == "table" then
        target[key] = target[key] or {}
        applyDefaults(target[key],value)
    elseif target[key] == nil then
        target[key] = value
    end
end
end

local function migrateDB()
if not DB.dbVersion or DB.dbVersion < DB_VERSION then
    local hide = DB.minimap and DB.minimap.hide or false

    DB.minimap = {
        hide = hide,
    }

    DB.dbVersion = DB_VERSION
end
end

local function hideDropdown()
if dropdownMenu then
    dropdownMenu:Hide()
end
end

local function createSeparator(parent,y)
local line = createTexture(parent,"ARTWORK","borderDim")
line:SetPoint("TOPLEFT",0,y)
line:SetPoint("TOPRIGHT",0,y)
line:SetHeight(1)
return line
end

local function createButton(parent,text,width)
local button = CreateFrame("Button",nil,parent)
button:SetSize(width,LAYOUT.buttonHeight)

button.bg = createTexture(button,"BACKGROUND","button")
button.bg:SetAllPoints()

button.border = createBorder(button)

button.label = createText(button,text,12)
button.label:SetPoint("CENTER")

button:SetScript("OnEnter",function(self)
    self.bg:SetColorTexture(color("buttonHover"))
    setBorderColor(self.border,"accent",0.75)
end)

button:SetScript("OnLeave",function(self)
    self.bg:SetColorTexture(color("button"))
    setBorderColor(self.border,"border")
end)

return button
end

local function createCheckbox(parent,text,onChanged)
local button = CreateFrame("Button",nil,parent)
button:SetSize(LAYOUT.checkboxWidth,LAYOUT.checkboxHeight)

local box = CreateFrame("Frame",nil,button)
box:SetSize(16,16)
box:SetPoint("LEFT")

local bg = createTexture(box,"BACKGROUND","field")
bg:SetAllPoints()

button.border = createBorder(box,"border")

button.check = createTexture(box,"ARTWORK","accent")
button.check:SetPoint("TOPLEFT",3,-3)
button.check:SetPoint("BOTTOMRIGHT",-3,3)
button.check:Hide()

button.label = createText(button,text,12)
button.label:SetPoint("LEFT",box,"RIGHT",9,0)

button.checked = false

function button:SetChecked(value)
self.checked = value and true or false
self.check:SetShown(self.checked)
end

function button:GetChecked()
return self.checked
end

button:SetScript("OnClick",function(self)
    self:SetChecked(not self:GetChecked())

    if onChanged then
        onChanged(self:GetChecked())
    end
end)

button:SetScript("OnEnter",function(self)
    setBorderColor(self.border,"accent",0.85)
    self.label:SetTextColor(color("white"))
end)

button:SetScript("OnLeave",function(self)
    setBorderColor(self.border,"border")
    self.label:SetTextColor(color("text"))
end)

return button
end

local function createSlider(parent,labelText,minValue,maxValue,step)
local container = CreateFrame("Frame",nil,parent)
container:SetSize(455,LAYOUT.sliderHeight)

local label = createText(container,labelText,13,"white")
label:SetPoint("TOPLEFT")

local track = CreateFrame("Frame",nil,container)
track:SetSize(LAYOUT.sliderWidth,18)
track:SetPoint("TOPLEFT",label,"BOTTOMLEFT",0,-13)

local bg = createTexture(track,"BACKGROUND","scroll")
bg:SetPoint("LEFT")
bg:SetPoint("RIGHT")
bg:SetHeight(4)

local slider = CreateFrame("Slider",nil,track)
slider:SetAllPoints()
slider:SetOrientation("HORIZONTAL")
slider:SetMinMaxValues(minValue,maxValue)
slider:SetValueStep(step)
slider:SetObeyStepOnDrag(true)

local thumb = slider:CreateTexture(nil,"ARTWORK")
thumb:SetSize(12,20)
thumb:SetColorTexture(color("accent"))
slider:SetThumbTexture(thumb)

local minText = createText(container,tostring(minValue),10,"dim")
minText:SetPoint("TOPLEFT",track,"BOTTOMLEFT",0,-4)

local maxText = createText(container,tostring(maxValue),10,"dim")
maxText:SetPoint("TOPRIGHT",track,"BOTTOMRIGHT",0,-4)

slider.valueText = createText(container,"",12,"white")
slider.valueText:SetPoint("LEFT",track,"RIGHT",20,0)
slider.container = container

return slider
end

local function createSectionLabel(parent,text)
return createText(parent,text,13,"white")
end

local function createPageHeader(parent,title,description)
local titleText = createText(parent,title,20,"title")
titleText:SetPoint("TOPLEFT")

local descriptionText = createText(parent,description,12)
descriptionText:SetTextColor(0.68,0.70,0.74)
descriptionText:SetPoint("TOPLEFT",titleText,"BOTTOMLEFT",0,-9)

createSeparator(parent,-56)

return descriptionText
end

local function createDropdownButton(parent)
local button = CreateFrame("Button",nil,parent)
button:SetSize(LAYOUT.fieldWidth,LAYOUT.fieldHeight)

button.bg = createTexture(button,"BACKGROUND","field")
button.bg:SetAllPoints()

button.border = createBorder(button)

button.text = createText(button,"",11)
button.text:SetPoint("LEFT",12,0)
button.text:SetPoint("RIGHT",-38,0)
button.text:SetJustifyH("LEFT")

button.arrow = createText(button,"v",11)
button.arrow:SetTextColor(0.65,0.68,0.72)
button.arrow:SetPoint("RIGHT",-14,2)

button:SetScript("OnEnter",function(self)
    self.bg:SetColorTexture(color("fieldHover"))
    setBorderColor(self.border,"accent",0.70)
end)

button:SetScript("OnLeave",function(self)
    self.bg:SetColorTexture(color("field"))
    setBorderColor(self.border,"border")
end)

return button
end

local function createDropdownMenu(button,entries)
if dropdownMenu then
    dropdownMenu:Hide()
    dropdownMenu:SetParent(nil)
    dropdownMenu = nil
end

local rowHeight = LAYOUT.menuRowHeight
local visibleRows = math.min(#entries,LAYOUT.menuMaxRows)
local visibleHeight = visibleRows*rowHeight
local contentHeight = math.max(#entries*rowHeight,1)
local menuHeight = visibleHeight+8
local maxScroll = math.max(0,contentHeight-visibleHeight)

dropdownMenu = CreateFrame("Frame",nil,frame)
dropdownMenu.owner = button
dropdownMenu:SetSize(LAYOUT.menuWidth,menuHeight)
dropdownMenu:SetPoint("TOPLEFT",button,"BOTTOMLEFT",0,-4)
dropdownMenu:SetFrameStrata("TOOLTIP")
dropdownMenu:SetFrameLevel(200)

local bg = createTexture(dropdownMenu,"BACKGROUND","header")
bg:SetAllPoints()

createBorder(dropdownMenu)

local scrollFrame = CreateFrame("ScrollFrame",nil,dropdownMenu)
scrollFrame:SetPoint("TOPLEFT",4,-4)
scrollFrame:SetPoint("BOTTOMRIGHT",-20,4)
scrollFrame:EnableMouseWheel(true)

local child = CreateFrame("Frame",nil,scrollFrame)
child:SetSize(LAYOUT.menuContentWidth,contentHeight)
scrollFrame:SetScrollChild(child)

local scrollbar = CreateFrame("Slider",nil,dropdownMenu)
scrollbar:SetWidth(10)
scrollbar:SetPoint("TOPRIGHT",-5,-6)
scrollbar:SetPoint("BOTTOMRIGHT",-5,6)
scrollbar:SetOrientation("VERTICAL")
scrollbar:SetMinMaxValues(0,maxScroll)
scrollbar:SetValueStep(rowHeight)
scrollbar:SetObeyStepOnDrag(false)

local scrollbarTrack = createTexture(scrollbar,"BACKGROUND","scroll")
scrollbarTrack:SetWidth(2)
scrollbarTrack:SetPoint("TOP",0,-2)
scrollbarTrack:SetPoint("BOTTOM",0,2)

local thumb = scrollbar:CreateTexture(nil,"ARTWORK")
thumb:SetSize(6,30)
thumb:SetColorTexture(color("accent",0.85))
scrollbar:SetThumbTexture(thumb)

if maxScroll > 0 then
    local ratio = visibleHeight/contentHeight
    thumb:SetHeight(math.max(26,math.floor((menuHeight-12)*ratio)))
else
    scrollbar:Hide()
end

scrollbar:SetScript("OnValueChanged",function(_,value)
    scrollFrame:SetVerticalScroll(value)
end)

scrollbar:SetScript("OnEnter",function()
    thumb:SetColorTexture(color("title"))
end)

scrollbar:SetScript("OnLeave",function()
    thumb:SetColorTexture(color("accent",0.85))
end)

scrollFrame:SetScript("OnMouseWheel",function(_,delta)
    if maxScroll <= 0 then
        return
    end

    local scroll = scrollFrame:GetVerticalScroll()
    scroll = math.max(0,math.min(maxScroll,scroll-delta*rowHeight))
    scrollbar:SetValue(scroll)
end)

local selectedIndex

for i,entryData in ipairs(entries) do
    local entry = entryData
    local selected = entry.selected

    local row = CreateFrame("Button",nil,child)
    row:SetSize(LAYOUT.menuContentWidth,rowHeight)
    row:SetPoint("TOPLEFT",0,-((i-1)*rowHeight))

    if selected then
        selectedIndex = i
    end

    local selectedBG = createTexture(row,"BACKGROUND","accent",0.10)
    selectedBG:SetAllPoints()
    selectedBG:SetShown(selected)

    local selectedBar = createTexture(row,"ARTWORK","accent")
    selectedBar:SetPoint("TOPLEFT")
    selectedBar:SetPoint("BOTTOMLEFT")
    selectedBar:SetWidth(2)
    selectedBar:SetShown(selected)

    local hover = createTexture(row,"BACKGROUND","accent",0.07)
    hover:SetAllPoints()
    hover:Hide()

    local text = createText(row,entry.text,11)
    text:SetPoint("LEFT",10,0)
    text:SetPoint("RIGHT",entry.onFavorite and -105 or -10,0)
    text:SetJustifyH("LEFT")

    if selected then
        text:SetTextColor(color("white"))
    end

    if entry.tag then
        local tag = createText(row,entry.tag,9,"accent")
        tag:SetPoint("RIGHT",entry.onFavorite and -52 or -10,0)
    end

    if entry.onFavorite then
        local favorite = CreateFrame("Button",nil,row)
        favorite:SetSize(40,22)
        favorite:SetPoint("RIGHT",-4,0)
        favorite:SetFrameLevel(row:GetFrameLevel()+2)

        favorite.bg = createTexture(favorite,"BACKGROUND","button")
        favorite.bg:SetAllPoints()

        favorite.border = createBorder(favorite,"borderDim")

        favorite.label = createText(favorite,"FAV",8)
        favorite.label:SetPoint("CENTER",0,1)

        local function updateFavorite()
        if entry.favorite then
            favorite.bg:SetColorTexture(color("accent",0.14))
            favorite.label:SetTextColor(color("title"))
            setBorderColor(favorite.border,"accent",0.70)
        else
            favorite.bg:SetColorTexture(color("button"))
            favorite.label:SetTextColor(0.43,0.46,0.50)
            setBorderColor(favorite.border,"borderDim")
        end
    end

    updateFavorite()

    favorite:SetScript("OnEnter",function()
        favorite.bg:SetColorTexture(color("accent",0.18))
        favorite.label:SetTextColor(color("title"))
        setBorderColor(favorite.border,"accent",0.85)
    end)

    favorite:SetScript("OnLeave",updateFavorite)

    favorite:SetScript("OnClick",function()
        entry.favorite = not entry.favorite
        entry.onFavorite(entry.favorite)
        updateFavorite()
    end)
end

row:SetScript("OnEnter",function()
    if not selected then
        hover:Show()
    end
end)

row:SetScript("OnLeave",function()
    hover:Hide()
end)

row:SetScript("OnClick",function()
    if entry.onClick then
        entry.onClick()
    end

    hideDropdown()
end)
end

local initialScroll = 0

if selectedIndex and maxScroll > 0 then
    local selectedBottom = selectedIndex*rowHeight

    if selectedBottom > visibleHeight then
        initialScroll = math.min(maxScroll,selectedBottom-visibleHeight)
    end
end

scrollFrame:SetVerticalScroll(initialScroll)
scrollbar:SetValue(initialScroll)

dropdownMenu:Show()
end

local function applyTTSSettings()
if FojjiCore.ApplyTTSSettings then
    FojjiCore:ApplyTTSSettings()
end
end

local function getFavoriteVoiceCount()
local count = 0

for _,name in ipairs(FojjiCore.voicePackOrder or {}) do
    if DB.ttsVoiceFavorites[name] then
        count = count+1
    end
end

return count
end

local function getSystemVoiceName(voiceID)
for _,voice in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
    if voice.voiceID == voiceID then
        return voice.name
    end
end

return "System Voice"
end

local function updateTTSControlState()
if not controls.volume or not controls.rate then
    return
end

local custom = DB.ttsVoiceType == "custom"

controls.volume.container:SetAlpha(custom and 0.30 or 1)
controls.rate.container:SetAlpha(custom and 0.30 or 1)

controls.volume:EnableMouse(not custom)
controls.rate:EnableMouse(not custom)

if controls.customVoiceHint then
    controls.customVoiceHint:SetShown(custom)
end
end

local function updateVoiceText()
if not controls.voice then
    return
end

local favoriteCount = getFavoriteVoiceCount()

if DB.ttsRandomFavorites then
    controls.voice.text:SetText("Random Favourites")

    if controls.voiceWarning then
        controls.voiceWarning:SetShown(favoriteCount == 0)
    end
elseif DB.ttsVoiceType == "custom" and DB.ttsVoicePack then
    controls.voice.text:SetText(DB.ttsVoicePack)

    if controls.voiceWarning then
        controls.voiceWarning:Hide()
    end
else
    controls.voice.text:SetText(getSystemVoiceName(DB.ttsVoiceID))

    if controls.voiceWarning then
        controls.voiceWarning:Hide()
    end
end

updateTTSControlState()
end

local function openVoiceMenu(button)
local entries = {}

-- System voices first
for _,voiceData in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
    local voice = voiceData

    entries[#entries+1] = {
        text = voice.name,
        selected = not DB.ttsRandomFavorites and DB.ttsVoiceType ~= "custom" and DB.ttsVoiceID == voice.voiceID,

        onClick = function()
            DB.ttsRandomFavorites = false
            DB.ttsVoiceType = "system"
            DB.ttsVoiceID = voice.voiceID
            DB.ttsVoicePack = nil

            applyTTSSettings()
            updateVoiceText()
        end,
    }
end

-- Random favourites after system voices
entries[#entries+1] = {
    text = "Random Favourites",
    selected = DB.ttsRandomFavorites,

    onClick = function()
        DB.ttsRandomFavorites = true
        DB.ttsVoiceType = "custom"

        applyTTSSettings()
        updateVoiceText()
    end,
}

-- Arabella first custom voice
if FojjiCore.voicePacks and FojjiCore.voicePacks["Arabella"] then
    local name = "Arabella"

    entries[#entries+1] = {
        text = name,
        tag = "AI",
        favorite = DB.ttsVoiceFavorites[name],
        selected = not DB.ttsRandomFavorites and DB.ttsVoiceType == "custom" and DB.ttsVoicePack == name,

        onFavorite = function(value)
            DB.ttsVoiceFavorites[name] = value
            updateVoiceText()
        end,

        onClick = function()
            DB.ttsRandomFavorites = false
            DB.ttsVoiceType = "custom"
            DB.ttsVoicePack = name

            applyTTSSettings()
            updateVoiceText()
        end,
    }
end

-- Remaining custom voices
for _,voiceName in ipairs(FojjiCore.voicePackOrder or {}) do
    local name = voiceName

    if name ~= "Arabella" then
        entries[#entries+1] = {
            text = name,
            tag = "AI",
            favorite = DB.ttsVoiceFavorites[name],
            selected = not DB.ttsRandomFavorites and DB.ttsVoiceType == "custom" and DB.ttsVoicePack == name,

            onFavorite = function(value)
                DB.ttsVoiceFavorites[name] = value
                updateVoiceText()
            end,

            onClick = function()
                DB.ttsRandomFavorites = false
                DB.ttsVoiceType = "custom"
                DB.ttsVoicePack = name

                applyTTSSettings()
                updateVoiceText()
            end,
        }
    end
end

createDropdownMenu(button,entries)
end

local function getFonts()
local fonts = {}

for _,fontName in ipairs(SharedMedia:List("font") or {}) do
    fonts[#fonts+1] = fontName
end

table.sort(fonts,function(a,b)
    return a:lower() < b:lower()
end)

return fonts
end

local function getInstalledFontPatchGroups()
local groups = {}

for _,groupName in ipairs(FojjiCore.fontPatchGroups or {}) do
    local data = WeakAuras.GetData(groupName)

    if data and data.controlledChildren then
        groups[#groups+1] = groupName
    end
end

return groups
end

local function openFontMenu(button)
local entries = {}

for _,fontData in ipairs(getFonts()) do
    local fontName = fontData

    entries[#entries+1] = {
        text = fontName,
        selected = DB.fontName == fontName,

        onClick = function()
            DB.fontName = fontName
            controls.font.text:SetText(fontName)
        end,
    }
end

createDropdownMenu(button,entries)
end

local function openFontTargetMenu(button)
local entries = {
    {
        text = "Apply to All",
        selected = DB.fontTarget == "ALL",

        onClick = function()
            DB.fontTarget = "ALL"
            controls.fontTarget.text:SetText("Apply to All")
        end,
    },
}

for _,groupData in ipairs(getInstalledFontPatchGroups()) do
    local groupName = groupData

    entries[#entries+1] = {
        text = groupName,
        selected = DB.fontTarget == groupName,

        onClick = function()
            DB.fontTarget = groupName
            controls.fontTarget.text:SetText(groupName)
        end,
    }
end

createDropdownMenu(button,entries)
end

local function fadePage(page)
page:SetAlpha(0)
page:Show()
UIFrameFadeIn(page,0.12,0,1)
end

local function selectTab(name)
hideDropdown()

for pageName,page in pairs(pages) do
    if pageName == name then
        if not page:IsShown() then
            fadePage(page)
        end
    else
        page:Hide()
    end
end

for tabName,button in pairs(tabs) do
    local active = tabName == name

    button.indicator:SetShown(active)
    button.glow:SetShown(active)

    if active then
        button.label:SetTextColor(color("white"))
    else
        button.label:SetTextColor(color("tab"))
    end
end
end

local function updateMinimapVisibility()
if DB.minimap.hide then
    DBIcon:Hide("FojjiCore")
else
    DBIcon:Show("FojjiCore")
end

if controls.minimap then
    controls.minimap:SetChecked(not DB.minimap.hide)
end
end

local function createMinimapButton()
local launcher = LDB:NewDataObject("FojjiCore",{
    type = "launcher",
    text = "Fojji Core",
    icon = ICON,
    iconCoords = {0.04,0.96,0.04,0.96},

    OnClick = function(_,button)
        if button == "LeftButton" then
            FojjiCore:ToggleOptions()
        elseif button == "RightButton" then
            DB.minimap.hide = true
            updateMinimapVisibility()
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cff4fc5ffFojji|cffff5b5bCore|r")
        tooltip:AddLine("Version "..(FojjiCore_Version or "Unknown"),0.60,0.62,0.66)
        tooltip:AddLine(" ")
        tooltip:AddLine("Left-click to open settings",1,1,1)
        tooltip:AddLine("Right-click to hide",0.65,0.67,0.71)
    end,
})

DBIcon:Register("FojjiCore",launcher,DB.minimap)
updateMinimapVisibility()
end

local function createOptions()
frame = CreateFrame("Frame","FojjiCoreOptionsFrame",UIParent)
frame:SetSize(LAYOUT.width,LAYOUT.height)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(100)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",frame.StartMoving)
frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)
frame:Hide()

local frameBG = createTexture(frame,"BACKGROUND","frame",0.99)
frameBG:SetAllPoints()

createBorder(frame,"accent",0.65)

table.insert(UISpecialFrames,"FojjiCoreOptionsFrame")

local header = CreateFrame("Frame",nil,frame)
header:SetPoint("TOPLEFT",1,-1)
header:SetPoint("TOPRIGHT",-1,-1)
header:SetHeight(LAYOUT.headerHeight)

local headerBG = createTexture(header,"BACKGROUND","header")
headerBG:SetAllPoints()

local logo = header:CreateTexture(nil,"ARTWORK")
logo:SetSize(44,44)
logo:SetPoint("LEFT",22,0)
logo:SetTexture(ICON)

local title = createText(header,"|cff4fc5ffFojji|cffff5b5bCore|r",17)
title:SetPoint("LEFT",logo,"RIGHT",12,7)

local version = createText(header,"Version "..(FojjiCore_Version or "Unknown"),10,"dim")
version:SetPoint("LEFT",logo,"RIGHT",12,-10)

local close = CreateFrame("Button",nil,header)
close:SetSize(30,30)
close:SetPoint("RIGHT",-18,0)

close.bg = createTexture(close,"BACKGROUND","button")
close.bg:SetAllPoints()

close.border = createBorder(close)

close.label = createText(close,"x",14)
close.label:SetPoint("CENTER",0,1)

close:SetScript("OnEnter",function(self)
    self.bg:SetColorTexture(color("buttonHover"))
    setBorderColor(self.border,"accent",0.75)
    self.label:SetTextColor(color("white"))
end)

close:SetScript("OnLeave",function(self)
    self.bg:SetColorTexture(color("button"))
    setBorderColor(self.border,"border")
    self.label:SetTextColor(color("text"))
end)

close:SetScript("OnClick",function()
    hideDropdown()
    frame:Hide()
end)

local headerSeparator = createTexture(frame,"ARTWORK","borderDim")
headerSeparator:SetPoint("TOPLEFT",1,-LAYOUT.headerHeight)
headerSeparator:SetPoint("TOPRIGHT",-1,-LAYOUT.headerHeight)
headerSeparator:SetHeight(1)

local body = CreateFrame("Frame",nil,frame)
body:SetPoint("TOPLEFT",1,-(LAYOUT.headerHeight+1))
body:SetPoint("BOTTOMRIGHT",-1,1)

local sidebar = CreateFrame("Frame",nil,body)
sidebar:SetPoint("TOPLEFT")
sidebar:SetPoint("BOTTOMLEFT")
sidebar:SetWidth(LAYOUT.sidebarWidth)

local sidebarBG = createTexture(sidebar,"BACKGROUND","sidebar")
sidebarBG:SetAllPoints()

local contentPanel = CreateFrame("Frame",nil,body)
contentPanel:SetPoint("TOPLEFT",sidebar,"TOPRIGHT")
contentPanel:SetPoint("BOTTOMRIGHT")

local contentBG = createTexture(contentPanel,"BACKGROUND","content")
contentBG:SetAllPoints()

local divider = createTexture(body,"ARTWORK","border")
divider:SetPoint("TOPLEFT",sidebar,"TOPRIGHT")
divider:SetPoint("BOTTOMLEFT",sidebar,"BOTTOMRIGHT")
divider:SetWidth(1)

local content = CreateFrame("Frame",nil,contentPanel)
content:SetPoint("TOPLEFT",LAYOUT.contentPadding,-30)
content:SetPoint("BOTTOMRIGHT",-LAYOUT.contentPadding,30)

local function createPage(name,titleText,description)
local page = CreateFrame("Frame",nil,content)
page:SetAllPoints()
page:Hide()

pages[name] = page
createPageHeader(page,titleText,description)

return page
end

local function createTab(name,text,y)
local button = CreateFrame("Button",nil,sidebar)
button:SetSize(LAYOUT.sidebarWidth,46)
button:SetPoint("TOPLEFT",0,y)

button.glow = createTexture(button,"BACKGROUND","accent",0.10)
button.glow:SetAllPoints()
button.glow:Hide()

button.indicator = createTexture(button,"ARTWORK","accent")
button.indicator:SetPoint("TOPLEFT")
button.indicator:SetPoint("BOTTOMLEFT")
button.indicator:SetWidth(3)
button.indicator:Hide()

button.label = createText(button,text,13,"tab")
button.label:SetPoint("LEFT",26,0)

button:SetScript("OnEnter",function(self)
    if not self.indicator:IsShown() then
        self.glow:SetColorTexture(1,1,1,0.025)
        self.glow:Show()
        self.label:SetTextColor(color("tabHover"))
    end
end)

button:SetScript("OnLeave",function(self)
    if not self.indicator:IsShown() then
        self.glow:Hide()
        self.label:SetTextColor(color("tab"))
    else
        self.glow:SetColorTexture(color("accent",0.10))
    end
end)

button:SetScript("OnClick",function()
    selectTab(name)
end)

tabs[name] = button
end

local sidebarY = -26

local function addSidebarHeader(text)
local label = createText(sidebar,text,10)
label:SetTextColor(0.40,0.44,0.48)
label:SetPoint("TOPLEFT",26,sidebarY)

sidebarY = sidebarY-32
end

local function addTab(name,text)
createTab(name,text,sidebarY)
sidebarY = sidebarY-46
end

addSidebarHeader("SETTINGS")
addTab("general","General")
addTab("tts","Text to Speech")
addTab("font","Font")

sidebarY = sidebarY-24

addSidebarHeader("INFO")
addTab("about","About")

local generalPage = createPage(
"general",
"General",
"Configure FojjiCore."
)

local minimapLabel = createSectionLabel(generalPage,"Minimap")
minimapLabel:SetPoint("TOPLEFT",0,-84)

controls.minimap = createCheckbox(
generalPage,
"Show minimap icon",
function(checked)
    DB.minimap.hide = not checked
    updateMinimapVisibility()
end
)

anchorBelow(controls.minimap,minimapLabel,10)
controls.minimap:SetChecked(not DB.minimap.hide)

local ttsPage = createPage(
"tts",
"Text to Speech",
"Configure the shared voice used by Fojji WeakAuras."
)

controls.disableTTS = createCheckbox(
ttsPage,
"Disable all TTS",
function(checked)
    DB.disableTTS = checked
end
)

controls.disableTTS:SetPoint("TOPLEFT",0,-76)
controls.disableTTS:SetChecked(DB.disableTTS)

controls.volume = createSlider(ttsPage,"Volume",0,100,1)
anchorBelow(controls.volume.container,controls.disableTTS,14)

controls.volume:SetValue(DB.ttsVolume)
controls.volume.valueText:SetText(DB.ttsVolume)

controls.volume:SetScript("OnValueChanged",function(self,value)
    value = math.floor(value+0.5)

    DB.ttsVolume = value
    self.valueText:SetText(value)

    applyTTSSettings()
end)

controls.rate = createSlider(ttsPage,"Speech Rate",-10,10,0.1)
anchorBelow(controls.rate.container,controls.volume.container,6)

controls.rate:SetValue(DB.ttsRate)
controls.rate.valueText:SetText(string.format("%.1f",DB.ttsRate))

controls.rate:SetScript("OnValueChanged",function(self,value)
    value = math.floor(value*10+0.5)/10

    DB.ttsRate = value
    self.valueText:SetText(string.format("%.1f",value))

    applyTTSSettings()
end)

local voiceLabel = createSectionLabel(ttsPage,"Voice")
anchorBelow(voiceLabel,controls.rate.container,8)

controls.voice = createDropdownButton(ttsPage)
anchorBelow(controls.voice,voiceLabel,8)

controls.voice:SetScript("OnClick",function(self)
    if dropdownMenu and dropdownMenu.owner == self and dropdownMenu:IsShown() then
        hideDropdown()
    else
        openVoiceMenu(self)
    end
end)

controls.voiceWarning = createText(
ttsPage,
"No favourite voices selected. Add favourites from the Voice menu.",
10,
"warning"
)

anchorBelow(controls.voiceWarning,controls.voice,7)
controls.voiceWarning:Hide()

controls.customVoiceHint = createText(
ttsPage,
"Custom Voices use your in-game Master Volume settings",
10,
"dim"
)

anchorBelow(controls.customVoiceHint,controls.voiceWarning,7)

local testLabel = createSectionLabel(ttsPage,"Test Voice")
anchorBelow(testLabel,controls.customVoiceHint,18)

local testButton = createButton(ttsPage,"Play Test TTS",140)
anchorBelow(testButton,testLabel,8)

testButton:SetScript("OnClick",function()
    FojjiCore:Speak(TEST_PHRASES[math.random(#TEST_PHRASES)])
end)

updateVoiceText()

local fontPage = createPage(
"font",
"Font",
"Apply the selected Font to your Fojji WeakAuras."
)

local fontLabel = createSectionLabel(fontPage,"Font")
fontLabel:SetPoint("TOPLEFT",0,-84)

controls.font = createDropdownButton(fontPage)
controls.font.text:SetText(DB.fontName)
anchorBelow(controls.font,fontLabel,8)

controls.font:SetScript("OnClick",function(self)
    if dropdownMenu and dropdownMenu.owner == self and dropdownMenu:IsShown() then
        hideDropdown()
    else
        openFontMenu(self)
    end
end)

local targetLabel = createSectionLabel(fontPage,"Apply To")
anchorBelow(targetLabel,controls.font,18)

controls.fontTarget = createDropdownButton(fontPage)
anchorBelow(controls.fontTarget,targetLabel,8)

if DB.fontTarget == "ALL" then
    controls.fontTarget.text:SetText("Apply to All")
else
    controls.fontTarget.text:SetText(DB.fontTarget)
end

controls.fontTarget:SetScript("OnClick",function(self)
    if dropdownMenu and dropdownMenu.owner == self and dropdownMenu:IsShown() then
        hideDropdown()
    else
        openFontTargetMenu(self)
    end
end)

controls.applyFont = createButton(fontPage,"Apply Font",140)
anchorBelow(controls.applyFont,controls.fontTarget,18)

controls.applyFont.confirming = false
controls.applyFont.confirmationID = 0

controls.applyFont:SetScript("OnClick",function(self)
    if not self.confirming then
        self.confirming = true
        self.confirmationID = self.confirmationID+1

        local confirmationID = self.confirmationID

        self.label:SetText("Are you sure?")

        C_Timer.After(5,function()
            if self.confirming and self.confirmationID == confirmationID then
                self.confirming = false
                self.label:SetText("Apply Font")
            end
        end)

        return
    end

    self.confirming = false
    self.confirmationID = self.confirmationID+1
    self.label:SetText("Apply Font")

    if DB.fontTarget == "ALL" then
        FojjiCore:PatchFontForAll(DB.fontName)
    else
        FojjiCore:PatchFontForGroup(DB.fontTarget,DB.fontName)
    end
end)

local fontHint = createText(
fontPage,
"A /reload is required after applying a new font.",
10,
"dim"
)

anchorBelow(fontHint,controls.applyFont,8)

local aboutPage = createPage(
"about",
"About",
"Information and links for FojjiCore."
)

local aboutLogo = aboutPage:CreateTexture(nil,"ARTWORK")
aboutLogo:SetSize(68,68)
aboutLogo:SetPoint("TOPLEFT",0,-82)
aboutLogo:SetTexture(ICON)

local aboutTitle = createText(
aboutPage,
"|cff4fc5ffFojji|cffff5b5bCore|r",
19
)

aboutTitle:SetPoint("LEFT",aboutLogo,"RIGHT",16,0)

local addonInfoLabel = createSectionLabel(aboutPage,"Addon Information")
anchorBelow(addonInfoLabel,aboutLogo,20)

local interfaceVersion = select(4,GetBuildInfo())

local info = createText(
aboutPage,
"FojjiCore Version:  |cffffffff"..(FojjiCore_Version or "Unknown")..
"|r\nInterface Version:  |cffffffff"..tostring(interfaceVersion or "Unknown").."|r",
12
)

info:SetTextColor(0.68,0.70,0.74)
info:SetJustifyH("LEFT")
info:SetSpacing(7)

anchorBelow(info,addonInfoLabel,10)

local linksLabel = createSectionLabel(aboutPage,"Links")
anchorBelow(linksLabel,info,28)

local function createLink(titleText,url,previous)
local button = CreateFrame("Button",nil,aboutPage)
button:SetSize(270,24)

anchorBelow(button,previous,8)

local text = createText(button,titleText,12,"accent")
text:SetPoint("LEFT")

local hint = createText(button,"Click to copy",10)
hint:SetTextColor(0.42,0.45,0.49)
hint:SetPoint("LEFT",text,"RIGHT",12,0)

button:SetScript("OnEnter",function()
    text:SetTextColor(0.52,0.84,1)
    hint:SetTextColor(0.62,0.65,0.69)
end)

button:SetScript("OnLeave",function()
    text:SetTextColor(color("accent"))
    hint:SetTextColor(0.42,0.45,0.49)
end)

button:SetScript("OnClick",function()
    ChatFrame_OpenChat(url)
end)

return button
end

local discord = createLink(
"Fojji Discord",
"https://discord.gg/fojjiwow",
linksLabel
)

local patreon = createLink(
"Patreon",
"https://www.patreon.com/c/fojjiwow",
discord
)

createLink(
"Twitch",
"https://twitch.tv/fojjiwow",
patreon
)

selectTab("general")
end

local function validateFontTarget()
if DB.fontTarget == "ALL" then
    return
end

local data = WeakAuras.GetData(DB.fontTarget)

if not data or not data.controlledChildren then
    DB.fontTarget = "ALL"
end
end

function FojjiCore:ToggleOptions()
if not frame then
    return
end

if frame:IsShown() then
    hideDropdown()
    frame:Hide()
    return
end
validateFontTarget()
applyTTSSettings()

controls.volume:SetValue(DB.ttsVolume)
controls.rate:SetValue(DB.ttsRate)

controls.minimap:SetChecked(not DB.minimap.hide)
controls.disableTTS:SetChecked(DB.disableTTS)

controls.font.text:SetText(DB.fontName)

if DB.fontTarget == "ALL" then
    controls.fontTarget.text:SetText("Apply to All")
else
    controls.fontTarget.text:SetText(DB.fontTarget)
end

updateVoiceText()
updateMinimapVisibility()

hideDropdown()
selectTab("general")

frame:SetAlpha(0)
frame:Show()

UIFrameFadeIn(frame,0.15,0,1)
end

SLASH_FOJJICORE1 = "/fojjicore"
SLASH_FOJJICORE2 = "/fc"

SlashCmdList["FOJJICORE"] = function()
    FojjiCore:ToggleOptions()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")

loader:SetScript("OnEvent",function(self,_,addonName)
    if addonName ~= "FojjiCore" then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")

    FojjiCoreDB = FojjiCoreDB or {}
    DB = FojjiCoreDB

    migrateDB()
    applyDefaults(DB,DEFAULTS)
    applyTTSSettings()

    createOptions()
    createMinimapButton()
end)
