-- Tempus UI: settings page for the gathering node icons.
local _, T = ...
local UI = T.UI
local W = UI.W

T:RegisterPage("minimap", { key = "nodes", label = "Gathering nodes", order = 4, build = function(p)
    local cfg = function() return T.db.nodes end
    p:Section("Gathering nodes", "The game does not tell addons what its minimap tracking blips are, so Tempus draws its own icons. It learns a node when you gather it (the icon is the first item looted). Needs the Gathering nodes module (General > Modules).")
    p:Check(cfg, "learn", "Remember nodes as I gather them", "Starts empty and fills up as you mine and pick herbs.")
    p:Slider(cfg, "size", "Icon size", 10, 32, 1)
    p:Check(cfg, "dim", "Dim nodes I just gathered", "The game does not tell addons whether a node is up. A node you gathered recently is shown dim until it has probably respawned. For a certain answer, turn on Find Minerals or Find Herbs: Blizzard's own blip under the pin only exists while the node is up.")
    p:Slider(cfg, "respawn", "Assumed respawn time (minutes)", 1, 30, 1)
    p:Section("Show")
    p:Check(cfg, "ore", "Ore")
    p:Check(cfg, "herb", "Herbs")
    p:Newline()
    p:Add(W.Button("Clear learned nodes", function() T.Nodes:Clear() end))
end })
