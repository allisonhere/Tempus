-- Danger alert: which mobs count as dangerous, and when a pull warning goes out.
-- Run: lua5.1 tests/danger.lua
local T = { Style = {}, issecret = function() return false end }
function T.Num(v) return type(v) == "number" and v == v end
function T:NewModule(key, def) self.module = def end
assert(loadfile("Modules/Danger/Danger.lua"))("Tempus", T)
local DG = T.Danger
local db = DG.defaults
local function R(info) return (DG.Reason(info, 20, db)) end

assert(R({ hostile = true, level = 21, classification = "normal" }) == nil, "a normal mob near your level")
assert(R({ hostile = true, level = 23, classification = "normal" }) == "+3 levels")
assert(R({ hostile = true, level = 19, classification = "elite" }) == "Elite")
assert(R({ hostile = true, level = 19, classification = "rareelite" }) == "Rare elite")
assert(R({ hostile = true, level = 19, classification = "rare" }) == "Rare")
assert(R({ hostile = true, level = -1, classification = "elite" }) == "Skull", "?? level beats elite")
assert(R({ hostile = true, level = 30, classification = "normal", dead = true }) == nil, "dead")
assert(R({ hostile = false, level = 30, classification = "elite" }) == nil, "friendly")
assert(R({ hostile = true, level = 10, classification = "normal", trivial = true }) == nil, "grey mob")
assert(R({ hostile = true, isPlayer = true, level = 20 }) == "Hostile player")
assert(DG.Reason({ hostile = true, level = 25, classification = "normal" }, 20, { levelGap = 0 }) == nil, "level warning off")
assert(DG.Reason({ hostile = true, level = 19, classification = "elite" }, 20, { elites = false }) == nil, "elite warning off")

assert(DG.PullWarn(3, 0, 3), "three on you")
assert(not DG.PullWarn(2, 0, 3), "two is fine")
assert(not DG.PullWarn(3, 3, 3), "already warned for three")
assert(DG.PullWarn(4, 3, 3), "a fourth joins")

-- Flying: on a taxi or a flying mount, no warnings.
assert(not DG.Flying(), "no flight APIs: not flying")
UnitOnTaxi = function() return true end
assert(DG.Flying(), "flight path")
UnitOnTaxi = function() return false end
IsFlying = function() return true end
assert(DG.Flying(), "flying mount")
IsFlying, UnitOnTaxi = nil, nil
print("danger ok")
