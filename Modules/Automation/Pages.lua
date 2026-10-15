-- Tempus UI: settings page for the automation module.
local _, T = ...

T:RegisterPage("general", { key = "automation", label = "Automation", order = 4.5, build = function(p)
    local cfg = function() return T.db.automation end
    p:Section("Quests", "Hold Shift while talking to an NPC to do it yourself. Needs the Automation module (General > Modules).")
    p:Check(cfg, "quests", "Accept quests", "Takes new quests from NPCs, skipping grey ones.")
    p:Check(cfg, "turnIn", "Hand in finished quests", "Never chooses between rewards and never pays gold; those stay your call.")
    p:Section("Combat")
    p:Check(cfg, "errors", "Hide error spam", "Drops the red \"not ready yet\", \"not enough energy\" and \"no target\" messages. Other errors still show.")
    p:Section("Looting")
    p:Check(cfg, "fastLoot", "Fast loot", "With auto-loot on, takes every item at once instead of one by one. Hold your auto-loot key to open the window as usual.")
    p:Section("Away")
    p:Check(cfg, "afk", "AFK screen", "When you go AFK the interface fades out, the camera turns slowly and a Tempus panel shows your name and how long you have been away. Move or press a key to come back.")
end })
