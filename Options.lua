-- /fc or /fojjicore
-- FojjiCore:ToggleOptions(tab): tts, font, general, about; speedrun on Forever only

local _, Addon = ...
local AuraAPI = Addon.AuraAPI or WeakAuras
local auraName = Addon.AuraAPI and "ForeverAuras" or "WeakAuras"
local defaultTab = Addon.CreateSpeedrunPage and "speedrun" or "tts"
local ICON = "Interface\\AddOns\\FojjiCore\\textures\\FojjiIcons\\F_icon_lightblue"
local FONT = "Interface\\AddOns\\FojjiCore\\font\\Numen.ttf"

local DB_VERSION = 2

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")

local COLORS = {
    accent = {0.40,0.70,1.00},
    title = {0.90,0.94,1.00},
    frame = {0.018,0.021,0.026},
    header = {0.022,0.026,0.032},
    sidebar = {0.025,0.032,0.040},
    content = {0.035,0.040,0.048},
    field = {0.024,0.028,0.034},
    fieldHover = {0.044,0.052,0.064},
    button = {0.052,0.058,0.068},
    buttonHover = {0.075,0.088,0.105},
    border = {0.16,0.18,0.22},
    borderDim = {0.13,0.15,0.18},
    text = {0.88,0.89,0.91},
    dim = {0.50,0.53,0.57},
    tab = {0.61,0.64,0.68},
    tabHover = {0.88,0.90,0.92},
    scroll = {0.08,0.09,0.11},
    white = {1,1,1},
    warning = {1.00,0.25,0.25},
}

local LAYOUT = {
    width = 880,
    height = 620,
    headerHeight = 60,
    sidebarWidth = 164,
    contentPadding = 20,
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
    buttonHeight = 28,
}

local DEFAULTS = {
    theme = "ember",
    windowWidth = 880,
    windowHeight = 620,
    optionsScale = 1,
    ttsVolume = 75,
    ttsRate = 1.8,
    ttsVoiceID = 0,
    ttsVoiceType = "custom",
    ttsVoicePack = "Arabella",
    ttsRandomFavorites = false,
    ttsVoiceFavorites = {},
    ttsSoundChannel = "Master",
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

local SOUND_CHANNELS = {
    {value = "Master", text = "Master"},
    {value = "SFX", text = "Sound Effects"},
    {value = "Music", text = "Music"},
    {value = "Ambience", text = "Ambience"},
    {value = "Dialog", text = "Dialog"},
}

local DB
local frame

local pages = {}
local tabs = {}
local controls = {}

local themeTextures = setmetatable({}, { __mode = "k" })
local themeFonts = setmetatable({}, { __mode = "k" })
local themeGlows = setmetatable({}, { __mode = "k" })
local THEME_ORDER = { "ember", "fojji", "arcane", "jade" }
local THEMES = {
    fojji = { name = "Fojji / Azure", rgb = {0.40,0.70,1.00} },
    ember = { name = "Ember / Crimson", rgb = {1.00,0.30,0.26} },
    arcane = { name = "Arcane / Violet", rgb = {0.70,0.48,1.00} },
    jade = { name = "Jade / Emerald", rgb = {0.20,0.88,0.66} },
}
local function applyTheme(key)
    local theme = THEMES[key] or THEMES.ember
    local r,g,b = unpack(theme.rgb)
    COLORS.accent = {r,g,b}
    COLORS.title = {0.90,0.94,1}
    COLORS.frame = {0.015+r*0.014,0.018+g*0.014,0.026+b*0.014}
    COLORS.header = {0.025+r*0.08,0.028+g*0.08,0.036+b*0.08}
    COLORS.sidebar = {0.025+r*0.025,0.028+g*0.025,0.035+b*0.025}
    COLORS.content = {0.055+r*0.018,0.060+g*0.018,0.073+b*0.018}
    COLORS.border = {0.10+r*0.24,0.10+g*0.24,0.12+b*0.24}
    COLORS.borderDim = {0.07+r*0.12,0.08+g*0.12,0.10+b*0.12}
    COLORS.button = {0.035+r*0.07,0.04+g*0.07,0.05+b*0.07}
    COLORS.buttonHover = {0.045+r*0.17,0.05+g*0.17,0.06+b*0.17}
    for texture, data in pairs(themeTextures) do
        local c = COLORS[data.name]
        texture:SetColorTexture(c[1],c[2],c[3],data.alpha or 1)
    end
    for texture in pairs(themeGlows) do
        texture:SetVertexColor(r, g, b)
    end
    for font, name in pairs(themeFonts) do
        local c = COLORS[name]
        font:SetTextColor(c[1],c[2],c[3])
    end
    if DB then DB.theme = THEMES[key] and key or "ember" end
    if Addon.SpeedrunRefreshTheme then Addon.SpeedrunRefreshTheme() end
end

function Addon.GetAccent()
    return COLORS.accent[1],COLORS.accent[2],COLORS.accent[3]
end

function Addon.GetColor(name)
    local c = COLORS[name] or COLORS.text
    return c[1],c[2],c[3]
end

local function color(name,alpha)
    local c = COLORS[name]
    return c[1],c[2],c[3],alpha or 1
end

local function createTexture(parent,layer,colorName,alpha)
    local texture = parent:CreateTexture(nil,layer)
    texture:SetColorTexture(color(colorName,alpha))
    themeTextures[texture] = { name = colorName, alpha = alpha }
    return texture
end

local function createArtwork(parent, asset, layer, tinted)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, 1)
    texture:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\"..asset)
    if tinted then
        texture:SetVertexColor(color("accent"))
        themeGlows[texture] = true
    end
    return texture
end

local function createText(parent,text,size,colorName)
    local font = parent:CreateFontString(nil,"OVERLAY")
    font:SetFont(FONT,math.max(9,math.floor((size or 12)*0.8+0.5)),"")
    font:SetText(text or "")
    font:SetTextColor(color(colorName or "text"))
    themeFonts[font] = colorName or "text"
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
    Addon.OptionsMenu.Close()
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

local function createPageHeader(parent,title)
    local titleText = createText(parent,title,20,"title")
    titleText:SetPoint("TOPLEFT")

    createSeparator(parent,-40)
    return titleText
end

local function createScrollFrame(parent)
    local scroll = CreateFrame("ScrollFrame",nil,parent)
    scroll:EnableMouseWheel(true)
    local bar = CreateFrame("Slider",nil,scroll)
    bar:SetPoint("TOPLEFT",scroll,"TOPRIGHT",10,0)
    bar:SetPoint("BOTTOMLEFT",scroll,"BOTTOMRIGHT",10,0)
    bar:SetWidth(7)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0,0)
    bar:SetValueStep(1)
    local track = createTexture(bar,"BACKGROUND","borderDim")
    track:SetAllPoints()
    local thumb = createTexture(bar,"ARTWORK","accent",0.65)
    thumb:SetSize(7,36)
    bar:SetThumbTexture(thumb)
    bar:SetScript("OnValueChanged",function(_,value) scroll:SetVerticalScroll(value) end)
    scroll:SetScript("OnScrollRangeChanged",function(_,_,range)
        bar:SetMinMaxValues(0,range)
        bar:SetShown(range > 0)
        if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    end)
    scroll:SetScript("OnVerticalScroll",function(_,value)
        if bar:GetValue() ~= value then bar:SetValue(value) end
    end)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()-delta*36)))
    end)
    return scroll
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

local function createDropdownMenu(button, entries)
    local items = {}
    for _, entry in ipairs(entries) do
        items[#items + 1] = {
            text = entry.text, tag = entry.tag, checked = entry.selected,
            onClick = entry.onClick, favorite = entry.favorite, onFavorite = entry.onFavorite,
        }
    end
    Addon.OptionsMenu.Open(button, items, {
        width = math.max(220, button:GetWidth()), maxRows = LAYOUT.menuMaxRows, openUp = button.openUp,
    })
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

local function getSoundChannelName(channel)
    for _,data in ipairs(SOUND_CHANNELS) do
        if data.value == channel then
            return data.text
        end
    end

    return "Master"
end

local function updateTTSControlState()
    local custom = DB.ttsVoiceType == "custom"

    controls.volume.container:SetAlpha(custom and 0.30 or 1)
    controls.rate.container:SetAlpha(custom and 0.30 or 1)
    controls.volume:EnableMouse(not custom)
    controls.rate:EnableMouse(not custom)

    controls.soundChannelLabel:SetShown(custom)
    controls.soundChannel:SetShown(custom)
    controls.soundChannelHint:SetShown(custom)
    controls.soundChannelNote:SetShown(custom)

    if custom then
        local previous = controls.voiceWarning:IsShown() and controls.voiceWarning or controls.voice
        local gap = controls.voiceWarning:IsShown() and 5 or 8

        anchorBelow(controls.soundChannelLabel,previous,gap)
        anchorBelow(controls.soundChannel,controls.soundChannelLabel,5)
        anchorBelow(controls.soundChannelHint,controls.soundChannel,4)
        anchorBelow(controls.soundChannelNote,controls.soundChannelHint,3)
        anchorBelow(controls.testLabel,controls.soundChannelNote,8)
    else
        anchorBelow(controls.testLabel,controls.voice,12)
    end

    anchorBelow(controls.testButton,controls.testLabel,5)
end

local function updateVoiceText()
    local favoriteCount = getFavoriteVoiceCount()

    if DB.ttsRandomFavorites then
        controls.voice.text:SetText("Random Favourites")
        controls.voiceWarning:SetShown(favoriteCount == 0)
    elseif DB.ttsVoiceType == "custom" and DB.ttsVoicePack then
        controls.voice.text:SetText(DB.ttsVoicePack)
        controls.voiceWarning:Hide()
    else
        controls.voice.text:SetText(getSystemVoiceName(DB.ttsVoiceID))
        controls.voiceWarning:Hide()
    end

    updateTTSControlState()
end

local function openVoiceMenu(button)
    local entries = {}

    for _,voice in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
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

    for _,name in ipairs(FojjiCore.voicePackOrder or {}) do
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

local function openSoundChannelMenu(button)
    local entries = {}

    for _,channelData in ipairs(SOUND_CHANNELS) do
        local channel = channelData

        entries[#entries+1] = {
            text = channel.text,
            selected = DB.ttsSoundChannel == channel.value,
            onClick = function()
                DB.ttsSoundChannel = channel.value
                controls.soundChannel.text:SetText(channel.text)
            end,
        }
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
        local data = AuraAPI.GetData(groupName)

        if data and data.controlledChildren then
            groups[#groups+1] = groupName
        end
    end

    return groups
end

local function openFontMenu(button)
    local entries = {}

    for _,fontName in ipairs(getFonts()) do
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

    for _,groupName in ipairs(getInstalledFontPatchGroups()) do
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
        button.label:SetTextColor(color(active and "white" or "tab"))
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
            tooltip:AddLine("|cff66b3ffFojji|cffff4444Core|r")
            tooltip:AddLine((FojjiCore_Version or "Unknown"):gsub("%-forever%.","."),0.60,0.62,0.66)
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
    frame:SetScale(DB.optionsScale or 1)
    frame:SetSize(math.min(1440,math.max(760,DB.windowWidth)),math.min(1080,math.max(540,DB.windowHeight)))
    frame:SetResizable(true)
    frame:SetResizeBounds(760,540,1440,1080)
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
    local grip = CreateFrame("Button",nil,frame)
    grip:SetSize(22,22)
    grip:SetFrameLevel(frame:GetFrameLevel()+20)
    grip:SetPoint("BOTTOMRIGHT",-3,3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown",function(_,button)
        if button ~= "LeftButton" then return end

        local left,top = frame:GetLeft(),frame:GetTop()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
        frame:StartSizing("BOTTOMRIGHT")
    end)
    local function stopSizing()
        frame:StopMovingOrSizing()
        DB.windowWidth,DB.windowHeight = frame:GetWidth(),frame:GetHeight()
    end
    grip:SetScript("OnMouseUp",stopSizing)
    frame:SetScript("OnHide",function() stopSizing(); hideDropdown() end)
    local frameBG = createTexture(frame,"BACKGROUND","frame",0.99)
    frameBG:SetAllPoints()

    createBorder(frame,"border",0.85)
    table.insert(UISpecialFrames,"FojjiCoreOptionsFrame")

    local header = CreateFrame("Frame",nil,frame)
    header:SetPoint("TOPLEFT",1,-1)
    header:SetPoint("TOPRIGHT",-1,-1)
    header:SetHeight(LAYOUT.headerHeight)

    local headerBG = createArtwork(header,"header-metal","BACKGROUND")
    headerBG:SetAllPoints()

    local logo = header:CreateTexture(nil,"ARTWORK")
    logo:SetSize(44,44)
    logo:SetPoint("LEFT",22,0)
    logo:SetTexture(ICON)

    local title = createText(header,"|cff66b3ffFojji|cffff4444Core|r",22)
    title:SetPoint("LEFT",logo,"RIGHT",12,8)

    local version = createText(header,(FojjiCore_Version or "Unknown"):gsub("%-forever%.","."),10,"dim")
    version:SetPoint("LEFT",logo,"RIGHT",12,-10)

    local atmosphere = createArtwork(header,"header-light","BACKGROUND",true)
    atmosphere:SetAllPoints()
    local edge = createArtwork(header,"header-edge","ARTWORK",true)
    edge:SetPoint("BOTTOMLEFT");edge:SetPoint("BOTTOMRIGHT");edge:SetHeight(16)
    local corner = createArtwork(header,"panel-corner","ARTWORK",true)
    corner:SetSize(24,24);corner:SetPoint("TOPLEFT",2,-2);corner:SetAlpha(.5)

    local close = CreateFrame("Button",nil,header)
    close:SetSize(30,30)
    close:SetPoint("RIGHT",-18,0)

    close.bg = close:CreateTexture(nil,"BACKGROUND")
    close.bg:SetAllPoints();close.bg:SetColorTexture(.08,.035,.04,.65)
    close.border = createBorder(close,"warning",0.24)
    close.icon = createArtwork(close,"close-cross","ARTWORK")
    close.icon:SetSize(22,22);close.icon:SetPoint("CENTER");close.icon:SetVertexColor(.9,.43,.40)
    close:SetScript("OnEnter",function(self)
        self.bg:SetColorTexture(.24,.035,.045,.95)
        setBorderColor(self.border,"warning",0.7)
        self.icon:SetVertexColor(1,.8,.75)
    end)
    close:SetScript("OnLeave",function(self)
        self.bg:SetColorTexture(.08,.035,.04,.65)
        setBorderColor(self.border,"warning",0.24)
        self.icon:SetVertexColor(.9,.43,.40)
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
    local grain = createArtwork(contentPanel,"panel-grain","BACKGROUND")
    grain:SetAllPoints()
    local contentMark = contentPanel:CreateTexture(nil,"BACKGROUND",nil,2)
    contentMark:SetTexture(ICON);contentMark:SetSize(180,180)
    contentMark:SetPoint("BOTTOMRIGHT",-30,24);contentMark:SetAlpha(0.018)
    local lowerEdge = createTexture(contentPanel,"BORDER","accent",0.3)
    lowerEdge:SetPoint("BOTTOMLEFT");lowerEdge:SetPoint("BOTTOMRIGHT");lowerEdge:SetHeight(1)

    local divider = createTexture(body,"ARTWORK","border")
    divider:SetPoint("TOPLEFT",sidebar,"TOPRIGHT")
    divider:SetPoint("BOTTOMLEFT",sidebar,"BOTTOMRIGHT")
    divider:SetWidth(1)

    local content = CreateFrame("Frame",nil,contentPanel)
    content:SetPoint("TOPLEFT",LAYOUT.contentPadding,-24)
    content:SetPoint("BOTTOMRIGHT",-LAYOUT.contentPadding,26)

    local function createPage(name,titleText)
        local page = CreateFrame("Frame",nil,content)
        page:SetAllPoints()
        page:Hide()
        pages[name] = page
        createPageHeader(page,titleText)
        return page
    end

    local function createTab(name,text,y)
        local button = CreateFrame("Button",nil,sidebar)
        button:SetSize(LAYOUT.sidebarWidth,32)
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

    local sidebarY = -18

    local function addSidebarHeader(text)
        local label = createText(sidebar,text,10)
        label:SetTextColor(0.40,0.44,0.48)
        label:SetPoint("TOPLEFT",26,sidebarY)
        sidebarY = sidebarY-22
    end

    local function addTab(name,text)
        createTab(name,text,sidebarY)
        sidebarY = sidebarY-34
    end

    if Addon.CreateSpeedrunPage then
        addSidebarHeader("RAID TOOLS")
        addTab("speedrun","Speedrun Timer")
        sidebarY = sidebarY-18
    end
    addSidebarHeader("FOJJI "..auraName:upper())
    addTab("tts","Audio & Voices")
    addTab("font","Aura Fonts")
    sidebarY = sidebarY-18
    addSidebarHeader("SETTINGS")
    addTab("general","Appearance")
    addTab("about","About")

    if Addon.CreateSpeedrunPage then
        local speedrunPage = createPage("speedrun","Speedrun Timer")
        local built, buildError = pcall(Addon.CreateSpeedrunPage, speedrunPage, {
            Button = createButton, Text = createText, Texture = createTexture, Font = FONT,
            Checkbox = createCheckbox, Scroll = createScrollFrame,
            Menu = createDropdownMenu, DropdownButton = createDropdownButton,
            Panel = function(parent)
                local bg = createTexture(parent,"BACKGROUND","field")
                bg:SetAllPoints()
                createBorder(parent,"borderDim")
            end,
        })
        if not built then Addon.Print("Speedrun settings page failed to build: "..tostring(buildError)) end
    end

    local generalPage = createPage("general","Appearance")

    local minimapLabel = createSectionLabel(generalPage,"Minimap")
    minimapLabel:SetPoint("TOPLEFT",0,-84)

    controls.minimap = createCheckbox(generalPage,"Show minimap icon",function(checked)
        DB.minimap.hide = not checked
        updateMinimapVisibility()
    end)

    anchorBelow(controls.minimap,minimapLabel,10)
    controls.minimap:SetChecked(not DB.minimap.hide)

    local themeLabel = createSectionLabel(generalPage,"Window theme")
    themeLabel:SetPoint("TOPLEFT",0,-164)
    local themeMenu = createDropdownButton(generalPage)
    anchorBelow(themeMenu,themeLabel,10)
    themeMenu.text:SetText((THEMES[DB.theme] or THEMES.ember).name)
    local function chooseTheme(button)
        local entries = {}
        for _, key in ipairs(THEME_ORDER) do
            local themeKey = key
            entries[#entries+1] = { text = THEMES[key].name, onClick = function()
                applyTheme(themeKey)
                themeMenu.text:SetText(THEMES[themeKey].name)
            end }
        end
        createDropdownMenu(button,entries)
    end
    themeMenu:SetScript("OnClick",chooseTheme)
    local resetWindow = createButton(generalPage,"Reset window",160)
    resetWindow:SetPoint("TOPLEFT",0,-270)
    resetWindow:SetScript("OnClick",function()
        frame:ClearAllPoints(); frame:SetPoint("CENTER")
        frame:SetSize(LAYOUT.width,LAYOUT.height)
        DB.windowWidth,DB.windowHeight = LAYOUT.width,LAYOUT.height
    end)
    local resizeHint = createText(generalPage,"Drag the bottom-right corner to resize. Your size and theme are saved.",12,"dim")
    resizeHint:SetPoint("TOPLEFT",0,-320)

    local scaleLabel = createSectionLabel(generalPage,"Options window scale")
    scaleLabel:SetPoint("TOPLEFT",0,-360)
    local scaleMenu = createDropdownButton(generalPage)
    scaleMenu:SetWidth(180)
    anchorBelow(scaleMenu,scaleLabel,10)
    local function setOptionsScale(value)
        DB.optionsScale = value
        scaleMenu.text:SetText(("%d%%"):format(math.floor(value*100+0.5)))
        frame:SetScale(value)
    end
    scaleMenu.text:SetText(("%d%%"):format(math.floor(DB.optionsScale*100+0.5)))
    scaleMenu:SetScript("OnClick",function(self)
        local entries = {}
        for percent = 60,140,5 do
            local value = percent/100
            entries[#entries+1] = {
                text = percent.."%", selected = math.abs(DB.optionsScale-value)<0.001,
                onClick = function() setOptionsScale(value) end,
            }
        end
        createDropdownMenu(self,entries)
    end)
    local resetScale = createButton(generalPage,"Reset to 100%",140)
    resetScale:SetPoint("LEFT",scaleMenu,"RIGHT",10,0)
    resetScale:SetScript("OnClick",function()
        hideDropdown()
        setOptionsScale(1)
    end)

    local ttsPage = createPage("tts","Text to Speech")
    local ttsDescription = createText(ttsPage,"Configure Text to Speech settings for use with Fojji "..auraName..".",12,"dim")
    ttsDescription:SetPoint("TOPLEFT",0,-50)

    controls.disableTTS = createCheckbox(ttsPage,"Disable all TTS",function(checked)
        DB.disableTTS = checked
    end)

    controls.disableTTS:SetPoint("TOPLEFT",0,-76)
    controls.disableTTS:SetChecked(DB.disableTTS)

    controls.volume = createSlider(ttsPage,"Volume",0,100,1)
    anchorBelow(controls.volume.container,controls.disableTTS,10)
    controls.volume:SetValue(DB.ttsVolume)
    controls.volume.valueText:SetText(DB.ttsVolume)

    controls.volume:SetScript("OnValueChanged",function(self,value)
        value = math.floor(value+0.5)
        DB.ttsVolume = value
        self.valueText:SetText(value)
        applyTTSSettings()
    end)

    controls.rate = createSlider(ttsPage,"Speech Rate",-10,10,0.1)
    anchorBelow(controls.rate.container,controls.volume.container,2)
    controls.rate:SetValue(DB.ttsRate)
    controls.rate.valueText:SetText(string.format("%.1f",DB.ttsRate))

    controls.rate:SetScript("OnValueChanged",function(self,value)
        value = math.floor(value*10+0.5)/10
        DB.ttsRate = value
        self.valueText:SetText(string.format("%.1f",value))
        applyTTSSettings()
    end)

    local voiceLabel = createSectionLabel(ttsPage,"Voice")
    anchorBelow(voiceLabel,controls.rate.container,2)

    controls.voice = createDropdownButton(ttsPage)
    anchorBelow(controls.voice,voiceLabel,5)

    controls.voice:SetScript("OnClick",function(self)
        if Addon.OptionsMenu.IsOpen(self) then
            hideDropdown()
        else
            openVoiceMenu(self)
        end
    end)

    controls.voiceWarning = createText(ttsPage,"No favourite voices selected. Add favourites from the Voice menu.",10,"warning")
    anchorBelow(controls.voiceWarning,controls.voice,4)
    controls.voiceWarning:Hide()

    controls.soundChannelLabel = createSectionLabel(ttsPage,"Sound Channel")

    controls.soundChannel = createDropdownButton(ttsPage)
    controls.soundChannel.text:SetText(getSoundChannelName(DB.ttsSoundChannel))

    controls.soundChannel:SetScript("OnClick",function(self)
        if Addon.OptionsMenu.IsOpen(self) then
            hideDropdown()
        else
            openSoundChannelMenu(self)
        end
    end)

	controls.soundChannelHint = createText(ttsPage,"Choose which sound channel the AI Voice uses.",10,"dim")
	controls.soundChannelNote = createText(ttsPage,"Note: Non-Master channels cannot play louder than your Master Volume setting.",10,"dim")

    controls.testLabel = createSectionLabel(ttsPage,"Test Voice")
    controls.testButton = createButton(ttsPage,"Play Test TTS",140)

    controls.testButton:SetScript("OnClick",function()
        FojjiCore:Speak(TEST_PHRASES[math.random(#TEST_PHRASES)])
    end)

    updateVoiceText()

    local fontPage = createPage("font","Font")
    local fontDescription = createText(fontPage,"Apply a font to your Fojji "..auraName..".",12,"dim")
    fontDescription:SetPoint("TOPLEFT",0,-50)

    local fontLabel = createSectionLabel(fontPage,"Font")
    fontLabel:SetPoint("TOPLEFT",0,-84)

    controls.font = createDropdownButton(fontPage)
    controls.font.text:SetText(DB.fontName)
    anchorBelow(controls.font,fontLabel,8)

    controls.font:SetScript("OnClick",function(self)
        if Addon.OptionsMenu.IsOpen(self) then
            hideDropdown()
        else
            openFontMenu(self)
        end
    end)

    local targetLabel = createSectionLabel(fontPage,"Apply To")
    anchorBelow(targetLabel,controls.font,18)

    controls.fontTarget = createDropdownButton(fontPage)
    anchorBelow(controls.fontTarget,targetLabel,8)
    controls.fontTarget.text:SetText(DB.fontTarget == "ALL" and "Apply to All" or DB.fontTarget)

    controls.fontTarget:SetScript("OnClick",function(self)
        if Addon.OptionsMenu.IsOpen(self) then
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

    local fontHint = createText(fontPage,"A /reload is required after applying a new font.",10,"dim")
    anchorBelow(fontHint,controls.applyFont,8)

    local aboutPage = createPage("about","About")

    local aboutLogo = aboutPage:CreateTexture(nil,"ARTWORK")
    aboutLogo:SetSize(68,68)
    aboutLogo:SetPoint("TOPLEFT",0,-82)
    aboutLogo:SetTexture(ICON)

    local aboutTitle = createText(aboutPage,"|cff66b3ffFojji|cffff4444Core|r",19)
    aboutTitle:SetPoint("LEFT",aboutLogo,"RIGHT",16,0)

    local addonInfoLabel = createSectionLabel(aboutPage,"Addon Information")
    anchorBelow(addonInfoLabel,aboutLogo,20)

    local interfaceVersion = select(4,GetBuildInfo())
    local info = createText(aboutPage,"FojjiCore Version:  |cffffffff"..(FojjiCore_Version or "Unknown").."|r\nInterface Version:  |cffffffff"..tostring(interfaceVersion or "Unknown").."|r",12)
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

    local discord = createLink("Fojji Discord","https://discord.gg/fojjiwow",linksLabel)
    local patreon = createLink("Patreon","https://www.patreon.com/c/fojjiwow",discord)
    createLink("Twitch","https://twitch.tv/fojjiwow",patreon)

    selectTab(defaultTab)
end

local function validateFontTarget()
    if DB.fontTarget == "ALL" then
        return
    end

    local data = AuraAPI.GetData(DB.fontTarget)

    if not data or not data.controlledChildren then
        DB.fontTarget = "ALL"
    end
end

function FojjiCore:ToggleOptions(tab)
    if not frame then
        return
    end

    if frame:IsShown() and tab and pages[tab] then
        selectTab(tab)
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
    controls.soundChannel.text:SetText(getSoundChannelName(DB.ttsSoundChannel))
    controls.minimap:SetChecked(not DB.minimap.hide)
    controls.disableTTS:SetChecked(DB.disableTTS)
    controls.font.text:SetText(DB.fontName)
    controls.fontTarget.text:SetText(DB.fontTarget == "ALL" and "Apply to All" or DB.fontTarget)

    updateVoiceText()
    updateMinimapVisibility()

    hideDropdown()
    selectTab((tab and pages[tab]) and tab or defaultTab)

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
    if not DB.optionsRevision or DB.optionsRevision < 9 then
        DB.theme = "ember"
        DB.optionsRevision = 9
    end
    if DB.optionsRevision < 10 then
        DB.windowWidth,DB.windowHeight = 880,620
        DB.optionsRevision = 10
    end
    applyTTSSettings()
    DB.windowScale = nil
    applyTheme(DB.theme)
    createOptions()
    createMinimapButton()
end)
