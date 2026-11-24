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
