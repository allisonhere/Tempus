-- Gear Advisor equip rules: dual wield, two-handers, off hands, unique-equipped.
local T = {}
assert(loadfile("Modules/GearAdvisor/EquipRules.lua"))("Tempus", T)
local R = T.GearAdvisor.EquipRules

-- Dual wield: the game's yes wins; a no is trusted only for classes that do not always learn it.
assert(R.CanDualWield("DRUID", 60, false) == false, "druids never dual wield")
assert(R.CanDualWield("DRUID", 60, nil) == false, "unknown druid counts as no")
assert(R.CanDualWield("ROGUE", 22, false) == true, "a rogue's no is not trusted past the learn level")
assert(R.CanDualWield("ROGUE", 5, false) == false, "a rogue below the learn level cannot")
assert(R.CanDualWield("WARRIOR", 19, nil) == false and R.CanDualWield("WARRIOR", 20, nil) == true, "warrior learns it at 20")
assert(R.CanDualWield("SHAMAN", 40, true) == true, "a shaman who learned it can")
assert(R.CanDualWield("SHAMAN", 40, nil) == false, "a shaman with no answer counts as no")

-- A one-hander only competes for the off hand when the character can dual wield.
assert(#R.Slots("INVTYPE_WEAPON", false) == 1 and R.Slots("INVTYPE_WEAPON", false)[1] == 16, "no dual wield: main hand only")
assert(#R.Slots("INVTYPE_WEAPON", true) == 2, "dual wield: both hands")
assert(R.Slots("INVTYPE_FINGER", false)[2] == 12 and R.Slots("INVTYPE_TRINKET", false)[2] == 14, "rings and trinkets take either slot")
assert(R.Slots("INVTYPE_NOPE", true) == nil, "unknown type")

-- The level you give up is the lowest slot; an empty slot is 0; an unreadable one gives nothing.
local worn = { [11] = 30, [12] = 18, [16] = 25 }
assert(R.Baseline("INVTYPE_FINGER", false, function(s) return worn[s] or 0 end) == 18, "ring replaces the weaker ring")
assert(R.Baseline("INVTYPE_WEAPON", false, function(s) return worn[s] or 0 end) == 25, "druid compares the main hand only")
assert(R.Baseline("INVTYPE_WEAPON", true, function(s) return worn[s] or 0 end) == 0, "dual wielder with an empty off hand: anything is an upgrade")
assert(R.Baseline("INVTYPE_FINGER", false, function(s) if s == 11 then return nil end return 5 end) == nil, "unreadable slot: no baseline")

-- What else comes off.
assert(R.Displaced("INVTYPE_2HWEAPON", { [17] = "INVTYPE_SHIELD" }) == "Also takes off your shield")
assert(R.Displaced("INVTYPE_2HWEAPON", { [17] = "INVTYPE_HOLDABLE" }) == "Also takes off your off hand")
assert(R.Displaced("INVTYPE_2HWEAPON", { [16] = "INVTYPE_WEAPON" }) == nil, "empty off hand: nothing extra")
assert(R.Displaced("INVTYPE_SHIELD", { [16] = "INVTYPE_2HWEAPON" }) == "Takes off your two-hander")
assert(R.Displaced("INVTYPE_WEAPON", { [16] = "INVTYPE_2HWEAPON" }) == "Takes off your two-hander")
assert(R.Displaced("INVTYPE_CHEST", { [16] = "INVTYPE_2HWEAPON" }) == nil, "other slots are unaffected")

-- Unique-equipped.
assert(R.UniqueConflict(100, true, { 100, 7 }) == true, "unique and already worn")
assert(R.UniqueConflict(100, false, { 100 }) == false, "not unique: a second is fine")
assert(R.UniqueConflict(100, true, { 7, 8 }) == false, "unique but not worn")
print("PASS: gear advisor equip rules (dual wield, slot baselines, displaced gear, unique-equipped)")
