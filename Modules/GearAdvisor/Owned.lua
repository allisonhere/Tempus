-- Gear Advisor: gear already in your bags that you could put on. Buying something no better than
-- what you carry is a waste, so those listings are left out. Pure logic; the caller reads the bags.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local O = {}
GA.Owned = O

-- The best carried item per slot group. `items` is { { group, level, link, score }, ... }; items
-- without a group or a numeric level are ignored. The score (what the item is worth against what you
-- wear, in your role) decides when both items have one, else item level does. Ties keep the first.
function O.Best(items)
    local best = {}
    for _, it in ipairs(items) do
        if it.group and type(it.level) == "number" then
            local cur = best[it.group]
            local better
            if cur and type(it.score) == "number" and type(cur.score) == "number" then
                better = it.score > cur.score
            else
                better = not cur or it.level > cur.level
            end
            if better then best[it.group] = it end
        end
    end
    return best
end

-- True when a carried item of the group is at least as good as the listing. When both have a score
-- the scores decide (a higher item level with worse stats for your role is not better); otherwise
-- item level does.
function O.Beats(best, group, level, listingScore)
    local cur = best[group]
    if not cur then return false end
    if type(cur.score) == "number" and type(listingScore) == "number" then return cur.score >= listingScore end
    return type(level) == "number" and cur.level >= level
end
