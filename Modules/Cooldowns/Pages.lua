-- Tempus UI: settings page for the cooldown tracker.
local _, T = ...
local UI = T.UI
local W, Changed = UI.W, UI.Changed

T:RegisterPage("combat", { key = "cooldowns", label = "Cooldowns", order = 5, build = function(p)
    local cfg = function() return T.db.cooldowns end
    p:Section("Cooldowns", "Icons with cooldown swipes for the spells you list and your equipped trinkets. Unlock the UI to move them. Needs the Cooldowns module (General > Modules).")
    p:Check(cfg, "enabled", "Show the cooldowns")
    p:Dropdown(cfg, "mode", "Style", { { "icons", "Row of icons" }, { "timeline", "Timeline" } })
    p:Check(cfg, "trinkets", "Include trinkets")
    p:Slider(cfg, "size", "Icon size", 20, 64, 1)
    p:Slider(cfg, "spacing", "Spacing", 0, 16, 1)
    p:Dropdown(cfg, "growX", "Row grows toward", { { "RIGHT", "Right" }, { "LEFT", "Left" } })
    p:Section("Timeline", "Each spell on cooldown falls down a scale toward the ready line, over a background that fades out as it gets there. Spells that would overlap take a second lane. In combat the game can hide cooldown times; those icons wait at the far end.")
    p:Slider(cfg, "length", "Timeline length", 160, 600, 10)
    p:Dropdown(cfg, "range", "Far end of the scale", { { 30, "30 seconds" }, { 60, "1 minute" }, { 120, "2 minutes" }, { 300, "5 minutes" } })
    p:Dropdown(cfg, "fall", "Direction", { { "DOWN", "Falls down" }, { "UP", "Rises up" } })
    p:Check(cfg, "showReady", "Keep ready spells at the ready line")
    p:Section("Timeline look", "The background is drawn behind the icons. Fading dims it toward the ready line so the near end melts away.")
    p:Dropdown(cfg, "bgStyle", "Background", { { "GLASS", "Glass" }, { "SOLID", "Solid" }, { "MINIMAL", "Rail and marks only" } })
    p:Slider(cfg, "bgOpacity", "Background opacity", 0, 1, 0.05, UI.pct)
    p:Slider(cfg, "fadeBg", "Fade background near ready", 0, 1, 0.05, UI.pct, "How much of the background and marks disappear at the ready line. 0% keeps it solid all the way.")
    p:Slider(cfg, "fadeIcons", "Fade icons near ready", 0, 1, 0.05, UI.pct, "How much icons dim as they arrive. 100% fades them out completely.")
    p:Check(cfg, "showLabels", "Show time labels")
    p:Check(cfg, "showTicks", "Show lines at each mark")
    p:Check(cfg, "accentRail", "Colour the rail with the accent")
    p:Dropdown(cfg, "labelSide", "Labels and rail on", { { "LEFT", "Left" }, { "RIGHT", "Right" } })
    p:Section("Tracked spells", "Spell name or ID. Only spells you know are shown.")
    p:Add(W.List("cooldowns", "Spell name or ID, e.g. Pummel"), 236, true)
    p:Add(W.Button("Add my interrupt", function()
        local id = T.Nameplates and T.Nameplates.FindKick and T.Nameplates.FindKick()
        if id then T:ListAdd("cooldowns", tostring(id)) else T:Print("no interrupt found for your class.") end
        Changed()
    end, "Adds your class's interrupt spell if Tempus knows it."))
end })
