local T = {Style = {C = {}}, NewModule = function() end, Wrap = function(_, _, fn) return fn end}
assert(loadfile('Modules/Skins/Skins.lua'))('Tempus', T)
local panel = {
    IsVisible = function(self) return self.shown end,
    bd = {SetFillColor = function() end, SetEdgeColor = function() end},
    Hide = function(self) self.shown = false end,
    Show = function(self) self.shown = true end,
    ClearAllPoints = function() end,
    SetPoint = function() end,
    SetHeight = function(self, value) self.height = value end,
}
local staleContent = {
    IsVisible = function() return true end,
    GetBottom = function() return 400 end,
    GetHeight = function() return 180 end,
    GetChildren = function() end,
}
local tr = {
    tempusPanel = panel,
    IsVisible = function(self) return not self.hidden end,
    GetTop = function() return 600 end,
    GetChildren = function() return staleContent, panel end,
    SetCollapsed = function(self, collapsed) self.isCollapsed = collapsed end,
    Hide = function(self) self.hidden = true end,
}
ObjectiveTrackerFrame = tr
function hooksecurefunc(obj, key, hook)
    local original = obj[key]
    obj[key] = function(...) original(...); hook(...) end
end
function CreateFrame()
    return {RegisterEvent = function() end, SetScript = function() end}
end
C_Timer = {After = function() end}
local SK = T.Skins
SK.db = {trackerPanel = true, trackerAlpha = 0.45}
SK.SkinTracker = function(self) self:UpdateTrackerPanel() end
SK:InitTracker()
assert(panel.shown and panel.height == 214, 'expanded panel should fit content')
tr:SetCollapsed(true)
assert(not panel.shown, 'collapse must hide panel immediately despite stale visible children')
tr:SetCollapsed(false)
assert(panel.shown and panel.height == 214, 'expand must restore panel immediately')
tr.collapsed = true
SK:UpdateTrackerPanel()
assert(not panel.shown, 'legacy collapsed flag must also hide panel')
tr.collapsed = false
SK.db.trackerPanel = false
SK:UpdateTrackerPanel()
assert(not panel.shown, 'disabled panel must stay hidden')
SK.db.trackerPanel = true
SK:UpdateTrackerPanel()
tr:Hide()
assert(not panel.shown, 'hidden tracker must hide panel')
print('PASS: immediate collapse/expand, stale content, legacy collapse, disabled background, hidden tracker')
