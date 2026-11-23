-- Gear Advisor: reading the talents you have points in, and telling which build they point to. The
-- detection is pure (Detect) and driven by data (T.GearAdvisor.TalentSignals), which is empty until a
-- class has been probed on a real character: no guessed talent names. Talents unlock at level 10, so
-- below that there is no signal and the build comes from the form, your choice, or a labelled guess.
local _, T = ...
local GA = T.GearAdvisor or {}
T.GearAdvisor = GA
local TL = {}
GA.Talents = TL

TL.MIN_LEVEL = 10        -- talents unlock here (as reported; not read from the client)
TL.MIN_POINTS = 5        -- fewer matching points than this is not a signal
TL.LEAD = 1.5            -- the top build needs this many times the runner-up's points

-- Per class: { ROLE = { { "Talent name", weight }, ... } }. Filled in only from probed characters
-- (/tempus gearsig). A talent counts rank * weight toward the build it is listed under.
GA.TalentSignals = GA.TalentSignals or {}

-- The talents with points, as { [lowercase name] = rank }, the total points, and the same list with
-- the names as the game writes them. nil when the client gives no talent data.
function TL.Read()
    local CT, CTr = C_ClassTalents, C_Traits
    if not (CT and CT.GetActiveConfigID and CTr and CTr.GetConfigInfo and CTr.GetTreeNodes and CTr.GetNodeInfo) then return nil end
    local ok, cfg = pcall(CT.GetActiveConfigID)
    if not (ok and cfg) then return nil end
    local okI, info = pcall(CTr.GetConfigInfo, cfg)
    local tree = okI and type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
    if not tree then return nil end
    local okN, nodes = pcall(CTr.GetTreeNodes, tree)
    if not (okN and type(nodes) == "table") then return nil end
    local ranks, total, display, positions = {}, 0, {}, {}
    for _, id in ipairs(nodes) do
        local okNode, ni = pcall(CTr.GetNodeInfo, cfg, id)
        local rank = okNode and type(ni) == "table" and ni.currentRank
        if type(rank) == "number" and rank > 0 then
            local entry = ni.activeEntry and ni.activeEntry.entryID or (ni.entryIDs and ni.entryIDs[1])
            local spell
            local okE, ei = pcall(CTr.GetEntryInfo, cfg, entry or 0)
            if okE and type(ei) == "table" and ei.definitionID then
                local okD, di = pcall(CTr.GetDefinitionInfo, ei.definitionID)
                if okD and type(di) == "table" then spell = di.spellID end
            end
            local name
            if spell and C_Spell and C_Spell.GetSpellName then
                local okS, n = pcall(C_Spell.GetSpellName, spell)
                if okS then name = n end
            end
            if type(ni.posX) == "number" then positions[#positions + 1] = { rank = rank, x = ni.posX } end
            if type(name) == "string" then
                ranks[name:lower()] = rank
                display[name] = rank
                total = total + rank
            end
        end
    end
    return ranks, total, display, positions
end

-- Which build the talents point to: the role code, or nil when there is no clear signal. `signals` is
-- one class's table from TalentSignals. Below the unlock level, or with too few matching points, or
-- with no clear leader, the answer is nil, never a guess.
function TL.Detect(level, ranks, signals)
    if type(level) ~= "number" or level < TL.MIN_LEVEL then return nil end
    if type(ranks) ~= "table" or type(signals) ~= "table" then return nil end
    local scores = {}
    for role, list in pairs(signals) do
        local sum = 0
        for _, sig in ipairs(list) do
            local rank = ranks[tostring(sig[1]):lower()]
            if rank then sum = sum + rank * (sig[2] or 1) end
        end
        scores[#scores + 1] = { role = role, score = sum }
    end
    table.sort(scores, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.role < b.role
    end)
    local top, second = scores[1], scores[2]
    if not top or top.score < TL.MIN_POINTS then return nil end
    if second and second.score > 0 and top.score < second.score * TL.LEAD then return nil end
    return top.role
end

-- Which build the points in each tab point to. `positions` is { { rank, x } ... } for the talents with points;
-- `tabs` is { { role, maxX } ... } left to right. Same rules as Detect: level gate, enough points, a clear lead.
function TL.DetectByTab(level, positions, tabs)
    if type(level) ~= "number" or level < TL.MIN_LEVEL then return nil end
    if type(positions) ~= "table" or type(tabs) ~= "table" or #tabs == 0 then return nil end
    local scores = {}
    for i, tab in ipairs(tabs) do scores[i] = { role = tab[1], score = 0 } end
    for _, node in ipairs(positions) do
        for i, tab in ipairs(tabs) do
            if node.x <= tab[2] then scores[i].score = scores[i].score + node.rank break end
        end
    end
    table.sort(scores, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.role < b.role
    end)
    local top, second = scores[1], scores[2]
    if not top or top.score < TL.MIN_POINTS then return nil end
    if second and second.score > 0 and top.score < second.score * TL.LEAD then return nil end
    return top.role
end

-- The build the character's own talents point to, or nil (no data for the class, too low, unclear).
function TL.ForPlayer(class, level)
    local signals = GA.TalentSignals[class]
    local tabs = GA.TalentTabs and GA.TalentTabs[class]
    local hasSignals = signals and next(signals) ~= nil
    if not hasSignals and not tabs then return nil end
    local ranks, _, _, positions = TL.Read()
    if not ranks then return nil end
    return (hasSignals and TL.Detect(level, ranks, signals)) or (tabs and TL.DetectByTab(level, positions, tabs)) or nil
end
