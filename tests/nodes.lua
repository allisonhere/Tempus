-- Gathering nodes: pin placement and merging of repeat nodes.
-- Run: lua5.1 tests/nodes.lua
local module
local T = { Num = function(v) return type(v) == "number" end, Wrap = function(_, _, fn) return fn end,
    NewModule = function(_, _, def) module = def end, ReportError = function() end }
assert(loadfile("Modules/Nodes/Nodes.lua"))("Tempus", T)
local N = T.Nodes

-- 233 yards east at a 466.67-yard diameter lands on the right edge of a 90-px half-width map.
local x, y = N.Project(233.335, 0, 466.67, 90)
assert(math.abs(x - 90) < 0.01 and math.abs(y) < 0.01, "east edge")
assert(N.Project(300, 0, 466.67, 90) == nil, "outside is hidden")
local x2, y2 = N.Project(0, 100, 200, 90)
assert(math.abs(x2) < 1e-9 and math.abs(y2 - 90) < 1e-9, "north at 100 yards of a 200-yard map")
-- Facing west (pi/2, counter-clockwise from north) with rotation on puts a north node to the right.
local x3, y3 = N.Project(0, 50, 200, 90, math.pi / 2)
assert(math.abs(x3 - 45) < 0.01 and math.abs(y3) < 0.01, "rotation")
-- Facing east (3pi/2) puts it to the left; facing south (pi) puts it below.
local x4 = N.Project(0, 50, 200, 90, 3 * math.pi / 2)
assert(math.abs(x4 + 45) < 0.01, "rotation east")
local _, y5 = N.Project(0, 50, 200, 90, math.pi)
assert(math.abs(y5 + 45) < 0.01, "rotation south")

-- A node of the same kind within a few yards is the same node; another kind is not.
local list = {}
assert(N.Add(list, { x = 0.5, y = 0.5, kind = "ore" }, 1000, 1000))
assert(not N.Add(list, { x = 0.5005, y = 0.5, kind = "ore", icon = "i" }, 1000, 1000), "merged")
assert(list[1].icon == "i", "merge keeps the newer icon")
assert(N.Add({ { x = 0.5, y = 0.5, kind = "ore", seen = 1 } }, { x = 0.5, y = 0.5, kind = "ore", seen = 99 }, 1000, 1000) == false, "repeat gather merges")
local again = { { x = 0.5, y = 0.5, kind = "ore", seen = 1 } }
N.Add(again, { x = 0.5, y = 0.5, kind = "ore", seen = 99 }, 1000, 1000)
assert(again[1].seen == 99, "re-gathering refreshes the time")
assert(N.Add(list, { x = 0.5005, y = 0.5, kind = "herb" }, 1000, 1000), "other kind kept")
assert(N.Add(list, { x = 0.6, y = 0.5, kind = "ore" }, 1000, 1000), "far node kept")

-- Learning: the icon is read on LOOT_READY, before fast loot empties the window.
local handler
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(self, k, fn) if k == "OnEvent" then handler = fn end end }
end
TempusDB = {}
T.db = { nodes = { learn = true } }
C_Map = {
    GetBestMapForUnit = function() return 7 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.4, 0.6 end } end,
}
C_Timer = { After = function() end }
GetTime = function() return 10 end
time = function() return 1000 end
local slots = { "ore-icon" }
GetNumLootItems = function() return #slots end
GetLootSlotInfo = function(i) return slots[i] end
module.OnEnable()
handler(nil, "UNIT_SPELLCAST_SENT", "player", "", "guid1", 2575)
handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid1", 2575)
handler(nil, "LOOT_READY")
slots = {}
handler(nil, "LOOT_OPENED")
local learned = TempusDB.nodes[7]
assert(learned and #learned == 1 and learned[1].icon == "ore-icon" and learned[1].kind == "ore", "icon from LOOT_READY")
-- An empty LOOT_READY waits for LOOT_OPENED.
handler(nil, "UNIT_SPELLCAST_SENT", "player", "", "guid2", 2366)
handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid2", 2366)
handler(nil, "LOOT_READY")
slots = { "herb-icon" }
handler(nil, "LOOT_OPENED")
assert(#learned == 2 and learned[2].icon == "herb-icon", "falls back to LOOT_OPENED")
-- A failed cast learns nothing.
handler(nil, "UNIT_SPELLCAST_SENT", "player", "", "guid3", 2575)
handler(nil, "UNIT_SPELLCAST_FAILED", "player", "guid3", 2575)
handler(nil, "LOOT_READY")
assert(#learned == 2, "failed gather ignored")

print("PASS: gathering nodes")
