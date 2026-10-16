local Addon = FojjiCoreNS
if not (Addon and Addon.IsForever) then return end
local FDJ = Addon.DJ

FDJ.LoadScreens = {
    ragefire = "Interface\\Glues\\LoadingScreens\\LoadScreenRagefireChasm",
    wailing = "Interface\\Glues\\LoadingScreens\\LoadScreenWailingCaverns",
    shadowfang = "Interface\\Glues\\LoadingScreens\\LoadScreenShadowFangKeep",
    deadmines = "Interface\\Glues\\LoadingScreens\\LoadScreenDeadmines",
    blackfathom = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackFathomDeeps",
    gnomeregan = "Interface\\Glues\\LoadingScreens\\LoadScreenGnomeregan",
    stockade = 131870,
    kraul = 131865,
    sm_graveyard = "Interface\\Glues\\LoadingScreens\\LoadScreenScarletMonastery2",
}
