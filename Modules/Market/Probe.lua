-- /tempus gearprobe: lists which character, talent, stat and item calls this client really has, with
-- what they return, so Gear Advisor is built on what the game offers and not on guesses.
local _, T = ...
local M = T.Market

local function Show(v)
    if v == nil then return "nil" end
    if T.issecret and T.issecret(v) then return "<secret>" end
    local t = type(v)
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table(" .. n .. ")"
    end
    return tostring(v)
end

-- "name = type" when the call is missing, else the first few results of calling it.
local function Try(out, name, fn, ...)
    if type(fn) ~= "function" then out[#out + 1] = name .. ": missing" return end
    local r = { pcall(fn, ...) }
    if not r[1] then out[#out + 1] = name .. ": error " .. Show(r[2]) return end
    local parts = {}
    for i = 2, math.min(#r, 6) do parts[#parts + 1] = Show(r[i]) end
    out[#out + 1] = name .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "(no result)")
end

function M.GearProbe()
    local out = {}
    local _, class = UnitClass("player")
    out[#out + 1] = ("class %s, level %s, interface %s"):format(tostring(class), Show(UnitLevel("player")), select(4, GetBuildInfo()) and tostring(select(4, GetBuildInfo())) or "?")
    -- Specialisation (retail style).
    Try(out, "GetSpecialization", GetSpecialization)
    Try(out, "GetSpecializationInfo(1)", GetSpecializationInfo, 1)
    Try(out, "C_SpecializationInfo.GetSpecialization", C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    Try(out, "GetPrimaryTalentTree", GetPrimaryTalentTree)
    -- Talents (classic style).
    Try(out, "GetNumTalentTabs", GetNumTalentTabs)
    local tabs = GetNumTalentTabs and select(2, pcall(GetNumTalentTabs))
    if type(tabs) == "number" then
        for i = 1, math.min(tabs, 4) do Try(out, "GetTalentTabInfo(" .. i .. ")", GetTalentTabInfo, i) end
        Try(out, "GetNumTalents(1)", GetNumTalents, 1)
        Try(out, "GetTalentInfo(1, 1)", GetTalentInfo, 1, 1)
    end
    -- Trait system.
    Try(out, "C_ClassTalents.GetActiveConfigID", C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    Try(out, "C_Traits.GetConfigInfo", C_Traits and C_Traits.GetConfigInfo, 0)
    -- Spec and trait details, read with the real config id (the first probe used 0).
    local SI = C_SpecializationInfo
    if SI then
        Try(out, "SI.GetNumSpecializations", SI.GetNumSpecializations)
        Try(out, "SI.GetSpecializationInfo(1)", SI.GetSpecializationInfo, 1)
        Try(out, "SI.GetSpecializationInfo(2)", SI.GetSpecializationInfo, 2)
        Try(out, "SI.GetSpecializationInfo(3)", SI.GetSpecializationInfo, 3)
        Try(out, "SI.GetSpecializationRole(1)", SI.GetSpecializationRole, 1)
        Try(out, "SI.GetActiveSpecGroup", SI.GetActiveSpecGroup)
    end
    local okc, cfg = pcall(function() return C_ClassTalents and C_ClassTalents.GetActiveConfigID() end)
    if okc and cfg and C_Traits then
        local okI, info = pcall(C_Traits.GetConfigInfo, cfg)
        out[#out + 1] = "config " .. Show(cfg) .. " info: " .. (okI and Show(info) or "error")
        if okI and type(info) == "table" then
            out[#out + 1] = "  config name: " .. Show(info.name) .. ", type: " .. Show(info.type) .. ", trees: " .. Show(info.treeIDs)
            local tree = type(info.treeIDs) == "table" and info.treeIDs[1]
            if tree then
                local okN, nodes = pcall(C_Traits.GetTreeNodes, tree)
                out[#out + 1] = "  tree " .. Show(tree) .. " nodes: " .. (okN and Show(nodes) or "error")
                local bought, names = 0, {}
                if okN and type(nodes) == "table" then
                    for _, id in ipairs(nodes) do
                        local okNode, ni = pcall(C_Traits.GetNodeInfo, cfg, id)
                        if okNode and type(ni) == "table" and (ni.currentRank or 0) > 0 then
                            bought = bought + 1
                            local entry = ni.activeEntry and ni.activeEntry.entryID or (ni.entryIDs and ni.entryIDs[1])
                            local name = "node " .. id
                            local okE, ei = pcall(C_Traits.GetEntryInfo, cfg, entry or 0)
                            if okE and type(ei) == "table" and ei.definitionID then
                                local okD, di = pcall(C_Traits.GetDefinitionInfo, ei.definitionID)
                                if okD and type(di) == "table" and di.spellID then
                                    local sn = C_Spell and C_Spell.GetSpellName and select(2, pcall(C_Spell.GetSpellName, di.spellID))
                                    name = tostring(sn or di.spellID)
                                end
                            end
                            if #names < 30 then names[#names + 1] = name .. " x" .. tostring(ni.currentRank) end
                        end
                    end
                end
                out[#out + 1] = "  talents with points: " .. bought
                if #names > 0 then out[#out + 1] = "  " .. table.concat(names, ", ") end
            end
        end
    end
    -- Stats and ratings.
    for i = 1, 5 do Try(out, "UnitStat(" .. i .. ")", UnitStat, "player", i) end
    Try(out, "UnitAttackPower", UnitAttackPower, "player")
    Try(out, "GetCritChance", GetCritChance)
    Try(out, "GetSpellCritChance(2)", GetSpellCritChance, 2)
    Try(out, "GetHitModifier", GetHitModifier)
    Try(out, "GetSpellHitModifier", GetSpellHitModifier)
    Try(out, "GetCombatRating(6)", GetCombatRating, 6)
    Try(out, "GetCombatRatingBonus(6)", GetCombatRatingBonus, 6)
    Try(out, "GetDodgeChance", GetDodgeChance)
    Try(out, "GetBlockChance", GetBlockChance)
    Try(out, "GetParryChance", GetParryChance)
    Try(out, "GetManaRegen", GetManaRegen)
    Try(out, "GetSpellBonusDamage(2)", GetSpellBonusDamage, 2)
    Try(out, "GetSpellBonusHealing", GetSpellBonusHealing)
    Try(out, "GetShapeshiftForm", GetShapeshiftForm)
    -- Weapon skills and equipment.
    Try(out, "GetNumSkillLines", GetNumSkillLines)
    Try(out, "C_SpellBook.IsSpellKnown(Dual Wield 674)", C_SpellBook and C_SpellBook.IsSpellKnown, 674)
    Try(out, "IsSpellKnown(674)", IsSpellKnown, 674)
    Try(out, "IsDualWielding", IsDualWielding)
    Try(out, "GetInventoryItemLink(16)", GetInventoryItemLink, "player", 16)
    -- Item data.
    local link = GetInventoryItemLink and select(2, pcall(GetInventoryItemLink, "player", 16))
    if type(link) == "string" then
        Try(out, "C_Item.GetItemStats(link)", C_Item and C_Item.GetItemStats, link)
        Try(out, "GetItemStats(link)", GetItemStats, link)
        Try(out, "C_Item.GetItemInfoInstant", C_Item and C_Item.GetItemInfoInstant, link)
        Try(out, "C_Item.GetDetailedItemLevelInfo", C_Item and C_Item.GetDetailedItemLevelInfo, link)
        Try(out, "C_TooltipInfo.GetHyperlink", C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
        Try(out, "C_Item.GetItemSpecInfo", C_Item and C_Item.GetItemSpecInfo, link)
        if C_Item and C_Item.GetItemStats then
            local ok, stats = pcall(C_Item.GetItemStats, link)
            if ok and type(stats) == "table" then
                local keys = {}
                for k in pairs(stats) do keys[#keys + 1] = tostring(k) end
                table.sort(keys)
                out[#out + 1] = "  stat keys on main hand: " .. table.concat(keys, ", ")
            end
        end
    else
        out[#out + 1] = "no main hand item to read; equip a weapon and run again for the item calls"
    end
    return out
end

-- /tempus gearstats: every stat name the game uses on the gear you carry, with how often it shows up,
-- the range of values, one example item, and whether Gear Advisor gives it a weight. Run it on
-- characters that wear different kinds of gear to find stat names the scoring does not know.
function M.GearStats()
    local out = {}
    local getStats = C_Item and C_Item.GetItemStats
    if type(getStats) ~= "function" then return { "C_Item.GetItemStats is missing on this client" } end
    local links = {}
    for slot = 1, 19 do
        local ok, link = pcall(GetInventoryItemLink, "player", slot)
        if ok and type(link) == "string" then links[#links + 1] = link end
    end
    local C = C_Container
    local bags = (NUM_BAG_SLOTS or 4)
    for bag = 0, bags do
        local okN, n = pcall(C and C.GetContainerNumSlots or GetContainerNumSlots, bag)
        if okN and type(n) == "number" then
            for slot = 1, n do
                local ok, link = pcall(C and C.GetContainerItemLink or GetContainerItemLink, bag, slot)
                if ok and type(link) == "string" then links[#links + 1] = link end
            end
        end
    end
    local weighted = {}
    local W = T.GearAdvisor and T.GearAdvisor.Weights
    if W then
        for key, roles in pairs(W) do
            if type(roles) == "table" then
                for _, set in pairs(roles) do
                    for _, tbl in ipairs({ set.leveling or {}, set.max or {} }) do
                        for stat in pairs(tbl) do weighted[stat] = true end
                    end
                end
            end
        end
    end
    local seen, seenItems = {}, 0
    for _, link in ipairs(links) do
        local ok, stats = pcall(getStats, link)
        if ok and type(stats) == "table" then
            seenItems = seenItems + 1
            for key, amount in pairs(stats) do
                if not (T.issecret and T.issecret(key)) then
                    local e = seen[key] or { n = 0 }
                    seen[key] = e
                    e.n = e.n + 1
                    if type(amount) == "number" then
                        e.lo = math.min(e.lo or amount, amount)
                        e.hi = math.max(e.hi or amount, amount)
                    end
                    if not e.example then
                        local okI, name = pcall((C_Item and C_Item.GetItemInfo) or GetItemInfo or error, link)
                        e.example = okI and name or link
                    end
                end
            end
        end
    end
    local keys = {}
    for key in pairs(seen) do keys[#keys + 1] = key end
    table.sort(keys)
    out[#out + 1] = ("%d items read, %d stat names"):format(seenItems, #keys)
    for _, key in ipairs(keys) do
        local e = seen[key]
        local range = e.lo and (e.lo == e.hi and tostring(e.lo) or (e.lo .. " to " .. e.hi)) or "?"
        out[#out + 1] = ("%s%s: %d items, %s, e.g. %s"):format(weighted[key] and "" or "NO WEIGHT  ", tostring(key), e.n, range, tostring(e.example))
    end
    return out
end

-- /tempus gearsig: the talents this character has points in, on one line, to paste back so Gear
-- Advisor can learn which talents mark which build. Talents unlock at level 10.
function M.GearSig()
    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    local TL = T.GearAdvisor and T.GearAdvisor.Talents
    if not TL then return { "the talent reader is not loaded" } end
    local _, total, display = TL.Read()
    if not display then return { ("%s %s: the client gave no talent data"):format(tostring(class), tostring(level)) } end
    local names = {}
    for name in pairs(display) do names[#names + 1] = name end
    table.sort(names)
    local parts = {}
    for _, name in ipairs(names) do parts[#parts + 1] = ("%s x%d"):format(name, display[name]) end
    return { ("%s %s, %d points: %s"):format(tostring(class), tostring(level), total or 0, #parts > 0 and table.concat(parts, ", ") or "none yet (talents unlock at level 10)") }
end

-- /tempus geartree: every talent in the class tree with its position and your points, four to a line,
-- so the tree can be split into its three tabs by position and a build read from where the points are.
function M.GearTree()
    local CT, CTr = C_ClassTalents, C_Traits
    if not (CT and CT.GetActiveConfigID and CTr and CTr.GetConfigInfo and CTr.GetTreeNodes and CTr.GetNodeInfo) then
        return { "the trait calls are missing on this client" }
    end
    local ok, cfg = pcall(CT.GetActiveConfigID)
    local tree
    if ok and cfg then
        local okI, info = pcall(CTr.GetConfigInfo, cfg)
        tree = okI and type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
    end
    if not tree then return { "no talent tree for this character" } end
    local okN, nodes = pcall(CTr.GetTreeNodes, tree)
    if not (okN and type(nodes) == "table") then return { "no talent nodes" } end
    local _, class = UnitClass("player")
    local entries = {}
    for _, id in ipairs(nodes) do
        local okNode, ni = pcall(CTr.GetNodeInfo, cfg, id)
        if okNode and type(ni) == "table" then
            local entry = ni.activeEntry and ni.activeEntry.entryID or (ni.entryIDs and ni.entryIDs[1])
            local name = "node" .. tostring(id)
            local okE, ei = pcall(CTr.GetEntryInfo, cfg, entry or 0)
            if okE and type(ei) == "table" and ei.definitionID then
                local okD, di = pcall(CTr.GetDefinitionInfo, ei.definitionID)
                if okD and type(di) == "table" and di.spellID and C_Spell and C_Spell.GetSpellName then
                    local okS, n = pcall(C_Spell.GetSpellName, di.spellID)
                    if okS and type(n) == "string" then name = n end
                end
            end
            entries[#entries + 1] = ("%s %d/%s @%s,%s"):format(name, tonumber(ni.currentRank) or 0, tostring(ni.maxRanks or "?"),
                tostring(ni.posX or "?"), tostring(ni.posY or "?"))
        end
    end
    local out = { ("%s tree %s, %d talents (name rank/max @x,y):"):format(tostring(class), tostring(tree), #entries) }
    for i = 1, #entries, 4 do
        out[#out + 1] = table.concat(entries, "; ", i, math.min(i + 3, #entries))
    end
    return out
end

-- A single text with everything gathered for improving Gear Advisor: the build (typed by the player), the
-- talent points, the talent tree and the stat names on carried gear.
function M.Report()
    local lines = { "Tempus gear data", "Build: (type your build here, for example Destruction)" }
    for _, part in ipairs({ M.GearSig, M.GearTree, M.GearStats }) do
        for _, line in ipairs(part()) do lines[#lines + 1] = (tostring(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    end
    return table.concat(lines, "\n")
end

-- Text cut into chat-sized lines: blank lines dropped, "|" turned into "/" (it starts game escape codes),
-- and lines over `max` characters split. For whispering the report.
function M.SplitForChat(text, max)
    max = max or 240
    local out = {}
    for raw in tostring(text or ""):gmatch("[^\n]+") do
        local line = raw:gsub("|", "/"):gsub("^%s+", ""):gsub("%s+$", "")
        while #line > max do
            local cut = line:sub(1, max):match("^.*()%s") or max
            out[#out + 1] = line:sub(1, cut)
            line = line:sub(cut + 1):gsub("^%s+", "")
        end
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

-- Who receives the gear data report: one character per faction, since mail and whispers do not cross
-- factions. The player can still type another name.
M.REPORT_TO = { Horde = "Dailyreports", Alliance = "Dailyreporter" }

function M.DefaultReportTo()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return M.REPORT_TO[faction] or ""
end
