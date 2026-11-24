-- Info bar: movement speed as a percent over the base run speed.
local T = { Style = {}, NewModule = function() end, Num = function(v) return type(v) == "number" end, accentHex = "ffffff" }
assert(loadfile("Modules/Minimap/DataBar.lua"))("Tempus", T)
local DB = T.DataBar
assert(DB.texts.speed and DB.texts.speed.label == "Movement speed", "listed as an info bar choice")
-- run speed 7 is the base, 11.2 is a 60% mount, 14 is 100%
assert(DB.SpeedBonus({ 0, 7, 7, 4.7222 }, false, false) == 0, "base speed is +0%")
assert(DB.SpeedBonus({ 0, 11.2, 7, 4.7 }, false, false) == 60, "a 60% mount")
assert(DB.SpeedBonus({ 14, 14, 14, 4.7 }, false, false) == 100)
assert(DB.SpeedBonus({ 0, 7, 11.2, 4.7 }, true, false) == 60, "flying uses the flight speed")
assert(DB.SpeedBonus({ 0, 7, 7, 9.45 }, false, true) == 35, "swimming uses the swim speed")
assert(DB.SpeedBonus({ 0, 5.95, 7, 4.7 }, false, false) == -15, "a slow shows a minus")
assert(DB.SpeedBonus({}, false, false) == nil and DB.SpeedBonus({ 0, 0 }, false, false) == nil, "no speed, no number")
GetUnitSpeed = function() return 0, 11.2, 7, 4.7 end
IsFlying, IsSwimming = function() return false end, function() return false end
assert(DB.texts.speed.text():find("%+60%%"), DB.texts.speed.text())
GetUnitSpeed = function() return 0, 7, 7, 4.7 end
assert(DB.texts.speed.text():find("%+0%%"))
GetUnitSpeed = nil
assert(DB.texts.speed.text() == "--")
print("PASS: info bar movement speed")
assert(DB.SpeedReadout(7, "KMH") == " 23.0 km/h")
assert(DB.SpeedReadout(7, "MPH") == " 14.3 mph")
assert(DB.SpeedReadout(0, "KMH") == " 0.0 km/h", "standing still shows zero actual speed")
assert(DB.SpeedReadout(7, "PERCENT") == "")
assert(DB.SpeedReadout(nil, "KMH") == " --")
GetUnitSpeed = function() return 11.2, 11.2, 7, 4.7 end
DB.db = { speedUnit = "MPH" }
assert(DB.texts.speed.text():find("22.9 mph", 1, true))
assert(DB.texts.speed.text():find("%+60%%"), "unit readout retains the speed bonus")

assert(not DB.texts.speed.text():find("Speed", 1, true), "compact readout omits the speed label")
