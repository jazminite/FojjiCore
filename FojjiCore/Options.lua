local _, Addon = ...
local AuraAPI = Addon.AuraAPI or WeakAuras
local function defaultTab() return Addon.CreateSpeedrunPage and "speedrun" or (Addon.AuraAPI and "tts") or "raidlead" end
Addon.Hidden = { raidpacks = true, raiddata = true }
local ICON = "Interface\\AddOns\\FojjiCore\\textures\\FojjiIcons\\F_icon_lightblue"
local NUMEN = "Interface\\AddOns\\FojjiCore\\font\\Numen.ttf"
local FONT = NUMEN

function Addon.ResolveUIFont(choice)
    if Addon.WideFont then return STANDARD_TEXT_FONT end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    choice = choice or (FojjiCoreDB and FojjiCoreDB.uiFont) or "auto"
    if choice == "auto" and FojjiCoreDB and FojjiCoreDB.theme == "wow" then return STANDARD_TEXT_FONT end
    if LSM then
        if choice == "auto" then
            return LSM:Fetch("font", "Expressway", true) or NUMEN
        end
        local path = LSM:Fetch("font", choice, true)
        if path then return path end
    end
    return NUMEN
end

local DB_VERSION = 2

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")

local COLORS = {
    accent = {0.40,0.70,1.00},
    accent2 = {0.55,0.40,1.00},
    panel = {0.14,0.142,0.15},
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
    width = 1180,
    height = 760,
    headerHeight = 60,
    sidebarWidth = 188,
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
    theme = "sunset",
    windowWidth = 1180,
    windowHeight = 760,
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
    auraScale = 1,
    scaleTarget = "ALL",
    anchorSizeSync = true,
    anchorAutoFit = false,
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
    {value = "Master", text = "Master", cvar = "Sound_MasterVolume"},
    {value = "SFX", text = "Sound Effects", cvar = "Sound_SFXVolume"},
    {value = "Music", text = "Music", cvar = "Sound_MusicVolume"},
    {value = "Ambience", text = "Ambience", cvar = "Sound_AmbienceVolume"},
    {value = "Dialog", text = "Dialog", cvar = "Sound_DialogVolume"},
}

local DB
local frame

local pages = {}
local tabs = {}
local controls = {}

local themeTextures = setmetatable({}, { __mode = "k" })
local themeFonts = setmetatable({}, { __mode = "k" })
local themeGlows = setmetatable({}, { __mode = "k" })
local THEME_ORDER = { "wow", "ember", "fojji", "arcane", "jade", "frost", "fel", "gold", "rose", "sunset", "void",
    "midnight", "bloodmoon", "storm", "worldtree", "abyss", "neon", "holy", "slate" }
local THEMES = {
    ember = { load = { "ej:moltencore", "ej:firelands1" }, name = "Ember", tag = "Warm forge glow", bg = { glow = { "bottomleft", 1.3, 0.120 }, glow2 = { "topright", 1.0, 0.060 } }, rgb = {1.00,0.30,0.26}, rgb2 = {1.00,0.62,0.20} },
    fojji = { load = { "wide:camelot160/main/loadscreen_camelot_easternkingdom", "ej:default" }, name = "Fojji", tag = "Soft azure light", bg = { glow = { "topright", 1.3, 0.096 }, glow2 = { "bottomleft", 1.0, 0.060 } }, rgb = {0.40,0.70,1.00}, rgb2 = {0.55,0.40,1.00} },
    arcane = { load = { "wide:camelot160/main/loadscreen_camelot_dalaran", "ej:violethold", "ej:thenexus" }, name = "Arcane", tag = "Violet light and stars", bg = { glow = { "topright", 1.3, 0.108 }, glow2 = { "bottomleft", 1.0, 0.060 } }, rgb = {0.70,0.48,1.00}, rgb2 = {0.35,0.75,1.00} },
    jade = { load = { "ej:zulgurub", "ej:templeofthejadeserpent" }, name = "Jade", tag = "Cool green light", bg = { glow = { "bottomright", 1.3, 0.096 }, glow2 = { "topleft", 1.0, 0.048 } }, rgb = {0.20,0.88,0.66}, rgb2 = {0.75,0.95,0.40} },
    frost = { load = { "ej:icecrowncitadel", "ej:utgardepinnacle", "ej:naxxramas" }, name = "Frost", tag = "Cold light and frost", bg = { glow = { "topleft", 1.3, 0.096 }, glow2 = { "bottomright", 1.0, 0.060 } }, rgb = {0.36,0.86,1.00}, rgb2 = {0.82,0.95,1.00} },
    fel = { load = { "ej:blacktemple", "ej:hellfirecitadel" }, name = "Fel", tag = "Green fel glow", bg = { glow = { "bottomleft", 1.3, 0.108 }, glow2 = { "topright", 1.0, 0.048 } }, rgb = {0.58,0.96,0.22}, rgb2 = {0.20,0.90,0.35} },
    gold = { load = { "ej:sunwellplateau", "ej:magisters terrace", "ej:magistersterrace-midnight" }, name = "Sunwell", tag = "Golden light", bg = { glow = { "topright", 1.4, 0.108 }, glow2 = { "bottomleft", 0.9, 0.048 } }, rgb = {1.00,0.78,0.30}, rgb2 = {1.00,0.52,0.20} },
    rose = { load = { "wide:camelot160/main/loadscreen_camelot_zephrasisle", "ej:terraceoftheendlessspring" }, name = "Blossom", tag = "Soft pink petals", bg = { glow = { "topright", 1.3, 0.096 }, glow2 = { "bottomleft", 1.1, 0.060 } }, rgb = {1.00,0.44,0.66}, rgb2 = {1.00,0.76,0.86} },
    sunset = { load = { "classic:loadscreenkalimdor" }, name = "Sunset", tag = "A low sun at dusk", bg = { glow = { "bottomright", 1.4, 0.120 }, glow2 = { "topleft", 1.1, 0.060 } }, rgb = {1.00,0.56,0.22}, rgb2 = {0.92,0.30,0.62} },
    void = { load = { "ej:voidspire", "ej:nyalotha", "ej:scholomance" }, name = "Void", tag = "Shadow and stars", bg = { glow = { "topright", 1.3, 0.096 }, glow2 = { "bottomleft", 1.2, 0.072 } }, rgb = {0.52,0.46,1.00}, rgb2 = {0.85,0.30,1.00}, base = -0.02, tint = 0.02 },
    midnight = { load = { "ej:midnight", "ej:darkwell", "ej:voidspire", "ej:nerubarpalace", "ej:scholomance" }, name = "Midnight", tag = "Xal'atath and the Void", bg = { glow = { "topright", 1.2, 0.084 }, glow2 = { "bottomleft", 1.0, 0.036 } }, rgb = {0.55,0.66,1.00}, rgb2 = {0.92,0.94,1.00}, base = -0.015 },
    bloodmoon = { load = { "ej:blackwinglair", "ej:onxyiaslair" }, name = "Blood Moon", tag = "Deep red glow", bg = { glow = { "topright", 1.3, 0.120 }, glow2 = { "bottomleft", 1.0, 0.048 } }, rgb = {0.95,0.16,0.22}, rgb2 = {1.00,0.42,0.30}, tint = 0.02 },
    storm = { load = { "ej:theemeraldnightmare", "ej:hallsoflightning" }, name = "Stormrage", tag = "Electric blue light", bg = { glow = { "topleft", 1.4, 0.096 }, glow2 = { "bottomright", 1.0, 0.060 } }, rgb = {0.30,0.80,1.00}, rgb2 = {0.72,0.58,1.00} },
    worldtree = { load = { "ej:emeralddream", "ej:wellofeternity", "ej:wailingcaverns" }, name = "World Tree", tag = "Hyjal greens and gold", bg = { glow = { "topright", 1.3, 0.096 }, glow2 = { "bottomleft", 1.1, 0.060 } }, rgb = {0.46,0.90,0.42}, rgb2 = {1.00,0.84,0.40} },
    abyss = { load = { "ej:throneofthetides", "ej:deadmines" }, name = "Abyss", tag = "Deep, still water", bg = { glow = { "bottomleft", 1.4, 0.096 }, glow2 = { "topright", 1.0, 0.060 } }, rgb = {0.16,0.86,0.76}, rgb2 = {0.30,0.52,1.00}, base = -0.01, tint = 0.02 },
    neon = { load = { "wide:camelot160/main/loadscreen_camelot_oldironforge", "ej:gnomeregan" }, name = "Neon", tag = "Pink and cyan glow", bg = { glow = { "bottomright", 1.3, 0.108 }, glow2 = { "topleft", 1.1, 0.072 } }, rgb = {1.00,0.28,0.80}, rgb2 = {0.20,0.88,1.00}, base = -0.01 },
    holy = { load = { "ej:trialofthecrusader", "ej:scarletmonastery" }, name = "Holy Light", tag = "Warm light from above", bg = { glow = { "topleft", 1.5, 0.108 }, glow2 = { "bottomright", 0.9, 0.036 } }, rgb = {1.00,0.86,0.52}, rgb2 = {1.00,1.00,0.92}, base = 0.02 },
    slate = { name = "Slate", tag = "Clean and plain - no art", rgb = {0.78,0.82,0.88}, rgb2 = {0.60,0.66,0.74} },
    wow = { load = { "classic:loadscreeneasternkingdom", "classic:loadscreenkalimdor" }, name = "WoW Classic", bg = { glow = { "topright", 1.2, 0.060 }, glow2 = { "bottomleft", 1.0, 0.036 } }, rgb = {1.00,0.82,0.12}, rgb2 = {0.82,0.64,0.16}, glowRgb = {0.90,0.52,0.20}, artRgb = {0.62,0.42,0.26}, tint = 0, blizzard = true },
}

local THEME_TEX = "Interface\\AddOns\\FojjiCore\\textures\\Themes\\"
local applyTheme
function applyTheme(key)
    local theme = THEMES[key] or THEMES.sunset
    local r,g,b = unpack(theme.rgb)
    COLORS.accent = {r,g,b}
    COLORS.accent2 = theme.rgb2 or {r,g,b}
    COLORS.title = {0.90,0.94,1}
    local k0, base = theme.tint or 0.012, theme.base or 0
    local function tint(v, k) k = k * (k0 / 0.012); return {v+base+r*k, v+base+g*k, v+base+b*k} end
    COLORS.frame = tint(0.070,0.012)
    COLORS.header = tint(0.085,0.020)
    COLORS.sidebar = tint(0.072,0.012)
    COLORS.content = tint(0.112,0.012)
    COLORS.panel = tint(0.140,0.012)
    COLORS.field = tint(0.078,0.010)
    COLORS.fieldHover = tint(0.100,0.020)
    COLORS.border = tint(0.235,0.040)
    COLORS.borderDim = tint(0.180,0.025)
    COLORS.button = tint(0.165,0.020)
    COLORS.buttonHover = tint(0.205,0.070)
    COLORS.text = {0.90,0.91,0.93}
    COLORS.dim = {0.64,0.66,0.70}
    COLORS.tab = {0.80,0.82,0.85}
    COLORS.tabHover = {1,1,1}
    COLORS.scroll = tint(0.180,0.020)
    if theme.blizzard then
        COLORS.frame, COLORS.header, COLORS.sidebar = {0.108,0.082,0.052}, {0.190,0.146,0.090}, {0.128,0.097,0.061}
        COLORS.content, COLORS.panel, COLORS.field = {0.118,0.090,0.057}, {0.165,0.127,0.080}, {0.075,0.057,0.036}
        COLORS.fieldHover, COLORS.button, COLORS.buttonHover = {0.120,0.092,0.058}, {0.215,0.165,0.102}, {0.280,0.215,0.132}
        COLORS.border, COLORS.borderDim, COLORS.scroll = {0.560,0.430,0.230}, {0.330,0.252,0.150}, {0.500,0.390,0.220}
        COLORS.title = {1.00,0.82,0.30}
        COLORS.text = {0.97,0.93,0.85}
        COLORS.dim = {0.74,0.66,0.54}
        COLORS.tab = {0.94,0.88,0.78}
    end
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
    if DB then DB.theme = THEMES[key] and key or "sunset" end
    if Addon.TintMinimapArc then Addon.TintMinimapArc() end
    if Addon.TintNodes then Addon.TintNodes() end
    if Addon.SpeedrunRefreshTheme then Addon.SpeedrunRefreshTheme() end
    if Addon.UIKit then Addon.UIKit.repaint() end
    local DJ = Addon.DJ
    if DJ and DJ.SyncTheme and DJ.Kit and DJ.SyncTheme() then DJ.Kit.Repaint() end
    if Addon.ApplyThemeFX then Addon.ApplyThemeFX(theme) end
end

local CORNER_TC = {
    topleft = { "TOPLEFT", 0.5, 1, 0.5, 1 }, topright = { "TOPRIGHT", 0, 0.5, 0.5, 1 },
    bottomleft = { "BOTTOMLEFT", 0.5, 1, 0, 0.5 }, bottomright = { "BOTTOMRIGHT", 0, 0.5, 0, 0.5 },
}
local function placeBackdrop(area, g1, g2, pat, theme, w, h, strength, yOff)
    strength = strength or 1
    yOff = yOff or 0
    local bg = theme.bg
    local function glow(t, spec, colorName)
        if not (bg and spec and CORNER_TC[spec[1]]) then t:Hide() return end
        local tc = CORNER_TC[spec[1]]
        local half = math.max(w, h) * (spec[2] or 1) / 2
        local fx, fy = math.min(1, w / half), math.min(1, h / half)
        t:SetTexture(THEME_TEX .. "glow-radial")
        t:SetBlendMode("ADD")
        local c = theme.glowRgb or (colorName == "accent2" and theme.rgb2) or theme.rgb
        t:SetVertexColor(c[1], c[2], c[3], (spec[3] or 0.12) * strength)
        t:ClearAllPoints()
        local bottom = tc[1]:find("BOTTOM")
        t:SetPoint(tc[1], area, tc[1], 0, bottom and yOff or 0)
        t:SetSize(half * fx, half * fy)
        local l, r, tp, b = tc[2], tc[3], tc[4], tc[5]
        if tc[1]:find("LEFT") then r = l + (r - l) * fx else l = r - (r - l) * fx end
        if bottom then tp = b - (b - tp) * fy else b = tp + (b - tp) * fy end
        t:SetTexCoord(l, r, tp, b)
        t:Show()
    end
    glow(g1, bg and bg.glow, "accent")
    glow(g2, bg and bg.glow2, "accent2")
    if bg and bg.pat then
        pat:SetTexture(THEME_TEX .. bg.pat[1], "REPEAT", "REPEAT")
        if pat.SetHorizTile then pat:SetHorizTile(true); pat:SetVertTile(true) end
        pat:SetTexCoord(0, w / 256, 0, h / 256)
        pat:SetBlendMode("ADD")
        local c = theme.rgb or COLORS.accent
        pat:SetVertexColor(c[1], c[2], c[3], bg.pat[2] * strength)
        pat:ClearAllPoints()
        pat:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
        pat:SetSize(w, h)
        pat:Show()
    else
        pat:Hide()
    end
end

local ART_KINDS = {
    ej = { path = "Interface\\EncounterJournal\\UI-EJ-LoreBg-", region = { 0, 0.76171875, 0, 0.849609375 }, aspect = 390 / 435, top = 0, focus = 0.35, alpha = 0.075 },
    wide = { path = "Interface\\Glues\\LoadingScreens\\", region = { 0, 1, 0, 1 }, aspect = 2, top = 0, focus = 0.5, alpha = 0.06 },
    classic = { path = "Interface\\Glues\\LoadingScreens\\", region = { 0, 1, 0, 1 }, aspect = 4 / 3, top = 0.3, focus = 0.6, alpha = 0.06 },
}
local artCache = {}
local artProbe

local function artExists(path)
    if GetFileIDFromPath then return GetFileIDFromPath(path) ~= nil end
    artProbe = artProbe or UIParent:CreateTexture(nil, "BACKGROUND")
    local ok = artProbe:SetTexture(path)
    artProbe:SetTexture(nil)
    return ok and true or false
end

local function resolveArt(theme)
    if artCache[theme] ~= nil then return artCache[theme] end
    local found = false
    for _, entry in ipairs(theme.load or {}) do
        local kind, name = entry:match("^(%a+):(.+)$")
        local spec = ART_KINDS[kind or ""]
        if spec then
            local path = spec.path .. name:gsub("/", "\\")
            if artExists(path) then
                found = setmetatable({ path = path }, { __index = spec })
                break
            end
        end
    end
    artCache[theme] = found
    return found
end

local function artCoords(art, w, h)
    w, h = math.max(1, w), math.max(1, h)
    local fw, fh = 1, 1
    if w / h > art.aspect then fh = art.aspect * h / w else fw = (w / h) / art.aspect end
    local room = 1 - art.top
    if fh > room then
        fw, fh = fw * room / fh, room
    end
    local x0 = (1 - fw) / 2
    local y0 = art.top + (room - fh) * art.focus
    local r = art.region
    local ru, rv = r[2] - r[1], r[4] - r[3]
    return r[1] + x0 * ru, r[1] + (x0 + fw) * ru, r[3] + y0 * rv, r[3] + (y0 + fh) * rv
end

local function tintArt(tex, theme, alpha)
    local c = theme.artRgb or theme.rgb
    if tex.SetDesaturation then tex:SetDesaturation(0.7) else tex:SetDesaturated(true) end
    tex:SetVertexColor(0.45 + c[1] * 0.55, 0.45 + c[2] * 0.55, 0.45 + c[3] * 0.55, alpha)
end

local function placeLore(tex, area, theme, w, h, strength)
    local art = Addon.IsForever and resolveArt(theme)
    if not art then tex:Hide() return end
    tex:SetTexture(art.path)
    tex:ClearAllPoints()
    tex:SetAllPoints(area)
    tex:SetTexCoord(artCoords(art, w, h))
    tintArt(tex, theme, math.min(0.16, art.alpha * (strength or 1)))
    tex:Show()
end
Addon.PlaceThemeLore = placeLore

local function buildThemeFX(panel, sidebar)
    local fx = { art = {} }
    for i = 1, 3 do
        fx.art[i] = panel:CreateTexture(nil, "BACKGROUND", nil, 4 + i)
        fx.art[i]:Hide()
    end
    fx.lore = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    fx.lore:Hide()
    fx.sideLore = sidebar:CreateTexture(nil, "BACKGROUND", nil, 1)
    fx.sideLore:SetAllPoints()
    fx.sideLore:Hide()
    local GRAD = "Interface\\AddOns\\FojjiCore\\textures\\UI\\grad-v"
    fx.shade = panel:CreateTexture(nil, "BACKGROUND", nil, 3)
    fx.shade:SetTexture(GRAD)
    fx.shade:SetPoint("BOTTOMLEFT"); fx.shade:SetPoint("BOTTOMRIGHT")
    fx.shade:SetTexCoord(0, 1, 1, 0)
    fx.fadeLeft = panel:CreateTexture(nil, "BACKGROUND", nil, 3)
    fx.fadeLeft:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\grad-h")
    fx.fadeLeft:SetPoint("TOPLEFT"); fx.fadeLeft:SetPoint("BOTTOMLEFT")
    fx.fadeLeft:Hide()
    fx.sideShade = sidebar:CreateTexture(nil, "BACKGROUND", nil, 2)
    fx.sideShade:SetTexture(GRAD)
    fx.sideShade:SetPoint("BOTTOMLEFT"); fx.sideShade:SetPoint("BOTTOMRIGHT")
    fx.sideShade:SetTexCoord(0, 1, 1, 0)
    fx.sideGlow = sidebar:CreateTexture(nil, "BACKGROUND", nil, 3)
    fx.sideGlow:SetTexture(GRAD)
    fx.sideGlow:SetPoint("BOTTOMLEFT"); fx.sideGlow:SetPoint("BOTTOMRIGHT"); fx.sideGlow:SetHeight(220)
    fx.sideGlow:SetTexCoord(0, 1, 1, 0)

    local function lore(theme)
        local art = Addon.IsForever and resolveArt(theme)
        if not art then
            fx.lore:Hide(); fx.sideLore:Hide(); fx.shade:Hide(); fx.sideShade:Hide(); fx.fadeLeft:Hide()
            return
        end
        local sw, pw = sidebar:GetWidth() or 188, panel:GetWidth() or 700
        local h = panel:GetHeight() or 560
        local total = sw + pw
        local l, r, t, b = artCoords(art, total, h)
        local split = l + (r - l) * sw / total
        fx.sideLore:SetTexture(art.path)
        fx.sideLore:SetTexCoord(l, split, t, b)
        tintArt(fx.sideLore, theme, art.alpha * 0.4)
        fx.sideLore:Show()
        fx.lore:SetTexture(art.path)
        fx.lore:ClearAllPoints()
        fx.lore:SetAllPoints(panel)
        fx.lore:SetTexCoord(split, r, t, b)
        tintArt(fx.lore, theme, art.alpha)
        fx.lore:Show()
        local cc, sc = COLORS.content, COLORS.sidebar
        fx.shade:SetHeight(h * 0.75)
        fx.shade:SetVertexColor(cc[1], cc[2], cc[3], 0.95)
        fx.shade:Show()
        fx.fadeLeft:SetWidth(pw * 0.55)
        fx.fadeLeft:SetVertexColor(cc[1], cc[2], cc[3], 0.9)
        fx.fadeLeft:Show()
        fx.sideShade:SetHeight(h * 0.7)
        fx.sideShade:SetVertexColor(sc[1], sc[2], sc[3], 0.95)
        fx.sideShade:Show()
    end

    function fx:Apply(theme)
        self.theme = theme
        local showArt = not (DB and DB.themeArt == false)
        if showArt and theme.bg then
            local w, h = panel:GetWidth() or 700, panel:GetHeight() or 560
            placeBackdrop(panel, self.art[1], self.art[2], self.art[3], theme, w, h - 48, 0.6, 48)
            lore(theme)
        else
            for _, t in ipairs(self.art) do t:Hide() end
            self.lore:Hide(); self.sideLore:Hide(); self.shade:Hide(); self.sideShade:Hide(); self.fadeLeft:Hide()
        end
        local c2 = theme.glowRgb or theme.rgb2 or theme.rgb
        self.sideGlow:SetVertexColor(c2[1], c2[2], c2[3], showArt and theme.bg and 0.05 or 0)
        if self.onTheme then self.onTheme(theme) end
    end

    panel:HookScript("OnSizeChanged", function() if fx.theme then fx:Apply(fx.theme) end end)
    return fx
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
    local font = Addon.Localize(parent:CreateFontString(nil,"OVERLAY"))
    font:SetFont(FONT,math.max(11,math.floor((size or 12)+0.5)),"")
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
    if Addon.Native and Addon.Skin then Addon.Skin.Rule(line, 0.6) end
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

    if Addon.Native and Addon.Skin and Addon.Skin.Button(button) then
        button.bg:Hide()
        for _,t in pairs(button.border) do t:Hide() end
        Addon.Skin.ButtonText(button.label,true,false)
        button:SetScript("OnEnter",function(self) Addon.Skin.ButtonText(self.label,true,true) end)
        button:SetScript("OnLeave",function(self) Addon.Skin.ButtonText(self.label,true,false) end)
        return button
    end

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
    local native = Addon.Native and Addon.Skin and Addon.Skin.Check(button, 22)
    if native then
        box:Hide()
        native:SetPoint("LEFT",-3,0)
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT",native,"RIGHT",4,1)
    end

    function button:SetChecked(value)
        self.checked = value and true or false
        self.check:SetShown(self.checked)
        if native then native:Set(self.checked, self:IsMouseOver()) end
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

    if Addon.UIKit then
        button.arrow = Addon.UIKit.Glyph(button,"icon-chevron-down",14,"dim")
        button.arrow:SetPoint("RIGHT",-10,0)
    else
        button.arrow = createText(button,"v",11)
        button.arrow:SetTextColor(0.65,0.68,0.72)
        button.arrow:SetPoint("RIGHT",-14,2)
    end

    if Addon.Native and Addon.Skin and Addon.Skin.Dropdown(button) then
        button.bg:Hide()
        for _,t in pairs(button.border) do t:Hide() end
        button.arrow:SetAlpha(0)
        button.text:SetPoint("RIGHT",-26,0)
        return button
    end

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
    if controls.systemCard then
        controls.systemCard:SetShown(not custom)
        controls.systemNote:Hide()
        controls.channelCard:SetShown(custom)
        if controls.ttsStack then controls.ttsStack:Layout() end
    end
end

local function updateVoiceText()
    local favoriteCount = getFavoriteVoiceCount()

    if DB.ttsRandomFavorites then
        controls.voice.text:SetText("Random Favourites")
        controls.voiceWarning:SetShown(favoriteCount == 0)
    elseif DB.ttsVoiceType == "custom" and DB.ttsVoicePack and FojjiCore.voicePacks and FojjiCore.voicePacks[DB.ttsVoicePack] then
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

    if next(FojjiCore.voicePacks or {}) then entries[#entries+1] = {
        text = "Random Favourites",
        selected = DB.ttsRandomFavorites,
        onClick = function()
            DB.ttsRandomFavorites = true
            DB.ttsVoiceType = "custom"
            applyTTSSettings()
            updateVoiceText()
        end,
    } end

    if FojjiCore.voicePacks and FojjiCore.voicePacks["Arabella"] then
        local name = "Arabella"

        entries[#entries+1] = {
            text = name,
            tag = "VOICE",
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
                tag = "VOICE",
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
                if controls.channelVolumeSync then controls.channelVolumeSync() end
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
    local groups, seen = {}, {}

    for _,groupName in ipairs(FojjiCore.fontPatchGroups or {}) do
        local found = FojjiCore.FindAuraName and FojjiCore:FindAuraName(groupName) or (AuraAPI and AuraAPI.GetData and AuraAPI.GetData(groupName) and groupName)

        if found and not seen[found] then
            seen[found] = true
            groups[#groups+1] = found
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
    if Addon.Hidden[name] or (name == "assignments" and Addon.Hidden.raiddata) or (name == "timeline" and Addon.Hidden.raidpacks) then name = defaultTab() end
    if DB and pages[name] then DB.lastTab = name end
    local page = pages[name]
    if frame and frame.pageTitle and page then
        frame.pageTitle:SetText(page.titleText or "")
        frame.pageSub:SetText(page.subText or "")
    end

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
        if active then button.glow:SetVertexColor(color("accent",0.28)) end
        button.label:SetTextColor(color(active and "white" or "tab"))
        if button.icon then button.icon:SetColorName(active and "accent" or "dim") end
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

local minimapArc
local function tintMinimapArc()
    if not minimapArc then return end
    local th = THEMES[DB and DB.theme] or THEMES.sunset
    minimapArc:SetVertexColor(th.rgb[1],th.rgb[2],th.rgb[3])
end

Addon.TintMinimapArc = function() tintMinimapArc() end

local function createMinimapButton()
    local launcher = LDB:NewDataObject("FojjiCore",{
        type = "launcher",
        text = "Fojji Core",
        icon = "Interface\\AddOns\\FojjiCore\\textures\\UI\\logo-small-base",
        iconCoords = {0,1,0,1},
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
    local button = DBIcon.GetMinimapButton and DBIcon:GetMinimapButton("FojjiCore")
    local icon = button and button.icon
    if icon and not minimapArc then
        minimapArc = button:CreateTexture(nil,"ARTWORK",nil,7)
        minimapArc:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\logo-small-arc")
        minimapArc:SetAllPoints(icon)
        minimapArc:SetTexCoord(icon:GetTexCoord())
        if type(icon.UpdateCoord) == "function" then
            hooksecurefunc(icon,"UpdateCoord",function(self) minimapArc:SetTexCoord(self:GetTexCoord()) end)
        end
        tintMinimapArc()
    end
    updateMinimapVisibility()
end

local function getAutoScale()
    local ui = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not ui or ui <= 0 then ui = 1 end
    return math.max(0.95, math.min(1.35, 0.57/ui))
end

local function applyOptionsScale()
    if frame then frame:SetScale((DB.optionsScale or 1)*getAutoScale()) end
end

local function createOptions()
    FONT = Addon.ResolveUIFont()
    if Addon.UIKit and Addon.UIKit.SetFontPath then Addon.UIKit.SetFontPath(FONT) end
    Addon.UIFont = FONT
    frame = CreateFrame("Frame","FojjiCoreOptionsFrame",UIParent)
    frame:SetScale((DB.optionsScale or 1)*getAutoScale())
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:SetScript("OnEvent",function() applyOptionsScale() end)
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
    local stopSizing
    grip:SetScript("OnMouseDown",function(_,button)
        if button ~= "LeftButton" then return end
        local left,top = frame:GetLeft(),frame:GetTop()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
        local startX,startY = GetCursorPosition()
        local startW,startH = frame:GetSize()
        local scale = frame:GetEffectiveScale()
        grip:SetScript("OnUpdate",function()
            if not IsMouseButtonDown("LeftButton") then stopSizing() return end
            local x,y = GetCursorPosition()
            local w = math.max(760,math.min(1440,startW+(x-startX)/scale))
            local h = math.max(540,math.min(1080,startH+(startY-y)/scale))
            frame:SetSize(w,h)
        end)
    end)
    stopSizing = function()
        if not grip:GetScript("OnUpdate") then return end
        grip:SetScript("OnUpdate",nil)
        DB.windowWidth,DB.windowHeight = frame:GetWidth(),frame:GetHeight()
    end
    grip:SetScript("OnMouseUp",stopSizing)
    frame:SetScript("OnHide",function() stopSizing(); hideDropdown() end)
    local frameBG = createTexture(frame,"BACKGROUND","frame",0.99)
    frameBG:SetAllPoints()

    createBorder(frame,"border",0.85)
    Addon.EscapeCloses("FojjiCoreOptionsFrame")
    do
        local TEX = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
        local SIZE, ALPHA = 14, 0.32
        local function piece(tex, l, r, t, b)
            local x = frame:CreateTexture(nil,"BACKGROUND",nil,-8)
            x:SetTexture(TEX..tex)
            x:SetVertexColor(0,0,0,ALPHA)
            x:SetTexCoord(l, r, t, b)
            return x
        end
        local e = piece("shadow-v", 0, 1, 0, 1)
        e:SetPoint("TOPLEFT", frame, "BOTTOMLEFT"); e:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT"); e:SetHeight(SIZE)
        e = piece("shadow-v", 0, 1, 1, 0)
        e:SetPoint("BOTTOMLEFT", frame, "TOPLEFT"); e:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT"); e:SetHeight(SIZE)
        e = piece("shadow-h", 0, 1, 0, 1)
        e:SetPoint("TOPLEFT", frame, "TOPRIGHT"); e:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT"); e:SetWidth(SIZE)
        e = piece("shadow-h", 1, 0, 0, 1)
        e:SetPoint("TOPRIGHT", frame, "TOPLEFT"); e:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT"); e:SetWidth(SIZE)
        local function corner(point, rel, l, r, t, b)
            local c = piece("shadow-corner", l, r, t, b)
            c:SetSize(SIZE, SIZE)
            c:SetPoint(point, frame, rel)
        end
        corner("BOTTOMRIGHT", "TOPLEFT", 0, 0.5, 0, 0.5)
        corner("BOTTOMLEFT", "TOPRIGHT", 0.5, 1, 0, 0.5)
        corner("TOPRIGHT", "BOTTOMLEFT", 0, 0.5, 0.5, 1)
        corner("TOPLEFT", "BOTTOMRIGHT", 0.5, 1, 0.5, 1)
    end

    local header = CreateFrame("Frame",nil,frame)
    header:SetPoint("TOPLEFT",1,-1)
    header:SetSize(LAYOUT.sidebarWidth,82)
    header:SetFrameLevel(frame:GetFrameLevel()+5)

    local headerBG = createArtwork(header,"header-metal","BACKGROUND")
    headerBG:SetAllPoints()
    headerBG:SetAlpha(0.55)

    local LOGO = "Interface\\AddOns\\FojjiCore\\textures\\FojjiIcons\\"
    local UITEX = "Interface\\AddOns\\FojjiCore\\textures\\UI\\"
    local halo = header:CreateTexture(nil,"BACKGROUND",nil,4)
    halo:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\Themes\\glow-radial")
    halo:SetBlendMode("ADD")
    halo:SetSize(84,84)
    local logo = header:CreateTexture(nil,"ARTWORK",nil,1)
    logo:SetSize(44,44)
    logo:SetPoint("LEFT",16,0)
    logo:SetTexture(LOGO.."F_logo_base_64")
    halo:SetPoint("CENTER",logo,"CENTER",0,0)
    local arc = header:CreateTexture(nil,"ARTWORK",nil,2)
    arc:SetAllPoints(logo)
    arc:SetTexture(LOGO.."F_logo_arc_64")
    local arcGlow = header:CreateTexture(nil,"ARTWORK",nil,0)
    arcGlow:SetPoint("TOPLEFT",logo,"TOPLEFT",-3,3)
    arcGlow:SetPoint("BOTTOMRIGHT",logo,"BOTTOMRIGHT",3,-3)
    arcGlow:SetTexture(LOGO.."F_logo_arc_64")
    arcGlow:SetBlendMode("ADD")

    local title = Addon.UIKit and Addon.UIKit.T(header,21,"white",nil,true) or createText(header,"",22)
    title:SetPoint("LEFT",logo,"RIGHT",11,8)

    local version = Addon.UIKit and Addon.UIKit.T(header,12,"dim",nil,true) or createText(header,"",10,"dim")
    version:SetText("v"..(FojjiCore_Version or "Unknown"):gsub("%-forever%.","."))
    version:SetPoint("LEFT",logo,"RIGHT",12,-11)

    local atmosphere = createArtwork(header,"header-light","BACKGROUND",true)
    atmosphere:SetAllPoints()
    atmosphere:SetAlpha(0.6)
    local sweep = header:CreateTexture(nil,"BACKGROUND",nil,3)
    sweep:SetTexture(UITEX.."grad-h")
    sweep:SetPoint("TOPLEFT"); sweep:SetPoint("BOTTOMLEFT"); sweep:SetWidth(LAYOUT.sidebarWidth)
    local crown = header:CreateTexture(nil,"BACKGROUND",nil,3)
    crown:SetTexture(UITEX.."grad-v")
    crown:SetPoint("TOPLEFT"); crown:SetPoint("TOPRIGHT"); crown:SetHeight(46)

    local function rule(parent, layer)
        local left = parent:CreateTexture(nil,layer or "ARTWORK")
        left:SetTexture("Interface\\Buttons\\WHITE8X8")
        local right = parent:CreateTexture(nil,layer or "ARTWORK")
        right:SetTexture("Interface\\Buttons\\WHITE8X8")
        local gem = parent:CreateTexture(nil,"OVERLAY")
        gem:SetTexture(UITEX.."ornament-diamond")
        gem:SetSize(14,14)
        left:SetHeight(1); right:SetHeight(1)
        left:SetPoint("RIGHT",gem,"CENTER",-6,0)
        right:SetPoint("LEFT",gem,"CENTER",6,0)
        return { left = left, right = right, gem = gem }
    end
    local function paintRule(r, c, a)
        a = a or 1
        if CreateColor and r.left.SetGradient then
            pcall(r.left.SetGradient, r.left, "HORIZONTAL", CreateColor(c[1],c[2],c[3],0), CreateColor(c[1],c[2],c[3],0.75*a))
            pcall(r.right.SetGradient, r.right, "HORIZONTAL", CreateColor(c[1],c[2],c[3],0.75*a), CreateColor(c[1],c[2],c[3],0))
        else
            r.left:SetVertexColor(c[1],c[2],c[3],0.5*a); r.right:SetVertexColor(c[1],c[2],c[3],0.5*a)
        end
        r.gem:SetVertexColor(c[1],c[2],c[3],a)
    end
    local headRule = rule(header)
    headRule.gem:SetPoint("CENTER",header,"BOTTOM",0,0)
    headRule.left:SetPoint("LEFT",header,"LEFT",10,0)
    headRule.right:SetPoint("RIGHT",header,"RIGHT",-10,0)
    frame.paintRule, frame.makeRule = paintRule, rule

    local corners = {}
    local chrome = CreateFrame("Frame",nil,frame)
    chrome:SetAllPoints()
    chrome:SetFrameLevel(frame:GetFrameLevel()+40)
    chrome:EnableMouse(false)
    local function bracket(point, sx, sy)
        local h = chrome:CreateTexture(nil,"OVERLAY",nil,6)
        local v = chrome:CreateTexture(nil,"OVERLAY",nil,6)
        h:SetTexture("Interface\\Buttons\\WHITE8X8"); v:SetTexture("Interface\\Buttons\\WHITE8X8")
        h:SetSize(22,2); v:SetSize(2,22)
        h:SetPoint(point,frame,point,0,0); v:SetPoint(point,frame,point,0,0)
        local g = chrome:CreateTexture(nil,"OVERLAY",nil,5)
        g:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\Themes\\glow-radial")
        g:SetBlendMode("ADD")
        g:SetSize(48,48)
        g:SetPoint(point,frame,point,0,0)
        local tc = CORNER_TC[point:lower()]
        g:SetTexCoord(tc[2],tc[3],tc[4],tc[5])
        corners[#corners+1] = { h = h, v = v, g = g, horiz = sx, vert = sy }
    end
    bracket("TOPLEFT",1,-1); bracket("TOPRIGHT",-1,-1); bracket("BOTTOMLEFT",1,1); bracket("BOTTOMRIGHT",-1,1)

    local function themeChrome()
        if Addon.Native then
            for _, t in ipairs({ halo, sweep, crown }) do t:Hide() end
            chrome:Hide()
        end
        local a1, a2 = COLORS.accent, COLORS.accent2 or COLORS.accent
        local hex = ("%02x%02x%02x"):format(math.floor(a1[1]*255+0.5), math.floor(a1[2]*255+0.5), math.floor(a1[3]*255+0.5))
        title:SetText("|cffffffffFojji|r|cff"..hex.."Core|r")
        arc:SetVertexColor(a1[1],a1[2],a1[3],1)
        arcGlow:SetVertexColor(a1[1],a1[2],a1[3],0.45)
        halo:SetVertexColor(a1[1],a1[2],a1[3],0.32)
        sweep:SetVertexColor(a1[1],a1[2],a1[3],0.16)
        crown:SetVertexColor(a2[1],a2[2],a2[3],0.10)
        paintRule(headRule, a1, 0.9)
        for _, c in ipairs(corners) do
            c.h:SetVertexColor(a1[1],a1[2],a1[3],0.85)
            c.v:SetVertexColor(a1[1],a1[2],a1[3],0.85)
            c.g:SetVertexColor(a1[1],a1[2],a1[3],0.14)
        end
        if frame.paintChrome then frame.paintChrome(a1, a2) end
    end
    if Addon.UIKit then Addon.UIKit.paint(themeChrome) else themeChrome() end
    frame.themeChrome = themeChrome

    local close = CreateFrame("Button",nil,frame)
    close:SetSize(30,30)
    close:SetPoint("TOPRIGHT",-16,-16)
    close:SetFrameLevel(frame:GetFrameLevel()+30)

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

    if Addon.Native then
        close.bg:Hide(); close.icon:Hide()
        for _, t in pairs(close.border) do if type(t) == "table" and t.Hide then t:Hide() end end
        close:SetSize(24,24)
        Addon.Skin.CloseButton(close)
        close:SetScript("OnEnter", nil)
        close:SetScript("OnLeave", nil)
        if Addon.Skin then Addon.Skin.Dialog(frame) end
    end
    close:SetScript("OnClick",function()
        hideDropdown()
        frame:Hide()
    end)

    do
        local minBtn = CreateFrame("Button",nil,frame)
        minBtn:SetSize(30,30)
        minBtn:SetPoint("RIGHT",close,"LEFT",-6,0)
        minBtn:SetFrameLevel(frame:GetFrameLevel()+30)
        minBtn.bg = minBtn:CreateTexture(nil,"BACKGROUND")
        minBtn.bg:SetAllPoints();minBtn.bg:SetColorTexture(.06,.065,.075,.7)
        minBtn.border = createBorder(minBtn,"border",0.5)
        minBtn.icon = createArtwork(minBtn,"icon-minus","ARTWORK")
        minBtn.icon:SetSize(16,16);minBtn.icon:SetPoint("CENTER");minBtn.icon:SetVertexColor(.8,.82,.86)
        minBtn:SetScript("OnEnter",function(self)
            self.bg:SetColorTexture(.12,.13,.15,.95)
            setBorderColor(self.border,"accent",0.7)
            self.icon:SetVertexColor(1,1,1)
            GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText("Minimize");GameTooltip:Show()
        end)
        minBtn:SetScript("OnLeave",function(self)
            self.bg:SetColorTexture(.06,.065,.075,.7)
            setBorderColor(self.border,"border",0.5)
            self.icon:SetVertexColor(.8,.82,.86)
            GameTooltip:Hide()
        end)
        if Addon.Native and Addon.Skin then
            minBtn.bg:Hide(); minBtn.icon:Hide()
            for _, t in pairs(minBtn.border) do if type(t) == "table" and t.Hide then t:Hide() end end
            minBtn:SetSize(24,24)
            Addon.Skin.MinimizeButton(minBtn)
            minBtn:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText("Minimize");GameTooltip:Show() end)
            minBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        frame.minBtn = minBtn

        local mini = CreateFrame("Button","FojjiCoreOptionsMini",UIParent)
        mini:SetSize(214,36)
        mini:SetFrameStrata("DIALOG")
        mini:SetFrameLevel(120)
        mini:SetClampedToScreen(true)
        mini:SetMovable(true)
        mini:EnableMouse(true)
        mini:RegisterForDrag("LeftButton")
        mini:RegisterForClicks("LeftButtonUp")
        mini.bg = mini:CreateTexture(nil,"BACKGROUND")
        mini.bg:SetAllPoints();mini.bg:SetColorTexture(.035,.038,.045,.96)
        mini.border = createBorder(mini,"border",0.8)
        mini.accent = mini:CreateTexture(nil,"ARTWORK")
        mini.accent:SetPoint("TOPLEFT",1,-1);mini.accent:SetPoint("BOTTOMLEFT",1,1);mini.accent:SetWidth(2)
        mini.accent:SetColorTexture(color("accent"))
        mini.logo = mini:CreateTexture(nil,"ARTWORK")
        mini.logo:SetTexture(ICON);mini.logo:SetSize(22,22);mini.logo:SetPoint("LEFT",10,0)
        mini.title = createText(mini,"FojjiCore",13,"white")
        mini.title:SetPoint("LEFT",mini.logo,"RIGHT",8,0)
        mini.hint = createText(mini,"click to open",11,"dim")
        mini.hint:SetPoint("LEFT",mini.title,"RIGHT",8,-1)
        local x = CreateFrame("Button",nil,mini)
        x:SetSize(22,22);x:SetPoint("RIGHT",-7,0)
        x.icon = createArtwork(x,"close-cross","ARTWORK")
        x.icon:SetSize(16,16);x.icon:SetPoint("CENTER");x.icon:SetVertexColor(.75,.45,.43)
        x:SetScript("OnEnter",function(self) self.icon:SetVertexColor(1,.8,.75) end)
        x:SetScript("OnLeave",function(self) self.icon:SetVertexColor(.75,.45,.43) end)
        x:SetScript("OnClick",function() mini:Hide() end)
        mini:SetScript("OnEnter",function(self) setBorderColor(self.border,"accent",0.8) end)
        mini:SetScript("OnLeave",function(self) setBorderColor(self.border,"border",0.8) end)
        mini:SetScript("OnDragStart",function(self) self.moved = true;self:StartMoving() end)
        mini:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        mini:Hide()
        frame.mini = mini

        local function screenTopRight(f)
            local right,top = f:GetRight(),f:GetTop()
            if not right or not top then return nil end
            local scale = f:GetEffectiveScale()
            return right*scale,top*scale
        end
        function frame.Minimize()
            hideDropdown()
            local x,y = screenTopRight(frame)
            mini:ClearAllPoints()
            if x then
                local s = mini:GetEffectiveScale()
                mini:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",x/s,y/s)
            else
                mini:SetPoint("CENTER")
            end
            frame:Hide()
            mini:Show()
        end
        function frame.Restore()
            if not mini:IsShown() then return end
            local x,y = screenTopRight(mini)
            mini:Hide()
            if x then
                local s = frame:GetEffectiveScale()
                frame:ClearAllPoints()
                frame:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",x/s,y/s)
            end
            frame:Show()
        end
        mini:SetScript("OnClick",function(self)
            if self.moved then self.moved = nil return end
            frame.Restore()
        end)
        minBtn:SetScript("OnClick",function() frame.Minimize() end)
        frame:HookScript("OnShow",function() mini:Hide() end)
    end

    local body = CreateFrame("Frame",nil,frame)
    body:SetPoint("TOPLEFT",1,-1)
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

    header:SetParent(sidebar)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT",sidebar,"TOPLEFT",0,0)
    header:SetFrameLevel(sidebar:GetFrameLevel()+5)
    close:SetParent(contentPanel)
    close:SetFrameLevel(contentPanel:GetFrameLevel()+30)
    local contentBG = createTexture(contentPanel,"BACKGROUND","content")
    contentBG:SetAllPoints()
    local grain = createArtwork(contentPanel,"panel-grain","BACKGROUND")
    grain:SetAllPoints()
    grain:SetAlpha(0.7)
    local contentMark = contentPanel:CreateTexture(nil,"BACKGROUND",nil,2)
    contentMark:SetTexture(ICON);contentMark:SetSize(220,220)
    contentMark:SetPoint("CENTER",0,-10);contentMark:SetAlpha(0.025)
    local topLight = contentPanel:CreateTexture(nil,"BACKGROUND",nil,3)
    topLight:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\grad-v")
    topLight:SetPoint("TOPLEFT");topLight:SetPoint("TOPRIGHT");topLight:SetHeight(120)
    topLight:SetVertexColor(1,1,1,0.035)
    local themeFX = buildThemeFX(contentPanel, sidebar)
    Addon.ApplyThemeFX = function(t) themeFX:Apply(t) end
    themeFX:Apply(THEMES[DB.theme] or THEMES.sunset)

    local pageTitle = Addon.UIKit and Addon.UIKit.T(contentPanel,20,"white",nil,true) or createText(contentPanel,"",20,"white")
    pageTitle:SetPoint("TOPLEFT",LAYOUT.contentPadding+2,-22)
    local pageSub = Addon.UIKit and Addon.UIKit.T(contentPanel,12,"dim",nil,true) or createText(contentPanel,"",12,"dim")
    pageSub:SetPoint("BOTTOMLEFT",pageTitle,"BOTTOMRIGHT",12,2)
    frame.pageTitle, frame.pageSub = pageTitle, pageSub
    local titleRule = createTexture(contentPanel,"ARTWORK","borderDim")
    titleRule:SetPoint("TOPLEFT",LAYOUT.contentPadding,-56)
    titleRule:SetPoint("TOPRIGHT",-LAYOUT.contentPadding,-56)
    titleRule:SetHeight(1)
    local titleGlow = contentPanel:CreateTexture(nil,"ARTWORK",nil,2)
    titleGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    titleGlow:SetPoint("TOPLEFT",titleRule,"TOPLEFT")
    titleGlow:SetHeight(1)
    titleGlow:SetWidth(360)
    local titleHaze = contentPanel:CreateTexture(nil,"BACKGROUND",nil,4)
    titleHaze:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\grad-v")
    titleHaze:SetTexCoord(0,1,1,0)
    titleHaze:SetPoint("BOTTOMLEFT",titleRule,"TOPLEFT",-LAYOUT.contentPadding,0)
    titleHaze:SetPoint("BOTTOMRIGHT",titleRule,"TOPRIGHT",LAYOUT.contentPadding,0)
    titleHaze:SetHeight(56)
    local sideEdge = sidebar:CreateTexture(nil,"BORDER")
    sideEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
    sideEdge:SetPoint("TOPRIGHT"); sideEdge:SetPoint("BOTTOMRIGHT"); sideEdge:SetWidth(1)
    frame.paintChrome = function(a1, a2)
        if CreateColor and titleGlow.SetGradient then
            pcall(titleGlow.SetGradient, titleGlow, "HORIZONTAL", CreateColor(a1[1],a1[2],a1[3],0.9), CreateColor(a1[1],a1[2],a1[3],0))
            pcall(sideEdge.SetGradient, sideEdge, "VERTICAL", CreateColor(a1[1],a1[2],a1[3],0.05), CreateColor(a1[1],a1[2],a1[3],0.35))
        else
            titleGlow:SetVertexColor(a1[1],a1[2],a1[3],0.6)
            sideEdge:SetVertexColor(a1[1],a1[2],a1[3],0.2)
        end
        titleHaze:SetVertexColor(a2[1],a2[2],a2[3],0.05)
    end
    if frame.themeChrome then frame.themeChrome() end
    if Addon.Native then
        titleHaze:Hide(); topLight:Hide(); grain:Hide()
        titleGlow:Hide()
        Addon.Skin.Rule(titleRule)
        sideEdge:SetVertexColor(0.52,0.43,0.28,0.8)
        if pageTitle.SetColorName then pageTitle:SetColorName("title") else pageTitle:SetTextColor(1,0.82,0) end
    end

    local footer = CreateFrame("Frame",nil,contentPanel)
    footer:SetPoint("BOTTOMLEFT");footer:SetPoint("BOTTOMRIGHT");footer:SetHeight(48)
    local footerBG = createTexture(footer,"BACKGROUND","sidebar",0.85)
    footerBG:SetAllPoints()
    local footerRule = createTexture(footer,"ARTWORK","borderDim")
    footerRule:SetPoint("TOPLEFT");footerRule:SetPoint("TOPRIGHT");footerRule:SetHeight(1)
    if Addon.UIKit then
        local K = Addon.UIKit
        local closeBtn = K.Button(footer,"Close",120,30)
        closeBtn:SetPoint("RIGHT",-LAYOUT.contentPadding,0)
        closeBtn:SetScript("OnClick",function() hideDropdown(); frame:Hide() end)
        local reloadBtn = K.Button(footer,"Reload UI",120,30)
        reloadBtn:SetPoint("RIGHT",closeBtn,"LEFT",-8,0)
        reloadBtn:SetScript("OnClick",function() ReloadUI() end)
        local SOCIAL = {
            { "social-paypal", "Donate", "https://www.paypal.com/donate/?hosted_button_id=6XBGL4AF4ZZ3A", "Buy Fojji a coffee through PayPal. Thank you!" },
            { "social-patreon", "Patreon", "https://www.patreon.com/c/fojjiwow", "Support FojjiCore on Patreon." },
            { "social-discord", "Fojji Discord", "https://discord.gg/fojjiwow", "Questions, ideas and bug reports." },
            { "social-twitch", "Twitch", "https://twitch.tv/fojjiwow", "Watch Fojji live." },
        }
        local anchorTo = reloadBtn
        for i, def in ipairs(SOCIAL) do
            local b = CreateFrame("Button",nil,footer)
            b:SetSize(30,30)
            b:SetPoint("RIGHT",anchorTo,"LEFT",i == 1 and -18 or -6,0)
            local g = b:CreateTexture(nil,"ARTWORK")
            g:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\"..def[1])
            g:SetSize(20,20)
            g:SetPoint("CENTER")
            g:SetDesaturated(true)
            g:SetAlpha(0.7)
            b:SetScript("OnEnter",function(self)
                g:SetDesaturated(false)
                g:SetAlpha(1)
                g:SetSize(23,23)
                GameTooltip:SetOwner(self,"ANCHOR_TOP")
                GameTooltip:SetText(def[2],1,1,1)
                GameTooltip:AddLine(def[4],0.8,0.8,0.8,true)
                GameTooltip:AddLine(def[3],0.5,0.5,0.5,true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function()
                g:SetDesaturated(true)
                g:SetAlpha(0.7)
                g:SetSize(20,20)
                GameTooltip:Hide()
            end)
            b:SetScript("OnClick",function() K.CopyBox(def[2], def[3], "Press Ctrl+C, then paste it in your browser.") end)
            anchorTo = b
        end
        local fhint = K.T(footer,12,"dim")
        fhint:SetPoint("LEFT",LAYOUT.contentPadding,0)
        fhint:SetText("Type |cffffffff/fc|r to open this window")
    end

    local divider = createTexture(body,"ARTWORK","border")
    divider:SetPoint("TOPLEFT",sidebar,"TOPRIGHT")
    divider:SetPoint("BOTTOMLEFT",sidebar,"BOTTOMRIGHT")
    divider:SetWidth(1)

    local content = CreateFrame("Frame",nil,contentPanel)
    content:SetPoint("TOPLEFT",LAYOUT.contentPadding,-68)
    content:SetPoint("BOTTOMRIGHT",-LAYOUT.contentPadding,60)

    local SUBTITLES = {
        raidpacks = "Timers, alerts, sounds and colours",
        timeline = "Recorded boss pulls",
        groupsetups = "Setups and builder",
        assignments = "Assignments, cooldowns, maps and roster for the raid",
        raidlead = "Versions, invites, roles, attendance and loot",
        speedrun = "Splits, best times and history",
        dungeonjournal = "Bosses, loot, maps, quests and routes",
        djsettings = "Display, group sharing and your data",
        worldroutes = "Routes, map pins and /way waypoints",
        guide = "Hidden quest chain with a step-by-step route",
        spellranks = "Spell ranks, training, action bar and talent reminders",
        bis = "Your best gear for every slot, and where it drops",
        tts = "Voice and sound channel",
        font = "One font for all your Fojji packs",
        general = "Theme, font, window and minimap",
        modules = "Turn FojjiCore's parts on or off",
        about = "Version, links and commands",
    }
    local function createPage(name,titleText)
        local page = CreateFrame("Frame",nil,content)
        page:SetPoint("TOPLEFT",content,"TOPLEFT",0,50)
        page:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",0,0)
        page:Hide()
        page.titleText, page.subText = titleText, SUBTITLES[name] or ""
        pages[name] = page
        return page
    end

    local sideScroll = CreateFrame("ScrollFrame",nil,sidebar)
    sideScroll:SetPoint("TOPLEFT",0,-90)
    sideScroll:SetPoint("BOTTOMRIGHT",0,36)
    do
        local row = CreateFrame("Frame",nil,sidebar)
        row:SetPoint("BOTTOMLEFT",18,12)
        row:SetPoint("BOTTOMRIGHT",-18,12)
        row:SetHeight(16)
        row:EnableMouse(true)
        local pct = createText(row,"100%",11,"dim")
        pct:SetPoint("RIGHT",0,0)
        pct:SetJustifyH("RIGHT")
        pct:SetWidth(34)
        local s = CreateFrame("Slider",nil,row)
        s:SetPoint("LEFT",0,0)
        s:SetPoint("RIGHT",pct,"LEFT",-8,0)
        s:SetHeight(16)
        s:SetOrientation("HORIZONTAL")
        s:SetMinMaxValues(30,100)
        s:SetValueStep(5)
        s:SetObeyStepOnDrag(true)
        s:EnableMouseWheel(true)
        local track = createTexture(s,"BACKGROUND","borderDim",0.9)
        track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(1)
        local fill = createTexture(s,"ARTWORK","accent",0.45)
        fill:SetPoint("LEFT"); fill:SetHeight(1)
        local thumb = s:CreateTexture(nil,"OVERLAY")
        thumb:SetColorTexture(1,1,1,0.8)
        thumb:SetSize(3,10)
        s:SetThumbTexture(thumb)
        row:SetAlpha(0.55)
        local function show(v)
            pct:SetText(math.floor(v+0.5).."%")
            local w = s:GetWidth() or 0
            fill:SetWidth(math.max(1, w*(v-30)/70))
        end
        local function hover(on)
            row:SetAlpha(on and 1 or 0.55)
            if on then
                GameTooltip:SetOwner(row,"ANCHOR_TOP")
                GameTooltip:SetText("Window opacity",1,1,1)
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
        row:SetScript("OnEnter",function() hover(true) end)
        row:SetScript("OnLeave",function() hover(false) end)
        s:SetScript("OnEnter",function() hover(true) end)
        s:SetScript("OnLeave",function() hover(false) end)
        s:SetScript("OnValueChanged",function(_,v,user)
            v = math.floor(v/5+0.5)*5
            show(v)
            if not user then return end
            DB.winAlpha = v/100
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
            frame:SetAlpha(DB.winAlpha)
        end)
        s:SetScript("OnMouseWheel",function(self,d)
            local v = math.max(30,math.min(100,(self:GetValue() or 100)+d*5))
            self:SetValue(v)
            DB.winAlpha = v/100
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
            frame:SetAlpha(DB.winAlpha)
        end)
        s:SetScript("OnSizeChanged",function() show(s:GetValue() or 100) end)
        frame.alphaSlider = { SetValue = function(_,v) s:SetValue(v); show(v) end }
    end
    local sideBody = CreateFrame("Frame",nil,sideScroll)
    sideBody:SetSize(LAYOUT.sidebarWidth,10)
    sideScroll:SetScrollChild(sideBody)
    sideScroll:EnableMouseWheel(true)
    sideScroll:SetScript("OnMouseWheel",function(self,delta)
        local range = math.max(0,(sideBody:GetHeight() or 0)-(self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0,math.min(range,self:GetVerticalScroll()-delta*34)))
    end)

    local function createTab(name,text,y)
        local button = CreateFrame("Button",nil,sideBody)
        button:SetSize(LAYOUT.sidebarWidth,34)
        button:SetPoint("TOPLEFT",0,y)

        button.glow = button:CreateTexture(nil,"BACKGROUND")
        button.glow:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\grad-h")
        button.glow:SetVertexColor(color("accent",0.28))
        button.glow:SetAllPoints()
        button.glow:Hide()

        button.indicator = createTexture(button,"ARTWORK","accent")
        button.indicator:SetPoint("TOPLEFT")
        button.indicator:SetPoint("BOTTOMLEFT")
        button.indicator:SetWidth(3)
        button.indicator:Hide()

        local NAV_SLOT = { ["nav-worldroutes"] = 0, ["nav-dungeonjournal"] = 1, ["nav-djsettings"] = 2, ["nav-guide"] = 3, ["nav-spellranks"] = 4, ["nav-plan"] = 5, ["icon-raid"] = 6, ["icon-export"] = 7, ["icon-palette"] = 8, ["nav-raidlead"] = 9, ["icon-timeline"] = 10, ["nav-speedrun"] = 11, ["nav-tts"] = 12, ["nav-font"] = 13, ["nav-scale"] = 14, ["icon-spark"] = 15, ["nav-general"] = 16, ["nav-about"] = 17, ["nav-modules"] = 18 }
        local NAV_COUNT = 19
        local TAB_ICONS = { worldroutes = "nav-worldroutes", dungeonjournal = "nav-dungeonjournal", djsettings = "nav-djsettings", guide = "nav-guide", spellranks = "nav-spellranks", bis = "nav-plan", raidpacks = "icon-raid", groupsetups = "icon-export", assignments = "icon-palette", raidlead = "nav-raidlead", timeline = "icon-timeline", speedrun = "nav-speedrun", tts = "nav-tts",
            font = "nav-font", scale = "nav-scale", qol = "icon-spark", general = "nav-general", about = "nav-about", modules = "nav-modules" }
        if Addon.UIKit then
            button.label = Addon.UIKit.T(button,13,"tab",nil,true)
            button.label:SetText(text)
            if TAB_ICONS[name] then
                button.icon = Addon.UIKit.Glyph(button,TAB_ICONS[name],16,"dim")
                button.icon:SetPoint("LEFT",20,0)
                local slot = NAV_SLOT[TAB_ICONS[name]]
                if slot then
                    local icon = button.icon
                    if icon.SetSnapToPixelGrid then icon:SetSnapToPixelGrid(true) end
                    if icon.SetTexelSnappingBias then icon:SetTexelSnappingBias(0) end
                    local function crisp()
                        local _, h = GetPhysicalScreenSize()
                        local ppu = button:GetEffectiveScale() * (tonumber(h) or 1080) / 768
                        local n = math.max(14, math.min(40, math.floor(16 * ppu + 0.5)))
                        icon:SetSize(n / ppu, n / ppu)
                        if icon.navSize == n then return end
                        icon.navSize = n
                        icon:SetTexture("Interface\\AddOns\\FojjiCore\\textures\\UI\\nav\\nav-" .. n)
                        icon:SetTexCoord(slot / NAV_COUNT, (slot + 1) / NAV_COUNT, 0, 1)
                    end
                    crisp()
                    button:HookScript("OnShow", crisp)
                    button:HookScript("OnSizeChanged", crisp)
                end
            end
        else
            button.label = createText(button,text,13,"tab")
        end
        button.label:SetPoint("LEFT",button.icon and 44 or 26,0)

        button:SetScript("OnEnter",function(self)
            if not self.indicator:IsShown() then
                self.glow:SetVertexColor(1,1,1,0.06)
                self.glow:Show()
                self.label:SetTextColor(color("tabHover"))
                if self.icon then self.icon:SetColorName("text") end
            end
        end)

        button:SetScript("OnLeave",function(self)
            if not self.indicator:IsShown() then
                self.glow:Hide()
                self.label:SetTextColor(color("tab"))
                if self.icon then self.icon:SetColorName("dim") end
            else
                self.glow:SetVertexColor(color("accent",0.28))
            end
        end)

        button:SetScript("OnClick",function()
            selectTab(name)
        end)

        tabs[name] = button
    end

    local sidebarY = -10

    local headerCount = 0
    local function addSidebarHeader(text)
        headerCount = headerCount + 1
        if headerCount > 1 then
            local rule = createTexture(sideBody,"ARTWORK","borderDim",1)
            rule:SetPoint("TOPLEFT",16,sidebarY+6)
            rule:SetPoint("TOPRIGHT",-16,sidebarY+6)
            rule:SetHeight(1)
            if Addon.Native and Addon.Skin then Addon.Skin.Rule(rule, 0.6) end
            sidebarY = sidebarY-8
        end
        local label = Addon.UIKit and Addon.UIKit.T(sideBody,11,"accent",nil,true) or createText(sideBody,text,11)
        label:SetText(text:upper())
        label:SetPoint("TOPLEFT",18,sidebarY)
        sidebarY = sidebarY-24
    end

    local qolListed
    local function addTab(name,text)
        createTab(name,text,sidebarY)
        sidebarY = sidebarY-34
    end

    if Addon.CreateSpeedrunPage or Addon.CreateRaidPackPage or Addon.CreateGroupSetupPage or Addon.CreateAssignmentsPage then
        addSidebarHeader("Raid Tools")
        if Addon.CreateRaidPackPage and not Addon.Hidden.raidpacks then
            addTab("raidpacks","Raid Packs")
            if Addon.IsForever and Addon.CreateTimelinePage then addTab("timeline","Timeline Recorder") end
        end
        if Addon.CreateAssignmentsPage and not Addon.Hidden.raiddata then addTab("assignments","Raid Data") end
        if Addon.CreateRaidLeadPage then addTab("raidlead","Raid Management") end
        if Addon.CreateSpeedrunPage then
            addTab("speedrun","Speedrun Timer")
        end
        sidebarY = sidebarY-14
    end
    if Addon.CreateDungeonJournalPage and Addon.DJ and Addon.DJ.off then
        addSidebarHeader("Forever Tools")
        addTab("djsettings","Journal Settings")
        sidebarY = sidebarY-14
    elseif Addon.CreateDungeonJournalPage then
        addSidebarHeader("Forever Tools")
        addTab("dungeonjournal","Dungeon Journal")
        addTab("djsettings","Journal Settings")
        if Addon.CreateGearPage then addTab("bis","BiS Manager") end
        if Addon.CreateWorldRoutesPage then addTab("worldroutes","Routes & Pins") end
        if Addon.CreateSpellRanksPage then addTab("spellranks","Spells & Talents") end
        addTab("qol","Extra Features")
        qolListed = true
        sidebarY = sidebarY-14
    end
    if Addon.AuraAPI then
        addSidebarHeader(Addon.IsForever and "Fojji ForeverAuras" or "Fojji WeakAuras")
        addTab("tts","Audio & Voices")
        addTab("font","Aura Fonts")
        if FojjiCore.SetGroupScale then addTab("scale","Aura Scale") end
        sidebarY = sidebarY-14
    end
    addSidebarHeader("Settings")
    if not qolListed then addTab("qol","Extra Features") end
    addTab("general","Appearance")
    if Addon.IsForever then addTab("modules","Modules") end
    addTab("about","About")
    sideBody:SetHeight(-sidebarY+10)

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

    if Addon.CreateRaidPackPage then
        local uiKit = {
            Button = createButton, Text = createText, Texture = createTexture, Font = FONT,
            Checkbox = createCheckbox, Scroll = createScrollFrame,
            Menu = createDropdownMenu, DropdownButton = createDropdownButton,
            Panel = function(parent)
                local bg = createTexture(parent,"BACKGROUND","field")
                bg:SetAllPoints()
                createBorder(parent,"borderDim")
            end,
        }
        local raidPage = createPage("raidpacks","Raid Packs")
        local built, buildError = pcall(Addon.CreateRaidPackPage, raidPage, uiKit)
        if not built then Addon.Print("Raid Packs page failed to build: "..tostring(buildError)) end
        if Addon.IsForever and Addon.CreateTimelinePage then
            local timelinePage = createPage("timeline","Timeline Recorder")
            built, buildError = pcall(Addon.CreateTimelinePage, timelinePage, uiKit)
            if not built then Addon.Print("Timeline page failed to build: "..tostring(buildError)) end
        end
    end

    if Addon.CreateAssignmentsPage then
        local assignPage = createPage("assignments","Raid Data")
        local built, buildError = pcall(Addon.CreateAssignmentsPage, assignPage, { Scroll = createScrollFrame })
        if not built then Addon.Print("Assignments page failed to build: "..tostring(buildError)) end
    end

    if Addon.CreateRaidLeadPage then
        local leadPage = createPage("raidlead","Raid Management")
        local built, buildError = pcall(Addon.CreateRaidLeadPage, leadPage, { Scroll = createScrollFrame })
        if not built then Addon.Print("Raid Management page failed to build: "..tostring(buildError)) end
    end

    local K = Addon.UIKit
    local cardKit = { Scroll = createScrollFrame }

    if Addon.CreateDungeonJournalPage and Addon.DJ and Addon.DJ.off then
        local settingsPage = createPage("djsettings","Journal Settings")
        local built, buildError = pcall(Addon.CreateDungeonJournalPage, settingsPage, {
            Button = createButton, Text = createText, Texture = createTexture, Font = FONT,
            Checkbox = createCheckbox, Scroll = createScrollFrame,
        })
        if not built then Addon.Print("Journal settings page failed to build: "..tostring(buildError)) end
    elseif Addon.CreateDungeonJournalPage then
        local djPage = createPage("dungeonjournal","Dungeon Journal")
        if Addon.EmbedDungeonJournal then
            local embedded, embedError = pcall(Addon.EmbedDungeonJournal, djPage)
            if not embedded then Addon.Print("Dungeon Journal failed to build: "..tostring(embedError)) end
            djPage:HookScript("OnShow", function()
                local w, h = frame:GetWidth(), frame:GetHeight()
                if w < 1180 or h < 780 then
                    local left, top = frame:GetLeft(), frame:GetTop()
                    w, h = math.min(1440, math.max(w, 1180)), math.min(1080, math.max(h, 780))
                    frame:SetSize(w, h)
                    if left and top then
                        frame:ClearAllPoints()
                        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
                    end
                    DB.windowWidth, DB.windowHeight = w, h
                end
            end)
        end
        if Addon.CreateWorldRoutesPage then
            local routesPage = createPage("worldroutes","Routes & Pins")
            local guide = Addon.CreateGuidePage and Addon.DJ and Addon.DJ.Guides and Addon.DJ.Guides[1]
            local routesHost, guideHost = routesPage, nil
            if guide and Addon.UIKit and Addon.UIKit.SubTabs then
                local sub = Addon.UIKit.SubTabs(routesPage, { { "routes", "Routes & Pins" }, { "guide", guide.name } })
                routesHost, guideHost = sub.views.routes, sub.views.guide
                routesPage:HookScript("OnShow", function() sub:Select(sub.current) end)
                sub:Select("routes")
            end
            local made, makeError = pcall(Addon.CreateWorldRoutesPage, routesHost)
            if not made then Addon.Print("Routes page failed to build: "..tostring(makeError)) end
            if guideHost then
                local ok, guideError = pcall(Addon.CreateGuidePage, guideHost, guide)
                if not ok then Addon.Print("Guide page failed to build: "..tostring(guideError)) end
            end
        end
        if Addon.CreateSpellRanksPage then
            local ranksPage = createPage("spellranks","Spells & Talents")
            local made, makeError = pcall(Addon.CreateSpellRanksPage, ranksPage, {
                Button = createButton, Text = createText, Texture = createTexture, Font = FONT,
                Checkbox = createCheckbox, Scroll = createScrollFrame,
            })
            if not made then Addon.Print("Spell ranks page failed to build: "..tostring(makeError)) end
        end
        if Addon.CreateGearPage then
            local bisPage = createPage("bis","BiS Manager")
            local made, makeError = pcall(Addon.CreateGearPage, bisPage)
            if not made then Addon.Print("BiS Manager page failed to build: "..tostring(makeError)) end
        end
        local settingsPage = createPage("djsettings","Journal Settings")
        local built, buildError = pcall(Addon.CreateDungeonJournalPage, settingsPage, {
            Button = createButton, Text = createText, Texture = createTexture, Font = FONT,
            Checkbox = createCheckbox, Scroll = createScrollFrame,
        })
        if not built then Addon.Print("Journal settings page failed to build: "..tostring(buildError)) end
    end

    local function field(caption, widget, height)
        local f = CreateFrame("Frame")
        f.cap = K.Caption(f, caption)
        f.cap:SetPoint("TOPLEFT", 0, 0)
        widget:SetParent(f)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", 0, -17)
        if widget.fill ~= false then widget:SetPoint("RIGHT", 0, 0) end
        f.h = (height or 28) + 17
        f.widget = widget
        return f
    end
    local function note(text, colorName)
        local f = CreateFrame("Frame")
        f.t = K.T(f, 12, colorName or "dim")
        f.t:SetPoint("TOPLEFT"); f.t:SetPoint("RIGHT")
        f.t:SetWordWrap(true)
        f.t:SetJustifyV("TOP")
        f.t:SetText(text)
        f.h = 30
        return f
    end
    local function dropdown(onOpen)
        local d = K.Dropdown(UIParent, 200, onOpen)
        d.text = d.label
        return d
    end
    local function switch(label, onChange)
        local r = K.SwitchRow(UIParent, label, onChange)
        r.SetChecked = r.SetValue
        r.GetChecked = function(self) return self.switch.value end
        return r
    end

    local generalPage = createPage("general","Appearance")
    local gStack = K.CardStack(generalPage, -54, cardKit)

    local themeCard = gStack:Add(K.Card(generalPage, "Theme", "Colours, background art and effects for every FojjiCore window. Saved per account."))
    local function themeLabel(th)
        return ("|cff%02x%02x%02x%s|r  |cff8a8f98%s|r"):format(th.rgb[1] * 255, th.rgb[2] * 255, th.rgb[3] * 255, th.name, th.tag or "")
    end
    local preview = CreateFrame("Frame")
    preview:SetHeight(64)
    preview.bg = preview:CreateTexture(nil, "BACKGROUND")
    preview.bg:SetAllPoints()
    preview.bg:SetTexture(K.WHITE)
    preview.g1 = preview:CreateTexture(nil, "BACKGROUND", nil, 1)
    preview.g2 = preview:CreateTexture(nil, "BACKGROUND", nil, 2)
    preview.pat = preview:CreateTexture(nil, "BACKGROUND", nil, 3)
    preview.lore = preview:CreateTexture(nil, "BACKGROUND", nil, 4)
    preview.stripe = preview:CreateTexture(nil, "OVERLAY")
    preview.stripe:SetTexture(K.WHITE)
    preview.stripe:SetPoint("TOPLEFT"); preview.stripe:SetPoint("BOTTOMLEFT"); preview.stripe:SetWidth(3)
    preview.bd = K.Border(preview, "borderDim", 1)
    preview.name = K.T(preview, 15, "white")
    preview.name:SetPoint("TOPLEFT", 14, -14)
    preview.tag = K.T(preview, 11, "text")
    preview.tag:SetPoint("TOPLEFT", preview.name, "BOTTOMLEFT", 0, -5)
    function preview:Paint()
        local th = THEMES[DB.theme] or THEMES.sunset
        local w = self:GetWidth() or 400
        local br = 0.075 + (th.base or 0)
        self.bg:SetVertexColor(br + th.rgb[1] * 0.02, br + th.rgb[2] * 0.02, br + th.rgb[3] * 0.02, 1)
        placeBackdrop(self, self.g1, self.g2, self.pat, th, w, 64, 2.2)
        placeLore(self.lore, self, th, w, 64, 2.4)
        self.stripe:SetVertexColor(th.rgb[1], th.rgb[2], th.rgb[3], 1)
        self.name:SetText(th.name)
        self.tag:SetText(th.tag or "")
    end
    preview:SetScript("OnSizeChanged", function(self) self:Paint() end)
    local themeDD = K.Dropdown(UIParent, 260, function(self)
        local entries = {}
        for _, key in ipairs(THEME_ORDER) do
            local k = key
            entries[#entries + 1] = { text = themeLabel(THEMES[k]), selected = DB.theme == k, onClick = function()
                local was = DB.theme == "wow"
                applyTheme(k)
                if was ~= (k == "wow") then
                    Addon.Print(k == "wow" and "WoW Classic theme: type |cffffd100/reload|r to switch FojjiCore to the game's own buttons, frames and fonts."
                        or "Type |cffffd100/reload|r to leave the WoW Classic theme's look completely.")
                end
                self:SetText(themeLabel(THEMES[k]))
                preview:Paint()
            end }
        end
        createDropdownMenu(self, entries)
    end)
    themeDD:SetText(themeLabel(THEMES[DB.theme] or THEMES.sunset))
    themeCard:Add(field("Theme", themeDD), 45, 10)
    themeCard:Add(preview, 64, 14)
    local fxRow = CreateFrame("Frame")
    local artSwitch = K.SwitchRow(fxRow, "Background art", function(v) DB.themeArt = v; applyTheme(DB.theme) end)
    artSwitch:SetPoint("TOPLEFT", 0, 0); artSwitch:SetWidth(220)
    artSwitch:SetValue(DB.themeArt ~= false)
    themeCard:Add(fxRow, 24, 6)

    local windowCard = gStack:Add(K.Card(generalPage, "Window"))
    local scaleRow = CreateFrame("Frame")
    local scaleDD = K.Dropdown(scaleRow, 150, nil)
    scaleDD:SetPoint("TOPLEFT", 0, -17)
    local scaleCap = K.Caption(scaleRow, "Scale")
    scaleCap:SetPoint("TOPLEFT", 0, 0)
    local scaleReset = K.Button(scaleRow, "Reset", 70, 28)
    scaleReset:SetPoint("LEFT", scaleDD, "RIGHT", 8, 0)
    local scaleInfo = K.T(scaleRow, 12, "dim")
    scaleInfo:SetPoint("LEFT", scaleReset, "RIGHT", 12, 0)
    scaleInfo:SetPoint("RIGHT", 0, 0)
    local function setOptionsScale(value)
        DB.optionsScale = value
        scaleDD:SetText(("%d%%"):format(math.floor(value*100+0.5)))
        scaleInfo:SetText(("Auto-adjusted for your UI scale: x%.2f"):format(getAutoScale()))
        applyOptionsScale()
    end
    scaleDD:SetScript("OnClick",function(self)
        local entries = {}
        for percent = 70,160,10 do
            local value = percent/100
            entries[#entries+1] = { text = percent.."%", selected = math.abs(DB.optionsScale-value)<0.001, onClick = function() setOptionsScale(value) end }
        end
        createDropdownMenu(self,entries)
    end)
    scaleReset:SetScript("OnClick",function() hideDropdown(); setOptionsScale(1) end)
    setOptionsScale(DB.optionsScale or 1)
    windowCard:Add(scaleRow, 45)
    local winRow = CreateFrame("Frame")
    local resetWindow = K.Button(winRow, "Reset window", 130, 28)
    resetWindow:SetPoint("LEFT", 0, 0)
    resetWindow:SetScript("OnClick",function()
        frame:ClearAllPoints(); frame:SetPoint("CENTER")
        frame:SetSize(LAYOUT.width,LAYOUT.height)
        DB.windowWidth,DB.windowHeight = LAYOUT.width,LAYOUT.height
    end)
    local winHint = K.T(winRow, 12, "dim")
    winHint:SetPoint("LEFT", resetWindow, "RIGHT", 12, 0)
    winHint:SetPoint("RIGHT", 0, 0)
    winHint:SetText("Drag the bottom-right corner to resize.")
    windowCard:Add(winRow, 28)

    local fontCard = gStack:Add(K.Card(generalPage, "Interface font", "The font this window uses. Auto picks Expressway when ElvUI or EllesmereUI provide it, else Numen. Needs a /reload."))
    local uiFontDD = K.Dropdown(UIParent, 200, function(self)
        local entries = { { text = "Auto (Expressway if available)", selected = (DB.uiFont or "auto") == "auto",
            onClick = function() DB.uiFont = "auto"; self:SetText("Auto"); Addon.Print("Interface font changes after a /reload.") end } }
        for _, name in ipairs(getFonts()) do
            local n = name
            entries[#entries + 1] = { text = n, selected = DB.uiFont == n,
                onClick = function() DB.uiFont = n; self:SetText(n); Addon.Print("Interface font changes after a /reload.") end }
        end
        createDropdownMenu(self, entries)
    end)
    uiFontDD:SetText((DB.uiFont and DB.uiFont ~= "auto") and DB.uiFont or "Auto")
    fontCard:Add(field("Font", uiFontDD), 45, 6)

    local miniCard = gStack:Add(K.Card(generalPage, "Minimap"))
    controls.minimap = switch("Show minimap icon", function(checked)
        DB.minimap.hide = not checked
        updateMinimapVisibility()
    end)
    miniCard:Add(controls.minimap, 24)
    controls.minimap:SetChecked(not DB.minimap.hide)
    gStack:Layout()

    local qolPage = createPage("qol","Extra Features")
    local qScroll = createScrollFrame(qolPage)
    qScroll:SetPoint("TOPLEFT", 0, -50)
    qScroll:SetPoint("BOTTOMRIGHT", -18, 0)
    local qBody = CreateFrame("Frame", nil, qScroll)
    qBody:SetSize(640, 600)
    qScroll:SetScrollChild(qBody)
    qScroll:SetScript("OnSizeChanged", function(_, width) qBody:SetWidth(width) end)
    local qy = 0
    local qolRefresh = {}
    qolPage:HookScript("OnShow", function() for _, fn in ipairs(qolRefresh) do fn() end end)
    local function qSection(title)
        qy = qy + 12
        local label = createText(qBody, title, 12, "accent")
        label:SetPoint("TOPLEFT", 0, -qy)
        local line = createTexture(qBody, "ARTWORK", "borderDim")
        line:SetPoint("TOPLEFT", 0, -(qy + 17))
        line:SetPoint("TOPRIGHT", 0, -(qy + 17))
        line:SetHeight(1)
        qy = qy + 26
    end
    local function qCheck(text, get, set)
        local b = createCheckbox(qBody, text, function(v) set(v) end)
        b:SetWidth(600)
        b:SetPoint("TOPLEFT", 0, -qy)
        qolRefresh[#qolRefresh + 1] = function() b:SetChecked(get()) end
        qy = qy + 30
        return b
    end

    local V = Addon.Vendor
    local QT = Addon.DJ and Addon.DJ.QuestTrack
    local CH = Addon.Games and Addon.Games.Chess

    qSection("Combat text font")
    local combatDD = K.Dropdown(qBody, 220, function(self)
        local entries = { { text = "Game default", selected = not DB.combatFont,
            onClick = function()
                DB.combatFont, DB.combatFontPath = nil, nil
                self:SetText("Game default")
                Addon.Print("Combat text font: back to the game's font after you log out and back in.")
            end } }
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        for _, name in ipairs(getFonts()) do
            local n = name
            entries[#entries + 1] = { text = n, selected = DB.combatFont == n, onClick = function()
                local path = LSM and LSM:Fetch("font", n, true)
                if not path then return end
                DB.combatFont, DB.combatFontPath = n, path
                self:SetText(n)
                Addon.Print("Combat text font set to " .. n .. ". Log out and back in to see it.")
            end }
        end
        createDropdownMenu(self, entries)
    end)
    combatDD:SetText(DB.combatFont or "Game default")
    combatDD:SetPoint("TOPLEFT", 0, -qy)
    local combatNote = createText(qBody, "Takes effect after you log out and back in.", 10, "dim")
    combatNote:SetPoint("LEFT", combatDD, "RIGHT", 12, 0)
    qy = qy + 40

    if QT then
        qSection("Dungeons")
        qCheck("Track only the dungeon's quests while I'm inside", QT.On, QT.Set)
    end

    if V then
        qSection("Invites")
        qCheck("Show a FojjiCore button to disband or invite my group", V.PartyOn, V.SetParty)
        local namesLabel = createText(qBody, "Players to invite (separate multiple names by comma)", 11, "dim")
        namesLabel:SetPoint("TOPLEFT", 0, -qy)
        qy = qy + 18
        local names = K.Input(qBody, function(v) V.SetPartyNames(v) end)
        names:SetPoint("TOPLEFT", 0, -qy)
        names:SetWidth(420)
        names.box:SetMaxLetters(255)
        qolRefresh[#qolRefresh + 1] = function() names:SetValue(FojjiCoreDB.partyNames or "") end
        qy = qy + 40
        qCheck("Auto accept group invites from guildies", V.GuildInviteOn, function(on) FojjiCoreDB.guildAccept = on and true or nil end)

        qSection("Levelling / Questing")
        qCheck("Show kills to level on enemy tooltips", V.KillsOn, function(on) FojjiCoreDB.killsTip = on and true or nil end)
        qCheck("Take a screenshot when I reach the level cap", V.ShotOn, function(on) FojjiCoreDB.capScreenshot = on and true or nil end)
        qCheck("Loot sparkles on quest items (turns outline mode off; requires a restart)", V.SparkleOn, function(on)
            FojjiCoreDB.lootSparkles = on and true or false
            V.ApplySparkle()
        end)

        qSection("Transmog")
        qCheck("Show whether I have an item's appearance on its tooltip", V.TransmogOn, function(on) FojjiCoreDB.transmogTip = on and true or false end)

        qSection("Vendors")
        qCheck("Sell grey items", V.SellOn, function(on) FojjiCoreDB.autoSell = on and true or nil end)
        qCheck("Repair my gear", V.RepairOn, function(on) FojjiCoreDB.autoRepair = on and true or nil end)
        qCheck("Use guild bank money for repairs", V.GuildOn, function(on) FojjiCoreDB.autoRepairGuild = on and true or false end)
    end

    if CH then
        qSection("Games")
        qCheck("Show the games card while I'm on a flight path", CH.FlightButtonOn, function(on)
            FojjiCoreDB.chessFlight = on and true or false
            if CH.ApplyFlight then CH.ApplyFlight() end
        end)
        qCheck("Hide games when I enter combat", CH.CombatHideOn, function(on)
            FojjiCoreDB.chessCombatHide = on and true or false
            if CH.Rewatch then CH.Rewatch() end
        end)
        qCheck("Pop up when someone challenges me to chess (otherwise just a line in chat; never in combat)", CH.PopupsOn, function(on) FojjiCoreDB.chessPopups = on and true or nil end)
    end
    qBody:SetHeight(qy + 20)

    local ttsPage = createPage("tts","Audio & Voices")
    local tStack = K.CardStack(ttsPage, -54, cardKit)
    controls.ttsStack = tStack

    local voiceCard = tStack:Add(K.Card(ttsPage, "Voice", (Addon.IsForever and "The voice used by Fojji ForeverAuras and Raiding Packs." or "The voice used by Fojji WeakAuras and Raiding Packs.")))
    controls.disableTTS = switch("Disable all voice", function(checked) DB.disableTTS = checked end)
    voiceCard:Add(controls.disableTTS, 24, 12)
    controls.disableTTS:SetChecked(DB.disableTTS)
    controls.voice = dropdown(function(self)
        if Addon.OptionsMenu.IsOpen(self) then hideDropdown() else openVoiceMenu(self) end
    end)
    voiceCard:Add(field("Voice", controls.voice), 45, 6)
    local warn = note("No favourite voices selected. Add favourites from the Voice menu.", "warning")
    controls.voiceWarning = warn.t
    warn.t.SetShown = function(t, v) warn:SetShown(v); voiceCard:Restack(); tStack:Layout() end
    warn.t.Hide = function(t) t:SetShown(false) end
    warn.t.Show = function(t) t:SetShown(true) end
    voiceCard:Add(warn, 18, 8)
    warn:Hide()
    local testRow = CreateFrame("Frame")
    controls.testButton = K.Button(testRow, "Play test line", 130, 28, "primary")
    controls.testButton:SetPoint("LEFT", 0, 0)
    controls.testButton:SetScript("OnClick",function() FojjiCore:Speak(TEST_PHRASES[math.random(#TEST_PHRASES)]) end)
    local packsLink = K.Button(testRow, "Get FojjiCore - Voice Packs", 210, 28, nil, "icon-link")
    packsLink:SetPoint("LEFT", controls.testButton, "RIGHT", 8, 0)
    packsLink:SetScript("OnClick", function()
        K.CopyBox("FojjiCore - Voice Packs", "https://www.curseforge.com/wow/addons/fojjicore-voicepacks", "Press Ctrl+C, then paste it in your browser.")
    end)
    K.Tip(packsLink, "FojjiCore - Voice Packs", "Recorded voices for every Fojji "..(Addon.IsForever and "ForeverAuras" or "WeakAuras").." pack. Click to copy the download link.")
    voiceCard:Add(testRow, 28)

    local channelCard = tStack:Add(K.Card(ttsPage, "Sound channel", "The channel voice packs play on."))
    controls.channelCard = channelCard
    controls.soundChannel = dropdown(function(self)
        if Addon.OptionsMenu.IsOpen(self) then hideDropdown() else openSoundChannelMenu(self) end
    end)
    channelCard:Add(field("Channel", controls.soundChannel), 45, 12)
    controls.soundChannel.text:SetText(getSoundChannelName(DB.ttsSoundChannel))
    do
        local function channelData()
            for _,c in ipairs(SOUND_CHANNELS) do if c.value == DB.ttsSoundChannel then return c end end
            return SOUND_CHANNELS[1]
        end
        local syncing = false
        controls.channelVolume = K.Slider(UIParent, "Volume", 0, 100, 1, function(value)
            if syncing then return end
            local c = channelData()
            SetCVar(c.cvar, math.floor(value+0.5)/100)
        end, function(v) return tostring(math.floor(v+0.5)) end)
        controls.channelVolume.container = controls.channelVolume
        channelCard:Add(controls.channelVolume, 46, 4)
        local hint = note("")
        channelCard:Add(hint, 18)
        controls.channelVolumeSync = function()
            local c = channelData()
            syncing = true
            controls.channelVolume:SetValue((tonumber(GetCVar(c.cvar)) or 1)*100)
            syncing = false
            hint.t:SetText("The game's "..c.text.." volume (also in Options > Sound).")
        end
        controls.channelVolumeSync()
        ttsPage:HookScript("OnShow", controls.channelVolumeSync)
    end

    local systemCard = tStack:Add(K.Card(ttsPage, "System voice", "Volume and speed for text-to-speech (system) voices."))
    controls.systemCard = systemCard
    local sysNote = note("Only used by system voices - a voice pack is selected.")
    controls.systemNote = sysNote
    systemCard:Add(sysNote, 18, 8)
    controls.volume = K.Slider(UIParent, "Volume", 0, 100, 1, function(value)
        DB.ttsVolume = math.floor(value+0.5)
        applyTTSSettings()
    end, function(v) return tostring(math.floor(v+0.5)) end)
    controls.volume.container = controls.volume
    systemCard:Add(controls.volume, 46, 12)
    controls.rate = K.Slider(UIParent, "Speech rate", -10, 10, 0.1, function(value)
        DB.ttsRate = math.floor(value*10+0.5)/10
        applyTTSSettings()
    end, function(v) return string.format("%.1f", v) end)
    controls.rate.container = controls.rate
    systemCard:Add(controls.rate, 46)
    controls.volume:SetValue(DB.ttsVolume)
    controls.rate:SetValue(DB.ttsRate)
    controls.volume.valueText = controls.volume.value
    controls.rate.valueText = controls.rate.value
    updateVoiceText()
    tStack:Layout()

    local fontPage = createPage("font","Aura Fonts")
    local fStack = K.CardStack(fontPage, -54, cardKit)
    local fontCard = fStack:Add(K.Card(fontPage, "Aura font", "Changes the font in every Fojji "..(Addon.IsForever and "ForeverAuras" or "WeakAuras").." pack you have installed. Needs a /reload."))
    controls.font = dropdown(function(self)
        if Addon.OptionsMenu.IsOpen(self) then hideDropdown() else openFontMenu(self) end
    end)
    controls.font.text:SetText(DB.fontName)
    fontCard:Add(field("Font", controls.font), 45, 12)
    controls.fontTarget = dropdown(function(self)
        if Addon.OptionsMenu.IsOpen(self) then hideDropdown() else openFontTargetMenu(self) end
    end)
    controls.fontTarget.text:SetText(DB.fontTarget == "ALL" and "Apply to All" or DB.fontTarget)
    fontCard:Add(field("Apply to", controls.fontTarget), 45, 14)
    local applyRow = CreateFrame("Frame")
    controls.applyFont = K.Button(applyRow, "Apply font", 130, 28, "primary")
    controls.applyFont:SetPoint("LEFT", 0, 0)
    controls.applyFont.confirming = false
    controls.applyFont.confirmationID = 0
    controls.applyFont:SetScript("OnClick",function(self)
        if not self.confirming then
            self.confirming = true
            self.confirmationID = self.confirmationID+1
            local confirmationID = self.confirmationID
            self.label:SetText("Are you sure?")
            self:SetKind("danger")
            C_Timer.After(5,function()
                if self.confirming and self.confirmationID == confirmationID then
                    self.confirming = false
                    self.label:SetText("Apply font")
                    self:SetKind("primary")
                end
            end)
            return
        end
        self.confirming = false
        self.confirmationID = self.confirmationID+1
        self.label:SetText("Apply font")
        self:SetKind("primary")
        if DB.fontTarget == "ALL" then
            FojjiCore:PatchFontForAll(DB.fontName)
        else
            FojjiCore:PatchFontForGroup(DB.fontTarget,DB.fontName)
        end
    end)
    local applyHint = K.T(applyRow, 12, "dim")
    applyHint:SetPoint("LEFT", controls.applyFont, "RIGHT", 12, 0)
    applyHint:SetText("Click twice to confirm, then /reload.")
    fontCard:Add(applyRow, 28)

    local fontList = fStack:Add(K.Card(fontPage, "Installed packs"))
    local fontRows = CreateFrame("Frame")
    fontRows.rows = {}
    fontList:Add(fontRows, 20, 4)
    local function refreshFonts()
        local list = getInstalledFontPatchGroups()
        for i, groupName in ipairs(list) do
            local row = fontRows.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, fontRows)
                row:SetHeight(20)
                row.name = K.T(row, 12, "text")
                row.name:SetPoint("LEFT", 0, 0)
                row.name:SetPoint("RIGHT", -180, 0)
                row.name:SetJustifyH("LEFT")
                row.value = K.T(row, 12, "white", "RIGHT")
                row.value:SetPoint("RIGHT", 0, 0)
                row.value:SetWidth(176)
                fontRows.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            row:SetPoint("RIGHT", 0, 0)
            row.name:SetText(groupName)
            row.value:SetText(FojjiCore.GetGroupFont and FojjiCore:GetGroupFont(groupName) or "-")
            row:Show()
        end
        for i = #list + 1, #fontRows.rows do fontRows.rows[i]:Hide() end
        if not fontRows.empty then
            fontRows.empty = K.T(fontRows, 12, "dim")
            fontRows.empty:SetPoint("TOPLEFT", 0, 0)
            fontRows.empty:SetText("No Fojji "..(Addon.IsForever and "ForeverAuras" or "WeakAuras").." packs installed.")
        end
        fontRows.empty:SetShown(#list == 0)
        local height = math.max(20, #list * 20)
        fontRows:SetHeight(height)
        for _, it in ipairs(fontList.items) do if it.w == fontRows then it.h = height end end
        fStack:Layout()
    end
    controls.applyFont:HookScript("OnClick", function() C_Timer.After(0, refreshFonts) end)
    fontPage:HookScript("OnShow", refreshFonts)
    fStack:Layout()

    local scalePage
    if FojjiCore.SetGroupScale then
        scalePage = createPage("scale","Aura Scale")
        local sStack = K.CardStack(scalePage, -54, cardKit)
        local function num(v)
            return (string.format("%.2f", tonumber(v) or 1):gsub("0+$", ""):gsub("%.$", ".0"))
        end
        local refreshScale

        local quick = sStack:Add(K.Card(scalePage, "Scale for your screen"))
        local function screenHeight()
            if GetPhysicalScreenSize then
                local _, h = GetPhysicalScreenSize()
                if tonumber(h) and tonumber(h) > 0 then return tonumber(h) end
            end
            local res = GetCVar and (GetCVar("gxFullscreenResolution") or GetCVar("gxWindowedResolution"))
            local h = res and tonumber(res:match("%d+x(%d+)"))
            return h or 1080
        end
        local quickRow = CreateFrame("Frame")
        local hiRes = K.Button(quickRow, "1440p / 4K  -  1.2", 170, 28)
        hiRes:SetPoint("LEFT", 0, 0)
        local loRes = K.Button(quickRow, "1080p  -  1.0", 150, 28)
        loRes:SetPoint("LEFT", hiRes, "RIGHT", 8, 0)
        local suggest = K.T(UIParent, 12, "dim")
        hiRes:SetScript("OnClick", function() DB.auraScale = 1.2; FojjiCore:SetScaleForAll(1.2); refreshScale() end)
        loRes:SetScript("OnClick", function() DB.auraScale = 1; FojjiCore:SetScaleForAll(1); refreshScale() end)
        K.Tip(hiRes, "1440p / 4K", "Sets every installed Fojji ForeverAuras pack to scale 1.2. Class UIs follow your anchors.")
        K.Tip(loRes, "1080p", "Sets every installed Fojji ForeverAuras pack to scale 1.0. Class UIs follow your anchors.")
        quick:Add(quickRow, 28, 8)
        local suggestRow = CreateFrame("Frame")
        suggest:SetParent(suggestRow); suggest:ClearAllPoints(); suggest:SetPoint("LEFT", 0, 0)
        quick:Add(suggestRow, 16, 6)

        if FojjiCore.SyncAnchorSizes then
            local anchorCard = sStack:Add(K.Card(scalePage, "Anchor sizes", "Resize an anchor in a Fojji anchors pack and the auras on it follow."))
            controls.anchorSizeSync = switch("Auras follow anchor sizes", function(v)
                DB.anchorSizeSync = v and true or false
                if v then FojjiCore:SyncAnchorSizes() end
            end)
            anchorCard:Add(controls.anchorSizeSync, 28, 8)
            controls.anchorAutoFit = switch("Automatically resize Auras added to Class UIs to Anchor sizes", function(v)
                DB.anchorAutoFit = v and true or false
                if v then FojjiCore:SyncAnchorSizes() end
            end)
            K.Tip(controls.anchorAutoFit, "Automatically resize Auras added to Class UIs to Anchor sizes", "On: an aura you drag into a class UI group takes its anchor's size straight away. Off: sizes only change when you resize the anchor itself.")
            anchorCard:Add(controls.anchorAutoFit, 28, 8)
            local syncRow = CreateFrame("Frame")
            local syncNow = K.Button(syncRow, "Match now", 130, 28)
            syncNow:SetPoint("LEFT", 0, 0)
            syncNow:SetScript("OnClick", function()
                if FojjiCore:SyncAnchorSizes(true, true) == 0 then
                    Addon.Print("Aura sizes already match your anchors.")
                else
                    Addon.Print("Aura sizes matched to your anchors.")
                end
            end)
            K.Tip(syncNow, "Match now", "Sizes every aura on your anchors now. Use this after importing a class UI or dragging auras into a group.")
            anchorCard:Add(syncRow, 28)
            scalePage:HookScript("OnShow", function()
                controls.anchorSizeSync:SetChecked(DB.anchorSizeSync ~= false)
                controls.anchorAutoFit:SetChecked(DB.anchorAutoFit == true)
            end)
        end

        local scaleCard = sStack:Add(K.Card(scalePage, "Fojji ForeverAuras scale"))
        controls.auraScale = K.Slider(UIParent, "Scale", FojjiCore.SCALE_MIN, FojjiCore.SCALE_MAX, 0.01, function(value)
            DB.auraScale = math.floor(value*100+0.5)/100
        end, num)
        scaleCard:Add(controls.auraScale, 46, 12)
        local function targetText()
            return DB.scaleTarget == "ALL" and "All installed packs" or DB.scaleTarget
        end
        controls.scaleTarget = dropdown(function(self)
            if Addon.OptionsMenu.IsOpen(self) then hideDropdown() return end
            local entries = {
                { text = "All installed packs", selected = DB.scaleTarget == "ALL", onClick = function()
                    DB.scaleTarget = "ALL"
                    controls.scaleTarget.text:SetText(targetText())
                end },
            }
            for _,groupName in ipairs(FojjiCore:GetInstalledPackGroups()) do
                entries[#entries+1] = { text = groupName.."  |cff8a8f98"..num(FojjiCore:GetGroupScale(groupName)).."|r", selected = DB.scaleTarget == groupName, onClick = function()
                    DB.scaleTarget = groupName
                    controls.scaleTarget.text:SetText(targetText())
                    controls.auraScale:SetValue(FojjiCore:GetGroupScale(groupName) or 1)
                end }
            end
            createDropdownMenu(self,entries)
        end)
        scaleCard:Add(field("Apply to", controls.scaleTarget), 45, 14)
        local scaleRow = CreateFrame("Frame")
        local applyScale = K.Button(scaleRow, "Apply scale", 130, 28, "primary")
        applyScale:SetPoint("LEFT", 0, 0)
        scaleCard:Add(scaleRow, 28)

        local listCard = sStack:Add(K.Card(scalePage, "Installed packs"))
        local listHolder = CreateFrame("Frame")
        listHolder.rows = {}
        listCard:Add(listHolder, 20, 4)

        refreshScale = function()
            if DB.scaleTarget ~= "ALL" then
                local ok = false
                for _, g in ipairs(FojjiCore:GetInstalledPackGroups()) do if g == DB.scaleTarget then ok = true end end
                if not ok then DB.scaleTarget = "ALL" end
            end
            controls.scaleTarget.text:SetText(targetText())
            controls.auraScale:SetValue(DB.auraScale or 1)
            local h = screenHeight()
            suggest:SetText("Your screen: "..h.."p  -  suggested "..(h >= 1440 and "1.2" or "1.0"))
            local list = FojjiCore:GetInstalledPackGroups()
            for i, groupName in ipairs(list) do
                local row = listHolder.rows[i]
                if not row then
                    row = CreateFrame("Frame", nil, listHolder)
                    row:SetHeight(20)
                    row.name = K.T(row, 12, "text")
                    row.name:SetPoint("LEFT", 0, 0)
                    row.name:SetPoint("RIGHT", -60, 0)
                    row.name:SetJustifyH("LEFT")
                    row.value = K.T(row, 12, "white", "RIGHT")
                    row.value:SetPoint("RIGHT", 0, 0)
                    row.value:SetWidth(56)
                    listHolder.rows[i] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
                row:SetPoint("RIGHT", 0, 0)
                row.name:SetText(groupName)
                row.value:SetText(num(FojjiCore:GetGroupScale(groupName)))
                row:Show()
            end
            for i = #list + 1, #listHolder.rows do listHolder.rows[i]:Hide() end
            if not listHolder.empty then
                listHolder.empty = K.T(listHolder, 12, "dim")
                listHolder.empty:SetPoint("TOPLEFT", 0, 0)
                listHolder.empty:SetText("No Fojji ForeverAuras packs installed.")
            end
            listHolder.empty:SetShown(#list == 0)
            local height = math.max(20, #list * 20)
            listHolder:SetHeight(height)
            for _, it in ipairs(listCard.items) do if it.w == listHolder then it.h = height end end
            sStack:Layout()
        end
        applyScale:SetScript("OnClick", function()
            if DB.scaleTarget == "ALL" then
                FojjiCore:SetScaleForAll(DB.auraScale or 1)
            else
                FojjiCore:SetGroupScale(DB.scaleTarget, DB.auraScale or 1)
            end
            refreshScale()
        end)
        scalePage:HookScript("OnShow", refreshScale)
    end

    local aboutPage = createPage("about","About")
    local aStack = K.CardStack(aboutPage, -54, cardKit)
    local idCard = aStack:Add(K.Card(aboutPage, "FojjiCore"))
    local idRow = CreateFrame("Frame")
    local aboutLogo = idRow:CreateTexture(nil,"ARTWORK")
    aboutLogo:SetSize(64,64)
    aboutLogo:SetPoint("LEFT",0,0)
    aboutLogo:SetTexture(ICON)
    local interfaceVersion = select(4,GetBuildInfo())
    local aboutTitle = K.T(idRow, 18, "white")
    aboutTitle:SetPoint("TOPLEFT", aboutLogo, "TOPRIGHT", 16, -6)
    aboutTitle:SetText("|cff66b3ffFojji|cffff4444Core|r")
    local info = K.T(idRow, 12, "dim")
    info:SetPoint("TOPLEFT", aboutTitle, "BOTTOMLEFT", 0, -8)
    info:SetText("Version  |cffffffff"..(FojjiCore_Version or "Unknown").."|r      Interface  |cffffffff"..tostring(interfaceVersion or "Unknown").."|r")
    idCard:Add(idRow, 64, 6)

    local thanksCard = aStack:Add(K.Card(aboutPage, "Thanks"))
    thanksCard.wide = true
    local THANKS = {
        { "Design inspiration", "|cffffffffEllesmereUI|r, for showing how good an addon can look." },
        { "Dungeon maps", "|cffffffffSantiago Reyes|r (@SR433_20 on X), who drew the original dungeon maps." },
        { "Minimap herbs & ore", "|cffffffffKrelock|r, whose NodeSight first found that the minimap's tracking dots can be read." },
        { "Chess pieces", "|cffffffffColin M.L. Burnett|r, whose \"cburnett\" piece set (BSD licence) the chess board uses." },
        { "Daily Word list", "|cffffffffKevin Atkinson|r's SCOWL / Hunspell en_US dictionary, where Daily Word's guessable words come from." },
        { "The team", "|cff8788eeJazminite|r, |cffffffffEnoriya|r, |cffc41e3aLedski|r, |cff0070ddMyri|r and |cffc69b6dSnickels|r" },
    }
    for i, t in ipairs(THANKS) do
        local row = CreateFrame("Frame")
        local head = K.T(row, 13, "text")
        head:SetPoint("TOPLEFT", 0, 0)
        head:SetText(t[1])
        local body = K.T(row, 12, "dim")
        body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
        body:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        body:SetJustifyH("LEFT")
        body:SetWordWrap(true)
        body:SetText(t[2])
        thanksCard:Add(row, 36, i < #THANKS and 12 or 6)
    end

    local cmdCard = aStack:Add(K.Card(aboutPage, "Commands", "Type these in chat."))
    cmdCard.wide = true
    local CMDS = {}
    local function group(title) CMDS[#CMDS+1] = { header = title } end
    local function cmd(c, d) CMDS[#CMDS+1] = { c, d } end
    group("General")
    cmd("/fc", "Open this window")
    if Addon.CreateGearPage then cmd("/fc bis", "BiS Manager") end
    cmd("/pull [seconds]", "Pull timer (/pull cancel stops it)")
    cmd("/break [minutes]", "Break timer")
    if Addon.CreateRaidPackPage and not Addon.Hidden.raidpacks then
        group("Raid Packs")
        cmd("/fc packs", "Raid Packs")
        cmd("/fc sounds", "Debuff sounds")
        cmd("/fc demo [boss] [seconds]", "Demo a boss (/fc demo all for the whole raid)")
        cmd("/fc demo stop", "Stop a running demo")
        cmd("/fc timeline", "Timeline Recorder")
    end
    if Addon.RaidLead or Addon.GroupSetups or Addon.Assignments then
        group("Raid Management")
        if Addon.GroupSetups then cmd("/fc groups", "Group setup popup (/fc groups edit: the builder)") end
        if Addon.Assignments and not Addon.Hidden.raiddata then cmd("/fc assign", "Assignment map window") end
        if Addon.RaidData and not Addon.Hidden.raiddata then cmd("/fc raiddata", "Raid Data - assignments") end
        if Addon.RaidLead then
            cmd("/fc versions", "Who has FojjiCore and which raid packs")
            cmd("/fc roles", "Set main tanks, assistants and master looter now")
            cmd("/fc invite [guild]", "Invite the roster (or the guild)")
        end
    end
    if Addon.CreateDungeonJournalPage then
        group("Dungeon Journal")
        cmd("/fc dj", "Open or close the journal")
        cmd("/fc dj quests", "Quests for your level or current dungeon")
        cmd("/fc dj sharepin", "Post your map pin to your group")
        cmd("/fc dj bar", "Show or hide the popout bar")
    end
    if Addon.CreateSpeedrunPage then
        group("Speedrun Timer")
        cmd("/fc speedrun", "Show or hide the tracker")
        cmd("/fc speedrun start  /  stop  /  reset", "Control the run")
        cmd("/fc speedrun lock  /  unlock", "Lock or move the tracker")
    end
    local cmdList = CreateFrame("Frame")
    local y = 0
    for i, c in ipairs(CMDS) do
        if c.header then
            if i > 1 then y = y + 10 end
            local label = K.T(cmdList, 11, "accent")
            label:SetPoint("TOPLEFT", 0, -y)
            label:SetText(c.header:upper())
            local line = cmdList:CreateTexture(nil, "ARTWORK")
            K.solid(line, "borderDim", 1)
            line:SetHeight(1)
            line:SetPoint("LEFT", label, "RIGHT", 10, 0)
            line:SetPoint("RIGHT", cmdList, "RIGHT", 0, 0)
            if Addon.Native and Addon.Skin then Addon.Skin.Rule(line, 0.6) end
            y = y + 22
        else
            local row = CreateFrame("Frame", nil, cmdList)
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            local chip = CreateFrame("Frame", nil, row)
            chip:SetSize(250, 24)
            chip:SetPoint("LEFT", 0, 0)
            K.Surface(chip, "field", 1, "borderDim")
            local bar = chip:CreateTexture(nil, "ARTWORK")
            K.solid(bar, "accent", 0.9)
            bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
            local ct = K.T(chip, 12, "white")
            ct:SetPoint("LEFT", 12, 0)
            ct:SetText(c[1])
            local dt = K.T(row, 12, "text")
            dt:SetPoint("LEFT", chip, "RIGHT", 14, 0)
            dt:SetPoint("RIGHT", 0, 0)
            dt:SetText(c[2])
            y = y + 29
        end
    end
    cmdCard:Add(cmdList, y, 8)
    aStack:Layout()

    if Addon.IsForever then
        local MODULES = {
            { "FojjiCore_DungeonJournal", "Dungeon Journal", "The BiS Manager, Spells & Talents and Games need this.", forever = true },
            { "FojjiCore_SpellRanks", "Spells & Talents", nil, forever = true },
            { "FojjiCore_BiS", "BiS Manager", nil, forever = true },
            { "FojjiCore_Games", "Games", nil, forever = true },
            { "FojjiCore_RaidTools", "Raid Tools", nil },
        }
        local modulesPage = createPage("modules","Modules")
        local mStack = K.CardStack(modulesPage, -54, cardKit)
        local mCard = mStack:Add(K.Card(modulesPage, "Modules", "Untick a module to switch it off for this character. Changes apply after a reload."))
        local player = UnitName("player")
        local function enabled(name)
            if C_AddOns and C_AddOns.GetAddOnEnableState then
                return (C_AddOns.GetAddOnEnableState(name, player) or 0) > 0
            end
            return GetAddOnEnableState and (GetAddOnEnableState(player, name) or 0) > 0
        end
        local function exists(name)
            if C_AddOns and C_AddOns.DoesAddOnExist then return C_AddOns.DoesAddOnExist(name) end
            return GetAddOnInfo and GetAddOnInfo(name) ~= nil
        end
        local reload
        local boxes = {}
        for _, m in ipairs(MODULES) do
            if exists(m[1]) and (Addon.ForeverClient or not m.forever) then
                local row = CreateFrame("Frame")
                local box
                box = createCheckbox(row, m[2], function(on)
                    local fn = on and ((C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn) or ((C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn)
                    if not fn then return end
                    fn(m[1], player)
                    if enabled(m[1]) ~= (on and true or false) then fn(m[1]) end
                    if C_AddOns and C_AddOns.SaveAddOns then C_AddOns.SaveAddOns() elseif SaveAddOns then SaveAddOns() end
                    box:SetChecked(enabled(m[1]))
                    reload:Show()
                end)
                box:SetPoint("TOPLEFT", 0, 0)
                if m[3] then
                    local note = createText(row, m[3], 11, "dim")
                    note:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 25, -2)
                    note:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                    note:SetJustifyH("LEFT")
                    note:SetWordWrap(true)
                end
                boxes[m[1]] = box
                mCard:Add(row, m[3] and 40 or 24, 6)
            end
        end
        reload = createButton(modulesPage, "Reload UI to apply", 180)
        reload:SetScript("OnClick", function() if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end end)
        local holder = CreateFrame("Frame")
        holder.fill = false
        holder:SetSize(180, 30)
        reload:SetParent(holder)
        reload:SetPoint("LEFT")
        reload:Hide()
        mCard:Add(holder, 30, 6)
        mStack:Layout()
        modulesPage:HookScript("OnShow", function()
            for name, box in pairs(boxes) do box:SetChecked(enabled(name)) end
            K.repaint()
        end)
    end

    for _, pg in ipairs({ generalPage, ttsPage, fontPage, aboutPage, scalePage }) do
        pg:HookScript("OnShow", function() K.repaint() end)
    end

    selectTab((DB.lastTab and pages[DB.lastTab]) and DB.lastTab or defaultTab())
end

local function validateFontTarget()
    if DB.fontTarget == "ALL" then
        return
    end

    local data = AuraAPI.GetData(DB.fontTarget)

    if not data then
        DB.fontTarget = "ALL"
    end
end

function FojjiCore:ToggleOptions(tab)
    if not frame then
        return
    end

    if frame.mini and frame.mini:IsShown() then
        frame.Restore()
        if tab and pages[tab] then selectTab(tab) end
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
    applyOptionsScale()
    controls.minimap:SetChecked(not DB.minimap.hide)
    controls.disableTTS:SetChecked(DB.disableTTS)
    controls.font.text:SetText(DB.fontName)
    controls.fontTarget.text:SetText(DB.fontTarget == "ALL" and "Apply to All" or DB.fontTarget)

    updateVoiceText()
    updateMinimapVisibility()

    hideDropdown()
    local want = (tab and pages[tab] and tab) or (DB.lastTab and pages[DB.lastTab] and DB.lastTab) or defaultTab()
    selectTab(want)

    local winAlpha = math.max(0.3, math.min(1, tonumber(DB.winAlpha) or 1))
    if frame.alphaSlider then frame.alphaSlider:SetValue(winAlpha * 100) end
    frame:SetAlpha(0)
    frame:Show()
    UIFrameFadeIn(frame,0.15,0,winAlpha)
end

SLASH_FOJJICORE1 = "/fojjicore"
SLASH_FOJJICORE2 = "/fc"

SlashCmdList["FOJJICORE"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local lc = cmd and cmd:lower()
    if (lc == "dj" or lc == "journal") and SlashCmdList.FOJJICOREDJ then
        SlashCmdList.FOJJICOREDJ(rest or "")
        return
    end
    if lc == "speedrun" and SlashCmdList.FOJJISPEEDRUN then
        SlashCmdList.FOJJISPEEDRUN(rest or "")
        return
    end
    if (lc == "plan" or lc == "bis") and Addon.CreateGearPage then
        FojjiCore:ToggleOptions("bis")
        return
    end
    if (lc == "dr" or lc == "deathroll" or lc == "games" or lc == "chess" or lc == "word" or lc == "wordle" or lc == "daily") and Addon.Games and Addon.Games.Slash(lc, rest) then
        return
    end
    if lc == "talents" and Addon.DJ and Addon.DJ.SpellRanks and Addon.DJ.SpellRanks.Talents and Addon.DJ.SpellRanks.Talents.Panel then
        local P = Addon.DJ.SpellRanks.Talents.Panel
        if (rest or ""):lower() == "debug" then P.Debug() else P.Toggle() end
        return
    end
    if lc == "gamepad" then
        local want = (rest or ""):lower()
        if want == "on" or want == "off" or want == "auto" then
            DB.gamepadUI = want ~= "auto" and want or nil
            Addon.Print("Gamepad UI safe mode: |cffffd100"..want.."|r. Type /reload to apply.")
            return
        end
        Addon.Print(("Gamepad UI safe mode: %s (setting: %s, game: gamepad UI %s)."):format(
            Addon.GamepadUI() and "|cff40ff40on|r" or "|cffff4040off|r", DB.gamepadUI or "auto",
            Addon.GamepadUIAuto() and "on" or "off"))
        return
    end
    if cmd and cmd:lower() == "spec" and FojjiCore.SpecReport then
        FojjiCore.SpecReport()
        return
    end
    if cmd and cmd:lower() == "groups" and Addon.GroupSetups then
        Addon.GroupSetups.Slash(rest)
        return
    end
    if cmd and Addon.Hidden.raiddata and (cmd:lower() == "raiddata" or cmd:lower() == "assign" or cmd:lower() == "assignments" or cmd:lower() == "plan") then
        FojjiCore:ToggleOptions()
        return
    end
    if cmd and (cmd:lower() == "assign" or cmd:lower() == "assignments" or cmd:lower() == "plan") and Addon.Assignments then
        Addon.Assignments:Toggle()
        return
    end
    if cmd and Addon.RaidLead and Addon.RaidLead.Slash(cmd:lower(), (rest or ""):lower()) then
        return
    end
    if Addon.RaidPackSlash and not Addon.Hidden.raidpacks and Addon.RaidPackSlash(msg) then
        return
    end
    FojjiCore:ToggleOptions()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")

loader:RegisterEvent("PLAYER_LOGIN")

loader:SetScript("OnEvent",function(self,event,addonName)
    if event == "PLAYER_LOGIN" then
        if not DB then return end
        if not frame then
            createOptions()
            createMinimapButton()
        end
        local packs = FojjiCore.voicePacks or {}
        if not next(packs) then
            applyTTSSettings()
            return
        end
        if DB.ttsVoiceType == "custom" and not packs[DB.ttsVoicePack] then
            DB.ttsVoicePack = DEFAULTS.ttsVoicePack
        end
        for name in pairs(DB.ttsVoiceFavorites) do
            if not packs[name] then DB.ttsVoiceFavorites[name] = nil end
        end
        if DB.ttsRandomFavorites and not next(DB.ttsVoiceFavorites) then
            DB.ttsRandomFavorites = false
        end
        applyTTSSettings()
        return
    end
    if addonName ~= "FojjiCore" then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")

    FojjiCoreDB = FojjiCoreDB or {}
    DB = FojjiCoreDB

    migrateDB()
    applyDefaults(DB,DEFAULTS)
    if not DB.minimapShown3 then
        DB.minimap.hide = false
        DB.minimapShown3 = true
    end
    if not DB.optionsRevision or DB.optionsRevision < 9 then
        DB.theme = "sunset"
        DB.optionsRevision = 9
    end
    if DB.optionsRevision < 10 then
        DB.windowWidth,DB.windowHeight = 880,620
        DB.optionsRevision = 10
    end
    if DB.optionsRevision < 11 then
        if (DB.windowWidth or 880) <= 880 and (DB.windowHeight or 620) <= 620 then
            DB.windowWidth,DB.windowHeight = 960,680
        end
        DB.optionsRevision = 11
    end
    if DB.optionsRevision < 12 then
        DB.theme = "sunset"
        DB.optionsRevision = 12
    end
    if DB.optionsRevision < 13 then
        if (DB.windowWidth or 960) <= 960 and (DB.windowHeight or 680) <= 680 then
            DB.windowWidth,DB.windowHeight = LAYOUT.width,LAYOUT.height
        end
        DB.optionsRevision = 13
    end
    applyTTSSettings()
    DB.windowScale = nil
    Addon.Native = DB.theme == "wow"
    if DB.combatFontPath then DAMAGE_TEXT_FONT = DB.combatFontPath end
    applyTheme(DB.theme)
end)
