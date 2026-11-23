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

-- A number without a long tail: whole numbers as they are, others to one decimal.
local function Tidy(v)
    if type(v) ~= "number" then return tostring(v) end
    if v == math.floor(v) then return ("%d"):format(v) end
    return ("%.1f"):format(v)
end
M.Tidy = Tidy

-- One equipped or carried item as a line: its name, level, type and every stat the game lists for it.
local function ItemLine(prefix, link)
    local getStats = C_Item and C_Item.GetItemStats
    local name = link
    local okI, nm = pcall((C_Item and C_Item.GetItemInfo) or GetItemInfo or error, link)
    if okI and type(nm) == "string" then name = nm end
    local info = { pcall((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant or error, link) }
    local loc = info[1] and info[5] or "?"
    local ilvl = select(2, pcall((C_Item and C_Item.GetDetailedItemLevelInfo) or error, link))
    local bits = {}
    if type(getStats) == "function" then
        local ok, stats = pcall(getStats, link)
        if ok and type(stats) == "table" then
            local keys = {}
            for k in pairs(stats) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            for _, k in ipairs(keys) do bits[#bits + 1] = (k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "")) .. "=" .. Tidy(stats[k]) end
        end
    end
    return ("%s %s (%s) %s: %s"):format(prefix, tostring(name), type(ilvl) == "number" and tostring(ilvl) or "?", tostring(loc), #bits > 0 and table.concat(bits, " ") or "no stats")
end

-- Everything gathered for improving Gear Advisor, as one text: the build (typed by the player), what the
-- client offers (specs, talents, stats, ratings), the talent points and tree, every equipped and carried
-- item with its stats, the stat names seen, and Gear Advisor's own state. No character name, account or realm.
function M.Report()
    local lines = { "Tempus gear data", "Build: (type your build here, for example Destruction)" }
    local function strip(line) return (tostring(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    local function add(list) for _, line in ipairs(list) do lines[#lines + 1] = strip(line) end end
    local okV, version = pcall((C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata or error, "Tempus", "Version")
    local _, class = UnitClass("player")
    local race = select(2, UnitRace("player"))
    local db = T.db and T.db.market or {}
    lines[#lines + 1] = ("Tempus %s | %s %s | level %s | %s | form %s"):format(okV and tostring(version) or "?", tostring(race), tostring(class),
        tostring(UnitLevel("player")), tostring(UnitFactionGroup and UnitFactionGroup("player")), tostring(GetShapeshiftForm and GetShapeshiftForm() or "?"))
    local w, label, why = M.RoleWeights and M.RoleWeights(class)
    lines[#lines + 1] = ("Gear Advisor: setting %s, scored as %s (%s), sort %s"):format(tostring(db.gearRole), tostring(label or "none"), tostring(why or "-"), tostring(db.upgradeSort))
    lines[#lines + 1] = "-- client calls and character stats"
    add(M.GearProbe())
    lines[#lines + 1] = "-- talent points"
    add(M.GearSig())
    lines[#lines + 1] = "-- equipped gear"
    for slot = 1, 19 do
        local ok, link = pcall(GetInventoryItemLink, "player", slot)
        if ok and type(link) == "string" then lines[#lines + 1] = strip(ItemLine("slot" .. slot, link)) end
    end
    lines[#lines + 1] = "-- carried gear"
    local C = C_Container
    local shown = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local okN, n = pcall(C and C.GetContainerNumSlots or GetContainerNumSlots, bag)
        if okN and type(n) == "number" then
            for slot = 1, n do
                local ok, link = pcall(C and C.GetContainerItemLink or GetContainerItemLink, bag, slot)
                if ok and type(link) == "string" and shown < 40 then
                    local ci = { pcall((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant or error, link) }
                    if ci[1] and (ci[7] == 2 or ci[7] == 4) then
                        shown = shown + 1
                        lines[#lines + 1] = strip(ItemLine("bag", link))
                    end
                end
            end
        end
    end
    lines[#lines + 1] = "-- stat names seen"
    add(M.GearStats())
    lines[#lines + 1] = "-- talent tree"
    add(M.GearTree())
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
M.REPORT_TO = { Horde = "Daily Reports", Alliance = "Daily Reporter" }

function M.DefaultReportTo()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return M.REPORT_TO[faction] or ""
end

-- Names an earlier build used as the default recipient (before character names were known to have two words).
-- A saved copy of one of them is replaced by the current default instead of being kept.
local OLD_REPORT_TO = { dailyreports = true, dailyreporter = true }
function M.FixReportTo(name)
    if type(name) == "string" and OLD_REPORT_TO[name:lower()] then return M.DefaultReportTo() end
    return name
end

-- The build line typed into the report (what follows "Build:"), or "" when it was left as the placeholder.
function M.BuildFrom(text)
    local build = tostring(text or ""):match("[Bb]uild:%s*([^\n]*)") or ""
    build = build:gsub("^%s+", ""):gsub("%s+$", "")
    if build:find("^%(type your build") then return "" end
    return build
end

-- A short report for mail, which holds about 450 characters a mail: the essentials in two or three mails
-- (character, talent points, each equipped item's level and stats, and every stat name seen on gear and in
-- bags). The full report is for copying or whispering.
function M.CompactReport(build)
    local function stat(k) return (tostring(k):gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "")) end
    local _, class = UnitClass("player")
    local race = select(2, UnitRace("player"))
    local db = T.db and T.db.market or {}
    local okV, version = pcall((C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata or error, "Tempus", "Version")
    local _, label, why
    if M.RoleWeights then _, label, why = M.RoleWeights(class) end
    local lines = {
        "Tempus gear data " .. (okV and tostring(version) or "?"),
        "Build: " .. ((build and build ~= "") and build or "?"),
        ("%s %s L%s %s form%s scored %s(%s)"):format(tostring(race), tostring(class), tostring(UnitLevel("player")),
            tostring(UnitFactionGroup and UnitFactionGroup("player")), tostring(GetShapeshiftForm and GetShapeshiftForm() or "?"), tostring(label or "-"), tostring(why or "-")),
    }
    local TL = T.GearAdvisor and T.GearAdvisor.Talents
    local _, _, display = TL and TL.Read() or nil
    local points = {}
    if display then
        local names = {}
        for name in pairs(display) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do points[#points + 1] = name .. " " .. display[name] end
    end
    lines[#lines + 1] = "Talents: " .. (#points > 0 and table.concat(points, ", ") or "none")
    local keys, getStats = {}, C_Item and C_Item.GetItemStats
    local function Stats(link)
        if type(getStats) ~= "function" then return {} end
        local ok, t = pcall(getStats, link)
        return ok and type(t) == "table" and t or {}
    end
    for slot = 1, 19 do
        local ok, link = pcall(GetInventoryItemLink, "player", slot)
        if ok and type(link) == "string" then
            local stats, bits = Stats(link), {}
            local sorted = {}
            for k in pairs(stats) do sorted[#sorted + 1] = tostring(k) end
            table.sort(sorted)
            for _, k in ipairs(sorted) do bits[#bits + 1] = stat(k) .. Tidy(stats[k]); keys[stat(k)] = true end
            local ilvl = select(2, pcall((C_Item and C_Item.GetDetailedItemLevelInfo) or error, link))
            lines[#lines + 1] = ("s%d i%s %s"):format(slot, type(ilvl) == "number" and tostring(ilvl) or "?", table.concat(bits, " "))
        end
    end
    local C = C_Container
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local okN, n = pcall(C and C.GetContainerNumSlots or GetContainerNumSlots, bag)
        if okN and type(n) == "number" then
            for slot = 1, n do
                local ok, link = pcall(C and C.GetContainerItemLink or GetContainerItemLink, bag, slot)
                if ok and type(link) == "string" then
                    for k in pairs(Stats(link)) do keys[stat(k)] = true end
                end
            end
        end
    end
    local names = {}
    for k in pairs(keys) do names[#names + 1] = k end
    table.sort(names)
    lines[#lines + 1] = "Keys: " .. table.concat(names, " ")
    return table.concat(lines, "\n")
end
