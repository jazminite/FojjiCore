-- Raid keys are instance IDs from GetInstanceInfo().
-- Boss entries: { encounterID, name, icon, optional = true, alias = { names } }

local _, Addon = ...
local D = {}
Addon.SRData = D

local ICON_ROOT = "Interface\\AddOns\\FojjiCore\\textures\\Speedrun\\boss\\"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

D.raids = {}
D.order = {}

function D.Norm(text)
    if type(text) ~= "string" then return "" end
    return (text:lower():gsub("[^%w]", ""))
end

function D.IconPath(boss)
    if boss and boss.icon then return ICON_ROOT .. boss.icon end
    return FALLBACK_ICON
end

local function Raid(instanceID, name, short, expansion, bosses, extra)
    local raid = {
        key = instanceID, name = name, short = short, expansion = expansion,
        bosses = {}, final = bosses[#bosses] and bosses[#bosses][1] or nil,
    }
    for _, spec in ipairs(bosses) do
        raid.bosses[#raid.bosses + 1] = {
            id = spec[1], name = spec[2], icon = spec[3],
            optional = spec.optional, alias = spec.alias,
        }
        if spec.final then raid.final = spec[1] end
    end
    if extra then for k, v in pairs(extra) do raid[k] = v end end
    D.raids[instanceID] = raid
    D.order[#D.order + 1] = instanceID
end

Raid(409, "Molten Core", "MC", "Classic", {
    { 663, "Lucifron" }, { 664, "Magmadar" }, { 665, "Gehennas" }, { 666, "Garr" },
    { 667, "Shazzrah" }, { 668, "Baron Geddon" }, { 669, "Sulfuron Harbinger" },
    { 670, "Golemagg the Incinerator" }, { 671, "Majordomo Executus" }, { 672, "Ragnaros" },
})
Raid(249, "Onyxia's Lair", "ONY", "Classic", {
    { 1084, "Onyxia" },
})
Raid(469, "Blackwing Lair", "BWL", "Classic", {
    { 610, "Razorgore the Untamed" }, { 611, "Vaelastrasz the Corrupt" },
    { 612, "Broodlord Lashlayer" }, { 613, "Firemaw" }, { 614, "Ebonroc" },
    { 615, "Flamegor" }, { 616, "Chromaggus" }, { 617, "Nefarian" },
})
Raid(509, "Ruins of Ahn'Qiraj", "AQ20", "Classic", {
    { 718, "Kurinnaxx" }, { 719, "General Rajaxx" }, { 720, "Moam" },
    { 721, "Buru the Gorger" }, { 722, "Ayamiss the Hunter" }, { 723, "Ossirian the Unscarred" },
})
Raid(531, "Temple of Ahn'Qiraj", "AQ40", "Classic", {
    { 709, "The Prophet Skeram" }, { 710, "Bug Trio", nil, alias = { "Silithid Royalty" } },
    { 711, "Battleguard Sartura" }, { 712, "Fankriss the Unyielding" }, { 713, "Viscidus" },
    { 714, "Princess Huhuran" }, { 715, "The Twin Emperors" }, { 716, "Ouro" }, { 717, "C'Thun" },
})
Raid(533, "Naxxramas", "NAXX", "Classic", {
    { 1107, "Anub'Rekhan", "n1107" }, { 1110, "Grand Widow Faerlina", "n1110" },
    { 1116, "Maexxna", "n1116" },
    { 1113, "Instructor Razuvious", "n1113" }, { 1109, "Gothik the Harvester", "n1109" },
    { 1121, "The Four Horsemen", "n1121" },
    { 1117, "Noth the Plaguebringer", "n1117" }, { 1112, "Heigan the Unclean", "n1112" },
    { 1115, "Loatheb", "n1115" },
    { 1118, "Patchwerk", "n1118" }, { 1111, "Grobbulus", "n1111" }, { 1108, "Gluth", "n1108" },
    { 1120, "Thaddius", "n1120" },
    { 1119, "Sapphiron", "n1119" }, { 1114, "Kel'Thuzad", "n1114" },
})

Raid(532, "Karazhan", "KARA", "TBC", {
    { 652, "Attumen the Huntsman" }, { 653, "Moroes" }, { 654, "Maiden of Virtue" },
    { 655, "Opera Hall", "opera", alias = { "Opera Event", "The Big Bad Wolf", "Romulo and Julianne", "The Crone" } },
    { 656, "The Curator" }, { 657, "Terestian Illhoof" }, { 658, "Shade of Aran" },
    { 659, "Netherspite" }, { 660, "Chess Event", nil, alias = { "Echo of Medivh" } },
    { 661, "Prince Malchezaar", "malchezar", final = true },
    { 662, "Nightbane", nil, optional = true },
})
Raid(565, "Gruul's Lair", "GRUUL", "TBC", {
    { 649, "High King Maulgar" }, { 650, "Gruul the Dragonkiller", "gruul" },
})
Raid(544, "Magtheridon's Lair", "MAG", "TBC", {
    { 651, "Magtheridon", "magtheridon" },
})
Raid(548, "Serpentshrine Cavern", "SSC", "TBC", {
    { 623, "Hydross the Unstable", "hydross" }, { 624, "The Lurker Below", "lurker" },
    { 625, "Leotheras the Blind", "leotheras" }, { 626, "Fathom-Lord Karathress", "karathress" },
    { 627, "Morogrim Tidewalker", "tidewalker" }, { 628, "Lady Vashj", "vashj" },
})
Raid(550, "Tempest Keep", "TK", "TBC", {
    { 730, "Al'ar", "alar" }, { 731, "Void Reaver", "voidreaver" },
    { 732, "High Astromancer Solarian", "solarian" }, { 733, "Kael'thas Sunstrider", "kaelthas" },
})
Raid(534, "Hyjal Summit", "HYJAL", "TBC", {
    { 618, "Rage Winterchill", "ragewinterchill" }, { 619, "Anetheron", "anetheron" },
    { 620, "Kaz'rogal", "kazrogal" }, { 621, "Azgalor", "azgalor" },
    { 622, "Archimonde", "archimonde" },
})
Raid(564, "Black Temple", "BT", "TBC", {
    { 601, "High Warlord Naj'entus", "najentus" }, { 602, "Supremus", "supremus" },
    { 603, "Shade of Akama", "akama" }, { 604, "Teron Gorefiend", "teron" },
    { 605, "Gurtogg Bloodboil", "gurtogg" }, { 606, "Reliquary of Souls", "reliquary" },
    { 607, "Mother Shahraz", "shahraz" },
    { 608, "The Illidari Council", "council", alias = { "Illidari Council" } },
    { 609, "Illidan Stormrage", "illidan" },
})
Raid(568, "Zul'Aman", "ZA", "TBC", {
    { 1189, "Nalorakk", "nalorakk" }, { 1190, "Akil'zon", "akilzon" },
    { 1191, "Jan'alai", "janalai" }, { 1192, "Halazzi" },
    { 1193, "Hex Lord Malacrass", "malacrass" }, { 1194, "Zul'jin", "zuljin" },
})
Raid(580, "Sunwell Plateau", "SWP", "TBC", {
    { 724, "Kalecgos", "kalecgos" }, { 725, "Brutallus", "brutallus" },
    { 726, "Felmyst", "felmyst" }, { 727, "The Eredar Twins", "twins", alias = { "Eredar Twins" } },
    { 728, "M'uru", "muru" }, { 729, "Kil'jaeden", "kiljaedan" },
})

local function Dungeon(instanceID, name, short)
    Raid(instanceID, name, short, "Dungeon", {}, { dynamic = true })
end
Dungeon(389, "Ragefire Chasm", "RFC")
Dungeon(43, "Wailing Caverns", "WC")
Dungeon(36, "The Deadmines", "VC")
Dungeon(33, "Shadowfang Keep", "SFK")
Dungeon(34, "The Stockade", "Stock")
Dungeon(48, "Blackfathom Deeps", "BFD")
Dungeon(90, "Gnomeregan", "Gnomer")
Dungeon(47, "Razorfen Kraul", "RFK")
Dungeon(129, "Razorfen Downs", "RFD")
Dungeon(70, "Uldaman", "Uldaman")
Dungeon(209, "Zul'Farrak", "ZF")
Dungeon(109, "The Temple of Atal'Hakkar", "ST")
Dungeon(349, "Maraudon", "Maraudon")
Dungeon(229, "Lower Blackrock Spire", "LBRS")
Dungeon(230, "Blackrock Depths", "BRD")
Dungeon(329, "Scarlet Monastery", "SM")
Dungeon(429, "Dire Maul", "DM")
Dungeon(289, "Scholomance", "Scholo")

local function Index(route)
    route.byID, route.byName = {}, {}
    for _, boss in ipairs(route.bosses) do
        route.byID[boss.id] = boss
        route.byName[D.Norm(boss.name)] = boss
        for _, alias in ipairs(boss.alias or {}) do route.byName[D.Norm(alias)] = boss end
    end
end

function D.Initials(name)
    local out = {}
    for word in tostring(name or ""):gmatch("%a+") do
        if #out < 4 and #word > 2 then out[#out + 1] = word:sub(1, 1):upper() end
    end
    return #out > 0 and table.concat(out) or "RUN"
end

function D.OrderedBosses(src, order)
    if not order or #order == 0 then return src.bosses end
    local placed, out, seen = {}, {}, {}
    for _, id in ipairs(order) do
        for _, boss in ipairs(src.bosses) do
            if boss.id == id and not seen[id] then out[#out + 1] = boss; seen[id] = true end
        end
    end
    for _, boss in ipairs(src.bosses) do
        if not seen[boss.id] then out[#out + 1] = boss end
    end
    return out
end

function D.NewRoute(key, customName, seen, order)
    local src = D.raids[key]
    local route = { key = key, bosses = {} }
    if src then
        route.name, route.short, route.dynamic = src.name, src.short, src.dynamic
        local ordered = (not src.dynamic) and D.OrderedBosses(src, order) or src.bosses
        for _, boss in ipairs(ordered) do
            route.bosses[#route.bosses + 1] = {
                id = boss.id, name = boss.name, icon = boss.icon,
                optional = boss.optional, alias = boss.alias,
            }
        end

        route.final = (order and #order > 0) and route.bosses[#route.bosses].id or src.final
    else
        route.name = customName or "Custom run"
        route.short = D.Initials(route.name)
        route.dynamic, route.custom = true, true
    end
    Index(route)
    for _, item in ipairs(seen or {}) do
        if type(item) == "table" and type(item.id) == "number" and not D.FindBoss(route, item.id, item.name) then
            D.AddExtra(route, item.id, item.name)
        end
    end
    return route
end

function D.AddExtra(route, id, name)
    local boss = { id = id, name = (type(name) == "string" and name ~= "") and name or ("Encounter " .. tostring(id)), extra = true }
    route.bosses[#route.bosses + 1] = boss
    route.byID[id] = boss
    route.byName[D.Norm(boss.name)] = boss
    return boss
end

function D.FindBoss(route, id, name)
    local boss = route.byID[id]
    if boss then return boss end
    local norm = D.Norm(name)
    if norm ~= "" then return route.byName[norm] end
end
