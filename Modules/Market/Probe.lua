-- /tempus gearprobe: lists which character, talent, stat and item calls this client really has, with
-- what they return, so Gear Advisor is built on what the game offers and not on guesses.
local _, T = ...
local M = T.Market

local function Show(v)
    if v == nil then return "nil" end
    if T.issecret and T.issecret(v) then return "<secret>" end
    local t = type(v)
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table(" .. n .. ")"
    end
    return tostring(v)
end

-- "name = type" when the call is missing, else the first few results of calling it.
local function Try(out, name, fn, ...)
    if type(fn) ~= "function" then out[#out + 1] = name .. ": missing" return end
    local r = { pcall(fn, ...) }
    if not r[1] then out[#out + 1] = name .. ": error " .. Show(r[2]) return end
    local parts = {}
    for i = 2, math.min(#r, 6) do parts[#parts + 1] = Show(r[i]) end
    out[#out + 1] = name .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "(no result)")
end

function M.GearProbe()
    local out = {}
    local _, class = UnitClass("player")
    out[#out + 1] = ("class %s, level %s, interface %s"):format(tostring(class), Show(UnitLevel("player")), select(4, GetBuildInfo()) and tostring(select(4, GetBuildInfo())) or "?")
    -- Specialisation (retail style).
    Try(out, "GetSpecialization", GetSpecialization)
    Try(out, "GetSpecializationInfo(1)", GetSpecializationInfo, 1)
    Try(out, "C_SpecializationInfo.GetSpecialization", C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    Try(out, "GetPrimaryTalentTree", GetPrimaryTalentTree)
    -- Talents (classic style).
    Try(out, "GetNumTalentTabs", GetNumTalentTabs)
    local tabs = GetNumTalentTabs and select(2, pcall(GetNumTalentTabs))
    if type(tabs) == "number" then
        for i = 1, math.min(tabs, 4) do Try(out, "GetTalentTabInfo(" .. i .. ")", GetTalentTabInfo, i) end
        Try(out, "GetNumTalents(1)", GetNumTalents, 1)
        Try(out, "GetTalentInfo(1, 1)", GetTalentInfo, 1, 1)
    end
    -- Trait system.
    Try(out, "C_ClassTalents.GetActiveConfigID", C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    Try(out, "C_Traits.GetConfigInfo", C_Traits and C_Traits.GetConfigInfo, 0)
    -- Stats and ratings.
    for i = 1, 5 do Try(out, "UnitStat(" .. i .. ")", UnitStat, "player", i) end
    Try(out, "UnitAttackPower", UnitAttackPower, "player")
    Try(out, "GetCritChance", GetCritChance)
    Try(out, "GetSpellCritChance(2)", GetSpellCritChance, 2)
    Try(out, "GetHitModifier", GetHitModifier)
    Try(out, "GetSpellHitModifier", GetSpellHitModifier)
    Try(out, "GetCombatRating(6)", GetCombatRating, 6)
    Try(out, "GetCombatRatingBonus(6)", GetCombatRatingBonus, 6)
    Try(out, "GetDodgeChance", GetDodgeChance)
    Try(out, "GetBlockChance", GetBlockChance)
    Try(out, "GetParryChance", GetParryChance)
    Try(out, "GetManaRegen", GetManaRegen)
    Try(out, "GetSpellBonusDamage(2)", GetSpellBonusDamage, 2)
    Try(out, "GetSpellBonusHealing", GetSpellBonusHealing)
    Try(out, "GetShapeshiftForm", GetShapeshiftForm)
    -- Weapon skills and equipment.
    Try(out, "GetNumSkillLines", GetNumSkillLines)
    Try(out, "C_SpellBook.IsSpellKnown(Dual Wield 674)", C_SpellBook and C_SpellBook.IsSpellKnown, 674)
    Try(out, "IsSpellKnown(674)", IsSpellKnown, 674)
    Try(out, "IsDualWielding", IsDualWielding)
    Try(out, "GetInventoryItemLink(16)", GetInventoryItemLink, "player", 16)
    -- Item data.
    local link = GetInventoryItemLink and select(2, pcall(GetInventoryItemLink, "player", 16))
    if type(link) == "string" then
        Try(out, "C_Item.GetItemStats(link)", C_Item and C_Item.GetItemStats, link)
        Try(out, "GetItemStats(link)", GetItemStats, link)
        Try(out, "C_Item.GetItemInfoInstant", C_Item and C_Item.GetItemInfoInstant, link)
        Try(out, "C_Item.GetDetailedItemLevelInfo", C_Item and C_Item.GetDetailedItemLevelInfo, link)
        Try(out, "C_TooltipInfo.GetHyperlink", C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
        Try(out, "C_Item.GetItemSpecInfo", C_Item and C_Item.GetItemSpecInfo, link)
        if C_Item and C_Item.GetItemStats then
            local ok, stats = pcall(C_Item.GetItemStats, link)
            if ok and type(stats) == "table" then
                local keys = {}
                for k in pairs(stats) do keys[#keys + 1] = tostring(k) end
                table.sort(keys)
                out[#out + 1] = "  stat keys on main hand: " .. table.concat(keys, ", ")
            end
        end
    else
        out[#out + 1] = "no main hand item to read; equip a weapon and run again for the item calls"
    end
    return out
end
