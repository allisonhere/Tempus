local combat = false
function InCombatLockdown() return combat end
function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
local applied = 0
local T = {Movers = {list = {}}, db = {unit = {point = {"CENTER", "UIParent", "CENTER", 5, 6}, size = 42}},
 defaults = {unit = {point = {"CENTER", "UIParent", "CENTER", 0, 0}}},
 ApplySettings = function() applied = applied + 1 end}
assert(loadfile("Core/Layouts.lua"))("Tempus", T)
local L = T.Layouts
assert(L:Save(" Solo ") == "Solo")
T.db.unit.point[4] = 70
assert(L:Store().Solo[1].point[4] == 5)
for _, name in ipairs({"Solo", " ", "bad|name", string.rep("a",49), "bad\nname"}) do assert(not L:Save(name)) end
assert(L:Duplicate("Solo", "Raid")); L:Store().Raid[1].point[4] = 100
assert(L:Store().Solo[1].point[4] == 5)
assert(not L:Rename("Solo", "Raid")); assert(L:Rename("Raid", "Group"))
assert(not L:Store().Raid and L:Store().Group)
assert(#L:Capture() == 1, "must not capture preset store")
assert(L:Stage("Solo")); assert(T.db.unit.point[4] == 70, "preview must not mutate")
L:Cancel(); assert(not L:Apply())
assert(L:Stage("Solo")); assert(L:Apply())
assert(T.db.unit.point[4] == 5 and T.db.unit.size == 42 and applied == 1)
T.db.unit.point[4] = 90; assert(L:Store().Solo[1].point[4] == 5)
assert(L:Stage(nil,true)); assert(L:Apply())
assert(T.db.unit.point[4] == 0 and T.db.unit.size == 42 and L:Store().Solo)
combat = true; assert(not L:Stage("Solo")); combat = false
assert(L:Stage("Solo")); combat = true; assert(not L:Apply()); combat = false; L:Cancel()
T.Movers.list = {{moving = true}}; assert(not L:Stage("Solo")); T.Movers.list = {}
assert(L:Stage("Solo")); T.Movers.list = {{moving = true}}; assert(not L:Apply()); T.Movers.list = {}; L:Cancel()
assert(L:Stage("Solo")); local previous = T.db; T.db = {unit = {point = {1,2,3,4,5}}}
assert(not L:Apply()); assert(T.db.unit.point[4] == 4 and not L.pending)
assert(#L:Names() == 0)
T.db = previous; assert(L:Stage("Solo")); T.db.unit = nil; assert(L:Apply())
print("PASS: layout presets")
-- Preview rendering uses current geometry without moving live frames, and reuses ghosts.
local function Region()
    return setmetatable({shown = true}, {__index = function(_, key)
        if key == "Hide" then return function(self) self.shown = false end end
        if key == "Show" then return function(self) self.shown = true end end
        if key == "CreateFontString" then return Region end
        return function() end
    end})
end
UIParent = {GetEffectiveScale = function() return 1 end}
CreateFrame = Region
T.Style = {Tex = Region, Accent = function(v) return v end, CreateBorder = Region}
T.accent = {1, .5, 0}
T.db.unit = {point = {"CENTER", "UIParent", "CENTER", 900, 800}}
local target = {GetEffectiveScale = function() return 2 end, GetWidth = function() return 100 end, GetHeight = function() return 30 end}
T.Movers.list = {{target = target, opts = {cfg = function() return T.db.unit end, label = "Player"}}}
assert(L:Stage("Solo")); assert(#L.ghosts == 1 and T.db.unit.point[4] == 900)
local first = L.ghosts[1]
L:Cancel(); assert(not first.shown)
assert(L:Stage("Solo")); assert(L.ghosts[1] == first and first.shown)
-- Staged positions stay detached even if saved data is edited after preview.
L:Store().Solo[1].point[4] = 777
assert(L:Apply()); assert(T.db.unit.point[4] == 5 and not first.shown)
