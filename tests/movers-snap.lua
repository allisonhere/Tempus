local T = {Style = {}}
assert(loadfile("Core/Movers.lua"))("Tempus", T)
local snap = T.Movers.FindSnap
local function check(box, targets, threshold, x, y, gx, gy)
    local a,b,c,d = snap(box,targets,threshold)
    assert(a == x and b == y and c == gx and d == gy,
        table.concat({tostring(a),tostring(b),tostring(c),tostring(d)}, ","))
end
-- Adjacent edges on both axes.
check({12,32,42,62}, {{35,55,65,85}}, 8, 3,3,35,65)
-- Centers align without forcing an edge alignment.
check({40,60,40,60}, {{20,82,20,82}}, 8, 1,1,51,51)
-- Outside the capture radius: completely free movement.
check({100,120,100,120}, {{200,220,200,220}}, 8, 0,0,nil,nil)
-- Inclusive threshold, and negative offsets.
check({108,128,108,128}, {{80,100,80,100}}, 8, -8,-8,100,100)
-- Nearest target wins, independent of registration order.
check({10,30,10,30}, {{35,55,35,55},{32,52,32,52}}, 8, 2,2,32,32)
-- Screen center and fractional coordinates from scaled frames.
check({39.5,59.5,39.5,59.5}, {{0,100,0,100}}, 8, .5,.5,50,50)
-- Exact alignment remains visible.
check({0,20,0,20}, {{0,100,0,100}}, 8, 0,0,0,0)
