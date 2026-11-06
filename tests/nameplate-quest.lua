-- Nameplates: quest progress text ("4/10") from tooltip lines or quest log objectives.
-- Run: lua5.1 tests/nameplate-quest.lua
local src = io.open("Modules/Nameplates/Nameplates.lua"):read("*a")
local fn = src:match("(function NP%.QuestProgress.-\nend)\n")
assert(fn, "NP.QuestProgress not found")
local NP = {}
assert(loadstring("local NP = ...\n" .. fn))(NP)

assert(NP.QuestProgress({ "Kobold Vermin slain: 4/10" }) == "4/10", "kill objective from the tooltip")
assert(NP.QuestProgress({ "The Kobold Threat", " - Gold Dust: 2/5" }) == "2/5", "drop objective from the tooltip")
assert(NP.QuestProgress({ "Kobold Vermin slain: 10/10" }) == nil, "finished objectives show nothing")
assert(NP.QuestProgress({ "Done: 3/3", "Wolf Meat: 1/8" }) == "1/8", "first unfinished one")
local log = { { text = "Kobold Vermin slain: 3/10", have = 3, need = 10 }, { text = "Wolf Meat: 8/8", have = 8, need = 8 } }
assert(NP.QuestProgress({}, "Kobold Vermin", log) == "3/10", "quest log fallback by mob name")
assert(NP.QuestProgress(nil, "kobold vermin", log) == "3/10", "name match ignores case")
assert(NP.QuestProgress({}, "Young Wolf", log) == nil, "no objective names the mob")
assert(NP.QuestProgress({}, nil, log) == nil, "no name, no fallback")
print("nameplate quest ok")
