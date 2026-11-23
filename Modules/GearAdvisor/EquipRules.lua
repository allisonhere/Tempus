-- Gear Advisor: which slots an item really competes for, and what putting it on gives up. Pure
-- logic (no game calls), so the rules are tested outside the client. The caller passes what it knows.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local R = {}
GA.EquipRules = R

-- Inventory slots by item type. Weapons list both hands; Slots() trims the off hand for characters
-- that cannot dual wield.
R.SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}
R.MAIN, R.OFF = 16, 17

-- Level at which each class learns Dual Wield, for when the client cannot say whether it is known.
-- Shamans and others that need a talent are left out: unknown counts as no.
local DUAL_LEVEL = { WARRIOR = 20, ROGUE = 10, HUNTER = 20, DEATHKNIGHT = 1 }

-- Can this character dual wield? `known` is true when the game says the Dual Wield spell is learned.
-- A "no" is not trusted for classes that always learn it, in case the spell check is wrong for them.
function R.CanDualWield(class, level, known)
    if known == true then return true end
    local need = DUAL_LEVEL[class]
    return need ~= nil and type(level) == "number" and level >= need
end

-- The inventory slots an item of this type would take. Off-hand weapons only count for dual wielders.
function R.Slots(equipLoc, dual)
    local slots = R.SLOTS[equipLoc]
    if not slots then return nil end
    if equipLoc == "INVTYPE_WEAPON" and not dual then return { R.MAIN } end
    return slots
end

-- The item level you give up: the lowest of the slots the item would take, nil when a slot cannot be
-- read (an empty slot counts as 0, so anything beats it). levelOf(slot) returns a number or nil.
function R.Baseline(equipLoc, dual, levelOf)
    local slots = R.Slots(equipLoc, dual)
    if not slots then return nil end
    local lowest
    for _, slot in ipairs(slots) do
        local level = levelOf(slot)
        if type(level) ~= "number" then return nil end
        if lowest == nil or level < lowest then lowest = level end
    end
    return lowest
end

-- A plain warning for what equipping this would also take off, from the gear in the hands. `held`
-- reports what is in each hand slot: { [16] = loc or nil, [17] = loc or nil }.
function R.Displaced(equipLoc, held)
    local main, off = held[R.MAIN], held[R.OFF]
    if equipLoc == "INVTYPE_2HWEAPON" and off then
        return off == "INVTYPE_SHIELD" and "Also takes off your shield" or "Also takes off your off hand"
    end
    if (equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_WEAPONOFFHAND"
        or equipLoc == "INVTYPE_WEAPON") and main == "INVTYPE_2HWEAPON" then
        return "Takes off your two-hander"
    end
    return nil
end

-- A unique-equipped item you already wear cannot be bought again. `wornIds` lists the item IDs in the
-- slots the new item would take; `isUnique` is the game's answer for the item.
function R.UniqueConflict(itemId, isUnique, wornIds)
    if not isUnique then return false end
    for _, id in ipairs(wornIds) do
        if id == itemId then return true end
    end
    return false
end
