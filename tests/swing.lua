-- Swing timer: which weapon rows show, and when the target counts as out of range.
-- Run: lua5.1 tests/swing.lua
local T = { Style = {}, issecret = function() return false end }
function T.Num(v) return type(v) == "number" and v == v end
function T:NewModule(key, def) self.module = def end
assert(loadfile("Modules/Swing/Swing.lua"))("Tempus", T)
local SW = T.Swing
assert(T.module and T.module.defaults == SW.defaults)

local db = { offHand = true, ranged = true }
local w = SW.Wanted(db, 2.6, nil, nil)
assert(w.main and not w.off and not w.ranged, "main hand only")
w = SW.Wanted(db, 2.6, 1.8, 3.0)
assert(w.main and w.off and w.ranged, "all weapons")
w = SW.Wanted(db, 2.6, 0, 0)
assert(not w.off and not w.ranged, "zero speed means no weapon")
w = SW.Wanted({ offHand = false, ranged = false }, 2.6, 1.8, 3.0)
assert(not w.off and not w.ranged, "rows turned off")

assert(SW.OutOfRange(false, true) == true)
assert(SW.OutOfRange(true, true) == false)
assert(SW.OutOfRange(false, false) == false, "no check made is not out of range")
assert(SW.OutOfRange(nil) == false, "nil from IsTargetWithinSwingRange is not out of range")
assert(SW.OutOfRange(false) == true)
print("swing ok")
