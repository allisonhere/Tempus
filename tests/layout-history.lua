-- Position history is separate from preset storage and other profile settings.
local combat = false
function InCombatLockdown() return combat end
function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
local function Point(x) return {"CENTER", "UIParent", "CENTER", x, 0} end
local function Profile(x) return {unit = {point = Point(x), size = 42}, other = {point = Point(100)}} end
local T = {db = Profile(0), defaults = Profile(0), Movers = {list = {}}}
local refreshes, applied = 0, 0
function T.Movers:RefreshHistory() refreshes = refreshes + 1 end
function T:ApplySettings() applied = applied + 1; self.Layouts:Cancel() end
assert(loadfile("Core/Layouts.lua"))("Tempus", T)
local L = T.Layouts
local function Edit(x)
    local edit = L:BeginEdit(); T.db.unit.point[4] = x; L:EndEdit(edit)
end
assert(not L:CanUndo() and not L:CanRedo())
assert(not L:Undo() and not L:Redo())
Edit(10); Edit(20)
assert(L:CanUndo() and not L:CanRedo())
assert(L:Undo() and T.db.unit.point[4] == 10)
assert(L:Undo() and T.db.unit.point[4] == 0)
assert(not L:Undo() and L:CanRedo())
assert(L:Redo() and T.db.unit.point[4] == 10)
-- Unrelated changes made outside mover history must survive position undo.
T.db.unit.size = 99; T.db.other.point[4] = 888
assert(L:Undo() and T.db.unit.point[4] == 0)
assert(T.db.unit.size == 99 and T.db.other.point[4] == 888)
-- A no-op preserves redo; a new position change branches and drops redo.
local noop = L:BeginEdit(); L:EndEdit(noop)
assert(L:CanRedo())
Edit(30); assert(not L:CanRedo()); assert(L:Undo()); assert(L:Redo())
assert(T.db.unit.point[4] == 30)
-- Preview and cancel must not add history; apply a preset and defaults as single steps.
assert(L:Save("Thirty")); Edit(45)
assert(L:Stage("Thirty")); L:Cancel()
assert(L:Undo() and T.db.unit.point[4] == 30)
assert(L:Redo() and T.db.unit.point[4] == 45)
assert(L:Stage("Thirty")); assert(L:Apply()); assert(T.db.unit.point[4] == 30)
assert(L:Undo() and T.db.unit.point[4] == 45)
assert(L:Redo() and T.db.unit.point[4] == 30)
assert(L:Stage(nil, true)); assert(L:Apply())
assert(T.db.unit.point[4] == 0 and T.db.other.point[4] == 100)
assert(L:Undo() and T.db.unit.point[4] == 30 and T.db.other.point[4] == 888)
assert(L:Redo() and T.db.unit.point[4] == 0)
assert(T.db.unit.size == 99 and L:Store().Thirty[1])
-- Failed requests leave both stacks intact, and do not queue future actions.
combat = true
assert(not L:CanUndo() and not L:Undo() and not L:Redo())
assert(T.db.unit.point[4] == 0); combat = false
for _, flag in ipairs({"moving", "sizing"}) do
    T.Movers.list = {{[flag] = true}}
    assert(not L:CanUndo() and not L:Undo() and not L:Redo())
end
T.Movers.list = {}; assert(L:Undo() and T.db.unit.point[4] == 30)
-- Switching profiles isolates histories, and abandoned edits cannot enter a new profile.
local first = T.db
local abandoned = L:BeginEdit()
T.db = Profile(500); L:EndEdit(abandoned)
assert(not L:CanUndo() and not L:CanRedo())
Edit(600); assert(L:Undo() and T.db.unit.point[4] == 500)
T.db = first; assert(L:CanRedo()); assert(L:Redo() and T.db.unit.point[4] == 0)
-- Snapshots and histories are detached, including settings mutated after redo.
assert(L:Undo()); T.db.unit.point[4] = 222
assert(L:Redo() and T.db.unit.point[4] == 0)
assert(L:Undo() and T.db.unit.point[4] == 30)
-- Missing modules are skipped; history never resurrects deleted config tables.
T.db = Profile(0); Edit(10); T.db.unit = nil
assert(L:Undo() and T.db.unit == nil); assert(L:Redo() and T.db.unit == nil)
-- Introducing an anchor is reversible, without erasing the frame's other settings.
T.db = {unit = {size = 9}}
local edit = L:BeginEdit(); T.db.unit.point = Point(3); L:EndEdit(edit)
assert(L:Undo() and T.db.unit.point == nil and T.db.unit.size == 9)
assert(L:Redo() and T.db.unit.point[4] == 3)
-- Numeric and string configuration paths remain distinct.
T.db = {groups = {[1] = {point = Point(0)}, ["1"] = {point = Point(100)}}}
edit = L:BeginEdit(); T.db.groups[1].point[4] = 15; L:EndEdit(edit)
assert(L:Undo() and T.db.groups[1].point[4] == 0 and T.db.groups["1"].point[4] == 100)
-- Only the latest 50 actions remain available; redo survives no-ops at the limit.
T.db = Profile(0)
for x = 1, 60 do Edit(x) end
for x = 59, 10, -1 do assert(L:Undo() and T.db.unit.point[4] == x) end
assert(not L:Undo())
edit = L:BeginEdit(); L:EndEdit(edit); assert(L:CanRedo())
for x = 11, 60 do assert(L:Redo() and T.db.unit.point[4] == x) end
assert(not L:Redo())
assert(T.db.layoutPresets == nil, "history must not be persisted in preset storage")
-- Reload starts clean even when the profile settings persist.
assert(loadfile("Core/Layouts.lua"))("Tempus", T)
assert(not T.Layouts:CanUndo() and not T.Layouts:CanRedo())
assert(refreshes > 0 and applied > 0)
print("PASS: position undo/redo, presets, branching, guards, profiles and history limit")
