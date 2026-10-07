local T = { Bags = {} }
assert(loadfile("Modules/Bags/Inventory.lua"))("Tempus", T)
local I = T.Bags.Inventory

local locations = {
    { storage = "CARRIED", container = 0, slot = 1 },
    { storage = "CARRIED", container = 0, slot = 2 },
    { storage = "CARRIED", container = 1, slot = 1 },
    { storage = "CARRIED", container = 1, slot = 2 },
    { storage = "CARRIED", container = 2, slot = 1 },
}
local reads = 0
local data = {
    ["CARRIED:0:1"] = { itemID = 100, name = "Major Healing Potion", itemType = "Consumable",
        itemSubType = "Potion", classID = 0, count = 3, quality = 1 },
    ["CARRIED:0:2"] = { itemID = 200, name = "Iron Sword", itemType = "Weapon",
        itemSubType = "Sword", equipLoc = "INVTYPE_WEAPON", classID = 2, quality = 2 },
    ["CARRIED:1:1"] = { itemID = 300, name = "A Mysterious Clue", itemType = "Quest",
        classID = 12, quest = true, quality = 1 },
    ["CARRIED:1:2"] = { itemID = 400, name = "Bent Gear", itemType = "Miscellaneous",
        classID = 15, quality = 0, hasNoValue = false },
}
local snapshot = I.Snapshot("CARRIED", locations, function(location)
    reads = reads + 1
    return data[I.Key(location)]
end)

assert(reads == 5 and snapshot.capacity == 5 and snapshot.used == 4, "snapshot reads every real slot once")
assert(snapshot.slots[5].empty and snapshot.byKey["CARRIED:2:1"].empty, "empty slots retain a location")
assert(snapshot.byItemID[100]["CARRIED:0:1"], "item index points to slot keys")

local grid = I.Project(snapshot, "GRID", "", true)
assert(#grid.sections == 1 and #grid.sections[1].keys == 5, "grid contains every physical slot")

local categories = I.Project(snapshot, "CATEGORIES", "", true)
local names, seen = {}, {}
for _, section in ipairs(categories.sections) do
    names[#names + 1] = section.key
    for _, key in ipairs(section.keys) do
        assert(not seen[key], "a slot appears in only one category")
        seen[key] = true
    end
end
assert(table.concat(names, ",") == "QUEST,EQUIPMENT,CONSUMABLE,JUNK,EMPTY", "fixed category priority")
assert(seen["CARRIED:0:1"] and seen["CARRIED:2:1"], "occupied and empty slots are projected")

local beforeSearch = reads
local search = I.Project(snapshot, "GRID", "potion consumable", true)
assert(reads == beforeSearch, "search never rereads containers")
assert(#search.sections[1].keys == 1 and search.sections[1].keys[1] == "CARRIED:0:1", "AND search matches metadata")
assert(I.Project(snapshot, "GRID", "200", true).sections[1].keys[1] == "CARRIED:0:2", "item ID search")
assert(I.Project(snapshot, "GRID", "missing", true).emptyResult, "empty search result")

-- Sorting, filters, bag limits, custom categories and collapsing.
do
    local more = {
        { storage = "CARRIED", container = 0, slot = 1 }, { storage = "CARRIED", container = 0, slot = 2 },
        { storage = "CARRIED", container = 0, slot = 3 }, { storage = "CARRIED", container = 1, slot = 1 },
        { storage = "CARRIED", container = 1, slot = 2 }, { storage = "CARRIED", container = 1, slot = 3 },
    }
    local items = {
        ["CARRIED:0:1"] = { itemID = 1, name = "Zed Blade", classID = 2, quality = 3, itemLevel = 50 },
        ["CARRIED:0:2"] = { itemID = 2, name = "Alpha Blade", classID = 2, quality = 3, itemLevel = 50 },
        ["CARRIED:0:3"] = { itemID = 3, name = "Big Blade", classID = 2, quality = 3, itemLevel = 60 },
        ["CARRIED:1:1"] = { itemID = 4, name = "Worm", classID = 0, quality = 1 },
        ["CARRIED:1:2"] = { itemID = 5, name = "Rubbish", classID = 15, quality = 0 },
    }
    local snap = I.Snapshot("CARRIED", more, function(l) return items[I.Key(l)] end)
    local function Keys(p, section) return table.concat(p.sections[section or 1].keys, ",") end

    local sorted = I.Project(snap, "GRID", "", true, { sort = true })
    assert(Keys(sorted) == "CARRIED:0:3,CARRIED:0:2,CARRIED:0:1,CARRIED:1:1,CARRIED:1:2,CARRIED:1:3",
        "sort: quality, item level, name; empty slots last")
    assert(Keys(I.Project(snap, "GRID", "", true)) == "CARRIED:0:1,CARRIED:0:2,CARRIED:0:3,CARRIED:1:1,CARRIED:1:2,CARRIED:1:3",
        "slot order is kept when sorting is off")

    assert(Keys(I.Project(snap, "GRID", "", true, { filter = "GEAR" })) == "CARRIED:0:1,CARRIED:0:2,CARRIED:0:3",
        "gear chip keeps only equipment")
    assert(I.Project(snap, "GRID", "", true, { filter = "JUNK" }).sections[1].keys[1] == "CARRIED:1:2", "junk chip")
    assert(Keys(I.Project(snap, "GRID", "", true, { container = 1 })) == "CARRIED:1:1,CARRIED:1:2,CARRIED:1:3",
        "bag filter limits to one container")

    local cat = I.Project(snap, "CATEGORIES", "", false, { customItems = { [4] = "Fishing" } })
    local order = {}
    for _, section in ipairs(cat.sections) do order[#order + 1] = section.key end
    assert(table.concat(order, ",") == "CUSTOM:Fishing,EQUIPMENT,JUNK", "custom categories sit after Quest, before the rest")
    assert(cat.sections[1].label == "Fishing" and cat.sections[1].count == 1, "custom category label and count")
    local quest = I.Project(snap, "CATEGORIES", "", false, { customItems = { [4] = "Fishing" } })
    assert(quest.sections[1].keys[1] == "CARRIED:1:1", "custom item moves out of its built-in category")

    local folded = I.Project(snap, "CATEGORIES", "", false, { collapsed = { EQUIPMENT = true } })
    local equipment
    for _, section in ipairs(folded.sections) do if section.key == "EQUIPMENT" then equipment = section end end
    assert(equipment.collapsed and #equipment.keys == 0 and equipment.count == 3, "collapsed sections keep their count")
end

print("PASS: bag snapshots drive grid, categories and immediate search")
