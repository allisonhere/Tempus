-- Tempus UI: settings page for the cooldown tracker.
local _, T = ...
local UI = T.UI
local W, Changed = UI.W, UI.Changed

T:RegisterPage("general", { key = "cooldowns", label = "Cooldowns", order = 5, build = function(p)
    local cfg = function() return T.db.cooldowns end
    p:Section("Cooldowns", "Icons with cooldown swipes for the spells you list and your equipped trinkets. Unlock the UI to move the row. Needs the Cooldowns module (General > Modules).")
    p:Check(cfg, "enabled", "Show the cooldown row")
    p:Check(cfg, "trinkets", "Include trinkets")
    p:Slider(cfg, "size", "Icon size", 20, 64, 1)
    p:Slider(cfg, "spacing", "Spacing", 0, 16, 1)
    p:Dropdown(cfg, "growX", "Grows toward", { { "RIGHT", "Right" }, { "LEFT", "Left" } })
    p:Section("Tracked spells", "Spell name or ID. Only spells you know are shown.")
    p:Add(W.List("cooldowns", "Spell name or ID, e.g. Pummel"), 236, true)
    p:Add(W.Button("Add my interrupt", function()
        local id = T.Nameplates and T.Nameplates.FindKick and T.Nameplates.FindKick()
        if id then T:ListAdd("cooldowns", tostring(id)) else T:Print("no interrupt found for your class.") end
        Changed()
    end, "Adds your class's interrupt spell if Tempus knows it."))
end })
