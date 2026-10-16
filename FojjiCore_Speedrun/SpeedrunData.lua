local Addon = FojjiCoreNS
if not Addon then return end
local D = {}
Addon.SRData = D

local ICON_ROOT = "Interface\\AddOns\\FojjiCore\\textures\\Speedrun\\boss\\"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Map_01"
D.instanceIcons = {
    [389] = "389",
    [43] = "43",
    [36] = "36",
    [33] = "33",
    [34] = "34",
    [48] = "48",
    [90] = "90",
    [47] = "47",
    [129] = "129",
    [70] = "70",
    [209] = "209",
    [109] = "109",
    [349] = "349",
    [230] = "230",
    [289] = "289",
    [189] = "189",
    [229] = "229",
    [329] = "329",
    [429] = "429",
    [3065] = "3065",
    [2999] = "2999",
    [2998] = "2998",
    [2959] = "2959",
    [409] = "409",
    [249] = "249",
    [469] = "469",
    [509] = "509",
    [531] = "531",
    [533] = "533",
    [532] = "532",
    [565] = "565",
    [544] = "544",
    [548] = "548",
    [550] = "550",
    [534] = "534",
    [564] = "564",
    [568] = "568",
    [580] = "580",
    [543] = "543",
    [542] = "542",
    [540] = "540",
    [557] = "557",
    [558] = "558",
    [556] = "556",
    [555] = "555",
    [547] = "547",
    [546] = "546",
    [545] = "545",
    [560] = "560",
    [269] = "269",
    [552] = "552",
    [553] = "553",
    [554] = "554",
    [585] = "585",
}

D.raids = {}
D.order = {}

function D.Norm(text)
    if type(text) ~= "string" then return "" end
    return (text:lower():gsub("[^%w]", ""))
end

function D.IconPath(boss, route)
    if boss and boss.icon then return ICON_ROOT .. boss.icon end
    local key = route and D.PhysicalKey(route.key)
    local icon = D.instanceIcons[key]
    return icon and ("Interface\\AddOns\\FojjiCore\\textures\\Speedrun\\instance\\" .. icon) or FALLBACK_ICON
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

local function Dungeon(instanceID, name, short, bosses, expectedBosses)
    Raid(instanceID, name, short, "Dungeon", bosses or {}, {
        dynamic = bosses == nil, expectedBosses = expectedBosses,
    })
end
Dungeon(389, "Ragefire Chasm", "RFC", {
    { Addon.ForeverClient and 2732 or -38901, "Oggleflint" },
    { -38902, "Taragaman the Hungerer" },
    { -38903, "Jergosh the Invoker" },
    { -38904, "Bazzalan", final = true },
}, 4)
D.wings = {}
local function NamedDungeon(key, name, short, names, optional, parent)
    local bosses = {}
    for boss in names:gmatch("[^|]+") do
        bosses[#bosses + 1] = { -(math.abs(key) * 100 + #bosses + 1), boss }
    end
    local expected = #bosses
    for boss in (optional or ""):gmatch("[^|]+") do
        bosses[#bosses + 1] = { -(math.abs(key) * 100 + #bosses + 1), boss, optional = true }
    end
    Dungeon(key, name, short, bosses, expected)
    D.raids[key].instanceID = parent or key
    if parent then
        D.wings[parent] = D.wings[parent] or {}
        table.insert(D.wings[parent], key)
    end
end
Dungeon(189, "Scarlet Monastery (wing detected on encounter)", "SM")
Dungeon(229, "Blackrock Spire (wing detected on encounter)", "BRS")
Dungeon(329, "Stratholme (wing detected on encounter)", "Strat")
Dungeon(429, "Dire Maul (wing detected on encounter)", "DM")
NamedDungeon(43, "Wailing Caverns", "WC",
    "Lady Anacondra|Lord Cobrahn|Kresh|Lord Pythas|Skum|Lord Serpentis|Verdan the Everliving|Mutanus the Devourer", "Deviate Faerie Dragon", nil)
NamedDungeon(36, "The Deadmines", "VC",
    "Rhahk'Zor|Sneed|Gilnid|Captain Greenskin|Mr. Smite|Cookie|Edwin VanCleef", "Miner Johnson", nil)
NamedDungeon(33, "Shadowfang Keep", "SFK",
    "Rethilgore|Razorclaw the Butcher|Baron Silverlaine|Commander Springvale|Odo the Blindwatcher|Fenrus the Devourer|Wolf Master Nandos|Archmage Arugal", "Deathsworn Captain", nil)
NamedDungeon(34, "The Stockade", "Stock",
    "Targorr the Dread|Kam Deepfury|Hamhock|Dextren Ward|Bazil Thredd", "Bruegal Ironknuckle", nil)
NamedDungeon(48, "Blackfathom Deeps", "BFD",
    "Ghamoo-ra|Lady Sarevess|Gelihast|Lorgus Jett|Old Serra'kis|Twilight Lord Kelris|Aku'mai", "Baron Aquanis", nil)
NamedDungeon(90, "Gnomeregan", "Gnomer",
    "Grubbis|Viscous Fallout|Electrocutioner 6000|Crowd Pummeler 9-60|Mekgineer Thermaplugg", "Dark Iron Ambassador", nil)
NamedDungeon(47, "Razorfen Kraul", "RFK",
    "Roogug|Aggem Thorncurse|Death Speaker Jargba|Overlord Ramtusk|Agathelos the Raging|Charlga Razorflank", "Earthcaller Halmgar|Blind Hunter", nil)
NamedDungeon(129, "Razorfen Downs", "RFD",
    "Tuten'kash|Plaguemaw the Rotting|Mordresh Fire Eye|Glutton|Amnennar the Coldbringer", "Ragglesnout", nil)
NamedDungeon(70, "Uldaman", "Uldaman",
    "Revelosh|The Lost Dwarves|Ironaya|Obsidian Sentinel|Ancient Stone Keeper|Galgann Firehammer|Grimlok|Archaedas", "", nil)
NamedDungeon(209, "Zul'Farrak", "ZF",
    "Hydromancer Velratha|Gahz'rilla|Antu'sul|Theka the Martyr|Witch Doctor Zum'rah|Nekrum Gutchewer|Shadowpriest Sezz'ziz|Chief Ukorz Sandscalp", "Sandarr Dunereaver|Zerillis|Dustwraith|Sergeant Bly|Sandfury Executioner|Ruuzlu", nil)
NamedDungeon(109, "The Temple of Atal'Hakkar", "ST",
    "Avatar of Hakkar|Jammal'an the Prophet|Dreamscythe|Weaver|Morphaz|Hazzas|Shade of Eranikus|Atal'alarion", "Zul'Lor|Gasher|Loro|Zolo|Mijan|Hukku|Ogom the Wretched", nil)
NamedDungeon(349, "Maraudon (full clear)", "Mara",
    "Noxxion|Razorlash|Tinkerer Gizlock|Lord Vyletongue|Celebras the Cursed|Landslide|Rotgrip|Princess Theradras", "Meshlok the Harvester", nil)
NamedDungeon(230, "Blackrock Depths (full clear)", "BRD",
    "High Interrogator Gerstahn|Lord Roccor|Houndmaster Grebmar|Ring of Law|Pyromancer Loregrain|Lord Incendius|Warder Stilgiss|Fineous Darkvire|Bael'Gar|General Angerforge|Golem Lord Argelmach|Hurley Blackbreath|Phalanx|Ribbly Screwspigot|Plugger Spazzring|The Vault|Ambassador Flamelash|The Seven|Magmus|Princess Moira Bronzebeard|Emperor Dagran Thaurissan", "Panzor the Invincible", nil)
NamedDungeon(289, "Scholomance", "Scholo",
    "Kirtonos|Jandice Barov|Rattlegore|Marduk Blackpool|Vectus|Ras Frostwhisperer|Instructor Malicia|Doctor Theolen Krastinov|Lorekeeper Polkelt|The Ravenian|Lord Alexei Barov|Lady Illucia Barov|Darkmaster Gandling", "Kormok|Death Knight Darkreaver", nil)
NamedDungeon(-18901, "Scarlet Monastery: Graveyard", "SM GY",
    "Interrogator Vishas|Bloodmage Thalnos", "Azshir the Sleepless|Fallen Champion|Ironspine", 189)
NamedDungeon(-18902, "Scarlet Monastery: Library", "SM Lib",
    "Houndmaster Loksey|Arcanist Doan", "", 189)
NamedDungeon(-18903, "Scarlet Monastery: Armory", "SM Arm",
    "Herod", "", 189)
NamedDungeon(-18904, "Scarlet Monastery: Cathedral", "SM Cath",
    "High Inquisitor Fairbanks|High Inquisitor Whitemane", "", 189)
NamedDungeon(-22901, "Lower Blackrock Spire", "LBRS",
    "Highlord Omokk|Shadow Hunter Vosh'gajin|War Master Voone|Mother Smolderweb|Urok Doomhowl|Quartermaster Zigris|Halycon|Gizrul the Slavener|Overlord Wyrmthalak", "Burning Felguard|Spirestone Battle Lord|Spirestone Lord Magus|Bannok Grimaxe|Crystal Fang|Ghok Bashguud|Spirestone Butcher", 229)
NamedDungeon(-22902, "Upper Blackrock Spire", "UBRS",
    "Pyroguard Emberseer|Warchief Rend Blackhand|The Beast|General Drakkisath", "Lord Valthalak|Jed Runewatcher|Solakar Flamewreath|Goraluk Anvilcrack", 229)
NamedDungeon(-42901, "Dire Maul: East", "DM E",
    "Zevrim Thornhoof|Hydrospawn|Lethtendris|Pusillin|Alzzin the Wildshaper", "", 429)
NamedDungeon(-42902, "Dire Maul: West", "DM W",
    "Tendris Warpwood|Illyanna Ravenoak|Magister Kalendris|Immol'thar|Prince Tortheldrin", "Lord Hel'nurath|Tsu'zee", 429)
NamedDungeon(-42903, "Dire Maul: North", "DM N",
    "Guard Mol'dar|Stomper Kreeg|Guard Fengus|Guard Slip'kik|Captain Kromcrush|Cho'Rush the Observer|King Gordok", "", 429)
NamedDungeon(-32901, "Stratholme: Living", "Strat Live",
    "Timmy the Cruel|Malor the Zealous|Cannon Master Willey|Archivist Galford|Balnazzar", "Hearthsinger Forresten|Crimson Hammersmith|Postmaster Malown|Skul|Ezra Grimm", 329)
NamedDungeon(-32902, "Stratholme: Undead", "Strat UD",
    "Baroness Anastari|Nerub'enkan|Maleki the Pallid|Magistrate Barthilas|Ramstein the Gorger|Baron Rivendare", "Black Guard Swordsmith|Stonespine", 329)
if Addon.ForeverClient then
NamedDungeon(3065, "The Hall of Thanes", "HoT",
    "Faldrim Anvilmar|Magmatus|Plunder|Durgen Dirgehammer", "", nil)
NamedDungeon(2999, "Ruins of Lordaeron", "RoL",
    "Witherfang|The Abandoned|The Baron|Rath'mael|Viktor the Vile|Bjork", "Lordaeron Captain", nil)
NamedDungeon(2998, "Excavation Site: Wetlands", "Excavation",
    "Saltspine|Shadetooth|Highland Horror|Relic Guardian", "", nil)
NamedDungeon(2959, "City of Dalaran", "Dalaran",
    "Atrexis the Grave Knight|Arcane Anomaly|Arcanic Enigma|Unstable Sentinel|Mana Devourer|Fel Ancient|Shade of the Archmage", "Lyn the Ignored", nil)

end

local function Alias(key, bossName, aliases)
    for _, boss in ipairs(D.raids[key].bosses) do
        if boss.name == bossName then boss.alias = aliases; return end
    end
end
Alias(48, "Gelihast", { "Geilhast" })
Alias(289, "Kirtonos", { "Kirtonos the Herald" })
Alias(289, "Ras Frostwhisperer", { "Ras Frostwhisper" })
if Addon.ForeverClient then
Alias(3065, "Magmatus", { "Infurnus" })
Alias(3065, "Durgen Dirgehammer", { "Dirgen Dirgehammer" })
Alias(2999, "The Baron", { "The Butcher" })
Alias(2959, "Arcanic Enigma", { "Mana Elemental" })
end
Alias(-18904, "High Inquisitor Whitemane", { "Scarlet Commander Mograine", "Mograine and Whitemane" })
D.heroic = {}
if not Addon.ForeverClient then
    local function TBC(key, name, short, bosses, optional)
        local heroic = -100000 - key
        local heroicBosses = bosses
        if key == 540 then
            heroicBosses = bosses .. "|Blood Guard Porung"
            optional = optional .. "|Blood Guard Porung"
        end
        NamedDungeon(key, name .. " (Normal)", short, bosses, optional)
        local heroicOptional = key == 540 and "Shattered Hand Executioner" or optional
        NamedDungeon(heroic, name .. " (Heroic)", short .. " H", heroicBosses, heroicOptional)
        D.raids[key].difficulty = 1
        D.raids[heroic].difficulty = 2
        D.raids[heroic].instanceID = key
        D.heroic[key] = heroic
        if key == 543 then
            local aliases = { "Vazruden", "Nazan", "Nazan & Vazruden", "Vazruden & Nazan", "Nazan and Vazruden" }
            Alias(key, "Vazruden and Nazan", aliases)
            Alias(heroic, "Vazruden and Nazan", aliases)
        end
    end
    TBC(543, "Hellfire Ramparts", "Ramps", "Watchkeeper Gargolmar|Omor the Unscarred|Vazruden and Nazan", "")
    TBC(542, "The Blood Furnace", "BF", "The Maker|Broggok|Keli'dan the Breaker", "")
    TBC(540, "The Shattered Halls", "SH", "Grand Warlock Nethekurse|Warbringer O'mrogg|Warchief Kargath Bladefist", "Shattered Hand Executioner")
    TBC(557, "Mana-Tombs", "MT", "Pandemonius|Tavarok|Nexus-Prince Shaffar", "Yor")
    TBC(558, "Auchenai Crypts", "AC", "Shirrak the Dead Watcher|Exarch Maladaar", "Avatar of the Martyred")
    TBC(556, "Sethekk Halls", "Sethekk", "Darkweaver Syth|Talon King Ikiss", "Anzu")
    TBC(555, "Shadow Labyrinth", "SL", "Ambassador Hellmaw|Blackheart the Inciter|Grandmaster Vorpil|Murmur", "First Fragment Guardian")
    TBC(547, "The Slave Pens", "SP", "Mennu the Betrayer|Rokmar the Crackler|Quagmirran", "Ahune")
    TBC(546, "The Underbog", "UB", "Hungarfen|Ghaz'an|Swamplord Musel'ek|The Black Stalker", "")
    TBC(545, "The Steamvault", "SV", "Hydromancer Thespia|Mekgineer Steamrigger|Warlord Kalithresh", "")
    TBC(560, "Old Hillsbrad Foothills", "OHF", "Lieutenant Drake|Captain Skarloc|Epoch Hunter", "Don Carlos")
    TBC(269, "The Black Morass", "BM", "Chrono Lord Deja|Temporus|Aeonus", "")
    TBC(552, "The Arcatraz", "Arc", "Zereketh the Unbound|Dalliah the Doomsayer|Wrath-Scryer Soccothrates|Harbinger Skyriss", "Third Fragment Guardian")
    TBC(553, "The Botanica", "Bot", "Commander Sarannis|High Botanist Freywinn|Thorngrin the Tender|Laj|Warp Splinter", "")
    TBC(554, "The Mechanar", "Mech", "Mechano-Lord Capacitus|Nethermancer Sepethrea|Pathaleon the Calculator", "Gatewatcher Gyro-Kill|Gatewatcher Iron-Hand")
    TBC(585, "Magisters' Terrace", "MgT", "Selin Fireheart|Vexallus|Priestess Delrissa|Kael'thas Sunstrider", "")
end
function D.DifficultyKey(key, difficulty)
    return difficulty == 2 and D.heroic[key] or key
end
function D.Difficulty(key)
    local route = D.raids[key]
    return route and route.difficulty
end

function D.PhysicalKey(key)
    local src = D.raids[key]
    return src and src.instanceID or key
end
D.excludedNames, D.excludedIDs = {}, {}
local excluded = {
    [43] = "Deviate Faerie Dragon",
    [36] = "Miner Johnson",
    [33] = "Deathsworn Captain",
    [34] = "Bruegal Ironknuckle",
    [90] = "Dark Iron Ambassador",
    [47] = "Earthcaller Halmgar|Blind Hunter",
    [129] = "Ragglesnout",
    [209] = "Sandarr Dunereaver|Zerillis|Dustwraith",
    [349] = "Meshlok the Harvester",
    [230] = "Panzor the Invincible",
    [189] = "Azshir the Sleepless|Fallen Champion|Ironspine",
    [229] = "Burning Felguard|Spirestone Battle Lord|Spirestone Lord Magus|Bannok Grimaxe|Crystal Fang|Ghok Bashguud|Spirestone Butcher|Jed Runewatcher",
    [429] = "Tsu'zee",
    [329] = "Hearthsinger Forresten|Skul|Stonespine",
    [2999] = "Lordaeron Captain",
}
for key, names in pairs(excluded) do
    D.excludedNames[key] = {}
    for name in names:gmatch("[^|]+") do D.excludedNames[key][D.Norm(name)] = true end
end
function D.IsExcluded(key, id, name)
    local names = D.excludedNames[D.PhysicalKey(key)]
    return (D.excludedIDs[key] and D.excludedIDs[key][id]) or (names and names[D.Norm(name)]) or false
end
for key, src in pairs(D.raids) do
    local kept = {}
    D.excludedIDs[key] = {}
    for _, boss in ipairs(src.bosses) do
        if D.IsExcluded(key, boss.id, boss.name) then
            D.excludedIDs[key][boss.id] = true
            if not boss.optional and src.expectedBosses then src.expectedBosses = src.expectedBosses - 1 end
        else kept[#kept + 1] = boss end
    end
    src.bosses = kept
end

function D.WingForEncounter(instanceID, id, name, seen)
    local norm = D.Norm(name)
    for _, key in ipairs(D.wings[instanceID] or {}) do
        for _, item in ipairs(seen and seen[key] or {}) do
            if item.id == id then return key end
        end
        for _, boss in ipairs(D.raids[key].bosses) do
            if not boss.optional and D.Norm(boss.name) == norm then return key end
            for _, alias in ipairs(boss.alias or {}) do
                if D.Norm(alias) == norm then return key end
            end
        end
    end
end

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
    local out, seen = {}, {}
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
    local route = { key = key, bosses = {}, excludedIDs = {} }
    for id in pairs(D.excludedIDs[key] or {}) do route.excludedIDs[id] = true end
    if src then
        route.name, route.short, route.dynamic = src.name, src.short, src.dynamic
        route.expectedBosses = src.expectedBosses
        route.instanceID = src.instanceID
        if key == 70 and UnitFactionGroup and UnitFactionGroup("player") == "Alliance" then
            route.expectedBosses = 7
        end
        local ordered = (not src.dynamic) and D.OrderedBosses(src, order) or src.bosses
        for _, boss in ipairs(ordered) do
            route.bosses[#route.bosses + 1] = {
                id = boss.id, name = boss.name, icon = boss.icon,
                optional = boss.optional or (key == 70 and boss.name == "The Lost Dwarves" and route.expectedBosses == 7), alias = boss.alias,
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
    if D.IsExcluded(route.key, id, name) then route.excludedIDs[id] = true; return nil end
    local existing = D.FindBoss(route, id, name)
    if existing then return existing end
    local boss = { id = id, name = (type(name) == "string" and name ~= "") and name or ("Encounter " .. tostring(id)), extra = true }
    if D.PhysicalKey(route.key) == 329 and D.Norm(boss.name) == D.Norm("The Unforgiven") then
        boss.optional = true
    end
    route.bosses[#route.bosses + 1] = boss
    route.byID[id] = boss
    route.byName[D.Norm(boss.name)] = boss
    return boss
end

function D.FindBoss(route, id, name)
    if D.IsExcluded(route.key, id, name) then return nil end
    local boss = route.byID[id]
    if boss then return boss end
    local norm = D.Norm(name)
    if norm ~= "" then
        boss = route.byName[norm]
        if boss and type(id) == "number" then
            route.byID[id] = boss
        end
        return boss
    end
end
function D.NormalizeRecord(route, record)
    if type(record) ~= "table" then return end
    for _, field in ipairs({ "splits", "pulls", "attempts" }) do
        local values = record[field]
        if type(values) == "table" then
            for id in pairs(route.excludedIDs or {}) do values[id] = nil end
            for id, boss in pairs(route.byID) do
                if id ~= boss.id and values[id] ~= nil then
                    if values[boss.id] == nil then values[boss.id] = values[id] end
                    values[id] = nil
                end
            end
        end
    end
    for index, id in ipairs(record.order or {}) do
        if not D.IsExcluded(route.key, id) then
            local boss = route.byID[id]
            if boss then record.order[index] = boss.id end
        end
    end
end
