local _, Addon = ...

local Vendor = {}
Addon.Vendor = Vendor

local function db() return FojjiCoreDB or {} end
function Vendor.SellOn() return db().autoSell == true end
function Vendor.RepairOn() return db().autoRepair == true end
function Vendor.GuildOn() return db().autoRepairGuild ~= false end

local function coins(amount)
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    return tostring(amount)
end

local function sellGreys()
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo and C.UseContainerItem) then return 0, 0 end
    local count, total = 0, 0
    for bag = 0, tonumber(NUM_BAG_SLOTS) or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and info.quality == 0 and not info.hasNoValue and not info.isLocked then
                local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                local price = select(11, getInfo(info.itemID or info.hyperlink)) or 0
                if price > 0 then
                    C.UseContainerItem(bag, slot)
                    count = count + 1
                    total = total + price * (info.stackCount or 1)
                end
            end
        end
    end
    return count, total
end

local function repair()
    if not (CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems) then return 0 end
    local cost, needed = GetRepairAllCost()
    if not needed or not cost or cost <= 0 then return 0 end
    if Vendor.GuildOn() and IsInGuild and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair()
        and (not GetGuildBankWithdrawMoney or GetGuildBankWithdrawMoney() == -1 or GetGuildBankWithdrawMoney() >= cost) then
        RepairAllItems(true)
        return cost, true
    end
    if GetMoney() < cost then return -cost end
    RepairAllItems()
    return cost
end

function Vendor.OnMerchant()
    local parts = {}
    if Vendor.SellOn() then
        local count, total = sellGreys()
        if count > 0 then parts[#parts + 1] = ("sold %d grey item%s for %s"):format(count, count == 1 and "" or "s", coins(total)) end
    end
    if Vendor.RepairOn() then
        local cost, guild = repair()
        if cost > 0 then parts[#parts + 1] = ("repaired for %s%s"):format(coins(cost), guild and " (guild bank)" or "")
        elseif cost < 0 then parts[#parts + 1] = ("not enough gold to repair (%s)"):format(coins(-cost)) end
    end
    if #parts > 0 and Addon.Print then
        local line = table.concat(parts, ", ")
        Addon.Print(line:sub(1, 1):upper() .. line:sub(2) .. ".")
    end
end

local watch = CreateFrame("Frame")
watch:RegisterEvent("MERCHANT_SHOW")
watch:SetScript("OnEvent", Vendor.OnMerchant)

function Vendor.ShotOn() return db().capScreenshot == true end
local ding = CreateFrame("Frame")
ding:RegisterEvent("PLAYER_LEVEL_UP")
ding:SetScript("OnEvent", function(_, _, level)
    if not Vendor.ShotOn() or not Screenshot then return end
    local cap = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    if tonumber(level) and tonumber(level) >= cap then C_Timer.After(1.2, Screenshot) end
end)

function Vendor.SparkleOn() return db().lootSparkles ~= false end
local SPARKLE = {
    graphicsOutlineMode = "0", raidGraphicsOutlineMode = "0",
    OutlineEngineMode = "0", RAIDOutlineEngineMode = "0",
    outlineModeShowLootEffectWhenDisabled = "1",
}
local function cvar(name)
    local ok, v = pcall(GetCVar, name)
    if ok and type(v) == "string" then return v end
end
local writing, tries = false, {}
local function setCvar(name, value)
    if (tries[name] or 0) >= 4 then return end
    tries[name] = (tries[name] or 0) + 1
    writing = true
    pcall(SetCVar, name, value)
    writing = false
    if cvar(name) ~= value then tries[name] = 4 end
end
local pending = false
local function applySparkle()
    if InCombatLockdown() then pending = true; return end
    pending = false
    local d = db()
    if Vendor.SparkleOn() then
        d.sparkleBackup = d.sparkleBackup or {}
        for name, value in pairs(SPARKLE) do
            if d.sparkleBackup[name] == nil then d.sparkleBackup[name] = cvar(name) or false end
            if cvar(name) ~= value then setCvar(name, value) end
        end
    elseif d.sparkleBackup then
        for name, old in pairs(d.sparkleBackup) do
            if old ~= false and cvar(name) ~= old then setCvar(name, old) end
        end
        d.sparkleBackup = nil
    end
end
Vendor.ApplySparkle = applySparkle
local sparkle = CreateFrame("Frame")
sparkle:RegisterEvent("PLAYER_LOGIN")
sparkle:RegisterEvent("CVAR_UPDATE")
sparkle:RegisterEvent("PLAYER_REGEN_ENABLED")
local waiting = false
sparkle:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then applySparkle() end
        return
    end
    if not Vendor.SparkleOn() then return end
    if event == "CVAR_UPDATE" and (writing or not (type(name) == "string" and SPARKLE[name])) then return end
    if waiting then return end
    waiting = true
    C_Timer.After(0.5, function() waiting = false; applySparkle() end)
end)

function Vendor.TransmogOn() return db().transmogTip ~= false end
local KNOWN = TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN or "You've collected this appearance"
local OTHER = TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN or "You've collected this appearance, but not from this item"
local UNKNOWN = TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN or "You haven't collected this appearance"

local function alreadySays(tooltip)
    local name = tooltip.GetName and tooltip:GetName()
    if not name then return false end
    for i = 1, tooltip:NumLines() do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and fs:GetText()
        if t == KNOWN or t == OTHER or t == UNKNOWN then return true end
    end
    return false
end

local function addLine(tooltip, state)
    if state == "known" then
        tooltip:AddLine("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " .. KNOWN, 0.45, 0.85, 0.45)
    elseif state == "other" then
        tooltip:AddLine(OTHER, 0.45, 0.85, 0.45, true)
    else
        tooltip:AddLine(UNKNOWN, 0.53, 0.67, 1)
    end
    tooltip:Show()
end

local function transmogLine(tooltip)
    if not Vendor.TransmogOn() or not (tooltip == GameTooltip or tooltip == ItemRefTooltip
        or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2) then return end
    local TC = C_TransmogCollection
    if not TC then return end
    local _, link = tooltip:GetItem()
    if not link or (issecretvalue and issecretvalue(link)) then return end
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end
    if C_Item and C_Item.IsDressableItemByID then
        local okD, dress = pcall(C_Item.IsDressableItemByID, itemID)
        if okD and not dress then return end
    end
    if alreadySays(tooltip) then return end
    local appearanceID, sourceID
    if TC.GetItemInfo then
        local ok, a, sId = pcall(TC.GetItemInfo, link)
        if ok and a then appearanceID, sourceID = a, sId else
            ok, a, sId = pcall(TC.GetItemInfo, itemID)
            if ok and a then appearanceID, sourceID = a, sId end
        end
    end
    if sourceID and TC.PlayerHasTransmogItemModifiedAppearance then
        local okH, has = pcall(TC.PlayerHasTransmogItemModifiedAppearance, sourceID)
        if okH and has then return addLine(tooltip, "known") end
        if appearanceID and TC.GetAllAppearanceSources then
            local okS, sources = pcall(TC.GetAllAppearanceSources, appearanceID)
            for _, id in ipairs(okS and type(sources) == "table" and sources or {}) do
                local okK, known = pcall(TC.PlayerHasTransmogItemModifiedAppearance, id)
                if okK and known then return addLine(tooltip, "other") end
            end
        end
        return addLine(tooltip, "missing")
    end
    if TC.PlayerHasTransmog then
        local okP, has = pcall(TC.PlayerHasTransmog, itemID)
        if okP then return addLine(tooltip, has and "known" or "missing") end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) pcall(transmogLine, tooltip) end)
end

function Vendor.KillsOn() return db().killsTip == true end

local learned, levelSeen = {}, {}

local function zeroDiff(pl)
    if pl <= 7 then return 5 elseif pl <= 9 then return 6 elseif pl <= 11 then return 7 elseif pl <= 15 then return 8
    elseif pl <= 19 then return 9 elseif pl <= 29 then return 11 elseif pl <= 39 then return 12 elseif pl <= 44 then return 13
    elseif pl <= 49 then return 14 elseif pl <= 54 then return 15 elseif pl <= 59 then return 16 end
    return 17
end

local function greyLevel(pl)
    if pl <= 5 then return 0 elseif pl <= 39 then return pl - 5 - math.floor(pl / 10)
    elseif pl <= 59 then return pl - 1 - math.floor(pl / 5) end
    return pl - 9
end

local function curveXP(pl, ml, elite)
    if ml <= greyLevel(pl) then return 0 end
    local base = pl * 5 + 45
    local xp
    if ml >= pl then xp = base * (1 + 0.05 * math.min(ml - pl, 4))
    else xp = base * (1 - (pl - ml) / zeroDiff(pl)) end
    if elite then xp = xp * 2 end
    return math.max(0, xp)
end

local function ratio() return tonumber(FojjiCoreDB and FojjiCoreDB.xpRatio) or 1 end

local function killsLine(tooltip)
    if not Vendor.KillsOn() or tooltip ~= GameTooltip or tooltip.fcKills then return end
    local _, unit = tooltip:GetUnit()
    if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) then unit = "mouseover" end
    if not UnitExists(unit) or UnitIsPlayer(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then return end
    local pl = UnitLevel("player") or 1
    local cap = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    if pl >= cap then return end
    local ml = UnitLevel(unit)
    local name = UnitName(unit)
    if issecretvalue and (issecretvalue(ml) or issecretvalue(name)) then return end
    if not ml or ml < 1 or not name then return end
    levelSeen[name] = ml
    local need = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
    if need <= 0 then return end
    local class = UnitClassification(unit)
    local seen = learned[name]
    local each, exact
    if seen and seen.pl == pl then
        each, exact = seen.xp, true
    else
        each = curveXP(pl, ml, class == "elite" or class == "rareelite" or class == "worldboss") * ratio()
    end
    if each <= 0 then return end
    local n = math.ceil(need / each)
    tooltip.fcKills = true
    tooltip:AddLine((exact and "%d kills to level" or "~%d kills to level"):format(n), 0.65, 0.65, 0.68)
    tooltip:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip) pcall(killsLine, tooltip) end)
end
if GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tooltip) pcall(killsLine, tooltip) end)
    GameTooltip:HookScript("OnTooltipCleared", function(tooltip) tooltip.fcKills = nil end)
end

local function ours(f)
    for _ = 1, 25 do
        if not f then return false end
        local n = f.GetName and f:GetName()
        if type(n) == "string" and n:find("^FojjiCore") then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end

local function compareRight(tip)
    if not tip or (tip.IsForbidden and tip:IsForbidden()) or not tip:IsShown() then return end
    local list = tip.shoppingTooltips or { ShoppingTooltip1, ShoppingTooltip2 }
    local a, b = list[1], list[2]
    if not a or not a:IsShown() or not tip:GetRight() or not a:GetTop() or not tip:GetTop() then return end
    if not ours(tip:GetOwner()) then return end
    local bOn = b and b:IsShown() and b:GetTop() and true
    local scale = a:GetEffectiveScale() / tip:GetEffectiveScale()
    local width = (a:GetWidth() + (bOn and b:GetWidth() or 0)) * scale
    local screen = GetScreenWidth() * UIParent:GetEffectiveScale() / tip:GetEffectiveScale()
    local over = tip:GetRight() + width - screen
    if over > 0 then
        local left, top = tip:GetLeft() - over, tip:GetTop()
        tip:ClearAllPoints()
        tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", math.max(0, left), top)
    end
    local ay = a:GetTop() * scale - tip:GetTop()
    local by = bOn and (b:GetTop() - a:GetTop())
    a:ClearAllPoints()
    a:SetPoint("TOPLEFT", tip, "TOPRIGHT", 0, ay / scale)
    if bOn then
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", a, "TOPRIGHT", 0, by)
    end
end
local function later(tip) if C_Timer and C_Timer.After then C_Timer.After(0, function() pcall(compareRight, tip) end) end end
if TooltipComparisonManager and TooltipComparisonManager.AnchorShoppingTooltips then
    hooksecurefunc(TooltipComparisonManager, "AnchorShoppingTooltips", function(self) pcall(compareRight, self.tooltip or GameTooltip) end)
end
if GameTooltip_ShowCompareItem then
    hooksecurefunc("GameTooltip_ShowCompareItem", function(tip) pcall(compareRight, tip or GameTooltip) end)
end
if ShoppingTooltip1 and ShoppingTooltip1.HookScript then
    ShoppingTooltip1:HookScript("OnShow", function() later(GameTooltip) end)
end

local function gainPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p
end
local XP_GAIN = gainPattern(COMBATLOG_XPGAIN_FIRSTPERSON)
local XP_BONUS = "%+(%d+)"

local gain = CreateFrame("Frame")
gain:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
gain:SetScript("OnEvent", function(_, _, text)
    if not Vendor.KillsOn() or not XP_GAIN or type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    local name, xp = text:match(XP_GAIN)
    xp = tonumber(xp)
    if not name or not xp then return end
    local bonus = tonumber(text:match(XP_BONUS, #name + 10))
    if bonus and bonus < xp then xp = xp - bonus end
    local pl = UnitLevel("player") or 1
    learned[name] = { xp = xp, pl = pl }
    local ml = levelSeen[name]
    if ml then
        local guess = curveXP(pl, ml, false)
        if guess > 0 and xp > 0 then
            local r = xp / guess
            if r > 0.3 and r < 5 then
                FojjiCoreDB.xpRatio = (ratio() * 4 + r) / 5
            end
        end
    end
end)

function Vendor.PartyOn() return db().partyHelper == true end

function Vendor.PartyNames()
    local out = {}
    for name in tostring(db().partyNames or ""):gmatch("[^,;\n]+") do
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then out[#out + 1] = name end
    end
    return out
end

local function plain(name)
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return nil end
    return (name:gsub("%-.*$", "")):lower()
end

local function members()
    local list = {}
    local raid = IsInRaid and IsInRaid()
    local n = raid and (GetNumGroupMembers() or 0) or 4
    for i = 1, n do
        local unit = (raid and "raid" or "party") .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = GetUnitName and GetUnitName(unit, true) or UnitName(unit)
            local key = plain(name)
            if key then list[#list + 1] = { unit = unit, name = name, key = key } end
        end
    end
    return list
end

local helper

local function grouped() return (IsInGroup and IsInGroup()) or (GetNumGroupMembers and GetNumGroupMembers() > 0) end

local function refreshHelper()
    if not helper then return end
    local show = false
    if Vendor.PartyOn() then
        if not grouped() then
            show = #Vendor.PartyNames() > 0
        else
            local want = {}
            for _, name in ipairs(Vendor.PartyNames()) do want[plain(name)] = true end
            for _, m in ipairs(members()) do if want[m.key] then show = true break end end
        end
    end
    helper:SetShown(show)
    if show then
        helper.disband:SetEnabled(grouped())
        helper.disband:SetAlpha(grouped() and 1 or 0.45)
    end
end

function Vendor.Disband()
    if not grouped() then return end
    local leader = UnitIsGroupLeader and UnitIsGroupLeader("player")
    if leader then
        local uninvite = (C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit
        for _, m in ipairs(members()) do pcall(uninvite, m.name) end
    else
        local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
        if leave then leave() end
    end
end

function Vendor.InviteListed()
    local here = {}
    for _, m in ipairs(members()) do here[m.key] = true end
    local me = plain(UnitName("player"))
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    for _, name in ipairs(Vendor.PartyNames()) do
        local key = plain(name)
        if key and key ~= me and not here[key] and invite then
            pcall(invite, name)
        end
    end
end

local function buildHelper()
    local K = Addon.UIKit
    if helper or not K then return end
    local f = CreateFrame("Frame", "FojjiCorePartyHelper", UIParent)
    f:SetSize(162, 30)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    K.Surface(f, "frame", 0.94, "border", 1)
    local pos = db().partyHelperPos
    if type(pos) == "table" and pos[1] then f:SetPoint(pos[1], UIParent, pos[1], pos[2] or 0, pos[3] or 0) else f:SetPoint("CENTER", 0, -180) end
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if FojjiCoreDB then FojjiCoreDB.partyHelperPos = { point, x, y } end
    end)
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(18, 18)
    logo:SetPoint("LEFT", 6, 0)
    logo:SetTexture(K.TEX .. "logo-small-base")
    local ring = f:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetAllPoints(logo)
    ring:SetTexture(K.TEX .. "logo-small-arc")
    K.paint(function() ring:SetVertexColor(K.C("accent")) end)
    f.disband = K.Button(f, "Disband", 64, 20, "danger")
    f.disband:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    f.disband:SetScript("OnClick", Vendor.Disband)
    f.invite = K.Button(f, "Invite", 62, 20, "primary")
    f.invite:SetPoint("LEFT", f.disband, "RIGHT", 4, 0)
    f.invite:SetScript("OnClick", Vendor.InviteListed)
    f:Hide()
    helper = f
end

function Vendor.SetParty(on)
    if FojjiCoreDB then FojjiCoreDB.partyHelper = on and true or nil end
    if on then buildHelper() end
    refreshHelper()
end

function Vendor.SetPartyNames(text)
    if FojjiCoreDB then FojjiCoreDB.partyNames = text end
    refreshHelper()
end

local party = CreateFrame("Frame")
party:RegisterEvent("PLAYER_LOGIN")
party:RegisterEvent("GROUP_ROSTER_UPDATE")
party:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if Vendor.PartyOn() then buildHelper() end
    end
    refreshHelper()
end)

function Vendor.GuildInviteOn() return db().guildAccept == true end

local function inGuild(name, guid)
    if not (IsInGuild and IsInGuild()) then return false end
    if guid and IsGuildMember then
        local ok, yes = pcall(IsGuildMember, guid)
        if ok and yes then return true end
    end
    local want = plain(name)
    if not want or not GetNumGuildMembers or not GetGuildRosterInfo then return false end
    for i = 1, GetNumGuildMembers() or 0 do
        if plain((GetGuildRosterInfo(i))) == want then return true end
    end
    return false
end

-- Credit: approach from Leatrix Plus (auto accept party invites).
local function closeInvitePopup()
    for i = 1, tonumber(STATICPOPUP_NUMDIALOGS) or 4 do
        local popup = _G["StaticPopup" .. i]
        local which = popup and popup:IsShown() and popup.which
        if which == "PARTY_INVITE" or which == "PARTY_INVITE_XREALM" then
            popup.inviteAccepted = 1
            if StaticPopup_Hide and not (Addon.GamepadUI and Addon.GamepadUI()) then StaticPopup_Hide(which) end
            return true
        end
    end
end
function Vendor.AcceptInvite()
    if not AcceptGroup then return end
    AcceptGroup()
    if not closeInvitePopup() and C_Timer then C_Timer.After(0, closeInvitePopup) end
end

local invites = CreateFrame("Frame")
invites:RegisterEvent("PARTY_INVITE_REQUEST")
invites:RegisterEvent("PLAYER_LOGIN")
invites:SetScript("OnEvent", function(_, event, name, ...)
    if not Vendor.GuildInviteOn() then return end
    if event == "PLAYER_LOGIN" then
        local ask = (C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster
        if ask and IsInGuild and IsInGuild() then pcall(ask) end
        return
    end
    local guid = select(6, ...)
    if type(guid) ~= "string" then guid = nil end
    if not (inGuild(name, guid) and AcceptGroup) then return end
    Vendor.AcceptInvite()
end)
