-- Tempus UI: settings page for the cooldown tracker.
local _, T = ...
local UI = T.UI
local W, Changed = UI.W, UI.Changed

local DEMO_W, DEMO_H = UI.COL_W, 330
local function TimelineDemo()
    local S = T.Style
    local f = CreateFrame("Frame")
    f:SetSize(DEMO_W, DEMO_H + 18)
    local title = UI.Text(f, 11, S.C.muted)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Live preview")
    if not (T.Cooldowns and T.Cooldowns.CreateDemo) then
        function f:Refresh() end
        return f
    end
    local box = T.Cooldowns.CreateDemo(DEMO_W, DEMO_H)
    box:SetParent(f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -18)
    function f:Refresh() box:Refresh() end
    return f
end

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
    p:Beside(TimelineDemo(), DEMO_H + 18, function()
        p:Slider(cfg, "length", "Timeline length", 160, 600, 10)
        p:Dropdown(cfg, "range", "Far end of the scale", { { 30, "30 seconds" }, { 60, "1 minute" }, { 120, "2 minutes" }, { 300, "5 minutes" } })
        p:Dropdown(cfg, "fall", "Direction", { { "DOWN", "Falls down" }, { "UP", "Rises up" } })
        p:Dropdown(cfg, "fallMode", "How icons fall", { { "OWN", "Each from the top, at its own speed" }, { "SCALE", "On one shared time scale" } }, "Each from the top: every icon starts at the top and reaches the bottom as its own time ends, so a 5 second debuff falls fast and a 30 second one slowly. Shared scale: position shows seconds left, with time labels.")
        p:Slider(cfg, "lanes", "Columns", 1, 5, 1, nil, "Icons that start together sit side by side in this many columns.")
        p:Check(cfg, "showReady", "Keep ready spells at the ready line")
        p:Dropdown(cfg, "bgStyle", "Background", { { "GLASS", "Glass" }, { "SOLID", "Solid" }, { "MINIMAL", "Rail and marks only" }, { "NONE", "None" } })
        p:Slider(cfg, "bgOpacity", "Background opacity", 0, 1, 0.05, UI.pct)
        p:Slider(cfg, "fadeBg", "Fade background near ready", 0, 1, 0.05, UI.pct, "How much of the background and marks disappear at the ready line. 0% keeps it solid all the way.")
        p:Slider(cfg, "fadeStart", "Fade starts", 0.1, 1, 0.05, UI.pct, "How far up the timeline the fade begins, measured from the ready line. The dashed line in the preview shows it. 100% fades the whole fall.")
        p:Slider(cfg, "fadeIcons", "Fade icons near ready", 0, 1, 0.05, UI.pct, "How much icons dim as they arrive. 100% fades them out completely.")
        p:Check(cfg, "showNumbers", "Show the countdown number on icons")
        p:Check(cfg, "showLabels", "Show time labels")
        p:Check(cfg, "showTicks", "Show lines at each mark")
        p:Check(cfg, "accentRail", "Colour the rail with the accent")
        p:Dropdown(cfg, "labelSide", "Labels and rail on", { { "LEFT", "Left" }, { "RIGHT", "Right" } })
    end)
    p:Section("Tracked spells", "Spell name or ID. Only spells you know are shown.")
    p:Add(W.List("cooldowns", "Spell name or ID, e.g. Pummel"), 236, true)
    p:Add(W.Button("Add my interrupt", function()
        local id = T.Nameplates and T.Nameplates.FindKick and T.Nameplates.FindKick()
        if id then T:ListAdd("cooldowns", tostring(id)) else T:Print("no interrupt found for your class.") end
        Changed()
    end, "Adds your class's interrupt spell if Tempus knows it."))
end })

local TD_W, TD_H = UI.COL_W, 330
local function DebuffDemo()
    local S = T.Style
    local f = CreateFrame("Frame")
    f:SetSize(TD_W, TD_H + 18)
    local title = UI.Text(f, 11, S.C.muted)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Live preview")
    if not (T.Cooldowns and T.Cooldowns.CreateDemo) then
        function f:Refresh() end
        return f
    end
    local box = T.Cooldowns.CreateDemo(TD_W, TD_H, function() return T.db.targetdebuffs end)
    box:SetParent(f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -18)
    function f:Refresh() box:Refresh() end
    return f
end

T:RegisterPage("combat", { key = "targetdebuffs", label = "Target debuffs", order = 5.5, build = function(p)
    local cfg = function() return T.db.targetdebuffs end
    p:Section("Target debuffs", "Your debuffs on the target, falling down a timeline toward the moment they run out. Unlock the UI to move it; the corner grip resizes it. Needs the Target debuff timeline module (General > Modules).")
    p:Check(cfg, "enabled", "Show the debuff timeline")
    p:Check(cfg, "hideRow", "Hide the target frame's own debuff icons", "Replaces the row of debuff icons above the target frame while the timeline is on. Leave it off until your debuffs show here, since the timeline only knows debuffs it has learned.")
    p:Beside(DebuffDemo(), TD_H + 18, function()
        p:Slider(cfg, "size", "Icon size", 20, 64, 1)
        p:Slider(cfg, "length", "Timeline length", 160, 600, 10)
        p:Dropdown(cfg, "fall", "Direction", { { "DOWN", "Falls down" }, { "UP", "Rises up" } })
        p:Dropdown(cfg, "fallMode", "How icons fall", { { "OWN", "Each from the top, at its own speed" }, { "SCALE", "On one shared time scale" } }, "Each from the top: every debuff starts at the top and reaches the bottom as it runs out, so a 5 second debuff falls fast and a 30 second one slowly. Shared scale: position shows seconds left, with time labels.")
        p:Slider(cfg, "lanes", "Columns", 1, 5, 1, nil, "Debuffs applied together sit side by side in this many columns.")
        p:Dropdown(cfg, "range", "Far end of the shared scale", { { 15, "15 seconds" }, { 30, "30 seconds" }, { 60, "1 minute" }, { 120, "2 minutes" } })
        p:Dropdown(cfg, "bgStyle", "Background", { { "GLASS", "Glass" }, { "SOLID", "Solid" }, { "MINIMAL", "Rail and marks only" }, { "NONE", "None" } })
        p:Slider(cfg, "bgOpacity", "Background opacity", 0, 1, 0.05, UI.pct)
        p:Slider(cfg, "fadeBg", "Fade background near the end", 0, 1, 0.05, UI.pct)
        p:Slider(cfg, "fadeStart", "Fade starts", 0.1, 1, 0.05, UI.pct, "How far up the timeline the fade begins, measured from the end. The dashed line in the preview shows it. 100% fades the whole fall.")
        p:Slider(cfg, "fadeIcons", "Fade icons near the end", 0, 1, 0.05, UI.pct)
        p:Check(cfg, "showNumbers", "Show the countdown number on icons")
        p:Check(cfg, "showLabels", "Show time labels")
        p:Check(cfg, "showTicks", "Show lines at each mark")
        p:Check(cfg, "accentRail", "Colour the rail with the accent")
        p:Dropdown(cfg, "labelSide", "Labels and rail on", { { "LEFT", "Left" }, { "RIGHT", "Right" } })
    end)
    p:Section("Your debuffs and their length", "The surest way to get a debuff on the timeline: pick it from your spells, or type it with how many seconds it lasts, for example Moonfire 12 or Corruption 18. Casting it then starts its timer, in or out of combat. A spell ID works too (8921 12).")
    p:Add(W.Button("Pick from my spells", function(btn)
        local TD = T.TargetDebuffs
        local items = {}
        for _, e in ipairs(TD and TD.KnownDebuffs() or {}) do
            items[#items + 1] = { e.name .. " " .. e.seconds, ("%s |cff9aa4b2%ds|r"):format(e.name, e.seconds) }
        end
        if #items == 0 then items = { { "", "|cff888888No debuff spells found for your level and class|r" } } end
        UI.OpenMenu(btn, items, function(v) if v ~= "" then T:ListAdd("debuffs", v) Changed() end end)
    end, "Lists your known harmful spells whose text gives a length, such as Moonfire 12s. The length comes from the spell's own text, so check it against what you see."))
    p:Add(W.List("debuffs", "Debuff and seconds, e.g. Rake 9", true), 236, true)
    p:Section("In combat", "The game hides debuffs from addons during a fight, so Tempus cannot read them then. It times your casts instead, using how long each debuff lasted the last time it could read it out of combat (Rake, Rip and Rupture have built-in lengths). Apply each of your other debuffs once out of combat, on a dummy or a mob, and Tempus learns it. /tempus tddebug shows what it has learned.")
end })
