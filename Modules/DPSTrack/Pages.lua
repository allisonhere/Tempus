-- Tempus UI: settings page for the layered DPS track.
local _, T = ...
local UI = T.UI

T:RegisterPage("general", { key = "dpstrack", label = "DPS track", order = 7, build = function(p)
    local cfg = function() return T.db.dpstrack end
    local two = function(v) return ("%.2f"):format(v) end
    p:Section("Layered DPS track", "One bar from Blizzard's damage meter: purple runs to your live DPS, gold on to your peak this fight, red on to the group's top DPS. Needs the Layered DPS track module (General > Modules).")
    p:Check(cfg, "enabled", "Show the DPS track")
    p:Check(function() return T.db end, "locked", "Lock position", "Untick to drag the track (and every other Tempus element).")
    p:Check(cfg, "test", "Test mode", "Animated sample values, so you can place and colour the track out of combat.")
    p:Check(cfg, "hideOOC", "Hide out of combat")
    p:Check(cfg, "labels", "Show numbers")
    p:Check(cfg, "markers", "Show edge markers")
    p:Dropdown(cfg, "resetOn", "Reset your peak", { { "COMBAT", "Every combat" }, { "ENCOUNTER", "Boss encounters only" } })
    p:Dropdown(cfg, "scaleMode", "Scale", {
        { "DYNAMIC", "Dynamic headroom" }, { "TOP", "Group top fills the bar" }, { "FIXED", "Fixed maximum" },
    }, "Dynamic headroom keeps the group top near 88% of the bar, leaving room to grow.")
    p:Slider(cfg, "fixedMax", "Fixed maximum", 10000, 5000000, 10000, T.DPSTrack.Format, "Used by the Fixed maximum scale.")
    p:Slider(cfg, "smoothing", "Smoothing speed", 0, 20, 1, nil, "Higher follows the meter faster; 0 turns smoothing off.")

    p:Section("Size")
    p:Slider(cfg, "width", "Width", 120, 800, 1)
    p:Slider(cfg, "height", "Height", 4, 40, 1)
    p:Slider(cfg, "scale", "Scale", 0.5, 2, 0.05, two)

    p:Section("Colours", "Live is drawn at full strength; peak and group top are softer hints by default.")
    p:Color(cfg, "liveColor", "Live DPS")
    p:Slider(cfg, "liveAlpha", "Live opacity", 0.1, 1, 0.05, UI.pct)
    p:Color(cfg, "peakColor", "Your peak")
    p:Slider(cfg, "peakAlpha", "Peak opacity", 0.1, 1, 0.05, UI.pct)
    p:Color(cfg, "topColor", "Group top")
    p:Slider(cfg, "topAlpha", "Group top opacity", 0.1, 1, 0.05, UI.pct)
    p:Color(cfg, "trackColor", "Empty track")
end })
