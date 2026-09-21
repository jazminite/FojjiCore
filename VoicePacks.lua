-- FojjiCore:RegisterVoicePack(name, folder, files)
-- Voice pack names and order are used by the voice selector.

FojjiCore.voicePacks = FojjiCore.voicePacks or {}
FojjiCore.voicePackOrder = FojjiCore.voicePackOrder or {}

function FojjiCore:RegisterVoicePack(name,folder,files)
    if not name or not folder or type(files) ~= "table" then
        return
    end

    local pack = {}

    for text,file in pairs(files) do
        pack[text] = "Interface\\AddOns\\FojjiCore\\voice\\" .. folder .. "\\" .. file
    end

    self.voicePacks[name] = pack
    self.voicePackOrder[#self.voicePackOrder+1] = name
end

local phrases = {
    "Air Burst","Barrage","Barrage on You","Blessing","Blizzard","Blood Phase","Boss","Break Shield","Breath",
    "Charge","Charged","Clear","Command","Consecration","Consecration Soon","Crash","Debuff","Deaden","Deaden Soon","Death and Decay",
    "Demon","Demons","Demons Soon","Disorient","Doom","Doom on You","Elite","Emerge","Enrage","Enrage Soon",
    "Enraged","Enraging","Explosion","Eye Beam","Fatal Attraction","Fear","Fear Soon","Fear Ward","Feared","Feign",
    "Fire Spawning","Fixate","Fixate on You","Flamestrike","Frontal","Freezing Trap","Frost","Gaze on You","Geyser",
    "Go Forward","Go Left","Go Right","Gravity Lapse","Grounding","High Stacks","Human","Icebolt","Illidan Trapped",
    "Impaled","Increased Arcane","Increased Fire","Increased Frost","Increased Holy","Increased Nature","Increased Shadow",
    "Increased Threat","Infection","Inferno","Inferno Soon","Interrupt","Jump","Kick","Kill Egg","Kill Totem","Kite Phase",
    "Knock Soon","Knockback","L Five","Lurker","Magical Kicks","Mark","Mark Soon","Marked","MC","Melt Armor","Meteor",
    "Mind Control","Move","Move Out","Murloc Wave","Nature","Overcharge","Parasite","Parasite on You","Phase 2","Phase 3",
    "Phase 4","Phase 5","Phoenix","Physical Kicks","Purge","Quake","Rage Phase","Rain","Rain of Chaos","Reduced Arcane",
    "Reduced Fire","Reduced Holy","Reduced Shadow","Reflect","Reflect Shell","Rogue is back","Safe","Sapper Now","Shadow Inferno",
    "Shadow of Death","Shear","Shear on Tank","Shear Soon","Shield","Shield Soon","Silence","Silenced","Soak","Soul Drain",
    "Soulwell","Spellsteal","Spine","Spite","Spite on You","Split","Sporebat","Spout","Spout Soon","Spread","Spread Out",
    "Stop Soaking","Strider","Submerge","Summon Globules","Table","Tainted","Tainted Soon","Tank Phase","Throw Spine",
    "Tornado","Totem","Toy on You","Tranq","Trap","Trap Placed","Trapped","Vanish","Vulnerable","Watch Blizzard","Watch HP",
    "Watch Tank","Whirlwind","Wrath","Use Bloodlust","Use Heroism","Use Mana Tide","Use Tranquility","Use AoE Taunt",
    "Use Block","Use Bubble","Berserk Soon","Berserk","10","9","8","7","6","5","4","3","2","1","Skull","Cross","Star",
    "Diamond","Square","Moon","Triangle","Debuffed","Debuff on You","Link","Linked","Spell Reflect","Stack Up","Stack",
    "Group Up","Bubble","Immune","Immunity","AoE","Raid Damage","Bloodlust","Heroism","Low Mana","Bomb","Arcane Bomb",
    "Bomb on You","Kite Phase Soon","Tank Phase Soon","Talk to Akama","Dodge","Beam","Watch Your Feet","Avoid"
}

local files = {}

for _,text in ipairs(phrases) do
    local file = text:lower():gsub("[^a-z0-9]+","_"):gsub("^_+",""):gsub("_+$","") .. ".ogg"
    files[text] = file
end

FojjiCore:RegisterVoicePack("Arabella","Arabella",files)
FojjiCore:RegisterVoicePack("Carla","Carla",files)
FojjiCore:RegisterVoicePack("Chris","Chris",files)
FojjiCore:RegisterVoicePack("Mark","Mark",files)

FojjiCore:RegisterVoicePack("Chinese - Stacy","Stacy",files)
FojjiCore:RegisterVoicePack("German - Helmut","Helmut",files)
FojjiCore:RegisterVoicePack("Korean - Suelki","Suelki",files)

FojjiCore:RegisterVoicePack("Flavour - Algalon","Algalon",files)
FojjiCore:RegisterVoicePack("Flavour - Anime Lulu","Anime Lulu",files)
FojjiCore:RegisterVoicePack("Flavour - Arthas","Arthas",files)
FojjiCore:RegisterVoicePack("Flavour - Grandpa Jim","Grandpa Jim",files)
FojjiCore:RegisterVoicePack("Flavour - Illidan","Illidan",files)
FojjiCore:RegisterVoicePack("Flavour - Sylvanas","Sylvanas",files)

FojjiCore:RegisterVoicePack("Community - Baron <Fusion>","Baron",files)
FojjiCore:RegisterVoicePack("Community - Doney <Numen>","Doney",files)
FojjiCore:RegisterVoicePack("Community - Enori <Numen>","Enori",files)
FojjiCore:RegisterVoicePack("Community - Fojji <Numen>","Fojji",files)
FojjiCore:RegisterVoicePack("Community - Joardee - Streamer","Joardee",files)
FojjiCore:RegisterVoicePack("Community - Ken <who>","Ken",files)
FojjiCore:RegisterVoicePack("Community - Rellie <Numen>","Rellie",files)
FojjiCore:RegisterVoicePack("Community - Trupster <Numen>","Trupster",files)
