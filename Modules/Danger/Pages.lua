-- Tempus UI: settings page for the danger alert.
local _, T = ...

T:RegisterPage("combat", { key = "danger", label = "Danger alert", order = 6.7, build = function(p)
    local cfg = function() return T.db.danger end
    p:Section("Danger alert", "A warning at the top of the screen when a risky mob's nameplate appears: elite, rare, skull (??) level, or several levels above you, and hostile players flagged for PvP. Another warning goes out when more mobs are on you than you meant to pull. Each mob warns once, then stays quiet for a while. It reads enemy nameplates, so keep them switched on (V). Unlock the UI to move the warning. Needs the Danger alert module (General > Modules).")
    p:Check(cfg, "enabled", "Danger alerts")
    p:Add(T.UI.W.Button("Test", function()
        if T.Danger and T.Danger.frame then T.Danger:Test() else T:Print("the Danger alert module is off.") end
    end, "Shows a sample warning."))
    p:Check(cfg, "elites", "Elites and rare elites")
    p:Check(cfg, "rares", "Rare mobs")
    p:Slider(cfg, "levelGap", "Warn for mobs this many levels above me (0 = off)", 0, 10, 1, nil, "A mob this many levels or more above you counts as risky. Skull (??) mobs always warn.")
    p:Check(cfg, "players", "Hostile players flagged for PvP")
    p:Check(cfg, "pull", "Warn when too many mobs are on me")
    p:Slider(cfg, "pullCount", "Too many mobs", 2, 6, 1, nil, "Warn when at least this many enemies are attacking you at once.")
    p:Check(cfg, "sound", "Play a warning sound")
    p:Slider(cfg, "quietFor", "Seconds before the same mob warns again", 30, 600, 10, nil, "After warning about a mob, stay quiet about that same mob for this long.")
end })
