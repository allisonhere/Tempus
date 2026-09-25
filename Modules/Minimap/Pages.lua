-- Tempus UI: settings pages for the minimap and info bar modules.
local _, T = ...
local UI = T.UI
local W, Changed = UI.W, UI.Changed

T:RegisterPage("minimap", { key = "minimap", label = "Minimap", order = 1, build = function(p)
    local cfg = function() return T.db.minimap end
    p:Section("Minimap", "A square minimap in a Tempus panel. Mouse wheel zooms, right-click opens tracking, middle-click opens the calendar. Addon buttons tuck around the square edge.")
    p:Slider(cfg, "size", "Size", 120, 320, 2)
    p:Slider(cfg, "scale", "Scale", 0.5, 2, 0.05, UI.pct)
    p:Dropdown(cfg, "zoneText", "Zone name", { { "MOUSEOVER", "On mouseover" }, { "ALWAYS", "Always" }, { "HIDE", "Hidden" } })
    p:Check(cfg, "fadeAddonButtons", "Hide addon buttons until mouseover")
    p:Check(cfg, "clock", "Clock")
    p:Check(cfg, "clock24", "24-hour clock")
    p:Check(cfg, "coords", "Coordinates")
    p:Newline()
    p:Add(W.Button("Reset position", function()
        T.db.minimap.point = { "TOPRIGHT", "UIParent", "TOPRIGHT", -8, -8 }
        Changed()
    end))
end })

T:RegisterPage("minimap", { key = "databar", label = "Info Bar", order = 2, build = function(p)
    local cfg = function() return T.db.databar end
    local slots = function() return T.db.databar.slots end
    p:Section("Info bar", "Live data texts. Hover one for details; click for a shortcut (bags, character sheet, calendar...).")
    p:Check(cfg, "enabled", "Enabled")
    p:Check(cfg, "time24", "24-hour time")
    p:Slider(cfg, "width", "Width", 150, 1600, 10)
    p:Slider(cfg, "height", "Height", 16, 36, 1)
    p:Slider(cfg, "fontSize", "Text size", 8, 16, 1)
    p:Slider(cfg, "count", "Number of slots", 1, 8, 1)
    p:Section("Slots", "Left to right.")
    for i = 1, 8 do
        local item = p:Dropdown(slots, i, "Slot " .. i, function() return T.DataBar:TextList() end)
        item.enabledIf = function() return i <= T.db.databar.count end
    end
    p:Section("Position")
    p:Add(W.Button("Reset position", function()
        T.db.databar.point = { "BOTTOM", "UIParent", "BOTTOM", 0, 10 }
        Changed()
    end))
end })
