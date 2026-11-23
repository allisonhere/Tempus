-- Gear Advisor budget plan.
local T = {}
assert(loadfile("Modules/GearAdvisor/Budget.lua"))("Tempus", T)
local B = T.GearAdvisor.Budget
local G = 10000
local groups = { "head", "chest", "finger", "trinket", "weapon", "twohand", "shield", "offhand" }
local function ids(plan) local t = {} for _, p in ipairs(plan.picks) do t[#t + 1] = p.id end table.sort(t) return table.concat(t, ",") end

-- Beats greedy: the single best item (id 1, 10 worth for 10g) would block two cheaper ones that add
-- up to more (id 2 and 3, 7 + 7 for 5g each).
local plan = B.Plan({
    { id = 1, group = "head", price = 10 * G, worth = 10 },
    { id = 2, group = "head", price = 5 * G, worth = 7 },
    { id = 3, group = "chest", price = 5 * G, worth = 7 },
}, 10 * G, groups)
assert(ids(plan) == "2,3" and plan.worth == 14 and plan.cost == 10 * G, ids(plan))

-- The budget is respected, and nothing affordable means an empty plan.
local p2 = B.Plan({ { id = 1, group = "head", price = 11 * G, worth = 5 } }, 10 * G, groups)
assert(#p2.picks == 0 and p2.cost == 0)
assert(#B.Plan({ { id = 1, group = "head", price = 1, worth = 5 } }, 0, groups).picks == 0, "no gold, no plan")

-- A two-hander excludes a shield and a one-hander; the plan takes whichever side is worth more.
local hands = {
    { id = 10, group = "twohand", price = 5 * G, worth = 20 },
    { id = 11, group = "weapon", price = 3 * G, worth = 6 },
    { id = 12, group = "shield", price = 3 * G, worth = 6 },
}
assert(ids(B.Plan(hands, 20 * G, groups)) == "10", "a two-hander beats a weapon plus shield here (20 against 12)")
hands[1].worth = 9
assert(ids(B.Plan(hands, 20 * G, groups)) == "11,12", "a weapon plus shield beats a weaker two-hander (12 against 9)")

-- Rings and trinkets can take two; the same item twice is not offered, and a third is dropped.
local rings = {
    { id = 20, group = "finger", price = 2 * G, worth = 5 },
    { id = 21, group = "finger", price = 2 * G, worth = 4 },
    { id = 22, group = "finger", price = 2 * G, worth = 3 },
}
assert(ids(B.Plan(rings, 100 * G, groups)) == "20,21", "two ring slots")
assert(ids(B.Plan({ rings[1] }, 100 * G, groups)) == "20", "one listing fills one slot")

-- Entries with no score, no group or a bad price are ignored. Results are deterministic.
local junk = { { id = 30, group = "head", price = G }, { id = 31, price = G, worth = 3 },
    { id = 32, group = "head", price = -5, worth = 3 }, { id = 33, group = "head", price = G, worth = 0 } }
assert(#B.Plan(junk, 100 * G, groups).picks == 0)
local many = {}
for i = 1, 40 do many[#many + 1] = { id = i, group = groups[(i % 5) + 1], price = (i % 7 + 1) * G, worth = (i * 37) % 11 + 1 } end
local a, b = B.Plan(many, 25 * G, groups), B.Plan(many, 25 * G, groups)
assert(ids(a) == ids(b) and a.worth == b.worth and a.cost <= 25 * G, "same input, same plan, within budget")
print("PASS: budget plan (beats greedy, respects the budget, hand conflicts, ring pairs, deterministic)")
