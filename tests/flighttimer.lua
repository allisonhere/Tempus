-- Flight timer: learned lengths, counting up then down, and the watch loop.
local modDef
local T = { NewModule = function(_, _, def) modDef = def end, RegisterPage = function() end }
now = 0
GetTime = function() return now end
assert(loadfile("Modules/FlightTimer/FlightTimer.lua"))("Tempus", T)
local FT = T.FlightTimer

assert(FT.Clock(0) == "0:00" and FT.Clock(75) == "1:15" and FT.Clock(59.6) == "1:00" and FT.Clock(-4) == "0:00")
assert(FT.Key("A", "B") == "A > B")

local times = {}
assert(FT.Record(times, "k", 2) == nil and times.k == nil, "a trip under three seconds is not a flight")
assert(FT.Record(times, "k", 100) == 100 and FT.Record(times, "k", 110) == 105, "later trips are averaged")

local fill, text, counting = FT.State(30, nil)
assert(fill == 0 and text == "0:30" and counting == false, "unknown length counts up")
fill, text, counting = FT.State(30, 120)
assert(fill == 0.25 and text == "1:30" and counting == true, "known length counts down")
assert(FT.State(500, 120) == 1, "never over full")

-- A flight: choose it on the map, take off, land.
FT.db = { times = {} }
FT.slots, FT.origin = { [3] = "Crossroads" }, "Orgrimmar"
FT:Chosen(3)
assert(FT.pending and FT.pending.from == "Orgrimmar" and FT.pending.to == "Crossroads")
now = 10
assert(FT:Step(now, false) == nil and FT.pending, "not flying yet")
local f1, t1 = FT:Step(now, true)
assert(FT.flight and f1 == 0 and t1 == "0:00", "take-off starts the timer")
now = 70
local _, t2 = FT:Step(now, true)
assert(t2 == "1:00", "counting up on the first trip")
assert(FT:Step(now + 5, false) == nil and FT.flight == nil and FT.db.times["Orgrimmar > Crossroads"] == 65, "landing saves the length")
now = 200; FT:Chosen(3)
FT:Step(now, true); now = 230
local f3, t3, _, counting3 = FT:Step(now, true)
assert(counting3 and t3 == "0:35" and math.abs(f3 - 30 / 65) < 1e-9, "the second trip counts down")
-- a chosen flight that never takes off is forgotten
FT.flight = nil; FT:Chosen(3); now = now + 200
FT:Step(now, false)
assert(FT.pending == nil, "a stale choice is dropped")
-- nothing chosen: a ride the timer did not see does nothing
assert(FT:Step(now, true) == nil and FT.flight == nil)
print("PASS: flight timer learns lengths, counts up then down")

-- WoW only updates visible frames. The watcher must keep running while the bar is hidden.
local frames = {}
local function region()
    return setmetatable({
        SetShown = function(self, value) self.shown = not not value end,
        Hide = function(self) self.shown = false end,
        SetText = function(self, value) self.text = value end,
        SetTexCoord = function(self, ...) self.coords = { ... } end,
    }, { __index = function() return function() end end })
end
CreateFrame = function(_, name)
    local frame = region()
    frame.name, frame.shown, frame.scripts = name, true, {}
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:SetShown(shown) self.shown = not not shown end
    frames[#frames + 1] = frame
    return frame
end
T.db = { locked = true, flighttimer = { enabled = true, width = 240, height = 22, times = {} } }
T.Style = { Backdrop = function() end, Tex = region, Accent = function() end,
    Text = region, C = { text = {} } }
T.Movers = { ApplyPoint = function() end, Register = function() end }
function T:Wrap(_, callback) return callback end
local choose
hooksecurefunc = function(name, callback)
    assert(name == "TakeTaxiNode")
    choose = callback
end
local onTaxi = false
UnitOnTaxi = function() return onTaxi end
local function tick()
    for _, frame in ipairs(frames) do
        if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.2) end
    end
end
FT.pending, FT.flight = nil, nil
modDef.OnEnable()
assert(not FT.frame.shown, "locked timer starts hidden")
FT.origin, FT.slots = "Orgrimmar", { [3] = "Crossroads" }
now = 1000
choose(3)
onTaxi = true
tick()
assert(FT.frame.shown and FT.flight, "hidden bar detects takeoff through the visible watcher")
assert(FT.frame.learning.shown and FT.frame.learning.text == "Learning route", "first trip explains learning")
assert(FT.frame.name.text == "Crossroads" and FT.frame.time.text == "0:00", "learning preserves destination and elapsed time")
tick()
assert(FT.frame.hourglass.coords[1] > 0, "visible hourglass advances through the sprite sheet")
T.db.animate = false
tick()
assert(FT.frame.hourglass.coords[1] == 0 and FT.frame.hourglass.coords[3] == 0, "disabled animations keep the hourglass still")
now = 1065
onTaxi = false
tick()
assert(not FT.frame.shown and FT.db.times["Orgrimmar > Crossroads"] == 65, "landing saves the flight and hides the bar")
assert(not FT.frame.learning.shown, "learning label hides on landing")
now = 1100
choose(3)
onTaxi = true
tick()
assert(FT.frame.shown and FT.flight, "watcher detects another flight after hiding the bar")
assert(not FT.frame.learning.shown and FT.frame.time.text == "1:05", "known route counts down without learning label")
print("PASS: hidden flight bar keeps watching for takeoff and landing")
