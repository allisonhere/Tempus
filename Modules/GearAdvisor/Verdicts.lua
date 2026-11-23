-- Gear Advisor: short verdict tags for the listed upgrades. Pure logic over entries shaped
-- { price, worth, rank }, so the rules are tested outside the client.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local V = {}
GA.Verdicts = V

V.SMALL_SHARE = 0.1     -- a "small upgrade" is worth at least this share of the biggest one

local function Num(v) return type(v) == "number" and v == v end

-- Marks entries with `tags` (a list of labels), at most one entry per tag:
--   Biggest upgrade  highest worth
--   Best value       highest rank (worth against price)
--   Best you can afford  highest worth among those within `money` (copper), when it differs from the biggest
--   Small upgrade    cheapest listing that is still a real gain (worth >= SMALL_SHARE of the biggest)
-- Entries without a numeric worth get no tags.
function V.Tag(list, money)
    for _, e in ipairs(list) do e.tags = nil end
    local function add(e, label)
        if e then
            e.tags = e.tags or {}
            e.tags[#e.tags + 1] = label
        end
    end
    local function pick(better, filter)
        local best
        for _, e in ipairs(list) do
            if Num(e.worth) and e.worth > 0 and (not filter or filter(e)) and (not best or better(e, best)) then best = e end
        end
        return best
    end
    local biggest = pick(function(a, b) return a.worth > b.worth end)
    local value = pick(function(a, b) return (a.rank or 0) > (b.rank or 0) end)
    add(biggest, "Biggest upgrade")
    add(value, "Best value")
    if biggest and Num(money) then
        local afford = pick(function(a, b) return a.worth > b.worth end, function(e) return Num(e.price) and e.price <= money end)
        if afford and afford ~= biggest then add(afford, "Best you can afford") end
    end
    if biggest then
        local small = pick(function(a, b) return a.price < b.price end,
            function(e) return Num(e.price) and e.worth >= biggest.worth * V.SMALL_SHARE end)
        if small and small ~= biggest and small ~= value then add(small, "Small upgrade") end
    end
end
