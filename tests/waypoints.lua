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
