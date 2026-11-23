-- Gear Advisor verdict tags.
local T = {}
assert(loadfile("Modules/GearAdvisor/Verdicts.lua"))("Tempus", T)
local V = T.GearAdvisor.Verdicts
local G = 10000
local function tags(e) return e.tags and table.concat(e.tags, "|") or "" end

local big = { price = 100 * G, worth = 50, rank = 5 }      -- the biggest gain, dear
local value = { price = 4 * G, worth = 20, rank = 10 }     -- the best deal
local small = { price = 1 * G, worth = 6, rank = 6 }       -- cheap, still a real gain
local tiny = { price = 0.5 * G, worth = 1, rank = 1.4 }    -- too small to call worthwhile
local none = { price = 1 * G, rank = 3 }                   -- no score
V.Tag({ big, value, small, tiny, none }, 10 * G)
assert(tags(big) == "Biggest upgrade", tags(big))
assert(tags(value):find("Best value") and tags(value):find("Best you can afford"), "the best deal you can pay for: " .. tags(value))
assert(tags(small) == "Small upgrade", tags(small))
assert(tags(tiny) == "" and tags(none) == "", "a tiny gain or an unscored item gets no tag")

-- With plenty of gold the biggest upgrade is also affordable: no separate affordability tag.
V.Tag({ big, value }, 1000 * G)
assert(tags(big) == "Biggest upgrade" and not tags(value):find("afford"), tags(value))

-- Tags are reset on every call, and an empty list is fine.
V.Tag({ big, value }, nil)
assert(tags(big) == "Biggest upgrade" and tags(value) == "Best value", tags(value))
V.Tag({}, 5)
print("PASS: verdict tags (biggest, best value, best you can afford, small upgrade)")
