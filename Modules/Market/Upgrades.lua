-- Cheapest gear upgrades from the Tempus auction scan. An upgrade is an item level above what you
-- wear in that slot (the same rule as the Bags arrow). Ranked by how much the stats you care about
-- improve (item levels when stats are unreadable), balanced against price so neither a nearly free
-- +1 nor a huge price tag wins on its own. Items whose stats are worse for your class are dropped.
local _, T = ...
local M = T.Market
local S = T.Style

local PER_GROUP = 8               -- best deals kept per slot group
local LIMIT = 250                 -- display rows: items plus group headers
local VISIBLE = 21                -- rows visible at once; the rest scroll
local REQUESTS_PER_PASS = 150     -- uncached items asked for per refresh, so the client is not flooded
local SKIP_LOCS = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local RANGED_SLOT = 18

-- Highest armor subclass each class wears (1 cloth, 2 leather, 3 mail, 4 plate), and the level at
-- which the heavier type unlocks for classes that start one type lower.
local ARMOR_TOP = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2,
    PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local ARMOR_UNLOCK = { WARRIOR = 40, PALADIN = 40, HUNTER = 40, SHAMAN = 40 }
local SHIELDS = { WARRIOR = true, PALADIN = true, SHAMAN = true }

-- What a stat is worth to each class, relative to its main stat. Used to tell a real upgrade from a
-- higher item level with the wrong stats (spirit on a cat's gloves). Unlisted stats count for nothing.
local MELEE = { ITEM_MOD_STRENGTH_SHORT = 1, ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_STAMINA_SHORT = 0.5,
    ITEM_MOD_ATTACK_POWER_SHORT = 0.5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6, RESISTANCE0_NAME = 0.02,
    ITEM_MOD_CRIT_RATING_SHORT = 0.8, ITEM_MOD_HIT_RATING_SHORT = 0.8, ITEM_MOD_HASTE_RATING_SHORT = 0.7,
    ITEM_MOD_EXPERTISE_RATING_SHORT = 0.7 }
local CASTER = { ITEM_MOD_INTELLECT_SHORT = 1, ITEM_MOD_SPIRIT_SHORT = 0.4, ITEM_MOD_STAMINA_SHORT = 0.4,
    ITEM_MOD_SPELL_POWER_SHORT = 0.9, ITEM_MOD_MANA_REGENERATION_SHORT = 0.5, RESISTANCE0_NAME = 0.01,
    ITEM_MOD_CRIT_RATING_SHORT = 0.7, ITEM_MOD_HIT_RATING_SHORT = 0.7, ITEM_MOD_HASTE_RATING_SHORT = 0.7 }
local WEIGHTS = {
    WARRIOR = { ITEM_MOD_STRENGTH_SHORT = 1, ITEM_MOD_AGILITY_SHORT = 0.5, ITEM_MOD_STAMINA_SHORT = 0.6,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6, RESISTANCE0_NAME = 0.03,
        ITEM_MOD_CRIT_RATING_SHORT = 0.8, ITEM_MOD_HIT_RATING_SHORT = 0.8, ITEM_MOD_EXPERTISE_RATING_SHORT = 0.7 },
    PALADIN = { ITEM_MOD_STRENGTH_SHORT = 1, ITEM_MOD_STAMINA_SHORT = 0.6, ITEM_MOD_INTELLECT_SHORT = 0.5,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.4, ITEM_MOD_SPELL_POWER_SHORT = 0.4, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5,
        RESISTANCE0_NAME = 0.03 },
    DEATHKNIGHT = { ITEM_MOD_STRENGTH_SHORT = 1, ITEM_MOD_STAMINA_SHORT = 0.6, ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6, RESISTANCE0_NAME = 0.03 },
    ROGUE = { ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_STRENGTH_SHORT = 0.4, ITEM_MOD_STAMINA_SHORT = 0.4,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6, ITEM_MOD_CRIT_RATING_SHORT = 0.8,
        ITEM_MOD_HIT_RATING_SHORT = 0.8, ITEM_MOD_HASTE_RATING_SHORT = 0.7, ITEM_MOD_EXPERTISE_RATING_SHORT = 0.7 },
    HUNTER = { ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_STAMINA_SHORT = 0.4, ITEM_MOD_INTELLECT_SHORT = 0.3,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6, ITEM_MOD_CRIT_RATING_SHORT = 0.8,
        ITEM_MOD_HIT_RATING_SHORT = 0.8 },
    SHAMAN = { ITEM_MOD_AGILITY_SHORT = 0.8, ITEM_MOD_STRENGTH_SHORT = 0.6, ITEM_MOD_INTELLECT_SHORT = 0.8,
        ITEM_MOD_STAMINA_SHORT = 0.5, ITEM_MOD_ATTACK_POWER_SHORT = 0.4, ITEM_MOD_SPELL_POWER_SHORT = 0.6,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 4, RESISTANCE0_NAME = 0.02 },
    -- Druids are one class with several jobs; this favours the cat/bear side (agility, strength, stamina).
    DRUID = { ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_STRENGTH_SHORT = 0.9, ITEM_MOD_STAMINA_SHORT = 0.5,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5, ITEM_MOD_INTELLECT_SHORT = 0.2, ITEM_MOD_SPIRIT_SHORT = 0.1,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5, RESISTANCE0_NAME = 0.02, ITEM_MOD_CRIT_RATING_SHORT = 0.7,
        ITEM_MOD_HIT_RATING_SHORT = 0.7 },
    PRIEST = CASTER, MAGE = CASTER, WARLOCK = CASTER,
}
M.WEIGHTS = WEIGHTS

local function Set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
-- Weapon subclasses by class: 0/1 axe, 2 bow, 3 gun, 4/5 mace, 6 polearm, 7/8 sword, 10 staff,
-- 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local WEAPONS = {
    WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
    DEATHKNIGHT = Set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18),
    ROGUE = Set(0, 2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST = Set(4, 10, 15, 19),
    SHAMAN = Set(0, 1, 4, 5, 10, 13, 15),
    MAGE = Set(7, 10, 15, 19),
    WARLOCK = Set(7, 10, 15, 19),
    DRUID = Set(4, 5, 6, 10, 13, 15),
}

local function Num(v) return T.Num(v) and v == v and not (T.issecret and T.issecret(v)) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end

local R = T.GearAdvisor.EquipRules
local Dual = false          -- can this character dual wield; refreshed at the start of each search

local function CanDual()
    local _, class = UnitClass("player")
    local fn = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    local known
    if fn then
        local ok, v = pcall(fn, 674)
        if ok and type(v) == "boolean" then known = v end
    end
    return R.CanDualWield(class, UnitLevel("player"), known)
end

local function HeldTypes()
    local held = {}
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    for _, slot in ipairs({ R.MAIN, R.OFF }) do
        local id = Call(GetInventoryItemID, "player", slot)
        if id then held[slot] = select(4, Call(instant, id)) end
    end
    return held
end

-- Can this class use the item? Unknown classes are not filtered. Rings, necks, trinkets, cloaks and
-- held-in-off-hand items are usable by everyone.
function M.CanUse(class, level, classID, subClassID, equipLoc, minLevel)
    if Num(minLevel) and Num(level) and minLevel > level then return false end
    if classID == 4 then
        if subClassID == 0 or equipLoc == "INVTYPE_CLOAK" then return true end
        if subClassID == 6 then return SHIELDS[class] == true end
        if subClassID >= 1 and subClassID <= 4 then
            local top = ARMOR_TOP[class]
            if not top then return true end
            if ARMOR_UNLOCK[class] and Num(level) and level < ARMOR_UNLOCK[class] then top = top - 1 end
            return subClassID == top
        end
        return false
    end
    if classID == 2 then
        local allowed = WEAPONS[class]
        return allowed == nil or allowed[subClassID] == true
    end
    return false
end

local function WornLevel(loc)
    if RANGED[loc] then
        local link = Call(GetInventoryItemLink, "player", RANGED_SLOT)
        if not link then return 0 end
        local lvl = Call(C_Item and C_Item.GetDetailedItemLevelInfo, link)
        return Num(lvl) and lvl or nil
    end
    return R.Baseline(loc, Dual, function(slot)
        local link = Call(GetInventoryItemLink, "player", slot)
        if not link then return 0 end
        local lvl = Call(C_Item and C_Item.GetDetailedItemLevelInfo, link)
        return Num(lvl) and lvl or nil
    end)
end

-- Gear metadata is read once per item and remembered on its price row (c = class, l = slot, s = subclass).
local function GearInfo(id, row, instant)
    if row.c == nil then
        local ok, _, _, _, loc, _, classID, subClassID = pcall(instant, id)
        if ok and Num(classID) then
            row.c, row.l, row.s = classID, type(loc) == "string" and loc or "", subClassID or 0
        else
            return nil
        end
    end
    local slots = T.Bags.Client.EQUIP_SLOTS
    if (row.c == 2 or row.c == 4) and slots[row.l] and not SKIP_LOCS[row.l] then return row end
    return nil
end

-- Slot groups, in the order the panel lists them. Variants of one slot share a group.
local GROUPS = {
    { "head", "Head", "INVTYPE_HEAD" }, { "neck", "Neck", "INVTYPE_NECK" },
    { "shoulder", "Shoulders", "INVTYPE_SHOULDER" }, { "back", "Back", "INVTYPE_CLOAK" },
    { "chest", "Chest", "INVTYPE_CHEST" }, { "wrist", "Wrists", "INVTYPE_WRIST" },
    { "hands", "Hands", "INVTYPE_HAND" }, { "waist", "Waist", "INVTYPE_WAIST" },
    { "legs", "Legs", "INVTYPE_LEGS" }, { "feet", "Feet", "INVTYPE_FEET" },
    { "finger", "Rings", "INVTYPE_FINGER" }, { "trinket", "Trinkets", "INVTYPE_TRINKET" },
    { "weapon", "One-hand weapons", "INVTYPE_WEAPON" }, { "mainhand", "Main hand", "INVTYPE_WEAPONMAINHAND" },
    { "twohand", "Two-hand weapons", "INVTYPE_2HWEAPON" }, { "offhand", "Off hand", "INVTYPE_WEAPONOFFHAND" },
    { "shield", "Shields", "INVTYPE_SHIELD" }, { "held", "Held in off hand", "INVTYPE_HOLDABLE" },
    { "ranged", "Ranged", "INVTYPE_RANGED" },
}
local GROUP_OF = { INVTYPE_ROBE = "chest", INVTYPE_RANGEDRIGHT = "ranged", INVTYPE_THROWN = "ranged" }
local GROUP_INDEX = {}
for i, g in ipairs(GROUPS) do GROUP_INDEX[g[1]] = i; GROUP_OF[g[3]] = GROUP_OF[g[3]] or g[1] end

function M.GroupKey(loc) return GROUP_OF[loc] end

-- Auction house filters ---------------------------------------------------------------------
-- The AH search bar keeps its filter state in the global g_auctionHouseFilters (required-level
-- range plus one flag per rarity). We read it so the list narrows the same way the AH does.

local QUALITY_FILTERS = { [0] = "PoorQuality", "CommonQuality", "UncommonQuality", "RareQuality", "EpicQuality",
    "LegendaryQuality", "ArtifactQuality" }
local QUALITY_NAMES = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact" }

-- The numbers the AH category filters use for an item's equip slot.
local INVENTORY_TYPE = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16,
    INVTYPE_2HWEAPON = 17, INVTYPE_BAG = 18, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21,
    INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26 }

-- The selected AH category as a list of { classID, subClassID, inventoryType } (any may be nil =
-- any), plus its name; nil when no category is selected or the AH frame is not there.
function M.ReadAHCategory(env)
    env = env or _G
    local frame = rawget(env, "AuctionHouseFrame")
    local list = type(frame) == "table" and frame.CategoriesList
    if type(list) ~= "table" or type(list.GetCategoryFilterData) ~= "function" then return nil end
    local ok, filters = pcall(list.GetCategoryFilterData, list)
    if not ok or type(filters) ~= "table" or #filters == 0 then return nil end
    local out = {}
    for _, f in ipairs(filters) do
        if type(f) == "table" and (f.classID ~= nil or f.subClassID ~= nil or f.inventoryType ~= nil) then
            out[#out + 1] = { classID = Num(f.classID) and f.classID or nil, subClassID = Num(f.subClassID) and f.subClassID or nil,
                inventoryType = Num(f.inventoryType) and f.inventoryType or nil }
        end
    end
    if #out == 0 then return nil end
    local name
    if type(list.GetCategoryData) == "function" then
        local ok2, data = pcall(list.GetCategoryData, list)
        if ok2 and type(data) == "table" and type(data.name) == "string" then name = data.name end
    end
    return out, name
end

-- nil = nothing is filtered (or the AH has never been opened); otherwise
-- { minLevel, maxLevel, quality = { [0..6] = false for hidden rarities } }.
function M.ReadAHFilters(env)
    env = env or _G
    local g = rawget(env, "g_auctionHouseFilters")
    if type(g) ~= "table" then g = {} end
    local out, active = { minLevel = 0, maxLevel = 0, quality = {} }, false
    local lo, hi = g.minLevel, g.maxLevel
    if Num(lo) and lo > 0 then out.minLevel, active = lo, true end
    if Num(hi) and hi > 0 then out.maxLevel, active = hi, true end
    local flags, enum = g.filters, env.Enum and env.Enum.AuctionHouseFilter
    if type(flags) == "table" and type(enum) == "table" then
        for q, name in pairs(QUALITY_FILTERS) do
            local id = enum[name]
            if id ~= nil and flags[id] == false then out.quality[q], active = false, true end
        end
    end
    -- The category picked in the AH's left-hand list (for example Weapons > Two-Handed Swords).
    local cat, name = M.ReadAHCategory(env)
    if cat then out.categories, out.categoryName, active = cat, name, true end
    return active and out or nil
end

-- Does an item of this quality and required level survive the filters? Unknown values pass.
function M.PassesFilters(filters, quality, requiredLevel, classID, subClassID, equipLoc)
    if not filters then return true end
    if filters.categories then
        local inv, any = INVENTORY_TYPE[equipLoc or ""], false
        for _, f in ipairs(filters.categories) do
            if (f.classID == nil or f.classID == classID) and (f.subClassID == nil or f.subClassID == subClassID)
                and (f.inventoryType == nil or f.inventoryType == inv) then any = true break end
        end
        if not any then return false end
    end
    if Num(quality) and filters.quality[quality] == false then return false end
    if Num(requiredLevel) then
        if filters.minLevel > 0 and requiredLevel < filters.minLevel then return false end
        if filters.maxLevel > 0 and requiredLevel > filters.maxLevel then return false end
    end
    return true
end

-- A string that changes whenever the AH filters do, so the open list can notice.
function M.FilterSignature()
    local f = M.ReadAHFilters()
    if not f then return "" end
    local parts = { f.minLevel, f.maxLevel }
    for q = 0, 6 do parts[#parts + 1] = f.quality[q] == false and 0 or 1 end
    for _, c in ipairs(f.categories or {}) do
        parts[#parts + 1] = (c.classID or "-") .. "." .. (c.subClassID or "-") .. "." .. (c.inventoryType or "-")
    end
    return table.concat(parts, ",")
end

function M.FilterSummary(filters)
    if not filters then return "" end
    local parts, shown = {}, {}
    if filters.categories then parts[#parts + 1] = filters.categoryName or "category" end
    for q = 0, 6 do if filters.quality[q] ~= false then shown[#shown + 1] = q end end
    if #shown < 7 and #shown > 0 then
        local contiguous = shown[#shown] - shown[1] == #shown - 1
        if contiguous and shown[#shown] >= 4 then
            parts[#parts + 1] = QUALITY_NAMES[shown[1]] .. "+"
        else
            local names = {}
            for _, q in ipairs(shown) do names[#names + 1] = QUALITY_NAMES[q] end
            parts[#parts + 1] = table.concat(names, "/")
        end
    end
    local lo, hi = filters.minLevel, filters.maxLevel
    if lo > 0 and hi > 0 then parts[#parts + 1] = ("level %d-%d"):format(lo, hi)
    elseif lo > 0 then parts[#parts + 1] = ("level %d+"):format(lo)
    elseif hi > 0 then parts[#parts + 1] = ("up to level %d"):format(hi) end
    return table.concat(parts, ", ")
end

-- Returns a ranked list, the number of items still waiting on item data, and how many were
-- requested this pass. Entry: { id, price, age, gain, level, worn, loc, score }.
local WornLink      -- defined with the detail code below

function M:FindUpgrades()
    local store = self.Store()
    local db = T.db.market or {}
    local C = C_Item
    local instant = (C and C.GetItemInfoInstant) or GetItemInfoInstant
    local getInfo = (C and C.GetItemInfo) or GetItemInfo
    local detailed = C and C.GetDetailedItemLevelInfo
    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    local money = db.upgradeAffordable and Call(GetMoney) or nil
    local cap = Num(db.upgradeMaxGold) and db.upgradeMaxGold > 0 and db.upgradeMaxGold * 10000 or nil
    local minGain = Num(db.upgradeMinGain) and db.upgradeMinGain or 1
    local now = time()
    local worn, out, pending, requested = {}, {}, 0, 0
    local wornLinks = {}
    local sort = db.upgradeSort or "VALUE"
    local staleDays = Num(db.staleDays) and db.staleDays or 3
    local filters = db.upgradeUseAHFilters ~= false and M.ReadAHFilters() or nil
    local hidden = 0
    if type(instant) ~= "function" or type(getInfo) ~= "function" then return out, 0, 0 end
    Dual = CanDual()
    local held = HeldTypes()
    local uniqueOf = C and C.GetItemUniquenessByID
    local wornIds = {}

    for id, row in pairs(store.items) do
        if GearInfo(id, row, instant) then
            local loc = row.l
            if worn[loc] == nil then worn[loc] = WornLevel(loc) or false end
            local base = worn[loc]
            if base ~= false and M.CanUse(class, level, row.c, row.s, loc, nil)
                and not (money and row.p > money) and not (cap and row.p > cap) then
                local _, _, quality, ilvl, minLevel = getInfo(id)
                local eff = Call(detailed, id)
                if Num(eff) and eff > 0 then ilvl = eff end
                if not Num(ilvl) then
                    pending = pending + 1
                    if requested < REQUESTS_PER_PASS and C and C.RequestLoadItemDataByID then
                        requested = requested + 1
                        Call(C.RequestLoadItemDataByID, id)
                    end
                elseif ilvl - base >= minGain and M.CanUse(class, level, row.c, row.s, loc, minLevel) then
                    local gain = ilvl - base
                    if wornIds[loc] == nil then
                        wornIds[loc] = {}
                        for _, slot in ipairs(R.Slots(loc, Dual) or {}) do
                            local wid = Call(GetInventoryItemID, "player", slot)
                            if wid then wornIds[loc][#wornIds[loc] + 1] = wid end
                        end
                    end
                    local unique = uniqueOf and Call(uniqueOf, id)
                    if not M.PassesFilters(filters, quality, minLevel, row.c, row.s, loc)
                        or R.UniqueConflict(id, unique == true, wornIds[loc]) then
                        hidden = hidden + 1
                    else
                        -- What the stats are worth to your class; nil when the client gives none.
                        if wornLinks[loc] == nil then wornLinks[loc] = WornLink(loc) or false end
                        local useful = M.UsefulScore("item:" .. id, wornLinks[loc] or nil, class)
                        if not (useful and useful <= 0) then
                            local gold = math.max(row.p / 10000, 0.01)
                            local age = Num(row.t) and math.max(0, math.floor((now - row.t) / 86400)) or nil
                            -- Worth, balanced against price: sqrt so a +1 for pennies does not beat a real
                            -- upgrade for a few gold; older prices count a little less.
                            local worth = useful or gain
                            local rank = worth / math.sqrt(gold)
                            if age and age > staleDays then rank = rank * 0.85 end
                            out[#out + 1] = { id = id, price = row.p, gain = gain, level = ilvl, worn = base, loc = loc,
                                age = age, score = gain / gold, quality = quality, useful = useful, worth = worth, rank = rank,
                                note = R.Displaced(loc, held) }
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if sort == "BIGGEST" then
            if a.worth ~= b.worth then return a.worth > b.worth end
            if a.price ~= b.price then return a.price < b.price end
        elseif sort == "CHEAPEST" then
            if a.price ~= b.price then return a.price < b.price end
            if a.worth ~= b.worth then return a.worth > b.worth end
        else
            if a.rank ~= b.rank then return a.rank > b.rank end
            if a.price ~= b.price then return a.price < b.price end
        end
        return a.id < b.id
    end)
    -- Keep the best few per slot group so every slot is covered, not just the best-value one.
    local kept, counts = {}, {}
    for _, e in ipairs(out) do
        local key = GROUP_OF[e.loc]
        counts[key] = (counts[key] or 0) + 1
        if counts[key] <= PER_GROUP then kept[#kept + 1] = e end
    end
    return kept, pending, requested, hidden, filters
end

-- What improves ------------------------------------------------------------------------------

local SHORT = { ITEM_MOD_STRENGTH_SHORT = "Str", ITEM_MOD_AGILITY_SHORT = "Agi", ITEM_MOD_STAMINA_SHORT = "Sta",
    ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_SPIRIT_SHORT = "Spi", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS", RESISTANCE0_NAME = "Armor" }

-- Shown in full ("Strength", not "Str"): the game's own stat names, with plain fallbacks.
local FULL = { ITEM_MOD_STRENGTH_SHORT = "Strength", ITEM_MOD_AGILITY_SHORT = "Agility", ITEM_MOD_STAMINA_SHORT = "Stamina",
    ITEM_MOD_INTELLECT_SHORT = "Intellect", ITEM_MOD_SPIRIT_SHORT = "Spirit", ITEM_MOD_ATTACK_POWER_SHORT = "Attack Power",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Damage Per Second", RESISTANCE0_NAME = "Armor" }

local function StatLabel(key)
    local text = _G[key]
    if type(text) == "string" and text ~= "" then return text end
    return FULL[key]
end

local function StatsOf(link)
    local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not link then return {} end
    local ok, t = pcall(fn, link)
    return ok and type(t) == "table" and t or {}
end

-- How much better the stats get for this class when `newLink` replaces `oldLink` (negative when
-- they get worse). nil when the client gives no stats for either, so callers fall back to item level.
function M.UsefulScore(newLink, oldLink, class)
    local w = WEIGHTS[class]
    if not w then return nil end
    local new, old = StatsOf(newLink), StatsOf(oldLink)
    if next(new) == nil and next(old) == nil then return nil end
    local total = 0
    for key, weight in pairs(w) do
        local n, o = Num(new[key]) and new[key] or 0, Num(old[key]) and old[key] or 0
        total = total + (n - o) * weight
    end
    return total
end

-- Sort orders for the list.
M.SORTS = { { "VALUE", "Best value" }, { "BIGGEST", "Biggest upgrade" }, { "CHEAPEST", "Cheapest" } }

-- The stats that go up when `newLink` replaces `oldLink` (nil = empty slot): up to `max` entries,
-- largest gain first, as { label, amount }.
function M.StatGains(newLink, oldLink, max, withLosses, withUnchanged)
    local new, old, out, seen = StatsOf(newLink), StatsOf(oldLink), {}, {}
    local function add(key)
        if seen[key] then return end
        seen[key] = true
        local n, o = Num(new[key]) and new[key] or 0, Num(old[key]) and old[key] or 0
        local delta = n - o
        local label = (delta > 0 or (withLosses and delta < 0) or (withUnchanged and delta == 0)) and StatLabel(key)
        if label then out[#out + 1] = { label = label, amount = delta, key = key, old = o, new = n } end
    end
    for key in pairs(new) do add(key) end
    if withLosses or withUnchanged then for key in pairs(old) do add(key) end end
    table.sort(out, function(a, b)
        local x, y = math.abs(a.amount), math.abs(b.amount)
        if x ~= y then return x > y end
        return a.key < b.key
    end)
    while #out > (max or 3) do out[#out] = nil end
    return out
end

-- One colour per stat so the same stat reads the same down the whole list.
local BAR_COLORS = { Str = { 0.86, 0.36, 0.30 }, Agi = { 0.36, 0.78, 0.42 }, Sta = { 0.93, 0.60, 0.26 },
    Int = { 0.38, 0.62, 0.95 }, Spi = { 0.72, 0.62, 0.92 }, AP = { 0.95, 0.78, 0.30 }, DPS = { 0.95, 0.78, 0.30 },
    Armor = { 0.62, 0.68, 0.74 } }
local BAR_DEFAULT = { 0.45, 0.78, 0.78 }

-- Colour by stat: pass the item-stat key when known (so full names still map), else the short label.
function M.BarColor(label, key) return BAR_COLORS[SHORT[key or ""] or label] or BAR_DEFAULT end

-- Fill width for one stat: its share of the biggest gain of that stat in the list, never a bare
-- sliver, so small upgrades still show a bar.
function M.BarWidth(amount, max, width)
    if not (Num(amount) and Num(max)) or max <= 0 or amount <= 0 then return 0 end
    return math.max(3, math.floor(width * math.min(1, amount / max) + 0.5))
end

local function AmountText(a) return a == math.floor(a) and ("%d"):format(a) or ("%.1f"):format(a) end

-- The worn item the candidate would replace: the lowest item level among its slots (empty = nil).
function WornLink(loc)
    local slots = RANGED[loc] and { RANGED_SLOT } or R.Slots(loc, Dual)
    local detailed = C_Item and C_Item.GetDetailedItemLevelInfo
    local best, bestLevel
    for _, slot in ipairs(slots or {}) do
        local link = Call(GetInventoryItemLink, "player", slot)
        local lvl = link and Call(detailed, link) or 0
        if not Num(lvl) then lvl = 0 end
        if bestLevel == nil or lvl < bestLevel then best, bestLevel = link, lvl end
    end
    return best
end

-- The list as the panel shows it: a header row per slot group (in GROUPS order) followed by that
-- group's items, best deal first.
function M.Layout(list)
    local by, out = {}, {}
    for _, e in ipairs(list) do
        local key = GROUP_OF[e.loc]
        by[key] = by[key] or {}
        by[key][#by[key] + 1] = e
    end
    for _, g in ipairs(GROUPS) do
        local items = by[g[1]]
        if items then
            out[#out + 1] = { header = g[2], count = #items }
            for _, e in ipairs(items) do out[#out + 1] = e end
        end
    end
    return out
end

-- Panel -----------------------------------------------------------------------------------------

local ROW_H, WIDTH = 22, 440
local DETAIL_W = 340    -- the detail pane to the right of the list

local function Money(copper)
    copper = math.floor(copper + 0.5)
    if copper >= 10000 then return ("%dg %ds"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100) end
    return ("%ds %dc"):format(math.floor(copper / 100), copper % 100)
end

-- Coins in their own colours: gold, silver, copper.
local function MoneyText(copper)
    copper = math.floor(copper + 0.5)
    local g, sv, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return ("%d|cffFFD633g|r %d|cffC9CBD3s|r"):format(g, sv) end
    return ("%d|cffC9CBD3s|r %d|cffE8A060c|r"):format(sv, c)
end
M.MoneyText = MoneyText

-- The item's rarity colour (white if unknown).
local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and Num(q) and ITEM_QUALITY_COLORS[q]
    if c and Num(c.r) then return c.r, c.g, c.b end
    return 0.62, 0.64, 0.7
end
M.QualityColor = QualityColor

-- Green that deepens with the size of the gain, for the ilvl badge.
local function GainColor(gain)
    local t = math.min(1, math.max(0, (Num(gain) and gain or 0) / 30))
    return 0.25 + 0.07 * t, 0.62 + 0.30 * t, 0.58 - 0.20 * t
end

-- The window has its own palette (auction-house gold), independent of the Tempus accent colour.
local GOLD = { 1, 0.80, 0.32 }
local function Paint(tex, c, a) tex:SetVertexColor(c[1], c[2], c[3], a or 1) return tex end

-- Heat map for the value meters: cold red for a weak deal through yellow to green for the best.
local function HeatColor(t)
    t = math.max(0, math.min(1, Num(t) and t or 0))
    if t < 0.5 then
        local u = t / 0.5
        return 0.95 + 0.05 * u, 0.25 + 0.55 * u, 0.25 + 0.07 * u
    end
    local u = (t - 0.5) / 0.5
    return 1 - 0.68 * u, 0.80 + 0.12 * u, 0.32 + 0.16 * u
end
M.HeatColor = HeatColor

local DETAIL_STATS = 7
local COL_W, BAR_COL = math.floor((DETAIL_W - 20) / DETAIL_STATS), 28
local TABLE_Y, TABLE_ROW, TABLE_ROWS = 118, 16, 8      -- current / buy comparison table
local CHART_TOP, CHART_H = 292, 150
local CHART_MID, HALF = CHART_TOP + CHART_H / 2, 58     -- centre line; tallest bar either way
local GROUP_LABEL = {}
for _, g in ipairs(GROUPS) do GROUP_LABEL[g[1]] = g[2] end

-- Everything the detail pane shows for one listed item.
function M.DetailInfo(e)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, _, _, _, _, _, _, _, icon = getInfo(e.id)
    local worn = WornLink(e.loc)
    return { name = name, link = link, icon = icon, slot = GROUP_LABEL[GROUP_OF[e.loc]] or "", level = e.level,
        worn = e.worn, wornLink = worn, gain = e.gain, price = e.price, age = e.age,
        perGold = e.score, note = e.note, stats = M.StatGains(link or ("item:" .. e.id), worn, DETAIL_STATS, true),
        all = M.StatGains(link or ("item:" .. e.id), worn, TABLE_ROWS, true, true) }
end

function M.BuildDetail(p, scroll)
    local d = CreateFrame("Frame", nil, p)
    d:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    d:SetSize(DETAIL_W - 18, VISIBLE * ROW_H)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(36, 36)
    d.icon:SetPoint("TOPLEFT", 0, 0)
    d.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    d.glow = d:CreateTexture(nil, "BORDER")
    d.glow:SetColorTexture(1, 1, 1, 1)
    d.glow:SetPoint("TOPLEFT", d.icon, -2, 2)
    d.glow:SetPoint("BOTTOMRIGHT", d.icon, 2, -2)
    d.name = S.Text(d, 13, S.C.text)
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 8, -2)
    d.name:SetWidth(DETAIL_W - 70)
    d.name:SetWordWrap(false)
    d.slot = S.Text(d, 11, S.C.muted)
    d.slot:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -3)
    d.line = {}
    for i = 1, 4 do
        d.line[i] = S.Text(d, 11, S.C.text)
        d.line[i]:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10 - (i - 1) * 16)
        d.line[i]:SetWidth(DETAIL_W - 20)
        d.line[i]:SetWordWrap(false)
    end
    d.head = S.Text(d, 11, GOLD)
    d.head:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -(CHART_TOP - 16))
    -- Side-by-side table: what you wear now against what you would buy.
    local cols = { { 0, 130, "LEFT" }, { 132, 60, "RIGHT" }, { 196, 60, "RIGHT" }, { 260, DETAIL_W - 20 - 260, "RIGHT" } }
    local function Cell(c, y, text, color)
        local fs = S.Text(d, 11, color or S.C.text)
        fs:SetPoint("TOPLEFT", d, "TOPLEFT", c[1], -y)
        fs:SetWidth(c[2])
        fs:SetJustifyH(c[3])
        fs:SetWordWrap(false)
        fs:SetText(text or "")
        return fs
    end
    d.tableHead = {}
    for k, c in ipairs(cols) do d.tableHead[k] = Cell(c, TABLE_Y, ({ "Stat", "Current", "Buy", "Change" })[k], GOLD) end
    d.table = {}
    for r = 1, TABLE_ROWS do
        local row = {}
        for k, c in ipairs(cols) do row[k] = Cell(c, TABLE_Y + 6 + r * TABLE_ROW) end
        d.table[r] = row
    end
    -- Vertical chart: gains rise above a centre line, losses hang below it, one column per stat.
    d.axis = d:CreateTexture(nil, "ARTWORK")
    d.axis:SetSize(DETAIL_W - 20, 1)
    d.axis:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -CHART_MID)
    d.axis:SetColorTexture(1, 1, 1, 0.25)
    d.stats = {}
    for i = 1, DETAIL_STATS do
        local s, cx = {}, (i - 0.5) * COL_W
        s.back = d:CreateTexture(nil, "BACKGROUND")
        s.back:SetSize(COL_W - 4, CHART_H)
        s.back:SetPoint("TOPLEFT", d, "TOPLEFT", (i - 1) * COL_W + 2, -CHART_TOP)
        s.back:SetColorTexture(1, 1, 1, 0.04)
        s.bar = d:CreateTexture(nil, "ARTWORK")
        s.bar:SetWidth(BAR_COL)
        s.up = { "BOTTOM", d, "TOPLEFT", cx, -CHART_MID }
        s.down = { "TOP", d, "TOPLEFT", cx, -CHART_MID }
        s.val = S.Text(d, 10, S.C.text, "OUTLINE")
        s.label = S.Text(d, 10, S.C.muted)
        s.label:SetPoint("TOP", d, "TOPLEFT", cx, -(CHART_TOP + CHART_H + 3))
        s.label:SetWidth(COL_W)
        s.label:SetJustifyH("CENTER")
        s.label:SetWordWrap(true)
        d.stats[i] = s
    end
    d.hint = S.Text(d, 11, S.C.muted)
    d.hint:SetPoint("TOPLEFT", 0, 0)
    d.hint:SetWidth(DETAIL_W - 24)
    d.hint:SetText("Hover an item to see exactly what changes.")
    return d
end

local function AgeText(age)
    if not age or age <= 0 then return "seen today" end
    return age == 1 and "seen 1 day ago" or ("seen %d days ago"):format(age)
end

function M:ShowDetail(e)
    local p, d = self.upgradePanel, self.upgradePanel and self.upgradePanel.detail
    if not d then return end
    self.detailEntry = e
    if not e then
        d.hint:Show(); d.icon:Hide(); d.glow:Hide(); d.name:SetText(""); d.slot:SetText(""); d.head:SetText("")
        for _, l in ipairs(d.line) do l:SetText("") end
        for _, s in ipairs(d.stats) do s.label:SetText(""); s.val:SetText(""); s.back:Hide(); s.bar:Hide() end
        d.axis:Hide()
        for _, h in ipairs(d.tableHead) do h:SetText("") end
        for _, row in ipairs(d.table) do for _, c in ipairs(row) do c:SetText("") end end
        return
    end
    local i = M.DetailInfo(e)
    d.hint:Hide()
    d.icon:Show()
    d.glow:SetVertexColor(QualityColor(e.quality))
    d.glow:Show()
    d.icon:SetTexture(i.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or 134400)
    d.name:SetText(i.link or i.name or ("item:" .. e.id))
    d.slot:SetText(i.slot)
    d.line[1]:SetText(("Item level |cffffffff%d|r  |cff66F27F+%d|r  (you wear %s)"):format(i.level or 0, i.gain or 0,
        i.worn and i.worn > 0 and tostring(i.worn) or "nothing"))
    d.line[2]:SetText("Replaces: " .. (i.wornLink or "empty slot") .. (i.note and ("  |cffE8A060" .. i.note .. "|r") or ""))
    d.line[3]:SetText("Price: " .. MoneyText(i.price) .. "  |cff8A93A0(" .. AgeText(i.age) .. ")|r")
    d.line[4]:SetText(e.useful and ("Worth: |cff7CFF8A+%.1f|r for your class  |cff8A93A0(%.1f item levels per gold)|r"):format(e.useful, i.perGold or 0)
        or i.perGold and ("Value: %.1f item levels per gold"):format(i.perGold) or "")
    for k, h in ipairs(d.tableHead) do h:SetText(({ "Stat", "Current", "Buy", "Change" })[k]) end
    for r, row in ipairs(d.table) do
        local g = i.all[r]
        if g then
            local c = M.BarColor(g.label, g.key)
            row[1]:SetText(g.label); row[1]:SetTextColor(c[1], c[2], c[3])
            row[2]:SetText(AmountText(g.old))
            row[3]:SetText(AmountText(g.new))
            row[3]:SetTextColor(g.amount > 0 and 0.48 or g.amount < 0 and 1 or S.C.text[1], g.amount > 0 and 1 or g.amount < 0 and 0.42 or S.C.text[2], g.amount > 0 and 0.54 or g.amount < 0 and 0.42 or S.C.text[3])
            row[4]:SetText(g.amount > 0 and ("|cff7CFF8A+" .. AmountText(g.amount) .. "|r")
                or g.amount < 0 and ("|cffFF6B6B-" .. AmountText(-g.amount) .. "|r") or "|cff888888=|r")
        else
            for _, cell in ipairs(row) do cell:SetText("") end
        end
    end
    d.head:SetText(#i.stats > 0 and "Stat changes: up = gain, down = loss" or "No stat changes known yet")
    d.axis:Show()
    for k, s in ipairs(d.stats) do
        local g = i.stats[k]
        if g then
            -- Heights are the change as a share of the larger of old and new, so a +1 and a +30
            -- of different stats can be compared by eye; the printed figure is the real amount.
            local lost = g.amount < 0
            local h = M.BarWidth(math.abs(g.amount), math.max(g.old, g.new), HALF)
            local c = lost and { 0.9, 0.28, 0.28 } or M.BarColor(g.label, g.key)
            s.back:Show()
            s.bar:ClearAllPoints()
            s.bar:SetPoint(unpack(lost and s.down or s.up))
            s.bar:SetHeight(h)
            s.bar:SetColorTexture(1, 1, 1, 1)
            -- Brighter at the tip, deeper at the centre line.
            local lo, hi = 0.55, 1
            if lost then
                S.SetGradient(s.bar, "VERTICAL", c[1] * hi, c[2] * hi, c[3] * hi, 0.95, c[1] * lo, c[2] * lo, c[3] * lo, 0.95)
            else
                S.SetGradient(s.bar, "VERTICAL", c[1] * lo, c[2] * lo, c[3] * lo, 0.95, c[1] * hi, c[2] * hi, c[3] * hi, 0.95)
            end
            s.bar:Show()
            s.val:ClearAllPoints()
            s.val:SetPoint(lost and "TOP" or "BOTTOM", s.bar, lost and "BOTTOM" or "TOP", 0, lost and -2 or 2)
            s.val:SetText((lost and "|cffFF6B6B-" or "|cff7CFF8A+") .. AmountText(math.abs(g.amount)) .. "|r")
            s.label:SetText(g.label)
        else
            s.label:SetText(""); s.val:SetText(""); s.back:Hide(); s.bar:Hide()
        end
    end
end

function M:BuildUpgradePanel()
    if self.upgradePanel then return self.upgradePanel end
    -- A free-standing window (not a child of the auction house) so it works anywhere: prices are saved.
    local p = CreateFrame("Frame", "TempusUpgradePanel", UIParent)
    p:SetSize(WIDTH + DETAIL_W, 60 + VISIBLE * ROW_H)
    p:SetFrameStrata("HIGH")
    p:SetClampedToScreen(true)
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", function(f) f:StartMoving() end)
    p:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, rel, x, y = f:GetPoint()
        if point and T.db.market then T.db.market.upgradePos = { point, rel, x, y } end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "TempusUpgradePanel") end
    if S and S.Backdrop then S.Backdrop(p, {}) end
    p.band = S.Tex(p, "BACKGROUND", nil, 3)
    p.band:SetPoint("TOPLEFT", 1, -1)
    p.band:SetPoint("TOPRIGHT", -1, -1)
    p.band:SetHeight(32)
    p.rule = Paint(S.Tex(p, "ARTWORK"), GOLD, 0.85)
    p.rule:SetPoint("TOPLEFT", p.band, "BOTTOMLEFT", 0, 0)
    p.rule:SetPoint("TOPRIGHT", p.band, "BOTTOMRIGHT", 0, 0)
    p.rule:SetHeight(1)
    p.title = S.Text(p, 15, S.C.text, "OUTLINE")
    p.title:SetPoint("TOPLEFT", 12, -9)
    p.title:SetText("Gear Advisor")
    p.priceLabel = S.Text(p, 11, S.C.muted)
    p.priceLabel:SetPoint("LEFT", p.title, "RIGHT", 18, 0)
    p.priceLabel:SetText("Max price (gold)")
    p.price = T.UI.StyledEditBox(p, 70, 20)
    p.price:SetPoint("LEFT", p.priceLabel, "RIGHT", 8, 0)
    p.price:SetFont(S.FONT, 11, "")
    p.price:SetJustifyH("RIGHT")
    p.price:SetMaxLetters(7)
    p.price:SetScript("OnTextChanged", function(box, user)
        -- The "no limit" hint shows only while the box is empty.
        if p.priceHint then p.priceHint:SetShown((box:GetText() or "") == "") end
        if not user then return end
        local v = tonumber((box:GetText():gsub("[,%s]", ""))) or 0
        if v < 0 or v ~= v then v = 0 end
        T.db.market.upgradeMaxGold = v
        M:ScheduleUpgradeRefresh()
    end)
    p.price:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    p.priceHint = S.Text(p.price, 10, S.C.muted)
    p.priceHint:SetPoint("RIGHT", -6, 0)
    p.priceHint:SetText("no limit")
    p.close = CreateFrame("Button", nil, p)
    p.close:SetSize(20, 20)
    p.close:SetPoint("TOPRIGHT", -6, -6)
    p.close.x = S.Text(p.close, 14, S.C.muted)
    p.close.x:SetPoint("CENTER")
    p.close.x:SetText("x")
    p.close:SetScript("OnClick", function() p:Hide() end)
    p.status = S.Text(p, 11, S.C.muted)
    p.status:SetPoint("TOPRIGHT", p.close, "TOPLEFT", -6, -4)
    p.foot = S.Text(p, 11, S.C.muted)
    p.foot:SetPoint("BOTTOMLEFT", 12, 10)
    local scroll = CreateFrame("ScrollFrame", nil, p)
    scroll:SetPoint("TOPLEFT", 10, -34)
    scroll:SetSize(WIDTH - 20, VISIBLE * ROW_H)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 20, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local max = math.max(0, content:GetHeight() - sf:GetHeight())
        sf:SetVerticalScroll(math.max(0, math.min(max, sf:GetVerticalScroll() - delta * ROW_H * 3)))
    end)
    p.scroll, p.content = scroll, content
    p.detail = M.BuildDetail(p, scroll)
    p.rows = {}
    for i = 1, LIMIT do
        local r = CreateFrame("Button", nil, content)
        r:SetSize(WIDTH - 20, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r.stripe = S.Tex(r, "BACKGROUND", { 1, 1, 1, 0.03 })
        r.stripe:SetAllPoints()
        r.stripe:SetShown(i % 2 == 0)
        r.hl = S.Tex(r, "BACKGROUND", nil, 1)
        r.hl:SetAllPoints()
        r.hl:Hide()
        r.hbg = S.Tex(r, "BACKGROUND", nil, 1)
        r.hbg:SetAllPoints()
        r.hbg:Hide()
        r.hline = Paint(S.Tex(r, "ARTWORK"), GOLD, 0.5)
        r.hline:SetPoint("BOTTOMLEFT", 0, 0)
        r.hline:SetPoint("BOTTOMRIGHT", 0, 0)
        r.hline:SetHeight(1)
        r.hline:Hide()
        r.sel = Paint(S.Tex(r, "ARTWORK"), GOLD, 1)
        r.sel:SetPoint("TOPLEFT", 0, 0)
        r.sel:SetPoint("BOTTOMLEFT", 0, 0)
        r.sel:SetWidth(2)
        r.sel:Hide()
        r.glow = r:CreateTexture(nil, "BORDER")
        r.glow:SetColorTexture(1, 1, 1, 1)
        r.glow:SetSize(22, 22)
        r.glow:SetPoint("LEFT", 2, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 4, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = S.Text(r, 12, S.C.text)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetWidth(230)
        r.name:SetJustifyH("LEFT")
        r.pill = S.Tex(r, "BACKGROUND", nil, 2)
        r.pill:SetSize(58, 16)
        r.gain = S.Text(r, 11, { 0.4, 0.95, 0.5 }, "OUTLINE")
        r.gain:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
        r.gain:SetWidth(56)
        r.gain:SetJustifyH("CENTER")
        r.pill:SetPoint("CENTER", r.gain, "CENTER", 0, 0)
        r.meter = Paint(S.Tex(r, "ARTWORK"), GOLD, 0.8)
        r.meter:SetPoint("BOTTOMLEFT", 30, 1)
        r.meter:SetHeight(2)
        r.meter:Hide()
        r.price = S.Text(r, 12, { 1, 0.82, 0.25 })
        r.price:SetPoint("RIGHT", -4, 0)
        r.price:SetJustifyH("RIGHT")
        r.price:SetWidth(96)
        r:SetScript("OnEnter", function(b)
            if b.header or not b.entry then return end
            b.hl:Show()
            M:ShowDetail(b.entry)
            for _, other in ipairs(p.rows) do other.sel:SetShown(other == b) end
        end)
        r:SetScript("OnLeave", function(b) b.hl:Hide() end)
        r:SetScript("OnClick", function(b)
            if b.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                ChatEdit_InsertLink(b.link)
            end
        end)
        r:Hide()
        p.rows[i] = r
    end
    -- Gradients: a warm gold band, gold hover sweep, deep slot-header bands.
    do
        local a = GOLD
        p.band:Hide()      -- no tint behind the title
        for _, r in ipairs(p.rows) do
            S.SetGradient(r.hl, "HORIZONTAL", a[1], a[2], a[3], 0.26, a[1], a[2], a[3], 0)
            r.hbg:SetColorTexture(0.18, 0.2, 0.4, 0.45)
            r.meter:SetColorTexture(1, 1, 1, 1)
        end
    end
    -- Item data arrives asynchronously; refresh the open panel as it lands.
    p:SetScript("OnShow", function(f)
        f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        f.filterSig = M.FilterSignature()
        f.fade = 0
        f:SetAlpha(0)
        f.scroll:SetVerticalScroll(0)
        M:RefreshUpgrades()
    end)
    p:SetScript("OnHide", function(f) f:UnregisterEvent("ITEM_DATA_LOAD_RESULT") end)
    -- The AH keeps its filters in a plain table with no event when they change (the level range is
    -- stored when you press Search), so while the list is open, look for a change twice a second.
    local waited = 0
    p:SetScript("OnUpdate", function(f, elapsed)
        if f.fade then            -- a short fade-in when the window opens
            f.fade = math.min(1, f.fade + (elapsed or 0) / 0.18)
            f:SetAlpha(f.fade)
            if f.fade >= 1 then f.fade = nil end
        end
        waited = waited + (elapsed or 0)
        if waited < 0.5 then return end
        waited = 0
        local sig = M.FilterSignature()
        if sig ~= f.filterSig then
            f.filterSig = sig
            M:RefreshUpgrades()
        end
    end)
    p:SetScript("OnEvent", function() M:ScheduleUpgradeRefresh() end)
    p:Hide()
    self.upgradePanel = p
    return p
end

function M:ScheduleUpgradeRefresh()
    if self.upgradeTimer then return end
    self.upgradeTimer = true
    C_Timer.After(0.4, function()
        M.upgradeTimer = nil
        if M.upgradePanel and M.upgradePanel:IsShown() then M:RefreshUpgrades() end
    end)
end

function M:RefreshUpgrades()
    local p = self.upgradePanel
    if not (p and p:IsShown()) then return end
    local store = self.Store()
    local maxGold = Num(T.db.market.upgradeMaxGold) and T.db.market.upgradeMaxGold or 0
    if p.price and not (p.price.HasFocus and p.price:HasFocus()) then
        p.price:SetText(maxGold > 0 and (maxGold == math.floor(maxGold) and ("%d"):format(maxGold) or tostring(maxGold)) or "")
    end
    if p.priceHint and p.price then p.priceHint:SetShown((p.price:GetText() or "") == "") end
    local list, pending, hidden, filters = {}, 0, 0, nil
    if Num(store.scanned) then
        local ok, l, n, _, h, f = pcall(self.FindUpgrades, self)
        if ok then list, pending, hidden, filters = l, n, h or 0, f end
    end
    local layout = M.Layout(list)
    local maxRank = {}
    for _, e in ipairs(layout) do
        if not e.header and Num(e.rank) then
            local g = GROUP_OF[e.loc]
            maxRank[g] = math.max(maxRank[g] or 0, e.rank)
        end
    end
    for i, r in ipairs(p.rows) do
        local e = layout[i]
        if e and e.header then
            r.itemID, r.link, r.entry = nil, nil, nil
            r.icon:Hide(); r.gain:SetText(""); r.price:SetText("")
            r.glow:Hide(); r.pill:Hide(); r.meter:Hide(); r.sel:Hide(); r.hl:Hide(); r.stripe:Hide()
            r.hbg:Show(); r.hline:Show()
            r.name:SetText(e.header)
            r.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            r.header = true
            r:Show()
        elseif e then
            r.header = nil
            r.hbg:Hide(); r.hline:Hide()
            r.stripe:SetShown(i % 2 == 0)
            r.icon:Show()
            r.glow:SetVertexColor(QualityColor(e.quality))
            r.glow:Show()
            r.pill:Show()
            r.pill:SetColorTexture(1, 1, 1, 1)
            do
                local gr, gg, gb = GainColor(e.gain)
                r.pill:SetVertexColor(gr, gg, gb, 0.32)
                r.gain:SetTextColor(math.min(1, gr + 0.25), math.min(1, gg + 0.1), math.min(1, gb + 0.25))
            end
            local top = maxRank[GROUP_OF[e.loc]]
            if top and top > 0 and Num(e.rank) then
                local t = e.rank / top
                r.meter:SetWidth(math.max(2, (WIDTH - 20 - 36) * t))
                -- Heat map: the bar runs from red up to the colour its deal quality reaches.
                local r1, g1, b1 = HeatColor(0)
                local r2, g2, b2 = HeatColor(t)
                S.SetGradient(r.meter, "HORIZONTAL", r1, g1, b1, 0.95, r2, g2, b2, 0.95)
                r.meter:Show()
            else
                r.meter:Hide()
            end
            r.sel:SetShown(M.detailEntry ~= nil and M.detailEntry.id == e.id)
            r.name:SetTextColor(S.C.text[1], S.C.text[2], S.C.text[3])
            r.itemID, r.entry = e.id, e
            local name, link, _, _, _, _, _, _, _, icon = (C_Item and C_Item.GetItemInfo or GetItemInfo)(e.id)
            r.link = link
            r.icon:SetTexture(icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or 134400)
            r.name:SetText(link or name or ("item:" .. e.id))
            r.gain:SetText("+" .. e.gain .. " ilvl")
            local stale = e.age and e.age >= (T.db.market.staleDays or 3)
            r.price:SetText(MoneyText(e.price) .. (stale and " |cff8A93A0(old)|r" or ""))
            r:Show()
        else
            r.itemID, r.link, r.header, r.entry = nil, nil, nil, nil
            r:Hide()
        end
    end
    local sel
    if self.detailEntry then
        for _, e in ipairs(layout) do if e.id == self.detailEntry.id then sel = e break end end
    end
    self:ShowDetail(sel)
    p.content:SetHeight(math.max(1, #layout * ROW_H))
    local max = math.max(0, #layout * ROW_H - VISIBLE * ROW_H)
    if p.scroll:GetVerticalScroll() > max then p.scroll:SetVerticalScroll(max) end
    if not Num(store.scanned) then
        p.status:SetText("Scan the auction house first")
    elseif pending > 0 then
        p.status:SetText(("Loading item data (%d)..."):format(pending))
    elseif #list == 0 then
        p.status:SetText(hidden > 0 and "No gear matches the AH filters"
            or maxGold > 0 and ("No gear under %s gold"):format(maxGold == math.floor(maxGold) and ("%d"):format(maxGold) or tostring(maxGold))
            or "No gear upgrades found")
    else
        p.status:SetText("")
    end
    local scanned = Num(store.scanned) and (time() - store.scanned) or nil
    p.foot:SetText(scanned and (("Scanned %s ago. Ranked by item levels gained per gold.")
        :format(scanned >= 86400 and (math.floor(scanned / 86400) .. " d") or scanned >= 3600
        and (math.floor(scanned / 3600) .. " h") or (math.floor(scanned / 60) .. " min"))
        .. (filters and ("  Using AH filters: " .. M.FilterSummary(filters)) or "")) or "")
end

function M:HideUpgrades()
    if self.upgradePanel then self.upgradePanel:Hide() end
end

-- Where the window opens: where you left it, else beside the auction house if it is open, else centred.
function M:PlaceUpgradePanel(p)
    p:ClearAllPoints()
    local pos = T.db.market and T.db.market.upgradePos
    if type(pos) == "table" and pos[1] then
        p:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    elseif AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown() then
        p:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 6, 0)
    else
        p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function M:ToggleUpgrades()
    local p = self:BuildUpgradePanel()
    if p:IsShown() then p:Hide() return end
    self:PlaceUpgradePanel(p)
    p:Show()
end

function M:EnsureUpgradeButton(scanButton)
    if self.upgradeButton or not scanButton then return end
    local ok, b = pcall(CreateFrame, "Button", "TempusUpgradesButton", AuctionHouseFrame, "UIPanelButtonTemplate")
    if not (ok and b) then return end
    b:SetSize(110, 22)
    b:SetPoint("LEFT", scanButton, "RIGHT", 4, 0)
    if b.SetFrameLevel and scanButton.GetFrameLevel then b:SetFrameLevel(scanButton:GetFrameLevel()) end
    b:SetText("Gear Advisor")
    b:SetScript("OnClick", function() M:ToggleUpgrades() end)
    local SK = T.Skins
    if SK and SK.On and SK.Button and SK:On("windows") then pcall(SK.Button, SK, b) end
    self.upgradeButton = b
end
