-- /tempus gearstats lists the stat names on carried gear and flags the ones with no weight.
local T = { Print = function() end, issecret = function() return false end }
T.Market = {}
assert(loadfile("Modules/GearAdvisor/Weights.lua"))("Tempus", T)
assert(loadfile("Modules/Market/Probe.lua"))("Tempus", T)
NUM_BAG_SLOTS = 1
GetInventoryItemLink = function(_, slot) if slot == 1 then return "head" elseif slot == 16 then return "mace" end end
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
    GetContainerItemLink = function(_, slot) return slot == 1 and "robe" or nil end }
local stats = { head = { ITEM_MOD_AGILITY_SHORT = 12, ITEM_MOD_STAMINA_SHORT = 5 },
    mace = { ITEM_MOD_AGILITY_SHORT = 7, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14.2 },
    robe = { ITEM_MOD_WEIRD_THING_SHORT = 33, ITEM_MOD_AGILITY_SHORT = 2 } }
C_Item = { GetItemStats = function(l) return stats[l] end, GetItemInfo = function(l) return "Name " .. l end }
local lines = T.Market.GearStats()
assert(lines[1] == "3 items read, 4 stat names", lines[1])
local text = table.concat(lines, "\n")
assert(text:find("ITEM_MOD_AGILITY_SHORT: 3 items, 2 to 12, e.g. Name head"), text)
assert(text:find("ITEM_MOD_DAMAGE_PER_SECOND_SHORT: 1 items, 14.2"), text)
assert(text:find("NO WEIGHT  ITEM_MOD_WEIRD_THING_SHORT"), "an unweighted stat name is flagged")
assert(not text:find("NO WEIGHT  ITEM_MOD_AGILITY_SHORT"), "a weighted one is not")
C_Item.GetItemStats = nil
assert(T.Market.GearStats()[1]:find("missing"), "no stats call: say so")
print("PASS: gearstats lists stat names, counts, ranges and unweighted keys")
