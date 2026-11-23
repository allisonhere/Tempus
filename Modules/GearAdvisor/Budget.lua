-- Gear Advisor: the best set of purchases for an amount of gold. A bounded beam search over slot
-- groups, deterministic, pure (no game calls). It never buys anything; it only proposes.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local B = {}
GA.Budget = B

B.PER_GROUP = 8          -- candidates considered per slot group (best score first)
B.BEAM = 300             -- partial plans kept after each group
B.CAPACITY = { finger = 2, trinket = 2 }   -- everything else takes one item
-- A two-hander cannot go with a second weapon, a shield or a held item, and the reverse.
B.TWO_HAND = "twohand"
B.HANDS = { weapon = true, mainhand = true, offhand = true, shield = true, held = true }

local function Num(v) return type(v) == "number" and v == v end

local function Better(a, b)
    if a.worth ~= b.worth then return a.worth > b.worth end
    if a.cost ~= b.cost then return a.cost < b.cost end
    return a.key < b.key
end

-- cands: { { id, group, price (copper), worth } ... }; groups: the group keys in the order to decide
-- them. Entries with no positive worth or a bad price are ignored. Returns { picks, cost, worth }
-- where picks lists the chosen candidates in group order.
function B.Plan(cands, budget, groups)
    if not Num(budget) or budget <= 0 then return { picks = {}, cost = 0, worth = 0 } end
    local by = {}
    for _, c in ipairs(cands) do
        if c.group and Num(c.price) and c.price >= 0 and Num(c.worth) and c.worth > 0 and c.price <= budget then
            by[c.group] = by[c.group] or {}
            table.insert(by[c.group], c)
        end
    end
    for _, list in pairs(by) do
        table.sort(list, function(a, b)
            if a.worth ~= b.worth then return a.worth > b.worth end
            if a.price ~= b.price then return a.price < b.price end
            return a.id < b.id
        end)
        while #list > B.PER_GROUP do table.remove(list) end
    end
    local states = { { picks = {}, cost = 0, worth = 0, key = "", twoHand = false, hands = false, ids = {} } }
    for _, group in ipairs(groups) do
        local list = by[group]
        if list then
            local cap = B.CAPACITY[group] or 1
            local nextStates = {}
            local seen = {}
            local function push(st)
                if not seen[st.key] then
                    seen[st.key] = true
                    nextStates[#nextStates + 1] = st
                end
            end
            for _, st in ipairs(states) do
                push(st)                                          -- buy nothing in this group
                local function extend(from, start, count)
                    for i = start, #list do
                        local c = list[i]
                        local cost = from.cost + c.price
                        local blocked = (group == B.TWO_HAND and from.hands) or (B.HANDS[group] and from.twoHand)
                        if cost <= budget and not blocked and not from.ids[c.id] then
                            local ids = setmetatable({ [c.id] = true }, { __index = from.ids })
                            local picks = {}
                            for k, v in ipairs(from.picks) do picks[k] = v end
                            picks[#picks + 1] = c
                            local st = { picks = picks, cost = cost, worth = from.worth + c.worth,
                                key = from.key .. "|" .. tostring(c.id), ids = ids,
                                twoHand = from.twoHand or group == B.TWO_HAND,
                                hands = from.hands or B.HANDS[group] == true }
                            push(st)
                            if count + 1 < cap then extend(st, i + 1, count + 1) end
                        end
                    end
                end
                extend(st, 1, 0)
            end
            table.sort(nextStates, Better)
            while #nextStates > B.BEAM do table.remove(nextStates) end
            states = nextStates
        end
    end
    table.sort(states, Better)
    local best = states[1]
    return { picks = best.picks, cost = best.cost, worth = best.worth }
end
