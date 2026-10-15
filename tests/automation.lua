-- Automation: quests, error filter, fast loot. Run: lua5.1 tests/automation.lua
local T = { Wrap = function(_, _, fn) return fn end, NewModule = function() end, issecret = function() return false end }
T.Style = {}
assert(loadfile("Modules/Automation/Automation.lua"))("Tempus", T)
local A = T.Automation
A.db = { quests = true, turnIn = true, errors = true, fastLoot = true, afk = false }

-- Quests
local calls = {}
local shift = false
IsShiftKeyDown = function() return shift end
AcceptQuest = function() calls[#calls + 1] = "accept" end
IsQuestCompletable = function() return true end
GetQuestMoneyToGet = function() return 0 end
CompleteQuest = function() calls[#calls + 1] = "complete" end
local choices = 0
GetNumQuestChoices = function() return choices end
GetQuestReward = function(i) calls[#calls + 1] = "reward" .. i end

A.OnQuestEvent("QUEST_DETAIL")
assert(calls[1] == "accept", "accepts")
shift = true
A.OnQuestEvent("QUEST_DETAIL")
assert(#calls == 1, "Shift skips")
shift = false
A.OnQuestEvent("QUEST_PROGRESS")
assert(calls[2] == "complete")
GetQuestMoneyToGet = function() return 100 end
A.OnQuestEvent("QUEST_PROGRESS")
assert(#calls == 2, "quests that cost gold are left alone")
A.OnQuestEvent("QUEST_COMPLETE")
assert(calls[3] == "reward0", "no choice: take the reward")
choices = 1
A.OnQuestEvent("QUEST_COMPLETE")
assert(calls[4] == "reward1", "one choice: take it")
choices = 3
A.OnQuestEvent("QUEST_COMPLETE")
assert(#calls == 4, "a real choice is the player's")

-- Gossip: hand in a finished quest before taking a new one; skip grey quests.
local picked
C_GossipInfo = {
    GetActiveQuests = function() return { { questID = 1, isComplete = false }, { questID = 2, isComplete = true } } end,
    GetAvailableQuests = function() return { { questID = 3, isTrivial = true }, { questID = 4 } } end,
    SelectActiveQuest = function(id) picked = "active" .. id end,
    SelectAvailableQuest = function(id) picked = "avail" .. id end,
}
A.OnQuestEvent("GOSSIP_SHOW")
assert(picked == "active2", picked)
C_GossipInfo.GetActiveQuests = function() return { { questID = 1, isComplete = false } } end
A.OnQuestEvent("GOSSIP_SHOW")
assert(picked == "avail4", picked)
A.db.quests = false
picked = nil
A.OnQuestEvent("GOSSIP_SHOW")
assert(picked == nil, "accepting off: nothing taken")
A.db.quests = true

-- Error filter
ERR_ABILITY_COOLDOWN = "Ability is not ready yet."
ERR_OUT_OF_ENERGY = "Not enough energy"
assert(A.IsSpam("Ability is not ready yet.") and A.IsSpam("Not enough energy"))
assert(not A.IsSpam("You are too far away!"), "other errors pass")
assert(not A.IsSpam(nil) and not A.IsSpam(42))

-- Fast loot takes every slot, last first.
local looted = {}
GetNumLootItems = function() return 3 end
LootSlot = function(i) looted[#looted + 1] = i end
A.FastLoot()
assert(table.concat(looted, ",") == "3,2,1")
assert(A.AutoLootOn(true) and not A.AutoLootOn(false))

print("PASS: automation accepts and hands in quests, filters error spam, loots everything")
