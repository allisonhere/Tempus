-- Tempus UI: settings page for the flight timer.
local _, T = ...

T:RegisterPage("convenience", { key = "flighttimer", label = "Flight timer", order = 4.6, build = function(p)
    local cfg = function() return T.db.flighttimer end
    p:Section("Flight timer", "A bar while you ride a flight path. The first time you fly a route it counts up; Tempus remembers how long the flight took (averaging later trips), so from then on it counts down the time left. Unlock the UI to move it. Needs the Flight timer module (General > Modules).")
    p:Section("Learning routes", "On your first trip, Learning route appears above the destination while the timer counts up. Later trips count down. The Tempus hourglass animates beside the destination; turn off Animations to keep it still.")
    p:Check(cfg, "enabled", "Show the flight timer")
    p:Slider(cfg, "width", "Width", 140, 420, 2)
    p:Slider(cfg, "height", "Height", 14, 40, 1)
    p:Add(T.UI.W.Button("Forget learned flight times", function() T.db.flighttimer.times = {} end, "Clears every flight length Tempus has learned; they are learned again as you fly.", 220))
end })
