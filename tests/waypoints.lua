local T = { NewModule = function() end, Num = function(n) return type(n) == "number" end }
assert(loadfile("Modules/Waypoints/Waypoints.lua"))("Tempus", T)
local W = T.Waypoints
local p = W.Parse("52.3 41.8 Bank", 37)
assert(p.map == 37 and p.x == 0.523 and p.y == 0.418 and p.label == "Bank")
p = W.Parse("#12 0,100 Southern edge", 37)
assert(p.map == 12 and p.x == 0 and p.y == 1 and p.label == "Southern edge")
assert(W.Parse("50 50", 37).label == "Waypoint")
assert(W.Parse(" clear ", 37) == false)
for _, text in ipairs({"", "101 10", "20 101", "-1 50", "NaN 10", "20", "#1 999 1"}) do
    assert(W.Parse(text, 37) == nil, text)
end
assert(W.Parse("50 50", nil) == nil)
local function near(a, b) assert(math.abs(a - b) < 1e-6, tostring(a) .. " != " .. tostring(b)) end
local angle, distance = W.Bearing(0, 100, 0)
near(angle, 0); near(distance, 100)
near(W.Bearing(100, 0, 0), -math.pi / 2)
near(W.Bearing(100, 0, 3 * math.pi / 2) % (2 * math.pi), 0)
local x, y = W.Project(100, 0, 200, 80)
near(x, 40); near(y, 0)
x, y = W.Project(10000, 10000, 200, 80)
near(math.sqrt(x*x+y*y), 80)
x, y = W.Project(100, 0, 200, 80, 3 * math.pi / 2)
near(x, 0); near(y, 40)
local messages = {}
T.Print = function(_, text) messages[#messages + 1] = text end
C_Map = { GetBestMapForUnit = function() return 37 end, GetMapInfo = function(id) return id == 37 and {} end }
W.db = {}
W.Update = function() end
W:Command("50 60 Test")
assert(W.db.target.label == "Test")
W:Command("#999 50 60")
assert(W.db.target.label == "Test", "invalid map leaves destination intact")
W:Command("clear")
assert(W.db.target == nil)
print("PASS: waypoint coordinates, bearing, minimap rotation, clamping and commands")

-- Exercise real UI updates: hiding a button's parent between mouse-down and mouse-up cancels clicks.
local module
local UI = { Num = T.Num, NewModule = function(_, _, def) module = def end }
assert(loadfile("Modules/Waypoints/Waypoints.lua"))("Tempus", UI)
local Way = UI.Waypoints
local function widget()
    local w = { scripts = {}, shown = true, hides = 0 }
    return setmetatable(w, { __index = function(_, key)
        if key == "GetFrameLevel" then return function() return 1 end end
        if key == "CreateTexture" then return widget end
        if key == "SetScript" then return function(self, event, fn) self.scripts[event] = fn end end
        if key == "Hide" then return function(self) self.shown = false; self.hides = self.hides + 1 end end
        if key == "Show" then return function(self) self.shown = true end end
        if key == "SetShown" then return function(self, value) self.shown = not not value end end
        return function() end
    end })
end
CreateFrame = widget
UI.Style = { Text = widget, Backdrop = function() end, C = { text = {} } }
UI.Movers = { ApplyPoint = function() end, Register = function() end }
UI.Wrap = function(_, _, fn) return fn end
UI.Print = function() end
UI.db = { locked = true, waypoints = {} }
GameTooltip = widget()
SlashCmdList = {}
module.OnEnable()
Way.db.target = { map = 37, x = .5, y = .6, label = "Test" }
Way:Update()
local before = Way.arrow.hides
Way:Update()
assert(Way.arrow.shown and Way.arrow.hides == before, "refresh must not interrupt a close click")
Way.arrow.scripts.OnHide = function() end
Way.arrow.close.scripts.OnClick()
assert(not Way.db.target and not Way.arrow.shown, "close clears destination and hides locked compass")
near(Way.CompassOffset(0), 0)
near(Way.CompassOffset(math.pi / 2), 140)
near(Way.CompassOffset(-math.pi / 2), -140)
UI.db.locked = false
Way:Update()
assert(Way.arrow.shown, "unlocked compass remains available for positioning")
print("PASS: compass refresh preserves clicks and close clears the waypoint")
