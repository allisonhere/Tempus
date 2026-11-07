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
local pw = SW.PreviewWanted({ offHand = true, ranged = false })
assert(pw.main and pw.off and not pw.ranged, "preview follows the bar settings, not the weapons")
assert(SW.PREVIEW.main > 0 and SW.PREVIEW.off > 0 and SW.PREVIEW.ranged > 0)

-- Settings demo rows swing on their own and never touch the real timer's fight tally.
local function Stub()
    local o = { scripts = {} }
    return setmetatable(o, { __index = function(t, k)
        if not k:match("^%u") then return nil end      -- fields stay nil; methods are no-ops
        if k == "SetScript" then return function(self, ev, fn) self.scripts[ev] = fn end end
        if k == "GetWidth" then return function() return 200 end end
        if k == "GetFrameLevel" then return function() return 1 end end
        if k == "GetStatusBarTexture" or k == "CreateTexture" or k == "CreateFontString" then
            return function() return Stub() end
        end
        return function() end
    end })
end
local made = {}
CreateFrame = function() local f = Stub(); made[#made + 1] = f; return f end
local now = 0
GetTime = function() return now end
GetNetStats = function() return 0, 0, 0, 40 end
T.Style = { Backdrop = function() end, StatusBar = function() return Stub() end, ApplyFont = function() end }
T.accent = { 0.2, 0.6, 1 }
T.Wrap = function(_, _, fn) return fn end
local loopFn
T.UI = { Loop = function(_, _, fn) loopFn = fn end }
T.db = { swing = {} }
for k, v in pairs(SW.defaults) do T.db.swing[k] = v end
assert(loadfile("Modules/Swing/Swing.lua"))("Tempus", T)
SW = T.Swing
SW.fight = SW.NewFight(0)
SW.db = T.db.swing
local box = SW.CreateDemo(300)
assert(box and loopFn, "demo built with a loop")
local notified = 0
SW.listener = function() notified = notified + 1 end
local finished = 0
for t = 0, 12, 0.05 do
    now = t
    loopFn(nil, now)
    for _, f in ipairs(made) do
        if f.scripts.OnUpdate then
            local had = f.endT
            f.scripts.OnUpdate(f)
            if had and not f.endT then finished = finished + 1 end
        end
    end
end
assert(finished >= 6, "demo rows swing and land on their own (" .. finished .. ")")
assert(SW.fight.swings == 0 and SW.fight.swinging == 0 and SW.fight.idle == 0, "demo swings stay out of the fight tally")
assert(notified == 0, "demo swings do not notify Combat Pulse")
print("swing ok")
