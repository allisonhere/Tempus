-- Resource ticker: tick detection, phase and the five-second rule, plus a run against a fake client.
-- Run: lua5.1 tests/ticker.lua
local T = { Style = {}, issecret = function() return false end, db = { locked = true } }
function T.Num(v) return type(v) == "number" and v == v end
function T:NewModule(key, def) self.module = def end
assert(loadfile("Modules/Ticker/Ticker.lua"))("Tempus", T)
local TK = T.Ticker
assert(T.module.defaults == TK.defaults)

-- Which gains count as a tick.
assert(TK.IsTick(20, 20), "a regular energy tick")
assert(TK.IsTick(21, 20), "rounding")
assert(not TK.IsTick(25, 20), "Relentless Strikes refund is not a tick")
assert(not TK.IsTick(40, 20), "Thistle Tea is not a tick")
assert(TK.IsTick(40, 40), "Adrenaline Rush doubles the tick")
assert(TK.IsTick(7, 20, true), "a tick that hits the cap gives less")
assert(not TK.IsTick(7, 20, false), "a small gain below the cap is not a tick")
assert(not TK.IsTick(0, 20) and not TK.IsTick(-5, 20), "no gain, no tick")
assert(TK.IsTick(13, nil), "without a regen figure any gain counts")

-- Phase from the last tick.
local left, done = TK.Phase(10, 10.5)
assert(math.abs(left - 1.5) < 1e-9 and math.abs(done - 0.25) < 1e-9)
left = TK.Phase(10, 14.5)
assert(math.abs(left - 1.5) < 1e-9, "the clock keeps running past missed ticks (power full)")
assert(TK.Phase(nil, 5) == nil, "no tick seen yet")

-- What the bar shows.
assert(TK.Mode("mana", 1, 8, 6, true) == "FSR")
assert(TK.Mode("mana", 1, 8, 6, false) == "TICK", "five-second rule display off")
assert(TK.Mode("mana", 1, 8, 9, true) == "TICK", "rule over")
assert(TK.Mode("energy", 1, 8, 6, true) == "TICK", "energy has no five-second rule")
assert(TK.Mode("energy", nil, nil, 6, true) == nil)

-- Fake client: a rogue spends energy, then the server ticks it back.
local now, energy, ptype, regen = 100, 100, 3, 10
GetTime = function() return now end
UnitPowerType = function() return ptype end
UnitPower = function() return energy end
UnitPowerMax = function() return 100 end
GetPowerRegen = function() return regen end
GetManaRegen = function() return 4, 1 end
UnitAffectingCombat = function() return false end
local shown
TK.db = {}
for k, v in pairs(TK.defaults) do TK.db[k] = v end
TK.frame = { SetShown = function(_, on) shown = on end, SetSize = function() end }
local font = { SetShown = function() end }
TK.text, TK.label = font, font
TK.spark = { SetSize = function() end }
T.Style.ApplyFont = function() end
TK:Refresh()
assert(TK.kind == "energy" and shown == false, "full energy out of combat stays hidden (AUTO)")
energy = 60; now = 100.3; TK:OnPower()
assert(TK.lastTick == nil and shown == true, "a spend shows the bar, no tick yet")
energy = 80; now = 101.1; TK:OnPower()
assert(TK.lastTick == 101.1, "a 20-energy gain is a tick")
energy = 105 - 20; now = 102.0; TK:OnPower()      -- +5 from a refund
assert(TK.lastTick == 101.1, "a small refund does not move the phase")

-- Mana: spending starts the five-second rule.
ptype, energy = 0, 500
UnitPower = function() return energy end
UnitPowerMax = function() return 1000 end
now = 200; TK:OnPower()
assert(TK.kind == "mana" and TK.lastTick == nil, "switching power resets the phase")
energy = 420; now = 200.5; TK:OnPower()
assert(TK.fsrEnd == 205.5, "spending mana starts the 5s rule")
energy = 422; now = 201; TK:OnPower()
assert(TK.lastTick == 201, "a casting-regen tick during the rule still sets the phase")
energy = 430; now = 207; TK:OnPower()
assert(TK.lastTick == 207, "a full spirit tick after the rule")
-- Bar colour follows what it shows.
assert(TK.ColorFor("FSR", "mana") == TK.FSR_COLOR, "violet during the five-second rule")
assert(TK.ColorFor("TICK", "mana") == TK.MANA_COLOR)
assert(TK.ColorFor("TICK", "energy") == TK.ENERGY_COLOR)
assert(TK.ColorFor(nil, "energy") == TK.ENERGY_COLOR)
print("ticker ok")
