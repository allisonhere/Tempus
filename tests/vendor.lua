-- Vendor module: sells only grey items with a price, repairs once, and reports. Run: lua5.1 tests/vendor.lua
local printed = {}
local T = { Num = function(v) return type(v) == "number" end, Wrap = function(_, _, fn) return fn end,
    NewModule = function() end, Print = function(_, msg, ...) printed[#printed + 1] = msg:format(...) end }
local bags = {
    [0] = { { quality = 0, stackCount = 3, itemID = 1 }, { quality = 1, itemID = 2 }, { quality = 0, hasNoValue = true, itemID = 3 } },
    [1] = { { quality = 0, stackCount = 1, itemID = 4 } },
}
NUM_BAG_SLOTS = 1
local used = {}
C_Container = {
    GetContainerNumSlots = function(bag) return #(bags[bag] or {}) end,
    GetContainerItemInfo = function(bag, slot) return bags[bag][slot] end,
    UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end,
}
local prices = { [1] = 10, [2] = 500, [3] = 0, [4] = 7 }
GetItemInfo = function(id) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, prices[id] end
GetCoinTextureString = function(c) return c .. "c" end
local repaired = 0
CanMerchantRepair = function() return true end
GetRepairAllCost = function() return 120 end
GetMoney = function() return 1000 end
RepairAllItems = function() repaired = repaired + 1 end
assert(loadfile("Modules/Vendor/Vendor.lua"))("Tempus", T)
local V = T.Vendor
V.db = { sellGrey = true, autoRepair = true, guildRepair = false, summary = true }
V:OnMerchant()
assert(table.concat(used, ",") == "0:1,1:1", "sold " .. table.concat(used, ","))
assert(repaired == 1, "repaired once")
assert(printed[1]:find("sold 2 grey items for 37c"), printed[1])
assert(printed[2]:find("repaired for 120c"), printed[2])

used, printed, repaired = {}, {}, 0
V.db = { sellGrey = false, autoRepair = false, summary = true }
V:OnMerchant()
assert(#used == 0 and repaired == 0 and #printed == 0, "everything off does nothing")

GetMoney = function() return 50 end
V.db = { sellGrey = false, autoRepair = true, summary = true }
V:OnMerchant()
assert(repaired == 0 and printed[1]:find("not enough gold"), "no repair when too poor")
print("PASS: vendor sells only priced grey items, repairs when affordable, respects the switches")
