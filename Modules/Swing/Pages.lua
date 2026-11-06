-- Tempus UI: settings page for the swing timer.
local _, T = ...

T:RegisterPage("general", { key = "swing", label = "Swing timer", order = 6, build = function(p)
    local cfg = function() return T.db.swing end
    p:Section("Swing timer", "A bar per weapon that refills on every auto attack and turns red while your target is out of range. Unlock the UI to move it. Needs the Swing timer module (General > Modules). Blizzard's own swing timer (Edit Mode) is separate and can stay off.")
    p:Check(cfg, "enabled", "Show the swing timer")
    p:Check(cfg, "offHand", "Off-hand bar when dual wielding")
    p:Check(cfg, "ranged", "Ranged bar when a ranged weapon is equipped")
    p:Check(cfg, "showTime", "Show time left")
    p:Check(cfg, "effects", "Spark swell and a flash when the swing is ready")
    p:Check(cfg, "cue", "Next-swing cue: a tick and a gold bar for the last moments, to time on-next-swing abilities (Heroic Strike, Maul)")
    p:Slider(cfg, "cueWindow", "Cue lead time", 0.1, 1.5, 0.05, function(v) return ("%.2fs"):format(v) end)
    p:Check(cfg, "cueLatency", "Add my latency to the cue")
    p:Check(cfg, "cueSound", "Play a sound when the cue starts")
    p:Dropdown(cfg, "visibility", "Show", { { "COMBAT", "In combat" }, { "ALWAYS", "Always" } })
    p:Slider(cfg, "width", "Width", 80, 400, 1)
    p:Slider(cfg, "height", "Height", 4, 30, 1)
    p:Slider(cfg, "spacing", "Spacing", 0, 12, 1)
end })
