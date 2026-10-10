-- Saved character inventories: capture, rebuild as a read-only snapshot, and tooltip counts.
-- Run: lua5.1 tests/bags-characters.lua
local T = { Bags = {} }
TempusDB = {}
assert(loadfile("Modules/Bags/Inventory.lua"))("Tempus", T)
assert(loadfile("Modules/Bags/Characters.lua"))("Tempus", T)
local I, Ch = T.Bags.Inventory, T.Bags.Characters
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 } }
C_Item = { GetItemInfoInstant = function(id)
    if id == 100 then return id, "Consumable", "Potion", "", 134400, 0, 1 end
    return id, "Weapon", "Sword", "INVTYPE_WEAPON", 135274, 2, 7
end }

local function Live(storage, rows, capacity)
    local locations = {}
    for i = 1, capacity do locations[i] = { storage = storage, container = 0, slot = i } end
    return I.Snapshot(storage, locations, function(location) return rows[location.slot] end)
end

local bags = Live("CARRIED", {
    { itemID = 100, name = "Major Healing Potion", count = 3, quality = 1, link = "|cff|Hitem:100|h[Major Healing Potion]|h|r" },
    nil,
    { itemID = 200, name = "Iron Sword", count = 1, quality = 2, itemLevel = 12 },
}, 4)
Ch.Capture("Mia - Realm", { name = "Mia", realm = "Realm", class = "PRIEST", money = 5000, time = 1000 }, "CARRIED", bags)
local bank = Live("BANK", { { itemID = 100, count = 20, quality = 1 } }, 6)
Ch.Capture("Mia - Realm", { name = "Mia", realm = "Realm", class = "PRIEST", money = 5000, time = 1000 }, "BANK", bank)
Ch.Capture("Zed - Realm", { name = "Zed", realm = "Realm", class = "WARRIOR", money = 1, time = 2000 }, "CARRIED",
    Live("CARRIED", { { itemID = 100, count = 2, quality = 1 } }, 4))

-- Rebuild: only real items, true capacity, readonly, static info filled in.
local snap = Ch.Snapshot("Mia - Realm", "CARRIED")
assert(snap.used == 2 and snap.capacity == 4, "saved capacity survives")
local potion = snap.byKey["CARRIED:0:1"]
assert(potion.readonly and potion.count == 3 and potion.classID == 0 and potion.icon == 134400, "static info is filled")
assert(snap.byKey["CARRIED:0:3"].itemLevel == 12)
assert(Ch.Snapshot("Nobody - Realm", "CARRIED") == nil, "unknown character has no snapshot")
local projection = I.Project(snap, "GRID", "potion", false, { sort = true })
assert(projection.visibleCount == 1, "search works on saved items")

-- List: newest first, with the storages that hold something.
local list = Ch.List()
assert(#list == 2 and list[1].key == "Zed - Realm", "most recently seen first")
assert(#list[2].storages == 2 and list[2].storages[2] == "BANK")

-- Counts: other characters, own bank; nothing to say when it is all in your own bags.
local lines = Ch.CountLines(100, "Zed - Realm", 8)
assert(#lines == 2 and lines[1].left:find("Zed") and lines[1].right == "Bags 2", "own character first")
assert(lines[2].right == "Bags 3  Bank 20", lines[2].right)
assert(#Ch.CountLines(200, "Mia - Realm", 8) == 0, "only in your own bags")
assert(#Ch.CountLines(100, "Zed - Realm", 1) == 1, "limit")

-- Forget.
Ch.ForgetAllExcept("Zed - Realm")
assert(#Ch.List() == 1 and #Ch.CountLines(100, "Zed - Realm", 8) == 0, "forgotten characters leave the counts")
assert(Ch.Age(30) == "just now" and Ch.Age(7200) == "2 hr ago")
print("PASS: saved character inventories")
