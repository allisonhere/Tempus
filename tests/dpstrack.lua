-- Layered DPS track: milestones stay ordered, the scale keeps headroom, numbers abbreviate,
-- and the meter's sources give the right live and top values (or report them secret).
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
local T = { issecret = function(v) return v == SECRET end }
for _, file in ipairs({ "State", "Scale", "Source" }) do
    assert(loadfile("Modules/DPSTrack/" .. file .. ".lua"))("Tempus", T)
end
local DT = T.DPSTrack
local State, Scale, Source = DT.State, DT.Scale, DT.Source

-- State: peak only rises, top never sits below the peak.
local s = State.New()
State.Update(s, 500, 900)
assert(s.live == 500 and s.peak == 500 and s.top == 900, "first reading")
State.Update(s, 800, 900)
assert(s.peak == 800 and s.top == 900, "peak rises")
State.Update(s, 300, 700)
assert(s.live == 300 and s.peak == 800 and s.groupTop == 700 and s.top == 800, "top never below peak")
State.Update(s, 1000, 0)
assert(s.groupTop == 1000 and s.top == 1000 and s.peak == 1000, "you lead: edges coincide")
State.Update(s, -5, 0 / 0)
assert(s.live == 0 and s.peak == 1000, "bad readings count as 0")
State.Reset(s)
assert(s.live == 0 and s.peak == 0 and s.top == 0, "reset")
State.Update(s, 800, 900)
State.BeginFight(s)
assert(s.live == 0 and s.peak == 800 and s.top == 800, "new fight keeps past high")
State.Update(s, 300, 500)
assert(s.peak == 800, "lower DPS in a later fight keeps past high")
s = State.New(s.peak)
assert(s.peak == 800, "saved high survives reload")
State.Reset(s)
assert(s.peak == 0, "meter reset clears past high")

-- Segment widths are the differences between edges and are never negative.
State.Update(s, 782e3, 1.24e6)
State.Update(s, 1.08e6, 1.24e6)
State.Update(s, 782e3, 1.24e6)
assert(s.live == 782e3 and s.peak == 1.08e6 and s.top == 1.24e6, "example from the spec")

-- Scale.
assert(Scale.Target(nil, "TOP", 1000) == 1000, "group top fills the bar")
assert(Scale.Target(nil, "FIXED", 1000, 5000) == 5000, "fixed")
local t = Scale.Target(nil, "DYNAMIC", 880)
assert(math.abs(t - 1000) < 1e-6, "dynamic puts the top at 88%")
assert(Scale.Target(t, "DYNAMIC", 900) == t, "small rise: no rescale")
assert(Scale.Target(t, "DYNAMIC", 700) == t, "small fall: no rescale")
assert(Scale.Target(t, "DYNAMIC", 960) > t, "near the end: grows")
assert(Scale.Target(t, "DYNAMIC", 500) == t, "falling DPS never shrinks the saved range")
assert(Scale.Target(nil, "DYNAMIC", 0) == 1, "no data: never 0")
assert(Scale.Approach(0, 100, 0, 0.016) == 100, "speed 0 snaps")
local a = Scale.Approach(0, 100, 8, 0.016)
assert(a > 0 and a < 100, "eases")
local b1 = Scale.Approach(Scale.Approach(0, 100, 8, 0.008), 100, 8, 0.008)
assert(math.abs(a - b1) < 1e-9, "frame-rate independent")

-- Format.
local cases = { [0] = "0", [999] = "999", [1500] = "1.5K", [99949] = "99.9K", [782e3] = "782K",
    [999600] = "1.00M", [1.08e6] = "1.08M", [1.24e6] = "1.24M", [2.5e9] = "2.50B" }
for v, want in pairs(cases) do assert(DT.Format(v) == want, v .. " -> " .. DT.Format(v)) end

-- Source.Pick: local player by flag or GUID, top across everyone.
local live, top, secret = Source.Pick({
    { amountPerSecond = 400, sourceGUID = "a" },
    { amountPerSecond = 700, isLocalPlayer = true },
    { amountPerSecond = 900, sourceGUID = "b" },
}, "x")
assert(live == 700 and top == 900 and not secret, "flagged player")
live, top = Source.Pick({ { amountPerSecond = 300, sourceGUID = "me" }, { amountPerSecond = 100 } }, "me")
assert(live == 300 and top == 300, "player by GUID, and leading")
live, top, secret = Source.Pick({ { amountPerSecond = SECRET, isLocalPlayer = true } }, "me")
assert(secret and live == SECRET and top == nil, "secret values are passed through, top unknown")
live, top, secret = Source.Pick(nil)
assert(live == 0 and top == 0 and not secret, "no sources")

-- The DPS session is ranked by the meter. maxAmount is total damage, not DPS.
Enum = { DamageMeterType = { DamageDone = 0, Dps = 1 }, DamageMeterSessionType = { Current = 1 } }
UnitGUID = function() return "me" end
C_DamageMeter = { GetCombatSessionFromType = function(sessionType, meterType)
    assert(sessionType == 1 and meterType == 1, "read current DPS session")
    return { maxAmount = 90000, combatSources = {
        { amountPerSecond = SECRET },
        { amountPerSecond = 400, isLocalPlayer = true },
    } }
end }
live, top, secret = Source.Read()
assert(live == 400 and top == SECRET and secret, "secret top uses ranked DPS, not total damage")

-- Test source keeps live within the group top.
for i = 0, 100 do
    local l, tp = Source.Test(i * 0.37)
    assert(l > 0 and tp >= l, "test values ordered")
end
print("PASS: DPS track state, scale, number format and meter source")
