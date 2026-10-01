local T = {Style = {C = {}}, NewModule = function() end, Wrap = function(_, _, fn) return fn end}
assert(loadfile('Modules/Skins/Skins.lua'))('Tempus', T)
local points = {}
local panel = {
    shown = false, bd = {SetFillColor = function() end, SetEdgeColor = function() end},
    Hide = function(self) self.shown = false end, Show = function(self) self.shown = true end,
    ClearAllPoints = function() points = {} end,
    SetPoint = function(_, point, rel, relPoint, x, y) points[point] = {rel = rel, y = y} end,
    SetHeight = function() error('anchored panel must not use a measured height') end,
}
local function module(bottom, height, visible)
    return {IsVisible = function() return visible ~= false end, GetBottom = function() return bottom end,
        GetHeight = function() return height end}
end
local a, b, c = module(500, 100), module(380, 60), module(200, 40, false)
local tr = {tempusPanel = panel, IsVisible = function() return true end, GetTop = function() return 600 end,
    ForEachModule = function(self, fn) for _, m in ipairs({a, b, c}) do fn(m) end end}
ObjectiveTrackerFrame = tr
local SK = T.Skins
SK.db = {trackerPanel = true, trackerAlpha = 0.45}
SK:UpdateTrackerPanel()
assert(panel.shown and points.BOTTOM.rel == b and points.BOTTOM.y == -8, 'bottom follows the lowest visible section')
b.IsVisible = function() return false end   -- the lower section went away
SK:UpdateTrackerPanel()
assert(points.BOTTOM.rel == a, 'a shorter list re-anchors to the new last section')
a.IsVisible = function() return false end
SK:UpdateTrackerPanel()
assert(not panel.shown, 'no visible section hides the panel')
print('PASS: panel anchors to the lowest visible tracker section and re-anchors when sections change')
