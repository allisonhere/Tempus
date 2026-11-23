-- Gear Advisor roles and scoring.
local T = {}
assert(loadfile("Modules/GearAdvisor/Weights.lua"))("Tempus", T)
assert(loadfile("Modules/GearAdvisor/Scoring.lua"))("Tempus", T)
local S = T.GearAdvisor.Scoring
local isNum = function(v) return type(v) == "number" end

-- Role: a chosen role wins; automatic follows the form, then the last role, then Cat.
assert(select(1, S.Role("DRUID", "BEAR", 3, nil)) == "BEAR")
assert(select(1, S.Role("DRUID", "AUTO", 3, nil)) == "CAT" and select(2, S.Role("DRUID", "AUTO", 3, nil)) == "form")
assert(select(1, S.Role("DRUID", "AUTO", 1, "CAT")) == "BEAR", "bear form scores as bear")
assert(select(1, S.Role("DRUID", "AUTO", 0, "BEAR")) == "BEAR" and select(2, S.Role("DRUID", "AUTO", 0, "BEAR")) == "last form")
assert(select(1, S.Role("DRUID", "AUTO", 0, nil)) == "CAT" and select(2, S.Role("DRUID", nil, nil, nil)) == "default")
assert(S.Role("NOPE", "AUTO", 0, nil) == nil, "a class with no weights has no role")
assert(select(1, S.Role("MAGE", "AUTO", 0, nil)) == "ARCANE" and select(2, S.Role("MAGE", "AUTO", 0, nil)) == "default", "other classes: a labelled guess")
assert(select(1, S.Role("WARRIOR", "PROTECTION", 0, nil)) == "PROTECTION" and select(2, S.Role("WARRIOR", "PROTECTION", 0, nil)) == "chosen")
assert(select(1, S.Role("WARRIOR", "BOGUS", 0, nil)) == "ARMS", "a stale saved role is ignored")

-- Weights: leveling below 60, endgame at 60, by role.
local lvl = S.Weights("DRUID", "CAT", 22)
local top = S.Weights("DRUID", "CAT", 60)
assert(lvl.ITEM_MOD_STAMINA_SHORT > top.ITEM_MOD_STAMINA_SHORT, "leveling values stamina more")
assert(S.Weights("DRUID", "NOPE", 22) == nil)
-- Rating weights are per rating point: Pawn's per-1% weight over the rating per 1%.
assert(math.abs(lvl.ITEM_MOD_CRIT_RATING_SHORT - 11.9 / 14) < 0.001, lvl.ITEM_MOD_CRIT_RATING_SHORT)

-- The same item is worth different amounts to a cat and a bear.
local agi = { ITEM_MOD_AGILITY_SHORT = 12 }
local sta = { ITEM_MOD_STAMINA_SHORT = 20 }
local cat, bear = S.Weights("DRUID", "CAT", 22), S.Weights("DRUID", "BEAR", 22)
local catAgi = S.Delta(agi, nil, cat, isNum)
local catSta = S.Delta(sta, nil, cat, isNum)
local bearSta = S.Delta(sta, nil, bear, isNum)
assert(catAgi > catSta, "a cat wants agility over stamina")
assert(bearSta > catSta * 3, "a bear wants stamina far more than a cat")

-- Delta: gains and losses, biggest first, unscored stats named.
local total, parts, unscored = S.Delta({ ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 5, ITEM_MOD_WEIRD = 3 },
    { ITEM_MOD_AGILITY_SHORT = 4, ITEM_MOD_STAMINA_SHORT = 9 }, cat, isNum)
assert(#parts == 2 and parts[1].key == "ITEM_MOD_AGILITY_SHORT" and parts[1].change == 6, "agility gain leads")
assert(parts[2].change == -4 and parts[2].value < 0, "the stamina loss counts against")
assert(unscored[1] == "ITEM_MOD_WEIRD", "a stat with no weight is reported, not guessed")
assert(math.abs(total - (parts[1].value + parts[2].value)) < 1e-9)
assert(S.Delta(nil, nil, cat, isNum) == 0, "no stats, no change")
print("PASS: gear advisor roles and scoring (form to role, leveling versus endgame, cat versus bear, unscored stats)")

-- The dropdown list: Automatic first, then the class's roles in order.
local list = S.RoleList("DRUID")
assert(list[1][1] == "AUTO" and list[2][1] == "BALANCE" and list[3][2] == "Cat", "druid list")
assert(S.RoleList("WARRIOR")[2][2] == "Arms" and S.RoleList("WARRIOR")[1][2] == "Automatic (assumed)")
assert(S.RoleList("NOPE") == nil)

-- Every class and role has weights for the stats its job lives on.
for class, set in pairs(T.GearAdvisor.Weights) do
    if type(set) == "table" then
        for _, code in ipairs(set._order) do
            local w = set[code].max
            assert(next(w), class .. " " .. code .. " has no weights")
        end
    end
end
assert(T.GearAdvisor.Weights.WARRIOR.PROTECTION.max.ITEM_MOD_STAMINA_SHORT > T.GearAdvisor.Weights.WARRIOR.ARMS.max.ITEM_MOD_STAMINA_SHORT, "a protection warrior values stamina more")
assert(T.GearAdvisor.Weights.MAGE.FIRE.max.ITEM_MOD_SPELL_POWER_SHORT and T.GearAdvisor.Weights.PRIEST.HOLY.max.ITEM_MOD_SPELL_POWER_SHORT, "casters weigh spell power")

-- A ranged weapon's DPS counts at the ranged weight.
local hunter = T.GearAdvisor.Weights.HUNTER.MARKSMANSHIP.max
assert(hunter.DPS_RANGED and S.ForItem(hunter, true).ITEM_MOD_DAMAGE_PER_SECOND_SHORT == hunter.DPS_RANGED)
assert(S.ForItem(hunter, false) == hunter, "melee gear keeps the melee weight")
print("PASS: gear advisor role lists, all-class weights, ranged DPS")
