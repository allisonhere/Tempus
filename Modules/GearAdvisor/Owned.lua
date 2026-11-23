-- Gear Advisor: gear already in your bags that you could put on. Buying something no better than
-- what you carry is a waste, so those listings are left out. Pure logic; the caller reads the bags.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local O = {}
GA.Owned = O

-- The best carried item per slot group. `items` is { { group, level, link }, ... }; items without a
-- group or a numeric level are ignored. Ties keep the first one listed.
function O.Best(items)
    local best = {}
    for _, it in ipairs(items) do
        if it.group and type(it.level) == "number" then
            local cur = best[it.group]
            if not cur or it.level > cur.level then best[it.group] = it end
        end
    end
    return best
end

-- True when a carried item of the group is at least as good as a listing of `level`.
function O.Beats(best, group, level)
    local cur = best[group]
    return cur ~= nil and type(level) == "number" and cur.level >= level
end
