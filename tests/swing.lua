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
assert(math.abs(SW.CueWindow({ cueWindow = 0.4 }, 50, 3) - 0.4) < 1e-9, "latency off by default in this db")
assert(math.abs(SW.CueWindow({ cueWindow = 0.4, cueLatency = true }, 100, 3) - 0.5) < 1e-9, "latency widens the cue")
assert(SW.CueWindow({ cueWindow = 1.5, cueLatency = true }, 200, 1) <= 0.6, "never longer than 60% of the swing")
assert(SW.CueWindow({}, nil, nil) == 0.4, "defaults")
-- Fight tally: swinging 10s, out of range 4s, idle 6s.
local f = SW.NewFight(0)
SW.FightMark(f, 2, true, false)      -- 0-2 idle
SW.FightMark(f, 12, false, true)     -- 2-12 swinging
SW.FightMark(f, 16, false, false)    -- 12-16 out of range
f.swings = 4
SW.FightFinish(f, 20)                -- 16-20 idle
assert(f.swinging == 10 and f.outOfRange == 4 and f.idle == 6, "tally split")
assert(math.abs(f.pct - 0.5) < 1e-9 and f.total == 20)
assert(SW.FightText(f) == "Swinging 50% | out of range 4.0s | idle 6.0s", SW.FightText(f))
f.swings = 1
assert(SW.FightText(f) == nil, "too few swings")
local g = SW.NewFight(0); g.swings = 5; SW.FightFinish(g, 3)
assert(SW.FightText(g) == nil, "too short")
print("swing ok")
