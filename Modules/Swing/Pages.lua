-- Tempus UI: Swing Timer configuration. Existing settings bindings remain intact.
local _, T = ...

T:RegisterPage("general", { key = "swing", label = "Swing timer", order = 6, build = function(p)
    if T.UI.RoyalSwing then
        T.UI.RoyalSwing.Build(p)
        return
    end
    local cfg = function() return T.db.swing end
    p:Section("Swing timer", "A bar per weapon that refills on each auto attack and turns red out of range.")
    p:Check(cfg, "enabled", "Show the swing timer")
    p:Check(cfg, "offHand", "Off-hand bar when dual wielding")
    p:Check(cfg, "ranged", "Ranged bar when a ranged weapon is equipped")
    p:Check(cfg, "showTime", "Show time left")
    p:Dropdown(cfg, "visibility", "Show", { { "COMBAT", "In combat" }, { "ALWAYS", "Always" } })
    p:Slider(cfg, "width", "Width", 80, 400, 1)
    p:Slider(cfg, "height", "Height", 4, 30, 1)
    p:Slider(cfg, "spacing", "Spacing", 0, 12, 1)
end })
