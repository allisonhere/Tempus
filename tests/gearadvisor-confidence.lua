-- Gear Advisor confidence.
local T = {}
assert(loadfile("Modules/GearAdvisor/Confidence.lua"))("Tempus", T)
local C = T.GearAdvisor.Confidence
local function reasons(a) local _, r = C.Of(a) return table.concat(r, "; ") end

assert(C.Of({ hasStats = true, roleWhy = "form", unscored = 0, age = 1, staleDays = 3 }) == "Medium", "scored and known build: at best Medium")
assert(C.Of({ hasStats = true, roleWhy = "chosen", unscored = 0 }) == "Medium")
assert(C.Of({ hasStats = true, roleWhy = "default", unscored = 0 }) == "Low" and reasons({ hasStats = true, roleWhy = "default" }):find("assumed"), "an assumed build is Low")
assert(C.Of({ hasStats = true, roleWhy = "form", unscored = 2 }) == "Low" and reasons({ hasStats = true, roleWhy = "form", unscored = 2 }):find("2 stats not scored"), "unscored stats lower it")
assert(reasons({ hasStats = true, roleWhy = "form", unscored = 1 }):find("1 stat not scored"))
assert(C.Of({ hasStats = true, roleWhy = "form", unscored = 0, age = 9, staleDays = 3 }) == "Low" and reasons({ hasStats = true, roleWhy = "form", age = 9, staleDays = 3 }):find("9 days old"), "a stale price lowers it")
assert(C.Of({ hasStats = false }) == "Item level only", "no stats: item level only")
assert(C.Of({ hasStats = true, legacy = true }) == "Item level only", "legacy ranking is never called a stat score")
assert(reasons({ hasStats = true, roleWhy = "form" }):find("estimates"), "always says the weights are estimates")
print("PASS: confidence is at best Medium, lowered by an assumed build, unscored stats and stale prices")
