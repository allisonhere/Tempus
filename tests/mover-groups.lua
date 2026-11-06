local T = {Movers = {}}
assert(loadfile("Core/MoverGroups.lua"))("Tempus", T)
local M = T.Movers
local boxes = {{10,110,50,70}, {400,480,100,140}, {750,870,300,330}}
local function Close(a,b) assert(math.abs(a-b) < .00001, tostring(a).." ~= "..tostring(b)) end
local function Plan(action,dx,dy) return assert(M.GroupPlan(boxes,action,dx,dy,1000,800)) end
local p = Plan("move",5,-10)
for i, b in ipairs(boxes) do Close(p[i][1],b[1]+5); Close(p[i][2],b[3]-10) end
-- Clamping preserves internal spacing instead of pinning individual frames at an edge.
p = Plan("move",9999,-9999)
Close(p[1][1],140); Close(p[3][1],880); Close(p[1][2],0); Close(p[2][2],50)
p = Plan("left"); for _, point in ipairs(p) do Close(point[1],10) end
p = Plan("right"); for i, point in ipairs(p) do Close(point[1]+boxes[i][2]-boxes[i][1],870) end
p = Plan("centerX"); for i, point in ipairs(p) do Close(point[1]+(boxes[i][2]-boxes[i][1])/2,440) end
p = Plan("top"); for i, point in ipairs(p) do Close(point[2]+boxes[i][4]-boxes[i][3],330) end
p = Plan("bottom"); for _, point in ipairs(p) do Close(point[2],50) end
p = Plan("centerY"); for i, point in ipairs(p) do Close(point[2]+(boxes[i][4]-boxes[i][3])/2,190) end
p = Plan("centerScreen"); Close(p[1][1],70); Close(p[3][1],810); Close(p[1][2],260)
-- Equal visible gaps account for unequal frame widths/heights; endpoints stay fixed.
p = Plan("spaceX"); Close(p[1][1],10); Close(p[2][1],390); Close(p[3][1],750)
Close(p[2][1]-(p[1][1]+100),p[3][1]-(p[2][1]+80))
p = Plan("spaceY"); Close(p[1][2],50); Close(p[3][2],300)
Close(p[2][2]-(p[1][2]+20),p[3][2]-(p[2][2]+40))
-- Registration order does not affect distribution. Ties retain registration order.
local shuffled = {boxes[3],boxes[1],boxes[2]}
p = assert(M.GroupPlan(shuffled,"spaceX",0,0,1000,800))
Close(p[1][1],750); Close(p[2][1],10); Close(p[3][1],390)
assert(not M.GroupPlan({boxes[1],boxes[2]},"spaceX",0,0,1000,800))
assert(not M.GroupPlan({boxes[1]},"left",0,0,1000,800))
assert(not M.GroupPlan({},"move",0,0,1000,800))
assert(not M.GroupPlan(boxes,"bad",0,0,1000,800))
assert(not M.GroupPlan({{0,100,0,20},{20,120,0,20},{40,140,0,20}},"spaceX",0,0,1000,800))
assert(not M.GroupPlan({{0,1200,0,20}},"move",0,0,1000,800))
-- Fractional geometry survives mixed-scale planning, and plans never mutate inputs.
p = assert(M.GroupPlan({{1.5,21.5,2.25,12.25}},"move",.25,.5,1000,800))
Close(p[1][1],1.75); Close(p[1][2],2.75)
assert(boxes[1][1] == 10 and boxes[3][3] == 300)
print("PASS: group alignment, centering, equal gaps, clamping and fractional geometry")
