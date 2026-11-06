-- Bags: emptying one bag into the others (right-click on the bag bar).
-- Run: lua5.1 tests/bags-empty.lua
local T = {
    Bags = {},
    Num = function(v) return type(v) == "number" and v == v end,
    Str = function(v) return type(v) == "string" and v ~= "" end,
}
assert(loadfile("Modules/Bags/Client.lua"))("Tempus", T)
local Client = T.Bags.Client

-- Backpack (2 slots), bag 1 (3 slots, being emptied), bag 2 a quiver (family 1, 2 slots).
local slots = { [0] = { 101, nil }, [1] = { 201, 202, 203 }, [2] = { nil, nil } }
local sizes = { [0] = 2, [1] = 3, [2] = 2 }
local families = { [2] = 1 }
local itemFamily = { [202] = 1 }            -- 202 is arrows
local cursor
local env = {
    NUM_BAG_SLOTS = 2, BACKPACK_CONTAINER = 0,
    C_Container = {
        GetContainerNumSlots = function(b) return sizes[b] or 0 end,
        GetContainerNumFreeSlots = function(b) return 0, families[b] or 0 end,
        GetContainerItemInfo = function(b, s)
            local id = slots[b] and slots[b][s]
            if id then return { itemID = id, isLocked = false } end
        end,
        PickupContainerItem = function(b, s)
            if cursor then slots[b][s], cursor = cursor, nil
            else cursor, slots[b][s] = slots[b][s], nil end
        end,
    },
    GetItemFamily = function(id) return itemFamily[id] or 0 end,
    CursorHasItem = function() return cursor ~= nil end,
    ClearCursor = function() cursor = nil end,
}
local c = Client.New(env)

local moves, left = c:PlanEmpty(1)
assert(#moves == 2 and left == 1, "two fit (one backpack slot, one quiver slot for arrows), one left over")
assert(moves[1].from[2] == 1 and moves[1].to[1] == 0 and moves[1].to[2] == 2, "plain item to the backpack")
assert(moves[2].from[2] == 2 and moves[2].to[1] == 2, "arrows to the quiver")

for _, m in ipairs(moves) do assert(c:MoveItem(m.from, m.to), "move runs") end
assert(slots[0][2] == 201 and slots[2][1] == 202 and slots[1][3] == 203 and not slots[1][1], "items landed")
assert(not c:MoveItem({ 1, 3 }, { 0, 1 }), "never drops onto an occupied slot")

-- Taking the bag off: it lands in a free plain slot, never the quiver or the backpack slot 0.
env.C_Container.ContainerIDToInventoryID = function(b) return 19 + b end
local bagOff
env.PickupBagFromSlot = function(inv) cursor, bagOff = "bag" .. inv, inv end
slots[1][3] = nil
slots[0][1] = nil
assert(c:IsEmpty(1), "bag 1 is empty now")
local ok = c:UnequipBag(1)
assert(ok and bagOff == 20 and slots[0][1] == "bag20" and cursor == nil, "bag went into the backpack's free slot")
local okB, why = c:UnequipBag(0)
assert(not okB and why:find("backpack"), "the backpack stays on")
slots[0][1], slots[1][3] = 101, 203

-- Dragging bags on and off the bar.
local putBag, putPack
env.PutItemInBag = function(inv) putBag, cursor = inv, nil end
env.PutItemInBackpack = function() putPack, cursor = true, nil end
assert(c:PickupBag(2) and cursor == "bag21", "a bag comes off onto the cursor")
assert(c:DropOnBag(1) and putBag == 20 and cursor == nil, "dropped on a bag slot it equips there")
assert(not c:DropOnBag(1), "nothing on the cursor, nothing to drop")
assert(not c:PickupBag(0), "the backpack cannot be dragged off")
cursor = 999
assert(c:DropOnBag(0) and putPack, "dropping on the backpack puts the item in it")

local none, rest = c:PlanEmpty(1)
assert(#none == 0 and rest == 1, "no room left for the last item")
print("bags empty ok")
