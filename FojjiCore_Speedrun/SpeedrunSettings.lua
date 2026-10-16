local Addon = FojjiCoreNS
if not Addon then return end

local DEFAULTS = {

    disabled = false,
    visibility = "instance", hideAfterFinish = 0,

    startMode = "combat",
    finishMode = "final",
    resetOnLeave = true, resetOnZone = true, follow = true,
    compare = "best",

    collapsed = false, locked = false, growUp = false, buttons = true,
    scale = 1, alpha = 1, bgAlpha = 0.88, border = true, width = 280,
    timerSize = 18, textSize = 12, headerSize = 12, rowHeight = 18, maxRows = 8,
    font = "Expressway", timerFont = "Expressway", accent = "theme", colors = "classic", rowStyle = "tint",
    colorEngaged = true, engagedColor = "theme",
    order = "route", showUnkilled = true, icons = true, deltas = true, attempts = true,
    statusLine = true, footer = false, decimals = 0, label = "",
}

local function Initialize(db)
    if not db.dbv then

        if db.autoStart and db.startMode == nil then db.startMode = db.autoStart == "encounter" and "pull" or db.autoStart end
        if db.shown == false and db.visibility == nil then db.visibility = "never" end
        if db.width == 260 then db.width = 210 end
        db.autoStart, db.shown, db.hideOutside = nil, nil, nil
        db.dbv = 2
    end

    if db.startMode == "boss" then db.startMode = "pull" end
    if db.headerSize == nil then db.headerSize = db.textSize or DEFAULTS.headerSize end
    if (db.dbv or 0) < 3 then
        if db.width == 210 then db.width = 240 end
        if db.font == "Numen" then db.font = "Expressway" end
        if db.timerFont == "Numen" then db.timerFont = "Expressway" end
        db.dbv = 3
    end
    if (db.dbv or 0) < 4 then
        for _, key in ipairs({ "collapsed", "statusLine", "buttons", "footer", "border", "locked", "growUp",
            "decimals", "scale", "width", "timerSize", "textSize", "alpha", "bgAlpha" }) do
            db[key] = DEFAULTS[key]
        end
        db.pos = nil
        db.dbv = 4
    end
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    for _, name in ipairs({ "bests", "imports", "history", "learned", "seen", "rules", "pinned", "bossOrder" }) do
        db[name] = db[name] or {}
    end
    db.nextRunId = db.nextRunId or 1
    for _, entry in ipairs(db.history) do
        if not entry.id then entry.id = db.nextRunId; db.nextRunId = db.nextRunId + 1 end
    end
end

local initializedStore

function Addon.GetSpeedrunStore()
    FojjiCoreDB = FojjiCoreDB or {}
    local field = Addon.ForeverClient and "foreverSpeedrun" or "speedrun"
    local db = FojjiCoreDB[field]
    if not db then db = {}; FojjiCoreDB[field] = db end
    if db ~= initializedStore then
        Initialize(db)
        initializedStore = db
    end
    return db
end
