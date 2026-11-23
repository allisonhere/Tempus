-- Gear Advisor scoring: which role a character is playing, and what swapping one item for another
-- is worth in that role. Pure logic (no game calls) so it is tested outside the client.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local S = {}
GA.Scoring = S

S.MAX_LEVEL = 60                 -- leveling weights below this, endgame weights from it

-- The roles a class can be scored as, for a settings dropdown: { { code, label }, ... }, led by
-- Automatic. nil for classes with no weights.
function S.RoleList(class)
    local set = GA.Weights and GA.Weights[class]
    if not (set and set._order) then return nil end
    local list = { { "AUTO", class == "DRUID" and "Automatic (from my form)" or "Automatic (assumed)" } }
    for _, code in ipairs(set._order) do list[#list + 1] = { code, set[code].label } end
    return list
end

-- Shapeshift form numbers that tell the druid's role, read from a Forever client at level 22: form 3
-- gave attack power 177 (cat: level*2 + 2*Str + Agi - 20) and form 1 gave 130 (bear: level*3 + 2*Str - 20).
local DRUID_FORM = { [3] = "CAT", [1] = "BEAR" }

-- The role to score with. `chosen` is the setting (AUTO or a role code), `form` the current shapeshift
-- form, `talents` the build the talents point to (nil when unknown), `last` the last role seen from a
-- form. Returns role, why it was picked ("chosen", "form", "talents", "last form" or "default": a guess
-- the screen must call an assumption).
function S.Role(class, chosen, form, last, talents)
    local set = GA.Weights and GA.Weights[class]
    if not (set and set._order) then return nil end
    if chosen and chosen ~= "AUTO" and set[chosen] then return chosen, "chosen" end
    if class == "DRUID" then
        local fromForm = DRUID_FORM[form]
        if fromForm then return fromForm, "form" end
    end
    if talents and set[talents] then return talents, "talents" end
    if class == "DRUID" then
        if last and set[last] then return last, "last form" end
        return "CAT", "default"
    end
    return set._order[1], "default"
end

-- The weights table for a class and role at this level, with where it comes from.
function S.Weights(class, role, level)
    local set = GA.Weights and GA.Weights[class] and GA.Weights[class][role]
    if not set then return nil end
    local w = (type(level) == "number" and level < S.MAX_LEVEL) and set.leveling or set.max
    return w, set.label, GA.Weights.source
end

-- What replacing `old` with `new` is worth. Both are stat tables ({ ITEM_MOD_* = amount }); a missing
-- one counts as no stats. Returns the total and the parts as { key, change, value }, biggest first.
-- Stats with no weight are listed in `unscored`.
function S.Delta(new, old, weights, isNumber)
    local parts, unscored, total = {}, {}, 0
    local seen = {}
    for _, t in ipairs({ new or {}, old or {} }) do
        for key in pairs(t) do seen[key] = true end
    end
    for key in pairs(seen) do
        local n = isNumber(new and new[key]) and new[key] or 0
        local o = isNumber(old and old[key]) and old[key] or 0
        local w = weights[key]
        if n ~= o then
            if w then
                local value = (n - o) * w
                total = total + value
                parts[#parts + 1] = { key = key, change = n - o, value = value }
            else
                unscored[#unscored + 1] = key
            end
        end
    end
    table.sort(parts, function(a, b)
        if math.abs(a.value) ~= math.abs(b.value) then return math.abs(a.value) > math.abs(b.value) end
        return a.key < b.key
    end)
    table.sort(unscored)
    return total, parts, unscored
end

-- The weights to use for one item: a ranged weapon's DPS counts at the ranged weight.
function S.ForItem(weights, ranged)
    if ranged and weights.DPS_RANGED then
        local copy = {}
        for k, v in pairs(weights) do copy[k] = v end
        copy.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = weights.DPS_RANGED
        return copy
    end
    return weights
end
