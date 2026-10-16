local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

FDJ.Guides = {
    {
        key = "sleepingbag",
        name = "Cozy Sleeping Bag",
        level = 14,
        summary = "A hidden quest chain across both continents, started from a note in a burned cart. No dungeon needed.",
        reward = "Cozy Sleeping Bag",
        rewards = { 211527 },
        extras = { 2459, 3388, 1652, 4471, 5432, 20709 },
        steps = {
            { zone = "Westfall", x = 37.0, y = 50.0, title = "...and that note you found", side = "Alliance",
                text = "Alexston Farmstead. Alliance: click the charred remains in the cart wreckage to start the chain. Horde: hand the quest in here." },
            { zone = "The Barrens", x = 46.0, y = 74.0, title = "The burned tower", side = "Horde",
                text = "The burned tower south of Camp Taurajo. Horde: start the chain here. Alliance: hand it in here and take Stepping Stones." },
            { zone = "Stonetalon Mountains", x = 40.6, y = 52.4, title = "Stepping Stones",
                text = "Abandoned camp north-east of Sun Rock Retreat. Click the Pocket Litter on the crate to hand in and take Scramble. Lighting the fire gives the optional Rekindle." },
            { zone = "Stonetalon Mountains", x = 39.6, y = 49.8, title = "Scramble",
                text = "Walk up the hill to the Mound of Dirt and jump on it. This finishes Scramble and starts Wet Job." },
            { zone = "Loch Modan", x = 49.4, y = 12.9, title = "Wet Job",
                text = "On the dam, use the carved heads as stepping stones to reach the ledge with the Eagle Figurine. This starts Eagle's Fist." },
            { zone = "Hillsbrad Foothills", x = 87.3, y = 49.6, title = "Eagle's Fist",
                text = "Thoradin's Wall. Climb in using the cart and click the Messenger Bag on the wall, then click the Hastily Rolled-Up Satchel below it for the Cozy Sleeping Bag." },
        },
    },
}
