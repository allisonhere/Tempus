-- Gear Advisor: carried gear that already beats a listing.
local T = {}
assert(loadfile("Modules/GearAdvisor/Owned.lua"))("Tempus", T)
local O = T.GearAdvisor.Owned
local best = O.Best({ { group = "head", level = 30, link = "a" }, { group = "head", level = 42, link = "b" },
    { group = "head", level = 42, link = "c" }, { group = "back", level = 20, link = "d" },
    { group = nil, level = 99, link = "x" }, { group = "feet", level = "?", link = "y" } })
assert(best.head.link == "b", "highest level wins, first on a tie")
assert(best.back.level == 20 and best.feet == nil and next({}) == nil, "ungrouped and unreadable items are ignored")
assert(O.Beats(best, "head", 42) == true, "an equal carried item beats the listing")
assert(O.Beats(best, "head", 43) == false, "a better listing is still offered")
assert(O.Beats(best, "legs", 10) == false, "nothing carried for that slot")
assert(O.Beats(best, "head", nil) == false, "unknown level: do not hide")

-- Scores decide when both sides have one: better stats beat a higher item level.
local scored = O.Best({ { group = "head", level = 40, link = "a", score = 9 }, { group = "head", level = 50, link = "b", score = 4 } })
assert(scored.head.link == "a", "the better score wins over the higher item level")
assert(O.Beats(scored, "head", 60, 8) == true, "a carried score of 9 beats a listing scoring 8 even at a higher item level")
assert(O.Beats(scored, "head", 30, 12) == false, "a listing that scores higher is still offered")
assert(O.Beats(scored, "head", 30, nil) == true, "no listing score: item level decides")
print("PASS: carried gear beats listings of equal or lower level, and by score when both have one")
