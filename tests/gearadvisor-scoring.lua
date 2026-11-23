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
assert(S.Role("MAGE", "AUTO", 0, nil) == nil, "classes with no roles are left to the class table")

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
