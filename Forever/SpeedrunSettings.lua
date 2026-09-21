-- Timer defaults and saved-setting migrations.
-- Addon.GetSpeedrunStore() returns FojjiCoreDB.foreverSpeedrun.

local _, Addon = ...

local DEFAULTS = {

    visibility = "instance", hideAfterFinish = 0,

    startMode = "combat",
    finishMode = "final",
    resetOnLeave = true, resetOnZone = true, follow = true,
    compare = "best",

    collapsed = true, locked = false, growUp = false, buttons = true,
    scale = 1, alpha = 1, bgAlpha = 0.88, border = true, width = 210,
    timerSize = 16, textSize = 10, rowHeight = 18, maxRows = 8,
    font = "Numen", timerFont = "Numen", accent = "theme", colors = "classic", rowStyle = "tint",
    colorEngaged = true, engagedColor = "theme",
    order = "route", showUnkilled = true, icons = true, deltas = true, attempts = true,
    statusLine = true, footer = false, decimals = 1, label = "",
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
    local db = FojjiCoreDB.foreverSpeedrun
    if not db then db = {}; FojjiCoreDB.foreverSpeedrun = db end
    if db ~= initializedStore then
        Initialize(db)
        initializedStore = db
    end
    return db
end
