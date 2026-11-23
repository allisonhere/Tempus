-- Gear Advisor talent detection.
local T = {}
assert(loadfile("Modules/GearAdvisor/Weights.lua"))("Tempus", T)
assert(loadfile("Modules/GearAdvisor/Scoring.lua"))("Tempus", T)
assert(loadfile("Modules/GearAdvisor/Talents.lua"))("Tempus", T)
local TL, S = T.GearAdvisor.Talents, T.GearAdvisor.Scoring

local signals = { CAT = { { "Ferocity", 1 }, { "Feral Swiftness", 1 } }, RESTO = { { "Genesis", 1 }, { "Nature's Majesty", 1 } } }
local feral = { ferocity = 5, ["feral swiftness"] = 1 }
assert(TL.Detect(22, feral, signals) == "CAT", "six feral points lead")
assert(TL.Detect(9, feral, signals) == nil, "below level 10 there is no signal")
assert(TL.Detect(22, { ferocity = 3 }, signals) == nil, "too few points is not a signal")
assert(TL.Detect(22, { ferocity = 5, genesis = 4 }, signals) == nil, "no clear leader is not a guess")
assert(TL.Detect(22, { ferocity = 6, genesis = 3 }, signals) == "CAT", "a clear lead wins")
assert(TL.Detect(22, {}, signals) == nil and TL.Detect(22, feral, {}) == nil and TL.Detect(nil, feral, signals) == nil)
assert(TL.Detect(22, { FEROCITY = 5 }, signals) == nil, "names are matched in lowercase, like Read stores them")

-- With no signals for a class (nothing probed yet) the player's build is never guessed from talents.
assert(TL.ForPlayer("MAGE", 30) == nil and TL.ForPlayer("DRUID", 30) == nil)

-- Reading the tree through the client's trait calls.
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
local nodes = { [1] = { currentRank = 5, entryIDs = { 11 } }, [2] = { currentRank = 0, entryIDs = { 12 } }, [3] = { currentRank = 2, entryIDs = { 13 } } }
local names = { [11] = 101, [12] = 102, [13] = 103 }
C_Traits = {
    GetConfigInfo = function(cfg) return cfg == 7 and { treeIDs = { 55 } } or nil end,
    GetTreeNodes = function(tree) return tree == 55 and { 1, 2, 3 } or {} end,
    GetNodeInfo = function(_, id) return nodes[id] end,
    GetEntryInfo = function(_, entry) return { definitionID = entry } end,
    GetDefinitionInfo = function(def) return { spellID = names[def] } end,
}
C_Spell = { GetSpellName = function(id) return ({ [101] = "Ferocity", [102] = "Unspent", [103] = "Feral Swiftness" })[id] end }
local ranks, total, display = TL.Read()
assert(ranks.ferocity == 5 and ranks["feral swiftness"] == 2 and ranks.unspent == nil and total == 7, "only talents with points")
assert(display.Ferocity == 5, "display names keep the game's spelling")
T.GearAdvisor.TalentSignals.DRUID = { CAT = { { "Ferocity", 1 } }, BEAR = { { "Thick Hide", 1 } } }
assert(TL.ForPlayer("DRUID", 22) == "CAT", "the player's talents point to cat")
C_ClassTalents.GetActiveConfigID = function() return nil end
assert(TL.Read() == nil and TL.ForPlayer("DRUID", 22) == nil, "no config: no signal")
T.GearAdvisor.TalentSignals.DRUID = nil

-- Role order: chosen, form, talents, last form, default.
assert(select(1, S.Role("DRUID", "AUTO", 0, "BEAR", "RESTO")) == "RESTO" and select(2, S.Role("DRUID", "AUTO", 0, "BEAR", "RESTO")) == "talents")
assert(select(1, S.Role("DRUID", "AUTO", 3, nil, "RESTO")) == "CAT", "form beats talents")
assert(select(1, S.Role("DRUID", "BEAR", 3, nil, "RESTO")) == "BEAR", "your choice beats everything")
assert(select(2, S.Role("WARRIOR", "AUTO", 0, nil, "FURY")) == "talents" and select(1, S.Role("WARRIOR", "AUTO", 0, nil, "FURY")) == "FURY")
assert(select(1, S.Role("WARRIOR", "AUTO", 0, nil, "NOPE")) == "ARMS", "an unknown talent role falls back")

-- /tempus gearsig prints the points on one line to paste back.
T.Market = {}
assert(loadfile("Modules/Market/Probe.lua"))("Tempus", T)
UnitClass = function() return "Druid", "DRUID" end
UnitLevel = function() return 22 end
C_ClassTalents.GetActiveConfigID = function() return 7 end
local sig = T.Market.GearSig()[1]
assert(sig == "DRUID 22, 7 points: Feral Swiftness x2, Ferocity x5", sig)
C_ClassTalents.GetActiveConfigID = function() return nil end
assert(T.Market.GearSig()[1]:find("no talent data"))
print("PASS: talent detection (level gate, clear lead, data-driven, role order, gearsig)")

-- /tempus geartree lists every node with its position and points.
C_ClassTalents.GetActiveConfigID = function() return 7 end
nodes = { [1] = { currentRank = 5, maxRanks = 5, posX = 100, posY = 50, entryIDs = { 11 } },
    [2] = { currentRank = 0, maxRanks = 3, posX = 900, posY = 50, entryIDs = { 12 } },
    [3] = { currentRank = 2, maxRanks = 2, posX = 500, posY = 150, entryIDs = { 13 } } }
local tree = T.Market.GearTree()
assert(tree[1]:find("DRUID tree 55, 3 talents"), tree[1])
assert(tree[2] == "Ferocity 5/5 @100,50; Unspent 0/3 @900,50; Feral Swiftness 2/2 @500,150", tree[2])
C_ClassTalents.GetActiveConfigID = function() return nil end
assert(T.Market.GearTree()[1]:find("no talent tree"))
print("PASS: geartree lists talent nodes with positions")

-- The gear data report: one text, and a whisper-sized split of it.
T.Market.GearSig = function() return { "DRUID 22, 5 points: Ferocity x5" } end
T.Market.GearTree = function() return { "tree line" } end
T.Market.GearStats = function() return { "|cffaabbcc2 items read|r" } end
local rep = T.Market.Report()
assert(rep == "Tempus gear data\nBuild: (type your build here, for example Destruction)\nDRUID 22, 5 points: Ferocity x5\ntree line\n2 items read", rep)
local parts = T.Market.SplitForChat("one\n\n  two|cffaabbcc  \n" .. string.rep("word ", 100), 50)
assert(parts[1] == "one" and parts[2] == "two/cffaabbcc", parts[2])
for _, line in ipairs(parts) do assert(#line <= 50 and not line:find("|", 1, true), line) end
assert(#parts >= 4 and #T.Market.SplitForChat(nil) == 0)
print("PASS: gear report text and whisper split")

-- The report goes to the character on the sender's faction.
UnitFactionGroup = function() return "Horde" end
assert(T.Market.DefaultReportTo() == "Dailyreports")
UnitFactionGroup = function() return "Alliance" end
assert(T.Market.DefaultReportTo() == "Dailyreporter")
UnitFactionGroup = function() return "Neutral" end
assert(T.Market.DefaultReportTo() == "", "no default for a faction without one")
UnitFactionGroup = nil
assert(T.Market.DefaultReportTo() == "")
print("PASS: the report recipient follows the sender's faction")
